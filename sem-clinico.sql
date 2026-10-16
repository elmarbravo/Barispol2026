-- Sem informação clínica (16-10-2026, Elmar: «Desativar o acesso de
-- relatórios e outras informações clínicas ao utilizador do Emmanuel»).
-- O ecrã já esconde (bspSemClinico); isto fecha o servidor.
-- Regras RESTRICTIVE: juntam-se às que existem, sem as mudar.
-- POR APLICAR (o conector do Supabase estava noutra conta a 16-10-2026).

create or replace function public.bsp_sem_clinico()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select coalesce(public.bsp_meu_id() = any (array['u22']), false)
$function$;
revoke all on function public.bsp_sem_clinico() from public, anon;
grant execute on function public.bsp_sem_clinico() to authenticated;

do $$
declare t text;
begin
  foreach t in array array['relatorios_area', 'feedback_utentes', 'ocorrencias', 'auditorias',
                           'marcacoes', 'utentes', 'seguimentos', 'registo_clinico', 'pedidos_marcacao']
  loop
    if to_regclass('public.' || t) is not null
       and not exists (select 1 from pg_policies where schemaname = 'public' and tablename = t and policyname = 'bsp_sem_clinico') then
      execute format('create policy bsp_sem_clinico on public.%I as restrictive for all to authenticated using (not public.bsp_sem_clinico()) with check (not public.bsp_sem_clinico())', t);
    end if;
  end loop;
end $$;

-- Funções security definer que devolvem dados clínicos passam por cima do
-- RLS: ao aplicar, acrescentar no início de cada uma (com o texto actual do
-- servidor) a recusa «if public.bsp_sem_clinico() then … vazio»:
--   bsp_painel_clinico, bsp_relatorio_metagest, crm_ficha, crm_pedidos,
--   bsp_minha_actividade, bsp_qualidade_resumo, bsp_qualidade_espera,
--   bsp_registo_clinico_dia, bsp_registo_clinico_lista.
-- Confirmar depois com sessão simulada (u22): select count(*) from
-- relatorios_area = 0; bsp_painel_clinico() sem linhas.

notify pgrst, 'reload schema';
