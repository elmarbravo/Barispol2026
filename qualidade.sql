-- Qualidade (03-10-2026, Elmar: «Coloque lá o feedback de utentes»).
--
-- 1. feedback_utentes: avaliações (1 a 5), elogios, reclamações e sugestões.
--    Entra por três vias:
--      a) página pública barispol.com/avaliar.html (QR na recepção), pela
--         função bsp_feedback_publico (a única coisa aberta a visitantes);
--      b) respostas com nota ao inquérito pós-consulta no WhatsApp da
--         clínica (bsp_feedback_whatsapp, de 30 em 30 min);
--      c) registo manual no Workspace (Recepção, Livro de Reclamações).
--    Reclamações: prazo de resposta de 15 dias (decisão por confirmar com o
--    Elmar) e aviso ao chefe da área (RI-4.7: se não resolver, comunicar de
--    imediato ao superior).
-- 2. ocorrencias: incidentes, quase-erros e eventos adversos (modelo
--    JCI/OMS): notificada → em análise → acção correctiva → verificação →
--    fechada. Pode ser anónima (cultura justa: quem notifica não é punido
--    por notificar).
--
-- Quem lê: a gestão e a Direcção Clínica tudo; o chefe de cada área o da
-- sua área (bsp_edita_escala); quem registou o seu. Nomes de utentes nunca:
-- o ecrã avisa e os relatórios não os mostram. O contacto do utente (para
-- responder) só o vê quem trata.

create table if not exists public.feedback_utentes (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  criado_por text default public.bsp_meu_id(),
  origem text not null default 'recepcao'
    check (origem in ('pagina', 'whatsapp', 'recepcao', 'livro', 'email', 'telefone', 'redes')),
  tipo text not null default 'avaliacao'
    check (tipo in ('avaliacao', 'elogio', 'reclamacao', 'sugestao')),
  nota int check (nota between 1 and 5),
  area text not null default '',
  medico text not null default '',
  dia_atendimento date,
  comentario text not null default '',
  contacto text not null default '',
  quer_resposta boolean not null default false,
  livro_numero text not null default '',
  estado text not null default 'Nova' check (estado in ('Nova', 'Em tratamento', 'Respondida', 'Fechada')),
  responsavel text not null default '',
  resposta text not null default '',
  prazo date,
  actualizado_por text,
  actualizado_em timestamptz not null default now(),
  fechado_em timestamptz,
  whatsapp_msg text unique
);
create index if not exists feedback_utentes_criado on public.feedback_utentes (criado_em desc);
alter table public.feedback_utentes enable row level security;

create table if not exists public.ocorrencias (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  criado_por text default public.bsp_meu_id(),
  anonima boolean not null default false,
  tipo text not null default 'Incidente sem dano'
    check (tipo in ('Quase-erro', 'Incidente sem dano', 'Evento adverso', 'Evento sentinela')),
  categoria text not null default 'Outro',
  gravidade text not null default 'Sem dano' check (gravidade in ('Sem dano', 'Leve', 'Moderado', 'Grave', 'Morte')),
  area text not null default '',
  local text not null default '',
  dia date not null default current_date,
  hora text not null default '',
  descricao text not null,
  accao_imediata text not null default '',
  estado text not null default 'Notificada'
    check (estado in ('Notificada', 'Em análise', 'Acção correctiva', 'Verificação', 'Fechada')),
  analise text not null default '',
  accao text not null default '',
  responsavel text not null default '',
  prazo date,
  verificacao text not null default '',
  actualizado_por text,
  actualizado_em timestamptz not null default now(),
  fechado_em timestamptz
);
create index if not exists ocorrencias_criado on public.ocorrencias (criado_em desc);
alter table public.ocorrencias enable row level security;

-- Quem vê toda a qualidade: a gestão e a Direcção Clínica.
create or replace function public.bsp_ve_qualidade()
returns boolean language sql stable security definer set search_path to 'public'
as $f$ select not public.bsp_e_socio() and (public.bsp_e_gestor() or public.bsp_le_areas_medicas()) $f$;

-- Ids da gestão e da Direcção Clínica (para os avisos no telemóvel).
create or replace function public.bsp_ids_qualidade()
returns text[] language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(array_agg(e->>'id'), '{}')
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and coalesce(e->>'accessLevel', '') <> 'Sócio'
     and (e->>'id' = 'u14'
          or coalesce((s.camadas -> (e->>'accessLevel') ->> 'podeGerirUtilizadores')::boolean,
                      (e->>'accessLevel') in ('Direcção', 'Coordenação')))
$f$;

-- Carimbos, prazos e anonimato.
create or replace function public.bsp_qualidade_carimbo()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
begin
  new.actualizado_em := now();
  new.actualizado_por := coalesce(public.bsp_meu_id(), new.actualizado_por);
  if tg_table_name = 'feedback_utentes' then
    new.area := public.bsp_area_chave(new.area);
    if tg_op = 'INSERT' and new.tipo = 'reclamacao' and new.prazo is null then
      new.prazo := current_date + 15;
    end if;
  else
    new.area := public.bsp_area_chave(new.area);
    if tg_op = 'INSERT' and new.anonima then new.criado_por := null; end if;
    if tg_op = 'UPDATE' then new.anonima := old.anonima; new.criado_por := old.criado_por; end if;
  end if;
  if new.estado = 'Fechada' and (tg_op = 'INSERT' or old.estado is distinct from 'Fechada') then
    new.fechado_em := now();
  elsif new.estado <> 'Fechada' then
    new.fechado_em := null;
  end if;
  return new;
end $f$;
drop trigger if exists bsp_feedback_carimbo on public.feedback_utentes;
create trigger bsp_feedback_carimbo before insert or update on public.feedback_utentes
  for each row execute function public.bsp_qualidade_carimbo();
drop trigger if exists bsp_ocorrencias_carimbo on public.ocorrencias;
create trigger bsp_ocorrencias_carimbo before insert or update on public.ocorrencias
  for each row execute function public.bsp_qualidade_carimbo();

-- Regras de leitura e escrita.
drop policy if exists feedback_ler on public.feedback_utentes;
create policy feedback_ler on public.feedback_utentes for select to authenticated
  using ((select public.bsp_ve_qualidade()) or criado_por = (select public.bsp_meu_id())
         or (area <> '' and public.bsp_edita_escala(area)));
drop policy if exists feedback_criar on public.feedback_utentes;
create policy feedback_criar on public.feedback_utentes for insert to authenticated
  with check (public.bsp_meu_id() is not null and not public.bsp_e_socio()
              and origem not in ('pagina', 'whatsapp') and whatsapp_msg is null);
drop policy if exists feedback_mudar on public.feedback_utentes;
create policy feedback_mudar on public.feedback_utentes for update to authenticated
  using ((select public.bsp_ve_qualidade()) or (area <> '' and public.bsp_edita_escala(area)))
  with check ((select public.bsp_ve_qualidade()) or (area <> '' and public.bsp_edita_escala(area)));

drop policy if exists ocorrencias_ler on public.ocorrencias;
create policy ocorrencias_ler on public.ocorrencias for select to authenticated
  using ((select public.bsp_ve_qualidade()) or criado_por = (select public.bsp_meu_id())
         or (area <> '' and public.bsp_edita_escala(area)));
drop policy if exists ocorrencias_criar on public.ocorrencias;
create policy ocorrencias_criar on public.ocorrencias for insert to authenticated
  with check (public.bsp_meu_id() is not null and not public.bsp_e_socio() and estado = 'Notificada');
drop policy if exists ocorrencias_mudar on public.ocorrencias;
create policy ocorrencias_mudar on public.ocorrencias for update to authenticated
  using ((select public.bsp_ve_qualidade()) or (area <> '' and public.bsp_edita_escala(area)))
  with check ((select public.bsp_ve_qualidade()) or (area <> '' and public.bsp_edita_escala(area)));
-- Apagar: ninguém pelo ecrã (fica o registo).

-- Avisos: reclamação, nota baixa e ocorrência grave chegam já ao telemóvel
-- da gestão, da Direcção Clínica e do chefe da área; tudo entra também nas
-- novidades (sino e e-mail das 05h00).
create or replace function public.bsp_qualidade_aviso()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare para text[]; titulo text; corpo text; chefes text[];
begin
  select coalesce(array_agg(distinct x), '{}') into chefes
    from public.bsp_escalas_responsaveis() r, unnest(r.ids) x where r.area = new.area;
  para := public.bsp_ids_qualidade() || chefes;
  if tg_table_name = 'feedback_utentes' then
    if not (new.tipo = 'reclamacao' or coalesce(new.nota, 5) <= 2) then return null; end if;
    titulo := case when new.tipo = 'reclamacao' then 'Reclamação de utente' else 'Avaliação baixa (' || new.nota || '/5)' end;
    corpo := left(coalesce(nullif(new.comentario, ''), 'Sem comentário.'), 160);
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'exceto', coalesce(new.criado_por, ''),
      'titulo', titulo, 'corpo', corpo, 'url', '#/qualidade', 'tag', 'feedback-' || new.id));
    insert into public.novidades (titulo, texto, grupos, destino)
      values (titulo, corpo || case when new.prazo is not null then ' Prazo de resposta: ' || to_char(new.prazo, 'DD-MM-YYYY') || '.' else '' end,
              array['gestao', 'direccao-clinica'] || case when new.area <> '' then array[new.area] else '{}' end, 'qualidade');
  else
    titulo := new.tipo || ' notificado' || case when new.gravidade in ('Grave', 'Morte') then ' · ' || new.gravidade else '' end;
    corpo := left(new.descricao, 160);
    if new.gravidade in ('Moderado', 'Grave', 'Morte') or new.tipo in ('Evento adverso', 'Evento sentinela') then
      perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'exceto', coalesce(new.criado_por, ''),
        'titulo', titulo, 'corpo', corpo, 'url', '#/qualidade', 'tag', 'ocorrencia-' || new.id));
    end if;
    insert into public.novidades (titulo, texto, grupos, destino)
      values (titulo, corpo, array['gestao', 'direccao-clinica'] || case when new.area <> '' then array[new.area] else '{}' end, 'qualidade');
  end if;
  return null;
end $f$;
drop trigger if exists bsp_feedback_aviso on public.feedback_utentes;
create trigger bsp_feedback_aviso after insert on public.feedback_utentes
  for each row execute function public.bsp_qualidade_aviso();
drop trigger if exists bsp_ocorrencias_aviso on public.ocorrencias;
create trigger bsp_ocorrencias_aviso after insert on public.ocorrencias
  for each row execute function public.bsp_qualidade_aviso();

-- a) Página pública. A única entrada sem sessão: valida tudo, guarda só o
-- texto, e trava abusos (300 por dia no total, o mesmo texto uma vez por hora).
create or replace function public.bsp_feedback_publico(p_nota int, p_tipo text, p_area text,
  p_comentario text, p_contacto text, p_quer_resposta boolean)
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
declare t text := coalesce(nullif(p_tipo, ''), 'avaliacao'); c text := left(btrim(coalesce(p_comentario, '')), 2000);
begin
  if t not in ('avaliacao', 'elogio', 'reclamacao', 'sugestao') then t := 'avaliacao'; end if;
  if p_nota is not null and p_nota not between 1 and 5 then raise exception 'Nota inválida.'; end if;
  if p_nota is null and c = '' then raise exception 'Escreva um comentário ou escolha uma nota.'; end if;
  if (select count(*) from public.feedback_utentes where origem = 'pagina' and criado_em > now() - interval '1 day') >= 300 then
    raise exception 'Recebemos muitas respostas hoje. Tente amanhã, por favor.';
  end if;
  if c <> '' and exists (select 1 from public.feedback_utentes where origem = 'pagina' and comentario = c
                          and criado_em > now() - interval '1 hour') then
    return true;
  end if;
  insert into public.feedback_utentes (origem, tipo, nota, area, comentario, contacto, quer_resposta, criado_por)
    values ('pagina', t, p_nota, left(coalesce(p_area, ''), 40), c, left(btrim(coalesce(p_contacto, '')), 120),
            coalesce(p_quer_resposta, false) and btrim(coalesce(p_contacto, '')) <> '', null);
  return true;
end $f$;
revoke execute on function public.bsp_feedback_publico(int, text, text, text, text, boolean) from public;
grant execute on function public.bsp_feedback_publico(int, text, text, text, text, boolean) to anon, authenticated;

-- b) WhatsApp: a primeira resposta com um número de 1 a 5, até 3 dias depois
-- do inquérito pós-consulta («De 1 a 5, como correu o atendimento…»).
-- direccao 2 = enviada pela clínica, 1 = recebida.
create or replace function public.bsp_feedback_whatsapp()
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare n int;
begin
  with inq as (
    select m.contacto_id, m.criado_em from whatsapp.mensagens m
     where m.direccao = 2 and m.criado_em > now() - interval '20 days'
       and m.texto ilike '%De 1 a 5%como correu o atendimento%'
  ), resp as (
    select distinct on (i.contacto_id, i.criado_em) r.id, r.texto, r.criado_em, c.telefone
      from inq i
      join whatsapp.mensagens r on r.contacto_id = i.contacto_id and r.direccao = 1
       and r.criado_em > i.criado_em and r.criado_em < i.criado_em + interval '3 days'
       and r.texto ~ '(^|[^0-9])[1-5]([^0-9]|$)'
      left join whatsapp.contactos c on c.id = i.contacto_id
     order by i.contacto_id, i.criado_em, r.criado_em
  )
  insert into public.feedback_utentes (origem, tipo, nota, comentario, contacto, whatsapp_msg, criado_por, criado_em)
  select 'whatsapp', 'avaliacao', substring(texto from '(?:^|[^0-9])([1-5])(?:[^0-9]|$)')::int,
         left(btrim(regexp_replace(texto, '^\s*[1-5]\s*[-.,:)]*\s*', '')), 2000), coalesce(telefone, ''), id, null, criado_em
    from resp
  on conflict (whatsapp_msg) do nothing;
  get diagnostics n = row_count;
  return n;
end $f$;
revoke execute on function public.bsp_feedback_whatsapp() from public, anon, authenticated;

-- Resumo para o ecrã e os relatórios (só números, nunca nomes).
create or replace function public.bsp_qualidade_resumo(p_dias int default 30)
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  with f as (select * from public.feedback_utentes where criado_em > now() - make_interval(days => p_dias)),
       o as (select * from public.ocorrencias where criado_em > now() - make_interval(days => p_dias))
  select case when not public.bsp_ve_qualidade() then null else jsonb_build_object(
    'dias', p_dias,
    'avaliacoes', (select count(*) from f where nota is not null),
    'media', (select round(avg(nota)::numeric, 2) from f where nota is not null),
    'satisfeitos', (select count(*) from f where nota >= 4),
    'insatisfeitos', (select count(*) from f where nota <= 2),
    'reclamacoes', (select count(*) from f where tipo = 'reclamacao'),
    'reclamacoes_abertas', (select count(*) from public.feedback_utentes where tipo = 'reclamacao' and estado not in ('Respondida', 'Fechada')),
    'reclamacoes_atrasadas', (select count(*) from public.feedback_utentes where tipo = 'reclamacao' and estado not in ('Respondida', 'Fechada') and prazo < current_date),
    'elogios', (select count(*) from f where tipo = 'elogio'),
    'por_area', coalesce((select jsonb_agg(jsonb_build_object('area', area, 'n', n, 'media', media) order by n desc)
                 from (select coalesce(nullif(area, ''), '—') area, count(*) n, round(avg(nota)::numeric, 2) media from f where nota is not null group by 1) a), '[]'),
    'por_origem', coalesce((select jsonb_object_agg(origem, n) from (select origem, count(*) n from f group by 1) a), '{}'),
    'ocorrencias', (select count(*) from o),
    'ocorrencias_abertas', (select count(*) from public.ocorrencias where estado <> 'Fechada'),
    'ocorrencias_graves', (select count(*) from o where gravidade in ('Grave', 'Morte') or tipo = 'Evento sentinela'),
    'ocorrencias_por_tipo', coalesce((select jsonb_object_agg(tipo, n) from (select tipo, count(*) n from o group by 1) a), '{}'))
  end
$f$;
grant execute on function public.bsp_qualidade_resumo(int) to authenticated;
revoke execute on function public.bsp_qualidade_resumo(int) from anon;

do $$ begin
  revoke execute on function public.bsp_ve_qualidade() from public, anon;
  revoke execute on function public.bsp_ids_qualidade() from public, anon;
  revoke execute on function public.bsp_qualidade_carimbo() from public, anon;
  revoke execute on function public.bsp_qualidade_aviso() from public, anon;
  grant execute on function public.bsp_ve_qualidade() to authenticated;
end $$;

-- Cron: respostas do WhatsApp de 30 em 30 minutos.
select cron.schedule('bsp-feedback-whatsapp', '*/30 * * * *', 'select public.bsp_feedback_whatsapp();');
