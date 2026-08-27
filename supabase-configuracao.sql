-- Barispol Workspace · configuracao completa
-- Pode correr esta pagina inteira mais do que uma vez sem estragar nada.

-- 1. TABELAS
create table if not exists messages (
  id bigint generated always as identity primary key,
  conv_key text not null, user_id text, text text, cid text,
  created_at timestamptz default now());
create table if not exists posts (
  id bigint generated always as identity primary key,
  user_id text, type text, title text, body text, cid text,
  created_at timestamptz default now());
create table if not exists shared_state (
  id int primary key, tasks jsonb, events jsonb, drive jsonb, team jsonb,
  updated_at timestamptz default now());
alter table shared_state add column if not exists drive jsonb;
alter table shared_state add column if not exists team jsonb;
insert into shared_state (id) values (1) on conflict (id) do nothing;

-- 2. TRANCAR AS TABELAS
-- So quem tiver sessao iniciada le e escreve. Sem sessao, nada.
alter table messages enable row level security;
alter table posts enable row level security;
alter table shared_state enable row level security;

drop policy if exists "bsp_msg" on messages;
drop policy if exists "bsp_post" on posts;
drop policy if exists "bsp_state" on shared_state;
drop policy if exists "bsp_msg_auth" on messages;
drop policy if exists "bsp_post_auth" on posts;
drop policy if exists "bsp_state_auth" on shared_state;

create policy "bsp_msg_auth" on messages for all
  to authenticated using (true) with check (true);
create policy "bsp_post_auth" on posts for all
  to authenticated using (true) with check (true);
create policy "bsp_state_auth" on shared_state for all
  to authenticated using (true) with check (true);

-- 3. ARMAZENAMENTO DE FICHEIROS (balde privado "drive")
insert into storage.buckets (id, name, public)
  values ('drive', 'drive', false) on conflict (id) do nothing;

drop policy if exists "bsp_drive_ler" on storage.objects;
drop policy if exists "bsp_drive_criar" on storage.objects;
drop policy if exists "bsp_drive_apagar" on storage.objects;

create policy "bsp_drive_ler" on storage.objects for select
  to authenticated using (bucket_id = 'drive');
create policy "bsp_drive_criar" on storage.objects for insert
  to authenticated with check (bucket_id = 'drive');
create policy "bsp_drive_apagar" on storage.objects for delete
  to authenticated using (bucket_id = 'drive');

-- 4. TEMPO REAL
do $$ begin alter publication supabase_realtime add table messages; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table posts; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table shared_state; exception when duplicate_object then null; end $$;
