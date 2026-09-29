-- Barispol Workspace · pedidos do WhatsApp no CRM (crm.pedidos)
-- Correcção pedida pelo Elmar, 29-09-2026: «no WhatsApp tem dados
-- irreais, não facturamos com ortopedia e tem valores, facturamos com
-- ecografia e está vazio». Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- O que estava mal:
--   · a regra de Ortopedia procurava «osso», que está dentro de «posso»:
--     todas as pessoas vindas de anúncios («Posso saber mais
--     informações?») caíam em Ortopedia (599 de 716);
--   · o texto do anúncio (referral) não contava; os anúncios de ecografia
--     ficavam sem serviço;
--   · o valor de cada pedido era tudo o que a pessoa pagou nos 30 dias
--     seguintes, fosse o que fosse.
-- Agora:
--   · o serviço sai das mensagens do doente (crm.servico_do_texto, com
--     palavras inteiras \m ... \M) e, quando o doente não diz, do anúncio
--     (crm.servico_do_anuncio, sem a morada);
--   · «Compareceu» = primeira factura nos 30 dias; o valor do pedido é o
--     que a pessoa pagou nesses 30 dias (como antes);
--   · nos Resultados (crm_resultados) cada factura conta uma só vez
--     (crm.pedidos_facturas) e o facturado divide-se pelo serviço de cada
--     acto (crm.servico_do_item): quem pediu «uma marcação» e fez uma
--     ecografia conta na Ecografia.
-- Nenhum nome nem telefone entra no repositório.

create or replace function crm.servico_do_texto(t text)
returns text
language sql
immutable
as $function$
  select case
    when t is null or btrim(t) = '' then 'Não identificado'
    when t ~* 'ecograf|ultrass|morfol[oó]gica|doppler|\meco\M' then 'Ecografia'
    when t ~* 'gineco|obstet|pr[eé].?natal|gr[aá]vida|gesta[cç]|gravidez' then 'Ginecologia e Obstetrícia'
    when t ~* 'pediatr|\mcrian[cç]as?\M|\mbeb[eé]s?\M|\mfilh[oa]s?\M' then 'Pediatria'
    when t ~* '\man[aá]lises?\M|exames? de sangue|hemograma|gota espessa|\murina\M|laborat|\mdsts?\M|\mists?\M|sa[uú]de [ií]ntima|\mhiv\M|s[ií]filis' then 'Análises'
    when t ~* '\mraio|\mrx\M|radiograf' then 'Raio-X'
    when t ~* 'cardio|electrocardio|eletrocardio|\mecg\M|holter' then 'Cardiologia'
    when t ~* 'urolog|pr[oó]stat' then 'Urologia'
    when t ~* 'dermato|\mpele\M' then 'Dermatologia'
    when t ~* 'ortoped|traumat|\mossos?\M|\mcoluna\M|fractur|fratur' then 'Ortopedia'
    when t ~* 'cl[ií]nica geral|medicina geral|\mconsultas?\M' then 'Clínica Geral'
    else 'Não identificado' end
$function$;

-- Serviço de um anúncio (título + texto). A morada vem depois de «📍» e
-- tem «Bom Sossego» e «Hospital Materno Infantil»: corta-se antes de
-- classificar. Os anúncios gerais e a campanha Materno-Infantil (pediatria,
-- ginecologia e clínica geral) não dizem um serviço: devolvem null.
create or replace function crm.servico_do_anuncio(t text)
returns text
language sql
immutable
as $function$
  select case
    when a ~* 'ecograf' then 'Ecografia'
    when a ~* '\mdsts?\M|sa[uú]de [ií]ntima' then 'Análises'
    when a ~* 'materno.?infantil' then null
    when a ~* 'pediatr' then 'Pediatria'
    when a ~* 'gineco|obstet' then 'Ginecologia e Obstetrícia'
    else null end
  from (select regexp_replace(coalesce(t, ''), '📍.*$', '', 's') as a) x
$function$;

-- Serviço de uma linha de factura do MetaGest (grupo + nome do acto).
create or replace function crm.servico_do_item(grupo text, nome text)
returns text
language sql
immutable
as $function$
  select case
    when coalesce(grupo, '') ~* 'ECOGRAF' or coalesce(nome, '') ~* 'ecograf' then 'Ecografia'
    when coalesce(grupo, '') ~* 'LABORAT' then 'Análises'
    when coalesce(grupo, '') ~* 'RAIO' or coalesce(nome, '') ~* '^rx\M' then 'Raio-X'
    when coalesce(grupo, '') ~* 'CARDIO' or coalesce(nome, '') ~* 'cardio|\mecg\M|electrocard|holter' then 'Cardiologia'
    when coalesce(grupo, '') ~* 'ORTOPED' or coalesce(nome, '') ~* 'ortoped' then 'Ortopedia'
    when coalesce(nome, '') ~* 'gineco|obstet' then 'Ginecologia e Obstetrícia'
    when coalesce(nome, '') ~* 'pediat' then 'Pediatria'
    when coalesce(nome, '') ~* 'urolog' then 'Urologia'
    when coalesce(nome, '') ~* 'dermat' then 'Dermatologia'
    when coalesce(nome, '') ~* 'cl[ií]nica geral|medicina (geral|familiar)|n[aã]o especialista' then 'Clínica Geral'
    when coalesce(grupo, '') ~* 'FARM' then 'Farmácia'
    when coalesce(grupo, '') ~* 'ENFERM' then 'Enfermagem'
    when coalesce(grupo, '') ~* 'URG' then 'Banco de urgência'
    when coalesce(grupo, '') ~* 'CONSULTA' then 'Outras consultas'
    else 'Outros' end
$function$;

create table if not exists crm.pedidos_facturas (
  pedido_id text not null,
  factura text not null,
  primary key (pedido_id, factura)
);
create index if not exists pedidos_facturas_factura on crm.pedidos_facturas (factura);

create or replace function crm.gerar_pedidos()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare n int;
begin
  create temp table _m on commit drop as
  select m.contacto_id, m.criado_em, m.direccao, m.tipo, m.autor, m.texto,
         case when m.direccao = 1 then nullif(btrim(concat_ws(' ', m.raw->'data'->'referral'->>'headline', m.raw->'data'->'referral'->>'body')), '') end as anuncio,
         case when m.direccao = 1 and (lag(m.criado_em) over w is null or m.criado_em - lag(m.criado_em) over w > interval '12 hours') then 1 else 0 end as novo
  from whatsapp.mensagens m window w as (partition by m.contacto_id order by m.criado_em);
  create temp table _s on commit drop as
  select *, sum(novo) over (partition by contacto_id order by criado_em rows unbounded preceding) as sessao from _m;
  create temp table _p on commit drop as
  select s.contacto_id, s.sessao,
    min(s.criado_em) filter (where s.direccao = 1) as inicio, max(s.criado_em) as fim,
    (array_agg(s.texto order by s.criado_em) filter (where s.direccao = 1 and s.texto is not null))[1] as primeira,
    (array_agg(s.texto order by s.criado_em desc) filter (where s.direccao = 1 and s.texto is not null))[1] as ultima,
    (array_agg(s.anuncio order by s.criado_em) filter (where s.anuncio is not null))[1] as anuncio,
    count(*) filter (where s.direccao = 1) as md, count(*) filter (where s.direccao = 2) as mc,
    min(s.criado_em) filter (where s.direccao = 2 and s.autor is null and s.tipo not in ('operator_note','template')) as bot,
    min(s.criado_em) filter (where s.direccao = 2 and s.autor is not null) as hum,
    (array_agg(s.autor order by s.criado_em) filter (where s.direccao = 2 and s.autor is not null and s.tipo <> 'operator_note'))[1] as resp,
    string_agg(s.texto, ' ' order by s.criado_em) filter (where s.direccao = 1) as txt_doente,
    string_agg(s.texto, ' ' order by s.criado_em) filter (where s.direccao = 2) as txt_clinica
  from _s s where s.sessao > 0 group by s.contacto_id, s.sessao;

  delete from crm.pedidos;
  insert into crm.pedidos (id, contacto_id, telefone, tel9, nome_whatsapp, paciente_id, paciente_nome, inicio, fim, origem, servico, categoria,
     primeira_mensagem, ultima_mensagem_doente, msgs_doente, msgs_clinica, resposta_bot_min, resposta_humana_min, responsavel,
     pediu_preco, preco_dado, marcado_na_conversa, compareceu_em, valor_facturado, no_horario, estado_auto, actualizado_em)
  select q.id, q.contacto_id, q.telefone, q.tel9, q.nome, q.pac_id, q.pac_nome, q.inicio, q.fim, q.origem, q.servico, q.categoria,
    q.primeira, q.ultima, q.md, q.mc, q.bot_min, q.hum_min, q.resp, q.pediu_preco, q.preco_dado, q.marcado,
    f.data, f.total,
    q.no_horario, null, now()
  from (
    select p.contacto_id || '-' || to_char(p.inicio at time zone 'UTC', 'YYYYMMDDHH24MISS') as id,
      p.contacto_id, c.telefone, right(c.telefone, 9) as tel9, c.nome, pac.id as pac_id, pac.nome as pac_nome, p.inicio, p.fim,
      case when p.anuncio is not null or p.txt_doente ~* 'posso (saber|ter) mais informa' then 'Anúncio' else 'Orgânico' end as origem,
      case when crm.servico_do_texto(p.txt_doente) not in ('Não identificado', 'Clínica Geral') then crm.servico_do_texto(p.txt_doente)
           else coalesce(crm.servico_do_anuncio(p.anuncio), crm.servico_do_texto(p.txt_doente)) end as servico,
      case
        when p.txt_doente ~* 'Presidente Jo[aã]o Louren[cç]o: Presente em Dinheiro' then 'Burla'
        when p.txt_doente ~* 'curr[ií]culo|candidatura|\mvagas?\M|est[aá]gio|emprego' then 'Candidatura'
        when p.txt_doente ~* 'parceria|proposta comercial|fornec|nossos servi[cç]os|apresenta[cç][aã]o da empresa' then 'Fornecedor'
        else 'Doente' end as categoria,
      left(p.primeira, 500) as primeira, left(p.ultima, 500) as ultima, p.md, p.mc,
      round(extract(epoch from p.bot - p.inicio)/60, 1) as bot_min, round(extract(epoch from p.hum - p.inicio)/60, 1) as hum_min, p.resp,
      coalesce(p.txt_doente ~* 'pre[cç]o|quanto (é|custa|fica)|custa|valor', false) as pediu_preco,
      coalesce(p.txt_clinica ~* '\d{1,3}[\.,]\d{3}', false) as preco_dado,
      coalesce(p.txt_clinica ~* 'confirmo a marca|marca[cç][aã]o (foi )?(feita|confirmada)|foi marcad|consulta (foi )?marcada|tem uma (consulta|marca)|agendad[ao] para', false) as marcado,
      ((p.inicio at time zone 'Africa/Luanda')::time between '07:30' and '22:00') as no_horario
    from _p p
    join whatsapp.contactos c on c.id = p.contacto_id
    left join lateral (select id, nome from crm.mg_pacientes x where x.tel9 = right(c.telefone, 9) order by criado_em desc limit 1) pac on true
    where p.inicio is not null
  ) q
  left join lateral (
     select min(fa.data) as data, sum(fa.total) as total
       from crm.mg_facturas fa
      where (fa.tel9 = q.tel9 or fa.paciente in (select id from crm.mg_pacientes y where y.tel9 = q.tel9))
        and fa.total > 0
        and fa.data between (q.inicio at time zone 'Africa/Luanda')::date and (q.inicio at time zone 'Africa/Luanda')::date + 30) f on true;

  -- Facturas de cada pedido (para somar cada factura uma só vez).
  delete from crm.pedidos_facturas;
  insert into crm.pedidos_facturas (pedido_id, factura)
  select distinct p.id, fa.id
    from crm.pedidos p
    join crm.mg_facturas fa
      on (fa.tel9 = p.tel9 or fa.paciente in (select id from crm.mg_pacientes y where y.tel9 = p.tel9))
     and fa.total > 0
     and fa.data between (p.inicio at time zone 'Africa/Luanda')::date and (p.inicio at time zone 'Africa/Luanda')::date + 30
   where p.compareceu_em is not null;

  update crm.pedidos set estado_auto = case
     when categoria <> 'Doente' then 'Não é doente'
     when compareceu_em is not null then 'Compareceu'
     when marcado_na_conversa then 'Marcado'
     when resposta_humana_min is not null then 'Em contacto'
     when inicio < now() - interval '7 days' then 'Perdido'
     else 'Novo' end;
  get diagnostics n = row_count;
  return jsonb_build_object('pedidos', n);
end $function$;
revoke all on function crm.gerar_pedidos() from public, anon, authenticated;

-- Resultados do CRM (ecrã CRM → Resultados). Cada factura conta uma só
-- vez, mesmo que a pessoa tenha escrito várias vezes. «por_acto» divide o
-- facturado pelo serviço de cada linha da factura.
create or replace function public.crm_resultados(p_dias integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare desde timestamptz := now() - make_interval(days => greatest(1, least(coalesce(p_dias, 30), 400)));
begin
  if not crm.pode_ver_crm() then raise exception 'Sem acesso ao CRM.'; end if;
  return (
    with cx as (select * from crm.caixa where inicio >= desde),
    fx as (select distinct cx.origem, cx.servico, pf.factura
             from cx join crm.pedidos_facturas pf on pf.pedido_id = cx.id),
    fu as (select distinct factura from fx)
    select jsonb_build_object(
      'total', (select jsonb_build_object(
          'pedidos', count(*),
          'respondidos', count(*) filter (where resposta_humana_min is not null),
          'em_15_min', count(*) filter (where resposta_humana_min <= 15),
          'marcados', count(*) filter (where estado in ('Marcado','Compareceu') or marcado_na_conversa),
          'compareceram', count(*) filter (where compareceu_em is not null or estado = 'Compareceu'),
          'valor', (select coalesce(sum(fa.total), 0) from fu join crm.mg_facturas fa on fa.id = fu.factura))
        from cx),
      'por_origem', (select coalesce(jsonb_agg(x order by x->>'origem'), '[]'::jsonb) from (
          select jsonb_build_object('origem', o.origem, 'pedidos', count(*),
            'respondidos', count(*) filter (where resposta_humana_min is not null),
            'marcados', count(*) filter (where estado in ('Marcado','Compareceu') or marcado_na_conversa),
            'compareceram', count(*) filter (where compareceu_em is not null or estado = 'Compareceu'),
            'valor', (select coalesce(sum(fa.total), 0) from (select distinct factura from fx where fx.origem = o.origem) d
                        join crm.mg_facturas fa on fa.id = d.factura)) x
          from cx o group by o.origem) o),
      'por_servico', (select coalesce(jsonb_agg(x order by (x->>'pedidos')::int desc), '[]'::jsonb) from (
          select jsonb_build_object('servico', s.servico, 'pedidos', count(*),
            'compareceram', count(*) filter (where compareceu_em is not null or estado = 'Compareceu'),
            'valor', (select coalesce(sum(fa.total), 0) from (select distinct factura from fx where fx.servico = s.servico) d
                        join crm.mg_facturas fa on fa.id = d.factura)) x
          from cx s group by s.servico) s),
      'por_acto', (select coalesce(jsonb_agg(x order by (x->>'valor')::numeric desc), '[]'::jsonb) from (
          select jsonb_build_object('servico', crm.servico_do_item(i.grupo, i.item_nome), 'actos', count(*),
            'pessoas', count(distinct coalesce(fa.paciente, fa.tel9)), 'valor', coalesce(sum(i.valor), 0)) x
          from fu join crm.mg_facturas fa on fa.id = fu.factura join crm.mg_factura_itens i on i.factura = fa.id
          group by crm.servico_do_item(i.grupo, i.item_nome)) a)));
end $function$;
revoke all on function public.crm_resultados(integer) from public, anon;
grant execute on function public.crm_resultados(integer) to authenticated;
