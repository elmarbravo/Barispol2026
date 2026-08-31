-- ═══════════════════════════════════════════════════════════════════════
--  BARISPOL WORKSPACE · INSTALAR TUDO
--
--  Cole ESTE ficheiro inteiro no SQL Editor do Supabase e carregue em RUN.
--  É uma vez só. Pode repetir sem estragar nada, se ficar na dúvida.
--
--  Junta, pela ordem certa, o que estava em quatro ficheiros separados:
--    1. seguranca-conversas.sql  regras por conversa (directas e grupos)
--    2. camadas-editaveis.sql    camadas de acesso editáveis
--    3. crm-seguimento.sql       utentes e seguimento (CRM)
--    4. tarefas-pessoais.sql     tarefas privadas de cada pessoa
--
--  A ordem importa: os blocos 2, 3 e 4 usam funções que o bloco 1 cria.
-- ═══════════════════════════════════════════════════════════════════════

-- PRIMEIRO, uma verificação. Tudo isto assenta nas tabelas base. Se elas
-- ainda não existirem, mais vale parar já com uma frase clara do que
-- falhar cinquenta linhas à frente com um erro que não diz nada.
do $verificar$
begin
  if to_regclass('public.messages') is null or to_regclass('public.shared_state') is null then
    raise exception
      'Faltam as tabelas base. Corra primeiro o supabase-configuracao.sql, depois volte a este.';
  end if;
end
$verificar$;



-- ═══════════════════════════════════════════════════════════════════════
--  1 de 4 · REGRAS POR CONVERSA
-- ═══════════════════════════════════════════════════════════════════════

-- ATENÇÃO: este bloco fecha as mensagens directas e os grupos privados.
-- Antes dele, qualquer pessoa com sessão iniciada conseguia ler tudo pela
-- API — os grupos privados eram privados só no ecrã.
--
-- Depois de correr: se alguém deixar de ver as suas mensagens directas, é
-- porque o e-mail dessa pessoa em Admin -> Utilizadores não coincide com o
-- e-mail de login. Corrigir o e-mail no directório resolve na hora.

-- Barispol Workspace · seguranca por conversa (passo 2)
-- Correr UMA vez no SQL Editor do Supabase. Pode repetir sem estragar nada.
-- O que faz: as mensagens directas passam a ser legiveis APENAS pelos dois
-- participantes (e os grupos privados apenas pelos membros), mesmo que alguem
-- fale directamente com o servidor por fora da aplicacao. Antes, qualquer
-- colaborador com sessao iniciada conseguia ler tudo pela API.

-- 1. Quem sou eu? (traduz o e-mail da sessao para o id usado na aplicacao)
create or replace function bsp_meu_id() returns text
language sql stable security definer set search_path = public as $f$
  select e->>'id'
  from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
  where s.id = 1
    and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email', ''))
  limit 1
$f$;

-- 2. Sou gestor? (Direccao ou Coordenacao)
create or replace function bsp_e_gestor() returns boolean
language sql stable security definer set search_path = public as $f$
  select exists (
    select 1
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
    where s.id = 1
      and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email', ''))
      and (e->>'accessLevel') in ('Direcção', 'Coordenação')
  )
$f$;

-- 3. Posso ver esta conversa?
--    dm-…            -> so os dois participantes
--    th~<conversa>~… -> a regra da conversa-mae
--    grupo privado   -> so os membros (a Direccao/Coordenacao ve tudo)
--    canais normais  -> toda a equipa autenticada
create or replace function bsp_ve_conversa(chave text) returns boolean
language plpgsql stable security definer set search_path = public as $f$
declare
  alvo text := chave;
  privado boolean;
begin
  if alvo like 'th~%' then
    alvo := split_part(alvo, '~', 2);
  end if;
  if alvo like 'dm-%' then
    return bsp_meu_id() is not null and (
      bsp_meu_id() = split_part(substr(alvo, 4), '_', 1)
      or bsp_meu_id() = split_part(substr(alvo, 4), '_', 2)
    );
  end if;
  select jsonb_array_length(coalesce(c.value->'membros', '[]'::jsonb)) > 0 into privado
  from shared_state s, jsonb_array_elements(coalesce(s.channels, '[]'::jsonb)) c
  where s.id = 1 and c.value->>'id' = alvo
  limit 1;
  if coalesce(privado, false) then
    return bsp_e_gestor() or exists (
      select 1
      from shared_state s, jsonb_array_elements(coalesce(s.channels, '[]'::jsonb)) c,
           jsonb_array_elements_text(c.value->'membros') m
      where s.id = 1 and c.value->>'id' = alvo and m = bsp_meu_id()
    );
  end if;
  return true;
end
$f$;

-- 4. Substituir as regras "tudo ou nada" das mensagens
drop policy if exists "bsp_msg_auth" on messages;
drop policy if exists "bsp_msg_ler" on messages;
drop policy if exists "bsp_msg_criar" on messages;
drop policy if exists "bsp_msg_apagar" on messages;

create policy "bsp_msg_ler" on messages for select
  to authenticated using (bsp_ve_conversa(conv_key));
create policy "bsp_msg_criar" on messages for insert
  to authenticated with check (
    bsp_ve_conversa(conv_key)
    and (user_id = bsp_meu_id() or bsp_meu_id() is null)
  );
create policy "bsp_msg_apagar" on messages for delete
  to authenticated using (user_id = bsp_meu_id() or bsp_e_gestor());

-- 5. Feed: todos leem; cada um publica em seu nome; apaga o autor ou um gestor
drop policy if exists "bsp_post_auth" on posts;
drop policy if exists "bsp_post_ler" on posts;
drop policy if exists "bsp_post_criar" on posts;
drop policy if exists "bsp_post_apagar" on posts;

create policy "bsp_post_ler" on posts for select
  to authenticated using (true);
create policy "bsp_post_criar" on posts for insert
  to authenticated with check (user_id = bsp_meu_id() or bsp_meu_id() is null);
create policy "bsp_post_apagar" on posts for delete
  to authenticated using (user_id = bsp_meu_id() or bsp_e_gestor());

-- Nota: se alguem deixar de ver as suas mensagens directas, e porque o
-- e-mail dessa pessoa em Admin -> Utilizadores nao coincide com o e-mail
-- de login. Corrigir o e-mail no directorio resolve na hora.

-- REVERTER (so em emergencia): apaga as regras novas e repoe as antigas.
-- drop policy if exists "bsp_msg_ler" on messages;
-- drop policy if exists "bsp_msg_criar" on messages;
-- drop policy if exists "bsp_msg_apagar" on messages;
-- create policy "bsp_msg_auth" on messages for all to authenticated using (true) with check (true);
-- drop policy if exists "bsp_post_ler" on posts;
-- drop policy if exists "bsp_post_criar" on posts;
-- drop policy if exists "bsp_post_apagar" on posts;
-- create policy "bsp_post_auth" on posts for all to authenticated using (true) with check (true);


-- ═══════════════════════════════════════════════════════════════════════
--  2 de 4 · CAMADAS DE ACESSO EDITÁVEIS
-- ═══════════════════════════════════════════════════════════════════════

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


-- ═══════════════════════════════════════════════════════════════════════
--  3 de 4 · UTENTES E SEGUIMENTO (CRM)
-- ═══════════════════════════════════════════════════════════════════════

-- Barispol Workspace · seguimento e retorno de utentes (CRM, passo 1)
-- Correr UMA vez no SQL Editor do Supabase. Pode repetir sem estragar nada.
--
-- O QUE FAZ: cria onde viver a lista de utentes e o registo de seguimento.
--
-- PORQUE EM TABELAS PRÓPRIAS, e não no shared_state como as tarefas e o
-- calendário: o shared_state é um único bloco JSON reescrito por inteiro a
-- cada alteração. Serve para dezenas de linhas, não para milhares de
-- utentes — com o histórico de uma clínica, cada mudança de estado
-- reenviaria a base toda.
--
-- O MetaGest continua a ser a verdade sobre consultas e facturação. Isto
-- não a duplica: guarda só quem é o utente, quando cá esteve pela última
-- vez, e o que a clínica fez desde então para o trazer de volta.

-- 1. Utentes. Alimentados por importação do Relatório do MetaGest.
create table if not exists utentes (
  id             bigint generated always as identity primary key,
  -- Chave estável para não duplicar a cada importação. Construída na
  -- aplicação a partir do nome normalizado + telefone.
  chave          text not null unique,
  nome           text not null,
  telefone       text,
  -- O que interessa ao seguimento, tirado da última linha do relatorio.
  ultima_visita  date,
  ultimo_servico text,
  ultimo_medico  text,
  visitas        integer not null default 1,
  criado_em      timestamptz not null default now(),
  actualizado_em timestamptz not null default now()
);

-- A pergunta que este módulo faz é sempre "quem não vem há muito tempo".
create index if not exists utentes_ultima_visita_idx on utentes (ultima_visita);
create index if not exists utentes_nome_idx on utentes (lower(nome));

-- 2. Seguimento. Uma linha por acção: quem falou com quem, quando, e o quê.
--    Histórico, não estado — o estado actual é a linha mais recente.
create table if not exists seguimentos (
  id         bigint generated always as identity primary key,
  utente_id  bigint not null references utentes (id) on delete cascade,
  -- por-contactar | contactado | marcado | voltou | dispensado
  estado     text not null,
  nota       text,
  user_id    text,
  created_at timestamptz not null default now()
);

create index if not exists seguimentos_utente_idx on seguimentos (utente_id, created_at desc);

-- 3. Trancar. Sem sessão iniciada, nada.
alter table utentes enable row level security;
alter table seguimentos enable row level security;

drop policy if exists "bsp_utentes_ler"    on utentes;
drop policy if exists "bsp_utentes_criar"  on utentes;
drop policy if exists "bsp_utentes_mudar"  on utentes;
drop policy if exists "bsp_utentes_apagar" on utentes;

-- Toda a equipa autenticada lê: é a recepção que faz as chamadas.
create policy "bsp_utentes_ler" on utentes for select
  to authenticated using (true);

-- Escrever na lista de utentes é importar, e isso é acto de gestão.
create policy "bsp_utentes_criar" on utentes for insert
  to authenticated with check (bsp_e_gestor());
create policy "bsp_utentes_mudar" on utentes for update
  to authenticated using (bsp_e_gestor()) with check (bsp_e_gestor());
create policy "bsp_utentes_apagar" on utentes for delete
  to authenticated using (bsp_e_gestor());

drop policy if exists "bsp_seg_ler"    on seguimentos;
drop policy if exists "bsp_seg_criar"  on seguimentos;
drop policy if exists "bsp_seg_apagar" on seguimentos;

-- O seguimento é o trabalho do dia-a-dia: qualquer pessoa da equipa
-- regista o que fez, em seu nome. Apagar é do autor ou de um gestor.
create policy "bsp_seg_ler" on seguimentos for select
  to authenticated using (true);
create policy "bsp_seg_criar" on seguimentos for insert
  to authenticated with check (user_id = bsp_meu_id() or bsp_meu_id() is null);
create policy "bsp_seg_apagar" on seguimentos for delete
  to authenticated using (user_id = bsp_meu_id() or bsp_e_gestor());

-- 4. Conferir. Deve devolver as duas tabelas com RLS activo.
--
-- select tablename, rowsecurity from pg_tables
-- where schemaname = 'public' and tablename in ('utentes','seguimentos');

-- REVERTER (só em emergência): apaga tudo o que este ficheiro criou.
-- drop table if exists seguimentos;
-- drop table if exists utentes;


-- ═══════════════════════════════════════════════════════════════════════
--  4 de 4 · TAREFAS PESSOAIS
-- ═══════════════════════════════════════════════════════════════════════

-- Barispol Workspace · tarefas pessoais
-- Correr UMA vez no SQL Editor do Supabase. Pode repetir sem estragar nada.
--
-- PORQUE UMA TABELA À PARTE, e não uma marca "pessoal" nas tarefas que já
-- existem: as tarefas da equipa vivem no shared_state, um bloco JSON que
-- é enviado por inteiro para todos os aparelhos. Marcar uma como pessoal
-- e escondê-la no ecrã não a esconderia de ninguém — continuaria a chegar
-- a todos os telemóveis, e qualquer pessoa a leria nos dados em bruto.
-- Seria privacidade a fingir.
--
-- Aqui, cada linha pertence a uma pessoa e a regra do servidor não deixa
-- ninguém ler as dos outros. Nem sequer chegam ao aparelho.

create table if not exists tarefas_pessoais (
  id         bigint generated always as identity primary key,
  -- O id da aplicação (u1, u2, ...), o mesmo que o bsp_meu_id() devolve.
  user_id    text not null,
  coluna     text not null default 'todo',   -- todo | doing | review | done
  titulo     text not null,
  prioridade text not null default 'media',  -- alta | media | baixa
  prazo      text,
  ordem      integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists tarefas_pessoais_dono_idx
  on tarefas_pessoais (user_id, coluna, ordem);

alter table tarefas_pessoais enable row level security;

drop policy if exists "bsp_tp_ler"    on tarefas_pessoais;
drop policy if exists "bsp_tp_criar"  on tarefas_pessoais;
drop policy if exists "bsp_tp_mudar"  on tarefas_pessoais;
drop policy if exists "bsp_tp_apagar" on tarefas_pessoais;

-- Só o dono. Sem excepção para gestores: uma tarefa pessoal que a
-- direcção pudesse ler não seria pessoal, e a pessoa que a escreveu
-- ficaria a pensar que era.
create policy "bsp_tp_ler" on tarefas_pessoais for select
  to authenticated using (user_id = bsp_meu_id());
create policy "bsp_tp_criar" on tarefas_pessoais for insert
  to authenticated with check (user_id = bsp_meu_id());
create policy "bsp_tp_mudar" on tarefas_pessoais for update
  to authenticated using (user_id = bsp_meu_id()) with check (user_id = bsp_meu_id());
create policy "bsp_tp_apagar" on tarefas_pessoais for delete
  to authenticated using (user_id = bsp_meu_id());

-- NOTA: o bsp_meu_id() traduz o e-mail da sessão para o id da aplicação,
-- procurando-o em Admin -> Utilizadores. Se o e-mail de login não
-- coincidir com o do directório, a função devolve nulo e a pessoa não vê
-- as suas próprias tarefas. Corrigir o e-mail no directório resolve.

-- Conferir:
-- select tablename, rowsecurity from pg_tables
-- where schemaname = 'public' and tablename = 'tarefas_pessoais';

-- REVERTER (só em emergência):
-- drop table if exists tarefas_pessoais;


-- ═══════════════════════════════════════════════════════════════════════
--  CONFERIR
--  Depois do RUN, corra isto para ver se ficou tudo de pé.
--  Deve devolver seis linhas, todas com protegida = true.
-- ═══════════════════════════════════════════════════════════════════════

select tablename, rowsecurity as protegida
from pg_tables
where schemaname = 'public'
  and tablename in ('messages', 'posts', 'shared_state',
                    'utentes', 'seguimentos', 'tarefas_pessoais')
order by tablename;
