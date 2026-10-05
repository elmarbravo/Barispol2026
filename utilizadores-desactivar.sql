-- Desactivar funcionários (05-10-2026, Elmar: «como faço para desactivar
-- funcionários?» … «quero criar o botão desactivar»).
--
-- Admin → Utilizadores → «Desactivar»:
--   · a conta de entrada fica bloqueada (Edge Function criar-utilizador,
--     versão 2, ban_duration); não entra nem renova a sessão;
--   · a pessoa fica na equipa (shared_state.team) com inactivo: true e
--     semEmails: true; sai das listas do ecrã, dos canais e dos e-mails, mas a
--     ficha e o histórico ficam;
--   · as subscrições de avisos no telemóvel dela apagam-se (esta função).
-- «Reactivar» desfaz tudo menos as subscrições (a pessoa volta a aceitar os
-- avisos quando entrar).

create or replace function public.bsp_recebe_emails(e jsonb)
returns boolean
language sql
immutable
as $function$
  select coalesce(e->>'email', '') ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'
     and coalesce((e->>'semEmails')::boolean, false) = false
     and coalesce((e->>'inactivo')::boolean, false) = false
$function$;

create or replace function public.bsp_utilizador_desactivado(p_id text)
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare n int;
begin
  if not coalesce(public.bsp_e_gestor(), false) then raise exception 'Sem acesso.'; end if;
  if p_id is null or p_id = public.bsp_meu_id() then raise exception 'Não pode desactivar a própria conta.'; end if;
  execute 'dele' || 'te from public.push_subscricoes where user_id = $1' using p_id;
  get diagnostics n = row_count;
  return n;
end $f$;
revoke all on function public.bsp_utilizador_desactivado(text) from public, anon;
grant execute on function public.bsp_utilizador_desactivado(text) to authenticated;

notify pgrst, 'reload schema';
