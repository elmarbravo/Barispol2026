-- Toners só para quem os trata (05-10-2026, Elmar: «Os toners só a Recepção,
-- Laboratório, Emmanuel e Direcção é que vêem»).
--
-- bsp_ve_toners(): quem trata as avarias (gestão, Serviços Gerais e o
-- Emmanuel, bsp_trata_avarias) e as áreas Recepção e Laboratório. No ecrã,
-- bspVeToners. Antes (toners-gerador.sql) via toda a equipa.

create or replace function public.bsp_ve_toners()
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(public.bsp_trata_avarias(), false)
      or (not coalesce(public.bsp_e_socio(), false) and coalesce(public.bsp_minha_area(), '') in ('recepcao', 'laboratorio'))
$f$;
revoke execute on function public.bsp_ve_toners() from public, anon;
grant execute on function public.bsp_ve_toners() to authenticated;

drop policy if exists impressoras_ler on public.impressoras;
create policy impressoras_ler on public.impressoras for select to authenticated using ((select public.bsp_ve_toners()));
drop policy if exists toners_minimo_ler on public.toners_minimo;
create policy toners_minimo_ler on public.toners_minimo for select to authenticated using ((select public.bsp_ve_toners()));
drop policy if exists toners_mov_ler on public.toners_movimentos;
create policy toners_mov_ler on public.toners_movimentos for select to authenticated using ((select public.bsp_ve_toners()));
drop policy if exists toners_mov_criar on public.toners_movimentos;
create policy toners_mov_criar on public.toners_movimentos for insert to authenticated
  with check ((select public.bsp_ve_toners()) and (tipo = 'Leitura' or (select public.bsp_trata_avarias())));

create or replace function public.bsp_toners_estado()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare r jsonb;
begin
  if not public.bsp_ve_toners() then raise exception 'Sem acesso.'; end if;
  with codigos as (
    select distinct unnest(consumiveis) codigo from public.impressoras where activo
    union select codigo from public.toners_movimentos union select codigo from public.toners_minimo),
  stock as (
    select c.codigo,
           coalesce(sum(case m.tipo when 'Entrada' then m.quantidade when 'Troca' then -m.quantidade when 'Acerto' then m.quantidade else 0 end), 0) qtd,
           coalesce((select minimo from public.toners_minimo t where t.codigo = c.codigo), 1) minimo,
           max(m.criado_em) filter (where m.tipo = 'Troca') ultima_troca
      from codigos c left join public.toners_movimentos m on m.codigo = c.codigo group by c.codigo),
  niveis as (
    select i.id, c codigo,
      (select case when m.tipo = 'Troca' then 100 else m.nivel end from public.toners_movimentos m
        where m.impressora_id = i.id and m.codigo = c and m.tipo in ('Troca', 'Leitura') order by m.criado_em desc limit 1) nivel,
      (select m.criado_em from public.toners_movimentos m
        where m.impressora_id = i.id and m.codigo = c and m.tipo in ('Troca', 'Leitura') order by m.criado_em desc limit 1) visto,
      (select m.criado_em from public.toners_movimentos m
        where m.impressora_id = i.id and m.codigo = c and m.tipo = 'Troca' order by m.criado_em desc limit 1) trocado
      from public.impressoras i, unnest(i.consumiveis) c where i.activo)
  select jsonb_build_object(
    'stock', (select coalesce(jsonb_agg(jsonb_build_object('codigo', codigo, 'qtd', qtd, 'minimo', minimo, 'ultima_troca', ultima_troca) order by codigo), '[]') from stock),
    'niveis', (select coalesce(jsonb_agg(jsonb_build_object('impressora', id, 'codigo', codigo, 'nivel', nivel, 'visto', visto, 'trocado', trocado)), '[]') from niveis))
  into r;
  return r;
end $f$;
revoke execute on function public.bsp_toners_estado() from public, anon;
grant execute on function public.bsp_toners_estado() to authenticated;

-- A novidade de 04-10 que pedia a todos para registar o nível passa a ir só
-- à Recepção e ao Laboratório.
update public.novidades set grupos = array['recepcao', 'laboratorio']
 where titulo = 'Toner a acabar? Registe no Workspace' and grupos = array['todos'];
