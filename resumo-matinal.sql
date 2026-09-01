-- Barispol Workspace · agendar o resumo matinal
-- Correr UMA vez no SQL Editor, DEPOIS de instalar a funcao
-- resumo-matinal nas Edge Functions.
--
-- PORQUE: havia um botao em Admin -> Sistema que enviava os lembretes, e
-- alguem tinha de se lembrar de lhe carregar. Um lembrete de que e preciso
-- lembrar-se nao e um lembrete nenhum.
--
-- A HORA: Angola e UTC+1 e nao muda ao longo do ano. As 6h30 de Luanda
-- sao as 5h30 em UTC, que e a hora em que o agendamento trabalha.

-- 1. Para nao sair o mesmo e-mail duas vezes no mesmo dia. O agendamento
--    pode disparar mais do que uma vez — por uma repeticao, por uma
--    reinstalacao — e ninguem quer o mesmo aviso tres vezes antes do cafe.
create table if not exists resumos_enviados (
  dia date primary key,
  criado_em timestamptz default now()
);
alter table resumos_enviados enable row level security;
-- Ninguem precisa de lhe tocar do navegador: quem escreve aqui e a funcao,
-- com a chave service_role, que passa por cima das regras. Sem politica
-- nenhuma, do lado do navegador esta fechada.

-- 2. As extensoes do agendamento.
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 3. O agendamento.
--
--    ATENCAO: as duas linhas abaixo tem de ser preenchidas a mao, porque
--    so o administrador do projecto as conhece:
--
--      <PROJECTO>  o endereco do projecto, sem a barra final
--                  (Project Settings -> API -> Project URL)
--      <SERVICE>   a chave service_role
--                  (Project Settings -> API -> service_role)
--
--    A chave service_role NUNCA sai do Supabase: fica aqui dentro, na
--    base de dados, e nao no site nem no repositorio.

select cron.unschedule('bsp-resumo-matinal')
where exists (select 1 from cron.job where jobname = 'bsp-resumo-matinal');

select cron.schedule(
  'bsp-resumo-matinal',
  '30 5 * * 1-6',   -- 06h30 em Luanda, de segunda a sabado
  $$
  select net.http_post(
    url     := '<PROJECTO>/functions/v1/resumo-matinal',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'Authorization', 'Bearer <SERVICE>'),
    body    := '{}'::jsonb
  );
  $$
);

-- 4. Conferir que ficou agendado.
select jobname as tarefa, schedule as quando, active as activa
from cron.job
where jobname = 'bsp-resumo-matinal';

-- Depois da primeira manha, ver se correu:
--
-- select status, return_message, start_time
-- from cron.job_run_details
-- where jobname = 'bsp-resumo-matinal'
-- order by start_time desc limit 5;
--
-- E que dias ja tiveram resumo:
-- select * from resumos_enviados order by dia desc limit 10;

-- PARAR (sem desinstalar nada):
-- select cron.unschedule('bsp-resumo-matinal');
