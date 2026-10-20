-- 2FA: sessões gémeas (20-10-2026, Elmar: «Os documentos todos desapareceram…
-- eu abro e está vazio»).
-- No iPhone, a entrada saía duas vezes no mesmo segundo (preenchimento
-- automático + envio do formulário): duas sessões. O código do e-mail ficava
-- numa e o Workspace usava a outra (aal1, sem registo em mfa_email_sessoes):
-- as regras RESTRICTIVE (bsp_mfa_aal2) devolviam listas vazias em tudo.
-- Confirmado nas sessões do Elmar de 19-10 18h05, 20-10 10h13 e 10h59: pares
-- criados no mesmo segundo, só um verificado.
-- Correcção: a sessão vale como verificada se outra sessão do mesmo utilizador,
-- criada até 10 s antes ou depois, foi verificada por e-mail. No ecrã, a
-- entrada passa a ignorar um segundo envio (LoginScreen, aEntrar).

create or replace function public.bsp_mfa_ok()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
      or exists (select 1 from public.mfa_email_sessoes s
                  where s.sessao = public.bsp_mfa_sessao() and s.user_id = auth.uid()
                    and s.verificado_em > now() - interval '30 days')
      or exists (select 1
                   from auth.sessions eu
                   join auth.sessions gemea on gemea.user_id = eu.user_id and gemea.id <> eu.id
                    and gemea.created_at between eu.created_at - interval '10 seconds' and eu.created_at + interval '10 seconds'
                   join public.mfa_email_sessoes s on s.sessao = gemea.id and s.user_id = eu.user_id
                  where eu.id = public.bsp_mfa_sessao() and eu.user_id = auth.uid()
                    and s.verificado_em > now() - interval '30 days')
$function$;
