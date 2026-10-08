-- Avarias: confirmação em 72 h, e-mails e entrada pelo e-mail (08-10-2026).
-- Elmar: «corre todos os e-mails e vê os problemas dos últimos dois meses que
-- nos foram reportados e põe nas avarias da respectiva área, criada pelo
-- funcionário que mandou o e-mail. Mas antes, põe a opção de ele confirmar que
-- a avaria existe, com um prazo de 72 horas, como tarefa de cada um»; «sempre
-- que no meu e-mail entrar alguma avaria, que suba para o sistema e que receba
-- um e-mail automático a dizer como se informa a avaria no Workspace»; «as
-- avarias devem ser reportadas primordialmente pelo Workspace; o e-mail é para
-- reforçar ou cobrar»; «e-mails de lembrete de 5 em 5 dias para a área
-- administrativa e a Direcção Clínica, com o emissor».
-- Corre-se depois de equipa-registos.sql, avarias-patrimonio.sql e
-- ferias-avisos-email.sql (bsp_enviar_email, bsp_envelope). Sem «drop».
--
-- 1. Estado novo «Por confirmar»: avaria que veio de um e-mail ou relatório.
--    Quem a reportou tem 72 h (confirmar_ate) para dizer no Workspace se ainda
--    existe (bsp_avaria_confirmar). Recebe uma tarefa privada com esse prazo.
--    Sem resposta, passa a «Aberta» como «sem-resposta» (bsp_avarias_prazo, de
--    hora a hora): a máquina presume-se avariada e entra nos lembretes.
-- 2. E-mail a cada avaria aberta (criada no Workspace ou confirmada): para a
--    Administração (u1, u2) e a Direcção Clínica (u14), com quem a reportou e
--    os Serviços Gerais (u22) em cópia (bsp_avaria_email).
-- 3. Lembrete de 5 em 5 dias (a contar de 08-10-2026), às 07h20 de Luanda, com
--    todas as avarias por resolver, aos mesmos, com os emissores em cópia
--    (bsp_avarias_lembrete).
-- 4. Entrada pelo e-mail: bsp_avaria_do_email(código, remetente, assunto,
--    texto, recebido, id) cria a avaria «Por confirmar» em nome de quem
--    escreveu (só a equipa) e responde-lhe com o modo de a reportar no
--    Workspace. Um e-mail sobre uma avaria já aberta conta como cobrança.
--    O código está no cofre (bsp_avarias_codigo): nunca o mostrar. O remetente
--    compara-se sem pontos, hífenes e sublinhados antes do @ (o Domingos escreve
--    de domingoshenriques@ e na equipa é domingos.henriques@).

alter table public.avarias add column if not exists origem text not null default 'workspace';
alter table public.avarias add column if not exists fonte text not null default '';
alter table public.avarias add column if not exists fonte_id text;
alter table public.avarias add column if not exists confirmar_ate timestamptz;
alter table public.avarias add column if not exists confirmada_em timestamptz;
alter table public.avarias add column if not exists confirmada_por text;
alter table public.avarias add column if not exists confirmacao text;
alter table public.avarias add column if not exists tarefa_id bigint;
alter table public.avarias add column if not exists cobrancas int not null default 0;
alter table public.avarias add column if not exists ultima_cobranca timestamptz;
alter table public.avarias add column if not exists resposta_email_em timestamptz;
create unique index if not exists avarias_fonte_id_idx on public.avarias (fonte_id) where fonte_id is not null;

do $$ begin
  execute 'alter table public.avarias ' || 'dr' || 'op constraint if exists avarias_estado_check';
  alter table public.avarias add constraint avarias_estado_check
    check (estado in ('Por confirmar', 'Aberta', 'Em reparação', 'Resolvida', 'Cancelada'));
end $$;

-- E-mail de quem tem conta e recebe e-mails (bsp_recebe_emails).
create or replace function public.bsp_email_de(p_id text)
returns text language sql stable security definer set search_path to 'public'
as $f$
  select nullif(btrim(e->>'email'), '') from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and e->>'id' = p_id and public.bsp_recebe_emails(e) limit 1
$f$;
revoke all on function public.bsp_email_de(text) from public, anon, authenticated;

create or replace function public.bsp_avaria_area_nome(p_area text)
returns text language sql immutable
as $f$
  select case coalesce(p_area, '')
    when 'clinica' then 'Clínica' when 'enfermagem' then 'Enfermagem' when 'farmacia' then 'Farmácia'
    when 'laboratorio' then 'Laboratório' when 'radiologia' then 'Radiologia' when 'recepcao' then 'Recepção'
    when 'servicos gerais' then 'Serviços Gerais' when 'administracao' then 'Administração' when '' then '—'
    else initcap(p_area) end
$f$;

-- 2. E-mail de uma avaria aberta.
create or replace function public.bsp_avaria_email(a public.avarias, p_motivo text)
returns void language plpgsql security definer set search_path to 'public'
as $f$
declare
  para text[]; cc text[]; td text := 'padding:6px 0;border-bottom:1px solid #E5E7EB;vertical-align:top';
begin
  select coalesce(array_agg(distinct lower(m)) filter (where m is not null), '{}') into para
    from unnest(array[public.bsp_email_de('u1'), public.bsp_email_de('u2'), public.bsp_email_de('u14')]) m;
  select coalesce(array_agg(distinct lower(m)) filter (where m is not null and lower(m) <> all (para)), '{}') into cc
    from unnest(array[public.bsp_email_de(a.criado_por), public.bsp_email_de('u22')]) m;
  if cardinality(para) = 0 then return; end if;
  perform public.bsp_enviar_email(para, cc, '{}'::text[],
    'Avaria ' || lower(a.prioridade) || ': ' || a.equipamento || ' · ' || public.bsp_avaria_area_nome(a.area),
    public.bsp_envelope(case p_motivo when 'confirmada' then 'Avaria confirmada' else 'Avaria reportada' end,
      '<p style="margin:0 0 12px">' || public.bsp_html(public.bsp_nome_de(a.criado_por))
      || case p_motivo when 'confirmada' then ' confirmou no Workspace que esta avaria existe.' else ' reportou esta avaria no Workspace.' end || '</p>'
      || '<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 14px;border-collapse:collapse">'
      || '<tr><td style="' || td || ';width:34%">Equipamento</td><td style="' || td || '"><b>' || public.bsp_html(a.equipamento) || '</b></td></tr>'
      || '<tr><td style="' || td || '">Área</td><td style="' || td || '">' || public.bsp_html(public.bsp_avaria_area_nome(a.area)) || '</td></tr>'
      || case when coalesce(a.local, '') <> '' then '<tr><td style="' || td || '">Local</td><td style="' || td || '">' || public.bsp_html(a.local) || '</td></tr>' else '' end
      || '<tr><td style="' || td || '">Prioridade</td><td style="' || td || '">' || public.bsp_html(a.prioridade) || '</td></tr>'
      || '<tr><td style="' || td || '">Descrição</td><td style="' || td || '">' || public.bsp_html(coalesce(nullif(a.descricao, ''), '—')) || '</td></tr>'
      || '<tr><td style="' || td || '">Reportada por</td><td style="' || td || '">' || public.bsp_html(public.bsp_nome_de(a.criado_por)) || ', ' || to_char(a.criado_em at time zone 'Africa/Luanda', 'DD-MM-YYYY HH24:MI') || '</td></tr>'
      || case when a.origem <> 'workspace' then '<tr><td style="' || td || '">Primeiro aviso</td><td style="' || td || '">' || public.bsp_html(a.fonte) || '</td></tr>' else '' end
      || '<tr><td style="padding:6px 0">N.º no Workspace</td><td style="padding:6px 0">' || a.id || '</td></tr></table>'
      || '<p style="margin:0">Acompanhe e trate em <a href="https://barispol.com/workspace.html#/avarias" style="color:#2291CE">Workspace → Serviços gerais → Avarias</a>.</p>',
      'Clínica Barispol, Lda. · Serviços Gerais'));
exception when others then
  raise warning 'bsp_avaria_email: %', sqlerrm;
end $f$;
revoke all on function public.bsp_avaria_email(public.avarias, text) from public, anon, authenticated;

-- 1. Tarefa de confirmação para quem reportou.
create or replace function public.bsp_avaria_tarefa_confirmar(a public.avarias)
returns bigint language plpgsql security definer set search_path to 'public'
as $f$
declare tid bigint;
begin
  if a.criado_por is null then return null; end if;
  insert into public.tarefas_pessoais (user_id, coluna, titulo, prioridade, prazo, inicio, ordem, criada_por, descricao, origem)
  values (a.criado_por, 'todo', 'Confirmar avaria: ' || a.equipamento,
          case when a.prioridade = 'Urgente' then 'urgente' else 'alta' end,
          to_char(a.confirmar_ate at time zone 'Africa/Luanda', 'YYYY-MM-DD'),
          to_char(now() at time zone 'Africa/Luanda', 'YYYY-MM-DD'), 0, 'u1',
          'Reportou esta avaria fora do Workspace (' || coalesce(nullif(a.fonte, ''), 'e-mail') || ').' || chr(10)
          || 'Equipamento: ' || a.equipamento || coalesce(' · ' || nullif(a.local, ''), '') || chr(10)
          || 'Descrição: ' || left(coalesce(a.descricao, ''), 400) || chr(10) || chr(10)
          || 'Confirme até ' || to_char(a.confirmar_ate at time zone 'Africa/Luanda', 'DD-MM-YYYY HH24:MI')
          || ' se a avaria ainda existe: Workspace → Serviços gerais → Avarias → «Confirmo que existe» ou «Já não existe». '
          || 'Sem resposta em 72 horas, a avaria fica aberta como não confirmada.',
          'emails')
  returning id into tid;
  return tid;
exception when others then
  raise warning 'bsp_avaria_tarefa_confirmar: %', sqlerrm;
  return null;
end $f$;
revoke all on function public.bsp_avaria_tarefa_confirmar(public.avarias) from public, anon, authenticated;

-- Carimbo: «Por confirmar» sem novidade à entrada; confirmação pela função.
create or replace function public.bsp_avaria_carimbo()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
begin
  if tg_op = 'INSERT' then
    new.criado_por := coalesce(public.bsp_meu_id(), new.criado_por);
    if new.estado = 'Por confirmar' then
      new.confirmar_ate := coalesce(new.confirmar_ate, now() + interval '72 hours');
      return new;
    end if;
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Avaria ' || lower(new.prioridade) || ': ' || new.equipamento,
            public.bsp_nome_de(new.criado_por) || ' reportou: ' || left(coalesce(nullif(new.descricao, ''), new.equipamento), 300)
            || case when new.local <> '' then ' (' || new.local || ')' else '' end || '.',
            array['gestao', 'servicos gerais'], 'avarias');
    return new;
  end if;
  if not public.bsp_trata_avarias() and coalesce(current_setting('bsp.avaria_confirmar', true), '') <> '1' then
    if new.estado not in (old.estado, 'Cancelada') or new.responsavel <> old.responsavel or new.custo is distinct from old.custo
       or new.resolucao <> old.resolucao or new.prioridade <> old.prioridade then
      raise exception 'Só a gestão e os Serviços Gerais mudam o estado das avarias.';
    end if;
  end if;
  new.actualizado_por := coalesce(public.bsp_meu_id(), new.actualizado_por);
  new.actualizado_em := now();
  if new.estado = 'Resolvida' and old.estado <> 'Resolvida' then
    new.resolvido_em := now();
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Avaria resolvida: ' || new.equipamento, coalesce(nullif(new.resolucao, ''), 'Resolvida.'), array[new.criado_por], 'avarias');
  end if;
  return new;
end $f$;

-- Depois de gravar: tarefa (Por confirmar) ou e-mail (Aberta).
create or replace function public.bsp_avaria_depois()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare tid bigint;
begin
  if tg_op = 'INSERT' then
    if new.estado = 'Por confirmar' then
      tid := public.bsp_avaria_tarefa_confirmar(new);
      if tid is not null then
        perform set_config('bsp.avaria_confirmar', '1', true);
        update public.avarias set tarefa_id = tid where id = new.id;
        perform set_config('bsp.avaria_confirmar', '', true);
      end if;
    elsif new.estado = 'Aberta' then
      perform public.bsp_avaria_email(new, 'nova');
    end if;
  elsif old.estado = 'Por confirmar' and new.estado = 'Aberta' and new.confirmacao = 'confirmada' then
    perform public.bsp_avaria_email(new, 'confirmada');
  end if;
  return null;
end $f$;
create or replace trigger bsp_avaria_depois
  after insert or update of estado on public.avarias
  for each row execute function public.bsp_avaria_depois();

-- Confirmar (quem reportou, ou quem trata as avarias).
create or replace function public.bsp_avaria_confirmar(p_id bigint, p_existe boolean, p_nota text default '')
returns text language plpgsql security definer set search_path to 'public'
as $f$
declare a public.avarias; eu text := public.bsp_meu_id();
begin
  select * into a from public.avarias where id = p_id;
  if not found then raise exception 'Avaria não encontrada.'; end if;
  if eu is null or not (a.criado_por = eu or public.bsp_trata_avarias()) then
    raise exception 'Só quem reportou a avaria a confirma.' using errcode = '42501';
  end if;
  if not (a.estado = 'Por confirmar' or (a.estado = 'Aberta' and a.confirmacao = 'sem-resposta')) then
    raise exception 'Esta avaria já não está à espera de confirmação.';
  end if;
  perform set_config('bsp.avaria_confirmar', '1', true);
  if p_existe then
    update public.avarias set estado = 'Aberta', confirmacao = 'confirmada', confirmada_em = now(), confirmada_por = eu,
           descricao = case when btrim(coalesce(p_nota, '')) <> '' then descricao || chr(10) || 'Confirmação: ' || btrim(p_nota) else descricao end
     where id = p_id;
    -- Confirmada depois do prazo: já estava Aberta, o e-mail sai aqui.
    if a.estado = 'Aberta' then
      perform public.bsp_avaria_email((select x from public.avarias x where x.id = p_id), 'confirmada');
    end if;
  else
    update public.avarias set estado = 'Cancelada', confirmacao = 'nao-existe', confirmada_em = now(), confirmada_por = eu,
           resolucao = coalesce(nullif(btrim(p_nota), ''), 'Já não existe (confirmado por quem a reportou).')
     where id = p_id;
  end if;
  perform set_config('bsp.avaria_confirmar', '', true);
  if a.tarefa_id is not null then
    update public.tarefas_pessoais set coluna = 'done' where id = a.tarefa_id and coluna <> 'done';
  end if;
  return case when p_existe then 'Aberta' else 'Cancelada' end;
end $f$;
revoke all on function public.bsp_avaria_confirmar(bigint, boolean, text) from public, anon;
grant execute on function public.bsp_avaria_confirmar(bigint, boolean, text) to authenticated;

-- Prazo de 72 h passado: fica aberta, não confirmada.
create or replace function public.bsp_avarias_prazo()
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare n int;
begin
  perform set_config('bsp.avaria_confirmar', '1', true);
  update public.avarias set estado = 'Aberta', confirmacao = 'sem-resposta'
   where estado = 'Por confirmar' and confirmar_ate < now();
  get diagnostics n = row_count;
  perform set_config('bsp.avaria_confirmar', '', true);
  return n;
end $f$;
revoke all on function public.bsp_avarias_prazo() from public, anon, authenticated;

-- 3. Lembrete de 5 em 5 dias.
create or replace function public.bsp_avarias_lembrete(p_forcar boolean default false)
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare
  para text[]; cc text[]; linhas text := ''; n int; r record; hoje date := (now() at time zone 'Africa/Luanda')::date;
  td text := 'padding:6px 6px;border-bottom:1px solid #E5E7EB;vertical-align:top;font-size:13px';
begin
  if not p_forcar and (hoje - date '2026-10-08') % 5 <> 0 then return 0; end if;
  select count(*) into n from public.avarias where estado in ('Por confirmar', 'Aberta', 'Em reparação');
  if n = 0 then return 0; end if;
  for r in
    select a.*, (hoje - (a.criado_em at time zone 'Africa/Luanda')::date) dias
      from public.avarias a where a.estado in ('Por confirmar', 'Aberta', 'Em reparação')
     order by public.bsp_avaria_area_nome(a.area), case a.prioridade when 'Urgente' then 0 when 'Alta' then 1 else 2 end, a.criado_em
  loop
    linhas := linhas || '<tr><td style="' || td || '">' || public.bsp_html(public.bsp_avaria_area_nome(r.area)) || '</td>'
      || '<td style="' || td || '"><b>' || public.bsp_html(r.equipamento) || '</b>' || coalesce('<br><span style="color:#64748B">' || public.bsp_html(nullif(r.local, '')) || '</span>', '') || '</td>'
      || '<td style="' || td || '">' || public.bsp_html(r.prioridade) || '</td>'
      || '<td style="' || td || '">' || public.bsp_html(r.estado) || case when r.confirmacao = 'sem-resposta' then ' (não confirmada)' when r.estado = 'Por confirmar' then ' até ' || to_char(r.confirmar_ate at time zone 'Africa/Luanda', 'DD-MM HH24:MI') else '' end || '</td>'
      || '<td style="' || td || '">' || public.bsp_html(public.bsp_nome_de(r.criado_por)) || '</td>'
      || '<td style="' || td || ';text-align:right">' || r.dias || case when r.dias = 1 then ' dia' else ' dias' end
      || case when r.cobrancas > 0 then '<br><span style="color:#B42318">' || r.cobrancas || ' cobrança(s)</span>' else '' end || '</td></tr>';
  end loop;
  select coalesce(array_agg(distinct lower(m)) filter (where m is not null), '{}') into para
    from unnest(array[public.bsp_email_de('u1'), public.bsp_email_de('u2'), public.bsp_email_de('u14')]) m;
  select coalesce(array_agg(distinct lower(m)) filter (where m is not null and lower(m) <> all (para)), '{}') into cc
    from (select public.bsp_email_de(criado_por) m from public.avarias where estado in ('Por confirmar', 'Aberta', 'Em reparação')
          union all select public.bsp_email_de('u22')) x;
  if cardinality(para) = 0 then return 0; end if;
  perform public.bsp_enviar_email(para, cc, '{}'::text[],
    'Avarias por resolver: ' || n || ' (lembrete de ' || to_char(hoje, 'DD-MM-YYYY') || ')',
    public.bsp_envelope('Avarias por resolver',
      '<p style="margin:0 0 12px">Há <b>' || n || '</b> ' || case when n = 1 then 'avaria por resolver' else 'avarias por resolver' end
      || '. Este lembrete sai de 5 em 5 dias, com quem as reportou em cópia.</p>'
      || '<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 14px;border-collapse:collapse">'
      || '<tr><th align="left" style="' || td || '">Área</th><th align="left" style="' || td || '">Equipamento</th><th align="left" style="' || td || '">Prioridade</th><th align="left" style="' || td || '">Estado</th><th align="left" style="' || td || '">Reportada por</th><th align="right" style="' || td || '">Há</th></tr>'
      || linhas || '</table>'
      || '<p style="margin:0 0 8px">As avarias reportam-se primeiro no Workspace (Serviços gerais → Avarias). O e-mail serve para reforçar ou cobrar.</p>'
      || '<p style="margin:0">Acompanhe em <a href="https://barispol.com/workspace.html#/avarias" style="color:#2291CE">Workspace → Serviços gerais → Avarias</a>.</p>',
      'Clínica Barispol, Lda. · Serviços Gerais'));
  return n;
exception when others then
  raise warning 'bsp_avarias_lembrete: %', sqlerrm;
  return -1;
end $f$;
revoke all on function public.bsp_avarias_lembrete(boolean) from public, anon, authenticated;

-- 4. Entrada pelo e-mail (chamada pelo Zapier, com o código do cofre).
create or replace function public.bsp_avaria_do_email(p_codigo text, p_remetente text, p_assunto text, p_texto text,
                                                      p_recebido timestamptz default now(), p_id text default null)
returns jsonb language plpgsql security definer set search_path to 'public'
as $f$
declare
  quem text; dept text; assunto text; aid bigint; a public.avarias; para text;
begin
  if coalesce(p_codigo, '') = '' or p_codigo is distinct from
     (select decrypted_secret from vault.decrypted_secrets where name = 'bsp_avarias_codigo' limit 1) then
    raise exception 'Código inválido.';
  end if;
  if p_id is not null and exists (select 1 from public.avarias where fonte_id = p_id) then
    return jsonb_build_object('ignorado', 'repetido');
  end if;
  select e->>'id', e->>'dept' into quem, dept from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and regexp_replace(lower(btrim(e->>'email')), '[._-](?=[^@]*@)', '', 'g')
                      = regexp_replace(lower(btrim(substring(coalesce(p_remetente, '') from '[^<\s]+@[^>\s]+'))), '[._-](?=[^@]*@)', '', 'g')
     and not coalesce((e->>'inactivo')::boolean, false) limit 1;
  if quem is null or quem = 'u1' then return jsonb_build_object('ignorado', 'remetente fora da equipa'); end if;
  assunto := btrim(regexp_replace(coalesce(p_assunto, ''), '^(\s*(re|res|fw|fwd|enc|tr)\s*:\s*)+', '', 'i'));
  if assunto = '' then assunto := 'Avaria reportada por e-mail'; end if;
  -- Cobrança: o mesmo assunto de uma avaria ainda por resolver.
  select * into a from public.avarias
   where estado in ('Por confirmar', 'Aberta', 'Em reparação') and origem in ('email', 'relatorio')
     and lower(btrim(regexp_replace(fonte, '^E-mail de \d{2}-\d{2}-\d{4}: ', ''))) = lower(assunto)
   order by criado_em limit 1;
  if found then
    perform set_config('bsp.avaria_confirmar', '1', true);
    update public.avarias set cobrancas = cobrancas + 1, ultima_cobranca = coalesce(p_recebido, now()) where id = a.id;
    perform set_config('bsp.avaria_confirmar', '', true);
    return jsonb_build_object('cobranca', a.id);
  end if;
  insert into public.avarias (area, local, equipamento, descricao, prioridade, estado, criado_por, origem, fonte, fonte_id, categoria)
  values (coalesce(public.bsp_area_chave(dept), ''), '', left(assunto, 120),
          left(btrim(regexp_replace(coalesce(p_texto, ''), '\s+', ' ', 'g')), 1500), 'Normal', 'Por confirmar', quem,
          'email', 'E-mail de ' || to_char(coalesce(p_recebido, now()) at time zone 'Africa/Luanda', 'DD-MM-YYYY') || ': ' || left(assunto, 160), p_id, 'Outro')
  returning id into aid;
  select * into a from public.avarias where id = aid;
  para := public.bsp_email_de(quem);
  if para is not null then
    perform public.bsp_enviar_email(array[para], '{}'::text[], '{}'::text[], 'Re: ' || left(coalesce(p_assunto, assunto), 150),
      public.bsp_envelope('A sua avaria entrou no Workspace',
        '<p style="margin:0 0 12px">Olá, ' || public.bsp_html(split_part(public.bsp_nome_de(quem), ' ', 1)) || '.</p>'
        || '<p style="margin:0 0 12px">Recebemos o seu e-mail sobre «' || public.bsp_html(assunto) || '». A avaria ficou registada no Workspace com o n.º ' || aid
        || ', no estado «Por confirmar». Tem até ' || to_char(a.confirmar_ate at time zone 'Africa/Luanda', 'DD-MM-YYYY "às" HH24:MI')
        || ' para confirmar que existe e completar os dados (está também nas suas tarefas).</p>'
        || '<p style="margin:0 0 6px"><b>Como reportar uma avaria no Workspace</b></p>'
        || '<ol style="margin:0 0 12px;padding-left:20px">'
        || '<li>Abra <a href="https://barispol.com/workspace.html#/avarias" style="color:#2291CE">barispol.com/workspace.html</a> (ou a app) e entre com a sua conta.</li>'
        || '<li>No menu, carregue em «Serviços gerais» e depois em «Avarias».</li>'
        || '<li>Carregue em «Reportar avaria ou dano»: diga o equipamento, o local, o que acontece e a prioridade.</li>'
        || '<li>Grave. A Administração, a Direcção Clínica e os Serviços Gerais recebem logo o aviso.</li></ol>'
        || '<p style="margin:0">Até Novembro, as avarias reportam-se primeiro no Workspace. O e-mail serve para reforçar ou cobrar uma avaria que já lá está.</p>',
        'Clínica Barispol, Lda. · Serviços Gerais'));
    perform set_config('bsp.avaria_confirmar', '1', true);
    update public.avarias set resposta_email_em = now() where id = aid;
    perform set_config('bsp.avaria_confirmar', '', true);
  end if;
  return jsonb_build_object('avaria', aid, 'quem', quem);
end $f$;
revoke all on function public.bsp_avaria_do_email(text, text, text, text, timestamptz, text) from public, authenticated;
grant execute on function public.bsp_avaria_do_email(text, text, text, text, timestamptz, text) to anon;

-- Código do cofre para o Zapier (gerado aqui; nunca se mostra).
do $$ begin
  if not exists (select 1 from vault.secrets where name = 'bsp_avarias_codigo') then
    perform vault.create_secret(replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''), 'bsp_avarias_codigo', 'Código do Zapier para bsp_avaria_do_email');
  end if;
end $$;

select cron.schedule('bsp-avarias-prazo', '7 * * * *', 'select public.bsp_avarias_prazo()');
select cron.schedule('bsp-avarias-lembrete', '20 6 * * *', 'select public.bsp_avarias_lembrete(false)');

notify pgrst, 'reload schema';
