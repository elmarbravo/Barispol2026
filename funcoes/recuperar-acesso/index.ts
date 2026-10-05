// Barispol Workspace · recuperação da palavra-passe (05-10-2026)
//
// Pedido do Elmar: «Os meus colegas conseguem [recuperar a palavra-passe]
// sem mim? Se não faça isso.» Não conseguiam: o «Esqueceu-se?» usava o correio
// de teste do Supabase, que só entrega a membros da organização, e a ligação
// levava a http://localhost:3000 (o «Site URL» do painel).
//
// Recebe { email }. Se houver uma conta com esse endereço, cria uma ligação
// de recuperação (generateLink, recovery) e envia-a pela Resend, de
// geral@barispol.com, só para esse endereço. A ligação abre
// https://barispol.com/workspace.html#recuperar=<código>; o Workspace pede a
// nova palavra-passe e só então gasta o código (verifyOtp, token_hash). Assim
// os antivírus que abrem as ligações dos e-mails não estragam o código.
//
// SEGURANÇA
//   · verificação de JWT desligada: quem se esqueceu não tem sessão;
//   · só aceita pedidos vindos de barispol.com (o site e a app);
//   · responde sempre o mesmo, exista ou não a conta (ninguém descobre
//     endereços por aqui);
//   · 3 pedidos por endereço por hora e 30 no total (bsp_recuperacao_pode,
//     recuperar-acesso.sql);
//   · o e-mail vai só para o endereço da própria conta.
// Não respeita a pausa dos e-mails (emails-pausa.sql): é a própria pessoa que
// pede, e sem isto fica sem entrar. Fica registado em emails_registo.
// Versão 2 (05-10-2026): a ligação leva também &email= e &nome=, que o ecrã
// «Nova palavra-passe» mostra.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ORIGENS = ["https://barispol.com", "https://www.barispol.com"];
const DESTINO = "https://barispol.com/workspace.html";
const FONTE = "Dax, 'Titillium Web', 'Segoe UI', Arial, sans-serif";
const LOGOTIPO = "https://barispol.com/assets/logo-barispol.png";
const COR = { marinho: "#292F58", botao: "#273069", azul: "#2291CE", texto: "#1C2033", suave: "#4E5366", linha: "#DDDBD6", claro: "#F5F4F2" };

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
const emailValido = (e: string) => /^[^@\s<>"]+@[^@\s<>"]+\.[^@\s<>"]+$/.test(e) && e.length <= 200;

async function resumo(s: string) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

const MESES = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
/* «5 Out 2026, 10:58», hora de Luanda (UTC+1). */
function dataLuanda(d: Date) {
  const l = new Date(d.getTime() + 3600_000);
  const h = String(l.getUTCHours()).padStart(2, "0") + ":" + String(l.getUTCMinutes()).padStart(2, "0");
  return l.getUTCDate() + " " + MESES[l.getUTCMonth()] + " " + l.getUTCFullYear() + ", " + h;
}

function cartao(nome: string, ligacao: string, ate: Date) {
  return `<!DOCTYPE html><html lang="pt-PT"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"></head>` +
    `<body style="margin:0;padding:0;background:${COR.claro}">` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${COR.claro}"><tr><td align="center" style="padding:24px 12px">` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border:1px solid ${COR.linha}">` +
    `<tr><td style="padding:16px 24px;border-bottom:1px solid ${COR.linha}">` +
    `<table role="presentation" cellpadding="0" cellspacing="0"><tr>` +
    `<td style="padding-right:12px;vertical-align:middle"><img src="${LOGOTIPO}" width="44" height="44" alt="Centro Médico Barispol" style="display:block;border:0;width:44px;height:44px"></td>` +
    `<td style="vertical-align:middle;font-family:${FONTE}"><div style="font-size:16px;font-weight:700;color:${COR.marinho};line-height:1.2">Centro Médico Barispol</div>` +
    `<div style="font-size:12.5px;font-weight:600;color:${COR.suave}">Workspace da equipa</div></td>` +
    `</tr></table></td></tr>` +
    `<tr><td style="padding:28px 24px 26px;font-family:${FONTE};font-size:15px;line-height:1.6;color:${COR.texto}">` +
    `<div style="font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:${COR.azul}">Palavra-passe</div>` +
    `<h1 style="margin:8px 0 16px;font-size:24px;line-height:1.2;font-weight:700;color:${COR.marinho}">Nova palavra-passe</h1>` +
    `<p style="margin:0 0 14px">Olá${nome ? ", " + esc(nome) : ""}.</p>` +
    `<p style="margin:0 0 14px">Pediu para mudar a palavra-passe do Workspace. Carregue no botão, escreva a nova palavra-passe duas vezes e grave. Entra logo a seguir.</p>` +
    `<p style="margin:0 0 22px">A ligação serve uma só vez e vale até ${esc(dataLuanda(ate))}.</p>` +
    `<a href="${esc(ligacao)}" style="display:inline-block;background:${COR.botao};color:#ffffff;text-decoration:none;font-weight:700;font-size:15px;padding:13px 22px">Escolher nova palavra-passe</a>` +
    `<p style="margin:22px 0 0;font-size:13px;color:${COR.suave}">Se não foi a pessoa que pediu, ignore este e-mail: a palavra-passe actual continua válida.</p>` +
    `</td></tr>` +
    `<tr><td style="padding:16px 24px;background:${COR.marinho};font-family:${FONTE};font-size:12.5px;line-height:1.6;color:#C9CCDA">` +
    `<b style="color:#ffffff">Centro Médico Barispol</b> · e-mail automático do Workspace.<br>` +
    `Clínica Barispol, Lda. · NIF&nbsp;5000999687</td></tr>` +
    `</table></td></tr></table></body></html>`;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin") || "";
  const permitida = ORIGENS.includes(origin);
  const cors: Record<string, string> = {
    "Access-Control-Allow-Origin": permitida ? origin : ORIGENS[0],
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  const responder = (corpo: unknown, estado = 200) =>
    new Response(JSON.stringify(corpo), { status: estado, headers: { ...cors, "Content-Type": "application/json" } });
  /* A resposta é a mesma, exista ou não a conta. */
  const pronto = () => responder({ ok: true });

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return responder({ erro: "Método não permitido." }, 405);
  if (!permitida) return responder({ erro: "Origem não autorizada." }, 403);

  let p: any;
  try { p = await req.json(); } catch { return responder({ erro: "Pedido inválido." }, 400); }
  const email = String(p && p.email || "").trim().toLowerCase();
  if (!emailValido(email)) return responder({ erro: "Escreva um e-mail válido." }, 400);

  const URL_SB = Deno.env.get("SUPABASE_URL") || "";
  const SERVICO = chaveServidor();
  if (!URL_SB || !SERVICO) return responder({ erro: "A função não tem as chaves do projecto." }, 500);
  const admin = createClient(URL_SB, SERVICO, { auth: { persistSession: false } });

  const { data: pode } = await admin.rpc("bsp_recuperacao_pode", { p_resumo: await resumo(email) });
  if (pode !== true) return responder({ erro: "Já pediu várias vezes. Espere uma hora ou fale com a Direcção." }, 429);

  const { data: link, error } = await admin.auth.admin.generateLink({ type: "recovery", email });
  const codigo = link && (link as any).properties && (link as any).properties.hashed_token;
  if (error || !codigo) return pronto();

  /* Nome, da equipa (shared_state), se lá estiver. */
  let nome = "", nomeCompleto = "";
  try {
    const { data: linha } = await admin.from("shared_state").select("team").eq("id", 1).single();
    const equipa: any[] = linha && Array.isArray(linha.team) ? linha.team : [];
    const u = equipa.find((x: any) => x && String(x.email || "").trim().toLowerCase() === email);
    nomeCompleto = u && u.name ? String(u.name).trim().replace(/\s+/g, " ") : "";
    nome = nomeCompleto.split(" ")[0];
  } catch { /* sem nome, o e-mail sai na mesma */ }

  let key = Deno.env.get("RESEND_API_KEY") || "";
  if (!key) {
    const { data: doCofre } = await admin.rpc("bsp_resend_key");
    if (typeof doCofre === "string" && doCofre) key = doCofre;
  }
  if (!key) return responder({ erro: "O envio de e-mail não está configurado." }, 500);

  /* O nome e o e-mail vão na ligação (05-10-2026, Elmar): o ecrã mostra de
     quem é a conta antes de gravar. Ficam depois do #, não chegam ao site. */
  const ligacao = DESTINO + "#recuperar=" + encodeURIComponent(codigo) +
    "&email=" + encodeURIComponent(email) + (nomeCompleto ? "&nome=" + encodeURIComponent(nomeCompleto) : "");
  const ate = new Date(Date.now() + 3600_000);
  const assunto = "Nova palavra-passe do Workspace";
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: "Bearer " + key },
    body: JSON.stringify({
      from: "Barispol Workspace <geral@barispol.com>",
      to: [email],
      subject: assunto,
      html: cartao(nome, ligacao, ate),
    }),
  });
  try { await admin.from("emails_registo").insert({ assunto, destinatarios: 1, estado: r.status, pausado: false }); } catch { /* o registo nunca impede o envio */ }
  if (!r.ok) return responder({ erro: "Não foi possível enviar o e-mail. Tente daqui a pouco." }, 502);
  return pronto();
});
