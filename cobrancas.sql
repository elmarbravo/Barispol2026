-- Barispol Workspace · facturas por receber (cobranças)
-- Pedido do Elmar, 01-10-2026 («Faz»). Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- 1. Acerto diário com o MetaGest (erp.reconciliar_cobrancas): a cópia
--    erp.sales_invoice só relê os últimos 7 dias, por isso uma factura antiga
--    paga depois ficava «por pagar». O acerto pede ao MetaGest a lista actual
--    das facturas com valor em falta e põe a cópia igual. Se o MetaGest
--    falhar a meio, pára com erro e não muda nada (erp.api_get levanta erro).
-- 2. Os números (erp.cobrancas_dados): por receber, vencido, antiguidade pela
--    data de vencimento, devedores. Seguradoras e empresas pelo nome;
--    utentes só em conjunto («Particulares»), nunca com nome. Restos abaixo
--    de 50 Kz (arredondamentos) não contam.
-- 3. Quem vê: as mesmas pessoas do Painel (bsp_ve_painel: Elmar, Financeiro,
--    sócios). Ecrã: Painel → «Por receber» (public.bsp_cobrancas).
-- 4. E-mail (public.bsp_cobrancas_email): existe mas NÃO está agendado.
--    O Elmar não quer o e-mail de cobranças (01-10-2026). Nada sai para
--    seguradoras nem clientes.

create table if not exists erp.cobrancas_estado (
  id int primary key default 1 check (id = 1),
  acertado_em timestamptz,
  facturas int,
  mudadas int,
  pagas int,
  fora_da_copia int
);
create table if not exists erp.cobrancas_dia (
  dia date primary key,
  total numeric not null,
  vencido numeric not null,
  facturas int not null
);
revoke all on erp.cobrancas_estado, erp.cobrancas_dia from public, anon, authenticated;

create or replace function erp.reconciliar_cobrancas()
returns jsonb
language plpgsql
security definer
set search_path to 'erp', 'public'
as $function$
declare v_start int := 0; v_page int := 500; v_lote jsonb; v_tudo jsonb := '[]'::jsonb; v_n int; v_mud int; v_pag int; v_fora int;
begin
  loop
    v_lote := erp.api_get('/api/resource/Sales%20Invoice?fields=' || erp.enc('["name","outstanding_amount","status","due_date"]')
      || '&filters=' || erp.enc('[["docstatus","=",1],["outstanding_amount",">",0]]')
      || '&limit_page_length=' || v_page || '&limit_start=' || v_start
      || '&order_by=' || erp.enc('name asc')) -> 'data';
    if v_lote is null then raise exception 'MetaGest sem resposta na posição %.', v_start; end if;
    v_tudo := v_tudo || v_lote;
    exit when jsonb_array_length(v_lote) < v_page;
    v_start := v_start + v_page;
  end loop;
  v_n := jsonb_array_length(v_tudo);
  -- Salvaguarda: uma lista vazia com muitas facturas em aberto na cópia é
  -- falha do MetaGest, não pagamento de tudo.
  if v_n = 0 and (select count(*) from erp.sales_invoice where docstatus = 1 and outstanding_amount > 0) > 50 then
    raise exception 'MetaGest devolveu a lista vazia; acerto cancelado.';
  end if;

  with c as (
    select distinct on (d->>'name') d->>'name' nome, (d->>'outstanding_amount')::numeric falta, d->>'status' estado,
           nullif(d->>'due_date', '') venc
      from jsonb_array_elements(v_tudo) d
  )
  update erp.sales_invoice si
     set outstanding_amount = c.falta,
         status = c.estado,
         raw = jsonb_set(coalesce(si.raw, '{}'::jsonb), '{due_date}', coalesce(to_jsonb(c.venc), 'null'::jsonb))
    from c
   where c.nome = si.name
     and (si.outstanding_amount is distinct from c.falta or si.status is distinct from c.estado
          or si.raw->>'due_date' is distinct from c.venc);
  get diagnostics v_mud = row_count;

  -- Em aberto na cópia e fora da lista do MetaGest: paga (ou anulada).
  update erp.sales_invoice si
     set outstanding_amount = 0,
         status = case when si.status in ('Overdue', 'Unpaid', 'Partly Paid') then 'Paid' else si.status end
   where si.docstatus = 1 and si.outstanding_amount > 0
     and si.name not in (select d->>'name' from jsonb_array_elements(v_tudo) d);
  get diagnostics v_pag = row_count;

  select count(*) into v_fora from jsonb_array_elements(v_tudo) d
    left join erp.sales_invoice si on si.name = d->>'name' where si.name is null;

  insert into erp.cobrancas_estado (id, acertado_em, facturas, mudadas, pagas, fora_da_copia)
  values (1, now(), v_n, v_mud, v_pag, v_fora)
  on conflict (id) do update set acertado_em = excluded.acertado_em, facturas = excluded.facturas,
    mudadas = excluded.mudadas, pagas = excluded.pagas, fora_da_copia = excluded.fora_da_copia;
  return jsonb_build_object('facturas', v_n, 'mudadas', v_mud, 'pagas', v_pag, 'fora_da_copia', v_fora);
end $function$;
revoke all on function erp.reconciliar_cobrancas() from public, anon, authenticated;

create or replace function erp.cobrancas_dados()
returns jsonb
language sql
stable
security definer
set search_path to 'erp', 'public'
as $function$
  with hoje as (select (now() at time zone 'Africa/Luanda')::date d),
  seg as (select distinct customer from erp.sales_invoice where customer_group = 'Seguradora'),
  -- Só nomes de empresa saem com nome; um cliente com nome de pessoa (há uma
  -- «família» no grupo Seguradora) conta como particular.
  f0 as (
    select si.posting_date, si.outstanding_amount v,
      coalesce(nullif(si.raw->>'due_date', '')::date, si.posting_date) venc,
      coalesce(nullif(si.customer_name, ''), si.customer) nome,
      case when si.customer in (select customer from seg) then 'Seguradora'
           when si.customer_group = 'Commercial' then 'Empresa' end tipo0
    from erp.sales_invoice si
    where si.docstatus = 1 and not coalesce(si.is_return, false) and si.outstanding_amount >= 50
  ),
  f as (
    select posting_date, v, venc,
      case when empresa then tipo0 else 'Particulares' end tipo,
      -- Igual a bspNomeSeguradora (workspace.html): corta em « - » ou na
      -- vírgula e tira o «S.A.» final, para juntar a mesma seguradora.
      case when empresa then btrim(regexp_replace(split_part(regexp_replace(nome, '\s+-\s+', ',', 'g'), ',', 1), '\s+S\.?\s?A\.?\s*$', '', 'i'))
           else 'Particulares (utentes)' end devedor
    from (select f0.*, tipo0 is not null and nome ~* '(\mS\.?\s?A\.?(\s|$)|\mLDA\M|SEGUR|\mBANCO\M|COMPANHIA|SA[UÚ]DE|GEST[AÃ]O|SOCIEDADE|CORPORA|M[UÚ]TUA|\mFUNDO\M|ASSOCIA|INSTITUTO|MINIST|EMPRESA|CL[IÍ]NICA|PACOTE|TRABALHADORES|FUNCION[AÁ]RIOS|COM[EÉ]RCIO|CONSTR|\mE\.\s?P\.?)' empresa from f0) z
  ),
  g as (select f.*, (select d from hoje) - f.venc dias from f)
  select jsonb_build_object(
    'hoje', (select d from hoje),
    'total', coalesce((select sum(v) from g), 0),
    'facturas', (select count(*) from g),
    'vencido', coalesce((select sum(v) from g where dias > 0), 0),
    'a_vencer', coalesce((select sum(v) from g where dias <= 0), 0),
    'idades', (select jsonb_agg(jsonb_build_object('faixa', x.faixa, 'facturas', x.n, 'valor', x.valor) order by x.o) from (
        select o, faixa, count(g.v) n, coalesce(sum(g.v), 0) valor
          from (values (0, 'A vencer', -100000, 0), (1, '1 a 30 dias', 1, 30), (2, '31 a 90 dias', 31, 90),
                       (3, '91 a 365 dias', 91, 365), (4, 'Mais de 1 ano', 366, 100000)) b(o, faixa, de, ate)
          left join g on g.dias between b.de and b.ate
         group by o, faixa) x),
    'por_tipo', (select jsonb_agg(jsonb_build_object('tipo', tipo, 'valor', valor, 'vencido', vencido) order by valor desc) from (
        select tipo, sum(v) valor, coalesce(sum(v) filter (where dias > 0), 0) vencido from g group by tipo) t),
    'devedores', (select coalesce(jsonb_agg(x order by (x->>'valor')::numeric desc), '[]'::jsonb) from (
        select jsonb_build_object('devedor', min(devedor), 'tipo', tipo, 'facturas', count(*), 'valor', sum(v),
          'vencido', coalesce(sum(v) filter (where dias > 0), 0),
          'mais_90', coalesce(sum(v) filter (where dias > 90), 0),
          'ultimos_30', coalesce(sum(v) filter (where posting_date > (select d from hoje) - 30), 0),
          'mais_antiga', min(venc)) x
        from (select g.*, upper(public.unaccent_safe(devedor)) chave from g) g group by chave, tipo order by sum(v) desc limit 15) d),
    'novas_7d', (select coalesce(jsonb_agg(x order by (x->>'valor')::numeric desc), '[]'::jsonb) from (
        select jsonb_build_object('devedor', min(devedor), 'tipo', tipo, 'facturas', count(*), 'valor', sum(v)) x
        from (select g.*, upper(public.unaccent_safe(devedor)) chave from g) g
        where posting_date > (select d from hoje) - 7 group by chave, tipo order by sum(v) desc limit 8) n),
    'ontem', (select jsonb_build_object('dia', dia, 'total', total, 'vencido', vencido) from erp.cobrancas_dia
               where dia < (select d from hoje) order by dia desc limit 1),
    'acerto', (select to_jsonb(e) - 'id' from erp.cobrancas_estado e where id = 1))
$function$;
revoke all on function erp.cobrancas_dados() from public, anon, authenticated;

-- Ecrã do Painel: só quem vê o Painel.
create or replace function public.bsp_cobrancas()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
begin
  if not public.bsp_ve_painel() then raise exception 'Sem acesso.'; end if;
  return erp.cobrancas_dados();
end $function$;
revoke all on function public.bsp_cobrancas() from public, anon;
grant execute on function public.bsp_cobrancas() to authenticated;

create or replace function public.bsp_num(v numeric)
returns text
language sql
immutable
set search_path to 'public'
as $function$ select replace(to_char(round(coalesce(v, 0)), 'FM999,999,999,990'), ',', ' ') $function$;

create or replace function public.bsp_kz(v numeric)
returns text
language sql
immutable
set search_path to 'public'
as $function$ select replace(to_char(round(coalesce(v, 0)), 'FM999,999,999,990'), ',', ' ') || ' Kz' $function$;

-- E-mail da manhã. p_enviar = false devolve o HTML sem enviar.
create or replace function public.bsp_cobrancas_email(p_enviar boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare d jsonb; para text[]; html text; corpo text; dif text := ''; aviso text := ''; linhas text; novas text; idades text; acerto timestamptz;
begin
  d := erp.cobrancas_dados();
  select array_agg(distinct lower(e->>'email')) into para
    from shared_state s, jsonb_array_elements(s.team) e
   where s.id = 1 and public.bsp_recebe_emails(e)
     and ((e->>'id') = 'u1' or public.bsp_area_chave(e->>'dept') in ('financeiro', 'financas') or public.bsp_membro_e_socio(e));
  if para is null then return jsonb_build_object('estado', 'sem destinatários'); end if;

  if d->'ontem' is not null and d->'ontem' <> 'null'::jsonb then
    dif := '<p style="margin:0 0 14px">Desde ' || to_char((d->'ontem'->>'dia')::date, 'DD/MM') || ': por receber '
      || case when (d->>'total')::numeric >= (d->'ontem'->>'total')::numeric then 'subiu ' else 'desceu ' end
      || bsp_kz(abs((d->>'total')::numeric - (d->'ontem'->>'total')::numeric)) || '; vencido '
      || case when (d->>'vencido')::numeric >= (d->'ontem'->>'vencido')::numeric then 'subiu ' else 'desceu ' end
      || bsp_kz(abs((d->>'vencido')::numeric - (d->'ontem'->>'vencido')::numeric)) || '.</p>';
  end if;
  acerto := (d->'acerto'->>'acertado_em')::timestamptz;
  if acerto is null or acerto < now() - interval '26 hours' then
    aviso := '<p style="margin:0 0 14px;padding:10px 12px;background:#FDECEC;border-left:4px solid #B42318">O acerto com o MetaGest não correu nas últimas 24 horas. Facturas pagas recentemente podem ainda aparecer aqui.</p>';
  end if;

  select string_agg('<tr><td style="padding:6px 8px 6px 0;border-bottom:1px solid #DDDBD6">' || bsp_html(x->>'faixa') || '</td>'
      || '<td style="padding:6px 8px;border-bottom:1px solid #DDDBD6;text-align:right">' || bsp_num((x->>'facturas')::numeric) || '</td>'
      || '<td style="padding:6px 0 6px 8px;border-bottom:1px solid #DDDBD6;text-align:right;white-space:nowrap"><b>' || bsp_kz((x->>'valor')::numeric) || '</b></td></tr>', '')
    into idades from jsonb_array_elements(d->'idades') x;
  select string_agg('<tr><td style="padding:6px 8px 6px 0;border-bottom:1px solid #DDDBD6">' || bsp_html(x->>'devedor')
      || '<div style="font-size:12px;color:#4E5366">' || bsp_html(x->>'tipo') || ' · ' || bsp_num((x->>'facturas')::numeric) || ' facturas · desde ' || to_char((x->>'mais_antiga')::date, 'DD/MM/YYYY') || '</div></td>'
      || '<td style="padding:6px 8px;border-bottom:1px solid #DDDBD6;text-align:right;white-space:nowrap">' || bsp_kz((x->>'vencido')::numeric) || '</td>'
      || '<td style="padding:6px 0 6px 8px;border-bottom:1px solid #DDDBD6;text-align:right;white-space:nowrap"><b>' || bsp_kz((x->>'valor')::numeric) || '</b></td></tr>', '')
    into linhas from jsonb_array_elements(d->'devedores') x;
  select string_agg(bsp_html(x->>'devedor') || ': ' || bsp_kz((x->>'valor')::numeric) || ' (' || (x->>'facturas') || ')', '<br>')
    into novas from jsonb_array_elements(d->'novas_7d') x;

  corpo := aviso
    || '<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 14px"><tr>'
    || '<td style="padding:10px;background:#F5F4F2;text-align:center"><div style="font-size:20px;font-weight:bold">' || bsp_kz((d->>'total')::numeric) || '</div><div style="font-size:12px">por receber (' || bsp_num((d->>'facturas')::numeric) || ' facturas)</div></td><td style="width:8px"></td>'
    || '<td style="padding:10px;background:#FDECEC;text-align:center"><div style="font-size:20px;font-weight:bold;color:#B42318">' || bsp_kz((d->>'vencido')::numeric) || '</div><div style="font-size:12px">vencido</div></td><td style="width:8px"></td>'
    || '<td style="padding:10px;background:#E8F5EE;text-align:center"><div style="font-size:20px;font-weight:bold;color:#06713F">' || bsp_kz((d->>'a_vencer')::numeric) || '</div><div style="font-size:12px">ainda no prazo</div></td></tr></table>'
    || dif
    || '<p style="margin:0 0 4px"><b>Antiguidade (dias depois do vencimento)</b></p>'
    || '<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 16px;font-size:14px">' || coalesce(idades, '') || '</table>'
    || '<p style="margin:0 0 4px"><b>Quem deve mais</b></p>'
    || '<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 16px;font-size:14px">'
    || '<tr><td style="padding:0 8px 4px 0;font-size:12px;color:#4E5366"></td><td style="padding:0 8px 4px;font-size:12px;color:#4E5366;text-align:right">Vencido</td><td style="padding:0 0 4px 8px;font-size:12px;color:#4E5366;text-align:right">Total</td></tr>'
    || coalesce(linhas, '') || '</table>'
    || case when novas is not null then '<p style="margin:0 0 4px"><b>Facturado a crédito nos últimos 7 dias</b></p><p style="margin:0 0 16px">' || novas || '</p>' else '' end
    || '<p style="margin:0 0 12px">Os utentes contam em conjunto, sem nomes. Detalhe no Workspace: Painel → Por receber.</p>'
    || '<p style="margin:0;font-size:12.5px;color:#4E5366">Valores do MetaGest, acertados a '
    || coalesce(to_char(acerto at time zone 'Africa/Luanda', 'DD/MM/YYYY "às" HH24:MI'), '—') || '. Restos abaixo de 50 Kz não contam.</p>';
  html := bsp_envelope('Facturas por receber', corpo, 'E-mail automático do sistema do Centro Médico Barispol.');

  if p_enviar then
    insert into erp.cobrancas_dia (dia, total, vencido, facturas)
    values ((d->>'hoje')::date, (d->>'total')::numeric, (d->>'vencido')::numeric, (d->>'facturas')::int)
    on conflict (dia) do update set total = excluded.total, vencido = excluded.vencido, facturas = excluded.facturas;
    perform bsp_enviar_email(para, '{}', '{}',
      'Por receber: ' || bsp_kz((d->>'total')::numeric) || ' (' || bsp_kz((d->>'vencido')::numeric) || ' vencidos)', html);
  end if;
  return jsonb_build_object('estado', case when p_enviar then 'enviado' else 'simulação' end, 'para', to_jsonb(para),
    'total', d->'total', 'vencido', d->'vencido', 'html', case when p_enviar then null else html end);
end $function$;
revoke all on function public.bsp_cobrancas_email(boolean) from public, anon, authenticated;

-- Acerto às 05h50 e às 13h50 (hora de Luanda = UTC+1). Sem e-mail agendado.
select cron.unschedule(jobname) from cron.job where jobname in ('bsp-cobrancas-acerto', 'bsp-cobrancas');
select cron.schedule('bsp-cobrancas-acerto', '50 4,12 * * *', $$set statement_timeout to '8min'; select erp.reconciliar_cobrancas();$$);

insert into public.novidades (titulo, texto, grupos, destino)
values ('Facturas por receber', 'Novo no Painel: «Por receber», com o que falta cobrar, o vencido e quem deve mais.', array['u1'], 'painel');

notify pgrst, 'reload schema';
