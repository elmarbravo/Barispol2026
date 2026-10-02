-- Barispol Workspace · indicadores de gestão clínica para a Direcção Clínica
-- Pedido do Elmar, 02-10-2026: «No relatório direcção clínica vê o que falta
-- e pode ser útil a nível de gestão clínica internacional». Aplicado no
-- projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais
-- do que uma vez. Corre-se depois de relatorios-diarios.sql.
--
-- Indicadores no modelo usado pela JCI e pela OMS (acesso, continuidade,
-- prática clínica, rastreabilidade, governação), só com o que já está no
-- Workspace e no MetaGest. Sem valores em Kz e sem nomes de utentes.
--   erp.direccao_clinica_dados(dia)      os indicadores (30 dias até ao dia)
--   public.bsp_srv_direccao_clinica(dia) atalho só para a chave do servidor
-- Sai no relatório diário da Clínica (07h15, relatorios-diarios), que vai
-- para a Direcção Clínica (u14).
-- Números reais ao lado de cada percentagem e, desde 02-10-2026 (pedido do
-- Elmar): comparação com os 30 dias anteriores, afluência por hora e por
-- dia da semana, consultas por especialidade, exames mais pedidos, faltas
-- por médico, utentes por financiador e dias de actividade por médico.

create or replace function erp.direccao_clinica_dados(p_dia date)
returns jsonb
language sql
stable
security definer
set search_path to 'erp', 'public'
as $function$
  with hoje as (select (now() at time zone 'Africa/Luanda')::date d),
  -- Facturas válidas dos últimos 120 dias (para a reconsulta) sem as anuladas.
  f as materialized (
    select s.name, s.posting_date dia, extract(hour from s.posting_time)::int hora,
           coalesce(nullif(s.patient, ''), s.customer, s.name) quem,
           s.ref_practitioner, nullif(btrim(coalesce(s.practitioner_name, '')), '') medico,
           case when s.seguradora is not null or s.customer_group = 'Seguradora' then 'Seguradora'
                when s.customer_group = 'Commercial' then 'Empresa' else 'Particular' end financiador,
           s.seguradora
      from erp.sales_invoice s
     where s.docstatus = 1 and not coalesce(s.is_return, false) and s.grand_total > 0
       and s.posting_date between p_dia - 120 and p_dia
       and not exists (select 1 from erp.sales_invoice r where r.docstatus = 1 and r.is_return and r.return_against = s.name)
     offset 0
  ),
  it as materialized (
    select f.dia, f.quem, f.name, f.medico, f.ref_practitioner,
           coalesce(nullif(btrim(i.item_name), ''), i.item_code) item,
           case when i.item_group ~* 'CONSULTA' then 'consulta'
                when i.item_group ~* 'EXTERNO' then 'lab_externo'
                when i.item_group ~* 'LABORAT' then 'laboratorio'
                when i.item_group ~* 'RAIO|ECOGRAF|CARDIO' then 'imagem'
                when i.item_group ~* 'FARM' then 'farmacia'
                when i.item_group ~* 'ENFERM' then 'enfermagem'
                else 'outro' end tipo,
           greatest(coalesce(i.qty, 1), 0) qty
      from f join erp.sales_invoice_item i on i.parent = f.name
     where i.amount > 0
  ),
  p30 as (select * from it where dia between p_dia - 29 and p_dia),
  a30 as (select * from it where dia between p_dia - 59 and p_dia - 30),
  -- Acesso: marcações dos 30 dias até ao dia.
  m as (select * from public.marcacoes where data_marcada between p_dia - 29 and p_dia),
  acesso as (
    select jsonb_build_object(
      'marcacoes', count(*),
      'compareceu', count(*) filter (where estado = 'Compareceu'),
      'faltou', count(*) filter (where estado = 'Faltou'),
      'cancelou', count(*) filter (where estado = 'Cancelou'),
      'remarcado', count(*) filter (where estado = 'Remarcado'),
      'por_fechar', count(*) filter (where estado in ('Agendada', 'Confirmada') and data_marcada < (select d from hoje)),
      'taxa_faltas', round(100.0 * count(*) filter (where estado = 'Faltou')
                     / nullif(count(*) filter (where estado in ('Compareceu', 'Faltou')), 0), 1),
      'taxa_cancel', round(100.0 * count(*) filter (where estado = 'Cancelou') / nullif(count(*), 0), 1),
      'espera_mediana', percentile_cont(0.5) within group (order by data_marcada - coalesce(dia_contacto, criado_em::date))
                        filter (where coalesce(dia_contacto, criado_em::date) <= data_marcada),
      'espera_media', round(avg(data_marcada - coalesce(dia_contacto, criado_em::date))
                      filter (where coalesce(dia_contacto, criado_em::date) <= data_marcada), 1)) j
      from m
  ),
  -- Continuidade: utentes com consulta há 31 a 60 dias que voltaram à consulta.
  c as (select distinct dia, quem from it where tipo = 'consulta'),
  coorte as (
    select c1.quem,
           exists (select 1 from c c2 where c2.quem = c1.quem and c2.dia > c1.dia and c2.dia <= c1.dia + 7) v7,
           exists (select 1 from c c2 where c2.quem = c1.quem and c2.dia > c1.dia and c2.dia <= c1.dia + 30) v30
      from c c1 where c1.dia between p_dia - 60 and p_dia - 31
  ),
  novos as (
    select count(*) filter (where not exists (select 1 from erp.sales_invoice s where s.docstatus = 1
                              and coalesce(nullif(s.patient, ''), s.customer, s.name) = x.quem and s.posting_date < p_dia - 29)) n,
           count(*) t
      from (select distinct quem from p30) x
  ),
  continuidade as (
    select jsonb_build_object(
      'base', (select count(*) from coorte),
      'reconsulta_7', (select round(100.0 * avg(v7::int), 1) from coorte),
      'reconsulta_30', (select round(100.0 * avg(v30::int), 1) from coorte),
      'voltaram_7', (select count(*) filter (where v7) from coorte),
      'voltaram_30', (select count(*) filter (where v30) from coorte),
      'utentes', (select t from novos),
      'novos', (select n from novos),
      'novos_pc', (select round(100.0 * n / nullif(t, 0), 1) from novos)) j
  ),
  -- Prática clínica: o que cada médico pede (o médico da factura é o solicitante).
  por_medico as (
    select medico,
           count(distinct (dia, quem)) filter (where tipo = 'consulta') consultas,
           count(distinct dia) filter (where tipo = 'consulta') dias,
           coalesce(round(sum(qty) filter (where tipo = 'laboratorio')), 0) lab,
           coalesce(round(sum(qty) filter (where tipo = 'lab_externo')), 0) externos,
           coalesce(round(sum(qty) filter (where tipo = 'imagem')), 0) imagem
      from p30 where medico is not null and medico <> 'EXTERNO' group by medico
  ),
  pratica as (
    select coalesce(jsonb_agg(jsonb_build_object('nome', medico, 'consultas', consultas, 'dias', dias, 'lab', lab, 'externos', externos, 'imagem', imagem,
             'por_dia', case when dias > 0 then round(consultas::numeric / dias, 1) end,
             'lab_por_consulta', case when consultas > 0 then round(lab::numeric / consultas, 1) end)
             order by consultas desc, lab desc, medico), '[]'::jsonb) j
      from por_medico where consultas > 0 or lab > 0 or imagem > 0
  ),
  totais as (
    select count(distinct (dia, quem)) filter (where tipo = 'consulta') consultas,
           coalesce(sum(qty) filter (where tipo = 'laboratorio'), 0) lab,
           coalesce(sum(qty) filter (where tipo = 'lab_externo'), 0) externos,
           coalesce(sum(qty) filter (where tipo = 'imagem'), 0) imagem
      from p30
  ),
  -- Rastreabilidade: facturas clínicas com médico solicitante.
  rastreio as (
    select count(distinct name) total,
           count(distinct name) filter (where ref_practitioner is not null) com_medico
      from p30 where tipo in ('consulta', 'laboratorio', 'lab_externo', 'imagem')
  ),
  -- Tendência: últimos 7 dias contra os 7 anteriores.
  tend as (
    select count(distinct (dia, quem)) filter (where dia between p_dia - 6 and p_dia) ut7,
           count(distinct (dia, quem)) filter (where dia between p_dia - 13 and p_dia - 7) ut7a,
           count(distinct (dia, quem)) filter (where tipo = 'consulta' and dia between p_dia - 6 and p_dia) co7,
           count(distinct (dia, quem)) filter (where tipo = 'consulta' and dia between p_dia - 13 and p_dia - 7) co7a
      from it where dia between p_dia - 13 and p_dia
  ),
  -- Os 30 dias anteriores, para comparar.
  antes as (
    select count(distinct (dia, quem)) utentes,
           count(distinct (dia, quem)) filter (where tipo = 'consulta') consultas,
           coalesce(round(sum(qty) filter (where tipo = 'laboratorio')), 0) lab,
           coalesce(round(sum(qty) filter (where tipo = 'lab_externo')), 0) externos,
           coalesce(round(sum(qty) filter (where tipo = 'imagem')), 0) imagem,
           count(distinct dia) dias
      from a30
  ),
  agora as (
    select count(distinct (dia, quem)) utentes, count(distinct dia) dias from p30
  ),
  m_antes as (
    select count(*) marcacoes, count(*) filter (where estado = 'Faltou') faltou, count(*) filter (where estado = 'Cancelou') cancelou
      from public.marcacoes where data_marcada between p_dia - 59 and p_dia - 30
  ),
  -- Afluência: atendimentos por hora e por dia da semana (30 dias).
  horas as (
    select coalesce(jsonb_agg(jsonb_build_object('hora', hora, 'n', n) order by hora), '[]'::jsonb) j
      from (select f.hora, count(distinct (f.dia, f.quem)) n from f where f.dia between p_dia - 29 and p_dia and f.hora is not null group by 1) x
  ),
  semana as (
    select coalesce(jsonb_agg(jsonb_build_object('dow', dow, 'n', n, 'dias', dias, 'media', round(n::numeric / nullif(dias, 0), 1)) order by dow), '[]'::jsonb) j
      from (select extract(isodow from f.dia)::int dow, count(distinct (f.dia, f.quem)) n, count(distinct f.dia) dias
              from f where f.dia between p_dia - 29 and p_dia group by 1) x
  ),
  -- Consultas por especialidade e exames mais pedidos (30 dias contra os anteriores).
  especialidades as (
    select coalesce(jsonb_agg(jsonb_build_object('nome', item, 'n', n, 'antes', a) order by n desc, item), '[]'::jsonb) j
      from (select item, count(distinct (dia, quem)) filter (where dia >= p_dia - 29) n,
                   count(distinct (dia, quem)) filter (where dia < p_dia - 29) a,
                   row_number() over (order by count(distinct (dia, quem)) filter (where dia >= p_dia - 29) desc, item) o
              from it where tipo = 'consulta' and dia between p_dia - 59 and p_dia group by item) x
     where o <= 12 and n > 0
  ),
  exames as (
    select tipo, coalesce(jsonb_agg(jsonb_build_object('nome', item, 'n', n) order by n desc, item), '[]'::jsonb) j
      from (select tipo, item, round(sum(qty)) n, row_number() over (partition by tipo order by sum(qty) desc, item) o
              from p30 where tipo in ('laboratorio', 'imagem', 'lab_externo') group by tipo, item) x
     where o <= 10 group by tipo
  ),
  -- Faltas por médico (marcações), só quem teve marcações.
  faltas_med as (
    select coalesce(jsonb_agg(jsonb_build_object('nome', medico, 'marcacoes', t, 'compareceu', c, 'faltou', fa, 'cancelou', ca) order by fa desc, t desc, medico), '[]'::jsonb) j
      from (select coalesce(nullif(btrim(medico), ''), 'Sem médico') medico, count(*) t,
                   count(*) filter (where estado = 'Compareceu') c, count(*) filter (where estado = 'Faltou') fa,
                   count(*) filter (where estado = 'Cancelou') ca
              from m group by 1) x
  ),
  -- Utentes por financiador (contagens, nunca valores).
  financiador as (
    select jsonb_build_object(
      'tipos', (select coalesce(jsonb_agg(jsonb_build_object('tipo', financiador, 'utentes', n) order by n desc), '[]'::jsonb)
                  from (select financiador, count(distinct quem) n from f where dia between p_dia - 29 and p_dia group by 1) x),
      'seguradoras', (select coalesce(jsonb_agg(jsonb_build_object('nome', seguradora, 'utentes', n) order by n desc, seguradora), '[]'::jsonb)
                  from (select seguradora, count(distinct quem) n from f where dia between p_dia - 29 and p_dia and seguradora is not null
                         group by 1 order by 2 desc, 1 limit 8) x)) j
  ),
  -- Governação: o que espera pela Direcção Clínica e pela gestão clínica.
  governacao as (
    select jsonb_build_object(
      'escalas_sem_visto', (select coalesce(jsonb_agg(jsonb_build_object('area', e.area, 'mes', e.mes) order by e.mes, e.area), '[]'::jsonb)
                              from public.escalas e where e.estado = 'publicada' and e.exige_visto and e.visto_em is null),
      'trocas_por_aprovar', (select count(*) from public.trocas_turno where estado = 'Aceite'),
      'relatorios_turno_7d', (select count(*) from public.relatorios_area where dia between p_dia - 6 and p_dia
                                and area in ('farmacia', 'laboratorio', 'imagiologia', 'enfermagem')),
      'avarias_abertas', (select count(*) from public.avarias where estado in ('Aberta', 'Em reparação')),
      'avarias_urgentes', (select count(*) from public.avarias where estado in ('Aberta', 'Em reparação') and prioridade ~* 'urgente|alta'),
      'formacoes_a_caducar', (select count(*) from public.formacoes where validade between (select d from hoje) and (select d from hoje) + 60),
      'formacoes_caducadas', (select count(*) from public.formacoes where validade < (select d from hoje)),
      'ausencias_hoje', (select count(*) from public.ausencias where estado = 'Aprovado' and (select d from hoje) between inicio and fim)) j
  ),
  alertas as (
    select coalesce(jsonb_agg(a), '[]'::jsonb) lista from (
      select jsonb_build_object('nivel', 'aviso', 'texto', 'Faltas às marcações: ' || ((select j from acesso)->>'faltou') || ' em ' || (((select j from acesso)->>'compareceu')::int + ((select j from acesso)->>'faltou')::int) || ' (' || replace(((select j from acesso)->>'taxa_faltas'), '.', ',') || '%) nos últimos 30 dias (referência: abaixo de 10%).') a
       where coalesce(((select j from acesso)->>'taxa_faltas')::numeric, 0) >= 10
      union all
      select jsonb_build_object('nivel', 'aviso', 'texto', (select total - com_medico from rastreio) || ' facturas clínicas sem médico solicitante em 30 dias ('
             || replace(round(100.0 * (select com_medico from rastreio) / nullif((select total from rastreio), 0), 1)::text, '.', ',') || '% com médico: ' || (select com_medico from rastreio) || ' de ' || (select total from rastreio) || '; referência: 100%).')
       where (select total - com_medico from rastreio) > 0
      union all
      select jsonb_build_object('nivel', 'perigo', 'texto', jsonb_array_length((select j from governacao)->'escalas_sem_visto') || ' escala(s) publicada(s) à espera do visto da Direcção Clínica: sem visto não estão em vigor.')
       where jsonb_array_length((select j from governacao)->'escalas_sem_visto') > 0
      union all
      select jsonb_build_object('nivel', 'aviso', 'texto', ((select j from governacao)->>'trocas_por_aprovar') || ' troca(s) de turno aceite(s) pelo colega, à espera da sua aprovação.')
       where ((select j from governacao)->>'trocas_por_aprovar')::int > 0
      union all
      select jsonb_build_object('nivel', 'aviso', 'texto', 'Nenhum relatório de turno das áreas médicas (Farmácia, Laboratório, Imagiologia, Enfermagem) nos últimos 7 dias. Sem eles não há registo de ocorrências nem de incidentes.')
       where ((select j from governacao)->>'relatorios_turno_7d')::int = 0
      union all
      select jsonb_build_object('nivel', 'perigo', 'texto', ((select j from governacao)->>'formacoes_caducadas') || ' formação(ões) obrigatória(s) caducada(s) na equipa.')
       where ((select j from governacao)->>'formacoes_caducadas')::int > 0
      union all
      select jsonb_build_object('nivel', 'aviso', 'texto', ((select j from governacao)->>'avarias_urgentes') || ' avaria(s) urgente(s) por resolver.')
       where ((select j from governacao)->>'avarias_urgentes')::int > 0
    ) q
  )
  select jsonb_build_object(
    'dia', p_dia, 'de', p_dia - 29,
    'acesso', (select j from acesso),
    'continuidade', (select j from continuidade),
    'pratica', (select j from pratica),
    'totais', (select jsonb_build_object('consultas', consultas, 'lab', round(lab), 'externos', round(externos), 'imagem', round(imagem),
                 'lab_por_consulta', case when consultas > 0 then round(lab::numeric / consultas, 1) end,
                 'imagem_por_100', case when consultas > 0 then round(100.0 * imagem / consultas, 1) end,
                 'externos_pc', case when lab + externos > 0 then round(100.0 * externos / (lab + externos), 1) end) from totais),
    'rastreio', (select jsonb_build_object('total', total, 'com_medico', com_medico,
                 'pc', round(100.0 * com_medico / nullif(total, 0), 1)) from rastreio),
    'tendencia', (select jsonb_build_object('utentes', ut7, 'utentes_antes', ut7a, 'consultas', co7, 'consultas_antes', co7a) from tend),
    'governacao', (select j from governacao),
    'comparacao', (select jsonb_build_object(
        'utentes', (select utentes from agora), 'utentes_antes', a.utentes,
        'dias', (select dias from agora), 'dias_antes', a.dias,
        'consultas', t.consultas, 'consultas_antes', a.consultas,
        'lab', round(t.lab), 'lab_antes', a.lab,
        'imagem', round(t.imagem), 'imagem_antes', a.imagem,
        'externos', round(t.externos), 'externos_antes', a.externos,
        'marcacoes', ((select j from acesso)->>'marcacoes')::int, 'marcacoes_antes', ma.marcacoes,
        'faltou', ((select j from acesso)->>'faltou')::int, 'faltou_antes', ma.faltou,
        'cancelou', ((select j from acesso)->>'cancelou')::int, 'cancelou_antes', ma.cancelou)
      from antes a, totais t, m_antes ma),
    'horas', (select j from horas),
    'semana', (select j from semana),
    'especialidades', (select j from especialidades),
    'exames', coalesce((select jsonb_object_agg(tipo, j) from exames), '{}'::jsonb),
    'faltas_medico', (select j from faltas_med),
    'financiador', (select j from financiador),
    'alertas', (select lista from alertas))
$function$;
revoke all on function erp.direccao_clinica_dados(date) from public, anon, authenticated;
grant execute on function erp.direccao_clinica_dados(date) to service_role;

create or replace function public.bsp_srv_direccao_clinica(p_dia date)
returns jsonb language sql stable security definer set search_path to 'public', 'erp'
as $$ select erp.direccao_clinica_dados(p_dia) $$;
revoke all on function public.bsp_srv_direccao_clinica(date) from public, anon, authenticated;
grant execute on function public.bsp_srv_direccao_clinica(date) to service_role;

notify pgrst, 'reload schema';
