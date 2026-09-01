-- Barispol Workspace · pastas na area pessoal do Drive
-- Correr UMA vez no SQL Editor, DEPOIS do ficheiros-pessoais.sql.
-- Pode repetir sem estragar nada. Nao apaga nem altera nenhum ficheiro.
--
-- PORQUE: a area pessoal era uma lista corrida. Com dezenas de ficheiros
-- deixa de servir para nada. Passa a ter pastas, como qualquer Drive.
--
-- Uma pasta e uma linha como as outras, com "e_pasta" a true e sem
-- caminho no armazenamento: assim herda as MESMAS regras de seguranca dos
-- ficheiros, sem uma segunda tabela e sem uma segunda fechadura para
-- manter em dia. A coluna "pasta" diz onde cada coisa esta — vazia para a
-- raiz, ou "Exames" ou "Exames/2026".

-- 0. Verificar que o ficheiros-pessoais.sql ja correu.
do $$
begin
  if to_regclass('public.ficheiros_pessoais') is null then
    raise exception 'Falta correr primeiro o ficheiros-pessoais.sql.';
  end if;
end $$;

-- 1. Onde cada coisa esta, e se e pasta.
alter table ficheiros_pessoais add column if not exists pasta text not null default '';
alter table ficheiros_pessoais add column if not exists e_pasta boolean not null default false;

-- Uma pasta nao tem bytes no armazenamento. A coluna era obrigatoria.
alter table ficheiros_pessoais alter column caminho drop not null;

create index if not exists ficheiros_pessoais_pasta
  on ficheiros_pessoais (user_id, pasta, e_pasta);

-- 2. Faltava a regra de ALTERAR. Sem ela, mudar de pasta ou mudar o nome
--    nao dava erro nenhum: o servidor recusava em silencio e o ecra
--    ficava a mostrar uma coisa que nao aconteceu.
drop policy if exists "bsp_fp_editar" on ficheiros_pessoais;

create policy "bsp_fp_editar" on ficheiros_pessoais for update
  to authenticated
  using (user_id = bsp_meu_id())
  with check (user_id = bsp_meu_id());

-- Ver nao e mexer: quem le as pessoais de todos continua a nao poder
-- alterar nem apagar as de outra pessoa.

-- 3. Conferir. Devem aparecer as quatro regras: ler, criar, editar, apagar.
select policyname as regra, cmd as para
from pg_policies
where schemaname = 'public' and tablename = 'ficheiros_pessoais'
order by 1;

-- E as colunas novas.
select column_name as coluna, data_type as tipo
from information_schema.columns
where table_schema = 'public' and table_name = 'ficheiros_pessoais'
  and column_name in ('pasta', 'e_pasta')
order by 1;
