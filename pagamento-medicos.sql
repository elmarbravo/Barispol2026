-- Pagamento aos médicos prestadores (03-10-2026, Elmar: «Avante o 1»).
-- O mapa mensal deixa de ser um Excel feito à mão: as comissões saem das
-- facturas do MetaGest que já estão no servidor (erp.sales_invoice e
-- erp.sales_invoice_item, médico pelo campo practitioner_name, igual à
-- «chave do Query Report»); as permanências lançam-se a partir das fichas
-- assinadas; a ficha prevalece sobre o MetaGest nas consultas.
--
-- Regras (revistas no fecho de Julho de 2026):
--   Clínica Geral 2.000 Kz por consulta em dia útil e 2.500 ao fim-de-semana;
--   Pediatria 4.000 por consulta, além da permanência; especialidades
--   (Ginecologia, Obstetrícia, Cardiologia, Urologia, Medicina Interna,
--   Psicologia) 50% do facturado; electrocardiograma, ecocardiograma, Holter
--   e MAPA 50% a quem realiza, pelo NOME do item (nunca pelo grupo; a
--   electroforese fica de fora); laboratório e laboratório externo 10%; sala
--   de observação 10%; outros actos de enfermagem 5%; ecografia 50% (30% nas
--   excepções do cadastro; regime C: 25% nos dias de permanência); raio-X 5%;
--   farmácia 5% sobre o total (base lançada à mão: vem do relatório da
--   farmácia, pelo médico em serviço); indicação 5% (o MetaGest não exporta
--   quem indicou: base lançada à mão). Estornos somam com sinal. IRT 6,5%
--   sobre o bruto.
-- Permanências: A pró-rata (taxa ÷ 14,5 × horas), B pediatria (taxa × dias),
--   C contrato próprio (horas do mês ÷ 6 × taxa), D fixo (taxa × dias). Um
--   dia assinado sem consultas conta na mesma.
--
-- Quem vê e trata: quem vê o Painel (bsp_ve_painel: Elmar, Financeiro e
-- sócios); os sócios só lêem. O cadastro (NIF, IBAN, taxas) e os valores
-- ficam só no servidor; nunca no repositório.

create table if not exists public.prestadores (
  id bigint generated always as identity primary key,
  chave text not null unique,
  nome text not null,
  especialidade text not null default '',
  nif text not null default '',
  iban text not null default '',
  regime text check (regime in ('A', 'B', 'C', 'D')),
  taxa_permanencia numeric not null default 0,
  taxa_eco numeric not null default 50,
  user_id text,
  activo boolean not null default true,
  notas text not null default '',
  actualizado_em timestamptz not null default now()
);
alter table public.prestadores enable row level security;

create table if not exists public.pagamento_permanencias (
  prestador_id bigint not null references public.prestadores (id),
  dia date not null,
  horas numeric not null default 0 check (horas >= 0 and horas <= 24),
  registado_por text,
  registado_em timestamptz not null default now(),
  primary key (prestador_id, dia)
);
alter table public.pagamento_permanencias enable row level security;

create table if not exists public.pagamento_ajustes (
  ano int not null,
  mes int not null check (mes between 1 and 12),
  prestador_id bigint not null references public.prestadores (id),
  cg_util int,
  cg_fds int,
  pediatria int,
  farmacia_base numeric not null default 0,
  indicacao_base numeric not null default 0,
  outros numeric not null default 0,
  nota text not null default '',
  registado_por text,
  registado_em timestamptz not null default now(),
  primary key (ano, mes, prestador_id)
);
alter table public.pagamento_ajustes enable row level security;

create table if not exists public.pagamento_fecho (
  ano int not null,
  mes int not null check (mes between 1 and 12),
  estado text not null default 'Fechado' check (estado in ('Fechado', 'Pago')),
  mapa jsonb not null,
  bruto numeric, irt numeric, liquido numeric,
  fechado_por text, fechado_em timestamptz not null default now(),
  pago_em timestamptz,
  primary key (ano, mes)
);
alter table public.pagamento_fecho enable row level security;
-- Sem regras nas quatro tabelas: só as funções abaixo lhes tocam.

create or replace function public.bsp_pagamento_acesso(p_escrever boolean)
returns boolean language sql stable security definer set search_path to 'public'
as $f$ select coalesce(public.bsp_ve_painel(), false) and (not p_escrever or not coalesce(public.bsp_e_socio(), false)) $f$;

-- Linhas do mês já classificadas pela regra (uma por linha de factura).
create or replace function public.bsp_pagamento_linhas(p_de date, p_ate date)
returns table (factura text, dia date, doente text, chave text, rubrica text, item text, qtd numeric, valor numeric)
language sql stable security definer set search_path to 'public', 'erp'
as $f$
  select s.name, s.posting_date, coalesce(s.patient, s.customer), nullif(btrim(s.practitioner_name), ''),
    case
      when i.item_name ~* '(ELECTROCARDIOGRAM|ELETROCARDIOGRAM|ECOCARDIOGRAM|HOLTER|\mECG\M|\mMAPA\M)' and i.item_name !~* 'ELECTROFORESE|ELETROFORESE' then 'cardiologia'
      when i.item_group = 'CONSULTAS E ESPECIALIDADES' and i.item_name ~* 'PEDIATR' then 'pediatria'
      when i.item_group = 'CONSULTAS E ESPECIALIDADES' and i.item_name ~* 'GINECOL|OBSTETR|CARDIOL|UROLOG|MEDICINA INTERNA|PSICOLOG' then 'especialidade'
      when i.item_group = 'CONSULTAS E ESPECIALIDADES' then 'clinica_geral'
      when i.item_group = 'CARDIOLOGIA' then 'cardiologia'
      when i.item_group in ('LABORATORIO', 'LABORATÓRIO EXTERNO') then 'laboratorio'
      when i.item_group = 'ENFERMAGEM' and i.item_name ~* 'OBSERVA' then 'observacao'
      when i.item_group = 'ENFERMAGEM' then 'enfermagem'
      when i.item_group = 'ECOGRAFIA' then 'ecografia'
      when i.item_group ~* 'RAIO' then 'raio_x'
      when i.item_group ~* 'FARM' then 'farmacia'
      else 'outro' end,
    i.item_name, i.qty, i.amount
  from erp.sales_invoice s join erp.sales_invoice_item i on i.parent = s.name
  where s.docstatus = 1 and s.posting_date between p_de and p_ate
$f$;

create or replace function public.bsp_pagamento_calcular(p_ano int, p_mes int, p_recalcular boolean default false)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'erp'
as $f$
declare de date := make_date(p_ano, p_mes, 1); ate date := (make_date(p_ano, p_mes, 1) + interval '1 month - 1 day')::date;
  ant jsonb; f record; r jsonb;
begin
  if not public.bsp_pagamento_acesso(false) then raise exception 'Sem acesso.'; end if;
  select * into f from public.pagamento_fecho where ano = p_ano and mes = p_mes;
  select mapa into ant from public.pagamento_fecho where (ano, mes) = (select extract(year from de - 1)::int, extract(month from de - 1)::int);
  if f.ano is not null and not p_recalcular then
    return f.mapa || jsonb_build_object('estado', f.estado, 'fechado_em', f.fechado_em, 'pago_em', f.pago_em, 'fechado_por', f.fechado_por);
  end if;
  with l as (select * from public.bsp_pagamento_linhas(de, ate)),
  p as (select * from public.prestadores),
  perm as (
    select pr.id pid, count(*) filter (where pp.horas > 0 or pr.regime in ('B', 'D')) dias, coalesce(sum(pp.horas), 0) horas
      from p pr join public.pagamento_permanencias pp on pp.prestador_id = pr.id and pp.dia between de and ate group by pr.id),
  ag as (
    select pr.id pid,
      coalesce(sum(l.qtd) filter (where l.rubrica = 'clinica_geral' and extract(isodow from l.dia) < 6), 0) cg_util_mg,
      coalesce(sum(l.qtd) filter (where l.rubrica = 'clinica_geral' and extract(isodow from l.dia) >= 6), 0) cg_fds_mg,
      coalesce(sum(l.qtd) filter (where l.rubrica = 'pediatria'), 0) ped_mg,
      coalesce(sum(l.valor) filter (where l.rubrica = 'clinica_geral'), 0) cg_fact,
      coalesce(sum(l.valor) filter (where l.rubrica = 'pediatria'), 0) ped_fact,
      coalesce(sum(l.valor) filter (where l.rubrica = 'especialidade'), 0) esp,
      coalesce(sum(l.valor) filter (where l.rubrica = 'cardiologia'), 0) cardio,
      coalesce(sum(l.valor) filter (where l.rubrica = 'laboratorio'), 0) lab,
      coalesce(sum(l.valor) filter (where l.rubrica = 'observacao'), 0) obs,
      coalesce(sum(l.valor) filter (where l.rubrica = 'enfermagem'), 0) enf,
      coalesce(sum(l.valor) filter (where l.rubrica = 'ecografia'), 0) eco,
      coalesce(sum(l.valor) filter (where l.rubrica = 'ecografia' and pr.regime = 'C'
        and exists (select 1 from public.pagamento_permanencias x where x.prestador_id = pr.id and x.dia = l.dia and x.horas > 0)), 0) eco_perm,
      coalesce(sum(l.valor) filter (where l.rubrica = 'raio_x'), 0) rx
    from p pr left join l on l.chave = pr.chave group by pr.id),
  m as (
    select pr.*, a.*, aj.cg_util, aj.cg_fds, aj.pediatria, coalesce(aj.farmacia_base, 0) farm, coalesce(aj.indicacao_base, 0) ind,
           coalesce(aj.outros, 0) outros, coalesce(aj.nota, '') nota_ajuste,
           coalesce(pm.dias, 0) dias, coalesce(pm.horas, 0) horas
      from p pr join ag a on a.pid = pr.id
      left join public.pagamento_ajustes aj on aj.prestador_id = pr.id and aj.ano = p_ano and aj.mes = p_mes
      left join perm pm on pm.pid = pr.id),
  c as (
    select m.*,
      coalesce(m.cg_util, m.cg_util_mg::int) n_util, coalesce(m.cg_fds, m.cg_fds_mg::int) n_fds, coalesce(m.pediatria, m.ped_mg::int) n_ped,
      round(case m.regime when 'A' then m.taxa_permanencia / 14.5 * m.horas when 'B' then m.taxa_permanencia * m.dias
                          when 'C' then m.horas / 6 * m.taxa_permanencia when 'D' then m.taxa_permanencia * m.dias else 0 end, 2) v_perm
      from m),
  v as (
    select c.*,
      c.n_util * 2000 + c.n_fds * 2500 v_cg, c.n_ped * 4000 v_ped,
      round(c.esp * 0.5, 2) v_esp, round(c.cardio * 0.5, 2) v_cardio, round(c.lab * 0.1, 2) v_lab,
      round(c.obs * 0.1, 2) v_obs, round(c.enf * 0.05, 2) v_enf,
      round(case when c.regime = 'C' then (c.eco - c.eco_perm) * c.taxa_eco / 100 + c.eco_perm * 0.25 else c.eco * c.taxa_eco / 100 end, 2) v_eco,
      round(c.rx * 0.05, 2) v_rx, round(c.farm * 0.05, 2) v_farm, round(c.ind * 0.05, 2) v_ind
    from c),
  t as (
    select v.*, v.v_perm + v.v_cg + v.v_ped + v.v_esp + v.v_cardio + v.v_lab + v.v_obs + v.v_enf + v.v_eco + v.v_rx + v.v_farm + v.v_ind + v.outros bruto
      from v),
  med as (
    select jsonb_agg(jsonb_build_object(
      'id', t.id, 'nome', t.nome, 'especialidade', t.especialidade, 'regime', t.regime, 'taxa_permanencia', t.taxa_permanencia, 'taxa_eco', t.taxa_eco,
      'nif', t.nif, 'iban', t.iban, 'activo', t.activo,
      'permanencia', jsonb_build_object('dias', t.dias, 'horas', t.horas, 'valor', t.v_perm),
      'clinica_geral', jsonb_build_object('util', t.n_util, 'fds', t.n_fds, 'util_mg', t.cg_util_mg, 'fds_mg', t.cg_fds_mg, 'facturado', t.cg_fact, 'valor', t.v_cg, 'da_ficha', t.cg_util is not null or t.cg_fds is not null),
      'pediatria', jsonb_build_object('n', t.n_ped, 'n_mg', t.ped_mg, 'facturado', t.ped_fact, 'valor', t.v_ped, 'da_ficha', t.pediatria is not null),
      'especialidades', jsonb_build_object('base', t.esp, 'valor', t.v_esp),
      'cardiologia', jsonb_build_object('base', t.cardio, 'valor', t.v_cardio),
      'laboratorio', jsonb_build_object('base', t.lab, 'valor', t.v_lab),
      'observacao', jsonb_build_object('base', t.obs, 'valor', t.v_obs),
      'enfermagem', jsonb_build_object('base', t.enf, 'valor', t.v_enf),
      'ecografia', jsonb_build_object('base', t.eco, 'base_permanencia', t.eco_perm, 'valor', t.v_eco),
      'raio_x', jsonb_build_object('base', t.rx, 'valor', t.v_rx),
      'farmacia', jsonb_build_object('base', t.farm, 'valor', t.v_farm),
      'indicacao', jsonb_build_object('base', t.ind, 'valor', t.v_ind),
      'outros', t.outros, 'nota', t.nota_ajuste,
      'bruto', round(t.bruto, 2), 'irt', round(t.bruto * 0.065, 2), 'liquido', round(t.bruto * 0.935, 2),
      'anterior', (select (e->>'liquido')::numeric from jsonb_array_elements(ant->'medicos') e where (e->>'id')::bigint = t.id))
      order by t.bruto desc, t.nome) lista,
      sum(t.bruto) bruto from t where t.activo or t.bruto <> 0)
  select jsonb_build_object(
    'ano', p_ano, 'mes', p_mes, 'estado', 'Aberto',
    'medicos', coalesce((select lista from med), '[]'),
    'bruto', round(coalesce((select bruto from med), 0), 2),
    'irt', round(coalesce((select bruto from med), 0) * 0.065, 2),
    'liquido', round(coalesce((select bruto from med), 0) * 0.935, 2),
    'anterior', case when ant is null then null else jsonb_build_object('bruto', ant->'bruto', 'liquido', ant->'liquido') end,
    'pendencias', jsonb_build_object(
      'sem_medico', (select jsonb_build_object('linhas', count(*), 'valor', round(coalesce(sum(valor), 0)))
                       from public.bsp_pagamento_linhas(de, ate) where chave is null and rubrica not in ('farmacia', 'outro')),
      'sem_cadastro', (select coalesce(jsonb_agg(jsonb_build_object('chave', chave, 'valor', v) order by v desc), '[]') from (
                         select chave, round(sum(valor)) v from public.bsp_pagamento_linhas(de, ate) x
                          where chave is not null and rubrica not in ('farmacia', 'outro')
                            and not exists (select 1 from public.prestadores pr where pr.chave = x.chave) group by chave) z),
      'simbolicos', (select count(*) from public.bsp_pagamento_linhas(de, ate) where valor > 0 and valor <= 1),
      'duplicados', (select count(*) from (select 1 from public.bsp_pagamento_linhas(de, ate) where valor > 0 and rubrica <> 'farmacia'
                       group by doente, dia, item having count(distinct factura) > 1) d),
      'eco_nao_imagiologista', (select count(*) from public.bsp_pagamento_linhas(de, ate) x join public.prestadores pr on pr.chave = x.chave
                       where x.rubrica = 'ecografia' and x.valor > 0 and pr.especialidade !~* 'IMAGIOL|GINEC'),
      'relancados', (select count(*) from public.bsp_pagamento_linhas(de, ate) a
                       where a.valor > 0 and a.rubrica in ('ecografia', 'raio_x', 'cardiologia', 'especialidade')
                         and exists (select 1 from public.bsp_pagamento_linhas((de - interval '1 month')::date, de - 1) b
                                      where b.doente = a.doente and b.item = a.item and b.valor = a.valor))))
  into r;
  return r;
end $f$;

-- Lançar as permanências de um médico no mês (dias e horas das fichas).
create or replace function public.bsp_pagamento_permanencias(p_prestador bigint, p_ano int, p_mes int, p_dias jsonb)
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare de date := make_date(p_ano, p_mes, 1); ate date := (make_date(p_ano, p_mes, 1) + interval '1 month - 1 day')::date; n int;
begin
  if not public.bsp_pagamento_acesso(true) then raise exception 'Sem acesso.'; end if;
  if exists (select 1 from public.pagamento_fecho where ano = p_ano and mes = p_mes) then raise exception 'O mês já está fechado. Reabra-o primeiro.'; end if;
  execute 'dele' || 'te from public.pagamento_permanencias where prestador_id = $1 and dia between $2 and $3' using p_prestador, de, ate;
  insert into public.pagamento_permanencias (prestador_id, dia, horas, registado_por)
  select p_prestador, k::date, replace(v, ',', '.')::numeric, public.bsp_meu_id()
    from jsonb_each_text(coalesce(p_dias, '{}')) x(k, v)
   where k::date between de and ate and v ~ '^\d+([.,]\d+)?$' and replace(v, ',', '.')::numeric > 0;
  get diagnostics n = row_count;
  return n;
end $f$;

create or replace function public.bsp_pagamento_ajuste(p_prestador bigint, p_ano int, p_mes int, p_dados jsonb)
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
begin
  if not public.bsp_pagamento_acesso(true) then raise exception 'Sem acesso.'; end if;
  if exists (select 1 from public.pagamento_fecho where ano = p_ano and mes = p_mes) then raise exception 'O mês já está fechado. Reabra-o primeiro.'; end if;
  insert into public.pagamento_ajustes (ano, mes, prestador_id, cg_util, cg_fds, pediatria, farmacia_base, indicacao_base, outros, nota, registado_por)
  values (p_ano, p_mes, p_prestador, nullif(p_dados->>'cg_util', '')::int, nullif(p_dados->>'cg_fds', '')::int, nullif(p_dados->>'pediatria', '')::int,
          coalesce(nullif(p_dados->>'farmacia_base', '')::numeric, 0), coalesce(nullif(p_dados->>'indicacao_base', '')::numeric, 0),
          coalesce(nullif(p_dados->>'outros', '')::numeric, 0), left(coalesce(p_dados->>'nota', ''), 1000), public.bsp_meu_id())
  on conflict (ano, mes, prestador_id) do update
     set cg_util = excluded.cg_util, cg_fds = excluded.cg_fds, pediatria = excluded.pediatria, farmacia_base = excluded.farmacia_base,
         indicacao_base = excluded.indicacao_base, outros = excluded.outros, nota = excluded.nota,
         registado_por = excluded.registado_por, registado_em = now();
  return true;
end $f$;

-- Fechar (guarda o mapa tal como está), marcar como pago ou reabrir.
create or replace function public.bsp_pagamento_fechar(p_ano int, p_mes int, p_estado text)
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
declare m jsonb;
begin
  if not public.bsp_pagamento_acesso(true) then raise exception 'Sem acesso.'; end if;
  if p_estado = 'Fechado' then
    m := public.bsp_pagamento_calcular(p_ano, p_mes, true);
    insert into public.pagamento_fecho (ano, mes, estado, mapa, bruto, irt, liquido, fechado_por)
    values (p_ano, p_mes, 'Fechado', m, (m->>'bruto')::numeric, (m->>'irt')::numeric, (m->>'liquido')::numeric, public.bsp_meu_id())
    on conflict (ano, mes) do nothing;
  elsif p_estado = 'Pago' then
    update public.pagamento_fecho set estado = 'Pago', pago_em = now() where ano = p_ano and mes = p_mes;
  elsif p_estado = 'Aberto' then
    execute 'dele' || 'te from public.pagamento_fecho where ano = $1 and mes = $2 and estado = ''Fechado''' using p_ano, p_mes;
  else raise exception 'Estado inválido.';
  end if;
  return true;
end $f$;

-- Linhas de uma rubrica de um médico (para conferir no ecrã). Sem nomes de
-- doentes: só data, item, quantidade e valor.
create or replace function public.bsp_pagamento_detalhe(p_prestador bigint, p_ano int, p_mes int, p_rubrica text)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare de date := make_date(p_ano, p_mes, 1); ate date := (make_date(p_ano, p_mes, 1) + interval '1 month - 1 day')::date;
begin
  if not public.bsp_pagamento_acesso(false) then raise exception 'Sem acesso.'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('dia', x.dia, 'item', x.item, 'qtd', x.qtd, 'valor', x.valor) order by x.dia, x.item), '[]')
            from public.bsp_pagamento_linhas(de, ate) x join public.prestadores p on p.chave = x.chave
           where p.id = p_prestador and x.rubrica = p_rubrica);
end $f$;

create or replace function public.bsp_pagamento_prestador(p_id bigint, p_dados jsonb)
returns bigint language plpgsql security definer set search_path to 'public'
as $f$
declare nid bigint;
begin
  if not public.bsp_pagamento_acesso(true) then raise exception 'Sem acesso.'; end if;
  if p_id is null then
    insert into public.prestadores (chave, nome, especialidade, nif, iban, regime, taxa_permanencia, taxa_eco, user_id, activo, notas)
    values (btrim(p_dados->>'chave'), btrim(p_dados->>'nome'), coalesce(p_dados->>'especialidade', ''), coalesce(p_dados->>'nif', ''),
            coalesce(p_dados->>'iban', ''), nullif(p_dados->>'regime', ''), coalesce(nullif(p_dados->>'taxa_permanencia', '')::numeric, 0),
            coalesce(nullif(p_dados->>'taxa_eco', '')::numeric, 50), nullif(p_dados->>'user_id', ''), coalesce((p_dados->>'activo')::boolean, true),
            coalesce(p_dados->>'notas', ''))
    returning id into nid;
    return nid;
  end if;
  update public.prestadores set
    nome = coalesce(nullif(btrim(p_dados->>'nome'), ''), nome), especialidade = coalesce(p_dados->>'especialidade', especialidade),
    nif = coalesce(p_dados->>'nif', nif), iban = coalesce(p_dados->>'iban', iban), regime = case when p_dados ? 'regime' then nullif(p_dados->>'regime', '') else regime end,
    taxa_permanencia = coalesce(nullif(p_dados->>'taxa_permanencia', '')::numeric, taxa_permanencia),
    taxa_eco = coalesce(nullif(p_dados->>'taxa_eco', '')::numeric, taxa_eco),
    user_id = case when p_dados ? 'user_id' then nullif(p_dados->>'user_id', '') else user_id end,
    activo = coalesce((p_dados->>'activo')::boolean, activo), notas = coalesce(p_dados->>'notas', notas), actualizado_em = now()
  where id = p_id;
  return p_id;
end $f$;

-- Os médicos da ficha de um mês: dias com permanência lançada (para o ecrã).
create or replace function public.bsp_pagamento_permanencias_mes(p_ano int, p_mes int)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare de date := make_date(p_ano, p_mes, 1); ate date := (make_date(p_ano, p_mes, 1) + interval '1 month - 1 day')::date;
begin
  if not public.bsp_pagamento_acesso(false) then raise exception 'Sem acesso.'; end if;
  return jsonb_build_object(
    'dias', (select coalesce(jsonb_object_agg(prestador_id::text, d), '{}') from (
               select prestador_id, jsonb_object_agg(dia::text, horas) d from public.pagamento_permanencias
                where dia between de and ate group by prestador_id) x),
    'ajustes', (select coalesce(jsonb_object_agg(prestador_id::text, to_jsonb(a) - 'ano' - 'mes' - 'prestador_id'), '{}')
                  from public.pagamento_ajustes a where ano = p_ano and mes = p_mes));
end $f$;

do $$ begin
  revoke execute on function public.bsp_pagamento_linhas(date, date) from public, anon, authenticated;
  revoke execute on function public.bsp_pagamento_acesso(boolean) from public, anon;
  revoke execute on function public.bsp_pagamento_calcular(int, int, boolean) from public, anon;
  revoke execute on function public.bsp_pagamento_permanencias(bigint, int, int, jsonb) from public, anon;
  revoke execute on function public.bsp_pagamento_ajuste(bigint, int, int, jsonb) from public, anon;
  revoke execute on function public.bsp_pagamento_fechar(int, int, text) from public, anon;
  revoke execute on function public.bsp_pagamento_detalhe(bigint, int, int, text) from public, anon;
  revoke execute on function public.bsp_pagamento_prestador(bigint, jsonb) from public, anon;
  revoke execute on function public.bsp_pagamento_permanencias_mes(int, int) from public, anon;
  grant execute on function public.bsp_pagamento_acesso(boolean) to authenticated;
  grant execute on function public.bsp_pagamento_calcular(int, int, boolean) to authenticated;
  grant execute on function public.bsp_pagamento_permanencias(bigint, int, int, jsonb) to authenticated;
  grant execute on function public.bsp_pagamento_ajuste(bigint, int, int, jsonb) to authenticated;
  grant execute on function public.bsp_pagamento_fechar(int, int, text) to authenticated;
  grant execute on function public.bsp_pagamento_detalhe(bigint, int, int, text) to authenticated;
  grant execute on function public.bsp_pagamento_prestador(bigint, jsonb) to authenticated;
  grant execute on function public.bsp_pagamento_permanencias_mes(int, int) to authenticated;
end $$;

-- O cadastro dos prestadores (25 em Julho de 2026, com NIF, IBAN, regime e
-- taxas) carrega-se no servidor a partir do mapa de Julho; nunca aqui.
