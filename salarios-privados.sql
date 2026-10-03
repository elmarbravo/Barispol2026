-- Salários e valores pagos só para o Elmar e a Arlete (03-10-2026, Elmar:
-- «Na avaliação retire imediatamente valores, deixa apenas pontuação.
-- Salários são particulares, só eu e a Arlete vimos. Cada funcionário só vê
-- as suas coisas; os superiores vêem da sua equipa»).
--
-- bsp_ve_salarios(): só u1 (Elmar, Director Geral) e u2 (Arlete, RH). Não
-- passa pela camada (a conta de teste da Direcção não entra).
-- Produtividade: as colunas com Kz (subsidio, total) deixam de se ler pela
-- tabela; só bsp_produtividade_valores as devolve, e só a quem vê salários.
-- Os chefes e o superior vêem e lançam as notas da sua equipa; cada pessoa
-- vê as suas notas e percentagens aprovadas, sem valores. A ficha (subsídio
-- e objectivos) e o «Pago» ficam só com o Elmar e a Arlete. O sócio deixa
-- de ver a produtividade (antes via bsp_ve_painel).
-- Pagamento dos médicos: só o Elmar e a Arlete (antes: Painel e sócios).
-- O e-mail das novidades às 05h00 deixa de sair (cron bsp-novidades
-- desligado); as novidades continuam no sino.

create or replace function public.bsp_ve_salarios()
returns boolean language sql stable security definer set search_path to 'public'
as $f$ select coalesce(public.bsp_meu_id() in ('u1', 'u2'), false) $f$;
revoke execute on function public.bsp_ve_salarios() from public, anon;
grant execute on function public.bsp_ve_salarios() to authenticated;

-- Quem vê e lança as notas: o próprio não; a gestão, o chefe da área e o
-- superior directo, sim (sem o Painel nem os sócios).
create or replace function public.bsp_produtividade_trata(p_area text, p_user text)
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select not coalesce(public.bsp_e_socio(), false) and (
         coalesce(public.bsp_e_gestor(), false)
      or (coalesce(p_area, '') <> '' and coalesce(public.bsp_edita_escala(p_area), false))
      or (p_user is not null and p_user is distinct from public.bsp_meu_id() and coalesce(public.bsp_chefe_de(p_user), false)))
$f$;
create or replace function public.bsp_produtividade_aprova()
returns boolean language sql stable security definer set search_path to 'public'
as $f$ select coalesce(public.bsp_e_gestor(), false) and not coalesce(public.bsp_e_socio(), false) $f$;

-- Colunas com Kz fora da leitura directa.
do $$ begin
  revoke select on public.produtividade_mensal from authenticated, anon;
  grant select (id, codigo, user_id, nome, area, funcao, ano, mes, objectivos, media, percentagem, estado, observacoes,
                avaliador, aprovado_por, aprovado_em, pago_em, fonte, criado_em, actualizado_em) on public.produtividade_mensal to authenticated;
  revoke select on public.produtividade_pessoas from authenticated, anon;
  grant select (codigo, user_id, nome, area, funcao, objectivos, activo, actualizado_em) on public.produtividade_pessoas to authenticated;
end $$;

create or replace function public.bsp_produtividade_valores(p_ano int, p_mes int)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
begin
  if not public.bsp_ve_salarios() then raise exception 'Os valores só os vê o Director Geral e os Recursos Humanos.'; end if;
  return jsonb_build_object(
    'subsidios', (select coalesce(jsonb_object_agg(codigo, subsidio), '{}') from public.produtividade_pessoas),
    'mes', (select coalesce(jsonb_object_agg(codigo, jsonb_build_object('subsidio', subsidio, 'total', total)), '{}')
              from public.produtividade_mensal where ano = p_ano and mes = p_mes),
    'meus', '{}'::jsonb);
end $f$;
revoke execute on function public.bsp_produtividade_valores(int, int) from public, anon;
grant execute on function public.bsp_produtividade_valores(int, int) to authenticated;

-- A ficha (subsídio e objectivos) só o Elmar e a Arlete.
create or replace function public.bsp_produtividade_pessoa(p_codigo text, p_dados jsonb)
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
begin
  if not public.bsp_ve_salarios() then raise exception 'Só o Director Geral e os Recursos Humanos alteram o subsídio e os objectivos.'; end if;
  insert into public.produtividade_pessoas (codigo, user_id, nome, area, funcao, subsidio, objectivos, activo)
  values (upper(btrim(p_codigo)), nullif(p_dados->>'user_id', ''), coalesce(p_dados->>'nome', ''), coalesce(p_dados->>'area', ''),
          coalesce(p_dados->>'funcao', ''), coalesce((p_dados->>'subsidio')::numeric, 0),
          coalesce(array(select jsonb_array_elements_text(p_dados->'objectivos')), '{}'), coalesce((p_dados->>'activo')::boolean, true))
  on conflict (codigo) do update
     set user_id = excluded.user_id, nome = excluded.nome, area = excluded.area, funcao = excluded.funcao,
         subsidio = case when p_dados ? 'subsidio' then excluded.subsidio else produtividade_pessoas.subsidio end,
         objectivos = excluded.objectivos, activo = excluded.activo, actualizado_em = now();
  return true;
end $f$;

-- «Pago» só o Elmar e a Arlete; aprovar continua com a gestão.
create or replace function public.bsp_produtividade_estado(p_ano int, p_mes int, p_estado text, p_area text default null)
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare n int;
begin
  if p_estado = 'Aprovado' and not public.bsp_produtividade_aprova() then raise exception 'Só a gestão aprova.'; end if;
  if p_estado = 'Pago' and not public.bsp_ve_salarios() then raise exception 'Só o Director Geral e os Recursos Humanos marcam como pago.'; end if;
  if p_estado not in ('Aprovado', 'Pago', 'Rascunho') then raise exception 'Estado inválido.'; end if;
  if p_estado = 'Rascunho' and not public.bsp_produtividade_aprova() then raise exception 'Só a gestão reabre.'; end if;
  update public.produtividade_mensal
     set estado = p_estado,
         aprovado_por = case when p_estado = 'Aprovado' then public.bsp_meu_id() else aprovado_por end,
         aprovado_em = case when p_estado = 'Aprovado' then now() else aprovado_em end,
         pago_em = case when p_estado = 'Pago' then now() else pago_em end
   where ano = p_ano and mes = p_mes and (p_area is null or area = p_area)
     and percentagem is not null
     and (p_estado <> 'Pago' or estado in ('Aprovado', 'Pago'));
  get diagnostics n = row_count;
  if p_estado = 'Aprovado' and n > 0 then
    insert into public.novidades (titulo, texto, grupos, destino)
    select 'Produtividade de ' || to_char(make_date(p_ano, p_mes, 1), 'MM-YYYY'),
           'A sua produtividade de ' || to_char(make_date(p_ano, p_mes, 1), 'MM-YYYY') || ' foi aprovada. Veja a pontuação em Equipa → Produtividade.',
           array_agg(distinct user_id), 'directory'
      from public.produtividade_mensal
     where ano = p_ano and mes = p_mes and (p_area is null or area = p_area) and user_id is not null and estado = 'Aprovado'
    having count(*) > 0;
  end if;
  return n;
end $f$;

-- Pagamento dos médicos: só o Elmar e a Arlete.
create or replace function public.bsp_pagamento_acesso(p_escrever boolean)
returns boolean language sql stable security definer set search_path to 'public'
as $f$ select public.bsp_ve_salarios() $f$;

-- Sem e-mail das novidades às 05h00.
select cron.unschedule('bsp-novidades');
