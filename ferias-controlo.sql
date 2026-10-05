-- Controlo de férias e subsídio de férias dos RH (05-10-2026, pedido da Arlete
-- pelo Elmar: «rh-controlo-de-ferias-e-subsidio.xlsx, actualize o sistema»).
--
-- A folha dos RH tem, por pessoa e por ano: dias de direito, os dois períodos
-- (1.º e 2.º semestre) com os dias úteis gozados, se o subsídio de férias foi
-- pago em cada semestre, e observações. Há pessoas sem conta no Workspace
-- (assistentes dos Serviços Gerais, Raio-X), por isso a linha guarda o nome e
-- o user_id só quando existe.
--
-- Quem vê: só bsp_ve_salarios() (Elmar u1 e Arlete u2). O subsídio é um
-- pagamento (regra «Salários e valores pagos», 03-10-2026). As férias em si
-- continuam na tabela ausencias (estado Aprovado), que alimenta o Mapa de
-- férias de toda a equipa.
--
-- Os dados nunca entram no repositório (é público): carregam-se por um
-- ficheiro à parte, no SQL Editor.

create table if not exists public.ferias_controlo (
  id bigint generated always as identity primary key,
  ano int not null,
  numero int,
  nome text not null,
  user_id text,
  funcao text not null default '',
  admissao date,
  dias_direito int not null default 22,
  s1_inicio date, s1_fim date, s1_dias int not null default 0, s1_subsidio boolean,
  s2_inicio date, s2_fim date, s2_dias int not null default 0, s2_subsidio boolean,
  observacoes text not null default '',
  actualizado_por text default public.bsp_meu_id(),
  actualizado_em timestamptz not null default now(),
  unique (ano, nome)
);
alter table public.ferias_controlo enable row level security;
revoke all on public.ferias_controlo from anon, authenticated;

-- Estado igual ao da folha («Estado Geral»).
create or replace function public.bsp_ferias_controlo(p_ano int)
returns table (numero int, nome text, user_id text, funcao text, admissao date, dias_direito int,
               s1_inicio date, s1_fim date, s1_dias int, s1_subsidio boolean,
               s2_inicio date, s2_fim date, s2_dias int, s2_subsidio boolean,
               total int, saldo int, estado text, observacoes text, actualizado_em timestamptz)
language plpgsql stable security definer set search_path to 'public'
as $f$
begin
  if not coalesce(public.bsp_ve_salarios(), false) then raise exception 'Sem acesso.'; end if;
  return query
  select c.numero, c.nome, c.user_id, c.funcao, c.admissao, c.dias_direito,
         c.s1_inicio, c.s1_fim, c.s1_dias, c.s1_subsidio,
         c.s2_inicio, c.s2_fim, c.s2_dias, c.s2_subsidio,
         c.s1_dias + c.s2_dias, c.dias_direito - c.s1_dias - c.s2_dias,
         case
           when c.s1_dias + c.s2_dias = 0 then 'Por marcar'
           when c.s1_dias + c.s2_dias > c.dias_direito then 'Excede direito'
           when (c.s1_dias > 0 and c.s1_subsidio is not true) or (c.s2_dias > 0 and c.s2_subsidio is not true) then 'Subsídio pendente'
           when c.s1_dias + c.s2_dias < c.dias_direito then 'Saldo por gozar'
           else 'Completo' end,
         c.observacoes, c.actualizado_em
    from public.ferias_controlo c
   where c.ano = p_ano
   order by c.numero nulls last, c.nome;
end $f$;
revoke all on function public.bsp_ferias_controlo(int) from public, anon;
grant execute on function public.bsp_ferias_controlo(int) to authenticated;

-- A Arlete marca o subsídio como pago no ecrã.
create or replace function public.bsp_ferias_subsidio(p_ano int, p_nome text, p_semestre int, p_pago boolean)
returns void language plpgsql security definer set search_path to 'public'
as $f$
begin
  if not coalesce(public.bsp_ve_salarios(), false) then raise exception 'Sem acesso.'; end if;
  if p_semestre not in (1, 2) then raise exception 'Semestre inválido.'; end if;
  update public.ferias_controlo
     set s1_subsidio = case when p_semestre = 1 then p_pago else s1_subsidio end,
         s2_subsidio = case when p_semestre = 2 then p_pago else s2_subsidio end,
         actualizado_por = public.bsp_meu_id(), actualizado_em = now()
   where ano = p_ano and nome = p_nome;
end $f$;
revoke all on function public.bsp_ferias_subsidio(int, text, int, boolean) from public, anon;
grant execute on function public.bsp_ferias_subsidio(int, text, int, boolean) to authenticated;

notify pgrst, 'reload schema';
