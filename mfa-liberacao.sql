-- Dispensa temporária do código por e-mail (26-10-2026, Elmar: «Desbloqueia»).
-- Desde 24-10 os e-mails do sistema não chegam às caixas @barispol.com
-- (Microsoft 365), e quem usa o código por e-mail não consegue entrar.
-- mfa_liberacoes: pessoa e prazo (curto, ex.: 48 h); bsp_mfa_ok aceita a
-- sessão dessa pessoa até ao prazo. Só a Direcção decide quem entra aqui.
-- A palavra-passe continua obrigatória. Quando o correio voltar, as dispensas
-- caducam sozinhas; não se renovam.

create table if not exists public.mfa_liberacoes (
  user_id uuid not null,
  ate timestamptz not null,
  motivo text not null default '',
  criado_em timestamptz not null default now(),
  primary key (user_id, criado_em)
);
alter table public.mfa_liberacoes enable row level security;
revoke all on public.mfa_liberacoes from anon, authenticated;

create or replace function public.bsp_mfa_ok()
returns boolean language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
      or exists (select 1 from public.mfa_email_sessoes s
                  where s.sessao = public.bsp_mfa_sessao() and s.user_id = auth.uid()
                    and s.verificado_em > now() - interval '30 days')
      or exists (select 1
                   from auth.sessions eu
                   join auth.sessions gemea on gemea.user_id = eu.user_id and gemea.id <> eu.id
                    and gemea.created_at between eu.created_at - interval '10 seconds' and eu.created_at + interval '10 seconds'
                   join public.mfa_email_sessoes s on s.sessao = gemea.id and s.user_id = eu.user_id
                  where eu.id = public.bsp_mfa_sessao() and eu.user_id = auth.uid()
                    and s.verificado_em > now() - interval '30 days')
      or exists (select 1 from public.mfa_liberacoes l
                  where l.user_id = auth.uid() and l.ate > now())
$f$;

-- 26-10-2026: Déricka Domingos, Neusa Chimi e Cássia Peixoto, 48 h
-- (pediram códigos que não chegaram e já não têm a sessão aberta). A Arlete,
-- a Joana Tati e o Domingos Henriques ficaram com a sessão aberta dada como
-- verificada (mfa_email_sessoes, via 'direccao').
