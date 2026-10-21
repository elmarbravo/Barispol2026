// Cópia de segurança do Workspace por e-mail (21-10-2026, Elmar: «envie o
// backup para o meu e-mail», opção 1: «só o Workspace»).
// Lê as tabelas do Workspace com a chave do servidor, junta-as num ZIP (um
// ficheiro JSON por tabela) e envia-o pela Resend, de geral@barispol.com,
// assinado pelo sistema. Ficam de fora, por decisão do Elmar e pela regra 4:
// utentes, marcações, inquéritos, registo clínico, facturação, pagamentos,
// salários, avaliações, registos de acesso, sessões e chaves.
// Só o servidor chama esta função (código do agendamento no cabeçalho
// x-bsp-agendamento, conferido por bsp_resumo_codigo_confere). O destino vem
// no corpo do pedido ({ "para": "..." }), nunca escrito aqui.
// Verificação de JWT desligada (autenticação própria).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import JSZip from "https://esm.sh/jszip@3.10.1";

const TABELAS = [
  "shared_state", "messages", "posts", "novidades", "tarefas_pessoais", "agenda_eventos",
  "escalas", "trocas_turno", "documentos", "documentos_leituras", "documentos_texto", "conhecimento",
  "ausencias", "formacoes", "integracoes", "integracao_passos", "integracao_modelo",
  "avarias", "equipamentos", "manutencoes_plano", "manutencoes_registo", "pedidos_compra",
  "toners_movimentos", "toners_minimo", "impressoras", "gerador", "gerador_registos",
  "transporte_viaturas", "transporte_viagens", "transporte_abastecimentos", "transporte_manutencoes", "transporte_acertos",
  "relatorios_area", "relatorios_destinos", "stock_responsaveis", "credenciais",
  "auditoria_modelos", "auditorias", "avaliacao_modelo", "fm_votos", "fm_resultados", "fm_pessoas", "fm_config",
];

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
const chaveServidor = () => [...valoresDe("SUPABASE_SECRET_KEYS"), ...valoresDe("SUPABASE_SERVICE_ROLE_KEY")][0] || "";

const resposta = (corpo: unknown, estado = 200) =>
  new Response(JSON.stringify(corpo), { status: estado, headers: { "Content-Type": "application/json" } });

const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c] as string);

Deno.serve(async (req) => {
  if (req.method !== "POST") return resposta({ erro: "Método não permitido." }, 405);
  const URL_SB = Deno.env.get("SUPABASE_URL") || "";
  const SERVICO = chaveServidor();
  if (!URL_SB || !SERVICO) return resposta({ erro: "A função não tem as chaves do projecto." }, 500);
  const admin = createClient(URL_SB, SERVICO, { auth: { persistSession: false } });

  const codigo = (req.headers.get("x-bsp-agendamento") || "").trim();
  if (!codigo) return resposta({ erro: "Sem autorização." }, 401);
  const { data: confere } = await admin.rpc("bsp_resumo_codigo_confere", { codigo });
  if (confere !== true) return resposta({ erro: "Código do agendamento inválido." }, 403);

  let pedido: any = {};
  try { pedido = await req.json(); } catch { /* corpo vazio */ }
  const para = String(pedido.para || "").trim();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(para)) return resposta({ erro: "Destino inválido." }, 400);

  const zip = new JSZip();
  const contagem: Record<string, number> = {};
  const falhas: string[] = [];
  for (const t of TABELAS) {
    const linhas: unknown[] = [];
    for (let de = 0; ; de += 1000) {
      const { data, error } = await admin.from(t).select("*").range(de, de + 999);
      if (error) { falhas.push(t + ": " + error.message); break; }
      linhas.push(...(data || []));
      if (!data || data.length < 1000) break;
    }
    contagem[t] = linhas.length;
    zip.file(t + ".json", JSON.stringify(linhas));
  }
  const agora = new Date();
  const dia = new Intl.DateTimeFormat("sv-SE", { timeZone: "Africa/Luanda" }).format(agora);
  zip.file("LEIA-ME.txt",
    "Cópia de segurança do Workspace Barispol, " + dia + ".\n" +
    "Um ficheiro JSON por tabela. Sem dados de utentes, facturação, pagamentos nem salários.\n" +
    "Os ficheiros guardados no Drive e nos Documentos (PDF, Word, imagens) não estão incluídos.\n");
  const conteudo = await zip.generateAsync({ type: "base64", compression: "DEFLATE", compressionOptions: { level: 9 } });
  const tamanhoMB = Math.round((conteudo.length * 3 / 4) / 1024 / 102.4) / 10;
  if (tamanhoMB > 38) return resposta({ erro: "Cópia com " + tamanhoMB + " MB: passa o limite do e-mail." }, 413);

  let key = Deno.env.get("RESEND_API_KEY") || "";
  if (!key) { const { data } = await admin.rpc("bsp_resend_key"); if (typeof data === "string") key = data; }
  if (!key) return resposta({ erro: "RESEND_API_KEY em falta" }, 500);

  const linhasTabela = Object.entries(contagem).map(([t, n]) =>
    '<tr><td style="padding:3px 10px 3px 0;border-bottom:1px solid #E3E7EE">' + esc(t) + '</td><td style="padding:3px 0;text-align:right;border-bottom:1px solid #E3E7EE">' + n + '</td></tr>').join("");
  const corpo =
    '<p style="margin:0 0 14px">Segue em anexo a cópia de segurança do Workspace de ' + esc(dia) + ' (' + tamanhoMB + ' MB, ZIP com um ficheiro por tabela).</p>' +
    '<p style="margin:0 0 14px">Não inclui dados de utentes, marcações, facturação, pagamentos, salários nem os ficheiros do Drive e dos Documentos.</p>' +
    (falhas.length ? '<p style="margin:0 0 14px;color:#B42318">Não foi possível copiar: ' + esc(falhas.join("; ")) + '</p>' : '') +
    '<table role="presentation" cellpadding="0" cellspacing="0" style="font-size:13px;margin:0 0 14px"><tr><th style="text-align:left;padding:0 10px 4px 0">Tabela</th><th style="text-align:right;padding:0 0 4px">Linhas</th></tr>' + linhasTabela + '</table>' +
    '<p style="margin:18px 0 0;color:#4E5366">Sistema · Workspace Barispol</p>';
  const { data: html } = await admin.rpc("bsp_envelope", { titulo: "Cópia de segurança do Workspace", corpo });

  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: "Bearer " + key },
    body: JSON.stringify({
      from: "Barispol Workspace <geral@barispol.com>",
      to: [para],
      subject: "Cópia de segurança do Workspace · " + dia,
      html: typeof html === "string" ? html : corpo,
      attachments: [{ filename: "workspace-barispol-" + dia + ".zip", content: conteudo }],
    }),
  });
  const res = await r.json().catch(() => ({}));
  try { await admin.from("emails_registo").insert({ assunto: "Cópia de segurança do Workspace", destinatarios: 1, estado: r.status, pausado: false, autor: "servidor" }); } catch { /* sem registo não pára */ }
  return resposta({ estado: r.status, tamanho_mb: tamanhoMB, tabelas: contagem, falhas, resend: res }, r.ok ? 200 : 502);
});
