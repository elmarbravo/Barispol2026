-- Registo clínico do médico no Workspace (05-10-2026). Pedido do Elmar: «sobre
-- a produção dos médicos dentro do workspace, preciso que coloque os dados
-- todos dos pacientes, pedidos de exames, resultados, observações de
-- enfermagem e tudo que o médico fez, para que o director clínico tenha os
-- dados todos a partir do sistema e só comparar. Quero que os médicos
-- preencham no sistema, encontram já as facturas e tudo.» Junta num só os três
-- papéis da Direcção Clínica: «Formulário de controlo de atendimento médico –
-- dia de banco», «Actividades realizadas por médico colaborador» e «Registo de
-- pacientes» (o que se repetia passa a vir do MetaGest ou a contar-se sozinho).
--
-- 1. Cópia do MetaGest (só no servidor, nunca no repositório nem no ecrã de
--    quem não deve ver): erp.clin_consulta (Patient Encounter: idade, sexo,
--    queixas, diagnóstico, análises pedidas, receita), erp.clin_triagem (Vital
--    Signs: tensão, pulso, temperatura, peso), erp.clin_lab (Lab Test: estado e
--    resultados), erp.clin_paciente (sexo e data de nascimento).
--    erp.sincronizar_clinico(de, ate): cron bsp-clinico-hoje (30 em 30 min,
--    07h–22h) e bsp-clinico (03h55, últimos 7 dias).
-- 2. public.registo_clinico: um registo por médico (código do MetaGest) e dia.
--    O médico escreve, por utente, o que o MetaGest não sabe (motivo,
--    diagnóstico, conduta, destino, urgente, observações) e no fim as
--    observações, dificuldades e sugestões. Rascunho → Submetido (recebe o
--    número BRSP-DC-BNC-AA-nnn) → Visto (Direcção Clínica ou gestão).
-- 3. Quem vê (regra «Quem vê o quê», dados de doentes): o próprio médico (pelo
--    campo metagest da equipa), a Direcção Clínica (bsp_le_areas_medicas) e a
--    gestão. Ninguém mais. Escrever: só o próprio médico (ou a gestão, para
--    ajudar). Visto: Direcção Clínica ou gestão.

-- ---------------------------------------------------------------- cópia
create table if not exists erp.clin_consulta (
  name text primary key, dia date, hora time, patient text, medico text,
  idade text, sexo text, departamento text,
  sintomas jsonb not null default '[]', diagnosticos jsonb not null default '[]',
  analises jsonb not null default '[]', receita jsonb not null default '[]',
  procedimentos jsonb not null default '[]', docstatus int, modificado text,
  sincronizado_em timestamptz not null default now());
create index if not exists clin_consulta_dia on erp.clin_consulta (dia, patient);

create table if not exists erp.clin_triagem (
  name text primary key, dia date, hora time, patient text, tensao text, pulso text,
  temperatura text, peso text, altura text, imc text, encontro text,
  sincronizado_em timestamptz not null default now());
create index if not exists clin_triagem_dia on erp.clin_triagem (dia, patient);

create table if not exists erp.clin_lab (
  name text primary key, dia date, patient text, exame text, estado text, docstatus int,
  resultado_em date, indicou text, idade text, sexo text,
  resultados jsonb not null default '[]', modificado text,
  sincronizado_em timestamptz not null default now());
create index if not exists clin_lab_dia on erp.clin_lab (dia, patient);

create table if not exists erp.clin_paciente (
  patient text primary key, sexo text, nascimento date,
  sincronizado_em timestamptz not null default now());

alter table erp.clin_consulta enable row level security;
alter table erp.clin_triagem enable row level security;
alter table erp.clin_lab enable row level security;
alter table erp.clin_paciente enable row level security;
revoke all on erp.clin_consulta, erp.clin_triagem, erp.clin_lab, erp.clin_paciente from public, anon, authenticated;

create or replace function erp.sincronizar_clinico(p_de date, p_ate date)
returns jsonb language plpgsql security definer set search_path to 'erp', 'public'
as $f$
declare
  filtro_dia text;
  x jsonb; d jsonb;
  n_c int := 0; n_t int := 0; n_l int := 0; n_p int := 0; k int;
  lista text[];
begin
  -- Triagem de enfermagem (campos de topo: chega a lista).
  filtro_dia := json_build_array(json_build_array('signs_date', '>=', p_de), json_build_array('signs_date', '<=', p_ate))::text;
  insert into erp.clin_triagem (name, dia, hora, patient, tensao, pulso, temperatura, peso, altura, imc, encontro, sincronizado_em)
  select v->>'name', (v->>'signs_date')::date, (v->>'signs_time')::time, v->>'patient',
         coalesce(nullif(v->>'bp', ''), nullif(concat_ws('/', nullif(v->>'bp_systolic', ''), nullif(v->>'bp_diastolic', '')), '')),
         v->>'pulse', v->>'temperature', v->>'weight', v->>'height', v->>'bmi', v->>'encounter', now()
    from jsonb_array_elements(erp.api_lista('Vital Signs',
           '["name","signs_date","signs_time","patient","bp","bp_systolic","bp_diastolic","pulse","temperature","weight","height","bmi","encounter","docstatus"]',
           filtro_dia)) v
   where coalesce((v->>'docstatus')::int, 0) < 2
  on conflict (name) do update set dia = excluded.dia, hora = excluded.hora, patient = excluded.patient, tensao = excluded.tensao,
     pulso = excluded.pulso, temperatura = excluded.temperatura, peso = excluded.peso, altura = excluded.altura, imc = excluded.imc,
     encontro = excluded.encontro, sincronizado_em = now();
  get diagnostics n_t = row_count;

  -- Consultas: a lista diz quais mudaram; o documento traz as tabelas filhas.
  filtro_dia := json_build_array(json_build_array('encounter_date', '>=', p_de), json_build_array('encounter_date', '<=', p_ate),
                                 json_build_array('docstatus', '<', 2))::text;
  for x in select * from jsonb_array_elements(erp.api_lista('Patient Encounter', '["name","modified"]', filtro_dia)) loop
    continue when exists (select 1 from erp.clin_consulta c where c.name = x->>'name' and c.modificado = x->>'modified');
    d := erp.api_get('/api/resource/Patient%20Encounter/' || erp.enc(x->>'name'));
    d := coalesce(d->'data', d);
    insert into erp.clin_consulta (name, dia, hora, patient, medico, idade, sexo, departamento, sintomas, diagnosticos, analises, receita, procedimentos, docstatus, modificado, sincronizado_em)
    values (d->>'name', (d->>'encounter_date')::date, (d->>'encounter_time')::time, d->>'patient', d->>'practitioner',
            d->>'patient_age', d->>'patient_sex', d->>'medical_department',
            coalesce((select jsonb_agg(e->>'complaint') from jsonb_array_elements(d->'symptoms') e where coalesce(e->>'complaint', '') <> ''), '[]'),
            coalesce((select jsonb_agg(e->>'diagnosis') from jsonb_array_elements(d->'diagnosis') e where coalesce(e->>'diagnosis', '') <> ''), '[]'),
            coalesce((select jsonb_agg(jsonb_build_object('exame', coalesce(e->>'lab_test_name', e->>'lab_test_code'), 'nota', e->>'lab_test_comment'))
                        from jsonb_array_elements(d->'lab_test_prescription') e), '[]'),
            coalesce((select jsonb_agg(jsonb_build_object('medicamento', coalesce(e->>'drug_name', e->>'drug_code'), 'dose', e->>'dosage',
                                                          'forma', e->>'dosage_form', 'periodo', e->>'period'))
                        from jsonb_array_elements(d->'drug_prescription') e), '[]'),
            coalesce((select jsonb_agg(coalesce(e->>'procedure_name', e->>'procedure')) from jsonb_array_elements(d->'procedure_prescription') e), '[]'),
            (d->>'docstatus')::int, d->>'modified', now())
    on conflict (name) do update set dia = excluded.dia, hora = excluded.hora, patient = excluded.patient, medico = excluded.medico,
       idade = excluded.idade, sexo = excluded.sexo, departamento = excluded.departamento, sintomas = excluded.sintomas,
       diagnosticos = excluded.diagnosticos, analises = excluded.analises, receita = excluded.receita,
       procedimentos = excluded.procedimentos, docstatus = excluded.docstatus, modificado = excluded.modificado, sincronizado_em = now();
    n_c := n_c + 1;
  end loop;

  -- Análises: lista com o estado; resultados só dos já validados.
  filtro_dia := json_build_array(json_build_array('creation', '>=', p_de), json_build_array('creation', '<', p_ate + 1))::text;
  for x in select * from jsonb_array_elements(erp.api_lista('Lab Test',
             '["name","modified","creation","patient","lab_test_name","status","docstatus","result_date","nome_medico_que_indicou","patient_age","patient_sex"]',
             filtro_dia)) loop
    continue when exists (select 1 from erp.clin_lab l where l.name = x->>'name' and l.modificado = x->>'modified');
    d := null;
    if (x->>'docstatus')::int = 1 then
      d := erp.api_get('/api/resource/Lab%20Test/' || erp.enc(x->>'name'));
      d := coalesce(d->'data', d);
    end if;
    insert into erp.clin_lab (name, dia, patient, exame, estado, docstatus, resultado_em, indicou, idade, sexo, resultados, modificado, sincronizado_em)
    values (x->>'name', (x->>'creation')::date, x->>'patient', x->>'lab_test_name', x->>'status', (x->>'docstatus')::int,
            nullif(x->>'result_date', '')::date, x->>'nome_medico_que_indicou', x->>'patient_age', x->>'patient_sex',
            coalesce((select jsonb_agg(jsonb_build_object('parametro', e->>'lab_test_name', 'valor', e->>'result_value'))
                        from jsonb_array_elements(d->'normal_test_items') e where coalesce(e->>'result_value', '') <> ''), '[]'),
            x->>'modified', now())
    on conflict (name) do update set dia = excluded.dia, patient = excluded.patient, exame = excluded.exame, estado = excluded.estado,
       docstatus = excluded.docstatus, resultado_em = excluded.resultado_em, indicou = excluded.indicou, idade = excluded.idade,
       sexo = excluded.sexo, resultados = excluded.resultados, modificado = excluded.modificado, sincronizado_em = now();
    n_l := n_l + 1;
  end loop;

  -- Sexo e data de nascimento dos utentes facturados no período.
  for lista in
    with u as (
      select distinct s.patient p
        from erp.sales_invoice s
       where s.posting_date between p_de and p_ate and coalesce(s.patient, '') <> ''
         and not exists (select 1 from erp.clin_paciente c where c.patient = s.patient)),
    g as (select p, (row_number() over (order by p) - 1) / 80 grupo from u)
    select array_agg(p) from g group by grupo
  loop
    insert into erp.clin_paciente (patient, sexo, nascimento, sincronizado_em)
    select v->>'name', v->>'sex', nullif(v->>'dob', '')::date, now()
      from jsonb_array_elements(erp.api_lista('Patient', '["name","sex","dob"]',
             json_build_array(json_build_array('name', 'in', to_jsonb(lista)))::text)) v
    on conflict (patient) do update set sexo = excluded.sexo, nascimento = excluded.nascimento, sincronizado_em = now();
    get diagnostics k = row_count;
    n_p := n_p + k;
  end loop;

  return jsonb_build_object('consultas', n_c, 'triagens', n_t, 'analises', n_l, 'utentes', n_p);
end $f$;
revoke all on function erp.sincronizar_clinico(date, date) from public, anon, authenticated;

-- ---------------------------------------------------------------- registo
create table if not exists public.registo_clinico (
  id bigint generated always as identity primary key,
  codigo text not null,                 -- código do médico no MetaGest (ref_practitioner)
  dia date not null,
  numero text unique,                   -- BRSP-DC-BNC-AA-nnn, dado ao submeter
  horario_de time, horario_ate time,
  linhas jsonb not null default '{}',   -- {utente: {motivo, diagnostico, conduta, destino, urgente, obs}}
  observacoes text not null default '', dificuldades text not null default '', sugestoes text not null default '',
  estado text not null default 'Rascunho' check (estado in ('Rascunho', 'Submetido', 'Visto')),
  criado_por text, actualizado_por text, actualizado_em timestamptz not null default now(),
  submetido_em timestamptz, visto_por text, visto_em timestamptz, nota_visto text not null default '',
  unique (codigo, dia));
alter table public.registo_clinico enable row level security;
revoke all on public.registo_clinico from anon, authenticated;

-- Códigos MetaGest do médico pedido, com a regra de acesso. Devolve null se a
-- pessoa não tiver códigos (não é médico ligado ao MetaGest).
create or replace function public.bsp_rc_codigos(p_membro text)
returns text[] language plpgsql stable security definer set search_path to 'public'
as $f$
declare
  eu text := public.bsp_meu_id();
  alvo text := coalesce(nullif(btrim(p_membro), ''), eu);
  codigos text[];
begin
  if eu is null or public.bsp_e_socio() then raise exception 'Sem acesso.'; end if;
  if alvo <> eu and not (public.bsp_e_gestor() or public.bsp_le_areas_medicas()) then
    raise exception 'Só vê os seus próprios doentes.';
  end if;
  if alvo like 'mg:%' then return array[substr(alvo, 4)]; end if;
  select array(select jsonb_array_elements_text(coalesce(e->'metagest', '[]'::jsonb))) into codigos
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e where s.id = 1 and e->>'id' = alvo limit 1;
  return nullif(codigos, '{}');
end $f$;
revoke all on function public.bsp_rc_codigos(text) from public, anon;
grant execute on function public.bsp_rc_codigos(text) to authenticated;

create or replace function public.bsp_registo_clinico_dia(p_dia date, p_membro text default null)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'erp'
as $f$
declare
  codigos text[] := public.bsp_rc_codigos(p_membro);
  r public.registo_clinico;
begin
  if codigos is null then return jsonb_build_object('ligado', false); end if;
  select * into r from public.registo_clinico where codigo = codigos[1] and dia = p_dia;
  return (
    with meus as (
      select distinct coalesce(s.patient, s.customer) p
        from erp.sales_invoice s
       where s.posting_date = p_dia and s.docstatus = 1 and not s.is_return and s.ref_practitioner = any (codigos)
      union
      select c.patient from erp.clin_consulta c where c.dia = p_dia and c.medico = any (codigos) and c.patient is not null
    ),
    fact as (
      select coalesce(s.patient, s.customer) p, s.name, coalesce(s.doc_agt, s.name) factura, s.posting_time hora,
             s.practitioner_name medico, s.ref_practitioner = any (codigos) minha, s.patient_name nome,
             case when s.customer_group = 'Seguradora' then s.customer_name end seguradora,
             (select coalesce(jsonb_agg(jsonb_build_object('grupo', i.item_group, 'nome', i.item_name, 'qtd', i.qty) order by i.idx), '[]')
                from erp.sales_invoice_item i where i.parent = s.name) itens
        from erp.sales_invoice s
       where s.posting_date = p_dia and s.docstatus = 1 and not s.is_return
         and coalesce(s.patient, s.customer) in (select p from meus)
    )
    select jsonb_build_object(
      'ligado', true, 'codigo', codigos[1], 'dia', p_dia,
      'medico', (select max(practitioner_name) from erp.sales_invoice where ref_practitioner = any (codigos) and posting_date > p_dia - 400),
      'registo', case when r.id is null then null else to_jsonb(r) end,
      'utentes', coalesce((
        select jsonb_agg(jsonb_build_object(
          'chave', m.p,
          'nome', (select max(f.nome) from fact f where f.p = m.p),
          'sexo', coalesce((select sexo from erp.clin_paciente cp where cp.patient = m.p),
                           (select max(sexo) from erp.clin_consulta c where c.patient = m.p and c.dia = p_dia)),
          'nascimento', (select nascimento from erp.clin_paciente cp where cp.patient = m.p),
          'hora', (select min(f.hora) from fact f where f.p = m.p),
          'facturas', coalesce((select jsonb_agg(jsonb_build_object('factura', f.factura, 'hora', f.hora, 'medico', f.medico, 'minha', f.minha,
                                                                    'seguradora', f.seguradora, 'itens', f.itens) order by f.hora)
                                  from fact f where f.p = m.p), '[]'),
          'consulta', (select jsonb_build_object('medico', c.medico, 'hora', c.hora, 'idade', c.idade, 'sexo', c.sexo, 'sintomas', c.sintomas,
                                                 'diagnosticos', c.diagnosticos, 'analises', c.analises, 'receita', c.receita,
                                                 'procedimentos', c.procedimentos)
                         from erp.clin_consulta c where c.patient = m.p and c.dia = p_dia
                        order by (c.medico = any (codigos)) desc, c.hora limit 1),
          'triagem', (select jsonb_build_object('hora', t.hora, 'tensao', t.tensao, 'pulso', t.pulso, 'temperatura', t.temperatura,
                                                'peso', t.peso, 'altura', t.altura, 'imc', t.imc)
                        from erp.clin_triagem t where t.patient = m.p and t.dia = p_dia order by t.hora limit 1),
          'analises', coalesce((select jsonb_agg(jsonb_build_object('exame', l.exame, 'estado', l.estado, 'validado', l.docstatus = 1,
                                                                    'resultado_em', l.resultado_em, 'resultados', l.resultados) order by l.exame)
                                  from erp.clin_lab l where l.patient = m.p and l.dia between p_dia and p_dia + 2), '[]'),
          'registo', coalesce(r.linhas -> m.p, '{}'::jsonb)
        ) order by (select min(f.hora) from fact f where f.p = m.p) nulls last)
        from meus m), '[]'),
      'sincronizado_em', (select max(sincronizado_em) from erp.clin_triagem)
    ));
end $f$;
revoke all on function public.bsp_registo_clinico_dia(date, text) from public, anon;
grant execute on function public.bsp_registo_clinico_dia(date, text) to authenticated;

create or replace function public.bsp_registo_clinico_gravar(p_dia date, p_dados jsonb, p_submeter boolean default false, p_membro text default null)
returns jsonb language plpgsql security definer set search_path to 'public'
as $f$
declare
  eu text := public.bsp_meu_id();
  codigos text[] := public.bsp_rc_codigos(p_membro);
  r public.registo_clinico;
  n int; num text;
begin
  if codigos is null then raise exception 'Esta pessoa não está ligada a um médico do MetaGest.'; end if;
  if coalesce(nullif(btrim(p_membro), ''), eu) <> eu and not public.bsp_e_gestor() then
    raise exception 'Só o próprio médico preenche o seu registo.';
  end if;
  if p_dia > (now() at time zone 'Africa/Luanda')::date then raise exception 'Não se regista um dia que ainda não chegou.'; end if;
  insert into public.registo_clinico (codigo, dia, criado_por) values (codigos[1], p_dia, eu)
  on conflict (codigo, dia) do nothing;
  select * into r from public.registo_clinico where codigo = codigos[1] and dia = p_dia for update;
  if r.estado = 'Visto' then raise exception 'Este registo já tem o visto da Direcção Clínica e não se altera.'; end if;
  update public.registo_clinico set
    horario_de = nullif(p_dados->>'horario_de', '')::time,
    horario_ate = nullif(p_dados->>'horario_ate', '')::time,
    linhas = coalesce(p_dados->'linhas', linhas),
    observacoes = coalesce(p_dados->>'observacoes', ''), dificuldades = coalesce(p_dados->>'dificuldades', ''),
    sugestoes = coalesce(p_dados->>'sugestoes', ''),
    actualizado_por = eu, actualizado_em = now()
   where id = r.id;
  if p_submeter then
    num := r.numero;
    if num is null then
      select coalesce(max(substring(numero from '(\d+)$')::int), 0) + 1 into n
        from public.registo_clinico where numero like 'BRSP-DC-BNC-' || to_char(p_dia, 'YY') || '-%';
      num := 'BRSP-DC-BNC-' || to_char(p_dia, 'YY') || '-' || lpad(n::text, 3, '0');
    end if;
    update public.registo_clinico set estado = 'Submetido', numero = num, submetido_em = coalesce(submetido_em, now()) where id = r.id;
  end if;
  return (select to_jsonb(x) from public.registo_clinico x where x.id = r.id);
end $f$;
revoke all on function public.bsp_registo_clinico_gravar(date, jsonb, boolean, text) from public, anon;
grant execute on function public.bsp_registo_clinico_gravar(date, jsonb, boolean, text) to authenticated;

create or replace function public.bsp_registo_clinico_visto(p_id bigint, p_nota text default '')
returns void language plpgsql security definer set search_path to 'public'
as $f$
begin
  if not (public.bsp_e_gestor() or public.bsp_le_areas_medicas()) then raise exception 'Só a Direcção Clínica dá o visto.'; end if;
  update public.registo_clinico set estado = 'Visto', visto_por = public.bsp_meu_id(), visto_em = now(), nota_visto = coalesce(p_nota, '')
   where id = p_id and estado = 'Submetido';
  if not found then raise exception 'Só se dá o visto a um registo submetido.'; end if;
end $f$;
revoke all on function public.bsp_registo_clinico_visto(bigint, text) from public, anon;
grant execute on function public.bsp_registo_clinico_visto(bigint, text) to authenticated;

-- Lista para comparar: um médico vê os seus dias; a Direcção Clínica e a
-- gestão vêem todos (p_membro null) ou um médico. Por médico e dia: utentes
-- facturados, consultas registadas no MetaGest, utentes com diagnóstico no
-- registo, análises por validar, estado e número.
create or replace function public.bsp_registo_clinico_lista(p_de date, p_ate date, p_membro text default null)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'erp'
as $f$
declare
  eu text := public.bsp_meu_id();
  todos boolean := (public.bsp_e_gestor() or public.bsp_le_areas_medicas()) and nullif(btrim(p_membro), '') is null;
  codigos text[];
begin
  if p_ate < p_de or p_ate - p_de > 62 then raise exception 'Período inválido (até 62 dias).'; end if;
  if not todos then
    codigos := public.bsp_rc_codigos(p_membro);
    if codigos is null then return '[]'::jsonb; end if;
  end if;
  return coalesce((
    with base as (
      select s.ref_practitioner codigo, s.posting_date dia, max(s.practitioner_name) medico,
             count(distinct coalesce(s.patient, s.customer)) utentes
        from erp.sales_invoice s
       where s.posting_date between p_de and p_ate and s.docstatus = 1 and not s.is_return
         and coalesce(s.ref_practitioner, '') <> '' and (todos or s.ref_practitioner = any (codigos))
         and exists (select 1 from erp.sales_invoice_item i where i.parent = s.name and coalesce(i.item_group, '') ~* 'CONSULTA|ECOGRAFIA|CARDIOLOGIA')
       group by 1, 2
    )
    select jsonb_agg(jsonb_build_object(
      'codigo', b.codigo, 'dia', b.dia, 'medico', b.medico, 'utentes', b.utentes,
      'metagest', (select count(distinct c.patient) from erp.clin_consulta c where c.medico = b.codigo and c.dia = b.dia),
      'registados', (select count(*) from jsonb_each(coalesce(r.linhas, '{}')) e where coalesce(e.value->>'diagnostico', '') <> ''),
      'id', r.id, 'estado', coalesce(r.estado, 'Por preencher'), 'numero', r.numero, 'visto_em', r.visto_em
    ) order by b.dia desc, b.medico)
    from base b left join public.registo_clinico r on r.codigo = b.codigo and r.dia = b.dia), '[]'::jsonb);
end $f$;
revoke all on function public.bsp_registo_clinico_lista(date, date, text) from public, anon;
grant execute on function public.bsp_registo_clinico_lista(date, date, text) to authenticated;

-- ---------------------------------------------------------------- agendamentos
-- Carga de Setembro de 2026 (passos de 2 dias, cron bsp-clinico-carga, a
-- desligar quando erp.clin_carga estiver toda feita) e cópia contínua.
create table if not exists erp.clin_carga (dia date primary key, feito_em timestamptz);
revoke all on erp.clin_carga from public, anon, authenticated;
create or replace function erp.clinico_carga_passo() returns text language plpgsql security definer set search_path to 'erp', 'public' as $c$
declare d date; r jsonb;
begin
  select dia into d from erp.clin_carga where feito_em is null order by dia limit 1 for update skip locked;
  if d is null then return 'feito'; end if;
  r := erp.sincronizar_clinico(d, d + 1);
  update erp.clin_carga set feito_em = now() where dia = d;
  return d::text || ' ' || r::text;
end $c$;
-- select cron.schedule('bsp-clinico-hoje', '*/30 6-21 * * *', $$set statement_timeout to '6min'; select erp.sincronizar_clinico((now() at time zone 'Africa/Luanda')::date, (now() at time zone 'Africa/Luanda')::date);$$);
-- select cron.schedule('bsp-clinico', '55 2 * * *', $$set statement_timeout to '15min'; select erp.sincronizar_clinico((now() at time zone 'Africa/Luanda')::date - 7, (now() at time zone 'Africa/Luanda')::date);$$);

notify pgrst, 'reload schema';
