-- Manutenção preventiva e calibração (03-10-2026, revisão «o que falta»).
--
-- equipamentos: o inventário do que precisa de manutenção (equipamento
-- médico, ar condicionado, gerador, viatura…), com série, fornecedor e
-- garantia.
-- manutencoes_plano: o que se faz a cada equipamento e de quantos em quantos
-- dias (manutenção preventiva, calibração, segurança eléctrica…); a próxima
-- data calcula-se a partir da última.
-- manutencoes_registo: o que se fez, por quem, o custo e o resultado. Um
-- registo ligado a um plano actualiza a última e a próxima data.
-- Avisos (novidades): 14 dias antes, no dia e com 7 dias de atraso, à gestão,
-- aos Serviços Gerais e à área do equipamento.
-- Lê toda a equipa (nada aqui é sensível); registam a gestão, os Serviços
-- Gerais e o Emmanuel (bsp_trata_avarias).

create table if not exists public.equipamentos (
  id bigint generated always as identity primary key,
  nome text not null,
  categoria text not null default 'Equipamento médico',
  area text not null default '',
  local text not null default '',
  marca text not null default '',
  modelo text not null default '',
  numero_serie text not null default '',
  fornecedor text not null default '',
  contacto_fornecedor text not null default '',
  adquirido date,
  garantia_ate date,
  estado text not null default 'Em uso' check (estado in ('Em uso', 'Avariado', 'Fora de serviço', 'Abatido')),
  nota text not null default '',
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now()
);
alter table public.equipamentos enable row level security;

create table if not exists public.manutencoes_plano (
  id bigint generated always as identity primary key,
  equipamento_id bigint not null references public.equipamentos (id) on delete cascade,
  tipo text not null default 'Manutenção preventiva',
  cada_dias int not null check (cada_dias between 1 and 3650),
  ultima date,
  proxima date,
  responsavel text not null default '',
  activo boolean not null default true,
  criado_em timestamptz not null default now()
);
create index if not exists manutencoes_plano_proxima on public.manutencoes_plano (proxima) where activo;
alter table public.manutencoes_plano enable row level security;

create table if not exists public.manutencoes_registo (
  id bigint generated always as identity primary key,
  equipamento_id bigint not null references public.equipamentos (id) on delete cascade,
  plano_id bigint references public.manutencoes_plano (id) on delete set null,
  dia date not null default current_date,
  tipo text not null default 'Manutenção preventiva',
  feito_por text not null default '',
  custo numeric,
  resultado text not null default 'Conforme' check (resultado in ('Conforme', 'Não conforme')),
  nota text not null default '',
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now()
);
create index if not exists manutencoes_registo_eq on public.manutencoes_registo (equipamento_id, dia desc);
alter table public.manutencoes_registo enable row level security;

-- A próxima data: a última mais a periodicidade; num plano novo sem última,
-- a data que se escolheu (ou hoje).
create or replace function public.bsp_plano_proxima()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
begin
  if new.ultima is not null then new.proxima := new.ultima + new.cada_dias;
  elsif new.proxima is null then new.proxima := current_date; end if;
  return new;
end $f$;
drop trigger if exists bsp_plano_proxima on public.manutencoes_plano;
create trigger bsp_plano_proxima before insert or update of ultima, cada_dias on public.manutencoes_plano
  for each row execute function public.bsp_plano_proxima();

create or replace function public.bsp_registo_actualiza_plano()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
begin
  if new.plano_id is not null then
    update public.manutencoes_plano set ultima = greatest(coalesce(ultima, new.dia), new.dia) where id = new.plano_id;
  end if;
  if new.resultado = 'Não conforme' then
    update public.equipamentos set estado = 'Avariado' where id = new.equipamento_id and estado = 'Em uso';
  end if;
  return null;
end $f$;
drop trigger if exists bsp_registo_actualiza_plano on public.manutencoes_registo;
create trigger bsp_registo_actualiza_plano after insert on public.manutencoes_registo
  for each row execute function public.bsp_registo_actualiza_plano();

drop policy if exists equipamentos_ler on public.equipamentos;
create policy equipamentos_ler on public.equipamentos for select to authenticated
  using (public.bsp_meu_id() is not null and not public.bsp_e_socio());
drop policy if exists equipamentos_mudar on public.equipamentos;
create policy equipamentos_mudar on public.equipamentos for all to authenticated
  using ((select public.bsp_trata_avarias())) with check ((select public.bsp_trata_avarias()));
drop policy if exists plano_ler on public.manutencoes_plano;
create policy plano_ler on public.manutencoes_plano for select to authenticated
  using (public.bsp_meu_id() is not null and not public.bsp_e_socio());
drop policy if exists plano_mudar on public.manutencoes_plano;
create policy plano_mudar on public.manutencoes_plano for all to authenticated
  using ((select public.bsp_trata_avarias())) with check ((select public.bsp_trata_avarias()));
drop policy if exists registo_ler on public.manutencoes_registo;
create policy registo_ler on public.manutencoes_registo for select to authenticated
  using (public.bsp_meu_id() is not null and not public.bsp_e_socio());
drop policy if exists registo_criar on public.manutencoes_registo;
create policy registo_criar on public.manutencoes_registo for insert to authenticated
  with check ((select public.bsp_trata_avarias()));

create or replace function public.bsp_manutencoes_alertar()
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare r record; n int := 0;
begin
  for r in
    select p.*, e.nome, e.area, p.proxima - current_date faltam
      from public.manutencoes_plano p join public.equipamentos e on e.id = p.equipamento_id
     where p.activo and e.estado <> 'Abatido' and p.proxima - current_date in (14, 0, -7)
  loop
    insert into public.novidades (titulo, texto, grupos, destino)
    values (case when r.faltam > 0 then r.tipo || ' daqui a ' || r.faltam || ' dias'
                 when r.faltam = 0 then r.tipo || ' marcada para hoje'
                 else r.tipo || ' em atraso há ' || (-r.faltam) || ' dias' end,
            r.nome || ': ' || lower(r.tipo) || ' de ' || r.cada_dias || ' em ' || r.cada_dias || ' dias, prevista para ' || to_char(r.proxima, 'DD-MM-YYYY')
              || coalesce(' (' || nullif(r.responsavel, '') || ')', '') || '. Registe no Workspace quando estiver feita.',
            array['gestao', 'servicos gerais'] || case when r.area <> '' then array[r.area] else '{}' end, 'avarias');
    n := n + 1;
  end loop;
  return n;
end $f$;
do $$ begin
  revoke execute on function public.bsp_manutencoes_alertar() from public, anon, authenticated;
  revoke execute on function public.bsp_plano_proxima() from public, anon;
  revoke execute on function public.bsp_registo_actualiza_plano() from public, anon;
end $$;
select cron.schedule('bsp-manutencoes', '45 3 * * *', 'select public.bsp_manutencoes_alertar();');
