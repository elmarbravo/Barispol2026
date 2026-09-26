// Barispol · caixa de contacto do site (barispol.com)
//
// Pedido do Elmar, 25-09-2026. O paciente escreve no site o que quiser e a
// clinica recebe por e-mail, sem depender so do WhatsApp.
//
// O que faz: guarda a mensagem em contactos_site e envia-a pela Resend,
// com o remetente geral@barispol.com, para rececao@barispol.com com
// geral@barispol.com em copia (pedido do Elmar, 26-09-2026). Se o
// paciente deixar o e-mail, entra como "responder a". Nunca envia nada
// ao paciente nem a mais ninguem: os destinos estao fixos aqui.
// Aspecto (26-09-2026): o mesmo do site novo (fundo branco, linhas finas,
// cantos rectos, marinho e azul da marca).
//
// SEGURANCA: verificacao de JWT desligada (o site e publico), mas:
//   · so aceita pedidos vindos de barispol.com;
//   · campo escondido "empresa": se vier preenchido, e um robo;
//   · 3 mensagens por hora por ligacao e 30 por hora no total;
//   · tamanhos limitados e texto sempre escapado no e-mail.
// ENVIO (25-09-2026, pedido do Elmar: "o e-mail sai da nossa caixa
// info@barispol.ao, use o SMTP"):
//   1. SMTP da caixa da clinica, se o painel tiver os segredos SMTP_HOST,
//      SMTP_USER e SMTP_PASS (e, se quiser, SMTP_PORT e SMTP_FROM). A
//      palavra-passe e colada pelo Elmar no painel (Edge Functions ->
//      Secrets) e nunca aparece aqui. As Edge Functions nao podem usar as
//      portas 25 e 587: so a 465 (SSL).
//   2. Se o SMTP faltar ou falhar, a Resend (geral@barispol.com), com a
//      chave de RESEND_API_KEY ou do cofre (bsp_resend_key). Assim
//      nenhuma mensagem se perde.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.14";

const DESTINO = "rececao@barispol.com";
const COPIA = "geral@barispol.com";
const ORIGENS = ["https://barispol.com", "https://www.barispol.com"];
const POR_LIGACAO_HORA = 3;
const TOTAL_HORA = 30;

const FONTE = "Dax, 'Titillium Web', 'Segoe UI', Arial, sans-serif";
const LOGOTIPO = "https://barispol.com/assets/logo-barispol.png";

const PREFIXO_DE_CHAVE = /^(sb_secret_|eyJ)/;
const valoresDe = (nome: string): string[] => {
  const cru = (Deno.env.get(nome) || "").trim();
  if (!cru) return [];
  if (!cru.startsWith("{") && !cru.startsWith("[")) return PREFIXO_DE_CHAVE.test(cru) ? [cru] : [];
  const recolher = (v: unknown): string[] =>
    typeof v === "string" ? [v]
      : Array.isArray(v) ? v.flatMap(recolher)
      : v && typeof v === "object" ? [...Object.keys(v as object), ...Object.values(v as object)].flatMap(recolher)
      : [];
  try { return recolher(JSON.parse(cru)).filter((s) => PREFIXO_DE_CHAVE.test(s)); } catch { return []; }
};
const chaveServidor = () =>
  [...valoresDe("SUPABASE_SECRET_KEYS"), ...valoresDe("SUPABASE_SECRET_KEY"), ...valoresDe("SUPABASE_SERVICE_ROLE_KEY")][0] || "";

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const texto = (v: unknown, max: number) =>
  String(v ?? "").replace(/\r\n?/g, "\n").replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "").trim().slice(0, max);
const umaLinha = (v: unknown, max: number) => texto(v, max).replace(/\s+/g, " ");
const emailValido = (e: string) => /^[^@\s<>"]+@[^@\s<>"]+\.[^@\s<>"]+$/.test(e);

async function resumo(s: string) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 32);
}

const MESES = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
/* «26 Set 2026, 10:58», hora de Luanda (UTC+1, sem hora de Verao). */
function dataLuanda(d: Date) {
  const l = new Date(d.getTime() + 3600_000);
  const h = String(l.getUTCHours()).padStart(2, "0") + ":" + String(l.getUTCMinutes()).padStart(2, "0");
  return l.getUTCDate() + " " + MESES[l.getUTCMonth()] + " " + l.getUTCFullYear() + ", " + h;
}
/* Telefone angolano em formato internacional, para os botoes. */
function tel244(t: string) {
  const d = t.replace(/[^0-9]/g, "");
  if (d.length === 9) return "244" + d;
  if (d.startsWith("00")) return d.slice(2);
  return d;
}

const COR = { marinho: "#292F58", marinho2: "#273069", azul: "#2291CE", texto: "#1C2033", suave: "#4E5366", linha: "#DDDBD6", claro: "#F5F4F2" };

function botao(href: string, rotulo: string, cheio: boolean) {
  return `<a href="${esc(href)}" style="display:inline-block;margin:0 8px 8px 0;white-space:nowrap;padding:11px 18px;border-radius:2px;font-family:${FONTE};font-size:14px;font-weight:700;text-decoration:none;` +
    (cheio ? `background:${COR.marinho2};color:#ffffff;border:1px solid ${COR.marinho2}` : `background:#ffffff;color:${COR.marinho2};border:1px solid ${COR.linha}`) +
    `">${esc(rotulo)}</a>`;
}

function cartao(d: { nome: string; telefone: string; email: string; assunto: string; seguro: string; origem: string; mensagem: string; quando: Date }) {
  const t = tel244(d.telefone);
  const valor = (k: string, v: string) => {
    if (k === "Telefone" && t) return `<a href="tel:+${t}" style="color:${COR.marinho2};text-decoration:underline">${esc(v)}</a>`;
    if (k === "E-mail") return `<a href="mailto:${esc(v)}" style="color:${COR.marinho2};text-decoration:underline">${esc(v)}</a>`;
    return esc(v);
  };
  const linhas = ([["Nome", d.nome], ["Telefone", d.telefone], ["E-mail", d.email], ["Seguro de saúde", d.seguro], ["Origem", d.origem]] as [string, string][])
    .filter(([, v]) => v)
    .map(([k, v]) =>
      `<tr><td style="padding:10px 16px 10px 0;border-top:1px solid ${COR.linha};font-family:${FONTE};font-size:13.5px;color:${COR.suave};white-space:nowrap;vertical-align:top;width:34%">${esc(k)}</td>` +
      `<td style="padding:10px 0;border-top:1px solid ${COR.linha};font-family:${FONTE};font-size:15px;color:${COR.texto};vertical-align:top">${valor(k, v)}</td></tr>`).join("");
  const primeiro = d.nome.split(" ")[0] || "o paciente";
  const botoes = [
    d.email ? botao("mailto:" + d.email + "?subject=" + encodeURIComponent("Centro Médico Barispol: " + (d.assunto || "a sua mensagem")), "Responder a " + primeiro, true) : "",
    t ? botao("tel:+" + t, "Ligar", !d.email) : "",
    t ? botao("https://wa.me/" + t, "WhatsApp", false) : "",
  ].join("");
  return `<!DOCTYPE html><html lang="pt-PT"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"></head>` +
    `<body style="margin:0;padding:0;background:${COR.claro}">` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${COR.claro}"><tr><td align="center" style="padding:24px 12px">` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border:1px solid ${COR.linha}">` +
    /* cabecalho, como o do site */
    `<tr><td style="padding:16px 24px;border-bottom:1px solid ${COR.linha}">` +
    `<table role="presentation" cellpadding="0" cellspacing="0"><tr>` +
    `<td style="padding-right:12px;vertical-align:middle"><img src="${LOGOTIPO}" width="44" height="44" alt="Centro Médico Barispol" style="display:block;border:0;width:44px;height:44px"></td>` +
    `<td style="vertical-align:middle;font-family:${FONTE}"><div style="font-size:16px;font-weight:700;color:${COR.marinho};line-height:1.2">Centro Médico Barispol</div>` +
    `<div style="font-size:12.5px;font-weight:600;color:${COR.suave}">Camama, Luanda</div></td>` +
    `</tr></table></td></tr>` +
    /* corpo */
    `<tr><td style="padding:28px 24px 8px;font-family:${FONTE}">` +
    `<div style="font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:${COR.azul}">Mensagem pelo site</div>` +
    `<h1 style="margin:8px 0 6px;font-family:${FONTE};font-size:24px;line-height:1.2;font-weight:700;color:${COR.marinho}">${esc(d.assunto || "Pedido de informação")}</h1>` +
    `<p style="margin:0 0 20px;font-size:15px;line-height:1.6;color:${COR.suave}">${esc(d.nome)} escreveu pela caixa de contacto de barispol.com a ${esc(dataLuanda(d.quando))}.</p>` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;border-bottom:1px solid ${COR.linha}">${linhas}</table>` +
    `<div style="margin:24px 0 8px;font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:${COR.suave}">Mensagem</div>` +
    `<div style="border-left:4px solid ${COR.azul};background:${COR.claro};padding:14px 16px;font-size:15px;line-height:1.6;color:${COR.texto};white-space:pre-wrap">${esc(d.mensagem)}</div>` +
    `</td></tr>` +
    (botoes ? `<tr><td style="padding:18px 24px 6px">${botoes}</td></tr>` : "") +
    `<tr><td style="padding:6px 24px 26px;font-family:${FONTE};font-size:13px;line-height:1.5;color:${COR.suave}">` +
    (d.email ? "Se responder a este e-mail, a resposta segue para " + esc(d.email) + "." : "A pessoa não deixou e-mail: responda por telefone ou WhatsApp.") +
    `</td></tr>` +
    /* rodape */
    `<tr><td style="padding:16px 24px;background:${COR.marinho};font-family:${FONTE};font-size:12.5px;line-height:1.6;color:#C9CCDA">` +
    `<b style="color:#ffffff">Centro Médico Barispol</b> · Camama 1, junto ao Condomínio BPC · todos os dias, das 07:30 às 22:00<br>` +
    `Clínica Barispol, Lda. · NIF&nbsp;5000999687</td></tr>` +
    `</table></td></tr></table></body></html>`;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin") || "";
  const permitida = ORIGENS.includes(origin);
  const cors: Record<string, string> = {
    "Access-Control-Allow-Origin": permitida ? origin : ORIGENS[0],
    "Access-Control-Allow-Headers": "content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  const responder = (corpo: unknown, estado = 200) =>
    new Response(JSON.stringify(corpo), { status: estado, headers: { ...cors, "Content-Type": "application/json" } });

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return responder({ erro: "Método não permitido." }, 405);
  if (!permitida) return responder({ erro: "Origem não autorizada." }, 403);

  let p: any;
  try { p = await req.json(); } catch { return responder({ erro: "Pedido inválido." }, 400); }

  /* Robo: preencheu o campo escondido. Responde-se como se tivesse
     corrido bem, para nao lhe ensinar nada. */
  if (texto(p?.empresa, 200)) return responder({ ok: true });

  const nome = umaLinha(p?.nome, 120);
  const telefone = umaLinha(p?.telefone, 40);
  const email = umaLinha(p?.email, 160).toLowerCase();
  const assunto = umaLinha(p?.assunto, 80);
  const seguro = umaLinha(p?.seguro, 80);
  const origem = umaLinha(p?.origem, 40);
  const mensagem = texto(p?.mensagem, 3000);

  if (nome.length < 3) return responder({ erro: "Escreva o seu nome." }, 400);
  if (mensagem.length < 5) return responder({ erro: "Escreva a sua mensagem." }, 400);
  const digitos = telefone.replace(/[^0-9]/g, "");
  if (!digitos && !email) return responder({ erro: "Deixe um telefone ou um e-mail para lhe respondermos." }, 400);
  if (digitos && digitos.length < 9) return responder({ erro: "Verifique o número de telefone." }, 400);
  if (email && !emailValido(email)) return responder({ erro: "Verifique o endereço de e-mail." }, 400);

  const URL_SB = Deno.env.get("SUPABASE_URL") || "";
  const SERVICO = chaveServidor();
  if (!URL_SB || !SERVICO) return responder({ erro: "O serviço está indisponível. Use o WhatsApp ou o telefone." }, 500);
  const admin = createClient(URL_SB, SERVICO, { auth: { persistSession: false } });

  const ip = (req.headers.get("x-forwarded-for") || "").split(",")[0].trim() || "sem-ip";
  const origemIp = await resumo(ip + "|" + URL_SB);
  const umaHora = new Date(Date.now() - 3600_000).toISOString();
  const [{ count: daLigacao }, { count: total }] = await Promise.all([
    admin.from("contactos_site").select("id", { count: "exact", head: true }).eq("origem_ip", origemIp).gte("criado_em", umaHora),
    admin.from("contactos_site").select("id", { count: "exact", head: true }).gte("criado_em", umaHora),
  ]);
  if ((daLigacao ?? 0) >= POR_LIGACAO_HORA || (total ?? 0) >= TOTAL_HORA) {
    return responder({ erro: "Recebemos muitas mensagens nesta hora. Use o WhatsApp ou o telefone." }, 429);
  }

  const { data: linha, error: erroGuardar } = await admin.from("contactos_site")
    .insert({ origem_ip: origemIp, nome, telefone, email, assunto, seguro, mensagem, origem })
    .select("id").single();
  if (erroGuardar || !linha) return responder({ erro: "Não foi possível enviar. Use o WhatsApp ou o telefone." }, 500);

  const html = cartao({ nome, telefone, email, assunto, seguro, origem, mensagem, quando: new Date() });
  const titulo = ("Site: " + (assunto || "mensagem") + " (" + nome + ")").slice(0, 150);
  const falhas: string[] = [];

  /* 1. SMTP da caixa da clinica. */
  const smtpHost = (Deno.env.get("SMTP_HOST") || "").trim();
  const smtpUser = (Deno.env.get("SMTP_USER") || "").trim();
  const smtpPass = Deno.env.get("SMTP_PASS") || "";
  const smtpPort = parseInt(Deno.env.get("SMTP_PORT") || "465", 10) || 465;
  let enviado = false;
  let via = "";
  if (smtpHost && smtpUser && smtpPass) {
    if (smtpPort === 25 || smtpPort === 587) {
      falhas.push("smtp: a porta " + smtpPort + " esta bloqueada nas Edge Functions; usar 465");
    } else {
      try {
        const t = nodemailer.createTransport({
          host: smtpHost, port: smtpPort, secure: smtpPort === 465,
          auth: { user: smtpUser, pass: smtpPass },
        });
        await t.sendMail({
          from: "Centro Médico Barispol <" + ((Deno.env.get("SMTP_FROM") || "").trim() || smtpUser) + ">",
          to: DESTINO,
          cc: COPIA,
          subject: titulo,
          html,
          ...(email ? { replyTo: email } : {}),
        });
        enviado = true;
        via = "smtp";
      } catch (e) {
        falhas.push("smtp: " + String((e as Error)?.message || e).slice(0, 160));
      }
    }
  }

  /* 2. Resend, se o SMTP faltar ou falhar. */
  if (!enviado) {
    let chave = Deno.env.get("RESEND_API_KEY") || "";
    if (!chave) {
      const { data: doCofre } = await admin.rpc("bsp_resend_key");
      if (typeof doCofre === "string") chave = doCofre;
    }
    if (chave) {
      const r = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: "Bearer " + chave },
        body: JSON.stringify({
          from: "Centro Médico Barispol <geral@barispol.com>",
          to: [DESTINO],
          cc: [COPIA],
          subject: titulo,
          html,
          ...(email ? { reply_to: email } : {}),
        }),
      });
      if (r.ok) { enviado = true; via = "resend"; } else falhas.push("resend " + r.status);
    } else {
      falhas.push("sem chave da Resend");
    }
  }

  await admin.from("contactos_site").update({
    enviado,
    erro: (via ? "via " + via : "") + (falhas.length ? (via ? "; " : "") + falhas.join("; ") : "") || null,
  }).eq("id", linha.id);
  if (!enviado) return responder({ erro: "Guardámos a mensagem, mas o e-mail falhou. Se for urgente, use o WhatsApp." }, 502);
  return responder({ ok: true });
});
