-- Recuperação da palavra-passe sem o Elmar (05-10-2026, Elmar: «A recuperação
-- de password como está? Os meus colegas conseguem sem mim? Se não faça isso»).
--
-- Antes: o «Esqueceu-se?» chamava resetPasswordForEmail. O e-mail saía pelo
-- correio de teste do Supabase (noreply@mail.app.supabase.io), que só entrega
-- a quem é membro da organização (o Elmar), e a ligação levava ao «Site URL»
-- do painel, que estava em http://localhost:3000. Os colegas não recebiam nada.
--
-- Agora: a Edge Function recuperar-acesso cria a ligação (generateLink,
-- recovery) e envia-a pela Resend, de geral@barispol.com, para o próprio
-- endereço da conta. A ligação abre workspace.html#recuperar=<código>; o
-- código só se gasta quando a pessoa grava a nova palavra-passe (verifyOtp).
--
-- Esta tabela limita os pedidos: 3 por endereço por hora e 30 no total por
-- hora. Guarda só um resumo do endereço (SHA-256), nunca o endereço.
-- Só o servidor lê e escreve (sem regras de acesso para quem entra).

create table if not exists public.recuperacoes_pedidos (
  id bigserial primary key,
  email_resumo text not null,
  criado_em timestamptz not null default now()
);
alter table public.recuperacoes_pedidos enable row level security;
create index if not exists recuperacoes_pedidos_quando on public.recuperacoes_pedidos (criado_em);

create or replace function public.bsp_recuperacao_pode(p_resumo text)
returns boolean language plpgsql security definer set search_path to 'public'
as $f$
begin
  if (select count(*) from public.recuperacoes_pedidos
       where email_resumo = p_resumo and criado_em > now() - interval '1 hour') >= 3
     or (select count(*) from public.recuperacoes_pedidos
          where criado_em > now() - interval '1 hour') >= 30 then
    return false;
  end if;
  insert into public.recuperacoes_pedidos (email_resumo) values (p_resumo);
  return true;
end $f$;
revoke execute on function public.bsp_recuperacao_pode(text) from public, anon, authenticated;
grant execute on function public.bsp_recuperacao_pode(text) to service_role;
