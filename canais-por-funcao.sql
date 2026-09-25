-- Barispol Workspace · canais de area pela funcao de cada pessoa
-- Pedido do Elmar, 25-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- Cada canal de area (#clinica, #enfermagem, #farmacia, #laboratorio,
-- #radiologia, #recepcao) e so de quem trabalha nessa area: o departamento
-- da pessoa em shared_state.team. Ficam tambem:
--   · a Direccao e a Coordenacao (bsp_e_gestor), em todos;
--   · a Direccao Clinica (Osvaldo Pacheco, bsp_le_areas_medicas), em todos
--     os da saude: clinica, enfermagem, farmacia, laboratorio, radiologia;
--   · quem tiver o canal em extraCanais (ajuste feito no Admin).
-- #geral, #avisos, #escalas e as mensagens directas ficam como estavam.
-- Antes, o servidor deixava qualquer colega ler os canais de area; so o
-- ecra os escondia.

-- A area de um texto (departamento ou canal), sem acentos nem maiusculas.
create or replace function public.bsp_area_chave(t text)
returns text
language sql
immutable
as $$
  select case x when 'rececao' then 'recepcao' else x end
  from (select btrim(translate(lower(coalesce(t, '')), 'áàâãéêíóôõúç', 'aaaaeeiooouc')) as x) q
$$;

-- A area de quem esta ligado.
create or replace function public.bsp_minha_area()
returns text
language sql
stable security definer
set search_path to 'public'
as $$
  select bsp_area_chave(e->>'dept')
  from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
  where s.id = 1 and e->>'id' = bsp_meu_id()
  limit 1
$$;

create or replace function public.bsp_ve_conversa(chave text)
returns boolean
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  alvo text := chave;
  privado boolean;
  area text;
begin
  if alvo like 'th~%' then
    alvo := split_part(alvo, '~', 2);
  end if;
  if alvo like 'dm-%' then
    return bsp_meu_id() is not null and (
      bsp_meu_id() = split_part(substr(alvo, 4), '_', 1)
      or bsp_meu_id() = split_part(substr(alvo, 4), '_', 2)
    );
  end if;
  select jsonb_array_length(coalesce(c.value->'membros', '[]'::jsonb)) > 0 into privado
  from shared_state s, jsonb_array_elements(coalesce(s.channels, '[]'::jsonb)) c
  where s.id = 1 and c.value->>'id' = alvo
  limit 1;
  if coalesce(privado, false) then
    return bsp_e_gestor() or exists (
      select 1
      from shared_state s, jsonb_array_elements(coalesce(s.channels, '[]'::jsonb)) c,
           jsonb_array_elements_text(c.value->'membros') m
      where s.id = 1 and c.value->>'id' = alvo and m = bsp_meu_id()
    );
  end if;
  /* Canais de area: pela funcao (25-09-2026). */
  area := case alvo
    when 'c-clinica'     then 'clinica'
    when 'c-enfermagem'  then 'enfermagem'
    when 'c-farmacia'    then 'farmacia'
    when 'c-laboratorio' then 'laboratorio'
    when 'c-radiologia'  then 'radiologia'
    when 'c-rececao'     then 'recepcao'
    else null end;
  if area is null then
    return true;
  end if;
  return bsp_e_gestor()
    or (bsp_le_areas_medicas() and area in ('clinica', 'enfermagem', 'farmacia', 'laboratorio', 'radiologia'))
    or coalesce(bsp_minha_area(), '') = area
    or exists (
      select 1
      from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e,
           jsonb_array_elements_text(coalesce(e->'extraCanais', '[]'::jsonb)) x
      where s.id = 1 and e->>'id' = bsp_meu_id() and x = alvo
    );
end
$function$;

-- Funcoes: o Nicolau (analista de laboratorio) passa ao Laboratorio; o
-- Emmanuel passa aos Servicos Gerais e responde a Arlete (u2).
update shared_state s
set team = (
  select jsonb_agg(
    case e->>'id'
      when 'u3'  then e || jsonb_build_object('dept', 'Laboratório')
      when 'u22' then e || jsonb_build_object('dept', 'Serviços Gerais', 'superior', 'u2')
      else e end
    order by ord)
  from jsonb_array_elements(s.team) with ordinality as t(e, ord)
)
where s.id = 1;
