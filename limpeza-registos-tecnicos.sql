-- Limpeza dos registos técnicos (30-10-2026, Elmar: «pode apagar os técnicos que
-- sugere»). Só registos de funcionamento, nunca dados da clínica.
-- Já existiam: cron.job_run_details (7 dias) e avisos_mensagens (30 dias) no
-- cron bsp-limpeza-registos; erp.sync_log (30 dias) no bsp-painel-limpeza.
-- Faltava o registo da sincronização do WhatsApp (whatsapp.sync_log), que
-- crescia sem fim. Apagado o que tinha mais de 30 dias (2779 linhas, mais 1345
-- do erp.sync_log) e acrescentado à limpeza de domingo às 03h00 UTC.
select cron.alter_job((select jobid from cron.job where jobname = 'bsp-limpeza-registos'), command := $c$
    delete from cron.job_run_details where end_time < now() - interval '7 days';
    delete from avisos_mensagens where criado_em < now() - interval '30 days';
    delete from whatsapp.sync_log where coalesce(fim, inicio) < now() - interval '30 days';
  $c$);
