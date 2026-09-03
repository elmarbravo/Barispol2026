-- Barispol Workspace · editar mensagens
-- Correr UMA vez no SQL Editor. Pode repetir sem estragar nada.
-- NAO HA NADA PARA PREENCHER.
--
-- PORQUE: as mensagens tinham regras para ler, criar e apagar — e nenhuma
-- para alterar. Sem esta, "editar" nao dava erro: o servidor recusava em
-- silencio, zero linhas alteradas, e o ecra ficava a mostrar um texto que
-- so existia naquele aparelho.
--
-- So o autor altera a sua mensagem. Nem a Direccao altera a de outra
-- pessoa: quem pode APAGAR nao e a mesma coisa que quem pode REESCREVER,
-- e reescrever o que outra pessoa disse e a pior das duas.

do $$
begin
  if to_regprocedure('public.bsp_meu_id()') is null then
    raise exception 'Falta correr primeiro o INSTALAR-TUDO.sql.';
  end if;
end $$;

drop policy if exists "bsp_msg_editar" on messages;
create policy "bsp_msg_editar" on messages for update
  to authenticated
  using (user_id = bsp_meu_id())
  with check (user_id = bsp_meu_id());

-- Conferir: devem aparecer quatro regras — ler, criar, editar, apagar.
select policyname as regra, cmd as para
from pg_policies
where schemaname = 'public' and tablename = 'messages'
order by 2, 1;
