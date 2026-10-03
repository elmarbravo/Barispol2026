-- Pedidos de marcação pelo site (03-10-2026, Elmar: «as marcações no site.
-- Mas no site o paciente espera ser contactado para marcar»).
--
-- barispol.com/contacto.html (e a mensagem da página inicial) gravam o
-- pedido aqui por bsp_pedido_site, aberta a visitantes como a
-- bsp_feedback_publico: nome, número para ligar e de quem é (o próprio ou
-- um familiar, com o telemóvel do próprio à parte), serviço, seguro, melhor
-- altura para ligar e de onde veio.
-- A Recepção recebe logo um aviso no telemóvel (bsp_push_post) e trata em
-- Utentes → Marcações → «Pedidos do site»: liga, marca (a marcação abre já
-- preenchida, origem «Site») ou regista que não atendeu ou desistiu.
-- Estados: Por ligar → Contactado / Marcado / Sem resposta / Desistiu.
-- Quem vê e trata: o mesmo das marcações (bsp_ve_marcacoes). Os dados dos
-- utentes ficam só no servidor.

create table if not exists public.pedidos_marcacao (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  pagina text not null default 'contacto',
  origem text not null default '',
  nome text not null,
  telefone text not null,
  tel9 text generated always as (nullif(substring(regexp_replace(coalesce(telefone, ''), '\D', '', 'g') from '(\d{9})$'), '')) stored,
  telefone_proprio text not null default '',
  familiar_quem text not null default '',
  servico text not null default '',
  seguro text not null default '',
  quando_ligar text not null default '',
  mensagem text not null default '',
  estado text not null default 'Por ligar' check (estado in ('Por ligar', 'Contactado', 'Marcado', 'Sem resposta', 'Desistiu')),
  tentativas int not null default 0,
  nota text not null default '',
  marcacao_id bigint,
  tratado_por text,
  tratado_em timestamptz
);
create index if not exists pedidos_marcacao_estado on public.pedidos_marcacao (estado, criado_em desc);
alter table public.pedidos_marcacao enable row level security;
drop policy if exists pedidos_marcacao_ler on public.pedidos_marcacao;
create policy pedidos_marcacao_ler on public.pedidos_marcacao for select to authenticated using (public.bsp_ve_marcacoes());

-- A única porta aberta a visitantes.
create or replace function public.bsp_pedido_site(p_dados jsonb)
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
declare nome text := left(btrim(coalesce(p_dados->>'nome', '')), 120);
  tel text := left(btrim(coalesce(p_dados->>'telefone', '')), 40);
  t9 text := right(regexp_replace(tel, '\D', '', 'g'), 9);
  prop text := left(btrim(coalesce(p_dados->>'telefone_proprio', '')), 40);
begin
  if coalesce(p_dados->>'empresa', '') <> '' then return true; end if; -- campo-armadilha para robôs
  if length(nome) < 3 then raise exception 'Escreva o seu nome.'; end if;
  if t9 !~ '^9\d{8}$' then raise exception 'Escreva um número angolano com nove dígitos, a começar por 9.'; end if;
  if prop <> '' and right(regexp_replace(prop, '\D', '', 'g'), 9) !~ '^9\d{8}$' then raise exception 'O telemóvel do próprio deve ter nove dígitos, a começar por 9.'; end if;
  if (select count(*) from public.pedidos_marcacao where criado_em > now() - interval '1 day') >= 300 then
    raise exception 'Recebemos muitos pedidos hoje. Ligue-nos ou use o WhatsApp, por favor.';
  end if;
  -- O mesmo número nas últimas 2 horas: não repete o pedido.
  if exists (select 1 from public.pedidos_marcacao where tel9 = t9 and criado_em > now() - interval '2 hours') then return true; end if;
  insert into public.pedidos_marcacao (pagina, origem, nome, telefone, telefone_proprio, familiar_quem, servico, seguro, quando_ligar, mensagem)
  values (left(coalesce(p_dados->>'pagina', 'contacto'), 20), left(coalesce(p_dados->>'origem', ''), 40), nome, tel, prop,
          left(btrim(coalesce(p_dados->>'familiar_quem', '')), 40), left(coalesce(p_dados->>'servico', ''), 80),
          left(coalesce(p_dados->>'seguro', ''), 60), left(coalesce(p_dados->>'quando_ligar', ''), 40),
          left(btrim(coalesce(p_dados->>'mensagem', '')), 1500));
  return true;
end $f$;

-- Aviso no telemóvel da Recepção a cada pedido novo.
create or replace function public.bsp_pedido_site_aviso()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare para text[];
begin
  select array_agg(e->>'id') into para from shared_state s, jsonb_array_elements(coalesce(s.team, '[]')) e
   where s.id = 1 and public.bsp_area_chave(e->>'dept') = 'recepcao';
  if para is null then return null; end if;
  perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para),
    'titulo', 'Pedido de marcação pelo site',
    'corpo', left(new.nome, 60) || coalesce(' · ' || nullif(new.servico, ''), '') || coalesce(' · ligar ' || nullif(lower(new.quando_ligar), ''), ''),
    'url', '#/marcacoes', 'tag', 'pedido-site-' || new.id));
  return null;
end $f$;
drop trigger if exists bsp_pedido_site_aviso on public.pedidos_marcacao;
create trigger bsp_pedido_site_aviso after insert on public.pedidos_marcacao
  for each row execute function public.bsp_pedido_site_aviso();

-- A Recepção trata o pedido.
create or replace function public.bsp_pedido_site_tratar(p_id bigint, p_estado text, p_nota text default null, p_marcacao bigint default null)
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
begin
  if not public.bsp_ve_marcacoes() then raise exception 'Sem acesso.'; end if;
  if p_estado not in ('Por ligar', 'Contactado', 'Marcado', 'Sem resposta', 'Desistiu') then raise exception 'Estado inválido.'; end if;
  update public.pedidos_marcacao
     set estado = p_estado,
         tentativas = tentativas + case when p_estado = 'Sem resposta' then 1 else 0 end,
         nota = case when coalesce(btrim(p_nota), '') = '' then nota else left(btrim(p_nota), 1000) end,
         marcacao_id = coalesce(p_marcacao, marcacao_id),
         tratado_por = public.bsp_meu_id(), tratado_em = now()
   where id = p_id;
  return found;
end $f$;

do $$ begin
  revoke execute on function public.bsp_pedido_site(jsonb) from public;
  grant execute on function public.bsp_pedido_site(jsonb) to anon, authenticated;
  revoke execute on function public.bsp_pedido_site_aviso() from public, anon, authenticated;
  revoke execute on function public.bsp_pedido_site_tratar(bigint, text, text, bigint) from public, anon;
  grant execute on function public.bsp_pedido_site_tratar(bigint, text, text, bigint) to authenticated;
end $$;
