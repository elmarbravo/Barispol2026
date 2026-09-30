-- Barispol Workspace · registo de tentativas de captura de ecrã (30-09-2026)
-- Pedido do Elmar: bloquear os prints para todos. No navegador e no iPhone
-- não há forma de os impedir; o Workspace escurece o ecrã ao carregar em
-- PrintScreen, põe marca de água em todos os ecrãs e regista aqui cada
-- tentativa que consegue ver (tecla PrintScreen, pedido de impressão).
-- Cada pessoa só grava as suas; só a gestão lê. Aplicado no projecto
-- Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia.

create table if not exists public.capturas_ecra (
  id bigint generated always as identity primary key,
  user_id text,
  ecra text not null default '',
  tipo text not null default 'printscreen' check (tipo in ('printscreen', 'impressao')),
  aparelho text not null default '',
  quando timestamptz not null default now()
);
create index if not exists capturas_ecra_quando on public.capturas_ecra (quando desc);

create or replace function public.bsp_capturas_carimbo()
returns trigger language plpgsql security definer set search_path to 'public' as $function$
begin
  new.user_id := public.bsp_meu_id();
  new.quando := now();
  new.aparelho := left(coalesce(new.aparelho, ''), 200);
  new.ecra := left(coalesce(new.ecra, ''), 40);
  return new;
end $function$;
drop trigger if exists bsp_capturas_carimbo on public.capturas_ecra;
create trigger bsp_capturas_carimbo before insert on public.capturas_ecra
  for each row execute function public.bsp_capturas_carimbo();

alter table public.capturas_ecra enable row level security;
drop policy if exists capturas_ecra_criar on public.capturas_ecra;
drop policy if exists capturas_ecra_ler on public.capturas_ecra;
create policy capturas_ecra_criar on public.capturas_ecra for insert to authenticated with check (public.bsp_meu_id() is not null);
create policy capturas_ecra_ler on public.capturas_ecra for select to authenticated using (public.bsp_e_gestor());
