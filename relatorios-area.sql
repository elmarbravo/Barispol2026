-- Barispol Workspace · relatorios padrao por area
-- Pedido do Elmar, 24-09-2026. Aplicado no servidor no mesmo dia.
-- Pode correr-se mais do que uma vez.
--
-- Cada area (Recepcao, Farmacia, Laboratorio, Imagiologia, Enfermagem)
-- preenche no Workspace um relatorio de escolha multipla, em vez do
-- e-mail em texto livre. As perguntas vivem no workspace.html
-- (BSP_RELATORIOS); aqui guardam-se as respostas.
--
-- Sem nomes de pacientes: so contagens e escolhas.

create table if not exists relatorios_area (
  id         bigint generated always as identity primary key,
  area       text not null,
  dia        date not null default ((now() at time zone 'Africa/Luanda')::date),
  turno      text,
  user_id    text not null default bsp_meu_id(),
  respostas  jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists relatorios_area_dia_idx on relatorios_area (dia, area);

alter table relatorios_area enable row level security;
drop policy if exists "bsp_rel_ler"    on relatorios_area;
drop policy if exists "bsp_rel_criar"  on relatorios_area;
drop policy if exists "bsp_rel_mudar"  on relatorios_area;
drop policy if exists "bsp_rel_apagar" on relatorios_area;

-- Cada pessoa ve os seus; a Direccao e a Coordenacao vem todos.
create policy "bsp_rel_ler" on relatorios_area for select to authenticated
  using (user_id = bsp_meu_id() or bsp_e_gestor());
-- So em nome proprio.
create policy "bsp_rel_criar" on relatorios_area for insert to authenticated
  with check (user_id = bsp_meu_id());
-- Corrigir ou apagar: o proprio, no dia; a Direccao e a Coordenacao, sempre.
create policy "bsp_rel_mudar" on relatorios_area for update to authenticated
  using ((user_id = bsp_meu_id() and dia >= ((now() at time zone 'Africa/Luanda')::date)) or bsp_e_gestor())
  with check (user_id = bsp_meu_id() or bsp_e_gestor());
create policy "bsp_rel_apagar" on relatorios_area for delete to authenticated
  using ((user_id = bsp_meu_id() and dia >= ((now() at time zone 'Africa/Luanda')::date)) or bsp_e_gestor());

notify pgrst, 'reload schema';

select policyname, cmd from pg_policies where tablename = 'relatorios_area' order by 1;
