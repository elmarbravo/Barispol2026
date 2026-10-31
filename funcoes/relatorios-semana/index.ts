// Barispol Workspace · relatórios da semana (31-10-2026, relatorios-semana.sql)
//
// Elmar, 31-10-2026: «Os relatórios todos quero que sejam impressos todas as
// semanas, nas segundas-feiras, um lembrete com anexo para cada chefe de área e
// director clínico». Às segundas (07h38 de Luanda, cron bsp-relatorios-semana)
// junta os relatórios de turno da semana anterior (segunda a domingo) e manda:
//   · a cada chefe de área (relatorios_destinos.para) o PDF da sua área;
//   · à Direcção Clínica (DireccaoClinica@barispol.com) um PDF com todas as
//     áreas, uma secção por área.
// O PDF tem um relatório por página, com o número (REL-<sigla>-AAAAMMDD-<id>,
// igual ao Workspace), quem entregou, a versão em vigor, as perguntas e
// respostas (coluna resumo) e as linhas de assinatura e visto. Os relatórios
// não têm nomes de utentes; os ficheiros anexados aos relatórios nunca vão
// por e-mail (só se dizem os nomes).
// Um envio por semana e destino (relatorios_enviados, tipo «semana», dia = a
// segunda-feira da semana). {"previa": true} devolve os e-mails sem enviar
// (sem o PDF); {"semana": "AAAA-MM-DD"} escolhe a segunda-feira;
// {"forcar": true} volta a enviar.
// SEGURANÇA: igual à relatorios-diarios (código do agendamento, chave do
// servidor ou sessão de gestor).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { PDFDocument, StandardFonts, rgb } from "npm:pdf-lib@1.17.1";
import fontkit from "npm:@pdf-lib/fontkit@1.1.1";

const cabecalhos = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-bsp-agendamento",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const responder = (corpo: unknown, estado = 200) =>
  new Response(JSON.stringify(corpo), { status: estado, headers: cabecalhos });
const escapar = (t: unknown) =>
  String(t ?? "").replace(/[&<>"]/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c] as string)
  );

const MARINHO = "#292F58";
const MARINHO_BOTAO = "#273069";
const AZUL = "#2291CE";
const FONTE = "'Titillium Web','Segoe UI',Arial,sans-serif";
const LOGOTIPO = "https://barispol.com/assets/logo-barispol.png";

/* O botao que leva a pessoa ao sitio, em vez de a mandar procurar.
   Aspecto de todos os e-mails (26-09-2026): o do site novo — fundo
   branco, linhas finas, cantos rectos, marinho e azul da marca. */
const SITIO = "https://barispol.com/workspace.html";
const TEXTO = "#1C2033";
const SUAVE = "#4E5366";
const LINHA = "#DDDBD6";
const CLARO = "#F5F4F2";
function botao(destino: string, rotulo: string) {
  const href = SITIO + "#/" + destino;
  return (
    '<a href="' + href + '" style="display:inline-block;padding:12px 22px;border-radius:2px;background:' + MARINHO_BOTAO + ';border:1px solid ' + MARINHO_BOTAO + ';font-family:' + FONTE + ';font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none">' +
    rotulo + "</a>" +
    '<p style="margin:10px 0 0;font-family:' + FONTE + ';font-size:11px;color:#8A8F9E;word-break:break-all">' + href + "</p>"
  );
}
/* O cartao de todos os e-mails desta funcao: cabecalho como o do site
   (logotipo pequeno e nome), etiqueta azul, titulo em marinho, botao
   recto e a pessoa juridica no rodape marinho. */
function envelope(titulo: string, corpo: string, destino?: string, rotulo?: string, rodape?: string, etiqueta?: string, subtitulo?: string, botaoPronto?: string) {
  return (
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:' + CLARO + '"><tr><td align="center" style="padding:24px 12px">' +
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border:1px solid ' + LINHA + '">' +
    '<tr><td style="padding:16px 24px;border-bottom:1px solid ' + LINHA + '"><table role="presentation" cellpadding="0" cellspacing="0"><tr>' +
    '<td style="padding-right:12px;vertical-align:middle"><img src="' + LOGOTIPO + '" width="44" height="44" alt="Centro Médico Barispol" style="display:block;border:0;width:44px;height:44px"></td>' +
    '<td style="vertical-align:middle;font-family:' + FONTE + '"><div style="font-size:16px;font-weight:700;color:' + MARINHO + ';line-height:1.2">Centro Médico Barispol</div>' +
    '<div style="font-size:12.5px;font-weight:600;color:' + SUAVE + '">' + (subtitulo || "Workspace da equipa") + "</div></td>" +
    "</tr></table></td></tr>" +
    '<tr><td style="padding:28px 24px 26px;font-family:' + FONTE + ';color:' + TEXTO + '">' +
    '<div style="font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:' + AZUL + '">' + (etiqueta || "Resumo da manhã") + "</div>" +
    '<h1 style="margin:8px 0 16px;font-family:' + FONTE + ';font-size:24px;line-height:1.2;font-weight:700;color:' + MARINHO + '">' + titulo + "</h1>" +
    corpo +
    (botaoPronto ? '<div style="margin-top:22px">' + botaoPronto + "</div>" : destino ? '<div style="margin-top:22px">' + botao(destino, rotulo || "Abrir no Workspace") + "</div>" : "") +
    "</td></tr>" +
    '<tr><td style="padding:16px 24px;background:' + MARINHO + ';font-family:' + FONTE + ';font-size:12.5px;line-height:1.6;color:#C9CCDA">' +
    '<b style="color:#ffffff">Centro Médico Barispol</b> · ' + (rodape || "Este é o resumo automático da manhã.") + "<br>" +
    "Clínica Barispol, Lda. · NIF&nbsp;5000999687</td></tr>" +
    "</table></td></tr></table>"
  );
}

/* Paragrafo de texto corrido, na fonte e na cor da marca. */
const paragrafo = (t: string, fim = false) =>
  '<p style="margin:0' + (fim ? "" : " 0 12px") + ";font-family:" + FONTE + ";font-size:15px;line-height:1.6;color:" + TEXTO + '">' + t + "</p>";

const PREFIXO_DE_CHAVE = /^(sb_secret_|sb_publishable_|eyJ)/;

const valoresDe = (nome: string): string[] => {
  const cru = (Deno.env.get(nome) || "").trim();
  if (!cru) return [];
  if (!cru.startsWith("{") && !cru.startsWith("[")) {
    return PREFIXO_DE_CHAVE.test(cru) ? [cru] : [];
  }
  /* Le chaves e valores: nao esta escrito em lado nenhum se a chave em si
     e a etiqueta do dicionario ou o valor guardado nela. */
  const recolher = (v: unknown): string[] =>
    typeof v === "string"
      ? [v]
      : Array.isArray(v)
        ? v.flatMap(recolher)
        : v && typeof v === "object"
          ? [...Object.keys(v as object), ...Object.values(v as object)].flatMap(recolher)
          : [];
  try {
    return recolher(JSON.parse(cru)).filter((s) => PREFIXO_DE_CHAVE.test(s));
  } catch {
    return [];
  }
};

const chavesServidor = (): string[] => [
  ...valoresDe("SUPABASE_SECRET_KEYS"),
  ...valoresDe("SUPABASE_SECRET_KEY"),
  ...valoresDe("SUPABASE_SERVICE_ROLE_KEY"),
];
const chavesPublicas = (): string[] => [
  ...valoresDe("SUPABASE_PUBLISHABLE_KEYS"),
  ...valoresDe("SUPABASE_PUBLISHABLE_KEY"),
  ...valoresDe("SUPABASE_ANON_KEY"),
];

const chaveServidor = () => chavesServidor()[0] || "";
/* De onde veio a chave que esta a ser usada — so o nome da variavel,
   nunca o valor. Serve para confirmar, antes de desligar as chaves JWT,
   que a leitura no plural esta a funcionar. */
const fonteChaveServidor = (): string => {
  for (const nome of ["SUPABASE_SECRET_KEYS", "SUPABASE_SECRET_KEY", "SUPABASE_SERVICE_ROLE_KEY"]) {
    if (valoresDe(nome).length) return nome;
  }
  return "";
};
const chavePublica = () => chavesPublicas()[0] || "";
/* Quem se apresenta com uma chave de servidor — a nova ou a antiga —
   e o proprio servidor. */
const ehChaveDoServidor = (t: string) => !!t && chavesServidor().includes(t);
const ehChavePublica = (t: string) => !!t && chavesPublicas().includes(t);

/* CORS por lista (12-10-2026, auditoria de seguranca, Fase 2): a resposta so
   autoriza as origens do site e da app; antes era "*". Pedidos sem Origin
   (servidor, agendamentos) nao mudam. O que decide o acesso continua a ser
   o testemunho, nao a origem. */
const ORIGENS_PERMITIDAS = ["https://barispol.com", "https://www.barispol.com", "https://ws.barispol.com", "https://localhost", "capacitor://localhost", "http://localhost"];
const comCors = (tratar: (req: Request) => Promise<Response>) => async (req: Request): Promise<Response> => {
  const r = await tratar(req);
  const origem = req.headers.get("Origin") || "";
  const h = new Headers(r.headers);
  h.set("Access-Control-Allow-Origin", ORIGENS_PERMITIDAS.includes(origem) ? origem : ORIGENS_PERMITIDAS[0]);
  h.append("Vary", "Origin");
  return new Response(r.body, { status: r.status, statusText: r.statusText, headers: h });
};


const AREAS: Record<string, { nome: string; sigla: string }> = {
  enfermagem: { nome: "Enfermagem", sigla: "ENF" },
  farmacia: { nome: "Farmácia", sigla: "FAR" },
  imagiologia: { nome: "Imagiologia", sigla: "IMG" },
  laboratorio: { nome: "Laboratório", sigla: "LAB" },
  rececao: { nome: "Recepção", sigla: "REC" },
};
const nomeArea = (a: string) => (AREAS[a] && AREAS[a].nome) || a;
const numero = (r: any) =>
  "REL-" + ((AREAS[r.area] && AREAS[r.area].sigla) || String(r.area || "REL").slice(0, 3).toUpperCase()) + "-" + String(r.dia || "").replace(/-/g, "") + "-" + r.id;
const MESES = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
const diaPt = (iso: string) => String(iso || "").slice(0, 10).split("-").reverse().join("-");
const quando = (iso: string) => {
  if (!iso) return "";
  const d = new Date(new Date(iso).getTime() + 3600 * 1000);
  return d.getUTCDate() + " " + MESES[d.getUTCMonth()].slice(0, 3) + " " + d.getUTCFullYear() + ", " +
    String(d.getUTCHours()).padStart(2, "0") + ":" + String(d.getUTCMinutes()).padStart(2, "0");
};
const somar = (iso: string, n: number) => {
  const d = new Date(iso + "T12:00:00Z");
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};

/* O PDF: um relatório por página (continua na seguinte se não couber).
   Titillium Web vem do repositório público das Google Fonts; se não chegar,
   usa-se a Helvetica, e o texto passa a WinAnsi. */
async function fazerPdf(rels: any[], titulo: string, nomeDe: (id: string) => string): Promise<Uint8Array> {
  const pdf = await PDFDocument.create();
  pdf.setTitle(titulo);
  pdf.setAuthor("Clínica Barispol, Lda.");
  pdf.setCreator("Workspace Barispol");
  let fonte: any, forte: any, unicode = true;
  try {
    pdf.registerFontkit(fontkit);
    const base = "https://raw.githubusercontent.com/google/fonts/main/ofl/titilliumweb/";
    const [a, b] = await Promise.all([
      fetch(base + "TitilliumWeb-Regular.ttf").then((r) => { if (!r.ok) throw new Error("fonte"); return r.arrayBuffer(); }),
      fetch(base + "TitilliumWeb-Bold.ttf").then((r) => { if (!r.ok) throw new Error("fonte"); return r.arrayBuffer(); }),
    ]);
    fonte = await pdf.embedFont(a, { subset: true });
    forte = await pdf.embedFont(b, { subset: true });
  } catch {
    fonte = await pdf.embedFont(StandardFonts.Helvetica);
    forte = await pdf.embedFont(StandardFonts.HelveticaBold);
    unicode = false;
  }
  const limpo = (t: unknown) => {
    let s = String(t ?? "").replace(/\r/g, "");
    if (!unicode) s = s.replace(/[→]/g, "->").replace(/[–—]/g, "-").replace(/[^\x09\x0A\x20-\x7E -ÿ·°]/g, "");
    return s;
  };
  let logo: any = null;
  try {
    const r = await fetch("https://barispol.com/assets/logo-barispol.png");
    if (r.ok) logo = await pdf.embedPng(await r.arrayBuffer());
  } catch { /* sem logotipo */ }

  const AZUL = rgb(0x22 / 255, 0x91 / 255, 0xCE / 255);
  const MAR = rgb(0x29 / 255, 0x2F / 255, 0x58 / 255);
  const TXT = rgb(0x1C / 255, 0x20 / 255, 0x33 / 255);
  const SUA = rgb(0x4E / 255, 0x53 / 255, 0x66 / 255);
  const LIN = rgb(0xDD / 255, 0xDB / 255, 0xD6 / 255);
  const CLA = rgb(0xEA / 255, 0xF5 / 255, 0xFC / 255);
  const W = 595.28, H = 841.89, M = 42;
  const larg = W - 2 * M;

  const partir = (texto: string, f: any, tam: number, max: number): string[] => {
    const linhas: string[] = [];
    limpo(texto).split("\n").forEach((par) => {
      const pal = par.split(/\s+/).filter(Boolean);
      if (!pal.length) { linhas.push(""); return; }
      let l = "";
      pal.forEach((p) => {
        const t = l ? l + " " + p : p;
        if (f.widthOfTextAtSize(t, tam) <= max) { l = t; return; }
        if (l) linhas.push(l);
        // palavra maior do que a linha: corta-se
        let resto = p;
        while (f.widthOfTextAtSize(resto, tam) > max && resto.length > 1) {
          let k = resto.length;
          while (k > 1 && f.widthOfTextAtSize(resto.slice(0, k), tam) > max) k--;
          linhas.push(resto.slice(0, k));
          resto = resto.slice(k);
        }
        l = resto;
      });
      if (l) linhas.push(l);
    });
    return linhas;
  };

  let total = 0;
  const paginas: any[] = [];
  const novaPagina = (r: any, cont: boolean) => {
    const pg = pdf.addPage([W, H]);
    paginas.push({ pg, r });
    let y = H - M;
    if (logo) pg.drawImage(logo, { x: M, y: y - 40, width: 40, height: 40 });
    pg.drawText("Centro Médico Barispol", { x: M + 50, y: y - 16, size: 13, font: forte, color: MAR });
    pg.drawText(limpo("Clínica Barispol, Lda. · NIF 5000999687"), { x: M + 50, y: y - 31, size: 8.5, font: fonte, color: SUA });
    const et = limpo(("Relatório de turno · " + nomeArea(r.area)).toUpperCase());
    pg.drawText(et, { x: W - M - forte.widthOfTextAtSize(et, 7.5), y: y - 8, size: 7.5, font: forte, color: AZUL });
    const tt = limpo(diaPt(r.dia) + (r.turno ? " · " + r.turno : "") + (cont ? " (continuação)" : ""));
    pg.drawText(tt, { x: W - M - forte.widthOfTextAtSize(tt, 15), y: y - 25, size: 15, font: forte, color: MAR });
    const nr = numero(r);
    pg.drawText(nr, { x: W - M - fonte.widthOfTextAtSize(nr, 8), y: y - 37, size: 8, font: fonte, color: SUA });
    y -= 48;
    pg.drawRectangle({ x: M, y, width: larg, height: 1.6, color: AZUL });
    return { pg, y: y - 12 };
  };

  for (const r of rels) {
    let { pg, y } = novaPagina(r, false);
    // identificação
    const versao = r.alterado_em
      ? "Versão " + (r.versao || 2) + ", em vigor desde " + quando(r.alterado_em) + (r.alterado_autorizou ? ", autorizada por " + nomeDe(r.alterado_autorizou) : "")
      : "Versão 1 (como foi entregue)";
    const id = [["Entregue por", nomeDe(r.user_id) + " · " + quando(r.created_at)], ["Estado", versao]];
    for (const [k, v] of id) {
      const ls = partir(v, fonte, 9.5, larg - 100);
      const h = ls.length * 12 + 8;
      pg.drawRectangle({ x: M, y: y - h, width: 92, height: h, color: CLA });
      pg.drawRectangle({ x: M, y: y - h, width: larg, height: h, borderColor: LIN, borderWidth: 0.6 });
      pg.drawText(limpo(k), { x: M + 6, y: y - 13, size: 9, font: forte, color: SUA });
      ls.forEach((l, i) => pg.drawText(l, { x: M + 100, y: y - 13 - i * 12, size: 9.5, font: fonte, color: TXT }));
      y -= h;
    }
    y -= 12;
    // perguntas e respostas
    const cabecalho = () => {
      pg.drawRectangle({ x: M, y: y - 18, width: larg, height: 18, color: AZUL });
      pg.drawText("Pergunta", { x: M + 6, y: y - 13, size: 9, font: forte, color: rgb(1, 1, 1) });
      pg.drawText("Resposta", { x: M + larg * 0.42 + 6, y: y - 13, size: 9, font: forte, color: rgb(1, 1, 1) });
      y -= 18;
    };
    cabecalho();
    const linhas: [string, string][] = Array.isArray(r.resumo) ? r.resumo.filter((x: any) => Array.isArray(x) && x[1] != null && x[1] !== "") : [];
    if (!linhas.length) linhas.push(["Respostas", "Sem respostas por extenso neste relatório."]);
    let par = false;
    for (const [p, v] of linhas) {
      const lp = partir(p, fonte, 9, larg * 0.42 - 12);
      const lv = partir(String(v), fonte, 9.5, larg * 0.58 - 12);
      const h = Math.max(lp.length, lv.length) * 12 + 8;
      if (y - h < M + 70) {
        ({ pg, y } = novaPagina(r, true));
        cabecalho();
      }
      if (par) pg.drawRectangle({ x: M, y: y - h, width: larg, height: h, color: rgb(0.969, 0.98, 0.988) });
      pg.drawLine({ start: { x: M, y: y - h }, end: { x: M + larg, y: y - h }, thickness: 0.5, color: LIN });
      lp.forEach((l, i) => pg.drawText(l, { x: M + 6, y: y - 13 - i * 12, size: 9, font: fonte, color: SUA }));
      lv.forEach((l, i) => pg.drawText(l, { x: M + larg * 0.42 + 6, y: y - 13 - i * 12, size: 9.5, font: fonte, color: TXT }));
      y -= h;
      par = !par;
    }
    // assinaturas
    if (y < M + 90) ({ pg, y } = novaPagina(r, true));
    y -= 46;
    const ass = (x: number, cima: string, baixo: string) => {
      pg.drawLine({ start: { x, y }, end: { x: x + larg / 2 - 20, y }, thickness: 0.6, color: TXT });
      const c = limpo(cima), b = limpo(baixo);
      pg.drawText(c, { x: x + (larg / 2 - 20 - forte.widthOfTextAtSize(c, 9.5)) / 2, y: y - 12, size: 9.5, font: forte, color: TXT });
      pg.drawText(b, { x: x + (larg / 2 - 20 - fonte.widthOfTextAtSize(b, 8.5)) / 2, y: y - 24, size: 8.5, font: fonte, color: SUA });
    };
    ass(M, nomeDe(r.user_id), "Quem entregou");
    ass(M + larg / 2 + 20, " ", "Visto da Direcção Clínica / Chefe da área");
    total++;
  }
  // rodapé com o número de páginas
  paginas.forEach(({ pg, r }, i) => {
    const esq = limpo(numero(r) + " · documento interno, sem dados de utentes");
    const dir = limpo("Workspace Barispol · página " + (i + 1) + " de " + paginas.length);
    pg.drawText(esq, { x: M, y: 24, size: 7.5, font: fonte, color: SUA });
    pg.drawText(dir, { x: W - M - fonte.widthOfTextAtSize(dir, 7.5), y: 24, size: 7.5, font: fonte, color: SUA });
  });
  return await pdf.save();
}

const base64 = (b: Uint8Array) => {
  let s = "";
  for (let i = 0; i < b.length; i += 0x8000) s += String.fromCharCode(...b.subarray(i, i + 0x8000));
  return btoa(s);
};

Deno.serve(comCors(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cabecalhos });
  if (req.method !== "POST") return responder({ erro: "Método não permitido." }, 405);
  const URL_SB = Deno.env.get("SUPABASE_URL")!;
  const CHAVE_SERVICO = chaveServidor();
  const CHAVE_ANON = chavePublica();
  if (!URL_SB || !CHAVE_SERVICO) return responder({ erro: "A função não tem acesso ao projecto." }, 500);
  const testemunho = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const codigoAgendamento = (req.headers.get("x-bsp-agendamento") || "").trim();
  if (!testemunho && !codigoAgendamento) return responder({ erro: "Sem autorização." }, 401);
  const admin = createClient(URL_SB, CHAVE_SERVICO, { auth: { persistSession: false } });
  let autorizado = false;
  if (codigoAgendamento) {
    const { data: confere } = await admin.rpc("bsp_resumo_codigo_confere", { codigo: codigoAgendamento });
    if (confere !== true) return responder({ erro: "Código do agendamento inválido." }, 403);
    autorizado = true;
  }
  if (!autorizado) autorizado = ehChaveDoServidor(testemunho);
  if (!autorizado) {
    if (ehChavePublica(testemunho)) return responder({ erro: "A chave pública não chega para enviar correio." }, 403);
    const comSessao = createClient(URL_SB, CHAVE_ANON, {
      global: { headers: { Authorization: "Bearer " + testemunho } },
      auth: { persistSession: false },
    });
    const { data: eGestor } = await comSessao.rpc("bsp_e_gestor");
    if (eGestor !== true) return responder({ erro: "Só um gestor pode fazer isto." }, 403);
  }

  const corpo = await req.json().catch(() => ({} as any));
  const previa = corpo && corpo.previa === true;
  const forcar = corpo && corpo.forcar === true;
  // A semana anterior: da segunda à domingo antes de hoje (Luanda).
  const hoje = new Date(Date.now() + 3600 * 1000).toISOString().slice(0, 10);
  const dSem = new Date(hoje + "T12:00:00Z").getUTCDay(); // 0 = domingo
  const estaSegunda = somar(hoje, -((dSem + 6) % 7));
  const de = corpo && /^\d{4}-\d{2}-\d{2}$/.test(String(corpo.semana || "")) ? String(corpo.semana) : somar(estaSegunda, -7);
  const ate = somar(de, 6);

  const [{ data: linha }, { data: rels, error: eR }, { data: destinos }] = await Promise.all([
    admin.from("shared_state").select("team").eq("id", 1).single(),
    admin.from("relatorios_area").select("*").gte("dia", de).lte("dia", ate).order("dia", { ascending: true }).order("created_at", { ascending: true }),
    admin.from("relatorios_destinos").select("area, para"),
  ]);
  if (eR) return responder({ erro: "Não foi possível ler os relatórios: " + eR.message }, 500);
  const equipa: any[] = Array.isArray(linha && (linha as any).team) ? (linha as any).team : [];
  const nomeDe = (id: string) => { const u = equipa.find((x) => x && x.id === id); return u ? String(u.name || id) : String(id || ""); };
  const todos: any[] = rels || [];
  const porArea: Record<string, any[]> = {};
  todos.forEach((r) => { (porArea[r.area] = porArea[r.area] || []).push(r); });
  const ordem = Object.keys(AREAS).filter((a) => porArea[a]).concat(Object.keys(porArea).filter((a) => !AREAS[a]));

  const periodo = diaPt(de) + " a " + diaPt(ate);
  const dias = Array.from({ length: 7 }, (_, i) => somar(de, i));
  const resumoHtml = (areas: string[]) => {
    const linhas = areas.map((a) => {
      const l = porArea[a] || [];
      const sem = dias.filter((d) => !l.some((r) => r.dia === d));
      return "<tr><td style=\"padding:6px 8px;border-bottom:1px solid " + LINHA + "\">" + escapar(nomeArea(a)) + "</td>" +
        "<td style=\"padding:6px 8px;border-bottom:1px solid " + LINHA + ";text-align:right\">" + l.length + "</td>" +
        "<td style=\"padding:6px 8px;border-bottom:1px solid " + LINHA + ";color:" + (sem.length ? "#B42318" : SUAVE) + "\">" +
        (sem.length ? "Sem relatório: " + sem.map((d) => diaPt(d).slice(0, 5)).join(", ") : "Todos os dias") + "</td></tr>";
    }).join("");
    return '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;font-family:' + FONTE + ';font-size:13.5px;color:' + TEXTO + ';margin:6px 0 14px">' +
      '<tr><td style="background:' + CLARO + ';font-weight:700;color:' + MARINHO + ';padding:6px 8px">Área</td><td style="background:' + CLARO + ';font-weight:700;color:' + MARINHO + ';padding:6px 8px;text-align:right">Relatórios</td><td style="background:' + CLARO + ';font-weight:700;color:' + MARINHO + ';padding:6px 8px">Dias em falta</td></tr>' +
      linhas + "</table>";
  };

  const envios: any[] = [];
  const mandar = async (chave: string, para: string[], areas: string[]) => {
    const p = Array.from(new Set(para.map((e) => String(e || "").trim()).filter((e) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e))));
    if (!p.length) { envios.push({ chave, ok: false, nota: "sem destinatários" }); return; }
    const lista = areas.flatMap((a) => porArea[a] || []);
    const assunto = "Lembrete: imprimir os relatórios de turno da semana " + periodo + (areas.length === 1 ? " · " + nomeArea(areas[0]) : "");
    const corpoHtml = paragrafo("Bom dia. Em anexo seguem os relatórios de turno da semana de <b>" + periodo + "</b>" +
        (areas.length === 1 ? " da " + escapar(nomeArea(areas[0])) : ", de todas as áreas") + ", um por página, prontos para imprimir.") +
      resumoHtml(areas) +
      paragrafo("Imprima, assine o visto em cada página e arquive na pasta da área. Os dias em falta devem ser pedidos a quem estava de turno.") +
      paragrafo("Os ficheiros anexados a cada relatório (fotografias, folhas) não seguem por e-mail: abra-os no Workspace.", true);
    const html = envelope("Relatórios da semana para imprimir", corpoHtml, "relatorios", "Abrir os relatórios no Workspace",
      "Lembrete automático das segundas-feiras. Sistema · Workspace Barispol.", "Lembrete semanal", "Workspace da equipa");
    if (previa) { envios.push({ chave, para: p, assunto, relatorios: lista.length, html }); return; }
    if (!forcar) {
      const { error: jaFoi } = await admin.from("relatorios_enviados").insert({ tipo: "semana", dia: de, chave, para: p.join(", ") });
      if (jaFoi) { envios.push({ chave, para: p, ok: true, nota: "já tinha saído" }); return; }
    }
    const anexos: any[] = [];
    if (lista.length) {
      const bytes = await fazerPdf(lista, "Relatórios de turno " + periodo, nomeDe);
      anexos.push({
        filename: "Relatorios de turno " + (areas.length === 1 ? nomeArea(areas[0]).normalize("NFD").replace(/[̀-ͯ]/g, "") + " " : "") + de + " a " + ate + ".pdf",
        content: base64(bytes), content_type: "application/pdf",
      });
    }
    const r = await fetch(URL_SB.replace(/\/$/, "") + "/functions/v1/bright-worker", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: "Bearer " + CHAVE_SERVICO },
      body: JSON.stringify({ to: p, subject: assunto, html, ...(anexos.length ? { attachments: anexos } : {}) }),
    }).catch(() => null);
    const ok = !!(r && r.ok);
    const nota = r && !r.ok ? await r.text().catch(() => "") : "";
    await admin.from("relatorios_enviados").update({ ok }).eq("tipo", "semana").eq("dia", de).eq("chave", chave);
    envios.push({ chave, para: p, relatorios: lista.length, ok, ...(nota ? { nota: nota.slice(0, 200) } : {}) });
  };

  // Cada chefe de área: só a sua. Áreas sem chefe ficam só para a Direcção Clínica.
  for (const d of (destinos || []) as any[]) {
    const para: string[] = Array.isArray(d.para) ? d.para : [];
    if (!para.length) continue;
    await mandar("area-" + d.area, para, [d.area]);
  }
  // Director Clínico: todas as áreas num só PDF.
  await mandar("direccao-clinica", ["DireccaoClinica@barispol.com"], ordem.length ? ordem : Object.keys(AREAS));
  return responder({ ok: true, de, ate, relatorios: todos.length, previa, envios });
}));
