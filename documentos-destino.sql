-- Barispol Workspace · para quem é cada documento (02-10-2026)
-- Pedido do Elmar, 02-10-2026: «sobre os comunicados, faça um filtro de quem
-- pode ver, tenho uns de médicos que não sei se convém colocar para todos».
-- Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode
-- correr-se mais do que uma vez. Corre-se depois de documentos.sql e de
-- emails-pausa.sql.
--
--   documentos.grupos  para quem é: os mesmos grupos das novidades
--                      (bsp_membro_nos_grupos): 'todos', uma área de
--                      bsp_area_chave ('clinica', 'enfermagem'...),
--                      'direccao-clinica', 'gestao' ou o id de uma pessoa.
--                      Por omissão, {todos}.
--   Leitura: quem está nos grupos, quem publica documentos e quem o publicou.
--   Fora de «todos»: sem publicação no Feed nem no #avisos (o texto chegava
--   a toda a equipa); a novidade e o aviso do telemóvel vão só aos grupos.

alter table public.documentos add column if not exists grupos text[] not null default array['todos'];

create or replace function public.bsp_eu_membro()
returns jsonb language sql stable security definer set search_path to 'public'
as $$
  select e from public.shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and e->>'id' = public.bsp_meu_id() limit 1
$$;
revoke all on function public.bsp_eu_membro() from public, anon;
grant execute on function public.bsp_eu_membro() to authenticated;

create or replace function public.bsp_ve_documento(p_grupos text[], p_publicado_por text)
returns boolean language sql stable security definer set search_path to 'public'
as $$
  select not public.bsp_e_socio() and (
       'todos' = any (coalesce(p_grupos, array['todos']))
    or p_publicado_por = public.bsp_meu_id()
    or public.bsp_publica_documentos()
    or public.bsp_membro_nos_grupos(public.bsp_eu_membro(), p_grupos))
$$;
revoke all on function public.bsp_ve_documento(text[], text) from public, anon;
grant execute on function public.bsp_ve_documento(text[], text) to authenticated;

alter policy documentos_ler on public.documentos using (public.bsp_ve_documento(grupos, publicado_por));

-- Documento novo: Feed e #avisos só quando é para todos; novidade só aos grupos.
create or replace function public.bsp_documentos_publicado()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  para_todos boolean := 'todos' = any (coalesce(new.grupos, array['todos']));
begin
  if new.substitui is not null then
    update public.documentos set arquivado = true where id = new.substitui;
  end if;
  if new.categoria = 'comunicado' and para_todos then
    insert into public.posts (user_id, type, title, body, cid)
    values (new.publicado_por, 'comunicado', new.titulo,
            coalesce(nullif(btrim(new.descricao), ''), 'Comunicado oficial publicado em Documentos.') || E'\n[documento:' || new.id || ']',
            'doc-' || new.id);
    insert into public.messages (conv_key, user_id, text, cid)
    values ('c-avisos', new.publicado_por,
            '📄 Comunicado: ' || new.titulo || coalesce(' (' || nullif(new.numero, '') || ')', '') || E'\n[documento:' || new.id || ']',
            'doc-' || new.id);
  end if;
  -- Menos e-mails (02-10-2026): o aviso vai nas novidades da manhã, no sino
  -- e no telemóvel (bsp_push_documento), só a quem o documento se destina.
  insert into public.novidades (titulo, texto, grupos, destino)
  values ('Documento novo' || case when new.leitura_obrigatoria then ' (leitura obrigatória)' else '' end || ': ' || new.titulo,
          'Publicado em Documentos' || coalesce(' com o n.º ' || nullif(new.numero, ''), '') || '. Abra-o no Workspace'
          || case when new.leitura_obrigatoria then ' e carregue em «Li e tomei conhecimento».' else '.' end,
          coalesce(new.grupos, array['todos']), 'documentos');
  update public.documentos set aviso_enviado_em = now() where id = new.id;
  return new;
end $function$;

create or replace function public.bsp_push_documento()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  para jsonb;
begin
  if coalesce(new.arquivado, false) then return null; end if;
  if 'todos' = any (coalesce(new.grupos, array['todos'])) then
    para := to_jsonb('todos'::text);
  else
    select coalesce(jsonb_agg(e->>'id'), '[]'::jsonb) into para
      from public.shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1 and public.bsp_membro_nos_grupos(e, new.grupos);
  end if;
  perform public.bsp_push_post(jsonb_build_object('para', para, 'exceto', new.publicado_por,
    'titulo', 'Documento novo' || case when new.leitura_obrigatoria then ' · leitura obrigatória' else '' end,
    'corpo', left(coalesce(new.titulo, ''), 160), 'url', '#/documentos', 'tag', 'documento-' || new.id));
  return null;
end $function$;

notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- Por camada ou cargo, e não por pessoa nem por área (Elmar, 02-10-2026:
-- «por camada ou cargo não por pessoa»). Valores de `grupos`:
--   'todos' · 'camada:<nome da camada>' · 'cargo:<família>'
-- As famílias de cargo saem do texto do cargo (campo role da equipa), com as
-- mesmas expressões que BSP_DOC_CARGOS no workspace.html.
-- A novidade e o aviso do telemóvel levam a lista de ids já calculada.

create or replace function public.bsp_cargo_grupos(p_cargo text)
returns text[] language sql immutable set search_path to 'public'
as $$
  select array_remove(array[
    case when p_cargo ~* '(m[eé]dic|director cl[ií]nico|pediatra)' then 'cargo:medicos' end,
    case when p_cargo ~* 'radiolog' then 'cargo:radiologistas' end,
    case when p_cargo ~* 'enferm' then 'cargo:enfermeiros' end,
    case when p_cargo ~* '(t[eé]cnic|analista)' then 'cargo:tecnicos' end,
    case when p_cargo ~* '(chefe|supervisor|director)' then 'cargo:chefes' end,
    case when p_cargo ~* 'recep' then 'cargo:recepcao' end,
    case when p_cargo ~* '(administrativ|\mrh\M|recursos humanos)' then 'cargo:administrativos' end,
    case when p_cargo ~* 'motorista' then 'cargo:motorista' end
  ], null)
$$;

create or replace function public.bsp_doc_no_grupo(membro jsonb, p_grupos text[])
returns boolean language sql stable set search_path to 'public'
as $$
  select membro is not null and not public.bsp_membro_e_socio(membro) and (
       'todos' = any (coalesce(p_grupos, array['todos']))
    or ('camada:' || coalesce(membro->>'accessLevel', '')) = any (p_grupos)
    or public.bsp_cargo_grupos(membro->>'role') && p_grupos)
$$;

create or replace function public.bsp_doc_destinatarios(p_grupos text[])
returns text[] language sql stable security definer set search_path to 'public'
as $$
  select coalesce(array_agg(e->>'id'), array[]::text[])
    from public.shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and public.bsp_doc_no_grupo(e, p_grupos)
$$;

create or replace function public.bsp_ve_documento(p_grupos text[], p_publicado_por text)
returns boolean language sql stable security definer set search_path to 'public'
as $$
  select not public.bsp_e_socio() and (
       'todos' = any (coalesce(p_grupos, array['todos']))
    or p_publicado_por = public.bsp_meu_id()
    or public.bsp_publica_documentos()
    or public.bsp_doc_no_grupo(public.bsp_eu_membro(), p_grupos))
$$;

create or replace function public.bsp_documentos_publicado()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  para_todos boolean := 'todos' = any (coalesce(new.grupos, array['todos']));
begin
  if new.substitui is not null then
    update public.documentos set arquivado = true where id = new.substitui;
  end if;
  if new.categoria = 'comunicado' and para_todos then
    insert into public.posts (user_id, type, title, body, cid)
    values (new.publicado_por, 'comunicado', new.titulo,
            coalesce(nullif(btrim(new.descricao), ''), 'Comunicado oficial publicado em Documentos.') || E'\n[documento:' || new.id || ']',
            'doc-' || new.id);
    insert into public.messages (conv_key, user_id, text, cid)
    values ('c-avisos', new.publicado_por,
            '📄 Comunicado: ' || new.titulo || coalesce(' (' || nullif(new.numero, '') || ')', '') || E'\n[documento:' || new.id || ']',
            'doc-' || new.id);
  end if;
  insert into public.novidades (titulo, texto, grupos, destino)
  values ('Documento novo' || case when new.leitura_obrigatoria then ' (leitura obrigatória)' else '' end || ': ' || new.titulo,
          'Publicado em Documentos' || coalesce(' com o n.º ' || nullif(new.numero, ''), '') || '. Abra-o no Workspace'
          || case when new.leitura_obrigatoria then ' e carregue em «Li e tomei conhecimento».' else '.' end,
          case when para_todos then array['todos'] else public.bsp_doc_destinatarios(new.grupos) end, 'documentos');
  update public.documentos set aviso_enviado_em = now() where id = new.id;
  return new;
end $function$;

create or replace function public.bsp_push_documento()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if coalesce(new.arquivado, false) then return null; end if;
  perform public.bsp_push_post(jsonb_build_object(
    'para', case when 'todos' = any (coalesce(new.grupos, array['todos'])) then to_jsonb('todos'::text)
                 else to_jsonb(public.bsp_doc_destinatarios(new.grupos)) end,
    'exceto', new.publicado_por,
    'titulo', 'Documento novo' || case when new.leitura_obrigatoria then ' · leitura obrigatória' else '' end,
    'corpo', left(coalesce(new.titulo, ''), 160), 'url', '#/documentos', 'tag', 'documento-' || new.id));
  return null;
end $function$;

notify pgrst, 'reload schema';
