-- Barispol Workspace · «A minha actividade» dos médicos (30-09-2026)
-- Pedido do Elmar: cada médico vê o que gerou, sem ver as contas da
-- clínica. Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo
-- dia. Pode correr-se mais do que uma vez.
--
-- Ligação: o campo metagest (lista de códigos ref_practitioner do
-- MetaGest) na pessoa, em shared_state.team. Um médico pode ter mais do
-- que um código. A gestão liga-o no Admin (bsp_metagest_medicos).
--
-- bsp_minha_actividade(de, ate, membro) devolve só os totais do médico:
-- doentes, consultas, só exames, actos por grupo, valor facturado dos seus
-- actos e os últimos 12 meses. Nunca a facturação da clínica, outros
-- médicos, seguradoras nem nomes de doentes. As facturas anuladas por
-- nota de crédito não contam (a mesma regra do Painel, painel.sql).
-- O médico só pede os seus; a gestão (bsp_e_gestor) e quem vê o Painel
-- (bsp_ve_painel) podem pedir os de outra pessoa (membro), para o «Ver
-- como» e para conferir.

create or replace function public.bsp_minha_actividade(p_de date, p_ate date, p_membro text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  eu text := public.bsp_meu_id();
  alvo text := coalesce(nullif(btrim(p_membro), ''), eu);
  codigos text[];
  inicio12 date := (date_trunc('month', p_ate) - interval '11 months')::date;
  res jsonb;
begin
  if eu is null or public.bsp_e_socio() then
    raise exception 'Sem acesso.';
  end if;
  if alvo <> eu and not (public.bsp_e_gestor() or public.bsp_ve_painel()) then
    raise exception 'Só vê a sua própria actividade.';
  end if;
  select array(select jsonb_array_elements_text(coalesce(e->'metagest', '[]'::jsonb)))
    into codigos
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and e->>'id' = alvo
   limit 1;
  if codigos is null or cardinality(codigos) = 0 then
    return jsonb_build_object('ligado', false);
  end if;

  with f as (
    select s.name, s.posting_date, s.grand_total,
           coalesce(s.patient, s.customer, s.name) quem,
           exists (select 1 from erp.sales_invoice_item i where i.parent = s.name
                    and coalesce(i.item_group, '') ~* 'CONSULTA' and i.amount > 0) tem_consulta
      from erp.sales_invoice s
     where s.docstatus = 1 and not s.is_return
       and s.ref_practitioner = any (codigos)
       and s.posting_date between least(p_de, inicio12) and p_ate
       and not exists (select 1 from erp.sales_invoice r where r.docstatus = 1 and r.is_return and r.return_against = s.name)
  ),
  per as (select * from f where posting_date between p_de and p_ate),
  itens as (
    select coalesce(nullif(btrim(i.item_group), ''), 'Outros') grupo,
           sum(i.qty) qtd, sum(i.amount) valor
      from per join erp.sales_invoice_item i on i.parent = per.name
     where i.amount > 0
     group by 1
  ),
  meses as (
    select to_char(date_trunc('month', posting_date), 'YYYY-MM') mes,
           count(distinct (posting_date, quem)) filter (where tem_consulta) consultas,
           count(distinct (posting_date, quem)) - count(distinct (posting_date, quem)) filter (where tem_consulta) exames,
           coalesce(sum(grand_total), 0) valor
      from f where posting_date >= inicio12
     group by 1
  )
  select jsonb_build_object(
    'ligado', true,
    'de', p_de, 'ate', p_ate,
    'resumo', (select jsonb_build_object(
        'doentes', count(distinct quem),
        'consultas', count(distinct (posting_date, quem)) filter (where tem_consulta),
        'exames', count(distinct (posting_date, quem)) - count(distinct (posting_date, quem)) filter (where tem_consulta),
        'facturas', count(*),
        'valor', coalesce(sum(grand_total), 0)) from per),
    'grupos', coalesce((select jsonb_agg(jsonb_build_object('grupo', grupo, 'qtd', qtd, 'valor', valor) order by valor desc) from itens), '[]'::jsonb),
    'meses', coalesce((select jsonb_agg(jsonb_build_object('mes', mes, 'consultas', consultas, 'exames', exames, 'valor', valor) order by mes) from meses), '[]'::jsonb),
    'actualizado', (select max(synced_at) from erp.sales_invoice where ref_practitioner = any (codigos))
  ) into res;
  return res;
end $function$;
revoke all on function public.bsp_minha_actividade(date, date, text) from public, anon;
grant execute on function public.bsp_minha_actividade(date, date, text) to authenticated;

-- Os médicos do MetaGest, para a gestão ligar cada conta (só nome, código
-- e número de facturas do ano; nenhum valor).
create or replace function public.bsp_metagest_medicos()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
begin
  if not public.bsp_e_gestor() then raise exception 'Só a gestão.'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', ref_practitioner, 'nome', nome, 'n', n) order by nome)
      from (select ref_practitioner, max(btrim(regexp_replace(practitioner_name, '\s+', ' ', 'g'))) nome, count(*) n
              from erp.sales_invoice
             where docstatus = 1 and ref_practitioner is not null
               and coalesce(btrim(practitioner_name), '') not in ('', 'EXTERNO')
               and posting_date >= date_trunc('year', current_date) - interval '1 year'
             group by 1) m), '[]'::jsonb);
end $function$;
revoke all on function public.bsp_metagest_medicos() from public, anon;
grant execute on function public.bsp_metagest_medicos() to authenticated;

-- Ligação das médicas que já estão na equipa (30-09-2026).
update public.shared_state s
   set team = (select jsonb_agg(case e->>'id'
                 when 'u4' then e || '{"metagest": ["HLC-PRAC-2024-00069"]}'::jsonb
                 when 'u5' then e || '{"metagest": ["HLC-PRAC-2025-00004"]}'::jsonb
                 when 'u6' then e || '{"metagest": ["HLC-PRAC-2025-00002"]}'::jsonb
                 when 'u7' then e || '{"metagest": ["HLC-PRAC-2024-00068"]}'::jsonb
                 else e end order by ord)
               from jsonb_array_elements(s.team) with ordinality t(e, ord)),
       updated_at = now()
 where s.id = 1;
