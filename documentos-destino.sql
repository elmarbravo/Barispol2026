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
