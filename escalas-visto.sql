-- Barispol Workspace · visto da Direcção Clínica nas escalas
-- Pedido do Elmar, 30-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
-- Precisa do escalas.sql, do transporte.sql e do escalas-alerta.sql.
--
-- Regra: a Direcção Clínica (u14, bsp_le_areas_medicas) pode alterar as
-- escalas de todas as áreas e tem de dar o visto a cada escala publicada.
-- Sem visto, a escala não entra em vigor: não conta para o transporte das
-- 22:30, não aparece em «De serviço hoje» e não segue para a equipa.
--   · o visto grava quem e quando (visto_por, visto_em), e só se dá pela
--     função bsp_escala_dar_visto (só u14);
--   · qualquer mudança aos turnos, aos dias ou ao estado de uma escala
--     apaga o visto: é preciso novo visto;
--   · as escalas publicadas antes desta regra ficam em vigor
--     (exige_visto = false) até serem alteradas.

alter table public.escalas add column if not exists visto_em timestamptz;
alter table public.escalas add column if not exists visto_por text;
alter table public.escalas add column if not exists exige_visto boolean not null default true;
alter table public.escalas add column if not exists enviar_para jsonb not null default '[]'::jsonb;

create or replace function public.bsp_escala_em_vigor(p_estado text, p_visto_em timestamptz, p_exige boolean)
returns boolean
language sql
immutable
as $function$
  select p_estado = 'publicada' and (p_visto_em is not null or not coalesce(p_exige, true))
$function$;

create or replace function public.bsp_edita_escala(p_area text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select not public.bsp_e_socio() and (
       public.bsp_e_gestor()
    or public.bsp_le_areas_medicas()
    or exists (
      select 1 from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
       where s.id = 1 and e->>'id' = public.bsp_meu_id()
         and public.bsp_area_chave(e->>'dept') = p_area
         and coalesce(e->>'role', '') ~* '(chefe|supervis|coordenad|director|directora|respons)')
    or exists (
      select 1 from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) x
       where s.id = 1 and x->>'superior' = public.bsp_meu_id()
         and public.bsp_area_chave(x->>'dept') = p_area))
$function$;

create or replace function public.bsp_escalas_alterado()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  new.alterado_em := now();
  new.alterado_por := coalesce(public.bsp_meu_id(), new.alterado_por);
  if tg_op = 'INSERT' then new.criado_por := coalesce(public.bsp_meu_id(), new.criado_por); end if;
  if new.estado = 'publicada' and (tg_op = 'INSERT' or old.estado is distinct from 'publicada') then
    new.publicada_em := now();
    new.publicada_por := coalesce(public.bsp_meu_id(), new.publicada_por);
  end if;
  /* O visto so muda por bsp_escala_dar_visto (que liga bsp.visto). */
  if coalesce(current_setting('bsp.visto', true), '') <> '1' then
    if tg_op = 'INSERT' then
      new.visto_em := null; new.visto_por := null; new.exige_visto := true;
    else
      new.visto_em := old.visto_em; new.visto_por := old.visto_por; new.exige_visto := old.exige_visto;
      if new.turnos is distinct from old.turnos or new.dias is distinct from old.dias
         or new.estado is distinct from old.estado or new.mes is distinct from old.mes or new.area is distinct from old.area then
        new.visto_em := null; new.visto_por := null; new.exige_visto := true;
      end if;
    end if;
  end if;
  return new;
end $function$;

create or replace function public.bsp_escala_dar_visto(p_id bigint)
returns setof public.escalas
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not public.bsp_le_areas_medicas() then raise exception 'Só a Direcção Clínica dá o visto às escalas.'; end if;
  if not exists (select 1 from public.escalas where id = p_id and estado = 'publicada') then
    raise exception 'Só se dá o visto a uma escala publicada.';
  end if;
  perform set_config('bsp.visto', '1', true);
  update public.escalas set visto_em = now(), visto_por = public.bsp_meu_id(), exige_visto = true where id = p_id;
  perform set_config('bsp.visto', '', true);
  return query select * from public.escalas where id = p_id;
end $function$;
revoke all on function public.bsp_escala_dar_visto(bigint) from public, anon;
grant execute on function public.bsp_escala_dar_visto(bigint) to authenticated;

-- As escalas ja publicadas antes da regra ficam em vigor.
do $$
begin
  perform set_config('bsp.visto', '1', true);
  update public.escalas set exige_visto = false where estado = 'publicada' and visto_em is null and exige_visto;
  perform set_config('bsp.visto', '', true);
end $$;

-- Transporte das 22:30: so escalas em vigor.
create or replace function public.bsp_transporte_saidas(p_dia date)
returns table(pessoa text, area text, turno text, fim text)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
begin
  if not public.bsp_ve_transporte() then raise exception 'Sem acesso ao transporte.'; end if;
  return query
  select distinct p.pessoa, e.area, t->>'nome', t->>'fim'
    from public.escalas e,
         jsonb_array_elements(e.turnos) t,
         jsonb_array_elements_text(coalesce(e.dias -> (p_dia::text) -> (t->>'id'), '[]'::jsonb)) p(pessoa)
   where public.bsp_escala_em_vigor(e.estado, e.visto_em, e.exige_visto)
     and e.mes = date_trunc('month', p_dia)::date
     and coalesce(t->>'fim', '') >= '22:00';
end $function$;

-- Alertas de 20 a 29: aos chefes (escala por publicar) e à Direcção Clínica
-- (escalas publicadas à espera do visto).
create or replace function public.bsp_escalas_alertar(p_hoje date default (now() at time zone 'Africa/Luanda')::date)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  meses text[] := array['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
  v_mes date := (date_trunc('month', p_hoje) + interval '1 month')::date;
  fim date := (date_trunc('month', p_hoje) + interval '1 month - 1 day')::date;
  hoje_real date := (now() at time zone 'Africa/Luanda')::date;
  nome_mes text;
  r record;
  estado_actual text;
  v_titulo text;
  por_visto text;
  n integer := 0;
begin
  if extract(day from p_hoje) not between 20 and 29 then return 0; end if;
  nome_mes := meses[extract(month from v_mes)::int] || ' de ' || extract(year from v_mes)::int;
  for r in select * from public.bsp_escalas_responsaveis() loop
    select e.estado into estado_actual from public.escalas e where e.area = r.area and e.mes = v_mes;
    continue when estado_actual = 'publicada';
    v_titulo := 'Escala de ' || nome_mes || ' por publicar: ' || r.nome_area;
    continue when exists (select 1 from public.novidades v where v.titulo = v_titulo
                            and (v.criado_em at time zone 'Africa/Luanda')::date = hoje_real);
    insert into public.novidades (titulo, texto, grupos, destino, criado_por) values (
      v_titulo,
      'A escala de ' || nome_mes || ' da área ' || r.nome_area || ' ainda não está publicada no Workspace.'
        || E'\n\n' || case when estado_actual = 'rascunho' then 'Já existe um rascunho: reveja-o e carregue em «Publicar».'
                           else 'Abra o menu Escalas, escolha a área e o mês, preencha os turnos e carregue em «Publicar».' end
        || E'\n\n' || 'Depois de publicada, a escala só entra em vigor com o visto da Direcção Clínica.'
        || E'\n\n' || 'Prazo: ' || to_char(fim, 'DD') || ' de ' || meses[extract(month from fim)::int]
        || ' (faltam ' || (fim - p_hoje) || case when fim - p_hoje = 1 then ' dia' else ' dias' end || '). '
        || 'Este aviso repete-se todos os dias, de 20 a 29, até a escala estar publicada.',
      r.ids, 'escalas', null);
    n := n + 1;
  end loop;
  select string_agg(coalesce((select min(x->>'dept') from shared_state s, jsonb_array_elements(s.team) x
                               where s.id = 1 and public.bsp_area_chave(x->>'dept') = e.area), e.area), ', ' order by e.area)
    into por_visto
    from public.escalas e
   where e.mes = v_mes and e.estado = 'publicada' and not public.bsp_escala_em_vigor(e.estado, e.visto_em, e.exige_visto);
  if por_visto is not null then
    v_titulo := 'Escalas de ' || nome_mes || ' à espera do seu visto';
    if not exists (select 1 from public.novidades v where v.titulo = v_titulo
                     and (v.criado_em at time zone 'Africa/Luanda')::date = hoje_real) then
      insert into public.novidades (titulo, texto, grupos, destino, criado_por) values (
        v_titulo,
        'Estas escalas estão publicadas e só entram em vigor com o seu visto: ' || por_visto || '.'
          || E'\n\n' || 'Abra o menu Escalas, reveja cada uma e carregue em «Dar visto». Fica registado o seu nome, o dia e a hora.',
        array['direccao-clinica'], 'escalas', null);
      n := n + 1;
    end if;
  end if;
  return n;
end $function$;
revoke all on function public.bsp_escalas_alertar(date) from public, anon, authenticated;
grant execute on function public.bsp_escalas_alertar(date) to service_role;

notify pgrst, 'reload schema';
