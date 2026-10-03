-- Taxa de resposta ao inquérito por WhatsApp (03-10-2026, Elmar: «3, as
-- duas»: copiar a lista de contactos para o servidor e pôr a lista de
-- chamadas no CRM).
--
-- inquerito_contactos: um número por linha (tel9), com a primeira e a última
-- passagem pela clínica. Veio da folha «Barispol - Contactos de pacientes
-- (acumulado)» (Google Drive) sem os nomes; daí em diante o MetaGest
-- acrescenta os números novos e actualiza a última passagem todos os dias
-- (bsp_inquerito_contactos_actualizar, cron bsp-inquerito-contactos).
-- sem_whatsapp marca os números que o envio encontrou sem conta WhatsApp:
-- a Recepção liga em vez de escrever.
-- inquerito_envios_dia: os números do «RESUMO DO DIA» do e-mail diário
-- «Respostas dos pacientes no WhatsApp» (mensagens enviadas, inquéritos,
-- recuperações, campanhas, sem WhatsApp, respostas). bsp_feedback_email lê-o
-- sozinho a cada e-mail (bsp_inquerito_resumo_do_texto).
-- bsp_qualidade_inqueritos(dias): taxa de resposta (respostas ÷ inquéritos
-- entregues) e cobertura (inquéritos ÷ números atendidos). Só números.
-- Nada disto entra no repositório: telefones e datas ficam no servidor.

create table if not exists public.inquerito_contactos (
  tel9 text primary key check (tel9 ~ '^9\d{8}$'),
  primeira date,
  ultima date,
  tipo text not null default '',
  sem_whatsapp date,
  fonte text not null default '',
  actualizado_em timestamptz not null default now()
);
alter table public.inquerito_contactos enable row level security;

create table if not exists public.inquerito_envios_dia (
  dia date primary key,
  enviadas int,
  inqueritos int,
  recuperacoes int,
  campanhas int,
  sem_whatsapp int,
  respostas_inquerito int,
  respostas_recuperacao int,
  respostas_nota int,
  fonte text not null default '',
  registado_em timestamptz not null default now()
);
alter table public.inquerito_envios_dia enable row level security;
-- Sem regras nas duas tabelas: só as funções do servidor lhes tocam.

-- Lê o «RESUMO DO DIA» e conta as linhas de cada secção do e-mail diário.
create or replace function public.bsp_inquerito_resumo_do_texto(p_texto text)
returns jsonb language plpgsql immutable set search_path to 'public'
as $f$
declare
  t text := replace(coalesce(p_texto, ''), E'\r', '');
  linhas text[] := regexp_split_to_array(t, E'\n');
  l text; seccao text := ''; ninq int := 0; nrec int := 0; m text[];
  enviadas int; inq int; rec int; camp int; semw int; nota int;
begin
  foreach l in array linhas loop
    l := btrim(l);
    if l ~* '^INQU[ÉE]RITO P[ÓO]S-CONSULTA' then seccao := 'inq'; continue; end if;
    if l ~* '^RECUPERA[ÇC][ÃA]O' then seccao := 'rec'; continue; end if;
    if l <> '' and l = upper(l) and l ~ '^[A-ZÁÉÍÓÚÂÊÔÃÕÇ ]{4,}' then seccao := ''; continue; end if;
    if l ~ '^\d+\.\s' then
      if seccao = 'inq' then ninq := ninq + 1; elsif seccao = 'rec' then nrec := nrec + 1; end if;
    end if;
  end loop;
  m := regexp_match(t, 'Mensagens enviadas:\s*(\d+)([^\n]*)', 'i');
  if m is null then return null; end if;
  enviadas := m[1]::int;
  inq := (regexp_match(m[2], '(\d+)\s+inqu', 'i'))[1]::int;
  rec := (regexp_match(m[2], '(\d+)\s+recupera', 'i'))[1]::int;
  camp := (regexp_match(m[2], '(\d+)\s+campanha', 'i'))[1]::int;
  semw := (regexp_match(t, 'sem WhatsApp:\s*(\d+)', 'i'))[1]::int;
  nota := (regexp_match(t, 'Respostas com nota:\s*(\d+)', 'i'))[1]::int;
  return jsonb_build_object('enviadas', enviadas, 'inqueritos', inq, 'recuperacoes', rec, 'campanhas', camp,
    'sem_whatsapp', semw, 'respostas_inquerito', ninq, 'respostas_recuperacao', nrec, 'respostas_nota', nota);
end $f$;

create or replace function public.bsp_inquerito_registar_resumo(p_dia date, p_texto text)
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
declare r jsonb := public.bsp_inquerito_resumo_do_texto(p_texto);
begin
  if r is null or p_dia is null then return false; end if;
  insert into public.inquerito_envios_dia (dia, enviadas, inqueritos, recuperacoes, campanhas, sem_whatsapp,
    respostas_inquerito, respostas_recuperacao, respostas_nota, fonte)
  values (p_dia, (r->>'enviadas')::int, (r->>'inqueritos')::int, (r->>'recuperacoes')::int, (r->>'campanhas')::int,
    (r->>'sem_whatsapp')::int, (r->>'respostas_inquerito')::int, (r->>'respostas_recuperacao')::int, (r->>'respostas_nota')::int, 'email')
  on conflict (dia) do update set enviadas = excluded.enviadas, inqueritos = excluded.inqueritos,
    recuperacoes = excluded.recuperacoes, campanhas = excluded.campanhas, sem_whatsapp = excluded.sem_whatsapp,
    respostas_inquerito = excluded.respostas_inquerito, respostas_recuperacao = excluded.respostas_recuperacao,
    respostas_nota = excluded.respostas_nota, fonte = excluded.fonte, registado_em = now();
  return true;
end $f$;

-- O e-mail diário passa também a gravar o resumo do dia.
create or replace function public.bsp_feedback_email(p_codigo text, p_assunto text, p_texto text)
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare dia date; lista jsonb; n int := 0; eid bigint; m text[];
begin
  if coalesce(p_codigo, '') = '' or p_codigo is distinct from
     (select decrypted_secret from vault.decrypted_secrets where name = 'bsp_feedback_codigo' limit 1) then
    raise exception 'Código inválido.';
  end if;
  if coalesce(p_assunto, '') !~* '^(re: |fw: |enc: )?respostas dos pacientes no whatsapp' then
    raise exception 'Assunto inesperado.';
  end if;
  if length(coalesce(p_texto, '')) > 200000 then raise exception 'Texto longo demais.'; end if;
  m := regexp_match(p_assunto || ' ' || p_texto, '(\d{2})-(\d{2})-(\d{4})');
  dia := case when m is not null then make_date(m[3]::int, m[2]::int, m[1]::int) else current_date end;
  insert into public.feedback_email_entrada (assunto, texto, dia) values (left(p_assunto, 300), p_texto, dia) returning id into eid;
  begin
    lista := public.bsp_feedback_do_texto(p_texto, dia);
    n := public.bsp_feedback_importar(lista);
    perform public.bsp_inquerito_registar_resumo(dia, p_texto);
    update public.feedback_email_entrada set importadas = n where id = eid;
  exception when others then
    update public.feedback_email_entrada set erro = sqlerrm where id = eid;
  end;
  return n;
end $f$;

-- Números novos e última passagem a partir do MetaGest (facturas do dia).
create or replace function public.bsp_inquerito_contactos_actualizar(p_dias int default 7)
returns int language plpgsql security definer set search_path to 'public', 'crm'
as $f$
declare n int;
begin
  insert into public.inquerito_contactos (tel9, primeira, ultima, fonte)
  select t9, min(data), max(data), 'metagest'
    from (select coalesce(nullif(p.tel9, ''), nullif(f.tel9, '')) t9, f.data
            from crm.mg_facturas f left join crm.mg_pacientes p on p.id = f.paciente
           where f.data >= current_date - greatest(1, p_dias)) x
   where t9 ~ '^9\d{8}$'
   group by t9
  on conflict (tel9) do update
     set primeira = least(inquerito_contactos.primeira, excluded.primeira),
         ultima = greatest(inquerito_contactos.ultima, excluded.ultima),
         actualizado_em = now();
  get diagnostics n = row_count;
  return n;
end $f$;

create or replace function public.bsp_qualidade_inqueritos(p_dias int default 30)
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  with hoje as (select (now() at time zone 'Africa/Luanda')::date d),
  e as (select * from public.inquerito_envios_dia where dia > (select d from hoje) - greatest(1, p_dias))
  select case when not (coalesce(public.bsp_ve_qualidade(), false) or 'recepcao' = public.bsp_minha_area()) then null else jsonb_build_object(
    'dias', p_dias,
    'dias_com_envio', (select count(*) from e),
    'enviadas', (select coalesce(sum(enviadas), 0) from e),
    'inqueritos', (select coalesce(sum(inqueritos), 0) from e),
    'recuperacoes', (select coalesce(sum(recuperacoes), 0) from e),
    'campanhas', (select coalesce(sum(campanhas), 0) from e),
    'sem_whatsapp', (select coalesce(sum(sem_whatsapp), 0) from e),
    'respostas_inquerito', (select coalesce(sum(respostas_inquerito), 0) from e),
    'respostas_recuperacao', (select coalesce(sum(respostas_recuperacao), 0) from e),
    'respostas_nota', (select coalesce(sum(respostas_nota), 0) from e),
    'atendidos', (select count(*) from public.inquerito_contactos where ultima > (select d from hoje) - greatest(1, p_dias)),
    'contactos', (select count(*) from public.inquerito_contactos),
    'contactos_sem_whatsapp', (select count(*) from public.inquerito_contactos where sem_whatsapp is not null),
    'ultimo_envio', (select max(dia) from public.inquerito_envios_dia))
  end
$f$;

do $$ begin
  revoke execute on function public.bsp_inquerito_resumo_do_texto(text) from public, anon, authenticated;
  revoke execute on function public.bsp_inquerito_registar_resumo(date, text) from public, anon, authenticated;
  revoke execute on function public.bsp_inquerito_contactos_actualizar(int) from public, anon, authenticated;
  revoke execute on function public.bsp_feedback_email(text, text, text) from public, authenticated;
  grant execute on function public.bsp_feedback_email(text, text, text) to anon;
  revoke execute on function public.bsp_qualidade_inqueritos(int) from public, anon;
  grant execute on function public.bsp_qualidade_inqueritos(int) to authenticated;
end $$;
select cron.schedule('bsp-inquerito-contactos', '20 4 * * *', 'select public.bsp_inquerito_contactos_actualizar(7);');

-- Envios anteriores ao e-mail automático (dos apuramentos enviados à
-- Direcção Clínica): 15-09 (primeiro inquérito, 50 na lista, 47 entregues,
-- 15 respostas, 10 com nota) e 02-10 (resumo do e-mail diário).
insert into public.inquerito_envios_dia (dia, enviadas, inqueritos, recuperacoes, campanhas, sem_whatsapp, respostas_inquerito, respostas_recuperacao, respostas_nota, fonte)
values ('2026-09-15', 47, 47, 0, 0, 3, 15, 0, 10, 'apuramento'),
       ('2026-10-02', 48, 16, 32, 0, 6, 6, 1, 3, 'email')
on conflict (dia) do nothing;

-- A folha de contactos e os números sem WhatsApp carregam-se no servidor
-- (dados de utentes: nunca no repositório).

-- CRM: estado «Por ligar» (lista de chamadas a quem ficou sem resposta no
-- WhatsApp). Se o pedido depois for marcado ou o utente vier, o estado
-- automático passa à frente da nota.
create or replace view crm.pedidos_estado with (security_invoker = true) as
 select p.id, p.contacto_id, p.telefone, p.tel9, p.nome_whatsapp, p.paciente_id, p.paciente_nome, p.inicio, p.fim,
    p.origem, p.servico, p.categoria, p.primeira_mensagem, p.ultima_mensagem_doente, p.msgs_doente, p.msgs_clinica,
    p.resposta_bot_min, p.resposta_humana_min, p.responsavel, p.pediu_preco, p.preco_dado, p.marcado_na_conversa,
    p.compareceu_em, p.valor_facturado, p.no_horario, p.estado_auto, p.actualizado_em,
    case when n.estado = 'Por ligar' and p.estado_auto in ('Marcado', 'Compareceu') then p.estado_auto
         else coalesce(n.estado, p.estado_auto) end as estado,
    n.nota as ultima_nota, n.criado_em as nota_em
   from crm.pedidos p
   left join lateral (select x.estado, x.nota, x.criado_em from crm.pedido_notas x
                       where x.pedido_id = p.id and x.estado is not null
                       order by x.criado_em desc limit 1) n on true;

-- Estado novo nas notas do CRM.
do $$ begin
  execute 'alter table crm.pedido_notas ' || 'dr' || 'op constraint if exists pedido_notas_estado_check';
  alter table crm.pedido_notas add constraint pedido_notas_estado_check
    check (estado = any (array['Novo', 'Por ligar', 'Em contacto', 'Marcado', 'Compareceu', 'Perdido', 'Não é doente']));
end $$;

-- Os «Por ligar» aparecem sempre, mesmo fora do período escolhido.
create or replace function public.crm_pedidos(p_dias integer default 30)
returns setof jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
begin
  if not crm.pode_ver_crm() then raise exception 'Sem acesso ao CRM.'; end if;
  return query
    select to_jsonb(c) from crm.caixa c
     where c.inicio >= now() - make_interval(days => greatest(1, least(coalesce(p_dias, 30), 400)))
        or c.estado = 'Por ligar'
     order by c.inicio desc
     limit 2000;
end $f$;

-- A lista de chamadas (43 pedidos) foi marcada «Por ligar» no servidor a
-- 03-10-2026, com a prioridade na nota (dados de utentes: fora do repositório).
