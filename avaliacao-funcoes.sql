-- Avaliação de desempenho com critérios da função (21-10-2026, Elmar: «A
-- avaliação do workspace está muito básica, sugiro que se adicione mais
-- critérios de avaliação relacionados à função que cada um exerce»).
-- Os 6 factores do formulário dos RH ficam (gerais). Junta-se:
-- - critérios gerais novos (familias nulo: todos);
-- - critérios da área (familias = chave de bsp_area_chave: clinica,
--   enfermagem, laboratorio, farmacia, radiologia, recepcao, administracao,
--   'servicos gerais');
-- - critérios de chefia (familias = {chefia}: cargo com chefe, supervisor,
--   director ou coordenador).
-- Cada pessoa é avaliada nos gerais, nos da sua área e, se chefiar, nos de
-- chefia (bsp_avaliacao_familias). Para concluir têm de estar todos
-- classificados. As avaliações já concluídas não mudam.
-- O texto dos critérios (nome, descrição, opções A–D) entra só no servidor,
-- como o do formulário dos RH (avaliacao-desempenho.sql); aqui só a estrutura.

alter table public.avaliacao_modelo add column if not exists familias text[];
alter table public.avaliacao_modelo add column if not exists grupo text not null default 'Geral';

create or replace function public.bsp_avaliacao_familias(p_user text)
returns text[]
language sql
stable
security definer
set search_path to 'public'
as $f$
  select array_remove(array[
           nullif(public.bsp_area_chave(e->>'dept'), ''),
           case when coalesce(e->>'role', '') ~* '(chefe|supervisor|director|coordenador)' then 'chefia' end
         ], null)
    from shared_state s, jsonb_array_elements(s.team) e
   where s.id = 1 and e->>'id' = p_user
   limit 1
$f$;
revoke all on function public.bsp_avaliacao_familias(text) from public, anon;
grant execute on function public.bsp_avaliacao_familias(text) to authenticated;

create or replace function public.bsp_avaliacao_gravar(p_user text, p_ano integer, p_factores jsonb, p_aprovada boolean, p_comentarios text, p_concluir boolean default false)
returns bigint
language plpgsql
security definer
set search_path to 'public'
as $function$
declare a record; nid bigint; faltam int; fam text[];
begin
  if not public.bsp_avalia(p_user) then raise exception 'Só a gestão e o superior avaliam (e ninguém se avalia a si próprio).'; end if;
  select * into a from public.avaliacoes_desempenho where user_id = p_user and ano = p_ano;
  if a.id is not null and a.estado <> 'Rascunho' and not public.bsp_e_gestor() then
    raise exception 'Esta avaliação já foi concluída. Só a gestão a pode alterar.';
  end if;
  if p_concluir then
    fam := coalesce(public.bsp_avaliacao_familias(p_user), '{}');
    select count(*) into faltam from public.avaliacao_modelo m
     where (m.familias is null or m.familias && fam)
       and coalesce(p_factores->>m.chave, '') not in ('A', 'B', 'C', 'D');
    if faltam > 0 or p_aprovada is null then raise exception 'Para concluir, classifique todos os critérios e diga se a avaliação é aprovada.'; end if;
  end if;
  insert into public.avaliacoes_desempenho (user_id, ano, avaliador, factores, aprovada, comentarios, estado, concluida_em)
  values (p_user, p_ano, public.bsp_meu_id(), coalesce(p_factores, '{}'), p_aprovada, coalesce(p_comentarios, ''),
          case when p_concluir then 'Concluída' else 'Rascunho' end, case when p_concluir then now() end)
  on conflict (user_id, ano) do update
     set avaliador = public.bsp_meu_id(), factores = excluded.factores, aprovada = excluded.aprovada, comentarios = excluded.comentarios,
         estado = case when p_concluir then 'Concluída' else avaliacoes_desempenho.estado end,
         concluida_em = case when p_concluir then now() else avaliacoes_desempenho.concluida_em end,
         actualizado_em = now()
  returning id into nid;
  if p_concluir then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('A sua avaliação de desempenho de ' || p_ano, 'A sua avaliação de desempenho de ' || p_ano || ' está concluída. Leia-a em Equipa → Avaliação e confirme que tomou conhecimento.', array[p_user], 'directory');
  end if;
  return nid;
end $function$;
