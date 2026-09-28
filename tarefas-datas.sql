-- Barispol Workspace · datas obrigatorias nas tarefas
-- Pedido do Elmar, 28-09-2026: todas as tarefas tem data de inicio e de
-- fim. Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia.
-- Pode correr-se mais do que uma vez.
--
-- tarefas_pessoais.prazo continua a ser a data de fim (texto AAAA-MM-DD);
-- inicio e a data de inicio, no mesmo formato. As tarefas da equipa
-- (shared_state.tasks) guardam as duas em start e due; ai quem obriga e o
-- ecra (TaskComposer), porque o estado partilhado e um so documento.

alter table public.tarefas_pessoais add column if not exists inicio text;

-- As que ja existiam: o inicio e o dia em que foram criadas.
update public.tarefas_pessoais
   set inicio = to_char(created_at at time zone 'Africa/Luanda', 'YYYY-MM-DD')
 where coalesce(inicio, '') = '';

-- Regra: uma tarefa nova tem as duas datas, e o fim nao vem antes do
-- inicio. Mudar so a coluna (mover no quadro) nao pede datas, para as
-- tarefas antigas sem fim continuarem a mexer-se; mudar as datas pede as
-- duas.
create or replace function public.bsp_tarefa_datas()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  if tg_op = 'INSERT'
     or new.inicio is distinct from old.inicio
     or new.prazo is distinct from old.prazo then
    if coalesce(new.inicio, '') !~ '^\d{4}-\d{2}-\d{2}$' or coalesce(new.prazo, '') !~ '^\d{4}-\d{2}-\d{2}$' then
      raise exception 'A tarefa precisa de data de início e de data de fim.';
    end if;
    if new.prazo < new.inicio then
      raise exception 'A data de fim não pode ser anterior à de início.';
    end if;
  end if;
  return new;
end $function$;

drop trigger if exists bsp_tarefa_datas on public.tarefas_pessoais;
create trigger bsp_tarefa_datas before insert or update on public.tarefas_pessoais
  for each row execute function public.bsp_tarefa_datas();

-- Aviso a toda a equipa (sai as 05h00).
insert into public.novidades (titulo, texto, grupos, destino)
select 'Tarefas com data de início e de fim',
       'Todas as tarefas novas passam a ter data de início e data de fim, obrigatórias. O cartão mostra as duas. As tarefas antigas sem data de fim ficam assinaladas: ao editá-las, preencha as duas datas.',
       array['todos'], 'tarefas'
 where not exists (select 1 from public.novidades where titulo = 'Tarefas com data de início e de fim');

notify pgrst, 'reload schema';
