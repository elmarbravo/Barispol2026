-- Quem vê o Stock e as compras correntes (07-10-2026, aplicado). Elmar: «a
-- Solange vê todos os stocks de saúde, a Rosa apenas o Laboratório, a Arlete
-- todos da empresa. O das compras que nem são de saúde só a Arlete vê comigo».
-- Corre-se depois de stock.sql e logistica-compras.sql. Sem «drop».
-- Ecrã: BSP_STOCK_RESPONSAVEIS, bspVeStock, bspVeComprasGerais (mudar juntos).
set lock_timeout = '5s';
insert into public.stock_responsaveis (user_id, armazem) values
  ('u1', '*'), ('u2', '*'),
  ('u17', 'FARMÁCIA - CBL'), ('u17', 'LABORATÓRIO - CBL'), ('u17', 'ENFERMAGEM - CBL'),
  ('u13', 'LABORATÓRIO - CBL')
on conflict do nothing;

-- O Stock deixa de seguir a regra dos consumos: só stock_responsaveis.
CREATE OR REPLACE FUNCTION public.bsp_ve_stock(p_armazem text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.bsp_meu_id() is not null and not public.bsp_e_socio() and
    exists (select 1 from public.stock_responsaveis r
             where r.user_id = public.bsp_meu_id() and (r.armazem = '*' or p_armazem is null or r.armazem = p_armazem))
$function$;

-- Compras correntes: só o Elmar e a Arlete (ler, registar, alterar, apagar).
CREATE OR REPLACE FUNCTION public.bsp_ve_compras_gerais()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(public.bsp_meu_id() in ('u1', 'u2'), false)
$function$;
revoke all on function public.bsp_ve_compras_gerais() from public, anon;
grant execute on function public.bsp_ve_compras_gerais() to authenticated;

alter policy logistica_ler on public.logistica_compras using (public.bsp_ve_compras_gerais());
alter policy logistica_criar on public.logistica_compras with check (public.bsp_ve_compras_gerais());
alter policy logistica_mudar on public.logistica_compras using (public.bsp_ve_compras_gerais()) with check (public.bsp_ve_compras_gerais());
alter policy logistica_apagar on public.logistica_compras using (public.bsp_ve_compras_gerais());
