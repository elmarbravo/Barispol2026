-- Janela de avisos importantes (06-10-2026, Elmar: «Pop up de notificações
-- importantes, consegue ter?»). Escolhidos pelo Elmar: tarefas delegadas,
-- documentos obrigatórios, alertas críticos, ligar para utentes e marcações
-- da Recepção. As conclusões das tarefas que o Elmar delegou ficam só no sino
-- e no telemóvel.
--
-- A janela abre por cima de tudo e só fecha com «Li» (ou «Abrir», que leva ao
-- ecrã). Fica registado quem leu e quando (lido_em). Quem não estava ligado vê
-- os avisos na entrada seguinte.
--
-- Duas fontes:
--   · avisos guardados: o bsp_push_post copia para alertas_importantes os
--     avisos do telemóvel que contam como importantes, pela etiqueta (tag):
--       tarefa-p<id>, tarefa-<id>  nova tarefa atribuída       (tarefa)
--       frio-<id>                  cadeia de frio               (critico)
--       vigilancia-<x>             possível falha do sistema    (critico)
--       toner-<x>, gerador         toners e gasóleo             (critico)
--       pedido-site-<id>           pedido de marcação do site   (marcacao)
--     A cópia faz-se antes de saber se a pessoa tem o telemóvel ligado.
--   · avisos calculados na hora (bsp_alertas_por_ler), com «Li» guardado na
--     mesma tabela:
--       doc-<id>-<dia>        documento de leitura obrigatória por confirmar
--                             (volta no dia seguinte até ser confirmado)
--       atrasadas-<dia>       tarefas delegadas à pessoa com o fim passado
--       ligar-<dia>           Recepção: utentes «Por ligar» (CRM e site)
--       marc-<id>-antes       Recepção: marcação de hoje daqui a menos de 1 h
--       marc-<id>-depois      Recepção: 30 min depois da hora, ainda em aberto
-- Nomes de utentes só no servidor (nunca no repositório).

create table if not exists public.alertas_importantes (
  id bigserial primary key,
  user_id text not null,
  chave text not null,
  tipo text not null default 'aviso',
  titulo text not null default '',
  texto text not null default '',
  destino text,
  criado_em timestamptz not null default now(),
  lido_em timestamptz,
  unique (user_id, chave)
);
alter table public.alertas_importantes enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'alertas_importantes' and policyname = 'bsp_alertas_ler') then
    create policy bsp_alertas_ler on public.alertas_importantes for select to authenticated
      using (user_id = public.bsp_meu_id() or public.bsp_e_gestor());
  end if;
end $$;
revoke insert, update on public.alertas_importantes from anon, authenticated;
create index if not exists alertas_importantes_por_ler on public.alertas_importantes (user_id) where lido_em is null;

-- Cópia de um aviso do telemóvel, se for importante.
create or replace function public.bsp_alerta_do_push(p_corpo jsonb)
returns void language plpgsql security definer set search_path to 'public'
as $f$
declare
  tag text := coalesce(p_corpo->>'tag', '');
  tit text := coalesce(p_corpo->>'titulo', '');
  tipo text;
  destino text := nullif(regexp_replace(coalesce(p_corpo->>'url', ''), '^#/?', ''), '');
begin
  if jsonb_typeof(p_corpo->'para') <> 'array' then return; end if;
  tipo := case
    when tag like 'tarefa-%' then 'tarefa'
    when tag like 'frio-%' or tag like 'toner-%' or tag = 'gerador' then 'critico'
    when tag like 'vigilancia-%' and tit like '%possível falha%' then 'critico'
    when tag like 'pedido-site-%' then 'marcacao'
    else null end;
  if tipo is null then return; end if;
  insert into public.alertas_importantes as a (user_id, chave, tipo, titulo, texto, destino)
  select distinct x, tag, tipo, left(tit, 200), left(coalesce(p_corpo->>'corpo', ''), 600), destino
    from jsonb_array_elements_text(p_corpo->'para') x
   where x <> coalesce(p_corpo->>'exceto', '')
  on conflict (user_id, chave) do update
    set titulo = excluded.titulo, texto = excluded.texto, destino = excluded.destino, tipo = excluded.tipo,
        criado_em = now(), lido_em = null;
exception when others then
  raise warning 'bsp_alerta_do_push: %', sqlerrm;
end $f$;
revoke all on function public.bsp_alerta_do_push(jsonb) from public, anon, authenticated;

-- O bsp_push_post passa a copiar os importantes (alteração sobre a versão do
-- servidor; se o texto esperado não estiver lá, fica como está e sai um aviso).
do $$ declare d text; n text;
begin
  d := pg_get_functiondef('public.bsp_push_post(jsonb)'::regprocedure);
  if position('bsp_alerta_do_push' in d) > 0 then return; end if;
  n := replace(d, E'declare para text[];\nbegin\n', E'declare para text[];\nbegin\n  perform public.bsp_alerta_do_push(p_corpo);\n');
  if n = d then raise notice 'bsp_push_post: texto esperado não encontrado, não mudou';
  else execute n; end if;
end $$;

-- Avisos por ler da pessoa com sessão aberta (guardados + calculados).
create or replace function public.bsp_alertas_por_ler()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare
  eu text := public.bsp_meu_id();
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  dia text := to_char((now() at time zone 'Africa/Luanda')::date, 'YYYY-MM-DD');
  agora_min int := extract(hour from now() at time zone 'Africa/Luanda')::int * 60 + extract(minute from now() at time zone 'Africa/Luanda')::int;
  recepcao boolean;
  r jsonb := '[]'::jsonb;
  n_crm int := 0; n_site int := 0;
begin
  if eu is null or public.bsp_e_socio() then return r; end if;
  select public.bsp_area_chave(e->>'dept') = 'recepcao' into recepcao
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and e->>'id' = eu;

  -- Guardados (os dos últimos 14 dias).
  r := r || coalesce((select jsonb_agg(jsonb_build_object('chave', chave, 'tipo', tipo, 'titulo', titulo, 'texto', texto,
                         'destino', destino, 'criado_em', criado_em) order by criado_em)
                        from public.alertas_importantes
                       where user_id = eu and lido_em is null and criado_em > now() - interval '14 days'), '[]'::jsonb);

  -- Documentos de leitura obrigatória por confirmar (publicados nos últimos 60 dias).
  r := r || coalesce((select jsonb_agg(jsonb_build_object('chave', 'doc-' || d.id || '-' || dia, 'tipo', 'documento',
                         'titulo', 'Leitura obrigatória: ' || d.titulo,
                         'texto', 'Publicado a ' || to_char(d.publicado_em at time zone 'Africa/Luanda', 'DD-MM-YYYY')
                                  || '. Abra o documento e confirme a leitura.',
                         'destino', 'documentos', 'criado_em', d.publicado_em) order by d.publicado_em)
                        from public.documentos d
                       where d.leitura_obrigatoria and not coalesce(d.arquivado, false)
                         and d.publicado_em > now() - interval '60 days'
                         and coalesce(d.publicado_por, '') <> eu
                         and public.bsp_ve_documento(d.grupos, d.publicado_por)
                         and not exists (select 1 from public.documentos_leituras l where l.documento_id = d.id and l.user_id = eu)), '[]'::jsonb);

  -- Tarefas delegadas à pessoa com o fim passado.
  r := r || coalesce((select jsonb_build_array(jsonb_build_object('chave', 'atrasadas-' || dia, 'tipo', 'tarefa',
                         'titulo', count(*) || case when count(*) = 1 then ' tarefa atrasada' else ' tarefas atrasadas' end,
                         'texto', string_agg('• ' || left(t.titulo, 120) || ' (fim ' || to_char(t.prazo, 'DD-MM') || ')', E'\n' order by t.prazo),
                         'destino', 'tarefas', 'criado_em', now()))
                        from (select titulo, prazo::date prazo from public.tarefas_pessoais
                               where user_id = eu and coluna <> 'done' and prazo ~ '^\d{4}-\d{2}-\d{2}$'
                                 and (origem = 'emails' or (criada_por is not null and criada_por <> user_id))) t
                       where t.prazo < hoje
                      having count(*) > 0), '[]'::jsonb);

  if coalesce(recepcao, false) then
    -- Utentes por ligar.
    select count(*) into n_crm from crm.caixa c where c.estado = 'Por ligar';
    select count(*) into n_site from public.pedidos_marcacao p where p.estado = 'Por ligar';
    if n_crm + n_site > 0 then
      r := r || jsonb_build_array(jsonb_build_object('chave', 'ligar-' || dia, 'tipo', 'ligar',
             'titulo', (n_crm + n_site) || case when n_crm + n_site = 1 then ' utente por ligar' else ' utentes por ligar' end,
             'texto', concat_ws(E'\n', case when n_crm > 0 then '• CRM (sem resposta no WhatsApp): ' || n_crm end,
                                       case when n_site > 0 then '• Pedidos do site: ' || n_site end)
                      || E'\nRegiste o resultado de cada chamada.',
             'destino', 'seguimento', 'criado_em', now()));
    end if;

    -- Marcações de hoje: 1 h antes e 30 min depois da hora, ainda em aberto.
    r := r || coalesce((select jsonb_agg(jsonb_build_object(
                           'chave', 'marc-' || m.id || case when m.h > agora_min then '-antes' else '-depois' end,
                           'tipo', 'marcacao',
                           'titulo', case when m.h > agora_min then 'Marcação às ' || m.hora || ': confirmar'
                                          else 'Marcação das ' || m.hora || ': ainda em aberto' end,
                           'texto', concat_ws(' · ', nullif(m.nome, ''), nullif(m.acto, ''), nullif(m.medico, ''))
                                    || case when m.h > agora_min then '. Confirme que o utente vem.'
                                            else '. Registe se compareceu, faltou ou remarcou.' end,
                           'destino', 'marcacoes', 'criado_em', now()) order by m.h)
                          from (select x.*, (substring(x.hora from '^(\d{1,2})')::int * 60 + substring(x.hora from '^\d{1,2}[:hH.](\d{2})')::int) h
                                  from public.marcacoes x
                                 where x.data_marcada = hoje and x.estado in ('Agendada', 'Confirmada')
                                   and x.hora ~ '^\d{1,2}[:hH.]\d{2}') m
                         where (agora_min >= m.h - 60 and agora_min < m.h) or agora_min >= m.h + 30), '[]'::jsonb);
  end if;

  -- Tira os calculados que já foram lidos.
  return coalesce((select jsonb_agg(x) from jsonb_array_elements(r) x
                    where not exists (select 1 from public.alertas_importantes a
                                       where a.user_id = eu and a.chave = x->>'chave' and a.lido_em is not null)), '[]'::jsonb);
end $f$;
revoke all on function public.bsp_alertas_por_ler() from public, anon;
grant execute on function public.bsp_alertas_por_ler() to authenticated;

-- «Li»: regista a leitura (também dos calculados, que não tinham linha).
create or replace function public.bsp_alertas_lidos(p_chaves text[])
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare eu text := public.bsp_meu_id(); n int;
begin
  if eu is null then raise exception 'Sem sessão.'; end if;
  insert into public.alertas_importantes as a (user_id, chave, tipo, lido_em)
  select eu, left(c, 120), 'calculado', now() from unnest(coalesce(p_chaves, '{}')) c where coalesce(c, '') <> ''
  on conflict (user_id, chave) do update set lido_em = now() where a.lido_em is null;
  get diagnostics n = row_count;
  return n;
end $f$;
revoke all on function public.bsp_alertas_lidos(text[]) from public, anon;
grant execute on function public.bsp_alertas_lidos(text[]) to authenticated;

notify pgrst, 'reload schema';
