-- Documentos com prazo de revisão (03-10-2026, revisão «o que falta»).
-- Protocolos, procedimentos e regulamentos têm data de revisão: 30 dias
-- antes e no dia, a gestão (e a Direcção Clínica, nos procedimentos) recebe
-- o aviso nas novidades. No ecrã: «Rever até» na janela de publicar; nos
-- procedimentos propõe-se 2 anos.

alter table public.documentos add column if not exists revisao_ate date;

create or replace function public.bsp_documentos_rever_alertar()
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare r record; n int := 0;
begin
  for r in
    select d.*, d.revisao_ate - current_date faltam from public.documentos d
     where not coalesce(d.arquivado, false) and d.revisao_ate is not null and d.revisao_ate - current_date in (30, 0)
  loop
    insert into public.novidades (titulo, texto, grupos, destino)
    values (case when r.faltam = 0 then 'Documento a rever hoje' else 'Documento a rever em 30 dias' end,
            '«' || r.titulo || '»' || coalesce(' (' || nullif(r.numero, '') || ')', '') || ' tem revisão marcada para ' || to_char(r.revisao_ate, 'DD-MM-YYYY')
              || '. Reveja-o e publique a nova versão, ou marque outra data em «Alterar».',
            array['gestao'] || case when r.categoria = 'procedimento' then array['direccao-clinica'] else '{}' end, 'documentos');
    n := n + 1;
  end loop;
  return n;
end $f$;
revoke execute on function public.bsp_documentos_rever_alertar() from public, anon, authenticated;
select cron.schedule('bsp-documentos-revisao', '50 3 * * *', 'select public.bsp_documentos_rever_alertar();');
