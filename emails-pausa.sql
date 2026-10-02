-- Barispol Workspace · pausa dos e-mails e registo de envios (02-10-2026)
-- Pedido do Elmar, 02-10-2026: «Não envie emails hoje, amanhã apenas.
-- Vamos diminuir o número de emails desnecessários. O Resend diz que saíram
-- 121 hoje, uso o gratuito não quero mudar.» Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
--   emails_pausa     uma linha: até quando não sai nenhum e-mail. A
--                    bright-worker consulta-a antes de cada envio e responde
--                    {"pausado": true} sem enviar.
--   emails_registo   cada envio (ou pausa) da bright-worker: assunto,
--                    número de destinatários e resultado. Serve para contar
--                    o dia contra o limite do plano gratuito da Resend
--                    (100 por dia, 3000 por mês). Sem endereços nem texto.
--   bsp_emails_hoje() quantos saíram hoje (Luanda), para a gestão.
--   bsp_emails_pausa_ate() a pausa marcada ou o tecto de 95 por dia.
--
-- Menos e-mails no mesmo dia:
--   · documento novo: deixa de mandar um e-mail por pessoa (Edge Function
--     documento-aviso). Vai nas novidades das 05h00 (um só e-mail com tudo),
--     no sino e no aviso do telemóvel;
--   · o colectivo das 12h00 (bsp-aviso-coletivo) fica desligado;
--   · a resumo-matinal (versão 14): o lembrete das 07h30 só a quem não abriu
--     o Workspace nos 2 dias anteriores, e o aviso de mensagem por ler não
--     vai por e-mail a quem recebe avisos no telemóvel.

create table if not exists public.emails_pausa (
  id integer primary key default 1 check (id = 1),
  ate timestamptz,
  motivo text not null default ''
);
alter table public.emails_pausa enable row level security;
revoke all on public.emails_pausa from anon, authenticated;
insert into public.emails_pausa (id, ate, motivo) values (1, null, '') on conflict (id) do nothing;

create table if not exists public.emails_registo (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  assunto text not null default '',
  destinatarios integer not null default 1,
  estado integer,
  pausado boolean not null default false
);
alter table public.emails_registo enable row level security;
revoke all on public.emails_registo from anon, authenticated;

-- Pausa marcada à mão ou, sem ela, o tecto do dia: com 95 destinatários já
-- servidos hoje (Luanda), nada mais sai até à meia-noite. Fica uma margem de
-- 5 para o plano gratuito (100 por dia).
create or replace function public.bsp_emails_pausa_ate()
returns timestamptz language sql stable security definer set search_path to 'public'
as $$
  select coalesce(
    (select ate from public.emails_pausa where id = 1 and ate > now()),
    (select (((now() at time zone 'Africa/Luanda')::date + 1)::timestamp at time zone 'Africa/Luanda')
       where (select coalesce(sum(destinatarios), 0) from public.emails_registo
               where not pausado and estado between 200 and 299
                 and (criado_em at time zone 'Africa/Luanda')::date = (now() at time zone 'Africa/Luanda')::date) >= 95))
$$;
revoke all on function public.bsp_emails_pausa_ate() from public, anon, authenticated;
grant execute on function public.bsp_emails_pausa_ate() to service_role;

create or replace function public.bsp_emails_hoje()
returns table (enviados bigint, destinatarios bigint, pausados bigint, falhados bigint)
language sql stable security definer set search_path to 'public'
as $$
  select count(*) filter (where not pausado and estado between 200 and 299),
         coalesce(sum(destinatarios) filter (where not pausado and estado between 200 and 299), 0),
         count(*) filter (where pausado),
         count(*) filter (where not pausado and coalesce(estado, 0) not between 200 and 299)
    from public.emails_registo
   where (criado_em at time zone 'Africa/Luanda')::date = (now() at time zone 'Africa/Luanda')::date
     and public.bsp_e_gestor()
$$;
revoke all on function public.bsp_emails_hoje() from public, anon;
grant execute on function public.bsp_emails_hoje() to authenticated;

-- Pausa de 02-10-2026: até à meia-noite de Luanda (23h00 UTC).
update public.emails_pausa set ate = timestamptz '2026-10-03 00:00:00+01',
       motivo = 'Pedido do Elmar: sem e-mails a 02-10-2026 (limite do plano gratuito da Resend).'
 where id = 1;

-- Documento novo: novidade em vez de um e-mail por pessoa.
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
  -- Menos e-mails (02-10-2026, pedido do Elmar): o documento novo deixa de
  -- mandar um e-mail por pessoa (documento-aviso). Vai nas novidades da
  -- manha (um so e-mail por pessoa, com tudo), no sino e no aviso do
  -- telemovel (bsp_push_documento), no instante.
  insert into public.novidades (titulo, texto, grupos, destino)
  values ('Documento novo' || case when new.leitura_obrigatoria then ' (leitura obrigatória)' else '' end || ': ' || new.titulo,
          'Publicado em Documentos' || coalesce(' com o n.º ' || nullif(new.numero, ''), '') || '. Abra-o no Workspace'
          || case when new.leitura_obrigatoria then ' e carregue em «Li e tomei conhecimento».' else '.' end,
          array['todos'], 'documentos');
  update public.documentos set aviso_enviado_em = now() where id = new.id;
  return new;
end $function$;

-- O colectivo das 12h00 (seg/qua/sex) fica desligado.
select cron.alter_job(jobid, active := false) from cron.job where jobname = 'bsp-aviso-coletivo';

notify pgrst, 'reload schema';
