-- Toners das impressoras e depósito do gerador (04-10-2026, Emmanuel, Serviços
-- Gerais: «Falta-me o controlo de toners em tempo real e o depósito do
-- gerador»).
--
-- Toners: impressoras (onde está, modelo, IP, consumíveis que usa) e
-- toners_movimentos: Entrada (compra), Troca (toner posto na impressora, sai
-- do stock e o nível volta a 100%), Leitura (nível visto na impressora, em %)
-- e Acerto (contagem do armário, com sinal). O stock de cada consumível é a
-- soma dos movimentos; o nível de cada impressora é a última leitura depois
-- da última troca. toners_minimo: abaixo disto avisa para comprar.
-- «Tempo real» automático exige um programa na rede da clínica a ler as
-- impressoras (SNMP): a nuvem não chega ao 192.168.x. Até lá, o nível
-- regista-se à mão e qualquer colaborador pode registar uma leitura.
--
-- Gerador: gerador (capacidade e limiar de aviso) e gerador_registos:
-- Leitura (litros no depósito) e Abastecimento (litros postos, valor, horas do
-- motor). bsp_gerador_estado calcula os litros de agora (última leitura mais
-- abastecimentos depois dela), o consumo médio por dia (leituras dos últimos
-- 30 dias) e os dias que restam.
-- Avisos (novidades + telemóvel, à gestão e aos Serviços Gerais): depósito
-- abaixo do limiar (no máximo um por 12 horas); toner abaixo do mínimo em
-- stock; impressora com 15% ou menos e sem toner de reserva.
-- Quem regista: gestão, Serviços Gerais e o Emmanuel (bsp_trata_avarias).
-- Lê toda a equipa (sócios não); o gerador só quem trata.

create table if not exists public.impressoras (
  id bigint generated always as identity primary key,
  local text not null,
  modelo text not null,
  ip text not null default '',
  consumiveis text[] not null default '{}',
  activo boolean not null default true,
  nota text not null default '',
  criado_em timestamptz not null default now()
);
alter table public.impressoras enable row level security;

create table if not exists public.toners_minimo (
  codigo text primary key,
  minimo int not null default 1 check (minimo >= 0)
);
alter table public.toners_minimo enable row level security;

create table if not exists public.toners_movimentos (
  id bigint generated always as identity primary key,
  codigo text not null,
  impressora_id bigint references public.impressoras (id) on delete set null,
  tipo text not null check (tipo in ('Entrada', 'Troca', 'Leitura', 'Acerto')),
  quantidade int not null default 0,
  nivel int check (nivel between 0 and 100),
  valor numeric,
  nota text not null default '',
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now()
);
create index if not exists toners_movimentos_cod on public.toners_movimentos (codigo, criado_em desc);
alter table public.toners_movimentos enable row level security;

create table if not exists public.gerador (
  id int primary key default 1 check (id = 1),
  capacidade_l numeric not null default 1000,
  alerta_pct int not null default 30 check (alerta_pct between 5 and 90),
  ultimo_aviso timestamptz
);
alter table public.gerador enable row level security;
insert into public.gerador (id) values (1) on conflict (id) do nothing;

create table if not exists public.gerador_registos (
  id bigint generated always as identity primary key,
  tipo text not null check (tipo in ('Leitura', 'Abastecimento')),
  litros numeric not null check (litros >= 0),
  valor numeric,
  horas_motor numeric,
  quando timestamptz not null default now(),
  nota text not null default '',
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now()
);
create index if not exists gerador_registos_quando on public.gerador_registos (quando desc);
alter table public.gerador_registos enable row level security;

-- Regras de acesso.
drop policy if exists impressoras_ler on public.impressoras;
create policy impressoras_ler on public.impressoras for select to authenticated using (public.bsp_meu_id() is not null and not public.bsp_e_socio());
drop policy if exists impressoras_mudar on public.impressoras;
create policy impressoras_mudar on public.impressoras for all to authenticated using ((select public.bsp_trata_avarias())) with check ((select public.bsp_trata_avarias()));
drop policy if exists toners_minimo_ler on public.toners_minimo;
create policy toners_minimo_ler on public.toners_minimo for select to authenticated using (public.bsp_meu_id() is not null and not public.bsp_e_socio());
drop policy if exists toners_minimo_mudar on public.toners_minimo;
create policy toners_minimo_mudar on public.toners_minimo for all to authenticated using ((select public.bsp_trata_avarias())) with check ((select public.bsp_trata_avarias()));
drop policy if exists toners_mov_ler on public.toners_movimentos;
create policy toners_mov_ler on public.toners_movimentos for select to authenticated using (public.bsp_meu_id() is not null and not public.bsp_e_socio());
-- Uma leitura do nível qualquer colaborador regista; o resto só quem trata.
drop policy if exists toners_mov_criar on public.toners_movimentos;
create policy toners_mov_criar on public.toners_movimentos for insert to authenticated
  with check (public.bsp_meu_id() is not null and not public.bsp_e_socio() and (tipo = 'Leitura' or (select public.bsp_trata_avarias())));
drop policy if exists gerador_ler on public.gerador;
create policy gerador_ler on public.gerador for select to authenticated using ((select public.bsp_trata_avarias()));
drop policy if exists gerador_mudar on public.gerador;
create policy gerador_mudar on public.gerador for update to authenticated using ((select public.bsp_trata_avarias())) with check ((select public.bsp_trata_avarias()));
drop policy if exists gerador_reg_ler on public.gerador_registos;
create policy gerador_reg_ler on public.gerador_registos for select to authenticated using ((select public.bsp_trata_avarias()));
drop policy if exists gerador_reg_criar on public.gerador_registos;
create policy gerador_reg_criar on public.gerador_registos for insert to authenticated with check ((select public.bsp_trata_avarias()));

-- Quem recebe os avisos: gestão e Serviços Gerais (e o Emmanuel).
create or replace function public.bsp_servicos_gerais_ids()
returns text[] language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(array_agg(e->>'id'), '{}')
    from public.shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and not public.bsp_membro_e_socio(e)
     and (e->>'id' = 'u22' or public.bsp_membro_nos_grupos(e, array['gestao', 'servicos gerais']))
$f$;

create or replace function public.bsp_aviso_servicos_gerais(p_titulo text, p_texto text, p_tag text)
returns void language plpgsql security definer set search_path to 'public'
as $f$
declare para text[] := public.bsp_servicos_gerais_ids();
begin
  insert into public.novidades (titulo, texto, grupos, destino) values (p_titulo, p_texto, array['gestao', 'servicos gerais', 'u22'], 'avarias');
  if cardinality(para) > 0 then
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'titulo', p_titulo, 'corpo', left(p_texto, 160), 'url', '#/avarias', 'tag', p_tag));
  end if;
end $f$;

-- Estado do stock e das impressoras.
create or replace function public.bsp_toners_estado()
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  with codigos as (
    select distinct unnest(consumiveis) codigo from public.impressoras where activo
    union select codigo from public.toners_movimentos union select codigo from public.toners_minimo),
  stock as (
    select c.codigo,
           coalesce(sum(case m.tipo when 'Entrada' then m.quantidade when 'Troca' then -m.quantidade when 'Acerto' then m.quantidade else 0 end), 0) qtd,
           coalesce((select minimo from public.toners_minimo t where t.codigo = c.codigo), 1) minimo,
           max(m.criado_em) filter (where m.tipo = 'Troca') ultima_troca
      from codigos c left join public.toners_movimentos m on m.codigo = c.codigo group by c.codigo),
  niveis as (
    select i.id, c codigo,
      (select case when m.tipo = 'Troca' then 100 else m.nivel end from public.toners_movimentos m
        where m.impressora_id = i.id and m.codigo = c and m.tipo in ('Troca', 'Leitura') order by m.criado_em desc limit 1) nivel,
      (select m.criado_em from public.toners_movimentos m
        where m.impressora_id = i.id and m.codigo = c and m.tipo in ('Troca', 'Leitura') order by m.criado_em desc limit 1) visto,
      (select m.criado_em from public.toners_movimentos m
        where m.impressora_id = i.id and m.codigo = c and m.tipo = 'Troca' order by m.criado_em desc limit 1) trocado
      from public.impressoras i, unnest(i.consumiveis) c where i.activo)
  select jsonb_build_object(
    'stock', (select coalesce(jsonb_agg(jsonb_build_object('codigo', codigo, 'qtd', qtd, 'minimo', minimo, 'ultima_troca', ultima_troca) order by codigo), '[]') from stock),
    'niveis', (select coalesce(jsonb_agg(jsonb_build_object('impressora', id, 'codigo', codigo, 'nivel', nivel, 'visto', visto, 'trocado', trocado)), '[]') from niveis))
  where public.bsp_meu_id() is not null and not public.bsp_e_socio()
$f$;

create or replace function public.bsp_toners_aviso()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare q int; mn int; onde text;
begin
  select coalesce(sum(case tipo when 'Entrada' then quantidade when 'Troca' then -quantidade when 'Acerto' then quantidade else 0 end), 0)
    into q from public.toners_movimentos where codigo = new.codigo;
  select coalesce((select minimo from public.toners_minimo where codigo = new.codigo), 1) into mn;
  select local || ' · ' || modelo into onde from public.impressoras where id = new.impressora_id;
  if new.tipo in ('Troca', 'Acerto') and q <= mn then
    perform public.bsp_aviso_servicos_gerais('Toner ' || new.codigo || ': comprar',
      'Restam ' || greatest(q, 0) || ' em stock (mínimo ' || mn || ')' || coalesce('. Última troca: ' || onde, '') || '.', 'toner-' || new.codigo);
  elsif new.tipo = 'Leitura' and new.nivel <= 15 and q <= 0 then
    perform public.bsp_aviso_servicos_gerais('Toner a acabar sem reserva',
      coalesce(onde, 'Impressora') || ': ' || new.codigo || ' a ' || new.nivel || '% e sem toner em stock.', 'toner-' || new.codigo);
  end if;
  return null;
end $f$;
drop trigger if exists bsp_toners_aviso on public.toners_movimentos;
create trigger bsp_toners_aviso after insert on public.toners_movimentos for each row execute function public.bsp_toners_aviso();

-- Estado do depósito.
create or replace function public.bsp_gerador_calculo()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare g record; ult record; pa record; agora numeric; consumo numeric; dias numeric; abast_mes numeric; valor_mes numeric;
begin
  select * into g from public.gerador where id = 1;
  select * into ult from public.gerador_registos where tipo = 'Leitura' order by quando desc limit 1;
  if ult.id is null then
    return jsonb_build_object('capacidade', g.capacidade_l, 'alerta_pct', g.alerta_pct, 'litros', null);
  end if;
  agora := least(g.capacidade_l, ult.litros + coalesce((select sum(litros) from public.gerador_registos where tipo = 'Abastecimento' and quando > ult.quando), 0));
  -- Consumo: entre a primeira e a última leitura dos últimos 30 dias, com os abastecimentos pelo meio.
  select * into pa from public.gerador_registos where tipo = 'Leitura' and quando > now() - interval '30 days' order by quando limit 1;
  if pa.id is not null and ult.quando - pa.quando >= interval '20 hours' then
    consumo := (pa.litros + coalesce((select sum(litros) from public.gerador_registos x where x.tipo = 'Abastecimento'
                 and x.quando > pa.quando and x.quando <= ult.quando), 0) - ult.litros)
               / (extract(epoch from ult.quando - pa.quando) / 86400);
  end if;
  dias := case when consumo > 0 then agora / consumo end;
  select coalesce(sum(litros), 0), sum(valor) into abast_mes, valor_mes from public.gerador_registos
   where tipo = 'Abastecimento' and quando >= date_trunc('month', now());
  return jsonb_build_object('capacidade', g.capacidade_l, 'alerta_pct', g.alerta_pct, 'litros', round(agora, 1),
    'pct', round(agora * 100 / nullif(g.capacidade_l, 0)), 'leitura', ult.litros, 'leitura_em', ult.quando,
    'consumo_dia', round(consumo, 1), 'dias', round(dias, 1), 'abastecido_mes', abast_mes, 'valor_mes', valor_mes,
    'alerta', agora * 100 / nullif(g.capacidade_l, 0) < g.alerta_pct);
end $f$;

create or replace function public.bsp_gerador_estado()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
begin
  if not public.bsp_trata_avarias() then raise exception 'Sem acesso.'; end if;
  return public.bsp_gerador_calculo();
end $f$;

create or replace function public.bsp_gerador_aviso()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare e jsonb := public.bsp_gerador_calculo(); g record;
begin
  select * into g from public.gerador where id = 1;
  if (e->>'alerta')::boolean and (g.ultimo_aviso is null or g.ultimo_aviso < now() - interval '12 hours') then
    perform public.bsp_aviso_servicos_gerais('Gerador: gasóleo a ' || (e->>'pct') || '%',
      'O depósito tem cerca de ' || round((e->>'litros')::numeric) || ' L de ' || round((e->>'capacidade')::numeric) || ' L'
        || coalesce(' (dá para cerca de ' || round((e->>'dias')::numeric) || ' dias ao consumo actual)', '') || '. Encomende o abastecimento.',
      'gerador');
    update public.gerador set ultimo_aviso = now() where id = 1;
  end if;
  return null;
end $f$;
drop trigger if exists bsp_gerador_aviso on public.gerador_registos;
create trigger bsp_gerador_aviso after insert on public.gerador_registos for each row execute function public.bsp_gerador_aviso();

do $$ begin
  revoke execute on function public.bsp_servicos_gerais_ids() from public, anon, authenticated;
  revoke execute on function public.bsp_aviso_servicos_gerais(text, text, text) from public, anon, authenticated;
  revoke execute on function public.bsp_gerador_calculo() from public, anon, authenticated;
  revoke execute on function public.bsp_toners_aviso() from public, anon, authenticated;
  revoke execute on function public.bsp_gerador_aviso() from public, anon, authenticated;
  revoke execute on function public.bsp_toners_estado() from public, anon;
  revoke execute on function public.bsp_gerador_estado() from public, anon;
  grant execute on function public.bsp_toners_estado() to authenticated;
  grant execute on function public.bsp_gerador_estado() to authenticated;
end $$;

-- As impressoras da clínica e a primeira leitura do depósito (lista do
-- Emmanuel, 04-10-2026) carregam-se no servidor, fora deste ficheiro.
