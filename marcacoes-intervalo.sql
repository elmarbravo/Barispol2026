-- Marcações espaçadas (07-10-2026, Elmar: «nas marcações não permita marcar
-- todas no mesmo minuto; ginecologia em média leva quanto tempo com a
-- paciente?»). Corre-se depois de marcacoes.sql. Sem «drop».
--
-- Medido nas facturas do MetaGest (6 meses, 153 consultas de ginecologia, 2
-- médicos): intervalo mediano 25 min, médio 34 min entre utentes seguidos.
-- Regra: o mesmo médico (ou, sem médico, o mesmo acto) não tem duas marcações
-- em aberto (Agendada/Confirmada) no mesmo dia mais perto do que a duração do
-- acto: consulta de ginecologia/obstetrícia 30 min; o resto 15 min
-- (marcacoes_duracoes, muda-se sem mexer no código). Só para hoje e datas
-- futuras; o que já estava gravado não muda. Para gravar sem a regra:
-- set_config('bsp.marc_livre', '1', true).

create table if not exists public.marcacoes_duracoes (
  padrao text primary key,          -- expressão regular sobre o acto
  minutos int not null check (minutos between 5 and 240),
  nota text not null default ''
);
alter table public.marcacoes_duracoes enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'marcacoes_duracoes' and policyname = 'marc_duracoes_ler') then
    create policy marc_duracoes_ler on public.marcacoes_duracoes for select to authenticated using (true);
  end if;
end $$;
revoke insert, update, delete on public.marcacoes_duracoes from anon, authenticated;
insert into public.marcacoes_duracoes (padrao, minutos, nota) values
  ('consulta.*(ginecolog|obstetr)', 30, 'Mediana 25 min, média 34 min (facturas, 6 meses)')
on conflict (padrao) do nothing;

-- Minutos desde a meia-noite de «8:30», «08h30», «8.30».
create or replace function public.bsp_marc_minutos(p_hora text)
returns int language sql immutable set search_path to 'public'
as $f$
  select case when coalesce(p_hora, '') ~ '^\s*\d{1,2}[:hH.]\d{2}'
              then substring(p_hora from '^\s*(\d{1,2})')::int * 60 + substring(p_hora from '^\s*\d{1,2}[:hH.](\d{2})')::int end
$f$;

create or replace function public.bsp_marc_duracao(p_acto text)
returns int language sql stable security definer set search_path to 'public'
as $f$
  select coalesce((select max(d.minutos) from public.marcacoes_duracoes d
                    where coalesce(p_acto, '') ~* d.padrao), 15)
$f$;
grant execute on function public.bsp_marc_duracao(text) to authenticated;

create or replace function public.bsp_marc_espacar()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare
  m int := public.bsp_marc_minutos(new.hora);
  chave text := lower(trim(coalesce(nullif(trim(new.medico), ''), new.acto, '')));
  por_medico boolean := coalesce(trim(new.medico), '') <> '';
  dur int := public.bsp_marc_duracao(new.acto);
  c record;
  livre int;
  hh text;
begin
  if coalesce(current_setting('bsp.marc_livre', true), '') = '1' then return new; end if;
  if m is null or chave = '' or new.estado not in ('Agendada', 'Confirmada')
     or new.data_marcada < (now() at time zone 'Africa/Luanda')::date then return new; end if;
  if tg_op = 'UPDATE' and new.data_marcada is not distinct from old.data_marcada and new.hora is not distinct from old.hora
     and new.medico is not distinct from old.medico and new.acto is not distinct from old.acto
     and old.estado in ('Agendada', 'Confirmada') then return new; end if;

  select x.hora, x.acto, public.bsp_marc_minutos(x.hora) mx, greatest(dur, public.bsp_marc_duracao(x.acto)) d into c
    from public.marcacoes x
   where x.data_marcada = new.data_marcada and x.id is distinct from new.id
     and x.estado in ('Agendada', 'Confirmada')
     and lower(trim(coalesce(nullif(trim(x.medico), ''), x.acto, ''))) = chave
     and public.bsp_marc_minutos(x.hora) is not null
     and abs(public.bsp_marc_minutos(x.hora) - m) < greatest(dur, public.bsp_marc_duracao(x.acto))
   order by abs(public.bsp_marc_minutos(x.hora) - m) limit 1;
  if not found then return new; end if;

  -- Próxima hora livre a partir da pedida, de 5 em 5 minutos, até às 22h00.
  livre := m;
  while livre < 22 * 60 and exists (
    select 1 from public.marcacoes x
     where x.data_marcada = new.data_marcada and x.id is distinct from new.id
       and x.estado in ('Agendada', 'Confirmada')
       and lower(trim(coalesce(nullif(trim(x.medico), ''), x.acto, ''))) = chave
       and public.bsp_marc_minutos(x.hora) is not null
       and abs(public.bsp_marc_minutos(x.hora) - livre) < greatest(dur, public.bsp_marc_duracao(x.acto))) loop
    livre := livre + 5;
  end loop;
  hh := lpad((livre / 60)::text, 2, '0') || ':' || lpad((livre % 60)::text, 2, '0');
  raise exception '%', 'Já há uma marcação ' || case when por_medico then 'com ' || trim(new.medico) else 'de ' || trim(new.acto) end
    || ' às ' || lpad((c.mx / 60)::text, 2, '0') || ':' || lpad((c.mx % 60)::text, 2, '0')
    || ' de ' || to_char(new.data_marcada, 'DD-MM-YYYY') || '. Cada utente precisa de ' || c.d || ' min.'
    || case when livre < 22 * 60 then ' Próxima hora livre: ' || hh || '.' else ' Não há hora livre neste dia.' end
    using errcode = 'P0001';
end $f$;

create or replace trigger bsp_marc_espacar
  before insert or update on public.marcacoes
  for each row execute function public.bsp_marc_espacar();

notify pgrst, 'reload schema';

-- Durações de referência geral (07-10-2026, Elmar: «vê de forma geral, o
-- MetaGest tem dado errado»): as facturas não medem a duração da consulta.
-- Aplicado. bsp_marc_duracao usa o maior valor entre os padrões que batem.
insert into public.marcacoes_duracoes (padrao, minutos, nota) values
  ('consulta.*(ginecolog|obstetr|obstétr)', 30, 'Referência geral'),
  ('consulta.*cardiolog', 30, 'Referência geral'),
  ('consulta.*pediatr', 20, 'Referência geral'),
  ('consulta.*urolog', 20, 'Referência geral'),
  ('consulta.*(cl[ií]nica geral|medicina geral|medicina interna)', 20, 'Referência geral'),
  ('consulta.*nutri', 45, 'Referência geral'),
  ('consulta.*psicolog', 50, 'Referência geral'),
  ('ecografia', 20, 'Referência geral'),
  ('ecografia.*(obst[eé]tric|obstÉtric|trimestre)', 30, 'Referência geral'),
  ('ecografia.*morfol', 45, 'Referência geral'),
  ('ecoc?g?cardiograma', 30, 'Referência geral'),
  ('(^|[^a-z])ecg([^a-z]|$)|electrocardiograma', 10, 'Referência geral'),
  ('mapa|holter', 15, 'Referência geral')
on conflict (padrao) do update set minutos = excluded.minutos, nota = excluded.nota;
