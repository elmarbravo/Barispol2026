-- Auditoria do Painel clínico (30-10-2026, Elmar: «a mesma auditoria faça no
-- painel clínico» → «sim» aos 11 pontos e aos três avisos no telemóvel).
-- bsp_clinico_qualidade(de, ate, areas, tudo) junta ao bsp_painel_clinico:
--   espera       triagem → consulta (erp.espera_utente): média, acima de 2 h,
--                por médico (só quem vê tudo)
--   relatorios   entregues, com «precisa de atenção» (bsp_relatorio_atencao) e
--                os que faltam pela escala publicada, por pessoa
--   turnos       aberturas e fechos em falta (Laboratório e Enfermagem, desde
--                31-10-2026), diferenças na passagem de turno, reagentes no fim
--                do prazo
--   seguranca    ocorrências, incidentes e quase-erros por área (OMS: zero
--                registos = subnotificação)
--   satisfacao   inquéritos (feedback_utentes): respostas, média, reclamações
--   registo      consultas facturadas × consultas com registo clínico no
--                MetaGest (erp.clin_consulta) e sem diagnóstico, por médico;
--                registos do Workspace; credenciais registadas
--   pedidos      pedidos à Farmácia por entregar e recebidos com problema
--   presencas    médicos com facturas hoje sem chegada marcada
--   marcacoes    taxa de comparência
--   alertas      os que daí saem, juntos aos do erp.clinico_dados
-- Cada chefe vê só a sua área; nomes só da equipa e dos médicos, nunca de
-- utentes. Telemóvel: bsp_clinico_alertar() (cron bsp-clinico-alertas, minutos
-- 27 e 57, livres): utente à espera há mais de 2 h, valores críticos por
-- comunicar num relatório, área clínica sem nenhum registo de segurança em 30
-- dias (uma vez por semana). Destino: Direcção Clínica (u14) e Elmar (u1); os
-- valores críticos também ao chefe da área. Uma vez cada (clinico_avisos).

create table if not exists public.clinico_avisos (
  chave text primary key,
  criado timestamptz not null default now()
);
alter table public.clinico_avisos enable row level security;
revoke all on public.clinico_avisos from anon, authenticated;

create or replace function public.bsp_equipa_nome(p_id text)
returns text language sql stable security definer set search_path to 'public'
as $f$
  select coalesce((select case when array_length(regexp_split_to_array(btrim(x->>'name'), '\s+'), 1) > 2
                 then split_part(btrim(x->>'name'), ' ', 1) || ' ' || (regexp_split_to_array(btrim(x->>'name'), '\s+'))[array_length(regexp_split_to_array(btrim(x->>'name'), '\s+'), 1)]
                 else btrim(x->>'name') end
     from shared_state s, jsonb_array_elements(s.team) x where x->>'id' = p_id limit 1), p_id);
$f$;
revoke all on function public.bsp_equipa_nome(text) from public, anon, authenticated;

create or replace function public.bsp_clinico_qualidade(p_de date, p_ate date, p_areas text[], p_tudo boolean)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'erp'
as $f$
declare
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  agora timestamp := now() at time zone 'Africa/Luanda';
  ve text[] := p_areas;           -- chaves do painel: recepcao, clinica, laboratorio, farmacia, enfermagem, radiologia
  rel_ve text[];                  -- as mesmas nos relatórios: rececao, imagiologia
  al jsonb := '[]'::jsonb; res jsonb := '{}'::jsonb;
  d date; e record; t jsonb; ids text[]; area_form text; dow int; fim timestamp;
  falta_rel jsonb := '[]'::jsonb; falta_turno jsonb := '[]'::jsonb; v jsonb;
begin
  rel_ve := array(select case a when 'recepcao' then 'rececao' when 'radiologia' then 'imagiologia' else a end from unnest(ve) a);

  -- Espera triagem → consulta (minutos), só registos plausíveis (< 6 h).
  if p_tudo or 'clinica' = any (ve) or 'recepcao' = any (ve) then
    with w as (
      select medico, extract(epoch from (consulta - triagem)) / 60 minutos
        from erp.espera_utente
       where dia between p_de and p_ate and triagem is not null and consulta > triagem and consulta - triagem < interval '6 hours')
    select jsonb_build_object('n', count(*), 'media', round(avg(minutos)), 'acima_2h', count(*) filter (where minutos > 120),
      'por_medico', case when p_tudo then (select coalesce(jsonb_agg(z order by z.media desc), '[]') from (
          select coalesce((select nome from erp.medicos where codigo = w2.medico), w2.medico, '—') medico, count(*) n, round(avg(minutos)) media,
                 count(*) filter (where minutos > 120) acima_2h
            from w w2 group by w2.medico having count(*) >= 3) z) else '[]'::jsonb end)
      into v from w;
    res := res || jsonb_build_object('espera', v);
    if coalesce((v->>'acima_2h')::int, 0) > 0 then
      al := al || jsonb_build_object('area', 'clinica', 'nivel', case when (v->>'media')::numeric > 60 then 'perigo' else 'aviso' end, 'o', 10,
        'texto', (v->>'acima_2h') || ' de ' || (v->>'n') || ' utentes esperaram mais de 2 h da triagem à consulta (média ' || (v->>'media') || ' min).');
    end if;
  end if;

  -- Relatórios de turno: entregues e com «precisa de atenção».
  select jsonb_build_object('entregues', count(*),
           'com_atencao', count(*) filter (where cardinality(public.bsp_relatorio_atencao(respostas)) > 0),
           'lista', coalesce((select jsonb_agg(z order by z.dia desc, z.area) from (
              select r2.area, r2.dia, r2.turno, public.bsp_equipa_nome(r2.user_id) quem, to_jsonb(public.bsp_relatorio_atencao(r2.respostas)) pontos
                from relatorios_area r2
               where r2.dia between p_de and p_ate and (p_tudo or r2.area = any (rel_ve))
                 and cardinality(public.bsp_relatorio_atencao(r2.respostas)) > 0
               order by r2.dia desc limit 20) z), '[]'::jsonb))
    into v from relatorios_area r where r.dia between p_de and p_ate and (p_tudo or r.area = any (rel_ve));
  res := res || jsonb_build_object('relatorios', v);

  -- Em falta pela escala publicada (dias já fechados do período).
  d := p_de;
  while d <= least(p_ate, hoje) loop
    dow := extract(dow from d)::int;
    for e in select * from escalas where mes = date_trunc('month', d)::date and estado = 'publicada'
               and area in ('recepcao', 'laboratorio', 'farmacia', 'enfermagem', 'radiologia') and (p_tudo or area = any (ve)) loop
      area_form := case e.area when 'recepcao' then 'rececao' when 'radiologia' then 'imagiologia' else e.area end;
      for t in select * from jsonb_array_elements(coalesce(e.turnos, '[]'::jsonb)) loop
        if not coalesce(t->'semana' @> to_jsonb(dow), false) then continue; end if;
        -- Turnos opcionais e de chefia não entregam relatório próprio.
        if coalesce((t->>'opcional')::boolean, false) or coalesce(t->>'nome', '') ~* 'chefia' then continue; end if;
        select coalesce(array_agg(x), '{}') into ids
          from jsonb_array_elements_text(coalesce(e.dias->(d::text)->(t->>'id'), '[]'::jsonb)) x
         where x !~ '^x:' and not exists (select 1 from shared_state s, jsonb_array_elements(s.team) m
                                            where m->>'id' = x and coalesce((m->>'inactivo')::boolean, false));
        if cardinality(ids) = 0 then continue; end if;
        fim := d + coalesce(nullif(t->>'fim', ''), '22:30')::time;
        if fim < d + coalesce(nullif(t->>'inicio', ''), '00:00')::time then fim := fim + interval '1 day'; end if;
        if agora < fim + interval '1 hour' then continue; end if;
        -- Cada área conta desde o primeiro relatório que entregou pelo Workspace.
        if d >= coalesce((select min(r.dia) from relatorios_area r where r.area = area_form), 'infinity'::date)
           and not exists (select 1 from relatorios_area r where r.area = area_form and r.dia = d and r.user_id = any (ids)) then
          falta_rel := falta_rel || jsonb_build_object('area', area_form, 'dia', d, 'turno', t->>'nome',
            'pessoas', (select jsonb_agg(public.bsp_equipa_nome(i)) from unnest(ids) i));
        end if;
        if e.area in ('laboratorio', 'enfermagem') and d >= date '2026-10-31' then
          if not exists (select 1 from turno_contagens c where c.area = e.area and c.dia = d and c.turno = t->>'nome' and c.momento = 'abertura') then
            falta_turno := falta_turno || jsonb_build_object('area', e.area, 'dia', d, 'turno', t->>'nome', 'momento', 'abertura',
              'pessoas', (select jsonb_agg(public.bsp_equipa_nome(i)) from unnest(ids) i));
          end if;
          if not exists (select 1 from turno_contagens c where c.area = e.area and c.dia = d and c.turno = t->>'nome' and c.momento = 'fecho') then
            falta_turno := falta_turno || jsonb_build_object('area', e.area, 'dia', d, 'turno', t->>'nome', 'momento', 'fecho',
              'pessoas', (select jsonb_agg(public.bsp_equipa_nome(i)) from unnest(ids) i));
          end if;
        end if;
      end loop;
    end loop;
    d := d + 1;
  end loop;
  res := res || jsonb_build_object('relatorios_falta', falta_rel, 'turnos_falta', falta_turno);
  if jsonb_array_length(falta_rel) > 0 then
    al := al || jsonb_build_object('area', case when p_tudo then 'clinica' else ve[1] end, 'nivel', 'aviso', 'o', 11,
      'texto', jsonb_array_length(falta_rel) || ' relatório(s) de turno por entregar no período: '
        || (select string_agg(q.nome || ' (' || q.k || ')', ', ' order by q.k desc) from (
              select p #>> '{}' nome, count(*) k from jsonb_array_elements(falta_rel) f, jsonb_array_elements(f->'pessoas') p group by 1 order by 2 desc limit 6) q) || '.');
  end if;
  if jsonb_array_length(falta_turno) > 0 then
    al := al || jsonb_build_object('area', case when p_tudo then 'laboratorio' else ve[1] end, 'nivel', 'perigo', 'o', 12,
      'texto', jsonb_array_length(falta_turno) || ' abertura(s) ou fecho(s) de turno em falta: '
        || (select string_agg(q.nome || ' (' || q.k || ')', ', ' order by q.k desc) from (
              select p #>> '{}' nome, count(*) k from jsonb_array_elements(falta_turno) f, jsonb_array_elements(f->'pessoas') p group by 1 order by 2 desc limit 6) q) || '.');
  end if;

  -- Turno: diferenças na passagem e reagentes no fim do prazo.
  select jsonb_build_object('contagens', count(*), 'diferencas', count(*) filter (where jsonb_array_length(coalesce(diferencas, '[]')) > 0),
           'fora_escala', count(*) filter (where fora_escala),
           'lista', coalesce((select jsonb_agg(z order by z.dia desc) from (
              select c2.area, c2.dia, c2.turno, public.bsp_equipa_nome(c2.user_id) quem, jsonb_array_length(c2.diferencas) linhas, c2.motivo
                from turno_contagens c2 where c2.dia between p_de and p_ate and jsonb_array_length(coalesce(c2.diferencas, '[]')) > 0
                 and (p_tudo or c2.area = any (ve)) order by c2.dia desc limit 10) z), '[]'::jsonb),
           'reagentes_prazo', (select count(*) from turno_reagente_avisos a where a.criado::date between p_de and p_ate and (p_tudo or 'laboratorio' = any (ve))))
    into v from turno_contagens c where c.dia between p_de and p_ate and (p_tudo or c.area = any (ve));
  res := res || jsonb_build_object('turnos', v);

  -- Segurança do doente (ocorrências + incidentes e quase-erros dos relatórios).
  select coalesce(jsonb_agg(z order by z.area), '[]') into v from (
    select a area,
           (select count(*) from ocorrencias o where o.area = a and o.criado_em::date between p_de and p_ate) ocorrencias,
           (select coalesce(sum(public.bsp_rel_n(r.respostas, 'incidentes')), 0) from relatorios_area r
             where r.area = case a when 'recepcao' then 'rececao' when 'radiologia' then 'imagiologia' else a end and r.dia between p_de and p_ate) incidentes,
           (select coalesce(sum(public.bsp_rel_n(r.respostas, 'quase_erros')), 0) from relatorios_area r
             where r.area = case a when 'recepcao' then 'rececao' when 'radiologia' then 'imagiologia' else a end and r.dia between p_de and p_ate) quase_erros,
           (select count(*) from ocorrencias o where o.area = a and o.criado_em > now() - interval '30 days')
           + (select count(*) from relatorios_area r where r.area = case a when 'recepcao' then 'rececao' when 'radiologia' then 'imagiologia' else a end
                and r.dia > hoje - 30 and (public.bsp_rel_n(r.respostas, 'incidentes') > 0 or public.bsp_rel_n(r.respostas, 'quase_erros') > 0)) ult30
      from unnest(array['clinica', 'laboratorio', 'enfermagem', 'farmacia', 'radiologia', 'recepcao']) a
     where p_tudo or a = any (ve)) z;
  res := res || jsonb_build_object('seguranca', v);
  select string_agg(case x->>'area' when 'clinica' then 'Clínica' when 'laboratorio' then 'Laboratório' when 'enfermagem' then 'Enfermagem'
                     when 'farmacia' then 'Farmácia' when 'radiologia' then 'Imagiologia' else 'Recepção' end, ', ')
    into area_form from jsonb_array_elements(v) x where (x->>'ult30')::int = 0;
  if area_form is not null then
    al := al || jsonb_build_object('area', case when p_tudo then 'clinica' else ve[1] end, 'nivel', 'aviso', 'o', 13,
      'texto', 'Sem nenhuma ocorrência, incidente ou quase-erro reportado em 30 dias: ' || area_form || '. Pela OMS, zero registos indica subnotificação: lembrar a equipa de reportar.');
  end if;

  -- Satisfação.
  select jsonb_build_object('n', count(*), 'media', round(avg(nota)::numeric, 2), 'reclamacoes', count(*) filter (where tipo ilike 'reclama%'),
           'abertas', count(*) filter (where tipo ilike 'reclama%' and fechado_em is null))
    into v from feedback_utentes where criado_em::date between p_de and p_ate
     and (p_tudo or coalesce(area, '') = any (ve) or coalesce(area, '') = '');
  res := res || jsonb_build_object('satisfacao', v);
  if coalesce((v->>'abertas')::int, 0) > 0 then
    al := al || jsonb_build_object('area', 'clinica', 'nivel', 'perigo', 'o', 14, 'texto', (v->>'abertas') || ' reclamação(ões) por fechar.');
  end if;

  -- Registo clínico no MetaGest, por médico (só quem vê tudo ou a Clínica).
  if p_tudo or 'clinica' = any (ve) then
    with fac as (
      select s.ref_practitioner cod, count(distinct (s.posting_date, coalesce(s.patient, s.customer))) consultas
        from erp.sales_invoice s
       where s.docstatus = 1 and not s.is_return and s.posting_date between p_de and p_ate and s.ref_practitioner is not null
         and exists (select 1 from erp.sales_invoice_item i where i.parent = s.name and coalesce(i.item_group, '') ~* 'CONSULTA' and i.amount > 0)
       group by 1),
    reg as (
      select medico cod, count(distinct (dia, patient)) registos,
             count(distinct (dia, patient)) filter (where coalesce(diagnosticos::text, '') in ('', '[]', 'null', '""')) sem_diag
        from erp.clin_consulta where dia between p_de and p_ate and coalesce(docstatus, 0) <> 2 group by 1),
    j as (
      select coalesce((select nome from erp.medicos where codigo = coalesce(fac.cod, reg.cod)), coalesce(fac.cod, reg.cod)) medico,
             coalesce(fac.consultas, 0) consultas, coalesce(reg.registos, 0) registos, coalesce(reg.sem_diag, 0) sem_diag
        from fac full join reg on reg.cod = fac.cod)
    select jsonb_build_object('consultas', coalesce(sum(consultas), 0), 'registos', coalesce(sum(registos), 0), 'sem_diag', coalesce(sum(sem_diag), 0),
             'por_medico', case when p_tudo then coalesce(jsonb_agg(j order by j.consultas desc) filter (where j.consultas > 0 or j.registos > 0), '[]') else '[]'::jsonb end,
             'workspace', (select count(*) from registo_clinico where dia between p_de and p_ate),
             'credenciais', (select count(distinct medico) from credenciais),
             'medicos_activos', (select count(distinct cod) from fac))
      into v from j;
    res := res || jsonb_build_object('registo', v);
    if (v->>'consultas')::int > 0 and (v->>'registos')::numeric < 0.8 * (v->>'consultas')::numeric then
      al := al || jsonb_build_object('area', 'clinica', 'nivel', 'perigo', 'o', 15,
        'texto', 'Registo clínico no MetaGest: só ' || (v->>'registos') || ' de ' || (v->>'consultas') || ' consultas facturadas ('
          || round(100 * (v->>'registos')::numeric / (v->>'consultas')::numeric) || '%); ' || (v->>'sem_diag') || ' sem diagnóstico.');
    end if;
    if (v->>'workspace')::int = 0 then
      al := al || jsonb_build_object('area', 'clinica', 'nivel', 'info', 'o', 16, 'texto', 'Nenhum registo clínico no Workspace neste período.');
    end if;
    if (v->>'credenciais')::int < (v->>'medicos_activos')::int then
      al := al || jsonb_build_object('area', 'clinica', 'nivel', 'info', 'o', 17,
        'texto', 'Credenciais registadas de ' || (v->>'credenciais') || ' médico(s); ' || (v->>'medicos_activos') || ' facturaram neste período. Sem registo, o aviso de caducidade não funciona.');
    end if;
  end if;

  -- Pedidos à Farmácia.
  select jsonb_build_object('por_entregar', count(*) filter (where estado = 'Pedido'), 'por_conferir', count(*) filter (where estado = 'Entregue'),
           'com_problema', count(*) filter (where problema and recebido_em::date between p_de and p_ate),
           'mais_antigo', min(criado) filter (where estado = 'Pedido'))
    into v from pedidos_area where p_tudo or area = any (ve) or 'farmacia' = any (ve);
  res := res || jsonb_build_object('pedidos', v);
  if coalesce((v->>'com_problema')::int, 0) > 0 then
    al := al || jsonb_build_object('area', 'farmacia', 'nivel', 'aviso', 'o', 18, 'texto', (v->>'com_problema') || ' recepção(ões) de produtos com problema no período.');
  end if;
  if (v->>'mais_antigo') is not null and (v->>'mais_antigo')::timestamptz < now() - interval '24 hours' then
    al := al || jsonb_build_object('area', 'farmacia', 'nivel', 'perigo', 'o', 19, 'texto', 'Há pedidos à Farmácia por entregar há mais de 24 h.');
  end if;

  -- Médicos com facturas hoje e sem chegada marcada (Recepção e quem vê tudo).
  if p_tudo or 'recepcao' = any (ve) then
    begin
      select coalesce(jsonb_agg(jsonb_build_object('nome', x->>'nome', 'facturas', (x->>'facturas')::int)), '[]') into v
        from jsonb_array_elements(to_jsonb(public.bsp_presencas_dia(hoje))) x
       where coalesce(x->>'entrada', '') = '' and coalesce((x->>'facturas')::int, 0) > 0;
    exception when others then v := '[]'::jsonb;
    end;
    res := res || jsonb_build_object('sem_chegada', v);
    if jsonb_array_length(v) > 0 then
      al := al || jsonb_build_object('area', 'recepcao', 'nivel', 'aviso', 'o', 20,
        'texto', 'Médicos com facturas hoje sem chegada marcada: ' || (select string_agg(x->>'nome', ', ') from jsonb_array_elements(v) x) || '.');
    end if;
  end if;

  -- Comparência das marcações.
  select jsonb_build_object('compareceu', count(*) filter (where estado = 'Compareceu'), 'faltou', count(*) filter (where estado = 'Faltou'),
           'cancelou', count(*) filter (where estado = 'Cancelou'))
    into v from marcacoes where data_marcada between p_de and least(p_ate, hoje);
  res := res || jsonb_build_object('comparencia', v);

  return res || jsonb_build_object('alertas_novos', al);
end $f$;
revoke all on function public.bsp_clinico_qualidade(date, date, text[], boolean) from public, anon, authenticated;

create or replace function public.bsp_painel_clinico(p_de date, p_ate date)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'public', 'erp'
as $function$
declare
  eu text := public.bsp_meu_id();
  tudo boolean;
  minhas text[];
  d jsonb;
  q jsonb;
  areas text[];
begin
  if eu is null then raise exception 'Sem sessão.'; end if;
  if p_ate < p_de or p_ate - p_de > 92 then raise exception 'Período inválido (até 3 meses).'; end if;
  tudo := coalesce(public.bsp_e_gestor(), false) or coalesce(public.bsp_ve_painel(), false) or coalesce(public.bsp_le_areas_medicas(), false);
  -- Médicos e restante equipa não vêem o Painel clínico (Elmar, 02-10-2026):
  -- só a gestão, a Direcção Clínica e os chefes de área, cada chefe só a sua.
  -- Os médicos vêem a sua produção em «A minha actividade».
  minhas := array(select r.area from public.bsp_escalas_responsaveis() r where eu = any (r.ids));
  if not tudo and coalesce(cardinality(minhas), 0) = 0 then
    raise exception 'O Painel clínico é só da Direcção, da Direcção Clínica e dos chefes de área.';
  end if;
  areas := case when tudo then array['recepcao', 'clinica', 'laboratorio', 'farmacia', 'enfermagem', 'radiologia', 'servicos gerais'] else minhas end;
  d := erp.clinico_dados(p_de, p_ate);
  -- Auditoria (30-10-2026, clinico-auditoria.sql).
  q := public.bsp_clinico_qualidade(p_de, p_ate, areas, tudo);
  return d || (q - 'alertas_novos') || jsonb_build_object(
    'tudo', tudo,
    'areas', to_jsonb(areas),
    'alertas', coalesce((select jsonb_agg(a order by coalesce((a->>'o')::int, 99)) from (
                  select a from jsonb_array_elements(d->'alertas') a where tudo or a->>'area' = any (minhas)
                  union all
                  select a from jsonb_array_elements(q->'alertas_novos') a) z), '[]'::jsonb),
    'stock', case when tudo then d->'stock' else coalesce((select jsonb_object_agg(k, v) from jsonb_each(d->'stock') x(k, v) where k = any (minhas)), '{}'::jsonb) end,
    -- A produção por médico é só de quem vê tudo.
    'medicos', case when tudo then d->'medicos' else '[]'::jsonb end,
    'extra', jsonb_strip_nulls(jsonb_build_object(
      'documentos', case when tudo or 'recepcao' = any (minhas) then d->'extra'->'documentos' end,
      'marcacoes_por_fechar', case when tudo or 'recepcao' = any (minhas) then d->'extra'->'marcacoes_por_fechar' end,
      'sem_medico_acum', case when tudo or 'recepcao' = any (minhas) then d->'extra'->'sem_medico_acum' end,
      'rascunhos', case when tudo or 'recepcao' = any (minhas) then d->'extra'->'rascunhos' end,
      'farmacia_vendido', case when tudo or 'farmacia' = any (minhas) then d->'extra'->'farmacia_vendido' end,
      'farmacia_repor', case when tudo or 'farmacia' = any (minhas) then d->'extra'->'farmacia_repor' end,
      'lab_consumiveis', case when tudo or 'laboratorio' = any (minhas) then d->'extra'->'lab_consumiveis' end)));
end $function$;

-- Telemóvel (de 30 em 30 min).
create or replace function public.bsp_clinico_alertar()
returns jsonb language plpgsql volatile security definer set search_path to 'public', 'erp'
as $f$
declare
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  agora timestamp := now() at time zone 'Africa/Luanda';
  r record; enviados int := 0; txt text; chefes text[]; semana text := to_char(hoje, 'IYYY-IW');
begin
  -- 1. Utente à espera há mais de 2 h (triagem feita, consulta ainda não) ou que
  --    esperou mais de 2 h (consulta já feita, hoje).
  for r in
    select md5(e.chave) chave, e.triagem, e.consulta, coalesce((select nome from erp.medicos where codigo = e.medico), 'sem médico') medico
      from erp.espera_utente e
     where e.dia = hoje and e.triagem is not null
       and ((e.consulta is null and e.saida is null and agora - (e.dia + e.triagem) > interval '2 hours' and agora - (e.dia + e.triagem) < interval '8 hours')
            or (e.consulta > e.triagem and e.consulta - e.triagem > interval '2 hours' and e.consulta - e.triagem < interval '6 hours'
                and agora - (e.dia + e.consulta) < interval '40 minutes'))
  loop
    insert into clinico_avisos (chave) values ('esp-' || hoje || '-' || r.chave) on conflict do nothing;
    if found then
      perform public.bsp_push_post(jsonb_build_object('para', jsonb_build_array('u14', 'u1'), 'titulo', 'Utente à espera há mais de 2 horas',
        'corpo', case when r.consulta is null then 'Triagem às ' || to_char(r.triagem, 'HH24:MI') || ', ainda sem consulta (' || r.medico || ').'
                      else 'Triagem às ' || to_char(r.triagem, 'HH24:MI') || ', consulta às ' || to_char(r.consulta, 'HH24:MI') || ' (' || r.medico || ').' end,
        'url', '#/painel-clinico', 'tag', 'clin-esp-' || hoje || '-' || r.chave));
      enviados := enviados + 1;
    end if;
  end loop;

  -- 2. Relatório com valores críticos por comunicar ao médico.
  for r in
    select ra.id, ra.area, ra.dia, ra.user_id, public.bsp_rel_n(ra.respostas, 'criticos') - public.bsp_rel_n(ra.respostas, 'criticos_comunicados') n
      from relatorios_area ra
     where ra.created_at > now() - interval '2 days'
       and public.bsp_rel_n(ra.respostas, 'criticos') > public.bsp_rel_n(ra.respostas, 'criticos_comunicados')
  loop
    insert into clinico_avisos (chave) values ('crit-' || r.id) on conflict do nothing;
    if found then
      select coalesce(array_agg(distinct x), '{}') into chefes from public.bsp_escalas_responsaveis() er, unnest(er.ids) x where er.area = r.area;
      perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(array(select distinct unnest(chefes || array['u14', 'u1']))),
        'titulo', 'Valores críticos por comunicar ao médico',
        'corpo', 'Laboratório, ' || to_char(r.dia, 'DD-MM') || ': ' || r.n || ' valor(es) crítico(s) não comunicado(s). Relatório de ' || public.bsp_equipa_nome(r.user_id) || '.',
        'url', '#/relatorios', 'tag', 'clin-crit-' || r.id));
      enviados := enviados + 1;
    end if;
  end loop;

  -- 3. Áreas clínicas sem nenhum registo de segurança em 30 dias (às segundas,
  --    uma vez por semana, depois das 09h00).
  if extract(isodow from hoje) = 1 and extract(hour from agora) >= 9 then
    select string_agg(nome, ', ') into txt from (
      select a, case a when 'clinica' then 'Clínica' when 'laboratorio' then 'Laboratório' when 'enfermagem' then 'Enfermagem'
                       when 'farmacia' then 'Farmácia' when 'radiologia' then 'Imagiologia' else 'Recepção' end nome
        from unnest(array['clinica', 'laboratorio', 'enfermagem', 'farmacia', 'radiologia', 'recepcao']) a
       where not exists (select 1 from ocorrencias o where o.area = a and o.criado_em > now() - interval '30 days')
         and not exists (select 1 from relatorios_area ra where ra.area = case a when 'recepcao' then 'rececao' when 'radiologia' then 'imagiologia' else a end
                           and ra.dia > hoje - 30 and (public.bsp_rel_n(ra.respostas, 'incidentes') > 0 or public.bsp_rel_n(ra.respostas, 'quase_erros') > 0))) z;
    if txt is not null then
      insert into clinico_avisos (chave) values ('semocorr-' || semana) on conflict do nothing;
      if found then
        perform public.bsp_push_post(jsonb_build_object('para', jsonb_build_array('u14', 'u1'), 'titulo', 'Áreas sem registos de segurança há 30 dias',
          'corpo', txt || ': nenhuma ocorrência, incidente ou quase-erro reportado. Zero registos costuma ser subnotificação.',
          'url', '#/painel-clinico', 'tag', 'clin-semocorr-' || semana));
        enviados := enviados + 1;
      end if;
    end if;
  end if;
  return jsonb_build_object('enviados', enviados);
end $f$;
revoke all on function public.bsp_clinico_alertar() from public, anon, authenticated;

select cron.schedule('bsp-clinico-alertas', '27,57 * * * *', 'select public.bsp_clinico_alertar()');
