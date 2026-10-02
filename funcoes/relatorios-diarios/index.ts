// Barispol Workspace · relatórios diários (02-10-2026, relatorios-diarios.sql)
//
// Os relatórios que saíam pelo Zapier (parados a 28-09-2026, sem tarefas no
// plano) passam a sair daqui, pelo Supabase. Pelo campo "qual" do corpo:
//   · "direccao" (06h50 de Luanda, bsp-relatorio-direccao): o resumo do dia
//     anterior, com valores, aos sócios e ao Director, mais os endereços de
//     relatorios_diarios_destinos (guardados só no servidor). Os números vêm
//     da API do MetaGest (erp.sales_invoice), iguais aos do Painel.
//   · "areas" (07h15, bsp-relatorio-areas): a cada chefe de área
//     (bsp_escalas_responsaveis) o que é da sua área, sem valores, com
//     adm@barispol.com em cópia. A Imagiologia vai para a Direcção
//     Clínica (u14), e não para o responsável da área (Elmar, 02-10-2026).
// Utentes nunca com nome. Um envio por relatório, dia e destino
// (relatorios_enviados). {"previa": true} devolve os e-mails sem enviar;
// {"dia": "AAAA-MM-DD"} escolhe o dia; {"forcar": true} volta a enviar.
//
// SEGURANÇA: igual à resumo-matinal. O código do agendamento (cabeçalho
// x-bsp-agendamento, conferido pela base de dados), a chave do servidor ou
// a sessão de um gestor. A chave pública sozinha não envia nada.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

/* A marca: as cores do logotipo e a fonte Dax, com Titillium Web, Segoe UI
   e Arial de recurso. A Dax so aparece a quem a tiver instalada — um
   e-mail nao leva fontes consigo, e o Gmail e o Outlook ignoram as da
   rede. O logotipo vem do proprio site. */
const MARINHO = "#292F58";
const MARINHO_BOTAO = "#273069";
const AZUL = "#2291CE";
const FONTE = "Dax,'Dax Pro','Titillium Web','Segoe UI',Arial,sans-serif";
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

/* Onde estao as chaves do projecto.

   O Supabase injecta SUPABASE_SECRET_KEYS e SUPABASE_PUBLISHABLE_KEYS —
   no plural, e com um dicionario JSON la dentro. As antigas
   SUPABASE_SERVICE_ROLE_KEY e SUPABASE_ANON_KEY ainda existem, marcadas
   como obsoletas, e desaparecem no dia em que se desligarem as chaves
   JWT. O singular SUPABASE_SECRET_KEY nunca existiu: quem procurasse so
   por ele tinha uma funcao que parecia instalada hoje e devolvia 500
   amanha.

   Le-se tudo, pela mesma razao por que se aceita um e-mail antigo e um
   novo durante uma mudanca: para nada parar no intervalo. */
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cabecalhos });
  if (req.method !== "POST") return responder({ erro: "Método não permitido." }, 405);

  const URL_SB = Deno.env.get("SUPABASE_URL")!;
  const CHAVE_SERVICO = chaveServidor();
  const CHAVE_ANON = chavePublica();
  if (!URL_SB || !CHAVE_SERVICO) {
    return responder({ erro: "A função não tem acesso ao projecto." }, 500);
  }

  const testemunho = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const codigoAgendamento = (req.headers.get("x-bsp-agendamento") || "").trim();
  if (!testemunho && !codigoAgendamento) return responder({ erro: "Sem autorização." }, 401);

  const admin = createClient(URL_SB, CHAVE_SERVICO, {
    auth: { persistSession: false },
  });

  /* Quem pode mandar isto correr: o agendamento (o codigo do cofre, ou a
     chave service_role) ou um gestor a carregar no botão. O codigo nunca
     sai da base de dados: quem confere e ela, e so responde sim ou nao. */
  let autorizado = false;
  if (codigoAgendamento) {
    const { data: confere } = await admin.rpc("bsp_resumo_codigo_confere", { codigo: codigoAgendamento });
    if (confere !== true) return responder({ erro: "Código do agendamento inválido." }, 403);
    autorizado = true;
  }
  if (!autorizado) autorizado = ehChaveDoServidor(testemunho);
  if (!autorizado) {
    if (ehChavePublica(testemunho)) {
      return responder({ erro: "A chave pública não chega para enviar correio." }, 403);
    }
    const comSessao = createClient(URL_SB, CHAVE_ANON, {
      global: { headers: { Authorization: "Bearer " + testemunho } },
      auth: { persistSession: false },
    });
    const { data: eGestor } = await comSessao.rpc("bsp_e_gestor");
    if (eGestor !== true) return responder({ erro: "Só um gestor pode fazer isto." }, 403);
    autorizado = true;
  }

  const corpo = await req.json().catch(() => ({} as any));
  const forcar = corpo && corpo.forcar === true;
  const tipo = "relatorios";

  const { data: linha, error } = await admin.from("shared_state").select("team, camadas").eq("id", 1).single();
  if (error || !linha) return responder({ erro: "Não foi possível ler os dados." }, 500);
  const equipa: any[] = Array.isArray(linha.team) ? linha.team : [];
  /* Mesmas regras da resumo-matinal: e-mail válido, sem a marca semEmails. */
  const semEmails = new Set(equipa.filter((u: any) => u && u.semEmails).map((u: any) => String(u.email || "").trim().toLowerCase()));
  const daClinica = (email: unknown) => {
    const e = String(email || "").trim().toLowerCase();
    return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e) && !semEmails.has(e);
  };
  const camadas: any = (linha as any).camadas || {};
  const socio = (u: any) => !!u && (u.accessLevel === "Sócio" || !!(camadas[u.accessLevel] && camadas[u.accessLevel].soNumeros));

    const qual = corpo && corpo.qual === "areas" ? "areas" : "direccao";
    const previa = corpo && corpo.previa === true;
    const luanda = new Date(Date.now() + 3600 * 1000);
    const ontem = new Date(Date.UTC(luanda.getUTCFullYear(), luanda.getUTCMonth(), luanda.getUTCDate() - 1)).toISOString().slice(0, 10);
    const dia = corpo && /^\d{4}-\d{2}-\d{2}$/.test(String(corpo.dia || "")) ? String(corpo.dia) : ontem;
    const MESES = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
    const SEMANA = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"];
    const SEM_C = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];
    const dt = (iso: string) => new Date(iso + "T12:00:00Z");
    const longa = (iso: string) => { const d = dt(iso); return SEMANA[d.getUTCDay()] + ", " + d.getUTCDate() + " de " + MESES[d.getUTCMonth()] + " de " + d.getUTCFullYear(); };
    const curta = (iso: string) => { const d = dt(iso); return d.getUTCDate() + " de " + MESES[d.getUTCMonth()]; };
    const n0 = (v: unknown) => Number(v || 0).toLocaleString("pt-PT", { maximumFractionDigits: 0 });
    const kz = (v: unknown) => Number(v || 0).toLocaleString("pt-PT", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + " Kz";
    const pc = (a: number, b: number) => (b ? (a / b * 100).toLocaleString("pt-PT", { maximumFractionDigits: 1 }) + "%" : "—");
    const frase = (t: string) => { const x = String(t || "").trim().toLowerCase(); return x ? x.charAt(0).toUpperCase() + x.slice(1) : ""; };
    const sec = (t: string) => '<div style="margin:24px 0 10px;padding-bottom:5px;border-bottom:2px solid ' + AZUL + ';font-family:' + FONTE + ';font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:' + AZUL + '">' + t + "</div>";
    const mosaicos = (itens: [string, string, string?][]) =>
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:separate;border-spacing:6px 6px;margin:0 -6px"><tr>' +
      itens.map(([r, v, s]) =>
        '<td style="width:' + Math.floor(100 / itens.length) + '%;vertical-align:top;border:1px solid ' + LINHA + ';padding:10px 12px;font-family:' + FONTE + '">' +
        '<div style="font-size:20px;font-weight:700;color:' + MARINHO + ';white-space:nowrap">' + v + "</div>" +
        '<div style="font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:' + SUAVE + ';margin-top:2px">' + r + "</div>" +
        (s ? '<div style="font-size:12px;color:' + SUAVE + ';margin-top:2px">' + s + "</div>" : "") + "</td>").join("") +
      "</tr></table>";
    const barras = (linhas: { r: string; v: number; t: string; cor?: string }[]) => {
      const max = Math.max(1, ...linhas.map((l) => Math.abs(l.v)));
      return '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="font-family:' + FONTE + ';font-size:13px;color:' + TEXTO + '">' +
        linhas.map((l) =>
          '<tr><td style="padding:3px 10px 3px 0;white-space:nowrap;width:1%">' + l.r + '</td><td style="padding:3px 0"><table role="presentation" cellpadding="0" cellspacing="0" width="100%"><tr>' +
          '<td style="width:' + Math.max(1, Math.round(Math.abs(l.v) / max * 70)) + '%;background:' + (l.cor || MARINHO) + ';height:14px;font-size:1px">&nbsp;</td>' +
          '<td style="padding-left:8px;white-space:nowrap">' + l.t + "</td></tr></table></td></tr>").join("") + "</table>";
    };
    const lista = (itens: string[], cor?: string) => itens.length
      ? '<ul style="padding-left:18px;margin:4px 0 8px">' + itens.map((t) => '<li style="margin-bottom:4px;font-family:' + FONTE + ';font-size:14px;line-height:1.5;color:' + (cor || TEXTO) + '">' + t + "</li>").join("") + "</ul>" : "";
    const tabela = (cab: string[], linhas: string[][]) =>
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;font-family:' + FONTE + ';font-size:13px;color:' + TEXTO + ';margin:4px 0 8px">' +
      "<tr>" + cab.map((c, i) => '<td style="background:' + CLARO + ';font-weight:700;color:' + MARINHO + ';padding:6px 8px;font-size:12px' + (i ? ";text-align:right" : "") + '">' + c + "</td>").join("") + "</tr>" +
      linhas.map((l) => "<tr>" + l.map((c, i) => '<td style="padding:5px 8px;border-bottom:1px solid ' + LINHA + (i ? ";text-align:right;white-space:nowrap" : "") + '">' + c + "</td>").join("") + "</tr>").join("") + "</table>";
    const COR_NIVEL: Record<string, string> = { perigo: "#B42318", aviso: "#8A5A00", info: SUAVE };
    const alertasHtml = (al: any[]) => al.length
      ? sec("Alertas") + lista(al.map((a) => '<span style="color:' + (COR_NIVEL[a.nivel] || TEXTO) + '">' + escapar(a.texto) + "</span>")) : "";
    const { data: destinos } = await admin.from("relatorios_diarios_destinos").select("tipo, para, cc");
    const extra = (t: string) => ((destinos || []) as any[]).find((d) => d.tipo === t) || { para: [], cc: [] };
    const reservar = async (chave: string, para: string) => {
      if (previa || forcar) return true;
      const { error: jaFoi } = await admin.from("relatorios_enviados").insert({ tipo: qual, dia, chave, para });
      return !jaFoi;
    };
    const mandar = async (chave: string, para: string[], cc: string[], assunto: string, html: string) => {
      const p = Array.from(new Set(para.map((e) => e.trim()).filter(Boolean)));
      const c = Array.from(new Set(cc.map((e) => e.trim()).filter((e) => e && !p.some((x) => x.toLowerCase() === e.toLowerCase()))));
      if (!p.length) return { chave, para: p, cc: c, ok: false, nota: "sem destinatários" };
      if (previa) return { chave, para: p, cc: c, assunto, html };
      if (!(await reservar(chave, p.join(", ")))) return { chave, para: p, ok: true, nota: "já tinha saído" };
      const r = await fetch(URL_SB.replace(/\/$/, "") + "/functions/v1/bright-worker", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: "Bearer " + CHAVE_SERVICO },
        body: JSON.stringify({ to: p, subject: assunto, html, ...(c.length ? { cc: c } : {}) }),
      }).catch(() => null);
      const ok = !!(r && r.ok);
      await admin.from("relatorios_enviados").update({ ok }).eq("tipo", qual).eq("dia", dia).eq("chave", chave);
      return { chave, para: p, cc: c, ok };
    };

    if (qual === "direccao") {
      const { data: d, error: eD } = await admin.rpc("bsp_srv_direccao_dados", { p_dia: dia });
      if (eD || !d) return responder({ erro: "Não foi possível ler o MetaGest: " + (eD ? eD.message : "sem dados") }, 500);
      const r = d.resumo || {};
      const serie: any[] = d.serie || [];
      const semana = serie.reduce((a, x) => a + Number(x.facturado || 0), 0);
      const media = serie.length ? semana / serie.length : 0;
      const vesp = serie.length > 1 ? Number(serie[serie.length - 2].facturado || 0) : 0;
      const fact = Number(r.facturado || 0);
      const varTxt = (a: number, b: number) => { if (!b) return "—"; const v = (a - b) / b * 100; return '<b style="color:' + (v < 0 ? "#B42318" : "#1D7A46") + '">' + (v > 0 ? "+" : "") + v.toLocaleString("pt-PT", { maximumFractionDigits: 1 }) + "%</b>"; };
      const origem: any[] = d.origem || [];
      const totOrig = origem.reduce((a, x) => a + Number(x.valor || 0), 0);
      const servico: any[] = d.servico || [];
      const totServ = servico.reduce((a, x) => a + Number(x.valor || 0), 0);
      const c = d.clinico || {};
      const mes = d.mes || {};
      const corpoHtml =
        paragrafo("Resumo de " + longa(dia) + ", com os números da API do MetaGest.") +
        mosaicos([
          ["Facturado", kz(fact), n0(r.documentos) + " documentos"],
          ["Utentes", n0(r.utentes), r.utentes ? kz(fact / Number(r.utentes)) + " por utente" : ""],
        ]) +
        mosaicos([
          ["Recebido no acto", kz(r.recebido), pc(Number(r.recebido || 0), fact) + " do facturado"],
          ["Por cobrar", kz(r.por_cobrar), Number(r.por_cobrar_seg || 0) ? kz(r.por_cobrar_seg) + " de seguradoras" : ""],
        ]) +
        (Number(r.notas_credito || 0) ? paragrafo("Notas de crédito do dia: " + kz(r.notas_credito) + " (já descontadas do facturado).") : "") +
        sec("Últimos 7 dias") +
        barras(serie.map((x) => ({ r: SEM_C[dt(x.dia).getUTCDay()] + " " + x.dia.slice(8, 10) + "/" + x.dia.slice(5, 7), v: Number(x.facturado || 0), t: kz(x.facturado) + " · " + n0(x.utentes) + " ut." }))) +
        paragrafo("Total da semana <b>" + kz(semana) + "</b> · média diária <b>" + kz(media) + "</b>.") +
        sec("Evolução") +
        lista(["Face à véspera (" + kz(vesp) + "): " + varTxt(fact, vesp), "Face à média diária da semana (" + kz(media) + "): " + varTxt(fact, media)]) +
        sec(MESES[dt(dia).getUTCMonth()] + " até agora") +
        mosaicos([["Facturado no mês", kz(mes.facturado), n0(mes.dias) + (Number(mes.dias) === 1 ? " dia fechado" : " dias fechados")], ["Média diária", kz(Number(mes.facturado || 0) / Math.max(1, Number(mes.dias || 1))), "1 a " + n0(mes.dias) + " de " + MESES[dt(dia).getUTCMonth()]]]) +
        sec("Actividade clínica do dia") +
        lista([
          n0(c.utentes) + " utentes atendidos, " + n0(c.novos) + " novos",
          n0(c.consultas) + " consultas · " + n0(c.exames_lab) + " exames de laboratório" + (Number(c.exames_externos) ? " · " + n0(c.exames_externos) + " externos" : ""),
          n0(c.actos_enfermagem) + " actos de enfermagem · " + n0(c.raiox) + " raio-X · " + n0(c.ecografias) + " ecografias · " + n0(c.cardiologia) + " cardiologia",
          n0(c.unidades_farmacia) + " unidades vendidas na farmácia (" + n0(c.produtos_farmacia) + " produtos)",
        ]) +
        (origem.length ? sec("Origem da receita · 7 dias") + barras(origem.map((o) => ({ r: escapar(o.origem), v: Number(o.valor), t: kz(o.valor) + " (" + pc(Number(o.valor), totOrig) + ")", cor: o.origem === "Seguradoras" ? AZUL : MARINHO }))) : "") +
        (servico.length ? sec("Receita por serviço · 7 dias") + barras(servico.map((o) => ({ r: escapar(frase(o.servico)), v: Number(o.valor), t: pc(Number(o.valor), totServ) }))) : "");
      const html = envelope("Resumo do dia " + curta(dia), corpoHtml, "painel", "Abrir o Painel",
        "Resumo diário da Direcção, todos os dias às 06h50.", "Resumo diário de actividade", "Camama, Luanda");
      const socios = equipa.filter((u: any) => socio(u) && daClinica(u.email)).map((u: any) => String(u.email));
      const director = equipa.filter((u: any) => u && u.id === "u1" && daClinica(u.email)).map((u: any) => String(u.email));
      const ex = extra("direccao");
      const para = socios.length ? socios.concat(ex.para || []) : director.concat(ex.para || []);
      const cc = (socios.length ? director : []).concat(ex.cc || []);
      const res = await mandar("direccao", para, cc, "Barispol — Resumo diário de actividade, " + curta(dia) + " de " + dt(dia).getUTCFullYear(), html);
      return responder({ ok: true, tipo, qual, dia, previa, envios: [res] });
    }

    // Areas: cada chefe recebe a sua, sem valores.
    const [{ data: d, error: eC }, { data: resp, error: eR }] = await Promise.all([
      admin.rpc("bsp_srv_clinico_dados", { p_de: dia, p_ate: dia }),
      admin.rpc("bsp_escalas_responsaveis"),
    ]);
    if (eC || eR || !d) return responder({ erro: "Não foi possível ler os dados: " + ((eC || eR) as any)?.message }, 500);
    const nm = d.numeros || {};
    const top = d.top || {};
    const stock = d.stock || {};
    const marc = d.marcacoes || {};
    const alertas: any[] = d.alertas || [];
    const topTab = (k: string, titulo: string) => (top[k] || []).length
      ? sec(titulo) + tabela(["Acto", "Qtd"], (top[k] as any[]).map((x) => [escapar(frase(x.nome)), n0(x.n)])) : "";
    const stockHtml = (k: string) => {
      const s = stock[k];
      if (!s) return "";
      const linhas: string[] = [];
      (s.esgotados || []).forEach((x: string) => linhas.push('<span style="color:#B42318">' + escapar(frase(x)) + " · esgotado</span>"));
      (s.caducados || []).forEach((x: any) => linhas.push('<span style="color:#B42318">' + escapar(frase(x.nome)) + " · lote caducado a " + escapar(String(x.validade).split("-").reverse().join("-")) + " (" + n0(x.qtd) + ")</span>"));
      (s.a_acabar || []).forEach((x: any) => linhas.push(escapar(frase(x.nome)) + " · acaba em " + n0(x.dias) + (Number(x.dias) === 1 ? " dia" : " dias")));
      (s.a_caducar || []).slice(0, 15).forEach((x: any) => linhas.push(escapar(frase(x.nome)) + " · caduca a " + escapar(String(x.validade).split("-").reverse().join("-")) + " (" + n0(x.qtd) + ")"));
      return linhas.length ? sec("Stock da área") + lista(linhas) + ((s.a_caducar || []).length > 15 ? paragrafo("E mais " + ((s.a_caducar || []).length - 15) + " lotes a caducar em 30 dias: veja o Stock no Workspace.") : "") : "";
    };
    // O que vinha nos relatórios antigos das áreas e o MetaGest dá (sem nomes de utentes).
    const ex = d.extra || {};
    const mesTxt = (m: string) => { const [a, b] = String(m).split("-"); return MESES[Number(b) - 1] + " " + a; };
    const recepcaoExtra = () => {
      const doc = ex.documentos || {};
      const mf = ex.marcacoes_por_fechar || {};
      const ra = ex.rascunhos || {};
      return sec("Documentos de ontem") + tabela(["Documento", "Qtd"], [["Factura-recibo (FR)", n0(doc.fr)], ["Factura (FT)", n0(doc.ft)], ["Nota de crédito (NC)", n0(doc.nc)]].concat(Number(doc.outros || 0) ? [["Outros", n0(doc.outros)]] : [])) +
        (Number(mf.total || 0) ? sec("Marcações passadas por fechar") + paragrafo(n0(mf.total) + " marcações já passaram e continuam «Agendada» ou «Confirmada». Marque Compareceu, Faltou, Cancelou ou Remarcado.") +
          tabela(["Mês", "Qtd"], ((mf.por_mes || []) as any[]).map((x) => [escapar(mesTxt(x.mes)), n0(x.n)])) : "") +
        (Number(ra.total || 0) ? paragrafo("<b>" + n0(ra.total) + " documentos em rascunho</b> no MetaGest desde Julho" + (Number(ra.periodo || 0) ? " (" + n0(ra.periodo) + " de ontem)" : "") + ". Emita-os ou apague-os.") : "");
    };
    const farmaciaExtra = () =>
      (((ex.farmacia_vendido || []) as any[]).length ? sec("Vendido ontem e stock que fica") +
        tabela(["Produto", "Qtd", "Stock que fica"], (ex.farmacia_vendido as any[]).map((x) => [escapar(frase(x.nome)), n0(x.qtd), x.fica == null ? "—" : n0(x.fica)])) : "") +
      (((ex.farmacia_repor || []) as any[]).length ? sec("Stock a repor") +
        tabela(["Produto", "Stock", "Saídas 30 dias", "Dá para"], (ex.farmacia_repor as any[]).map((x) => [escapar(frase(x.nome)), n0(x.stock), n0(x.saidas_30d), x.dias == null ? "—" : n0(x.dias) + (Number(x.dias) === 1 ? " dia" : " dias")])) : "");
    const labExtra = () => ((ex.lab_consumiveis || []) as any[]).length
      ? sec("Testes e consumíveis") + tabela(["Artigo", "Stock", "Saídas 30 dias", "Dá para"], (ex.lab_consumiveis as any[]).map((x) => [escapar(frase(x.nome)), n0(x.stock), n0(x.saidas_30d), x.dias == null ? "—" : n0(x.dias) + (Number(x.dias) === 1 ? " dia" : " dias")]))
      : "";
    const AREAS: Record<string, { titulo: string; corpo: () => string; tem: () => boolean }> = {
      recepcao: {
        titulo: "Recepção",
        tem: () => true,
        corpo: () => mosaicos([["Utentes atendidos", n0(nm.utentes), n0(nm.novos) + " novos"], ["Marcações hoje", n0(marc.hoje), n0(marc.por_confirmar) + " por confirmar"], ["Amanhã", n0(marc.amanha), "marcações"]]) +
          (Number(d.sem_medico || 0) ? paragrafo('<b style="color:#8A5A00">' + n0(d.sem_medico) + (Number(d.sem_medico) === 1 ? " factura" : " facturas") + " de ontem sem médico solicitante.</b> Corrija no MetaGest.") : "") +
          recepcaoExtra() + topTab("consulta", "Consultas de ontem"),
      },
      clinica: {
        titulo: "Clínica",
        tem: () => true,
        corpo: () => mosaicos([["Utentes", n0(nm.utentes), n0(nm.novos) + " novos"], ["Consultas", n0(nm.consultas)], ["Exames de laboratório", n0(nm.exames_lab)]]) +
          ((d.medicos || []).length ? sec("Por médico") + tabela(["Médico", "Consultas", "Utentes"], (d.medicos as any[]).map((m) => [escapar(m.nome), n0(m.consultas), n0(m.utentes)])) : "") +
          topTab("consulta", "Consultas por especialidade"),
      },
      laboratorio: {
        titulo: "Laboratório",
        tem: () => true,
        corpo: () => mosaicos([["Exames facturados", n0(nm.exames_lab), n0(nm.utentes_lab) + " utentes"], ["Externos", n0(nm.exames_externos)]]) +
          topTab("laboratorio", "Exames de ontem") + labExtra() + stockHtml("laboratorio"),
      },
      farmacia: {
        titulo: "Farmácia",
        tem: () => true,
        corpo: () => mosaicos([["Unidades vendidas", n0(nm.unidades_farmacia), n0(nm.produtos_farmacia) + " produtos"], ["Utentes", n0(nm.utentes_farmacia)]]) +
          farmaciaExtra() + topTab("farmacia", "Mais vendidos ontem") + stockHtml("farmacia"),
      },
      enfermagem: {
        titulo: "Enfermagem",
        tem: () => true,
        corpo: () => mosaicos([["Actos de enfermagem", n0(nm.actos_enfermagem), n0(nm.utentes_enfermagem) + " utentes"]]) +
          topTab("enfermagem", "Actos de ontem") + stockHtml("enfermagem"),
      },
      radiologia: {
        titulo: "Imagiologia",
        tem: () => Number(nm.raiox || 0) + Number(nm.ecografias || 0) + Number(nm.cardiologia || 0) > 0,
        corpo: () => mosaicos([["Raio-X", n0(nm.raiox)], ["Ecografias", n0(nm.ecografias)], ["Cardiologia", n0(nm.cardiologia)]]) +
          topTab("raiox", "Raio-X") + topTab("ecografia", "Ecografias") + topTab("cardiologia", "Cardiologia"),
      },
      "servicos gerais": {
        titulo: "Serviços Gerais",
        tem: () => !!stockHtml("servicos gerais"),
        corpo: () => stockHtml("servicos gerais"),
      },
    };
    const ADM = "adm@barispol.com";
    /* Áreas cujo relatório vai para outra pessoa que não o responsável da
       escala: a Imagiologia vai para a Direcção Clínica (Elmar, 02-10-2026). */
    const PARA_AREA: Record<string, string[]> = { radiologia: ["u14"] };
    const envios: any[] = [];
    for (const r of (resp || []) as any[]) {
      const a = AREAS[r.area];
      if (!a || !a.tem()) continue;
      const ids: string[] = PARA_AREA[r.area] || r.ids || [];
      const chefes = equipa.filter((u: any) => ids.includes(u.id) && daClinica(u.email) && !socio(u)).map((u: any) => String(u.email));
      const html = envelope(a.titulo + " · " + curta(dia),
        paragrafo("O que a sua área fez ontem, " + longa(dia) + ", segundo o MetaGest. Sem valores.") +
          alertasHtml(alertas.filter((x) => x.area === r.area)) + a.corpo(),
        "painel-clinico", "Abrir o Painel clínico",
        "Relatório diário da área, todos os dias às 07h15.", "Relatório da área", "Camama, Luanda");
      envios.push(await mandar(r.area, chefes, [ADM], "Barispol — " + a.titulo + ", " + curta(dia) + " de " + dt(dia).getUTCFullYear(), html));
    }
    return responder({ ok: true, tipo, qual, dia, previa, envios });
});
