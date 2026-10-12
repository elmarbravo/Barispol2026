// Barispol · entrada pública do site (versão 1, 12-10-2026, auditoria de
// segurança, Fase 2, ponto 5; entradas-publicas.sql)
//
// Porque existe: o pedido de marcação do site (index.html, contacto.html) e o
// inquérito de satisfação (avaliar.html) chamavam directamente, com a chave
// pública, as funções bsp_pedido_site e bsp_feedback_publico. O único travão
// era um tecto global de 300 por dia: um robô esgotava-o em minutos e
// bloqueava os pedidos verdadeiros, e cada pedido falso acordava a Recepção
// no telemóvel. Agora as duas funções já não são chamáveis pela chave
// pública: só esta Edge Function lhes chega, com a chave do servidor, e só
//   · de uma origem do site (https://barispol.com, https://www.barispol.com);
//   · até POR_LIGACAO_HORA entradas por hora por ligação (o IP guardado só
//     como resumo SHA-256 com sal, em entradas_publicas; nunca o IP);
//   · com o campo-armadilha «empresa» vazio (um robô que o preencha recebe
//     «ok» e nada é gravado).
// O corpo: { qual: "pedido" | "feedback", dados: {...} }. Em "pedido", dados
// é o p_dados da bsp_pedido_site; em "feedback", os parâmetros da
// bsp_feedback_publico (p_nota, p_tipo, p_area, p_comentario, p_contacto,
// p_quer_resposta). Os erros das funções (ex.: «Escreva o seu nome.») voltam
// em {"message": "..."} com 400, como antes pelo PostgREST, para as páginas
// os mostrarem sem mudar.
// Verificação de JWT desligada: a função é pública por desenho; o travão é a
// origem, o limite por ligação e o campo-armadilha. Turnstile (Cloudflare)
// entra aqui quando o Elmar tiver as chaves.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ORIGENS = ["https://barispol.com", "https://www.barispol.com"];
const POR_LIGACAO_HORA = 5;

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

async function resumo(s: string) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 32);
}

const texto = (v: unknown, max: number) =>
  String(v ?? "").replace(/\r\n?/g, "\n").replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "").trim().slice(0, max);

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin") || "";
  const permitida = ORIGENS.includes(origin);
  const cabecalhos = {
    "Access-Control-Allow-Origin": permitida ? origin : ORIGENS[0],
    "Access-Control-Allow-Headers": "content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
    "Content-Type": "application/json",
  };
  const responder = (corpo: unknown, estado = 200) => new Response(JSON.stringify(corpo), { status: estado, headers: cabecalhos });
  if (req.method === "OPTIONS") return new Response("ok", { headers: cabecalhos });
  if (req.method !== "POST") return responder({ message: "Método não permitido." }, 405);
  if (!permitida) return responder({ message: "Origem não autorizada." }, 403);

  let pedido: any;
  try { pedido = await req.json(); } catch { return responder({ message: "Pedido inválido." }, 400); }
  const qual = pedido && pedido.qual === "feedback" ? "feedback" : pedido && pedido.qual === "pedido" ? "pedido" : "";
  if (!qual) return responder({ message: "Pedido inválido." }, 400);
  const dados = pedido.dados && typeof pedido.dados === "object" ? pedido.dados : {};
  /* Campo-armadilha: um robô que o preencha recebe «ok» e nada se grava. */
  if (texto(dados.empresa, 50)) return responder({ ok: true });

  const URL_SB = Deno.env.get("SUPABASE_URL") || "";
  const SERVICO = chaveServidor();
  if (!URL_SB || !SERVICO) return responder({ message: "O serviço está indisponível. Ligue-nos ou use o WhatsApp." }, 500);
  const admin = createClient(URL_SB, SERVICO, { auth: { persistSession: false } });

  /* Limite por ligação: o IP só entra na base como resumo com sal. */
  const ip = (req.headers.get("x-forwarded-for") || "").split(",")[0].trim() || "sem-ip";
  const sal = (Deno.env.get("BSP_IP_SAL") || "").trim() || URL_SB;
  const origemIp = await resumo(ip + "|" + sal);
  const umaHora = new Date(Date.now() - 3600_000).toISOString();
  const { count } = await admin.from("entradas_publicas").select("id", { count: "exact", head: true })
    .eq("origem_ip", origemIp).gte("criado_em", umaHora);
  if ((count ?? 0) >= POR_LIGACAO_HORA) {
    return responder({ message: "Recebemos muitos pedidos desta ligação. Ligue-nos ou use o WhatsApp, por favor." }, 429);
  }
  await admin.from("entradas_publicas").insert({ origem_ip: origemIp, qual });

  let resposta;
  if (qual === "pedido") {
    const p_dados: Record<string, string> = {};
    for (const k of ["pagina", "origem", "nome", "telefone", "familiar_quem", "telefone_proprio", "servico", "seguro", "quando_ligar", "mensagem"]) {
      p_dados[k] = texto(dados[k], k === "mensagem" ? 2000 : 200);
    }
    resposta = await admin.rpc("bsp_pedido_site", { p_dados });
  } else {
    const nota = Number(dados.p_nota);
    resposta = await admin.rpc("bsp_feedback_publico", {
      p_nota: Number.isInteger(nota) && nota > 0 ? nota : null,
      p_tipo: texto(dados.p_tipo, 40),
      p_area: texto(dados.p_area, 60),
      p_comentario: texto(dados.p_comentario, 4000),
      p_contacto: texto(dados.p_contacto, 120),
      p_quer_resposta: dados.p_quer_resposta === true,
    });
  }
  if (resposta.error) {
    /* A mensagem da função («Escreva o seu nome.») é para a pessoa; o resto
       dos erros não (não se revela o que há por trás). */
    const m = String(resposta.error.message || "");
    const paraPessoa = resposta.error.code === "P0001" && m && !/^(permission|function|relation)/i.test(m);
    return responder({ message: paraPessoa ? m : "Não foi possível enviar. Ligue-nos ou use o WhatsApp." }, paraPessoa ? 400 : 500);
  }
  return responder({ ok: true, id: resposta.data ?? null });
});
