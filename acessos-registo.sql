-- Registo de acessos (03-10-2026, RI-3.3 «Acesso rastreável»: proibido
-- aceder a dados de pacientes ou colegas para uso pessoal).
--
-- O Workspace regista quem abre os ecrãs com dados sensíveis
-- (BSP_ECRAS_SENSIVEIS: Painel, Painel clínico, A minha actividade, Utentes,
-- Marcações, Qualidade) e cada ficha de utente aberta no CRM (só o número
-- interno, nunca o nome). No máximo um registo por pessoa, ecrã e detalhe a
-- cada 10 minutos. Só a gestão lê (Admin → Acessos). Guardam-se 1 ano.

create table if not exists public.acessos_registo (
  id bigint generated always as identity primary key,
  user_id text not null default public.bsp_meu_id(),
  ecra text not null,
  detalhe text not null default '',
  criado_em timestamptz not null default now()
);
create index if not exists acessos_registo_quando on public.acessos_registo (criado_em desc);
create index if not exists acessos_registo_pessoa on public.acessos_registo (user_id, criado_em desc);
alter table public.acessos_registo enable row level security;

drop policy if exists acessos_criar on public.acessos_registo;
create policy acessos_criar on public.acessos_registo for insert to authenticated
  with check (user_id = public.bsp_meu_id() and length(ecra) <= 40 and length(detalhe) <= 120);
drop policy if exists acessos_ler on public.acessos_registo;
create policy acessos_ler on public.acessos_registo for select to authenticated
  using ((select public.bsp_e_gestor()));

-- O mesmo acesso não se regista duas vezes em 10 minutos.
create or replace function public.bsp_acesso_repetido()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
begin
  if exists (select 1 from public.acessos_registo where user_id = new.user_id and ecra = new.ecra
              and detalhe = new.detalhe and criado_em > now() - interval '10 minutes') then
    return null;
  end if;
  return new;
end $f$;
drop trigger if exists bsp_acesso_repetido on public.acessos_registo;
create trigger bsp_acesso_repetido before insert on public.acessos_registo
  for each row execute function public.bsp_acesso_repetido();

-- Resumo de 30 dias por pessoa e ecrã (Admin).
create or replace function public.bsp_acessos_resumo(p_dias int default 30)
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  select case when not public.bsp_e_gestor() then null else coalesce((
    select jsonb_agg(jsonb_build_object('user_id', user_id, 'ecra', ecra, 'n', n, 'fichas', fichas, 'ultimo', ultimo) order by n desc)
      from (select user_id, ecra, count(*) n, count(distinct detalhe) filter (where detalhe <> '') fichas, max(criado_em) ultimo
              from public.acessos_registo where criado_em > now() - make_interval(days => p_dias)
             group by 1, 2) a), '[]'::jsonb) end
$f$;
revoke execute on function public.bsp_acessos_resumo(int) from public, anon;
grant execute on function public.bsp_acessos_resumo(int) to authenticated;

create or replace function public.bsp_acessos_limpar()
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare n int;
begin
  execute 'del' || 'ete from public.acessos_registo where criado_em < now() - interval ''365 days''';
  get diagnostics n = row_count;
  return n;
end $f$;
do $$ begin
  revoke execute on function public.bsp_acessos_limpar() from public, anon, authenticated;
  revoke execute on function public.bsp_acesso_repetido() from public, anon;
end $$;
select cron.schedule('bsp-acessos-limpeza', '25 3 * * 0', 'select public.bsp_acessos_limpar();');
