-- «A minha actividade»: sala de observação numa linha própria (19-10-2026).
-- Dra. Ludmila Da Silva (Chat, ao Elmar): «os dados das observações não entram
-- no resumo do mês?». Entravam, mas dentro de «Enfermagem» (o MetaGest põe a
-- «SALA DE OBSERVAÇÃO» no item_group ENFERMAGEM). Agora o grupo vem de
-- bsp_mg_grupo: observação à parte, o resto igual. A mesma separação que o
-- pagamento dos médicos já faz (rubrica 'observacao', pagamento-medicos.sql).
-- Substitui a função de minha-actividade-servicos.sql (mesma assinatura).

create or replace function public.bsp_mg_grupo(p_grupo text, p_item text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select case
    when coalesce(p_grupo, '') ~* 'ENFERMAGEM' and coalesce(p_item, '') ~* 'OBSERVA' then 'Sala de observação'
    else coalesce(nullif(btrim(p_grupo), ''), 'Outros')
  end
$$;
revoke all on function public.bsp_mg_grupo(text, text) from public, anon;
grant execute on function public.bsp_mg_grupo(text, text) to authenticated;

create or replace function public.bsp_minha_actividade(p_de date, p_ate date, p_membro text default null, p_servico text default null)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  eu text := public.bsp_meu_id();
  alvo text := coalesce(nullif(btrim(p_membro), ''), eu);
  serv text := nullif(btrim(p_servico), '');
  codigos text[];
  inicio12 date := (date_trunc('month', p_ate) - interval '11 months')::date;
  res jsonb;
begin
  if eu is null or public.bsp_e_socio() then
    raise exception 'Sem acesso.';
  end if;
  if p_ate < p_de or p_ate - p_de > 1100 then
    raise exception 'Período inválido (até 3 anos).';
  end if;
  if alvo <> eu and not (public.bsp_e_gestor() or public.bsp_ve_painel() or public.bsp_le_areas_medicas()) then
    raise exception 'Só vê a sua própria actividade.';
  end if;
  select array(select jsonb_array_elements_text(coalesce(e->'metagest', '[]'::jsonb)))
    into codigos
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and e->>'id' = alvo
   limit 1;
  -- Médico do MetaGest sem conta no Workspace (Direcção Clínica, 02-10-2026).
  if alvo like 'mg:%' then codigos := array[substr(alvo, 4)]; end if;
  if codigos is null or cardinality(codigos) = 0 then
    return jsonb_build_object('ligado', false);
  end if;

  with f0 as (
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
  -- Com serviço: só as facturas desse serviço, e o valor das suas linhas.
  f as (
    select f0.name, f0.posting_date, f0.quem, f0.tem_consulta,
           case when serv is null then f0.grand_total
                else (select coalesce(sum(i.amount), 0) from erp.sales_invoice_item i
                       where i.parent = f0.name and i.amount > 0
                         and public.bsp_mg_grupo(i.item_group, i.item_name) = serv) end grand_total
      from f0
     where serv is null or exists (select 1 from erp.sales_invoice_item i
                                    where i.parent = f0.name and i.amount > 0
                                      and public.bsp_mg_grupo(i.item_group, i.item_name) = serv)
  ),
  per as (select * from f where posting_date between p_de and p_ate),
  itens as (
    select public.bsp_mg_grupo(i.item_group, i.item_name) grupo,
           sum(i.qty) qtd, sum(i.amount) valor
      from per join erp.sales_invoice_item i on i.parent = per.name
     where i.amount > 0
       and (serv is null or public.bsp_mg_grupo(i.item_group, i.item_name) = serv)
     group by 1
  ),
  servicos as (
    select distinct public.bsp_mg_grupo(i.item_group, i.item_name) grupo
      from f0 join erp.sales_invoice_item i on i.parent = f0.name
     where f0.posting_date between p_de and p_ate and i.amount > 0
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
    'de', p_de, 'ate', p_ate, 'servico', serv,
    'resumo', (select jsonb_build_object(
        'doentes', count(distinct quem),
        'consultas', count(distinct (posting_date, quem)) filter (where tem_consulta),
        'exames', count(distinct (posting_date, quem)) - count(distinct (posting_date, quem)) filter (where tem_consulta),
        'facturas', count(*),
        'valor', coalesce(sum(grand_total), 0)) from per),
    'grupos', coalesce((select jsonb_agg(jsonb_build_object('grupo', grupo, 'qtd', qtd, 'valor', valor) order by valor desc) from itens), '[]'::jsonb),
    'servicos', coalesce((select jsonb_agg(grupo order by grupo) from servicos), '[]'::jsonb),
    'meses', coalesce((select jsonb_agg(jsonb_build_object('mes', mes, 'consultas', consultas, 'exames', exames, 'valor', valor) order by mes) from meses), '[]'::jsonb),
    'actualizado', (select max(synced_at) from erp.sales_invoice where ref_practitioner = any (codigos))
  ) into res;
  -- A Direcção Clínica vê só quantidades dos outros médicos (Elmar, 02-10-2026).
  if alvo <> eu and not (public.bsp_e_gestor() or public.bsp_ve_painel()) then
    res := (res - 'actualizado') || jsonb_build_object(
      'actualizado', res->'actualizado', 'sem_valores', true,
      'resumo', (res->'resumo') - 'valor',
      'grupos', coalesce((select jsonb_agg(g - 'valor') from jsonb_array_elements(res->'grupos') g), '[]'::jsonb),
      'meses', coalesce((select jsonb_agg(m - 'valor') from jsonb_array_elements(res->'meses') m), '[]'::jsonb));
  end if;
  return res;
end $function$;

revoke execute on function public.bsp_minha_actividade(date, date, text, text) from public, anon;
grant execute on function public.bsp_minha_actividade(date, date, text, text) to authenticated;

