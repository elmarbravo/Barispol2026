-- Registo inicial de km pelo motorista (12-10-2026, Emmanuel: «não tem a
-- opção de registo inicial»). Pode correr-se mais do que uma vez.
--
-- Os acertos de km (transporte-acertos.sql) eram só da gestão. Uma viatura
-- sem nenhum acerto ainda não tem ponto de partida: o motorista pode fazer o
-- primeiro registo («Registo inicial de km»), uma só vez por viatura. A
-- partir daí só a gestão acerta. No ecrã: Transporte → «Registo inicial de
-- km» (cabeçalho e cartão da viatura) e o campo «Km no conta-quilómetros» ao
-- criar uma viatura nova (TranspViaturaModal).

alter policy transporte_acertos_criar on public.transporte_acertos
  with check (
    criado_por = public.bsp_meu_id()
    and (public.bsp_e_gestor()
         or (public.bsp_ve_transporte()
             and not exists (select 1 from public.transporte_acertos a where a.viatura_id = transporte_acertos.viatura_id))));

notify pgrst, 'reload schema';
