-- Stock geral: alerta mais cedo nos artigos com mais saídas (16-10-2026,
-- Elmar). Os 10 artigos com mais saídas em 30 dias no Stock geral passam a
-- «A acabar» com menos de 14 dias de stock (os outros continuam a 7).
-- Igual no ecrã: bspStockMaisSaidas (BSP_STOCK_TOPO, BSP_STOCK_TOPO_DIAS).
-- Corre-se depois de stock-validades.sql (é a mesma função, com o «topo»).
-- O bsp_stock_resumo (Início e sino) lê esta função: passa a contar igual.
-- POR APLICAR (o conector do Supabase estava noutra conta a 16-10-2026).

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
  ), topo as (
    -- Stock geral: os 10 artigos com mais saídas em 30 dias (alerta a 14 dias).
    select item_code, warehouse from (
      select item_code, warehouse, row_number() over (partition by warehouse order by s desc) n
        from saidas where warehouse ilike 'STOCK GERAL%' and s > 0) q
     where n <= 10
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
           when coalesce(x.s, 0) > 0 and s.qty_after / (x.s / 30.0) < (case when tp.item_code is not null then 14 else 7 end) then 'a-acabar'
           when lo.expiry_date is not null and lo.expiry_date <= (now() at time zone 'Africa/Luanda')::date + 60 then 'a-caducar'
           else 'ok' end
    from saldo s
    left join erp.stock_artigo a on a.item_code = s.item_code
    left join saidas x on x.item_code = s.item_code and x.warehouse = s.warehouse
    left join lote lo on lo.item_code = s.item_code and lo.warehouse = s.warehouse
    left join topo tp on tp.item_code = s.item_code and tp.warehouse = s.warehouse
   where not coalesce(a.disabled, false)
     and (coalesce(s.qty_after, 0) <> 0 or coalesce(x.s, 0) > 0)
$function$;

notify pgrst, 'reload schema';
