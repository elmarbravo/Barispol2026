-- Barispol Workspace · painel da gestao (MetaGest quase em tempo real)
-- Pedido do Elmar, 27-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- Fontes:
--   · dias anteriores: crm.mg_facturas / mg_factura_itens / mg_consultas
--     (historico desde 2022, sincronizado as 04h00 UTC);
--   · hoje: erp.sales_invoice / sales_invoice_item, que o agendamento
--     bsp-painel-hoje vai buscar a API do MetaGest de 5 em 5 minutos.
--   As duas fontes batem ao centimo (conferido em Setembro de 2026).
-- Quem ve: so a gestao (bsp_e_gestor: Direccao e Coordenacao). Sao dados de
-- facturacao: nao saem do servidor, e o painel nao mostra nomes de doentes.

-- Hoje, de 5 em 5 minutos, das 06h00 as 22h00 de Luanda (05h-20h UTC).
create or replace function public.bsp_painel_sincronizar_hoje()
returns text
language plpgsql
security definer
set search_path to 'public', 'erp'
as $function$
declare hoje date := (now() at time zone 'Africa/Luanda')::date; a int; b int;
begin
  a := erp.sync_sales_invoices(hoje, hoje);
  b := erp.sync_sales_invoice_items(hoje, hoje);
  return hoje || ': ' || a || ' facturas, ' || b || ' linhas';
end $function$;
revoke all on function public.bsp_painel_sincronizar_hoje() from public, anon, authenticated;

select cron.unschedule('bsp-painel-hoje') where exists (select 1 from cron.job where jobname = 'bsp-painel-hoje');
select cron.schedule('bsp-painel-hoje', '*/5 5-20 * * *', 'set statement_timeout to ''2min''; select public.bsp_painel_sincronizar_hoje();');

-- O registo de sincronizacoes cresce 2 linhas a cada 5 minutos: guarda-se
-- um mes.
select cron.unschedule('bsp-painel-limpeza') where exists (select 1 from cron.job where jobname = 'bsp-painel-limpeza');
select cron.schedule('bsp-painel-limpeza', '20 3 * * 0', 'delete from erp.sync_log where started_at < now() - interval ''30 days'';');

-- O painel, para um periodo [p_de, p_ate].
create or replace function public.bsp_painel(p_de date, p_ate date)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'crm', 'erp'
as $function$
declare
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  dias int := p_ate - p_de + 1;
  ant_de date := p_de - (p_ate - p_de + 1);
  ant_ate date := p_de - 1;
  res jsonb;
begin
  if not public.bsp_e_gestor() then raise exception 'Só a gestão vê o painel.'; end if;
  if p_ate < p_de or dias > 800 then raise exception 'Período inválido.'; end if;

  with
  -- Facturas: historico ate ontem, hoje em directo.
  f as (
    select data, coalesce(paciente, cliente, id) quem, total, grupo_cliente grupo, id, 'crm' fonte
      from crm.mg_facturas where data between ant_de and least(p_ate, hoje - 1)
    union all
    select posting_date, coalesce(patient, customer, name), grand_total, customer_group, name, 'erp'
      from erp.sales_invoice where docstatus = 1 and posting_date = hoje and hoje between ant_de and p_ate
  ),
  fp as (select * from f where data between p_de and p_ate),
  fa as (select * from f where data between ant_de and ant_ate),
  it as (
    select i.grupo, i.valor from crm.mg_factura_itens i join fp on fp.id = i.factura and fp.fonte = 'crm'
    union all
    select i.item_group, i.amount from erp.sales_invoice_item i join fp on fp.id = i.parent and fp.fonte = 'erp'
  ),
  resumo as (
    select
      coalesce(sum(total), 0) facturado,
      count(*) filter (where total >= 0) facturas,
      count(*) filter (where total < 0) devolucoes,
      coalesce(-sum(total) filter (where total < 0), 0) devolvido,
      count(distinct (data, quem)) filter (where total > 0) atendimentos,
      count(distinct quem) filter (where total > 0) pacientes
    from fp
  ),
  resumo_ant as (
    select coalesce(sum(total), 0) facturado,
           count(distinct (data, quem)) filter (where total > 0) atendimentos,
           count(*) filter (where total >= 0) facturas
    from fa
  ),
  serie as (
    select d::date dia,
           coalesce((select sum(total) from fp where fp.data = d::date), 0) facturado,
           coalesce((select count(distinct quem) from fp where fp.data = d::date and total > 0), 0) atendimentos
      from generate_series(p_de, least(p_ate, hoje), interval '1 day') d
  ),
  areas as (
    select coalesce(nullif(btrim(grupo), ''), 'Outros') area, sum(valor) valor, count(*) actos
      from it group by 1 order by 2 desc
  ),
  clientes as (
    select case grupo when 'Individual' then 'Particular' when 'Seguradora' then 'Seguro'
                      when 'Commercial' then 'Empresas' else 'Outros' end tipo,
           sum(total) filter (where total > 0) valor, count(*) filter (where total > 0) n
      from fp group by 1
  ),
  medicos as (
    select medico, count(*) consultas from (
      select c.medico from crm.mg_consultas c where c.data between p_de and least(p_ate, hoje - 1)
      union all
      select s.practitioner_name from erp.sales_invoice s
       where s.docstatus = 1 and not s.is_return and s.posting_date = hoje and hoje between p_de and p_ate
         and s.practitioner_name is not null
    ) m where coalesce(btrim(medico), '') <> '' group by 1 order by 2 desc limit 12
  ),
  horas as (
    select extract(hour from s.posting_time)::int hora, count(*) n, sum(s.grand_total) valor
      from erp.sales_invoice s
     where s.docstatus = 1 and not s.is_return and s.posting_date between p_de and p_ate and s.posting_time is not null
     group by 1 order by 1
  ),
  divida as (
    select coalesce(sum(outstanding_amount), 0) valor, count(*) filter (where outstanding_amount > 0) n
      from erp.sales_invoice where docstatus = 1 and posting_date between p_de and p_ate
  ),
  marc as (
    select estado, count(*) n from public.marcacoes where data_marcada between p_de and p_ate group by 1
  )
  select jsonb_build_object(
    'de', p_de, 'ate', p_ate, 'hoje', hoje, 'ant_de', ant_de, 'ant_ate', ant_ate,
    'resumo', (select to_jsonb(resumo) from resumo),
    'anterior', (select to_jsonb(resumo_ant) from resumo_ant),
    'serie', (select coalesce(jsonb_agg(to_jsonb(serie) order by dia), '[]') from serie),
    'areas', (select coalesce(jsonb_agg(to_jsonb(areas)), '[]') from areas),
    'clientes', (select coalesce(jsonb_agg(to_jsonb(clientes)), '[]') from clientes),
    'medicos', (select coalesce(jsonb_agg(to_jsonb(medicos)), '[]') from medicos),
    'horas', (select coalesce(jsonb_agg(to_jsonb(horas)), '[]') from horas),
    'horas_desde', (select min(posting_date) from erp.sales_invoice),
    'divida', (select to_jsonb(divida) from divida),
    'marcacoes', (select coalesce(jsonb_object_agg(estado, n), '{}') from marc),
    'actualizado', (select max(synced_at) from erp.sales_invoice where posting_date = hoje),
    'sincronizado', (select max(started_at) from erp.sync_log where ok is not false and doctype = 'Sales Invoice' and date_to = hoje)
  ) into res;
  return res;
end $function$;
revoke all on function public.bsp_painel(date, date) from public, anon;
grant execute on function public.bsp_painel(date, date) to authenticated;

notify pgrst, 'reload schema';
