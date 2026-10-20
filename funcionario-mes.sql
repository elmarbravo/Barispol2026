-- Funcionário do Mês (20-10-2026, pedido da Arlete; Elmar: «Votação: dias 17 e
-- 18 de cada mês; apuramento e divulgação dos resultados: dia 23 de cada mês»).
-- Regulamento «Programa Funcionário do Mês — eleição por pares» (aprovado pelo
-- Elmar) e o formulário em papel passam para o Workspace: Equipa → «Funcionário
-- do mês». O calendário do Elmar substitui o do regulamento (17 a 25, apuramento
-- no 1.º dia útil e anúncio até ao dia 5).
--
-- Regras (regulamento, pontos 2 a 7):
-- - vota e é nomeado quem tem 120 dias de vínculo e não tem processo
--   disciplinar em curso; um voto por mês; ninguém vota em si próprio;
-- - cinco critérios de 1 a 5, 20% cada (a média dos cinco é a nota do voto);
--   média final por candidato; vence a maior média;
-- - empate: maior média em «Atitude e Espírito de Equipa»; se persistir, a
--   Direcção decide (bsp_fm_decidir);
-- - o vencedor de um mês não pode ser eleito no mês seguinte;
-- - votos confidenciais: só o apurador (Elmar u1 e Arlete u2, Direcção e
--   responsável operacional) vê quem votou em quem (bsp_fm_votos).
-- Vínculo: fm_pessoas.admissao (os apuradores corrigem no ecrã); sem ela, a data
-- de criação da conta (ids «u<milissegundos>»); sem nenhuma, conta como antigo.
-- Processo disciplinar: fm_pessoas.impedido_ate, sem motivo escrito.
-- Fora da votação: sócios, ocultos, desactivados, a conta de teste (semEmails) e
-- os apuradores como nomeados (votam, mas não são nomeados).
-- Directores fora dos nomeados (Elmar, 20-10-2026: «Estão fora da lista de
-- nomeados os directores»): cargo «Director…» ou camada Direcção; votam.
-- Prémio (Elmar, 20-10-2026): valor em dinheiro e certificado de reconhecimento.
-- O texto do prémio fica só no servidor (fm_config, chave 'premio'), nunca no
-- repositório; ao eleger, a gestão (u1, u2) recebe o aviso para o pagar.
-- Votos em papel: o apurador regista-os em nome de quem votou até ao apuramento.
-- Horas de Luanda. Crons: abertura dia 17 às 07h00, lembrete dia 18 às 12h00,
-- apuramento e divulgação dia 23 às 08h00 (Feed, sino e telemóvel).
-- Nas funções pela ferramenta, nunca as palavras que pedem confirmação.

create table if not exists public.fm_votos (
  id bigint generated always as identity primary key,
  mes date not null,
  votante text not null,
  nomeado text not null,
  assiduidade smallint not null check (assiduidade between 1 and 5),
  atitude smallint not null check (atitude between 1 and 5),
  qualidade smallint not null check (qualidade between 1 and 5),
  compromisso smallint not null check (compromisso between 1 and 5),
  relacionamento smallint not null check (relacionamento between 1 and 5),
  justificacao text,
  origem text not null default 'workspace' check (origem in ('workspace', 'papel')),
  registado_por text not null,
  criado_em timestamptz not null default now(),
  unique (mes, votante),
  check (votante <> nomeado)
);

create table if not exists public.fm_resultados (
  mes date primary key,
  estado text not null check (estado in ('eleito', 'empate', 'sem-votos')),
  vencedor text,
  votos integer not null default 0,
  votantes integer not null default 0,
  classificacao jsonb not null default '[]'::jsonb,
  apurado_em timestamptz not null default now(),
  decidido_por text,
  publicado_em timestamptz
);

create table if not exists public.fm_config (
  chave text primary key,
  valor text not null
);
alter table public.fm_config enable row level security;
revoke all on public.fm_config from anon, authenticated;

create table if not exists public.fm_pessoas (
  user_id text primary key,
  admissao date,
  impedido_ate date,
  actualizado_por text,
  actualizado_em timestamptz not null default now()
);

alter table public.fm_votos enable row level security;
alter table public.fm_resultados enable row level security;
alter table public.fm_pessoas enable row level security;
-- Sem regras de acesso: tudo passa pelas funções abaixo.
revoke all on public.fm_votos, public.fm_resultados, public.fm_pessoas from anon, authenticated;

create or replace function public.bsp_fm_apurador()
returns boolean language sql stable security definer set search_path to 'public'
as $f$ select coalesce(public.bsp_meu_id() in ('u1', 'u2'), false) $f$;

create or replace function public.bsp_fm_mes_nome(p_mes date)
returns text language sql immutable
as $f$
  select (array['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'])[extract(month from p_mes)::int]
         || ' de ' || extract(year from p_mes)::int
$f$;

-- Equipa com a elegibilidade do mês (dia 17 é a referência).
create or replace function public.bsp_fm_equipa(p_mes date)
returns table (id text, nome text, funcao text, area text, inicio date, fonte text,
               impedido_ate date, vota boolean, nomeavel boolean, motivo text)
language sql stable security definer set search_path to 'public'
as $f$
  with ref as (select (date_trunc('month', p_mes)::date + 16) dia),
  anterior as (select r.vencedor from public.fm_resultados r
                where r.mes = (date_trunc('month', p_mes) - interval '1 month')::date and r.estado = 'eleito'),
  equipa as (
    select e->>'id' id, e->>'name' nome, coalesce(e->>'role', '') funcao, coalesce(e->>'dept', '') area,
           (coalesce(e->>'role', '') ~* '^\s*director' or e->>'accessLevel' = 'Direcção') director,
           p.admissao, p.impedido_ate,
           case when (e->>'id') ~ '^u\d{13}$' then (to_timestamp(substr(e->>'id', 2)::bigint / 1000.0) at time zone 'Africa/Luanda')::date end conta
      from shared_state s cross join jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
      left join public.fm_pessoas p on p.user_id = e->>'id'
     where s.id = 1 and coalesce(e->>'id', '') <> ''
       and not public.bsp_membro_e_socio(e)
       and not coalesce((e->>'oculto')::boolean, false)
       and not coalesce((e->>'inactivo')::boolean, false)
       and not coalesce((e->>'semEmails')::boolean, false)
  ),
  x as (
    select q.*, coalesce(q.admissao, q.conta) ini,
           case when q.admissao is not null then 'admissao' when q.conta is not null then 'conta' else 'antigo' end fonte_,
           (select dia from ref) dia
      from equipa q
  )
  select x.id, x.nome, x.funcao, x.area, x.ini, x.fonte_, x.impedido_ate,
         (x.ini is null or x.ini <= x.dia - 120) and not coalesce(x.impedido_ate >= x.dia, false),
         (x.ini is null or x.ini <= x.dia - 120) and not coalesce(x.impedido_ate >= x.dia, false)
           and x.id not in ('u1', 'u2') and not x.director and x.id is distinct from (select vencedor from anterior),
         case when coalesce(x.impedido_ate >= x.dia, false) then 'Impedido até ' || to_char(x.impedido_ate, 'DD-MM-YYYY')
              when x.ini is not null and x.ini > x.dia - 120 then 'Menos de 120 dias de vínculo (desde ' || to_char(x.ini, 'DD-MM-YYYY') || ')'
              when x.id in ('u1', 'u2') then 'Apurador (vota, não é nomeado)'
              when x.director then 'Director (vota, não é nomeado)'
              when x.id = (select vencedor from anterior) then 'Eleito no mês anterior'
         end
    from x
$f$;

-- Média de cada candidato (regulamento 6.3).
create or replace function public.bsp_fm_contagem(p_mes date)
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  with v as (
    select nomeado, (assiduidade + atitude + qualidade + compromisso + relacionamento) / 5.0 nota, atitude,
           assiduidade, qualidade, compromisso, relacionamento
      from public.fm_votos
     where mes = date_trunc('month', p_mes)::date
       and nomeado not in (select r.vencedor from public.fm_resultados r
                            where r.mes = (date_trunc('month', p_mes) - interval '1 month')::date and r.estado = 'eleito' and r.vencedor is not null)
  ), c as (
    select nomeado, round(avg(nota), 2) media, round(avg(atitude), 2) atitude, count(*) votos,
           jsonb_build_object('assiduidade', round(avg(assiduidade), 2), 'atitude', round(avg(atitude), 2),
             'qualidade', round(avg(qualidade), 2), 'compromisso', round(avg(compromisso), 2),
             'relacionamento', round(avg(relacionamento), 2)) criterios
      from v group by nomeado
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', c.nomeado,
           'nome', (select e->>'name' from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = c.nomeado limit 1),
           'media', c.media, 'atitude', c.atitude, 'votos', c.votos, 'criterios', c.criterios)
         order by c.media desc, c.atitude desc, c.votos desc), '[]'::jsonb)
    from c
$f$;

-- Estado para quem abre o ecrã.
create or replace function public.bsp_fm_estado()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare
  eu text := public.bsp_meu_id();
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  v_mes date := date_trunc('month', hoje)::date;
  dia int := extract(day from hoje)::int;
  r_eu record;
  meu jsonb;
  res jsonb;
begin
  if eu is null or public.bsp_e_socio() then raise exception 'Sem acesso.'; end if;
  select * into r_eu from public.bsp_fm_equipa(v_mes) q where q.id = eu;
  select to_jsonb(v) - 'votante' - 'registado_por' - 'id' into meu from public.fm_votos v where v.mes = v_mes and v.votante = eu;
  select jsonb_build_object(
    'hoje', hoje, 'mes', v_mes, 'mes_nome', public.bsp_fm_mes_nome(v_mes),
    'fase', case when dia < 17 then 'antes' when dia <= 18 then 'votacao' when dia < 23 then 'contagem' else 'resultado' end,
    'abre', v_mes + 16, 'fecha', v_mes + 17, 'apura', v_mes + 22,
    'vota', coalesce(r_eu.vota, false), 'motivo', r_eu.motivo,
    'meu_voto', meu,
    'meu_nomeado_nome', (select q.nome from public.bsp_fm_equipa(v_mes) q where q.id = meu->>'nomeado'),
    'candidatos', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'nome', q.nome, 'funcao', q.funcao, 'area', q.area) order by q.nome)
                              from public.bsp_fm_equipa(v_mes) q where q.nomeavel and q.id <> eu), '[]'::jsonb),
    'apurador', public.bsp_fm_apurador(),
    'premio', (select valor from public.fm_config where chave = 'premio'),
    'direccao', public.bsp_e_direccao(),
    'historico', coalesce((select jsonb_agg(jsonb_build_object('mes', r.mes, 'mes_nome', public.bsp_fm_mes_nome(r.mes), 'estado', r.estado,
                              'vencedor', r.vencedor, 'publicado_em', r.publicado_em,
                              'nome', (select e->>'name' from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = r.vencedor limit 1),
                              'funcao', (select e->>'role' from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = r.vencedor limit 1))
                            order by r.mes desc)
                             from (select * from public.fm_resultados order by mes desc limit 12) r), '[]'::jsonb)
  ) into res;
  return res;
end $f$;

-- Votar (no Workspace, dias 17 e 18) ou registar um voto em papel (apurador).
create or replace function public.bsp_fm_votar(p_nomeado text, p_notas jsonb, p_justificacao text, p_declaracao boolean, p_votante text default null)
returns jsonb language plpgsql volatile security definer set search_path to 'public'
as $f$
declare
  eu text := public.bsp_meu_id();
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  v_mes date := date_trunc('month', hoje)::date;
  quem text := coalesce(nullif(btrim(p_votante), ''), eu);
  papel boolean;
  n int[];
  k text;
begin
  if eu is null or public.bsp_e_socio() then raise exception 'Sem acesso.'; end if;
  papel := quem <> eu;
  if papel then
    if not public.bsp_fm_apurador() then raise exception 'Só o apurador regista votos em papel.'; end if;
    if extract(day from hoje) < 17 then raise exception 'A votação de % ainda não abriu.', public.bsp_fm_mes_nome(v_mes); end if;
    if exists (select 1 from public.fm_resultados where mes = v_mes) then raise exception 'O mês já foi apurado.'; end if;
  elsif extract(day from hoje) not in (17, 18) then
    raise exception 'A votação decorre só nos dias 17 e 18 de cada mês.';
  end if;
  if not coalesce(p_declaracao, false) then raise exception 'Falta confirmar a declaração.'; end if;
  if not exists (select 1 from public.bsp_fm_equipa(v_mes) q where q.id = quem and q.vota) then
    raise exception 'Esta pessoa não pode votar este mês (120 dias de vínculo, sem processo disciplinar).';
  end if;
  if p_nomeado = quem then raise exception 'Ninguém pode votar em si próprio.'; end if;
  if not exists (select 1 from public.bsp_fm_equipa(v_mes) q where q.id = p_nomeado and q.nomeavel) then
    raise exception 'Esta pessoa não pode ser nomeada este mês.';
  end if;
  foreach k in array array['assiduidade', 'atitude', 'qualidade', 'compromisso', 'relacionamento'] loop
    if coalesce(p_notas->>k, '') !~ '^[1-5]$' then raise exception 'Falta a pontuação de 1 a 5 em todos os critérios.'; end if;
    n := n || (p_notas->>k)::int;
  end loop;
  begin
    insert into public.fm_votos (mes, votante, nomeado, assiduidade, atitude, qualidade, compromisso, relacionamento, justificacao, origem, registado_por)
    values (v_mes, quem, p_nomeado, n[1], n[2], n[3], n[4], n[5], nullif(btrim(left(coalesce(p_justificacao, ''), 2000)), ''),
            case when papel then 'papel' else 'workspace' end, eu);
  exception when unique_violation then
    raise exception '%', case when papel then 'Esta pessoa já votou este mês.' else 'Já votou este mês. Cada colaborador vota uma só vez.' end;
  end;
  return jsonb_build_object('ok', true, 'mes', v_mes);
end $f$;

-- Votos e contagem: só o apurador (regulamento 6.2).
create or replace function public.bsp_fm_votos(p_mes date)
returns jsonb language plpgsql volatile security definer set search_path to 'public'
as $f$
declare v_mes date := date_trunc('month', p_mes)::date;
begin
  if not public.bsp_fm_apurador() then raise exception 'Só o apurador vê os votos.'; end if;
  perform public.bsp_acesso_srv('funcionario-mes', 'votos ' || to_char(v_mes, 'YYYY-MM'));
  return jsonb_build_object(
    'mes', v_mes,
    'votos', coalesce((select jsonb_agg(jsonb_build_object('id', v.id, 'votante', v.votante, 'nomeado', v.nomeado,
                 'assiduidade', v.assiduidade, 'atitude', v.atitude, 'qualidade', v.qualidade, 'compromisso', v.compromisso,
                 'relacionamento', v.relacionamento, 'justificacao', v.justificacao, 'origem', v.origem,
                 'registado_por', v.registado_por, 'criado_em', v.criado_em) order by v.criado_em)
                 from public.fm_votos v where v.mes = v_mes), '[]'::jsonb),
    'classificacao', public.bsp_fm_contagem(v_mes),
    'resultado', (select to_jsonb(r) from public.fm_resultados r where r.mes = v_mes),
    'equipa', coalesce((select jsonb_agg(to_jsonb(q) order by q.nome) from public.bsp_fm_equipa(v_mes) q), '[]'::jsonb));
end $f$;

-- Data de admissão e impedimento (processo disciplinar), sem motivo escrito.
create or replace function public.bsp_fm_pessoa(p_user text, p_admissao date, p_impedido_ate date)
returns void language plpgsql volatile security definer set search_path to 'public'
as $f$
begin
  if not public.bsp_fm_apurador() then raise exception 'Só o apurador muda estes dados.'; end if;
  insert into public.fm_pessoas (user_id, admissao, impedido_ate, actualizado_por, actualizado_em)
  values (p_user, p_admissao, p_impedido_ate, public.bsp_meu_id(), now())
  on conflict (user_id) do update set admissao = excluded.admissao, impedido_ate = excluded.impedido_ate,
    actualizado_por = excluded.actualizado_por, actualizado_em = now();
end $f$;

-- Divulgação: Feed, sino e telemóvel de todos.
create or replace function public.bsp_fm_publicar(p_mes date)
returns void language plpgsql volatile security definer set search_path to 'public'
as $f$
declare
  r record;
  nome text;
  funcao text;
  v_titulo text;
  v_texto text;
begin
  select * into r from public.fm_resultados where mes = p_mes;
  if not found or r.estado <> 'eleito' or r.publicado_em is not null then return; end if;
  select e->>'name', e->>'role' into nome, funcao from shared_state s, jsonb_array_elements(s.team) e where s.id = 1 and e->>'id' = r.vencedor limit 1;
  v_titulo := 'Funcionário do Mês: ' || public.bsp_fm_mes_nome(p_mes);
  v_texto := 'Parabéns a ' || coalesce(nome, 'colega') || coalesce(' (' || nullif(funcao, '') || ')', '') || ', eleito(a) pelos colegas Funcionário do Mês de '
    || public.bsp_fm_mes_nome(p_mes) || '.' || E'\n\n'
    || 'A escolha avalia assiduidade e pontualidade, atitude e espírito de equipa, qualidade do trabalho, comprometimento e relacionamento com os utentes.'
    || coalesce(E'\n\n' || 'Recebe ' || (select valor from public.fm_config where chave = 'premio') || '.', '')
    || E'\n\n' || 'Obrigado a todos os que votaram. A próxima votação decorre a 17 e 18 de '
    || public.bsp_fm_mes_nome((p_mes + interval '1 month')::date) || ', em Equipa → Funcionário do mês.';
  if not exists (select 1 from public.posts where cid = 'fm-' || to_char(p_mes, 'YYYY-MM')) then
    insert into public.posts (user_id, type, title, body, cid) values ('u1', 'normal', v_titulo, v_texto, 'fm-' || to_char(p_mes, 'YYYY-MM'));
  end if;
  insert into public.novidades (titulo, texto, grupos, destino) values (v_titulo, v_texto, array['todos'], 'directory');
  perform public.bsp_push_post(jsonb_build_object('titulo', v_titulo, 'corpo', 'Parabéns a ' || coalesce(nome, 'colega') || '!', 'url', '#/feed', 'tag', 'fm-' || to_char(p_mes, 'YYYY-MM')));
  insert into public.novidades (titulo, texto, grupos, destino) values (
    'Prémio do Funcionário do Mês por entregar', coalesce(nome, 'colega') || ' venceu ' || public.bsp_fm_mes_nome(p_mes) || '. Entregar: '
      || coalesce((select valor from public.fm_config where chave = 'premio'), 'prémio') || '. O certificado imprime-se em Equipa → Funcionário do mês.',
    array['u1', 'u2'], 'directory');
  update public.fm_resultados set publicado_em = now() where mes = p_mes;
end $f$;

-- Apuramento (dia 23, pelo agendamento; o apurador pode correr a partir do dia 23).
create or replace function public.bsp_fm_apurar(p_mes date default null)
returns jsonb language plpgsql volatile security definer set search_path to 'public'
as $f$
declare
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  v_mes date := coalesce(date_trunc('month', p_mes)::date, date_trunc('month', hoje)::date);
  cl jsonb;
  t1 jsonb;
  t2 jsonb;
  v_estado text;
  v_venc text;
begin
  if auth.uid() is not null and not public.bsp_fm_apurador() then raise exception 'Só o apurador faz o apuramento.'; end if;
  if v_mes = date_trunc('month', hoje)::date and extract(day from hoje) < 23 then
    raise exception 'O apuramento é a 23 de cada mês.';
  end if;
  if exists (select 1 from public.fm_resultados where mes = v_mes) then
    return (select to_jsonb(r) from public.fm_resultados r where r.mes = v_mes);
  end if;
  cl := public.bsp_fm_contagem(v_mes);
  t1 := cl->0; t2 := cl->1;
  if t1 is null then
    v_estado := 'sem-votos';
  elsif t2 is not null and (t2->>'media')::numeric = (t1->>'media')::numeric and (t2->>'atitude')::numeric = (t1->>'atitude')::numeric then
    v_estado := 'empate';
  else
    v_estado := 'eleito'; v_venc := t1->>'id';
  end if;
  insert into public.fm_resultados (mes, estado, vencedor, votos, votantes, classificacao)
  values (v_mes, v_estado, v_venc,
          (select count(*) from public.fm_votos where mes = v_mes),
          (select count(distinct votante) from public.fm_votos where mes = v_mes),
          cl);
  if v_estado = 'eleito' then
    perform public.bsp_fm_publicar(v_mes);
  else
    insert into public.novidades (titulo, texto, grupos, destino) values (
      'Funcionário do Mês de ' || public.bsp_fm_mes_nome(v_mes) || ': ' || case when v_estado = 'empate' then 'empate' else 'sem votos' end,
      case when v_estado = 'empate'
           then 'Dois ou mais colegas têm a mesma média e a mesma nota em «Atitude e Espírito de Equipa». Pelo regulamento, decide a Direcção: Equipa → Funcionário do mês → «Decidir».'
           else 'Não houve votos este mês. Não há Funcionário do Mês a anunciar.' end,
      array['u1', 'u2'], 'directory');
  end if;
  return (select to_jsonb(r) from public.fm_resultados r where r.mes = v_mes);
end $f$;

-- Empate que persiste: decide a Direcção, só entre os empatados.
create or replace function public.bsp_fm_decidir(p_mes date, p_vencedor text)
returns void language plpgsql volatile security definer set search_path to 'public'
as $f$
declare r record; t1 jsonb;
begin
  if not public.bsp_e_direccao() then raise exception 'Só a Direcção decide o empate.'; end if;
  select * into r from public.fm_resultados where mes = date_trunc('month', p_mes)::date;
  if not found or r.estado <> 'empate' then raise exception 'Este mês não está empatado.'; end if;
  t1 := r.classificacao->0;
  if not exists (select 1 from jsonb_array_elements(r.classificacao) c
                  where c->>'id' = p_vencedor and c->>'media' = t1->>'media' and c->>'atitude' = t1->>'atitude') then
    raise exception 'Escolha um dos colegas empatados.';
  end if;
  update public.fm_resultados set estado = 'eleito', vencedor = p_vencedor, decidido_por = public.bsp_meu_id() where mes = r.mes;
  perform public.bsp_fm_publicar(r.mes);
end $f$;

-- Abertura (dia 17) e lembrete (dia 18) a quem ainda não votou.
create or replace function public.bsp_fm_avisar(p_tipo text)
returns integer language plpgsql volatile security definer set search_path to 'public'
as $f$
declare
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  v_mes date := date_trunc('month', hoje)::date;
  para text[];
begin
  select array_agg(q.id) into para from public.bsp_fm_equipa(v_mes) q
   where q.vota and not exists (select 1 from public.fm_votos v where v.mes = v_mes and v.votante = q.id);
  if para is null then return 0; end if;
  if p_tipo = 'abrir' then
    insert into public.novidades (titulo, texto, grupos, destino) values (
      'Funcionário do Mês: votação aberta hoje e amanhã',
      'Escolha o colega que mais se destacou de 1 a 15 de ' || public.bsp_fm_mes_nome(v_mes) || '. Avalie cinco critérios de 1 a 5. '
        || coalesce('Prémio: ' || (select valor from public.fm_config where chave = 'premio') || '. ', '')
        || 'O voto é confidencial: só a Direcção e a responsável operacional o vêem. Ninguém vota em si próprio e cada um vota uma vez.'
        || E'\n\n' || 'Equipa → Funcionário do mês, até às 23h59 de amanhã. Resultado a 23 de ' || public.bsp_fm_mes_nome(v_mes) || '.',
      array['todos'], 'directory');
  end if;
  perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para),
    'titulo', case when p_tipo = 'abrir' then 'Funcionário do Mês: vote hoje ou amanhã' else 'Funcionário do Mês: último dia para votar' end,
    'corpo', 'Equipa → Funcionário do mês', 'url', '#/directory', 'tag', 'fm-voto-' || to_char(hoje, 'YYYY-MM-DD')));
  return cardinality(para);
end $f$;

revoke all on function public.bsp_fm_equipa(date), public.bsp_fm_contagem(date), public.bsp_fm_publicar(date),
  public.bsp_fm_avisar(text), public.bsp_fm_mes_nome(date) from public, anon, authenticated;
revoke all on function public.bsp_fm_apurador(), public.bsp_fm_estado(), public.bsp_fm_votar(text, jsonb, text, boolean, text),
  public.bsp_fm_votos(date), public.bsp_fm_pessoa(text, date, date), public.bsp_fm_apurar(date), public.bsp_fm_decidir(date, text)
  from public, anon;
grant execute on function public.bsp_fm_apurador(), public.bsp_fm_estado(), public.bsp_fm_votar(text, jsonb, text, boolean, text),
  public.bsp_fm_votos(date), public.bsp_fm_pessoa(text, date, date), public.bsp_fm_apurar(date), public.bsp_fm_decidir(date, text)
  to authenticated;

-- Agendamentos (UTC; Luanda = UTC+1).
select cron.schedule('bsp-fm-abrir', '0 6 17 * *', $$select public.bsp_fm_avisar('abrir')$$);
select cron.schedule('bsp-fm-lembrar', '0 11 18 * *', $$select public.bsp_fm_avisar('lembrar')$$);
select cron.schedule('bsp-fm-apurar', '0 7 23 * *', $$select public.bsp_fm_apurar()$$);
