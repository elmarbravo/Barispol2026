-- Acertos de km das viaturas (09-10-2026, Elmar: «actualizar a quilometragem
-- inicial da ambulância» e «editar as quilometragens mesmo sem actividade;
-- coloca a quilometragem agora e depois soma a cada movimentação»).
--
-- transporte_acertos: leitura do conta-quilómetros registada sem viagem.
-- O último acerto mais recente do que a última viagem da viatura passa a ser
-- o ponto de partida (o «último registo»); as viagens seguintes somam daí.
-- Os acertos não contam como km andados nem como «km sem registo».
-- Só a gestão acerta (bsp_e_gestor); quem vê o Transporte vê os acertos.
-- Nunca se apagam nem se alteram: um engano corrige-se com outro acerto.

create table if not exists public.transporte_acertos (
  id bigint generated always as identity primary key,
  viatura_id bigint not null references public.transporte_viaturas (id),
  km integer not null check (km >= 0),
  motivo text not null check (btrim(motivo) <> ''),
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now()
);
create index if not exists transporte_acertos_viatura on public.transporte_acertos (viatura_id, criado_em);
alter table public.transporte_acertos enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'transporte_acertos' and policyname = 'transporte_acertos_ler') then
    create policy transporte_acertos_ler on public.transporte_acertos for select to authenticated using (public.bsp_ve_transporte());
    create policy transporte_acertos_criar on public.transporte_acertos for insert to authenticated
      with check (public.bsp_e_gestor() and criado_por = public.bsp_meu_id());
  end if;
end $$;
grant select, insert on public.transporte_acertos to authenticated;

notify pgrst, 'reload schema';
