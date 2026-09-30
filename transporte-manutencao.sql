-- Barispol Workspace · manutenção da viatura e relatório semanal ao motorista
-- Pedido do Elmar, 30-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
-- Precisa do transporte.sql.
--
-- Manutenção: orçamentos e trabalhos feitos na viatura (valor, oficina, km,
-- fotografia do orçamento ou da factura, próxima revisão). Mesmo acesso que
-- o resto do transporte: a gestão e quem tem o cargo de motorista; só a
-- gestão apaga.
--
-- Relatório semanal: segunda-feira às 07h45 em Luanda (06h45 UTC), tipo
-- «transporte» da resumo-matinal. Vai para o motorista, com a Administração
-- em cópia, e pede-lhe a informação da viatura. Um envio por semana
-- (transporte_semana_enviados).

create table if not exists public.transporte_manutencoes (
  id bigint generated always as identity primary key,
  data date not null default current_date,
  estado text not null default 'orcamento' check (estado in ('orcamento', 'aprovada', 'feita')),
  km integer check (km is null or km >= 0),
  descricao text not null default '',
  valor numeric(12, 2) not null default 0 check (valor >= 0),
  oficina text not null default '',
  foto text,
  proxima_km integer check (proxima_km is null or proxima_km >= 0),
  proxima_data date,
  nota text not null default '',
  aprovada_por text,
  criado_por text,
  criado_em timestamptz not null default now(),
  alterado_em timestamptz not null default now()
);
create index if not exists transporte_manutencoes_data on public.transporte_manutencoes (data);

create or replace function public.bsp_transporte_carimbo()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if tg_table_name = 'transporte_viagens' then
    new.alterado_em := now();
    if tg_op = 'INSERT' then
      new.criado_por := coalesce(public.bsp_meu_id(), new.criado_por);
      new.motorista := coalesce(new.motorista, public.bsp_meu_id());
    end if;
  elsif tg_table_name = 'transporte_abastecimentos' then
    if tg_op = 'INSERT' then new.criado_por := coalesce(public.bsp_meu_id(), new.criado_por); end if;
  elsif tg_table_name = 'transporte_manutencoes' then
    new.alterado_em := now();
    if tg_op = 'INSERT' then
      new.criado_por := coalesce(public.bsp_meu_id(), new.criado_por);
      new.aprovada_por := null;
    end if;
    /* Aprovar um orçamento é da gestão. */
    if new.estado = 'aprovada' and (tg_op = 'INSERT' or old.estado <> 'aprovada') then
      if not public.bsp_e_gestor() and public.bsp_meu_id() is not null then
        raise exception 'Só a gestão aprova um orçamento.';
      end if;
      new.aprovada_por := coalesce(public.bsp_meu_id(), new.aprovada_por);
    end if;
  else
    new.alterado_em := now();
  end if;
  return new;
end $function$;

drop trigger if exists bsp_transporte_manut_carimbo on public.transporte_manutencoes;
create trigger bsp_transporte_manut_carimbo before insert or update on public.transporte_manutencoes
  for each row execute function public.bsp_transporte_carimbo();

alter table public.transporte_manutencoes enable row level security;
drop policy if exists transporte_manutencoes_ler on public.transporte_manutencoes;
drop policy if exists transporte_manutencoes_criar on public.transporte_manutencoes;
drop policy if exists transporte_manutencoes_mudar on public.transporte_manutencoes;
drop policy if exists transporte_manutencoes_apagar on public.transporte_manutencoes;
create policy transporte_manutencoes_ler on public.transporte_manutencoes for select to authenticated using (public.bsp_ve_transporte());
create policy transporte_manutencoes_criar on public.transporte_manutencoes for insert to authenticated with check (public.bsp_ve_transporte());
create policy transporte_manutencoes_mudar on public.transporte_manutencoes for update to authenticated using (public.bsp_ve_transporte()) with check (public.bsp_ve_transporte());
create policy transporte_manutencoes_apagar on public.transporte_manutencoes for delete to authenticated using (public.bsp_e_gestor());

-- Um relatório semanal por semana (segunda-feira da semana a que respeita).
create table if not exists public.transporte_semana_enviados (
  semana date primary key,
  enviado_em timestamptz not null default now(),
  para text,
  ok boolean
);
alter table public.transporte_semana_enviados enable row level security;
revoke all on public.transporte_semana_enviados from anon, authenticated;

do $$
declare
  comando text := $cmd$
    select net.http_post(
      url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/resumo-matinal',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                         where name = 'bsp_resumo_agendamento' limit 1)),
      body    := '{"tipo":"transporte"}'::jsonb
    );
  $cmd$;
begin
  if exists (select 1 from cron.job where jobname = 'bsp-transporte-semana') then
    perform cron.unschedule('bsp-transporte-semana');
  end if;
  perform cron.schedule('bsp-transporte-semana', '45 6 * * 1', comando);
end $$;

notify pgrst, 'reload schema';
