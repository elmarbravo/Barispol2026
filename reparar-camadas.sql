-- Barispol Workspace · reparar as camadas gravadas sem o campo "canais"
--
-- PORQUE: a primeira versao do camadas-editaveis.sql semeou as camadas com
-- a ordem e as permissoes, mas sem o campo "canais" — a lista de
-- departamentos que cada camada alcanca. A aplicacao lia esse campo e
-- fazia canais.indexOf(): os ecras do Chat e das Permissoes ficavam em
-- branco, sem explicacao nenhuma.
--
-- A aplicacao ja aguenta os dados estragados (repoe o que falta a partir
-- das definicoes de origem), mas os dados devem estar certos na base. Este
-- ficheiro poe-nos certos SEM apagar nada: acrescenta o "canais" so a
-- quem nao o tem, e nao toca nas camadas que a clinica tenha criado com
-- o campo ja preenchido.
--
-- Pode correr as vezes que quiser. Se nao houver nada a reparar, nao faz
-- nada.

-- 1. Antes: quem esta sem o campo.
select 'ANTES' as quando, key as camada,
       case when value ? 'canais' then 'ok' else 'SEM CANAIS' end as estado
from shared_state s, jsonb_each(coalesce(s.camadas, '{}'::jsonb))
where s.id = 1
order by 2;

-- 2. A reparacao. Cada camada recebe o "canais" que lhe compete:
--      - as quatro de origem, o que sempre foi o delas;
--      - qualquer outra criada na clinica, apenas os canais gerais
--        (o [null]) — nunca "*", porque um erro de dados nao pode dar
--        acessos a ninguem. Depois ajusta-se no ecra das Permissoes.
update shared_state s
set camadas = (
  select jsonb_object_agg(
    c.key,
    case when c.value ? 'canais' then c.value
         else c.value || jsonb_build_object('canais',
           case c.key
             when 'Direcção'    then '"*"'::jsonb
             when 'Coordenação' then '"*"'::jsonb
             when 'Clínica'     then '[null,"clinica","enfermagem","farmacia","escalas"]'::jsonb
             when 'Operações'   then '[null,"rececao","escalas"]'::jsonb
             else '[null]'::jsonb
           end)
    end)
  from jsonb_each(s.camadas) c
)
where s.id = 1
  and s.camadas is not null
  and exists (
    select 1 from jsonb_each(s.camadas) c where not (c.value ? 'canais')
  );

-- 3. Depois: devem estar todas "ok".
select 'DEPOIS' as quando, key as camada,
       case when value ? 'canais' then 'ok' else 'SEM CANAIS' end as estado,
       value ->> 'canais' as alcanca
from shared_state s, jsonb_each(coalesce(s.camadas, '{}'::jsonb))
where s.id = 1
order by 2;
