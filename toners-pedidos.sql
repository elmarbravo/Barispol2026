-- Pedido de toners (12-10-2026, Emmanuel: «não temos a opção para solicitar
-- toners»). Pode correr-se mais do que uma vez.
--
-- Os pedidos de compra (equipa-registos.sql) só aceitavam armazéns do
-- MetaGest, pela bsp_ve_stock(armazem). Os toners não são um armazém do
-- MetaGest: ficam no armário da Recepção (toners-gerador.sql). Agora o
-- armazém «Toners» em pedidos_compra é de quem vê os toners (bsp_ve_toners:
-- gestão, Serviços Gerais e Emmanuel, Recepção e Laboratório). No ecrã,
-- Logística e stock → Toners → «Pedir toners» (TonersPainel com o
-- PedidosCompraPainel, armazém 'Toners', artigos sugeridos = consumíveis
-- abaixo do mínimo). A gestão aprova no mesmo sítio, como os outros pedidos.

alter policy pedidos_compra_ler on public.pedidos_compra
  using (public.bsp_ve_stock(armazem) or (armazem = 'Toners' and public.bsp_ve_toners()));
alter policy pedidos_compra_criar on public.pedidos_compra
  with check ((public.bsp_ve_stock(armazem) or (armazem = 'Toners' and public.bsp_ve_toners())) and estado = 'Pedido');
alter policy pedidos_compra_mudar on public.pedidos_compra
  using (public.bsp_ve_stock(armazem) or (armazem = 'Toners' and public.bsp_ve_toners()))
  with check (public.bsp_ve_stock(armazem) or (armazem = 'Toners' and public.bsp_ve_toners()));

-- A novidade para a gestão manda para o sítio certo (Toners, não Stock).
create or replace function public.bsp_pedido_compra_carimbo()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
begin
  if tg_op = 'INSERT' then
    new.criado_por := coalesce(public.bsp_meu_id(), new.criado_por);
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Pedido de compra: ' || replace(new.armazem, ' - CBL', ''),
            public.bsp_nome_de(new.criado_por) || ' pede ' || jsonb_array_length(new.itens) || ' artigo(s). '
              || case when new.armazem = 'Toners' then 'Aprove em Logística e stock → Toners.' else 'Aprove em Stock → Pedidos de compra.' end,
            array['gestao'], 'stock');
    return new;
  end if;
  if new.estado <> old.estado and new.estado in ('Aprovado', 'Recusado') then
    if not public.bsp_e_gestor() then raise exception 'Só a gestão aprova pedidos de compra.'; end if;
    new.decidido_por := public.bsp_meu_id();
    new.decidido_em := now();
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Pedido de compra ' || lower(new.estado), 'O pedido de ' || replace(new.armazem, ' - CBL', '') || ' foi ' || lower(new.estado) || '.', array[new.criado_por], 'stock');
  end if;
  if old.estado = 'Pedido' and new.estado in ('Comprado', 'Recebido') then
    raise exception 'O pedido tem de ser aprovado primeiro.';
  end if;
  if new.itens is distinct from old.itens and old.estado <> 'Pedido' then
    raise exception 'Depois de decidido, o pedido não muda.';
  end if;
  new.actualizado_em := now();
  return new;
end $f$;

notify pgrst, 'reload schema';
