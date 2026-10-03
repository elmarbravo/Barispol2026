-- Satisfação, espera e auditorias no relatório diário da Direcção
-- (03-10-2026, Elmar: «A satisfação e a espera no relatório diário, para a
-- Direcção ver todas as manhãs»). A Edge Function relatorios-diarios
-- (versão 12) chama bsp_srv_qualidade_direccao(dia) com a chave do servidor.
-- Sem nomes de utentes: só contagens, médias e medianas.

create or replace function public.bsp_srv_qualidade_direccao(p_dia date)
returns jsonb language sql stable security definer set search_path to 'public', 'erp'
as $f$
  with hoje as (select (now() at time zone 'Africa/Luanda')::date d),
  fb as (select * from public.feedback_utentes where criado_em::date between p_dia - 29 and p_dia),
  e as (
    select dia,
           case when consulta - triagem between interval '0' and interval '6 hours' then extract(epoch from consulta - triagem) / 60 end consulta_min,
           case when saida - triagem between interval '1 minute' and interval '8 hours' then extract(epoch from saida - triagem) / 60 end estadia_min
      from erp.espera_utente where dia between p_dia - 29 and p_dia
  )
  select jsonb_build_object(
    'satisfacao', (select jsonb_build_object(
        'avaliacoes', count(nota),
        'media', round(avg(nota)::numeric, 2),
        'baixas', count(*) filter (where nota <= 2),
        'elogios', count(*) filter (where tipo = 'elogio'),
        'reclamacoes', count(*) filter (where tipo = 'reclamacao'),
        'do_dia', count(*) filter (where criado_em::date = p_dia)) from fb),
    'reclamacoes_abertas', (select count(*) from public.feedback_utentes where tipo = 'reclamacao' and estado <> 'Fechada'),
    'reclamacoes_fora_prazo', (select count(*) from public.feedback_utentes where tipo = 'reclamacao' and estado <> 'Fechada' and prazo < (select d from hoje)),
    'por_tratar', (select count(*) from public.feedback_utentes where estado = 'Nova'),
    'espera_dia', (select jsonb_build_object(
        'n', count(estadia_min),
        'estadia', round((percentile_cont(0.5) within group (order by estadia_min))::numeric, 0),
        'mais_2h', count(*) filter (where estadia_min > 120),
        'consultas', count(consulta_min),
        'consulta', round((percentile_cont(0.5) within group (order by consulta_min))::numeric, 0)) from e where dia = p_dia),
    'espera_30', (select jsonb_build_object(
        'n', count(estadia_min),
        'estadia', round((percentile_cont(0.5) within group (order by estadia_min))::numeric, 0),
        'pc_mais_2h', round(100.0 * count(*) filter (where estadia_min > 120) / nullif(count(estadia_min), 0), 0),
        'consulta', round((percentile_cont(0.5) within group (order by consulta_min))::numeric, 0)) from e),
    'incidentes_abertos', (select count(*) from public.ocorrencias where estado <> 'Fechada'),
    'auditorias_atraso', (select count(*) from public.auditoria_modelos m where m.activo
        and coalesce((select max(a.dia) from public.auditorias a where a.modelo_id = m.id) + m.periodicidade, (select d from hoje) - 1) < (select d from hoje)),
    'auditorias_dia', (select jsonb_build_object('feitas', count(*), 'falhas', coalesce(sum(falhas), 0)) from public.auditorias where dia = p_dia)
  )
$f$;
revoke execute on function public.bsp_srv_qualidade_direccao(date) from public, anon, authenticated;
