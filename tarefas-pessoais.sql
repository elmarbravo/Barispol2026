-- Barispol Workspace · tarefas pessoais
-- Correr UMA vez no SQL Editor do Supabase. Pode repetir sem estragar nada.
--
-- PORQUE UMA TABELA À PARTE, e não uma marca "pessoal" nas tarefas que já
-- existem: as tarefas da equipa vivem no shared_state, um bloco JSON que
-- é enviado por inteiro para todos os aparelhos. Marcar uma como pessoal
-- e escondê-la no ecrã não a esconderia de ninguém — continuaria a chegar
-- a todos os telemóveis, e qualquer pessoa a leria nos dados em bruto.
-- Seria privacidade a fingir.
--
-- Aqui, cada linha pertence a uma pessoa e a regra do servidor não deixa
-- ninguém ler as dos outros. Nem sequer chegam ao aparelho.

create table if not exists tarefas_pessoais (
  id         bigint generated always as identity primary key,
  -- O id da aplicação (u1, u2, ...), o mesmo que o bsp_meu_id() devolve.
  user_id    text not null,
  coluna     text not null default 'todo',   -- todo | doing | review | done
  titulo     text not null,
  prioridade text not null default 'media',  -- alta | media | baixa
  prazo      text,
  ordem      integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists tarefas_pessoais_dono_idx
  on tarefas_pessoais (user_id, coluna, ordem);

alter table tarefas_pessoais enable row level security;

drop policy if exists "bsp_tp_ler"    on tarefas_pessoais;
drop policy if exists "bsp_tp_criar"  on tarefas_pessoais;
drop policy if exists "bsp_tp_mudar"  on tarefas_pessoais;
drop policy if exists "bsp_tp_apagar" on tarefas_pessoais;

-- Só o dono. Sem excepção para gestores: uma tarefa pessoal que a
-- direcção pudesse ler não seria pessoal, e a pessoa que a escreveu
-- ficaria a pensar que era.
create policy "bsp_tp_ler" on tarefas_pessoais for select
  to authenticated using (user_id = bsp_meu_id());
create policy "bsp_tp_criar" on tarefas_pessoais for insert
  to authenticated with check (user_id = bsp_meu_id());
create policy "bsp_tp_mudar" on tarefas_pessoais for update
  to authenticated using (user_id = bsp_meu_id()) with check (user_id = bsp_meu_id());
create policy "bsp_tp_apagar" on tarefas_pessoais for delete
  to authenticated using (user_id = bsp_meu_id());

-- NOTA: o bsp_meu_id() traduz o e-mail da sessão para o id da aplicação,
-- procurando-o em Admin -> Utilizadores. Se o e-mail de login não
-- coincidir com o do directório, a função devolve nulo e a pessoa não vê
-- as suas próprias tarefas. Corrigir o e-mail no directório resolve.

-- Conferir:
-- select tablename, rowsecurity from pg_tables
-- where schemaname = 'public' and tablename = 'tarefas_pessoais';

-- REVERTER (só em emergência):
-- drop table if exists tarefas_pessoais;
