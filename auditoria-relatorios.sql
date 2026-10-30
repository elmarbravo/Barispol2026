-- Auditoria dos relatórios de turno (30-10-2026, Elmar: «audita os relatórios com
-- base nas regras internacionais» → «as 4»). Campos novos no ecrã
-- (BSP_CAMPOS_LAB_QUALIDADE, BSP_CAMPOS_CARRO, BSP_CAMPOS_RX_REPETIDOS e
-- frio_accao em BSP_CAMPOS_FRIO, agora obrigatórios) e, aqui, o que deles conta
-- como «precisa de atenção» (aviso e novidade, como os outros):
--   ciq                   ISO 15189 §7.3.7.2  controlo interno não feito ou fora
--   lote_novo             ISO 15189 §6.6.3    lote usado sem verificação
--   suspensos             ISO 15189 §7.4      exames suspensos no turno
--   criticos(_comunicados) ISO 15189 §7.4.1.3 valores críticos por comunicar
--   frio_accao            OMS cadeia de frio  fora de 2–8 °C
--   carro_urgencia        JCI COP.3           não verificado ou com faltas
--   repetidos             protecção radiológica  Raio-X repetidos
-- Os ids mudam-se dos dois lados juntos.

create or replace function public.bsp_relatorio_atencao(r jsonb)
returns text[] language plpgsql immutable
as $function$
declare res text[] := '{}'; v text;
begin
  v := r->>'rupturas'; if v is not null and v <> 'Nenhuma' then res := res || ('Rupturas de stock: ' || v); end if;
  v := r->>'reagentes'; if v in ('Stock baixo', 'Em ruptura') then res := res || ('Reagentes e consumíveis: ' || lower(v)); end if;
  v := r->>'consumiveis'; if v in ('Stock baixo', 'Em ruptura') then res := res || ('Películas e consumíveis: ' || lower(v)); end if;
  if jsonb_typeof(r->'material') = 'array' and not (r->'material' ? 'Nenhum') and jsonb_array_length(r->'material') > 0 then
    res := res || ('Material em falta: ' || (select string_agg(x, ', ') from jsonb_array_elements_text(r->'material') x));
  end if;
  v := coalesce(r->>'equipamentos', r->>'aparelhos'); if v is not null and v <> 'Todos operacionais' then res := res || ('Equipamentos: ' || lower(v)); end if;
  if jsonb_typeof(r->'avarias') = 'array' and not (r->'avarias' ? 'Nenhuma') and jsonb_array_length(r->'avarias') > 0 then
    res := res || ('Avarias: ' || (select string_agg(x, ', ') from jsonb_array_elements_text(r->'avarias') x));
  end if;
  v := r->>'intercorrencias'; if v like 'Graves%' then res := res || 'Intercorrências graves no turno'::text; end if;
  if public.bsp_rel_n(r, 'incidentes') > 0 then res := res || ('Incidentes com dano ao utente: ' || public.bsp_rel_n(r, 'incidentes')); end if;
  if public.bsp_rel_n(r, 'quase_erros') > 0 then res := res || ('Quase-erros: ' || public.bsp_rel_n(r, 'quase_erros')); end if;
  if public.bsp_rel_n(r, 'resultados_atraso') > 0 then res := res || ('Resultados fora do prazo: ' || public.bsp_rel_n(r, 'resultados_atraso')); end if;
  v := r->>'resultados'; if v in ('Alguns pendentes', 'Todos pendentes') then res := res || ('Resultados: ' || lower(v)); end if;
  v := r->>'requisicoes'; if v in ('Algumas por pagar', 'Algumas por processar') then res := res || ('Requisições: ' || lower(v)); end if;
  if public.bsp_rel_n(r, 'reclamacoes') > 0 then res := res || ('Reclamações: ' || public.bsp_rel_n(r, 'reclamacoes')); end if;
  if jsonb_typeof(r->'documentos') = 'array' and not (r->'documentos' ? 'Nenhum') and jsonb_array_length(r->'documentos') > 0 then
    res := res || ('Documentos por regularizar no MetaGest: ' || (select string_agg(x, ', ') from jsonb_array_elements_text(r->'documentos') x));
  end if;
  v := r->>'fecho_caixa'; if v = 'Por enviar' then res := res || 'Fecho de caixa por enviar'::text; end if;
  v := r->>'tpa'; if v = 'Por enviar' then res := res || 'Fecho do TPA por enviar'::text; end if;
  v := r->>'mapas'; if v in ('Alguns em falta', 'Nenhum entregue') then res := res || ('Mapas dos médicos: ' || lower(v)); end if;
  -- Auditoria (30-10-2026).
  v := r->>'ciq'; if v is not null and v not like 'Feito, dentro%' then res := res || ('Controlo interno de qualidade: ' || lower(v)); end if;
  v := r->>'lote_novo'; if v like '%sem verificação%' then res := res || 'Lote novo de reagente usado sem verificação'::text; end if;
  if jsonb_typeof(r->'suspensos') = 'array' and not (r->'suspensos' ? 'Nenhum') and jsonb_array_length(r->'suspensos') > 0 then
    res := res || ('Exames suspensos: ' || (select string_agg(x, ', ') from jsonb_array_elements_text(r->'suspensos') x));
  end if;
  if public.bsp_rel_n(r, 'criticos') > public.bsp_rel_n(r, 'criticos_comunicados') then
    res := res || ('Valores críticos por comunicar ao médico: ' || (public.bsp_rel_n(r, 'criticos') - public.bsp_rel_n(r, 'criticos_comunicados')));
  end if;
  v := r->>'frio_accao'; if v like 'Fora%' then res := res || ('Frigorífico fora de 2–8 °C: ' || lower(substr(v, 7))); end if;
  v := r->>'carro_urgencia'; if v is not null and v <> 'Verificado e completo' then res := res || ('Carro de urgência: ' || lower(v)); end if;
  if public.bsp_rel_n(r, 'repetidos') > 0 then
    res := res || ('Raio-X repetidos: ' || public.bsp_rel_n(r, 'repetidos')
      || coalesce(' (' || (select string_agg(x, ', ') from jsonb_array_elements_text(case when jsonb_typeof(r->'repetidos_motivo') = 'array' then r->'repetidos_motivo' else '[]'::jsonb end) x where x <> 'Nenhum repetido') || ')', ''));
  end if;
  return res;
end $function$;
