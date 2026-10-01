-- Barispol Workspace · o comunicado oficial vive em Documentos
-- Pedido do Elmar, 01-10-2026 (auditoria: comunicados em quatro sítios).
-- Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode
-- correr-se mais do que uma vez.
--
-- Publicar em Documentos um documento da categoria «comunicado» cria, no
-- mesmo instante, uma publicação no Feed (tipo comunicado) e uma mensagem
-- no canal #avisos. As duas terminam com a linha «[documento:<id>]», que o
-- Workspace troca pelo botão «Abrir o documento». A leitura confirmada
-- continua em Documentos. Mantém o resto do gatilho (arquivar a versão
-- substituída e o aviso por e-mail, documento-aviso).

create or replace function public.bsp_documentos_publicado()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if new.substitui is not null then
    update public.documentos set arquivado = true where id = new.substitui;
  end if;
  if new.categoria = 'comunicado' then
    insert into public.posts (user_id, type, title, body, cid)
    values (new.publicado_por, 'comunicado', new.titulo,
            coalesce(nullif(btrim(new.descricao), ''), 'Comunicado oficial publicado em Documentos.') || E'\n[documento:' || new.id || ']',
            'doc-' || new.id);
    insert into public.messages (conv_key, user_id, text, cid)
    values ('c-avisos', new.publicado_por,
            '📄 Comunicado: ' || new.titulo || coalesce(' (' || nullif(new.numero, '') || ')', '') || E'\n[documento:' || new.id || ']',
            'doc-' || new.id);
  end if;
  perform net.http_post(
    url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/documento-aviso',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                       where name = 'bsp_resumo_agendamento' limit 1)),
    body    := jsonb_build_object('id', new.id),
    timeout_milliseconds := 10000
  );
  return new;
end $function$;
