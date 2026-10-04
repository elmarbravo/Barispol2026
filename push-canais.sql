-- Aviso no telemóvel também nas mensagens dos canais (04-10-2026, Elmar: «as
-- mensagens normais entre pessoas no chat não estão a notificar nem a contar
-- números, preciso que notifique tudo»).
--
-- Antes: o push do servidor (bsp_push_mensagem) só saía nas mensagens
-- directas e nos grupos com membros; nos canais (#geral, #avisos, #escalas e
-- os de área) só nas menções. Confirmado nos registos de 03-10-2026: as
-- mensagens de #recepção, #laboratório, #escalas e #radiologia não geraram
-- nenhum push; as do grupo, sim.
-- Agora: nos canais avisa quem vê o canal, com a mesma regra do bspVeCanal do
-- ecrã e do bsp_ve_conversa: nos de área, a área, a gestão, a Direcção
-- Clínica (nos da saúde) e quem tem o canal em extraCanais; em #geral,
-- #avisos e #escalas, toda a equipa menos quem está em semCanais. Nunca o
-- autor nem os sócios. Etiqueta conv-<chave>, a mesma do aviso do ecrã.

CREATE OR REPLACE FUNCTION public.bsp_push_mensagem()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  select coalesce(array_agg(e->>'id'), '{}') into mencoes
    from public.shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and e->>'id' <> new.user_id and not public.bsp_membro_e_socio(e)
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
  -- Canais (sem membros escolhidos): avisa quem vê o canal, como o bspVeCanal do ecrã
  -- (04-10-2026, Elmar: «preciso que notifique tudo»; push-canais.sql).
  if chave like 'c-%' and grupo is null then
    select coalesce(array_agg(e->>'id'), '{}') into para
      from public.shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1 and e->>'id' <> new.user_id and not public.bsp_membro_e_socio(e)
       and case when area is null then not (coalesce(e->'semCanais', '[]'::jsonb) ? chave)
                else public.bsp_membro_nos_grupos(e, array[area, 'gestao']
                       || case when area in ('clinica', 'enfermagem', 'farmacia', 'laboratorio', 'radiologia') then array['direccao-clinica'] else '{}'::text[] end)
                     or coalesce(e->'extraCanais', '[]'::jsonb) ? chave end;
    select autor || ' · #' || coalesce(nullif(c.value->>'name', ''), substr(chave, 3)) into titulo
      from public.shared_state s, jsonb_array_elements(coalesce(s.channels, '[]'::jsonb)) c
     where s.id = 1 and c.value->>'id' = chave limit 1;
    titulo := coalesce(titulo, autor || ' · #' || case chave when 'c-clinica' then 'clínica' when 'c-rececao' then 'recepção'
                when 'c-farmacia' then 'farmácia' when 'c-laboratorio' then 'laboratório' else substr(chave, 3) end);
  end if;
  if cardinality(para) > 0 then
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'exceto', new.user_id,
      'titulo', titulo, 'corpo', corpo, 'url', url, 'tag', 'conv-' || chave));
  end if;
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
end $function$;
