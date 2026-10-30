-- Anexos do relatório de turno (30-10-2026, Elmar: «os anexos podem ir
-- directamente no Workspace»; «parem de enviar no chat e mandem só no
-- relatório»). Requisições, folhas diárias e fotografias do BS-200 sobem com o
-- relatório para o contentor drive, no caminho
--   relatorio/<área>/<id de quem entrega>/<carimbo>/<ficheiro>
-- e guardam-se em relatorios_area.respostas.ficheiros ([{path, name, size}]).
-- Quem lê é quem lê o relatório (bsp_rel_ler): o próprio, a gestão e, nas áreas
-- médicas, a Direcção Clínica. O e-mail do relatório só leva os nomes.
-- As regras gerais do drive deixam de valer para relatorio/ (antes, um caminho
-- sem prefixo conhecido era de toda a equipa).

alter policy bsp_drive_ler on storage.objects using (
  (not public.bsp_e_socio()) and bucket_id = 'drive' and (
    (name not like 'privado/%' and name not like 'conversa/%' and name not like 'relatorio/%')
    or (name like 'privado/%' and (split_part(name, '/', 2) = public.bsp_meu_id() or public.bsp_ve_pessoais_de_todos()))
    or (name like 'conversa/%' and public.bsp_ve_conversa(split_part(name, '/', 2)))
    or (name like 'relatorio/%' and (
          split_part(name, '/', 3) = public.bsp_meu_id()
          or public.bsp_e_gestor()
          or (split_part(name, '/', 2) in ('laboratorio', 'imagiologia', 'enfermagem') and public.bsp_le_areas_medicas())))
  ));

alter policy bsp_drive_criar on storage.objects with check (
  bucket_id = 'drive' and (
    (name not like 'privado/%' and name not like 'conversa/%' and name not like 'equipa/%' and name not like 'documentos/%' and name not like 'relatorio/%')
    or (name like 'privado/%' and split_part(name, '/', 2) = public.bsp_meu_id())
    or (name like 'equipa/%' and split_part(name, '/', 2) = public.bsp_meu_id())
    or (name like 'conversa/%' and public.bsp_ve_conversa(split_part(name, '/', 2)))
    or (name like 'documentos/%' and public.bsp_publica_documentos())
    or (name like 'relatorio/%' and split_part(name, '/', 3) = public.bsp_meu_id()
        and split_part(name, '/', 2) in ('rececao', 'farmacia', 'laboratorio', 'imagiologia', 'enfermagem'))
  ));

alter policy bsp_drive_apagar on storage.objects using (
  bucket_id = 'drive' and (
    (name not like 'privado/%' and name not like 'conversa/%' and name not like 'equipa/%' and name not like 'documentos/%' and name not like 'relatorio/%')
    or (name like 'privado/%' and split_part(name, '/', 2) = public.bsp_meu_id())
    or (name like 'equipa/%' and (split_part(name, '/', 2) = public.bsp_meu_id() or public.bsp_pode_apagar_ficheiros()))
    or (name like 'conversa/%' and public.bsp_ve_conversa(split_part(name, '/', 2)))
    or (name like 'documentos/%' and public.bsp_publica_documentos())
    or (name like 'relatorio/%' and (split_part(name, '/', 3) = public.bsp_meu_id() or public.bsp_e_gestor()))
  ));
