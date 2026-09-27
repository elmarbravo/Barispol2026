-- Barispol Workspace · categoria «Sócio»
-- Pedido do Elmar, 27-09-2026: os socios vem so numeros (o Painel) e nada
-- do dia-a-dia. Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no
-- mesmo dia. Pode correr-se mais do que uma vez. Corre antes de painel.sql.
--
-- Um socio e quem tem accessLevel 'Sócio' (ou uma camada com soNumeros).
-- No servidor:
--   · ve o painel (bsp_painel, em painel.sql);
--   · nao ve conversas (bsp_ve_conversa devolve falso), nem o Feed, nem os
--     ficheiros do Drive; Marcacoes, CRM e tarefas privadas ja eram
--     fechadas;
--   · so recebe novidades do grupo 'socios' (ou dirigidas a ele pelo id);
--   · a resumo-matinal nao lhe manda lembretes nem resumos (versao 7).
-- Limite: o estado partilhado (shared_state: equipa, tarefas da equipa,
-- agenda) continua legivel por quem entra, porque o Workspace precisa da
-- equipa e das camadas para arrancar. O ecra do socio nao o mostra.

create or replace function public.bsp_membro_e_socio(membro jsonb)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select coalesce(membro is not null and (
       (membro->>'accessLevel') = 'Sócio'
    or coalesce(((select s.camadas from shared_state s where s.id = 1) -> (membro->>'accessLevel') ->> 'soNumeros')::boolean, false)
  ), false)
$function$;

create or replace function public.bsp_e_socio()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1
       and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email', ''))
       and public.bsp_membro_e_socio(e))
$function$;
grant execute on function public.bsp_e_socio() to authenticated;

-- A camada, para aparecer no Admin (Pessoas e Permissoes).
update public.shared_state
   set camadas = coalesce(camadas, '{}'::jsonb) || jsonb_build_object('Sócio', jsonb_build_object(
         'ordem', 8,
         'desc', 'Sócios da clínica. Vêem só o Painel com os números do MetaGest; não vêem o Chat, o Feed, as tarefas, a agenda, o Drive, o CRM nem as marcações.',
         'canais', '[]'::jsonb, 'admin', null, 'soNumeros', true,
         'podeGerirUtilizadores', false, 'podeVerSistema', false,
         'podeVerTarefasPessoais', false, 'podeApagarFicheiros', false))
 where id = 1 and not (coalesce(camadas, '{}'::jsonb) ? 'Sócio');

-- Conversas: nenhuma para socios.
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

-- Feed e Drive: fechados para socios.
alter policy bsp_post_ler on public.posts using (not public.bsp_e_socio());
alter policy bsp_drive_ler on storage.objects using (
  not public.bsp_e_socio() and (bucket_id = 'drive') and (
       ((name !~~ 'privado/%') and (name !~~ 'conversa/%'))
    or ((name ~~ 'privado/%') and ((split_part(name, '/', 2) = bsp_meu_id()) or bsp_ve_pessoais_de_todos()))
    or ((name ~~ 'conversa/%') and bsp_ve_conversa(split_part(name, '/', 2)))));

-- Novidades: aos socios, so as do grupo 'socios' ou com o id deles.
create or replace function public.bsp_membro_nos_grupos(membro jsonb, grupos text[])
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select coalesce(membro is not null and (
    case when public.bsp_membro_e_socio(membro) then
         'socios' = any (grupos) or (membro->>'id') = any (grupos)
    else
         'todos' = any (grupos)
      or (membro->>'id') = any (grupos)
      or public.bsp_area_chave(membro->>'dept') = any (grupos)
      or ('direccao-clinica' = any (grupos) and (membro->>'id') = any (array['u14']))
      or ('gestao' = any (grupos) and coalesce(
            ((select s.camadas from shared_state s where s.id = 1) -> (membro->>'accessLevel') ->> 'podeGerirUtilizadores')::boolean,
            (membro->>'accessLevel') in ('Direcção', 'Coordenação')))
    end
  ), false)
$function$;

notify pgrst, 'reload schema';
