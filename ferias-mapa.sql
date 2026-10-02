-- Barispol Workspace · mapa de férias da equipa (02-10-2026)
-- Pedido do Elmar, 02-10-2026: «nas férias, quem vê? pode estar lá todo mapa
-- de quem vai de férias quando na equipa?». Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Corre-se depois de equipa-registos.sql.
--
-- Toda a equipa (sem sócios) vê as férias APROVADAS de todos: pessoa, primeiro
-- e último dia. Nada mais: os outros tipos de ausência (doença, faltas,
-- licenças), as notas e os pedidos por decidir continuam só para a própria
-- pessoa e para quem decide (regra ausencias_ler). Serve o plano anual de
-- férias do regulamento interno (RI-6.1).

create or replace function public.bsp_mapa_ferias(p_ano int)
returns table (user_id text, inicio date, fim date)
language sql stable security definer set search_path to 'public'
as $$
  select a.user_id, a.inicio, a.fim
    from public.ausencias a
   where not public.bsp_e_socio()
     and public.bsp_meu_id() is not null
     and a.tipo = 'Férias' and a.estado = 'Aprovado'
     and a.fim >= make_date(p_ano, 1, 1) and a.inicio <= make_date(p_ano, 12, 31)
   order by a.inicio, a.user_id
$$;
revoke all on function public.bsp_mapa_ferias(int) from public, anon;
grant execute on function public.bsp_mapa_ferias(int) to authenticated;

notify pgrst, 'reload schema';
