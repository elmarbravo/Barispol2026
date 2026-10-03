-- Subsídio de produtividade mensal (03-10-2026, Elmar: «No SharePoint vê
-- esse ficheiro e funde com a produtividade que já tem. Esse serve para
-- pagar: Apuramento_Subs Produtividade.xlsx»; RI-5.3, nota interna
-- BRSP-DG-NINT-24-001).
--
-- O apuramento passa a fazer-se no Workspace com a regra do ficheiro dos RH:
-- cada pessoa tem até 4 objectivos da sua função, cada um com nota de 1 a 3
-- (1 não cumpriu, 2 cumpriu a 75%, 3 cumpriu a 100%); a média dá a
-- percentagem (até 1,6 → 50%; até 2,6 → 75%; acima → 100%) e o total a
-- pagar = subsídio × percentagem. As contas fazem-se no servidor.
--
-- produtividade_objectivos: o catálogo de objectivos por função (a folha
--   «Legenda - Objectivos»). Texto interno: preenche-se só no servidor.
-- produtividade_pessoas: quem tem subsídio (número BRP, nome, área, função,
--   valor do subsídio e os seus objectivos). Liga à pessoa do Workspace
--   (user_id) quando ela tem conta; os assistentes sem conta ficam pelo BRP.
-- produtividade_mensal: uma linha por pessoa e mês. Rascunho → Aprovado
--   (gestão) → Pago (gestão ou Financeiro).
-- A fusão: ao aprovar, a percentagem e a média do mês passam para
-- desempenho_historico (fonte «apuramento»), que a avaliação anual já lê.
--
-- Quem vê e quem lança: a gestão e o Financeiro (bsp_ve_painel) vêem tudo;
-- o chefe da área (bsp_edita_escala) e o superior (bsp_chefe_de) vêem e
-- lançam a sua equipa; cada pessoa vê os seus meses aprovados.
-- Valores e nomes ficam no servidor; nunca no repositório.

create table if not exists public.produtividade_objectivos (
  id bigint generated always as identity primary key,
  nome text not null,
  funcao text not null default '',
  descricao text not null default '',
  exemplos text not null default '',
  ordem int not null default 0,
  activo boolean not null default true
);
alter table public.produtividade_objectivos enable row level security;

create table if not exists public.produtividade_pessoas (
  codigo text primary key,
  user_id text,
  nome text not null,
  area text not null default '',
  funcao text not null default '',
  subsidio numeric not null default 0,
  objectivos text[] not null default '{}',
  activo boolean not null default true,
  actualizado_em timestamptz not null default now()
);
alter table public.produtividade_pessoas enable row level security;

create table if not exists public.produtividade_mensal (
  id bigint generated always as identity primary key,
  codigo text not null,
  user_id text,
  nome text not null,
  area text not null default '',
  funcao text not null default '',
  ano int not null,
  mes int not null check (mes between 1 and 12),
  subsidio numeric not null default 0,
  objectivos jsonb not null default '[]',
  media numeric,
  percentagem int,
  total numeric,
  estado text not null default 'Rascunho' check (estado in ('Rascunho', 'Aprovado', 'Pago')),
  observacoes text not null default '',
  avaliador text,
  aprovado_por text,
  aprovado_em timestamptz,
  pago_em timestamptz,
  fonte text not null default 'workspace',
  criado_em timestamptz not null default now(),
  actualizado_em timestamptz not null default now(),
  unique (codigo, ano, mes)
);
create index if not exists produtividade_mensal_mes on public.produtividade_mensal (ano, mes);
alter table public.produtividade_mensal enable row level security;

-- Quem vê / lança a produtividade de uma pessoa.
create or replace function public.bsp_produtividade_trata(p_area text, p_user text)
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(public.bsp_e_gestor(), false) or coalesce(public.bsp_ve_painel(), false)
      or (coalesce(p_area, '') <> '' and coalesce(public.bsp_edita_escala(p_area), false))
      or (p_user is not null and p_user is distinct from public.bsp_meu_id() and coalesce(public.bsp_chefe_de(p_user), false))
$f$;
create or replace function public.bsp_produtividade_aprova()
returns boolean language sql stable security definer set search_path to 'public'
as $f$ select coalesce(public.bsp_e_gestor(), false) $f$;

create policy prod_obj_ler on public.produtividade_objectivos for select to authenticated using (public.bsp_meu_id() is not null);
create policy prod_pes_ler on public.produtividade_pessoas for select to authenticated
  using (public.bsp_produtividade_trata(area, user_id) or user_id = (select public.bsp_meu_id()));
create policy prod_mes_ler on public.produtividade_mensal for select to authenticated
  using (public.bsp_produtividade_trata(area, user_id) or (user_id = (select public.bsp_meu_id()) and estado <> 'Rascunho'));

-- Regra do ficheiro dos RH.
create or replace function public.bsp_produtividade_percentagem(p_media numeric)
returns int language sql immutable as $f$
  select case when p_media is null then null when p_media <= 1.6 then 50 when p_media <= 2.6 then 75 else 100 end
$f$;

create or replace function public.bsp_produtividade_calcular()
returns trigger language plpgsql set search_path to 'public'
as $f$
begin
  new.actualizado_em := now();
  -- Meses importados dos ficheiros dos RH guardam os números da folha (o que
  -- se pagou), mesmo quando a folha fez a conta de outra maneira.
  if new.fonte = 'sharepoint' and new.percentagem is not null then return new; end if;
  select round(avg((o->>'nota')::numeric), 2) into new.media
    from jsonb_array_elements(coalesce(new.objectivos, '[]')) o where (o->>'nota') ~ '^[1-3]$';
  new.percentagem := public.bsp_produtividade_percentagem(new.media);
  new.total := case when new.percentagem is null then null else round(new.subsidio * new.percentagem / 100.0, 2) end;
  return new;
end $f$;
create trigger bsp_produtividade_calcular before insert or update on public.produtividade_mensal
  for each row execute function public.bsp_produtividade_calcular();

-- Ao aprovar ou pagar: a produtividade do mês entra no histórico da avaliação.
create or replace function public.bsp_produtividade_historico()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
begin
  if new.user_id is not null and new.estado in ('Aprovado', 'Pago') and new.percentagem is not null then
    insert into public.desempenho_historico (user_id, ano, mes, produtividade_pc, classificacao, fonte)
    values (new.user_id, new.ano, new.mes, new.percentagem, replace(to_char(new.media, 'FM0.00'), '.', ',') || ' em 3', 'apuramento')
    on conflict (user_id, ano, mes) do update
       set produtividade_pc = excluded.produtividade_pc, classificacao = excluded.classificacao,
           fonte = case when desempenho_historico.fonte in ('', 'apuramento') then 'apuramento' else desempenho_historico.fonte || ' + apuramento' end,
           importado_em = now();
  end if;
  return new;
end $f$;
create trigger bsp_produtividade_historico after insert or update on public.produtividade_mensal
  for each row execute function public.bsp_produtividade_historico();

-- Lançar (ou corrigir) o mês de uma pessoa. Notas de 1 a 3 por objectivo.
create or replace function public.bsp_produtividade_gravar(p_codigo text, p_ano int, p_mes int, p_notas jsonb, p_observacoes text default '')
returns bigint language plpgsql security definer set search_path to 'public'
as $f$
declare p record; m record; nid bigint; objs jsonb;
begin
  select * into p from public.produtividade_pessoas where codigo = p_codigo;
  if p.codigo is null then raise exception 'Pessoa sem subsídio de produtividade.'; end if;
  if not public.bsp_produtividade_trata(p.area, p.user_id) then raise exception 'Sem permissão para lançar a produtividade desta pessoa.'; end if;
  if p.user_id is not null and p.user_id = public.bsp_meu_id() and not public.bsp_e_gestor() then raise exception 'Ninguém lança a sua própria produtividade.'; end if;
  select * into m from public.produtividade_mensal where codigo = p_codigo and ano = p_ano and mes = p_mes;
  if m.id is not null and m.estado <> 'Rascunho' and not public.bsp_produtividade_aprova() then
    raise exception 'Este mês já foi aprovado. Só a gestão o altera.';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('nome', x.nome, 'nota', case when (p_notas->>x.nome) ~ '^[1-3]$' then (p_notas->>x.nome)::int end) order by x.ord), '[]')
    into objs from unnest(p.objectivos) with ordinality x(nome, ord);
  insert into public.produtividade_mensal (codigo, user_id, nome, area, funcao, ano, mes, subsidio, objectivos, observacoes, avaliador)
  values (p.codigo, p.user_id, p.nome, p.area, p.funcao, p_ano, p_mes, p.subsidio, objs, left(coalesce(p_observacoes, ''), 2000), public.bsp_meu_id())
  on conflict (codigo, ano, mes) do update
     set objectivos = excluded.objectivos, observacoes = excluded.observacoes, avaliador = excluded.avaliador,
         subsidio = case when produtividade_mensal.estado = 'Rascunho' then excluded.subsidio else produtividade_mensal.subsidio end
  returning id into nid;
  return nid;
end $f$;

-- Aprovar ou marcar como pago um mês inteiro (ou só uma área).
create or replace function public.bsp_produtividade_estado(p_ano int, p_mes int, p_estado text, p_area text default null)
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare n int;
begin
  if p_estado = 'Aprovado' and not public.bsp_produtividade_aprova() then raise exception 'Só a gestão aprova.'; end if;
  if p_estado = 'Pago' and not (public.bsp_produtividade_aprova() or coalesce(public.bsp_ve_painel(), false)) then raise exception 'Só a gestão e o Financeiro marcam como pago.'; end if;
  if p_estado not in ('Aprovado', 'Pago', 'Rascunho') then raise exception 'Estado inválido.'; end if;
  if p_estado = 'Rascunho' and not public.bsp_produtividade_aprova() then raise exception 'Só a gestão reabre.'; end if;
  update public.produtividade_mensal
     set estado = p_estado,
         aprovado_por = case when p_estado = 'Aprovado' then public.bsp_meu_id() else aprovado_por end,
         aprovado_em = case when p_estado = 'Aprovado' then now() else aprovado_em end,
         pago_em = case when p_estado = 'Pago' then now() else pago_em end
   where ano = p_ano and mes = p_mes and (p_area is null or area = p_area)
     and percentagem is not null
     and (p_estado <> 'Pago' or estado in ('Aprovado', 'Pago'));
  get diagnostics n = row_count;
  if p_estado = 'Aprovado' and n > 0 then
    insert into public.novidades (titulo, texto, grupos, destino)
    select 'Produtividade de ' || to_char(make_date(p_ano, p_mes, 1), 'MM-YYYY'),
           'A sua produtividade de ' || to_char(make_date(p_ano, p_mes, 1), 'MM-YYYY') || ' foi aprovada. Veja-a em Equipa → Produtividade.',
           array_agg(distinct user_id), 'directory'
      from public.produtividade_mensal
     where ano = p_ano and mes = p_mes and (p_area is null or area = p_area) and user_id is not null and estado = 'Aprovado'
    having count(*) > 0;
  end if;
  return n;
end $f$;

-- Gestão: acertar a ficha de uma pessoa (subsídio, objectivos, ligação).
create or replace function public.bsp_produtividade_pessoa(p_codigo text, p_dados jsonb)
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
begin
  if not public.bsp_produtividade_aprova() then raise exception 'Só a gestão altera o subsídio e os objectivos.'; end if;
  insert into public.produtividade_pessoas (codigo, user_id, nome, area, funcao, subsidio, objectivos, activo)
  values (upper(btrim(p_codigo)), nullif(p_dados->>'user_id', ''), coalesce(p_dados->>'nome', ''), coalesce(p_dados->>'area', ''),
          coalesce(p_dados->>'funcao', ''), coalesce((p_dados->>'subsidio')::numeric, 0),
          coalesce(array(select jsonb_array_elements_text(p_dados->'objectivos')), '{}'), coalesce((p_dados->>'activo')::boolean, true))
  on conflict (codigo) do update
     set user_id = excluded.user_id, nome = excluded.nome, area = excluded.area, funcao = excluded.funcao,
         subsidio = excluded.subsidio, objectivos = excluded.objectivos, activo = excluded.activo, actualizado_em = now();
  return true;
end $f$;

do $$ begin
  revoke execute on function public.bsp_produtividade_calcular() from public, anon, authenticated;
  revoke execute on function public.bsp_produtividade_historico() from public, anon, authenticated;
  revoke execute on function public.bsp_produtividade_trata(text, text) from public, anon;
  revoke execute on function public.bsp_produtividade_aprova() from public, anon;
  revoke execute on function public.bsp_produtividade_gravar(text, int, int, jsonb, text) from public, anon;
  revoke execute on function public.bsp_produtividade_estado(int, int, text, text) from public, anon;
  revoke execute on function public.bsp_produtividade_pessoa(text, jsonb) from public, anon;
  grant execute on function public.bsp_produtividade_trata(text, text) to authenticated;
  grant execute on function public.bsp_produtividade_aprova() to authenticated;
  grant execute on function public.bsp_produtividade_gravar(text, int, int, jsonb, text) to authenticated;
  grant execute on function public.bsp_produtividade_estado(int, int, text, text) to authenticated;
  grant execute on function public.bsp_produtividade_pessoa(text, jsonb) to authenticated;
end $$;

-- O catálogo de objectivos, as pessoas e o histórico importado dos ficheiros
-- dos RH (SharePoint, BRSP_RH_PRODUTIVIDADE) carregam-se no servidor.
