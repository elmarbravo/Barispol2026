-- Barispol Workspace · stock do MetaGest no Workspace
-- Pedido do Elmar, 01-10-2026: a Arlete e a Solange recebem no Workspace o
-- relatório e os alertas de stock. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- O utilizador da API do MetaGest não lê o «Bin» (quantidades por armazém):
-- o saldo sai do último movimento de cada artigo em cada armazém (Stock
-- Ledger Entry, qty_after_transaction). Copia-se também a ficha dos artigos
-- (nome, grupo, unidade) e os lotes (validade e quantidade).
--   · erp.stock_mov, erp.stock_artigo, erp.stock_lote: cópia do MetaGest
--   · erp.sincronizar_stock(): busca o que mudou (agendamento bsp-stock,
--     a cada 15 minutos)
--   · public.stock_responsaveis: quem vê cada armazém ('*' = todos)
--   · public.bsp_stock(): o relatório; public.bsp_stock_resumo(): os alertas
-- Esgotado: saldo 0 com saídas nos últimos 30 dias. A acabar: dura menos de
-- 7 dias ao ritmo dos últimos 30. A caducar: lote com saldo e validade até
-- 60 dias.

create table if not exists erp.stock_mov (
  name text primary key,
  item_code text not null,
  warehouse text not null,
  posting_date date not null,
  posting_time time,
  creation timestamptz,
  actual_qty numeric not null default 0,
  qty_after numeric,
  valuation_rate numeric,
  voucher_type text,
  is_cancelled boolean not null default false,
  modified timestamptz
);
create index if not exists stock_mov_saldo on erp.stock_mov (item_code, warehouse, posting_date desc, posting_time desc, creation desc);
create table if not exists erp.stock_artigo (
  item_code text primary key,
  item_name text,
  item_group text,
  stock_uom text,
  disabled boolean not null default false,
  modified timestamptz
);
create table if not exists erp.stock_lote (
  name text primary key,
  item text,
  expiry_date date,
  batch_qty numeric,
  disabled boolean not null default false,
  modified timestamptz
);
create table if not exists erp.stock_estado (
  id int primary key default 1,
  sincronizado_em timestamptz,
  erro text
);
insert into erp.stock_estado (id) values (1) on conflict do nothing;

-- Todas as paginas de uma lista do MetaGest.
create or replace function erp.api_lista(p_doctype text, p_campos text, p_filtros text)
returns jsonb
language plpgsql
security definer
set search_path to 'erp', 'extensions', 'public'
as $function$
declare
  v_start int := 0;
  v_page int := 500;
  v_lote jsonb;
  v_tudo jsonb := '[]'::jsonb;
begin
  loop
    v_lote := erp.api_get('/api/resource/' || erp.enc(p_doctype)
      || '?fields=' || erp.enc(p_campos)
      || '&filters=' || erp.enc(p_filtros)
      || '&limit_page_length=' || v_page || '&limit_start=' || v_start
      || '&order_by=' || erp.enc('modified asc')) -> 'data';
    exit when v_lote is null or jsonb_array_length(v_lote) = 0;
    v_tudo := v_tudo || v_lote;
    exit when jsonb_array_length(v_lote) < v_page;
    v_start := v_start + v_page;
  end loop;
  return v_tudo;
end $function$;
revoke all on function erp.api_lista(text, text, text) from public, anon, authenticated;

create or replace function erp.sincronizar_stock()
returns text
language plpgsql
security definer
set search_path to 'erp', 'public'
as $function$
declare
  desde text;
  d jsonb;
  n1 int; n2 int; n3 int;
begin
  -- Movimentos: os mudados desde o ultimo (com um dia de folga).
  select coalesce(to_char(max(modified) - interval '1 day', 'YYYY-MM-DD HH24:MI:SS'), '2000-01-01') into desde from erp.stock_mov;
  d := erp.api_lista('Stock Ledger Entry',
    '["name","item_code","warehouse","posting_date","posting_time","creation","actual_qty","qty_after_transaction","valuation_rate","voucher_type","is_cancelled","modified"]',
    format('[["modified",">=","%s"]]', desde));
  insert into erp.stock_mov as m (name, item_code, warehouse, posting_date, posting_time, creation, actual_qty, qty_after, valuation_rate, voucher_type, is_cancelled, modified)
  select x->>'name', x->>'item_code', x->>'warehouse', (x->>'posting_date')::date, nullif(x->>'posting_time', '')::time,
         nullif(x->>'creation', '')::timestamptz, coalesce((x->>'actual_qty')::numeric, 0), (x->>'qty_after_transaction')::numeric,
         (x->>'valuation_rate')::numeric, x->>'voucher_type', coalesce((x->>'is_cancelled')::int, 0) = 1, nullif(x->>'modified', '')::timestamptz
    from jsonb_array_elements(d) x
  on conflict (name) do update set item_code = excluded.item_code, warehouse = excluded.warehouse, posting_date = excluded.posting_date,
    posting_time = excluded.posting_time, creation = excluded.creation, actual_qty = excluded.actual_qty, qty_after = excluded.qty_after,
    valuation_rate = excluded.valuation_rate, voucher_type = excluded.voucher_type, is_cancelled = excluded.is_cancelled, modified = excluded.modified;
  n1 := jsonb_array_length(d);

  select coalesce(to_char(max(modified) - interval '1 day', 'YYYY-MM-DD HH24:MI:SS'), '2000-01-01') into desde from erp.stock_artigo;
  d := erp.api_lista('Item', '["item_code","item_name","item_group","stock_uom","disabled","modified"]',
    format('[["is_stock_item","=",1],["modified",">=","%s"]]', desde));
  insert into erp.stock_artigo as a (item_code, item_name, item_group, stock_uom, disabled, modified)
  select x->>'item_code', x->>'item_name', x->>'item_group', x->>'stock_uom', coalesce((x->>'disabled')::int, 0) = 1, nullif(x->>'modified', '')::timestamptz
    from jsonb_array_elements(d) x
  on conflict (item_code) do update set item_name = excluded.item_name, item_group = excluded.item_group, stock_uom = excluded.stock_uom,
    disabled = excluded.disabled, modified = excluded.modified;
  n2 := jsonb_array_length(d);

  -- Lotes: a quantidade muda sem mexer sempre no "modified"; vem tudo.
  d := erp.api_lista('Batch', '["name","item","expiry_date","batch_qty","disabled","modified"]', '[]');
  insert into erp.stock_lote as l (name, item, expiry_date, batch_qty, disabled, modified)
  select x->>'name', x->>'item', nullif(x->>'expiry_date', '')::date, (x->>'batch_qty')::numeric, coalesce((x->>'disabled')::int, 0) = 1, nullif(x->>'modified', '')::timestamptz
    from jsonb_array_elements(d) x
  on conflict (name) do update set item = excluded.item, expiry_date = excluded.expiry_date, batch_qty = excluded.batch_qty,
    disabled = excluded.disabled, modified = excluded.modified;
  n3 := jsonb_array_length(d);

  update erp.stock_estado set sincronizado_em = now(), erro = null where id = 1;
  return format('movimentos %s, artigos %s, lotes %s', n1, n2, n3);
exception when others then
  update erp.stock_estado set erro = left(sqlerrm, 500) where id = 1;
  return 'erro: ' || left(sqlerrm, 200);
end $function$;
revoke all on function erp.sincronizar_stock() from public, anon, authenticated;

-- Quem ve que armazem. A gestao (Direccao e Coordenacao) ve todos.
create table if not exists public.stock_responsaveis (
  user_id text not null,
  armazem text not null,
  primary key (user_id, armazem)
);
alter table public.stock_responsaveis enable row level security;
drop policy if exists stock_responsaveis_ler on public.stock_responsaveis;
create policy stock_responsaveis_ler on public.stock_responsaveis for select to authenticated using (true);
revoke insert, update, delete on public.stock_responsaveis from anon, authenticated;
insert into public.stock_responsaveis (user_id, armazem) values
  ('u2', '*'),                -- Arlete Tatiana Tchinguli (Administração): todos
  ('u17', 'FARMÁCIA - CBL')   -- Solange Orlando (Chefe da Farmácia)
on conflict do nothing;

create or replace function public.bsp_ve_stock(p_armazem text default null)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.bsp_meu_id() is not null and not public.bsp_e_socio() and (
    public.bsp_e_gestor()
    or exists (select 1 from public.stock_responsaveis r
                where r.user_id = public.bsp_meu_id() and (r.armazem = '*' or p_armazem is null or r.armazem = p_armazem)))
$function$;
grant execute on function public.bsp_ve_stock(text) to authenticated;

-- O relatorio: um artigo por armazem, com saldo, consumo e lotes.
create or replace function public.bsp_stock()
returns table (armazem text, artigo text, nome text, grupo text, unidade text, qtd numeric, valor_unit numeric,
               saidas_30d numeric, dias numeric, ultimo date, lote_validade date, lote_qtd numeric, estado text)
language sql
stable
security definer
set search_path to 'public', 'erp'
as $function$
  -- Armazéns que a pessoa vê, calculados uma vez (01-10-2026): com o filtro
  -- por linha, o planeador chamava bsp_ve_stock para cada movimento (10 mil
  -- chamadas, 10 s) e o ecrã Stock caía no limite de 8 s. O «offset 0»
  -- impede que o filtro desça para a leitura dos movimentos.
  with arm as materialized (
    select w from (select distinct m.warehouse w from erp.stock_mov m offset 0) x where public.bsp_ve_stock(w)
  ), saldo as (
    select distinct on (m.item_code, m.warehouse) m.item_code, m.warehouse, m.qty_after, m.valuation_rate, m.posting_date
      from erp.stock_mov m
     where not m.is_cancelled and m.warehouse in (select w from arm)
     order by m.item_code, m.warehouse, m.posting_date desc, m.posting_time desc nulls last, m.creation desc nulls last
  ), saidas as (
    select m.item_code, m.warehouse, sum(-m.actual_qty) s
      from erp.stock_mov m
     where not m.is_cancelled and m.actual_qty < 0 and m.posting_date >= (now() at time zone 'Africa/Luanda')::date - 30
     group by 1, 2
  ), lote as (
    select distinct on (l.item) l.item, l.expiry_date, l.batch_qty
      from erp.stock_lote l
     where not l.disabled and coalesce(l.batch_qty, 0) > 0 and l.expiry_date is not null
     order by l.item, l.expiry_date
  )
  select s.warehouse, s.item_code, coalesce(a.item_name, s.item_code), a.item_group, a.stock_uom,
         round(coalesce(s.qty_after, 0), 2), round(s.valuation_rate, 2), round(coalesce(x.s, 0), 2),
         case when coalesce(x.s, 0) > 0 then round(greatest(s.qty_after, 0) / (x.s / 30.0), 1) end,
         s.posting_date, lo.expiry_date, lo.batch_qty,
         case
           when coalesce(s.qty_after, 0) <= 0 and coalesce(x.s, 0) > 0 then 'esgotado'
           when coalesce(x.s, 0) > 0 and s.qty_after / (x.s / 30.0) < 7 then 'a-acabar'
           when lo.expiry_date is not null and lo.expiry_date <= (now() at time zone 'Africa/Luanda')::date + 60 and coalesce(s.qty_after, 0) > 0 then 'a-caducar'
           else 'ok' end
    from saldo s
    left join erp.stock_artigo a on a.item_code = s.item_code
    left join saidas x on x.item_code = s.item_code and x.warehouse = s.warehouse
    left join lote lo on lo.item = s.item_code
   where not coalesce(a.disabled, false)
     and (coalesce(s.qty_after, 0) <> 0 or coalesce(x.s, 0) > 0)
$function$;
grant execute on function public.bsp_stock() to authenticated;

-- Os alertas (para o sino e o Inicio): contagens por armazem.
create or replace function public.bsp_stock_resumo()
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'erp'
as $function$
  select jsonb_build_object(
    'sincronizado_em', (select sincronizado_em from erp.stock_estado where id = 1),
    'armazens', coalesce((select jsonb_agg(jsonb_build_object('armazem', armazem, 'esgotado', e, 'a_acabar', a, 'a_caducar', c, 'artigos', n) order by armazem)
      from (select armazem, count(*) filter (where estado = 'esgotado') e, count(*) filter (where estado = 'a-acabar') a,
                   count(*) filter (where estado = 'a-caducar') c, count(*) n
              from public.bsp_stock() group by armazem) q), '[]'::jsonb))
  where public.bsp_ve_stock()
$function$;
grant execute on function public.bsp_stock_resumo() to authenticated;

-- Agendamento: a cada 15 minutos.
select cron.unschedule('bsp-stock') where exists (select 1 from cron.job where jobname = 'bsp-stock');
select cron.schedule('bsp-stock', '*/15 * * * *', 'set statement_timeout to ''5min''; select erp.sincronizar_stock();');

notify pgrst, 'reload schema';
