-- Documentos «Para quem» sem misturar áreas (06-10-2026, Elmar: «ao publicar
-- um documento, para quem pode ver, juntaste técnicos de laboratório com os da
-- farmácia; revê todas essas secções para não vazar informação»).
-- Corre-se depois de documentos-destino.sql.
--
-- O grupo «cargo:tecnicos» saía só da palavra «técnico/analista» no cargo e
-- juntava Laboratório e Farmácia. Elmar: «gere os cargos como deve ser: téc.
-- de farmácia, téc. de enfermagem, téc. de laboratório». Os grupos das áreas
-- de saúde saem da área da pessoa (departamento), com o chefe da área:
--   cargo:enfermeiros              Técnicos de enfermagem (área Enfermagem)
--   cargo:tecnicos-laboratorio     Técnicos de laboratório (área Laboratório)
--   cargo:tecnicos-farmacia        Técnicos de farmácia (área Farmácia)
--   cargo:radiologistas            Técnicos de radiologia (área Radiologia)
--   cargo:medicos                  Médicos (pelo cargo)
-- Ninguém de uma área entra no grupo de outra.
-- «cargo:tecnicos» continua a ser lido (= Laboratório + Farmácia) para os
-- documentos antigos, mas já não se oferece no ecrã.
-- Os grupos por cargo passam a ler o membro inteiro (cargo + departamento):
-- bsp_cargo_grupos_membro. No ecrã: BSP_DOC_CARGOS (mudar os dois juntos).

create or replace function public.bsp_cargo_grupos_membro(membro jsonb)
returns text[] language sql stable set search_path to 'public'
as $f$
  select array_remove(array[
    case when c ~* '(m[eé]dic|director cl[ií]nico|pediatra)' and a in ('clinica', '') then 'cargo:medicos' end,
    case when a = 'radiologia' or (a = '' and c ~* 'radiolog') then 'cargo:radiologistas' end,
    case when a = 'enfermagem' or (a = '' and c ~* 'enferm') then 'cargo:enfermeiros' end,
    case when a = 'laboratorio' then 'cargo:tecnicos-laboratorio' end,
    case when a = 'farmacia' then 'cargo:tecnicos-farmacia' end,
    case when a in ('laboratorio', 'farmacia') then 'cargo:tecnicos' end,
    case when chefe then 'cargo:chefes' end,
    case when a = 'recepcao' or (a = '' and c ~* 'recep') then 'cargo:recepcao' end,
    case when c ~* '(administrativ|\mrh\M|recursos humanos)' then 'cargo:administrativos' end,
    case when c ~* 'motorista' then 'cargo:motorista' end
  ], null)
  from (select coalesce(membro->>'role', '') c, public.bsp_area_chave(coalesce(membro->>'dept', '')) a,
               coalesce(membro->>'role', '') ~* '(chefe|supervisor|director)' chefe) x
$f$;
revoke all on function public.bsp_cargo_grupos_membro(jsonb) from public, anon;
grant execute on function public.bsp_cargo_grupos_membro(jsonb) to authenticated;

create or replace function public.bsp_doc_no_grupo(membro jsonb, p_grupos text[])
returns boolean language sql stable set search_path to 'public'
as $f$
  select membro is not null and not public.bsp_membro_e_socio(membro) and (
       'todos' = any (coalesce(p_grupos, array['todos']))
    or ('camada:' || coalesce(membro->>'accessLevel', '')) = any (p_grupos)
    or public.bsp_cargo_grupos_membro(membro) && p_grupos)
$f$;

-- O documento antigo com «cargo:tecnicos» fica com os dois grupos novos
-- (as mesmas pessoas de antes; o Elmar decide se deve ficar só um).
update public.documentos
   set grupos = array_remove(grupos, 'cargo:tecnicos') || array['cargo:tecnicos-laboratorio', 'cargo:tecnicos-farmacia']
 where 'cargo:tecnicos' = any (grupos);

notify pgrst, 'reload schema';
