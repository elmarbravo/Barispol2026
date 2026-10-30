-- Painel financeiro: nomes, dinheiro e alertas (30-10-2026, auditoria pedida
-- pelo Elmar: «sinto que faltam coisas financeiras, nomes, alertas» → «sim, os
-- 12, alerta a partir de 50 000 Kz» → «a soma de notas de crédito que passe de
-- 30 mil no dia, com a respectiva emissora da factura principal»).
-- bsp_painel passa a devolver, além do que já tinha:
--   recebido      já pago das facturas do período (total − em falta)
--   descontos     descontos dados (n, valor) e os de 50 000 Kz ou mais
--   pessoas       facturação por quem emitiu (owner do MetaGest), descontos e as
--                 notas de crédito contadas a quem emitiu a factura anulada
--   homologo      mesmo período do ano anterior (crm.mg_facturas)
--   notas_credito cada nota com quem emitiu a factura anulada e o motivo
--   alertas       notas de crédito acima de 30 000 Kz no dia, descontos de
--                 50 000 Kz ou mais, particulares por pagar, rascunhos no
--                 MetaGest, seguradoras com mais de 90 dias, dia abaixo do
--                 normal, facturas sem grupo de cliente, MetaGest parado
-- «All Customer Groups» (cliente sem grupo no MetaGest, sempre com utente)
-- conta como Particular; o alerta diz quantas são, para corrigir a ficha.
-- bsp_financeiro_alertar(): telemóvel do Elmar (u1) e do departamento
-- Financeiro, de 30 em 30 min (cron bsp-financeiro-alertas, minutos 19 e 49,
-- livres): notas de crédito do dia acima de 30 000 Kz, descontos de 50 000 Kz
-- ou mais e, às 19h00, os particulares do dia por pagar. Uma vez cada
-- (financeiro_avisos). Nunca nomes de utentes; os nomes são da equipa.
-- Limites: BSP_FIN_LIMITE_NC (30 000) e BSP_FIN_LIMITE_DESC (50 000) no ecrã;
-- mudar os dois lados juntos.

create table if not exists public.financeiro_avisos (
  chave text primary key,
  criado timestamptz not null default now()
);
alter table public.financeiro_avisos enable row level security;
revoke all on public.financeiro_avisos from anon, authenticated;

-- Nome da equipa (nome e apelido) a partir do e-mail do MetaGest (owner);
-- sem ficha, a parte antes do @.
create or replace function public.bsp_fin_pessoa(p_email text)
returns text language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(
    (select case when array_length(regexp_split_to_array(btrim(x->>'name'), '\s+'), 1) > 2
                 then split_part(btrim(x->>'name'), ' ', 1) || ' ' || (regexp_split_to_array(btrim(x->>'name'), '\s+'))[array_length(regexp_split_to_array(btrim(x->>'name'), '\s+'), 1)]
                 else btrim(x->>'name') end
       from shared_state s, jsonb_array_elements(s.team) x
      where lower(x->>'email') = lower(p_email) limit 1),
    nullif(split_part(coalesce(p_email, ''), '@', 1), ''), '—');
$f$;
revoke all on function public.bsp_fin_pessoa(text) from public, anon, authenticated;

-- «NOSSA SEGUROS - NOVA SOCIEDADE…, S.A.» → «NOSSA SEGUROS» (como bspNomeSeguradora).
create or replace function public.bsp_fin_seguradora(p text)
returns text language sql immutable
as $f$
  select coalesce(nullif(btrim(regexp_replace(split_part(split_part(coalesce(p, ''), ' - ', 1), ',', 1), '\s+S\.?\s?A\.?\s*$', '', 'i')), ''), p);
$f$;

create or replace function public.bsp_fin_n(v numeric)
returns text language sql immutable
as $f$
  -- Espaço que não parte (chr(160)): «92 797» nunca muda de linha a meio.
  select replace(to_char(round(coalesce(v, 0)), 'FM999G999G999G990'), ',', chr(160));
$f$;

create or replace function public.bsp_fin_desconto(raw jsonb)
returns numeric language sql immutable
as $f$
  select coalesce(public.bsp_num(raw->>'discount_amount'), 0) + coalesce(public.bsp_num(raw->>'total_desconto_linha'), 0);
$f$;

create or replace function public.bsp_fin_alertas(p_de date, p_ate date)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'erp'
as $f$
declare
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  hora int := extract(hour from now() at time zone 'Africa/Luanda');
  al jsonb := '[]'::jsonb; r record; v numeric; m numeric; n int; txt text; sinc timestamptz;
begin
  -- 1. Notas de crédito acima de 30 000 Kz num dia, com quem emitiu a factura anulada.
  for r in
    with nc as (
      select x.posting_date dia, -x.grand_total valor, public.bsp_fin_pessoa(o.owner) quem
        from erp.sales_invoice x left join erp.sales_invoice o on o.name = x.return_against
       where x.docstatus = 1 and x.is_return and x.posting_date between p_de and p_ate),
    d as (select dia, sum(valor) total, count(*) n from nc group by dia having sum(valor) > 30000),
    q as (select dia, quem, count(*) k, sum(valor) v from nc group by dia, quem)
    select d.dia, d.total, d.n,
           (select string_agg(q.quem || ' (' || q.k || ', ' || public.bsp_fin_n(q.v) || ' Kz)', ', ' order by q.v desc)
              from q where q.dia = d.dia) quem
      from d order by d.dia desc limit 10
  loop
    al := al || jsonb_build_object('nivel', 'perigo', 'tipo', 'notas',
      'texto', to_char(r.dia, 'DD-MM') || ': notas de crédito somam ' || public.bsp_fin_n(r.total) || ' Kz em '
        || r.n || (case when r.n = 1 then ' nota' else ' notas' end) || '. Facturas anuladas emitidas por ' || coalesce(r.quem, '—') || '.');
  end loop;

  -- 2. Descontos de 50 000 Kz ou mais.
  for r in
    select x.posting_date dia, x.name, public.bsp_fin_desconto(x.raw) d, public.bsp_fin_pessoa(x.owner) quem
      from erp.sales_invoice x
     where x.docstatus = 1 and not x.is_return and x.posting_date between p_de and p_ate
       and public.bsp_fin_desconto(x.raw) >= 50000
     order by x.posting_date desc, x.name desc limit 10
  loop
    al := al || jsonb_build_object('nivel', 'perigo', 'tipo', 'desconto',
      'texto', to_char(r.dia, 'DD-MM') || ': desconto de ' || public.bsp_fin_n(r.d) || ' Kz na factura ' || r.name || ', emitida por ' || r.quem || '.');
  end loop;

  -- 3. Particulares com factura por pagar (últimos 180 dias).
  select count(*), coalesce(sum(outstanding_amount), 0), max(hoje - posting_date)
    into n, v, m
    from erp.sales_invoice
   where docstatus = 1 and not is_return and outstanding_amount > 0 and posting_date >= hoje - 180
     and (customer_group = 'Individual' or (customer_group = 'All Customer Groups' and coalesce(btrim(seguradora), '') = ''));
  if n > 0 then
    select string_agg(quem || ' (' || k || ')', ', ' order by k desc) into txt from (
      select public.bsp_fin_pessoa(owner) quem, count(*) k from erp.sales_invoice
       where docstatus = 1 and not is_return and outstanding_amount > 0 and posting_date >= hoje - 180
         and (customer_group = 'Individual' or (customer_group = 'All Customer Groups' and coalesce(btrim(seguradora), '') = ''))
       group by owner order by 2 desc limit 5) z;
    al := al || jsonb_build_object('nivel', 'aviso', 'tipo', 'particulares',
      'texto', 'Particulares com factura por pagar nos últimos 6 meses: ' || n || (case when n = 1 then ' factura, ' else ' facturas, ' end)
        || public.bsp_fin_n(v) || ' Kz; a mais antiga tem ' || m || ' dias. Emitidas por ' || coalesce(txt, '—') || '.');
  end if;

  -- 4. Facturas em rascunho no MetaGest (60 dias).
  select count(*), coalesce(sum(grand_total), 0) into n, v
    from erp.sales_invoice where docstatus = 0 and posting_date >= hoje - 60;
  if n > 0 then
    select string_agg(quem || ' (' || k || ')', ', ' order by k desc) into txt from (
      select public.bsp_fin_pessoa(owner) quem, count(*) k from erp.sales_invoice
       where docstatus = 0 and posting_date >= hoje - 60 group by owner) z;
    al := al || jsonb_build_object('nivel', 'aviso', 'tipo', 'rascunhos',
      'texto', 'Facturas em rascunho no MetaGest, por submeter: ' || n || ' (' || public.bsp_fin_n(v) || ' Kz), de ' || coalesce(txt, '—') || '.');
  end if;

  -- 5. Seguradoras com dívida vencida há mais de 90 dias.
  select string_agg(s || ' ' || public.bsp_fin_n(t) || ' Kz', '; ' order by t desc), sum(t)
    into txt, v from (
    select public.bsp_fin_seguradora(coalesce(nullif(btrim(seguradora), ''), customer_name, customer)) s, sum(outstanding_amount) t
      from erp.sales_invoice
     where docstatus = 1 and not is_return and outstanding_amount > 0 and customer_group = 'Seguradora'
       and coalesce(nullif(raw->>'due_date', '')::date, posting_date + 30) < hoje - 90
     group by 1 order by 2 desc limit 5) z;
  if v > 0 then
    al := al || jsonb_build_object('nivel', 'perigo', 'tipo', 'seguradoras',
      'texto', 'Seguradoras com dívida vencida há mais de 90 dias: ' || txt || '.');
  end if;

  -- 6. Ontem abaixo do normal: menos de 60% da média do mesmo dia da semana
  --    nas 4 semanas anteriores.
  select coalesce(sum(grand_total), 0) into v from erp.sales_invoice where docstatus = 1 and posting_date = hoje - 1;
  select avg(t) into m from (
    select k, coalesce((select sum(grand_total) from erp.sales_invoice where docstatus = 1 and posting_date = hoje - 1 - 7 * k), 0) t
      from generate_series(1, 4) k) z;
  if m > 0 and v < 0.6 * m then
    al := al || jsonb_build_object('nivel', 'aviso', 'tipo', 'dia',
      'texto', 'Ontem (' || to_char(hoje - 1, 'DD-MM') || ') facturou-se ' || public.bsp_fin_n(v) || ' Kz, '
        || round(100 * v / m) || '% da média do mesmo dia nas 4 semanas anteriores (' || public.bsp_fin_n(m) || ' Kz).');
  end if;

  -- 7. Facturas sem grupo de cliente no período (contam como particulares).
  select count(*) into n from erp.sales_invoice
   where docstatus = 1 and not is_return and posting_date between p_de and p_ate and customer_group = 'All Customer Groups';
  if n > 0 then
    select string_agg(quem || ' (' || k || ')', ', ' order by k desc) into txt from (
      select public.bsp_fin_pessoa(owner) quem, count(*) k from erp.sales_invoice
       where docstatus = 1 and not is_return and posting_date between p_de and p_ate and customer_group = 'All Customer Groups'
       group by owner order by 2 desc limit 5) z;
    al := al || jsonb_build_object('nivel', 'info', 'tipo', 'sem-grupo',
      'texto', n || (case when n = 1 then ' factura' else ' facturas' end) || ' de clientes sem grupo no MetaGest, contadas como particulares. Corrigir a ficha do cliente. Emitidas por ' || coalesce(txt, '—') || '.');
  end if;

  -- 8. MetaGest sem actualizar (das 07h00 às 21h59).
  select max(started_at) into sinc from erp.sync_log where ok is not false and doctype = 'Sales Invoice';
  if hora between 7 and 21 and (sinc is null or sinc < now() - interval '30 minutes') then
    al := al || jsonb_build_object('nivel', 'perigo', 'tipo', 'metagest',
      'texto', 'O MetaGest não actualiza desde ' || coalesce(to_char(sinc at time zone 'Africa/Luanda', 'DD-MM HH24:MI'), 'sempre') || ': os números de hoje podem estar incompletos.');
  end if;
  return al;
end $f$;
revoke all on function public.bsp_fin_alertas(date, date) from public, anon, authenticated;

create or replace function public.bsp_painel(p_de date, p_ate date)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'public', 'crm', 'erp'
as $function$
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
    select erp.grupo_item(i.grupo, i.item_nome) grupo, i.valor from crm.mg_factura_itens i join fp on fp.id = i.factura and fp.fonte = 'crm'
    union all
    select erp.grupo_item(i.item_group, i.item_name) grupo, i.amount from erp.sales_invoice_item i join fp on fp.id = i.parent and fp.fonte = 'erp'
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
  homologo as (
    select coalesce(sum(total), 0) facturado, count(*) filter (where total >= 0) facturas,
           (p_de - interval '1 year')::date de, (p_ate - interval '1 year')::date ate
      from crm.mg_facturas where data between (p_de - interval '1 year')::date and (p_ate - interval '1 year')::date
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
  -- «All Customer Groups»: cliente sem grupo no MetaGest, sempre com utente
  -- (30-10-2026): conta como particular.
  clientes as (
    select case when grupo in ('Individual', 'All Customer Groups') then 'Particular' when grupo = 'Seguradora' then 'Seguro'
                when grupo = 'Commercial' then 'Empresas' else 'Outros' end tipo,
           sum(total) filter (where total > 0) valor, count(*) filter (where total > 0) n
      from fp group by 1
  ),
  sv as (
    select s.* from erp.sales_invoice s where s.docstatus = 1 and s.posting_date between p_de and p_ate
  ),
  recebido as (
    select coalesce(sum(greatest(0, grand_total - greatest(0, outstanding_amount))), 0) valor
      from sv where not is_return
  ),
  descontos as (
    select count(*) filter (where public.bsp_fin_desconto(raw) > 0) n,
           coalesce(sum(public.bsp_fin_desconto(raw)), 0) valor,
           count(*) filter (where public.bsp_fin_desconto(raw) >= 50000) grandes
      from sv where not is_return
  ),
  -- Por quem emitiu (owner). As notas de crédito contam a quem emitiu a
  -- factura anulada (Elmar, 30-10-2026).
  nc_orig as (
    select o.owner, -x.grand_total valor
      from sv x left join erp.sales_invoice o on o.name = x.return_against
     where x.is_return
  ),
  pessoas as (
    select public.bsp_fin_pessoa(coalesce(p.owner, n.owner)) nome, coalesce(p.facturas, 0) facturas,
           coalesce(p.facturado, 0) facturado, coalesce(p.desc_n, 0) desc_n, coalesce(p.desc_valor, 0) desc_valor,
           coalesce(n.k, 0) notas, coalesce(n.v, 0) notas_valor, coalesce(p.por_pagar, 0) por_pagar
      from (select owner, count(*) facturas, sum(grand_total) facturado,
                   count(*) filter (where public.bsp_fin_desconto(raw) > 0) desc_n,
                   coalesce(sum(public.bsp_fin_desconto(raw)), 0) desc_valor,
                   coalesce(sum(outstanding_amount) filter (where customer_group <> 'Seguradora' and outstanding_amount > 0), 0) por_pagar
              from sv where not is_return group by owner) p
      full join (select owner, count(*) k, sum(valor) v from nc_orig group by owner) n on n.owner is not distinct from p.owner
     order by coalesce(p.facturado, 0) desc, coalesce(n.v, 0) desc
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
    select fp.id numero, fp.data, -fp.total valor, s.return_against anula,
           public.bsp_fin_pessoa(o.owner) emissora, public.bsp_fin_pessoa(s.owner) anulou,
           nullif(btrim(coalesce(nullif(btrim(s.remarks), ''), s.raw->>'motivo_cancelado', '')), '') motivo
      from fp left join erp.sales_invoice s on s.name = fp.id
              left join erp.sales_invoice o on o.name = s.return_against
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
    'homologo', (select to_jsonb(homologo) from homologo),
    'recebido', (select valor from recebido),
    'descontos', (select to_jsonb(descontos) from descontos),
    'pessoas', (select coalesce(jsonb_agg(to_jsonb(pessoas)), '[]') from pessoas),
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
    'alertas', public.bsp_fin_alertas(p_de, p_ate),
    'actualizado', (select max(synced_at) from erp.sales_invoice where posting_date = hoje),
    'sincronizado', (select max(started_at) from erp.sync_log where ok is not false and doctype = 'Sales Invoice' and date_to = hoje)
  ) into res;
  return res;
end $function$;

-- Telemóvel (de 30 em 30 min).
create or replace function public.bsp_financeiro_alertar()
returns jsonb language plpgsql volatile security definer set search_path to 'public', 'erp'
as $f$
declare
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  hora int := extract(hour from now() at time zone 'Africa/Luanda');
  para text[]; r record; n int; v numeric; txt text; enviados int := 0;
begin
  para := array(select distinct y from unnest(array['u1'] || coalesce((
    select array_agg(x->>'id') from shared_state s, jsonb_array_elements(s.team) x
     where public.bsp_area_chave(x->>'dept') in ('financeiro', 'financas')
       and not coalesce((x->>'inactivo')::boolean, false)), '{}')) y);

  -- Notas de crédito do dia acima de 30 000 Kz: avisa ao passar o limite e a
  -- cada nota nova depois disso.
  select count(*), coalesce(-sum(grand_total), 0) into n, v
    from erp.sales_invoice where docstatus = 1 and is_return and posting_date = hoje;
  if v > 30000 then
    insert into financeiro_avisos (chave) values ('nc-' || hoje || '-' || n) on conflict do nothing;
    if found then
      select string_agg(quem || ' (' || k || ')', ', ' order by k desc) into txt from (
        select public.bsp_fin_pessoa(o.owner) quem, count(*) k
          from erp.sales_invoice x left join erp.sales_invoice o on o.name = x.return_against
         where x.docstatus = 1 and x.is_return and x.posting_date = hoje group by o.owner) z;
      perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'titulo', 'Notas de crédito acima de 30 000 Kz',
        'corpo', 'Hoje: ' || public.bsp_fin_n(v) || ' Kz em ' || n || (case when n = 1 then ' nota' else ' notas' end)
          || '. Facturas anuladas de ' || coalesce(txt, '—') || '.',
        'url', '#/painel', 'tag', 'fin-nc-' || to_char(hoje, 'YYYYMMDD')));
      enviados := enviados + 1;
    end if;
  end if;

  -- Descontos de 50 000 Kz ou mais.
  for r in
    select x.name, public.bsp_fin_desconto(x.raw) d, public.bsp_fin_pessoa(x.owner) quem
      from erp.sales_invoice x
     where x.docstatus = 1 and not x.is_return and x.posting_date >= hoje - 1
       and public.bsp_fin_desconto(x.raw) >= 50000
  loop
    insert into financeiro_avisos (chave) values ('desc-' || r.name) on conflict do nothing;
    if found then
      perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'titulo', 'Desconto de 50 000 Kz ou mais',
        'corpo', 'Desconto de ' || public.bsp_fin_n(r.d) || ' Kz na factura ' || r.name || ', emitida por ' || r.quem || '.',
        'url', '#/painel', 'tag', 'fin-desc-' || r.name));
      enviados := enviados + 1;
    end if;
  end loop;

  -- Às 19h00: particulares de hoje por pagar.
  if hora >= 19 then
    select count(*), coalesce(sum(outstanding_amount), 0) into n, v
      from erp.sales_invoice
     where docstatus = 1 and not is_return and outstanding_amount > 0 and posting_date = hoje
       and (customer_group = 'Individual' or (customer_group = 'All Customer Groups' and coalesce(btrim(seguradora), '') = ''));
    if n > 0 then
      insert into financeiro_avisos (chave) values ('part-' || hoje) on conflict do nothing;
      if found then
        select string_agg(quem || ' (' || k || ')', ', ' order by k desc) into txt from (
          select public.bsp_fin_pessoa(owner) quem, count(*) k from erp.sales_invoice
           where docstatus = 1 and not is_return and outstanding_amount > 0 and posting_date = hoje
             and (customer_group = 'Individual' or (customer_group = 'All Customer Groups' and coalesce(btrim(seguradora), '') = ''))
           group by owner) z;
        perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'titulo', 'Particulares por pagar hoje',
          'corpo', n || (case when n = 1 then ' factura' else ' facturas' end) || ' de particulares por pagar: '
            || public.bsp_fin_n(v) || ' Kz. Emitidas por ' || coalesce(txt, '—') || '.',
          'url', '#/painel', 'tag', 'fin-part-' || to_char(hoje, 'YYYYMMDD')));
        enviados := enviados + 1;
      end if;
    end if;
  end if;
  return jsonb_build_object('enviados', enviados, 'para', to_jsonb(para));
end $f$;
revoke all on function public.bsp_financeiro_alertar() from public, anon, authenticated;

select cron.schedule('bsp-financeiro-alertas', '19,49 * * * *', 'select public.bsp_financeiro_alertar()');
