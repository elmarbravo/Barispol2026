-- Fechar o shared_state (12-10-2026, auditoria de segurança; Elmar: «estamos
-- vulneráveis»).
--
-- Antes, a regra bsp_state_auth (supabase-configuracao.sql) dava a toda a equipa
-- escrita total na linha do shared_state. É lá (team, camadas) que o servidor
-- decide quem é gestor (bsp_e_gestor), quem é quem (bsp_meu_id) e quem vê
-- salários. Com a chave publicável e um update, qualquer colaborador podia
-- pôr-se na Direcção ou trocar o seu e-mail pela entrada de outra pessoa.
--
-- Agora:
--   · ler: quem tem sessão (como antes);
--   · gravar tasks, events, drive, channels: quem tem sessão (a equipa
--     trabalha nesses campos);
--   · gravar team e camadas: só a gestão (bsp_e_gestor). Para os outros, o
--     gatilho bsp_estado_guarda mantém os valores antigos em silêncio: a
--     gravação das tarefas não falha, mas a equipa não muda;
--   · cada alteração a team/camadas, aceite ou recusada, fica em
--     equipa_auditoria (quem, quando, antes, depois); só a gestão lê;
--   · apagar a linha: ninguém pela API;
--   · inserir: só a linha 1 (o upsert do ecrã).
-- O servidor (postgres, crons, service_role) não passa pelo gatilho.
-- (alter policy / create or replace trigger: a ferramenta do servidor pára
-- com a palavra que apaga objectos.)

create table if not exists public.equipa_auditoria (
  id bigint generated always as identity primary key,
  quando timestamptz not null default now(),
  quem text,
  email text,
  campo text not null check (campo in ('team', 'camadas')),
  permitido boolean not null,
  antes jsonb,
  depois jsonb
);
alter table public.equipa_auditoria enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'equipa_auditoria' and policyname = 'equipa_auditoria_ler') then
    create policy equipa_auditoria_ler on public.equipa_auditoria for select to authenticated using (public.bsp_e_gestor());
  end if;
end $$;
revoke all on public.equipa_auditoria from anon;
grant select on public.equipa_auditoria to authenticated;

create or replace function public.bsp_estado_guarda()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare gestor boolean; eu text; mail text; papel text;
begin
  -- Só as ligações pela API (testemunho de authenticated ou anon) passam
  -- pela guarda; o postgres, os crons e o service_role gravam livremente.
  -- (current_user não serve: dentro de uma função security definer é o dono.)
  papel := coalesce(auth.jwt()->>'role', '');
  if papel not in ('authenticated', 'anon') then return new; end if;
  if tg_op = 'INSERT' then
    if new.id <> 1 then raise exception 'Só existe a linha 1.'; end if;
    return new;
  end if;
  mail := lower(coalesce(auth.jwt()->>'email', ''));
  eu := public.bsp_meu_id();
  gestor := public.bsp_e_gestor();
  if new.team is distinct from old.team then
    insert into public.equipa_auditoria (quem, email, campo, permitido, antes, depois)
    values (eu, mail, 'team', gestor, old.team, new.team);
    if not gestor then new.team := old.team; end if;
  end if;
  if new.camadas is distinct from old.camadas then
    insert into public.equipa_auditoria (quem, email, campo, permitido, antes, depois)
    values (eu, mail, 'camadas', gestor, old.camadas, new.camadas);
    if not gestor then new.camadas := old.camadas; end if;
  end if;
  return new;
end $f$;
revoke all on function public.bsp_estado_guarda() from public, anon, authenticated;

create or replace trigger bsp_estado_guarda before insert or update on public.shared_state
  for each row execute function public.bsp_estado_guarda();

-- A regra antiga «for all … using (true)» passa a ser só de leitura e escrita
-- nos campos partilhados; apagar fica fechado.
alter policy bsp_state_auth on public.shared_state to authenticated
  using (true) with check (id = 1);
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'shared_state' and policyname = 'bsp_state_apagar') then
    create policy bsp_state_apagar on public.shared_state for delete to authenticated using (false);
  end if;
end $$;
-- Uma policy «for all» cobre o delete com using (true); a «bsp_state_apagar»
-- não a anula (as policies somam-se com OR). Por isso tira-se o privilégio
-- de apagar à API de vez, e com ele os outros que a API nunca precisou
-- (esvaziar a tabela, referências, gatilhos).
revoke all on public.shared_state from anon;
revoke all on public.shared_state from authenticated;
grant select, insert, update on public.shared_state to authenticated;
