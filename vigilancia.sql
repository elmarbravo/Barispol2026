-- Vigilância automática (03-10-2026). A falha de 02-10-2026 (a
-- sincronização parada 4 horas depois da mudança da sessão) só se viu porque
-- uma médica se queixou. Agora o servidor verifica-se a si próprio de 15 em
-- 15 minutos e avisa a Direcção no telemóvel, uma vez por problema (de novo
-- só depois de 6 horas se continuar), e outra vez quando se resolve.
--
-- Verificações:
--   agendamento     — uma tarefa agendada falhou nos últimos 30 min
--   funcoes         — 5 ou mais chamadas às funções com erro em 30 min
--   presenca        — dias úteis, 08h–18h de Luanda: nenhum aparelho deu
--                     sinal em 45 min (foi o sintoma de 02-10-2026)
--   metagest        — 06h–21h de Luanda: a cópia do MetaGest não correu bem
--                     em 30 min
--   whatsapp        — a cópia do WhatsApp não corre há 30 min
--   emails          — 80 ou mais e-mails hoje (o limite gratuito é 100)
-- O estado de cada verificação fica em vigilancia_estado; o ecrã Admin →
-- «Saúde do sistema» mostra-o (bsp_saude_sistema, só a gestão).

create table if not exists public.vigilancia_estado (
  chave text primary key,
  ok boolean not null default true,
  detalhe text not null default '',
  desde timestamptz not null default now(),
  avisado_em timestamptz,
  verificado_em timestamptz not null default now()
);
alter table public.vigilancia_estado enable row level security;

create or replace function public.bsp_vigilancia()
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare
  luanda timestamp := now() at time zone 'Africa/Luanda';
  util boolean := extract(isodow from luanda) <= 5;
  h int := extract(hour from luanda);
  r record; n int := 0; gestao text[];
  v jsonb := '[]';
begin
  -- agendamentos
  v := v || jsonb_build_object('chave', 'agendamento', 'ok', not exists (
         select 1 from cron.job_run_details d where d.status = 'failed' and d.start_time > now() - interval '30 minutes'),
       'detalhe', coalesce((select 'Falhou: ' || string_agg(distinct j.jobname, ', ') from cron.job_run_details d join cron.job j on j.jobid = d.jobid
                             where d.status = 'failed' and d.start_time > now() - interval '30 minutes'), ''));
  -- funções
  v := v || jsonb_build_object('chave', 'funcoes', 'ok', (select count(*) from net._http_response
           where created > now() - interval '30 minutes' and (status_code >= 500 or error_msg is not null)) < 5,
       'detalhe', (select count(*) || ' chamadas com erro em 30 min' from net._http_response
           where created > now() - interval '30 minutes' and (status_code >= 500 or error_msg is not null)));
  -- presença (o Workspace aberto em algum aparelho)
  v := v || jsonb_build_object('chave', 'presenca', 'ok', not (util and h between 8 and 17)
           or exists (select 1 from public.presenca where visto_em > now() - interval '45 minutes'),
       'detalhe', 'Último sinal: ' || coalesce(to_char((select max(visto_em) from public.presenca) at time zone 'Africa/Luanda', 'DD-MM HH24:MI'), 'nunca'));
  -- MetaGest
  v := v || jsonb_build_object('chave', 'metagest', 'ok', not (h between 6 and 20)
           or exists (select 1 from erp.sync_log where ok and started_at > now() - interval '30 minutes'),
       'detalhe', 'Última cópia boa: ' || coalesce(to_char((select max(started_at) from erp.sync_log where ok) at time zone 'Africa/Luanda', 'DD-MM HH24:MI'), 'nunca'));
  -- WhatsApp
  v := v || jsonb_build_object('chave', 'whatsapp', 'ok', exists (select 1 from whatsapp.sync_log where fim > now() - interval '30 minutes'),
       'detalhe', 'Última cópia: ' || coalesce(to_char((select max(fim) from whatsapp.sync_log) at time zone 'Africa/Luanda', 'DD-MM HH24:MI'), 'nunca'));
  -- e-mails
  v := v || jsonb_build_object('chave', 'emails', 'ok', (select count(*) from public.emails_registo
           where not pausado and criado_em >= (date_trunc('day', luanda) at time zone 'Africa/Luanda')) < 80,
       'detalhe', (select count(*) || ' e-mails hoje (limite 95)' from public.emails_registo
           where not pausado and criado_em >= (date_trunc('day', luanda) at time zone 'Africa/Luanda')));

  select coalesce(array_agg(e->>'id'), '{}') into gestao
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and coalesce(e->>'accessLevel', '') <> 'Sócio'
     and coalesce((s.camadas -> (e->>'accessLevel') ->> 'podeGerirUtilizadores')::boolean, (e->>'accessLevel') in ('Direcção', 'Coordenação'));

  for r in
    select x->>'chave' chave, (x->>'ok')::boolean ok, x->>'detalhe' detalhe, s.ok antes, s.avisado_em
      from jsonb_array_elements(v) x left join public.vigilancia_estado s on s.chave = x->>'chave'
  loop
    insert into public.vigilancia_estado as e (chave, ok, detalhe, desde, verificado_em)
    values (r.chave, r.ok, r.detalhe, now(), now())
    on conflict (chave) do update set ok = excluded.ok, detalhe = excluded.detalhe, verificado_em = now(),
      desde = case when e.ok is distinct from excluded.ok then now() else e.desde end;
    if not r.ok and (r.antes is distinct from false or r.avisado_em is null or r.avisado_em < now() - interval '6 hours') then
      perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(gestao), 'titulo', 'Workspace: possível falha (' || r.chave || ')',
        'corpo', left(r.detalhe, 150), 'url', '#/admin', 'tag', 'vigilancia-' || r.chave));
      update public.vigilancia_estado set avisado_em = now() where chave = r.chave;
      n := n + 1;
    elsif r.ok and r.antes = false and r.avisado_em is not null then
      perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(gestao), 'titulo', 'Workspace: resolvido (' || r.chave || ')',
        'corpo', left(r.detalhe, 150), 'url', '#/admin', 'tag', 'vigilancia-' || r.chave));
      update public.vigilancia_estado set avisado_em = null where chave = r.chave;
    end if;
  end loop;
  return n;
end $f$;
revoke execute on function public.bsp_vigilancia() from public, anon, authenticated;

create or replace function public.bsp_saude_sistema()
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  select case when not public.bsp_e_gestor() then null else
    coalesce((select jsonb_agg(to_jsonb(v) order by v.ok, v.chave) from public.vigilancia_estado v), '[]'::jsonb) end
$f$;
revoke execute on function public.bsp_saude_sistema() from public, anon;
grant execute on function public.bsp_saude_sistema() to authenticated;

select cron.schedule('bsp-vigilancia', '*/15 * * * *', 'select public.bsp_vigilancia();');
