-- Novidades no sino sem atraso nem repetições (03-10-2026, Elmar: «As
-- novidades continuam atrasadas e repetidas»).
--
-- Antes: o ecrã pedia as 20 novidades MAIS ANTIGAS dos últimos 14 dias e
-- guardava as já vistas só no aparelho. Com mais de 20 por quinzena, as
-- novas nunca chegavam (voltavam sempre as de dias antes) e, com a memória
-- do aparelho cheia, as mesmas voltavam a cada 10 minutos.
-- Agora: novidades_vistas guarda, por pessoa, até que novidade já viu (um
-- número). bsp_novidades_por_ver devolve as seguintes que são para ela
-- (bsp_novidade_para_mim), logo que são criadas, sem esperar pelo e-mail das
-- 05h00; bsp_novidades_vistas(id) avança o marcador. Na primeira vez, o
-- marcador começa nas de há um dia (sem inundar o sino).

create table if not exists public.novidades_vistas (
  user_id text primary key,
  ate_id bigint not null default 0,
  actualizado_em timestamptz not null default now()
);
alter table public.novidades_vistas enable row level security;
-- Sem regras: só as duas funções lhe tocam.

create or replace function public.bsp_novidades_por_ver()
returns setof jsonb language plpgsql security definer set search_path to 'public'
as $f$
declare eu text := public.bsp_meu_id(); marca bigint;
begin
  if eu is null then return; end if;
  select ate_id into marca from public.novidades_vistas where user_id = eu;
  if marca is null then
    marca := coalesce((select max(id) from public.novidades where criado_em < now() - interval '1 day'), 0);
    insert into public.novidades_vistas (user_id, ate_id) values (eu, marca) on conflict (user_id) do nothing;
  end if;
  return query
    select jsonb_build_object('id', n.id, 'titulo', n.titulo, 'texto', n.texto, 'destino', n.destino,
                              'quando', coalesce(n.enviado_em, n.criado_em))
      from public.novidades n
     where n.id > marca and n.criado_em >= now() - interval '14 days'
       and public.bsp_novidade_para_mim(n.grupos)
     order by n.id
     limit 30;
end $f$;

create or replace function public.bsp_novidades_vistas(p_ate bigint)
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
declare eu text := public.bsp_meu_id();
begin
  if eu is null or p_ate is null then return false; end if;
  insert into public.novidades_vistas (user_id, ate_id) values (eu, p_ate)
  on conflict (user_id) do update set ate_id = greatest(novidades_vistas.ate_id, excluded.ate_id), actualizado_em = now();
  return true;
end $f$;

do $$ begin
  revoke execute on function public.bsp_novidades_por_ver() from public, anon;
  revoke execute on function public.bsp_novidades_vistas(bigint) from public, anon;
  grant execute on function public.bsp_novidades_por_ver() to authenticated;
  grant execute on function public.bsp_novidades_vistas(bigint) to authenticated;
end $$;
