-- Barispol Workspace · camadas de acesso editaveis (passo 3)
-- Correr UMA vez no SQL Editor do Supabase. Pode repetir sem estragar nada.
--
-- PORQUE: ate aqui, saber quem e gestor era uma lista de nomes escrita a
-- mao dentro do bsp_e_gestor(): 'Direccao' e 'Coordenacao'. Com as camadas
-- editaveis na aplicacao, criar uma camada nova de gestao — "Coordenacao
-- Clinica", por exemplo — dava-lhe os botoes todos na interface e nenhum
-- poder no servidor. O contrario tambem: renomear 'Direccao' tirava-lhe o
-- estatuto de gestor sem aviso nenhum.
--
-- A partir daqui a pergunta deixa de ser "como se chama a camada?" e passa
-- a ser "a camada desta pessoa pode gerir utilizadores?", lida da mesma
-- definicao que a aplicacao usa.

-- 1. Coluna onde as camadas passam a viver, ao lado das outras.
alter table shared_state add column if not exists camadas jsonb;

-- 2. Semear com as quatro originais, para nenhuma instalacao existente
--    ficar sem gestores entre correr isto e a aplicacao gravar pela
--    primeira vez. So preenche se estiver vazia.
update shared_state set camadas = '{
  "Direcção":    {"ordem":1,"podeGerirUtilizadores":true, "podeVerSistema":true},
  "Coordenação": {"ordem":2,"podeGerirUtilizadores":true, "podeVerSistema":false},
  "Clínica":     {"ordem":3,"podeGerirUtilizadores":false,"podeVerSistema":false},
  "Operações":   {"ordem":4,"podeGerirUtilizadores":false,"podeVerSistema":false}
}'::jsonb
where id = 1 and (camadas is null or camadas = '{}'::jsonb);

-- 3. Sou gestor? Agora pela permissao da camada, nao pelo nome dela.
create or replace function bsp_e_gestor() returns boolean
language sql stable security definer set search_path = public as $f$
  select exists (
    select 1
    from shared_state s,
         jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
    where s.id = 1
      and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email', ''))
      and coalesce(
            -- a camada da pessoa, procurada nas camadas gravadas
            (s.camadas -> (e->>'accessLevel') ->> 'podeGerirUtilizadores')::boolean,
            -- rede de seguranca: instalacao ainda sem a coluna preenchida
            (e->>'accessLevel') in ('Direcção', 'Coordenação')
          )
  )
$f$;

-- 4. Verificar. Deve listar cada pessoa e se o servidor a considera gestora.
--    Se alguem aparecer como gestor sem dever ser, ou o contrario, o
--    problema esta no e-mail em Admin -> Utilizadores nao coincidir com o
--    e-mail de login.
--
-- select e->>'name'        as pessoa,
--        e->>'accessLevel' as camada,
--        coalesce((s.camadas -> (e->>'accessLevel') ->> 'podeGerirUtilizadores')::boolean, false) as e_gestor
-- from shared_state s, jsonb_array_elements(coalesce(s.team,'[]'::jsonb)) e
-- where s.id = 1
-- order by 3 desc, 1;

-- REVERTER (so em emergencia): repoe a lista de nomes fixa.
-- create or replace function bsp_e_gestor() returns boolean
-- language sql stable security definer set search_path = public as $f$
--   select exists (
--     select 1 from shared_state s, jsonb_array_elements(coalesce(s.team,'[]'::jsonb)) e
--     where s.id = 1 and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email',''))
--       and (e->>'accessLevel') in ('Direcção', 'Coordenação'))
-- $f$;
