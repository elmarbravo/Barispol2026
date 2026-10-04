-- A Arlete vê tudo o que é consumo (05-10-2026, Elmar: «Arlete vê tudo que é
-- consumo»).
--
-- bsp_ve_consumos(): o Elmar (u1) e a Arlete (u2) pelo nome, mais a gestão.
-- Antes a Arlete só via pela camada (Direcção/Coordenação); se a camada mudar,
-- continua a ver. Entra em: toners (bsp_ve_toners), gerador (leitura e
-- bsp_gerador_estado), transporte (combustível, viagens, manutenção:
-- bsp_ve_transporte) e stock (bsp_ve_stock). Registar continua com quem
-- trata. Os avisos de toner e de gasóleo vão sempre também à Arlete.
-- No ecrã: bspVeConsumos.

create or replace function public.bsp_ve_consumos()
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select public.bsp_meu_id() is not null and not coalesce(public.bsp_e_socio(), false)
     and (public.bsp_meu_id() in ('u1', 'u2') or coalesce(public.bsp_e_gestor(), false))
$f$;
revoke execute on function public.bsp_ve_consumos() from public, anon;
grant execute on function public.bsp_ve_consumos() to authenticated;

create or replace function public.bsp_ve_toners()
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(public.bsp_trata_avarias(), false) or coalesce(public.bsp_ve_consumos(), false)
      or (not coalesce(public.bsp_e_socio(), false) and coalesce(public.bsp_minha_area(), '') in ('recepcao', 'laboratorio'))
$f$;

create or replace function public.bsp_ve_gerador()
returns boolean language sql stable security definer set search_path to 'public'
as $f$ select coalesce(public.bsp_trata_avarias(), false) or coalesce(public.bsp_ve_consumos(), false) $f$;
revoke execute on function public.bsp_ve_gerador() from public, anon;
grant execute on function public.bsp_ve_gerador() to authenticated;

drop policy if exists gerador_ler on public.gerador;
create policy gerador_ler on public.gerador for select to authenticated using ((select public.bsp_ve_gerador()));
drop policy if exists gerador_reg_ler on public.gerador_registos;
create policy gerador_reg_ler on public.gerador_registos for select to authenticated using ((select public.bsp_ve_gerador()));

create or replace function public.bsp_gerador_estado()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
begin
  if not public.bsp_ve_gerador() then raise exception 'Sem acesso.'; end if;
  return public.bsp_gerador_calculo();
end $f$;

create or replace function public.bsp_ve_transporte()
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select not public.bsp_e_socio() and (
       public.bsp_ve_consumos()
    or exists (
      select 1 from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
       where s.id = 1 and e->>'id' = public.bsp_meu_id()
         and coalesce(e->>'role', '') ~* 'motorista'))
$f$;

create or replace function public.bsp_ve_stock(p_armazem text default null)
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select public.bsp_meu_id() is not null and not public.bsp_e_socio() and (
    public.bsp_ve_consumos()
    or exists (select 1 from public.stock_responsaveis r
                where r.user_id = public.bsp_meu_id() and (r.armazem = '*' or p_armazem is null or r.armazem = p_armazem)))
$f$;

create or replace function public.bsp_servicos_gerais_ids()
returns text[] language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(array_agg(distinct x), '{}') from (
    select e->>'id' x
      from public.shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1 and not public.bsp_membro_e_socio(e)
       and (e->>'id' in ('u22', 'u2') or public.bsp_membro_nos_grupos(e, array['gestao', 'servicos gerais']))) z
$f$;
