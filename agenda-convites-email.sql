-- Barispol Workspace · convite de calendário por e-mail em todos os eventos
-- Pedido do Elmar, 02-10-2026: «Tudo que for evento de um funcionário
-- coloque no seu email ou faça convite no seu Email». Aplicado no projecto
-- Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que
-- uma vez. Corre-se depois de agenda-lembretes.sql.
--
-- Cada e-mail leva o convite.ics (Edge Function agenda-avisos):
--   · criar          → o dono e os convidados (qual "convite")
--   · entrar depois  → só quem entrou (qual "convite")
--   · mudar a hora, o dia, a data, a duração, o título ou o local
--                    → quem já estava e não respondeu «nao» (qual "actualizado")
--   · sair ou apagar → quem saiu, ou todos (qual "cancelado", METHOD:CANCEL)
--   agenda_eventos.ics_seq sobe a cada mudança: o calendário de cada pessoa
--   actualiza o mesmo evento (UID agenda-<id>@barispol.com) em vez de criar
--   outro.
-- Para gravar sem e-mail (por exemplo, para os juntar num só):
--   select set_config('bsp.sem_convite', '1', true);  -- só nessa transacção

alter table public.agenda_eventos add column if not exists ics_seq integer not null default 0;

create or replace function public.bsp_agenda_ics_seq()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  if (new.titulo, new.hora, new.duracao, new.dia, new.data, new.dia_mes, new.local)
     is distinct from (old.titulo, old.hora, old.duracao, old.dia, old.data, old.dia_mes, old.local) then
    new.ics_seq := old.ics_seq + 1;
  end if;
  return new;
end $function$;
create or replace trigger bsp_agenda_ics_seq before update on public.agenda_eventos
  for each row execute function public.bsp_agenda_ics_seq();

create or replace function public.bsp_agenda_avisos_post(p_corpo jsonb)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  perform net.http_post(
    url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/agenda-avisos',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                       where name = 'bsp_resumo_agendamento' limit 1)),
    body    := p_corpo,
    timeout_milliseconds := 30000);
end $function$;
revoke all on function public.bsp_agenda_avisos_post(jsonb) from public, anon, authenticated;

create or replace function public.bsp_agenda_convite_aviso()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare novos text[] := '{}'; sairam text[] := '{}'; ficam text[] := '{}';
begin
  if coalesce(current_setting('bsp.sem_convite', true), '') = '1' then return coalesce(new, old); end if;
  if tg_op = 'DELETE' then
    ficam := array(select distinct x from unnest(array[old.dono] || coalesce(old.convidados, '{}')) x
                    where coalesce(old.respostas->>x, '') <> 'nao');
    if coalesce(array_length(ficam, 1), 0) > 0 then
      perform public.bsp_agenda_avisos_post(jsonb_build_object('qual', 'cancelado', 'ids', to_jsonb(ficam),
        'dados', to_jsonb(old) - 'respostas' - 'lembretes_pessoa'));
    end if;
    return old;
  end if;
  if tg_op = 'INSERT' then
    novos := array(select distinct x from unnest(array[new.dono] || coalesce(new.convidados, '{}')) x);
  else
    novos := array(select distinct x from unnest(array[new.dono] || coalesce(new.convidados, '{}')) x
                    where not (x = old.dono or x = any (coalesce(old.convidados, '{}'))));
    sairam := array(select distinct x from unnest(array[old.dono] || coalesce(old.convidados, '{}')) x
                     where not (x = new.dono or x = any (coalesce(new.convidados, '{}'))));
    if new.ics_seq <> old.ics_seq then
      ficam := array(select distinct x from unnest(array[new.dono] || coalesce(new.convidados, '{}')) x
                      where not (x = any (novos)) and coalesce(new.respostas->>x, '') <> 'nao');
    end if;
  end if;
  if coalesce(array_length(novos, 1), 0) > 0 then
    -- O aviso no sino é a novidade do gatilho bsp_agenda_carimbo: fica
    -- marcada como enviada para não voltar a sair no e-mail das 05h00.
    update public.novidades set enviado_em = now(), enviados = coalesce(enviados, 0)
     where enviado_em is null and destino = 'calendar' and titulo = 'Convite: ' || new.titulo
       and criado_em > now() - interval '1 minute';
    perform public.bsp_agenda_avisos_post(jsonb_build_object('qual', 'convite', 'evento', new.id, 'ids', to_jsonb(novos)));
  end if;
  if coalesce(array_length(sairam, 1), 0) > 0 then
    perform public.bsp_agenda_avisos_post(jsonb_build_object('qual', 'cancelado', 'saiu', true, 'ids', to_jsonb(sairam),
      'dados', to_jsonb(old) - 'respostas' - 'lembretes_pessoa'));
  end if;
  if coalesce(array_length(ficam, 1), 0) > 0 then
    perform public.bsp_agenda_avisos_post(jsonb_build_object('qual', 'actualizado', 'evento', new.id, 'ids', to_jsonb(ficam)));
  end if;
  return new;
end $function$;
revoke all on function public.bsp_agenda_convite_aviso() from public, anon;
create or replace trigger bsp_agenda_convite_aviso after insert or update or delete on public.agenda_eventos
  for each row execute function public.bsp_agenda_convite_aviso();

insert into public.novidades (titulo, texto, grupos, destino)
select 'Eventos no calendário do seu e-mail',
       'Cada evento da Agenda do Workspace chega agora por e-mail com o convite de calendário (convite.ics) a quem está nele: ao criar, ao mudar a hora ou o dia e ao cancelar. Abra o anexo para o evento ficar também no Outlook, no Gmail ou no iPhone.',
       array['todos'], 'calendar'
 where not exists (select 1 from public.novidades where titulo = 'Eventos no calendário do seu e-mail');

notify pgrst, 'reload schema';
