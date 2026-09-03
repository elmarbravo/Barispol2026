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
drop policy if exists "bsp_msg_editar" on messages;

create policy "bsp_msg_ler" on messages for select
  to authenticated using (bsp_ve_conversa(conv_key));
create policy "bsp_msg_criar" on messages for insert
  to authenticated with check (
    bsp_ve_conversa(conv_key)
    and (user_id = bsp_meu_id() or bsp_meu_id() is null)
  );
create policy "bsp_msg_apagar" on messages for delete
  to authenticated using (user_id = bsp_meu_id() or bsp_e_gestor());

-- Alterar: so o autor. Quem pode apagar nao e quem pode reescrever — e
-- reescrever o que outra pessoa disse e a pior das duas.
create policy "bsp_msg_editar" on messages for update
  to authenticated
  using (user_id = bsp_meu_id())
  with check (user_id = bsp_meu_id());

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
