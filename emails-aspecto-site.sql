-- Barispol · aspecto de todos os e-mails igual ao site novo
-- Pedido do Elmar, 26-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- bsp_envelope (relatorios do WhatsApp) passa a ter o desenho da caixa de
-- contacto e do Workspace: fundo branco, linhas finas, cantos rectos,
-- cabecalho com o logotipo pequeno, etiqueta azul, titulo marinho e rodape
-- marinho com a pessoa juridica. O mesmo desenho esta em workspace.html
-- (bspEmailWrap) e em funcoes/resumo-matinal (envelope): mudar os tres
-- juntos. A assinatura nao muda, para nenhuma chamada partir.

create or replace function public.bsp_envelope(titulo text, corpo text, rodape text default 'E-mail automático do sistema do Centro Médico Barispol.')
returns text
language sql
immutable
as $function$
  select '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F5F4F2"><tr><td align="center" style="padding:24px 12px">'
      || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:640px;background:#ffffff;border:1px solid #DDDBD6">'
      || '<tr><td style="padding:16px 24px;border-bottom:1px solid #DDDBD6"><table role="presentation" cellpadding="0" cellspacing="0"><tr>'
      || '<td style="padding-right:12px;vertical-align:middle"><img src="https://barispol.com/assets/logo-barispol.png" width="44" height="44" alt="Centro Médico Barispol" style="display:block;border:0;width:44px;height:44px"></td>'
      || '<td style="vertical-align:middle;font-family:Dax,''Titillium Web'',''Segoe UI'',Arial,sans-serif"><div style="font-size:16px;font-weight:700;color:#292F58;line-height:1.2">Centro Médico Barispol</div><div style="font-size:12.5px;font-weight:600;color:#4E5366">Workspace da equipa</div></td>'
      || '</tr></table></td></tr>'
      || '<tr><td style="padding:28px 24px 26px;font-family:Dax,''Titillium Web'',''Segoe UI'',Arial,sans-serif;font-size:15px;line-height:1.6;color:#1C2033">'
      || '<div style="font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:#2291CE">Relatório automático</div>'
      || '<h1 style="margin:8px 0 16px;font-size:24px;line-height:1.2;font-weight:700;color:#292F58">' || titulo || '</h1>'
      || corpo
      || '</td></tr>'
      || '<tr><td style="padding:16px 24px;background:#292F58;font-family:Dax,''Titillium Web'',''Segoe UI'',Arial,sans-serif;font-size:12.5px;line-height:1.6;color:#C9CCDA"><b style="color:#ffffff">Centro Médico Barispol</b> · ' || replace(rodape, 'E-mail automático do sistema do Centro Médico Barispol.', 'e-mail automático do Workspace.') || '<br>Clínica Barispol, Lda. · NIF&nbsp;5000999687</td></tr>'
      || '</table></td></tr></table>'
$function$;

-- Dentro dos relatorios do WhatsApp: o cinzento-azulado antigo passa ao
-- cinzento claro do site e os cantos redondos passam a rectos.
do $$
declare f text; d text;
begin
  foreach f in array array['public.wa_resumo_8h', 'public.wa_alerta_historico', 'public.bsp_wa_tabela'] loop
    select pg_get_functiondef(p.oid) into d from pg_proc p where p.oid = to_regproc(f);
    if d is null then continue; end if;
    d := replace(d, '#F3F6FB', '#F5F4F2');
    d := replace(d, '#DFE6F0', '#DDDBD6');
    d := regexp_replace(d, 'border-radius:(6|8|10|12)px', 'border-radius:2px', 'g');
    execute d;
  end loop;
end $$;
