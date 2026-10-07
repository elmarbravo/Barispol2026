-- Quem vê a produtividade (07-10-2026, Elmar: «a produtividade só o próprio
-- funcionário, o superior e a gestão podem ver»). Corre-se depois de
-- produtividade.sql e ferias-duas-aprovacoes.sql. Sem «drop».
--
-- Antes também viam os chefes que editam a escala da área (a Direcção Clínica
-- em todas as áreas de saúde) e os responsáveis da área. Agora:
--   · o próprio (só meses já aprovados, como antes);
--   · o superior: com conta, bsp_aprovador_de (campo «superior» da equipa,
--     senão o chefe da área, o mesmo das férias); sem conta (17 pessoas em
--     07-10-2026), o chefe da área (bsp_superior_area: o responsável da escala
--     da área, a Direcção Clínica só quando não há outro);
--   · a gestão (Direcção e Coordenação).
-- O mesmo vale para lançar notas (bsp_produtividade_gravar usa esta função) e
-- para o histórico mensal (desempenho_historico).

create or replace function public.bsp_superior_area(p_area text)
returns text language sql stable security definer set search_path to 'public'
as $f$
  select c.rid
    from public.bsp_escalas_responsaveis() r, unnest(r.ids) c(rid)
   where r.area = p_area
   order by (c.rid = 'u14'), c.rid
   limit 1
$f$;
revoke all on function public.bsp_superior_area(text) from public, anon, authenticated;

create or replace function public.bsp_produtividade_trata(p_area text, p_user text)
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select not coalesce(public.bsp_e_socio(), false) and public.bsp_meu_id() is not null and (
         coalesce(public.bsp_e_gestor(), false)
      or (p_user is not null and p_user is distinct from public.bsp_meu_id()
          and public.bsp_aprovador_de(p_user) = public.bsp_meu_id())
      or (p_user is null and coalesce(p_area, '') <> '' and public.bsp_superior_area(p_area) = public.bsp_meu_id()))
$f$;

alter policy hist_ler on public.desempenho_historico
  using (user_id = (select public.bsp_meu_id()) or public.bsp_produtividade_trata(null, user_id));
