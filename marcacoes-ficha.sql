-- Barispol Workspace · marcacoes ligadas a ficha do paciente
-- Pedido do Elmar, 26-09-2026 (pontos 1 a 4). Aplicado no projecto
-- Barispol (gnqleaxrtuerlcrriqqs) a 27-09-2026. Pode correr-se mais do que
-- uma vez. Corre depois de marcacoes.sql.
--
-- 1. A ficha do paciente (crm_ficha) mostra as marcacoes do mesmo telefone
--    ou do mesmo paciente do MetaGest, so a quem ve as Marcacoes.
-- 2. «Compareceu» automatico: uma marcacao Agendada ou Confirmada passa a
--    Compareceu quando o MetaGest tem factura ou consulta desse paciente
--    no dia marcado. Com paciente escolhido, conta so esse paciente; sem
--    ele, conta o telefone (uma familia pode partilhar o numero).
-- 3. bsp_marc_sugerir: ao marcar, sugere pacientes do MetaGest e de
--    marcacoes anteriores pelo nome ou pelo telefone.
-- 4. E-mail do paciente na marcacao. O MetaGest nao tem e-mail nem sexo:
--    vem da ultima marcacao do mesmo telefone.

-- Colunas -------------------------------------------------------------------
alter table public.marcacoes add column if not exists email text;
alter table public.marcacoes add column if not exists paciente_id text;
alter table public.marcacoes drop constraint if exists marcacoes_email_check;
alter table public.marcacoes add constraint marcacoes_email_check
  check (email is null or email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$');
-- Ultimos 9 algarismos do primeiro numero («927.../974...» usa o primeiro).
alter table public.marcacoes add column if not exists tel9 text
  generated always as (nullif(substring(regexp_replace(split_part(coalesce(contacto, ''), '/', 1), '\D', '', 'g') from '(\d{9})$'), '')) stored;
create index if not exists marcacoes_tel9_idx on public.marcacoes (tel9);
create index if not exists marcacoes_paciente_idx on public.marcacoes (paciente_id);

-- Quem altera: a pessoa com sessao; sem sessao (agendamento), fica o que
-- a propria alteracao escreveu (ex.: 'MetaGest').
create or replace function public.bsp_marcacoes_alterado()
returns trigger
language plpgsql
as $function$
begin
  new.alterado_por := coalesce(public.bsp_meu_id(), new.alterado_por);
  new.alterado_em := now();
  return new;
end $function$;

-- 2. Compareceu pelo MetaGest ----------------------------------------------
create or replace function public.bsp_marcacoes_comparecer()
returns integer
language plpgsql
security definer
set search_path to 'public', 'crm'
as $function$
declare n integer;
begin
  update public.marcacoes m
     set estado = 'Compareceu', alterado_por = 'MetaGest'
   where m.estado in ('Agendada', 'Confirmada')
     and m.data_marcada <= (now() at time zone 'Africa/Luanda')::date
     and (
       (m.paciente_id is not null and (
          exists (select 1 from crm.mg_facturas f where f.data = m.data_marcada and f.paciente = m.paciente_id)
          or exists (select 1 from crm.mg_consultas c where c.data = m.data_marcada and c.paciente = m.paciente_id)))
       or (m.paciente_id is null and m.tel9 is not null and (
          exists (select 1 from crm.mg_facturas f where f.data = m.data_marcada and f.tel9 = m.tel9)
          or exists (select 1 from crm.mg_facturas f join crm.mg_pacientes p on p.id = f.paciente
                      where f.data = m.data_marcada and p.tel9 = m.tel9)
          or exists (select 1 from crm.mg_consultas c join crm.mg_pacientes p on p.id = c.paciente
                      where c.data = m.data_marcada and p.tel9 = m.tel9)))
     );
  get diagnostics n = row_count;
  return n;
end $function$;
revoke all on function public.bsp_marcacoes_comparecer() from public, anon, authenticated;

-- Depois da sincronizacao do MetaGest (crm-metagest-diario, 04h00 UTC).
select cron.unschedule('bsp-marcacoes-metagest') where exists (select 1 from cron.job where jobname = 'bsp-marcacoes-metagest');
select cron.schedule('bsp-marcacoes-metagest', '30 4 * * *', 'select public.bsp_marcacoes_comparecer();');

-- 3. Sugestoes ao marcar ---------------------------------------------------
create or replace function public.bsp_marc_sugerir(q text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'crm'
as $function$
declare
  sem text := 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  com text := 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  t text := lower(translate(btrim(coalesce(q, '')), sem, com));
  dig text := regexp_replace(coalesce(q, ''), '\D', '', 'g');
  res jsonb;
begin
  if not public.bsp_ve_marcacoes() then raise exception 'Sem acesso às marcações.'; end if;
  if length(t) < 3 and length(dig) < 4 then return '[]'::jsonb; end if;
  with mg as (
    select p.id, p.nome, p.tel9,
           (select max(d) from (select data d from crm.mg_facturas where paciente = p.id
                                union select data from crm.mg_consultas where paciente = p.id) v) ultima
      from crm.mg_pacientes p
     where (length(dig) >= 4 and p.tel9 like '%' || right(dig, 9) || '%')
        or (length(t) >= 3 and lower(translate(p.nome, sem, com)) like '%' || t || '%')
     order by p.criado_em desc nulls last
     limit 8
  ), mc as (
    select distinct on (lower(m.nome), coalesce(m.tel9, '')) m.nome, m.tel9, m.contacto
      from public.marcacoes m
     where m.paciente_id is null
       and ((length(dig) >= 4 and m.tel9 like '%' || right(dig, 9) || '%')
         or (length(t) >= 3 and lower(translate(m.nome, sem, com)) like '%' || t || '%'))
     order by lower(m.nome), coalesce(m.tel9, ''), m.data_marcada desc
     limit 8
  ), todos as (
    select 'MetaGest' fonte, mg.id paciente_id, mg.nome, mg.tel9, mg.tel9 contacto, mg.ultima from mg
    union all
    select 'Marcação', null, mc.nome, mc.tel9, mc.contacto, null from mc
     where mc.tel9 is null or mc.tel9 not in (select tel9 from mg where tel9 is not null)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'fonte', x.fonte, 'paciente_id', x.paciente_id, 'nome', x.nome, 'tel9', x.tel9,
           'contacto', x.contacto, 'ultima', x.ultima,
           'email', (select m.email from public.marcacoes m where m.email is not null
                       and ((x.paciente_id is not null and m.paciente_id = x.paciente_id) or (x.tel9 is not null and m.tel9 = x.tel9))
                     order by m.data_marcada desc limit 1),
           'sexo', (select m.sexo from public.marcacoes m where m.sexo is not null
                       and ((x.paciente_id is not null and m.paciente_id = x.paciente_id) or (x.tel9 is not null and m.tel9 = x.tel9))
                     order by m.data_marcada desc limit 1))), '[]'::jsonb)
    into res
    from (select * from todos limit 8) x;
  return res;
end $function$;
revoke all on function public.bsp_marc_sugerir(text) from public, anon;
grant execute on function public.bsp_marc_sugerir(text) to authenticated;

-- 1. Ficha do paciente com as marcacoes ------------------------------------
-- Igual a versao anterior, mais a chave 'marcacoes' (vazia para quem nao
-- ve as Marcacoes, por exemplo o Comercial).
create or replace function public.crm_ficha(p_tel9 text default null, p_paciente text default null)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public', 'crm'
as $function$
declare t9 text := nullif(right(regexp_replace(coalesce(p_tel9,''), '\D', '', 'g'), 9), '');
        ids text[];
begin
  if not crm.pode_ver_crm() then raise exception 'Sem acesso ao CRM.'; end if;
  if p_paciente is not null then
    ids := array[p_paciente];
    if t9 is null then select tel9 into t9 from crm.mg_pacientes where id = p_paciente; end if;
  else
    select coalesce(array_agg(id), '{}') into ids from crm.mg_pacientes where tel9 = t9;
  end if;
  if t9 is null and coalesce(array_length(ids,1),0) = 0 then return jsonb_build_object('erro','Sem telefone nem paciente.'); end if;

  return jsonb_build_object(
    'tel9', t9,
    'pacientes', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'nome', p.nome, 'telemovel', coalesce(p.telemovel, p.telefone), 'desde', p.criado_em::date,
        'visitas', (select count(distinct d) from (select data d from crm.mg_facturas where paciente = p.id
                                                   union select data from crm.mg_consultas where paciente = p.id) v),
        'primeira', (select min(d) from (select data d from crm.mg_facturas where paciente = p.id union select data from crm.mg_consultas where paciente = p.id) v),
        'ultima', (select max(d) from (select data d from crm.mg_facturas where paciente = p.id union select data from crm.mg_consultas where paciente = p.id) v),
        'total', (select coalesce(sum(total),0) from crm.mg_facturas where paciente = p.id),
        'historico', (select coalesce(jsonb_agg(h order by h->>'data' desc), '[]') from (
            select jsonb_build_object('data', d.data,
              'consultas', (select coalesce(jsonb_agg(jsonb_build_object('medico', c.medico, 'especialidade', c.especialidade)), '[]')
                              from crm.mg_consultas c where c.paciente = p.id and c.data = d.data),
              'servicos', (select coalesce(jsonb_agg(distinct i.item_nome), '[]') from crm.mg_facturas f join crm.mg_factura_itens i on i.factura = f.id
                              where f.paciente = p.id and f.data = d.data),
              'valor', (select coalesce(sum(total),0) from crm.mg_facturas f where f.paciente = p.id and f.data = d.data)) h
            from (select data from crm.mg_facturas where paciente = p.id union select data from crm.mg_consultas where paciente = p.id) d
            order by d.data desc limit 60) hh)
      ) order by p.criado_em desc), '[]') from crm.mg_pacientes p where p.id = any(ids)),
    'whatsapp', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id, 'contacto_id', c.contacto_id, 'inicio', c.inicio, 'fim', c.fim, 'servico', c.servico, 'origem', c.origem,
        'primeira_mensagem', c.primeira_mensagem, 'resposta_humana_min', c.resposta_humana_min, 'responsavel', c.responsavel,
        'estado', coalesce(c.estado, c.estado_auto), 'compareceu_em', c.compareceu_em, 'valor', c.valor_facturado,
        'notas', (select coalesce(jsonb_agg(jsonb_build_object('em', n.criado_em, 'estado', n.estado, 'nota', n.nota) order by n.criado_em desc), '[]')
                    from crm.pedido_notas n where n.pedido_id = c.id)
      ) order by c.inicio desc), '[]') from crm.caixa c where t9 is not null and c.tel9 = t9 and c.categoria = 'Doente'),
    've_marcacoes', public.bsp_ve_marcacoes(),
    'marcacoes', case when public.bsp_ve_marcacoes() then (select coalesce(jsonb_agg(jsonb_build_object(
        'id', m.id, 'data', m.data_marcada, 'hora', m.hora, 'acto', m.acto, 'medico', m.medico, 'nome', m.nome,
        'estado', m.estado, 'observacoes', m.observacoes, 'email', m.email, 'alterado_por', m.alterado_por
      ) order by m.data_marcada desc, m.hora desc nulls last), '[]')
      from (select * from public.marcacoes m
             where (t9 is not null and m.tel9 = t9) or m.paciente_id = any(ids)
             order by m.data_marcada desc limit 60) m) else '[]'::jsonb end
  );
end $function$;

notify pgrst, 'reload schema';

-- 5. Valor pago (27-09-2026) ----------------------------------------------
-- O que o MetaGest facturou ao paciente no dia marcado, com os actos e o
-- valor de cada um. Facturacao: so a quem ve as Marcacoes E o CRM (a
-- Recepcao e a gestao; a Direccao Clinica nao ve o CRM). Com paciente
-- escolhido conta so esse; sem ele, o telefone.
create or replace function public.bsp_marc_valores(p_de date, p_ate date)
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'crm'
as $function$
  select coalesce(jsonb_object_agg(x.id, jsonb_build_object('total', x.total, 'itens', x.itens)), '{}'::jsonb)
  from (
    select m.id,
           (select coalesce(sum(f.total), 0) from crm.mg_facturas f where f.id = any (fs.ids)) total,
           (select coalesce(jsonb_agg(jsonb_build_object('nome', i.item_nome, 'valor', i.valor) order by i.valor desc), '[]'::jsonb)
              from crm.mg_factura_itens i where i.factura = any (fs.ids)) itens
      from public.marcacoes m
      cross join lateral (
        select array(
          select f.id from crm.mg_facturas f
           where f.data = m.data_marcada
             and ((m.paciente_id is not null and f.paciente = m.paciente_id)
               or (m.paciente_id is null and m.tel9 is not null and (f.tel9 = m.tel9
                    or f.paciente in (select p.id from crm.mg_pacientes p where p.tel9 = m.tel9))))) ids
      ) fs
     where public.bsp_ve_marcacoes() and crm.pode_ver_crm()
       and m.data_marcada between p_de and p_ate
       and m.data_marcada <= (now() at time zone 'Africa/Luanda')::date
       and cardinality(fs.ids) > 0
  ) x
$function$;
revoke all on function public.bsp_marc_valores(date, date) from public, anon;
grant execute on function public.bsp_marc_valores(date, date) to authenticated;
