-- Barispol Workspace · a Direcção vê as tarefas pessoais
-- Correr UMA vez no SQL Editor do Supabase, DEPOIS do INSTALAR-TUDO.sql.
--
-- Até aqui, uma tarefa pessoal era só do dono, sem excepção. Passa a poder
-- ser lida por quem estiver numa camada com a permissão "Ver as tarefas
-- pessoais de todos", que se liga em Admin -> Permissões.
--
-- É uma permissão da camada e não o nome "Direcção" à letra: com as
-- camadas editáveis, um nome fixo aqui ficaria errado assim que alguém
-- criasse ou renomeasse uma camada.
--
-- IMPORTANTE: a aplicação avisa quem escreve uma tarefa pessoal, no
-- momento em que a escreve, de que camadas a podem ler. Se alguma vez
-- correr este ficheiro sem a versão da aplicação que traz esse aviso, a
-- interface fica a prometer uma privacidade que já não existe.
--
-- Continua a ser SÓ LEITURA: ninguém edita nem apaga a tarefa de outra
-- pessoa. Ver não é mexer.

create or replace function bsp_ve_tarefas_de_todos() returns boolean
language sql stable security definer set search_path = public as $f$
  select exists (
    select 1
    from shared_state s,
         jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
    where s.id = 1
      and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email', ''))
      and (s.camadas -> (e->>'accessLevel') ->> 'podeVerTarefasPessoais')::boolean is true
  )
$f$;

drop policy if exists "bsp_tp_ler" on tarefas_pessoais;

create policy "bsp_tp_ler" on tarefas_pessoais for select
  to authenticated using (
    user_id = bsp_meu_id() or bsp_ve_tarefas_de_todos()
  );

-- Conferir quem passa a ver tudo. Se aparecer alguém a mais, tire-lhe a
-- permissão em Admin -> Permissões.
--
-- select e->>'name' as pessoa, e->>'accessLevel' as camada
-- from shared_state s, jsonb_array_elements(coalesce(s.team,'[]'::jsonb)) e
-- where s.id = 1
--   and (s.camadas -> (e->>'accessLevel') ->> 'podeVerTarefasPessoais')::boolean is true;

-- REVERTER: volta a ser só do dono.
-- drop policy if exists "bsp_tp_ler" on tarefas_pessoais;
-- create policy "bsp_tp_ler" on tarefas_pessoais for select
--   to authenticated using (user_id = bsp_meu_id());
