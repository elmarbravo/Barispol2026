-- Barispol Workspace · validades dos produtos por lote e por armazém
-- Pergunta do Elmar, 01-10-2026: «O prazo de validade dos produtos convém que
-- apareçam, não?». Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no
-- mesmo dia. Pode correr-se mais do que uma vez.
--
-- Antes: só o lote que caducava primeiro, com a quantidade do lote em todos
-- os armazéns (erp.stock_lote.batch_qty). Agora:
--   - cada movimento guarda o lote (erp.stock_mov.batch_no; a sincronização
--     de 15 em 15 minutos já o traz; erp.stock_preencher_lotes encheu o
--     histórico uma vez);
--   - quantidade de cada lote em cada armazém = soma dos movimentos;
--   - estado «caducado» (lote com quantidade e validade passada) antes de
--     todos os outros;
--   - bsp_stock_lotes(): um lote por linha, para a lista «Validades».

alter table erp.stock_mov add column if not exists batch_no text;
create index if not exists stock_mov_lote on erp.stock_mov (item_code, warehouse, batch_no) where batch_no is not null;

-- (erp.sincronizar_stock: o campo batch_no entrou na lista de campos e no
-- insert/update; ver stock.sql.)

create or replace function erp.stock_preencher_lotes()
returns text
language plpgsql
security definer
set search_path to 'erp', 'public'
as $function$
declare d jsonb; n int;
begin
  d := erp.api_lista('Stock Ledger Entry', '["name","batch_no"]', '[["batch_no","is","set"]]');
  update erp.stock_mov m set batch_no = x->>'batch_no'
    from jsonb_array_elements(d) x
   where m.name = x->>'name' and m.batch_no is distinct from x->>'batch_no';
  get diagnostics n = row_count;
  return format('%s movimentos com lote no MetaGest, %s preenchidos', jsonb_array_length(d), n);
end $function$;
revoke all on function erp.stock_preencher_lotes() from public, anon, authenticated;

-- Lotes com quantidade, por armazém. Mesmo acesso de bsp_stock.
create or replace function public.bsp_stock_lotes()
returns table(armazem text, artigo text, nome text, unidade text, lote text, validade date, qtd numeric, dias integer, estado text)
language sql
stable
security definer
set search_path to 'public', 'erp'
as $function$
  with arm as materialized (
    select w from (select distinct m.warehouse w from erp.stock_mov m offset 0) x where public.bsp_ve_stock(w)
  ), hoje as (select (now() at time zone 'Africa/Luanda')::date d),
  l as (
    select m.item_code, m.warehouse, m.batch_no, sum(m.actual_qty) q
      from erp.stock_mov m
     where not m.is_cancelled and m.batch_no is not null and m.warehouse in (select w from arm)
     group by 1, 2, 3
    having sum(m.actual_qty) > 0.0001
  )
  select l.warehouse, l.item_code, coalesce(a.item_name, l.item_code), a.stock_uom, l.batch_no, b.expiry_date,
         round(l.q, 2), (b.expiry_date - (select d from hoje))::int,
         case when b.expiry_date is null then 'sem-validade'
              when b.expiry_date < (select d from hoje) then 'caducado'
              when b.expiry_date <= (select d from hoje) + 60 then 'a-caducar'
              else 'ok' end
    from l
    left join erp.stock_lote b on b.name = l.batch_no
    left join erp.stock_artigo a on a.item_code = l.item_code
   where not coalesce(a.disabled, false)
$function$;
revoke all on function public.bsp_stock_lotes() from public, anon;
grant execute on function public.bsp_stock_lotes() to authenticated;

-- bsp_stock: o lote mais próximo passa a ser o do armazém, com a quantidade
-- do lote nesse armazém; estado «caducado» primeiro.
create or replace function public.bsp_stock()
returns table(armazem text, artigo text, nome text, grupo text, unidade text, qtd numeric, valor_unit numeric, saidas_30d numeric, dias numeric, ultimo date, lote_validade date, lote_qtd numeric, estado text)
language sql
stable
security definer
set search_path to 'public', 'erp'
as $function$
  -- Armazéns que a pessoa vê, calculados uma vez (ver stock.sql).
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
  ), lotes as (
    select m.item_code, m.warehouse, m.batch_no, sum(m.actual_qty) q
      from erp.stock_mov m
     where not m.is_cancelled and m.batch_no is not null and m.warehouse in (select w from arm)
     group by 1, 2, 3
    having sum(m.actual_qty) > 0.0001
  ), lote as (
    select distinct on (x.item_code, x.warehouse) x.item_code, x.warehouse, b.expiry_date, x.q
      from lotes x join erp.stock_lote b on b.name = x.batch_no
     where b.expiry_date is not null
     order by x.item_code, x.warehouse, b.expiry_date
  )
  select s.warehouse, s.item_code, coalesce(a.item_name, s.item_code), a.item_group, a.stock_uom,
         round(coalesce(s.qty_after, 0), 2), round(s.valuation_rate, 2), round(coalesce(x.s, 0), 2),
         case when coalesce(x.s, 0) > 0 then round(greatest(s.qty_after, 0) / (x.s / 30.0), 1) end,
         s.posting_date, lo.expiry_date, round(lo.q, 2),
         case
           when lo.expiry_date is not null and lo.expiry_date < (now() at time zone 'Africa/Luanda')::date then 'caducado'
           when coalesce(s.qty_after, 0) <= 0 and coalesce(x.s, 0) > 0 then 'esgotado'
           when coalesce(x.s, 0) > 0 and s.qty_after / (x.s / 30.0) < 7 then 'a-acabar'
           when lo.expiry_date is not null and lo.expiry_date <= (now() at time zone 'Africa/Luanda')::date + 60 then 'a-caducar'
           else 'ok' end
    from saldo s
    left join erp.stock_artigo a on a.item_code = s.item_code
    left join saidas x on x.item_code = s.item_code and x.warehouse = s.warehouse
    left join lote lo on lo.item_code = s.item_code and lo.warehouse = s.warehouse
   where not coalesce(a.disabled, false)
     and (coalesce(s.qty_after, 0) <> 0 or coalesce(x.s, 0) > 0)
$function$;

-- Resumo para o Início e o sino: conta também os caducados.
create or replace function public.bsp_stock_resumo()
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'erp'
as $function$
  select jsonb_build_object(
    'sincronizado_em', (select sincronizado_em from erp.stock_estado where id = 1),
    'armazens', coalesce((select jsonb_agg(jsonb_build_object('armazem', armazem, 'caducado', c0, 'esgotado', e, 'a_acabar', a, 'a_caducar', c, 'artigos', n) order by armazem)
      from (select armazem, count(*) filter (where estado = 'caducado') c0, count(*) filter (where estado = 'esgotado') e,
                   count(*) filter (where estado = 'a-acabar') a, count(*) filter (where estado = 'a-caducar') c, count(*) n
              from public.bsp_stock() group by armazem) q), '[]'::jsonb))
  where public.bsp_ve_stock()
$function$;

notify pgrst, 'reload schema';
