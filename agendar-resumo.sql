-- ============================================================
--  Barispol Workspace · agendar o resumo matinal
--
--  SO HA UMA COISA PARA MUDAR NESTE FICHEIRO: a linha 22.
--  Todo o resto fica como esta.
--
--  ONDE ARRANJAR A CHAVE:
--    No Supabase, barra da esquerda -> Project Settings -> API
--    -> "Project API keys" -> a linha service_role -> Reveal -> copiar.
--
--  Essa chave contorna todas as regras da base de dados. Fica guardada
--  DENTRO do proprio Supabase, nesta tarefa agendada, e nunca no site
--  nem no repositorio. Nao a envie por mensagem a ninguem.
-- ============================================================

-- Para nao sair o mesmo e-mail duas vezes no mesmo dia. O agendamento
-- pode disparar mais do que uma vez, e ninguem quer o mesmo aviso tres
-- vezes antes do cafe.
create table if not exists resumos_enviados (
  dia date primary key,
  criado_em timestamptz default now()
);
alter table resumos_enviados enable row level security;
-- Sem politica nenhuma: quem escreve aqui e a funcao, com a chave do
-- servidor, que passa por cima das regras. Do lado do navegador fica
-- fechada, que e como deve ser.

create extension if not exists pg_cron;
create extension if not exists pg_net;

do $$
declare
  -- ↓↓↓ COLE A CHAVE service_role AQUI, ENTRE AS ASPAS ↓↓↓
  chave text := 'COLE_AQUI';
  -- ↑↑↑ e mais nada ↑↑↑
  projecto text := 'https://ferqkmfntcockmhviscf.supabase.co';
begin
  -- Travao: mais vale parar aqui do que ficar com um agendamento activo
  -- que falha todas as manhas em silencio. Foi o que aconteceu da
  -- primeira vez.
  if chave = 'COLE_AQUI' or length(chave) < 40 then
    raise exception
      'Falta colar a chave service_role na linha 22. Encontra-a em Project Settings -> API -> service_role -> Reveal.';
  end if;
  if chave not like 'eyJ%' then
    raise exception
      'Isso nao parece a chave service_role: ela comeca por "eyJ". Confirme que nao copiou a anon public nem a palavra-passe da base de dados.';
  end if;

  if exists (select 1 from cron.job where jobname = 'bsp-resumo-matinal') then
    perform cron.unschedule('bsp-resumo-matinal');
  end if;

  perform cron.schedule(
    'bsp-resumo-matinal',
    '30 5 * * 1-6',   -- 06h30 em Luanda (UTC+1), de segunda a sabado
    format(
      $cmd$
      select net.http_post(
        url     := %L,
        headers := jsonb_build_object(
                     'Content-Type', 'application/json',
                     'Authorization', %L),
        body    := '{}'::jsonb
      );
      $cmd$,
      projecto || '/functions/v1/resumo-matinal',
      'Bearer ' || chave
    )
  );
end $$;

-- ============================================================
--  CONFERIR
-- ============================================================
-- 1. Ficou agendado, e o endereco esta preenchido?
--    Na coluna "para_onde" tem de aparecer o endereco do projecto.
--    Se aparecer <PROJECTO>, alguma coisa correu mal.
select jobname   as tarefa,
       schedule  as quando,
       active    as activa,
       substring(command from 'https://[^'']+') as para_onde
from cron.job
where jobname = 'bsp-resumo-matinal';

-- 2. Amanha de manha, ver se correu:
--
-- select status, return_message, start_time
-- from cron.job_run_details
-- where jobname = 'bsp-resumo-matinal'
-- order by start_time desc limit 5;
--
--    "succeeded" quer dizer que o pedido saiu. Para ver se os e-mails
--    sairam mesmo, o mais rapido e o botao em Admin -> Sistema.

-- PARAR (sem desinstalar nada):
-- select cron.unschedule('bsp-resumo-matinal');
