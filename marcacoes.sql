-- Barispol Workspace · marcacoes de consultas e exames
-- Pedido do Elmar, 26-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- As marcacoes passam a viver aqui, e nao numa planilha do SharePoint que
-- nao abria dentro do Workspace. As colunas sao as da planilha
-- «MARCAÇÕES - 2026» (dia que contactou, data marcada, hora, sexo, acto
-- medico, nome, contacto, medico), mais o estado e as observacoes. A
-- planilha antiga entra por CSV no proprio ecra; o ecra exporta CSV para o
-- Excel quando for preciso.
--
-- Quem le e escreve: a Recepcao (pelo departamento), a Direccao Clinica
-- (bsp_le_areas_medicas) e a gestao (bsp_e_gestor). Mais ninguem: sao
-- dados de doentes. So a gestao apaga.

create table if not exists public.marcacoes (
  id bigint generated always as identity primary key,
  dia_contacto date,
  data_marcada date not null,
  hora text,
  sexo text check (sexo is null or sexo in ('F', 'M')),
  acto text not null,
  nome text not null,
  contacto text,
  medico text,
  estado text not null default 'Agendada'
    check (estado in ('Agendada', 'Confirmada', 'Compareceu', 'Faltou', 'Cancelou', 'Remarcado')),
  observacoes text,
  origem text,
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now(),
  alterado_por text,
  alterado_em timestamptz
);
-- Colunas da planilha «reformulada» e os estados dela (26-09-2026).
alter table public.marcacoes add column if not exists entidade text;
alter table public.marcacoes add column if not exists seguradora text;
alter table public.marcacoes add column if not exists rececionista text;
alter table public.marcacoes drop constraint if exists marcacoes_estado_check;
update public.marcacoes set estado = case estado when 'Marcado' then 'Agendada' when 'Confirmado' then 'Confirmada' else estado end
  where estado in ('Marcado', 'Confirmado');
alter table public.marcacoes alter column estado set default 'Agendada';
alter table public.marcacoes add constraint marcacoes_estado_check
  check (estado in ('Agendada', 'Confirmada', 'Compareceu', 'Faltou', 'Cancelou', 'Remarcado'));
create index if not exists marcacoes_data_idx on public.marcacoes (data_marcada, hora);
create index if not exists marcacoes_nome_idx on public.marcacoes (lower(nome));

create or replace function public.bsp_ve_marcacoes()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $$
  select coalesce(bsp_e_gestor(), false)
      or coalesce(bsp_le_areas_medicas(), false)
      or coalesce(bsp_minha_area(), '') = 'recepcao'
$$;

create or replace function public.bsp_marcacoes_alterado()
returns trigger
language plpgsql
as $$
begin
  new.alterado_por := public.bsp_meu_id();
  new.alterado_em := now();
  return new;
end $$;
drop trigger if exists marcacoes_alterado on public.marcacoes;
create trigger marcacoes_alterado before update on public.marcacoes
  for each row execute function public.bsp_marcacoes_alterado();

alter table public.marcacoes enable row level security;
drop policy if exists "bsp_marc_ler" on public.marcacoes;
drop policy if exists "bsp_marc_criar" on public.marcacoes;
drop policy if exists "bsp_marc_mudar" on public.marcacoes;
drop policy if exists "bsp_marc_apagar" on public.marcacoes;
create policy "bsp_marc_ler" on public.marcacoes for select to authenticated using (public.bsp_ve_marcacoes());
create policy "bsp_marc_criar" on public.marcacoes for insert to authenticated with check (public.bsp_ve_marcacoes());
create policy "bsp_marc_mudar" on public.marcacoes for update to authenticated using (public.bsp_ve_marcacoes()) with check (public.bsp_ve_marcacoes());
create policy "bsp_marc_apagar" on public.marcacoes for delete to authenticated using (public.bsp_e_gestor());

revoke all on public.marcacoes from anon;
grant select, insert, update, delete on public.marcacoes to authenticated;

notify pgrst, 'reload schema';
