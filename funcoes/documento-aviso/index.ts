// Barispol Workspace · aviso de documento novo (documentos.sql, 30-09-2026)
//
// O gatilho bsp_documentos_publicado chama esta funcao no instante em que
// um documento e publicado. Envia um e-mail a cada pessoa da equipa (menos
// socios, quem tem semEmails e quem publicou), com o aspecto do site, a
// pedir que leia e confirme «Li e tomei conhecimento» no Workspace.
// Um aviso por documento: aviso_enviado_em marca-o antes do envio.
//
// SEGURANCA: so aceita o codigo do agendamento (x-bsp-agendamento, do
// cofre, conferido por bsp_resumo_codigo_confere) ou a chave do servidor.
// Verificacao de JWT desligada: a autenticacao e esta.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cabecalhos = { "Content-Type": "application/json" };
const responder = (corpo: unknown, estado = 200) =>
  new Response(JSON.stringify(corpo), { status: estado, headers: cabecalhos });

const PREFIXO_DE_CHAVE = /^(sb_secret_|sb_publishable_|eyJ)/;
const valoresDe = (nome: string): string[] => {
  const cru = (Deno.env.get(nome) || "").trim();
  if (!cru) return [];
  if (!cru.startsWith("{") && !cru.startsWith("[")) return PREFIXO_DE_CHAVE.test(cru) ? [cru] : [];
  const recolher = (v: unknown): string[] =>
    typeof v === "string" ? [v]
      : Array.isArray(v) ? v.flatMap(recolher)
        : v && typeof v === "object" ? [...Object.keys(v as object), ...Object.values(v as object)].flatMap(recolher) : [];
  try { return recolher(JSON.parse(cru)).filter((s) => PREFIXO_DE_CHAVE.test(s)); } catch { return []; }
};
const chavesServidor = (): string[] => [
  ...valoresDe("SUPABASE_SECRET_KEYS"), ...valoresDe("SUPABASE_SECRET_KEY"), ...valoresDe("SUPABASE_SERVICE_ROLE_KEY"),
];

const MARINHO = "#292F58";
const MARINHO_BOTAO = "#273069";
const AZUL = "#2291CE";
const FONTE = "'Titillium Web','Segoe UI',Arial,sans-serif";
const TEXTO = "#1C2033";
const LINHA = "#DDDBD6";
const SITIO = "https://barispol.com/workspace.html";
const CATEGORIAS: Record<string, string> = {
  regulamento: "Regulamento interno", nota: "Nota interna", comunicado: "Comunicado",
  procedimento: "Procedimento ou protocolo", formulario: "Formulário ou minuta",
};
const MESES_C = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
const dataCurta = (iso: string) => { const d = new Date(String(iso).slice(0, 10) + "T12:00:00Z"); return d.getUTCDate() + " " + MESES_C[d.getUTCMonth()] + " " + d.getUTCFullYear(); };
const escapar = (t: unknown) => String(t ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c] as string));
const paragrafo = (t: string, fim = false) =>
  '<p style="margin:' + (fim ? "0" : "0 0 12px") + ";font-family:" + FONTE + ";font-size:15px;line-height:1.6;color:" + TEXTO + '">' + t + "</p>";
const linhaDado = (r: string, v: string) =>
  '<tr><td style="padding:6px 16px 6px 0;font-family:' + FONTE + ';font-size:15px;font-weight:700;color:' + MARINHO + ';vertical-align:top;white-space:nowrap">' + r + '</td><td style="padding:6px 0;font-family:' + FONTE + ';font-size:15px;color:' + TEXTO + '">' + v + "</td></tr>";

function envelope(titulo: string, corpo: string) {
  const href = SITIO + "#/documentos";
  return '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F5F4F2"><tr><td align="center" style="padding:24px 12px">' +
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border:1px solid ' + LINHA + '">' +
    '<tr><td style="padding:16px 24px;border-bottom:1px solid ' + LINHA + '"><table role="presentation" cellpadding="0" cellspacing="0"><tr>' +
    '<td style="padding-right:12px;vertical-align:middle"><img src="https://barispol.com/assets/logo-barispol.png" width="44" height="44" alt="Centro Médico Barispol" style="display:block;border:0;width:44px;height:44px"></td>' +
    '<td style="vertical-align:middle;font-family:' + FONTE + '"><div style="font-size:16px;font-weight:700;color:' + MARINHO + ';line-height:1.2">Centro Médico Barispol</div><div style="font-size:12.5px;font-weight:600;color:#4E5366">Workspace da equipa</div></td></tr></table></td></tr>' +
    '<tr><td style="padding:28px 24px 26px;font-family:' + FONTE + ';color:' + TEXTO + '"><div style="font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:' + AZUL + '">Documento novo</div>' +
    '<h1 style="margin:8px 0 16px;font-family:' + FONTE + ';font-size:24px;line-height:1.2;font-weight:700;color:' + MARINHO + '">' + titulo + "</h1>" + corpo +
    '<div style="margin-top:22px"><a href="' + href + '" style="display:inline-block;padding:12px 22px;border-radius:2px;background:' + MARINHO_BOTAO + ';border:1px solid ' + MARINHO_BOTAO + ';font-family:' + FONTE + ';font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none">Ler e confirmar no Workspace</a>' +
    '<p style="margin:10px 0 0;font-family:' + FONTE + ';font-size:11px;color:#8A8F9E;word-break:break-all">' + href + "</p></div></td></tr>" +
    '<tr><td style="padding:16px 24px;background:' + MARINHO + ';font-family:' + FONTE + ';font-size:12.5px;line-height:1.6;color:#C9CCDA"><b style="color:#ffffff">Centro Médico Barispol</b> · Aviso de documento novo no Workspace.<br>Clínica Barispol, Lda. · NIF&nbsp;5000999687</td></tr>' +
    "</table></td></tr></table>";
}

const espera = (ms: number) => new Promise((r) => setTimeout(r, ms));

Deno.serve(async (req) => {
  if (req.method !== "POST") return responder({ erro: "Método não permitido." }, 405);
  const URL_SB = Deno.env.get("SUPABASE_URL") || "";
  const CHAVE = chavesServidor()[0] || "";
  if (!URL_SB || !CHAVE) return responder({ erro: "A função não tem acesso ao projecto." }, 500);
  const admin = createClient(URL_SB, CHAVE, { auth: { persistSession: false } });

  const testemunho = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const codigo = (req.headers.get("x-bsp-agendamento") || "").trim();
  let autorizado = !!testemunho && chavesServidor().includes(testemunho);
  if (!autorizado && codigo) {
    const { data: confere } = await admin.rpc("bsp_resumo_codigo_confere", { codigo });
    autorizado = confere === true;
  }
  if (!autorizado) return responder({ erro: "Sem autorização." }, 403);

  const corpo = await req.json().catch(() => ({} as any));
  const id = Number(corpo && corpo.id);
  if (!id) return responder({ erro: "Falta o id do documento." }, 400);

  /* Marca o aviso antes de enviar: um segundo pedido para o mesmo
     documento nao manda nada. */
  const { data: marcados, error: eM } = await admin.from("documentos")
    .update({ aviso_enviado_em: new Date().toISOString() })
    .eq("id", id).is("aviso_enviado_em", null).select("*");
  if (eM) return responder({ erro: eM.message }, 500);
  const doc: any = marcados && marcados[0];
  if (!doc) return responder({ ok: true, nota: "Aviso já enviado ou documento inexistente." });

  const { data: linha } = await admin.from("shared_state").select("team, camadas").eq("id", 1).single();
  const equipa: any[] = linha && Array.isArray(linha.team) ? linha.team : [];
  const camadas: any = (linha && linha.camadas) || {};
  const socio = (u: any) => u.accessLevel === "Sócio" || !!(camadas[u.accessLevel] && camadas[u.accessLevel].soNumeros);
  const valido = (e: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e);
  const vistos = new Set<string>();
  const para = equipa.filter((u: any) => {
    const e = String(u && u.email || "").trim().toLowerCase();
    if (!u || !valido(e) || u.semEmails || socio(u) || u.id === doc.publicado_por || vistos.has(e)) return false;
    vistos.add(e);
    return true;
  });
  const autor = equipa.find((u: any) => u && u.id === doc.publicado_por);
  const categoria = CATEGORIAS[doc.categoria] || "Documento";

  const envio = (async () => {
    let enviados = 0;
    const falhas: string[] = [];
    for (const u of para) {
      const nome = String(u.name || "").split(" ")[0];
      const html = envelope(
        escapar(doc.titulo),
        paragrafo((nome ? escapar(nome) + ", foi" : "Foi") + " publicado no Workspace um documento que diz respeito a toda a equipa:") +
          '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:4px 0 16px;border-top:1px solid ' + LINHA + ';border-bottom:1px solid ' + LINHA + '">' +
          linhaDado("Tipo", escapar(categoria)) +
          (doc.numero ? linhaDado("Número", escapar(doc.numero)) : "") +
          linhaDado("Em vigor desde", dataCurta(doc.em_vigor_desde)) +
          (autor ? linhaDado("Publicado por", escapar(autor.name)) : "") +
          "</table>" +
          (doc.descricao ? paragrafo(escapar(doc.descricao).replace(/\n/g, "<br>")) : "") +
          paragrafo("<b>A leitura é obrigatória.</b> Abra o documento no Workspace, em «Documentos», e carregue em «Li e tomei conhecimento».", true),
      );
      try {
        const r = await fetch(URL_SB.replace(/\/$/, "") + "/functions/v1/bright-worker", {
          method: "POST",
          headers: { "Content-Type": "application/json", Authorization: "Bearer " + CHAVE },
          body: JSON.stringify({ to: u.email, subject: "Documento novo: " + categoria + " · " + String(doc.titulo), html }),
        });
        r.ok ? enviados++ : falhas.push(u.email);
      } catch (_) {
        falhas.push(u.email);
      }
      await espera(600); // a Resend aceita 2 envios por segundo
    }
    console.log(JSON.stringify({ documento: id, enviados, falhas }));
  })();
  /* Responde logo e continua a enviar: o gatilho da base de dados nao
     fica a espera. */
  // @ts-ignore EdgeRuntime existe no Supabase
  if (typeof EdgeRuntime !== "undefined") EdgeRuntime.waitUntil(envio); else await envio;
  return responder({ ok: true, documento: id, destinatarios: para.length });
});
