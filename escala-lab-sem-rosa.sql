-- Escala do Laboratório sem a Rosa Queirós (17-10-2026, Elmar: «Na escala
-- retire Rosa desde o dia que a Rosa saiu e coloque-os a rodar a Cássia e o
-- Nicolau»).
-- A Rosa Queirós (u13) saiu a 12-10-2026. Em todas as escalas do Laboratório
-- de Outubro em diante, a partir de 12-10, cada turno onde estava a Rosa passa
-- para o Nicolau Castigo (u3) e para a Cássia Peixoto (u19), à vez, por ordem
-- de dia e de turno. Se a pessoa da vez já está nesse turno, entra a outra; se
-- as duas já lá estão, a Rosa sai e ninguém entra.
-- Mudança aprovada pela gestão: o visto da Direcção Clínica mantém-se
-- (bsp.visto = '1', como em bsp_troca_decidir).
-- Por aplicar: o conector do Supabase estava na conta errada a 17-10-2026.

do $$
declare
  e record;
  d text;
  t text;
  lista jsonb;
  vez int := 0;
  quem text;
  outro text;
  novos jsonb;
  mudou int := 0;
begin
  perform set_config('bsp.visto', '1', true);
  for e in
    select id, dias from public.escalas
     where public.bsp_area_chave(area) = 'laboratorio' and mes >= date '2026-10-01'
     order by mes
  loop
    novos := e.dias;
    for d in select k from jsonb_object_keys(e.dias) k where k >= '2026-10-12' order by k loop
      for t in select k from jsonb_object_keys(e.dias -> d) k where k <> '_n' order by k loop
        lista := e.dias -> d -> t;
        if jsonb_typeof(lista) = 'array' and lista ? 'u13' then
          quem := case when vez % 2 = 0 then 'u3' else 'u19' end;
          outro := case when quem = 'u3' then 'u19' else 'u3' end;
          lista := lista - 'u13';
          if not lista ? quem then
            lista := lista || to_jsonb(quem);
          elsif not lista ? outro then
            lista := lista || to_jsonb(outro);
          end if;
          vez := vez + 1;
          mudou := mudou + 1;
          novos := jsonb_set(novos, array[d, t], lista);
        end if;
      end loop;
    end loop;
    if novos is distinct from e.dias then
      update public.escalas set dias = novos where id = e.id;
    end if;
  end loop;
  perform set_config('bsp.visto', '', true);
  raise notice 'Turnos mudados: %', mudou;
end $$;

-- Confirmar: nenhum turno do Laboratório com a Rosa desde 12-10.
-- select e.mes, d.key, t.key, t.value
--   from public.escalas e, jsonb_each(e.dias) d, jsonb_each(d.value) t
--  where public.bsp_area_chave(e.area) = 'laboratorio' and d.key >= '2026-10-12'
--    and t.key <> '_n' and t.value ? 'u13';
