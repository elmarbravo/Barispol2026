-- Férias e ausências com duas aprovações (06-10-2026, Elmar: «os pedidos de
-- férias não chegaram ao Dr. Osvaldo; todos os chefes das áreas clínicas devem
-- ter duas aprovações, 1.º o Dr. Osvaldo, depois a Arlete (RH). Todos os
-- técnicos devem ter aprovação do superior hierárquico e depois a Arlete (RH)»).
-- RI-6.1: o plano de férias é aprovado pelo superior.
--
-- Porque não chegava: o aviso do pedido ia para o «superior» da pessoa e para o
-- chefe da área. Os chefes das áreas clínicas não tinham «superior» e são eles
-- próprios o chefe da área, por isso o pedido deles só ia para a gestão (sino),
-- e a Arlete podia aprovar logo. Também não havia aviso no telemóvel.
--
-- Agora:
--   1.º passo: o superior hierárquico (bsp_aprovador_de), guardado no pedido
--      (superior_id) quando é feito:
--        · o campo «superior» da pessoa na equipa, se existir;
--        · senão, o chefe da área (bsp_escalas_responsaveis);
--        · os chefes das áreas clínicas e os radiologistas passam a ter o
--          Dr. Osvaldo (u14) como «superior».
--      Se o superior for a própria RH, ou não houver, salta-se este passo.
--   2.º passo: os RH (Arlete, u2) dão a aprovação final.
--   Estados: Pedido → Aprovado (ou Recusado em qualquer passo, ou Cancelado
--   por quem pediu). O 1.º passo dado fica em superior_ok_por/superior_ok_em
--   (o estado continua «Pedido»; a regra ausencias_estado_check não muda). No
--   ecrã aparece «Aprovado pelo superior».
--   O Director Geral (u1) pode substituir em qualquer dos passos.
-- Cada passo avisa no sino, no telemóvel e na janela de avisos importantes
-- (etiqueta ferias-<id>).

set lock_timeout = '5s';
alter table public.ausencias add column if not exists superior_id text,
  add column if not exists superior_ok_por text, add column if not exists superior_ok_em timestamptz;

-- Chefes das áreas clínicas e radiologistas: o superior é o Director Clínico.
update public.shared_state s
   set team = (select jsonb_agg(case
                 when e->>'id' in ('u9', 'u17', 'u13', 'u1790684896306', 'u1790255566296')
                      and coalesce(e->>'superior', '') = '' then e || '{"superior": "u14"}'::jsonb
                 else e end order by o)
                 from jsonb_array_elements(s.team) with ordinality t(e, o)),
       updated_at = now()
 where s.id = 1;

create or replace function public.bsp_ferias_rh()
returns text language sql immutable as $f$ select 'u2'::text $f$;

-- Quem dá o 1.º passo (null = vai direito aos RH).
create or replace function public.bsp_aprovador_de(p_user text)
returns text language sql stable security definer set search_path to 'public'
as $f$
  select case when x is null or x in (p_user, public.bsp_ferias_rh()) then null else x end
  from (select coalesce(
          (select nullif(e->>'superior', '') from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
            where s.id = 1 and e->>'id' = p_user and e->>'superior' is distinct from p_user),
          (select c.rid from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e,
                  public.bsp_escalas_responsaveis() r, unnest(r.ids) c(rid)
            where s.id = 1 and e->>'id' = p_user and r.area = public.bsp_area_chave(e->>'dept') and c.rid <> p_user
            -- o chefe da própria área antes do Director Clínico, que também
            -- aparece como responsável das áreas cujo chefe tem nele o superior
            order by (c.rid = 'u14'), c.rid limit 1)) x) q
$f$;
revoke all on function public.bsp_aprovador_de(text) from public, anon;
grant execute on function public.bsp_aprovador_de(text) to authenticated;

-- Para o ecrã: quem aprova os meus pedidos.
create or replace function public.bsp_ferias_aprovadores()
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  select jsonb_build_object('superior', public.bsp_aprovador_de(public.bsp_meu_id()), 'rh', public.bsp_ferias_rh())
$f$;
revoke all on function public.bsp_ferias_aprovadores() from public, anon;
grant execute on function public.bsp_ferias_aprovadores() to authenticated;

-- O superior fica gravado no pedido.
create or replace function public.bsp_ausencia_superior()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
begin
  new.superior_id := public.bsp_aprovador_de(new.user_id);
  return new;
end $f$;
revoke all on function public.bsp_ausencia_superior() from public, anon, authenticated;
-- Sem «drop»: a ferramenta do servidor fica à espera de confirmação.
create or replace trigger bsp_ausencia_superior before insert on public.ausencias
  for each row execute function public.bsp_ausencia_superior();

-- Aviso a quem tem de decidir: sino, telemóvel e janela de avisos.
create or replace function public.bsp_ausencia_avisar(a public.ausencias, p_para text, p_titulo text, p_texto text)
returns void language plpgsql security definer set search_path to 'public'
as $f$
begin
  insert into public.novidades (titulo, texto, grupos, destino)
  values (p_titulo, p_texto, array[p_para], 'directory');
  perform public.bsp_push_post(jsonb_build_object('para', jsonb_build_array(p_para), 'titulo', p_titulo,
    'corpo', p_texto, 'url', '#directory', 'tag', 'ferias-' || a.id));
exception when others then
  raise warning 'bsp_ausencia_avisar: %', sqlerrm;
end $f$;
revoke all on function public.bsp_ausencia_avisar(public.ausencias, text, text, text) from public, anon, authenticated;

create or replace function public.bsp_ausencia_pedida()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare para text := coalesce(new.superior_id, public.bsp_ferias_rh());
begin
  if para = new.user_id then para := 'u1'; end if;
  perform public.bsp_ausencia_avisar(new, para,
    'Pedido de ' || lower(new.tipo) || ': ' || public.bsp_nome_de(new.user_id),
    public.bsp_nome_de(new.user_id) || ' pede ' || lower(new.tipo) || ' de ' || to_char(new.inicio, 'DD-MM-YYYY') || ' a ' || to_char(new.fim, 'DD-MM-YYYY')
    || case when new.superior_id is not null then '. 1.º passo: aprovação do superior. Depois decidem os RH.'
            else '. Aprovação dos RH.' end
    || ' Equipa → Férias e ausências.');
  return new;
end $f$;

create or replace function public.bsp_ausencia_decidir(p_id bigint, p_estado text, p_motivo text default '')
returns void language plpgsql security definer set search_path to 'public'
as $f$
declare
  a public.ausencias;
  eu text := public.bsp_meu_id();
  rh text := public.bsp_ferias_rh();
  passo int;
begin
  select * into a from public.ausencias where id = p_id for update;
  if not found then raise exception 'Pedido não encontrado.'; end if;

  if p_estado = 'Cancelado' then
    if a.user_id <> eu and not public.bsp_chefe_de(a.user_id) then raise exception 'Só quem pediu cancela.'; end if;
    update public.ausencias set estado = 'Cancelado', decidido_por = eu, decidido_em = now() where id = p_id;
    return;
  end if;
  if p_estado not in ('Aprovado', 'Recusado') then raise exception 'Estado inválido.'; end if;
  if a.user_id = eu then raise exception 'Não pode decidir o seu próprio pedido.'; end if;

  if a.estado = 'Pedido' and a.superior_id is not null and a.superior_ok_em is null then passo := 1;
  elsif a.estado = 'Pedido' then passo := 2;
  else raise exception 'Este pedido já foi decidido.'; end if;

  if passo = 1 and eu not in (a.superior_id, 'u1') then
    raise exception 'Falta primeiro a aprovação de %.', public.bsp_nome_de(a.superior_id);
  end if;
  if passo = 2 and eu not in (rh, 'u1') then
    raise exception 'A aprovação final é dos RH (%).', public.bsp_nome_de(rh);
  end if;

  if passo = 1 and p_estado = 'Aprovado' then
    update public.ausencias set superior_ok_por = eu, superior_ok_em = now()
     where id = p_id;
    perform public.bsp_ausencia_avisar(a, rh,
      'Férias para aprovar: ' || public.bsp_nome_de(a.user_id),
      public.bsp_nome_de(eu) || ' aprovou o pedido de ' || lower(a.tipo) || ' de ' || public.bsp_nome_de(a.user_id)
      || ' (' || to_char(a.inicio, 'DD-MM-YYYY') || ' a ' || to_char(a.fim, 'DD-MM-YYYY') || '). Falta a aprovação dos RH.');
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('O seu pedido de ' || lower(a.tipo) || ' passou o 1.º passo',
            public.bsp_nome_de(eu) || ' aprovou. Falta a aprovação dos RH.', array[a.user_id], 'directory');
    return;
  end if;

  update public.ausencias set estado = p_estado, decidido_por = eu, decidido_em = now(), motivo = coalesce(p_motivo, '')
   where id = p_id;
  insert into public.novidades (titulo, texto, grupos, destino)
  values ('O seu pedido de ' || lower(a.tipo) || ' foi ' || lower(p_estado),
          public.bsp_nome_de(eu) || ' ' || lower(p_estado) || ' o pedido de ' || to_char(a.inicio, 'DD-MM-YYYY') || ' a ' || to_char(a.fim, 'DD-MM-YYYY') || '.'
          || case when coalesce(p_motivo, '') <> '' then ' Motivo: ' || p_motivo else '' end,
          array[a.user_id], 'directory');
  -- Recusa no 2.º passo: o superior que aprovou também fica a saber.
  if p_estado = 'Recusado' and a.superior_ok_por is not null and a.superior_ok_por <> eu then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Pedido recusado pelos RH: ' || public.bsp_nome_de(a.user_id), coalesce(nullif(p_motivo, ''), 'Sem motivo.'),
            array[a.superior_ok_por], 'directory');
  end if;
end $f$;
revoke all on function public.bsp_ausencia_decidir(bigint, text, text) from public, anon;
grant execute on function public.bsp_ausencia_decidir(bigint, text, text) to authenticated;

-- O superior do pedido vê-o sempre.
alter policy ausencias_ler on public.ausencias
  using (user_id = public.bsp_meu_id() or superior_id = public.bsp_meu_id() or public.bsp_chefe_de(user_id));

-- Janela de avisos importantes: os pedidos de férias contam.
do $$ declare d text; n text;
begin
  d := pg_get_functiondef('public.bsp_alerta_do_push(jsonb)'::regprocedure);
  if position('ferias-' in d) > 0 then return; end if;
  n := replace(d, $x$when tag like 'tarefa-%' then 'tarefa'$x$, $x$when tag like 'tarefa-%' or tag like 'ferias-%' then 'tarefa'$x$);
  if n = d then raise notice 'bsp_alerta_do_push: texto esperado não encontrado';
  else execute n; end if;
end $$;

notify pgrst, 'reload schema';
