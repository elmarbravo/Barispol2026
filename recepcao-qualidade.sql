-- Barispol Workspace · qualidade do atendimento da Recepção
-- Pedido do Elmar, 02-10-2026: «Esse relatório da receção está muito vago e
-- redundante, coloque dados de qualidade de atendimento da equipa e coisas
-- desta natureza». Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no
-- mesmo dia. Pode correr-se mais do que uma vez.
--
--   erp.recepcao_qualidade(dia)          os números do dia (e 7 dias)
--   public.bsp_srv_recepcao_qualidade(dia)  atalho só para a chave do servidor
-- Sai no relatório da Recepção das 07h15 (relatorios-diarios versão 9).
--
-- Por colaborador (nomes da equipa, nunca de utentes):
--   · WhatsApp (crm.caixa): pedidos, tempo até à primeira resposta de uma
--     pessoa, respondidos em 15 minutos, preço dado a quem o pediu,
--     marcados na conversa;
--   · MetaGest: documentos emitidos, sem médico solicitante, notas de
--     crédito (anulações) e rascunhos por fechar;
--   · marcações registadas no Workspace e se ficaram completas (telefone,
--     e-mail, ficha);
--   · Workspace aberto (presenca_dias: primeira e última hora).
-- E ainda: o estado das marcações de ontem e de amanhã, o relatório de turno
-- da Recepção (espera, satisfação, reclamações, incidentes) e os pedidos da
-- caixa de contacto do site.

create or replace function erp.recepcao_qualidade(p_dia date)
returns jsonb
language sql
stable
security definer
set search_path to 'erp', 'public', 'crm'
as $function$
  with equipa as (
    select e->>'id' id, e->>'name' nome, lower(btrim(e->>'email')) email, public.bsp_area_chave(e->>'dept') area
      from public.shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1
  ),
  rec as (select * from equipa where area = 'recepcao'),
  -- WhatsApp: pedidos de ontem e dos últimos 7 dias.
  wa as materialized (
    select (c.inicio at time zone 'Africa/Luanda')::date dia,
           nullif(btrim(c.responsavel), '') resp, c.msgs_clinica, c.resposta_humana_min, c.pediu_preco, c.preco_dado,
           c.marcado_na_conversa, c.no_horario
      from crm.caixa c
     where c.inicio >= (p_dia - 6)::timestamp at time zone 'Africa/Luanda'
       and c.inicio < (p_dia + 1)::timestamp at time zone 'Africa/Luanda'
     offset 0
  ),
  wa_tot as (
    select jsonb_build_object(
      'ontem', jsonb_build_object(
        'pedidos', count(*) filter (where dia = p_dia),
        'sem_resposta', count(*) filter (where dia = p_dia and coalesce(msgs_clinica, 0) = 0),
        'mediana_min', round((percentile_cont(0.5) within group (order by resposta_humana_min) filter (where dia = p_dia))::numeric, 0),
        'ate15', count(*) filter (where dia = p_dia and resposta_humana_min <= 15),
        'mais60', count(*) filter (where dia = p_dia and resposta_humana_min > 60),
        'com_resposta', count(*) filter (where dia = p_dia and resposta_humana_min is not null),
        'pediu_preco', count(*) filter (where dia = p_dia and pediu_preco),
        'preco_dado', count(*) filter (where dia = p_dia and pediu_preco and preco_dado),
        'marcou', count(*) filter (where dia = p_dia and marcado_na_conversa),
        'fora_horario', count(*) filter (where dia = p_dia and not coalesce(no_horario, true))),
      'semana', jsonb_build_object(
        'pedidos', count(*),
        'sem_resposta', count(*) filter (where coalesce(msgs_clinica, 0) = 0),
        'mediana_min', round((percentile_cont(0.5) within group (order by resposta_humana_min))::numeric, 0),
        'ate15', count(*) filter (where resposta_humana_min <= 15),
        'com_resposta', count(*) filter (where resposta_humana_min is not null),
        'pediu_preco', count(*) filter (where pediu_preco),
        'preco_dado', count(*) filter (where pediu_preco and preco_dado),
        'marcou', count(*) filter (where marcado_na_conversa))) j
      from wa
  ),
  wa_pessoa as (
    select coalesce(jsonb_agg(jsonb_build_object('nome', nome, 'pedidos', n, 'mediana_min', med, 'ate15', ate15, 'com_resposta', cr,
             'pediu_preco', pp, 'preco_dado', pd, 'marcou', mc) order by n desc, nome), '[]'::jsonb) j
      from (select initcap(lower(resp)) nome, count(*) n,
                   round((percentile_cont(0.5) within group (order by resposta_humana_min))::numeric, 0) med,
                   count(*) filter (where resposta_humana_min <= 15) ate15,
                   count(*) filter (where resposta_humana_min is not null) cr,
                   count(*) filter (where pediu_preco) pp, count(*) filter (where pediu_preco and preco_dado) pd,
                   count(*) filter (where marcado_na_conversa) mc
              from wa where resp is not null group by initcap(lower(resp))) x
  ),
  -- MetaGest: documentos de ontem por operador.
  fact as (
    select coalesce(q.nome, split_part(s.owner, '@', 1)) nome,
           count(*) filter (where s.docstatus = 1 and not coalesce(s.is_return, false)) documentos,
           count(*) filter (where s.docstatus = 1 and s.is_return) notas_credito,
           count(*) filter (where s.docstatus = 0) rascunhos,
           count(*) filter (where s.docstatus = 1 and not coalesce(s.is_return, false) and coalesce(s.ref_practitioner, '') = ''
                              and exists (select 1 from erp.sales_invoice_item i where i.parent = s.name and i.item_group ~* 'CONSULTA|LABORAT|RAIO|ECOGRAF|CARDIO')) sem_medico
      from erp.sales_invoice s
      left join equipa q on q.email = lower(s.owner)
     where s.posting_date = p_dia
     group by 1
  ),
  fact_j as (
    select coalesce(jsonb_agg(jsonb_build_object('nome', nome, 'documentos', documentos, 'notas_credito', notas_credito,
             'rascunhos', rascunhos, 'sem_medico', sem_medico) order by documentos desc, nome), '[]'::jsonb) j from fact
  ),
  -- Marcações registadas ontem no Workspace, por colaborador.
  marc_reg as (
    select coalesce(jsonb_agg(jsonb_build_object('nome', nome, 'marcacoes', n, 'com_telefone', t, 'com_email', e, 'com_ficha', f) order by n desc, nome), '[]'::jsonb) j
      from (select coalesce(q.nome, nullif(btrim(m.rececionista), ''), 'Sem nome') nome, count(*) n,
                   count(*) filter (where coalesce(m.tel9, '') <> '') t,
                   count(*) filter (where coalesce(m.email, '') <> '') e,
                   count(*) filter (where m.paciente_id is not null) f
              from public.marcacoes m left join equipa q on q.id = m.criado_por
             where (m.criado_em at time zone 'Africa/Luanda')::date = p_dia
             group by 1) x
  ),
  marc_dia as (
    select jsonb_build_object(
      'ontem', (select jsonb_build_object('total', count(*),
                  'compareceu', count(*) filter (where estado = 'Compareceu'), 'faltou', count(*) filter (where estado = 'Faltou'),
                  'cancelou', count(*) filter (where estado = 'Cancelou'), 'remarcado', count(*) filter (where estado = 'Remarcado'),
                  'em_aberto', count(*) filter (where estado in ('Agendada', 'Confirmada')))
                  from public.marcacoes where data_marcada = p_dia),
      'amanha', (select jsonb_build_object('total', count(*), 'confirmadas', count(*) filter (where estado = 'Confirmada'),
                  'por_confirmar', count(*) filter (where estado = 'Agendada'),
                  'sem_contacto', count(*) filter (where coalesce(tel9, '') = '' and coalesce(email, '') = ''))
                  from public.marcacoes where data_marcada = p_dia + 2)) j
  ),
  -- Workspace aberto ontem (primeira e última hora), por pessoa da Recepção.
  presenca as (
    select coalesce(jsonb_agg(jsonb_build_object('nome', r.nome,
             'primeira', to_char(p.primeira at time zone 'Africa/Luanda', 'HH24:MI'),
             'ultima', to_char(p.ultima at time zone 'Africa/Luanda', 'HH24:MI'),
             'horas', round((extract(epoch from p.ultima - p.primeira) / 3600)::numeric, 1)) order by r.nome), '[]'::jsonb) j
      from rec r left join public.presenca_dias p on p.user_id = r.id and p.dia = p_dia
  ),
  turno as (
    select jsonb_build_object('relatorios', count(*),
      'espera_min', round(avg((respostas->>'espera_min')::numeric) filter (where respostas ? 'espera_min'), 0),
      'espera_30', sum(coalesce((respostas->>'espera_30')::int, 0)),
      'satisf_resp', sum(coalesce((respostas->>'satisf_resp')::int, 0)),
      'satisf_ok', sum(coalesce((respostas->>'satisf_ok')::int, 0)),
      'reclamacoes', sum(coalesce((respostas->>'reclamacoes')::int, 0)),
      'incidentes', sum(coalesce((respostas->>'incidentes')::int, 0)),
      'quase_erros', sum(coalesce((respostas->>'quase_erros')::int, 0)),
      'fecho_caixa_por_enviar', count(*) filter (where respostas->>'fecho_caixa' = 'Por enviar')) j
      from public.relatorios_area where area = 'rececao' and dia = p_dia
  ),
  site as (
    select count(*) n from public.contactos_site where (criado_em at time zone 'Africa/Luanda')::date = p_dia
  )
  select jsonb_build_object(
    'dia', p_dia,
    'whatsapp', (select j from wa_tot),
    'whatsapp_pessoas', (select j from wa_pessoa),
    'facturacao', (select j from fact_j),
    'marcacoes_registadas', (select j from marc_reg),
    'marcacoes', (select j from marc_dia),
    'presenca', (select j from presenca),
    'turno', (select j from turno),
    'site', (select n from site))
$function$;
revoke all on function erp.recepcao_qualidade(date) from public, anon, authenticated;
grant execute on function erp.recepcao_qualidade(date) to service_role;

create or replace function public.bsp_srv_recepcao_qualidade(p_dia date)
returns jsonb language sql stable security definer set search_path to 'public', 'erp'
as $$ select erp.recepcao_qualidade(p_dia) $$;
revoke all on function public.bsp_srv_recepcao_qualidade(date) from public, anon, authenticated;
grant execute on function public.bsp_srv_recepcao_qualidade(date) to service_role;

notify pgrst, 'reload schema';
