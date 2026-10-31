-- Médicos novos do MetaGest entram no Workspace (31-10-2026, Elmar: «médicos
-- novos que se cadastram no MetaGest e não estão no Workspace devem vir também
-- para aqui… ver bem a facturação»).
--
-- Todos os dias às 07h53 de Luanda (06h53 UTC, minuto livre), o cron
-- bsp-medicos-novos corre bsp_medicos_novos_sincronizar():
--   · procura quem emitiu facturas no MetaGest nos últimos 30 dias
--     (erp.sales_invoice.practitioner_name, a chave do Query Report) e não está
--     no cadastro dos médicos (prestadores.chave ou chaves_extra, sem contar
--     maiúsculas nem espaços a mais); «EXTERNO» fica de fora;
--   · acrescenta-o a prestadores (activo, especialidade do MetaGest, sem NIF,
--     IBAN, regime nem taxa de permanência), para entrar no mapa de pagamento
--     do mês, na Equipa médica e nas presenças. As comissões contam logo; a
--     permanência fica a zero até a gestão completar a ficha;
--   · avisa o Elmar e a Arlete (novidade da gestão + telemóvel) para completarem
--     NIF, IBAN, regime e taxas e, se a pessoa precisar, criarem a conta.
-- Nomes e valores nunca neste ficheiro. Sem a palavra que apaga objectos.

create or replace function public.bsp_medicos_novos_sincronizar()
returns int
language plpgsql
volatile security definer
set search_path to 'public'
as $f$
declare
  r record;
  n int := 0;
  nomes text[] := '{}';
begin
  for r in
    with fact as (
      select regexp_replace(btrim(f.practitioner_name), '\s+', ' ', 'g') chave_limpa,
             max(f.practitioner_name) chave, max(f.ref_practitioner) codigo, count(*) facturas
        from erp.sales_invoice f
       where f.docstatus = 1 and f.posting_date >= current_date - 30
         and coalesce(btrim(f.practitioner_name), '') <> ''
         and upper(btrim(f.practitioner_name)) <> 'EXTERNO'
       group by 1),
    conhecidos as (
      select lower(regexp_replace(btrim(x), '\s+', ' ', 'g')) k
        from prestadores p, unnest(array_append(coalesce(p.chaves_extra, '{}'), p.chave)) x)
    select fa.chave, fa.codigo, fa.facturas, m.nome, m.departamento
      from fact fa left join erp.medicos m on m.codigo = fa.codigo
     where lower(fa.chave_limpa) not in (select k from conhecidos)
  loop
    insert into prestadores (chave, nome, especialidade, activo, notas)
    values (r.chave, coalesce(nullif(btrim(r.nome), ''), r.chave), upper(coalesce(r.departamento, '')), true,
            'Criado automaticamente do MetaGest a ' || to_char(current_date, 'DD-MM-YYYY') ||
            ' (' || coalesce(r.codigo, 'sem código') || '). Completar NIF, IBAN, regime e taxas.');
    n := n + 1;
    nomes := array_append(nomes, coalesce(nullif(btrim(r.nome), ''), r.chave));
  end loop;
  if n > 0 then
    insert into novidades (titulo, texto, grupos, destino, criado_por)
    values ('Médicos novos do MetaGest no cadastro',
            n || ' médico(s) com facturas no MetaGest entraram no cadastro dos médicos: ' || array_to_string(nomes, ', ') ||
            '. Completem NIF, IBAN, regime e taxas em Equipa médica → Pagamentos e, se for preciso, criem a conta no Workspace.',
            array['u1', 'u2'], '#/actividade', 'u1');
    begin
      perform bsp_push_post(jsonb_build_object('para', jsonb_build_array('u1', 'u2'),
        'titulo', 'Médicos novos do MetaGest',
        'corpo', n || ' médico(s) novo(s) no cadastro. Completar NIF, IBAN, regime e taxas.',
        'url', '#/actividade', 'tag', 'medicos-novos-' || current_date));
    exception when others then raise warning 'bsp_medicos_novos_sincronizar push: %', sqlerrm;
    end;
  end if;
  return n;
end $f$;
revoke all on function public.bsp_medicos_novos_sincronizar() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'bsp-medicos-novos') then perform cron.unschedule('bsp-medicos-novos'); end if;
  perform cron.schedule('bsp-medicos-novos', '53 6 * * *', $c$select public.bsp_medicos_novos_sincronizar()$c$);
end $$;

select public.bsp_medicos_novos_sincronizar() as novos;
