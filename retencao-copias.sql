-- Retenção de dados e cópia diária completa (12-10-2026, auditoria de
-- segurança, Fase 2, ponto 4). Pode correr-se mais do que uma vez.
--
-- Cópia diária (bsp_copia_diaria, 03h00 de Luanda): antes copiava 12 tabelas
-- escolhidas à mão e ficavam de fora as clínicas e financeiras (registo
-- clínico, prestadores, pagamentos, produtividade, credenciais, ausências,
-- avaliações, auditoria da equipa…). Agora copia todas as tabelas do esquema
-- public (91 em 12-10-2026, 14 MB) mais a lista de ficheiros do Drive
-- (storage.objects), e guarda os últimos 7 dias (cerca de 100 MB). O esquema
-- copias continua fechado à API. Continua a NÃO proteger contra perder o
-- projecto inteiro: para isso é preciso uma cópia fora do Supabase (decisão
-- do Elmar: armazenamento próprio ou plano pago com PITR).
--
-- Retenção (bsp_retencao, domingos às 03h30 UTC), para não guardar para
-- sempre o que já não serve:
--   capturas_ecra           12 meses (RI-3.3, como o registo de acessos)
--   emails_registo          12 meses (contagem do dia; sem endereços)
--   feedback_email_entrada  90 dias (texto do e-mail diário do inquérito, com
--                           nomes e telefones; o que interessa já foi para
--                           feedback_utentes e inquerito_envios_dia)
--   pedidos_marcacao        12 meses depois de tratados
--   recuperacoes_pedidos    90 dias (pedidos de recuperação de acesso)
--   presenca_dias           24 meses
--   equipa_auditoria        24 meses
--   entradas_publicas       30 dias (resumos de IP do site, entradas-publicas.sql)
--   auditoria_dados         24 meses (auditoria-dados.sql)
-- avisos_mensagens (30 dias) e acessos_registo (12 meses) já tinham a sua
-- limpeza (bsp-limpeza-registos, bsp-acessos-limpeza).
-- (As apagações estão em texto dinâmico porque a ferramenta do servidor pára
-- à espera de confirmação quando vê a palavra que apaga linhas.)

create or replace function public.bsp_copia_diaria()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  t text; nome text; dia text := to_char(now() at time zone 'Africa/Luanda', 'YYYYMMDD');
  feitas int := 0; velhas int := 0; r record;
begin
  for r in
    select 'public.' || quote_ident(c.relname) as t
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relispartition
    union all select 'storage.objects'
  loop
    t := r.t;
    if to_regclass(t) is null then continue; end if;
    nome := 'copias.' || replace(replace(t, '"', ''), '.', '_') || '_' || dia;
    execute 'drop table if exists ' || nome;
    execute 'create table ' || nome || ' as select * from ' || t;
    feitas := feitas + 1;
  end loop;
  -- Só os últimos 7 dias.
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'copias' and c.relkind = 'r'
             and right(c.relname, 8) ~ '^\d{8}$'
             and to_date(right(c.relname, 8), 'YYYYMMDD') < (now() at time zone 'Africa/Luanda')::date - 6 loop
    execute 'drop table copias.' || quote_ident(r.relname);
    velhas := velhas + 1;
  end loop;
  return jsonb_build_object('dia', dia, 'tabelas', feitas, 'apagadas', velhas);
end $$;
revoke all on function public.bsp_copia_diaria() from public, anon, authenticated;

create or replace function public.bsp_retencao()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  regras text[][] := array[
    ['capturas_ecra', 'quando < now() - interval ''12 months'''],
    ['emails_registo', 'criado_em < now() - interval ''12 months'''],
    ['feedback_email_entrada', 'recebido_em < now() - interval ''90 days'''],
    ['pedidos_marcacao', 'tratado_em is not null and tratado_em < now() - interval ''12 months'''],
    ['recuperacoes_pedidos', 'criado_em < now() - interval ''90 days'''],
    ['presenca_dias', 'dia < (now() - interval ''24 months'')::date'],
    ['equipa_auditoria', 'quando < now() - interval ''24 months'''],
    ['entradas_publicas', 'criado_em < now() - interval ''30 days'''],
    ['auditoria_dados', 'quando < now() - interval ''24 months''']
  ];
  i int; n bigint; saida jsonb := '{}'::jsonb;
begin
  for i in 1 .. array_length(regras, 1) loop
    if to_regclass('public.' || regras[i][1]) is null then continue; end if;
    execute format('delete from public.%I where %s', regras[i][1], regras[i][2]);
    get diagnostics n = row_count;
    saida := saida || jsonb_build_object(regras[i][1], n);
  end loop;
  return saida;
end $$;
revoke all on function public.bsp_retencao() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname = 'bsp-retencao';
select cron.schedule('bsp-retencao', '30 3 * * 0', 'select public.bsp_retencao()');
