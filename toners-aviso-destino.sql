-- Avisos dos toners em Logística e stock (07-10-2026, aplicado). O menu das
-- avarias passou a «Serviços gerais» e os toners saíram de lá: um aviso com
-- etiqueta toner… abre #/stock (novidade e telemóvel); o resto (gerador)
-- continua em #/avarias. Corre-se depois de toners-gerador.sql.
CREATE OR REPLACE FUNCTION public.bsp_aviso_servicos_gerais(p_titulo text, p_texto text, p_tag text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare para text[] := public.bsp_servicos_gerais_ids();
  -- Toners em Logística e stock desde 07-10-2026; o resto em Serviços gerais.
  dest text := case when coalesce(p_tag, '') like 'toner%' then 'stock' else 'avarias' end;
begin
  insert into public.novidades (titulo, texto, grupos, destino) values (p_titulo, p_texto, array['gestao', 'servicos gerais', 'u22'], dest);
  if cardinality(para) > 0 then
    perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para), 'titulo', p_titulo, 'corpo', left(p_texto, 160), 'url', '#/' || dest, 'tag', p_tag));
  end if;
end $function$;
