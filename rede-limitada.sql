-- Fora da clínica: só Chat e Escalas (25-10-2026, passo 3 de
-- privacidade-rede.sql; Elmar, 22-10: «fora de lá só abram os chats» e «tem
-- um chefe de escala que tem que fazer a escala»).
--
-- Em vez de fechar tudo a quem está fora da rede (e não é isento), o servidor
-- deixa passar só o que o Chat e as Escalas usam:
-- - bsp_pre_pedido(): corre antes de cada pedido à API (pgrst.db_pre_request
--   no papel authenticator). Fora da rede, só passam as tabelas e as funções
--   da lista; o resto dá 403 «Fora da clínica: só Chat e Escalas».
-- - bsp_meu_id() e bsp_sessao_aal2() deixam de ter bsp_rede_ok (senão o Chat
--   também fechava fora). A 2FA continua igual.
-- - Ficheiros: regra RESTRICTIVE bsp_rede_ficheiros em storage.objects. Fora
--   da rede só abrem os anexos das conversas (conversa/…); o Drive não.
-- - bsp_entrada_estado devolve 'limitado' e o ecrã mostra só Chat e Escalas,
--   com a faixa «Fora da clínica: só Chat e Escalas».
-- Enquanto rede_config 'activa' for false, nada muda para ninguém.
-- Uma tabela ou função nova que o Chat ou as Escalas usem entra na lista.
-- Nas funções pela ferramenta, nunca as palavras que pedem confirmação.

create or replace function public.bsp_meu_id()
returns text language sql stable security definer set search_path to 'public'
as $function$
  select e->>'id'
  from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
  where s.id = 1
    and lower(e->>'email') = lower(coalesce(auth.jwt()->>'email', ''))
  limit 1
$function$;

create or replace function public.bsp_sessao_aal2()
returns boolean language sql stable security definer set search_path to 'public'
as $function$ select public.bsp_mfa_ok() $function$;

create or replace function public.bsp_pre_pedido()
returns void language plpgsql stable security definer set search_path to 'public'
as $f$
declare p text;
begin
  if public.bsp_rede_ok() then return; end if;
  p := coalesce(current_setting('request.path', true), '');
  if p ~ '/(messages|shared_state|presenca|escalas|trocas_turno|capturas_ecra|acessos_registo)$'
     or p ~ '/rpc/(bsp_entrada_estado|bsp_politica_aceitar|bsp_mfa_[a-z_]+|bsp_push_registar|bsp_vapid_publica|bsp_tamanho_ficheiros|bsp_novidades_por_ver|bsp_novidades_vistas|bsp_alertas_por_ler|bsp_alertas_lidos|bsp_notif_estado|bsp_notif_estado_lista|bsp_utilizador_desactivado|bsp_escalas_responsaveis|bsp_escala_dar_visto|bsp_troca_pedir|bsp_troca_responder|bsp_troca_decidir)$' then
    return;
  end if;
  raise sqlstate 'PT403' using message = 'Fora da clínica: só Chat e Escalas.';
end $f$;
revoke all on function public.bsp_pre_pedido() from public, anon;
grant execute on function public.bsp_pre_pedido() to authenticated, authenticator;

create policy bsp_rede_ficheiros on storage.objects as restrictive for all to authenticated
  using (public.bsp_rede_ok() or name like 'conversa/%')
  with check (public.bsp_rede_ok() or name like 'conversa/%');

create or replace function public.bsp_entrada_estado()
returns jsonb language plpgsql volatile security definer set search_path to 'public'
as $function$
declare quem text := public.bsp_rede_quem(); ok boolean := public.bsp_rede_ok(); fora boolean := public.bsp_rede_fora(); pol record; res jsonb;
begin
  if auth.uid() is null then raise exception 'Sem sessão.'; end if;
  -- Registo das entradas de fora: com o bloqueio ligado ou só em observação.
  if fora then
    insert into rede_bloqueios (user_id, ip, bloqueado) values (quem, public.bsp_ip_pedido(), not ok);
  end if;
  select * into pol from politica_versoes where activa order by criada_em desc limit 1;
  res := jsonb_build_object('rede_ok', ok, 'limitado', not ok, 'ip', public.bsp_ip_pedido(),
    'isento', coalesce((select valor from rede_config where chave = 'isentos') ? quem, false));
  if found and quem is not null and not exists (select 1 from politica_aceites a where a.user_id = quem and a.versao = pol.versao) then
    res := res || jsonb_build_object('politica', jsonb_build_object('versao', pol.versao, 'titulo', pol.titulo, 'texto', pol.texto));
  end if;
  return res;
end $function$;

-- Aplicado a 25-10-2026 sem ligar. Ligar (só com o «sim» do Elmar):
--   alter role authenticator set pgrst.db_pre_request = 'public.bsp_pre_pedido';
--   notify pgrst, 'reload config';
--   insert into rede_config (chave, valor) values ('activa', 'true') on conflict (chave) do update set valor = excluded.valor;
-- Desligar em emergência: o mesmo insert com 'false' (o pre_request fica
-- inofensivo: com 'activa' a false deixa passar tudo).
