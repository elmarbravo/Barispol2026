-- Barispol Workspace · assistente com IA (Claude Haiku 4.5)
-- Pedido do Elmar, 01-10-2026: o modelo mais barato, com um limite por
-- pessoa como o do ChatGPT gratuito. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- Limite: 10 perguntas a cada 5 horas por pessoa (janela que corre).
-- Cada pergunta respondida fica em assistente_uso, com os tokens gastos.
-- A Edge Function `assistente` grava (chave do servidor); cada pessoa só
-- lê o seu uso; a gestão lê tudo (para ver o custo).

create table if not exists public.assistente_uso (
  id bigint generated always as identity primary key,
  user_id text not null,
  criado_em timestamptz not null default now(),
  tokens_entrada integer not null default 0,
  tokens_saida integer not null default 0
);
create index if not exists assistente_uso_quem on public.assistente_uso (user_id, criado_em desc);
alter table public.assistente_uso enable row level security;
drop policy if exists assistente_uso_ler on public.assistente_uso;
create policy assistente_uso_ler on public.assistente_uso for select to authenticated
  using (user_id = public.bsp_meu_id() or public.bsp_e_gestor());
revoke insert, update, delete on public.assistente_uso from anon, authenticated;

-- Quantas perguntas restam a uma pessoa e quando volta a ter mais.
create or replace function public.bsp_assistente_quota(p_user text default null)
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $function$
  with quem as (select coalesce(case when auth.role() = 'service_role' then p_user end, public.bsp_meu_id()) id),
  usadas as (
    select criado_em from public.assistente_uso, quem
     where user_id = quem.id and criado_em > now() - interval '5 hours'
  )
  select jsonb_build_object(
    'limite', 10,
    'horas', 5,
    'usadas', (select count(*) from usadas),
    'restantes', greatest(0, 10 - (select count(*) from usadas)),
    'proxima', case when (select count(*) from usadas) >= 10
                    then (select min(criado_em) + interval '5 hours' from usadas) end)
$function$;
grant execute on function public.bsp_assistente_quota(text) to authenticated, service_role;

notify pgrst, 'reload schema';
