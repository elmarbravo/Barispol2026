-- Destinatários dos relatórios de turno (14-10-2026, Elmar: «os relatórios
-- seguem para direcção clínica, adm e superiores de cada área»).
-- Pode correr-se mais do que uma vez.
--
-- Cada relatório entregue no Workspace vai por e-mail:
--   para: o chefe da área (relatorios_destinos.para) e a Direcção Clínica;
--   cc:   a DAF (adm@) e o superior de quem entrega (campo `superior` na
--         equipa, por exemplo a Arlete para a Juliana).
-- Quem entrega nunca recebe o seu próprio relatório; sem repetidos.
-- Antes: a Recepção não ia à Direcção Clínica e o Laboratório e a
-- Imagiologia não iam a nenhum chefe (o Laboratório não tem chefe desde a
-- saída da Rosa Queirós; a coluna fica vazia até haver um).

update public.relatorios_destinos set
  para = case area
    when 'rececao'     then array['juliana.lourenco@barispol.com']
    when 'farmacia'    then array['solange.orlando@barispol.com']
    when 'enfermagem'  then array['filomena.silva@barispol.com']
    else '{}'::text[] end,
  substituto = '{}'::text[],
  cc = array['DireccaoClinica@barispol.com', 'adm@barispol.com'];

create or replace function public.bsp_relatorio_destinatarios(p_area text, p_user text)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare
  d record; autor jsonb; sup text; eu text; para text[] := '{}'; cc text[] := '{}'; x text;
begin
  select * into d from relatorios_destinos where area = p_area;
  if not found then return null; end if;
  select e into autor from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = p_user limit 1;
  eu := lower(coalesce(autor->>'email', ''));
  select lower(e->>'email') into sup from shared_state s, jsonb_array_elements(s.team) e
    where s.id = 1 and e->>'id' = autor->>'superior' and coalesce(e->>'inactivo', '') <> 'true' limit 1;
  foreach x in array coalesce(d.para, '{}') || array['DireccaoClinica@barispol.com'] loop
    if lower(x) <> eu and not lower(x) = any (select lower(y) from unnest(para) y) then para := para || x; end if;
  end loop;
  foreach x in array coalesce(d.cc, '{}') || array['adm@barispol.com'] || coalesce(array[sup], '{}') loop
    if x is null or lower(x) = eu then continue; end if;
    if lower(x) = any (select lower(y) from unnest(para || cc) y) then continue; end if;
    cc := cc || x;
  end loop;
  return jsonb_build_object('para', to_jsonb(para), 'cc', to_jsonb(cc));
end $f$;
revoke all on function public.bsp_relatorio_destinatarios(text, text) from public, anon, authenticated;

-- O envio passa a usar a lista acima (o resto do e-mail não muda).
do $x$
declare def text;
begin
  def := pg_get_functiondef('public.bsp_relatorio_area_email'::regproc);
  if position('bsp_relatorio_destinatarios' in def) > 0 then return; end if;
  def := replace(def,
    $a$  para := case when lower(coalesce(autor->>'email','')) = any (select lower(y) from unnest(d.para) y) then d.substituto else d.para end;$a$,
    $a$  para := array(select jsonb_array_elements_text(public.bsp_relatorio_destinatarios(new.area, new.user_id)->'para'));$a$);
  def := replace(def,
    $a$  perform bsp_enviar_email(para, array(select y from unnest(d.cc) y where not (y = any(para))), '{}',$a$,
    $a$  perform bsp_enviar_email(para, array(select jsonb_array_elements_text(public.bsp_relatorio_destinatarios(new.area, new.user_id)->'cc')), '{}',$a$);
  if position('bsp_relatorio_destinatarios' in def) = 0 then
    raise exception 'bsp_relatorio_area_email não tem o texto esperado; nada mudou.';
  end if;
  execute def;
end $x$;

notify pgrst, 'reload schema';
