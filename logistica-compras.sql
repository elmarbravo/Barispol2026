-- Despesas da logística: alimentação e consumíveis de escritório (06-10-2026,
-- Elmar: «para o controle da Arlete, logística: vê o que fazer com estes
-- dados» e «e os alimentos, gestão de comida»). Substitui as folhas de Excel
-- «Controle de gastos com a alimentação» e «Consumíveis de escritório».
--
-- Uma linha por compra. A previsão da próxima compra e os alertas calculam-se
-- no ecrã (LogisticaPainel): média dos últimos 3 meses com compras; mês acima
-- da média em mais de 30% fica a vermelho.
-- forma = 'Adiantamento': dinheiro entregue antes da compra; fica «por acertar»
-- até ter o n.º da factura.
-- Quem vê e regista: a regra dos consumos (bsp_ve_consumos: Elmar, Arlete,
-- Emmanuel, Serviços Gerais e gestão). Só a gestão apaga.
-- As compras antigas foram importadas das folhas da Arlete directamente no
-- servidor (nota «Folha da Arlete»); os valores não entram no repositório.
-- Sem «drop» (a ferramenta do servidor fica à espera de confirmação).

create table if not exists public.logistica_compras (
  id bigint generated always as identity primary key,
  categoria text not null check (categoria in ('alimentacao', 'escritorio', 'limpeza', 'agua', 'gas', 'outro')),
  descricao text not null default '',
  data date not null,
  valor numeric(14, 2) not null check (valor > 0),
  forma text not null default 'Compra' check (forma in ('Compra', 'Adiantamento')),
  factura text not null default '',
  fornecedor text not null default '',
  nota text not null default '',
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now()
);
create index if not exists logistica_compras_data on public.logistica_compras (categoria, data);
alter table public.logistica_compras enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'logistica_compras' and policyname = 'logistica_ler') then
    create policy logistica_ler on public.logistica_compras for select to authenticated using (public.bsp_ve_consumos());
    create policy logistica_criar on public.logistica_compras for insert to authenticated with check (public.bsp_ve_consumos());
    create policy logistica_mudar on public.logistica_compras for update to authenticated using (public.bsp_ve_consumos()) with check (public.bsp_ve_consumos());
    create policy logistica_apagar on public.logistica_compras for delete to authenticated using (public.bsp_e_gestor());
  end if;
end $$;

notify pgrst, 'reload schema';
