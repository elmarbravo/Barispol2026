-- Sincronização do WhatsApp mais leve (30-10-2026, Elmar: «Usa o 2, aliviar a
-- sincronização do WhatsApp»). Em dois congestionamentos da base nesse dia
-- (10h31 e 12h37 de Luanda) a whatsapp.cron_sync levou até 204 s, numa só
-- transacção, e regravava ~1.300 contactos a cada 20 min sem mudança (só 33
-- tiveram actividade em 24 h): escrita e WAL inúteis, que o tempo real tem de ler.
-- - sync_contactos: o upsert só grava quando algum campo mudou.
-- - cron_sync: releitura completa dos contactos de hora a hora (era 15 min) e
--   lote de mensagens de 25 conversas (era 75; cada conversa espera 2,1 s pela
--   SendPulse). O resto fica igual.

create or replace function whatsapp.sync_contactos()
returns jsonb language plpgsql security definer set search_path to 'public', 'extensions'
as $f$
declare off int := 0; j jsonb; c jsonb; n int := 0; lid bigint;
begin
  insert into whatsapp.sync_log(tipo) values ('contactos') returning id into lid;
  loop
    perform pg_sleep(2.1);
    j := whatsapp._get('https://api.sendpulse.com/whatsapp/chats?bot_id=6878d4fb45f616ab4d04ac92&limit=100&offset='||off||'&skip='||off);
    exit when j ? 'erro' or jsonb_array_length(coalesce(j->'data','[]'::jsonb)) = 0;
    for c in select * from jsonb_array_elements(j->'data') loop
      insert into whatsapp.contactos as t (id, telefone, nome, criado_em, ultima_actividade, ultima_mensagem_recebida, estado, etiquetas, variaveis, origem_anuncio, raw, sincronizado_em)
      values (c->'contact'->>'id', c->'contact'->'channel_data'->>'phone', c->'contact'->'channel_data'->>'name',
              (c->'contact'->>'created_at')::timestamptz, (c->'contact'->>'last_activity_at')::timestamptz,
              (c->'inbox_last_message'->>'created_at')::timestamptz, (c->'contact'->>'status')::int,
              c->'contact'->'tags', c->'contact'->'variables', c->'contact'->'last_referral', c->'contact', now())
      on conflict (id) do update set telefone = excluded.telefone, nome = excluded.nome, ultima_actividade = excluded.ultima_actividade,
        ultima_mensagem_recebida = excluded.ultima_mensagem_recebida, estado = excluded.estado, etiquetas = excluded.etiquetas,
        variaveis = excluded.variaveis, origem_anuncio = coalesce(excluded.origem_anuncio, t.origem_anuncio), raw = excluded.raw, sincronizado_em = now()
      where (t.telefone, t.nome, t.ultima_actividade, t.ultima_mensagem_recebida, t.estado, t.etiquetas, t.variaveis, t.raw)
            is distinct from
            (excluded.telefone, excluded.nome, excluded.ultima_actividade, excluded.ultima_mensagem_recebida, excluded.estado, excluded.etiquetas, excluded.variaveis, excluded.raw);
      n := n + 1;
    end loop;
    off := off + 100;
    exit when off > 20000;
  end loop;
  update whatsapp.sync_log set fim = now(), contactos = n, detalhe = case when j ? 'erro' then j::text end where id = lid;
  return jsonb_build_object('contactos', n);
end $f$;

create or replace function whatsapp.cron_sync()
returns jsonb language plpgsql security definer set search_path to 'public', 'extensions'
as $f$
declare r jsonb; ult timestamptz;
begin
  if not pg_try_advisory_lock(778899) then return jsonb_build_object('estado','ocupado'); end if;
  begin
    select max(fim) into ult from whatsapp.sync_log where tipo = 'contactos' and fim is not null;
    if ult is null or ult < now() - interval '60 minutes' then
      r := whatsapp.sync_contactos();
    else
      r := whatsapp.sync_mensagens(25);
    end if;
  exception when others then
    perform pg_advisory_unlock(778899);
    insert into whatsapp.sync_log(tipo, fim, detalhe) values ('erro', now(), left(sqlerrm, 500));
    return jsonb_build_object('erro', sqlerrm);
  end;
  perform pg_advisory_unlock(778899);
  return r;
end $f$;
