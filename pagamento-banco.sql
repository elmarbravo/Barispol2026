-- Mapas de pagamento dos médicos para o banco (07-10-2026, Elmar: «o formato
-- deve ser sempre esse [Template de Pagamentos Médicos do BAI], data do dia que
-- extraio, mapa para BAI-BAI e mapa para outros bancos, nunca junte; a conta de
-- origem é a que está no template»). Corre-se depois de pagamento-medicos.sql.
--
-- A conta a debitar (NIB) e os dados fixos do ficheiro ficam só aqui, no
-- servidor: o repositório é público. Lê-os só quem vê os salários
-- (bsp_pagamento_acesso = u1 e u2), pela função bsp_pagamento_banco().
-- O NIB grava-se à parte, à mão, nunca neste ficheiro:
--   update public.pagamento_banco set nib_debito = '<NIB>' where id = 1;

create table if not exists public.pagamento_banco (
  id int primary key default 1 check (id = 1),
  nib_debito text not null default '',
  tipo_operacao text not null default '33',   -- 33 = Pagamentos de Diversos/Outros
  email text not null default 'Financas@barispol.com',
  banco_codigo text not null default '0040',  -- BAI no IBAN angolano (AO06 0040 …)
  actualizado_em timestamptz not null default now()
);
alter table public.pagamento_banco enable row level security;
revoke all on public.pagamento_banco from anon, authenticated;
insert into public.pagamento_banco (id) values (1) on conflict (id) do nothing;

create or replace function public.bsp_pagamento_banco()
returns jsonb language sql stable security definer set search_path to 'public'
as $f$
  select case when public.bsp_pagamento_acesso(false) then
    (select jsonb_build_object('nib_debito', nib_debito, 'tipo_operacao', tipo_operacao, 'email', email, 'banco_codigo', banco_codigo)
       from public.pagamento_banco where id = 1)
  end
$f$;
revoke all on function public.bsp_pagamento_banco() from public, anon;
grant execute on function public.bsp_pagamento_banco() to authenticated;

notify pgrst, 'reload schema';
