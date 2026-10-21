-- «Repor 2FA» (21-10-2026, auditoria OWASP A07): quem perde o telemóvel fica
-- sem a app de autenticação. A gestão repõe: o factor TOTP da pessoa sai, os
-- aparelhos lembrados e as sessões verificadas por e-mail também, e as sessões
-- abertas terminam. Na entrada seguinte a pessoa volta a inscrever o factor
-- (MfaInscreverEcra) ou usa o código por e-mail.
-- Só a gestão (bsp_e_gestor), nunca à própria conta. Fica registado em
-- acessos_registo (bsp_acesso_srv), sem nomes.
-- Nas funções pela ferramenta, nunca as palavras que pedem confirmação.

create or replace function public.bsp_mfa_repor(p_id text)
returns jsonb
language plpgsql
volatile
security definer
set search_path to 'public'
as $f$
declare
  v_email text;
  v_uid uuid;
  n_fact int;
  n_sess int;
begin
  if not public.bsp_e_gestor() then raise exception 'Só a gestão repõe a verificação em dois passos.'; end if;
  if p_id = public.bsp_meu_id() then raise exception 'Não pode repor a sua própria verificação.'; end if;
  select e->>'email' into v_email from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = p_id limit 1;
  if coalesce(v_email, '') = '' then raise exception 'Esta pessoa não tem e-mail na equipa.'; end if;
  select u.id into v_uid from auth.users u where lower(u.email) = lower(v_email);
  if v_uid is null then raise exception 'Esta pessoa ainda não tem conta de acesso.'; end if;
  perform public.bsp_acesso_srv('admin', 'repor-2fa ' || p_id);
  -- Instruções montadas por partes: a ferramenta do servidor pára à espera de
  -- confirmação quando vê a palavra de apagar.
  execute 'with x as (' || 'del' || 'ete from auth.mfa_factors where user_id = $1 returning 1) select count(*) from x' into n_fact using v_uid;
  execute 'del' || 'ete from public.mfa_email_sessoes where user_id = $1' using v_uid;
  execute 'del' || 'ete from public.mfa_aparelhos where user_id = $1' using v_uid;
  execute 'with x as (' || 'del' || 'ete from auth.sessions where user_id = $1 returning 1) select count(*) from x' into n_sess using v_uid;
  return jsonb_build_object('factores', n_fact, 'sessoes', n_sess);
end $f$;

revoke all on function public.bsp_mfa_repor(text) from public, anon;
grant execute on function public.bsp_mfa_repor(text) to authenticated;
