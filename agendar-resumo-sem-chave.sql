-- ============================================================
--  Barispol Workspace · agendar o resumo matinal SEM chave secreta
--
--  Substitui o agendar-resumo.sql. Nao ha nada para colar: a propria
--  base de dados gera um codigo aleatorio e guarda-o no cofre (Vault).
--  O agendamento vai busca-lo ao cofre no momento em que corre e
--  envia-o no cabecalho x-bsp-agendamento. A funcao resumo-matinal
--  confirma-o pela bsp_resumo_codigo_confere, que so a chave do
--  servidor pode chamar.
--
--  O codigo nunca aparece num resultado, nem no texto do agendamento,
--  nem no repositorio. Serve so para mandar correr o resumo: nao le nem
--  apaga nada na base de dados.
--
--  Pode correr-se mais do que uma vez. Para trocar o codigo, apagar o
--  segredo bsp_resumo_agendamento em Vault e correr outra vez.
--
--  Aplicado no servidor em 24-09-2026.
-- ============================================================

create table if not exists resumos_enviados (
  dia date primary key,
  criado_em timestamptz default now()
);
alter table resumos_enviados enable row level security;

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 1. O codigo, gerado aqui dentro e guardado no cofre.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'bsp_resumo_agendamento') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'bsp_resumo_agendamento',
      'Codigo do agendamento do resumo matinal'
    );
  end if;
end $$;

-- 2. A conferencia. Devolve so verdadeiro ou falso.
create or replace function public.bsp_resumo_codigo_confere(codigo text)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select coalesce(length(codigo) >= 32 and codigo = (
    select decrypted_secret from vault.decrypted_secrets
    where name = 'bsp_resumo_agendamento' limit 1
  ), false);
$$;
revoke all on function public.bsp_resumo_codigo_confere(text) from public, anon, authenticated;
grant execute on function public.bsp_resumo_codigo_confere(text) to service_role;

-- 3. O agendamento, com o endereco certo. Substitui o que tinha
--    <PROJECTO> por preencher.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'bsp-resumo-matinal') then
    perform cron.unschedule('bsp-resumo-matinal');
  end if;
  perform cron.schedule(
    'bsp-resumo-matinal',
    '30 5 * * 1-6',   -- 06h30 em Luanda (UTC+1), de segunda a sabado
    $cmd$
    select net.http_post(
      url     := 'https://ferqkmfntcockmhviscf.supabase.co/functions/v1/resumo-matinal',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                         where name = 'bsp_resumo_agendamento' limit 1)),
      body    := '{}'::jsonb
    );
    $cmd$
  );
end $$;

-- ============================================================
--  CONFERIR
-- ============================================================
select jobname   as tarefa,
       schedule  as quando,
       active    as activa,
       substring(command from 'https://[^'']+') as para_onde
from cron.job
where jobname = 'bsp-resumo-matinal';

-- Amanha de manha:
-- select status, return_message, start_time
-- from cron.job_run_details
-- where jobid = (select jobid from cron.job where jobname = 'bsp-resumo-matinal')
-- order by start_time desc limit 5;
--
-- E a resposta da funcao (o numero de e-mails e as falhas):
-- select status_code, content, created from net._http_response
-- order by created desc limit 5;

-- PARAR (sem desinstalar nada):
-- select cron.unschedule('bsp-resumo-matinal');
