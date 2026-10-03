-- Tempo de espera dos doentes de cada médico (03-10-2026, Elmar: «Na
-- qualidade não tem para os médicos o tempo de espera, não convém?»).
-- Em «A minha actividade», cada médico vê a espera dos seus doentes
-- (triagem → abertura da consulta no MetaGest), a da clínica para comparar,
-- e quantas das suas consultas ficaram sem registo no MetaGest. Mesmas
-- regras de acesso de bsp_minha_actividade: o próprio; a gestão, o Painel e
-- a Direcção Clínica escolhem o médico. Sem nomes de doentes.

create or replace function public.bsp_minha_espera(p_de date, p_ate date, p_membro text default null)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'erp'
as $f$
declare
  eu text := public.bsp_meu_id();
  alvo text := coalesce(nullif(btrim(p_membro), ''), eu);
  codigos text[];
begin
  if eu is null or public.bsp_e_socio() then raise exception 'Sem acesso.'; end if;
  if p_ate < p_de or p_ate - p_de > 400 then raise exception 'Período inválido (até 400 dias).'; end if;
  if alvo <> eu and not (public.bsp_e_gestor() or public.bsp_ve_painel() or public.bsp_le_areas_medicas()) then
    raise exception 'Só vê os seus próprios números.';
  end if;
  select array(select jsonb_array_elements_text(coalesce(e->'metagest', '[]'::jsonb))) into codigos
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e where s.id = 1 and e->>'id' = alvo limit 1;
  if alvo like 'mg:%' then codigos := array[substr(alvo, 4)]; end if;
  if codigos is null or cardinality(codigos) = 0 then return jsonb_build_object('ligado', false); end if;
  return (
    with e as (
      select medico,
             case when consulta - triagem between interval '0' and interval '6 hours' then extract(epoch from consulta - triagem) / 60 end consulta_min
        from erp.espera_utente where dia between p_de and p_ate
    ),
    meus as (select * from e where medico = any (codigos)),
    -- Consultas facturadas ao médico no período (doente por dia com consulta).
    fact as (
      select count(distinct (s.posting_date, coalesce(s.patient, s.customer))) n
        from erp.sales_invoice s
       where s.docstatus = 1 and not s.is_return and s.ref_practitioner = any (codigos)
         and s.posting_date between p_de and p_ate
         and exists (select 1 from erp.sales_invoice_item i where i.parent = s.name and coalesce(i.item_group, '') ~* 'CONSULTA' and i.amount > 0)
    )
    select jsonb_build_object(
      'ligado', true,
      'n', (select count(consulta_min) from meus),
      'mediana', (select round((percentile_cont(0.5) within group (order by consulta_min))::numeric, 0) from meus),
      'mais_30', (select count(*) filter (where consulta_min > 30) from meus),
      'mais_60', (select count(*) filter (where consulta_min > 60) from meus),
      'clinica_mediana', (select round((percentile_cont(0.5) within group (order by consulta_min))::numeric, 0) from e),
      'consultas_facturadas', (select n from fact),
      'consultas_registadas', (select count(*) from meus))
  );
end $f$;
revoke execute on function public.bsp_minha_espera(date, date, text) from public, anon;
grant execute on function public.bsp_minha_espera(date, date, text) to authenticated;
