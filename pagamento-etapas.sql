-- Pagamento dos médicos por etapas (07-10-2026, Elmar: «tem como escolher que
-- médicos colocar na planilha para pagar? Vou pagar por etapas, há escassez de
-- valores» e «os pagos tenho de validar no perfil de cada um»). Corre-se depois
-- de pagamento-medicos.sql e pagamento-banco.sql. Sem «drop».
--
-- Uma linha por médico e mês: quando entrou num mapa do banco (data, BAI ou
-- outros bancos, valor) e quando o Elmar ou a Arlete validaram que está pago.
-- Só quem vê os salários (bsp_pagamento_acesso = u1 e u2) lê e grava, e só
-- pelas funções. Valores nunca no repositório.

create table if not exists public.pagamento_etapas (
  ano int not null,
  mes int not null check (mes between 1 and 12),
  prestador_id bigint not null,
  mapa_em date,
  mapa_banco text check (mapa_banco in ('bai', 'outros')),
  mapa_valor numeric,
  pago_em timestamptz,
  pago_valor numeric,
  pago_por text,
  nota text not null default '',
  actualizado_em timestamptz not null default now(),
  primary key (ano, mes, prestador_id)
);
alter table public.pagamento_etapas enable row level security;
revoke all on public.pagamento_etapas from anon, authenticated;

create or replace function public.bsp_pagamento_etapas(p_ano int, p_mes int)
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  select case when public.bsp_pagamento_acesso(false) then
    coalesce((select jsonb_object_agg(prestador_id::text, jsonb_build_object(
        'mapa_em', mapa_em, 'mapa_banco', mapa_banco, 'mapa_valor', mapa_valor,
        'pago_em', pago_em, 'pago_valor', pago_valor, 'pago_por', pago_por, 'nota', nota))
       from public.pagamento_etapas where ano = p_ano and mes = p_mes), '{}'::jsonb)
  end
$f$;
revoke all on function public.bsp_pagamento_etapas(int, int) from public, anon;
grant execute on function public.bsp_pagamento_etapas(int, int) to authenticated;

-- p_accao: 'mapa' (entrou num mapa do banco hoje), 'pago' (validado como pago),
-- 'tirar_mapa', 'tirar_pago'. p_ids: os médicos; p_valores: {id: líquido}.
create or replace function public.bsp_pagamento_etapa(p_ano int, p_mes int, p_accao text, p_ids bigint[], p_valores jsonb default '{}'::jsonb, p_banco text default null)
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare n int;
begin
  if not public.bsp_pagamento_acesso(true) or public.bsp_meu_id() is null then
    raise exception 'Só o Elmar e a Arlete registam pagamentos.' using errcode = '42501';
  end if;
  if p_accao not in ('mapa', 'pago', 'tirar_mapa', 'tirar_pago') then
    raise exception 'Acção desconhecida: %', p_accao;
  end if;
  if p_accao = 'mapa' and coalesce(p_banco, '') not in ('bai', 'outros') then
    raise exception 'Falta o banco do mapa.';
  end if;
  insert into public.pagamento_etapas (ano, mes, prestador_id)
  select p_ano, p_mes, i from unnest(coalesce(p_ids, '{}')) i
  on conflict (ano, mes, prestador_id) do nothing;
  update public.pagamento_etapas e set
    mapa_em    = case p_accao when 'mapa' then (now() at time zone 'Africa/Luanda')::date when 'tirar_mapa' then null else e.mapa_em end,
    mapa_banco = case p_accao when 'mapa' then p_banco when 'tirar_mapa' then null else e.mapa_banco end,
    mapa_valor = case p_accao when 'mapa' then nullif(p_valores->>e.prestador_id::text, '')::numeric when 'tirar_mapa' then null else e.mapa_valor end,
    pago_em    = case p_accao when 'pago' then now() when 'tirar_pago' then null else e.pago_em end,
    pago_valor = case p_accao when 'pago' then nullif(p_valores->>e.prestador_id::text, '')::numeric when 'tirar_pago' then null else e.pago_valor end,
    pago_por   = case p_accao when 'pago' then public.bsp_meu_id() when 'tirar_pago' then null else e.pago_por end,
    actualizado_em = now()
  where e.ano = p_ano and e.mes = p_mes and e.prestador_id = any(p_ids);
  get diagnostics n = row_count;
  return n;
end $f$;
revoke all on function public.bsp_pagamento_etapa(int, int, text, bigint[], jsonb, text) from public, anon;
grant execute on function public.bsp_pagamento_etapa(int, int, text, bigint[], jsonb, text) to authenticated;

notify pgrst, 'reload schema';
