-- ============================================================
--  Barispol Workspace · TUDO O QUE FALTA, NUM SO FICHEIRO
--
--  NAO HA NADA PARA PREENCHER AQUI.
--  Copie tudo, cole no SQL Editor do Supabase, carregue em RUN.
--  Pode correr as vezes que quiser sem estragar nada.
--
--  O que isto traz:
--    1. Pastas na area pessoal do Drive
--    2. No Drive da equipa, so quem carregou (e quem tiver a
--       permissao) e que apaga
--
--  O agendamento do resumo matinal fica de fora, e esta no
--  agendar-resumo.sql, porque esse precisa de uma coisa que so o
--  administrador do projecto pode colar.
-- ============================================================

-- Verificar que os passos anteriores ja correram.
do $$
begin
  if to_regclass('public.ficheiros_pessoais') is null then
    raise exception 'Falta correr primeiro o ficheiros-pessoais.sql.';
  end if;
  if to_regprocedure('public.bsp_ve_conversa(text)') is null then
    raise exception 'Falta correr primeiro o INSTALAR-TUDO.sql.';
  end if;
end $$;


-- ============================================================
--  1. PASTAS NA AREA PESSOAL
-- ============================================================
-- Uma pasta e uma linha como as outras, com "e_pasta" a true e sem
-- caminho no armazenamento: assim herda as MESMAS regras de seguranca
-- dos ficheiros, sem uma segunda tabela para manter em dia.

alter table ficheiros_pessoais add column if not exists pasta text not null default '';
alter table ficheiros_pessoais add column if not exists e_pasta boolean not null default false;
alter table ficheiros_pessoais alter column caminho drop not null;

create index if not exists ficheiros_pessoais_pasta
  on ficheiros_pessoais (user_id, pasta, e_pasta);

-- Faltava a regra de ALTERAR. Sem ela, mudar de pasta ou mudar o nome
-- nao dava erro nenhum: o servidor recusava em silencio e o ecra ficava
-- a mostrar uma coisa que nao aconteceu.
drop policy if exists "bsp_fp_editar" on ficheiros_pessoais;
create policy "bsp_fp_editar" on ficheiros_pessoais for update
  to authenticated
  using (user_id = bsp_meu_id())
  with check (user_id = bsp_meu_id());


-- ============================================================
--  2. QUEM PODE APAGAR NO DRIVE DA EQUIPA
-- ============================================================
-- Ate aqui, qualquer pessoa com sessao iniciada podia apagar o que
-- outra tivesse carregado. Passa a ser de quem carregou, e das camadas
-- a que se der a permissao "Apagar ficheiros da equipa" em
-- Admin -> Permissoes.
--
-- E uma permissao da camada e nao um nome de pessoa escrito no codigo:
-- pessoas mudam de funcao e saem, e um nome fixo ficaria errado sem
-- ninguem dar por isso.
--
-- HONESTAMENTE: os ficheiros que JA LA ESTAO nao tem no armazenamento
-- nada que diga quem os carregou. Nesses, a regra e so a do ecra — o
-- botao nao aparece a quem nao deve, mas o servidor nao o pode impedir.
-- A partir de agora, todos os novos ficam protegidos dos dois lados.

create or replace function bsp_pode_apagar_ficheiros() returns boolean
language sql stable security definer set search_path = public as $f$
  select exists (
    select 1
    from shared_state s,
         jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
    where s.id = 1
      and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email', ''))
      and (s.camadas -> (e->>'accessLevel') ->> 'podeApagarFicheiros')::boolean is true
  )
$f$;

drop policy if exists "bsp_drive_ler" on storage.objects;
drop policy if exists "bsp_drive_criar" on storage.objects;
drop policy if exists "bsp_drive_apagar" on storage.objects;

-- Ler: o que e da equipa e da equipa; o pessoal e do dono; os anexos
-- seguem a regra da conversa onde foram partilhados.
create policy "bsp_drive_ler" on storage.objects for select
  to authenticated using (
    bucket_id = 'drive' and (
      (name not like 'privado/%' and name not like 'conversa/%')
      or (name like 'privado/%' and (
            split_part(name, '/', 2) = bsp_meu_id()
            or bsp_ve_pessoais_de_todos()
          ))
      or (name like 'conversa/%' and bsp_ve_conversa(split_part(name, '/', 2)))
    )
  );

-- Criar: so em meu nome nas gavetas que tem dono.
create policy "bsp_drive_criar" on storage.objects for insert
  to authenticated with check (
    bucket_id = 'drive' and (
      (name not like 'privado/%' and name not like 'conversa/%' and name not like 'equipa/%')
      or (name like 'privado/%' and split_part(name, '/', 2) = bsp_meu_id())
      or (name like 'equipa/%'  and split_part(name, '/', 2) = bsp_meu_id())
      or (name like 'conversa/%' and bsp_ve_conversa(split_part(name, '/', 2)))
    )
  );

-- Apagar: e aqui que esta a mudanca.
create policy "bsp_drive_apagar" on storage.objects for delete
  to authenticated using (
    bucket_id = 'drive' and (
      (name not like 'privado/%' and name not like 'conversa/%' and name not like 'equipa/%')
      or (name like 'privado/%' and split_part(name, '/', 2) = bsp_meu_id())
      or (name like 'equipa/%' and (
            split_part(name, '/', 2) = bsp_meu_id()
            or bsp_pode_apagar_ficheiros()
          ))
      or (name like 'conversa/%' and bsp_ve_conversa(split_part(name, '/', 2)))
    )
  );


-- ============================================================
--  CONFERIR
-- ============================================================
-- Devem aparecer as duas colunas novas e as quatro regras da tabela.
select 'coluna' as o_que, column_name as nome, '' as detalhe
from information_schema.columns
where table_schema = 'public' and table_name = 'ficheiros_pessoais'
  and column_name in ('pasta', 'e_pasta')
union all
select 'regra dos ficheiros pessoais', policyname, cmd
from pg_policies
where schemaname = 'public' and tablename = 'ficheiros_pessoais'
union all
select 'regra do armazenamento', policyname, cmd
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and policyname like 'bsp_drive_%'
order by 1, 2;
