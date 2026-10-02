-- Barispol Workspace · qualidade clínica (as 5 etapas do modelo internacional)
-- Pedido do Elmar, 02-10-2026: «Avance com as 5 etapas». Aplicado no projecto
-- Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que
-- uma vez. Corre-se depois de direccao-clinica.sql.
--
-- Os dados vêm dos relatórios de turno (relatorios_area, campos novos de
-- 02-10-2026 no BSP_RELATORIOS do workspace.html) e do MetaGest:
--   1. incidentes e eventos adversos   incidentes, quase_erros, incidente_tipo
--                                      (todas as áreas)
--   2. satisfação do utente            satisf_resp, satisf_ok, reclamacoes
--                                      (Recepção)
--   3. tempo de espera                 espera_min, espera_30 (Recepção) e,
--                                      do MetaGest, a permanência: da
--                                      primeira à última factura do mesmo
--                                      utente no mesmo dia
--   4. entrega dos resultados do lab.  amostras, amostras_rejeitadas,
--                                      resultados_entregues,
--                                      resultados_atraso, tat_horas
--   5. cumprimento de protocolos       prot_verificados, prot_conformes,
--                                      prot_falhas (áreas de saúde)
-- Só contagens: sem nomes de utentes e sem valores em Kz.
--   erp.qualidade_clinica_dados(dia)     30 dias até ao dia e os 30 anteriores
--   public.bsp_srv_direccao_clinica(dia) passa a juntar a chave "qualidade"

create or replace function erp.qualidade_clinica_dados(p_dia date)
returns jsonb
language sql
stable
security definer
set search_path to 'erp', 'public'
as $function$
  with r as materialized (
    select area, dia, respostas x, dia >= p_dia - 29 agora
      from public.relatorios_area
     where dia between p_dia - 59 and p_dia
     offset 0
  ),
  num as (
    select area, agora,
           count(*) relatorios,
           sum(coalesce((x->>'incidentes')::int, 0)) incidentes,
           sum(coalesce((x->>'quase_erros')::int, 0)) quase_erros,
           count(*) filter (where x ? 'incidentes') com_incidentes,
           sum(coalesce((x->>'satisf_resp')::int, 0)) satisf_resp,
           sum(coalesce((x->>'satisf_ok')::int, 0)) satisf_ok,
           sum(coalesce((x->>'reclamacoes')::int, 0)) reclamacoes,
           sum(coalesce((x->>'utentes')::int, 0)) filter (where x ? 'espera_min') utentes_espera,
           round(avg((x->>'espera_min')::numeric) filter (where x ? 'espera_min'), 1) espera_media,
           sum(coalesce((x->>'espera_30')::int, 0)) espera_30,
           count(*) filter (where x ? 'espera_min') com_espera,
           sum(coalesce((x->>'amostras')::int, 0)) amostras,
           sum(coalesce((x->>'amostras_rejeitadas')::int, 0)) rejeitadas,
           sum(coalesce((x->>'resultados_entregues')::int, 0)) entregues,
           sum(coalesce((x->>'resultados_atraso')::int, 0)) atraso,
           round(avg((x->>'tat_horas')::numeric) filter (where x ? 'tat_horas'), 1) tat_horas,
           count(*) filter (where x ? 'resultados_entregues') com_lab,
           sum(coalesce((x->>'prot_verificados')::int, 0)) prot_verificados,
           sum(coalesce((x->>'prot_conformes')::int, 0)) prot_conformes,
           count(*) filter (where x ? 'prot_verificados') com_prot
      from r group by area, agora
  ),
  t as (
    select agora,
           sum(relatorios) relatorios, sum(incidentes) incidentes, sum(quase_erros) quase_erros, sum(com_incidentes) com_incidentes,
           sum(satisf_resp) satisf_resp, sum(satisf_ok) satisf_ok, sum(reclamacoes) reclamacoes,
           sum(utentes_espera) utentes_espera, max(espera_media) espera_media, sum(espera_30) espera_30, sum(com_espera) com_espera,
           sum(amostras) amostras, sum(rejeitadas) rejeitadas, sum(entregues) entregues, sum(atraso) atraso,
           max(tat_horas) tat_horas, sum(com_lab) com_lab,
           sum(prot_verificados) prot_verificados, sum(prot_conformes) prot_conformes, sum(com_prot) com_prot
      from num group by agora
  ),
  a as (select * from t where agora), b as (select * from t where not agora),
  -- Escolhas múltiplas (tipos de incidente, passos falhados), sem «Nenhum».
  tipos as (
    select campo, coalesce(jsonb_agg(jsonb_build_object('nome', v, 'n', c) order by c desc, v), '[]'::jsonb) j
      from (select k campo, e v, count(*) c
              from r, lateral (values ('incidente_tipo'), ('prot_falhas')) q(k),
                   lateral jsonb_array_elements_text(case when jsonb_typeof(x->k) = 'array' then x->k else '[]'::jsonb end) e
             where r.agora and e !~* '^nenhu'
             group by 1, 2) y
     group by campo
  ),
  prot_area as (
    select coalesce(jsonb_agg(jsonb_build_object('area', area, 'relatorios', com_prot, 'verificados', prot_verificados, 'conformes', prot_conformes,
             'pc', round(100.0 * prot_conformes / nullif(prot_verificados, 0), 1)) order by area), '[]'::jsonb) j
      from num where agora and com_prot > 0
  ),
  inc_area as (
    select coalesce(jsonb_agg(jsonb_build_object('area', area, 'relatorios', com_incidentes, 'incidentes', incidentes, 'quase_erros', quase_erros) order by area), '[]'::jsonb) j
      from num where agora and com_incidentes > 0
  ),
  -- MetaGest: permanência do utente na clínica (primeira à última factura
  -- do mesmo dia, só quando há mais do que uma). Aproximação, sem a hora
  -- de chegada.
  perm as (
    select dia >= p_dia - 29 agora, count(*) n,
           round((percentile_cont(0.5) within group (order by m))::numeric, 0) mediana,
           count(*) filter (where m > 60) mais_60
      from (select s.posting_date dia, extract(epoch from max(s.posting_time) - min(s.posting_time)) / 60 m
              from erp.sales_invoice s
             where s.docstatus = 1 and not coalesce(s.is_return, false) and s.grand_total > 0
               and s.posting_date between p_dia - 59 and p_dia and coalesce(s.patient, '') <> ''
             group by s.patient, s.posting_date having count(*) > 1) z
     group by 1
  ),
  q as (
    select jsonb_build_object(
      'incidentes', jsonb_build_object(
          'relatorios', coalesce((select com_incidentes from a), 0),
          'incidentes', coalesce((select incidentes from a), 0), 'incidentes_antes', coalesce((select incidentes from b), 0),
          'quase_erros', coalesce((select quase_erros from a), 0), 'quase_erros_antes', coalesce((select quase_erros from b), 0),
          'tipos', coalesce((select j from tipos where campo = 'incidente_tipo'), '[]'::jsonb),
          'por_area', (select j from inc_area)),
      'satisfacao', jsonb_build_object(
          'respostas', coalesce((select satisf_resp from a), 0), 'satisfeitos', coalesce((select satisf_ok from a), 0),
          'pc', (select round(100.0 * satisf_ok / nullif(satisf_resp, 0), 1) from a),
          'pc_antes', (select round(100.0 * satisf_ok / nullif(satisf_resp, 0), 1) from b),
          'reclamacoes', coalesce((select reclamacoes from a), 0), 'reclamacoes_antes', coalesce((select reclamacoes from b), 0)),
      'espera', jsonb_build_object(
          'relatorios', coalesce((select com_espera from a), 0),
          'media_min', (select espera_media from a), 'media_min_antes', (select espera_media from b),
          'mais_30', coalesce((select espera_30 from a), 0), 'utentes', coalesce((select utentes_espera from a), 0),
          'pc_mais_30', (select round(100.0 * espera_30 / nullif(utentes_espera, 0), 1) from a),
          'permanencia_mediana', (select mediana from perm where agora), 'permanencia_n', coalesce((select n from perm where agora), 0),
          'permanencia_mais_60', coalesce((select mais_60 from perm where agora), 0),
          'permanencia_mediana_antes', (select mediana from perm where not agora)),
      'laboratorio', jsonb_build_object(
          'relatorios', coalesce((select com_lab from a), 0),
          'amostras', coalesce((select amostras from a), 0), 'rejeitadas', coalesce((select rejeitadas from a), 0),
          'pc_rejeitadas', (select round(100.0 * rejeitadas / nullif(amostras, 0), 1) from a),
          'entregues', coalesce((select entregues from a), 0), 'atraso', coalesce((select atraso from a), 0),
          'pc_no_prazo', (select round(100.0 * (entregues - atraso) / nullif(entregues, 0), 1) from a),
          'pc_no_prazo_antes', (select round(100.0 * (entregues - atraso) / nullif(entregues, 0), 1) from b),
          'tat_horas', (select tat_horas from a)),
      'protocolos', jsonb_build_object(
          'relatorios', coalesce((select com_prot from a), 0),
          'verificados', coalesce((select prot_verificados from a), 0), 'conformes', coalesce((select prot_conformes from a), 0),
          'pc', (select round(100.0 * prot_conformes / nullif(prot_verificados, 0), 1) from a),
          'pc_antes', (select round(100.0 * prot_conformes / nullif(prot_verificados, 0), 1) from b),
          'falhas', coalesce((select j from tipos where campo = 'prot_falhas'), '[]'::jsonb),
          'por_area', (select j from prot_area))) j
  ),
  alertas as (
    select coalesce(jsonb_agg(al), '[]'::jsonb) lista from (
      select jsonb_build_object('nivel', 'perigo', 'texto', (j#>>'{incidentes,incidentes}') || ' incidente(s) com dano ao utente nos últimos 30 dias. Cada um pede análise da causa e plano de acção.') al
        from q where (j#>>'{incidentes,incidentes}')::int > 0
      union all
      select jsonb_build_object('nivel', 'aviso', 'texto', 'Satisfação dos utentes: ' || (j#>>'{satisfacao,satisfeitos}') || ' de ' || (j#>>'{satisfacao,respostas}') || ' satisfeitos (' || replace(j#>>'{satisfacao,pc}', '.', ',') || '%; referência: 85% ou mais).')
        from q where (j#>>'{satisfacao,pc}')::numeric < 85
      union all
      select jsonb_build_object('nivel', 'aviso', 'texto', (j#>>'{espera,mais_30}') || ' de ' || (j#>>'{espera,utentes}') || ' utentes esperaram mais de 30 minutos (' || replace(j#>>'{espera,pc_mais_30}', '.', ',') || '%; referência: abaixo de 20%).')
        from q where (j#>>'{espera,pc_mais_30}')::numeric >= 20
      union all
      select jsonb_build_object('nivel', 'aviso', 'texto', 'Resultados do laboratório no prazo: ' || replace(j#>>'{laboratorio,pc_no_prazo}', '.', ',') || '% (' || (j#>>'{laboratorio,atraso}') || ' de ' || (j#>>'{laboratorio,entregues}') || ' fora do prazo; referência: 95% ou mais no prazo).')
        from q where (j#>>'{laboratorio,pc_no_prazo}')::numeric < 95
      union all
      select jsonb_build_object('nivel', 'aviso', 'texto', 'Amostras rejeitadas: ' || (j#>>'{laboratorio,rejeitadas}') || ' de ' || (j#>>'{laboratorio,amostras}') || ' (' || replace(j#>>'{laboratorio,pc_rejeitadas}', '.', ',') || '%; referência: abaixo de 2%).')
        from q where (j#>>'{laboratorio,pc_rejeitadas}')::numeric >= 2
      union all
      select jsonb_build_object('nivel', 'aviso', 'texto', 'Cumprimento de protocolos: ' || (j#>>'{protocolos,conformes}') || ' de ' || (j#>>'{protocolos,verificados}') || ' actos (' || replace(j#>>'{protocolos,pc}', '.', ',') || '%; referência: 95% ou mais).')
        from q where (j#>>'{protocolos,pc}')::numeric < 95
    ) y
  )
  select (select j from q) || jsonb_build_object('alertas', (select lista from alertas))
$function$;
revoke all on function erp.qualidade_clinica_dados(date) from public, anon, authenticated;
grant execute on function erp.qualidade_clinica_dados(date) to service_role;

create or replace function public.bsp_srv_direccao_clinica(p_dia date)
returns jsonb language sql stable security definer set search_path to 'public', 'erp'
as $$ select erp.direccao_clinica_dados(p_dia) || jsonb_build_object('qualidade', erp.qualidade_clinica_dados(p_dia)) $$;
revoke all on function public.bsp_srv_direccao_clinica(date) from public, anon, authenticated;
grant execute on function public.bsp_srv_direccao_clinica(date) to service_role;

insert into public.novidades (titulo, texto, grupos, destino)
select 'Relatórios de turno: qualidade clínica',
       'Os relatórios de turno pedem agora os dados de qualidade: incidentes e quase-erros (todas as áreas), espera e satisfação dos utentes (Recepção), amostras e entrega dos resultados (Laboratório) e cumprimento dos protocolos (áreas de saúde). Só números, nunca nomes de utentes.',
       array['recepcao', 'farmacia', 'laboratorio', 'radiologia', 'enfermagem', 'direccao-clinica', 'gestao'], 'relatorios'
 where not exists (select 1 from public.novidades where titulo = 'Relatórios de turno: qualidade clínica');

notify pgrst, 'reload schema';
