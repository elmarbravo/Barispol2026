-- Barispol Workspace · ficheiros pessoais e ficheiros das conversas
-- Correr UMA vez no SQL Editor do Supabase, DEPOIS do INSTALAR-TUDO.sql.
-- Pode repetir as vezes que quiser sem estragar nada.
--
-- PORQUE: ate aqui, tudo o que entrava no armazenamento era legivel por
-- qualquer pessoa com sessao iniciada. Duas consequencias:
--
--   1. Nao havia onde guardar um ficheiro so seu.
--   2. Um documento anexado numa mensagem DIRECTA era copiado para o
--      Drive da equipa — bastava mandar um exame a uma colega para ele
--      aparecer a toda a gente.
--
-- A partir daqui o caminho do ficheiro diz a quem ele pertence, e e o
-- servidor que decide:
--
--   privado/<id da pessoa>/...   so o dono (e quem tiver a permissao)
--   conversa/<chave>/...         so quem alcanca essa conversa
--   qualquer outro caminho       a equipa, como sempre foi
--
-- Os ficheiros que ja la estao nao tem prefixo nenhum, e por isso
-- continuam a ser da equipa. Nada se perde.

-- 0. Verificar que o INSTALAR-TUDO.sql ja correu.
do $$
begin
  if to_regprocedure('public.bsp_ve_conversa(text)') is null then
    raise exception 'Falta correr primeiro o INSTALAR-TUDO.sql (nao existe a funcao bsp_ve_conversa).';
  end if;
end $$;

-- 1. Quem pode ver o que e pessoal dos outros. E a mesma permissao das
--    tarefas pessoais, lida da camada e nao do nome dela. Fica aqui
--    tambem para o caso de o direccao-ve-tarefas.sql ainda nao ter
--    corrido — a definicao e identica, e repeti-la nao faz mal.
create or replace function bsp_ve_pessoais_de_todos() returns boolean
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

-- 2. A ficha de cada ficheiro pessoal. Os bytes vivem no armazenamento;
--    esta tabela guarda o nome, o tamanho e o caminho.
--
--    Tem de ser uma tabela a parte: a lista do Drive da equipa vive no
--    shared_state, que toda a gente le. Escrever la um ficheiro
--    "pessoal" seria esconde-lo no ecra e deixa-lo a vista na API.
create table if not exists ficheiros_pessoais (
  id bigint generated always as identity primary key,
  user_id text not null,
  nome text not null,
  caminho text not null,
  bytes bigint default 0,
  mime text,
  created_at timestamptz default now()
);
create index if not exists ficheiros_pessoais_dono on ficheiros_pessoais (user_id, created_at desc);
alter table ficheiros_pessoais enable row level security;

drop policy if exists "bsp_fp_ler" on ficheiros_pessoais;
drop policy if exists "bsp_fp_criar" on ficheiros_pessoais;
drop policy if exists "bsp_fp_apagar" on ficheiros_pessoais;

-- Ler: as minhas. Quem tiver a permissao le as de todos.
create policy "bsp_fp_ler" on ficheiros_pessoais for select
  to authenticated using (
    user_id = bsp_meu_id() or bsp_ve_pessoais_de_todos()
  );

-- Criar: so em meu nome. Sem isto, alguem podia gravar uma ficha com o
-- nome de outra pessoa.
create policy "bsp_fp_criar" on ficheiros_pessoais for insert
  to authenticated with check (
    user_id = bsp_meu_id() and bsp_meu_id() is not null
  );

-- Apagar: so o dono. Ver nao e mexer, nem para quem ve tudo.
create policy "bsp_fp_apagar" on ficheiros_pessoais for delete
  to authenticated using (user_id = bsp_meu_id());

-- 3. As regras do armazenamento. E aqui que o "privado" passa a querer
--    dizer privado: sem isto, a tabela acima escondia a ficha mas os
--    bytes continuavam ao alcance de quem soubesse o caminho.
drop policy if exists "bsp_drive_ler" on storage.objects;
drop policy if exists "bsp_drive_criar" on storage.objects;
drop policy if exists "bsp_drive_apagar" on storage.objects;

create policy "bsp_drive_ler" on storage.objects for select
  to authenticated using (
    bucket_id = 'drive' and (
      -- da equipa: tudo o que nao esta numa das duas gavetas fechadas
      (name not like 'privado/%' and name not like 'conversa/%')
      -- a minha gaveta, ou a de outra pessoa se eu puder ver as pessoais
      or (name like 'privado/%' and (
            split_part(name, '/', 2) = bsp_meu_id()
            or bsp_ve_pessoais_de_todos()
          ))
      -- os anexos de uma conversa seguem a regra dessa conversa
      or (name like 'conversa/%' and bsp_ve_conversa(split_part(name, '/', 2)))
    )
  );

create policy "bsp_drive_criar" on storage.objects for insert
  to authenticated with check (
    bucket_id = 'drive' and (
      (name not like 'privado/%' and name not like 'conversa/%')
      -- so na minha gaveta
      or (name like 'privado/%' and split_part(name, '/', 2) = bsp_meu_id())
      -- so em conversas que eu alcance
      or (name like 'conversa/%' and bsp_ve_conversa(split_part(name, '/', 2)))
    )
  );

create policy "bsp_drive_apagar" on storage.objects for delete
  to authenticated using (
    bucket_id = 'drive' and (
      (name not like 'privado/%' and name not like 'conversa/%')
      -- apagar o que e pessoal e so do dono, mesmo para quem ve tudo
      or (name like 'privado/%' and split_part(name, '/', 2) = bsp_meu_id())
      or (name like 'conversa/%' and bsp_ve_conversa(split_part(name, '/', 2)))
    )
  );

-- 4. Conferir. Deve dizer que a tabela esta protegida e listar as tres
--    regras do armazenamento.
select 'ficheiros_pessoais' as tabela,
       (select rowsecurity from pg_tables
        where schemaname = 'public' and tablename = 'ficheiros_pessoais') as protegida;

select policyname as regra_do_armazenamento, cmd as para
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and policyname like 'bsp_drive_%'
order by 1;

-- Quem passa a ver o que e pessoal dos outros. Se aparecer alguem a
-- mais, tire-lhe a permissao em Admin -> Permissoes.
--
-- select e->>'name' as pessoa, e->>'accessLevel' as camada
-- from shared_state s, jsonb_array_elements(coalesce(s.team,'[]'::jsonb)) e
-- where s.id = 1
--   and (s.camadas -> (e->>'accessLevel') ->> 'podeVerTarefasPessoais')::boolean is true;

-- REVERTER (volta a "toda a gente le tudo"):
-- drop policy if exists "bsp_drive_ler" on storage.objects;
-- create policy "bsp_drive_ler" on storage.objects for select
--   to authenticated using (bucket_id = 'drive');
