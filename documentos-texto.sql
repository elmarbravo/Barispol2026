-- Barispol Workspace · texto dos documentos e conhecimento do assistente
-- Pedido do Elmar, 02-10-2026: «Consegues colocar o regulamento interno nas
-- regras do sistema? Ler os artigos e sempre que necessário usamos sem ter
-- de ir ler todo ele». Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs)
-- no mesmo dia. Pode correr-se mais do que uma vez. Corre-se depois de
-- documentos.sql.
--
--   documentos_texto   o texto de cada documento de Documentos (Edge
--                      Function documento-texto: .docx lido, PDF com texto
--                      lido, PDF digitalizado transcrito pelo Claude quando
--                      houver ANTHROPIC_API_KEY)
--   conhecimento       textos de referência do assistente do Workspace, por
--                      chave. 'regulamento-interno' = resumo por secção
--                      (RI-n.m). O texto NÃO está aqui: o repositório é
--                      público e o regulamento é do foro interno (RI-4.8).
--                      Insere-se directamente no servidor.
--   cron bsp-documentos-texto  diário às 05h20 (Luanda): lê os documentos
--                      novos e transcreve os digitalizados que faltam.
-- Só o servidor lê as duas tabelas (sem regras para authenticated).

create table if not exists public.documentos_texto (
  documento_id bigint primary key references public.documentos(id) on delete cascade,
  texto text not null default '',
  paginas integer,
  metodo text,
  extraido_em timestamptz not null default now()
);
alter table public.documentos_texto enable row level security;
revoke all on public.documentos_texto from anon, authenticated;

create table if not exists public.conhecimento (
  chave text primary key,
  titulo text not null,
  texto text not null,
  actualizado_em timestamptz not null default now()
);
alter table public.conhecimento enable row level security;
revoke all on public.conhecimento from anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'bsp-documentos-texto') then perform cron.unschedule('bsp-documentos-texto'); end if;
  perform cron.schedule('bsp-documentos-texto', '20 4 * * *', $cmd$
    select net.http_post(
      url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/documento-texto',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                         where name = 'bsp_resumo_agendamento' limit 1)),
      body    := '{}'::jsonb,
      timeout_milliseconds := 120000
    );
  $cmd$);
end $$;
