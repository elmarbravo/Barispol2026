-- Relatórios de turno no Workspace (14-10-2026, Elmar: «ver nos relatórios o
-- que está débil e o que pode ser repetitivo agora com o Workspace … o
-- importante não enviam»). Pode correr-se mais do que uma vez.
--
-- Até hoje só tinham entrado 2 relatórios no formulário (Imagiologia, 2 e 3
-- de Outubro); a equipa escrevia e-mails à mão com as contagens do dia, que o
-- MetaGest já dá, e deixava de fora o que só a área sabe. Agora:
--
-- 1. bsp_relatorio_metagest(area, dia): o que o MetaGest já registou nesse
--    dia para a área (contagens, stock esgotado ou a acabar, avisos da área),
--    para o formulário vir preenchido e a pessoa só confirmar e acrescentar
--    o que falta. Só a própria área, a Direcção Clínica (u14) e a gestão.
-- 2. Ao entregar (gatilho bsp_relatorio_preparar): a coluna metagest guarda
--    os números do servidor nesse momento (não se escrevem do ecrã).
-- 3. Conferência (bsp_relatorio_conferir): se a área declarar mais actos do
--    que o MetaGest facturou no dia (soma dos relatórios da área), a gestão e
--    a Arlete (u2) recebem a novidade «Possível acto por facturar».
-- 4. «Precisa de atenção» (bsp_relatorio_atencao): ruptura ou stock baixo,
--    equipamento avariado, intercorrências graves, incidentes ou quase-erros,
--    resultados atrasados, documentos por regularizar → novidade e aviso no
--    telemóvel à gestão, à Direcção Clínica (áreas de saúde) e ao chefe da
--    área, no momento.
-- 5. E-mail (bsp_relatorio_area_email): as perguntas por extenso (coluna
--    resumo, enviada pelo ecrã) em vez dos nomes internos dos campos, com
--    «Precisa de atenção» e a conferência no topo.
-- 6. Lembrete de fim de turno (bsp_relatorios_lembrar, de 30 em 30 min): 1
--    hora depois do fim de cada turno da escala publicada da área, quem
--    esteve nesse turno e ainda não entregou recebe aviso no telemóvel e no
--    sino; uma vez por turno (relatorios_lembretes).
--
-- O dia do relatório: antes das 06h00 de Luanda conta como o dia anterior
-- (os turnos que acabam às 22h30 entregam depois da meia-noite).
-- Sem nomes de utentes em nada disto.

alter table public.relatorios_area add column if not exists resumo jsonb;
alter table public.relatorios_area add column if not exists metagest jsonb;

-- A área do formulário de uma pessoa (igual a bspAreaDe no ecrã: pelo cargo e
-- depois pelo departamento).
create or replace function public.bsp_relatorio_area_de(p_id text)
returns text language sql stable security definer set search_path to 'public'
as $f$
  select case
    when x ~ '(laborat|analista)' then 'laboratorio'
    when x ~ 'farmac' then 'farmacia'
    when x ~ 'enferm' then 'enfermagem'
    when x ~ '(radiolog|raio|ecograf|imagiolog)' then 'imagiologia'
    when x ~ '(recep|caixa)' then 'rececao'
  end
  from (
    select translate(lower(coalesce(e->>'role', '') || ' ' || coalesce(e->>'dept', '')), 'áàâãéêíóôõúç', 'aaaaeeiooouc') x
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
    where s.id = 1 and e->>'id' = p_id
    limit 1
  ) q
$f$;
revoke all on function public.bsp_relatorio_area_de(text) from public, anon, authenticated;

-- A área do formulário → a área da escala.
create or replace function public.bsp_relatorio_area_escala(p_area text)
returns text language sql immutable
as $f$ select case p_area when 'rececao' then 'recepcao' when 'imagiologia' then 'radiologia' else p_area end $f$;

-- Os números do MetaGest de uma área num dia (sem controlo de acesso; só para
-- as funções do servidor).
create or replace function public.bsp_relatorio_mg(p_area text, p_dia date)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare d jsonb; n jsonb; st jsonb; ex jsonb; r jsonb;
begin
  d := erp.clinico_dados(p_dia, p_dia);
  n := coalesce(d->'numeros', '{}'::jsonb);
  st := coalesce(d->'stock', '{}'::jsonb);
  ex := coalesce(d->'extra', '{}'::jsonb);
  r := case p_area
    when 'rececao' then jsonb_build_object('utentes', n->'utentes', 'novos', n->'novos', 'consultas', n->'consultas')
    when 'laboratorio' then jsonb_build_object('pacientes', n->'utentes_lab', 'exames', n->'exames_lab', 'externos', n->'exames_externos')
    when 'imagiologia' then jsonb_build_object('raiox', n->'raiox', 'ecografias', n->'ecografias')
    when 'enfermagem' then jsonb_build_object('actos', n->'actos_enfermagem', 'utentes', n->'utentes_enfermagem', 'consultas', n->'consultas')
    when 'farmacia' then jsonb_build_object('utentes', n->'utentes_farmacia', 'unidades', n->'unidades_farmacia', 'produtos', n->'produtos_farmacia')
    else '{}'::jsonb end;
  -- Stock que o MetaGest já sabe que falta (para a pessoa não ter de o contar).
  if p_area = 'farmacia' then
    r := r || jsonb_build_object(
      'esgotados', coalesce(st->'farmacia'->'esgotados', '[]'::jsonb),
      'a_acabar', coalesce((select jsonb_agg(x->>'nome' || ' (' || (x->>'dias') || ' d)') from jsonb_array_elements(coalesce(st->'farmacia'->'a_acabar', '[]'::jsonb)) x), '[]'::jsonb),
      'a_caducar', coalesce((select jsonb_agg(x->>'nome' || ' (' || to_char((x->>'validade')::date, 'DD-MM') || ')') from jsonb_array_elements(coalesce(st->'farmacia'->'a_caducar', '[]'::jsonb)) x where (x->>'validade')::date <= p_dia + 7), '[]'::jsonb));
  elsif p_area = 'laboratorio' then
    r := r || jsonb_build_object(
      'esgotados', coalesce((select jsonb_agg(x->>'nome') from jsonb_array_elements(coalesce(ex->'lab_consumiveis', '[]'::jsonb)) x where coalesce((x->>'stock')::numeric, 0) <= 0 and coalesce((x->>'saidas_30d')::numeric, 0) > 0), '[]'::jsonb),
      'a_acabar', coalesce((select jsonb_agg(x->>'nome' || ' (' || (x->>'dias') || ' d)') from jsonb_array_elements(coalesce(ex->'lab_consumiveis', '[]'::jsonb)) x where (x->>'dias') is not null and (x->>'dias')::numeric between 1 and 14), '[]'::jsonb));
  elsif p_area = 'enfermagem' then
    r := r || jsonb_build_object(
      'esgotados', coalesce(st->'enfermagem'->'esgotados', '[]'::jsonb),
      'a_acabar', coalesce((select jsonb_agg(x->>'nome') from jsonb_array_elements(coalesce(st->'enfermagem'->'a_acabar', '[]'::jsonb)) x), '[]'::jsonb));
  end if;
  -- Avisos da área (marcações por fechar, rascunhos, etc.).
  r := r || jsonb_build_object('avisos', coalesce((select jsonb_agg(a->>'texto' order by (a->>'o')::int)
    from jsonb_array_elements(coalesce(d->'alertas', '[]'::jsonb)) a
    where a->>'area' = bsp_relatorio_area_escala(p_area)), '[]'::jsonb));
  return r;
end $f$;
revoke all on function public.bsp_relatorio_mg(text, date) from public, anon, authenticated;

-- Para o ecrã: só a própria área, a Direcção Clínica e a gestão.
create or replace function public.bsp_relatorio_metagest(p_area text, p_dia date default null)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare dia date := coalesce(p_dia, ((now() at time zone 'Africa/Luanda') - interval '6 hours')::date);
begin
  if p_area not in ('rececao', 'laboratorio', 'imagiologia', 'enfermagem', 'farmacia') then raise exception 'Área desconhecida.'; end if;
  if not (public.bsp_e_gestor() or public.bsp_meu_id() = 'u14' or public.bsp_relatorio_area_de(public.bsp_meu_id()) = p_area) then
    raise exception 'Sem acesso aos números desta área.';
  end if;
  if dia < current_date - 7 or dia > current_date + 1 then raise exception 'Só os últimos 7 dias.'; end if;
  return public.bsp_relatorio_mg(p_area, dia) || jsonb_build_object('dia', dia);
end $f$;
revoke all on function public.bsp_relatorio_metagest(text, date) from public, anon;
grant execute on function public.bsp_relatorio_metagest(text, date) to authenticated;

-- Ao entregar: os números do MetaGest ficam guardados com o relatório.
create or replace function public.bsp_relatorio_preparar()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
begin
  begin
    new.metagest := public.bsp_relatorio_mg(new.area, new.dia) - 'avisos';
  exception when others then
    new.metagest := null; -- o MetaGest em baixo nunca impede a entrega
  end;
  return new;
end $f$;
revoke all on function public.bsp_relatorio_preparar() from public, anon, authenticated;
create or replace trigger bsp_relatorio_preparar before insert on public.relatorios_area
  for each row execute function public.bsp_relatorio_preparar();

-- Números de um relatório (inteiros; o que não for número conta 0).
create or replace function public.bsp_rel_n(r jsonb, k text)
returns numeric language sql immutable
as $f$ select coalesce(case when (r->>k) ~ '^\s*\d+([.,]\d+)?\s*$' then replace(r->>k, ',', '.')::numeric end, 0) $f$;

-- Conferência: o que a área declarou no dia (soma dos relatórios) contra o
-- que o MetaGest facturou. Devolve as linhas em que se declarou a mais.
create or replace function public.bsp_relatorio_conferir(p_area text, p_dia date)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare mg jsonb; declarado_ jsonb; res jsonb := '[]'::jsonb; r record;
begin
  mg := public.bsp_relatorio_mg(p_area, p_dia);
  select jsonb_build_object(
      'im_ev_etc', sum(bsp_rel_n(respostas, 'im') + bsp_rel_n(respostas, 'ev') + bsp_rel_n(respostas, 'observacoes') + bsp_rel_n(respostas, 'nebulizacoes') + bsp_rel_n(respostas, 'curativos')),
      'exames', sum(bsp_rel_n(respostas, 'exames')),
      'raiox', sum(bsp_rel_n(respostas, 'raiox')),
      'ecografias', sum(bsp_rel_n(respostas, 'ecografias')),
      'utentes', sum(bsp_rel_n(respostas, 'utentes')))
    into declarado_
    from public.relatorios_area where area = p_area and dia = p_dia;
  for r in
    select * from (values
      ('enfermagem', 'Actos de enfermagem (injecções, observações, nebulizações, curativos)', 'im_ev_etc', 'actos'),
      ('laboratorio', 'Exames de laboratório', 'exames', 'exames'),
      ('imagiologia', 'Exames de Raio-X', 'raiox', 'raiox'),
      ('imagiologia', 'Ecografias', 'ecografias', 'ecografias'),
      ('rececao', 'Utentes atendidos', 'utentes', 'utentes')) v(area, rotulo, kd, km)
    where v.area = p_area
  loop
    if coalesce((declarado_->>r.kd)::numeric, 0) > coalesce((mg->>r.km)::numeric, 0) then
      res := res || jsonb_build_array(jsonb_build_object('o', r.rotulo, 'declarado', (declarado_->>r.kd)::numeric, 'metagest', coalesce((mg->>r.km)::numeric, 0)));
    end if;
  end loop;
  return res;
end $f$;
revoke all on function public.bsp_relatorio_conferir(text, date) from public, anon, authenticated;

-- O que precisa de atenção num relatório (texto curto, sem nomes).
create or replace function public.bsp_relatorio_atencao(r jsonb)
returns text[] language plpgsql immutable
as $f$
declare res text[] := '{}'; v text;
begin
  v := r->>'rupturas'; if v is not null and v <> 'Nenhuma' then res := res || ('Rupturas de stock: ' || v); end if;
  v := r->>'reagentes'; if v in ('Stock baixo', 'Em ruptura') then res := res || ('Reagentes e consumíveis: ' || lower(v)); end if;
  v := r->>'consumiveis'; if v in ('Stock baixo', 'Em ruptura') then res := res || ('Películas e consumíveis: ' || lower(v)); end if;
  if jsonb_typeof(r->'material') = 'array' and not (r->'material' ? 'Nenhum') and jsonb_array_length(r->'material') > 0 then
    res := res || ('Material em falta: ' || (select string_agg(x, ', ') from jsonb_array_elements_text(r->'material') x));
  end if;
  v := coalesce(r->>'equipamentos', r->>'aparelhos'); if v is not null and v <> 'Todos operacionais' then res := res || ('Equipamentos: ' || lower(v)); end if;
  if jsonb_typeof(r->'avarias') = 'array' and not (r->'avarias' ? 'Nenhuma') and jsonb_array_length(r->'avarias') > 0 then
    res := res || ('Avarias: ' || (select string_agg(x, ', ') from jsonb_array_elements_text(r->'avarias') x));
  end if;
  v := r->>'intercorrencias'; if v like 'Graves%' then res := res || 'Intercorrências graves no turno'::text; end if;
  if public.bsp_rel_n(r, 'incidentes') > 0 then res := res || ('Incidentes com dano ao utente: ' || public.bsp_rel_n(r, 'incidentes')); end if;
  if public.bsp_rel_n(r, 'quase_erros') > 0 then res := res || ('Quase-erros: ' || public.bsp_rel_n(r, 'quase_erros')); end if;
  if public.bsp_rel_n(r, 'resultados_atraso') > 0 then res := res || ('Resultados fora do prazo: ' || public.bsp_rel_n(r, 'resultados_atraso')); end if;
  v := r->>'resultados'; if v in ('Alguns pendentes', 'Todos pendentes') then res := res || ('Resultados: ' || lower(v)); end if;
  v := r->>'requisicoes'; if v in ('Algumas por pagar', 'Algumas por processar') then res := res || ('Requisições: ' || lower(v)); end if;
  if public.bsp_rel_n(r, 'reclamacoes') > 0 then res := res || ('Reclamações: ' || public.bsp_rel_n(r, 'reclamacoes')); end if;
  if jsonb_typeof(r->'documentos') = 'array' and not (r->'documentos' ? 'Nenhum') and jsonb_array_length(r->'documentos') > 0 then
    res := res || ('Documentos por regularizar no MetaGest: ' || (select string_agg(x, ', ') from jsonb_array_elements_text(r->'documentos') x));
  end if;
  v := r->>'fecho_caixa'; if v = 'Por enviar' then res := res || 'Fecho de caixa por enviar'::text; end if;
  v := r->>'tpa'; if v = 'Por enviar' then res := res || 'Fecho do TPA por enviar'::text; end if;
  v := r->>'mapas'; if v in ('Alguns em falta', 'Nenhum entregue') then res := res || ('Mapas dos médicos: ' || lower(v)); end if;
  return res;
end $f$;

-- Depois de entregar: novidade e telemóvel com o que precisa de atenção, e a
-- conferência com o MetaGest.
create or replace function public.bsp_relatorio_depois()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare aten text[]; conf jsonb; nome text; chefes text[]; para text[]; txt text; c jsonb;
begin
  nome := case new.area when 'rececao' then 'Recepção' when 'laboratorio' then 'Laboratório' when 'farmacia' then 'Farmácia'
                        when 'enfermagem' then 'Enfermagem' when 'imagiologia' then 'Imagiologia' else new.area end;
  aten := public.bsp_relatorio_atencao(new.respostas);
  if coalesce(array_length(aten, 1), 0) > 0 then
    select coalesce(array_agg(distinct x), '{}') into chefes
      from public.bsp_escalas_responsaveis() r, unnest(r.ids) x where r.area = public.bsp_relatorio_area_escala(new.area);
    para := array['u1', 'u2'] || case when new.area <> 'rececao' then array['u14'] else '{}'::text[] end || chefes;
    txt := nome || ', ' || to_char(new.dia, 'DD-MM') || coalesce(' (' || nullif(new.turno, '') || ')', '') || ': ' || array_to_string(aten, '; ') || '.';
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'exceto', coalesce(new.user_id, ''),
      'titulo', 'Relatório de ' || nome || ': precisa de atenção', 'corpo', left(txt, 160), 'url', '#/relatorios', 'tag', 'relatorio-' || new.id));
    insert into public.novidades (titulo, texto, grupos, destino)
      values ('Relatório de ' || nome || ': precisa de atenção', txt,
              array['gestao'] || case when new.area <> 'rececao' then array['direccao-clinica'] else '{}'::text[] end || chefes, 'relatorios');
  end if;
  conf := public.bsp_relatorio_conferir(new.area, new.dia);
  if jsonb_array_length(conf) > 0 then
    txt := nome || ', ' || to_char(new.dia, 'DD-MM') || ': ' || (select string_agg((x->>'o') || ' — declarados ' || (x->>'declarado') || ', facturados no MetaGest ' || (x->>'metagest'), '; ')
             from jsonb_array_elements(conf) x) || '. Confirmar se há actos por facturar.';
    insert into public.novidades (titulo, texto, grupos, destino)
      values ('Possível acto por facturar', txt, array['u1', 'u2'], 'relatorios');
  end if;
  return null;
exception when others then
  return null; -- os avisos nunca impedem a entrega
end $f$;
revoke all on function public.bsp_relatorio_depois() from public, anon, authenticated;
create or replace trigger bsp_relatorio_depois after insert on public.relatorios_area
  for each row execute function public.bsp_relatorio_depois();

-- E-mail do relatório: perguntas por extenso, «Precisa de atenção» e a
-- conferência no topo.
create or replace function public.bsp_relatorio_area_email()
returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare
  d record; autor jsonb; para text[]; nomes jsonb := '{"rececao":"Recepção / Caixa","farmacia":"Farmácia","laboratorio":"Laboratório","imagiologia":"Imagiologia","enfermagem":"Enfermagem"}';
  linhas text := ''; k text; v jsonb; valor text; area_nome text; aten text[]; conf jsonb; topo text := ''; mg text := ''; x jsonb;
  td1 text := '<td style="padding:6px 10px 6px 0;vertical-align:top;color:#5A6180;font-size:13px;border-bottom:1px solid #E7EBF3">';
  td2 text := '<td style="padding:6px 0;vertical-align:top;color:#292F58;font-size:13px;border-bottom:1px solid #E7EBF3">';
begin
  select * into d from relatorios_destinos where area = new.area;
  if not found then return new; end if;
  select e into autor from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = new.user_id limit 1;
  para := case when lower(coalesce(autor->>'email','')) = any (select lower(y) from unnest(d.para) y) then d.substituto else d.para end;
  area_nome := coalesce(nomes->>new.area, new.area);
  if jsonb_typeof(new.resumo) = 'array' then
    for x in select * from jsonb_array_elements(new.resumo) loop
      if coalesce(x->>1, '') = '' then continue; end if;
      linhas := linhas || '<tr>' || td1 || bsp_html(x->>0) || '</td>' || td2 || bsp_html(x->>1) || '</td></tr>';
    end loop;
  else
    for k, v in select * from jsonb_each(new.respostas) loop
      valor := case jsonb_typeof(v) when 'array' then (select string_agg(y, ', ') from jsonb_array_elements_text(v) y) else v #>> '{}' end;
      if coalesce(valor,'') = '' then continue; end if;
      linhas := linhas || '<tr>' || td1 || bsp_html(initcap(replace(k,'_',' '))) || '</td>' || td2 || bsp_html(valor) || '</td></tr>';
    end loop;
  end if;
  aten := public.bsp_relatorio_atencao(new.respostas);
  if coalesce(array_length(aten, 1), 0) > 0 then
    topo := '<div style="border-left:4px solid #B91C1C;background:#FEF2F2;padding:10px 14px;margin:0 0 14px"><b style="color:#B91C1C">Precisa de atenção</b><ul style="margin:6px 0 0;padding-left:18px">'
      || (select string_agg('<li>' || bsp_html(y) || '</li>', '') from unnest(aten) y) || '</ul></div>';
  end if;
  begin
    conf := public.bsp_relatorio_conferir(new.area, new.dia);
    if jsonb_array_length(conf) > 0 then
      topo := topo || '<div style="border-left:4px solid #B45309;background:#FFFBEB;padding:10px 14px;margin:0 0 14px"><b style="color:#B45309">Declarado a mais do que o facturado no MetaGest</b><ul style="margin:6px 0 0;padding-left:18px">'
        || (select string_agg('<li>' || bsp_html(y->>'o') || ': declarados ' || (y->>'declarado') || ', facturados ' || (y->>'metagest') || '</li>', '') from jsonb_array_elements(conf) y) || '</ul></div>';
    end if;
  exception when others then null;
  end;
  if new.metagest is not null then
    mg := '<p style="margin:14px 0 0;color:#5A6180;font-size:12px">MetaGest no momento da entrega: '
      || bsp_html((select string_agg(replace(key, '_', ' ') || ' ' || value, ' · ') from jsonb_each_text(new.metagest) where value ~ '^\d+$')) || '.</p>';
  end if;
  perform bsp_enviar_email(para, array(select y from unnest(d.cc) y where not (y = any(para))), '{}',
    '[Relatório] ' || area_nome || ' — ' || to_char(new.dia, 'DD/MM/YYYY') || coalesce(' — ' || nullif(new.turno, ''), '') || ' — ' || coalesce(split_part(autor->>'name',' ',1),'colega')
      || case when coalesce(array_length(aten, 1), 0) > 0 then ' — precisa de atenção' else '' end,
    bsp_envelope('Relatório do dia: ' || bsp_html(area_nome),
      '<p style="margin:0 0 10px">Entregue por <b>' || bsp_html(coalesce(autor->>'name','colega')) || '</b> às ' || to_char(new.created_at at time zone 'Africa/Luanda','HH24:MI') || ' de ' || to_char(new.created_at at time zone 'Africa/Luanda','DD/MM/YYYY')
      || coalesce(' · ' || bsp_html(new.turno), '') || '.</p>' || topo
      || '<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse">' || linhas || '</table>' || mg
      || '<p style="margin:16px 0 0"><a href="https://barispol.com/workspace.html#/relatorios" style="color:#2291CE">Ver no Workspace</a></p>'));
  return new;
exception when others then
  return new; -- o e-mail nunca impede a entrega do relatorio
end $function$;

-- Lembrete de fim de turno.
create table if not exists public.relatorios_lembretes (
  area text not null,
  dia date not null,
  turno text not null,
  enviado_em timestamptz not null default now(),
  para text[] not null default '{}',
  primary key (area, dia, turno)
);
alter table public.relatorios_lembretes enable row level security;
revoke all on public.relatorios_lembretes from public, anon, authenticated;

create or replace function public.bsp_relatorios_lembrar()
returns jsonb language plpgsql security definer set search_path to 'public'
as $f$
declare
  agora timestamp := now() at time zone 'Africa/Luanda';
  d_dia date; e record; t jsonb; ids text[]; fim timestamp; area_form text; nome text; n int := 0; dow int;
begin
  -- Hoje e ontem (os turnos das 22h30 lembram-se às 23h30; um atraso do
  -- agendamento depois da meia-noite ainda apanha o dia anterior).
  foreach d_dia in array array[agora::date, agora::date - 1] loop
    dow := extract(dow from d_dia)::int;
    for e in select * from public.escalas
              where mes = date_trunc('month', d_dia)::date and estado = 'publicada'
                and area in ('recepcao', 'laboratorio', 'farmacia', 'enfermagem', 'radiologia') loop
      area_form := case e.area when 'recepcao' then 'rececao' when 'radiologia' then 'imagiologia' else e.area end;
      nome := case area_form when 'rececao' then 'Recepção' when 'laboratorio' then 'Laboratório' when 'farmacia' then 'Farmácia'
                             when 'enfermagem' then 'Enfermagem' else 'Imagiologia' end;
      for t in select * from jsonb_array_elements(coalesce(e.turnos, '[]'::jsonb)) loop
        if not coalesce(t->'semana' @> to_jsonb(dow), false) then continue; end if;
        select coalesce(array_agg(x), '{}') into ids
          from jsonb_array_elements_text(coalesce(e.dias->(d_dia::text)->(t->>'id'), '[]'::jsonb)) x where x !~ '^x:';
        if coalesce(array_length(ids, 1), 0) = 0 then continue; end if;
        fim := d_dia + coalesce(nullif(t->>'fim', ''), '22:30')::time;
        -- 1 hora depois do fim; só até 6 horas depois (não lembrar de turnos antigos).
        if agora < fim + interval '1 hour' or agora > fim + interval '6 hours' then continue; end if;
        if exists (select 1 from public.relatorios_lembretes l where l.area = area_form and l.dia = d_dia and l.turno = t->>'id') then continue; end if;
        if exists (select 1 from public.relatorios_area r where r.area = area_form and r.dia = d_dia and r.user_id = any(ids)) then continue; end if;
        perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(ids),
          'titulo', 'Relatório de turno por entregar', 'corpo', nome || ', ' || (t->>'nome') || ' de ' || to_char(d_dia, 'DD-MM') || ': entregue o relatório no Workspace (menu Relatórios).',
          'url', '#/relatorios', 'tag', 'relatorio-falta-' || area_form || '-' || d_dia || '-' || (t->>'id')));
        insert into public.novidades (titulo, texto, grupos, destino)
          values ('Relatório de turno por entregar', nome || ', ' || (t->>'nome') || ' de ' || to_char(d_dia, 'DD-MM')
                  || ': o relatório ainda não entrou. Entregue-o no menu Relatórios; os números do MetaGest já vêm preenchidos.', ids, 'relatorios');
        insert into public.relatorios_lembretes (area, dia, turno, para) values (area_form, d_dia, t->>'id', ids);
        n := n + 1;
      end loop;
    end loop;
  end loop;
  return jsonb_build_object('lembretes', n);
end $f$;
revoke all on function public.bsp_relatorios_lembrar() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname = 'bsp-relatorios-lembrar';
select cron.schedule('bsp-relatorios-lembrar', '*/30 * * * *', 'select public.bsp_relatorios_lembrar()');

notify pgrst, 'reload schema';
