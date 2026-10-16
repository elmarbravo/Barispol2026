-- Segundo passo por e-mail (16-10-2026, Elmar: «Dois factores por e-mail ou
-- app. As duas opções valem»). O Supabase Auth só faz 2FA por app (TOTP) ou
-- SMS; o código por e-mail é nosso:
--   bsp_mfa_email_enviar()            código de 6 algarismos (10 min) para o
--                                     e-mail da conta (auth.users), por
--                                     bsp_enviar_email; até 5 por hora.
--   bsp_mfa_email_verificar(c, lembrar) confirma (até 5 tentativas por código)
--                                     e marca a sessão (session_id do JWT); com
--                                     «lembrar», devolve um testemunho do
--                                     aparelho válido 12 h (só o hash fica aqui).
--   bsp_mfa_email_retomar(token)      sessão nova num aparelho lembrado.
--   bsp_mfa_ok()                      aal2 (app) ou sessão confirmada por e-mail.
-- Tabelas sem regras de acesso: só as funções lá chegam.
-- Corre-se antes de mfa-obrigatoria.sql. Sem «drop» nem «truncate».
-- POR APLICAR (o conector do Supabase estava noutra conta a 16-10-2026).

create table if not exists public.mfa_email_codigos (
  id bigserial primary key,
  user_id uuid not null,
  sessao uuid not null,
  codigo_hash text not null,
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null,
  tentativas int not null default 0,
  usado_em timestamptz
);
create table if not exists public.mfa_email_sessoes (
  sessao uuid primary key,
  user_id uuid not null,
  verificado_em timestamptz not null default now(),
  via text not null default 'email'
);
create table if not exists public.mfa_aparelhos (
  token_hash text primary key,
  user_id uuid not null,
  ate timestamptz not null,
  criado_em timestamptz not null default now()
);
alter table public.mfa_email_codigos enable row level security;
alter table public.mfa_email_sessoes enable row level security;
alter table public.mfa_aparelhos enable row level security;
revoke all on public.mfa_email_codigos, public.mfa_email_sessoes, public.mfa_aparelhos from anon, authenticated;

create or replace function public.bsp_mfa_hash(t text)
returns text language sql immutable set search_path to 'public', 'extensions'
as $f$ select encode(extensions.digest(t, 'sha256'), 'hex') $f$;
revoke all on function public.bsp_mfa_hash(text) from public, anon, authenticated;

create or replace function public.bsp_mfa_sessao()
returns uuid language sql stable set search_path to 'public'
as $f$ select nullif(auth.jwt() ->> 'session_id', '')::uuid $f$;

create or replace function public.bsp_mfa_ok()
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
      or exists (select 1 from public.mfa_email_sessoes s
                  where s.sessao = public.bsp_mfa_sessao() and s.user_id = auth.uid()
                    and s.verificado_em > now() - interval '24 hours')
$f$;
revoke all on function public.bsp_mfa_ok() from public, anon;
grant execute on function public.bsp_mfa_ok() to authenticated;

create or replace function public.bsp_mfa_email_enviar()
returns jsonb language plpgsql volatile security definer set search_path to 'public', 'extensions'
as $f$
declare
  uid uuid := auth.uid();
  ses uuid := public.bsp_mfa_sessao();
  para text;
  cod text;
begin
  if uid is null or ses is null then raise exception 'Sem sessão.'; end if;
  if (select count(*) from public.mfa_email_codigos where user_id = uid and criado_em > now() - interval '1 hour') >= 5 then
    raise exception 'Já pediu 5 códigos na última hora. Espere um pouco ou use a app de autenticação.';
  end if;
  select email into para from auth.users where id = uid;
  if coalesce(para, '') = '' then raise exception 'A conta não tem e-mail.'; end if;
  cod := lpad(((('x' || encode(extensions.gen_random_bytes(4), 'hex'))::bit(32)::bigint) % 1000000)::text, 6, '0');
  insert into public.mfa_email_codigos (user_id, sessao, codigo_hash, expira_em)
  values (uid, ses, public.bsp_mfa_hash(uid::text || ':' || cod), now() + interval '10 minutes');
  perform public.bsp_enviar_email(array[para], '{}'::text[], '{}'::text[],
    'Código de entrada no Workspace Barispol',
    public.bsp_envelope('Código de entrada',
      '<p style="margin:0 0 12px">Para entrar no Workspace, escreva este código:</p>'
      || '<p style="margin:0 0 16px;font-size:28px;font-weight:700;letter-spacing:8px">' || cod || '</p>'
      || '<p style="margin:0 0 12px">Vale 10 minutos. Se não foi a pessoa que tentou entrar, mude já a palavra-passe e avise a Direcção.</p>'));
  return jsonb_build_object('ok', true, 'para', regexp_replace(para, '^(.).*(@.*)$', '\1***\2'));
end $f$;
revoke all on function public.bsp_mfa_email_enviar() from public, anon;
grant execute on function public.bsp_mfa_email_enviar() to authenticated;

create or replace function public.bsp_mfa_email_verificar(p_codigo text, p_lembrar boolean default false)
returns jsonb language plpgsql volatile security definer set search_path to 'public', 'extensions'
as $f$
declare
  uid uuid := auth.uid();
  ses uuid := public.bsp_mfa_sessao();
  c public.mfa_email_codigos;
  tok text;
begin
  if uid is null or ses is null then return jsonb_build_object('ok', false, 'erro', 'Sem sessão.'); end if;
  select * into c from public.mfa_email_codigos
   where user_id = uid and sessao = ses and usado_em is null and expira_em > now()
   order by criado_em desc limit 1 for update;
  if c.id is null then return jsonb_build_object('ok', false, 'erro', 'O código caducou. Peça outro.'); end if;
  if c.tentativas >= 5 then return jsonb_build_object('ok', false, 'erro', 'Demasiadas tentativas. Peça outro código.'); end if;
  update public.mfa_email_codigos set tentativas = tentativas + 1 where id = c.id;
  if c.codigo_hash <> public.bsp_mfa_hash(uid::text || ':' || regexp_replace(coalesce(p_codigo, ''), '\D', '', 'g')) then
    return jsonb_build_object('ok', false, 'erro', 'Código errado.');
  end if;
  update public.mfa_email_codigos set usado_em = now() where id = c.id;
  insert into public.mfa_email_sessoes (sessao, user_id) values (ses, uid)
  on conflict (sessao) do update set verificado_em = now(), user_id = excluded.user_id;
  if coalesce(p_lembrar, false) then
    tok := encode(extensions.gen_random_bytes(24), 'hex');
    insert into public.mfa_aparelhos (token_hash, user_id, ate) values (public.bsp_mfa_hash(tok), uid, now() + interval '12 hours');
  end if;
  return jsonb_build_object('ok', true, 'token', tok);
end $f$;
revoke all on function public.bsp_mfa_email_verificar(text, boolean) from public, anon;
grant execute on function public.bsp_mfa_email_verificar(text, boolean) to authenticated;

create or replace function public.bsp_mfa_email_retomar(p_token text)
returns boolean language plpgsql volatile security definer set search_path to 'public', 'extensions'
as $f$
declare uid uuid := auth.uid(); ses uuid := public.bsp_mfa_sessao();
begin
  if uid is null or ses is null or coalesce(p_token, '') = '' then return false; end if;
  if not exists (select 1 from public.mfa_aparelhos where token_hash = public.bsp_mfa_hash(p_token) and user_id = uid and ate > now()) then
    return false;
  end if;
  insert into public.mfa_email_sessoes (sessao, user_id, via) values (ses, uid, 'aparelho')
  on conflict (sessao) do update set verificado_em = now(), user_id = excluded.user_id, via = 'aparelho';
  return true;
end $f$;
revoke all on function public.bsp_mfa_email_retomar(text) from public, anon;
grant execute on function public.bsp_mfa_email_retomar(text) to authenticated;

-- Limpeza: acrescentar à lista «regras» da bsp_retencao (retencao-copias.sql):
-- mfa_email_codigos (1 dia), mfa_email_sessoes (2 dias), mfa_aparelhos (1 dia
-- depois de «ate»). Cada código conta nos 95 e-mails por dia da Resend.

notify pgrst, 'reload schema';
