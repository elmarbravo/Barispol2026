-- Início pessoal (29-10-2026, auditoria do Início; Elmar: «Faz as 3»).
-- bsp_relatorio_por_entregar(): os relatórios de turno que a própria pessoa
-- ainda deve, pela mesma regra do bsp_relatorios_lembrar (escala publicada,
-- turno de hoje ou de ontem já acabado, nenhum relatório dessa área e dia de
-- quem estava no turno). Só lê; devolve área, dia e turno, sem nomes.

create or replace function public.bsp_relatorio_por_entregar()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare
  eu text := public.bsp_meu_id();
  agora timestamp := now() at time zone 'Africa/Luanda';
  d_dia date; e record; t jsonb; ids text[]; fim timestamp; area_form text; dow int;
  res jsonb := '[]'::jsonb;
begin
  if eu is null or not public.bsp_mfa_ok() then return res; end if;
  foreach d_dia in array array[agora::date, agora::date - 1] loop
    dow := extract(dow from d_dia)::int;
    for e in select * from public.escalas
              where mes = date_trunc('month', d_dia)::date and estado = 'publicada'
                and area in ('recepcao', 'laboratorio', 'farmacia', 'enfermagem', 'radiologia') loop
      area_form := case e.area when 'recepcao' then 'rececao' when 'radiologia' then 'imagiologia' else e.area end;
      for t in select * from jsonb_array_elements(coalesce(e.turnos, '[]'::jsonb)) loop
        if not coalesce(t->'semana' @> to_jsonb(dow), false) then continue; end if;
        select coalesce(array_agg(x), '{}') into ids
          from jsonb_array_elements_text(coalesce(e.dias->(d_dia::text)->(t->>'id'), '[]'::jsonb)) x where x !~ '^x:';
        if not (eu = any(ids)) then continue; end if;
        fim := d_dia + coalesce(nullif(t->>'fim', ''), '22:30')::time;
        if agora < fim or agora > fim + interval '24 hours' then continue; end if;
        if exists (select 1 from public.relatorios_area r where r.area = area_form and r.dia = d_dia and r.user_id = any(ids)) then continue; end if;
        res := res || jsonb_build_array(jsonb_build_object('area', area_form, 'dia', d_dia, 'turno', t->>'nome', 'fim', t->>'fim'));
      end loop;
    end loop;
  end loop;
  return res;
end $f$;
revoke all on function public.bsp_relatorio_por_entregar() from public, anon;
grant execute on function public.bsp_relatorio_por_entregar() to authenticated;

-- Também aplicado a 29-10-2026 (por substituição no próprio servidor):
-- bsp_alertas_por_ler deixa de pedir a leitura de documentos destinados a
-- outros grupos a quem publica; acrescenta, a seguir a
-- «public.bsp_ve_documento(d.grupos, d.publicado_por)»:
--   and public.bsp_doc_no_grupo((select x from public.shared_state s,
--       jsonb_array_elements(s.team) x where s.id = 1 and x->>'id' = eu limit 1), d.grupos)
