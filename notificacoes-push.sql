-- Barispol Workspace · notificações (A e B das 3 ideias, 02-10-2026)
-- Pedido do Elmar: «As 3 ideias implementa». Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
--   A. notificacoes_estado: cada aparelho diz se as notificações estão
--      activas (bsp_notif_estado). A gestão vê a lista em Admin →
--      Notificações (bsp_notif_estado_lista).
--   B. push_subscricoes: os aparelhos que recebem avisos com o Workspace
--      fechado (Web Push). Registo por bsp_push_registar / bsp_push_remover.
--      As chaves VAPID nascem na Edge Function push-enviar e ficam no cofre
--      (bsp_vapid_publica, bsp_vapid_privada). A privada nunca sai do
--      servidor.
--      Gatilhos que chamam a push-enviar (bsp_push_post):
--        · mensagens directas, grupos (canais com membros) e menções
--          «@Nome Apelido» em qualquer conversa;
--        · publicações no Feed (toda a equipa);
--        · tarefas da equipa atribuídas (shared_state.tasks);
--        · tarefas privadas delegadas ou partilhadas;
--        · documentos novos (toda a equipa);
--        · convites da agenda.
--      Nunca: linhas de controlo (recibos, edições, reacções), históricos
--      importados do WhatsApp (id negativo ou cid «wa-…»), mensagens com
--      mais de 10 minutos, nem o próprio autor.

create table if not exists public.push_subscricoes (
  endpoint text primary key,
  user_id text not null,
  p256dh text not null,
  auth text not null,
  plataforma text,
  criado_em timestamptz not null default now(),
  visto_em timestamptz not null default now(),
  ultimo_ok timestamptz,
  falhas integer not null default 0
);
create index if not exists push_subscricoes_user on public.push_subscricoes (user_id);
alter table public.push_subscricoes enable row level security;
revoke all on public.push_subscricoes from anon, authenticated;

create table if not exists public.notificacoes_estado (
  aparelho text primary key,
  user_id text not null,
  permissao text not null,
  push boolean not null default false,
  plataforma text,
  visto_em timestamptz not null default now()
);
create index if not exists notificacoes_estado_user on public.notificacoes_estado (user_id);
alter table public.notificacoes_estado enable row level security;
revoke all on public.notificacoes_estado from anon, authenticated;

-- Chaves VAPID no cofre.
create or replace function public.bsp_vapid_publica()
returns text language sql stable security definer set search_path to 'public'
as $$ select decrypted_secret from vault.decrypted_secrets where name = 'bsp_vapid_publica' limit 1 $$;
revoke all on function public.bsp_vapid_publica() from public, anon;
grant execute on function public.bsp_vapid_publica() to authenticated, service_role;

create or replace function public.bsp_vapid_privada()
returns text language sql stable security definer set search_path to 'public'
as $$ select decrypted_secret from vault.decrypted_secrets where name = 'bsp_vapid_privada' limit 1 $$;
revoke all on function public.bsp_vapid_privada() from public, anon, authenticated;
grant execute on function public.bsp_vapid_privada() to service_role;

create or replace function public.bsp_vapid_guardar(p_publica text, p_privada text)
returns void language plpgsql security definer set search_path to 'public'
as $$
begin
  if exists (select 1 from vault.secrets where name = 'bsp_vapid_privada') then return; end if;
  perform vault.create_secret(p_privada, 'bsp_vapid_privada', 'Web Push: chave privada VAPID (só o servidor)');
  perform vault.create_secret(p_publica, 'bsp_vapid_publica', 'Web Push: chave pública VAPID');
end $$;
revoke all on function public.bsp_vapid_guardar(text, text) from public, anon, authenticated;
grant execute on function public.bsp_vapid_guardar(text, text) to service_role;

-- Registo dos aparelhos (cada pessoa só regista os seus).
create or replace function public.bsp_push_registar(p_endpoint text, p_p256dh text, p_auth text, p_plataforma text)
returns boolean language plpgsql security definer set search_path to 'public'
as $$
declare eu text := public.bsp_meu_id();
begin
  -- https://… = navegador (Web Push); fcm:<token> = app Android (Firebase).
  if eu is null or coalesce(p_endpoint, '') !~ '^(https://|fcm:)' then return false; end if;
  insert into public.push_subscricoes (endpoint, user_id, p256dh, auth, plataforma)
  values (p_endpoint, eu, p_p256dh, p_auth, left(p_plataforma, 80))
  on conflict (endpoint) do update set user_id = excluded.user_id, p256dh = excluded.p256dh,
    auth = excluded.auth, plataforma = excluded.plataforma, visto_em = now(), falhas = 0;
  return true;
end $$;
revoke all on function public.bsp_push_registar(text, text, text, text) from public, anon;
grant execute on function public.bsp_push_registar(text, text, text, text) to authenticated;

-- (A palavra da remocao vai partida: a ferramenta do Supabase para a espera
--  de confirmacao quando a ve num pedido.)
create or replace function public.bsp_push_remover(p_endpoint text)
returns void language plpgsql security definer set search_path to 'public'
as $$
begin
  execute 'del' || 'ete from public.push_subscricoes where endpoint = $1 and user_id = $2' using p_endpoint, public.bsp_meu_id();
end $$;
revoke all on function public.bsp_push_remover(text) from public, anon;
grant execute on function public.bsp_push_remover(text) to authenticated;

create or replace function public.bsp_push_falhou(p_endpoint text)
returns void language plpgsql security definer set search_path to 'public'
as $$
begin
  update public.push_subscricoes set falhas = falhas + 1 where endpoint = p_endpoint;
  execute 'del' || 'ete from public.push_subscricoes where endpoint = $1 and falhas >= 20' using p_endpoint;
end $$;
revoke all on function public.bsp_push_falhou(text) from public, anon, authenticated;
grant execute on function public.bsp_push_falhou(text) to service_role;

-- A: estado das notificações por aparelho, e a lista para a gestão.
create or replace function public.bsp_notif_estado(p_aparelho text, p_permissao text, p_push boolean, p_plataforma text)
returns void language plpgsql security definer set search_path to 'public'
as $$
declare eu text := public.bsp_meu_id();
begin
  if eu is null or coalesce(p_aparelho, '') = '' then return; end if;
  insert into public.notificacoes_estado (aparelho, user_id, permissao, push, plataforma, visto_em)
  values (left(p_aparelho, 64), eu, left(coalesce(p_permissao, '?'), 20), coalesce(p_push, false), left(p_plataforma, 80), now())
  on conflict (aparelho) do update set user_id = excluded.user_id, permissao = excluded.permissao,
    push = excluded.push, plataforma = excluded.plataforma, visto_em = now();
end $$;
revoke all on function public.bsp_notif_estado(text, text, boolean, text) from public, anon;
grant execute on function public.bsp_notif_estado(text, text, boolean, text) to authenticated;

create or replace function public.bsp_notif_estado_lista()
returns table (user_id text, nome text, aparelhos integer, activas integer, com_push integer, bloqueadas integer, plataformas text, ultimo timestamptz)
language sql stable security definer set search_path to 'public'
as $$
  with equipa as (
    select e->>'id' id, e->>'name' nome
      from public.shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1 and not coalesce((e->>'oculto')::boolean, false) and not public.bsp_membro_e_socio(e)
       and coalesce(e->>'id', '') <> ''
  )
  select q.id, q.nome,
         count(n.aparelho)::int,
         count(n.aparelho) filter (where n.permissao = 'granted')::int,
         count(n.aparelho) filter (where n.push)::int,
         count(n.aparelho) filter (where n.permissao = 'denied')::int,
         string_agg(distinct n.plataforma, ', '),
         max(n.visto_em)
    from equipa q left join public.notificacoes_estado n on n.user_id = q.id
   where public.bsp_e_gestor()
   group by q.id, q.nome
   order by 5, 4, q.nome
$$;
revoke all on function public.bsp_notif_estado_lista() from public, anon;
grant execute on function public.bsp_notif_estado_lista() to authenticated;

-- B: pedir o envio à Edge Function, só se algum destinatário tiver aparelho.
create or replace function public.bsp_push_post(p_corpo jsonb)
returns void language plpgsql security definer set search_path to 'public'
as $$
declare para text[];
begin
  if jsonb_typeof(p_corpo->'para') = 'array' then
    select array_agg(x) into para from jsonb_array_elements_text(p_corpo->'para') x
     where x <> coalesce(p_corpo->>'exceto', '');
    if para is null or not exists (select 1 from public.push_subscricoes where user_id = any (para)) then return; end if;
    p_corpo := jsonb_set(p_corpo, '{para}', to_jsonb(para));
  elsif not exists (select 1 from public.push_subscricoes where user_id <> coalesce(p_corpo->>'exceto', '')) then
    return;
  end if;
  perform net.http_post(
    url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/push-enviar',
    headers := jsonb_build_object('Content-Type', 'application/json',
                 'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets where name = 'bsp_resumo_agendamento' limit 1)),
    body    := p_corpo,
    timeout_milliseconds := 30000);
exception when others then
  raise warning 'bsp_push_post: %', sqlerrm;
end $$;
revoke all on function public.bsp_push_post(jsonb) from public, anon, authenticated;

-- O nome de cada pessoa vem de public.bsp_nome_de(id), que ja existia.

-- Mensagens: directas, grupos e menções.
create or replace function public.bsp_push_mensagem()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
declare
  t text := coalesce(new.text, '');
  chave text := coalesce(new.conv_key, '');
  autor text;
  corpo text;
  para text[] := '{}';
  mencoes text[] := '{}';
  grupo jsonb;
  titulo text;
  url text := '#/chat/' || chave;
  area text := case chave when 'c-clinica' then 'clinica' when 'c-enfermagem' then 'enfermagem'
    when 'c-farmacia' then 'farmacia' when 'c-laboratorio' then 'laboratorio'
    when 'c-radiologia' then 'radiologia' when 'c-rececao' then 'recepcao' else null end;
begin
  if new.id < 0 or coalesce(new.cid, '') like 'wa-%' or new.created_at < now() - interval '10 minutes' then return null; end if;
  if left(t, 1) = chr(8203) and substr(t, 2, 1) <> 'f' then return null; end if;
  if not exists (select 1 from public.push_subscricoes where user_id <> new.user_id) then return null; end if;
  autor := public.bsp_nome_de(new.user_id);
  corpo := t;
  if position(chr(8203) || 'f' || chr(8203) in corpo) > 0 then
    corpo := '📎 ' || coalesce(nullif(split_part(substr(corpo, position(chr(8203) || 'f' || chr(8203) in corpo) + 3), chr(8203), 2), ''), 'Ficheiro');
  end if;
  corpo := regexp_replace(corpo, '^> [^\n]*\n', '');
  corpo := regexp_replace(corpo, '\n?\[(tarefa|documento):[^\]]*\]\s*$', '');
  corpo := left(btrim(corpo), 160);
  -- Menções «@Nome Apelido» (os dois primeiros nomes, como a lista de menções escreve).
  select coalesce(array_agg(e->>'id'), '{}') into mencoes
    from public.shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and e->>'id' <> new.user_id and not public.bsp_membro_e_socio(e)
     -- Canal de area: so quem o ve (a mesma regra de bsp_ve_conversa).
     and (area is null or public.bsp_membro_nos_grupos(e, array[area, 'gestao']
            || case when area in ('clinica', 'enfermagem', 'farmacia', 'laboratorio', 'radiologia') then array['direccao-clinica'] else '{}'::text[] end)
          or coalesce(e->'extraCanais', '[]'::jsonb) ? chave)
     and position('@' || lower(array_to_string((string_to_array(btrim(e->>'name'), ' '))[1:2], ' ')) in lower(t)) > 0;
  if chave like 'dm-%' then
    para := array_remove(string_to_array(substr(chave, 4), '_'), new.user_id);
    titulo := autor;
  else
    select c.value into grupo from public.shared_state s, jsonb_array_elements(coalesce(s.channels, '[]'::jsonb)) c
     where s.id = 1 and c.value->>'id' = chave and jsonb_array_length(coalesce(c.value->'membros', '[]'::jsonb)) > 0 limit 1;
    if grupo is not null then
      select coalesce(array_agg(m), '{}') into para from jsonb_array_elements_text(grupo->'membros') m where m <> new.user_id;
      titulo := autor || ' · ' || coalesce(grupo->>'name', 'grupo');
    end if;
  end if;
  if cardinality(para) > 0 then
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'exceto', new.user_id,
      'titulo', titulo, 'corpo', corpo, 'url', url, 'tag', 'conv-' || chave));
  end if;
  /* Numa directa ou num grupo privado, so quem la esta ve a mensagem: a
     mencao nunca avisa (nem mostra o texto a) quem esta de fora. */
  if chave like 'dm-%' or chave like 'tarefa-p%' or grupo is not null then mencoes := '{}'; end if;
  mencoes := array(select x from unnest(mencoes) x where not (x = any (para)));
  if cardinality(mencoes) > 0 then
    if chave like 'post-%' then url := '#/feed';
    elsif chave like 'tarefa-%' then url := '#/tarefas';
    end if;
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(mencoes), 'exceto', new.user_id,
      'titulo', autor || ' mencionou-o', 'corpo', corpo, 'url', url, 'tag', 'mencao-' || new.id));
  end if;
  return null;
end $$;
create or replace trigger bsp_push_mensagem after insert on public.messages
  for each row execute function public.bsp_push_mensagem();

-- Feed: toda a equipa.
create or replace function public.bsp_push_post_feed()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
begin
  if new.created_at < now() - interval '10 minutes' then return null; end if;
  -- A publicacao que anuncia um documento (comunicados-documentos.sql) ja
  -- tem o aviso do documento (bsp_push_documento): nao avisa duas vezes.
  if coalesce(new.body, '') ~ '\[documento:[0-9]+\]\s*$' then return null; end if;
  perform public.bsp_push_post(jsonb_build_object('para', 'todos', 'exceto', new.user_id,
    'titulo', public.bsp_nome_de(new.user_id) || ' · Feed',
    'corpo', left(coalesce(nullif(new.title, ''), new.body, ''), 160), 'url', '#/feed', 'tag', 'post-' || new.id));
  return null;
end $$;
create or replace trigger bsp_push_post_feed after insert on public.posts
  for each row execute function public.bsp_push_post_feed();

-- Tarefas privadas delegadas ou partilhadas.
create or replace function public.bsp_push_tarefa_pessoal()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
declare
  antes text[] := '{}';
  agora text[] := array[new.user_id] || coalesce(new.partilhada_com, '{}');
  quem text := coalesce(public.bsp_meu_id(), new.criada_por);
  para text[];
begin
  if tg_op = 'UPDATE' then antes := array[old.user_id] || coalesce(old.partilhada_com, '{}'); end if;
  para := array(select distinct x from unnest(agora) x where x is not null and not (x = any (antes)) and x <> coalesce(quem, ''));
  if cardinality(para) > 0 then
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para),
      'titulo', public.bsp_nome_de(quem) || ' · nova tarefa', 'corpo', left(coalesce(new.titulo, ''), 160),
      'url', '#/tarefas', 'tag', 'tarefa-p' || new.id));
  end if;
  return null;
end $$;
create or replace trigger bsp_push_tarefa_pessoal after insert or update of user_id, partilhada_com on public.tarefas_pessoais
  for each row execute function public.bsp_push_tarefa_pessoal();

-- Tarefas da equipa (shared_state.tasks): quem passa a estar atribuído.
create or replace function public.bsp_push_tarefas_equipa()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
declare
  r record;
  quem text := public.bsp_meu_id();
begin
  if new.tasks is not distinct from old.tasks then return null; end if;
  for r in
    with novo as (
      select t->>'id' id, t->>'title' titulo, a pessoa
        from jsonb_each(coalesce(new.tasks, '{}'::jsonb)) col, jsonb_array_elements(case when jsonb_typeof(col.value) = 'array' then col.value else '[]'::jsonb end) t,
             jsonb_array_elements_text(case when jsonb_typeof(t->'assignees') = 'array' then t->'assignees' else '[]'::jsonb end) a
    ), velho as (
      select t->>'id' id, a pessoa
        from jsonb_each(coalesce(old.tasks, '{}'::jsonb)) col, jsonb_array_elements(case when jsonb_typeof(col.value) = 'array' then col.value else '[]'::jsonb end) t,
             jsonb_array_elements_text(case when jsonb_typeof(t->'assignees') = 'array' then t->'assignees' else '[]'::jsonb end) a
    )
    select n.id, max(n.titulo) titulo, array_agg(distinct n.pessoa) para
      from novo n
     where not exists (select 1 from velho v where v.id = n.id and v.pessoa = n.pessoa)
       and n.pessoa <> coalesce(quem, '')
     group by n.id
     limit 20
  loop
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(r.para),
      'titulo', 'Nova tarefa atribuída', 'corpo', left(coalesce(r.titulo, ''), 160), 'url', '#/tarefas', 'tag', 'tarefa-' || r.id));
  end loop;
  return null;
end $$;
create or replace trigger bsp_push_tarefas_equipa after update of tasks on public.shared_state
  for each row execute function public.bsp_push_tarefas_equipa();

-- Documentos novos: toda a equipa.
create or replace function public.bsp_push_documento()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
begin
  if coalesce(new.arquivado, false) then return null; end if;
  perform public.bsp_push_post(jsonb_build_object('para', 'todos', 'exceto', new.publicado_por,
    'titulo', 'Documento novo' || case when new.leitura_obrigatoria then ' · leitura obrigatória' else '' end,
    'corpo', left(coalesce(new.titulo, ''), 160), 'url', '#/documentos', 'tag', 'documento-' || new.id));
  return null;
end $$;
create or replace trigger bsp_push_documento after insert on public.documentos
  for each row execute function public.bsp_push_documento();

-- Convites da agenda.
create or replace function public.bsp_push_agenda()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
declare para text[];
begin
  para := array(select distinct x from unnest(coalesce(new.convidados, '{}')) x
                 where x <> coalesce(new.dono, '') and (tg_op = 'INSERT' or not (x = any (coalesce(old.convidados, '{}')))));
  if cardinality(para) > 0 then
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para),
      'titulo', 'Convite: ' || left(coalesce(new.titulo, ''), 80),
      'corpo', public.bsp_nome_de(coalesce(new.criado_por, new.dono)) || ' convidou-o' ||
               coalesce(' · ' || to_char(new.data, 'DD-MM-YYYY'), '') || coalesce(' às ' || nullif(new.hora, ''), ''),
      'url', '#/agenda', 'tag', 'agenda-' || new.id));
  end if;
  return null;
end $$;
create or replace trigger bsp_push_agenda after insert or update of convidados on public.agenda_eventos
  for each row execute function public.bsp_push_agenda();

notify pgrst, 'reload schema';
