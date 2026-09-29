-- Barispol Workspace · transporte (rotas do motorista, viagens de dia,
-- abastecimentos e bairros de quem é levado)
-- Pedido do motorista e do Elmar, 29-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- Transporte de pessoal (quem sai às 22:30), amostras e compras; nunca
-- doentes. O carro fica com o motorista: a viagem para casa é registada.
-- Cada viagem tem km de início e de fim; os km que não continuam de uma
-- viagem para a seguinte aparecem como «sem registo» e o ecrã pede o
-- motivo (viagem de ligação).
--
-- Quem vê e regista (bsp_ve_transporte, igual a bspVeTransporte no ecrã):
-- a gestão e quem tem o cargo de motorista. Os bairros de residência são
-- dados pessoais: só estes os vêem. Nenhum nome nem bairro entra no
-- repositório; o histórico de 24 a 28-09-2026 foi carregado directamente
-- na base de dados.

create or replace function public.bsp_ve_transporte()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select not public.bsp_e_socio() and (
       public.bsp_e_gestor()
    or exists (
      select 1 from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
       where s.id = 1 and e->>'id' = public.bsp_meu_id()
         and coalesce(e->>'role', '') ~* 'motorista'))
$function$;
grant execute on function public.bsp_ve_transporte() to authenticated;

-- tipo: pessoal (rota das 22:30), amostras, compras, outro, casa (para
-- casa do motorista), ligacao (km entre duas viagens, com o motivo).
-- paragens: [{quem: 'u8' | 'x:Nome', zona, deixado_em, falta, nota}]
create table if not exists public.transporte_viagens (
  id bigint generated always as identity primary key,
  data date not null,
  tipo text not null check (tipo in ('pessoal', 'amostras', 'compras', 'outro', 'casa', 'ligacao')),
  km_inicio integer not null check (km_inicio >= 0),
  km_fim integer check (km_fim is null or km_fim >= km_inicio),
  hora_inicio timestamptz,
  hora_fim timestamptz,
  destino text not null default '',
  paragens jsonb not null default '[]'::jsonb,
  nota text not null default '',
  foto_inicio text,
  foto_fim text,
  motorista text,
  criado_por text,
  criado_em timestamptz not null default now(),
  alterado_em timestamptz not null default now()
);
create index if not exists transporte_viagens_data on public.transporte_viagens (data);

create table if not exists public.transporte_abastecimentos (
  id bigint generated always as identity primary key,
  quando timestamptz not null default now(),
  km integer not null check (km >= 0),
  litros numeric(8, 2) not null check (litros > 0),
  valor numeric(12, 2) not null default 0 check (valor >= 0),
  foto text,
  nota text not null default '',
  criado_por text,
  criado_em timestamptz not null default now()
);

-- Bairro de cada pessoa que o carro leva (id da equipa ou «x:Nome»).
create table if not exists public.transporte_zonas (
  pessoa text primary key,
  zona text not null default '',
  ponto text not null default '',
  alterado_em timestamptz not null default now()
);

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
  else
    new.alterado_em := now();
  end if;
  return new;
end $function$;
drop trigger if exists bsp_transporte_viagens_carimbo on public.transporte_viagens;
create trigger bsp_transporte_viagens_carimbo before insert or update on public.transporte_viagens
  for each row execute function public.bsp_transporte_carimbo();
drop trigger if exists bsp_transporte_abast_carimbo on public.transporte_abastecimentos;
create trigger bsp_transporte_abast_carimbo before insert on public.transporte_abastecimentos
  for each row execute function public.bsp_transporte_carimbo();
drop trigger if exists bsp_transporte_zonas_carimbo on public.transporte_zonas;
create trigger bsp_transporte_zonas_carimbo before insert or update on public.transporte_zonas
  for each row execute function public.bsp_transporte_carimbo();

do $$
declare t text;
begin
  foreach t in array array['transporte_viagens', 'transporte_abastecimentos', 'transporte_zonas'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_ler', t);
    execute format('drop policy if exists %I on public.%I', t || '_criar', t);
    execute format('drop policy if exists %I on public.%I', t || '_mudar', t);
    execute format('drop policy if exists %I on public.%I', t || '_apagar', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.bsp_ve_transporte())', t || '_ler', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.bsp_ve_transporte())', t || '_criar', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.bsp_ve_transporte()) with check (public.bsp_ve_transporte())', t || '_mudar', t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.bsp_e_gestor())', t || '_apagar', t);
  end loop;
end $$;

-- Quem sai à noite (turno que acaba às 22:00 ou depois) num dia, pelas
-- escalas publicadas de todas as áreas. O motorista não vê as escalas das
-- outras áreas: esta função dá-lhe só o nome, a área e o turno.
create or replace function public.bsp_transporte_saidas(p_dia date)
returns table (pessoa text, area text, turno text, fim text)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
begin
  if not public.bsp_ve_transporte() then raise exception 'Sem acesso ao transporte.'; end if;
  return query
  select distinct p.pessoa, e.area, t->>'nome', t->>'fim'
    from public.escalas e,
         jsonb_array_elements(e.turnos) t,
         jsonb_array_elements_text(coalesce(e.dias -> (p_dia::text) -> (t->>'id'), '[]'::jsonb)) p(pessoa)
   where e.estado = 'publicada'
     and e.mes = date_trunc('month', p_dia)::date
     and coalesce(t->>'fim', '') >= '22:00';
end $function$;
revoke all on function public.bsp_transporte_saidas(date) from public, anon;
grant execute on function public.bsp_transporte_saidas(date) to authenticated;

insert into public.novidades (titulo, texto, grupos, destino)
select 'Transporte no Workspace',
       'O motorista regista no ecrã «Transporte» a rota das 22:30 (quem sai vem das escalas), a hora a que deixa cada pessoa, as viagens de dia (amostras, compras), a ida para casa e os abastecimentos. O resumo de cada rota aparece no grupo #transporte. Os km que não continuam de uma viagem para a seguinte ficam assinalados.',
       array['u22', 'gestao'], 'transporte'
 where not exists (select 1 from public.novidades where titulo = 'Transporte no Workspace');

notify pgrst, 'reload schema';
