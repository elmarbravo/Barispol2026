-- Barispol Workspace · seguimento e retorno de utentes (CRM, passo 1)
-- Correr UMA vez no SQL Editor do Supabase. Pode repetir sem estragar nada.
--
-- O QUE FAZ: cria onde viver a lista de utentes e o registo de seguimento.
--
-- PORQUE EM TABELAS PRÓPRIAS, e não no shared_state como as tarefas e o
-- calendário: o shared_state é um único bloco JSON reescrito por inteiro a
-- cada alteração. Serve para dezenas de linhas, não para milhares de
-- utentes — com o histórico de uma clínica, cada mudança de estado
-- reenviaria a base toda.
--
-- O MetaGest continua a ser a verdade sobre consultas e facturação. Isto
-- não a duplica: guarda só quem é o utente, quando cá esteve pela última
-- vez, e o que a clínica fez desde então para o trazer de volta.

-- 1. Utentes. Alimentados por importação do Relatório do MetaGest.
create table if not exists utentes (
  id             bigint generated always as identity primary key,
  -- Chave estável para não duplicar a cada importação. Construída na
  -- aplicação a partir do nome normalizado + telefone.
  chave          text not null unique,
  nome           text not null,
  telefone       text,
  -- O que interessa ao seguimento, tirado da última linha do relatorio.
  ultima_visita  date,
  ultimo_servico text,
  ultimo_medico  text,
  visitas        integer not null default 1,
  criado_em      timestamptz not null default now(),
  actualizado_em timestamptz not null default now()
);

-- A pergunta que este módulo faz é sempre "quem não vem há muito tempo".
create index if not exists utentes_ultima_visita_idx on utentes (ultima_visita);
create index if not exists utentes_nome_idx on utentes (lower(nome));

-- 2. Seguimento. Uma linha por acção: quem falou com quem, quando, e o quê.
--    Histórico, não estado — o estado actual é a linha mais recente.
create table if not exists seguimentos (
  id         bigint generated always as identity primary key,
  utente_id  bigint not null references utentes (id) on delete cascade,
  -- por-contactar | contactado | marcado | voltou | dispensado
  estado     text not null,
  nota       text,
  user_id    text,
  created_at timestamptz not null default now()
);

create index if not exists seguimentos_utente_idx on seguimentos (utente_id, created_at desc);

-- 3. Trancar. Sem sessão iniciada, nada.
alter table utentes enable row level security;
alter table seguimentos enable row level security;

drop policy if exists "bsp_utentes_ler"    on utentes;
drop policy if exists "bsp_utentes_criar"  on utentes;
drop policy if exists "bsp_utentes_mudar"  on utentes;
drop policy if exists "bsp_utentes_apagar" on utentes;

-- Toda a equipa autenticada lê: é a recepção que faz as chamadas.
create policy "bsp_utentes_ler" on utentes for select
  to authenticated using (true);

-- Escrever na lista de utentes é importar, e isso é acto de gestão.
create policy "bsp_utentes_criar" on utentes for insert
  to authenticated with check (bsp_e_gestor());
create policy "bsp_utentes_mudar" on utentes for update
  to authenticated using (bsp_e_gestor()) with check (bsp_e_gestor());
create policy "bsp_utentes_apagar" on utentes for delete
  to authenticated using (bsp_e_gestor());

drop policy if exists "bsp_seg_ler"    on seguimentos;
drop policy if exists "bsp_seg_criar"  on seguimentos;
drop policy if exists "bsp_seg_apagar" on seguimentos;

-- O seguimento é o trabalho do dia-a-dia: qualquer pessoa da equipa
-- regista o que fez, em seu nome. Apagar é do autor ou de um gestor.
create policy "bsp_seg_ler" on seguimentos for select
  to authenticated using (true);
create policy "bsp_seg_criar" on seguimentos for insert
  to authenticated with check (user_id = bsp_meu_id() or bsp_meu_id() is null);
create policy "bsp_seg_apagar" on seguimentos for delete
  to authenticated using (user_id = bsp_meu_id() or bsp_e_gestor());

-- 4. Conferir. Deve devolver as duas tabelas com RLS activo.
--
-- select tablename, rowsecurity from pg_tables
-- where schemaname = 'public' and tablename in ('utentes','seguimentos');

-- REVERTER (só em emergência): apaga tudo o que este ficheiro criou.
-- drop table if exists seguimentos;
-- drop table if exists utentes;
