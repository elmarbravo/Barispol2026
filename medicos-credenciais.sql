-- Credenciais dos médicos (03-10-2026, Elmar: «Os dados dos médicos tens no
-- MetaGest»).
--
-- O MetaGest (ERPNext, «Healthcare Practitioner») tem o código, o nome, a
-- cédula profissional, o departamento e o estado de cada médico; não tem
-- validades. Copia-se todos os dias para erp.medicos (a pessoa que entra
-- nunca lê erp.*). As validades (quota da Ordem, seguro de responsabilidade
-- civil, contrato, suporte de vida, especialidade) registam-se no Workspace,
-- em public.credenciais, com aviso 30 e 7 dias antes e no dia em que caducam.
--
-- Quem vê: a gestão e a Direcção Clínica (bsp_ve_qualidade) todos os
-- médicos; cada médico as suas (pelos códigos metagest da sua ficha).

create table if not exists erp.medicos (
  codigo text primary key,
  nome text not null default '',
  cedula text not null default '',
  departamento text not null default '',
  estado text not null default '',
  modificado timestamptz,
  sincronizado_em timestamptz not null default now()
);
alter table erp.medicos enable row level security;

create or replace function erp.sincronizar_medicos()
returns int language plpgsql security definer set search_path to 'erp', 'public'
as $f$
declare d jsonb;
begin
  d := erp.api_lista('Healthcare Practitioner', '["name","practitioner_name","cedula","department","status","modified"]', '[]');
  insert into erp.medicos as m (codigo, nome, cedula, departamento, estado, modificado, sincronizado_em)
  select x->>'name', btrim(regexp_replace(coalesce(x->>'practitioner_name', ''), '\s+', ' ', 'g')), btrim(coalesce(x->>'cedula', '')),
         coalesce(x->>'department', ''), coalesce(x->>'status', ''), nullif(x->>'modified', '')::timestamptz, now()
    from jsonb_array_elements(d) x where coalesce(x->>'name', '') <> ''
  on conflict (codigo) do update set nome = excluded.nome, cedula = excluded.cedula, departamento = excluded.departamento,
    estado = excluded.estado, modificado = excluded.modificado, sincronizado_em = now();
  return jsonb_array_length(d);
end $f$;
revoke execute on function erp.sincronizar_medicos() from public, anon, authenticated;

create table if not exists public.credenciais (
  id bigint generated always as identity primary key,
  medico text not null,
  tipo text not null check (tipo in ('Cédula profissional', 'Quota da Ordem dos Médicos', 'Seguro de responsabilidade civil',
    'Contrato', 'Suporte básico de vida', 'Suporte avançado de vida', 'Título de especialidade', 'Outro')),
  numero text not null default '',
  emitido date,
  validade date,
  nota text not null default '',
  criado_por text default public.bsp_meu_id(),
  criado_em timestamptz not null default now(),
  actualizado_em timestamptz not null default now()
);
create index if not exists credenciais_medico on public.credenciais (medico);
alter table public.credenciais enable row level security;

-- Os códigos MetaGest de quem entra (campo metagest da ficha).
create or replace function public.bsp_meus_codigos_metagest()
returns text[] language sql stable security definer set search_path to 'public'
as $f$
  select coalesce(array(select jsonb_array_elements_text(coalesce(e->'metagest', '[]'::jsonb))
    from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and e->>'id' = public.bsp_meu_id() limit 1), '{}')
$f$;

drop policy if exists credenciais_ler on public.credenciais;
create policy credenciais_ler on public.credenciais for select to authenticated
  using ((select public.bsp_ve_qualidade()) or medico in (select unnest(public.bsp_meus_codigos_metagest())));
drop policy if exists credenciais_criar on public.credenciais;
create policy credenciais_criar on public.credenciais for insert to authenticated
  with check ((select public.bsp_ve_qualidade()));
drop policy if exists credenciais_mudar on public.credenciais;
create policy credenciais_mudar on public.credenciais for update to authenticated
  using ((select public.bsp_ve_qualidade())) with check ((select public.bsp_ve_qualidade()));
drop policy if exists credenciais_apagar on public.credenciais;
create policy credenciais_apagar on public.credenciais for delete to authenticated
  using ((select public.bsp_ve_qualidade()));

-- Lista para o ecrã: os médicos (activos e com facturas nos últimos 6 meses
-- primeiro), a cédula, a ficha do Workspace ligada e o estado das validades.
create or replace function public.bsp_medicos_credenciais(p_todos boolean default false)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare tudo boolean := public.bsp_ve_qualidade(); meus text[] := public.bsp_meus_codigos_metagest();
begin
  if not tudo and cardinality(meus) = 0 then raise exception 'Sem acesso.'; end if;
  return coalesce((
    with act as (
      select s.ref_practitioner codigo, count(*) n, max(s.posting_date) ultima
        from erp.sales_invoice s
       where s.docstatus = 1 and s.posting_date > current_date - 180 and s.ref_practitioner is not null
       group by 1 offset 0
    ), ws as (
      select c codigo, e->>'id' membro
        from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e,
             jsonb_array_elements_text(coalesce(e->'metagest', '[]'::jsonb)) c
       where s.id = 1
    )
    select jsonb_agg(jsonb_build_object(
      'codigo', m.codigo, 'nome', m.nome, 'cedula', m.cedula, 'departamento', m.departamento, 'estado', m.estado,
      'facturas_6m', coalesce(a.n, 0), 'ultima', a.ultima, 'membro', w.membro,
      'credenciais', coalesce((select jsonb_agg(to_jsonb(c) order by c.validade nulls last) from public.credenciais c where c.medico = m.codigo), '[]'),
      'caducadas', (select count(*) from public.credenciais c where c.medico = m.codigo and c.validade < current_date),
      'a_caducar', (select count(*) from public.credenciais c where c.medico = m.codigo and c.validade between current_date and current_date + 30))
      order by (a.n is null), m.nome)
    from erp.medicos m
    left join act a on a.codigo = m.codigo
    left join lateral (select membro from ws where ws.codigo = m.codigo limit 1) w on true
    where (tudo and (p_todos or (m.estado = 'Active' and a.n is not null))) or m.codigo = any (meus)
  ), '[]'::jsonb);
end $f$;
revoke execute on function public.bsp_medicos_credenciais(boolean) from public, anon;
grant execute on function public.bsp_medicos_credenciais(boolean) to authenticated;

-- Avisos: 30 dias antes, 7 dias antes e no dia, pelas novidades (e-mail das
-- 05h00 e sino) à gestão, à Direcção Clínica e ao próprio médico.
create or replace function public.bsp_credenciais_alertar()
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare r record; n int := 0; membro text;
begin
  for r in
    select c.*, m.nome, c.validade - current_date faltam
      from public.credenciais c join erp.medicos m on m.codigo = c.medico
     where c.validade - current_date in (30, 7, 0)
  loop
    select e->>'id' into membro from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1 and e->'metagest' ? r.medico limit 1;
    insert into public.novidades (titulo, texto, grupos, destino)
    values (case when r.faltam = 0 then 'Credencial caduca hoje' else 'Credencial caduca em ' || r.faltam || ' dias' end,
            r.tipo || ' de ' || initcap(lower(r.nome)) || coalesce(' (n.º ' || nullif(r.numero, '') || ')', '') || ': válida até ' || to_char(r.validade, 'DD-MM-YYYY') || '. Peça o documento renovado.',
            array['gestao', 'direccao-clinica'] || case when membro is not null then array[membro] else '{}' end, 'directory');
    n := n + 1;
  end loop;
  return n;
end $f$;
revoke execute on function public.bsp_credenciais_alertar() from public, anon, authenticated;
do $$ begin
  revoke execute on function public.bsp_meus_codigos_metagest() from public, anon;
  grant execute on function public.bsp_meus_codigos_metagest() to authenticated;
end $$;

select cron.schedule('bsp-medicos', '40 3 * * *', 'set statement_timeout to ''2min''; select erp.sincronizar_medicos(); select public.bsp_credenciais_alertar();');
