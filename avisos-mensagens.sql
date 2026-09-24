-- Barispol Workspace · aviso por e-mail das mensagens directas
-- Pedido do Elmar, 24-09-2026. Aplicado no servidor no mesmo dia.
-- Pode correr-se mais do que uma vez.
--
-- O e-mail de uma mensagem directa deixou de sair logo. So sai se a
-- mensagem ficar 5 minutos sem resposta nem leitura E quem a recebeu
-- estiver offline. Quem decide e a funcao resumo-matinal (tipo
-- "mensagens"), chamada a cada minuto por este agendamento.

-- 1. Presenca: o Workspace aberto e a vista regista "estou aqui" a cada
--    minuto. Sem sinal ha mais de 2 minutos, a pessoa esta offline.
create table if not exists presenca (
  user_id  text primary key,
  visto_em timestamptz not null default now()
);
alter table presenca enable row level security;
drop policy if exists "bsp_pres_ler"   on presenca;
drop policy if exists "bsp_pres_criar" on presenca;
drop policy if exists "bsp_pres_mudar" on presenca;
create policy "bsp_pres_ler" on presenca for select to authenticated using (true);
create policy "bsp_pres_criar" on presenca for insert to authenticated with check (user_id = bsp_meu_id());
create policy "bsp_pres_mudar" on presenca for update to authenticated
  using (user_id = bsp_meu_id()) with check (user_id = bsp_meu_id());

-- 2. O que ja foi visto pela funcao: avisado (enviado = true) ou sem
--    necessidade de aviso (false). Sem regras: so a funcao, com a chave
--    do servidor, le e escreve.
create table if not exists avisos_mensagens (
  msg_id    bigint primary key,
  enviado   boolean not null default false,
  criado_em timestamptz not null default now()
);
alter table avisos_mensagens enable row level security;

-- As mensagens que ja existiam ficam marcadas: o e-mail delas ja tinha
-- saido na altura (o Workspace enviava logo). Nada de avisos atrasados.
insert into avisos_mensagens (msg_id, enviado)
select id, false from messages where conv_key like 'dm-%'
on conflict (msg_id) do nothing;

notify pgrst, 'reload schema';

-- 3. O agendamento: a cada minuto.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'bsp-avisos-mensagens') then
    perform cron.unschedule('bsp-avisos-mensagens');
  end if;
  perform cron.schedule('bsp-avisos-mensagens', '* * * * *', $cmd$
    select net.http_post(
      url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/resumo-matinal',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                         where name = 'bsp_resumo_agendamento' limit 1)),
      body    := '{"tipo":"mensagens"}'::jsonb
    );
  $cmd$);
end $$;

-- Limpeza semanal das respostas guardadas pelo pg_net e do registo do
-- pg_cron: a cada minuto acumulam-se linhas.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'bsp-limpeza-registos') then
    perform cron.unschedule('bsp-limpeza-registos');
  end if;
  perform cron.schedule('bsp-limpeza-registos', '0 3 * * 0', $cmd$
    delete from cron.job_run_details where end_time < now() - interval '7 days';
    delete from avisos_mensagens where criado_em < now() - interval '30 days';
  $cmd$);
end $$;

-- CONFERIR
select jobname, schedule, active from cron.job where jobname like 'bsp-%' order by 1;
