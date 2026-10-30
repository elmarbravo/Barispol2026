// Barispol Workspace · ler um anexo do Chat (30-10-2026)
//
// Pedido do Elmar: «localize os pacotes que o Dr. Osvaldo mandou… num dos
// grupos». Lê um anexo de conversa/ (contentor drive) e devolve o texto:
//   · .docx: o texto de word/document.xml;
//   · imagem (.jpg/.jpeg/.png/.webp): transcrição pelo Claude (ANTHROPIC_API_KEY).
// Corpo: {"caminho": "conversa/…"}. Só lê; não grava nada.
// SEGURANÇA: só o código do agendamento (x-bsp-agendamento, conferido pela
// base de dados) ou a chave do servidor. Nunca chamada pelo navegador.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { unzipSync, strFromU8 } from "https://esm.sh/fflate@0.8.2";

const PREFIXO = /^(sb_secret_|eyJ)/;
const valoresDe = (nome: string): string[] => {
  const cru = (Deno.env.get(nome) || "").trim();
  if (!cru) return [];
  if (!cru.startsWith("{") && !cru.startsWith("[")) return PREFIXO.test(cru) ? [cru] : [];
  const rec = (v: unknown): string[] => typeof v === "string" ? [v] : Array.isArray(v) ? v.flatMap(rec)
    : v && typeof v === "object" ? [...Object.keys(v as object), ...Object.values(v as object)].flatMap(rec) : [];
  try { return rec(JSON.parse(cru)).filter((s) => PREFIXO.test(s)); } catch { return []; }
};
const chavesServidor = () => [...valoresDe("SUPABASE_SECRET_KEYS"), ...valoresDe("SUPABASE_SECRET_KEY"), ...valoresDe("SUPABASE_SERVICE_ROLE_KEY")];
const json = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { "Content-Type": "application/json" } });

function textoDocx(bytes: Uint8Array): string {
  const zip = unzipSync(bytes, { filter: (f) => f.name === "word/document.xml" });
  const xml = strFromU8(zip["word/document.xml"] || new Uint8Array());
  return xml
    .replace(/<w:tab\/>/g, "\t")
    .replace(/<w:br[^>]*\/>/g, "\n")
    .replace(/<\/w:p>/g, "\n")
    .replace(/<\/w:tc>/g, " | ")
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

async function transcreverImagem(bytes: Uint8Array, tipo: string, chave: string): Promise<string> {
  let bin = "";
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": chave, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({ model: Deno.env.get("ANTHROPIC_MODEL") || "claude-sonnet-5-5", max_tokens: 3000,
      system: "Transcreves capturas de ecrã para uma clínica. Devolve só o texto visível, com preços, nomes de serviços e listas tal como aparecem. Não comentes.",
      messages: [{ role: "user", content: [{ type: "image", source: { type: "base64", media_type: tipo, data: btoa(bin) } }, { type: "text", text: "Transcreve esta imagem." }] }] }),
  });
  const d = await r.json();
  if (!r.ok) throw new Error("claude " + r.status + ": " + JSON.stringify(d.error || d).slice(0, 200));
  return (d.content || []).map((c: any) => c.text || "").join("").trim();
}

Deno.serve(async (req) => {
  const URL_SB = Deno.env.get("SUPABASE_URL") || "";
  const SERVICO = chavesServidor()[0] || "";
  if (!URL_SB || !SERVICO) return json({ erro: "sem chaves do projecto" }, 500);
  const admin = createClient(URL_SB, SERVICO, { auth: { persistSession: false } });
  const testemunho = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const codigo = (req.headers.get("x-bsp-agendamento") || "").trim();
  let autorizado = !!testemunho && chavesServidor().includes(testemunho);
  if (!autorizado && codigo) {
    const { data } = await admin.rpc("bsp_resumo_codigo_confere", { codigo });
    autorizado = data === true;
  }
  if (!autorizado) return json({ erro: "sem autorizacao" }, 401);

  const corpo = await req.json().catch(() => ({} as any));
  const caminho = String(corpo && corpo.caminho || "");
  if (!/^conversa\/[^/]+\/[^/]+\/[^/]+$/.test(caminho) || caminho.includes("..")) return json({ erro: "caminho invalido" }, 400);
  const { data: blob, error } = await admin.storage.from("drive").download(caminho);
  if (error || !blob) return json({ erro: "nao encontrado: " + (error && error.message) }, 404);
  const bytes = new Uint8Array(await blob.arrayBuffer());
  const ext = (caminho.split(".").pop() || "").toLowerCase();
  try {
    if (ext === "docx") return json({ caminho, texto: textoDocx(bytes) });
    const tipos: Record<string, string> = { jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", webp: "image/webp" };
    if (tipos[ext]) {
      const chave = (Deno.env.get("ANTHROPIC_API_KEY") || "").trim();
      if (!chave) return json({ erro: "sem ANTHROPIC_API_KEY" }, 500);
      return json({ caminho, texto: await transcreverImagem(bytes, tipos[ext], chave) });
    }
    return json({ erro: "tipo nao suportado: " + ext }, 400);
  } catch (e) {
    return json({ erro: String(e && (e as Error).message || e).slice(0, 300) }, 500);
  }
});
