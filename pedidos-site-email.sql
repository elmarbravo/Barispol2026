-- Pedidos do site também por e-mail (30-10-2026, Elmar: «fiz pedido e não chegou
-- email»). Cada pedido de contacto do site (pedidos_marcacao) manda um e-mail a
-- rececao@barispol.com, com geral@barispol.com em cópia, além do aviso no
-- telemóvel da Recepção. O e-mail fica só na caixa da clínica; o pedido trata-se no
-- Workspace (Utentes → Marcações → «Pedidos do site»).

create or replace function public.bsp_pedido_site_email(p public.pedidos_marcacao)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  td text := 'padding:6px 0;border-bottom:1px solid #E5E7EB;vertical-align:top';
  linha text := '';
  quando text := to_char(p.criado_em at time zone 'Africa/Luanda', 'DD-MM-YYYY, HH24:MI');
begin
  linha := '<tr><td style="' || td || ';width:34%">Nome</td><td style="' || td || '"><b>' || public.bsp_html(coalesce(p.nome, '')) || '</b></td></tr>'
    || '<tr><td style="' || td || '">Telemóvel</td><td style="' || td || '"><a href="tel:' || public.bsp_html(coalesce(p.telefone, '')) || '">' || public.bsp_html(coalesce(p.telefone, '')) || '</a>'
    || case when coalesce(p.familiar_quem, '') <> '' then ' (de ' || public.bsp_html(p.familiar_quem) || ')' else '' end || '</td></tr>'
    || case when coalesce(p.telefone_proprio, '') <> '' then '<tr><td style="' || td || '">Telemóvel do próprio</td><td style="' || td || '">' || public.bsp_html(p.telefone_proprio) || '</td></tr>' else '' end
    || '<tr><td style="' || td || '">Precisa de</td><td style="' || td || '">' || public.bsp_html(coalesce(nullif(p.servico, ''), 'Não indicou')) || '</td></tr>'
    || '<tr><td style="' || td || '">Seguro</td><td style="' || td || '">' || public.bsp_html(coalesce(nullif(p.seguro, ''), 'Não indicou')) || '</td></tr>'
    || '<tr><td style="' || td || '">Melhor altura</td><td style="' || td || '">' || public.bsp_html(coalesce(nullif(p.quando_ligar, ''), 'Qualquer hora')) || '</td></tr>'
    || case when coalesce(p.mensagem, '') <> '' then '<tr><td style="' || td || '">Mensagem</td><td style="' || td || '">' || public.bsp_html(p.mensagem) || '</td></tr>' else '' end
    || '<tr><td style="' || td || '">Recebido</td><td style="' || td || '">' || quando || ' · página ' || public.bsp_html(coalesce(nullif(p.pagina, ''), 'site'))
    || case when coalesce(p.origem, '') <> '' then ' · veio de ' || public.bsp_html(p.origem) else '' end || '</td></tr>';
  perform public.bsp_enviar_email(array['rececao@barispol.com'], array['geral@barispol.com'], '{}'::text[],
    'Pedido de contacto pelo site: ' || coalesce(nullif(p.servico, ''), 'marcação') || ' (' || quando || ')',
    public.bsp_envelope('Pedido de contacto pelo site',
      '<p style="margin:0 0 12px">Uma pessoa deixou o contacto no site e espera a chamada da Recepção.</p>'
      || '<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 14px;border-collapse:collapse">' || linha || '</table>'
      || '<p style="margin:0">Depois de ligar, registe o resultado no Workspace: Utentes → Marcações → «Pedidos do site».</p>',
      'Sistema · Workspace Barispol'));
exception when others then
  -- O e-mail nunca impede que o pedido fique gravado.
  raise warning 'bsp_pedido_site_email: %', sqlerrm;
end $function$;

revoke all on function public.bsp_pedido_site_email(public.pedidos_marcacao) from public, anon, authenticated;

create or replace function public.bsp_pedido_site_aviso()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare para text[];
begin
  perform public.bsp_pedido_site_email(new);
  select array_agg(e->>'id') into para from shared_state s, jsonb_array_elements(coalesce(s.team, '[]')) e
   where s.id = 1 and public.bsp_area_chave(e->>'dept') = 'recepcao';
  if para is null then return null; end if;
  perform public.bsp_push_post(jsonb_build_object('para', to_jsonb(para),
    'titulo', 'Pedido de marcação pelo site',
    'corpo', left(new.nome, 60) || coalesce(' · ' || nullif(new.servico, ''), '') || coalesce(' · ligar ' || nullif(lower(new.quando_ligar), ''), ''),
    'url', '#/marcacoes', 'tag', 'pedido-site-' || new.id));
  return null;
end $function$;
