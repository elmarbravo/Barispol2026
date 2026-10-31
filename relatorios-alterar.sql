-- Relatórios de turno: colegas da área lêem; alterar só com autorização
-- (31-10-2026).
--
-- Elmar, 31-10-2026, sobre a pergunta da Gizela («como é que eu vejo os
-- relatórios enviados pelas minhas colegas?»): «com isso também» (colegas da
-- mesma área e chefe da área lêem os relatórios da área) e «cada um editar o
-- seu relatório, mas com permissão. Edita, fica em rascunho com autorização do
-- superior … o director clínico é que autoriza a alteração do relatório».
--
-- 1. Quem lê (bsp_rel_ler): o próprio, a gestão, a Direcção Clínica nas áreas
--    médicas, e agora os colegas da mesma área e o chefe de quem entregou
--    (bsp_chefe_de). Os anexos seguem a mesma regra (bsp_drive_ler, relatorio/).
--    Só leitura: ninguém muda o relatório de outra pessoa.
-- 2. Quem muda (bsp_rel_mudar): só a gestão, directamente. Quem entregou pede a
--    alteração com motivo (bsp_relatorio_alteracao_pedir); fica «Pendente» em
--    relatorios_alteracoes até quem autoriza decidir
--    (bsp_relatorio_alteracao_decidir). Autoriza:
--      · Laboratório, Imagiologia e Enfermagem: a Direcção Clínica (u14);
--      · as outras áreas: o superior de quem entregou (bsp_aprovador_de);
--      · a gestão (bsp_e_gestor) pode sempre.
--    O pedido leva uma observação obrigatória (motivo, mensagem para quem
--    autoriza); a decisão leva uma resposta obrigatória (nota), que segue para
--    quem pediu. Mínimo de 10 letras nas duas (BSP_REL_ALT_MIN no ecrã).
--    Ao autorizar, as respostas novas entram no relatório; as antigas ficam
--    guardadas no pedido (respostas_antes). Nada se apaga.
-- 3. Avisos: no telemóvel de quem autoriza ao pedir; no de quem pediu ao decidir.
--
-- Sem a palavra que apaga objectos: só create or replace e alter policy.

-- Área do relatório de uma pessoa: a mesma regra do ecrã (bspAreaDe).
create or replace function public.bsp_rel_area_de(p_user text)
returns text
language sql
stable security definer
set search_path to 'public'
as $$
  select case
    when x ~ '(laborat|analista)' then 'laboratorio'
    when x ~ 'farmac' then 'farmacia'
    when x ~ 'enferm' then 'enfermagem'
    when x ~ '(radiolog|raio|ecograf|imagiolog)' then 'imagiologia'
    when x ~ '(recep|caixa)' then 'rececao'
  end
  from (
    select translate(lower(coalesce(e->>'role', '') || ' ' || coalesce(e->>'dept', '')),
                     'áàâãéêíóôõúç', 'aaaaeeiooouc') as x
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
    where s.id = 1 and e->>'id' = p_user
    limit 1
  ) q
$$;
revoke all on function public.bsp_rel_area_de(text) from public, anon;
grant execute on function public.bsp_rel_area_de(text) to authenticated;

-- 1. Ler: colegas da área e chefe de quem entregou.
alter policy "bsp_rel_ler" on relatorios_area
  using (
    user_id = bsp_meu_id()
    or bsp_e_gestor()
    or (area in ('laboratorio', 'imagiologia', 'enfermagem') and bsp_le_areas_medicas())
    or area = bsp_rel_area_de(bsp_meu_id())
    or bsp_chefe_de(user_id)
  );

-- Anexos dos relatórios (relatorio/<área>/<autor>/…): a mesma regra.
alter policy bsp_drive_ler on storage.objects using (
  (not public.bsp_e_socio()) and bucket_id = 'drive' and (
    (name not like 'privado/%' and name not like 'conversa/%' and name not like 'relatorio/%')
    or (name like 'privado/%' and (split_part(name, '/', 2) = public.bsp_meu_id() or public.bsp_ve_pessoais_de_todos()))
    or (name like 'conversa/%' and public.bsp_ve_conversa(split_part(name, '/', 2)))
    or (name like 'relatorio/%' and (
          split_part(name, '/', 3) = public.bsp_meu_id()
          or public.bsp_e_gestor()
          or (split_part(name, '/', 2) in ('laboratorio', 'imagiologia', 'enfermagem') and public.bsp_le_areas_medicas())
          or split_part(name, '/', 2) = public.bsp_rel_area_de(public.bsp_meu_id())
          or public.bsp_chefe_de(split_part(name, '/', 3))))
  ));

-- 2. Mudar directamente: só a gestão. Apagar mantém-se (o próprio, no dia).
alter policy "bsp_rel_mudar" on relatorios_area
  using (bsp_e_gestor())
  with check (bsp_e_gestor());

alter table public.relatorios_area add column if not exists alterado_em timestamptz;
alter table public.relatorios_area add column if not exists alterado_autorizou text;

create table if not exists public.relatorios_alteracoes (
  id              bigint generated always as identity primary key,
  relatorio_id    bigint not null references public.relatorios_area(id) on delete cascade,
  area            text not null,
  dia             date not null,
  user_id         text not null,
  aprovador_id    text not null,
  motivo          text not null,
  respostas_antes jsonb not null,
  respostas_novas jsonb not null,
  resumo_novo     jsonb,
  estado          text not null default 'Pendente'
                  check (estado in ('Pendente', 'Autorizada', 'Recusada', 'Cancelada')),
  decidido_por    text,
  decidido_em     timestamptz,
  nota            text,
  criado_em       timestamptz not null default now()
);
create index if not exists relatorios_alteracoes_pend on public.relatorios_alteracoes (aprovador_id) where estado = 'Pendente';
create index if not exists relatorios_alteracoes_rel on public.relatorios_alteracoes (relatorio_id);
alter table public.relatorios_alteracoes enable row level security;
-- Só se lê pelas funções; ninguém escreve na tabela directamente.
revoke all on public.relatorios_alteracoes from anon, authenticated;

-- Quem autoriza a alteração de um relatório.
create or replace function public.bsp_relatorio_autoriza(p_area text, p_user text)
returns text
language sql
stable security definer
set search_path to 'public'
as $$
  select case
    when p_area in ('laboratorio', 'imagiologia', 'enfermagem') then 'u14'
    else coalesce(nullif(public.bsp_aprovador_de(p_user), p_user), 'u1')
  end
$$;
revoke all on function public.bsp_relatorio_autoriza(text, text) from public, anon, authenticated;

-- Pedir a alteração (só quem entregou). Um pedido pendente por relatório: o
-- novo substitui o anterior (fica «Cancelada»).
create or replace function public.bsp_relatorio_alteracao_pedir(p_relatorio bigint, p_respostas jsonb, p_resumo jsonb, p_motivo text)
returns bigint
language plpgsql
volatile security definer
set search_path to 'public'
as $$
declare
  eu text := bsp_meu_id();
  r relatorios_area;
  quem text;
  novo bigint;
begin
  if eu is null then raise exception 'Sem sessão.'; end if;
  select * into r from relatorios_area where id = p_relatorio;
  if not found then raise exception 'Relatório não encontrado.'; end if;
  if r.user_id <> eu then raise exception 'Só quem entregou o relatório pode pedir a alteração.'; end if;
  -- Observação obrigatória (31-10-2026, Elmar: «campo de observação com motivo
  -- obrigatório … como se fosse uma mensagem para quem autoriza»).
  if length(coalesce(btrim(p_motivo), '')) < 10 then raise exception 'Escreva o motivo da alteração para quem autoriza (pelo menos 10 letras).'; end if;
  if p_respostas is null or jsonb_typeof(p_respostas) <> 'object' then raise exception 'Respostas inválidas.'; end if;
  if p_respostas = r.respostas then raise exception 'Não mudou nenhuma resposta.'; end if;
  quem := bsp_relatorio_autoriza(r.area, r.user_id);
  update relatorios_alteracoes set estado = 'Cancelada', decidido_por = eu, decidido_em = now(),
         nota = 'Substituído por um pedido novo.'
   where relatorio_id = r.id and estado = 'Pendente';
  insert into relatorios_alteracoes (relatorio_id, area, dia, user_id, aprovador_id, motivo, respostas_antes, respostas_novas, resumo_novo)
  values (r.id, r.area, r.dia, eu, quem, left(btrim(p_motivo), 1000), r.respostas, p_respostas, p_resumo)
  returning id into novo;
  begin
    perform bsp_push_post(jsonb_build_object('para', jsonb_build_array(quem),
      'titulo', 'Pedido para alterar um relatório',
      'corpo', 'Relatório de ' || to_char(r.dia, 'DD-MM') || ' (' || r.area || '). Motivo: ' || left(btrim(p_motivo), 120),
      'url', '#/relatorios', 'tag', 'relatorio-alt-' || novo));
  exception when others then raise warning 'bsp_relatorio_alteracao_pedir push: %', sqlerrm;
  end;
  return novo;
end $$;
revoke all on function public.bsp_relatorio_alteracao_pedir(bigint, jsonb, jsonb, text) from public, anon;
grant execute on function public.bsp_relatorio_alteracao_pedir(bigint, jsonb, jsonb, text) to authenticated;

-- Autorizar ou recusar (quem autoriza ou a gestão). Quem pediu também pode
-- cancelar o seu pedido (p_aprovar = null).
create or replace function public.bsp_relatorio_alteracao_decidir(p_id bigint, p_aprovar boolean, p_nota text default null)
returns text
language plpgsql
volatile security definer
set search_path to 'public'
as $$
declare
  eu text := bsp_meu_id();
  a relatorios_alteracoes;
  est text;
begin
  if eu is null then raise exception 'Sem sessão.'; end if;
  select * into a from relatorios_alteracoes where id = p_id for update;
  if not found then raise exception 'Pedido não encontrado.'; end if;
  if a.estado <> 'Pendente' then raise exception 'Este pedido já foi decidido (%).', a.estado; end if;
  if p_aprovar is null then
    if a.user_id <> eu then raise exception 'Só quem pediu pode cancelar.'; end if;
    est := 'Cancelada';
  else
    if not (a.aprovador_id = eu or bsp_e_gestor()) then raise exception 'Não pode decidir este pedido.'; end if;
    if a.user_id = eu and not bsp_e_gestor() then raise exception 'Não pode autorizar o seu próprio pedido.'; end if;
    -- Resposta obrigatória de quem autoriza, ao autorizar e ao recusar
    -- (31-10-2026, Elmar: «quem autoriza é também um campo para responder»).
    if length(coalesce(btrim(p_nota), '')) < 10 then raise exception 'Escreva a resposta para quem pediu (pelo menos 10 letras).'; end if;
    est := case when p_aprovar then 'Autorizada' else 'Recusada' end;
  end if;
  update relatorios_alteracoes set estado = est, decidido_por = eu, decidido_em = now(),
         nota = nullif(left(btrim(coalesce(p_nota, '')), 1000), '')
   where id = a.id;
  if est = 'Autorizada' then
    update relatorios_area set respostas = a.respostas_novas,
           resumo = coalesce(a.resumo_novo, resumo),
           alterado_em = now(), alterado_autorizou = eu
     where id = a.relatorio_id;
  end if;
  if est <> 'Cancelada' then
    begin
      perform bsp_push_post(jsonb_build_object('para', jsonb_build_array(a.user_id),
        'titulo', case when est = 'Autorizada' then 'Alteração do relatório autorizada' else 'Alteração do relatório recusada' end,
        'corpo', 'Relatório de ' || to_char(a.dia, 'DD-MM') || '. Resposta: ' || left(btrim(p_nota), 140),
        'url', '#/relatorios', 'tag', 'relatorio-alt-' || a.id));
    exception when others then raise warning 'bsp_relatorio_alteracao_decidir push: %', sqlerrm;
    end;
  end if;
  return est;
end $$;
revoke all on function public.bsp_relatorio_alteracao_decidir(bigint, boolean, text) from public, anon;
grant execute on function public.bsp_relatorio_alteracao_decidir(bigint, boolean, text) to authenticated;

-- Os pedidos que me tocam: os que tenho de decidir (pendentes) e os meus dos
-- últimos 30 dias. A gestão vê todos os pendentes.
create or replace function public.bsp_relatorio_alteracoes()
returns setof public.relatorios_alteracoes
language sql
stable security definer
set search_path to 'public'
as $$
  select * from relatorios_alteracoes a
   where (a.estado = 'Pendente' and (a.aprovador_id = bsp_meu_id() or bsp_e_gestor()))
      or (a.user_id = bsp_meu_id() and a.criado_em > now() - interval '30 days')
   order by (a.estado = 'Pendente') desc, a.criado_em desc
   limit 200
$$;
revoke all on function public.bsp_relatorio_alteracoes() from public, anon;
grant execute on function public.bsp_relatorio_alteracoes() to authenticated;

notify pgrst, 'reload schema';

select policyname, cmd from pg_policies where tablename = 'relatorios_area' order by 1;
