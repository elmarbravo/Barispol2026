-- Barispol Workspace · resumo pessoal da manhã (02-10-2026)
-- O cron bsp-resumo-matinal (06h30 de Luanda, segunda a sábado) passa a
-- chamar a Edge Function resumo-pessoal, que junta as tarefas privadas
-- (tarefas_pessoais, também as partilhadas) às do quadro da equipa e à
-- agenda. A resumo-matinal continua com os outros tipos (lembrete,
-- coletivo, mensagens, novidades, marcacoes, transporte).
-- Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs). Pode correr-se mais
-- do que uma vez.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'bsp-resumo-matinal') then perform cron.unschedule('bsp-resumo-matinal'); end if;
  perform cron.schedule('bsp-resumo-matinal', '30 5 * * 1-6', $cmd$
    select net.http_post(
      url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/resumo-pessoal',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                         where name = 'bsp_resumo_agendamento' limit 1)),
      body    := '{}'::jsonb,
      timeout_milliseconds := 60000
    );
  $cmd$);
end $$;
