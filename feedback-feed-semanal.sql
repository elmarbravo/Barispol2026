-- Opiniões dos utentes no Feed (06-10-2026, Elmar: «faz um post no feed com
-- os feedback todos, passa a postar os elogios e reclamações da semana num
-- post»). Corre-se depois de qualidade.sql.
--
-- bsp_feedback_post_feed(de, ate, titulo) junta as opiniões de feedback_utentes
-- criadas no período (hora de Luanda) e publica UMA publicação no Feed
-- (tabela posts, autor u1, cid «fb-<de>-<ate>», nunca duas vezes):
--   Elogios      tipo elogio, ou avaliação com nota 4 ou 5
--   Reclamações  tipo reclamação, ou avaliação com nota 1 ou 2 (com o estado)
--   Sugestões    tipo sugestão
--   Outras       o resto (nota 3 ou sem nota)
-- Nomes de utentes nunca vão para o Feed: bsp_feedback_sem_nomes troca
-- «o/a <Nome>» por «o/a utente», salvo nomes da equipa e palavras como Dra.,
-- Deus, Clínica. Não leva telefones nem médicos (só a área).
-- Agendamento bsp-feedback-feed: segunda-feira às 08h00 de Luanda, com a
-- semana anterior (segunda a domingo). Sem opiniões, não publica.

create or replace function public.bsp_feedback_sem_nomes(p_texto text)
returns text language plpgsql stable security definer set search_path to 'public'
as $f$
declare
  t text := coalesce(p_texto, '');
  m text[];
  permitidos text[];
begin
  select array['Dra', 'Dr', 'Doutora', 'Doutor', 'Enfermeira', 'Enfermeiro', 'Deus', 'Centro', 'Clínica',
               'Barispol', 'Recepção', 'Farmácia', 'Médica', 'Médico', 'Equipa']
         || coalesce(array_agg(distinct split_part(e->>'name', ' ', 1)), '{}')
    into permitidos
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e where s.id = 1;
  for m in select regexp_matches(t, '(^|[^[:alpha:]])([OoAa])\s+([A-ZÁÉÍÓÚÂÊÔÃÕÇ][a-záéíóúâêôãõç]+)', 'g') loop
    if not (m[3] = any (permitidos)) then
      t := regexp_replace(t, '\m' || m[2] || '\s+' || m[3] || '\M', m[2] || ' utente', 'g');
    end if;
  end loop;
  return t;
end $f$;
revoke all on function public.bsp_feedback_sem_nomes(text) from public, anon, authenticated;

create or replace function public.bsp_feedback_post_feed(p_de date, p_ate date, p_titulo text default null)
returns bigint language plpgsql security definer set search_path to 'public'
as $f$
declare
  v_cid text := 'fb-' || p_de || '-' || p_ate;
  r record;
  elog text := ''; recl text := ''; sug text := ''; outras text := '';
  ne int := 0; nr int := 0; ns int := 0; no int := 0;
  media numeric; navaliacoes int;
  corpo text;
  novo bigint;
  areas jsonb := '{"recepcao":"Recepção","clinica":"Clínica","enfermagem":"Enfermagem","laboratorio":"Laboratório","farmacia":"Farmácia","radiologia":"Radiologia"}';
  linha text;
begin
  if exists (select 1 from public.posts p where p.cid = v_cid) then return null; end if;
  for r in
    select f.*, (f.criado_em at time zone 'Africa/Luanda')::date dia
      from public.feedback_utentes f
     where (f.criado_em at time zone 'Africa/Luanda')::date between p_de and p_ate
       and coalesce(trim(f.comentario), '') <> ''
     order by f.criado_em
  loop
    linha := '• «' || left(regexp_replace(public.bsp_feedback_sem_nomes(trim(both '«»" ' from r.comentario)), '\s+', ' ', 'g'), 240)
             || case when length(r.comentario) > 240 then '…' else '' end || '»'
             || ' (' || to_char(r.dia, 'DD-MM')
             || case when coalesce(r.area, '') <> '' then ' · ' || coalesce(areas->>r.area, r.area) else '' end
             || case when r.nota is not null then ' · nota ' || r.nota else '' end || ')';
    if r.tipo = 'elogio' or (r.tipo = 'avaliacao' and r.nota >= 4) then
      elog := elog || linha || E'\n'; ne := ne + 1;
    elsif r.tipo = 'reclamacao' or (r.tipo = 'avaliacao' and r.nota <= 2) then
      recl := recl || linha || ' — ' || coalesce(nullif(r.estado, ''), 'Nova') || E'\n'; nr := nr + 1;
    elsif r.tipo = 'sugestao' then
      sug := sug || linha || E'\n'; ns := ns + 1;
    else
      outras := outras || linha || E'\n'; no := no + 1;
    end if;
  end loop;
  if ne + nr + ns + no = 0 then return null; end if;
  select round(avg(nota), 1), count(*) into media, navaliacoes from public.feedback_utentes
   where nota is not null and (criado_em at time zone 'Africa/Luanda')::date between p_de and p_ate;
  corpo := 'O que os utentes disseram de ' || to_char(p_de, 'DD-MM-YYYY') || ' a ' || to_char(p_ate, 'DD-MM-YYYY') || '.'
    || case when navaliacoes > 0 then E'\nNota média: ' || replace(media::text, '.', ',') || ' em 5 (' || navaliacoes || case when navaliacoes = 1 then ' avaliação)' else ' avaliações)' end else '' end
    || E'\n\n👏 Elogios (' || ne || E')\n' || coalesce(nullif(elog, ''), E'Nenhum.\n')
    || E'\n⚠️ Reclamações (' || nr || E')\n' || coalesce(nullif(recl, ''), E'Nenhuma.\n')
    || case when ns > 0 then E'\n💡 Sugestões (' || ns || E')\n' || sug else '' end
    || case when no > 0 then E'\n💬 Outras opiniões (' || no || E')\n' || outras else '' end
    || E'\nObrigado a todos pelo cuidado com cada utente. As reclamações são tratadas pela Qualidade com as áreas.';
  insert into public.posts (user_id, type, title, body, cid)
  values ('u1', 'normal', coalesce(p_titulo, 'Voz dos utentes: ' || to_char(p_de, 'DD-MM') || ' a ' || to_char(p_ate, 'DD-MM-YYYY')), corpo, v_cid)
  returning id into novo;
  return novo;
end $f$;
revoke all on function public.bsp_feedback_post_feed(date, date, text) from public, anon, authenticated;

-- Semana anterior (segunda a domingo), chamada à segunda-feira. Começa no dia
-- seguinte ao fim da última publicação destas, para não repetir opiniões.
create or replace function public.bsp_feedback_post_semana()
returns bigint language sql security definer set search_path to 'public'
as $f$
  select public.bsp_feedback_post_feed(
    greatest((date_trunc('week', (now() at time zone 'Africa/Luanda')::date) - interval '7 days')::date,
             coalesce((select max(right(cid, 10)::date) + 1 from public.posts where cid ~ '^fb-\d{4}-\d{2}-\d{2}-\d{4}-\d{2}-\d{2}$'), '2000-01-01'::date)),
    (date_trunc('week', (now() at time zone 'Africa/Luanda')::date) - interval '1 day')::date)
$f$;
revoke all on function public.bsp_feedback_post_semana() from public, anon, authenticated;

-- Segunda-feira às 08h00 de Luanda (07h00 UTC). Primeira publicação, à mão a
-- 06-10-2026: bsp_feedback_post_feed('2026-09-16', '2026-10-06', ...).
select cron.schedule('bsp-feedback-feed', '0 7 * * 1', 'select public.bsp_feedback_post_semana()');
