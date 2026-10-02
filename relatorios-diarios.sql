-- Barispol Workspace · relatórios diários e painel clínico (02-10-2026)
-- Pedido do Elmar: os relatórios que saíam pelo Zapier (parados a 28-09-2026,
-- sem tarefas no plano) passam a sair pelo Supabase; o sócio recebe o resumo
-- da Direcção; os relatórios das áreas levam adm@barispol.com em cópia; e um
-- painel clínico sem valores para quem é da área, com alertas.
-- Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs). Pode correr-se mais
-- do que uma vez.
--
--   erp.clinico_dados(de, ate)   números sem valores, por área, e alertas
--   erp.direccao_dados(dia)      o resumo da Direcção (com valores)
--   bsp_painel_clinico(de, ate)  o ecrã: cada pessoa só recebe as suas áreas
--   relatorios_enviados          um envio por tipo, dia e destino
--   crons bsp-relatorio-direccao (06h50 de Luanda) e bsp-relatorio-areas
--   (07h15), Edge Function relatorios-diarios (funcoes/relatorios-diarios).
-- Utentes nunca com nome. Os dados de erp.* nunca se abrem a quem entra:
-- as funções erp.* só correm com a chave do servidor.

-- Mais pormenor nas áreas (02-10-2026, a partir dos relatórios que saíam
-- pelo Zapier): documentos do dia por tipo, marcações passadas por fechar,
-- facturas sem médico em atraso desde 01-07 (pelo número do documento),
-- rascunhos por submeter (o total de facturas sem médico desde 01-07 fica
-- só nos dados: a regra do MetaGest separa o médico que indica do que
-- pratica, e por esta contagem dava 259 contra 23); na Farmácia o vendido com o stock que fica e o
-- que repor; no Laboratório os testes e consumíveis. Sem nomes de utentes.
create or replace function erp.clinico_extra(p_de date, p_ate date)
returns jsonb
language sql
stable
security definer
set search_path to 'erp', 'public'
as $function$
  with hoje as (select (now() at time zone 'Africa/Luanda')::date d),
  docs as (
    select s.* from erp.sales_invoice s where s.docstatus = 1 and s.posting_date between p_de and p_ate offset 0
  ),
  sem_med as (
    select s.posting_date, s.doc_agt from erp.sales_invoice s
     where s.docstatus = 1 and not coalesce(s.is_return, false) and s.posting_date >= date '2026-07-01'
       and s.ref_practitioner is null and s.grand_total > 0
       and not exists (select 1 from erp.sales_invoice r where r.docstatus = 1 and r.is_return and r.return_against = s.name)
       and exists (select 1 from erp.sales_invoice_item i where i.parent = s.name and i.amount > 0
                    and i.item_group ~* '(CONSULTA|LABORAT|RAIO|ECOGRAF|CARDIO)')
  ),
  marc as (
    select to_char(m.data_marcada, 'YYYY-MM') mes, count(*) n from public.marcacoes m
     where m.data_marcada < (select d from hoje) and m.estado in ('Agendada', 'Confirmada') group by 1
  ),
  saldo as materialized (
    select distinct on (m.item_code, m.warehouse) m.item_code, m.warehouse, m.qty_after
      from erp.stock_mov m where not m.is_cancelled
     order by m.item_code, m.warehouse, m.posting_date desc, m.posting_time desc nulls last, m.creation desc nulls last
  ),
  saidas as (
    select m.item_code, sum(-m.actual_qty) s from erp.stock_mov m
     where not m.is_cancelled and m.actual_qty < 0 and m.posting_date >= (select d from hoje) - 30 group by 1
  ),
  total as (select item_code, sum(greatest(qty_after, 0)) q from saldo group by 1),
  vend as (
    select coalesce(nullif(btrim(i.item_name), ''), i.item_code) nome, i.item_code, sum(i.qty) qtd
      from erp.sales_invoice_item i join docs s on s.name = i.parent
     where not coalesce(s.is_return, false) and i.amount > 0 and i.item_group ~* 'FARM'
     group by 1, 2
  ),
  stk as (
    select a.item_code, coalesce(a.item_name, a.item_code) nome, a.item_group, coalesce(t.q, 0) q, coalesce(x.s, 0) sai,
           case when coalesce(x.s, 0) > 0 then coalesce(t.q, 0) / (x.s / 30.0) end dias
      from erp.stock_artigo a left join total t on t.item_code = a.item_code left join saidas x on x.item_code = a.item_code
     where not coalesce(a.disabled, false)
  ),
  r as (
    select jsonb_build_object(
      'documentos', jsonb_build_object(
        'fr', (select count(*) from docs where not coalesce(is_return, false) and doc_agt ~ '^FR'),
        'ft', (select count(*) from docs where not coalesce(is_return, false) and doc_agt ~ '^FT'),
        'outros', (select count(*) from docs where not coalesce(is_return, false) and coalesce(doc_agt, '') !~ '^F[RT]'),
        'nc', (select count(*) from docs where coalesce(is_return, false))),
      'marcacoes_por_fechar', jsonb_build_object('total', coalesce((select sum(n) from marc), 0),
        'por_mes', coalesce((select jsonb_agg(jsonb_build_object('mes', mes, 'n', n) order by mes desc) from marc), '[]'::jsonb)),
      'sem_medico_acum', jsonb_build_object('total', (select count(*) from sem_med), 'desde', '2026-07-01',
        'docs', coalesce((select jsonb_agg(jsonb_build_object('dia', posting_date, 'doc', doc_agt) order by posting_date desc)
                            from (select * from sem_med order by posting_date desc limit 30) z), '[]'::jsonb)),
      'rascunhos', jsonb_build_object(
        'total', (select count(*) from erp.sales_invoice where docstatus = 0 and posting_date >= date '2026-07-01'),
        'periodo', (select count(*) from erp.sales_invoice where docstatus = 0 and posting_date between p_de and p_ate)),
      'farmacia_vendido', coalesce((select jsonb_agg(jsonb_build_object('nome', v.nome, 'qtd', round(v.qtd), 'fica', round(coalesce(t.q, 0))) order by v.qtd desc, v.nome)
                                      from vend v left join total t on t.item_code = v.item_code), '[]'::jsonb),
      'farmacia_repor', coalesce((select jsonb_agg(jsonb_build_object('nome', nome, 'stock', round(q), 'saidas_30d', round(sai), 'dias', round(dias)) order by (q > 0), sai desc)
                                    from (select * from stk where item_group ~* 'FARM' and sai >= 3 and (q <= 0 or dias < 7) order by (q > 0), sai desc limit 15) z), '[]'::jsonb),
      'lab_consumiveis', coalesce((select jsonb_agg(jsonb_build_object('nome', nome, 'stock', round(q), 'saidas_30d', round(sai), 'dias', round(dias)) order by coalesce(dias, 9999), nome)
                                     from (select * from stk where (item_group ~* 'LABORAT' or nome ~* '(TESTE|TIRAS?|L[AÂ]MINA|PONTEIRA|REAGENTE|LANCETA|TUBO)')
                                            and (sai > 0 or q > 0) order by coalesce(dias, 9999), nome limit 20) z), '[]'::jsonb)) j
  )
  select (select j from r) || jsonb_build_object('alertas',
    (select coalesce(jsonb_agg(a), '[]'::jsonb) from (
       select jsonb_build_object('o', 7, 'area', 'recepcao', 'nivel', 'aviso', 'texto',
                (j->'marcacoes_por_fechar'->>'total') || ' marcação(ões) passadas sem estado fechado (Compareceu, Faltou, Cancelou ou Remarcado).') a
         from r where (j->'marcacoes_por_fechar'->>'total')::int > 0
       union all
       select jsonb_build_object('o', 8, 'area', 'recepcao', 'nivel', 'info', 'texto',
                (j->'rascunhos'->>'total') || ' rascunho(s) no MetaGest desde 01-07 por submeter ou eliminar.')
         from r where (j->'rascunhos'->>'total')::int > 0
) q))
$function$;
revoke all on function erp.clinico_extra(date, date) from public, anon, authenticated;
grant execute on function erp.clinico_extra(date, date) to service_role;

-- Contagens clínicas, sem valores. Uma factura anulada por nota de crédito
-- não conta (igual ao Painel).
create or replace function erp.clinico_dados(p_de date, p_ate date)
returns jsonb
language sql
stable
security definer
set search_path to 'erp', 'public'
as $function$
  with hoje as (select (now() at time zone 'Africa/Luanda')::date d),
  f as materialized (
    select s.name, s.posting_date dia, coalesce(nullif(s.patient, ''), s.customer, s.name) quem,
           s.ref_practitioner, nullif(btrim(coalesce(s.practitioner_name, '')), '') medico
      from erp.sales_invoice s
     where s.docstatus = 1 and not coalesce(s.is_return, false)
       and s.posting_date between p_de - 7 and p_ate and s.grand_total > 0
       and not exists (select 1 from erp.sales_invoice r where r.docstatus = 1 and r.is_return and r.return_against = s.name)
     offset 0
  ),
  it as materialized (
    select f.dia, f.quem, f.name, f.medico, f.ref_practitioner,
           case
             when i.item_group ~* 'CONSULTA' then 'consulta'
             when i.item_group ~* 'EXTERNO' then 'lab_externo'
             when i.item_group ~* 'LABORAT' then 'laboratorio'
             when i.item_group ~* 'FARM' then 'farmacia'
             when i.item_group ~* 'ENFERM' then 'enfermagem'
             when i.item_group ~* 'RAIO' then 'raiox'
             when i.item_group ~* 'ECOGRAF' then 'ecografia'
             when i.item_group ~* 'CARDIO' then 'cardiologia'
             else 'outro' end tipo,
           coalesce(nullif(btrim(i.item_name), ''), i.item_code) nome, greatest(coalesce(i.qty, 1), 0) qty
      from f join erp.sales_invoice_item i on i.parent = f.name
     where i.amount > 0
  ),
  p as (select * from it where dia between p_de and p_ate),
  novos as (
    select count(distinct x.quem) n from (select distinct quem, min(dia) d from f where dia between p_de and p_ate group by quem) x
     where not exists (select 1 from erp.sales_invoice s where s.docstatus = 1
                         and coalesce(nullif(s.patient, ''), s.customer, s.name) = x.quem and s.posting_date < p_de)
  ),
  top as (
    select tipo, jsonb_agg(jsonb_build_object('nome', nome, 'n', n) order by n desc, nome) lista
      from (select tipo, nome, round(sum(qty)) n,
                   row_number() over (partition by tipo order by sum(qty) desc, nome) o
              from p group by tipo, nome) z
     where o <= 12 group by tipo
  ),
  medicos as (
    select coalesce(jsonb_agg(jsonb_build_object('nome', medico, 'consultas', c, 'utentes', u) order by c desc, u desc, medico), '[]'::jsonb) lista
      from (select medico, count(distinct (dia, quem)) filter (where tipo = 'consulta') c, count(distinct (dia, quem)) u
              from p where medico is not null and medico <> 'EXTERNO' group by medico) z
  ),
  serie as (
    select coalesce(jsonb_agg(jsonb_build_object('dia', d::date,
             'utentes', (select count(distinct quem) from f where f.dia = d::date),
             'consultas', (select count(distinct quem) from it where it.dia = d::date and tipo = 'consulta'),
             'exames', (select coalesce(round(sum(qty)), 0) from it where it.dia = d::date and tipo = 'laboratorio')) order by d), '[]'::jsonb) s
      from generate_series(greatest(p_de, p_ate - 30), p_ate, interval '1 day') d
  ),
  -- Média dos 7 dias antes do período (para o alerta de dia fraco).
  antes as (
    select round(count(distinct (dia, quem)) / 7.0, 1) utentes_dia from f where dia between p_de - 7 and p_de - 1
  ),
  sem_medico as (
    select count(distinct name) n from p where tipo in ('consulta', 'laboratorio', 'raiox', 'ecografia', 'cardiologia') and ref_practitioner is null
  ),
  -- Stock: o saldo pelo último movimento (igual ao bsp_stock), por área do artigo.
  saldo as materialized (
    select distinct on (m.item_code, m.warehouse) m.item_code, m.warehouse, m.qty_after
      from erp.stock_mov m where not m.is_cancelled
     order by m.item_code, m.warehouse, m.posting_date desc, m.posting_time desc nulls last, m.creation desc nulls last
  ),
  saidas as (
    select m.item_code, m.warehouse, sum(-m.actual_qty) s from erp.stock_mov m
     where not m.is_cancelled and m.actual_qty < 0 and m.posting_date >= (select d from hoje) - 30 group by 1, 2
  ),
  lotes as (
    select m.item_code, m.batch_no, sum(m.actual_qty) q from erp.stock_mov m
     where not m.is_cancelled and m.batch_no is not null group by 1, 2 having sum(m.actual_qty) > 0.0001
  ),
  st as (
    select case when a.item_group ~* 'LABORAT' then 'laboratorio' when a.item_group ~* 'ENFERM' then 'enfermagem'
                when a.item_group ~* 'LIMPEZA' then 'servicos gerais' when a.item_group ~* 'FARM' then 'farmacia' end area,
           coalesce(a.item_name, s.item_code) nome, s.qty_after q, coalesce(x.s, 0) sai,
           case when coalesce(x.s, 0) > 0 then greatest(s.qty_after, 0) / (x.s / 30.0) end dias
      from saldo s join erp.stock_artigo a on a.item_code = s.item_code
      left join saidas x on x.item_code = s.item_code and x.warehouse = s.warehouse
     where not coalesce(a.disabled, false)
  ),
  val as (
    select case when a.item_group ~* 'LABORAT' then 'laboratorio' when a.item_group ~* 'ENFERM' then 'enfermagem'
                when a.item_group ~* 'LIMPEZA' then 'servicos gerais' when a.item_group ~* 'FARM' then 'farmacia' end area,
           coalesce(a.item_name, l.item_code) nome, b.expiry_date validade, l.q
      from lotes l join erp.stock_lote b on b.name = l.batch_no join erp.stock_artigo a on a.item_code = l.item_code
     where b.expiry_date is not null and b.expiry_date <= (select d from hoje) + 30
  ),
  stock as (
    select area, jsonb_build_object(
      'esgotados', coalesce((select jsonb_agg(distinct nome) from st t where t.area = z.area and t.q <= 0 and t.sai > 0), '[]'::jsonb),
      'a_acabar', coalesce((select jsonb_agg(jsonb_build_object('nome', nome, 'dias', round(dias)) order by dias) from st t
                             where t.area = z.area and t.q > 0 and t.dias < 7), '[]'::jsonb),
      'caducados', coalesce((select jsonb_agg(jsonb_build_object('nome', nome, 'validade', validade, 'qtd', round(q)) order by validade) from val v
                              where v.area = z.area and v.validade < (select d from hoje)), '[]'::jsonb),
      'a_caducar', coalesce((select jsonb_agg(jsonb_build_object('nome', nome, 'validade', validade, 'qtd', round(q)) order by validade) from val v
                              where v.area = z.area and v.validade >= (select d from hoje)), '[]'::jsonb)) dados
      from (values ('laboratorio'), ('farmacia'), ('enfermagem'), ('servicos gerais')) z(area)
  ),
  marc as (
    select jsonb_build_object(
      'hoje', (select count(*) from public.marcacoes m where m.data_marcada = (select d from hoje) and m.estado in ('Agendada', 'Confirmada')),
      'por_confirmar', (select count(*) from public.marcacoes m where m.data_marcada = (select d from hoje) and m.estado = 'Agendada'),
      'amanha', (select count(*) from public.marcacoes m where m.data_marcada = (select d from hoje) + 1 and m.estado in ('Agendada', 'Confirmada')),
      'faltas_periodo', (select count(*) from public.marcacoes m where m.data_marcada between p_de and p_ate and m.estado = 'Faltou'),
      'compareceu_periodo', (select count(*) from public.marcacoes m where m.data_marcada between p_de and p_ate and m.estado = 'Compareceu')) j
  ),
  num as (
    select
      (select count(distinct (dia, quem)) from f where dia between p_de and p_ate) utentes,
      (select n from novos) novos,
      (select count(distinct (dia, quem)) from p where tipo = 'consulta') consultas,
      (select coalesce(round(sum(qty)), 0) from p where tipo = 'laboratorio') exames_lab,
      (select count(distinct (dia, quem)) from p where tipo = 'laboratorio') utentes_lab,
      (select coalesce(round(sum(qty)), 0) from p where tipo = 'lab_externo') exames_externos,
      (select coalesce(round(sum(qty)), 0) from p where tipo = 'farmacia') unidades_farmacia,
      (select count(distinct nome) from p where tipo = 'farmacia') produtos_farmacia,
      (select count(distinct (dia, quem)) from p where tipo = 'farmacia') utentes_farmacia,
      (select coalesce(round(sum(qty)), 0) from p where tipo = 'enfermagem') actos_enfermagem,
      (select count(distinct (dia, quem)) from p where tipo = 'enfermagem') utentes_enfermagem,
      (select coalesce(round(sum(qty)), 0) from p where tipo = 'raiox') raiox,
      (select coalesce(round(sum(qty)), 0) from p where tipo = 'ecografia') ecografias,
      (select coalesce(round(sum(qty)), 0) from p where tipo = 'cardiologia') cardiologia
  ),
  sk as (select jsonb_object_agg(area, dados) j from stock),
  tp as (select jsonb_object_agg(tipo, lista) j from top),
  al as (
    select coalesce(jsonb_agg(a order by (a->>'o')::int, a->>'texto'), '[]'::jsonb) lista from (
      select jsonb_build_object('o', 0, 'area', area, 'nivel', 'perigo', 'texto',
               jsonb_array_length(dados->'esgotados') || ' esgotado(s) com procura: ' ||
               (select string_agg(x, ', ') from (select jsonb_array_elements_text(dados->'esgotados') x limit 5) y)) a
        from stock where jsonb_array_length(dados->'esgotados') > 0
      union all
      select jsonb_build_object('o', 1, 'area', area, 'nivel', 'perigo', 'texto',
               jsonb_array_length(dados->'caducados') || ' lote(s) caducado(s) em stock: ' ||
               (select string_agg(x->>'nome', ', ') from (select jsonb_array_elements(dados->'caducados') x limit 5) y))
        from stock where jsonb_array_length(dados->'caducados') > 0
      union all
      select jsonb_build_object('o', 2, 'area', area, 'nivel', 'aviso', 'texto',
               jsonb_array_length(dados->'a_acabar') || ' artigo(s) acabam em menos de 7 dias: ' ||
               (select string_agg((x->>'nome') || ' (' || (x->>'dias') || ' d)', ', ') from (select jsonb_array_elements(dados->'a_acabar') x limit 5) y))
        from stock where jsonb_array_length(dados->'a_acabar') > 0
      union all
      select jsonb_build_object('o', 3, 'area', area, 'nivel', 'aviso', 'texto',
               jsonb_array_length(dados->'a_caducar') || ' lote(s) caducam em 30 dias: ' ||
               (select string_agg((x->>'nome') || ' (' || to_char((x->>'validade')::date, 'DD-MM') || ')', ', ') from (select jsonb_array_elements(dados->'a_caducar') x limit 5) y))
        from stock where jsonb_array_length(dados->'a_caducar') > 0
      union all
      select jsonb_build_object('o', 4, 'area', 'recepcao', 'nivel', 'aviso', 'texto',
               n || case when n = 1 then ' factura sem médico solicitante.' else ' facturas sem médico solicitante.' end)
        from sem_medico where n > 0
      union all
      select jsonb_build_object('o', 5, 'area', 'recepcao', 'nivel', 'info', 'texto',
               (j->>'por_confirmar') || ' marcação(ões) de hoje por confirmar.')
        from marc where (j->>'por_confirmar')::int > 0 and p_ate >= (select d from hoje) - 1
      union all
      select jsonb_build_object('o', 6, 'area', 'clinica', 'nivel', 'aviso', 'texto',
               'Utentes abaixo da média: ' || u.utentes || ' contra ' || replace(a.utentes_dia::text, '.', ',') || ' por dia nos 7 dias anteriores.')
        from num u, antes a where p_de = p_ate and a.utentes_dia > 0 and u.utentes < a.utentes_dia * 0.7
    ) q
  ),
  ex as materialized (select erp.clinico_extra(p_de, p_ate) j)
  select jsonb_build_object(
    'de', p_de, 'ate', p_ate, 'hoje', (select d from hoje),
    'extra', (select j - 'alertas' from ex),
    'numeros', (select to_jsonb(num) from num),
    'top', coalesce((select j from tp), '{}'::jsonb),
    'medicos', (select lista from medicos),
    'serie', (select s from serie),
    'stock', coalesce((select j from sk), '{}'::jsonb),
    'marcacoes', (select j from marc),
    'sem_medico', (select n from sem_medico),
    'alertas', (select lista from al) || coalesce((select j->'alertas' from ex), '[]'::jsonb))
$function$;
revoke all on function erp.clinico_dados(date, date) from public, anon, authenticated;
grant execute on function erp.clinico_dados(date, date) to service_role;

-- O ecrã: cada pessoa recebe só as áreas que vê. Gestão, quem vê o Painel e
-- a Direcção Clínica (u14) vêem todas; os outros, a sua área (e as que chefiam).
-- Nunca valores.
create or replace function public.bsp_painel_clinico(p_de date, p_ate date)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'erp'
as $function$
declare
  eu text := public.bsp_meu_id();
  tudo boolean;
  minhas text[];
  d jsonb;
begin
  if eu is null then raise exception 'Sem sessão.'; end if;
  if p_ate < p_de or p_ate - p_de > 92 then raise exception 'Período inválido (até 3 meses).'; end if;
  tudo := coalesce(public.bsp_e_gestor(), false) or coalesce(public.bsp_ve_painel(), false) or coalesce(public.bsp_le_areas_medicas(), false);
  minhas := array(select x from (
      select public.bsp_minha_area() x
      union select r.area from public.bsp_escalas_responsaveis() r where eu = any (r.ids)) z where x is not null);
  if not tudo and 'clinica' = any (minhas) then minhas := minhas || array['laboratorio', 'recepcao']; end if;
  d := erp.clinico_dados(p_de, p_ate);
  return d || jsonb_build_object(
    'tudo', tudo,
    'areas', to_jsonb(case when tudo then array['recepcao', 'clinica', 'laboratorio', 'farmacia', 'enfermagem', 'radiologia', 'servicos gerais'] else minhas end),
    'alertas', coalesce((select jsonb_agg(a) from jsonb_array_elements(d->'alertas') a
                          where tudo or a->>'area' = any (minhas)), '[]'::jsonb),
    'stock', case when tudo then d->'stock' else coalesce((select jsonb_object_agg(k, v) from jsonb_each(d->'stock') x(k, v) where k = any (minhas)), '{}'::jsonb) end,
    'medicos', case when tudo or 'clinica' = any (minhas) then d->'medicos' else '[]'::jsonb end,
    'extra', jsonb_strip_nulls(jsonb_build_object(
      'documentos', case when tudo or 'recepcao' = any (minhas) then d->'extra'->'documentos' end,
      'marcacoes_por_fechar', case when tudo or 'recepcao' = any (minhas) then d->'extra'->'marcacoes_por_fechar' end,
      'sem_medico_acum', case when tudo or 'recepcao' = any (minhas) then d->'extra'->'sem_medico_acum' end,
      'rascunhos', case when tudo or 'recepcao' = any (minhas) then d->'extra'->'rascunhos' end,
      'farmacia_vendido', case when tudo or 'farmacia' = any (minhas) then d->'extra'->'farmacia_vendido' end,
      'farmacia_repor', case when tudo or 'farmacia' = any (minhas) then d->'extra'->'farmacia_repor' end,
      'lab_consumiveis', case when tudo or 'laboratorio' = any (minhas) then d->'extra'->'lab_consumiveis' end)));
end $function$;
revoke all on function public.bsp_painel_clinico(date, date) from public, anon;
grant execute on function public.bsp_painel_clinico(date, date) to authenticated, service_role;

-- O resumo da Direcção (com valores), igual ao que saía pelo Zapier.
create or replace function erp.direccao_dados(p_dia date)
returns jsonb
language sql
stable
security definer
set search_path to 'erp', 'public'
as $function$
  with s as materialized (
    select s.name, s.posting_date dia, s.grand_total v, coalesce(s.outstanding_amount, 0) devido, s.is_return,
           coalesce(nullif(s.patient, ''), s.customer, s.name) quem,
           case when s.customer_group = 'Seguradora' or s.customer in (select customer from erp.cobrancas_planos) then 'Seguradoras'
                when s.customer_group = 'Commercial' then 'Empresas' else 'Particulares' end origem
      from erp.sales_invoice s
     where s.docstatus = 1 and s.posting_date between date_trunc('month', p_dia - 6)::date and p_dia
     offset 0
  ),
  dia as (
    select coalesce(sum(v), 0) facturado,
           count(*) filter (where not is_return) documentos,
           count(distinct quem) filter (where v > 0 and not is_return) utentes,
           coalesce(sum(v - devido) filter (where not is_return), 0) recebido,
           coalesce(sum(devido) filter (where not is_return), 0) por_cobrar,
           coalesce(sum(devido) filter (where not is_return and origem <> 'Particulares'), 0) por_cobrar_seg,
           coalesce(-sum(v) filter (where is_return), 0) notas_credito
      from s where s.dia = p_dia
  ),
  serie as (
    select jsonb_agg(jsonb_build_object('dia', d::date, 'facturado', coalesce((select sum(v) from s where s.dia = d::date), 0),
                                        'utentes', (select count(distinct quem) from s where s.dia = d::date and v > 0 and not is_return)) order by d) j
      from generate_series(p_dia - 6, p_dia, interval '1 day') d
  ),
  mes as (
    select coalesce(sum(v), 0) facturado, extract(day from p_dia)::int dias from s where s.dia between date_trunc('month', p_dia)::date and p_dia
  ),
  origem as (
    select jsonb_agg(jsonb_build_object('origem', origem, 'valor', valor) order by valor desc) j
      from (select origem, sum(v) valor from s where s.dia between p_dia - 6 and p_dia group by origem having sum(v) <> 0) z
  ),
  servico as (
    select jsonb_agg(jsonb_build_object('servico', g, 'valor', valor) order by valor desc) j
      from (select initcap(lower(coalesce(nullif(btrim(i.item_group), ''), 'Outros'))) g, sum(i.amount) valor
              from erp.sales_invoice_item i join s on s.name = i.parent
             where s.dia between p_dia - 6 and p_dia and not s.is_return group by 1 having sum(i.amount) > 0) z
  )
  select jsonb_build_object('dia', p_dia, 'resumo', (select to_jsonb(dia) from dia), 'serie', (select j from serie),
    'mes', (select to_jsonb(mes) from mes), 'origem', coalesce((select j from origem), '[]'::jsonb),
    'servico', coalesce((select j from servico), '[]'::jsonb),
    'clinico', erp.clinico_dados(p_dia, p_dia) -> 'numeros')
$function$;
revoke all on function erp.direccao_dados(date) from public, anon, authenticated;
grant execute on function erp.direccao_dados(date) to service_role;

-- A Edge Function lê as funções erp.* por estes atalhos (o PostgREST só
-- expõe public). Só a chave do servidor.
create or replace function public.bsp_srv_clinico_dados(p_de date, p_ate date)
returns jsonb language sql stable security definer set search_path to 'public', 'erp'
as $$ select erp.clinico_dados(p_de, p_ate) $$;
create or replace function public.bsp_srv_direccao_dados(p_dia date)
returns jsonb language sql stable security definer set search_path to 'public', 'erp'
as $$ select erp.direccao_dados(p_dia) $$;
revoke all on function public.bsp_srv_clinico_dados(date, date) from public, anon, authenticated;
revoke all on function public.bsp_srv_direccao_dados(date) from public, anon, authenticated;
grant execute on function public.bsp_srv_clinico_dados(date, date) to service_role;
grant execute on function public.bsp_srv_direccao_dados(date) to service_role;

-- Um envio por tipo, dia e destino (o agendamento pode repetir-se).
create table if not exists public.relatorios_enviados (
  tipo text not null,
  dia date not null,
  chave text not null,
  para text,
  ok boolean,
  criado_em timestamptz not null default now(),
  primary key (tipo, dia, chave)
);
alter table public.relatorios_enviados enable row level security;
revoke all on public.relatorios_enviados from anon, authenticated;

-- Destinatários extra de cada relatório (por exemplo, o Gmail do Director
-- em cópia no resumo da Direcção). Os endereços ficam só no servidor.
create table if not exists public.relatorios_diarios_destinos (
  tipo text primary key,
  para text[] not null default '{}',
  cc text[] not null default '{}'
);
alter table public.relatorios_diarios_destinos enable row level security;
revoke all on public.relatorios_diarios_destinos from anon, authenticated;

-- Agendamentos: Direcção às 06h50 e áreas às 07h15 de Luanda (UTC+1).
do $$
declare
  modelo text := $cmd$
    select net.http_post(
      url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/relatorios-diarios',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                         where name = 'bsp_resumo_agendamento' limit 1)),
      body    := '{"qual":"QUAL"}'::jsonb,
      timeout_milliseconds := 60000
    );
  $cmd$;
begin
  if exists (select 1 from cron.job where jobname = 'bsp-relatorio-direccao') then perform cron.unschedule('bsp-relatorio-direccao'); end if;
  if exists (select 1 from cron.job where jobname = 'bsp-relatorio-areas') then perform cron.unschedule('bsp-relatorio-areas'); end if;
  perform cron.schedule('bsp-relatorio-direccao', '50 5 * * *', replace(modelo, 'QUAL', 'direccao'));
  perform cron.schedule('bsp-relatorio-areas', '15 6 * * *', replace(modelo, 'QUAL', 'areas'));
end $$;

notify pgrst, 'reload schema';

