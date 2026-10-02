-- Avarias por área (02-10-2026, Elmar: «as avarias não podem aparecer todas
-- para todos, só aparece aos demais as que a sua área reporta»).
--
-- Lêem tudo: a gestão e os Serviços Gerais (bsp_trata_avarias).
-- Os outros lêem as suas e as reportadas por alguém da sua área (o
-- departamento de quem reportou, em shared_state.team). Quem não tem área
-- só vê as suas. A lista de colegas calcula-se uma vez por consulta.

create or replace function public.bsp_ids_da_minha_area()
returns text[]
language sql
stable
security definer
set search_path to 'public'
as $function$
  select coalesce(array_agg(e->>'id'), '{}')
  from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
  where s.id = 1
    and coalesce(public.bsp_minha_area(), '') <> ''
    and public.bsp_area_chave(e->>'dept') = public.bsp_minha_area()
$function$;
grant execute on function public.bsp_ids_da_minha_area() to authenticated;

-- (aplicado com alter policy: a ferramenta do servidor pára com drop)
alter policy avarias_ler on public.avarias to authenticated
  using (
    public.bsp_meu_id() is not null and not public.bsp_e_socio()
    and (
      (select public.bsp_trata_avarias())
      or criado_por = (select public.bsp_meu_id())
      or criado_por in (select unnest(public.bsp_ids_da_minha_area()))
    )
  );
