-- Barispol Workspace · funil de vendas do CRM
-- Pedido do Elmar, 01-10-2026: «Preciso ter um funil de vendas». Aplicado no
-- projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais
-- do que uma vez.
--
-- Usa os pedidos do WhatsApp (crm.caixa: só doentes, sem os contactos
-- excluídos). Cada pedido fica na etapa mais avançada a que chegou, para o
-- funil nunca subir:
--   1 Pedido (escreveu)  2 Respondido por uma pessoa  3 Marcado
--   4 Veio e pagou (factura no MetaGest nos 30 dias seguintes)
-- Perdas: sem resposta; respondido sem marcação; marcado e não veio. Os
-- pedidos dos últimos 7 dias que ainda não vieram contam à parte («em
-- curso»): ainda podem avançar.
-- Só quem vê o CRM (crm.pode_ver_crm). Sem nomes nem telefones.

create or replace function public.crm_funil(p_dias integer default 30, p_origem text default null, p_servico text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare desde timestamptz := now() - make_interval(days => greatest(1, least(coalesce(p_dias, 30), 400)));
begin
  if not crm.pode_ver_crm() then raise exception 'Sem acesso ao CRM.'; end if;
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
      where c.inicio >= desde
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
      'origens', (select coalesce(jsonb_agg(distinct origem), '[]'::jsonb) from crm.caixa where inicio >= desde),
      'servicos', (select coalesce(jsonb_agg(distinct servico), '[]'::jsonb) from crm.caixa where inicio >= desde)));
end $function$;
revoke all on function public.crm_funil(integer, text, text) from public, anon;
grant execute on function public.crm_funil(integer, text, text) to authenticated;

notify pgrst, 'reload schema';
