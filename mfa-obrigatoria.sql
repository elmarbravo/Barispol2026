-- Verificação em dois passos obrigatória no servidor (16-10-2026, Elmar:
-- «Cria autenticação de dois factores para todos acessos»).
-- O ecrã já não abre sem 2FA (MfaInscreverEcra); isto faz o mesmo nas
-- tabelas: uma sessão sem o segundo passo (app ou e-mail) não lê nem grava nada.
-- A função vai entre (select …): calcula-se uma vez por consulta, não por linha.
-- Aplicado a 16-10-2026: 98 regras (97 tabelas + storage.objects); teste:
-- sem segundo passo shared_state = 0 linhas, com e-mail ou app = 1.
-- Regras RESTRICTIVE: juntam-se às que existem, sem as mudar. As Edge
-- Functions com a chave do servidor e o site (entrada-publica) não mudam.
-- Pode correr-se já: o ecrã obriga a activar o 2FA antes de ler qualquer
-- tabela, e a activação só usa o Auth.

-- Corre-se depois de mfa-email.sql: o segundo passo vale pela app (aal2) ou
-- pelo código por e-mail (bsp_mfa_ok).
create or replace function public.bsp_sessao_aal2()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.bsp_mfa_ok()
$function$;

do $$
declare t record;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
  loop
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = t.relname and policyname = 'bsp_mfa_aal2') then
      execute format('create policy bsp_mfa_aal2 on public.%I as restrictive for all to authenticated using ((select public.bsp_sessao_aal2())) with check ((select public.bsp_sessao_aal2()))', t.relname);
    end if;
  end loop;
  begin
    if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'bsp_mfa_aal2') then
      execute 'create policy bsp_mfa_aal2 on storage.objects as restrictive for all to authenticated using ((select public.bsp_sessao_aal2())) with check ((select public.bsp_sessao_aal2()))';
    end if;
  exception when others then raise notice 'storage.objects: %', sqlerrm;
  end;
end $$;

-- As funções security definer passam por cima do RLS: ao aplicar, ver se
-- bsp_meu_id() deve devolver null quando bsp_sessao_aal2() for falso (fecha
-- de uma vez todas as funções que dependem dela). Testar antes com uma
-- sessão aal1 simulada.
-- Uma tabela nova com RLS precisa da mesma regra (correr de novo o bloco).

notify pgrst, 'reload schema';
