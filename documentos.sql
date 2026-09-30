-- Barispol Workspace · Documentos da clínica (regulamento interno, notas
-- internas, comunicados, procedimentos, formulários). Pedido do Elmar,
-- 30-09-2026. Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo
-- dia. Pode correr-se mais do que uma vez.
--
-- Toda a equipa lê (menos os sócios, que só vêem o Painel). Publicam a
-- Direcção e a Coordenação (bsp_e_gestor), a Direcção Clínica
-- (bsp_le_areas_medicas, Osvaldo Pacheco) e o departamento Administração.
-- A mesma regra está no ecrã: bspPublicaDocumentos.
--
-- A leitura é obrigatória: cada pessoa confirma «Li e tomei conhecimento»
-- (documentos_leituras) e quem publica vê quem confirmou e quem falta.
--
-- Aviso no instante da publicação: o gatilho chama a Edge Function
-- documento-aviso (e-mail a cada pessoa) e o Workspace ouve a tabela em
-- tempo real (sino com som).
--
-- Os ficheiros ficam no bucket drive, na pasta documentos/: toda a equipa
-- lê; só quem publica grava e apaga.

create or replace function public.bsp_publica_documentos()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select not public.bsp_e_socio() and (
       public.bsp_e_gestor()
    or public.bsp_le_areas_medicas()
    or coalesce(public.bsp_minha_area(), '') = 'administracao')
$function$;
grant execute on function public.bsp_publica_documentos() to authenticated;

create table if not exists public.documentos (
  id bigint generated always as identity primary key,
  categoria text not null check (categoria in ('regulamento', 'nota', 'comunicado', 'procedimento', 'formulario')),
  titulo text not null check (length(btrim(titulo)) > 0),
  numero text not null default '',
  descricao text not null default '',
  caminho text not null,
  nome_ficheiro text not null,
  tamanho bigint,
  em_vigor_desde date not null default current_date,
  substitui bigint references public.documentos (id) on delete set null,
  arquivado boolean not null default false,
  leitura_obrigatoria boolean not null default true,
  publicado_por text,
  publicado_em timestamptz not null default now(),
  aviso_enviado_em timestamptz
);
create index if not exists documentos_publicado on public.documentos (publicado_em desc);

create table if not exists public.documentos_leituras (
  documento_id bigint not null references public.documentos (id) on delete cascade,
  user_id text not null,
  lido_em timestamptz not null default now(),
  primary key (documento_id, user_id)
);

create or replace function public.bsp_documentos_carimbo()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if tg_table_name = 'documentos' then
    if tg_op = 'INSERT' then
      new.publicado_por := coalesce(public.bsp_meu_id(), new.publicado_por);
      new.publicado_em := now();
      new.aviso_enviado_em := null;
    end if;
  else
    new.user_id := coalesce(public.bsp_meu_id(), new.user_id);
    new.lido_em := now();
  end if;
  return new;
end $function$;

drop trigger if exists bsp_documentos_carimbo on public.documentos;
create trigger bsp_documentos_carimbo before insert on public.documentos
  for each row execute function public.bsp_documentos_carimbo();
drop trigger if exists bsp_documentos_leituras_carimbo on public.documentos_leituras;
create trigger bsp_documentos_leituras_carimbo before insert on public.documentos_leituras
  for each row execute function public.bsp_documentos_carimbo();

-- Depois de publicar: arquiva a versão substituída e manda avisar já.
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
  perform net.http_post(
    url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/documento-aviso',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                       where name = 'bsp_resumo_agendamento' limit 1)),
    body    := jsonb_build_object('id', new.id),
    timeout_milliseconds := 10000
  );
  return new;
end $function$;
drop trigger if exists bsp_documentos_publicado on public.documentos;
create trigger bsp_documentos_publicado after insert on public.documentos
  for each row execute function public.bsp_documentos_publicado();

alter table public.documentos enable row level security;
drop policy if exists documentos_ler on public.documentos;
drop policy if exists documentos_criar on public.documentos;
drop policy if exists documentos_mudar on public.documentos;
drop policy if exists documentos_apagar on public.documentos;
create policy documentos_ler on public.documentos for select to authenticated using (not public.bsp_e_socio());
create policy documentos_criar on public.documentos for insert to authenticated with check (public.bsp_publica_documentos());
create policy documentos_mudar on public.documentos for update to authenticated using (public.bsp_publica_documentos()) with check (public.bsp_publica_documentos());
create policy documentos_apagar on public.documentos for delete to authenticated using (public.bsp_publica_documentos());

alter table public.documentos_leituras enable row level security;
drop policy if exists documentos_leituras_ler on public.documentos_leituras;
drop policy if exists documentos_leituras_criar on public.documentos_leituras;
drop policy if exists documentos_leituras_apagar on public.documentos_leituras;
create policy documentos_leituras_ler on public.documentos_leituras for select to authenticated
  using (user_id = public.bsp_meu_id() or public.bsp_publica_documentos());
create policy documentos_leituras_criar on public.documentos_leituras for insert to authenticated
  with check (user_id = public.bsp_meu_id() and not public.bsp_e_socio());
create policy documentos_leituras_apagar on public.documentos_leituras for delete to authenticated
  using (public.bsp_publica_documentos());

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'documentos') then
    alter publication supabase_realtime add table public.documentos;
  end if;
end $$;

-- Pasta documentos/ do bucket drive: toda a equipa lê (regra de leitura
-- geral, sem mudança); só quem publica grava e apaga.
drop policy if exists "bsp_drive_criar" on storage.objects;
create policy "bsp_drive_criar" on storage.objects for insert to authenticated with check (
  bucket_id = 'drive' and (
       (name !~~ 'privado/%' and name !~~ 'conversa/%' and name !~~ 'equipa/%' and name !~~ 'documentos/%')
    or (name ~~ 'privado/%' and split_part(name, '/', 2) = public.bsp_meu_id())
    or (name ~~ 'equipa/%' and split_part(name, '/', 2) = public.bsp_meu_id())
    or (name ~~ 'conversa/%' and public.bsp_ve_conversa(split_part(name, '/', 2)))
    or (name ~~ 'documentos/%' and public.bsp_publica_documentos())));
drop policy if exists "bsp_drive_apagar" on storage.objects;
create policy "bsp_drive_apagar" on storage.objects for delete to authenticated using (
  bucket_id = 'drive' and (
       (name !~~ 'privado/%' and name !~~ 'conversa/%' and name !~~ 'equipa/%' and name !~~ 'documentos/%')
    or (name ~~ 'privado/%' and split_part(name, '/', 2) = public.bsp_meu_id())
    or (name ~~ 'equipa/%' and (split_part(name, '/', 2) = public.bsp_meu_id() or public.bsp_pode_apagar_ficheiros()))
    or (name ~~ 'conversa/%' and public.bsp_ve_conversa(split_part(name, '/', 2)))
    or (name ~~ 'documentos/%' and public.bsp_publica_documentos())));

notify pgrst, 'reload schema';
