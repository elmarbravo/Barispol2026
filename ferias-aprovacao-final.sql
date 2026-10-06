-- Aprovação final das férias por pessoa (06-10-2026, Elmar: «Juliana aprovada
-- por Arlete e depois ir a mim»). Corre-se depois de ferias-duas-aprovacoes.sql.
--
-- O 2.º passo deixa de ser sempre os RH: cada pessoa pode ter na equipa o campo
-- «aprovaFerias» (id de quem dá a aprovação final). Sem ele, são os RH (u2).
-- Juliana (u12, Recepção): 1.º passo Arlete (superior = u2), 2.º passo Elmar.
-- O pedido guarda final_id quando é feito, como o superior_id.
-- Sem «drop» (a ferramenta do servidor fica à espera de confirmação).

set lock_timeout = '5s';
alter table public.ausencias add column if not exists final_id text;

update public.shared_state s
   set team = (select jsonb_agg(case when e->>'id' = 'u12'
                 then e || '{"superior": "u2", "aprovaFerias": "u1"}'::jsonb else e end order by o)
                 from jsonb_array_elements(s.team) with ordinality t(e, o)),
       updated_at = now()
 where s.id = 1;

-- Quem dá a aprovação final (2.º passo).
create or replace function public.bsp_aprovador_final_de(p_user text)
returns text language sql stable security definer set search_path to 'public'
as $f$
  select coalesce((select nullif(e->>'aprovaFerias', '') from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
                    where s.id = 1 and e->>'id' = p_user and e->>'aprovaFerias' is distinct from p_user),
                  public.bsp_ferias_rh())
$f$;
revoke all on function public.bsp_aprovador_final_de(text) from public, anon;
grant execute on function public.bsp_aprovador_final_de(text) to authenticated;

-- 1.º passo: salta-se quando coincide com quem dá a aprovação final.
create or replace function public.bsp_aprovador_de(p_user text)
returns text language sql stable security definer set search_path to 'public'
as $f$
  select case when x is null or x in (p_user, public.bsp_aprovador_final_de(p_user)) then null else x end
  from (select coalesce(
          (select nullif(e->>'superior', '') from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
            where s.id = 1 and e->>'id' = p_user and e->>'superior' is distinct from p_user),
          (select c.rid from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e,
                  public.bsp_escalas_responsaveis() r, unnest(r.ids) c(rid)
            where s.id = 1 and e->>'id' = p_user and r.area = public.bsp_area_chave(e->>'dept') and c.rid <> p_user
            order by (c.rid = 'u14'), c.rid limit 1)) x) q
$f$;

create or replace function public.bsp_ferias_aprovadores()
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  select jsonb_build_object('superior', public.bsp_aprovador_de(public.bsp_meu_id()),
                            'final', public.bsp_aprovador_final_de(public.bsp_meu_id()),
                            'rh', public.bsp_ferias_rh())
$f$;

create or replace function public.bsp_ausencia_superior()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
begin
  new.superior_id := public.bsp_aprovador_de(new.user_id);
  new.final_id := public.bsp_aprovador_final_de(new.user_id);
  return new;
end $f$;

create or replace function public.bsp_ausencia_pedida()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare para text := coalesce(new.superior_id, new.final_id, public.bsp_ferias_rh());
begin
  if para = new.user_id then para := 'u1'; end if;
  perform public.bsp_ausencia_avisar(new, para,
    'Pedido de ' || lower(new.tipo) || ': ' || public.bsp_nome_de(new.user_id),
    public.bsp_nome_de(new.user_id) || ' pede ' || lower(new.tipo) || ' de ' || to_char(new.inicio, 'DD-MM-YYYY') || ' a ' || to_char(new.fim, 'DD-MM-YYYY')
    || case when new.superior_id is not null
            then '. 1.º passo: a sua aprovação. Depois decide ' || public.bsp_nome_de(coalesce(new.final_id, public.bsp_ferias_rh())) || '.'
            else '. Aprovação final.' end
    || ' Equipa → Férias e ausências.');
  return new;
end $f$;

create or replace function public.bsp_ausencia_decidir(p_id bigint, p_estado text, p_motivo text default '')
returns void language plpgsql security definer set search_path to 'public'
as $f$
declare
  a public.ausencias;
  eu text := public.bsp_meu_id();
  fin text;
  passo int;
begin
  select * into a from public.ausencias where id = p_id for update;
  if not found then raise exception 'Pedido não encontrado.'; end if;
  fin := coalesce(a.final_id, public.bsp_ferias_rh());

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
  if passo = 2 and eu not in (fin, 'u1') then
    raise exception 'A aprovação final é de %.', public.bsp_nome_de(fin);
  end if;

  if passo = 1 and p_estado = 'Aprovado' then
    update public.ausencias set superior_ok_por = eu, superior_ok_em = now() where id = p_id;
    perform public.bsp_ausencia_avisar(a, fin,
      'Férias para aprovar: ' || public.bsp_nome_de(a.user_id),
      public.bsp_nome_de(eu) || ' aprovou o pedido de ' || lower(a.tipo) || ' de ' || public.bsp_nome_de(a.user_id)
      || ' (' || to_char(a.inicio, 'DD-MM-YYYY') || ' a ' || to_char(a.fim, 'DD-MM-YYYY') || '). Falta a sua aprovação final.');
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('O seu pedido de ' || lower(a.tipo) || ' passou o 1.º passo',
            public.bsp_nome_de(eu) || ' aprovou. Falta a aprovação de ' || public.bsp_nome_de(fin) || '.', array[a.user_id], 'directory');
    return;
  end if;

  update public.ausencias set estado = p_estado, decidido_por = eu, decidido_em = now(), motivo = coalesce(p_motivo, '')
   where id = p_id;
  insert into public.novidades (titulo, texto, grupos, destino)
  values ('O seu pedido de ' || lower(a.tipo) || ' foi ' || lower(p_estado),
          public.bsp_nome_de(eu) || ' ' || lower(p_estado) || ' o pedido de ' || to_char(a.inicio, 'DD-MM-YYYY') || ' a ' || to_char(a.fim, 'DD-MM-YYYY') || '.'
          || case when coalesce(p_motivo, '') <> '' then ' Motivo: ' || p_motivo else '' end,
          array[a.user_id], 'directory');
  if p_estado = 'Recusado' and a.superior_ok_por is not null and a.superior_ok_por <> eu then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Pedido recusado: ' || public.bsp_nome_de(a.user_id), public.bsp_nome_de(eu) || ' recusou. ' || coalesce(nullif(p_motivo, ''), 'Sem motivo.'),
            array[a.superior_ok_por], 'directory');
  end if;
end $f$;

-- Quem dá a aprovação final também lê o pedido.
alter policy ausencias_ler on public.ausencias
  using (user_id = public.bsp_meu_id() or superior_id = public.bsp_meu_id() or final_id = public.bsp_meu_id()
         or public.bsp_chefe_de(user_id));

-- Pedidos antigos ainda por decidir ficam com os RH como aprovação final.
update public.ausencias set final_id = public.bsp_aprovador_final_de(user_id) where estado = 'Pedido' and final_id is null;

notify pgrst, 'reload schema';
