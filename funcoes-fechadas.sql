-- Barispol Workspace · funções internas fechadas a quem chama de fora
-- Fiscalização de 01-10-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- bsp_wa_linhas e bsp_entradas_rececao montam o texto dos e-mails do WhatsApp
-- (wa_resumo_8h, wa_alerta_16h), que correm no cron como dono. Estavam
-- abertas a qualquer um com a chave publicável: a primeira devolvia nomes e
-- telefones de quem escreveu ao WhatsApp; a segunda, a hora de entrada da
-- Recepção. Só o dono (postgres) as chama.
revoke all on function public.bsp_wa_linhas(timestamptz, timestamptz, boolean) from public, anon, authenticated;
revoke all on function public.bsp_entradas_rececao(date) from public, anon, authenticated;

-- Fiscalização, passo B (Elmar, 01-10-2026: «apaga», «tira o acesso»):
-- 1. Restos da migração. As funções _mig_* (mudavam palavras-passe, a chave
--    da Resend e ficheiros) ficam sem execução para todos, incluindo a chave
--    de serviço. As Edge Functions mig-recebe e bsp-crm-patch passaram a uma
--    versão que recusa tudo (410, com verificação de JWT); apagar no painel.
revoke all on function public._mig_set_resend(text) from public, anon, authenticated, service_role;
revoke all on function public._mig_token_ok(text) from public, anon, authenticated, service_role;
revoke all on function public._mig_load(regclass, jsonb) from public, anon, authenticated, service_role;
revoke all on function public._mig_set_pw(jsonb) from public, anon, authenticated, service_role;

-- 3. Nenhuma função bsp_* com privilégios (security definer) fica aberta a
--    visitantes sem sessão. Quem tem sessão e a chave de serviço continuam.
--    Nenhuma regra de acesso de visitantes as usa (verificado); os gatilhos
--    não dependem deste direito. Correr de novo depois de criar funções novas.
do $$ declare r record; begin
for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'execute') and p.proname like 'bsp\_%'
loop
  execute format('grant execute on function %s to authenticated, service_role', r.sig);
  execute format('revoke execute on function %s from public, anon', r.sig);
end loop; end $$;
