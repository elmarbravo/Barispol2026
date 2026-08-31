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
--    primeira vez.
--
--    O campo "canais" TEM de vir aqui. Uma versao anterior deste ficheiro
--    gravava so a ordem e as permissoes, e a aplicacao fazia
--    canais.indexOf() sobre um valor inexistente — o ecra do Chat ficava
--    em branco. A aplicacao passou a tolerar isso, mas os dados devem
--    estar certos na origem.
--
--    O "where" apanha tambem as instalacoes ja semeadas pela versao com o
--    defeito: se faltar o canais a qualquer camada, reescreve.
update shared_state set camadas = '{
  "Direcção":    {"ordem":1,"canais":"*","desc":"Vê tudo e administra o sistema.","podeGerirUtilizadores":true, "podeVerSistema":true, "podeVerTarefasPessoais":true},
  "Coordenação": {"ordem":2,"canais":"*","desc":"Coordenação, recursos humanos e apoio à direcção.","podeGerirUtilizadores":true, "podeVerSistema":false,"podeVerTarefasPessoais":false},
  "Clínica":     {"ordem":3,"canais":[null,"clinica","enfermagem","farmacia","escalas"],"desc":"Médicos, enfermagem e laboratório.","podeGerirUtilizadores":false,"podeVerSistema":false,"podeVerTarefasPessoais":false},
  "Operações":   {"ordem":4,"canais":[null,"rececao","escalas"],"desc":"Recepção, motorista e apoio geral.","podeGerirUtilizadores":false,"podeVerSistema":false,"podeVerTarefasPessoais":false}
}'::jsonb
where id = 1
  and (
    camadas is null
    or camadas = '{}'::jsonb
    -- alguma camada gravada sem o campo canais
    or exists (
      select 1 from jsonb_each(camadas) c
      where not (c.value ? 'canais')
    )
  );

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
