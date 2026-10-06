-- Viaturas do Transporte (06-10-2026, sugestões do Emmanuel no #transporte:
-- «Lista de viaturas da clínica · opção para escolher a viatura que vou usar ·
-- histórico para cada uma delas»).
--
-- transporte_viaturas: uma linha por viatura. Nunca se apaga: a que sai de
-- serviço fica activa = false. Quem vê e regista é o mesmo do resto do
-- Transporte (bsp_ve_transporte: gestão e cargo «motorista»).
-- viagens, abastecimentos e manutenções ganham viatura_id. Os registos antigos
-- ficam na viatura que já existia (criada aqui com a matrícula por indicar).
-- Um registo novo sem viatura (aparelho com a página antiga) fica na viatura
-- activa mais antiga (gatilho bsp_transp_viatura_omissao).
-- Os km contam-se por viatura: cada uma tem o seu conta-quilómetros.

create table if not exists public.transporte_viaturas (
  id bigint generated always as identity primary key,
  nome text not null,
  matricula text not null default '',
  marca text not null default '',
  modelo text not null default '',
  ano int,
  combustivel text not null default 'Gasóleo',
  activa boolean not null default true,
  nota text not null default '',
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now()
);
alter table public.transporte_viaturas enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'transporte_viaturas' and policyname = 'transporte_viaturas_ler') then
    create policy transporte_viaturas_ler on public.transporte_viaturas for select to authenticated using (public.bsp_ve_transporte());
    create policy transporte_viaturas_criar on public.transporte_viaturas for insert to authenticated with check (public.bsp_ve_transporte());
    create policy transporte_viaturas_mudar on public.transporte_viaturas for update to authenticated using (public.bsp_ve_transporte()) with check (public.bsp_ve_transporte());
  end if;
end $$;

alter table public.transporte_viagens add column if not exists viatura_id bigint references public.transporte_viaturas (id);
alter table public.transporte_abastecimentos add column if not exists viatura_id bigint references public.transporte_viaturas (id);
alter table public.transporte_manutencoes add column if not exists viatura_id bigint references public.transporte_viaturas (id);
create index if not exists transporte_viagens_viatura on public.transporte_viagens (viatura_id, km_inicio);

-- A viatura que já existia e os registos antigos.
do $$ declare v bigint;
begin
  if not exists (select 1 from public.transporte_viaturas) then
    insert into public.transporte_viaturas (nome, nota) values ('Viatura 1', 'Matrícula por indicar') returning id into v;
  else
    select min(id) into v from public.transporte_viaturas;
  end if;
  update public.transporte_viagens set viatura_id = v where viatura_id is null;
  update public.transporte_abastecimentos set viatura_id = v where viatura_id is null;
  update public.transporte_manutencoes set viatura_id = v where viatura_id is null;
end $$;

create or replace function public.bsp_transp_viatura_omissao()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
begin
  if new.viatura_id is null then
    select id into new.viatura_id from public.transporte_viaturas where activa order by id limit 1;
  end if;
  return new;
end $f$;
revoke all on function public.bsp_transp_viatura_omissao() from public, anon, authenticated;

do $$ declare t text;
begin
  foreach t in array array['transporte_viagens', 'transporte_abastecimentos', 'transporte_manutencoes'] loop
    if not exists (select 1 from pg_trigger where tgname = 'bsp_transp_viatura_omissao' and tgrelid = ('public.' || t)::regclass) then
      execute format('create trigger bsp_transp_viatura_omissao before insert on public.%I for each row execute function public.bsp_transp_viatura_omissao()', t);
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';
