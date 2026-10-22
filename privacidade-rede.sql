-- Política de privacidade assinada no login e uso só na rede da clínica
-- (22-10-2026, Elmar: «no próximo login de cada pessoa mandes a política para
-- eles assinarem e receberem por e-mail» e «além de mim, do Dr. Osvaldo, da
-- Arlete e do Emanuel… mais ninguém pode usar o software fora da instituição»).
--
-- 1. Política: politica_versoes (texto HTML; uma só activa) e politica_aceites
--    (quem, versão, quando, nome escrito como assinatura, IP, aparelho). No ecrã,
--    PoliticaEcra depois da 2FA; bsp_politica_aceitar regista e envia a cópia
--    por e-mail (geral@, assinado pelo sistema).
-- 2. Rede: rede_clinica (IP ou faixa da clínica) e rede_config ('activa',
--    'isentos'). bsp_ip_pedido() lê o IP do pedido (x-forwarded-for);
--    bsp_rede_ok() diz se a sessão pode trabalhar. Entra na regra RESTRICTIVE
--    de todas as tabelas (bsp_sessao_aal2, mfa-obrigatoria.sql) e em
--    bsp_meu_id() (fecha as funções security definer). Sem cabeçalhos (tarefas
--    do servidor, tempo real) não bloqueia. Isentos: u1, u14, u2, u22.
--    Desligado à partida ('activa' = false): liga-se depois de confirmar os IP.
-- Nas funções pela ferramenta, nunca as palavras que pedem confirmação.

create table if not exists public.politica_versoes (
  versao text primary key,
  titulo text not null,
  texto text not null,
  activa boolean not null default false,
  criada_em timestamptz not null default now()
);
create table if not exists public.politica_aceites (
  user_id text not null,
  versao text not null references public.politica_versoes(versao),
  nome_assinado text not null,
  aceite_em timestamptz not null default now(),
  ip text,
  aparelho text,
  email_enviado_em timestamptz,
  primary key (user_id, versao)
);
create table if not exists public.rede_clinica (
  faixa cidr primary key,
  nota text,
  criado_por text,
  criado_em timestamptz not null default now()
);
create table if not exists public.rede_config (
  chave text primary key,
  valor jsonb not null
);
create table if not exists public.rede_bloqueios (
  id bigint generated always as identity primary key,
  user_id text,
  ip text,
  quando timestamptz not null default now()
);
alter table public.politica_versoes enable row level security;
alter table public.politica_aceites enable row level security;
alter table public.rede_clinica enable row level security;
alter table public.rede_config enable row level security;
alter table public.rede_bloqueios enable row level security;
revoke all on public.politica_versoes, public.politica_aceites, public.rede_clinica, public.rede_config, public.rede_bloqueios from anon, authenticated;

insert into public.rede_config (chave, valor) values
  ('activa', 'false'::jsonb),
  ('isentos', '["u1", "u14", "u2", "u22"]'::jsonb)
on conflict (chave) do nothing;

-- IP do pedido (PostgREST põe os cabeçalhos em request.headers).
create or replace function public.bsp_ip_pedido()
returns text language sql stable
as $f$
  select nullif(btrim(split_part(coalesce(
           nullif(current_setting('request.headers', true), '')::json->>'x-forwarded-for',
           nullif(current_setting('request.headers', true), '')::json->>'x-real-ip', ''), ',', 1)), '')
$f$;

-- Quem é (pelo e-mail do testemunho), sem passar por bsp_meu_id().
create or replace function public.bsp_rede_quem()
returns text language sql stable security definer set search_path to 'public'
as $f$
  select e->>'id' from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email', '')) limit 1
$f$;

create or replace function public.bsp_rede_ok()
returns boolean language plpgsql stable security definer set search_path to 'public'
as $f$
declare ip text := public.bsp_ip_pedido(); quem text;
begin
  if coalesce((select valor from rede_config where chave = 'activa'), 'false'::jsonb) <> 'true'::jsonb then return true; end if;
  if ip is null or auth.uid() is null then return true; end if;
  quem := public.bsp_rede_quem();
  if quem is not null and (select valor from rede_config where chave = 'isentos') ? quem then return true; end if;
  begin
    return exists (select 1 from rede_clinica r where ip::inet <<= r.faixa);
  exception when others then return false;
  end;
end $f$;

-- Para o ecrã: estado da entrada (rede e política), uma chamada só.
create or replace function public.bsp_entrada_estado()
returns jsonb language plpgsql volatile security definer set search_path to 'public'
as $f$
declare quem text := public.bsp_rede_quem(); ok boolean := public.bsp_rede_ok(); pol record; res jsonb;
begin
  if auth.uid() is null then raise exception 'Sem sessão.'; end if;
  if not ok then
    insert into rede_bloqueios (user_id, ip) values (quem, public.bsp_ip_pedido());
  end if;
  select * into pol from politica_versoes where activa order by criada_em desc limit 1;
  res := jsonb_build_object('rede_ok', ok, 'ip', public.bsp_ip_pedido(),
    'isento', coalesce((select valor from rede_config where chave = 'isentos') ? quem, false));
  if found and quem is not null and not exists (select 1 from politica_aceites a where a.user_id = quem and a.versao = pol.versao) then
    res := res || jsonb_build_object('politica', jsonb_build_object('versao', pol.versao, 'titulo', pol.titulo, 'texto', pol.texto));
  end if;
  return res;
end $f$;

-- Assinar: regista e manda a cópia por e-mail, assinada pelo sistema.
create or replace function public.bsp_politica_aceitar(p_versao text, p_nome text, p_aparelho text default null)
returns jsonb language plpgsql volatile security definer set search_path to 'public'
as $f$
declare quem text := public.bsp_rede_quem(); pol record; v_email text; v_nome text; corpo text;
begin
  if quem is null then raise exception 'Sem acesso.'; end if;
  select * into pol from politica_versoes where versao = p_versao and activa;
  if not found then raise exception 'Esta versão da política já não está em vigor. Recarregue o Workspace.'; end if;
  if length(btrim(coalesce(p_nome, ''))) < 5 then raise exception 'Escreva o seu nome completo para assinar.'; end if;
  select e->>'email', e->>'name' into v_email, v_nome from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = quem limit 1;
  insert into politica_aceites (user_id, versao, nome_assinado, ip, aparelho)
  values (quem, p_versao, left(btrim(p_nome), 200), public.bsp_ip_pedido(), left(p_aparelho, 300))
  on conflict (user_id, versao) do nothing;
  if coalesce(v_email, '') ~ '@' then
    corpo := '<p style="margin:0 0 14px">' || replace(replace(coalesce(v_nome, ''), '<', '&lt;'), '>', '&gt;') || ', assinou a política de privacidade da equipa no Workspace a '
      || to_char(now() at time zone 'Africa/Luanda', 'DD-MM-YYYY "às" HH24:MI') || ' (versão ' || pol.versao || ', nome escrito: '
      || replace(replace(btrim(p_nome), '<', '&lt;'), '>', '&gt;') || '). Segue o texto para guardar.</p>'
      || '<div style="border-top:1px solid #DDDBD6;padding-top:12px">' || pol.texto || '</div>'
      || '<p style="margin:18px 0 0;color:#4E5366">Sistema · Workspace Barispol</p>';
    perform public.bsp_enviar_email(array[v_email], null, null, 'Política de privacidade da equipa (cópia assinada)',
      public.bsp_envelope('Política de privacidade: a sua cópia', corpo));
    update politica_aceites set email_enviado_em = now() where user_id = quem and versao = p_versao;
  end if;
  return jsonb_build_object('ok', true);
end $f$;

-- Gestão: quem assinou e IPs da clínica.
create or replace function public.bsp_privacidade_resumo()
returns jsonb language plpgsql volatile security definer set search_path to 'public'
as $f$
begin
  if not public.bsp_e_gestor() then raise exception 'Só a gestão.'; end if;
  return jsonb_build_object(
    'versao', (select versao from politica_versoes where activa order by criada_em desc limit 1),
    'aceites', coalesce((select jsonb_agg(jsonb_build_object('user_id', user_id, 'versao', versao, 'aceite_em', aceite_em, 'ip', ip) order by aceite_em) from politica_aceites), '[]'::jsonb),
    'rede_activa', (select valor from rede_config where chave = 'activa'),
    'isentos', (select valor from rede_config where chave = 'isentos'),
    'faixas', coalesce((select jsonb_agg(jsonb_build_object('faixa', faixa::text, 'nota', nota) order by faixa) from rede_clinica), '[]'::jsonb),
    'bloqueios', coalesce((select jsonb_agg(jsonb_build_object('user_id', user_id, 'ip', ip, 'quando', quando) order by quando desc) from (select * from rede_bloqueios order by quando desc limit 30) b), '[]'::jsonb),
    'meu_ip', public.bsp_ip_pedido());
end $f$;

-- Gestão: juntar o IP actual (ou uma faixa) à rede da clínica.
create or replace function public.bsp_rede_juntar(p_faixa text, p_nota text default null)
returns void language plpgsql volatile security definer set search_path to 'public'
as $f$
begin
  if not public.bsp_e_gestor() then raise exception 'Só a gestão.'; end if;
  insert into rede_clinica (faixa, nota, criado_por) values (coalesce(nullif(btrim(p_faixa), ''), public.bsp_ip_pedido())::cidr, p_nota, public.bsp_rede_quem())
  on conflict (faixa) do update set nota = excluded.nota;
end $f$;

revoke all on function public.bsp_ip_pedido(), public.bsp_rede_quem() from public, anon;
revoke all on function public.bsp_rede_ok(), public.bsp_entrada_estado(), public.bsp_politica_aceitar(text, text, text),
  public.bsp_privacidade_resumo(), public.bsp_rede_juntar(text, text) from public, anon;
grant execute on function public.bsp_ip_pedido(), public.bsp_rede_quem(), public.bsp_rede_ok() to authenticated;
grant execute on function public.bsp_entrada_estado(), public.bsp_politica_aceitar(text, text, text),
  public.bsp_privacidade_resumo(), public.bsp_rede_juntar(text, text) to authenticated;

-- Regra de todas as tabelas: 2FA e rede.
create or replace function public.bsp_sessao_aal2()
returns boolean language sql stable security definer set search_path to 'public'
as $function$ select public.bsp_mfa_ok() and public.bsp_rede_ok() $function$;

-- bsp_meu_id() com a rede: fora da rede (e não isento) devolve nulo e todas as
-- funções security definer que dependem dela recusam.
create or replace function public.bsp_meu_id()
returns text language sql stable security definer set search_path to 'public'
as $function$
  select e->>'id'
  from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
  where s.id = 1
    and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email', ''))
    and public.bsp_rede_ok()
  limit 1
$function$;

-- Aplicado a 22-10-2026, desligado. IP da clínica tirado das sessões de 16 a
-- 22-10 (13 pessoas de 6 áreas pelo mesmo IP):
--   insert into rede_clinica (faixa, nota, criado_por) values ('129.122.165.219/32', …, 'sistema');
-- Texto da versão 2 (politica-privacidade-equipa.html) em politica_versoes, activa = false.
-- Ligar: update rede_config set valor = 'true' where chave = 'activa';
--        update politica_versoes set activa = true where versao = '2';
-- Desligar em emergência: update rede_config set valor = 'false' where chave = 'activa';
