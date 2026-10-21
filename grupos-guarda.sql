-- Grupos do Chat protegidos e alerta de perdas (21-10-2026, OWASP A01 e A09;
-- Elmar: «OWASP avance»).
-- A01: os grupos vivem em shared_state.channels, que cada posto grava inteiro.
-- Até aqui, qualquer colega com conhecimentos técnicos podia pôr-se como membro
-- de um grupo privado (DAF, direcção) e ler as mensagens. Agora, quem não é da
-- gestão só muda um grupo (membros, tipo, área, nome) se for membro dele ou o
-- tiver criado; só apaga os que criou; um grupo novo fica com o seu criadoPor.
-- O que não pode mudar, o gatilho repõe como estava (sem erro, para o resto da
-- gravação passar, como o bsp_estado_guarda faz com a equipa).
-- A09: se uma gravação tirar 2 ou mais grupos, entradas do Drive ou pessoas da
-- equipa, a gestão recebe logo um aviso no telemóvel e no sino (o incidente de
-- 18-10 só foi notado pelos utilizadores).
-- Substitui a função de canais-recuperar.sql (mesmo nome, mesmo gatilho).
-- Nas funções pela ferramenta, nunca as palavras que pedem confirmação.

create or replace function public.bsp_estado_canais_guarda()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  eu text;
  gestor boolean;
  velho jsonb;
  novo jsonb := '[]'::jsonb;
  c jsonb;
  o jsonb;
  n_antes int;
  n_depois int;
  perdas text[] := '{}';
begin
  -- Lista vazia nunca apaga dois ou mais (19-10-2026).
  if jsonb_typeof(old.channels) = 'array' and jsonb_array_length(old.channels) >= 2
     and (new.channels is null or jsonb_typeof(new.channels) <> 'array' or jsonb_array_length(new.channels) = 0) then
    new.channels := old.channels;
  end if;
  if jsonb_typeof(old.drive) = 'array' and jsonb_array_length(old.drive) >= 2
     and (new.drive is null or jsonb_typeof(new.drive) <> 'array' or jsonb_array_length(new.drive) = 0) then
    new.drive := old.drive;
  end if;

  -- Quem grava (sem sessão: tarefas do servidor, passam).
  if auth.uid() is not null and jsonb_typeof(old.channels) = 'array' and jsonb_typeof(new.channels) = 'array'
     and new.channels is distinct from old.channels then
    eu := public.bsp_meu_id();
    gestor := public.bsp_e_gestor();
    if not gestor then
      velho := old.channels;
      for c in select value from jsonb_array_elements(new.channels) loop
        select value into o from jsonb_array_elements(velho) where value->>'id' = c->>'id' limit 1;
        if o is null then
          -- Grupo novo: fica em nome de quem o cria.
          novo := novo || jsonb_build_array(c || jsonb_build_object('criadoPor', eu));
        elsif (c - 'unread') = (o - 'unread') then
          novo := novo || jsonb_build_array(c);
        elsif eu is not null and (o->>'criadoPor' = eu or coalesce(o->'membros', '[]'::jsonb) ? eu) then
          -- Membro ou criador: pode mudar, mas o criador não muda.
          novo := novo || jsonb_build_array(c || jsonb_strip_nulls(jsonb_build_object('criadoPor', o->'criadoPor')));
        else
          novo := novo || jsonb_build_array(o);
        end if;
      end loop;
      -- Grupos que desapareceram: só sai o que o próprio criou.
      for o in select value from jsonb_array_elements(velho) loop
        if not exists (select 1 from jsonb_array_elements(new.channels) x where x->>'id' = o->>'id')
           and coalesce(o->>'criadoPor', '') <> coalesce(eu, '-') then
          novo := novo || jsonb_build_array(o);
        end if;
      end loop;
      new.channels := novo;
    end if;
  end if;

  -- A09: aviso à gestão quando uma gravação tira 2 ou mais.
  n_antes := case when jsonb_typeof(old.channels) = 'array' then jsonb_array_length(old.channels) else 0 end;
  n_depois := case when jsonb_typeof(new.channels) = 'array' then jsonb_array_length(new.channels) else 0 end;
  if n_antes - n_depois >= 2 then perdas := perdas || ('grupos ' || n_antes || ' → ' || n_depois); end if;
  n_antes := case when jsonb_typeof(old.drive) = 'array' then jsonb_array_length(old.drive) else 0 end;
  n_depois := case when jsonb_typeof(new.drive) = 'array' then jsonb_array_length(new.drive) else 0 end;
  if n_antes - n_depois >= 2 then perdas := perdas || ('Drive ' || n_antes || ' → ' || n_depois); end if;
  n_antes := case when jsonb_typeof(old.team) = 'array' then jsonb_array_length(old.team) else 0 end;
  n_depois := case when jsonb_typeof(new.team) = 'array' then jsonb_array_length(new.team) else 0 end;
  if n_antes - n_depois >= 2 then perdas := perdas || ('equipa ' || n_antes || ' → ' || n_depois); end if;
  if cardinality(perdas) > 0 then
    insert into public.novidades (titulo, texto, grupos, destino) values (
      'Alerta: o estado partilhado perdeu conteúdo',
      'Uma gravação acabou de tirar ' || array_to_string(perdas, ', ') || ' (quem gravou: ' || coalesce(public.bsp_meu_id(), 'servidor') || '). '
        || 'Se não foi de propósito, repõe-se da cópia diária (canais-recuperar.sql).',
      array['gestao'], 'admin');
    perform public.bsp_push_post(jsonb_build_object('para', jsonb_build_array('u1', 'u2'),
      'titulo', 'Alerta: perda no estado partilhado', 'corpo', array_to_string(perdas, ', '),
      'url', '#/admin', 'tag', 'vigilancia-estado'));
  end if;
  return new;
end $$;
revoke all on function public.bsp_estado_canais_guarda() from public, anon, authenticated;
create or replace trigger bsp_estado_canais_guarda
  before update on public.shared_state
  for each row execute function public.bsp_estado_canais_guarda();
