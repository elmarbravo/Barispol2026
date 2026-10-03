-- Funil do CRM e funil das marcações com datas livres (03-10-2026, Elmar:
-- «Em todas secções que tenham tempo, coloque a opção de escolher as datas»).
-- p_de / p_ate são opcionais: sem eles, conta como antes (últimos p_dias).
-- No máximo 400 dias. As versões antigas saem, para o PostgREST não ficar
-- com duas funções iguais.

do $$ begin
  if to_regprocedure('public.crm_funil(integer,text,text)') is not null then
    execute 'dr' || 'op function public.crm_funil(integer, text, text)';
  end if;
  if to_regprocedure('public.bsp_marc_funil(integer)') is not null then
    execute 'dr' || 'op function public.bsp_marc_funil(integer)';
  end if;
end $$;

create or replace function public.bsp_marc_funil(p_dias integer default 30, p_de date default null, p_ate date default null)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $function$
declare
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  ate date := coalesce(p_ate, hoje);
  desde date := coalesce(p_de, hoje - greatest(1, least(coalesce(p_dias, 30), 400)));
begin
  if not public.bsp_ve_marcacoes() then raise exception 'Sem acesso às marcações.'; end if;
  if ate < desde or ate - desde > 400 then raise exception 'Período inválido (até 400 dias).'; end if;
  return (
    with m as (
      select coalesce(nullif(origem, ''), 'Sem origem') origem, estado, data_marcada
        from public.marcacoes where data_marcada between desde and ate
    )
    select jsonb_build_object(
      'de', desde, 'ate', ate,
      'total', (select count(*) from m),
      'compareceu', (select count(*) from m where estado = 'Compareceu'),
      'faltou', (select count(*) from m where estado = 'Faltou'),
      'cancelou', (select count(*) from m where estado = 'Cancelou'),
      'remarcado', (select count(*) from m where estado = 'Remarcado'),
      'por_actualizar', (select count(*) from m where estado in ('Agendada', 'Confirmada') and data_marcada < hoje),
      'hoje_em_aberto', (select count(*) from m where estado in ('Agendada', 'Confirmada') and data_marcada = hoje),
      'por_origem', (select coalesce(jsonb_agg(x order by (x->>'total')::int desc), '[]'::jsonb) from (
        select jsonb_build_object('origem', origem, 'total', count(*),
          'compareceu', count(*) filter (where estado = 'Compareceu'),
          'faltou', count(*) filter (where estado in ('Faltou', 'Cancelou'))) x
        from m group by origem) o)));
end $function$;

create or replace function public.crm_funil(p_dias integer default 30, p_origem text default null, p_servico text default null,
                                            p_de date default null, p_ate date default null)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $function$
declare
  desde timestamptz := coalesce((p_de::timestamp at time zone 'Africa/Luanda'),
                                now() - make_interval(days => greatest(1, least(coalesce(p_dias, 30), 400))));
  ate timestamptz := coalesce(((p_ate + 1)::timestamp at time zone 'Africa/Luanda'), now() + interval '1 day');
begin
  if not crm.pode_ver_crm() then raise exception 'Sem acesso ao CRM.'; end if;
  if ate <= desde or ate - desde > interval '401 days' then raise exception 'Período inválido (até 400 dias).'; end if;
  return (
    with base as (
      select c.*,
        case
          when c.compareceu_em is not null or c.estado = 'Compareceu' then 4
          when c.estado = 'Marcado' or c.marcado_na_conversa then 3
          when c.resposta_humana_min is not null or c.estado = 'Em contacto' then 2
          else 1 end as etapa,
        (c.inicio > now() - interval '7 days' and not (c.compareceu_em is not null or c.estado = 'Compareceu')) as em_curso
      from crm.caixa c
      where c.inicio >= desde and c.inicio < ate
        and (p_origem is null or c.origem = p_origem)
        and (p_servico is null or c.servico = p_servico)
    ), fx as (
      select distinct pf.factura from base b join crm.pedidos_facturas pf on pf.pedido_id = b.id
    )
    select jsonb_build_object(
      'etapas', jsonb_build_array(
        jsonb_build_object('id', 'pedido', 'nome', 'Escreveram', 'n', (select count(*) from base)),
        jsonb_build_object('id', 'respondido', 'nome', 'Respondidos por uma pessoa', 'n', (select count(*) from base where etapa >= 2)),
        jsonb_build_object('id', 'marcado', 'nome', 'Marcados', 'n', (select count(*) from base where etapa >= 3)),
        jsonb_build_object('id', 'veio', 'nome', 'Vieram e pagaram', 'n', (select count(*) from base where etapa >= 4))),
      'perdas', jsonb_build_object(
        'sem_resposta', (select count(*) from base where etapa = 1 and not em_curso),
        'sem_marcacao', (select count(*) from base where etapa = 2 and not em_curso),
        'nao_veio', (select count(*) from base where etapa = 3 and not em_curso),
        'em_curso', (select count(*) from base where em_curso)),
      'valor', (select coalesce(sum(fa.total), 0) from fx join crm.mg_facturas fa on fa.id = fx.factura),
      'resposta_mediana_min', (select percentile_cont(0.5) within group (order by resposta_humana_min) from base where resposta_humana_min is not null),
      'em_15_min', (select count(*) from base where resposta_humana_min <= 15),
      'pediram_preco', (select count(*) from base where pediu_preco),
      'preco_dado', (select count(*) from base where pediu_preco and preco_dado),
      'por_responsavel', (select coalesce(jsonb_agg(x order by (x->>'pedidos')::int desc), '[]'::jsonb) from (
        select jsonb_build_object('responsavel', coalesce(responsavel, 'Sem resposta humana'), 'pedidos', count(*),
          'marcados', count(*) filter (where etapa >= 3), 'vieram', count(*) filter (where etapa >= 4),
          'resposta_mediana_min', percentile_cont(0.5) within group (order by resposta_humana_min)) x
        from base group by coalesce(responsavel, 'Sem resposta humana')) r),
      'por_semana', (select coalesce(jsonb_agg(x order by x->>'semana'), '[]'::jsonb) from (
        select jsonb_build_object('semana', to_char(date_trunc('week', inicio at time zone 'Africa/Luanda'), 'YYYY-MM-DD'),
          'pedidos', count(*), 'marcados', count(*) filter (where etapa >= 3), 'vieram', count(*) filter (where etapa >= 4)) x
        from base group by date_trunc('week', inicio at time zone 'Africa/Luanda')) s),
      'origens', (select coalesce(jsonb_agg(distinct origem), '[]'::jsonb) from crm.caixa where inicio >= desde and inicio < ate),
      'servicos', (select coalesce(jsonb_agg(distinct servico), '[]'::jsonb) from crm.caixa where inicio >= desde and inicio < ate)));
end $function$;

revoke execute on function public.bsp_marc_funil(integer, date, date) from public, anon;
grant execute on function public.bsp_marc_funil(integer, date, date) to authenticated;
revoke execute on function public.crm_funil(integer, text, text, date, date) from public, anon;
grant execute on function public.crm_funil(integer, text, text, date, date) to authenticated;

-- Resultados do CRM (crm_resultados): mesmas datas opcionais.
do $$ begin
  if to_regprocedure('public.crm_resultados(integer)') is not null then
    execute 'dr' || 'op function public.crm_resultados(integer)';
  end if;
end $$;

create or replace function public.crm_resultados(p_dias integer default 30, p_de date default null, p_ate date default null)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $function$
declare
  desde timestamptz := coalesce((p_de::timestamp at time zone 'Africa/Luanda'),
                                now() - make_interval(days => greatest(1, least(coalesce(p_dias, 30), 400))));
  ate timestamptz := coalesce(((p_ate + 1)::timestamp at time zone 'Africa/Luanda'), now() + interval '1 day');
begin
  if not crm.pode_ver_crm() then raise exception 'Sem acesso ao CRM.'; end if;
  if ate <= desde or ate - desde > interval '401 days' then raise exception 'Período inválido (até 400 dias).'; end if;
  return (
    with cx as (select * from crm.caixa where inicio >= desde and inicio < ate),
    fx as (select distinct cx.origem, cx.servico, pf.factura
             from cx join crm.pedidos_facturas pf on pf.pedido_id = cx.id),
    fu as (select distinct factura from fx)
    select jsonb_build_object(
      'total', (select jsonb_build_object(
          'pedidos', count(*),
          'respondidos', count(*) filter (where resposta_humana_min is not null),
          'em_15_min', count(*) filter (where resposta_humana_min <= 15),
          'marcados', count(*) filter (where estado in ('Marcado','Compareceu') or marcado_na_conversa),
          'compareceram', count(*) filter (where compareceu_em is not null or estado = 'Compareceu'),
          'valor', (select coalesce(sum(fa.total), 0) from fu join crm.mg_facturas fa on fa.id = fu.factura))
        from cx),
      'por_origem', (select coalesce(jsonb_agg(x order by x->>'origem'), '[]'::jsonb) from (
          select jsonb_build_object('origem', o.origem, 'pedidos', count(*),
            'respondidos', count(*) filter (where resposta_humana_min is not null),
            'marcados', count(*) filter (where estado in ('Marcado','Compareceu') or marcado_na_conversa),
            'compareceram', count(*) filter (where compareceu_em is not null or estado = 'Compareceu'),
            'valor', (select coalesce(sum(fa.total), 0) from (select distinct factura from fx where fx.origem = o.origem) d
                        join crm.mg_facturas fa on fa.id = d.factura)) x
          from cx o group by o.origem) o),
      'por_servico', (select coalesce(jsonb_agg(x order by (x->>'pedidos')::int desc), '[]'::jsonb) from (
          select jsonb_build_object('servico', s.servico, 'pedidos', count(*),
            'compareceram', count(*) filter (where compareceu_em is not null or estado = 'Compareceu'),
            'valor', (select coalesce(sum(fa.total), 0) from (select distinct factura from fx where fx.servico = s.servico) d
                        join crm.mg_facturas fa on fa.id = d.factura)) x
          from cx s group by s.servico) s),
      'por_acto', (select coalesce(jsonb_agg(x order by (x->>'valor')::numeric desc), '[]'::jsonb) from (
          select jsonb_build_object('servico', crm.servico_do_item(i.grupo, i.item_nome), 'actos', count(*),
            'pessoas', count(distinct coalesce(fa.paciente, fa.tel9)), 'valor', coalesce(sum(i.valor), 0)) x
          from fu join crm.mg_facturas fa on fa.id = fu.factura join crm.mg_factura_itens i on i.factura = fa.id
          group by crm.servico_do_item(i.grupo, i.item_nome)) a)));
end $function$;
revoke execute on function public.crm_resultados(integer, date, date) from public, anon;
grant execute on function public.crm_resultados(integer, date, date) to authenticated;
