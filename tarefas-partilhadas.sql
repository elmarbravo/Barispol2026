-- Barispol Workspace · tarefas privadas partilhadas por varias pessoas
-- Pedido do Elmar, 25-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- Uma tarefa privada tem um dono (user_id). Pode agora ter tambem outras
-- pessoas em partilhada_com: todas a vem e a actualizam (coluna, titulo,
-- prazo). So o dono, a Direccao e a Coordenacao a apagam. Quem nao esta
-- na tarefa continua sem a ver.

alter table tarefas_pessoais
  add column if not exists partilhada_com text[] not null default '{}';

drop policy if exists "bsp_tp_ler"   on tarefas_pessoais;
drop policy if exists "bsp_tp_mudar" on tarefas_pessoais;

create policy "bsp_tp_ler" on tarefas_pessoais for select to authenticated
  using (user_id = bsp_meu_id() or bsp_ve_tarefas_pessoais() or bsp_meu_id() = any(partilhada_com));

create policy "bsp_tp_mudar" on tarefas_pessoais for update to authenticated
  using (user_id = bsp_meu_id() or bsp_ve_tarefas_pessoais() or bsp_meu_id() = any(partilhada_com))
  with check (user_id = bsp_meu_id() or bsp_ve_tarefas_pessoais() or bsp_meu_id() = any(partilhada_com));

-- bsp_tp_criar e bsp_tp_apagar ficam como estavam (tarefas-delegar.sql).

notify pgrst, 'reload schema';
