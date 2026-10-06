-- Avisos das férias a quem pediu e e-mail na aprovação (06-10-2026, Elmar:
-- «os pedidos de férias devem vir pop ups a quem deve aprovar e a quem pediu
-- depois de aprovada»; «e um e-mail após aprovação com RH em cc»).
-- Corre-se depois de ferias-aprovacao-final.sql.
--
-- Quem deve aprovar já recebia sino + telemóvel + janela de avisos
-- (bsp_ausencia_avisar, etiqueta ferias-<id>). Agora quem pediu também recebe
-- os três: quando o 1.º passo é dado e na decisão final (aprovado ou recusado).
-- Na aprovação final sai um e-mail a quem pediu, com os RH (Arlete) em cópia,
-- no aspecto dos e-mails do site (bsp_envelope). Fica de fora quem não recebe
-- e-mails (bsp_recebe_emails). Um erro no e-mail nunca impede a aprovação.

create or replace function public.bsp_ausencia_email_aprovado(a public.ausencias, p_quem text)
returns void language plpgsql security definer set search_path to 'public'
as $f$
declare
  para text; cc text; rh text := public.bsp_ferias_rh();
  dias int := (a.fim - a.inicio) + 1;
begin
  select e->>'email' into para from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and e->>'id' = a.user_id and public.bsp_recebe_emails(e);
  select e->>'email' into cc from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
   where s.id = 1 and e->>'id' = rh;
  if coalesce(para, '') = '' then
    if coalesce(cc, '') = '' then return; end if;
    para := cc; cc := null;
  end if;
  if lower(coalesce(cc, '')) = lower(para) then cc := null; end if;
  perform public.bsp_enviar_email(array[para], case when cc is null then '{}'::text[] else array[cc] end, '{}'::text[],
    'Pedido de ' || lower(a.tipo) || ' aprovado: ' || to_char(a.inicio, 'DD-MM-YYYY') || ' a ' || to_char(a.fim, 'DD-MM-YYYY'),
    public.bsp_envelope('Pedido de ' || lower(a.tipo) || ' aprovado',
      '<p style="margin:0 0 12px">Olá, ' || public.bsp_html(split_part(public.bsp_nome_de(a.user_id), ' ', 1)) || '.</p>'
      || '<p style="margin:0 0 12px">O seu pedido de ' || public.bsp_html(lower(a.tipo)) || ' foi aprovado.</p>'
      || '<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 14px;border-collapse:collapse">'
      || '<tr><td style="padding:6px 0;border-bottom:1px solid #E5E7EB;width:40%">Colaborador</td><td style="padding:6px 0;border-bottom:1px solid #E5E7EB"><b>' || public.bsp_html(public.bsp_nome_de(a.user_id)) || '</b></td></tr>'
      || '<tr><td style="padding:6px 0;border-bottom:1px solid #E5E7EB">Tipo</td><td style="padding:6px 0;border-bottom:1px solid #E5E7EB">' || public.bsp_html(a.tipo) || '</td></tr>'
      || '<tr><td style="padding:6px 0;border-bottom:1px solid #E5E7EB">Primeiro dia</td><td style="padding:6px 0;border-bottom:1px solid #E5E7EB">' || to_char(a.inicio, 'DD-MM-YYYY') || '</td></tr>'
      || '<tr><td style="padding:6px 0;border-bottom:1px solid #E5E7EB">Último dia</td><td style="padding:6px 0;border-bottom:1px solid #E5E7EB">' || to_char(a.fim, 'DD-MM-YYYY') || ' (' || dias || case when dias = 1 then ' dia' else ' dias' end || ' de calendário)</td></tr>'
      || case when a.superior_ok_por is not null then '<tr><td style="padding:6px 0;border-bottom:1px solid #E5E7EB">1.º passo</td><td style="padding:6px 0;border-bottom:1px solid #E5E7EB">' || public.bsp_html(public.bsp_nome_de(a.superior_ok_por)) || ', ' || to_char(a.superior_ok_em at time zone 'Africa/Luanda', 'DD-MM-YYYY HH24:MI') || '</td></tr>' else '' end
      || '<tr><td style="padding:6px 0">Aprovação final</td><td style="padding:6px 0">' || public.bsp_html(public.bsp_nome_de(p_quem)) || ', ' || to_char(now() at time zone 'Africa/Luanda', 'DD-MM-YYYY HH24:MI') || '</td></tr></table>'
      || '<p style="margin:0">Pode consultar o pedido no Workspace, em Equipa → Férias e ausências.</p>',
      'Clínica Barispol, Lda. · Recursos Humanos'));
exception when others then
  raise warning 'bsp_ausencia_email_aprovado: %', sqlerrm;
end $f$;
revoke all on function public.bsp_ausencia_email_aprovado(public.ausencias, text) from public, anon, authenticated;

create or replace function public.bsp_ausencia_decidir(p_id bigint, p_estado text, p_motivo text default '')
returns void language plpgsql security definer set search_path to 'public'
as $f$
declare
  a public.ausencias;
  eu text := public.bsp_meu_id();
  fin text;
  passo int;
  periodo text;
begin
  select * into a from public.ausencias where id = p_id for update;
  if not found then raise exception 'Pedido não encontrado.'; end if;
  fin := coalesce(a.final_id, public.bsp_ferias_rh());
  periodo := to_char(a.inicio, 'DD-MM-YYYY') || ' a ' || to_char(a.fim, 'DD-MM-YYYY');

  if p_estado = 'Cancelado' then
    if a.user_id <> eu and not public.bsp_chefe_de(a.user_id) then raise exception 'Só quem pediu cancela.'; end if;
    update public.ausencias set estado = 'Cancelado', decidido_por = eu, decidido_em = now() where id = p_id;
    return;
  end if;
  if p_estado not in ('Aprovado', 'Recusado') then raise exception 'Estado inválido.'; end if;
  if a.user_id = eu then raise exception 'Não pode decidir o seu próprio pedido.'; end if;

  if a.estado = 'Pedido' and a.superior_id is not null and a.superior_ok_em is null then passo := 1;
  elsif a.estado = 'Pedido' then passo := 2;
  else raise exception 'Este pedido já foi decidido.'; end if;

  if passo = 1 and eu not in (a.superior_id, 'u1') then
    raise exception 'Falta primeiro a aprovação de %.', public.bsp_nome_de(a.superior_id);
  end if;
  if passo = 2 and eu not in (fin, 'u1') then
    raise exception 'A aprovação final é de %.', public.bsp_nome_de(fin);
  end if;

  if passo = 1 and p_estado = 'Aprovado' then
    update public.ausencias set superior_ok_por = eu, superior_ok_em = now() where id = p_id;
    perform public.bsp_ausencia_avisar(a, fin,
      'Férias para aprovar: ' || public.bsp_nome_de(a.user_id),
      public.bsp_nome_de(eu) || ' aprovou o pedido de ' || lower(a.tipo) || ' de ' || public.bsp_nome_de(a.user_id)
      || ' (' || periodo || '). Falta a sua aprovação final.');
    perform public.bsp_ausencia_avisar(a, a.user_id,
      'O seu pedido de ' || lower(a.tipo) || ' passou o 1.º passo',
      public.bsp_nome_de(eu) || ' aprovou o pedido de ' || periodo || '. Falta a aprovação de ' || public.bsp_nome_de(fin) || '.');
    return;
  end if;

  update public.ausencias set estado = p_estado, decidido_por = eu, decidido_em = now(), motivo = coalesce(p_motivo, '')
   where id = p_id;
  perform public.bsp_ausencia_avisar(a, a.user_id,
    'O seu pedido de ' || lower(a.tipo) || ' foi ' || lower(p_estado),
    public.bsp_nome_de(eu) || ' ' || lower(p_estado) || ' o pedido de ' || periodo || '.'
    || case when coalesce(p_motivo, '') <> '' then ' Motivo: ' || p_motivo else '' end);
  if p_estado = 'Aprovado' then
    select * into a from public.ausencias where id = p_id;
    perform public.bsp_ausencia_email_aprovado(a, eu);
  end if;
  if p_estado = 'Recusado' and a.superior_ok_por is not null and a.superior_ok_por <> eu then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Pedido recusado: ' || public.bsp_nome_de(a.user_id), public.bsp_nome_de(eu) || ' recusou. ' || coalesce(nullif(p_motivo, ''), 'Sem motivo.'),
            array[a.superior_ok_por], 'directory');
  end if;
end $f$;
revoke all on function public.bsp_ausencia_decidir(bigint, text, text) from public, anon;
grant execute on function public.bsp_ausencia_decidir(bigint, text, text) to authenticated;

notify pgrst, 'reload schema';
