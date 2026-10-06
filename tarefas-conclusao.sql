-- Tarefas delegadas: aviso ao concluir e lista das atrasadas de manhã
-- (06-10-2026, Elmar: «coloca botão concluído em cada uma delas para ela as
-- marcar como concluídas e me notificar todas as atrasadas de manhã e todas
-- concluídas assim que ela marcar»).
--
-- O prazo das tarefas privadas é texto AAAA-MM-DD: converte-se antes de comparar.
-- Uma tarefa privada delegada tem criada_por (quem delegou) diferente de
-- user_id (quem a faz). No ecrã, o botão «Concluída» passa-a para a coluna
-- done. Aqui:
--   · ao passar para done, quem delegou recebe logo um aviso no telemóvel e
--     no sino (novidade só para essa pessoa);
--   · todos os dias às 06h45 de Luanda, cada pessoa que delegou recebe a lista
--     das suas tarefas delegadas com o prazo passado e ainda por concluir.

create or replace function public.bsp_tarefa_concluida_aviso()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare quem text := public.bsp_nome_de(new.user_id);
begin
  if new.coluna = 'done' and old.coluna is distinct from 'done'
     and new.criada_por is not null and new.criada_por <> new.user_id then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Tarefa concluída: ' || quem,
            quem || ' concluiu «' || left(coalesce(new.titulo, ''), 160) || '» a '
              || to_char(now() at time zone 'Africa/Luanda', 'DD-MM-YYYY "às" HH24:MI') || '.',
            array[new.criada_por], 'tarefas');
    perform public.bsp_push_post(jsonb_build_object('para', jsonb_build_array(new.criada_por),
      'titulo', quem || ' · tarefa concluída', 'corpo', left(coalesce(new.titulo, ''), 160),
      'url', '#/tarefas', 'tag', 'tarefa-p' || new.id));
  end if;
  return null;
end $f$;

do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'bsp_tarefa_concluida_aviso') then
    create trigger bsp_tarefa_concluida_aviso after update of coluna on public.tarefas_pessoais
      for each row execute function public.bsp_tarefa_concluida_aviso();
  end if;
end $$;

create or replace function public.bsp_tarefas_atrasadas_alertar()
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare
  hoje date := (now() at time zone 'Africa/Luanda')::date;
  r record;
  n int := 0;
begin
  for r in
    with t as (select criada_por, user_id, titulo, coluna, prazo::date prazo
                 from public.tarefas_pessoais where prazo ~ '^\d{4}-\d{2}-\d{2}$')
    select t.criada_por,
           count(*) total,
           string_agg('• ' || public.bsp_nome_de(t.user_id) || ': ' || left(t.titulo, 120)
                      || ' (fim ' || to_char(t.prazo, 'DD-MM') || ', ' || (hoje - t.prazo)
                      || case when hoje - t.prazo = 1 then ' dia' else ' dias' end || ' de atraso)',
                      E'\n' order by t.prazo, t.user_id) linhas
      from t
     where t.criada_por is not null and t.criada_por <> t.user_id
       and t.coluna <> 'done' and t.prazo < hoje
     group by t.criada_por
  loop
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Tarefas delegadas atrasadas: ' || r.total, r.linhas, array[r.criada_por], 'tarefas');
    perform public.bsp_push_post(jsonb_build_object('para', jsonb_build_array(r.criada_por),
      'titulo', r.total || case when r.total = 1 then ' tarefa delegada atrasada' else ' tarefas delegadas atrasadas' end,
      'corpo', left(r.linhas, 300), 'url', '#/tarefas', 'tag', 'tarefas-atrasadas'));
    n := n + 1;
  end loop;
  return n;
end $f$;
revoke all on function public.bsp_tarefas_atrasadas_alertar() from public, anon, authenticated;

-- 06h45 de Luanda (05h45 UTC), todos os dias (o mesmo nome substitui o anterior).
select cron.schedule('bsp-tarefas-atrasadas', '45 5 * * *', $$select public.bsp_tarefas_atrasadas_alertar()$$);

-- Origem «emails» (06-10-2026, Elmar: «as tarefas ficam delegadas pelo sistema
-- e não por mim, diz que é com base nos e-mails trocados»). criada_por fica com
-- quem recebe os avisos; o ecrã mostra «Sistema (com base nos e-mails trocados)».
alter table public.tarefas_pessoais add column if not exists origem text;
update public.tarefas_pessoais set origem = 'emails' where id between 26 and 37 and criada_por = 'u1';
