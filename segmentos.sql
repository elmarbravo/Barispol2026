-- Segmentos de utentes (08-10-2026, Elmar: «ponto 1 do HubSpot»: listas de
-- utentes por critério, para a Recepção ligar). Corre-se depois de
-- crm-seguimento.sql e marcacoes-ficha.sql. Sem «drop».
--
-- Junta-se ao separador «Recuperar utentes» (SeguimentoScreen): o mesmo
-- registo de chamadas (seguimentos) e os mesmos estados. A chave do utente é
-- o id do doente do MetaGest (utentes.chave = erp.sales_invoice.patient).
-- Segmentos (regras fixas, calculadas aqui):
--   pacote      último pacote promocional (o «check-up») há 11 a 24 meses
--   faltou      faltou ou cancelou uma marcação nos últimos 60 dias e não
--               remarcou nem veio depois (ligação pelo telefone)
--   so-servicos usou laboratório, farmácia, enfermagem ou imagem nos últimos
--               12 meses e nunca teve consulta na clínica
-- «Exames sem consulta de resultados» ficou de fora: a reconsulta quase nunca
-- se factura (25 em 12 meses), por isso as facturas não a medem.
-- Quem vê: quem vê o CRM (crm.pode_ver_crm), como as tabelas utentes e
-- seguimentos. Nomes de utentes nunca no repositório.

create or replace function public.bsp_segmento(p_seg text)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $f$
declare res jsonb;
begin
  if not crm.pode_ver_crm() then raise exception 'Sem acesso aos utentes.' using errcode = '42501'; end if;
  if p_seg = 'pacote' then
    select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'desde', x.dia,
             'detalhe', initcap(lower(regexp_replace(x.item, '^PACOTE PROMOCIONAL\s*-?\s*', 'Pacote '))) || ' a ' || to_char(x.dia, 'DD-MM-YYYY'))
             order by x.dia), '[]'::jsonb)
      into res
      from (select s.patient, max(s.posting_date) dia,
                   (array_agg(i.item_name order by s.posting_date desc))[1] item
              from erp.sales_invoice s join erp.sales_invoice_item i on i.parent = s.name
             where s.docstatus = 1 and not s.is_return and i.item_name ~* '^PACOTE PROMOCIONAL'
             group by s.patient offset 0) x
      join public.utentes u on u.chave = x.patient
     where x.dia between current_date - 730 and current_date - 335;
  elsif p_seg = 'faltou' then
    with m as (
      select distinct on (m.tel9) m.tel9, m.data_marcada dia, m.estado, m.acto
        from public.marcacoes m
       where m.estado in ('Faltou', 'Cancelou') and m.tel9 is not null
         and m.data_marcada between current_date - 60 and current_date - 1
       order by m.tel9, m.data_marcada desc
    ), u as (
      select distinct on (right(regexp_replace(coalesce(telefone, ''), '\D', '', 'g'), 9)) id, chave,
             right(regexp_replace(coalesce(telefone, ''), '\D', '', 'g'), 9) tel9
        from public.utentes where coalesce(telefone, '') <> ''
       order by right(regexp_replace(coalesce(telefone, ''), '\D', '', 'g'), 9), ultima_visita desc nulls last
    )
    select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'desde', m.dia,
             'detalhe', (case m.estado when 'Faltou' then 'Faltou' else 'Cancelou' end) || ' à marcação de ' || to_char(m.dia, 'DD-MM') || coalesce(' (' || nullif(btrim(m.acto), '') || ')', ''))
             order by m.dia desc), '[]'::jsonb)
      into res
      from m join u on u.tel9 = m.tel9
     where not exists (select 1 from public.marcacoes n where n.tel9 = m.tel9 and n.data_marcada > m.dia
                         and n.estado not in ('Faltou', 'Cancelou'))
       and not exists (select 1 from erp.sales_invoice s where s.patient = u.chave and s.docstatus = 1 and s.posting_date > m.dia);
  elsif p_seg = 'so-servicos' then
    with f as (
      select s.patient,
             max(s.posting_date) dia,
             bool_or(i.item_group = 'CONSULTAS E ESPECIALIDADES') consulta,
             count(distinct s.name) filter (where s.posting_date >= current_date - 365) n,
             (array_agg(distinct initcap(lower(i.item_group))) filter (where s.posting_date >= current_date - 365)) grupos
        from erp.sales_invoice s join erp.sales_invoice_item i on i.parent = s.name
       where s.docstatus = 1 and not s.is_return and s.patient is not null
       group by s.patient offset 0
    )
    select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'desde', f.dia,
             'detalhe', f.n || (case when f.n = 1 then ' visita' else ' visitas' end) || ' sem consulta (' || array_to_string(f.grupos[1:3], ', ') || ')')
             order by f.n desc, f.dia desc), '[]'::jsonb)
      into res
      from f join public.utentes u on u.chave = f.patient
     where not f.consulta and f.n > 0;
  else
    raise exception 'Segmento desconhecido: %', p_seg;
  end if;
  return res;
end $f$;
revoke all on function public.bsp_segmento(text) from public, anon;
grant execute on function public.bsp_segmento(text) to authenticated;

-- «Voltou» automático: quem foi contactado ou marcado e depois teve factura
-- no MetaGest passa a «voltou», com nota. Corre todos os dias às 07h00 (Luanda).
create or replace function public.bsp_segmentos_voltou()
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare n int;
begin
  insert into public.seguimentos (utente_id, estado, nota, user_id)
  select ult.utente_id, 'voltou', 'Automático: factura do MetaGest de ' || to_char(fa.dia, 'DD-MM-YYYY'), null
    from (select distinct on (utente_id) utente_id, estado, created_at
            from public.seguimentos order by utente_id, created_at desc) ult
    join public.utentes u on u.id = ult.utente_id
    cross join lateral (select min(s.posting_date) dia from erp.sales_invoice s
                         where s.patient = u.chave and s.docstatus = 1 and not s.is_return
                           and s.posting_date >= (ult.created_at at time zone 'Africa/Luanda')::date) fa
   where ult.estado in ('contactado', 'marcado') and fa.dia is not null;
  get diagnostics n = row_count;
  return n;
end $f$;
revoke all on function public.bsp_segmentos_voltou() from public, anon, authenticated;

select cron.schedule('bsp-segmentos-voltou', '0 6 * * *', 'select public.bsp_segmentos_voltou()');

notify pgrst, 'reload schema';
