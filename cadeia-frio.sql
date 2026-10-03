-- Cadeia de frio (03-10-2026, revisão «o que falta»). Os relatórios de turno
-- da Farmácia, do Laboratório e da Enfermagem levam a temperatura mínima e
-- máxima do frigorífico (campos frio_min e frio_max em BSP_CAMPOS_AREA,
-- opcionais). Fora de 2 a 8 °C, a gestão, a Direcção Clínica e o chefe da
-- área recebem logo o aviso no telemóvel, e fica nas novidades.

create or replace function public.bsp_num(t text)
returns numeric language sql immutable
as $f$ select case when replace(btrim(coalesce(t, '')), ',', '.') ~ '^-?[0-9]+(\.[0-9]+)?$' then replace(btrim(t), ',', '.')::numeric end $f$;

create or replace function public.bsp_frio_aviso()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare mn numeric := public.bsp_num(new.respostas->>'frio_min'); mx numeric := public.bsp_num(new.respostas->>'frio_max');
        para text[]; chefes text[]; txt text; area text;
begin
  if new.area not in ('farmacia', 'laboratorio', 'enfermagem') then return null; end if;
  if (mn is null or mn >= 2) and (mx is null or mx <= 8) then return null; end if;
  area := case new.area when 'farmacia' then 'Farmácia' when 'laboratorio' then 'Laboratório' else 'Enfermagem' end;
  select coalesce(array_agg(distinct x), '{}') into chefes
    from public.bsp_escalas_responsaveis() r, unnest(r.ids) x where r.area = new.area;
  para := public.bsp_ids_qualidade() || chefes;
  txt := area || ', ' || to_char(new.dia, 'DD-MM') || coalesce(' (' || nullif(new.turno, '') || ')', '') || ': frigorífico entre '
         || coalesce(mn::text, '?') || ' e ' || coalesce(mx::text, '?') || ' °C (deve estar entre 2 e 8). Verificar vacinas, reagentes e medicamentos.';
  perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'exceto', coalesce(new.user_id, ''),
    'titulo', 'Cadeia de frio fora do intervalo', 'corpo', left(txt, 160), 'url', '#/relatorios', 'tag', 'frio-' || new.id));
  insert into public.novidades (titulo, texto, grupos, destino)
    values ('Cadeia de frio fora do intervalo', txt, array['gestao', 'direccao-clinica', new.area], 'relatorios');
  return null;
end $f$;
revoke execute on function public.bsp_frio_aviso() from public, anon, authenticated;
drop trigger if exists bsp_frio_aviso on public.relatorios_area;
create trigger bsp_frio_aviso after insert on public.relatorios_area
  for each row execute function public.bsp_frio_aviso();
