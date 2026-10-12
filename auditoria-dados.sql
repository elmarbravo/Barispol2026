-- Auditoria genérica dos dados sensíveis (12-10-2026, auditoria de segurança,
-- Fase 2, ponto 7). Pode correr-se mais do que uma vez.
--
-- 1. auditoria_dados: cada alteração ou apagamento, feito pela API com sessão,
--    nas tabelas com dados de utentes, clínicos ou de pagamentos fica
--    registado (quem, quando, tabela, chave, o que mudou: só as colunas que
--    mudaram, antes e depois). O servidor (crons, service_role, MetaGest) não
--    entra: senão a cópia diária dos utentes enchia a tabela. Só a gestão lê
--    (Admin). 24 meses na bsp_retencao.
--    Tabelas: marcacoes, utentes, seguimentos, registo_clinico, prestadores,
--    credenciais, ausencias, produtividade_pessoas, produtividade_mensal e
--    todas as pagamento_*.
-- 2. Leituras pela API: as funções que devolvem dados sensíveis passam a
--    registar quem as chamou em acessos_registo (RI-3.3), tal como o ecrã já
--    regista os ecrãs sensíveis; assim uma leitura feita fora do Workspace
--    (ferramenta, consola) também fica registada. bsp_acesso_srv(ecra,
--    detalhe) é a função de registo (só com sessão; nunca falha a chamada
--    principal); entra no início de crm_ficha, bsp_registo_clinico_dia,
--    bsp_registo_clinico_lista, bsp_pagamento_calcular, bsp_pagamento_detalhe
--    e bsp_produtividade_valores (texto da função reescrito no servidor com
--    pg_get_functiondef; as funções passam a VOLATILE, que o INSERT exige).
--    O detalhe nunca leva nomes: id do paciente, dia, mês ou prestador.
-- (Pela ferramenta do servidor este ficheiro corre codificado em base64:
-- tem as palavras que apagam.)

create table if not exists public.auditoria_dados (
  id bigint generated always as identity primary key,
  quando timestamptz not null default now(),
  quem text,
  email text,
  tabela text not null,
  operacao text not null,
  chave text,
  antes jsonb,
  depois jsonb
);
create index if not exists auditoria_dados_quando on public.auditoria_dados (quando desc);
create index if not exists auditoria_dados_tabela on public.auditoria_dados (tabela, chave);
alter table public.auditoria_dados enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'auditoria_dados' and policyname = 'auditoria_dados_ler') then
    create policy auditoria_dados_ler on public.auditoria_dados for select to authenticated using (public.bsp_e_gestor());
  end if;
end $$;
revoke all on public.auditoria_dados from public, anon, authenticated;
grant select on public.auditoria_dados to authenticated;

create or replace function public.bsp_auditar()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare
  papel text := coalesce(auth.jwt()->>'role', '');
  a jsonb; d jsonb; antes jsonb := '{}'; depois jsonb := '{}'; k text; chave text;
begin
  -- Só o que vem pela API com sessão; o servidor e os crons não.
  if papel not in ('authenticated', 'anon') then return null; end if;
  a := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
  d := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
  if tg_op = 'UPDATE' then
    for k in select jsonb_object_keys(a) loop
      if k in ('actualizado_em', 'updated_at', 'alterado_em') then continue; end if;
      if a->k is distinct from d->k then
        antes := antes || jsonb_build_object(k, a->k);
        depois := depois || jsonb_build_object(k, d->k);
      end if;
    end loop;
    if antes = '{}'::jsonb then return null; end if;
  else
    antes := a; depois := d;
  end if;
  chave := coalesce(a, d)->>'id';
  if chave is null then
    chave := concat_ws('/', coalesce(a, d)->>'ano', coalesce(a, d)->>'mes', coalesce(a, d)->>'prestador_id', coalesce(a, d)->>'codigo', coalesce(a, d)->>'dia');
  end if;
  insert into public.auditoria_dados (quem, email, tabela, operacao, chave, antes, depois)
  values (public.bsp_meu_id(), lower(coalesce(auth.jwt()->>'email', '')), tg_table_name, tg_op, left(chave, 80), antes, depois);
  return null;
end $f$;
revoke all on function public.bsp_auditar() from public, anon, authenticated;

do $$
declare t text;
begin
  for t in
    select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r'
       and (c.relname in ('marcacoes', 'utentes', 'seguimentos', 'registo_clinico', 'prestadores', 'credenciais',
                          'ausencias', 'produtividade_pessoas', 'produtividade_mensal')
            or c.relname like 'pagamento\_%')
  loop
    execute format('create or replace trigger bsp_auditar after update or delete on public.%I for each row execute function public.bsp_auditar()', t);
  end loop;
end $$;

-- 2. Registo das leituras pela API.
create or replace function public.bsp_acesso_srv(p_ecra text, p_detalhe text default '')
returns void language plpgsql security definer set search_path to 'public'
as $f$
begin
  if coalesce(auth.jwt()->>'role', '') <> 'authenticated' then return; end if;
  insert into public.acessos_registo (user_id, ecra, detalhe)
  values (coalesce(public.bsp_meu_id(), '?'), left(p_ecra, 40), left(coalesce(p_detalhe, ''), 120));
exception when others then
  null; -- o registo nunca impede a leitura
end $f$;
revoke all on function public.bsp_acesso_srv(text, text) from public, anon, authenticated;

do $$
declare r record; def text; linha text;
begin
  for r in
    select p.oid, p.proname, p.oid::regprocedure as assinatura,
           case p.proname
             when 'crm_ficha' then 'coalesce(p_paciente, t9)'
             when 'bsp_registo_clinico_dia' then 'p_dia::text'
             when 'bsp_registo_clinico_lista' then 'p_de::text || ''..'' || p_ate::text'
             when 'bsp_pagamento_calcular' then 'p_ano || ''-'' || p_mes'
             when 'bsp_pagamento_detalhe' then 'p_ano || ''-'' || p_mes || '' prestador '' || p_prestador'
             when 'bsp_produtividade_valores' then 'p_ano || ''-'' || p_mes'
           end as detalhe
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('crm_ficha', 'bsp_registo_clinico_dia', 'bsp_registo_clinico_lista',
                         'bsp_pagamento_calcular', 'bsp_pagamento_detalhe', 'bsp_produtividade_valores')
  loop
    def := pg_get_functiondef(r.oid);
    if position('bsp_acesso_srv' in def) > 0 then continue; end if;
    linha := E'\nbegin\n  perform public.bsp_acesso_srv(' || quote_literal(r.proname) || ', ' || r.detalhe || E');\n';
    if position(E'\nbegin\n' in def) = 0 then raise exception 'Sem «begin» em %', r.proname; end if;
    def := regexp_replace(def, E'\nbegin\n', linha);
    execute def;
    execute 'alter function ' || r.assinatura || ' volatile';
  end loop;
end $$;

notify pgrst, 'reload schema';
