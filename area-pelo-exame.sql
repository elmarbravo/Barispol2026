-- Área de cada exame pelo nome, e não só pelo grupo do MetaGest (06-10-2026).
--
-- Elmar: «ECG, MAPA e Holter são da Imagiologia?» … «O MetaGest pode estar
-- errado». São exames de Cardiologia. No MetaGest há um ECG no grupo
-- ENFERMAGEM e um ecocardiograma no grupo ECOGRAFIA; e o relatório da
-- Direcção Clínica (erp.direccao_clinica_dados) contava todo o grupo
-- CARDIOLOGIA como «exames de imagem».
--
-- erp.grupo_item(grupo, nome) devolve o grupo corrigido: os exames do coração
-- vão sempre para CARDIOLOGIA, seja qual for o grupo do MetaGest; o resto fica
-- como vem. Usado no Painel (facturação por área), nos números clínicos
-- (erp.clinico_dados), no relatório da Direcção (erp.direccao_dados) e no da
-- Direcção Clínica, onde a Cardiologia deixa de contar como imagem.
--
-- O pagamento dos médicos (bsp_pagamento_linhas) NÃO muda aqui: mexe em
-- valores pagos e espera a decisão do Elmar.
--
-- Cada função é alterada sobre a versão que está no servidor; se o texto
-- esperado não estiver lá, essa função fica como está e sai um aviso.

create or replace function erp.grupo_item(p_grupo text, p_nome text)
returns text language sql immutable as $f$
  select case
    when coalesce(p_nome, '') ~* '(\mECG\M|ELE[C]?TROCARDIO|ECOCARDIO|\mHOLTER\M|^\s*MAPA\M|PROVA DE ESFOR)' then 'CARDIOLOGIA'
    else p_grupo end
$f$;
grant execute on function erp.grupo_item(text, text) to authenticated, service_role;

-- Painel: facturação por área.
do $$ declare d text; n text;
begin
  d := pg_get_functiondef('public.bsp_painel(date,date)'::regprocedure);
  n := replace(d, 'select i.grupo, i.valor from crm.mg_factura_itens i', 'select erp.grupo_item(i.grupo, i.item_nome) grupo, i.valor from crm.mg_factura_itens i');
  n := replace(n, 'select i.item_group, i.amount from erp.sales_invoice_item i', 'select erp.grupo_item(i.item_group, i.item_name) grupo, i.amount from erp.sales_invoice_item i');
  if n = d or position('erp.grupo_item(i.grupo' in n) = 0 or position('erp.grupo_item(i.item_group' in n) = 0 then
    raise notice 'bsp_painel: texto esperado não encontrado, não mudou';
  else execute n; end if;
end $$;

-- Números clínicos (Painel clínico, relatórios das áreas).
do $$ declare d text; n text;
begin
  d := pg_get_functiondef('erp.clinico_dados(date,date)'::regprocedure);
  n := regexp_replace(d, 'when i\.item_group ~\* ', 'when erp.grupo_item(i.item_group, i.item_name) ~* ', 'g');
  if n = d then raise notice 'erp.clinico_dados: texto esperado não encontrado, não mudou';
  else execute n; end if;
end $$;

-- Relatório da Direcção: facturação por serviço.
do $$ declare d text; n text;
begin
  d := pg_get_functiondef('erp.direccao_dados(date)'::regprocedure);
  n := replace(d, 'coalesce(nullif(btrim(i.item_group), ''''), ''Outros'')', 'coalesce(nullif(btrim(erp.grupo_item(i.item_group, i.item_name)), ''''), ''Outros'')');
  if n = d then raise notice 'erp.direccao_dados: texto esperado não encontrado, não mudou';
  else execute n; end if;
end $$;

-- Relatório da Direcção Clínica: a Cardiologia deixa de ser «imagem».
do $$ declare d text; n text;
begin
  d := pg_get_functiondef('erp.direccao_clinica_dados(date)'::regprocedure);
  n := regexp_replace(d, 'when i\.item_group ~\* ', 'when erp.grupo_item(i.item_group, i.item_name) ~* ', 'g');
  n := replace(n, '~* ''RAIO|ECOGRAF|CARDIO'' then ''imagem''', '~* ''CARDIO'' then ''cardiologia''
                when erp.grupo_item(i.item_group, i.item_name) ~* ''RAIO|ECOGRAF'' then ''imagem''');
  if n = d or position('then ''cardiologia''' in n) = 0 then
    raise notice 'erp.direccao_clinica_dados: texto esperado não encontrado, não mudou';
  else execute n; end if;
end $$;

notify pgrst, 'reload schema';
