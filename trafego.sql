-- Barispol Workspace · menos tráfego de saída (Egress) do Supabase
-- 01-10-2026. Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo
-- dia. Pode correr-se mais do que uma vez.
--
-- Tamanho dos ficheiros do Chat, para o ecrã não descarregar sozinho as
-- imagens acima de 600 KB (AnexoMensagem mostra um cartão «toque para ver»).
-- Corre com as permissões de quem chama (security invoker): as regras de
-- storage.objects decidem o que cada pessoa vê; um caminho que não vê não
-- aparece na resposta.
create or replace function public.bsp_tamanho_ficheiros(p_caminhos text[])
returns table (caminho text, bytes bigint)
language sql
stable
security invoker
set search_path to 'public'
as $function$
  select o.name, coalesce((o.metadata->>'size')::bigint, 0)
    from storage.objects o
   where o.bucket_id = 'drive'
     and o.name = any (p_caminhos[1:200])
$function$;
revoke all on function public.bsp_tamanho_ficheiros(text[]) from public, anon;
grant execute on function public.bsp_tamanho_ficheiros(text[]) to authenticated, service_role;

notify pgrst, 'reload schema';
