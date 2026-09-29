-- Barispol Workspace · lembrete da marcacao ao paciente, por e-mail
-- Pedido e texto aprovados pelo Elmar a 28-09-2026. Aplicado no projecto
-- Barispol (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do
-- que uma vez.
--
-- O e-mail nao sai quando se faz a marcacao: sai na vespera, as 10h00 de
-- Luanda (bsp-marcacoes-lembrete, tipo "marcacoes" da resumo-matinal),
-- para cada marcacao Agendada ou Confirmada do dia seguinte com e-mail.
-- Vai sempre com rececao@barispol.com em copia e com o link do GPS.
-- Cada marcacao recebe um so lembrete (marcacoes_lembretes). Se a data ou
-- a hora mudarem depois do envio, sai outro para a data nova.
-- Nomes e e-mails de pacientes ficam so no servidor.

create table if not exists public.marcacoes_lembretes (
  marcacao_id bigint not null references public.marcacoes(id) on delete cascade,
  data_marcada date not null,
  hora text not null default '',
  email text not null,
  reclamado_em timestamptz not null default now(),
  enviado boolean,
  primary key (marcacao_id, data_marcada, hora)
);
alter table public.marcacoes_lembretes enable row level security;
-- Quem ve as marcacoes ve se o lembrete saiu.
drop policy if exists bsp_marc_lembretes_ler on public.marcacoes_lembretes;
create policy bsp_marc_lembretes_ler on public.marcacoes_lembretes
  for select to authenticated using (public.bsp_ve_marcacoes());

-- Marca como enviados, antes do envio, os lembretes de um dia e devolve-os.
-- Assim um agendamento repetido nao manda o mesmo e-mail duas vezes.
create or replace function public.bsp_marc_lembretes_reclamar(p_dia date)
returns table (marcacao_id bigint, nome text, email text, data_marcada date, hora text, acto text, medico text)
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  return query
  with novos as (
    insert into public.marcacoes_lembretes as l (marcacao_id, data_marcada, hora, email)
    select m.id, m.data_marcada, coalesce(m.hora, ''), lower(btrim(m.email))
      from public.marcacoes m
     where m.data_marcada = p_dia
       and m.estado in ('Agendada', 'Confirmada')
       and coalesce(btrim(m.email), '') ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
    on conflict do nothing
    returning l.marcacao_id
  )
  select m.id, m.nome, lower(btrim(m.email)), m.data_marcada, coalesce(m.hora, ''), m.acto, m.medico
    from public.marcacoes m join novos n on n.marcacao_id = m.id
   order by m.hora;
end $function$;
revoke all on function public.bsp_marc_lembretes_reclamar(date) from public, anon, authenticated;
grant execute on function public.bsp_marc_lembretes_reclamar(date) to service_role;

create or replace function public.bsp_marc_lembrete_registar(p_id bigint, p_dia date, p_ok boolean)
returns void
language sql
security definer
set search_path to 'public'
as $function$
  update public.marcacoes_lembretes set enviado = p_ok
   where marcacao_id = p_id and data_marcada = p_dia;
$function$;
revoke all on function public.bsp_marc_lembrete_registar(bigint, date, boolean) from public, anon, authenticated;
grant execute on function public.bsp_marc_lembrete_registar(bigint, date, boolean) to service_role;

-- Todos os dias as 10h00 de Luanda (09h00 UTC): as marcacoes de amanha.
do $$
declare
  comando text := $cmd$
    select net.http_post(
      url     := 'https://gnqleaxrtuerlcrriqqs.supabase.co/functions/v1/resumo-matinal',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'x-bsp-agendamento', (select decrypted_secret from vault.decrypted_secrets
                                         where name = 'bsp_resumo_agendamento' limit 1)),
      body    := '{"tipo":"marcacoes"}'::jsonb
    );
  $cmd$;
begin
  perform cron.unschedule('bsp-marcacoes-lembrete') where exists (select 1 from cron.job where jobname = 'bsp-marcacoes-lembrete');
  perform cron.schedule('bsp-marcacoes-lembrete', '0 9 * * *', comando);
end $$;

insert into public.novidades (titulo, texto, grupos, destino)
select 'Lembrete por e-mail aos pacientes',
       'Na véspera de cada marcação, às 10h00, o paciente com e-mail recebe um lembrete com a data, a hora, o acto e o link do GPS para a clínica. A recepção (rececao@barispol.com) recebe cópia de todos. Preencha sempre o e-mail do paciente na marcação.',
       array['recepcao', 'gestao'], 'marcacoes'
 where not exists (select 1 from public.novidades where titulo = 'Lembrete por e-mail aos pacientes');

-- Lembretes para a Recepcao (29-09-2026): 1 hora antes de cada marcacao
-- e 30 minutos depois, no ecra Marcacoes e no sino. Correm no Workspace
-- (MarcLembretes e o efeito junto das novidades do sino); nada no servidor alem
-- desta novidade.
insert into public.novidades (titulo, texto, grupos, destino)
select 'Lembretes das marcações',
       'O ecrã Marcações mostra no topo os lembretes de hoje. Uma hora antes de cada marcação: ligue ao paciente para confirmar e avise o médico. Trinta minutos depois da hora, se continuar «Agendada» ou «Confirmada»: ligue e actualize o estado (Compareceu, Faltou, Remarcado ou Cancelou). Quem é da Recepção recebe também um aviso no sino, com som.',
       array['recepcao', 'gestao'], 'marcacoes'
 where not exists (select 1 from public.novidades where titulo = 'Lembretes das marcações');

notify pgrst, 'reload schema';
