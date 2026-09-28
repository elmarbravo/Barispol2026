-- Barispol Workspace · escalas de serviço por área
-- Pedido do Elmar, 28-09-2026: o superior preenche a escala do mês no
-- Workspace e envia-a por e-mail ou imprime-a. Modelo: «ESCALA DA
-- RECEPÇÃO - SETEMBRO 2026.xlsx». Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- Uma escala por área (bsp_area_chave do departamento) e por mês:
--   turnos  [{id, nome, inicio, fim, semana: [0..6, 0 = Domingo]}]
--   dias    {"AAAA-MM-DD": {"<turno>": ["u8", ...], "_n": "nota do dia"}}
--   estado  rascunho | publicada
-- Quem preenche (bsp_edita_escala, igual a bspEditaEscala no ecrã): a
-- gestão, quem tem cargo de chefia na área (chefe, supervisor(a),
-- coordenador(a), director(a), responsável) e quem é superior de alguém
-- da área. Quem lê: estes e toda a gente da área. Os sócios não.

create table if not exists public.escalas (
  id bigint generated always as identity primary key,
  area text not null,
  mes date not null check (extract(day from mes) = 1),
  turnos jsonb not null default '[]'::jsonb,
  dias jsonb not null default '{}'::jsonb,
  notas text not null default '',
  estado text not null default 'rascunho' check (estado in ('rascunho', 'publicada')),
  publicada_em timestamptz,
  publicada_por text,
  criado_por text,
  criado_em timestamptz not null default now(),
  alterado_por text,
  alterado_em timestamptz not null default now(),
  unique (area, mes)
);

create or replace function public.bsp_edita_escala(p_area text)
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
         and public.bsp_area_chave(e->>'dept') = p_area
         and coalesce(e->>'role', '') ~* '(chefe|supervis|coordenad|director|directora|respons)')
    or exists (
      select 1 from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) x
       where s.id = 1 and x->>'superior' = public.bsp_meu_id()
         and public.bsp_area_chave(x->>'dept') = p_area))
$function$;
grant execute on function public.bsp_edita_escala(text) to authenticated;

create or replace function public.bsp_ve_escala(p_area text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select not public.bsp_e_socio() and (
       public.bsp_edita_escala(p_area)
    or coalesce(public.bsp_minha_area(), '') = p_area)
$function$;
grant execute on function public.bsp_ve_escala(text) to authenticated;

create or replace function public.bsp_escalas_alterado()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  new.alterado_em := now();
  new.alterado_por := coalesce(public.bsp_meu_id(), new.alterado_por);
  if tg_op = 'INSERT' then new.criado_por := coalesce(public.bsp_meu_id(), new.criado_por); end if;
  if new.estado = 'publicada' and (tg_op = 'INSERT' or old.estado is distinct from 'publicada') then
    new.publicada_em := now();
    new.publicada_por := coalesce(public.bsp_meu_id(), new.publicada_por);
  end if;
  return new;
end $function$;
drop trigger if exists bsp_escalas_alterado on public.escalas;
create trigger bsp_escalas_alterado before insert or update on public.escalas
  for each row execute function public.bsp_escalas_alterado();

alter table public.escalas enable row level security;
drop policy if exists bsp_escalas_ler on public.escalas;
drop policy if exists bsp_escalas_criar on public.escalas;
drop policy if exists bsp_escalas_mudar on public.escalas;
drop policy if exists bsp_escalas_apagar on public.escalas;
create policy bsp_escalas_ler on public.escalas for select to authenticated using (public.bsp_ve_escala(area));
create policy bsp_escalas_criar on public.escalas for insert to authenticated with check (public.bsp_edita_escala(area));
create policy bsp_escalas_mudar on public.escalas for update to authenticated using (public.bsp_edita_escala(area)) with check (public.bsp_edita_escala(area));
create policy bsp_escalas_apagar on public.escalas for delete to authenticated using (public.bsp_e_gestor());

-- A escala da Recepção de Setembro de 2026, tirada do Excel: Juliana
-- (u12) das 08:00 às 17:45 de segunda a sexta (horário dado pelo Elmar
-- a 28-09-2026; o Excel dizia 08:00-17:30); Joaquina Joice (u8) e
-- Déricka Domingos (u15) das 07:00 às 22:30, dia sim, dia não.
insert into public.escalas (area, mes, turnos, dias, estado, criado_por, publicada_por)
select 'recepcao', date '2026-09-01',
  '[{"id":"t1","nome":"Dia","inicio":"08:00","fim":"17:45","semana":[1,2,3,4,5]},{"id":"t2","nome":"Turno longo","inicio":"07:00","fim":"22:30","semana":[0,1,2,3,4,5,6]}]'::jsonb,
  '{"2026-09-01":{"t1":["u12"],"t2":["u8"]},"2026-09-02":{"t1":["u12"],"t2":["u15"]},"2026-09-03":{"t1":["u12"],"t2":["u8"]},"2026-09-04":{"t1":["u12"],"t2":["u15"]},"2026-09-05":{"t2":["u8"]},"2026-09-06":{"t2":["u15"]},"2026-09-07":{"t1":["u12"],"t2":["u8"]},"2026-09-08":{"t1":["u12"],"t2":["u15"]},"2026-09-09":{"t1":["u12"],"t2":["u8"]},"2026-09-10":{"t1":["u12"],"t2":["u15"]},"2026-09-11":{"t1":["u12"],"t2":["u8"]},"2026-09-12":{"t2":["u15"]},"2026-09-13":{"t2":["u8"]},"2026-09-14":{"t1":["u12"],"t2":["u15"]},"2026-09-15":{"t1":["u12"],"t2":["u8"]},"2026-09-16":{"t1":["u12"],"t2":["u15"]},"2026-09-17":{"t1":["u12"],"t2":["u8"]},"2026-09-18":{"t1":["u12"],"t2":["u15"]},"2026-09-19":{"t2":["u8"]},"2026-09-20":{"t2":["u15"]},"2026-09-21":{"t1":["u12"],"t2":["u8"]},"2026-09-22":{"t1":["u12"],"t2":["u15"]},"2026-09-23":{"t1":["u12"],"t2":["u8"]},"2026-09-24":{"t1":["u12"],"t2":["u15"]},"2026-09-25":{"t1":["u12"],"t2":["u8"]},"2026-09-26":{"t2":["u15"]},"2026-09-27":{"t2":["u8"]},"2026-09-28":{"t1":["u12"],"t2":["u15"]},"2026-09-29":{"t1":["u12"],"t2":["u8"]},"2026-09-30":{"t1":["u12"],"t2":["u15"]}}'::jsonb,
  'publicada', 'u12', 'u12'
where not exists (select 1 from public.escalas where area = 'recepcao' and mes = date '2026-09-01');

insert into public.novidades (titulo, texto, grupos, destino)
select 'Escalas de serviço no Workspace',
       'Há um ecrã novo, «Escalas». Cada área vê a sua escala do mês e quem está de serviço hoje aparece no Início. Quem chefia a área preenche a escala (com rotação automática e continuação do mês anterior), publica-a, envia-a por e-mail a cada pessoa com os seus turnos e imprime-a. A escala da Recepção de Setembro já lá está.',
       array['todos'], 'escalas'
 where not exists (select 1 from public.novidades where titulo = 'Escalas de serviço no Workspace');

notify pgrst, 'reload schema';
