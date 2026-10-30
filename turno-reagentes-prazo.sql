-- Prazo dos reagentes do BS-200 depois de abertos (30-10-2026, Elmar:
-- «acrescente» a data de abertura de cada reagente e o aviso aos 28 dias).
-- A bula Mindray (série BS) dá 28 dias a bordo, refrigerado; cada reagente pode
-- ter outro prazo na bula, marcado em «Corrigir a lista» (campo `prazo`).
-- - Contagem do turno: cada reagente leva `aberto` (AAAA-MM-DD) no item
--   (`TurnoContagemForm`, obrigatório; vem da contagem anterior).
-- - bsp_turno_lista_gravar guarda `prazo` (dias) nos reagentes do Laboratório.
-- - bsp_turno_reagentes_alertar(): 2 dias antes do fim do prazo e no dia, uma
--   vez por frasco (turno_reagente_avisos), novidade + telemóvel ao
--   Laboratório e à Direcção Clínica (u14). Cron bsp-turno-reagentes, 06h41 UTC
--   (07h41 de Luanda; minuto livre).

create or replace function public.bsp_turno_lista_gravar(p_area text, p_itens jsonb)
returns boolean language plpgsql volatile security definer set search_path to 'public'
as $f$
declare eu text := public.bsp_meu_id(); lim jsonb;
begin
  if eu is null or not public.bsp_mfa_ok() then raise exception 'Sem sessão.'; end if;
  if not (public.bsp_e_gestor() or public.bsp_edita_escala(p_area)
          or exists (select 1 from turno_listas where area = p_area and eu = any(responsaveis))) then
    raise exception 'Só o chefe da área ou os responsáveis mudam esta lista.';
  end if;
  -- tipo 'material' (30-10-2026): no Laboratório, contado por quantidade e não
  -- pelo R1/R2 do BS-200 (testes rápidos, seringas, lamelas…). Nos reagentes,
  -- `prazo` = dias de uso depois de aberto (bula; sem valor = 28).
  select coalesce(jsonb_agg(jsonb_build_object('k', left(trim(x->>'nome'), 60), 'nome', left(trim(x->>'nome'), 60),
           'minimo', greatest(0, coalesce(public.bsp_num(x->>'minimo'), 0)))
           || case when p_area = 'laboratorio' and x->>'tipo' = 'material' then jsonb_build_object('tipo', 'material') else '{}'::jsonb end
           || case when p_area = 'laboratorio' and coalesce(x->>'tipo', '') <> 'material' and public.bsp_num(x->>'prazo') between 1 and 730
                   then jsonb_build_object('prazo', round(public.bsp_num(x->>'prazo'))) else '{}'::jsonb end), '[]'::jsonb)
    into lim from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) x where trim(coalesce(x->>'nome', '')) <> '';
  update turno_listas set itens = lim, alterado_por = eu, alterado_em = now() where area = p_area;
  return found;
end $f$;

create table if not exists public.turno_reagente_avisos (
  id bigint generated always as identity primary key,
  area text not null,
  k text not null,
  aberto date not null,
  fase text not null check (fase in ('antes', 'fim')),
  criado timestamptz not null default now(),
  unique (area, k, aberto, fase)
);
alter table public.turno_reagente_avisos enable row level security;
revoke all on public.turno_reagente_avisos from anon, authenticated;

create or replace function public.bsp_turno_reagentes_alertar()
returns jsonb language plpgsql volatile security definer set search_path to 'public'
as $f$
declare
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  ult record; lista jsonb; it jsonb; a jsonb; ab date; prazo int; fim date; fase text;
  linhas text[] := '{}'; para text[]; txt text;
begin
  select * into ult from turno_contagens where area = 'laboratorio' order by criado desc limit 1;
  if not found then return jsonb_build_object('avisos', 0); end if;
  select itens into lista from turno_listas where area = 'laboratorio';
  for it in select * from jsonb_array_elements(coalesce(ult.itens, '[]'::jsonb)) loop
    if coalesce(it->>'aberto', '') !~ '^\d{4}-\d{2}-\d{2}$' then continue; end if;
    select x into a from jsonb_array_elements(coalesce(lista, '[]'::jsonb)) x where x->>'k' = it->>'k' limit 1;
    if a is null or coalesce(a->>'tipo', '') = 'material' then continue; end if;
    ab := (it->>'aberto')::date;
    prazo := coalesce(nullif(round(coalesce(public.bsp_num(a->>'prazo'), 0)), 0), 28)::int;
    fim := ab + prazo;
    fase := case when hoje >= fim then 'fim' when hoje >= fim - 2 then 'antes' end;
    if fase is null then continue; end if;
    insert into turno_reagente_avisos (area, k, aberto, fase) values ('laboratorio', it->>'k', ab, fase)
      on conflict do nothing;
    if found then
      linhas := linhas || ((it->>'k') || ' (aberto a ' || to_char(ab, 'DD-MM') || ', prazo de ' || prazo || ' dias: '
        || case when fase = 'fim' then 'terminou a ' || to_char(fim, 'DD-MM') else 'termina a ' || to_char(fim, 'DD-MM') end || ')');
    end if;
  end loop;
  if array_length(linhas, 1) is null then return jsonb_build_object('avisos', 0); end if;

  select coalesce(array_agg(distinct x->>'id'), '{}') into para
    from shared_state s, jsonb_array_elements(s.team) x
   where public.bsp_area_chave(x->>'dept') = 'laboratorio' and not coalesce((x->>'inactivo')::boolean, false);
  para := array(select distinct unnest(para || array['u14']));
  txt := 'Laboratório, reagentes do BS-200 no fim do prazo depois de abertos: ' || array_to_string(linhas, '; ')
      || '. Fora do prazo, trocar o frasco antes de fazer exames.';
  insert into novidades (titulo, texto, grupos, destino) values ('Reagente do BS-200 no fim do prazo', txt, array['laboratorio', 'direccao-clinica'], null);
  perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'titulo', 'Reagente do BS-200 no fim do prazo',
    'corpo', left(txt, 160), 'url', '#/relatorios', 'tag', 'reagente-' || to_char(hoje, 'YYYYMMDD')));
  return jsonb_build_object('avisos', array_length(linhas, 1), 'para', to_jsonb(para));
end $f$;
revoke all on function public.bsp_turno_reagentes_alertar() from public, anon, authenticated;

select cron.schedule('bsp-turno-reagentes', '41 6 * * *', 'select public.bsp_turno_reagentes_alertar()');
