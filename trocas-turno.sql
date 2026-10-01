-- Barispol Workspace · trocas de turno nas escalas
-- Pedido do Elmar, 01-10-2026 («faz todos eles», auditoria). Aplicado no
-- projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais
-- do que uma vez.
--
-- Fluxo: quem está no turno pede → o colega aceita → a Direcção Clínica
-- (bsp_le_areas_medicas, quem dá o visto às escalas) aprova. Ao aprovar, a
-- troca entra na escala e o visto mantém-se (é quem o dá que aprova). Em
-- troca, o colega pode dar um dos seus turnos (dia2/turno2).
-- Lêem: as duas pessoas, o chefe da área (bsp_chefe_de), a Direcção
-- Clínica e a gestão.

create table if not exists public.trocas_turno (
  id bigint generated always as identity primary key,
  escala_id bigint not null references public.escalas(id) on delete cascade,
  dia date not null,
  turno text not null,
  de_user text not null default public.bsp_meu_id(),
  para_user text not null,
  dia2 date,
  turno2 text,
  nota text not null default '',
  estado text not null default 'Pedido' check (estado in ('Pedido', 'Aceite', 'Aprovado', 'Recusado', 'Cancelado')),
  respondido_em timestamptz,
  decidido_por text,
  decidido_em timestamptz,
  motivo text not null default '',
  criado_em timestamptz not null default now(),
  check (de_user <> para_user)
);
alter table public.trocas_turno enable row level security;
drop policy if exists trocas_ler on public.trocas_turno;
create policy trocas_ler on public.trocas_turno for select to authenticated
  using (de_user = public.bsp_meu_id() or para_user = public.bsp_meu_id() or public.bsp_chefe_de(de_user) or public.bsp_le_areas_medicas());
revoke insert, update, delete on public.trocas_turno from anon, authenticated;

-- Quem está num turno de uma escala num dia.
create or replace function public.bsp_escala_no_turno(p_escala bigint, p_dia date, p_turno text, p_user text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (select 1 from public.escalas e
                  where e.id = p_escala
                    and coalesce(e.dias -> to_char(p_dia, 'YYYY-MM-DD') -> p_turno, '[]'::jsonb) ? p_user)
$function$;
revoke all on function public.bsp_escala_no_turno(bigint, date, text, text) from public, anon;

create or replace function public.bsp_troca_pedir(p_escala bigint, p_dia date, p_turno text, p_para text, p_dia2 date default null, p_turno2 text default null, p_nota text default '')
returns bigint
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_id bigint; eu text := public.bsp_meu_id();
begin
  if eu is null then raise exception 'Sem sessão.'; end if;
  if p_dia < (now() at time zone 'Africa/Luanda')::date then raise exception 'Esse dia já passou.'; end if;
  if not public.bsp_escala_no_turno(p_escala, p_dia, p_turno, eu) then raise exception 'Não está nesse turno.'; end if;
  if public.bsp_escala_no_turno(p_escala, p_dia, p_turno, p_para) then raise exception 'O colega já está nesse turno.'; end if;
  if p_dia2 is not null and not public.bsp_escala_no_turno(p_escala, p_dia2, p_turno2, p_para) then
    raise exception 'O colega não está no turno que daria em troca.';
  end if;
  insert into public.trocas_turno (escala_id, dia, turno, de_user, para_user, dia2, turno2, nota)
  values (p_escala, p_dia, p_turno, eu, p_para, p_dia2, p_turno2, coalesce(p_nota, ''))
  returning id into v_id;
  insert into public.novidades (titulo, texto, grupos, destino)
  values ('Pedido de troca de turno', public.bsp_nome_de(eu) || ' pede-lhe que fique com o turno de ' || to_char(p_dia, 'DD-MM-YYYY')
          || case when p_dia2 is not null then ', e fica com o seu de ' || to_char(p_dia2, 'DD-MM-YYYY') else '' end
          || '. Aceite ou recuse em Escalas → Trocas de turno.', array[p_para], 'escalas');
  return v_id;
end $function$;
grant execute on function public.bsp_troca_pedir(bigint, date, text, text, date, text, text) to authenticated;

-- O colega aceita ou recusa; quem pediu cancela.
create or replace function public.bsp_troca_responder(p_id bigint, p_estado text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare t public.trocas_turno; eu text := public.bsp_meu_id();
begin
  select * into t from public.trocas_turno where id = p_id for update;
  if not found then raise exception 'Troca não encontrada.'; end if;
  if p_estado = 'Cancelado' then
    if t.de_user <> eu or t.estado not in ('Pedido', 'Aceite') then raise exception 'Não pode cancelar esta troca.'; end if;
  elsif p_estado in ('Aceite', 'Recusado') then
    if t.para_user <> eu or t.estado <> 'Pedido' then raise exception 'Não pode responder a esta troca.'; end if;
  else
    raise exception 'Estado inválido.';
  end if;
  update public.trocas_turno set estado = p_estado, respondido_em = now() where id = p_id;
  if p_estado = 'Aceite' then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Troca de turno para aprovar', public.bsp_nome_de(t.para_user) || ' aceita ficar com o turno de ' || public.bsp_nome_de(t.de_user)
            || ' de ' || to_char(t.dia, 'DD-MM-YYYY') || '. Aprove em Escalas → Trocas de turno.', array['direccao-clinica'], 'escalas');
  elsif p_estado = 'Recusado' then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Troca de turno recusada', public.bsp_nome_de(t.para_user) || ' não pode ficar com o seu turno de ' || to_char(t.dia, 'DD-MM-YYYY') || '.', array[t.de_user], 'escalas');
  end if;
end $function$;
grant execute on function public.bsp_troca_responder(bigint, text) to authenticated;

-- A Direcção Clínica aprova (e a troca entra na escala) ou recusa.
create or replace function public.bsp_troca_decidir(p_id bigint, p_aprovar boolean, p_motivo text default '')
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare t public.trocas_turno; d jsonb; k1 text; k2 text;
begin
  if not public.bsp_le_areas_medicas() then raise exception 'Só a Direcção Clínica aprova trocas de turno.'; end if;
  select * into t from public.trocas_turno where id = p_id for update;
  if not found or t.estado <> 'Aceite' then raise exception 'A troca tem de estar aceite pelo colega.'; end if;
  if not p_aprovar then
    update public.trocas_turno set estado = 'Recusado', decidido_por = public.bsp_meu_id(), decidido_em = now(), motivo = coalesce(p_motivo, '') where id = p_id;
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Troca de turno não aprovada', 'A troca do turno de ' || to_char(t.dia, 'DD-MM-YYYY') || ' não foi aprovada.'
            || case when coalesce(p_motivo, '') <> '' then ' Motivo: ' || p_motivo else '' end, array[t.de_user, t.para_user], 'escalas');
    return;
  end if;
  if not public.bsp_escala_no_turno(t.escala_id, t.dia, t.turno, t.de_user) then raise exception 'A escala mudou: quem pediu já não está nesse turno.'; end if;
  if t.dia2 is not null and not public.bsp_escala_no_turno(t.escala_id, t.dia2, t.turno2, t.para_user) then raise exception 'A escala mudou: o colega já não está no turno dado em troca.'; end if;
  select dias into d from public.escalas where id = t.escala_id for update;
  k1 := to_char(t.dia, 'YYYY-MM-DD');
  d := jsonb_set(d, array[k1, t.turno], (select coalesce(jsonb_agg(case when x = t.de_user then t.para_user else x end), '[]'::jsonb) from jsonb_array_elements_text(d -> k1 -> t.turno) x));
  if t.dia2 is not null then
    k2 := to_char(t.dia2, 'YYYY-MM-DD');
    d := jsonb_set(d, array[k2, t.turno2], (select coalesce(jsonb_agg(case when x = t.para_user then t.de_user else x end), '[]'::jsonb) from jsonb_array_elements_text(d -> k2 -> t.turno2) x));
  end if;
  -- O visto mantém-se: quem aprova é quem o dá (ver escalas-visto.sql).
  perform set_config('bsp.visto', '1', true);
  update public.escalas set dias = d,
         notas = btrim(coalesce(notas, '') || E'\n' || 'Troca aprovada a ' || to_char(now() at time zone 'Africa/Luanda', 'DD-MM-YYYY HH24:MI') || ': '
                 || public.bsp_nome_de(t.de_user) || ' → ' || public.bsp_nome_de(t.para_user) || ' (' || to_char(t.dia, 'DD-MM') || ')'
                 || case when t.dia2 is not null then ' e ' || public.bsp_nome_de(t.para_user) || ' → ' || public.bsp_nome_de(t.de_user) || ' (' || to_char(t.dia2, 'DD-MM') || ')' else '' end)
   where id = t.escala_id;
  perform set_config('bsp.visto', '', true);
  update public.trocas_turno set estado = 'Aprovado', decidido_por = public.bsp_meu_id(), decidido_em = now() where id = p_id;
  insert into public.novidades (titulo, texto, grupos, destino)
  values ('Troca de turno aprovada', 'A troca do turno de ' || to_char(t.dia, 'DD-MM-YYYY') || ' está na escala.', array[t.de_user, t.para_user], 'escalas');
end $function$;
grant execute on function public.bsp_troca_decidir(bigint, boolean, text) to authenticated;

notify pgrst, 'reload schema';
