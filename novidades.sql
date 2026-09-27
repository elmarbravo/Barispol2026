-- Barispol Workspace · novidades do sistema
-- Pedido do Elmar, 27-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- Cada actualizacao do Workspace que muda o trabalho de alguem fica aqui,
-- com os grupos a quem diz respeito. Uma vez por dia, as 05h00 de Luanda,
-- a resumo-matinal (tipo "novidades") envia um e-mail a cada pessoa desses
-- grupos com as novidades por enviar. Sem novidades, nao sai nada. O
-- Workspace mostra as mesmas novidades no sino (tipo "sistema"), a quem
-- diz respeito, depois de enviadas.
--
-- Grupos (campo grupos):
--   'todos'             toda a equipa
--   'gestao'            quem gere utilizadores (Direccao e Coordenacao)
--   'direccao-clinica'  Direccao Clinica (bsp_le_areas_medicas: u14)
--   uma area            a chave de bsp_area_chave(dept): 'recepcao',
--                       'clinica', 'enfermagem', 'laboratorio',
--                       'farmacia', 'radiologia', 'administracao',
--                       'servicos gerais'...
--   um id               'u12', para uma pessoa

create table if not exists public.novidades (
  id bigint generated always as identity primary key,
  titulo text not null,
  texto text not null,            -- paragrafos separados por linha em branco
  grupos text[] not null default array['todos'],
  destino text,                   -- ecra do Workspace: 'marcacoes', 'tarefas'...
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now(),
  enviado_em timestamptz,
  enviados integer
);
create index if not exists novidades_enviado_idx on public.novidades (enviado_em);

-- Uma pessoa da equipa (linha de shared_state.team) pertence a algum grupo?
create or replace function public.bsp_membro_nos_grupos(membro jsonb, grupos text[])
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select coalesce(membro is not null and (
       'todos' = any (grupos)
    or (membro->>'id') = any (grupos)
    or public.bsp_area_chave(membro->>'dept') = any (grupos)
    or ('direccao-clinica' = any (grupos) and (membro->>'id') = any (array['u14']))
    or ('gestao' = any (grupos) and coalesce(
          ((select s.camadas from shared_state s where s.id = 1) -> (membro->>'accessLevel') ->> 'podeGerirUtilizadores')::boolean,
          (membro->>'accessLevel') in ('Direcção', 'Coordenação')))
  ), false)
$function$;

-- A pessoa com sessao pertence aos grupos?
create or replace function public.bsp_novidade_para_mim(grupos text[])
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1
       and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email', ''))
       and public.bsp_membro_nos_grupos(e, grupos))
$function$;

alter table public.novidades enable row level security;
drop policy if exists bsp_novidades_ler on public.novidades;
create policy bsp_novidades_ler on public.novidades for select to authenticated
  using (public.bsp_e_gestor() or (enviado_em is not null and public.bsp_novidade_para_mim(grupos)));
drop policy if exists bsp_novidades_criar on public.novidades;
create policy bsp_novidades_criar on public.novidades for insert to authenticated
  with check (public.bsp_e_gestor());
drop policy if exists bsp_novidades_mudar on public.novidades;
create policy bsp_novidades_mudar on public.novidades for update to authenticated
  using (public.bsp_e_gestor() and enviado_em is null) with check (public.bsp_e_gestor());
drop policy if exists bsp_novidades_apagar on public.novidades;
create policy bsp_novidades_apagar on public.novidades for delete to authenticated
  using (public.bsp_e_gestor() and enviado_em is null);
revoke all on public.novidades from anon;

-- Para a resumo-matinal: marca como enviadas as novidades por enviar (de
-- uma so vez, para um agendamento repetido nao as mandar duas vezes) e
-- devolve, por pessoa com e-mail @barispol.com, as que lhe dizem respeito.
create or replace function public.bsp_novidades_reclamar()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare novas jsonb;
begin
  with r as (
    update public.novidades set enviado_em = now()
     where enviado_em is null
    returning id, titulo, texto, grupos, destino, criado_em
  )
  select coalesce(jsonb_agg(to_jsonb(r) order by r.id), '[]'::jsonb) into novas from r;
  if jsonb_array_length(novas) = 0 then return '[]'::jsonb; end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', e->>'id', 'nome', e->>'name', 'email', e->>'email',
             'novidades', (select jsonb_agg(n order by (n->>'id')::bigint) from jsonb_array_elements(novas) n
                            where public.bsp_membro_nos_grupos(e, array(select jsonb_array_elements_text(n->'grupos')))))), '[]'::jsonb)
      from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1
       and (e->>'email') ~* '@barispol\.com$'
       and exists (select 1 from jsonb_array_elements(novas) n
                    where public.bsp_membro_nos_grupos(e, array(select jsonb_array_elements_text(n->'grupos'))))
  );
end $function$;
revoke all on function public.bsp_novidades_reclamar() from public, anon, authenticated;
grant execute on function public.bsp_novidades_reclamar() to service_role;

-- A resumo-matinal conta quantos e-mails sairam.
create or replace function public.bsp_novidades_registar(ids bigint[], n integer)
returns void
language sql
security definer
set search_path to 'public'
as $function$
  update public.novidades set enviados = n where id = any (ids);
$function$;
revoke all on function public.bsp_novidades_registar(bigint[], integer) from public, anon, authenticated;
grant execute on function public.bsp_novidades_registar(bigint[], integer) to service_role;

-- 05h00 em Luanda (04h00 UTC), todos os dias. A funcao so envia quando ha
-- novidades por enviar.
do $$
declare
  comando text := $cmd$
    select net.http_post(
      url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/resumo-matinal',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                         where name = 'bsp_resumo_agendamento' limit 1)),
      body    := '{"tipo":"novidades"}'::jsonb
    );
  $cmd$;
begin
  if exists (select 1 from cron.job where jobname = 'bsp-novidades') then
    perform cron.unschedule('bsp-novidades');
  end if;
  perform cron.schedule('bsp-novidades', '0 4 * * *', comando);
end $$;

notify pgrst, 'reload schema';

-- Para acrescentar uma novidade (no SQL Editor, ou pelo assistente):
-- insert into public.novidades (titulo, texto, grupos, destino) values (
--   'Titulo curto', 'Primeiro paragrafo.' || E'\n\n' || 'Segundo paragrafo.',
--   array['recepcao', 'gestao'], 'marcacoes');
