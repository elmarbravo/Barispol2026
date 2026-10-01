-- Barispol Workspace · férias e ausências, avarias, formações e pedidos de compra
-- Pedido do Elmar, 01-10-2026 («faz todos eles», auditoria: funções em
-- falta). Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia.
-- Pode correr-se mais do que uma vez.
--
-- Quem decide (bsp_chefe_de): a gestão (Direcção e Coordenação, onde está a
-- Arlete), o superior directo da pessoa (campo «superior» na equipa) e o
-- chefe da área dela (bsp_escalas_responsaveis). Ninguém decide os seus
-- próprios pedidos. Os avisos saem pelas novidades (sino e e-mail das 05h00).

-- A pessoa p_user responde a mim?
create or replace function public.bsp_chefe_de(p_user text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.bsp_meu_id() is not null and p_user is distinct from public.bsp_meu_id() and (
    public.bsp_e_gestor()
    or exists (select 1 from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
                where s.id = 1 and e->>'id' = p_user and e->>'superior' = public.bsp_meu_id())
    or exists (select 1 from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e,
                    public.bsp_escalas_responsaveis() r
                where s.id = 1 and e->>'id' = p_user and r.area = public.bsp_area_chave(e->>'dept')
                  and public.bsp_meu_id() = any (r.ids)))
$function$;
grant execute on function public.bsp_chefe_de(text) to authenticated;

-- Quem decide os pedidos de uma pessoa (para os avisos).
create or replace function public.bsp_chefes_de(p_user text)
returns text[]
language sql
stable
security definer
set search_path to 'public'
as $function$
  select coalesce(array_agg(distinct x) filter (where x is not null and x <> p_user), '{}')
  from (
    select e->>'superior' x from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1 and e->>'id' = p_user
    union all
    select unnest(r.ids) from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e,
           public.bsp_escalas_responsaveis() r
     where s.id = 1 and e->>'id' = p_user and r.area = public.bsp_area_chave(e->>'dept')
  ) q
$function$;
revoke all on function public.bsp_chefes_de(text) from public, anon, authenticated;

create or replace function public.bsp_nome_de(p_user text)
returns text
language sql
stable
security definer
set search_path to 'public'
as $function$
  select coalesce((select e->>'name' from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
                    where s.id = 1 and e->>'id' = p_user limit 1), 'Um colega')
$function$;
revoke all on function public.bsp_nome_de(text) from public, anon, authenticated;

-- ───────────── Férias e ausências ─────────────
create table if not exists public.ausencias (
  id bigint generated always as identity primary key,
  user_id text not null default public.bsp_meu_id(),
  tipo text not null check (tipo in ('Férias', 'Doença', 'Falta justificada', 'Formação', 'Licença', 'Outro')),
  inicio date not null,
  fim date not null,
  nota text not null default '',
  estado text not null default 'Pedido' check (estado in ('Pedido', 'Aprovado', 'Recusado', 'Cancelado')),
  decidido_por text,
  decidido_em timestamptz,
  motivo text not null default '',
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now(),
  check (fim >= inicio)
);
alter table public.ausencias enable row level security;
drop policy if exists ausencias_ler on public.ausencias;
create policy ausencias_ler on public.ausencias for select to authenticated
  using (user_id = public.bsp_meu_id() or public.bsp_chefe_de(user_id));
drop policy if exists ausencias_criar on public.ausencias;
create policy ausencias_criar on public.ausencias for insert to authenticated
  with check (estado = 'Pedido' and (user_id = public.bsp_meu_id() or public.bsp_e_gestor()));
revoke update, delete on public.ausencias from anon, authenticated;

create or replace function public.bsp_ausencia_decidir(p_id bigint, p_estado text, p_motivo text default '')
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare a public.ausencias;
begin
  select * into a from public.ausencias where id = p_id;
  if not found then raise exception 'Pedido não encontrado.'; end if;
  if p_estado = 'Cancelado' then
    if a.user_id <> public.bsp_meu_id() and not public.bsp_chefe_de(a.user_id) then raise exception 'Só quem pediu cancela.'; end if;
  elsif p_estado in ('Aprovado', 'Recusado') then
    if not public.bsp_chefe_de(a.user_id) then raise exception 'Não pode decidir este pedido.'; end if;
  else
    raise exception 'Estado inválido.';
  end if;
  update public.ausencias set estado = p_estado, decidido_por = public.bsp_meu_id(), decidido_em = now(), motivo = coalesce(p_motivo, '')
   where id = p_id;
  if p_estado in ('Aprovado', 'Recusado') then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('O seu pedido de ' || lower(a.tipo) || ' foi ' || lower(p_estado),
            public.bsp_nome_de(public.bsp_meu_id()) || ' ' || lower(p_estado) || ' o pedido de ' || to_char(a.inicio, 'DD-MM-YYYY') || ' a ' || to_char(a.fim, 'DD-MM-YYYY') || '.'
            || case when coalesce(p_motivo, '') <> '' then ' Motivo: ' || p_motivo else '' end,
            array[a.user_id], 'directory');
  end if;
end $function$;
grant execute on function public.bsp_ausencia_decidir(bigint, text, text) to authenticated;

create or replace function public.bsp_ausencia_pedida()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare quem text[] := public.bsp_chefes_de(new.user_id);
begin
  insert into public.novidades (titulo, texto, grupos, destino)
  values ('Pedido de ' || lower(new.tipo) || ': ' || public.bsp_nome_de(new.user_id),
          public.bsp_nome_de(new.user_id) || ' pede ' || lower(new.tipo) || ' de ' || to_char(new.inicio, 'DD-MM-YYYY') || ' a ' || to_char(new.fim, 'DD-MM-YYYY')
          || '. Aprove ou recuse em Equipa → Férias e ausências.',
          case when cardinality(quem) > 0 then quem || array['gestao'] else array['gestao'] end, 'directory');
  return new;
end $function$;
drop trigger if exists bsp_ausencia_pedida on public.ausencias;
create trigger bsp_ausencia_pedida after insert on public.ausencias
  for each row execute function public.bsp_ausencia_pedida();

-- ───────────── Avarias ─────────────
create table if not exists public.avarias (
  id bigint generated always as identity primary key,
  area text not null default '',
  local text not null default '',
  equipamento text not null,
  descricao text not null default '',
  prioridade text not null default 'Normal' check (prioridade in ('Urgente', 'Alta', 'Normal')),
  estado text not null default 'Aberta' check (estado in ('Aberta', 'Em reparação', 'Resolvida', 'Cancelada')),
  responsavel text not null default '',
  custo numeric,
  resolucao text not null default '',
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now(),
  actualizado_por text,
  actualizado_em timestamptz not null default now(),
  resolvido_em timestamptz
);
alter table public.avarias enable row level security;
-- Quem trata as avarias: a gestão e os Serviços Gerais.
create or replace function public.bsp_trata_avarias()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.bsp_e_gestor() or coalesce(public.bsp_minha_area(), '') = 'servicos gerais'
$function$;
grant execute on function public.bsp_trata_avarias() to authenticated;
drop policy if exists avarias_ler on public.avarias;
create policy avarias_ler on public.avarias for select to authenticated
  using (public.bsp_meu_id() is not null and not public.bsp_e_socio());
drop policy if exists avarias_criar on public.avarias;
create policy avarias_criar on public.avarias for insert to authenticated
  with check (public.bsp_meu_id() is not null and not public.bsp_e_socio() and estado = 'Aberta');
drop policy if exists avarias_mudar on public.avarias;
create policy avarias_mudar on public.avarias for update to authenticated
  using (public.bsp_trata_avarias() or criado_por = public.bsp_meu_id())
  with check (public.bsp_trata_avarias() or criado_por = public.bsp_meu_id());
revoke delete on public.avarias from anon, authenticated;

create or replace function public.bsp_avaria_carimbo()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if tg_op = 'INSERT' then
    new.criado_por := coalesce(public.bsp_meu_id(), new.criado_por);
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Avaria ' || lower(new.prioridade) || ': ' || new.equipamento,
            public.bsp_nome_de(new.criado_por) || ' reportou: ' || left(coalesce(nullif(new.descricao, ''), new.equipamento), 300)
            || case when new.local <> '' then ' (' || new.local || ')' else '' end || '.',
            array['gestao', 'servicos gerais'], 'avarias');
    return new;
  end if;
  -- Quem reportou só pode cancelar ou acrescentar à descrição; o resto é de quem trata.
  if not public.bsp_trata_avarias() then
    if new.estado not in (old.estado, 'Cancelada') or new.responsavel <> old.responsavel or new.custo is distinct from old.custo
       or new.resolucao <> old.resolucao or new.prioridade <> old.prioridade then
      raise exception 'Só a gestão e os Serviços Gerais mudam o estado das avarias.';
    end if;
  end if;
  new.actualizado_por := public.bsp_meu_id();
  new.actualizado_em := now();
  if new.estado = 'Resolvida' and old.estado <> 'Resolvida' then
    new.resolvido_em := now();
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Avaria resolvida: ' || new.equipamento, coalesce(nullif(new.resolucao, ''), 'Resolvida.'), array[new.criado_por], 'avarias');
  end if;
  return new;
end $function$;
drop trigger if exists bsp_avaria_carimbo on public.avarias;
create trigger bsp_avaria_carimbo before insert or update on public.avarias
  for each row execute function public.bsp_avaria_carimbo();

-- ───────────── Formações ─────────────
create table if not exists public.formacoes (
  id bigint generated always as identity primary key,
  user_id text not null default public.bsp_meu_id(),
  titulo text not null,
  entidade text not null default '',
  data date not null,
  horas numeric,
  validade date,
  nota text not null default '',
  registado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now()
);
alter table public.formacoes enable row level security;
drop policy if exists formacoes_ler on public.formacoes;
create policy formacoes_ler on public.formacoes for select to authenticated
  using (user_id = public.bsp_meu_id() or public.bsp_chefe_de(user_id));
drop policy if exists formacoes_criar on public.formacoes;
create policy formacoes_criar on public.formacoes for insert to authenticated
  with check (user_id = public.bsp_meu_id() or public.bsp_e_gestor());
drop policy if exists formacoes_mudar on public.formacoes;
create policy formacoes_mudar on public.formacoes for update to authenticated
  using (public.bsp_e_gestor() or registado_por = public.bsp_meu_id())
  with check (public.bsp_e_gestor() or registado_por = public.bsp_meu_id());
drop policy if exists formacoes_apagar on public.formacoes;
create policy formacoes_apagar on public.formacoes for delete to authenticated
  using (public.bsp_e_gestor() or registado_por = public.bsp_meu_id());

-- ───────────── Pedidos de compra (Stock) ─────────────
create table if not exists public.pedidos_compra (
  id bigint generated always as identity primary key,
  armazem text not null,
  itens jsonb not null default '[]'::jsonb,
  nota text not null default '',
  estado text not null default 'Pedido' check (estado in ('Pedido', 'Aprovado', 'Recusado', 'Comprado', 'Recebido')),
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now(),
  decidido_por text,
  decidido_em timestamptz,
  actualizado_em timestamptz not null default now()
);
alter table public.pedidos_compra enable row level security;
drop policy if exists pedidos_compra_ler on public.pedidos_compra;
create policy pedidos_compra_ler on public.pedidos_compra for select to authenticated
  using (public.bsp_ve_stock(armazem));
drop policy if exists pedidos_compra_criar on public.pedidos_compra;
create policy pedidos_compra_criar on public.pedidos_compra for insert to authenticated
  with check (public.bsp_ve_stock(armazem) and estado = 'Pedido');
drop policy if exists pedidos_compra_mudar on public.pedidos_compra;
create policy pedidos_compra_mudar on public.pedidos_compra for update to authenticated
  using (public.bsp_ve_stock(armazem)) with check (public.bsp_ve_stock(armazem));
revoke delete on public.pedidos_compra from anon, authenticated;

create or replace function public.bsp_pedido_compra_carimbo()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if tg_op = 'INSERT' then
    new.criado_por := coalesce(public.bsp_meu_id(), new.criado_por);
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Pedido de compra: ' || replace(new.armazem, ' - CBL', ''),
            public.bsp_nome_de(new.criado_por) || ' pede ' || jsonb_array_length(new.itens) || ' artigo(s). Aprove em Stock → Pedidos de compra.',
            array['gestao'], 'stock');
    return new;
  end if;
  -- Aprovar ou recusar: só a gestão. Comprado e Recebido: quem vê o armazém.
  if new.estado <> old.estado and new.estado in ('Aprovado', 'Recusado') then
    if not public.bsp_e_gestor() then raise exception 'Só a gestão aprova pedidos de compra.'; end if;
    new.decidido_por := public.bsp_meu_id();
    new.decidido_em := now();
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Pedido de compra ' || lower(new.estado), 'O pedido de ' || replace(new.armazem, ' - CBL', '') || ' foi ' || lower(new.estado) || '.', array[new.criado_por], 'stock');
  end if;
  if old.estado = 'Pedido' and new.estado in ('Comprado', 'Recebido') then
    raise exception 'O pedido tem de ser aprovado primeiro.';
  end if;
  if new.itens is distinct from old.itens and old.estado <> 'Pedido' then
    raise exception 'Depois de decidido, o pedido não muda.';
  end if;
  new.actualizado_em := now();
  return new;
end $function$;
drop trigger if exists bsp_pedido_compra_carimbo on public.pedidos_compra;
create trigger bsp_pedido_compra_carimbo before insert or update on public.pedidos_compra
  for each row execute function public.bsp_pedido_compra_carimbo();

notify pgrst, 'reload schema';
