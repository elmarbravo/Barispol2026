-- Escalas: quem aprova mantém o visto ao alterar (02-10-2026).
--
-- Antes, qualquer mudança de turnos ou dias apagava o visto. A 02-10-2026
-- a Direcção mudou a escala da Clínica de Outubro no ecrã e ela saiu de
-- vigor sem aviso: os médicos deixaram de a ver. Agora, uma mudança feita
-- pela gestão (bsp_e_gestor) ou pela Direcção Clínica (bsp_le_areas_medicas)
-- numa escala publicada que continua publicada mantém o visto e o
-- exige_visto. As mudanças dos chefes de área continuam a apagar o visto
-- (o ecrã avisa antes). Uma escala nova continua a pedir o visto.

create or replace function public.bsp_escalas_alterado()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  new.alterado_em := now();
  new.alterado_por := coalesce(public.bsp_meu_id(), new.alterado_por);
  if tg_op = 'INSERT' then new.criado_por := coalesce(public.bsp_meu_id(), new.criado_por); end if;
  if new.estado = 'publicada' and (tg_op = 'INSERT' or old.estado is distinct from 'publicada') then
    new.publicada_em := now();
    new.publicada_por := coalesce(public.bsp_meu_id(), new.publicada_por);
  end if;
  if coalesce(current_setting('bsp.visto', true), '') <> '1' then
    if tg_op = 'INSERT' then
      new.visto_em := null; new.visto_por := null; new.exige_visto := true;
    else
      new.visto_em := old.visto_em; new.visto_por := old.visto_por; new.exige_visto := old.exige_visto;
      if new.estado is distinct from old.estado or new.mes is distinct from old.mes or new.area is distinct from old.area
         or ((new.turnos is distinct from old.turnos or new.dias is distinct from old.dias)
             and not (public.bsp_e_gestor() or public.bsp_le_areas_medicas())) then
        new.visto_em := null; new.visto_por := null; new.exige_visto := true;
      end if;
    end if;
  end if;
  return new;
end $function$;
