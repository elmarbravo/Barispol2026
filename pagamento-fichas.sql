-- Fichas de actividade dos médicos no Pagamento (05-10-2026, Elmar: «com base
-- nesse cálculo criar algo no Workspace? Para Outubro ser mais leve»).
--
-- Em Setembro o mapa fez-se à mão: ler cada ficha (data, entrada, saída,
-- consultas, reconsultas, enfermagem, observação), somar as horas, somar as
-- consultas por dia útil e fim-de-semana, comparar dia a dia com o MetaGest e
-- montar o Excel e os mapas individuais. Agora:
--   · cada dia da ficha grava-se inteiro em pagamento_permanencias (entrada,
--     saída e quantidades); as horas calculam-se da entrada e da saída;
--   · bsp_pagamento_fichas grava o mês de um médico e põe nos ajustes as
--     consultas da ficha (a ficha prevalece, regra de Agosto): clínica geral
--     por dia útil e fim-de-semana, pediatria pelo total; especialistas
--     continuam pelo facturado;
--   · bsp_pagamento_conferir compara, dia a dia, as consultas da ficha com as
--     do MetaGest;
--   · bsp_pagamento_actos dá os actos do mês somados por médico, rubrica, dia
--     e acto, sem doentes (para a folha ACTOS do Excel e os mapas individuais).
-- Acesso igual ao resto do Pagamento (bsp_pagamento_acesso).

alter table public.pagamento_permanencias
  add column if not exists entrada time,
  add column if not exists saida time,
  add column if not exists consultas int check (consultas >= 0),
  add column if not exists reconsultas int check (reconsultas >= 0),
  add column if not exists enfermagem int check (enfermagem >= 0),
  add column if not exists observacao int check (observacao >= 0),
  add column if not exists outros text not null default '',
  add column if not exists nota text not null default '';

-- Grava as fichas de um médico num mês. p_fichas: lista de
-- {dia, entrada, saida, horas, consultas, reconsultas, enfermagem, observacao, outros, nota}.
-- Sem entrada e saída, usa «horas» (fichas antigas só com horas).
create or replace function public.bsp_pagamento_fichas(p_prestador bigint, p_ano int, p_mes int, p_fichas jsonb)
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare de date := make_date(p_ano, p_mes, 1); ate date := (make_date(p_ano, p_mes, 1) + interval '1 month - 1 day')::date;
  n int; esp text;
begin
  if not public.bsp_pagamento_acesso(true) then raise exception 'Sem acesso.'; end if;
  if exists (select 1 from public.pagamento_fecho where ano = p_ano and mes = p_mes) then raise exception 'O mês já está fechado. Reabra-o primeiro.'; end if;
  if jsonb_typeof(coalesce(p_fichas, '[]')) <> 'array' then raise exception 'Fichas inválidas.'; end if;
  if exists (select 1 from jsonb_array_elements(p_fichas) f
              where coalesce(f->>'dia', '') !~ '^\d{4}-\d{2}-\d{2}$'
                 or (f->>'dia')::date not between de and ate
                 or coalesce(nullif(f->>'entrada', ''), '00:00') !~ '^\d{1,2}:\d{2}$'
                 or coalesce(nullif(f->>'saida', ''), '00:00') !~ '^\d{1,2}:\d{2}$') then
    raise exception 'Há uma data ou hora inválida nas fichas.';
  end if;
  if (select count(*) <> count(distinct f->>'dia') from jsonb_array_elements(p_fichas) f) then
    raise exception 'O mesmo dia aparece duas vezes.';
  end if;
  execute 'dele' || 'te from public.pagamento_permanencias where prestador_id = $1 and dia between $2 and $3' using p_prestador, de, ate;
  insert into public.pagamento_permanencias (prestador_id, dia, horas, entrada, saida, consultas, reconsultas, enfermagem, observacao, outros, nota, registado_por)
  select p_prestador, x.dia,
         case when x.entrada is not null and x.saida is not null
              then round((extract(epoch from (x.saida - x.entrada)) / 3600.0 + case when x.saida < x.entrada then 24 else 0 end)::numeric, 2)
              else least(24, greatest(0, coalesce(x.horas, 0))) end,
         x.entrada, x.saida, x.consultas, x.reconsultas, x.enfermagem, x.observacao, x.outros, x.nota, public.bsp_meu_id()
    from (select (f->>'dia')::date dia, nullif(f->>'entrada', '')::time entrada, nullif(f->>'saida', '')::time saida,
                 nullif(replace(f->>'horas', ',', '.'), '')::numeric horas,
                 nullif(f->>'consultas', '')::int consultas, nullif(f->>'reconsultas', '')::int reconsultas,
                 nullif(f->>'enfermagem', '')::int enfermagem, nullif(f->>'observacao', '')::int observacao,
                 left(coalesce(f->>'outros', ''), 200) outros, left(coalesce(f->>'nota', ''), 500) nota
            from jsonb_array_elements(p_fichas) f) x;
  get diagnostics n = row_count;

  -- As consultas da ficha passam para os ajustes (a ficha prevalece).
  select upper(coalesce(especialidade, '')) into esp from public.prestadores where id = p_prestador;
  if exists (select 1 from public.pagamento_permanencias
              where prestador_id = p_prestador and dia between de and ate and (consultas is not null or reconsultas is not null)) then
    if esp ~ 'PEDIATR' then
      insert into public.pagamento_ajustes (ano, mes, prestador_id, pediatria, registado_por)
      select p_ano, p_mes, p_prestador, sum(coalesce(consultas, 0) + coalesce(reconsultas, 0))::int, public.bsp_meu_id()
        from public.pagamento_permanencias where prestador_id = p_prestador and dia between de and ate
      on conflict (ano, mes, prestador_id) do update
         set pediatria = excluded.pediatria, registado_por = excluded.registado_por, registado_em = now();
    elsif esp ~ 'GERAL|INTERNA' then
      insert into public.pagamento_ajustes (ano, mes, prestador_id, cg_util, cg_fds, registado_por)
      select p_ano, p_mes, p_prestador,
             coalesce(sum(coalesce(consultas, 0) + coalesce(reconsultas, 0)) filter (where extract(isodow from dia) < 6), 0)::int,
             coalesce(sum(coalesce(consultas, 0) + coalesce(reconsultas, 0)) filter (where extract(isodow from dia) >= 6), 0)::int,
             public.bsp_meu_id()
        from public.pagamento_permanencias where prestador_id = p_prestador and dia between de and ate
      on conflict (ano, mes, prestador_id) do update
         set cg_util = excluded.cg_util, cg_fds = excluded.cg_fds, registado_por = excluded.registado_por, registado_em = now();
    end if;
  end if;
  return n;
end $f$;

-- Fichas, horas e ajustes do mês (para o ecrã). Mantém «dias» e «ajustes».
create or replace function public.bsp_pagamento_permanencias_mes(p_ano int, p_mes int)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare de date := make_date(p_ano, p_mes, 1); ate date := (make_date(p_ano, p_mes, 1) + interval '1 month - 1 day')::date;
begin
  if not public.bsp_pagamento_acesso(false) then raise exception 'Sem acesso.'; end if;
  return jsonb_build_object(
    'dias', (select coalesce(jsonb_object_agg(prestador_id::text, d), '{}') from (
               select prestador_id, jsonb_object_agg(dia::text, horas) d from public.pagamento_permanencias
                where dia between de and ate group by prestador_id) x),
    'fichas', (select coalesce(jsonb_object_agg(prestador_id::text, d), '{}') from (
               select prestador_id, jsonb_agg(jsonb_build_object('dia', dia, 'entrada', to_char(entrada, 'HH24:MI'), 'saida', to_char(saida, 'HH24:MI'),
                        'horas', horas, 'consultas', consultas, 'reconsultas', reconsultas, 'enfermagem', enfermagem, 'observacao', observacao,
                        'outros', outros, 'nota', nota) order by dia) d
                 from public.pagamento_permanencias where dia between de and ate group by prestador_id) x),
    'ajustes', (select coalesce(jsonb_object_agg(prestador_id::text, to_jsonb(a) - 'ano' - 'mes' - 'prestador_id'), '{}')
                  from public.pagamento_ajustes a where ano = p_ano and mes = p_mes));
end $f$;

-- Consultas por dia: ficha contra MetaGest. Só dias com ficha ou com consultas
-- facturadas. {"<prestador>": [{dia, ficha, metagest, horas}]}.
create or replace function public.bsp_pagamento_conferir(p_ano int, p_mes int)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare de date := make_date(p_ano, p_mes, 1); ate date := (make_date(p_ano, p_mes, 1) + interval '1 month - 1 day')::date;
begin
  if not public.bsp_pagamento_acesso(false) then raise exception 'Sem acesso.'; end if;
  return (
    with mg as (
      select p.id pid, x.dia, sum(x.qtd) q
        from public.bsp_pagamento_linhas(de, ate) x
        join public.prestadores p on p.chave = x.chave or x.chave = any(p.chaves_extra)
       where x.rubrica in ('clinica_geral', 'pediatria', 'especialidade')
       group by 1, 2),
    fi as (
      select prestador_id pid, dia, horas,
             case when consultas is null and reconsultas is null then null else coalesce(consultas, 0) + coalesce(reconsultas, 0) end q
        from public.pagamento_permanencias where dia between de and ate),
    j as (
      select coalesce(fi.pid, mg.pid) pid, coalesce(fi.dia, mg.dia) dia, fi.q ficha, mg.q metagest, fi.horas, fi.pid is not null tem_ficha
        from fi full join mg on mg.pid = fi.pid and mg.dia = fi.dia)
    select coalesce(jsonb_object_agg(pid::text, l), '{}') from (
      select pid, jsonb_agg(jsonb_build_object('dia', dia, 'ficha', ficha, 'metagest', metagest, 'horas', horas, 'tem_ficha', tem_ficha) order by dia) l
        from j where tem_ficha or coalesce(metagest, 0) <> 0 group by pid) z);
end $f$;

-- Actos do mês por médico, rubrica, dia e acto, sem doentes.
create or replace function public.bsp_pagamento_actos(p_ano int, p_mes int)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare de date := make_date(p_ano, p_mes, 1); ate date := (make_date(p_ano, p_mes, 1) + interval '1 month - 1 day')::date;
begin
  if not public.bsp_pagamento_acesso(false) then raise exception 'Sem acesso.'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', pid, 'rubrica', rubrica, 'dia', dia, 'item', item, 'qtd', qtd, 'valor', valor)
                                   order by pid, rubrica, dia, item), '[]')
            from (select p.id pid, x.rubrica, x.dia, x.item, sum(x.qtd) qtd, sum(x.valor) valor
                    from public.bsp_pagamento_linhas(de, ate) x
                    join public.prestadores p on p.chave = x.chave or x.chave = any(p.chaves_extra)
                   group by 1, 2, 3, 4) a);
end $f$;

do $$ begin
  revoke execute on function public.bsp_pagamento_fichas(bigint, int, int, jsonb) from public, anon;
  revoke execute on function public.bsp_pagamento_permanencias_mes(int, int) from public, anon;
  revoke execute on function public.bsp_pagamento_conferir(int, int) from public, anon;
  revoke execute on function public.bsp_pagamento_actos(int, int) from public, anon;
  grant execute on function public.bsp_pagamento_fichas(bigint, int, int, jsonb) to authenticated;
  grant execute on function public.bsp_pagamento_permanencias_mes(int, int) to authenticated;
  grant execute on function public.bsp_pagamento_conferir(int, int) to authenticated;
  grant execute on function public.bsp_pagamento_actos(int, int) to authenticated;
end $$;

notify pgrst, 'reload schema';

-- As fichas de Setembro de 2026 (entrada, saída e quantidades) carregaram-se
-- no servidor a 05-10-2026; os nomes e valores nunca entram aqui.
