-- Barispol Workspace · alerta aos chefes de área para fazerem as escalas
-- Pedido do Elmar, 30-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
-- Precisa do escalas.sql e do novidades.sql.
--
-- Do dia 20 ao dia 29 de cada mês, às 04h55 de Luanda, cada área que ainda
-- não publicou a escala do mês seguinte gera uma novidade para o chefe
-- dessa área. As novidades saem por e-mail às 05h00 (bsp-novidades) e
-- aparecem no sino. Uma por área e por dia; quando a escala é publicada,
-- os alertas param.
--
-- Chefe de uma área (a mesma regra de bsp_edita_escala e bspEditaEscala):
--   · quem é dessa área e tem cargo de chefia (chefe, supervisora,
--     coordenador, director, responsável);
--   · quem é «superior» de alguém dessa área.
-- Área sem chefe: o alerta vai para a Arlete (u2, Coordenação e RH), que
-- pode fazer escalas de todas as áreas.
-- A Administração não trabalha por turnos: fica de fora.

create or replace function public.bsp_escalas_responsaveis()
returns table (area text, nome_area text, ids text[])
language sql
stable
security definer
set search_path to 'public'
as $function$
  with equipa as (
    select e from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1 and not public.bsp_membro_e_socio(e) and not coalesce((e->>'semEmails')::boolean, false)
  ), areas as (
    select public.bsp_area_chave(e->>'dept') area, min(e->>'dept') nome_area
      from equipa
     where public.bsp_area_chave(e->>'dept') is not null
       and public.bsp_area_chave(e->>'dept') not in ('', 'administracao')
     group by 1
  ), chefes as (
    select a.area, array(
      select distinct c->>'id' from equipa q, lateral (select q.e as c) z
       where (public.bsp_area_chave(c->>'dept') = a.area and coalesce(c->>'role', '') ~* '(chefe|supervis|coordenad|director|directora|respons)')
          or exists (select 1 from equipa x where x.e->>'superior' = c->>'id' and public.bsp_area_chave(x.e->>'dept') = a.area)
       order by 1) ids
      from areas a
  )
  select a.area, a.nome_area, case when cardinality(c.ids) > 0 then c.ids else array['u2'] end
    from areas a join chefes c using (area)
   order by a.nome_area
$function$;
revoke all on function public.bsp_escalas_responsaveis() from public, anon;
grant execute on function public.bsp_escalas_responsaveis() to authenticated, service_role;

create or replace function public.bsp_escalas_alertar(p_hoje date default (now() at time zone 'Africa/Luanda')::date)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  meses text[] := array['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
  v_mes date := (date_trunc('month', p_hoje) + interval '1 month')::date;
  fim date := (date_trunc('month', p_hoje) + interval '1 month - 1 day')::date;
  nome_mes text;
  r record;
  estado_actual text;
  v_titulo text;
  n integer := 0;
begin
  if extract(day from p_hoje) not between 20 and 29 then return 0; end if;
  nome_mes := meses[extract(month from v_mes)::int] || ' de ' || extract(year from v_mes)::int;
  for r in select * from public.bsp_escalas_responsaveis() loop
    select e.estado into estado_actual from public.escalas e where e.area = r.area and e.mes = v_mes;
    continue when estado_actual = 'publicada';
    v_titulo := 'Escala de ' || nome_mes || ' por publicar: ' || r.nome_area;
    continue when exists (select 1 from public.novidades v where v.titulo = v_titulo
                            and (v.criado_em at time zone 'Africa/Luanda')::date = (now() at time zone 'Africa/Luanda')::date);
    insert into public.novidades (titulo, texto, grupos, destino, criado_por) values (
      v_titulo,
      'A escala de ' || nome_mes || ' da área ' || r.nome_area || ' ainda não está publicada no Workspace.'
        || E'\n\n' || case when estado_actual = 'rascunho' then 'Já existe um rascunho: reveja-o e carregue em «Publicar».'
                           else 'Abra o menu Escalas, escolha a área e o mês, preencha os turnos e carregue em «Publicar».' end
        || E'\n\n' || 'Prazo: ' || to_char(fim, 'DD') || ' de ' || meses[extract(month from fim)::int]
        || ' (faltam ' || (fim - p_hoje) || case when fim - p_hoje = 1 then ' dia' else ' dias' end || '). '
        || 'Este aviso repete-se todos os dias, de 20 a 29, até a escala estar publicada.',
      r.ids, 'escalas', null);
    n := n + 1;
  end loop;
  return n;
end $function$;
revoke all on function public.bsp_escalas_alertar(date) from public, anon, authenticated;
grant execute on function public.bsp_escalas_alertar(date) to service_role;

-- 04h55 em Luanda (03h55 UTC), dias 20 a 29. As novidades saem às 05h00.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'bsp-escalas-alerta') then
    perform cron.unschedule('bsp-escalas-alerta');
  end if;
  perform cron.schedule('bsp-escalas-alerta', '55 3 20-29 * *', 'select public.bsp_escalas_alertar()');
end $$;

notify pgrst, 'reload schema';
