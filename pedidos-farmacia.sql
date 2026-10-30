-- Pedido de material à Farmácia pelo Workspace, com recepção de produtos
-- (30-10-2026, Elmar: «sim» à proposta; auditoria dos relatórios: a recepção de
-- produtos não existia em lado nenhum). Até aqui o Laboratório e a Enfermagem
-- pediam por e-mail à Solange e à Arlete (35 pedidos de Maio a Outubro) e o
-- MetaGest deixou de registar as entregas (facturas internas ao cliente
-- «LABORATORIO» pararam em 01-2026).
-- Fluxo: a área pede (Pedido) → a Farmácia entrega com lote e validade
-- (Entregue) → a área confere a recepção (Recebido ou Recusado): quantidade,
-- embalagem, frio e validade (boas práticas de recepção, OMS / ISO 15189 §6.6).
-- - pedidos_area: só por estas funções; lêem a área, a Farmácia, a gestão e
--   a Direcção Clínica (u14).
-- - bsp_pedido_area_criar / _entregar / _receber / _cancelar.
-- - Avisos: pedido novo → Farmácia; entregue → quem pediu e a área; recepção
--   com problema (falta, embalagem, frio, validade, recusa) → Farmácia, u1, u2,
--   u14 e novidade.
-- - bsp_turno_reforco(area): o que a área recebeu desde a última contagem do
--   turno; o ecrã preenche a coluna «Reforço» (TurnoContagemForm).
-- Durante uma semana os pedidos por e-mail continuam em paralelo (Elmar).

create table if not exists public.pedidos_area (
  id bigint generated always as identity primary key,
  area text not null,
  criado_por text not null,
  criado timestamptz not null default now(),
  itens jsonb not null default '[]'::jsonb,
  nota text,
  urgente boolean not null default false,
  estado text not null default 'Pedido' check (estado in ('Pedido', 'Entregue', 'Recebido', 'Recusado', 'Cancelado')),
  entregue_por text,
  entregue_em timestamptz,
  entrega jsonb,
  nota_entrega text,
  recebido_por text,
  recebido_em timestamptz,
  recepcao jsonb,
  problema boolean not null default false
);
create index if not exists pedidos_area_area_idx on public.pedidos_area (area, criado desc);
alter table public.pedidos_area enable row level security;
revoke all on public.pedidos_area from anon, authenticated;
grant select on public.pedidos_area to authenticated;

create or replace function public.bsp_pedidos_area_ve(p_area text)
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select public.bsp_meu_id() is not null and (
    coalesce(public.bsp_minha_area(), '') in (p_area, 'farmacia')
    or public.bsp_e_gestor() or public.bsp_meu_id() = 'u14');
$f$;
grant execute on function public.bsp_pedidos_area_ve(text) to authenticated;

create policy bsp_pedidos_area_ler on public.pedidos_area for select to authenticated
  using (public.bsp_pedidos_area_ve(area));

create or replace function public.bsp_area_membros(p_area text)
returns text[] language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(array_agg(distinct x->>'id'), '{}')
    from shared_state s, jsonb_array_elements(s.team) x
   where public.bsp_area_chave(x->>'dept') = p_area and not coalesce((x->>'inactivo')::boolean, false);
$f$;
revoke all on function public.bsp_area_membros(text) from public, anon, authenticated;

create or replace function public.bsp_pedido_area_criar(p_area text, p_itens jsonb, p_nota text, p_urgente boolean)
returns bigint language plpgsql volatile security definer set search_path to 'public'
as $f$
declare eu text := public.bsp_meu_id(); v_id bigint; lim jsonb; nome_area text; txt text;
begin
  if eu is null or not public.bsp_mfa_ok() then raise exception 'Sem sessão.'; end if;
  if p_area not in ('laboratorio', 'enfermagem') then raise exception 'Esta área ainda não pede pelo Workspace.'; end if;
  if not (public.bsp_minha_area() = p_area or public.bsp_e_gestor()) then raise exception 'Só a própria área faz o pedido.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('k', left(coalesce(nullif(trim(x->>'k'), ''), trim(x->>'nome')), 60),
           'nome', left(trim(x->>'nome'), 60), 'q', round(public.bsp_num(x->>'q')))), '[]'::jsonb)
    into lim from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) x
   where trim(coalesce(x->>'nome', '')) <> '' and coalesce(public.bsp_num(x->>'q'), 0) > 0;
  if jsonb_array_length(lim) = 0 then raise exception 'Escolha pelo menos um artigo com quantidade.'; end if;
  insert into pedidos_area (area, criado_por, itens, nota, urgente)
  values (p_area, eu, lim, nullif(left(trim(coalesce(p_nota, '')), 1000), ''), coalesce(p_urgente, false))
  returning id into v_id;
  nome_area := case p_area when 'laboratorio' then 'Laboratório' else 'Enfermagem' end;
  txt := nome_area || ' pede ' || jsonb_array_length(lim) || (case when jsonb_array_length(lim) = 1 then ' artigo' else ' artigos' end) || ': '
      || (select string_agg((x->>'nome') || ' × ' || (x->>'q'), ', ') from jsonb_array_elements(lim) x);
  perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(public.bsp_area_membros('farmacia')), 'exceto', eu,
    'titulo', (case when p_urgente then 'Pedido URGENTE do ' else 'Pedido do ' end) || nome_area,
    'corpo', left(txt, 160), 'url', '#/stock', 'tag', 'pedido-area-' || v_id));
  return v_id;
end $f$;
grant execute on function public.bsp_pedido_area_criar(text, jsonb, text, boolean) to authenticated;

create or replace function public.bsp_pedido_area_entregar(p_id bigint, p_entrega jsonb, p_nota text)
returns boolean language plpgsql volatile security definer set search_path to 'public'
as $f$
declare eu text := public.bsp_meu_id(); p record; lim jsonb; nome_area text;
begin
  if eu is null or not public.bsp_mfa_ok() then raise exception 'Sem sessão.'; end if;
  if not (public.bsp_minha_area() = 'farmacia' or public.bsp_e_gestor()) then raise exception 'Só a Farmácia regista a entrega.'; end if;
  select * into p from pedidos_area where id = p_id for update;
  if not found or p.estado <> 'Pedido' then raise exception 'Este pedido já não está à espera de entrega.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('k', left(coalesce(nullif(trim(x->>'k'), ''), trim(x->>'nome')), 60),
           'nome', left(trim(x->>'nome'), 60), 'q', greatest(0, round(coalesce(public.bsp_num(x->>'q'), 0))),
           'lote', nullif(left(trim(coalesce(x->>'lote', '')), 40), ''),
           'validade', case when coalesce(x->>'validade', '') ~ '^\d{4}-\d{2}-\d{2}$' then x->>'validade' end)), '[]'::jsonb)
    into lim from jsonb_array_elements(coalesce(p_entrega, '[]'::jsonb)) x where trim(coalesce(x->>'nome', '')) <> '';
  if not exists (select 1 from jsonb_array_elements(lim) x where (x->>'q')::numeric > 0) then
    raise exception 'Escreva o que entrega (ou cancele o pedido).';
  end if;
  update pedidos_area set estado = 'Entregue', entregue_por = eu, entregue_em = now(), entrega = lim,
         nota_entrega = nullif(left(trim(coalesce(p_nota, '')), 1000), '') where id = p_id;
  nome_area := case p.area when 'laboratorio' then 'Laboratório' else 'Enfermagem' end;
  perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(array(select distinct unnest(public.bsp_area_membros(p.area) || array[p.criado_por]))),
    'exceto', eu, 'titulo', 'A Farmácia entregou o pedido',
    'corpo', 'Confira a recepção no Workspace: quantidades, embalagem, frio e validade.', 'url', '#/dashboard', 'tag', 'pedido-area-' || p_id));
  return true;
end $f$;
grant execute on function public.bsp_pedido_area_entregar(bigint, jsonb, text) to authenticated;

-- p_recepcao: { itens: [{k, q}], embalagem: 'Íntegra'|'Danificada',
--   frio: 'Adequado'|'Fora de 2–8 °C'|'Não se aplica',
--   validade: 'Conferida'|'Curta (menos de 3 meses)'|'Caducada',
--   recusar: bool, nota }
create or replace function public.bsp_pedido_area_receber(p_id bigint, p_recepcao jsonb)
returns jsonb language plpgsql volatile security definer set search_path to 'public'
as $f$
declare eu text := public.bsp_meu_id(); p record; it jsonb; rec numeric; faltas text[] := '{}';
  probs text[] := '{}'; recusar boolean := coalesce((p_recepcao->>'recusar')::boolean, false); r jsonb; nome_area text; txt text; itens jsonb := '[]'::jsonb;
begin
  if eu is null or not public.bsp_mfa_ok() then raise exception 'Sem sessão.'; end if;
  select * into p from pedidos_area where id = p_id for update;
  if not found or p.estado <> 'Entregue' then raise exception 'Este pedido não está à espera de recepção.'; end if;
  if not (public.bsp_minha_area() = p.area or public.bsp_e_gestor()) then raise exception 'Só a área que pediu confere a recepção.'; end if;
  if coalesce(p_recepcao->>'embalagem', '') not in ('Íntegra', 'Danificada')
     or coalesce(p_recepcao->>'frio', '') not in ('Adequado', 'Fora de 2–8 °C', 'Não se aplica')
     or coalesce(p_recepcao->>'validade', '') not in ('Conferida', 'Curta (menos de 3 meses)', 'Caducada') then
    raise exception 'Responda à embalagem, ao frio e à validade.';
  end if;
  if recusar and trim(coalesce(p_recepcao->>'nota', '')) = '' then raise exception 'Escreva o motivo da recusa.'; end if;
  for it in select * from jsonb_array_elements(coalesce(p.entrega, '[]'::jsonb)) loop
    select public.bsp_num(x->>'q') into rec from jsonb_array_elements(coalesce(p_recepcao->'itens', '[]'::jsonb)) x where x->>'k' = it->>'k' limit 1;
    rec := case when recusar then 0 else greatest(0, round(coalesce(rec, (it->>'q')::numeric))) end;
    itens := itens || jsonb_build_object('k', it->>'k', 'nome', it->>'nome', 'q', rec, 'entregue', (it->>'q')::numeric);
    if not recusar and rec < (it->>'q')::numeric then faltas := faltas || ((it->>'nome') || ' (' || rec || ' de ' || (it->>'q') || ')'); end if;
  end loop;
  if array_length(faltas, 1) > 0 then probs := probs || ('Quantidade a menos: ' || array_to_string(faltas, ', ')); end if;
  if p_recepcao->>'embalagem' = 'Danificada' then probs := probs || 'embalagem danificada'::text; end if;
  if p_recepcao->>'frio' = 'Fora de 2–8 °C' then probs := probs || 'frio fora de 2–8 °C'::text; end if;
  if p_recepcao->>'validade' <> 'Conferida' then probs := probs || ('validade ' || lower(p_recepcao->>'validade')); end if;
  if recusar then probs := array['Recusado: ' || trim(p_recepcao->>'nota')] || probs; end if;
  r := jsonb_build_object('itens', itens, 'embalagem', p_recepcao->>'embalagem', 'frio', p_recepcao->>'frio',
         'validade', p_recepcao->>'validade', 'nota', nullif(left(trim(coalesce(p_recepcao->>'nota', '')), 1000), ''),
         'problemas', to_jsonb(probs));
  update pedidos_area set estado = case when recusar then 'Recusado' else 'Recebido' end, recebido_por = eu, recebido_em = now(),
         recepcao = r, problema = coalesce(array_length(probs, 1), 0) > 0 where id = p_id;
  if array_length(probs, 1) > 0 then
    nome_area := case p.area when 'laboratorio' then 'Laboratório' else 'Enfermagem' end;
    txt := nome_area || ', pedido n.º ' || p_id || ' entregue pela Farmácia: ' || array_to_string(probs, '; ') || '.';
    insert into novidades (titulo, texto, grupos, destino) values ('Recepção de produtos com problema', txt, array['gestao', 'farmacia', 'direccao-clinica', p.area], null);
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(array(select distinct unnest(public.bsp_area_membros('farmacia') || array['u1', 'u2', 'u14']))),
      'exceto', eu, 'titulo', 'Recepção de produtos com problema', 'corpo', left(txt, 160), 'url', '#/stock', 'tag', 'pedido-area-rec-' || p_id));
  end if;
  return jsonb_build_object('ok', true, 'problemas', to_jsonb(probs));
end $f$;
grant execute on function public.bsp_pedido_area_receber(bigint, jsonb) to authenticated;

create or replace function public.bsp_pedido_area_cancelar(p_id bigint)
returns boolean language plpgsql volatile security definer set search_path to 'public'
as $f$
declare eu text := public.bsp_meu_id(); p record;
begin
  if eu is null or not public.bsp_mfa_ok() then raise exception 'Sem sessão.'; end if;
  select * into p from pedidos_area where id = p_id for update;
  if not found or p.estado <> 'Pedido' then raise exception 'Só se cancela um pedido ainda por entregar.'; end if;
  if not (p.criado_por = eu or public.bsp_e_gestor() or public.bsp_minha_area() = 'farmacia') then raise exception 'Sem permissão.'; end if;
  update pedidos_area set estado = 'Cancelado' where id = p_id;
  return true;
end $f$;
grant execute on function public.bsp_pedido_area_cancelar(bigint) to authenticated;

-- Reforço desde a última contagem do turno: soma do que a área recebeu.
create or replace function public.bsp_turno_reforco(p_area text)
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(jsonb_object_agg(k, q), '{}'::jsonb) from (
    select x->>'k' k, sum((x->>'q')::numeric) q
      from pedidos_area p, jsonb_array_elements(coalesce(p.recepcao->'itens', '[]'::jsonb)) x
     where p.area = p_area and p.estado = 'Recebido' and public.bsp_pedidos_area_ve(p_area)
       and p.recebido_em > coalesce((select max(criado) from turno_contagens where area = p_area), '-infinity')
       and (x->>'q')::numeric > 0
     group by 1) z;
$f$;
grant execute on function public.bsp_turno_reforco(text) to authenticated;
