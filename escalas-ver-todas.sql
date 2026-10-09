-- Escalas de todas as áreas para toda a equipa (09-10-2026, Elmar: «A escala
-- não aparece para todos no perfil da Solange… resolva para todos»; escolheu
-- «Todos vêem todas»).
--
-- Quem tem conta (menos os sócios) lê as escalas PUBLICADAS de todas as áreas.
-- Os rascunhos continuam só para quem vê a área (bsp_ve_escala: a própria
-- área e quem edita). Editar não muda (bsp_edita_escala).
-- No ecrã: bspVeEscala lista todas as áreas; o cartão «De serviço hoje» do
-- Início mostra toda a clínica.

alter policy bsp_escalas_ler on public.escalas to authenticated
  using (
    public.bsp_ve_escala(area)
    or (estado = 'publicada' and public.bsp_meu_id() is not null and not public.bsp_e_socio())
  );
