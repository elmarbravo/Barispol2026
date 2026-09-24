// Barispol · caixa de contacto do site (barispol.com)
//
// Pedido do Elmar, 25-09-2026. O paciente escreve no site o que quiser e a
// clinica recebe por e-mail, sem depender so do WhatsApp.
//
// O que faz: guarda a mensagem em contactos_site e envia-a pela Resend,
// com o remetente geral@barispol.com, SO para info@barispol.ao (a caixa da clinica, pedido do Elmar 25-09-2026). Se o
// paciente deixar o e-mail, entra como "responder a". Nunca envia nada
// ao paciente nem a mais ninguem: o destino esta fixo aqui.
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

const DESTINO = "info@barispol.ao";
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

function cartao(linhas: [string, string][], mensagem: string) {
  const tabela = linhas.filter(([, v]) => v).map(([k, v]) =>
    `<tr><td style="padding:4px 14px 4px 0;color:#5A6180;font-family:${FONTE};font-size:14px;white-space:nowrap;vertical-align:top">${esc(k)}</td>` +
    `<td style="padding:4px 0;color:#292F58;font-family:${FONTE};font-size:14px">${esc(v)}</td></tr>`).join("");
  return `<div style="background:#F3F6FB;padding:24px 12px">` +
    `<div style="font-family:${FONTE};max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #DFE6F0;border-radius:12px;overflow:hidden">` +
    `<div style="padding:22px 20px 16px;text-align:center"><img src="${LOGOTIPO}" width="84" alt="Centro Médico Barispol" style="display:inline-block;border:0;width:84px;height:auto"></div>` +
    `<div style="height:4px;background:#2291CE;line-height:4px;font-size:0">&nbsp;</div>` +
    `<div style="padding:24px 24px 26px;color:#292F58">` +
    `<h2 style="margin:0 0 14px;font-family:${FONTE};font-size:20px;color:#292F58">Mensagem pelo site</h2>` +
    `<table role="presentation" style="border-collapse:collapse;margin:0 0 16px">${tabela}</table>` +
    `<div style="border-top:1px solid #DFE6F0;padding-top:14px;font-family:${FONTE};font-size:15px;line-height:1.6;color:#292F58;white-space:pre-wrap">${esc(mensagem)}</div>` +
    `</div>` +
    `<div style="padding:14px 24px;background:#292F58;color:#ffffff;font-family:${FONTE};font-size:12px;line-height:1.5">` +
    `<b>Centro Médico Barispol</b> · caixa de contacto de barispol.com<br>` +
    `<span style="color:#C9D3E6">Clínica Barispol, Lda. · NIF 5000999687</span></div>` +
    `</div></div>`;
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

  const html = cartao([
    ["Nome", nome], ["Telefone", telefone], ["E-mail", email],
    ["Assunto", assunto], ["Seguro", seguro], ["Origem", origem],
  ], mensagem);
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
