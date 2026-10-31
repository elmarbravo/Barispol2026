-- Relatórios da semana para imprimir (31-10-2026, Elmar: «Os relatórios todos
-- quero que sejam impressos todas as semanas nas segundas-feiras, um lembrete
-- com anexo para cada chefe de área e director clínico»).
--
-- À segunda-feira, às 07h38 de Luanda (06h38 UTC; minuto livre, longe das
-- cargas das 07h15, 07h20 e 07h30), o cron bsp-relatorios-semana chama a Edge
-- Function relatorios-semana (funcoes/relatorios-semana), que junta os
-- relatórios de turno da semana anterior (segunda a domingo) e manda:
--   · a cada chefe de área (relatorios_destinos.para) o PDF da sua área;
--   · à Direcção Clínica (DireccaoClinica@barispol.com) o PDF de todas as áreas.
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
