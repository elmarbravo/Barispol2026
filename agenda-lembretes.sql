-- Barispol Workspace · lembretes dos eventos e e-mail a cada convite
-- Pedido do Elmar, 02-10-2026: «Nos eventos adicione a opção lembretes para
-- escolhermos quando nos avisar e envie por e-mail sempre que alguém for
-- convidado». Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo
-- dia. Pode correr-se mais do que uma vez. Corre-se depois de
-- agenda-privada.sql.
--
--   agenda_eventos.lembretes          minutos antes, escolhidos por quem cria
--                                     (valem para todos os do evento)
--   agenda_eventos.lembretes_pessoa   {id: [minutos]}: cada pessoa muda os seus
--   bsp_evento_lembretes(id, minutos) muda os lembretes da própria pessoa
--   agenda_lembretes_enviados         um aviso por evento, pessoa, ocorrência
--                                     e antecedência
--   bsp_srv_agenda_lembretes()        os lembretes que vencem agora (só a
--                                     chave do servidor; marca-os como enviados)
--   bsp_agenda_convite_aviso          gatilho: e-mail no instante a quem é
--                                     convidado (Edge Function agenda-avisos)
--   cron bsp-agenda-lembretes         de 5 em 5 minutos

alter table public.agenda_eventos add column if not exists lembretes integer[] not null default '{}';
alter table public.agenda_eventos add column if not exists lembretes_pessoa jsonb not null default '{}'::jsonb;

-- Cada pessoa que vê o evento escolhe os seus lembretes (vazio = sem aviso;
-- nulo = volta aos do evento).
create or replace function public.bsp_evento_lembretes(p_id bigint, p_minutos integer[])
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare eu text := public.bsp_meu_id(); e public.agenda_eventos;
begin
  if eu is null then raise exception 'Sem sessão.'; end if;
  select * into e from public.agenda_eventos where id = p_id for update;
  if not found or not (not e.privado or e.dono = eu or e.criado_por = eu or eu = any (e.convidados) or public.bsp_ve_tarefas_pessoais()) then
    raise exception 'Evento não encontrado.';
  end if;
  if p_minutos is not null and exists (select 1 from unnest(p_minutos) m where m < 0 or m > 20160) then
    raise exception 'Lembrete inválido.';
  end if;
  update public.agenda_eventos
     set lembretes_pessoa = case when p_minutos is null then lembretes_pessoa - eu
                                 else lembretes_pessoa || jsonb_build_object(eu, to_jsonb(p_minutos)) end
   where id = p_id;
end $function$;
revoke all on function public.bsp_evento_lembretes(bigint, integer[]) from public, anon;
grant execute on function public.bsp_evento_lembretes(bigint, integer[]) to authenticated;

create table if not exists public.agenda_lembretes_enviados (
  evento_id bigint not null,
  user_id text not null,
  ocorre timestamptz not null,
  minutos integer not null,
  enviado_em timestamptz not null default now(),
  primary key (evento_id, user_id, ocorre, minutos)
);
alter table public.agenda_lembretes_enviados enable row level security;
revoke all on public.agenda_lembretes_enviados from anon, authenticated;

-- Os lembretes que vencem agora (com 15 minutos de folga para trás, para um
-- agendamento atrasado não os perder). Marca-os como enviados antes de os
-- devolver: um agendamento repetido não manda o mesmo aviso duas vezes.
-- Ocorrências: numa data (data), todas as semanas (dia, 0 = Segunda, desde
-- data se houver) e todos os meses (dia_mes, desde data). Hora de Luanda.
create or replace function public.bsp_srv_agenda_lembretes()
returns table (evento_id bigint, user_id text, nome text, email text, titulo text, local text, descricao text,
               ocorre timestamptz, minutos integer, privado boolean)
language sql
volatile
security definer
set search_path to 'public'
as $function$
  with hoje as (select (now() at time zone 'Africa/Luanda')::date d),
  dias as (select (select d from hoje) + k d from generate_series(-1, 15) k),
  oc as (
    select e.*, ((x.d + e.hora::time) at time zone 'Africa/Luanda') quando
      from public.agenda_eventos e, dias x
     where e.hora ~ '^\d{2}:\d{2}$'
       and (case
              when e.dia_mes is not null then extract(day from x.d) = e.dia_mes and x.d >= coalesce(e.data, x.d)
              when e.dia is not null then (extract(isodow from x.d)::int - 1) = e.dia and x.d >= coalesce(e.data, x.d)
              else x.d = e.data end)
  ),
  pessoas as (
    select o.*, p.uid from oc o,
      lateral (select o.dono uid union select unnest(o.convidados)) p
     where coalesce(o.respostas->>p.uid, '') <> 'nao'
  ),
  devidos as (
    select p.id, p.uid, p.quando, m.minutos, p.titulo, p.local, p.descricao, p.privado
      from pessoas p,
      lateral (select unnest(case when p.lembretes_pessoa ? p.uid
                                  then array(select jsonb_array_elements_text(p.lembretes_pessoa->p.uid)::int)
                                  else p.lembretes end) minutos) m
     where p.quando - make_interval(mins => m.minutos) between now() - interval '15 minutes' and now()
       and p.quando > now() - interval '15 minutes'
  ),
  novos as (
    insert into public.agenda_lembretes_enviados (evento_id, user_id, ocorre, minutos)
    select id, uid, quando, minutos from devidos
    on conflict do nothing
    returning evento_id, user_id, ocorre, minutos
  )
  select n.evento_id, n.user_id, t.e->>'name', t.e->>'email', d.titulo, d.local, d.descricao, n.ocorre, n.minutos, d.privado
    from novos n
    join devidos d on d.id = n.evento_id and d.uid = n.user_id and d.quando = n.ocorre and d.minutos = n.minutos
    left join lateral (select e from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = n.user_id limit 1) t on true
$function$;
revoke all on function public.bsp_srv_agenda_lembretes() from public, anon, authenticated;
grant execute on function public.bsp_srv_agenda_lembretes() to service_role;

-- Convite: o e-mail sai no instante (agenda-avisos). O aviso no sino é a
-- novidade do gatilho bsp_agenda_carimbo, marcada como já enviada para não
-- voltar a sair no e-mail das 05h00.
create or replace function public.bsp_agenda_convite_aviso()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare novos text[];
begin
  novos := array(select x from unnest(coalesce(new.convidados, '{}')) x
                  where tg_op = 'INSERT' or not (x = any (coalesce(old.convidados, '{}'))));
  if coalesce(array_length(novos, 1), 0) = 0 then return new; end if;
  update public.novidades set enviado_em = now(), enviados = coalesce(enviados, 0)
   where enviado_em is null and destino = 'calendar' and titulo = 'Convite: ' || new.titulo
     and criado_em > now() - interval '1 minute';
  perform net.http_post(
    url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/agenda-avisos',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                       where name = 'bsp_resumo_agendamento' limit 1)),
    body    := jsonb_build_object('qual', 'convite', 'evento', new.id, 'ids', to_jsonb(novos)),
    timeout_milliseconds := 20000
  );
  return new;
end $function$;
revoke all on function public.bsp_agenda_convite_aviso() from public, anon;
create or replace trigger bsp_agenda_convite_aviso after insert or update of convidados on public.agenda_eventos
  for each row execute function public.bsp_agenda_convite_aviso();

-- Lembretes por e-mail de 5 em 5 minutos.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'bsp-agenda-lembretes') then perform cron.unschedule('bsp-agenda-lembretes'); end if;
  perform cron.schedule('bsp-agenda-lembretes', '*/5 * * * *', $cmd$
    select net.http_post(
      url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/agenda-avisos',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                         where name = 'bsp_resumo_agendamento' limit 1)),
      body    := '{"qual":"lembretes"}'::jsonb,
      timeout_milliseconds := 30000
    );
  $cmd$);
end $$;

insert into public.novidades (titulo, texto, grupos, destino)
select 'Lembretes nos eventos',
       'Na Agenda, cada evento pode ter lembretes: na hora, 15 minutos, 1 hora, 1 dia antes e outros. Quem cria escolhe os do evento e cada pessoa pode mudar os seus no próprio evento. O lembrete chega no sino e por e-mail. Quem é convidado recebe também um e-mail no instante.',
       array['todos'], 'calendar'
 where not exists (select 1 from public.novidades where titulo = 'Lembretes nos eventos');

notify pgrst, 'reload schema';
