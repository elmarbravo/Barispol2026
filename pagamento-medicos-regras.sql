-- Pagamento dos médicos pelo mapa de Agosto de 2026 (04-10-2026, Elmar:
-- «Use o pagamento de Agosto para te guiares… Irão faltar todos os meses os
-- mapas de presença… [A imagiologista] tem adenda contratual: 40% terça e domingo,
-- 50% nos restantes dias. Os outros médicos estão off»).
--
-- Ecografia por dia da semana: prestadores.taxa_eco_dias ({"isodow": %},
-- 1 = segunda … 7 = domingo) sobrepõe-se à taxa_eco nesses dias. Substitui a
-- regra antiga do regime C (25% nos dias de permanência). A permanência do
-- regime C continua: horas do mês ÷ 6 × taxa.
-- chaves_extra: outros nomes do mesmo médico no MetaGest; contam como a chave.
-- Nutrição conta como especialidade (50% do facturado), como no mapa de Agosto.
-- Sem presenças: as fichas de presença ainda são em papel e podem faltar. O
-- mapa calcula-se na mesma (permanência a zero) e o médico com actividade no
-- mês sem nenhum dia lançado aparece em pendencias.sem_presencas e com
-- sem_presenca = true, até se lançarem as fichas.
-- Os dados de cada prestador (adenda, taxas, NIF, IBAN, quem está activo)
-- ficam só no servidor; nunca no repositório.

alter table public.prestadores add column if not exists taxa_eco_dias jsonb not null default '{}';
-- Outros nomes do mesmo médico no MetaGest (o nome muda: em Setembro de 2026
-- uma médica passou a aparecer com o nome curto).
alter table public.prestadores add column if not exists chaves_extra text[] not null default '{}';

create or replace function public.bsp_pagamento_linhas(p_de date, p_ate date)
returns table (factura text, dia date, doente text, chave text, rubrica text, item text, qtd numeric, valor numeric)
language sql stable security definer set search_path to 'public', 'erp'
as $f$
  select s.name, s.posting_date, coalesce(s.patient, s.customer), nullif(btrim(s.practitioner_name), ''),
    case
      when i.item_name ~* '(ELECTROCARDIOGRAM|ELETROCARDIOGRAM|ECOCARDIOGRAM|HOLTER|\mECG\M|\mMAPA\M)' and i.item_name !~* 'ELECTROFORESE|ELETROFORESE' then 'cardiologia'
      when i.item_group = 'CONSULTAS E ESPECIALIDADES' and i.item_name ~* 'PEDIATR' then 'pediatria'
      when i.item_group = 'CONSULTAS E ESPECIALIDADES' and i.item_name ~* 'GINECOL|OBSTETR|CARDIOL|UROLOG|MEDICINA INTERNA|PSICOLOG|NUTRI' then 'especialidade'
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
      -- Ecografia: taxa do dia da semana (adenda) ou a taxa do prestador.
      coalesce(sum(l.valor * coalesce((pr.taxa_eco_dias->>extract(isodow from l.dia)::int::text)::numeric, pr.taxa_eco) / 100)
        filter (where l.rubrica = 'ecografia'), 0) eco_valor,
      coalesce(sum(l.valor) filter (where l.rubrica = 'ecografia' and pr.taxa_eco_dias ? extract(isodow from l.dia)::int::text), 0) eco_dias_base,
      count(l.chave) filter (where l.valor > 0) n_actos,
      coalesce(sum(l.valor) filter (where l.rubrica = 'raio_x'), 0) rx
    from p pr left join l on l.chave = pr.chave or l.chave = any(pr.chaves_extra) group by pr.id),
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
      round(c.eco_valor, 2) v_eco,
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
      'ecografia', jsonb_build_object('base', t.eco, 'base_dias', t.eco_dias_base, 'taxa_dias', t.taxa_eco_dias, 'valor', t.v_eco),
      'raio_x', jsonb_build_object('base', t.rx, 'valor', t.v_rx),
      'farmacia', jsonb_build_object('base', t.farm, 'valor', t.v_farm),
      'indicacao', jsonb_build_object('base', t.ind, 'valor', t.v_ind),
      'outros', t.outros, 'nota', t.nota_ajuste,
      'sem_presenca', t.regime is not null and t.dias = 0 and (t.n_actos > 0 or t.cg_util is not null or t.cg_fds is not null or t.pediatria is not null),
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
      'sem_presencas', (select coalesce(jsonb_agg(e->>'nome' order by e->>'nome'), '[]') from jsonb_array_elements(coalesce((select lista from med), '[]')) e
                         where (e->>'sem_presenca')::boolean),
      'sem_medico', (select jsonb_build_object('linhas', count(*), 'valor', round(coalesce(sum(valor), 0)))
                       from public.bsp_pagamento_linhas(de, ate) where chave is null and rubrica not in ('farmacia', 'outro')),
      'sem_cadastro', (select coalesce(jsonb_agg(jsonb_build_object('chave', chave, 'valor', v) order by v desc), '[]') from (
                         select chave, round(sum(valor)) v from public.bsp_pagamento_linhas(de, ate) x
                          where chave is not null and rubrica not in ('farmacia', 'outro')
                            and not exists (select 1 from public.prestadores pr where pr.chave = x.chave or x.chave = any(pr.chaves_extra)) group by chave) z),
      'simbolicos', (select count(*) from public.bsp_pagamento_linhas(de, ate) where valor > 0 and valor <= 1),
      'duplicados', (select count(*) from (select 1 from public.bsp_pagamento_linhas(de, ate) where valor > 0 and rubrica <> 'farmacia'
                       group by doente, dia, item having count(distinct factura) > 1) d),
      'eco_nao_imagiologista', (select count(*) from public.bsp_pagamento_linhas(de, ate) x join public.prestadores pr on pr.chave = x.chave or x.chave = any(pr.chaves_extra)
                       where x.rubrica = 'ecografia' and x.valor > 0 and pr.especialidade !~* 'IMAGIOL|GINEC'),
      'relancados', (select count(*) from public.bsp_pagamento_linhas(de, ate) a
                       where a.valor > 0 and a.rubrica in ('ecografia', 'raio_x', 'cardiologia', 'especialidade')
                         and exists (select 1 from public.bsp_pagamento_linhas((de - interval '1 month')::date, de - 1) b
                                      where b.doente = a.doente and b.item = a.item and b.valor = a.valor))))
  into r;
  return r;
end $f$;

create or replace function public.bsp_pagamento_prestador(p_id bigint, p_dados jsonb)
returns bigint language plpgsql security definer set search_path to 'public'
as $f$
declare nid bigint;
begin
  if not public.bsp_pagamento_acesso(true) then raise exception 'Sem acesso.'; end if;
  if p_id is null then
    insert into public.prestadores (chave, nome, especialidade, nif, iban, regime, taxa_permanencia, taxa_eco, taxa_eco_dias, user_id, activo, notas)
    values (btrim(p_dados->>'chave'), btrim(p_dados->>'nome'), coalesce(p_dados->>'especialidade', ''), coalesce(p_dados->>'nif', ''),
            coalesce(p_dados->>'iban', ''), nullif(p_dados->>'regime', ''), coalesce(nullif(p_dados->>'taxa_permanencia', '')::numeric, 0),
            coalesce(nullif(p_dados->>'taxa_eco', '')::numeric, 50), coalesce(p_dados->'taxa_eco_dias', '{}'), nullif(p_dados->>'user_id', ''), coalesce((p_dados->>'activo')::boolean, true),
            coalesce(p_dados->>'notas', ''))
    returning id into nid;
    return nid;
  end if;
  update public.prestadores set
    nome = coalesce(nullif(btrim(p_dados->>'nome'), ''), nome), especialidade = coalesce(p_dados->>'especialidade', especialidade),
    nif = coalesce(p_dados->>'nif', nif), iban = coalesce(p_dados->>'iban', iban), regime = case when p_dados ? 'regime' then nullif(p_dados->>'regime', '') else regime end,
    taxa_permanencia = coalesce(nullif(p_dados->>'taxa_permanencia', '')::numeric, taxa_permanencia),
    taxa_eco = coalesce(nullif(p_dados->>'taxa_eco', '')::numeric, taxa_eco),
    taxa_eco_dias = case when p_dados ? 'taxa_eco_dias' then coalesce(p_dados->'taxa_eco_dias', '{}') else taxa_eco_dias end,
    user_id = case when p_dados ? 'user_id' then nullif(p_dados->>'user_id', '') else user_id end,
    activo = coalesce((p_dados->>'activo')::boolean, activo), notas = coalesce(p_dados->>'notas', notas), actualizado_em = now()
  where id = p_id;
  return p_id;
end $f$;

create or replace function public.bsp_pagamento_detalhe(p_prestador bigint, p_ano int, p_mes int, p_rubrica text)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare de date := make_date(p_ano, p_mes, 1); ate date := (make_date(p_ano, p_mes, 1) + interval '1 month - 1 day')::date;
begin
  if not public.bsp_pagamento_acesso(false) then raise exception 'Sem acesso.'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('dia', x.dia, 'item', x.item, 'qtd', x.qtd, 'valor', x.valor) order by x.dia, x.item), '[]')
            from public.bsp_pagamento_linhas(de, ate) x join public.prestadores p on p.chave = x.chave or x.chave = any(p.chaves_extra)
           where p.id = p_prestador and x.rubrica = p_rubrica);
end $f$;

do $$ begin
  revoke execute on function public.bsp_pagamento_linhas(date, date) from public, anon, authenticated;
  revoke execute on function public.bsp_pagamento_calcular(int, int, boolean) from public, anon;
  grant execute on function public.bsp_pagamento_calcular(int, int, boolean) to authenticated;
  revoke execute on function public.bsp_pagamento_prestador(bigint, jsonb) from public, anon;
  grant execute on function public.bsp_pagamento_prestador(bigint, jsonb) to authenticated;
end $$;
