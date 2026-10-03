-- Avaliação de desempenho anual (03-10-2026, Elmar; RI-5.3 e nota interna
-- BRSP-DG-NINT-24-001, avaliação de produtividade e assiduidade).
--
-- avaliacao_modelo: os factores do formulário «Avaliação de Desempenho –
-- Barispol 2026» (Assiduidade, Disciplina, Iniciativa, Produtividade,
-- Responsabilidade, Requisitos do descritivo de funções), cada um com as
-- opções A (Excelente) a D (Insatisfatório). O texto do formulário é um
-- documento interno: preenche-se só no servidor, nunca no repositório.
-- avaliacoes_desempenho: uma por pessoa e por ano. Rascunho → Concluída →
-- Tomou conhecimento (a pessoa lê e pode comentar).
-- desempenho_historico: produtividade e assiduidade por pessoa e por mês,
-- importadas dos ficheiros dos RH (pedido à Arlete, 03-10-2026).
-- Quem avalia: a gestão e o superior / chefe da área (bsp_chefe_de), nunca
-- a própria pessoa. A pessoa vê a sua avaliação depois de concluída.
-- Escrita só pelas funções bsp_avaliacao_gravar / bsp_avaliacao_conhecimento.

create table if not exists public.avaliacao_modelo (
  id bigint generated always as identity primary key,
  ordem int not null,
  chave text not null unique,
  nome text not null,
  descricao text not null default '',
  opcoes jsonb not null default '[]'
);
alter table public.avaliacao_modelo enable row level security;

create table if not exists public.avaliacoes_desempenho (
  id bigint generated always as identity primary key,
  user_id text not null,
  ano int not null,
  avaliador text not null,
  factores jsonb not null default '{}',
  aprovada boolean,
  comentarios text not null default '',
  estado text not null default 'Rascunho' check (estado in ('Rascunho', 'Concluída', 'Tomou conhecimento')),
  comentario_colaborador text not null default '',
  criado_em timestamptz not null default now(),
  actualizado_em timestamptz not null default now(),
  concluida_em timestamptz,
  conhecimento_em timestamptz,
  unique (user_id, ano)
);
alter table public.avaliacoes_desempenho enable row level security;

create table if not exists public.desempenho_historico (
  user_id text not null,
  ano int not null,
  mes int not null check (mes between 1 and 12),
  produtividade_pc numeric,
  classificacao text not null default '',
  faltas_justificadas numeric,
  faltas_injustificadas numeric,
  atrasos int,
  subsidio_assiduidade boolean,
  fonte text not null default '',
  importado_em timestamptz not null default now(),
  primary key (user_id, ano, mes)
);
alter table public.desempenho_historico enable row level security;

create or replace function public.bsp_avalia(p_user text)
returns boolean language sql stable security definer set search_path to 'public'
as $f$ select p_user is distinct from public.bsp_meu_id() and (coalesce(public.bsp_e_gestor(), false) or coalesce(public.bsp_chefe_de(p_user), false)) $f$;

create policy aval_modelo_ler on public.avaliacao_modelo for select to authenticated using (public.bsp_meu_id() is not null);
create policy aval_ler on public.avaliacoes_desempenho for select to authenticated
  using (public.bsp_avalia(user_id) or (user_id = (select public.bsp_meu_id()) and estado <> 'Rascunho'));
create policy hist_ler on public.desempenho_historico for select to authenticated
  using (public.bsp_avalia(user_id) or user_id = (select public.bsp_meu_id()));

create or replace function public.bsp_avaliacao_gravar(p_user text, p_ano int, p_factores jsonb, p_aprovada boolean, p_comentarios text, p_concluir boolean default false)
returns bigint language plpgsql security definer set search_path to 'public'
as $f$
declare a record; nid bigint; faltam int;
begin
  if not public.bsp_avalia(p_user) then raise exception 'Só a gestão e o superior avaliam (e ninguém se avalia a si próprio).'; end if;
  select * into a from public.avaliacoes_desempenho where user_id = p_user and ano = p_ano;
  if a.id is not null and a.estado <> 'Rascunho' and not public.bsp_e_gestor() then
    raise exception 'Esta avaliação já foi concluída. Só a gestão a pode alterar.';
  end if;
  if p_concluir then
    select count(*) into faltam from public.avaliacao_modelo m
     where coalesce(p_factores->>m.chave, '') not in ('A', 'B', 'C', 'D');
    if faltam > 0 or p_aprovada is null then raise exception 'Para concluir, classifique todos os factores e diga se a avaliação é aprovada.'; end if;
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
end $f$;

create or replace function public.bsp_avaliacao_conhecimento(p_id bigint, p_comentario text default '')
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
begin
  update public.avaliacoes_desempenho
     set estado = 'Tomou conhecimento', conhecimento_em = now(), comentario_colaborador = left(coalesce(p_comentario, ''), 2000)
   where id = p_id and user_id = public.bsp_meu_id() and estado = 'Concluída';
  return found;
end $f$;

-- Dados de apoio ao avaliador: ausências do ano (aprovadas, por tipo, em
-- dias), formações e o histórico mensal importado dos RH.
create or replace function public.bsp_avaliacao_apoio(p_user text, p_ano int)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare de date := make_date(p_ano, 1, 1); ate date := make_date(p_ano, 12, 31);
begin
  if not (public.bsp_avalia(p_user) or p_user = public.bsp_meu_id()) then raise exception 'Sem acesso.'; end if;
  return jsonb_build_object(
    'ausencias', (select coalesce(jsonb_object_agg(tipo, dias), '{}') from (
        select tipo, sum(least(fim, ate) - greatest(inicio, de) + 1) dias from public.ausencias
         where user_id = p_user and estado = 'Aprovado' and inicio <= ate and fim >= de group by tipo) x),
    'formacoes', (select jsonb_build_object('n', count(*), 'horas', coalesce(sum(horas), 0)) from public.formacoes where user_id = p_user and data between de and ate),
    'historico', (select coalesce(jsonb_agg(to_jsonb(h) - 'user_id' - 'importado_em' order by mes), '[]') from public.desempenho_historico h where user_id = p_user and ano = p_ano),
    'historico_resumo', (select jsonb_build_object('meses', count(*), 'produtividade_media', round(avg(produtividade_pc), 1),
         'faltas_injustificadas', sum(faltas_injustificadas), 'faltas_justificadas', sum(faltas_justificadas), 'atrasos', sum(atrasos),
         'meses_sem_subsidio', count(*) filter (where subsidio_assiduidade = false))
       from public.desempenho_historico where user_id = p_user and ano = p_ano)
  );
end $f$;

do $$ begin
  revoke execute on function public.bsp_avalia(text) from public, anon;
  revoke execute on function public.bsp_avaliacao_gravar(text, int, jsonb, boolean, text, boolean) from public, anon;
  revoke execute on function public.bsp_avaliacao_conhecimento(bigint, text) from public, anon;
  revoke execute on function public.bsp_avaliacao_apoio(text, int) from public, anon;
  grant execute on function public.bsp_avalia(text) to authenticated;
  grant execute on function public.bsp_avaliacao_gravar(text, int, jsonb, boolean, text, boolean) to authenticated;
  grant execute on function public.bsp_avaliacao_conhecimento(bigint, text) to authenticated;
  grant execute on function public.bsp_avaliacao_apoio(text, int) to authenticated;
end $$;

-- O modelo (6 factores, opções A–D) preenche-se no servidor a partir do
-- formulário dos RH, pasta BRSP_RH_AVALIAÇÃO DE DESEMPENHO.
