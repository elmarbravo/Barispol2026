-- Painel: «ontem» a 0 Kz depois da meia-noite (05-10-2026, Elmar: «O sistema
-- está a dar 0 kzs no dia 5»).
--
-- O Painel lia os dias passados só do histórico (crm.mg_facturas), carregado
-- às 05h00 de Luanda, e só o dia de hoje da cópia do MetaGest
-- (erp.sales_invoice). Entre a meia-noite e a carga, o dia anterior ficava a 0.
-- Agora todo o dia depois do último dia do histórico («corte») vem da cópia do
-- MetaGest. Conferido: 1 a 4 de Outubro iguais nas duas fontes; dia 5 = 397 625 Kz.

CREATE OR REPLACE FUNCTION public.bsp_painel(p_de date, p_ate date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'crm', 'erp'
AS $function$
declare
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  dias int := p_ate - p_de + 1;
  ant_de date := p_de - (p_ate - p_de + 1);
  ant_ate date := p_de - 1;
  -- Último dia já no histórico (crm.mg_facturas, carregado às 05h00). Os dias
  -- depois dele vêm da cópia do MetaGest: depois da meia-noite, «ontem» dava 0 Kz
  -- até à carga (05-10-2026).
  corte date := least(coalesce((select max(data) from crm.mg_facturas), (now() at time zone 'Africa/Luanda')::date - 1), (now() at time zone 'Africa/Luanda')::date - 1);
  res jsonb;
begin
  if not public.bsp_ve_painel() then raise exception 'Sem acesso ao painel.'; end if;
  if p_ate < p_de or dias > 800 then raise exception 'Período inválido.'; end if;

  with
  f as (
    select data, coalesce(paciente, cliente, id) quem, total, grupo_cliente grupo, id, 'crm' fonte
      from crm.mg_facturas where data between ant_de and least(p_ate, corte)
    union all
    select posting_date, coalesce(patient, customer, name), grand_total, customer_group, name, 'erp'
      from erp.sales_invoice where docstatus = 1 and posting_date > corte and posting_date <= hoje and posting_date between ant_de and p_ate
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
           coalesce((select count(distinct quem) from fp where fp.data = d::date and total > 0), 0) atendimentos,
           coalesce((select -sum(total) from fp where fp.data = d::date and total < 0), 0) notas_credito
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
  fm as (
    select s.name, s.posting_date, s.ref_practitioner, s.practitioner_name, s.grand_total,
           coalesce(s.patient, s.customer, s.name) quem,
           exists (select 1 from erp.sales_invoice_item i where i.parent = s.name
                    and coalesce(i.item_group, '') ~* 'CONSULTA' and i.amount > 0) tem_consulta
      from erp.sales_invoice s
     where s.docstatus = 1 and not s.is_return and s.posting_date between p_de and p_ate
       and s.ref_practitioner is not null
       and coalesce(btrim(s.practitioner_name), '') not in ('', 'EXTERNO')
       and not exists (select 1 from erp.sales_invoice r where r.docstatus = 1 and r.is_return and r.return_against = s.name)
  ),
  medicos as (
    select max(practitioner_name) medico,
           count(distinct (posting_date, quem)) filter (where tem_consulta) consultas,
           count(distinct (posting_date, quem)) - count(distinct (posting_date, quem)) filter (where tem_consulta) exames,
           coalesce(sum(grand_total), 0) valor
      from fm
     group by ref_practitioner order by 2 desc, 3 desc, 4 desc limit 15
  ),
  seguradoras as (
    select btrim(s.seguradora) seguradora, count(*) n,
           coalesce(sum(s.grand_total), 0) valor, coalesce(sum(s.copagamento), 0) copagamento
      from erp.sales_invoice s
     where s.docstatus = 1 and not s.is_return and s.posting_date between p_de and p_ate
       and coalesce(btrim(s.seguradora), '') <> ''
     group by 1 order by 3 desc, 2 desc limit 15
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
  notas as (
    select fp.id numero, fp.data, -fp.total valor, s.return_against anula
      from fp left join erp.sales_invoice s on s.name = fp.id
     where fp.total < 0
     order by fp.data desc, fp.id desc limit 100
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
    'seguradoras', (select coalesce(jsonb_agg(to_jsonb(seguradoras)), '[]') from seguradoras),
    'horas', (select coalesce(jsonb_agg(to_jsonb(horas)), '[]') from horas),
    'horas_desde', (select min(posting_date) from erp.sales_invoice),
    'divida', (select to_jsonb(divida) from divida),
    'marcacoes', (select coalesce(jsonb_object_agg(estado, n), '{}') from marc),
    'notas_credito', (select coalesce(jsonb_agg(to_jsonb(notas) order by notas.data desc, notas.numero desc), '[]') from notas),
    'actualizado', (select max(synced_at) from erp.sales_invoice where posting_date = hoje),
    'sincronizado', (select max(started_at) from erp.sync_log where ok is not false and doctype = 'Sales Invoice' and date_to = hoje)
  ) into res;
  return res;
end $function$;

notify pgrst, 'reload schema';
