-- Terminar a sessão de todos (16-10-2026, Elmar: «Termine a sessão de todos»).
-- Apaga as sessões do Supabase Auth: os testemunhos de renovação deixam de
-- valer e cada aparelho com o Workspace aberto sai em menos de 1 hora (quando
-- o testemunho de acesso caduca). No ecrã, BSP_SESSAO_GERACAO fecha logo a
-- sessão de cada aparelho na próxima abertura.
-- Pode correr-se no SQL Editor do painel do Supabase. Não apaga contas nem
-- a verificação em dois passos já activada.
delete from auth.sessions;
select count(*) as sessoes_restantes from auth.sessions;
