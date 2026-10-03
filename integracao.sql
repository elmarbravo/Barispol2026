-- Integração de novos colaboradores (03-10-2026, RI-2.2 acolhimento e
-- integração; RI-2.3 período experimental; RI-2.4 descritivo de funções).
--
-- integracao_modelo: os passos padrão e o prazo de cada um em dias desde a
-- entrada. Preenchido no servidor a partir do resumo do regulamento
-- (public.conhecimento, 'regulamento-interno'): os números do RI não se
-- copiam para o repositório. A gestão pode mudar o modelo.
-- integracoes / integracao_passos: um plano por pessoa nova, copiado do
-- modelo por bsp_integracao_iniciar(pessoa, entrada, superior). Cada passo
-- tem quem o faz (DCH, Superior, Colaborador), prazo e «feito».
-- Lêem: a gestão, a própria pessoa e o superior / chefe da área
-- (bsp_chefe_de). Marcam feito: a gestão, o superior; a pessoa os seus.
-- Avisos (novidades): no dia do prazo e com 3 dias de atraso.

create table if not exists public.integracao_modelo (
  id bigint generated always as identity primary key,
  ordem int not null,
  etapa text not null,
  passo text not null,
  dias int not null default 0,
  quem text not null default 'DCH' check (quem in ('DCH', 'Superior', 'Colaborador')),
  referencia text not null default ''
);
alter table public.integracao_modelo enable row level security;

create table if not exists public.integracoes (
  id bigint generated always as identity primary key,
  user_id text not null,
  entrada date not null,
  superior text not null default '',
  estado text not null default 'Em curso' check (estado in ('Em curso', 'Concluída', 'Interrompida')),
  nota text not null default '',
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now()
);
alter table public.integracoes enable row level security;

create table if not exists public.integracao_passos (
  id bigint generated always as identity primary key,
  integracao_id bigint not null references public.integracoes (id) on delete cascade,
  ordem int not null,
  etapa text not null,
  passo text not null,
  quem text not null,
  referencia text not null default '',
  prazo date not null,
  feito_em timestamptz,
  feito_por text,
  nota text not null default ''
);
create index if not exists integracao_passos_int on public.integracao_passos (integracao_id, ordem);
alter table public.integracao_passos enable row level security;

create or replace function public.bsp_ve_integracao(p_id bigint)
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select exists (select 1 from public.integracoes i where i.id = p_id
    and (public.bsp_e_gestor() or i.user_id = public.bsp_meu_id() or i.superior = public.bsp_meu_id() or public.bsp_chefe_de(i.user_id)))
$f$;

drop policy if exists modelo_ler on public.integracao_modelo;
create policy modelo_ler on public.integracao_modelo for select to authenticated using (public.bsp_meu_id() is not null);
drop policy if exists modelo_mudar on public.integracao_modelo;
create policy modelo_mudar on public.integracao_modelo for all to authenticated
  using ((select public.bsp_e_gestor())) with check ((select public.bsp_e_gestor()));
drop policy if exists integracoes_ler on public.integracoes;
create policy integracoes_ler on public.integracoes for select to authenticated using (public.bsp_ve_integracao(id));
drop policy if exists integracoes_mudar on public.integracoes;
create policy integracoes_mudar on public.integracoes for update to authenticated
  using ((select public.bsp_e_gestor()) or superior = (select public.bsp_meu_id()))
  with check ((select public.bsp_e_gestor()) or superior = (select public.bsp_meu_id()));
drop policy if exists passos_ler on public.integracao_passos;
create policy passos_ler on public.integracao_passos for select to authenticated using (public.bsp_ve_integracao(integracao_id));

-- Marcar um passo feito (ou desfazer): quem pode, e só isso.
create or replace function public.bsp_integracao_passo(p_id bigint, p_feito boolean, p_nota text default null)
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
declare p record; i record; eu text := public.bsp_meu_id();
begin
  select * into p from public.integracao_passos where id = p_id;
  if p is null then return false; end if;
  select * into i from public.integracoes where id = p.integracao_id;
  if not (public.bsp_e_gestor() or i.superior = eu or public.bsp_chefe_de(i.user_id)
          or (i.user_id = eu and p.quem = 'Colaborador')) then
    raise exception 'Este passo não é seu.';
  end if;
  update public.integracao_passos set feito_em = case when p_feito then now() end, feito_por = case when p_feito then eu end,
         nota = coalesce(p_nota, nota) where id = p_id;
  if not exists (select 1 from public.integracao_passos where integracao_id = i.id and feito_em is null) then
    update public.integracoes set estado = 'Concluída' where id = i.id and estado = 'Em curso';
  elsif i.estado = 'Concluída' then
    update public.integracoes set estado = 'Em curso' where id = i.id;
  end if;
  return true;
end $f$;

create or replace function public.bsp_integracao_iniciar(p_user text, p_entrada date, p_superior text default '')
returns bigint language plpgsql security definer set search_path to 'public'
as $f$
declare nid bigint;
begin
  if not public.bsp_e_gestor() then raise exception 'Só a gestão inicia a integração.'; end if;
  if exists (select 1 from public.integracoes where user_id = p_user and estado = 'Em curso') then
    raise exception 'Esta pessoa já tem uma integração em curso.';
  end if;
  insert into public.integracoes (user_id, entrada, superior) values (p_user, p_entrada, coalesce(p_superior, '')) returning id into nid;
  insert into public.integracao_passos (integracao_id, ordem, etapa, passo, quem, referencia, prazo)
  select nid, m.ordem, m.etapa, m.passo, m.quem, m.referencia, p_entrada + m.dias from public.integracao_modelo m order by m.ordem;
  insert into public.novidades (titulo, texto, grupos, destino)
  values ('Integração iniciada', 'Começou o plano de integração de ' || coalesce((select e->>'name' from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = p_user limit 1), 'um novo colaborador')
          || ', com entrada a ' || to_char(p_entrada, 'DD-MM-YYYY') || '. Veja os passos em Equipa → Integração.',
          array['gestao', p_user] || case when coalesce(p_superior, '') <> '' then array[p_superior] else '{}' end, 'directory');
  return nid;
end $f$;

create or replace function public.bsp_integracao_alertar()
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare r record; n int := 0;
begin
  -- Um aviso por pessoa e por dia, com a lista dos passos.
  for r in
    select i.id, i.user_id, i.superior, current_date - p.prazo atraso,
           (select e->>'name' from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = i.user_id limit 1) nome,
           string_agg(p.passo || ' (' || p.quem || ')', '; ' order by p.ordem) passos,
           bool_or(p.quem = 'Colaborador') do_colaborador
      from public.integracao_passos p join public.integracoes i on i.id = p.integracao_id
     where i.estado = 'Em curso' and p.feito_em is null and current_date - p.prazo in (0, 3)
     group by i.id, i.user_id, i.superior, current_date - p.prazo
  loop
    insert into public.novidades (titulo, texto, grupos, destino)
    values (case when r.atraso = 0 then 'Integração: passos para hoje' else 'Integração: passos em atraso' end,
            coalesce(r.nome, 'Novo colaborador') || ' · ' || r.passos || '.',
            array['gestao'] || case when r.do_colaborador then array[r.user_id] else '{}' end
                            || case when r.superior <> '' then array[r.superior] else '{}' end, 'directory');
    n := n + 1;
  end loop;
  return n;
end $f$;

do $$ begin
  revoke execute on function public.bsp_integracao_alertar() from public, anon, authenticated;
  revoke execute on function public.bsp_ve_integracao(bigint) from public, anon;
  revoke execute on function public.bsp_integracao_passo(bigint, boolean, text) from public, anon;
  revoke execute on function public.bsp_integracao_iniciar(text, date, text) from public, anon;
  grant execute on function public.bsp_ve_integracao(bigint) to authenticated;
  grant execute on function public.bsp_integracao_passo(bigint, boolean, text) to authenticated;
  grant execute on function public.bsp_integracao_iniciar(text, date, text) to authenticated;
end $$;
select cron.schedule('bsp-integracao', '55 3 * * *', 'select public.bsp_integracao_alertar();');
