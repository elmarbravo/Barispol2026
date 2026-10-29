-- Lembrar o aparelho também com o código da app (29-10-2026, Elmar: «A equipa
-- está descontente»; «Por omissão e aviso»). Até aqui só o código por e-mail
-- tinha a caixa «Lembrar este aparelho durante 30 dias»; quem usa a app de
-- autenticação escrevia a palavra-passe e o código sempre que o separador
-- fechava. Esta função dá a lembrança de 30 dias (mfa_aparelhos), só a uma
-- sessão que já passou o código da app (aal2).

create or replace function public.bsp_mfa_app_lembrar()
returns text language plpgsql volatile security definer set search_path to 'public', 'extensions'
as $f$
declare uid uuid := auth.uid(); tok text;
begin
  if uid is null or coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then return null; end if;
  tok := encode(extensions.gen_random_bytes(24), 'hex');
  insert into public.mfa_aparelhos (token_hash, user_id, ate) values (public.bsp_mfa_hash(tok), uid, now() + interval '30 days');
  return tok;
end $f$;
revoke all on function public.bsp_mfa_app_lembrar() from public, anon;
grant execute on function public.bsp_mfa_app_lembrar() to authenticated;
