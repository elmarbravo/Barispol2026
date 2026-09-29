-- Leitura das mensagens sem esgotar o tempo (29-09-2026).
--
-- Problema: a regra bsp_msg_ler chamava bsp_ve_conversa(conv_key) em cada
-- linha. Com os historicos do WhatsApp (cerca de 13 000 linhas), a primeira
-- carga do Workspace («as 3000 mais recentes») levava 19,7 s para quem nao
-- e da gestao e caia no limite de 8 s (erro 500). O Workspace ficava sem
-- tempo real e sem os historicos (a Gizela, na Farmacia, nao via nada).
--
-- Solucao: a lista das conversas que a pessoa ve calcula-se uma vez por
-- consulta (uma chamada a bsp_ve_conversa por conversa, cerca de 50) e a
-- regra so compara a chave. O acesso e exactamente o mesmo.

create or replace function public.bsp_conversas_que_vejo()
returns text[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(array_agg(d.k), '{}'::text[])
  from (select distinct conv_key as k from public.messages) d
  where public.bsp_ve_conversa(d.k)
$$;

revoke all on function public.bsp_conversas_que_vejo() from public, anon;
grant execute on function public.bsp_conversas_que_vejo() to authenticated;

drop policy if exists "bsp_msg_ler" on public.messages;
create policy "bsp_msg_ler" on public.messages for select
  to authenticated
  using (conv_key = any ((select public.bsp_conversas_que_vejo())));
