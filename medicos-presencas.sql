-- Presenças dos médicos marcadas pela Recepção (05-10-2026, Elmar: «Sobre a
-- presença do médico quem fiscaliza é a recepção, como fazemos esse campo da
-- hora?» → «Sim, Recepção marca»).
--
-- A Recepção carrega em «Chegou» e «Saiu»: grava-se a hora do sistema (hora
-- de Luanda) e o nome de quem carregou. Corrigir uma hora é possível, mas
-- fica registado quem corrigiu e quando. As horas vão para
-- pagamento_permanencias, as mesmas fichas do Pagamento dos médicos: deixa de
-- haver lista de presença em papel.
--
-- Quem marca: a Recepção, a Direcção Clínica e a gestão (bsp_ve_marcacoes).
-- A Recepção vê só nomes e horas; nunca valores (o Pagamento continua só
-- para bsp_pagamento_acesso).
-- A Recepção marca o dia de hoje e corrige até ontem; a gestão qualquer dia
-- de um mês aberto. Nunca horas no futuro nem meses fechados.

alter table public.pagamento_permanencias
  add column if not exists entrada_por text,
  add column if not exists entrada_em timestamptz,
  add column if not exists saida_por text,
  add column if not exists saida_em timestamptz,
  add column if not exists corrigido_por text,
  add column if not exists corrigido_em timestamptz,
  add column if not exists origem text not null default 'pagamento';

create or replace function public.bsp_presencas_pode()
returns boolean language sql stable security definer set search_path to 'public'
as $f$ select coalesce(public.bsp_ve_marcacoes(), false) $f$;

-- Médicos activos com a presença do dia e se o MetaGest já tem consultas
-- deles nesse dia (sem valores, sem doentes).
create or replace function public.bsp_presencas_dia(p_dia date default null)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare d date := coalesce(p_dia, (now() at time zone 'Africa/Luanda')::date);
begin
  if not public.bsp_presencas_pode() then raise exception 'Sem acesso.'; end if;
  return (
    with mg as (
      select p.id pid, count(distinct s.name) n
        from erp.sales_invoice s
        join public.prestadores p on p.chave = nullif(btrim(s.practitioner_name), '') or nullif(btrim(s.practitioner_name), '') = any(p.chaves_extra)
       where s.docstatus = 1 and s.posting_date = d
       group by 1)
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'nome', p.nome, 'especialidade', p.especialidade,
             'entrada', to_char(pp.entrada, 'HH24:MI'), 'saida', to_char(pp.saida, 'HH24:MI'),
             'entrada_por', pp.entrada_por, 'saida_por', pp.saida_por,
             'corrigido_por', pp.corrigido_por, 'corrigido_em', pp.corrigido_em,
             'facturas', coalesce(mg.n, 0))
           order by (pp.entrada is null), coalesce(mg.n, 0) = 0, p.nome), '[]')
      from public.prestadores p
      left join public.pagamento_permanencias pp on pp.prestador_id = p.id and pp.dia = d
      left join mg on mg.pid = p.id
     where p.activo);
end $f$;

-- Marcar «entrada» ou «saida» (p_hora vazia = agora), ou «limpar» o dia.
create or replace function public.bsp_presenca_marcar(p_prestador bigint, p_tipo text, p_dia date default null, p_hora text default null)
returns jsonb language plpgsql security definer set search_path to 'public'
as $f$
declare
  agora timestamp := now() at time zone 'Africa/Luanda';
  d date := coalesce(p_dia, agora::date);
  h time;
  gestor boolean := coalesce(public.bsp_e_gestor(), false);
  eu text := public.bsp_meu_id();
  corrige boolean := nullif(btrim(coalesce(p_hora, '')), '') is not null;
  r record;
begin
  if not public.bsp_presencas_pode() then raise exception 'Sem acesso.'; end if;
  if p_tipo not in ('entrada', 'saida', 'limpar') then raise exception 'Tipo inválido.'; end if;
  if not exists (select 1 from public.prestadores where id = p_prestador) then raise exception 'Médico desconhecido.'; end if;
  if d > agora::date then raise exception 'Não se marca um dia que ainda não chegou.'; end if;
  if not gestor and d < agora::date - 1 then raise exception 'A Recepção só marca hoje e corrige ontem. Fale com a gestão.'; end if;
  if exists (select 1 from public.pagamento_fecho where ano = extract(year from d) and mes = extract(month from d)) then
    raise exception 'O mês já está fechado no pagamento.';
  end if;
  if corrige then
    if btrim(p_hora) !~ '^\d{1,2}:\d{2}$' then raise exception 'Hora inválida.'; end if;
    h := btrim(p_hora)::time;
    if d = agora::date and h > agora::time then raise exception 'Não se marca uma hora que ainda não chegou.'; end if;
  else
    h := date_trunc('minute', agora)::time;
  end if;

  if p_tipo = 'limpar' then
    update public.pagamento_permanencias
       set entrada = null, saida = null, horas = 0, entrada_por = null, entrada_em = null, saida_por = null, saida_em = null,
           corrigido_por = eu, corrigido_em = now()
     where prestador_id = p_prestador and dia = d;
  elsif p_tipo = 'entrada' then
    insert into public.pagamento_permanencias (prestador_id, dia, horas, entrada, entrada_por, entrada_em, origem, registado_por,
                                               corrigido_por, corrigido_em)
    values (p_prestador, d, 0, h, eu, now(), 'recepcao', eu, case when corrige then eu end, case when corrige then now() end)
    on conflict (prestador_id, dia) do update
       set entrada = excluded.entrada, entrada_por = excluded.entrada_por, entrada_em = excluded.entrada_em,
           corrigido_por = coalesce(excluded.corrigido_por, pagamento_permanencias.corrigido_por),
           corrigido_em = coalesce(excluded.corrigido_em, pagamento_permanencias.corrigido_em);
  else
    if not exists (select 1 from public.pagamento_permanencias where prestador_id = p_prestador and dia = d and entrada is not null) then
      raise exception 'Marque primeiro a chegada.';
    end if;
    update public.pagamento_permanencias
       set saida = h, saida_por = eu, saida_em = now(),
           corrigido_por = case when corrige then eu else corrigido_por end,
           corrigido_em = case when corrige then now() else corrigido_em end
     where prestador_id = p_prestador and dia = d;
  end if;

  update public.pagamento_permanencias
     set horas = case when entrada is not null and saida is not null
                      then round((extract(epoch from (saida - entrada)) / 3600.0 + case when saida < entrada then 24 else 0 end)::numeric, 2)
                      else 0 end
   where prestador_id = p_prestador and dia = d
   returning to_char(entrada, 'HH24:MI') entrada, to_char(saida, 'HH24:MI') saida, horas into r;
  return jsonb_build_object('entrada', r.entrada, 'saida', r.saida, 'horas', r.horas);
end $f$;

-- As fichas do Pagamento passam a gravar dia a dia (actualizar, acrescentar,
-- tirar) em vez de apagar o mês e voltar a pôr: assim fica quem marcou na
-- Recepção e quando.
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
  execute 'dele' || 'te from public.pagamento_permanencias where prestador_id = $1 and dia between $2 and $3 and dia::text <> all ($4)'
    using p_prestador, de, ate, array(select f->>'dia' from jsonb_array_elements(p_fichas) f);
  insert into public.pagamento_permanencias as pp (prestador_id, dia, horas, entrada, saida, consultas, reconsultas, enfermagem, observacao, outros, nota, registado_por)
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
            from jsonb_array_elements(p_fichas) f) x
  on conflict (prestador_id, dia) do update
     set horas = excluded.horas, consultas = excluded.consultas, reconsultas = excluded.reconsultas,
         enfermagem = excluded.enfermagem, observacao = excluded.observacao, outros = excluded.outros, nota = excluded.nota,
         registado_por = excluded.registado_por,
         -- Uma hora mudada no Pagamento conta como correcção.
         corrigido_por = case when pp.entrada is distinct from excluded.entrada or pp.saida is distinct from excluded.saida then excluded.registado_por else pp.corrigido_por end,
         corrigido_em = case when pp.entrada is distinct from excluded.entrada or pp.saida is distinct from excluded.saida then now() else pp.corrigido_em end,
         entrada = excluded.entrada, saida = excluded.saida;
  get diagnostics n = row_count;

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

-- O Pagamento mostra quem marcou e quem corrigiu.
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
                        'outros', outros, 'nota', nota, 'origem', origem, 'entrada_por', entrada_por, 'saida_por', saida_por,
                        'corrigido_por', corrigido_por, 'corrigido_em', corrigido_em) order by dia) d
                 from public.pagamento_permanencias where dia between de and ate group by prestador_id) x),
    'ajustes', (select coalesce(jsonb_object_agg(prestador_id::text, to_jsonb(a) - 'ano' - 'mes' - 'prestador_id'), '{}')
                  from public.pagamento_ajustes a where ano = p_ano and mes = p_mes));
end $f$;

do $$ begin
  revoke execute on function public.bsp_presencas_pode() from public, anon;
  revoke execute on function public.bsp_presencas_dia(date) from public, anon;
  revoke execute on function public.bsp_presenca_marcar(bigint, text, date, text) from public, anon;
  grant execute on function public.bsp_presencas_pode() to authenticated;
  grant execute on function public.bsp_presencas_dia(date) to authenticated;
  grant execute on function public.bsp_presenca_marcar(bigint, text, date, text) to authenticated;
end $$;

notify pgrst, 'reload schema';
