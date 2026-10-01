-- Barispol Workspace · descrição e comentários nas tarefas
-- Pedido do Elmar, 01-10-2026: campo descrição, comentar dentro da própria
-- tarefa (como o Planner do Teams) e levar a tarefa para o Chat. Aplicado no
-- projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais
-- do que uma vez.
--
-- Descrição: as tarefas da equipa guardam-na no estado partilhado (campo
-- desc); as privadas, na coluna nova descricao.
-- Comentários: mensagens na tabela messages, na conversa «tarefa-<id>»
--   · tarefa da equipa: «tarefa-t…» (o id do quadro); vê quem vê o quadro;
--   · tarefa privada: «tarefa-p<id>»; só quem vê a tarefa (o dono, as
--     pessoas com quem está partilhada e quem lê as tarefas privadas de
--     todos: bsp_ve_tarefas_pessoais).

alter table public.tarefas_pessoais add column if not exists descricao text not null default '';

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
  if public.bsp_e_socio() then
    return false;
  end if;
  if alvo like 'th~%' then
    alvo := split_part(alvo, '~', 2);
  end if;
  if alvo like 'dm-%' then
    return bsp_meu_id() is not null and (
      bsp_meu_id() = split_part(substr(alvo, 4), '_', 1)
      or bsp_meu_id() = split_part(substr(alvo, 4), '_', 2)
    );
  end if;
  /* Comentarios de uma tarefa privada: quem ve a tarefa (01-10-2026). */
  if alvo like 'tarefa-p%' then
    if substr(alvo, 9) !~ '^[0-9]+$' then
      return false;
    end if;
    return bsp_meu_id() is not null and exists (
      select 1 from public.tarefas_pessoais t
       where t.id = substr(alvo, 9)::bigint
         and (t.user_id = bsp_meu_id() or bsp_meu_id() = any (t.partilhada_com) or public.bsp_ve_tarefas_pessoais())
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

notify pgrst, 'reload schema';
