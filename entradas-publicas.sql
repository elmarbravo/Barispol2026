-- Entradas do site atrás de uma Edge Function (12-10-2026, auditoria de
-- segurança, Fase 2, ponto 5; funcoes/entrada-publica/index.ts).
--
-- bsp_pedido_site (pedido de marcação do site) e bsp_feedback_publico
-- (inquérito de satisfação, avaliar.html) deixam de ser chamáveis pela chave
-- pública. Só a Edge Function entrada-publica lhes chega, com a chave do
-- servidor, depois de conferir a origem (barispol.com), o campo-armadilha e
-- o limite de 5 entradas por hora por ligação. O IP de quem entra fica só
-- como resumo SHA-256 com sal, em entradas_publicas, para contar a hora;
-- a bsp_retencao apaga as linhas com mais de 30 dias.
-- Pode correr-se mais do que uma vez.

create table if not exists public.entradas_publicas (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  origem_ip text not null,
  qual text not null check (qual in ('pedido', 'feedback'))
);
create index if not exists entradas_publicas_ip_hora on public.entradas_publicas (origem_ip, criado_em);
alter table public.entradas_publicas enable row level security;
revoke all on public.entradas_publicas from public, anon, authenticated;

-- As duas entradas fecham-se à chave pública; o servidor (service_role) mantém.
revoke execute on function public.bsp_pedido_site(jsonb) from public, anon;
grant execute on function public.bsp_pedido_site(jsonb) to service_role, authenticated;
revoke execute on function public.bsp_feedback_publico(integer, text, text, text, text, boolean) from public, anon;
grant execute on function public.bsp_feedback_publico(integer, text, text, text, text, boolean) to service_role, authenticated;

-- Retenção: 30 dias de resumos de IP (acrescenta-se à lista da bsp_retencao
-- em retencao-copias.sql; aqui só para quem corre este ficheiro sozinho).
-- ['entradas_publicas', 'criado_em < now() - interval ''30 days''']

notify pgrst, 'reload schema';
