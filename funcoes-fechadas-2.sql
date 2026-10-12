-- Fecho de funções e tabelas à chave pública (12-10-2026, auditoria de
-- segurança, Fase 2, ponto 3). Pode correr-se mais do que uma vez.
--
-- Levantamento feito no servidor antes de aplicar:
--   · o papel anon (a chave pública, sem sessão) tinha SELECT e INSERT em 70
--     tabelas de public, por herança dos privilégios por omissão do Supabase.
--     Não havia nenhuma regra RLS para anon, por isso não lia nada; mas uma
--     tabela nova criada sem RLS ficava logo aberta a quem tivesse a chave;
--   · 60 funções de public, crm, erp e whatsapp podiam ser chamadas por anon
--     (conversa_html do WhatsApp, cargas do MetaGest, funções de gatilho,
--     utilitários de texto): sem dados por si, mas sem razão para estar;
--   · 10 tabelas de erp e crm sem RLS (stock, cobranças, espera, fila).
--
-- Agora:
--   1. anon perde todos os privilégios nas tabelas e sequências de public e
--      deixa de os receber por omissão nas tabelas novas (postgres);
--   2. anon perde EXECUTE em todas as funções de public e deixa de o receber
--      por omissão; ficam só as quatro entradas de visitantes:
--      bsp_pedido_site e bsp_feedback_publico (site; até à Edge Function do
--      ponto 5), bsp_feedback_email e bsp_avaria_do_email (Zapier, com código
--      do cofre);
--   3. authenticated mantém exactamente o que tinha (concedido de forma
--      explícita às funções que hoje chama pelo papel PUBLIC), menos as
--      funções de gatilho, que ninguém chama pela API;
--   4. crm, erp e whatsapp: nenhuma função chamável por anon nem por
--      authenticated (as do Workspace vivem em public); RLS ligado nas
--      tabelas que não o tinham (sem regras: só o servidor lê).
-- Uma função nova em public fica fechada a anon por omissão; para abrir uma
-- entrada pública nova: grant execute … to anon, de propósito.

do $$
declare r record; abertas text[] := array['bsp_pedido_site', 'bsp_feedback_publico', 'bsp_feedback_email', 'bsp_avaria_do_email'];
begin
  -- 3. authenticated: o que hoje tem por PUBLIC passa a ser explícito.
  for r in
    select p.oid, p.oid::regprocedure as assinatura, p.prorettype = 'trigger'::regtype as gatilho
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'execute')
  loop
    if r.gatilho then
      execute 'revoke all on function ' || r.assinatura || ' from public, anon, authenticated';
    else
      execute 'grant execute on function ' || r.assinatura || ' to authenticated';
    end if;
  end loop;
  -- 2. anon e PUBLIC fora de todas as funções de public…
  for r in
    select p.oid::regprocedure as assinatura, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('public', p.oid, 'execute'))
  loop
    execute 'revoke all on function ' || r.assinatura || ' from public, anon';
    -- …menos as entradas de visitantes.
    if r.proname = any (abertas) then
      execute 'grant execute on function ' || r.assinatura || ' to anon, authenticated';
    end if;
  end loop;
  -- 4. crm, erp, whatsapp: nenhuma função pela API.
  for r in
    select p.oid::regprocedure as assinatura
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname in ('crm', 'erp', 'whatsapp')
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('public', p.oid, 'execute'))
  loop
    execute 'revoke all on function ' || r.assinatura || ' from public, anon, authenticated';
  end loop;
  -- 4. RLS nas tabelas de crm, erp e whatsapp que não o tinham.
  for r in
    select n.nspname, c.relname
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where c.relkind in ('r', 'p') and n.nspname in ('crm', 'erp', 'whatsapp') and not c.relrowsecurity
  loop
    execute format('alter table %I.%I enable row level security', r.nspname, r.relname);
    execute format('revoke all on %I.%I from public, anon, authenticated', r.nspname, r.relname);
  end loop;
end $$;

-- 1. anon fora das tabelas e sequências de public, hoje e nas futuras.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
alter default privileges for role postgres in schema public revoke all on tables from anon;
alter default privileges for role postgres in schema public revoke all on sequences from anon;
alter default privileges for role postgres in schema public revoke execute on functions from anon, public;

notify pgrst, 'reload schema';
