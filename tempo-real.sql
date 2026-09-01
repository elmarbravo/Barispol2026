-- Barispol Workspace · pôr o tempo real a funcionar
-- Correr no SQL Editor do Supabase. Pode repetir sem estragar nada.
--
-- SINTOMA: as mensagens chegam com segundos de atraso, ou parecem não
-- chegar a alguns aparelhos. A aplicação tem uma sondagem de recurso que
-- vai buscar o que falta, e é ela que está a fazer o trabalho — daí o
-- atraso. O tempo real, que deveria entregar na hora, não está ligado.
--
-- CAUSA HABITUAL: as tabelas não estão na publicação do tempo real. Sem
-- isso o Supabase não anuncia as alterações a ninguém.

-- 1. VER PRIMEIRO. Devem aparecer messages, posts e shared_state.
--    Se faltar alguma, é essa a causa.
select tablename as tabela_no_tempo_real
from pg_publication_tables
where pubname = 'supabase_realtime'
order by 1;

-- 2. ACRESCENTAR o que faltar. Repetir é inofensivo.
do $$ begin alter publication supabase_realtime add table messages;
  exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table posts;
  exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table shared_state;
  exception when duplicate_object then null; end $$;

-- 3. CONFIRMAR. Agora devem estar as três.
select tablename as tabela_no_tempo_real
from pg_publication_tables
where pubname = 'supabase_realtime'
order by 1;

-- SE MESMO ASSIM CONTINUAR LENTO
--
-- O tempo real respeita as regras de segurança: para entregar uma
-- mensagem a alguém, o servidor tem de conseguir responder "esta pessoa
-- pode ver esta conversa?". Se o e-mail de login não coincidir com o do
-- directório, a resposta é não, e essa pessoa não recebe nada em tempo
-- real — só pela sondagem, e só o que a sondagem conseguir ler.
--
-- Corra a consulta de diagnóstico do LIGAR-SERVIDOR-Supabase.md, secção
-- "Conferir que está tudo de pé". É a mesma causa de alguém não ver as
-- suas mensagens directas.
--
-- Verifique também, no painel do Supabase, em Settings -> Realtime, se o
-- serviço está activo no projecto.
