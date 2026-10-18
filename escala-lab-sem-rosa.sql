-- Escala do Laboratório sem a Rosa Queirós (17-10-2026, Elmar: «Na escala
-- retire Rosa desde o dia que a Rosa saiu e coloque-os a rodar a Cássia e o
-- Nicolau»).
-- A Rosa Queirós (u13) saiu a 12-10-2026. Em todas as escalas do Laboratório
-- de Outubro em diante, a partir de 12-10, a Rosa sai de cada turno. Quem
-- entra, entre o Nicolau Castigo (u3) e a Cássia Peixoto (u19):
--   · se um deles já está no mesmo turno, ninguém entra;
--   · senão, entra quem não trabalha nesse dia (nunca dois turnos no mesmo dia);
--   · se os dois estão livres, entra quem não trabalhou na véspera (os dois
--     rodam dia sim, dia não);
--   · se os dois já trabalham nesse dia, ninguém entra.
-- Mudança aprovada pela gestão: o visto da Direcção Clínica mantém-se
-- (bsp.visto = '1', como em bsp_troca_decidir).
-- Aplicado a 17-10-2026 na escala de Outubro (id 10): 12 turnos.
-- Depois, Elmar: «Sem chefia»: tirado o t1 (Chefia) a 12, 13, 14, 15 e 30-10:
--   novos := jsonb_set(novos, array[dia], (novos -> dia) - 't1')  (com bsp.visto = '1').
-- Depois, Elmar (18-10): «todos aos turnos longos»: desde 12-10, t1, t2 e t4
-- juntos no t3 (Turno longo). Nicolau nos dias pares, Cássia nos ímpares.

do $$
declare
  e record;
  d text;
  t text;
  lista jsonb;
  dia_turnos jsonb;
  vespera jsonb;
  ocupados text[];
  ontem text[];
  quem text;
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
        dia_turnos := novos -> d;
        lista := dia_turnos -> t;
        if jsonb_typeof(lista) = 'array' and lista ? 'u13' then
          lista := lista - 'u13';
          select coalesce(array_agg(distinct p), '{}') into ocupados
            from jsonb_each(dia_turnos) x, jsonb_array_elements_text(case when jsonb_typeof(x.value) = 'array' then x.value else '[]' end) p
           where x.key <> '_n';
          vespera := novos -> to_char(d::date - 1, 'YYYY-MM-DD');
          select coalesce(array_agg(distinct p), '{}') into ontem
            from jsonb_each(coalesce(vespera, '{}')) x, jsonb_array_elements_text(case when jsonb_typeof(x.value) = 'array' then x.value else '[]' end) p
           where x.key <> '_n';
          quem := null;
          if not (lista ? 'u3' or lista ? 'u19') then
            if not ('u3' = any(ocupados)) and not ('u19' = any(ocupados)) then
              quem := case when 'u3' = any(ontem) and not ('u19' = any(ontem)) then 'u19'
                           when 'u19' = any(ontem) and not ('u3' = any(ontem)) then 'u3'
                           else 'u3' end;
            elsif not ('u3' = any(ocupados)) then quem := 'u3';
            elsif not ('u19' = any(ocupados)) then quem := 'u19';
            end if;
          end if;
          if quem is not null then lista := lista || to_jsonb(quem); end if;
          novos := jsonb_set(novos, array[d, t], lista);
          mudou := mudou + 1;
          raise notice '% % → %', d, t, coalesce(quem, '(ninguém)');
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
