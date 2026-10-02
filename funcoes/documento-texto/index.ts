// Barispol Workspace · texto dos documentos da clínica (02-10-2026)
//
// Pedido do Elmar: «colocar o regulamento interno nas regras do sistema; ler
// os artigos e, sempre que necessário, usar sem ter de ir ler todo ele».
// Lê os documentos publicados em Documentos (tabela documentos, contentor
// drive, só a pasta documentos/) e guarda o texto em documentos_texto, para
// o assistente do Workspace e os resumos por artigo.
//   · .docx: o texto de word/document.xml, parágrafo a parágrafo.
//   · .pdf: o texto das páginas (PDF digitalizado sem texto fica vazio, com
//     metodo "pdf-sem-texto").
// Corpo: {"id": n} para um documento, ou {} para todos os que faltam;
// {"id": n, "texto": "..."} grava um texto transcrito à mão.
// PDF digitalizado: com o segredo ANTHROPIC_API_KEY nas Edge Functions, o
// texto é transcrito pelo Claude (modelo ANTHROPIC_MODEL ou o Sonnet mais
// recente da conta), palavra por palavra. Sem a chave fica "pdf-sem-texto" e
// volta a tentar na passagem seguinte (cron bsp-documentos-texto, diário).
// Nunca lê fora de documentos/: os anexos do Chat e os ficheiros pessoais
// ficam de fora.
//
// SEGURANÇA: o código do agendamento (x-bsp-agendamento, conferido pela base
// de dados) ou a chave do servidor. A chave pública não chega.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { unzipSync, strFromU8 } from "https://esm.sh/fflate@0.8.2";
import { extractText, getDocumentProxy } from "https://esm.sh/unpdf@0.12.1";

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

let modeloEscolhido = "";
async function modelo(chave: string): Promise<string> {
  if (Deno.env.get("ANTHROPIC_MODEL")) return Deno.env.get("ANTHROPIC_MODEL")!;
  if (modeloEscolhido) return modeloEscolhido;
  try {
    const r = await fetch("https://api.anthropic.com/v1/models?limit=100", { headers: { "x-api-key": chave, "anthropic-version": "2023-06-01" } });
    const d = await r.json();
    const ids: string[] = (d.data || []).map((m: any) => m.id);
    modeloEscolhido = ids.find((i) => /sonnet/.test(i)) || ids[0] || "";
  } catch { /* fica vazio */ }
  return modeloEscolhido;
}
/* Transcrição de um PDF digitalizado, palavra por palavra. */
async function transcrever(bytes: Uint8Array, chave: string): Promise<string> {
  const mod = await modelo(chave);
  if (!mod) throw new Error("sem modelo");
  let bin = "";
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": chave, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({ model: mod, max_tokens: 4000,
      system: "Transcreves documentos internos de uma clínica (notas internas, regulamentos). Devolve só o texto do documento, palavra por palavra, com os títulos e a numeração originais. Não resumas nem comentes. Assinaturas e carimbos: escreve [assinatura] ou [carimbo].",
      messages: [{ role: "user", content: [{ type: "document", source: { type: "base64", media_type: "application/pdf", data: btoa(bin) } }, { type: "text", text: "Transcreve este documento." }] }] }),
  });
  const d = await r.json();
  if (!r.ok) throw new Error("claude " + r.status + ": " + JSON.stringify(d.error || d).slice(0, 200));
  return (d.content || []).map((c: any) => c.text || "").join("").trim();
}

/* Texto de um .docx: um parágrafo por linha, tabulações e quebras mantidas. */
function textoDocx(bytes: Uint8Array): string {
  const zip = unzipSync(bytes, { filter: (f) => f.name === "word/document.xml" });
  const xml = strFromU8(zip["word/document.xml"] || new Uint8Array());
  return xml
    .replace(/<w:tab\/>/g, "\t")
    .replace(/<w:br[^>]*\/>/g, "\n")
    .replace(/<\/w:p>/g, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
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
  /* {"id": n, "texto": "...", "metodo": "transcrito"}: grava o texto de um
     documento digitalizado, transcrito à mão a partir da imagem. */
  if (corpo && Number(corpo.id) > 0 && typeof corpo.texto === "string") {
    await admin.from("documentos_texto").upsert({ documento_id: Number(corpo.id), texto: corpo.texto, metodo: String(corpo.metodo || "transcrito"), extraido_em: new Date().toISOString() });
    return json({ ok: true, id: Number(corpo.id), caracteres: corpo.texto.length });
  }
  let q = admin.from("documentos").select("id, caminho, nome_ficheiro, titulo").eq("arquivado", false);
  if (corpo && Number(corpo.id) > 0) q = q.eq("id", Number(corpo.id));
  const { data: docs, error } = await q;
  if (error) return json({ erro: error.message }, 500);
  const chaveIA = (Deno.env.get("ANTHROPIC_API_KEY") || "").trim();
  const { data: feitos } = await admin.from("documentos_texto").select("documento_id, metodo");
  /* Já lidos: todos menos os digitalizados por transcrever, quando há chave. */
  const ja = new Set((feitos || []).filter((x: any) => !(chaveIA && x.metodo === "pdf-sem-texto")).map((x: any) => x.documento_id));

  const res: any[] = [];
  for (const d of (docs || []) as any[]) {
    if (!(corpo && corpo.id) && ja.has(d.id) && !corpo.refazer) continue;
    const caminho = String(d.caminho || "");
    if (!caminho.startsWith("documentos/")) { res.push({ id: d.id, erro: "fora de documentos/" }); continue; }
    try {
      const { data: blob, error: e2 } = await admin.storage.from("drive").download(caminho);
      if (e2 || !blob) throw new Error(e2 ? e2.message : "sem ficheiro");
      const bytes = new Uint8Array(await blob.arrayBuffer());
      let texto = "", paginas: number | null = null, metodo = "";
      if (/\.docx$/i.test(caminho)) {
        texto = textoDocx(bytes); metodo = "docx";
      } else if (/\.pdf$/i.test(caminho)) {
        const pdf = await getDocumentProxy(bytes);
        const r = await extractText(pdf, { mergePages: false });
        paginas = r.totalPages;
        texto = (r.text as string[]).map((t, i) => "[Página " + (i + 1) + "]\n" + String(t || "").trim()).join("\n\n").trim();
        metodo = (r.text as string[]).join("").replace(/\s+/g, "").length > 40 ? "pdf" : "pdf-sem-texto";
        if (metodo === "pdf-sem-texto" && chaveIA) {
          texto = await transcrever(bytes, chaveIA);
          metodo = "transcrito-ia";
        }
      } else {
        metodo = "formato-nao-lido";
      }
      await admin.from("documentos_texto").upsert({ documento_id: d.id, texto, paginas, metodo, extraido_em: new Date().toISOString() });
      res.push({ id: d.id, titulo: d.titulo, metodo, caracteres: texto.length, paginas });
    } catch (e) {
      res.push({ id: d.id, titulo: d.titulo, erro: String(e).slice(0, 300) });
    }
  }
  return json({ ok: true, documentos: res });
});
