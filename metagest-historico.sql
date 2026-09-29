-- Barispol Workspace · historico do MetaGest em erp.sales_invoice
-- Pedido do Elmar, 29-09-2026 («no painel faltam dados, ontem teve mais
-- medicos»). Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo
-- dia. Pode correr-se mais do que uma vez.
--
-- crm.mg_consultas tem so uma parte das consultas (28-09-2026: 4 consultas
-- e 1 medico; as facturas desse dia tinham 5 medicos). As facturas de
-- erp.sales_invoice trazem o medico (practitioner_name, ref_practitioner),
-- a seguradora e o co-pagamento, mas so existiam desde 01-09-2026. Esta
-- fila traz o resto, de Agosto de 2022 a Agosto de 2026, um mes por
-- minuto (a API do MetaGest demora; uma so chamada passava do limite).
-- Quando a fila acaba, o agendamento apaga-se sozinho. O documento
-- original (raw) so fica guardado desde Setembro de 2026, para poupar
-- espaco.

create table if not exists erp.historico_fila (
  mes date primary key,
  feito_em timestamptz,
  facturas integer,
  itens integer,
  erro text
);
insert into erp.historico_fila (mes)
select d::date from generate_series(date '2022-08-01', date '2026-08-01', interval '1 month') d
on conflict (mes) do nothing;

create or replace function erp.historico_um_mes()
returns text
language plpgsql
security definer
set search_path to 'erp', 'public'
as $function$
declare m date; a int; b int;
begin
  select mes into m from erp.historico_fila where feito_em is null order by mes desc limit 1;
  if m is null then
    perform cron.unschedule('bsp-metagest-historico');
    return 'fila vazia';
  end if;
  begin
    a := erp.sync_sales_invoices(m, (m + interval '1 month' - interval '1 day')::date);
    b := erp.sync_sales_invoice_items(m, (m + interval '1 month' - interval '1 day')::date);
    -- O documento original completo so se guarda desde Setembro de 2026.
    update erp.sales_invoice set raw = null where posting_date between m and (m + interval '1 month' - interval '1 day')::date and posting_date < date '2026-09-01';
    update erp.sales_invoice_item set raw = null where posting_date between m and (m + interval '1 month' - interval '1 day')::date and posting_date < date '2026-09-01';
    update erp.historico_fila set feito_em = now(), facturas = a, itens = b, erro = null where mes = m;
  exception when others then
    update erp.historico_fila set erro = sqlerrm, feito_em = now() where mes = m;
  end;
  return m::text;
end $function$;
revoke all on function erp.historico_um_mes() from public, anon, authenticated;

select cron.unschedule('bsp-metagest-historico') where exists (select 1 from cron.job where jobname = 'bsp-metagest-historico');
select cron.schedule('bsp-metagest-historico', '* * * * *', 'set statement_timeout to ''5min''; select erp.historico_um_mes();')
 where exists (select 1 from erp.historico_fila where feito_em is null);

-- Ver o andamento:
--   select mes, feito_em, facturas, itens, erro from erp.historico_fila order by mes desc;
