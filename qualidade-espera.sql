-- Tempo de espera na Qualidade (03-10-2026, Elmar: «Consegues colocar na
-- qualidade o tempo de espera também?»).
--
-- Medido pelo MetaGest, sem depender do que se escreve à mão:
--   chegada  = hora da triagem (Vital Signs, signs_time), a primeira do dia;
--   consulta = hora da consulta (Patient Encounter, encounter_time), só quando
--              o médico abre o registo no MetaGest (cerca de 1 em cada 3);
--   saída    = hora da última factura do dia (a factura faz-se no fim).
-- Espera pelo médico = consulta − triagem (0 a 6 h).
-- Tempo na clínica   = saída − triagem (1 min a 8 h).
-- Fora destes limites, o registo não conta (horas trocadas ou dias seguidos).
-- Um utente por dia, sem nome: a chave é um resumo (md5) do nome no MetaGest.
-- A Recepção continua a escrever a espera no relatório de turno
-- (espera_min / espera_30): aparece ao lado, como «registado pela Recepção».

create table if not exists erp.espera_utente (
  dia date not null,
  chave text not null,
  triagem time not null,
  consulta time,
  saida time,
  medico text,
  sincronizado_em timestamptz not null default now(),
  primary key (dia, chave)
);
create index if not exists espera_utente_dia on erp.espera_utente (dia);

create or replace function erp.sincronizar_espera(p_de date, p_ate date)
returns int language plpgsql security definer set search_path to 'erp', 'public'
as $f$
declare n int;
begin
  with vs as (
    select (x->>'signs_date')::date dia, x->>'patient' p, min((x->>'signs_time')::time) t
      from jsonb_array_elements(erp.api_lista('Vital Signs', '["signs_date","signs_time","patient"]',
             json_build_array(json_build_array('signs_date', '>=', p_de), json_build_array('signs_date', '<=', p_ate))::text)) x
     where coalesce(x->>'patient', '') <> '' and x->>'signs_time' is not null
     group by 1, 2
  ),
  pe as (
    select (x->>'encounter_date')::date dia, x->>'patient' p,
           min((x->>'encounter_time')::time) t, min(x->>'practitioner') medico
      from jsonb_array_elements(erp.api_lista('Patient Encounter', '["encounter_date","encounter_time","patient","practitioner"]',
             json_build_array(json_build_array('encounter_date', '>=', p_de), json_build_array('encounter_date', '<=', p_ate))::text)) x
     where coalesce(x->>'patient', '') <> '' and x->>'encounter_time' is not null
     group by 1, 2
  ),
  fa as (
    select s.posting_date dia, coalesce(s.patient, s.customer) p, max(s.posting_time) t
      from erp.sales_invoice s
     where s.docstatus = 1 and not s.is_return and s.posting_date between p_de and p_ate
     group by 1, 2
  )
  insert into erp.espera_utente (dia, chave, triagem, consulta, saida, medico, sincronizado_em)
  select vs.dia, md5(vs.p), vs.t,
         case when pe.t >= vs.t then pe.t end,
         case when fa.t > vs.t then fa.t end,
         pe.medico, now()
    from vs left join pe using (dia, p) left join fa using (dia, p)
  on conflict (dia, chave) do update
     set triagem = excluded.triagem, consulta = excluded.consulta, saida = excluded.saida,
         medico = excluded.medico, sincronizado_em = now();
  get diagnostics n = row_count;
  return n;
end $f$;
revoke execute on function erp.sincronizar_espera(date, date) from public, anon, authenticated;

-- Quem vê: a Qualidade (gestão + Direcção Clínica) e a Recepção (é a sua área).
create or replace function public.bsp_qualidade_espera(p_de date, p_ate date)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'erp'
as $f$
declare
  ant_de date := p_de - (p_ate - p_de + 1);
  ant_ate date := p_de - 1;
  ve_medicos boolean := coalesce(public.bsp_e_gestor(), false) or coalesce(public.bsp_le_areas_medicas(), false);
begin
  if not (coalesce(public.bsp_ve_qualidade(), false) or 'recepcao' = public.bsp_minha_area()) then
    raise exception 'Sem acesso.';
  end if;
  if p_ate < p_de or p_ate - p_de > 400 then raise exception 'Período inválido (até 400 dias).'; end if;
  return (
    with e as (
      select dia, triagem, medico,
             case when consulta - triagem between interval '0' and interval '6 hours' then extract(epoch from consulta - triagem) / 60 end consulta_min,
             case when saida - triagem between interval '1 minute' and interval '8 hours' then extract(epoch from saida - triagem) / 60 end estadia_min
        from erp.espera_utente where dia between ant_de and p_ate
    ),
    per as (select * from e where dia between p_de and p_ate),
    ant as (select * from e where dia between ant_de and ant_ate),
    rel as (
      select round(avg(public.bsp_num(r.respostas->>'espera_min')), 1) media,
             sum(coalesce(public.bsp_num(r.respostas->>'espera_30'), 0)) mais_30,
             count(*) filter (where public.bsp_num(r.respostas->>'espera_min') is not null) relatorios
        from public.relatorios_area r where r.area = 'recepcao' and r.dia between p_de and p_ate
    )
    select jsonb_build_object(
      'de', p_de, 'ate', p_ate,
      'triados', (select count(*) from per),
      'estadia', (select jsonb_build_object(
          'n', count(estadia_min),
          'mediana', round((percentile_cont(0.5) within group (order by estadia_min))::numeric, 0),
          'p90', round((percentile_cont(0.9) within group (order by estadia_min))::numeric, 0),
          'mais_2h', count(*) filter (where estadia_min > 120),
          'mais_3h', count(*) filter (where estadia_min > 180)) from per),
      'estadia_antes', (select round((percentile_cont(0.5) within group (order by estadia_min))::numeric, 0) from ant),
      'consulta', (select jsonb_build_object(
          'n', count(consulta_min),
          'mediana', round((percentile_cont(0.5) within group (order by consulta_min))::numeric, 0),
          'p90', round((percentile_cont(0.9) within group (order by consulta_min))::numeric, 0),
          'mais_30', count(*) filter (where consulta_min > 30),
          'mais_60', count(*) filter (where consulta_min > 60)) from per),
      'consulta_antes', (select round((percentile_cont(0.5) within group (order by consulta_min))::numeric, 0) from ant),
      'por_dia', (select coalesce(jsonb_agg(x order by x->>'dia'), '[]'::jsonb) from (
          select jsonb_build_object('dia', dia, 'n', count(estadia_min),
                   'estadia', round((percentile_cont(0.5) within group (order by estadia_min))::numeric, 0),
                   'consulta', round((percentile_cont(0.5) within group (order by consulta_min))::numeric, 0)) x
            from per group by dia) d),
      'por_hora', (select coalesce(jsonb_agg(x order by (x->>'hora')::int), '[]'::jsonb) from (
          select jsonb_build_object('hora', extract(hour from triagem)::int, 'n', count(estadia_min),
                   'estadia', round((percentile_cont(0.5) within group (order by estadia_min))::numeric, 0)) x
            from per group by extract(hour from triagem)::int) h),
      'por_semana', (select coalesce(jsonb_agg(x order by (x->>'dow')::int), '[]'::jsonb) from (
          select jsonb_build_object('dow', extract(dow from dia)::int, 'n', count(estadia_min),
                   'estadia', round((percentile_cont(0.5) within group (order by estadia_min))::numeric, 0)) x
            from per group by extract(dow from dia)::int) w),
      'medicos', case when ve_medicos then (select coalesce(jsonb_agg(x order by (x->>'mediana')::numeric desc), '[]'::jsonb) from (
          select jsonb_build_object('medico', coalesce(m.nome, per.medico), 'n', count(consulta_min),
                   'mediana', round((percentile_cont(0.5) within group (order by consulta_min))::numeric, 0),
                   'mais_60', count(*) filter (where consulta_min > 60)) x
            from per left join erp.medicos m on m.codigo = per.medico
           where per.medico is not null and consulta_min is not null
           group by coalesce(m.nome, per.medico) having count(consulta_min) >= 3) mm) else '[]'::jsonb end,
      'recepcao', (select to_jsonb(rel) from rel),
      'actualizado', (select max(sincronizado_em) from erp.espera_utente)
    ));
end $f$;
revoke execute on function public.bsp_qualidade_espera(date, date) from public, anon;
grant execute on function public.bsp_qualidade_espera(date, date) to authenticated;

-- Cópia: hoje de 30 em 30 min (06h–21h) e os últimos 7 dias todas as noites.
select cron.schedule('bsp-espera-hoje', '*/30 6-21 * * *',
  $$select erp.sincronizar_espera((now() at time zone 'Africa/Luanda')::date, (now() at time zone 'Africa/Luanda')::date)$$);
select cron.schedule('bsp-espera', '50 3 * * *',
  $$select erp.sincronizar_espera((now() at time zone 'Africa/Luanda')::date - 7, (now() at time zone 'Africa/Luanda')::date)$$);
-- Histórico (uma vez): erp.sincronizar_espera mês a mês desde Janeiro de 2026.
