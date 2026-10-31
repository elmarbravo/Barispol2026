-- Relatórios da semana para imprimir (31-10-2026, Elmar: «Os relatórios todos
-- quero que sejam impressos todas as semanas nas segundas-feiras, um lembrete
-- com anexo para cada chefe de área e director clínico»).
--
-- À segunda-feira, às 07h38 de Luanda (06h38 UTC; minuto livre, longe das
-- cargas das 07h15, 07h20 e 07h30), o cron bsp-relatorios-semana chama a Edge
-- Function relatorios-semana (funcoes/relatorios-semana), que junta os
-- relatórios de turno da semana anterior (segunda a domingo) e manda:
--   · a cada chefe de área (relatorios_destinos.para) o PDF compacto da sua área,
--     para imprimir uma vez por semana, assinar e remeter ao Director Clínico;
--     as áreas sem chefe vão ao Director Clínico (DireccaoClinica@), que assina;
--   · ao Elmar e ao Director Clínico o parecer do Workspace sobre a semana
--     (avaliação de tudo o que se recebeu), em HTML no corpo e em PDF.
-- (31-10-2026, Elmar: «não quero que imprimam todos os dias… muitas despesas».)
-- Um envio por semana e destino em relatorios_enviados (tipo «semana»).
-- O PDF vai como anexo pela bright-worker, que passa a aceitar application/pdf
-- só do servidor (até ~5 MB). Sem nomes de utentes; os ficheiros anexados aos
-- relatórios nunca vão por e-mail.
--
-- Antes de correr: publicar a Edge Function relatorios-semana com a verificação
-- de JWT desligada (tem autenticação própria, como a relatorios-diarios) e a
-- bright-worker nova. O código do agendamento é o do cofre
-- (bsp_resumo_agendamento), conferido por bsp_resumo_codigo_confere.
-- Ensaio sem enviar: chamar a função com {"previa": true}.

-- Folhas semanais (31-10-2026, Elmar: «a obrigatoriedade do chefe da área assinar
-- e remeter ao director clínico»). Uma linha por semana e área: o PDF enviado
-- (pela Edge Function), a assinatura e remessa do chefe e a recepção do Director
-- Clínico. Áreas sem chefe em relatorios_destinos: assina o próprio Director
-- Clínico (u14). Lembrete à quarta-feira a quem ainda não assinou e à sexta ao
-- Director Clínico do que ainda não recebeu.
create table if not exists public.relatorios_semana_folhas (
  semana        date not null,          -- a segunda-feira da semana
  area          text not null,
  relatorios    int not null default 0,
  enviado_em    timestamptz,
  assinado_por  text,
  assinado_em   timestamptz,
  recebido_por  text,
  recebido_em   timestamptz,
  primary key (semana, area)
);
alter table public.relatorios_semana_folhas enable row level security;
revoke all on public.relatorios_semana_folhas from anon, authenticated;

-- É chefe desta área? (o e-mail da sessão está em relatorios_destinos.para)
create or replace function public.bsp_rel_e_chefe(p_area text)
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select exists (select 1 from relatorios_destinos d
                  where d.area = p_area
                    and lower(coalesce(auth.jwt()->>'email', '')) = any (select lower(x) from unnest(coalesce(d.para, '{}')) x))
$f$;
revoke all on function public.bsp_rel_e_chefe(text) from public, anon;
grant execute on function public.bsp_rel_e_chefe(text) to authenticated;

-- Quem assina a folha da área: o chefe; sem chefe, o Director Clínico.
create or replace function public.bsp_rel_assina_folha(p_area text)
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select bsp_rel_e_chefe(p_area)
      or bsp_e_gestor()
      or (bsp_meu_id() = 'u14' and not exists (select 1 from relatorios_destinos d where d.area = p_area and coalesce(array_length(d.para, 1), 0) > 0))
$f$;
revoke all on function public.bsp_rel_assina_folha(text) from public, anon;
grant execute on function public.bsp_rel_assina_folha(text) to authenticated;

create or replace function public.bsp_rel_semana_lista(p_semanas int default 8)
returns setof public.relatorios_semana_folhas
language sql stable security definer set search_path to 'public'
as $f$
  select f.* from relatorios_semana_folhas f
   where f.semana >= (current_date - (greatest(1, least(p_semanas, 52)) * 7))
     and (bsp_e_gestor() or bsp_meu_id() = 'u14' or bsp_rel_e_chefe(f.area))
   order by f.semana desc, f.area
$f$;
revoke all on function public.bsp_rel_semana_lista(int) from public, anon;
grant execute on function public.bsp_rel_semana_lista(int) to authenticated;

create or replace function public.bsp_rel_semana_marcar(p_semana date, p_area text, p_accao text)
returns text language plpgsql volatile security definer set search_path to 'public'
as $f$
declare eu text := bsp_meu_id(); f relatorios_semana_folhas;
begin
  if eu is null then raise exception 'Sem sessão.'; end if;
  select * into f from relatorios_semana_folhas where semana = p_semana and area = p_area for update;
  if not found then raise exception 'Folha não encontrada.'; end if;
  if p_accao = 'assinado' then
    if not bsp_rel_assina_folha(p_area) then raise exception 'Só o chefe da área assina esta folha.'; end if;
    if f.assinado_em is not null then return 'já assinada'; end if;
    update relatorios_semana_folhas set assinado_por = eu, assinado_em = now() where semana = p_semana and area = p_area;
    begin
      perform bsp_push_post(jsonb_build_object('para', jsonb_build_array('u14'),
        'titulo', 'Folha semanal assinada e remetida',
        'corpo', 'Relatórios de ' || p_area || ', semana de ' || to_char(p_semana, 'DD-MM') || '. Confirme a recepção no Workspace.',
        'url', '#/relatorios', 'tag', 'folha-' || p_area || '-' || p_semana));
    exception when others then raise warning 'bsp_rel_semana_marcar push: %', sqlerrm;
    end;
    return 'assinada';
  elsif p_accao = 'recebido' then
    if not (eu = 'u14' or bsp_e_gestor()) then raise exception 'Só o Director Clínico confirma a recepção.'; end if;
    if f.assinado_em is null then raise exception 'A folha ainda não foi assinada pelo chefe da área.'; end if;
    update relatorios_semana_folhas set recebido_por = eu, recebido_em = now() where semana = p_semana and area = p_area;
    return 'recebida';
  end if;
  raise exception 'Acção desconhecida.';
end $f$;
revoke all on function public.bsp_rel_semana_marcar(date, text, text) from public, anon;
grant execute on function public.bsp_rel_semana_marcar(date, text, text) to authenticated;

-- Lembretes: quarta (por assinar, ao chefe ou a u14) e sexta (por receber, a u14).
create or replace function public.bsp_rel_semana_lembrar(p_qual text)
returns int language plpgsql volatile security definer set search_path to 'public'
as $f$
declare f record; n int := 0; para jsonb;
begin
  for f in select * from relatorios_semana_folhas
            where semana >= current_date - 21 and enviado_em is not null
              and ((p_qual = 'assinar' and assinado_em is null) or (p_qual = 'receber' and assinado_em is not null and recebido_em is null)) loop
    if p_qual = 'assinar' then
      select coalesce(jsonb_agg(e->>'id'), '[]'::jsonb) into para
        from shared_state s, jsonb_array_elements(s.team) e, relatorios_destinos d
       where s.id = 1 and d.area = f.area and lower(e->>'email') = any (select lower(x) from unnest(coalesce(d.para, '{}')) x);
      if para = '[]'::jsonb then para := '["u14"]'::jsonb; end if;
    else
      para := '["u14"]'::jsonb;
    end if;
    perform bsp_push_post(jsonb_build_object('para', para,
      'titulo', case when p_qual = 'assinar' then 'Folha semanal por assinar' else 'Folha semanal por receber' end,
      'corpo', 'Relatórios de ' || f.area || ', semana de ' || to_char(f.semana, 'DD-MM') ||
               case when p_qual = 'assinar' then ': imprima, assine e remeta ao Director Clínico.' else ': confirme a recepção no Workspace.' end,
      'url', '#/relatorios', 'tag', 'folha-' || f.area || '-' || f.semana));
    n := n + 1;
  end loop;
  return n;
end $f$;
revoke all on function public.bsp_rel_semana_lembrar(text) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'bsp-folhas-assinar') then perform cron.unschedule('bsp-folhas-assinar'); end if;
  if exists (select 1 from cron.job where jobname = 'bsp-folhas-receber') then perform cron.unschedule('bsp-folhas-receber'); end if;
  perform cron.schedule('bsp-folhas-assinar', '43 8 * * 3', $c$select public.bsp_rel_semana_lembrar('assinar')$c$);  -- quarta 09h43
  perform cron.schedule('bsp-folhas-receber', '43 8 * * 5', $c$select public.bsp_rel_semana_lembrar('receber')$c$);  -- sexta 09h43
end $$;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'bsp-relatorios-semana') then
    perform cron.unschedule('bsp-relatorios-semana');
  end if;
  perform cron.schedule(
    'bsp-relatorios-semana',
    '38 6 * * 1',   -- segunda-feira, 07h38 em Luanda (UTC+1)
    $cmd$
    select net.http_post(
      url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/relatorios-semana',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                         where name = 'bsp_resumo_agendamento' limit 1)),
      body    := '{}'::jsonb,
      timeout_milliseconds := 120000
    );
    $cmd$
  );
end $$;

select jobname, schedule from cron.job where jobname = 'bsp-relatorios-semana';
