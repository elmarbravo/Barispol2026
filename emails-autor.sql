-- E-mails enviados pela aplicação: autor e limite por pessoa (12-10-2026,
-- auditoria de segurança, Fase 2; bright-worker versão 8).
--
-- Antes, qualquer colaborador com sessão mandava, de geral@barispol.com,
-- quantos e-mails quisesse (só para endereços da equipa) e com o HTML que
-- quisesse: dava para esgotar os 100 por dia do plano gratuito da Resend e
-- para forjar um e-mail da clínica a um colega. Agora:
--   · emails_registo.autor guarda quem pediu o envio (id da equipa, ou
--     «servidor» / «gestor:<id>»);
--   · bsp_emails_de_hoje(autor) conta os envios do dia (Luanda) desse autor;
--     a bright-worker recusa o 21.º de um colaborador que não é gestor;
--   · a bright-worker limpa o HTML de quem não é gestor (sem scripts, sem
--     formulários, ligações só para barispol.com).
-- Pode correr-se mais do que uma vez.

alter table public.emails_registo add column if not exists autor text;
create index if not exists emails_registo_autor_dia on public.emails_registo (autor, criado_em);

create or replace function public.bsp_emails_de_hoje(p_autor text)
returns integer language sql stable security definer set search_path to 'public'
as $$
  select count(*)::integer
    from public.emails_registo
   where autor = p_autor and not pausado
     and (criado_em at time zone 'Africa/Luanda')::date = (now() at time zone 'Africa/Luanda')::date
$$;
revoke all on function public.bsp_emails_de_hoje(text) from public, anon, authenticated;
grant execute on function public.bsp_emails_de_hoje(text) to service_role;

notify pgrst, 'reload schema';
