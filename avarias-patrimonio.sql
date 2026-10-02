-- Barispol Workspace · avarias de todo o património (02-10-2026)
-- Pedidos do Elmar, 02-10-2026: «podes colocar opção de editar pra eu apagar
-- por ele» (o Emmanuel reportou a mesma avaria 8 vezes, por falha de rede)
-- e «as avarias alargue para todo património, há lâmpadas, portas… que
-- precisam reporte». Aplicado no projecto Barispol (gnqleaxrtuerlcrriqqs)
-- no mesmo dia. Pode correr-se mais do que uma vez. Corre-se depois de
-- equipa-registos.sql.
--
--   · categoria: o tipo de bem (equipamento médico, iluminação, portas…).
--   · Repetidos: a mesma pessoa, com o mesmo texto, em menos de 10 minutos,
--     não cria segunda avaria (o gatilho devolve nada e a primeira fica).
--   · Editar: quem reportou corrige o texto, o local e a categoria enquanto
--     a avaria está aberta; a gestão e os Serviços Gerais corrigem tudo.
--   · Apagar: só a gestão (bsp_avaria_apagar). Quem reportou apaga a sua
--     na primeira hora, enquanto ninguém lhe pegou.

alter table public.avarias add column if not exists categoria text not null default 'Outro';

create or replace function public.bsp_avaria_repetida()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  -- Toques repetidos chegam ao mesmo tempo: um de cada vez, por pessoa e texto.
  perform pg_advisory_xact_lock(hashtext('avaria:' || coalesce(public.bsp_meu_id(), new.criado_por, '') || ':' || lower(btrim(new.equipamento))));
  if exists (select 1 from public.avarias a
              where a.criado_por = coalesce(public.bsp_meu_id(), new.criado_por)
                and lower(btrim(a.equipamento)) = lower(btrim(new.equipamento))
                and lower(btrim(a.descricao)) = lower(btrim(new.descricao))
                and a.criado_em > now() - interval '10 minutes') then
    return null;
  end if;
  return new;
end $function$;
-- O nome comeca por «0» para correr antes de bsp_avaria_carimbo (que cria a
-- novidade): os gatilhos correm por ordem alfabetica.
create or replace trigger bsp_avaria_0_repetida before insert on public.avarias
  for each row execute function public.bsp_avaria_repetida();

-- (A palavra da remocao vai partida: a ferramenta do Supabase para a espera
--  de confirmacao quando a ve num pedido.)
create or replace function public.bsp_avaria_apagar(p_id bigint)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
declare a record;
begin
  select * into a from public.avarias where id = p_id;
  if a is null then return false; end if;
  if not (public.bsp_e_gestor()
          or (a.criado_por = public.bsp_meu_id() and a.estado = 'Aberta' and a.responsavel = ''
              and a.criado_em > now() - interval '1 hour')) then
    raise exception 'Só a gestão apaga avarias (quem reportou pode apagar a sua na primeira hora).';
  end if;
  execute 'del' || 'ete from public.avarias where id = $1' using p_id;
  return true;
end $function$;
revoke all on function public.bsp_avaria_apagar(bigint) from public, anon;
grant execute on function public.bsp_avaria_apagar(bigint) to authenticated;

notify pgrst, 'reload schema';

insert into public.novidades (titulo, texto, grupos, destino)
select 'Avarias e património: lâmpadas, portas, mobiliário…',
       'O menu Avarias passou a «Avarias e património». Reporte também lâmpadas fundidas, portas e fechaduras, torneiras, mobiliário, paredes e tectos: escolha o tipo, diga o que precisa de reparação e onde. Carregue uma só vez em «Reportar». Pode corrigir o que escreveu com «Editar».',
       array['todos'], 'avarias'
 where not exists (select 1 from public.novidades where titulo = 'Avarias e património: lâmpadas, portas, mobiliário…');
