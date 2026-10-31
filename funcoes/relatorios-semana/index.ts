// Barispol Workspace · relatórios da semana (31-10-2026, relatorios-semana.sql)
//
// Elmar, 31-10-2026: «Os relatórios todos quero que sejam impressos todas as
// semanas, nas segundas-feiras… a obrigatoriedade do chefe da área assinar e
// remeter ao director clínico… e um relatório do Workspace automático a fazer a
// avaliação de tudo o que recebeu e dar o seu parecer», e «não quero que imprimam
// todos os dias… muitas despesas». Às segundas (07h38 de Luanda, cron
// bsp-relatorios-semana) junta os relatórios de turno da semana anterior e:
//   · manda a cada chefe de área (relatorios_destinos.para) o PDF compacto da
//     sua área (relatórios em bloco, itens em duas colunas, selo do sistema em
//     cada um e uma só declaração do chefe no fim); as áreas sem chefe vão ao
//     Director Clínico (DireccaoClinica@), que as assina;
//   · regista cada folha em relatorios_semana_folhas, à espera de «Assinei e
//     remeti» (chefe) e «Recebido» (Director Clínico);
//   · manda ao Elmar e ao Director Clínico o parecer do Workspace sobre a semana:
//     entregas, produção, segurança do utente, recursos e atendimento por área,
//     classificação (Conforme, Atenção, Crítico), recomendações e o estado das
//     folhas; HTML no corpo e o mesmo em PDF. Com ANTHROPIC_API_KEY o parecer
//     é redigido pela IA a partir dos números (sem nomes de utentes); sem ela,
//     sai das regras.
// Termos: «Item» e «Registo» (Elmar: «o termo certo é pergunta e resposta, não
// será outra coisa?»). Logotipo lido do site (assets/logo-barispol.png). Os relatórios não têm nomes
// de utentes; os ficheiros anexados aos relatórios nunca vão por e-mail.
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
const base64 = (b: Uint8Array) => {
  let s = "";
  for (let i = 0; i < b.length; i += 0x8000) s += String.fromCharCode(...b.subarray(i, i + 0x8000));
  return btoa(s);
};

/* ── Escritor de PDF: A4, cabeçalho com logotipo, texto partido em linhas,
   quebra de página automática, rodapé numerado. ─────────────────────────── */
async function novoPdf(titulo: string) {
  const pdf = await PDFDocument.create();
  pdf.setTitle(titulo);
  pdf.setAuthor("Clínica Barispol, Lda.");
  pdf.setCreator("Workspace Barispol");
  let fonte: any, forte: any, unicode = true;
  try {
    pdf.registerFontkit(fontkit);
    const base = "https://raw.githubusercontent.com/google/fonts/main/ofl/titilliumweb/";
    const [a, b] = await Promise.all(["TitilliumWeb-Regular.ttf", "TitilliumWeb-Bold.ttf"].map((n) =>
      fetch(base + n).then((r) => { if (!r.ok) throw new Error("fonte"); return r.arrayBuffer(); })));
    fonte = await pdf.embedFont(a, { subset: true });
    forte = await pdf.embedFont(b, { subset: true });
  } catch {
    fonte = await pdf.embedFont(StandardFonts.Helvetica);
    forte = await pdf.embedFont(StandardFonts.HelveticaBold);
    unicode = false;
  }
  /* Logotipo do próprio site (assets/logo-barispol.png, 180 px). Se o site não
     responder, o PDF sai sem ele (nunca falha por isso). */
  let logo: any = null;
  try {
    const r = await fetch(LOGOTIPO);
    if (r.ok) logo = await pdf.embedPng(new Uint8Array(await r.arrayBuffer()));
  } catch { logo = null; }
  const limpo = (t: unknown) => {
    let s = String(t ?? "").replace(/\r/g, "");
    if (!unicode) s = s.replace(/[→]/g, "->").replace(/[–—]/g, "-").replace(/✓/g, "").replace(/[^\x09\x0A\x20-\x7E\u00A0-\u00FF\u00B7\u00B0]/g, "");
    else s = s.replace(/✓/g, "");
    return s;
  };
  const C = {
    azul: rgb(0x22 / 255, 0x91 / 255, 0xCE / 255), azul2: rgb(0x1C / 255, 0x7D / 255, 0xB3 / 255),
    mar: rgb(0x29 / 255, 0x2F / 255, 0x58 / 255), txt: rgb(0x1C / 255, 0x20 / 255, 0x33 / 255),
    sua: rgb(0x4E / 255, 0x53 / 255, 0x66 / 255), lin: rgb(0xDD / 255, 0xDB / 255, 0xD6 / 255),
    cla: rgb(0xEA / 255, 0xF5 / 255, 0xFC / 255), branco: rgb(1, 1, 1),
    perigo: rgb(0xB4 / 255, 0x23 / 255, 0x18 / 255), aviso: rgb(0x8A / 255, 0x5A / 255, 0), ok: rgb(0x1D / 255, 0x7A / 255, 0x46 / 255),
  };
  const W = 595.28, H = 841.89, M = 36, larg = W - 2 * M;
  const partir = (texto: unknown, f: any, tam: number, max: number): string[] => {
    const linhas: string[] = [];
    limpo(texto).split("\n").forEach((par) => {
      const pal = par.split(/\s+/).filter(Boolean);
      if (!pal.length) { linhas.push(""); return; }
      let l = "";
      pal.forEach((p) => {
        const t = l ? l + " " + p : p;
        if (f.widthOfTextAtSize(t, tam) <= max) { l = t; return; }
        if (l) linhas.push(l);
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
  const paginas: any[] = [];
  const st: any = { pg: null, y: 0, etiqueta: "", titulo: "" };
  const pagina = (etiqueta: string, tit: string) => {
    st.etiqueta = etiqueta; st.titulo = tit;
    const pg = pdf.addPage([W, H]);
    paginas.push(pg);
    const y = H - M;
    if (logo) pg.drawImage(logo, { x: M, y: y - 38, width: 38, height: 38 * 183 / 180 });
    pg.drawText("Centro Médico Barispol", { x: M + 46, y: y - 15, size: 12.5, font: forte, color: C.mar });
    pg.drawText(limpo("Clínica Barispol, Lda. · NIF 5000999687"), { x: M + 46, y: y - 29, size: 8, font: fonte, color: C.sua });
    const et = limpo(etiqueta.toUpperCase());
    pg.drawText(et, { x: W - M - forte.widthOfTextAtSize(et, 7.5), y: y - 8, size: 7.5, font: forte, color: C.azul });
    const tt = limpo(tit);
    pg.drawText(tt, { x: W - M - forte.widthOfTextAtSize(tt, 14), y: y - 25, size: 14, font: forte, color: C.mar });
    pg.drawRectangle({ x: M, y: y - 46, width: larg, height: 1.6, color: C.azul });
    st.pg = pg; st.y = y - 56;
  };
  const espaco = (h: number) => { if (st.y - h < M + 26) pagina(st.etiqueta, st.titulo); };
  const titulo2 = (t: string, cor = C.azul) => {
    espaco(26);
    st.y -= 6;
    st.pg.drawText(limpo(t.toUpperCase()), { x: M, y: st.y - 10, size: 9, font: forte, color: cor });
    st.pg.drawRectangle({ x: M, y: st.y - 14, width: larg, height: 0.8, color: cor });
    st.y -= 20;
  };
  const texto = (t: string, o: any = {}) => {
    const tam = o.tam || 9.5, f = o.forte ? forte : fonte, x = M + (o.recuo || 0);
    for (const l of partir(t, f, tam, larg - (o.recuo || 0))) {
      espaco(tam + 4);
      st.pg.drawText(l, { x, y: st.y - tam, size: tam, font: f, color: o.cor || C.txt });
      st.y -= tam + 3.5;
    }
    st.y -= o.depois ?? 3;
  };
  /* Tabela: larguras em fracções; cabeçalho azul; cores por célula. */
  const tabela = (cab: string[], linhas: { v: string; cor?: any; forte?: boolean }[][], fr: number[], tam = 8.5) => {
    const ws = fr.map((f) => f * larg);
    const desenharCab = () => {
      espaco(16);
      st.pg.drawRectangle({ x: M, y: st.y - 14, width: larg, height: 14, color: C.azul });
      let x = M;
      cab.forEach((c, i) => { st.pg.drawText(limpo(c), { x: x + 4, y: st.y - 10, size: 8, font: forte, color: C.branco }); x += ws[i]; });
      st.y -= 14;
    };
    if (cab.length) desenharCab();
    let par = false;
    for (const l of linhas) {
      const parts = l.map((c, i) => partir(c.v, c.forte ? forte : fonte, tam, ws[i] - 8));
      const h = Math.max(...parts.map((p) => p.length)) * (tam + 3) + 5;
      if (st.y - h < M + 26) { pagina(st.etiqueta, st.titulo); if (cab.length) desenharCab(); }
      if (par) st.pg.drawRectangle({ x: M, y: st.y - h, width: larg, height: h, color: rgb(0.969, 0.98, 0.988) });
      st.pg.drawLine({ start: { x: M, y: st.y - h }, end: { x: M + larg, y: st.y - h }, thickness: 0.4, color: C.lin });
      let x = M;
      parts.forEach((p, i) => {
        p.forEach((t, k) => st.pg.drawText(t, { x: x + 4, y: st.y - tam - 2 - k * (tam + 3), size: tam, font: l[i].forte ? forte : fonte, color: l[i].cor || C.txt }));
        x += ws[i];
      });
      st.y -= h;
      par = !par;
    }
    st.y -= 6;
  };
  const caixa = (t: string, cor: any) => {
    const ls = partir(t, fonte, 9, larg - 16);
    const h = ls.length * 12 + 10;
    espaco(h);
    st.pg.drawRectangle({ x: M, y: st.y - h, width: larg, height: h, color: C.cla });
    st.pg.drawRectangle({ x: M, y: st.y - h, width: 3, height: h, color: cor });
    ls.forEach((l, i) => st.pg.drawText(l, { x: M + 10, y: st.y - 13 - i * 12, size: 9, font: fonte, color: C.txt }));
    st.y -= h + 6;
  };
  const fechar = async (rodape: string) => {
    paginas.forEach((pg, i) => {
      const e = limpo(rodape), d = limpo("Workspace Barispol · página " + (i + 1) + " de " + paginas.length);
      pg.drawText(e, { x: M, y: 18, size: 7, font: fonte, color: C.sua });
      pg.drawText(d, { x: W - M - fonte.widthOfTextAtSize(d, 7), y: 18, size: 7, font: fonte, color: C.sua });
    });
    return await pdf.save();
  };
  return { pdf, C, M, larg, st, pagina, espaco, titulo2, texto, tabela, caixa, fechar, partir, fonte, forte, limpo };
}

/* PDF compacto de uma área (a folha semanal do chefe). */
async function pdfArea(area: string, lista: any[], periodo: string, nomeDe: (id: string) => string, chefeNome: string, dcNome: string) {
  const w = await novoPdf("Relatórios de turno " + nomeArea(area) + " " + periodo);
  w.pagina("Relatórios de turno · " + nomeArea(area), periodo);
  w.texto(lista.length + (lista.length === 1 ? " relatório" : " relatórios") + ". Cada um leva o selo do sistema: o técnico que o fez e quando o entregou.", { cor: w.C.sua, tam: 8.5, depois: 6 });
  for (const r of lista) {
    const linhas: [string, string][] = (Array.isArray(r.resumo) ? r.resumo : []).filter((x: any) => Array.isArray(x) && x[1] != null && x[1] !== "" && !/^(turno|fecho)$/i.test(String(x[0])));
    w.espaco(40);
    // barra do relatório
    w.st.pg.drawRectangle({ x: w.M, y: w.st.y - 15, width: w.larg, height: 15, color: w.C.cla });
    w.st.pg.drawText(w.limpo(diaPt(r.dia) + (r.turno ? " · " + r.turno : "")), { x: w.M + 5, y: w.st.y - 11, size: 9.5, font: w.forte, color: w.C.mar });
    const nr = numero(r);
    w.st.pg.drawText(nr, { x: w.M + w.larg - 5 - w.fonte.widthOfTextAtSize(nr, 7.5), y: w.st.y - 10.5, size: 7.5, font: w.fonte, color: w.C.sua });
    w.st.y -= 15;
    const selo = "Técnico: " + nomeDe(r.user_id) + " · entregue a " + quando(r.created_at) +
      (r.alterado_em ? " · versão " + (r.versao || 2) + ", autorizada" + (r.alterado_autorizou ? " por " + nomeDe(r.alterado_autorizou) : "") + " a " + quando(r.alterado_em) : " · versão 1");
    w.texto(selo, { tam: 7.5, cor: w.C.azul2, depois: 1 });
    const curtas = linhas.filter((l) => String(l[1]).length <= 60 && !/^relato/i.test(l[0]));
    const longas = linhas.filter((l) => String(l[1]).length > 60 || /^relato/i.test(l[0]));
    const filas: { v: string; cor?: any; forte?: boolean }[][] = [];
    for (let i = 0; i < curtas.length; i += 2) {
      const a = curtas[i], b = curtas[i + 1];
      filas.push([{ v: a[0], cor: w.C.sua }, { v: String(a[1]), forte: true }, { v: b ? b[0] : "", cor: w.C.sua }, { v: b ? String(b[1]) : "", forte: true }]);
    }
    if (filas.length) w.tabela([], filas, [0.3, 0.2, 0.3, 0.2], 7.8);
    for (const l of longas) w.tabela([], [[{ v: l[0], cor: w.C.sua }, { v: String(l[1]) }]], [0.3, 0.7], 7.8);
    w.st.y -= 4;
  }
  // declaração do chefe
  w.espaco(90);
  w.st.y -= 6;
  const y0 = w.st.y;
  w.st.pg.drawRectangle({ x: w.M, y: y0 - 80, width: w.larg, height: 80, borderColor: w.C.mar, borderWidth: 1.2 });
  w.st.pg.drawText("Vistos", { x: w.M + 8, y: y0 - 14, size: 9.5, font: w.forte, color: w.C.mar });
  w.st.pg.drawText(w.limpo("O chefe da área revê os " + lista.length + " relatórios acima, assina e remete ao Director Clínico, que dá o seu visto."), { x: w.M + 8, y: y0 - 27, size: 8.5, font: w.fonte, color: w.C.txt });
  const col = (w.larg - 30) / 2;
  [["Visto do chefe da área" + (chefeNome ? ": " + chefeNome : ""), "Assinatura e data"], ["Visto do Director Clínico" + (dcNome ? ": " + dcNome : ""), "Assinatura e data"]].forEach(([t, s2], i) => {
    const x = w.M + 10 + i * (col + 10);
    w.st.pg.drawLine({ start: { x, y: y0 - 58 }, end: { x: x + col, y: y0 - 58 }, thickness: 0.6, color: w.C.txt });
    w.st.pg.drawText(w.limpo(t), { x, y: y0 - 68, size: 8, font: w.forte, color: w.C.txt });
    w.st.pg.drawText(w.limpo(s2), { x, y: y0 - 77, size: 7, font: w.fonte, color: w.C.sua });
  });
  w.st.y = y0 - 86;
  return await w.fechar("Documento interno, sem dados de utentes · imprimir uma vez por semana");
}

/* ── Avaliação da semana (o parecer). Só números e escolhas dos registos. ── */
const num = (v: unknown) => { const n = Number(v); return isFinite(n) ? n : 0; };
const tem = (v: unknown, t: string) => Array.isArray(v) ? v.includes(t) : v === t;
const algum = (v: unknown, nada: string[]) => Array.isArray(v) ? v.some((x) => !nada.includes(x)) : (v != null && v !== "" && !nada.includes(String(v)));
type Achado = { nivel: "critico" | "atencao"; texto: string; recomendacao?: string };
function avaliarArea(area: string, lista: any[], dias: string[]) {
  const R = lista.map((r) => r.respostas || {});
  const soma = (k: string) => R.reduce((s, x) => s + num(x[k]), 0);
  const conta = (f: (x: any) => boolean) => R.filter(f).length;
  const achados: Achado[] = [];
  const add = (nivel: Achado["nivel"], n: number, texto: string, recomendacao?: string) => { if (n > 0) achados.push({ nivel, texto: texto.replace("{n}", String(n)), recomendacao }); };
  const semDia = dias.filter((d) => !lista.some((r) => r.dia === d));
  if (semDia.length >= 3) achados.push({ nivel: "critico", texto: "Sem relatório em " + semDia.length + " dos 7 dias (" + semDia.map((d) => diaPt(d).slice(0, 5)).join(", ") + ").", recomendacao: "Chefe da área: apurar porquê e garantir o relatório em todos os turnos da escala." });
  else if (semDia.length) achados.push({ nivel: "atencao", texto: "Sem relatório em " + semDia.map((d) => diaPt(d).slice(0, 5)).join(", ") + ".", recomendacao: "Confirmar se havia turno nesses dias." });
  // Segurança do utente (todas as áreas)
  add("critico", soma("incidentes"), "{n} incidente(s) com dano ao utente registado(s).", "Abrir ocorrência em Qualidade e analisar a causa.");
  add("atencao", soma("quase_erros"), "{n} quase-erro(s) detectado(s).", "Rever o circuito em reunião de área.");
  add("critico", conta((x) => (x.frio_min !== undefined && x.frio_min !== "" && num(x.frio_min) < 2) || (x.frio_max !== undefined && x.frio_max !== "" && num(x.frio_max) > 8)), "Frigorífico fora de 2–8 °C em {n} turno(s).", "Verificar o equipamento e os produtos guardados; registar a acção tomada.");
  add("atencao", conta((x) => tem(x.limpeza, "Com falhas (ver relato)")), "Limpeza ou recolha de resíduos com falhas em {n} turno(s).", "Serviços Gerais: rever a recolha de resíduos e cortantes.");
  add("atencao", conta((x) => algum(x.ocorrencias, ["Nenhuma"])), "Ocorrências registadas em {n} turno(s).");
  add("atencao", conta((x) => tem(x.equipamentos, "Algum com avaria") || tem(x.aparelhos, "Algum com avaria") || algum(x.avarias, ["Nenhuma"])), "Equipamento avariado em {n} turno(s).", "Confirmar que a avaria está em Serviços gerais.");
  if (area === "laboratorio") {
    const am = soma("amostras"), rej = soma("amostras_rejeitadas"), ent = soma("resultados_entregues"), atr = soma("resultados_atraso"), cr = soma("criticos"), crc = soma("criticos_comunicados");
    add("critico", conta((x) => x.ciq && x.ciq !== "Feito, dentro dos limites"), "Controlo interno de qualidade fora dos limites ou não feito em {n} turno(s).", "Reter resultados até o controlo estar dentro dos limites (ISO 15189).");
    add("critico", conta((x) => tem(x.lote_novo, "Lote novo usado sem verificação")), "Lote novo de reagente usado sem verificação em {n} turno(s).", "Verificar cada lote novo com controlo antes de usar.");
    add("critico", cr - crc, "{n} valor(es) crítico(s) sem comunicação ao médico.", "Comunicar sempre os valores críticos e registar a quem.");
    if (am && rej / am > 0.05) achados.push({ nivel: "atencao", texto: "Amostras rejeitadas: " + rej + " de " + am + " (" + Math.round(rej / am * 100) + "%, acima de 5%).", recomendacao: "Rever a técnica de colheita e a identificação dos tubos." });
    if (ent && atr / ent > 0.1) achados.push({ nivel: "atencao", texto: "Resultados fora do prazo: " + atr + " de " + ent + " (" + Math.round(atr / ent * 100) + "%).", recomendacao: "Rever o tempo de resposta por tipo de exame." });
    add("atencao", conta((x) => tem(x.reagentes, "Stock baixo") || tem(x.reagentes, "Em ruptura")), "Reagentes com stock baixo ou em ruptura em {n} turno(s).", "Pedir à Farmácia ou aos fornecedores antes da ruptura.");
    add("atencao", conta((x) => x.manutencao && x.manutencao !== "Feita em todos"), "Manutenção diária dos aparelhos incompleta em {n} turno(s).");
  }
  if (area === "enfermagem") {
    add("critico", conta((x) => x.carro_urgencia === "Não verificado"), "Carro de urgência não verificado em {n} turno(s).", "Verificar o carro de urgência em todos os turnos.");
    add("atencao", conta((x) => x.carro_urgencia === "Verificado com faltas (ver observação)"), "Carro de urgência com faltas em {n} turno(s).", "Repor o material e a medicação em falta.");
    add("critico", conta((x) => tem(x.intercorrencias, "Graves (ver observação)")), "Intercorrências graves em {n} turno(s).");
    add("atencao", conta((x) => algum(x.material, ["Nenhum"])), "Material em falta em {n} turno(s).", "Pedido à Farmácia pelo Workspace.");
    add("atencao", conta((x) => x.esterilizacao && x.esterilizacao !== "Dentro do prazo"), "Material esterilizado fora do prazo ou não verificado em {n} turno(s).");
  }
  if (area === "imagiologia") {
    const rx = soma("raiox"), rep = soma("repetidos");
    if (rx && rep / rx > 0.05) achados.push({ nivel: "atencao", texto: "Raio-X repetidos: " + rep + " de " + rx + " (" + Math.round(rep / rx * 100) + "%).", recomendacao: "Rever posicionamento e exposição; a repetição aumenta a dose ao utente." });
    add("atencao", conta((x) => tem(x.consumiveis, "Stock baixo") || tem(x.consumiveis, "Em ruptura")), "Películas ou consumíveis em falta em {n} turno(s).");
    add("critico", conta((x) => tem(x.protecao, "Com falhas (ver relato)")), "Falhas na protecção radiológica em {n} turno(s).", "Dosímetro, avental e pergunta de gravidez em todos os exames.");
  }
  if (area === "farmacia") {
    add("critico", conta((x) => tem(x.psicotropicos, "Conferidos, com diferença (ver relato)")), "Diferença na contagem de psicotrópicos em {n} turno(s).", "Apurar a diferença com a Direcção Clínica no próprio dia.");
    add("atencao", conta((x) => x.rupturas && x.rupturas !== "Nenhuma"), "Rupturas de stock em {n} turno(s).");
    add("atencao", conta((x) => x.supridas === "Parcialmente" || x.supridas === "Nenhuma"), "Receitas internas não supridas por inteiro em {n} turno(s).");
    add("atencao", conta((x) => tem(x.validades, "Há produtos a caducar em 30 dias (ver relato)")), "Produtos a caducar em 30 dias assinalados em {n} turno(s).", "Dar saída primeiro aos lotes mais curtos ou devolver.");
    add("atencao", conta((x) => tem(x.inventario, "Por enviar")), "Inventário semanal por enviar em {n} turno(s).");
  }
  if (area === "rececao") {
    add("atencao", conta((x) => x.fecho_caixa === "Por enviar" || x.tpa === "Por enviar"), "Fecho de caixa ou do TPA por enviar em {n} turno(s).", "A DAF confere os fechos no dia seguinte.");
    add("atencao", conta((x) => x.mapas && x.mapas !== "Todos entregues"), "Mapas dos médicos em falta em {n} turno(s).");
    add("atencao", conta((x) => x.marcacoes && x.marcacoes !== "Todas actualizadas"), "Estado das marcações por actualizar em {n} turno(s).");
    add("atencao", conta((x) => algum(x.documentos, ["Nenhum"])), "Documentos por regularizar no MetaGest em {n} turno(s).");
    add("atencao", soma("espera_30"), "{n} utente(s) esperaram mais de 30 minutos.", "Rever a distribuição da equipa nas horas de maior movimento.");
    add("atencao", soma("reclamacoes"), "{n} reclamação(ões) registada(s).", "Responder por escrito e registar em Qualidade.");
    add("atencao", soma("pedidos_sem_resposta"), "{n} pedido(s) de utentes sem resposta.", "Responder a todos os pedidos no próprio dia.");
    add("atencao", conta((x) => tem(x.marc_amanha, "Algumas por confirmar")), "Marcações do dia seguinte por confirmar em {n} turno(s).");
  }
  const crit = achados.filter((a) => a.nivel === "critico").length, aten = achados.filter((a) => a.nivel === "atencao").length;
  const classe = crit ? "Crítico" : aten ? "Atenção" : "Conforme";
  const producao: [string, number][] = (({
    rececao: [["Utentes atendidos", "utentes"], ["Novos utentes", "novos"]],
    farmacia: [["Receitas internas", "receitas"]],
    laboratorio: [["Pacientes", "pacientes"], ["Exames", "exames"], ["Amostras colhidas", "amostras"], ["Resultados entregues", "resultados_entregues"]],
    imagiologia: [["Pacientes", "pacientes"], ["Raio-X", "raiox"], ["Ecografias", "ecografias"]],
    enfermagem: [["Consultas apoiadas", "consultas"], ["Injecções IM", "im"], ["Injecções EV", "ev"], ["Observações", "observacoes"], ["Nebulizações", "nebulizacoes"], ["Curativos", "curativos"]],
  } as Record<string, [string, string][]>)[area] || []).map(([r, k]) => [r, soma(k)] as [string, number]);
  const satResp = soma("satisf_resp"), satOk = soma("satisf_ok");
  if (area === "rececao" && satResp) producao.push(["Satisfação (% satisfeitos)", Math.round(satOk / satResp * 100)]);
  return { area, n: lista.length, semDia, achados, crit, aten, classe, producao, alterados: lista.filter((r) => r.alterado_em).length };
}

async function parecerIa(dados: unknown): Promise<string | null> {
  const chave = (Deno.env.get("ANTHROPIC_API_KEY") || "").trim();
  if (!chave) return null;
  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": chave, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: "claude-haiku-4-5",
        max_tokens: 900,
        system: "És o assistente de gestão clínica do Centro Médico Barispol (Clínica Barispol, Lda., Luanda). Escreves em português de Portugal, sem o Acordo Ortográfico de 1990, sem gerúndio, com frases curtas e verbos concretos. Redige o parecer semanal para o Director Geral e o Director Clínico a partir dos indicadores dados. Não inventes números nem factos. Estrutura: 1) apreciação geral em 2 a 3 frases; 2) o que está bem; 3) o que exige acção esta semana, por prioridade, com quem deve agir. Sem títulos markdown; parágrafos curtos e listas com hífen.",
        messages: [{ role: "user", content: "Indicadores da semana (JSON):\n" + JSON.stringify(dados) }],
      }),
    });
    if (!r.ok) return null;
    const j = await r.json();
    const t = (j.content || []).map((c: any) => c.text || "").join("").trim();
    return t || null;
  } catch { return null; }
}

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
  const hoje = new Date(Date.now() + 3600 * 1000).toISOString().slice(0, 10);
  const dSem = new Date(hoje + "T12:00:00Z").getUTCDay();
  const estaSegunda = somar(hoje, -((dSem + 6) % 7));
  const de = corpo && /^\d{4}-\d{2}-\d{2}$/.test(String(corpo.semana || "")) ? String(corpo.semana) : somar(estaSegunda, -7);
  const ate = somar(de, 6);
  const periodo = diaPt(de) + " a " + diaPt(ate);
  const dias = Array.from({ length: 7 }, (_, i) => somar(de, i));

  const [{ data: linha }, { data: rels, error: eR }, { data: destinos }, { data: folhasAnt }] = await Promise.all([
    admin.from("shared_state").select("team").eq("id", 1).single(),
    admin.from("relatorios_area").select("*").gte("dia", de).lte("dia", ate).order("dia", { ascending: true }).order("created_at", { ascending: true }),
    admin.from("relatorios_destinos").select("area, para"),
    admin.from("relatorios_semana_folhas").select("*").lt("semana", de).gte("semana", somar(de, -28)),
  ]);
  if (eR) return responder({ erro: "Não foi possível ler os relatórios: " + eR.message }, 500);
  const equipa: any[] = Array.isArray(linha && (linha as any).team) ? (linha as any).team : [];
  const nomeDe = (id: string) => { const u = equipa.find((x) => x && x.id === id); return u ? String(u.name || id) : String(id || ""); };
  const todos: any[] = rels || [];
  const porArea: Record<string, any[]> = {};
  todos.forEach((r) => { (porArea[r.area] = porArea[r.area] || []).push(r); });
  const ordem = Object.keys(AREAS).concat(Object.keys(porArea).filter((a) => !AREAS[a]));
  const chefes: Record<string, string[]> = {};
  ((destinos || []) as any[]).forEach((d) => { if (Array.isArray(d.para) && d.para.length) chefes[d.area] = d.para; });

  const envios: any[] = [];
  const enviar = async (chave: string, para: string[], assunto: string, html: string, anexo?: { nome: string; bytes: Uint8Array }) => {
    const p = Array.from(new Set(para.map((e) => String(e || "").trim()).filter((e) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e))));
    if (!p.length) { envios.push({ chave, ok: false, nota: "sem destinatários" }); return false; }
    if (previa) { envios.push({ chave, para: p, assunto, html, anexo: anexo ? anexo.nome + " (" + anexo.bytes.length + " bytes)" : null }); return true; }
    if (!forcar) {
      const { error: jaFoi } = await admin.from("relatorios_enviados").insert({ tipo: "semana", dia: de, chave, para: p.join(", ") });
      if (jaFoi) { envios.push({ chave, para: p, ok: true, nota: "já tinha saído" }); return true; }
    }
    const r = await fetch(URL_SB.replace(/\/$/, "") + "/functions/v1/bright-worker", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: "Bearer " + CHAVE_SERVICO },
      body: JSON.stringify({ to: p, subject: assunto, html, ...(anexo ? { attachments: [{ filename: anexo.nome, content: base64(anexo.bytes), content_type: "application/pdf" }] } : {}) }),
    }).catch(() => null);
    const ok = !!(r && r.ok);
    const nota = r && !r.ok ? await r.text().catch(() => "") : "";
    await admin.from("relatorios_enviados").update({ ok }).eq("tipo", "semana").eq("dia", de).eq("chave", chave);
    envios.push({ chave, para: p, ok, ...(nota ? { nota: nota.slice(0, 200) } : {}) });
    return ok;
  };
  const semAcentos = (t: string) => t.normalize("NFD").replace(/[\u0300-\u036f]/g, "");

  // 1. Folha de cada área: ao chefe, ou ao Director Clínico se a área não tem chefe.
  const semChefe: string[] = [];
  for (const area of ordem) {
    const lista = porArea[area] || [];
    if (!lista.length) continue;
    const para = chefes[area] || ["DireccaoClinica@barispol.com"];
    if (!chefes[area]) semChefe.push(area);
    const chefeNome = (chefes[area] || []).map((e) => { const u = equipa.find((x) => x && String(x.email || "").toLowerCase() === String(e).toLowerCase()); return u ? String(u.name) : ""; }).filter(Boolean).join(", ");
    const bytes = await pdfArea(area, lista, periodo, nomeDe, chefeNome, nomeDe("u14"));
    const corpoHtml = paragrafo("Bom dia. Em anexo segue a folha semanal da <b>" + escapar(nomeArea(area)) + "</b>, de " + periodo + ": " + lista.length + (lista.length === 1 ? " relatório" : " relatórios") + ", em formato compacto.") +
      paragrafo("<b>O que fazer:</b> imprimir uma vez, rever, assinar a declaração no fim e entregar ao Director Clínico. Depois, no Workspace (Relatórios → Folhas semanais), carregar em «Assinei e remeti».") +
      paragrafo("Não é preciso imprimir os relatórios todos os dias: cada relatório já tem o selo do sistema (quem entregou e quando).", true);
    const html = envelope("Folha semanal para assinar · " + nomeArea(area), corpoHtml, "relatorios", "Abrir Relatórios no Workspace",
      "Lembrete automático das segundas-feiras. Sistema · Workspace Barispol.", "Relatórios de turno", "Workspace da equipa");
    const ok = await enviar("area-" + area, para, "Folha semanal para assinar: " + nomeArea(area) + ", " + periodo, html,
      { nome: "Relatorios " + semAcentos(nomeArea(area)) + " " + de + " a " + ate + ".pdf", bytes });
    if (!previa) await admin.from("relatorios_semana_folhas").upsert({ semana: de, area, relatorios: lista.length, ...(ok ? { enviado_em: new Date().toISOString() } : {}) }, { onConflict: "semana,area" });
  }

  // 2. Parecer do Workspace ao Elmar e ao Director Clínico.
  const av = ordem.filter((a) => AREAS[a]).map((a) => avaliarArea(a, porArea[a] || [], dias));
  const pendentes = ((folhasAnt || []) as any[]).filter((f) => !f.assinado_em || !f.recebido_em);
  const globalCrit = av.reduce((s, a) => s + a.crit, 0), globalAten = av.reduce((s, a) => s + a.aten, 0);
  const classeGeral = globalCrit ? "Crítico" : globalAten ? "Atenção" : "Conforme";
  const dadosIa = {
    semana: periodo, relatorios: todos.length,
    areas: av.map((a) => ({ area: nomeArea(a.area), relatorios: a.n, dias_sem_relatorio: a.semDia.length, classificacao: a.classe, producao: Object.fromEntries(a.producao), achados: a.achados.map((x) => x.nivel + ": " + x.texto), relatorios_alterados: a.alterados })),
    folhas_por_assinar_ou_receber: pendentes.map((f) => nomeArea(f.area) + " (semana de " + diaPt(f.semana) + ")"),
  };
  const textoIa = await parecerIa(dadosIa);
  const regras = (() => {
    const l: string[] = [];
    l.push("Semana de " + periodo + ": " + todos.length + " relatórios de turno em " + av.filter((a) => a.n).length + " áreas. Classificação geral: " + classeGeral + " (" + globalCrit + " ponto(s) crítico(s), " + globalAten + " de atenção).");
    const bem = av.filter((a) => a.classe === "Conforme" && a.n).map((a) => nomeArea(a.area));
    if (bem.length) l.push("Conformes: " + bem.join(", ") + ".");
    const crit = av.flatMap((a) => a.achados.filter((x) => x.nivel === "critico").map((x) => "- " + nomeArea(a.area) + ": " + x.texto + (x.recomendacao ? " " + x.recomendacao : "")));
    if (crit.length) l.push("Exige acção esta semana:\n" + crit.join("\n"));
    if (pendentes.length) l.push("Folhas semanais anteriores por assinar ou receber: " + pendentes.map((f) => nomeArea(f.area) + " (" + diaPt(f.semana) + ")").join(", ") + ".");
    return l.join("\n\n");
  })();
  const parecer = textoIa || regras;
  const corCls = (c: string) => c === "Crítico" ? "#B42318" : c === "Atenção" ? "#8A5A00" : "#1D7A46";
  const td = "padding:6px 8px;border-bottom:1px solid " + LINHA + ";vertical-align:top;font-family:" + FONTE + ";font-size:13px;color:" + TEXTO;
  const th = "padding:6px 8px;background:" + CLARO + ";font-family:" + FONTE + ";font-size:12px;font-weight:700;color:" + MARINHO + ";text-align:left";
  const sec = (t: string) => '<div style="margin:22px 0 8px;padding-bottom:5px;border-bottom:2px solid ' + AZUL + ';font-family:' + FONTE + ';font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:' + AZUL + '">' + t + "</div>";
  const htmlParecer = escapar(parecer).split(/\n{2,}/).map((p) => paragrafo(p.replace(/\n/g, "<br>"))).join("");
  const tabelaResumo = '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse">' +
    '<tr><td style="' + th + '">Área</td><td style="' + th + ';text-align:right">Relatórios</td><td style="' + th + '">Dias sem relatório</td><td style="' + th + '">Avaliação</td></tr>' +
    av.map((a) => '<tr><td style="' + td + '">' + escapar(nomeArea(a.area)) + '</td><td style="' + td + ';text-align:right">' + a.n + '</td><td style="' + td + '">' + (a.semDia.length ? a.semDia.map((d) => diaPt(d).slice(0, 5)).join(", ") : "—") + '</td><td style="' + td + ';font-weight:700;color:' + corCls(a.classe) + '">' + a.classe + "</td></tr>").join("") + "</table>";
  const detalhe = av.filter((a) => a.n || a.semDia.length).map((a) =>
    '<div style="margin:14px 0 4px;font-family:' + FONTE + ';font-size:15px;font-weight:700;color:' + MARINHO + '">' + escapar(nomeArea(a.area)) + ' · <span style="color:' + corCls(a.classe) + '">' + a.classe + "</span></div>" +
    (a.producao.length ? paragrafo(a.producao.map(([r, v]) => escapar(r) + ": <b>" + v + "</b>").join(" · ")) : "") +
    (a.achados.length ? '<ul style="padding-left:18px;margin:4px 0 8px">' + a.achados.map((x) => '<li style="margin-bottom:4px;font-family:' + FONTE + ';font-size:13.5px;line-height:1.5;color:' + (x.nivel === "critico" ? "#B42318" : TEXTO) + '">' + escapar(x.texto) + (x.recomendacao ? ' <span style="color:' + SUAVE + '">' + escapar(x.recomendacao) + "</span>" : "") + "</li>").join("") + "</ul>" : paragrafo("Sem pontos a assinalar.")) +
    (a.alterados ? paragrafo(a.alterados + " relatório(s) alterado(s) com autorização nesta semana.") : "")).join("");
  const folhasHtml = pendentes.length ? sec("Folhas semanais em atraso") + '<ul style="padding-left:18px;margin:4px 0 8px">' + pendentes.map((f) => '<li style="font-family:' + FONTE + ';font-size:13.5px;color:' + TEXTO + '">' + escapar(nomeArea(f.area)) + ", semana de " + diaPt(f.semana) + ": " + (!f.assinado_em ? "por assinar pelo chefe da área" : "por receber pelo Director Clínico") + "</li>").join("") + "</ul>" : "";
  const corpoParecer = paragrafo("Avaliação automática de todos os relatórios de turno recebidos de " + periodo + ". Classificação geral: <b style=\"color:" + corCls(classeGeral) + "\">" + classeGeral + "</b>.") +
    sec("Parecer" + (textoIa ? " (redigido pela IA a partir dos números)" : "")) + htmlParecer +
    sec("Resumo por área") + tabelaResumo + sec("Detalhe por área") + detalhe + folhasHtml +
    paragrafo('<span style="color:' + SUAVE + ';font-size:12.5px">Critérios: Crítico = risco para o utente ou falha de controlo obrigatório (incidente com dano, frio fora de 2–8 °C, controlo de qualidade, valores críticos, psicotrópicos, carro de urgência, 3 ou mais dias sem relatório). Atenção = falhas de processo ou de recursos. Fontes: relatórios de turno do Workspace; sem nomes de utentes.</span>', true);
  const htmlP = envelope("Parecer semanal dos relatórios de turno", corpoParecer, "relatorios", "Abrir Relatórios no Workspace",
    "Parecer automático do Workspace, às segundas-feiras. Sistema · Workspace Barispol.", "Parecer do Workspace", periodo);
  // PDF do parecer
  const w = await novoPdf("Parecer semanal " + periodo);
  w.pagina("Parecer do Workspace · relatórios de turno", periodo);
  const corPdf = (c: string) => c === "Crítico" ? w.C.perigo : c === "Atenção" ? w.C.aviso : w.C.ok;
  w.caixa("Classificação geral: " + classeGeral + ". " + todos.length + " relatórios de turno avaliados. " + globalCrit + " ponto(s) crítico(s) e " + globalAten + " de atenção.", corPdf(classeGeral));
  w.titulo2("Parecer" + (textoIa ? " (redigido pela IA a partir dos números)" : ""));
  parecer.split(/\n{2,}/).forEach((p) => w.texto(p, { depois: 6 }));
  w.titulo2("Resumo por área");
  w.tabela(["Área", "Relatórios", "Dias sem relatório", "Avaliação"], av.map((a) => [{ v: nomeArea(a.area), forte: true }, { v: String(a.n) }, { v: a.semDia.length ? a.semDia.map((d) => diaPt(d).slice(0, 5)).join(", ") : "—" }, { v: a.classe, forte: true, cor: corPdf(a.classe) }]), [0.3, 0.15, 0.35, 0.2]);
  for (const a of av.filter((x) => x.n || x.semDia.length)) {
    w.titulo2(nomeArea(a.area) + " · " + a.classe, corPdf(a.classe));
    if (a.producao.length) w.texto(a.producao.map(([r, v]) => r + ": " + v).join(" · "), { tam: 9 });
    if (a.achados.length) w.tabela(["Nível", "Registo", "Recomendação"], a.achados.map((x) => [{ v: x.nivel === "critico" ? "Crítico" : "Atenção", forte: true, cor: x.nivel === "critico" ? w.C.perigo : w.C.aviso }, { v: x.texto }, { v: x.recomendacao || "—", cor: w.C.sua }]), [0.12, 0.48, 0.4]);
    else w.texto("Sem pontos a assinalar.", { cor: w.C.sua });
  }
  if (pendentes.length) {
    w.titulo2("Folhas semanais em atraso", w.C.perigo);
    w.tabela(["Área", "Semana", "Falta"], pendentes.map((f) => [{ v: nomeArea(f.area) }, { v: diaPt(f.semana) }, { v: !f.assinado_em ? "Assinatura do chefe da área" : "Recepção do Director Clínico" }]), [0.3, 0.2, 0.5]);
  }
  w.titulo2("Critérios", w.C.sua);
  w.texto("Crítico: risco para o utente ou falha de controlo obrigatório (incidente com dano, frio fora de 2–8 °C, controlo de qualidade, valores críticos, psicotrópicos, carro de urgência, 3 ou mais dias sem relatório). Atenção: falhas de processo ou de recursos. Fonte: relatórios de turno do Workspace, sem nomes de utentes.", { tam: 8, cor: w.C.sua });
  const bytesP = await w.fechar("Parecer automático · documento interno, sem dados de utentes");
  await enviar("parecer", ["elmar.bravo@barispol.com", "DireccaoClinica@barispol.com"], "Parecer semanal dos relatórios de turno: " + periodo + " · " + classeGeral, htmlP,
    { nome: "Parecer semanal " + de + " a " + ate + ".pdf", bytes: bytesP });

  return responder({ ok: true, de, ate, relatorios: todos.length, classe: classeGeral, ia: !!textoIa, previa, envios });
}));
