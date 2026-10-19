-- Repor os grupos do Chat que desapareceram (19-10-2026, Elmar: «Os canais
-- Rp, DAF desapareceram»). Os grupos ficam em shared_state.channels; as
-- mensagens (messages, conv_key = id do grupo) não se perderam.
-- Causa provável: um posto gravou o estado antes de o ler do servidor (lista
-- vazia, depois de as sessões terminarem a 16-10). Corrigido no ecrã
-- (estadoLido, canaisServidor em workspace.html) e no servidor (gatilho
-- abaixo).
-- Fonte: as cópias diárias (copias.public_shared_state_AAAAMMDD, 7 dias).
-- Nas funções pela ferramenta, nunca as palavras que pedem confirmação.

-- 1. Ver primeiro, por cópia, quantos grupos havia:
--   select c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
--    where s.nspname = 'copias' and c.relname like 'public_shared_state_%' order by 1 desc;
--   (e em cada uma: select jsonb_array_length(channels) from copias.<nome> where id = 1)

-- 2. Repor: junta ao estado actual cada grupo da cópia mais recente que tinha
--    mais grupos do que o estado tem agora (pelo id; nunca duplica).
do $$
declare
  r record;
  melhor text;
  n_melhor int := -1;
  n int;
  actual jsonb;
  copia jsonb;
  repostos int := 0;
  g jsonb;
begin
  select coalesce(channels, '[]'::jsonb) into actual from public.shared_state where id = 1;
  for r in
    select c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
     where s.nspname = 'copias' and c.relname ~ '^public_shared_state_\d{8}$'
     order by c.relname desc
  loop
    execute format('select coalesce(jsonb_array_length(channels), 0) from copias.%I where id = 1', r.relname) into n;
    if coalesce(n, 0) > jsonb_array_length(actual) and coalesce(n, 0) > n_melhor then
      melhor := r.relname; n_melhor := n;
      exit; -- a mais recente com mais grupos do que agora
    end if;
  end loop;
  if melhor is null then
    raise notice 'Nenhuma cópia tem mais grupos do que o estado actual (%).', jsonb_array_length(actual);
    return;
  end if;
  execute format('select channels from copias.%I where id = 1', melhor) into copia;
  for g in select value from jsonb_array_elements(copia) loop
    if not exists (select 1 from jsonb_array_elements(actual) a where a->>'id' = g->>'id') then
      actual := actual || jsonb_build_array(g);
      repostos := repostos + 1;
      raise notice 'Reposto: % (%)', g->>'name', g->>'id';
    end if;
  end loop;
  update public.shared_state set channels = actual, updated_at = now() where id = 1;
  raise notice 'Cópia %: % grupos repostos; agora %.', melhor, repostos, jsonb_array_length(actual);
end $$;

-- 3. Guarda no servidor: uma gravação que traga uma lista de grupos vazia
--    nunca apaga dois ou mais (o ecrã apaga um de cada vez). Junta-se ao
--    gatilho bsp_estado_guarda (shared-state-fechar.sql) como gatilho próprio.
create or replace function public.bsp_estado_canais_guarda()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if jsonb_typeof(old.channels) = 'array' and jsonb_array_length(old.channels) >= 2
     and (new.channels is null or jsonb_typeof(new.channels) <> 'array' or jsonb_array_length(new.channels) = 0) then
    new.channels := old.channels;
  end if;
  return new;
end $$;
revoke all on function public.bsp_estado_canais_guarda() from public, anon, authenticated;
create or replace trigger bsp_estado_canais_guarda
  before update on public.shared_state
  for each row execute function public.bsp_estado_canais_guarda();
