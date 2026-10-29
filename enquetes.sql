-- Enquetes do Feed com votos a sério (29-10-2026, Elmar: «Coloque enquete»).
-- Até aqui a enquete era só aspecto: as opções não iam para o servidor e
-- tocar numa opção não fazia nada.
-- - posts.poll: as opções ({options: [{id, label}]}), gravadas com a publicação.
-- - enquete_votos: um voto por pessoa e enquete (pode mudar de opção). Quem
--   votou em quê não se mostra a ninguém pela API: só os totais.
-- - bsp_enquete_votar(post, opcao) grava; bsp_enquete_resultados() devolve os
--   totais de cada opção e o meu voto.

alter table public.posts add column if not exists poll jsonb;

create table if not exists public.enquete_votos (
  post_id bigint not null references public.posts(id) on delete cascade,
  user_id text not null,
  opcao text not null,
  em timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table public.enquete_votos enable row level security;
revoke all on public.enquete_votos from anon, authenticated;

create or replace function public.bsp_enquete_votar(p_post bigint, p_opcao text)
returns boolean language plpgsql volatile security definer set search_path to 'public'
as $f$
declare eu text := public.bsp_meu_id(); pl jsonb;
begin
  if eu is null or not public.bsp_mfa_ok() then raise exception 'Sem sessão.'; end if;
  select poll into pl from posts where id = p_post;
  if pl is null or not exists (select 1 from jsonb_array_elements(pl->'options') o where o->>'id' = p_opcao) then
    raise exception 'Opção inválida.';
  end if;
  insert into enquete_votos (post_id, user_id, opcao) values (p_post, eu, p_opcao)
  on conflict (post_id, user_id) do update set opcao = excluded.opcao, em = now();
  return true;
end $f$;

create or replace function public.bsp_enquete_resultados()
returns table (post_id bigint, opcao text, votos bigint, meu boolean)
language sql stable security definer set search_path to 'public'
as $f$
  with eu as (select public.bsp_meu_id() id offset 0)
  select v.post_id, v.opcao, count(*), bool_or(v.user_id = (select id from eu))
    from enquete_votos v
   where (select id from eu) is not null and public.bsp_mfa_ok()
   group by v.post_id, v.opcao
$f$;

revoke all on function public.bsp_enquete_votar(bigint, text) from public, anon;
revoke all on function public.bsp_enquete_resultados() from public, anon;
grant execute on function public.bsp_enquete_votar(bigint, text) to authenticated;
grant execute on function public.bsp_enquete_resultados() to authenticated;
