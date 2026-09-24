-- Barispol Workspace · Direccao e Coordenacao vem e delegam tarefas
-- Pedido do Elmar, 24-09-2026. Aplicado no servidor no mesmo dia.
-- Pode correr-se mais do que uma vez.
--
-- As tarefas pessoais (tarefas_pessoais) eram so do dono: nem a Direccao
-- as via. Agora quem esta numa camada com «ver tarefas pessoais» (por
-- omissao, Direccao e Coordenacao) ve as de todos, e pode criar uma
-- tarefa na lista de outra pessoa — delegar. Os restantes colegas
-- continuam a ver so as suas.

-- Quem delegou. Fica o id de quem criou; se for diferente do dono, a
-- tarefa foi delegada.
alter table tarefas_pessoais add column if not exists criada_por text default bsp_meu_id();

-- A mesma forma da bsp_e_gestor: a camada da pessoa, lida nas camadas
-- gravadas; sem esse campo, Direccao e Coordenacao.
create or replace function public.bsp_ve_tarefas_pessoais()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $$
  select exists (
    select 1
    from shared_state s,
         jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
    where s.id = 1
      and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email', ''))
      and coalesce(
            (s.camadas -> (e->>'accessLevel') ->> 'podeVerTarefasPessoais')::boolean,
            (e->>'accessLevel') in ('Direcção', 'Coordenação')
          )
  )
$$;
revoke all on function public.bsp_ve_tarefas_pessoais() from public, anon;
grant execute on function public.bsp_ve_tarefas_pessoais() to authenticated;

drop policy if exists "bsp_tp_ler"    on tarefas_pessoais;
drop policy if exists "bsp_tp_criar"  on tarefas_pessoais;
drop policy if exists "bsp_tp_mudar"  on tarefas_pessoais;
drop policy if exists "bsp_tp_apagar" on tarefas_pessoais;

create policy "bsp_tp_ler" on tarefas_pessoais for select
  to authenticated using (user_id = bsp_meu_id() or bsp_ve_tarefas_pessoais());
create policy "bsp_tp_criar" on tarefas_pessoais for insert
  to authenticated with check (
    (user_id = bsp_meu_id() or bsp_ve_tarefas_pessoais())
    and coalesce(criada_por, bsp_meu_id()) = bsp_meu_id()
  );
create policy "bsp_tp_mudar" on tarefas_pessoais for update
  to authenticated using (user_id = bsp_meu_id() or bsp_ve_tarefas_pessoais())
  with check (user_id = bsp_meu_id() or bsp_ve_tarefas_pessoais());
create policy "bsp_tp_apagar" on tarefas_pessoais for delete
  to authenticated using (user_id = bsp_meu_id() or bsp_ve_tarefas_pessoais());

-- As camadas gravadas passam a dizer o mesmo que o servidor faz.
update shared_state s set camadas = (
  select jsonb_object_agg(k, v || jsonb_build_object('podeVerTarefasPessoais', k in ('Direcção', 'Coordenação')))
  from jsonb_each(s.camadas) as x(k, v)
)
where id = 1 and s.camadas is not null and s.camadas <> '{}'::jsonb;

notify pgrst, 'reload schema';

-- CONFERIR
select policyname, cmd from pg_policies where tablename = 'tarefas_pessoais' order by 1;
