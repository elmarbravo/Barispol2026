-- Avarias e equipamentos por área (08-10-2026, Elmar: «As avarias apenas os da
-- mesma área e nós superiores vemos, não podem todos ver tudo»).
--
-- Avarias: lêem a gestão e os Serviços Gerais (bsp_trata_avarias), quem
-- reportou, a área de quem reportou, a área da avaria (coluna area), o
-- superior/chefe de quem reportou (bsp_chefe_de) e a Direcção Clínica (u14)
-- nas áreas de saúde.
-- Equipamentos, planos e registos de manutenção: a gestão e os Serviços
-- Gerais, a área do equipamento e a Direcção Clínica nas áreas de saúde.
-- Equipamento sem área (ar condicionado…) só quem trata as avarias.
-- Antes (03-10-2026) toda a equipa lia o inventário.
-- (alter policy: a ferramenta do servidor pára com a outra palavra)

alter policy avarias_ler on public.avarias to authenticated
  using (
    public.bsp_meu_id() is not null and not public.bsp_e_socio()
    and (
      (select public.bsp_trata_avarias())
      or criado_por = (select public.bsp_meu_id())
      or criado_por in (select unnest(public.bsp_ids_da_minha_area()))
      or (area <> '' and area = (select public.bsp_minha_area()))
      or ((select public.bsp_le_areas_medicas())
          and area in ('clinica', 'enfermagem', 'farmacia', 'laboratorio', 'radiologia'))
      or public.bsp_chefe_de(criado_por)
    )
  );

alter policy equipamentos_ler on public.equipamentos to authenticated
  using (
    public.bsp_meu_id() is not null and not public.bsp_e_socio()
    and (
      (select public.bsp_trata_avarias())
      or (area <> '' and area = (select public.bsp_minha_area()))
      or ((select public.bsp_le_areas_medicas())
          and area in ('clinica', 'enfermagem', 'farmacia', 'laboratorio', 'radiologia'))
    )
  );

-- Os planos e os registos seguem o equipamento (a regra de cima aplica-se
-- dentro da subconsulta).
alter policy plano_ler on public.manutencoes_plano to authenticated
  using (equipamento_id in (select id from public.equipamentos));

alter policy registo_ler on public.manutencoes_registo to authenticated
  using (equipamento_id in (select id from public.equipamentos));
