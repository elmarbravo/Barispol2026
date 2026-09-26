-- Barispol · copia diaria dos dados do Workspace
-- Pedido do Elmar, 26-09-2026 («fazes backup de todo o sistema?»). Aplicado
-- no projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se
-- mais do que uma vez.
--
-- O projecto esta no plano gratuito do Supabase, que nao guarda copias
-- que se possam repor. Esta funcao copia, todas as noites, as tabelas do
-- Workspace para o esquema «copias» (copias.<tabela>_AAAAMMDD) e guarda
-- os ultimos 7 dias. Protege contra um apagamento ou um erro; NAO protege
-- contra perder o projecto inteiro (para isso: copia fora do Supabase,
-- ver O-QUE-FALTA 3-ad).
--
-- Ficam de fora o que se volta a ir buscar sozinho: o WhatsApp (SendPulse,
-- esquema whatsapp) e o MetaGest (esquemas crm e erp). Os ficheiros do
-- Drive entram so como lista (storage.objects), nao o conteudo.
-- O esquema copias nao esta exposto na API: so o servidor o le.

create schema if not exists copias;
revoke all on schema copias from public, anon, authenticated;

create or replace function public.bsp_copia_diaria()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  t text; nome text; dia text := to_char(now() at time zone 'Africa/Luanda', 'YYYYMMDD');
  feitas int := 0; velhas int := 0; r record;
begin
  foreach t in array array[
    'public.shared_state', 'public.messages', 'public.posts', 'public.tarefas_pessoais',
    'public.marcacoes', 'public.relatorios_area', 'public.relatorios_destinos',
    'public.contactos_site', 'public.utentes', 'public.seguimentos',
    'public.ficheiros_pessoais', 'storage.objects'
  ] loop
    if to_regclass(t) is null then continue; end if;
    nome := 'copias.' || replace(t, '.', '_') || '_' || dia;
    execute 'drop table if exists ' || nome;
    execute 'create table ' || nome || ' as select * from ' || t;
    feitas := feitas + 1;
  end loop;
  -- So os ultimos 7 dias.
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'copias' and c.relkind = 'r'
             and right(c.relname, 8) ~ '^\d{8}$'
             and to_date(right(c.relname, 8), 'YYYYMMDD') < (now() at time zone 'Africa/Luanda')::date - 6 loop
    execute 'drop table copias.' || quote_ident(r.relname);
    velhas := velhas + 1;
  end loop;
  return jsonb_build_object('dia', dia, 'tabelas', feitas, 'apagadas', velhas);
end $$;
revoke all on function public.bsp_copia_diaria() from public, anon, authenticated;

-- Todas as noites as 03h00 de Luanda (02h00 UTC).
select cron.unschedule(jobid) from cron.job where jobname = 'bsp-copia-diaria';
select cron.schedule('bsp-copia-diaria', '0 2 * * *', 'select public.bsp_copia_diaria()');
