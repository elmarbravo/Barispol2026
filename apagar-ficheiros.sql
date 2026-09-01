-- Barispol Workspace · quem pode apagar no Drive da equipa
-- Correr UMA vez no SQL Editor, DEPOIS do ficheiros-pessoais.sql.
-- Pode repetir sem estragar nada. Nao apaga nem altera nenhum ficheiro.
--
-- PORQUE: no Drive da equipa, qualquer pessoa com sessao iniciada podia
-- apagar o que outra tivesse carregado. Passa a ser de quem carregou, e
-- das camadas a que se der a permissao "Apagar ficheiros da equipa" em
-- Admin -> Permissoes.
--
-- E uma permissao da camada e nao um nome de pessoa escrito no codigo:
-- pessoas mudam de funcao e saem, e um nome fixo aqui ficaria errado sem
-- ninguem dar por isso.
--
-- COMO: os ficheiros novos passam a ser guardados em
--   equipa/<id de quem carregou>/...
-- e e o caminho que diz ao servidor de quem eles sao.
--
-- HONESTAMENTE: os ficheiros que ja la estao NAO tem esse prefixo — nao
-- ha no armazenamento nada que diga quem os carregou. Nesses, a regra e
-- so a do ecra: o botao de apagar nao aparece a quem nao deve, mas o
-- servidor nao o pode impedir. Vale para os que existem hoje; a partir de
-- agora, todos os novos ficam protegidos dos dois lados.

do $$
begin
  if to_regprocedure('public.bsp_ve_conversa(text)') is null then
    raise exception 'Falta correr primeiro o INSTALAR-TUDO.sql.';
  end if;
  if to_regprocedure('public.bsp_ve_pessoais_de_todos()') is null then
    raise exception 'Falta correr primeiro o ficheiros-pessoais.sql.';
  end if;
end $$;

-- 1. A permissao, lida da camada.
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

-- 2. As regras do armazenamento, agora com a gaveta da equipa.
drop policy if exists "bsp_drive_ler" on storage.objects;
drop policy if exists "bsp_drive_criar" on storage.objects;
drop policy if exists "bsp_drive_apagar" on storage.objects;

-- Ler continua igual: o que e da equipa e da equipa.
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
      -- ficheiros anteriores a esta regra: nada no armazenamento diz de
      -- quem sao, por isso ficam pela regra do ecra
      (name not like 'privado/%' and name not like 'conversa/%' and name not like 'equipa/%')
      -- pessoal: so o dono, mesmo para quem le os de todos
      or (name like 'privado/%' and split_part(name, '/', 2) = bsp_meu_id())
      -- da equipa: quem carregou, ou quem tiver a permissao
      or (name like 'equipa/%' and (
            split_part(name, '/', 2) = bsp_meu_id()
            or bsp_pode_apagar_ficheiros()
          ))
      -- anexos: segue a regra da conversa
      or (name like 'conversa/%' and bsp_ve_conversa(split_part(name, '/', 2)))
    )
  );

-- 3. Conferir quem passa a poder apagar o que os outros carregaram.
--    Se aparecer alguem a mais, tire-lhe a permissao em Admin -> Permissoes.
select e->>'name' as pessoa, e->>'accessLevel' as camada
from shared_state s, jsonb_array_elements(coalesce(s.team,'[]'::jsonb)) e
where s.id = 1
  and (s.camadas -> (e->>'accessLevel') ->> 'podeApagarFicheiros')::boolean is true
order by 1;

-- E as tres regras do armazenamento.
select policyname as regra, cmd as para
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and policyname like 'bsp_drive_%'
order by 1;
