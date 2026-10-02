-- Revisão geral (02-10-2026): funções privilegiadas fechadas a visitantes.
-- O consultor de segurança do Supabase mostrava 10 funções SECURITY DEFINER
-- que se podiam chamar sem sessão (papel anon). Quem tem sessão continua a
-- usá-las; os gatilhos não dependem desta permissão. Aplicado.
do $$ declare f text; begin
foreach f in array array['bsp_avaria_repetida()','bsp_doc_destinatarios(text[])','bsp_e_direccao()',
  'bsp_ids_da_minha_area()','bsp_push_agenda()','bsp_push_documento()','bsp_push_mensagem()',
  'bsp_push_post_feed()','bsp_push_tarefa_pessoal()','bsp_push_tarefas_equipa()'] loop
  execute format('revoke execute on function public.%s from public, anon', f);
end loop; end $$;
-- Regra para funções novas: depois de criar, «revoke execute ... from public,
-- anon» e «grant execute ... to authenticated» só se o ecrã a chamar.
