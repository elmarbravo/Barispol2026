-- Barispol · sincronizacao do WhatsApp (SendPulse) a cada 15 minutos
-- Pedido do Elmar, 25-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- O agendamento whatsapp-sync corre a cada 3 minutos. Antes, a lista de
-- contactos (quem teve actividade nova) so se pedia a SendPulse de hora a
-- hora, e as mensagens novas podiam demorar ate uma hora a aparecer.
-- Agora pede-se a cada 15 minutos. So muda o intervalo; o resto e igual.

create or replace function whatsapp.cron_sync()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'extensions'
as $function$
declare r jsonb; ult timestamptz;
begin
  if not pg_try_advisory_lock(778899) then return jsonb_build_object('estado','ocupado'); end if;
  begin
    select max(fim) into ult from whatsapp.sync_log where tipo = 'contactos' and fim is not null;
    if ult is null or ult < now() - interval '15 minutes' then
      r := whatsapp.sync_contactos();
    else
      r := whatsapp.sync_mensagens(75);
    end if;
  exception when others then
    perform pg_advisory_unlock(778899);
    insert into whatsapp.sync_log(tipo, fim, detalhe) values ('erro', now(), left(sqlerrm, 500));
    return jsonb_build_object('erro', sqlerrm);
  end;
  perform pg_advisory_unlock(778899);
  return r;
end $function$;
