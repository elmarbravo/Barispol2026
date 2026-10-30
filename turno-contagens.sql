-- Abertura e fecho do turno no Laboratório e na Enfermagem (30-10-2026, Elmar:
-- «Tem que fazer a abertura do dia. Ao abrir o dia, lançam lá as quantidades e
-- ao fechar o dia também»; «algo intuitivo, obrigatório, logo que a pessoa […]
-- entra, pede-lhe logo para carregar os dados»). Responsável da lista da
-- Enfermagem: Filomena Silva (u9); de baixa, os enfermeiros mantêm a lista.
--
-- turno_listas: o que se conta em cada área (Laboratório: reagentes do BS-200,
--   R1 e R2; Enfermagem: material, quantidade). Muda só por
--   bsp_turno_lista_gravar (gestão, chefe da área ou responsáveis da lista).
-- turno_contagens: uma abertura e um fecho por área, dia e turno, gravados só
--   por bsp_turno_contar. Na gravação o servidor compara a abertura com o
--   último fecho (passagem de turno) e o material com o mínimo, e avisa o chefe
--   da área, a gestão e a Direcção Clínica (novidade e telemóvel).
-- bsp_turno_pendente(): o que a pessoa tem por abrir ou fechar, pela escala em
--   vigor. O ecrã obrigatório do Workspace lê esta função.
-- Lêem as contagens: a própria área, quem edita a escala da área, a gestão e a
-- Direcção Clínica. Sem nomes de utentes.

create table if not exists public.turno_listas (
  area text primary key check (area in ('laboratorio', 'enfermagem')),
  itens jsonb not null default '[]'::jsonb,
  responsaveis text[] not null default '{}',
  alterado_por text,
  alterado_em timestamptz not null default now()
);
alter table public.turno_listas enable row level security;
revoke all on public.turno_listas from anon, authenticated;
grant select on public.turno_listas to authenticated;
create policy bsp_mfa_aal2 on public.turno_listas as restrictive for all to authenticated
  using ((select public.bsp_sessao_aal2())) with check ((select public.bsp_sessao_aal2()));
create policy bsp_turno_listas_ler on public.turno_listas for select to authenticated using (true);

create table if not exists public.turno_contagens (
  id bigserial primary key,
  area text not null check (area in ('laboratorio', 'enfermagem')),
  dia date not null,
  turno text not null,
  momento text not null check (momento in ('abertura', 'fecho')),
  user_id text not null,
  itens jsonb not null default '[]'::jsonb,
  frio numeric,
  motivo text,
  ficheiros jsonb not null default '[]'::jsonb,
  fora_escala boolean not null default false,
  diferencas jsonb not null default '[]'::jsonb,
  criado timestamptz not null default now(),
  unique (area, dia, turno, momento)
);
alter table public.turno_contagens enable row level security;
revoke all on public.turno_contagens from anon, authenticated;
grant select on public.turno_contagens to authenticated;
create policy bsp_mfa_aal2 on public.turno_contagens as restrictive for all to authenticated
  using ((select public.bsp_sessao_aal2())) with check ((select public.bsp_sessao_aal2()));
create policy bsp_turno_contagens_ler on public.turno_contagens for select to authenticated using (
  public.bsp_minha_area() = area or public.bsp_e_gestor() or public.bsp_edita_escala(area)
  or public.bsp_le_areas_medicas());

-- Listas iniciais. A da Enfermagem corrige-se no Workspace.
insert into public.turno_listas (area, itens, responsaveis) values
 ('laboratorio', (select jsonb_agg(jsonb_build_object('k', k, 'nome', k, 'minimo', 20)) from unnest(array[
   'ALT-TGP', 'AST-TGO', 'Ácido úrico', 'Bilirrubina D', 'Bilirrubina T', 'Colesterol total', 'Creatinina',
   'Glicemia', 'HDL-Col', 'LDL-Col', 'Triglicéridos', 'Ureia']) k), array['u16']),
 ('enfermagem', (select jsonb_agg(jsonb_build_object('k', k, 'nome', k, 'minimo', 0)) from unnest(array[
   'Seringas de 2 ml', 'Seringas de 5 ml', 'Seringas de 10 ml', 'Agulhas', 'Cateteres', 'Sistemas de soro',
   'Soro fisiológico', 'Soro glicosado', 'Luvas (pares)', 'Compressas', 'Adesivo', 'Algodão', 'Álcool',
   'Máscaras de nebulização']) k), array['u9', 'u10', 'u11', 'u1790684118990'])
on conflict (area) do nothing;

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
  -- pelo R1/R2 do BS-200 (testes rápidos, seringas, lamelas…).
  select coalesce(jsonb_agg(jsonb_build_object('k', left(trim(x->>'nome'), 60), 'nome', left(trim(x->>'nome'), 60),
           'minimo', greatest(0, coalesce(public.bsp_num(x->>'minimo'), 0)))
           || case when p_area = 'laboratorio' and x->>'tipo' = 'material' then jsonb_build_object('tipo', 'material') else '{}'::jsonb end), '[]'::jsonb)
    into lim from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) x where trim(coalesce(x->>'nome', '')) <> '';
  update turno_listas set itens = lim, alterado_por = eu, alterado_em = now() where area = p_area;
  return found;
end $f$;

-- Os turnos de hoje e de ontem em que a pessoa está, pela escala em vigor.
create or replace function public.bsp_turno_meus(p_eu text)
returns table (area text, dia date, turno text, inicio timestamp, fim timestamp)
language sql stable security definer set search_path to 'public'
as $f$
  with agora as (select (now() at time zone 'Africa/Luanda')::date d offset 0)
  select e.area, d.dia, t->>'nome',
         d.dia + coalesce(nullif(t->>'inicio', ''), '07:00')::time,
         d.dia + coalesce(nullif(t->>'fim', ''), '22:30')::time
           + case when coalesce(nullif(t->>'fim', ''), '22:30')::time <= coalesce(nullif(t->>'inicio', ''), '07:00')::time then interval '1 day' else interval '0' end
    from agora, lateral (values (agora.d), (agora.d - 1)) d(dia)
    join public.escalas e on e.mes = date_trunc('month', d.dia)::date and e.area in ('laboratorio', 'enfermagem')
     and public.bsp_escala_em_vigor(e.estado, e.visto_em, e.exige_visto)
    cross join lateral jsonb_array_elements(coalesce(e.turnos, '[]'::jsonb)) t
   where coalesce(t->'semana' @> to_jsonb(extract(dow from d.dia)::int), false)
     and coalesce(e.dias->(d.dia::text)->(t->>'id'), '[]'::jsonb) ? p_eu
$f$;
revoke all on function public.bsp_turno_meus(text) from public, anon, authenticated;

create or replace function public.bsp_turno_pendente()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare
  eu text := public.bsp_meu_id();
  agora timestamp := now() at time zone 'Africa/Luanda';
  r record; res jsonb := '[]'::jsonb; ab boolean; fe boolean;
begin
  if eu is null or not public.bsp_mfa_ok() then return jsonb_build_object('pendentes', res); end if;
  for r in select * from public.bsp_turno_meus(eu) order by inicio loop
    -- Em vigor a partir de 31-10-2026 (Elmar: «coloca em vigor amanhã… para não
    -- ser surpresa»): os turnos de 30-10 não pedem abertura nem fecho.
    if r.dia < date '2026-10-31' then continue; end if;
    ab := exists (select 1 from turno_contagens c where c.area = r.area and c.dia = r.dia and c.turno = r.turno and c.momento = 'abertura');
    fe := exists (select 1 from turno_contagens c where c.area = r.area and c.dia = r.dia and c.turno = r.turno and c.momento = 'fecho');
    -- Abrir: desde 30 min antes do início até ao fim do turno.
    if not ab and agora >= r.inicio - interval '30 minutes' and agora < r.fim then
      res := res || jsonb_build_array(jsonb_build_object('area', r.area, 'dia', r.dia, 'turno', r.turno, 'momento', 'abertura',
        'inicio', to_char(r.inicio, 'HH24:MI'), 'fim', to_char(r.fim, 'HH24:MI'), 'obrigatorio', true));
    end if;
    -- Fechar: na última hora pode-se; depois do fim é obrigatório (até 24 h).
    if not fe and agora >= r.fim - interval '1 hour' and agora <= r.fim + interval '24 hours' then
      res := res || jsonb_build_array(jsonb_build_object('area', r.area, 'dia', r.dia, 'turno', r.turno, 'momento', 'fecho',
        'inicio', to_char(r.inicio, 'HH24:MI'), 'fim', to_char(r.fim, 'HH24:MI'), 'obrigatorio', agora >= r.fim));
    end if;
  end loop;
  return jsonb_build_object('pendentes', res, 'area', public.bsp_minha_area());
end $f$;

-- A última contagem da área (para vir preenchida) e a lista.
create or replace function public.bsp_turno_base(p_area text)
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  select case when public.bsp_minha_area() = p_area or public.bsp_e_gestor() or public.bsp_edita_escala(p_area) then
    jsonb_build_object(
      'lista', (select itens from turno_listas where area = p_area),
      'pode_lista', public.bsp_e_gestor() or public.bsp_edita_escala(p_area)
                    or exists (select 1 from turno_listas where area = p_area and public.bsp_meu_id() = any(responsaveis)),
      'ultima', (select jsonb_build_object('momento', momento, 'dia', dia, 'turno', turno, 'itens', itens, 'criado', criado)
                   from turno_contagens where area = p_area order by criado desc limit 1))
  end
$f$;

create or replace function public.bsp_turno_contar(p_area text, p_dia date, p_turno text, p_momento text,
  p_itens jsonb, p_frio numeric, p_motivo text, p_ficheiros jsonb)
returns jsonb language plpgsql volatile security definer set search_path to 'public'
as $f$
declare
  eu text := public.bsp_meu_id();
  na_escala boolean; ant record; dif jsonb := '[]'::jsonb; baixos text[] := '{}'; it jsonb; a jsonb;
  lista jsonb; nome_area text; para text[]; txt text; v_id bigint; v numeric; va numeric;
begin
  if eu is null or not public.bsp_mfa_ok() then raise exception 'Sem sessão.'; end if;
  if p_area not in ('laboratorio', 'enfermagem') or p_momento not in ('abertura', 'fecho') then raise exception 'Pedido inválido.'; end if;
  if not (public.bsp_minha_area() = p_area or public.bsp_e_gestor()) then raise exception 'Só a própria área conta o turno.'; end if;
  if p_dia < (now() at time zone 'Africa/Luanda')::date - 1 or p_dia > (now() at time zone 'Africa/Luanda')::date then
    raise exception 'Só se conta o turno de hoje ou de ontem.';
  end if;
  na_escala := exists (select 1 from public.bsp_turno_meus(eu) m where m.area = p_area and m.dia = p_dia and m.turno = p_turno);
  -- Passagem de turno: a abertura compara-se com o último fecho da área.
  if p_momento = 'abertura' then
    select * into ant from turno_contagens where area = p_area and momento = 'fecho' order by criado desc limit 1;
    if found then
      for it in select * from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) loop
        select x into a from jsonb_array_elements(ant.itens) x where x->>'k' = it->>'k' limit 1;
        if a is null then continue; end if;
        foreach txt in array array['q', 'r1', 'r2'] loop
          v := public.bsp_num(it->>txt); va := public.bsp_num(a->>txt);
          -- Reforço recebido da Solange desde o último fecho (30-10-2026, Elmar:
          -- «ela guarda uma parte e fornece outra às áreas e vai reforçando»):
          -- a abertura compara-se com o fecho mais o reforço.
          if txt = 'q' and va is not null then va := va + greatest(0, coalesce(public.bsp_num(it->>'ref'), 0)); end if;
          if v is not null and va is not null and v <> va then
            dif := dif || jsonb_build_array(jsonb_build_object('k', it->>'k', 'campo', txt, 'fecho', public.bsp_num(a->>txt), 'abertura', v)
              || case when txt = 'q' and coalesce(public.bsp_num(it->>'ref'), 0) > 0 then jsonb_build_object('reforco', public.bsp_num(it->>'ref')) else '{}'::jsonb end);
          end if;
        end loop;
      end loop;
    end if;
  end if;
  insert into turno_contagens (area, dia, turno, momento, user_id, itens, frio, motivo, ficheiros, fora_escala, diferencas)
  values (p_area, p_dia, p_turno, p_momento, eu, coalesce(p_itens, '[]'::jsonb), p_frio, nullif(left(trim(coalesce(p_motivo, '')), 1000), ''),
          coalesce(p_ficheiros, '[]'::jsonb), not na_escala, dif)
  on conflict (area, dia, turno, momento) do nothing
  returning id into v_id;
  if v_id is null then return jsonb_build_object('ok', true, 'ja', true); end if;

  -- Abaixo do mínimo.
  select itens into lista from turno_listas where area = p_area;
  for it in select * from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) loop
    select x into a from jsonb_array_elements(coalesce(lista, '[]'::jsonb)) x where x->>'k' = it->>'k' limit 1;
    v := least(coalesce(public.bsp_num(it->>'q'), 1e9), coalesce(public.bsp_num(it->>'r1'), 1e9), coalesce(public.bsp_num(it->>'r2'), 1e9));
    if a is not null and coalesce(public.bsp_num(a->>'minimo'), 0) > 0 and v < 1e9 and v <= public.bsp_num(a->>'minimo') then
      baixos := baixos || (it->>'k' || ' (' || v::text || ')');
    end if;
  end loop;

  nome_area := case p_area when 'laboratorio' then 'Laboratório' else 'Enfermagem' end;
  select coalesce(array_agg(distinct x), '{}') into para
    from public.bsp_escalas_responsaveis() r, unnest(r.ids) x where r.area = p_area;
  para := array(select distinct unnest(para || array['u1', 'u2', 'u14']));
  if jsonb_array_length(dif) > 0 then
    txt := nome_area || ', ' || to_char(p_dia, 'DD-MM') || ' (' || p_turno || '): a abertura não bate com o último fecho em '
        || jsonb_array_length(dif) || ' linha(s): '
        || (select string_agg((d->>'k') || ' ' || case when d->>'campo' = 'q' then '' else upper(d->>'campo') || ' ' end
              || (d->>'fecho') || coalesce(' + reforço ' || (d->>'reforco'), '') || ' → ' || (d->>'abertura'), '; ')
              from jsonb_array_elements(dif) d) || '.' || coalesce(' Motivo: ' || nullif(trim(p_motivo), ''), '');
    insert into novidades (titulo, texto, grupos, destino) values ('Passagem de turno com diferenças', txt, array['gestao', 'direccao-clinica', p_area], null);
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'exceto', eu, 'titulo', 'Passagem de turno com diferenças',
      'corpo', left(txt, 160), 'url', '#/relatorios', 'tag', 'turno-' || v_id));
  end if;
  if array_length(baixos, 1) > 0 then
    txt := nome_area || ', ' || to_char(p_dia, 'DD-MM') || ': abaixo do mínimo: ' || array_to_string(baixos, ', ') || '.';
    insert into novidades (titulo, texto, grupos, destino) values ('Stock baixo no turno', txt, array['gestao', p_area], null);
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para || array['u22']), 'exceto', eu, 'titulo', 'Stock baixo no turno',
      'corpo', left(txt, 160), 'url', '#/relatorios', 'tag', 'turno-min-' || v_id));
  end if;
  if not na_escala then
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'exceto', eu, 'titulo', 'Turno aberto fora da escala',
      'corpo', nome_area || ', ' || to_char(p_dia, 'DD-MM') || ' (' || p_turno || '): ' || p_momento || ' feita por quem não está na escala.',
      'url', '#/relatorios', 'tag', 'turno-fora-' || v_id));
  end if;
  return jsonb_build_object('ok', true, 'diferencas', dif, 'baixos', to_jsonb(baixos));
end $f$;

revoke all on function public.bsp_turno_lista_gravar(text, jsonb) from public, anon;
revoke all on function public.bsp_turno_pendente() from public, anon;
revoke all on function public.bsp_turno_base(text) from public, anon;
revoke all on function public.bsp_turno_contar(text, date, text, text, jsonb, numeric, text, jsonb) from public, anon;
grant execute on function public.bsp_turno_lista_gravar(text, jsonb) to authenticated;
grant execute on function public.bsp_turno_pendente() to authenticated;
grant execute on function public.bsp_turno_base(text) to authenticated;
grant execute on function public.bsp_turno_contar(text, date, text, text, jsonb, numeric, text, jsonb) to authenticated;

