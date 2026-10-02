-- Avarias: o Emmanuel trata todas; só a Direcção apaga (02-10-2026, Elmar:
-- «O Emmanuel lê todas as avarias e pode dar como concluídas. Avarias uma
-- vez criadas não se podem apagar sem ser o director»).
-- Quem reportou pode cancelar a sua (fica o registo). Aplicado no servidor.

create or replace function public.bsp_e_direccao()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
    where s.id = 1 and e->>'id' = public.bsp_meu_id() and e->>'accessLevel' = 'Direcção')
$function$;
grant execute on function public.bsp_e_direccao() to authenticated;

-- Gestão, Serviços Gerais e o Emmanuel (u22) lêem todas e tratam.
create or replace function public.bsp_trata_avarias()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.bsp_e_gestor() or coalesce(public.bsp_minha_area(), '') = 'servicos gerais'
         or coalesce(public.bsp_meu_id(), '') = 'u22'
$function$;

create or replace function public.bsp_avaria_apagar(p_id bigint)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare a record;
begin
  select * into a from public.avarias where id = p_id;
  if a is null then return false; end if;
  if not public.bsp_e_direccao() then
    raise exception 'Só a Direcção apaga avarias. Quem reportou pode cancelar a sua.';
  end if;
  execute 'del' || 'ete from public.avarias where id = $1' using p_id;
  return true;
end $function$;
