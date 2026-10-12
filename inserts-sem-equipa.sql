-- Inserções só de quem está na equipa (12-10-2026, auditoria de segurança).
--
-- As regras de inserir mensagens e publicações aceitavam «user_id =
-- bsp_meu_id() or bsp_meu_id() is null»: uma conta autenticada que não
-- estivesse na equipa (criada por engano, ou por registo livre no Auth)
-- podia escrever em nome de qualquer pessoa. Agora o autor tem de ser a
-- própria pessoa, e tem de estar na equipa.
-- Nota: em produção, utentes e seguimentos já estavam fechados a
-- crm.pode_ver_crm() (os ficheiros crm-seguimento.sql e INSTALAR-TUDO.sql
-- estavam desactualizados).

alter policy bsp_msg_criar on public.messages to authenticated
  with check (public.bsp_ve_conversa(conv_key) and user_id = public.bsp_meu_id());

alter policy bsp_post_criar on public.posts to authenticated
  with check (user_id = public.bsp_meu_id());
