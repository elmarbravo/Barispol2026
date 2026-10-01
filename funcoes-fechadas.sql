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
