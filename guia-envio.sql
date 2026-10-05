-- Barispol Workspace · envio do Guia do Workspace a cada colaborador
-- Pedido do Elmar, 30-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia.
--
-- Cada pessoa recebe por e-mail o mapa dos menus e as fichas só dos menus a
-- que tem acesso (calculados com as regras do Workspace: NAV_ITEMS e as
-- funções bspVe*). O RH (Arlete, u2) vai em cópia e é quem recebe a
-- confirmação de leitura do programa de e-mail. A confirmação de recepção
-- é obrigatória: o botão do e-mail abre o Workspace em #confirmar-guia e
-- grava a data e a hora em guia_recepcoes; até lá, o Início mostra o pedido.
-- As imagens estão em https://barispol.com/guia/ (sem dados de doentes).
--
-- Envio: uma fila (guia_envios) e um agendamento a cada 10 segundos
-- (bsp-guia-envio), um e-mail de cada vez; o agendamento apaga-se sozinho
-- quando a fila acaba.

create table if not exists public.guia_envios (
  user_id text primary key,
  ordem integer not null default 100,
  menus text[] not null,
  estado text not null default 'por-enviar' check (estado in ('por-enviar', 'enviado', 'sem-email')),
  pedido_id bigint,
  enviado_em timestamptz
);
create table if not exists public.guia_recepcoes (
  user_id text primary key default public.bsp_meu_id(),
  confirmado_em timestamptz not null default now()
);
alter table public.guia_envios enable row level security;
alter table public.guia_recepcoes enable row level security;
drop policy if exists guia_envios_ler on public.guia_envios;
create policy guia_envios_ler on public.guia_envios for select to authenticated
  using (user_id = public.bsp_meu_id() or public.bsp_e_gestor());
drop policy if exists guia_recepcoes_ler on public.guia_recepcoes;
create policy guia_recepcoes_ler on public.guia_recepcoes for select to authenticated
  using (user_id = public.bsp_meu_id() or public.bsp_e_gestor());
drop policy if exists guia_recepcoes_criar on public.guia_recepcoes;
create policy guia_recepcoes_criar on public.guia_recepcoes for insert to authenticated
  with check (user_id = public.bsp_meu_id());
revoke all on public.guia_envios, public.guia_recepcoes from anon;

-- O e-mail de uma pessoa: saudação, pedido de confirmação e as imagens.
create or replace function public.bsp_guia_html(p_nome text, p_menus text[])
returns text
language sql
immutable
as $function$
  with fichas(id, ficheiro, nome, ordem) as (values
    ('mapa', '00-menus.png', 'Os menus do Workspace', 0),
    ('dashboard', '01-inicio.png', 'Início', 1), ('chat', '02-chat.png', 'Chat', 2),
    ('feed', '03-feed.png', 'Feed', 3), ('drive', '04-drive.png', 'Drive', 4),
    ('calendar', '05-calendario.png', 'Calendário', 5), ('tasks', '06-tarefas.png', 'Tarefas', 6),
    ('escalas', '07-escalas.png', 'Escalas', 7), ('transporte', '08-transporte.png', 'Transporte', 8),
    ('seguimento', '09-crm.png', 'CRM', 9), ('marcacoes', '10-marcacoes.png', 'Marcações', 10),
    ('painel', '11-painel.png', 'Painel', 11), ('relatorios', '12-relatorios.png', 'Relatórios', 12),
    ('actividade', '13-a-minha-actividade.png', 'A minha actividade', 13),
    ('documentos', '14-documentos.png', 'Documentos', 14), ('admin', '15-admin.png', 'Admin', 15)
  ), minhas as (
    select * from fichas where id = 'mapa' or id = any (p_menus)
  ), botao as (
    select '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:6px 0 22px"><tr><td style="background:#273069">'
        || '<a href="https://barispol.com/workspace.html#confirmar-guia" style="display:inline-block;padding:13px 24px;font-family:''Titillium Web'',''Segoe UI'',Arial,sans-serif;font-size:15px;font-weight:700;color:#ffffff;text-decoration:none">Confirmo a recepção</a>'
        || '</td></tr></table>' b
  )
  select replace(public.bsp_envelope(
    'Os seus menus do Workspace',
    '<p style="margin:0 0 14px">Olá, ' || split_part(coalesce(p_nome, ''), ' ', 1) || '.</p>'
    || '<p style="margin:0 0 14px">Enviamos o guia do Workspace Barispol com os menus a que tem acesso ('
    || (select count(*) from minhas where id <> 'mapa') || '). Cada imagem explica para que serve o menu, o que pode fazer e quem o vê.</p>'
    || '<p style="margin:0 0 14px"><b>Confirmação de recepção obrigatória.</b> Depois de ler, carregue no botão abaixo. A confirmação fica registada no Workspace com a data e a hora. O RH recebe cópia deste e-mail.</p>'
    || (select b from botao)
    || (select string_agg('<img src="https://barispol.com/guia/' || ficheiro || '" alt="Guia: ' || nome || '" width="592" style="display:block;width:100%;max-width:592px;height:auto;border:1px solid #DDDBD6;margin:0 0 16px">', '' order by ordem) from minhas)
    || '<p style="margin:8px 0 14px;font-size:13px;color:#4E5366">Se as imagens não aparecerem, carregue em «Mostrar imagens» no seu programa de e-mail. No Workspace, o botão «?» ao lado do título de cada ecrã mostra o mesmo guia.</p>'
    || (select b from botao)
  ), 'Relatório automático', 'Guia do Workspace')
$function$;

-- Envia o próximo da fila. Chamado pelo agendamento bsp-guia-envio.
create or replace function public.bsp_guia_enviar_proximo()
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  r record;
  pessoa jsonb;
  rh text;
  pedido bigint;
begin
  select * into r from public.guia_envios where estado = 'por-enviar' order by ordem, user_id limit 1 for update skip locked;
  if not found then
    if exists (select 1 from cron.job where jobname = 'bsp-guia-envio') then perform cron.unschedule('bsp-guia-envio'); end if;
    return 'fila vazia';
  end if;
  select e into pessoa from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = r.user_id;
  select lower(e->>'email') into rh from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = 'u2';
  if pessoa is null or not public.bsp_recebe_emails(pessoa) then
    update public.guia_envios set estado = 'sem-email' where user_id = r.user_id;
    return r.user_id || ': sem e-mail';
  end if;
  select net.http_post(
    url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/bright-worker',
    headers := jsonb_build_object('Content-Type', 'application/json',
                 'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets where name = 'bsp_resumo_agendamento' limit 1)),
    body    := jsonb_build_object(
                 'to', jsonb_build_array(pessoa->>'email'),
                 'cc', case when lower(pessoa->>'email') = rh then '[]'::jsonb else jsonb_build_array(rh) end,
                 'reply_to', jsonb_build_array(rh),
                 'headers', jsonb_build_object('Disposition-Notification-To', rh, 'Return-Receipt-To', rh),
                 'subject', 'Guia do Workspace: os seus menus (confirmação de recepção obrigatória)',
                 'html', public.bsp_guia_html(pessoa->>'name', r.menus)),
    timeout_milliseconds := 20000
  ) into pedido;
  update public.guia_envios set estado = 'enviado', pedido_id = pedido, enviado_em = now() where user_id = r.user_id;
  return r.user_id || ': pedido ' || pedido;
end $function$;
revoke all on function public.bsp_guia_enviar_proximo() from public, anon, authenticated;

notify pgrst, 'reload schema';

-- A fila (30-09-2026) e o agendamento foram criados à parte, na mesma data:
--   insert into public.guia_envios (user_id, ordem, menus) values (...);
--   select cron.schedule('bsp-guia-envio', '10 seconds', 'select public.bsp_guia_enviar_proximo()');
-- Os menus de cada pessoa saíram das regras do Workspace aplicadas à equipa
-- desse dia.
