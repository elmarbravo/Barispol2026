-- Barispol Workspace · agenda privada e pública, com convidados
-- Pedido do Elmar, 01-10-2026: «A mesma privacidade das tarefas quero no
-- calendário, agendas privadas e agendas públicas, convidar pessoas para o
-- evento». Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo
-- dia. Pode correr-se mais do que uma vez.
--
-- Regras iguais às tarefas privadas (tarefas_pessoais, tarefas-delegar.sql):
--   - privado: vêem o dono, quem o criou, os convidados e quem vê as tarefas
--     privadas de todos (bsp_ve_tarefas_pessoais: Direcção e Coordenação);
--   - público: toda a equipa vê;
--   - a Direcção e a Coordenação criam na agenda de outra pessoa (delegam);
--   - mudam e apagam o dono, quem criou e a Direcção/Coordenação;
--   - cada convidado só responde por si (bsp_evento_responder).
-- Os eventos antigos da equipa (shared_state.events) continuam públicos.
-- Convite: novidade para os convidados (sino e e-mail das 05h00).

create table if not exists public.agenda_eventos (
  id bigint generated always as identity primary key,
  dono text not null default public.bsp_meu_id(),
  criado_por text default public.bsp_meu_id(),
  titulo text not null check (length(btrim(titulo)) > 0),
  descricao text not null default '',
  local text not null default '',
  categoria text not null default 'reuniao',
  hora text not null default '09:00' check (hora ~ '^\d{2}:\d{2}$'),
  duracao integer not null default 60 check (duracao between 5 and 1440),
  dia smallint check (dia between 0 and 6),          -- todas as semanas (0 = Segunda)
  data date,                                           -- numa data
  privado boolean not null default true,
  convidados text[] not null default '{}',
  respostas jsonb not null default '{}'::jsonb,        -- { id: 'sim' | 'nao' | 'talvez' }
  criado_em timestamptz not null default now(),
  actualizado_em timestamptz not null default now(),
  check (dia is not null or data is not null)
);
create index if not exists agenda_eventos_dono on public.agenda_eventos (dono);
create index if not exists agenda_eventos_convidados on public.agenda_eventos using gin (convidados);
alter table public.agenda_eventos enable row level security;

drop policy if exists agenda_ler on public.agenda_eventos;
create policy agenda_ler on public.agenda_eventos for select to authenticated
  using (not privado or dono = (select public.bsp_meu_id()) or criado_por = (select public.bsp_meu_id())
         or (select public.bsp_meu_id()) = any (convidados) or (select public.bsp_ve_tarefas_pessoais()));
drop policy if exists agenda_criar on public.agenda_eventos;
create policy agenda_criar on public.agenda_eventos for insert to authenticated
  with check ((dono = (select public.bsp_meu_id()) or (select public.bsp_ve_tarefas_pessoais()))
              and coalesce(criado_por, (select public.bsp_meu_id())) = (select public.bsp_meu_id()));
drop policy if exists agenda_mudar on public.agenda_eventos;
create policy agenda_mudar on public.agenda_eventos for update to authenticated
  using (dono = (select public.bsp_meu_id()) or criado_por = (select public.bsp_meu_id()) or (select public.bsp_ve_tarefas_pessoais()))
  with check (dono = (select public.bsp_meu_id()) or criado_por = (select public.bsp_meu_id()) or (select public.bsp_ve_tarefas_pessoais()));
drop policy if exists agenda_apagar on public.agenda_eventos;
create policy agenda_apagar on public.agenda_eventos for delete to authenticated
  using (dono = (select public.bsp_meu_id()) or criado_por = (select public.bsp_meu_id()) or (select public.bsp_ve_tarefas_pessoais()));
grant select, insert, update, delete on public.agenda_eventos to authenticated;
revoke all on public.agenda_eventos from anon;

-- O convidado responde só por si.
create or replace function public.bsp_evento_responder(p_id bigint, p_resposta text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare eu text := public.bsp_meu_id(); e public.agenda_eventos;
begin
  if eu is null then raise exception 'Sem sessão.'; end if;
  if p_resposta not in ('sim', 'nao', 'talvez') then raise exception 'Resposta inválida.'; end if;
  select * into e from public.agenda_eventos where id = p_id for update;
  if not found or not (eu = any (e.convidados)) then raise exception 'Não foi convidado para este evento.'; end if;
  update public.agenda_eventos set respostas = respostas || jsonb_build_object(eu, p_resposta) where id = p_id;
  if e.dono <> eu then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Resposta a um convite', public.bsp_nome_de(eu) || case p_resposta when 'sim' then ' vai' when 'nao' then ' não vai' else ' talvez vá' end
            || ' a «' || e.titulo || '».', array[e.dono], 'calendar');
  end if;
end $function$;
revoke all on function public.bsp_evento_responder(bigint, text) from public, anon;
grant execute on function public.bsp_evento_responder(bigint, text) to authenticated;

-- Carimbo, quem criou, e avisos de convite e de evento posto na agenda de
-- outra pessoa.
create or replace function public.bsp_agenda_carimbo()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare novos text[]; quando text;
begin
  if tg_op = 'INSERT' then
    new.criado_por := coalesce(public.bsp_meu_id(), new.criado_por, new.dono);
  else
    new.criado_por := old.criado_por;
    new.respostas := case when new.convidados is distinct from old.convidados
      then (select coalesce(jsonb_object_agg(k, v), '{}'::jsonb) from jsonb_each(old.respostas) x(k, v) where k = any (new.convidados))
      else new.respostas end;
  end if;
  new.convidados := array(select distinct x from unnest(coalesce(new.convidados, '{}')) x where x is not null and x <> new.dono);
  new.actualizado_em := now();
  quando := case when new.data is not null then to_char(new.data, 'DD-MM-YYYY')
                 else 'todas as ' || (array['segundas', 'terças', 'quartas', 'quintas', 'sextas', 'sábados', 'domingos'])[new.dia + 1] end
            || ' às ' || new.hora;
  novos := array(select x from unnest(new.convidados) x
                  where tg_op = 'INSERT' or not (x = any (coalesce(old.convidados, '{}'))));
  if array_length(novos, 1) > 0 then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Convite: ' || new.titulo, public.bsp_nome_de(coalesce(new.criado_por, new.dono)) || ' convida-o para «' || new.titulo || '», '
            || quando || case when new.local <> '' then ', em ' || new.local else '' end || '. Responda na Agenda.', novos, 'calendar');
  end if;
  if tg_op = 'INSERT' and new.dono <> coalesce(new.criado_por, new.dono) then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Novo na sua agenda', public.bsp_nome_de(new.criado_por) || ' pôs «' || new.titulo || '» na sua agenda, ' || quando || '.', array[new.dono], 'calendar');
  end if;
  return new;
end $function$;
revoke all on function public.bsp_agenda_carimbo() from public, anon;
drop trigger if exists bsp_agenda_carimbo on public.agenda_eventos;
create trigger bsp_agenda_carimbo before insert or update on public.agenda_eventos
  for each row execute function public.bsp_agenda_carimbo();

-- Tempo real (o convidado vê o convite sem recarregar).
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'agenda_eventos') then
    alter publication supabase_realtime add table public.agenda_eventos;
  end if;
end $$;

insert into public.novidades (titulo, texto, grupos, destino)
select 'Agenda com eventos privados e convidados',
       'Na Agenda, cada evento novo pode ser privado (só o vê quem o criou e os convidados) ou de toda a equipa. Pode convidar colegas, que respondem «Vou», «Talvez» ou «Não vou». Toque num evento para o ver, mudar ou apagar.',
       array['todos'], 'calendar'
 where not exists (select 1 from public.novidades where titulo = 'Agenda com eventos privados e convidados');

notify pgrst, 'reload schema';
