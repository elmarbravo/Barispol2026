-- Metas financeiras mensais (28-10-2026, Elmar: «Sim faz a tabela nova e a
-- meta»). Uma linha por mês e indicador, com o valor realista e o alto.
-- Os valores ficam só no servidor (o repositório é público): este ficheiro
-- cria a estrutura e nunca leva números.
--
-- Quem vê e muda: só o Elmar (u1) e a Arlete (u2), pela bsp_ve_salarios
-- (a meta de pessoal é um valor de salários). Nunca pela camada.
--
-- Indicadores: facturado, recebido (das facturas do mês), por_receber (no fim
-- do mês), utentes, pessoal. sentido = 'max' (mais é melhor) ou 'min'
-- (menos é melhor: por_receber, pessoal).
--
-- bsp_financas_metas(mes) devolve as metas e o realizado, com a regra do
-- Painel: facturas submetidas de erp.sales_invoice, notas de crédito
-- abatidas. O pessoal não tem realizado automático (vem das folhas dos RH).
-- O resumo financeiro de segunda-feira lê esta função.

create table if not exists public.financas_metas (
  mes date not null check (extract(day from mes) = 1),
  indicador text not null check (indicador in ('facturado', 'recebido', 'por_receber', 'utentes', 'pessoal')),
  realista numeric not null,
  alta numeric,
  sentido text not null default 'max' check (sentido in ('max', 'min')),
  nota text,
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now(),
  actualizado_em timestamptz not null default now(),
  primary key (mes, indicador)
);

alter table public.financas_metas enable row level security;
revoke all on public.financas_metas from anon;
grant select, insert, update, delete on public.financas_metas to authenticated;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'financas_metas' and policyname = 'financas_metas_u1u2') then
    create policy financas_metas_u1u2 on public.financas_metas for all to authenticated
      using (public.bsp_ve_salarios()) with check (public.bsp_ve_salarios());
  end if;
end $$;

create or replace trigger bsp_auditar after update or delete on public.financas_metas
  for each row execute function public.bsp_auditar();

create or replace function public.bsp_financas_metas(p_mes date default date_trunc('month', current_date)::date)
returns jsonb language plpgsql volatile security definer set search_path to 'public'
as $f$
declare
  v_de date := date_trunc('month', p_mes)::date;
  v_ate date := (date_trunc('month', p_mes) + interval '1 month - 1 day')::date;
  v_real jsonb;
begin
  if not public.bsp_ve_salarios() then raise exception 'As metas financeiras só as vê o Director Geral e os Recursos Humanos.'; end if;
  perform public.bsp_acesso_srv('financas-metas', to_char(v_de, 'YYYY-MM'));

  select jsonb_build_object(
           'facturado', round(coalesce(sum(grand_total), 0)),
           'recebido', round(coalesce(sum(grand_total - outstanding_amount), 0)),
           'por_receber', round(coalesce(sum(outstanding_amount), 0)),
           'utentes', count(distinct patient) filter (where not is_return),
           'dias', count(distinct posting_date))
    into v_real
    from erp.sales_invoice
   where docstatus = 1 and posting_date between v_de and v_ate;

  return jsonb_build_object(
    'mes', to_char(v_de, 'YYYY-MM'),
    'dias_do_mes', extract(day from v_ate)::int,
    'realizado', v_real,
    'metas', (select coalesce(jsonb_agg(jsonb_build_object(
                'indicador', indicador, 'realista', realista, 'alta', alta,
                'sentido', sentido, 'nota', nota) order by indicador), '[]')
                from public.financas_metas where mes = v_de));
end $f$;
revoke execute on function public.bsp_financas_metas(date) from public, anon;
grant execute on function public.bsp_financas_metas(date) to authenticated;
