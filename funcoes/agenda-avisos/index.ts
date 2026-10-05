// Barispol Workspace · avisos da Agenda (02-10-2026, agenda-lembretes.sql)
//
// Pedido do Elmar: lembretes nos eventos, à escolha, e e-mail sempre que
// alguém é convidado. Pelo campo "qual" do corpo:
//   · "convite" (gatilho bsp_agenda_convite_aviso, no instante): e-mail a
//     quem fica com o evento na agenda: o dono e cada convidado novo
//     ({"evento": id, "ids": [...]}, ou {"eventos": [ids]} para juntar
//     vários num só e-mail, com "nota" opcional).
//   · "actualizado": a hora, o dia, o título ou o local mudaram.
//   · "cancelado": o evento foi apagado ou a pessoa saiu dele (o gatilho
//     manda os dados, porque a linha já não existe).
//   Todos levam o convite de calendário (.ics, 02-10-2026, pedido do Elmar:
//   «tudo que for evento de um funcionário … faça convite no seu e-mail»),
//   para o evento aparecer no Outlook, Gmail ou iPhone de cada pessoa.
//   · "lembretes" (cron bsp-agenda-lembretes, de 5 em 5 minutos): e-mail
//     com os lembretes que vencem agora (bsp_srv_agenda_lembretes, que os
//     marca como enviados antes de os devolver).
// O sino do Workspace avisa por si (useLembretesAgenda), com o mesmo cálculo.
// Quem tem a marca semEmails não recebe e-mail.
//
// SEGURANÇA: igual à resumo-matinal. O código do agendamento (cabeçalho
// x-bsp-agendamento, conferido pela base de dados) ou a chave do servidor.
// A chave pública sozinha não envia nada.

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

/* A marca: as cores do logotipo e a fonte Titillium Web (gratuita), com Segoe UI
   e Arial de recurso. Sem a Dax desde 05-10-2026: abria mal nalguns PCs — um
   e-mail nao leva fontes consigo, e o Gmail e o Outlook ignoram as da
   rede. O logotipo vem do proprio site. */
const MARINHO = "#292F58";
const MARINHO_BOTAO = "#273069";
const AZUL = "#2291CE";
const FONTE = "'Titillium Web','Segoe UI',Arial,sans-serif";
const LOGOTIPO = "https://barispol.com/assets/logo-barispol.png";

/* O botao que leva a pessoa ao sitio, em vez de a mandar procurar.
   Aspecto de todos os e-mails (26-09-2026): o do site novo — fundo
   branco, linhas finas, cantos rectos, marinho e azul da marca. */
const SITIO = "https://barispol.com/workspace.html";
/* Texto em base64 (UTF-8), para o anexo do convite. */
const base64 = (t: string) => {
  const b = new TextEncoder().encode(t);
  let s = "";
  for (let i = 0; i < b.length; i += 0x8000) s += String.fromCharCode(...b.subarray(i, i + 0x8000));
  return btoa(s);
};
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
  const qual = corpo && ["convite", "actualizado", "cancelado"].includes(corpo.qual) ? String(corpo.qual) : "lembretes";

  const { data: linha } = await admin.from("shared_state").select("team").eq("id", 1).single();
  const equipa: any[] = Array.isArray(linha && linha.team) ? linha.team : [];
  const pessoa = (id: string) => equipa.find((u: any) => u && u.id === id) || null;
  const emailDe = (u: any) => {
    const e = String((u && u.email) || "").trim();
    return u && !u.semEmails && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e) ? e : "";
  };
  const primeiro = (u: any) => String((u && u.name) || "").trim().split(/\s+/)[0] || "";
  const MESES = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
  const SEMANA = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"];
  const SEMANA_PL = ["segundas-feiras", "terças-feiras", "quartas-feiras", "quintas-feiras", "sextas-feiras", "sábados", "domingos"];
  const dataLonga = (iso: string) => { const d = new Date(iso + "T12:00:00Z"); return SEMANA[d.getUTCDay()] + ", " + d.getUTCDate() + " de " + MESES[d.getUTCMonth()] + " de " + d.getUTCFullYear(); };
  const dataCurta = (iso: string) => { const d = new Date(iso + "T12:00:00Z"); return d.getUTCDate() + " de " + MESES[d.getUTCMonth()]; };
  const luandaDe = (ts: string) => { const d = new Date(new Date(ts).getTime() + 3600 * 1000); return { iso: d.toISOString().slice(0, 10), hora: d.toISOString().slice(11, 16) }; };
  const antecedencia = (m: number) => m === 0 ? "na hora" : m < 60 ? m + " minutos antes" : m < 1440 ? (m / 60) + (m === 60 ? " hora antes" : " horas antes") : m % 10080 === 0 ? (m / 10080) + (m === 10080 ? " semana antes" : " semanas antes") : (m / 1440) + (m === 1440 ? " dia antes" : " dias antes");
  const quandoTexto = (e: any) => {
    const h = e.hora ? " às " + e.hora : "";
    if (e.dia_mes) return "Todos os meses, no dia " + e.dia_mes + h + (e.data ? " (desde " + dataCurta(e.data) + ")" : "");
    if (e.dia != null) return "Todas as " + SEMANA_PL[Number(e.dia)] + h;
    return e.data ? dataLonga(e.data).replace(/^./, (c) => c.toUpperCase()) + h : "";
  };
  const linhaDado = (rotulo: string, valor: string) =>
    '<tr><td style="padding:6px 16px 6px 0;font-family:' + FONTE + ';font-size:15px;font-weight:700;color:' + MARINHO + ';vertical-align:top;white-space:nowrap">' + rotulo + '</td><td style="padding:6px 0;font-family:' + FONTE + ';font-size:15px;color:' + TEXTO + '">' + valor + "</td></tr>";
  const tabela = (linhas: string) => '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:4px 0 16px;border-top:1px solid ' + LINHA + ';border-bottom:1px solid ' + LINHA + '">' + linhas + "</table>";
  const previa = corpo && corpo.previa === true;
  const enviar = async (para: string, assunto: string, html: string, ics?: string) => {
    if (previa) return true;
    const r = await fetch(URL_SB.replace(/\/$/, "") + "/functions/v1/bright-worker", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: "Bearer " + CHAVE_SERVICO },
      body: JSON.stringify({
        to: para, subject: assunto, html,
        ...(ics ? { attachments: [{ filename: "convite.ics", content: base64(ics), content_type: "text/calendar; charset=utf-8; method=" + (/METHOD:CANCEL/.test(ics) ? "CANCEL" : "REQUEST") }] } : {}),
      }),
    }).catch(() => null);
    return !!(r && r.ok);
  };

  /* O convite de calendario (RFC 5545). Hora de Luanda (sem horario de
     verao); UID fixo por evento e SEQUENCE a subir a cada mudanca, para o
     calendario de cada pessoa actualizar o mesmo evento em vez de criar
     outro. Semanais: a partir da data de inicio (ou de hoje), todas as
     semanas no mesmo dia; mensais: no mesmo dia do mes. */
  const DIAS_ICS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"];
  const hojeLuanda = luandaDe(new Date().toISOString()).iso;
  const somarDias = (iso: string, n: number) => new Date(Date.parse(iso + "T12:00:00Z") + n * 86400000).toISOString().slice(0, 10);
  const primeiraData = (e: any) => {
    const base = e.data && (e.dia != null || e.dia_mes) ? (e.data > hojeLuanda ? e.data : hojeLuanda) : (e.data || hojeLuanda);
    if (e.dia_mes) { for (let i = 0; i < 400; i++) { const d = somarDias(base, i); if (Number(d.slice(8, 10)) === Number(e.dia_mes)) return d; } }
    if (e.dia != null && !e.dia_mes) { for (let i = 0; i < 7; i++) { const d = somarDias(base, i); if ((new Date(d + "T12:00:00Z").getUTCDay() + 6) % 7 === Number(e.dia)) return d; } }
    return base;
  };
  const icsTexto = (t: unknown) => String(t ?? "").replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");
  const dobrar = (l: string) => {
    const enc = new TextEncoder();
    const partes: string[] = [];
    let atual = "", bytes = 0;
    for (const c of l) {
      const n = enc.encode(c).length;
      if (bytes + n > (partes.length ? 73 : 74)) { partes.push(atual); atual = ""; bytes = 0; }
      atual += c; bytes += n;
    }
    partes.push(atual);
    return partes.join("\r\n ");
  };
  const carimbo = (d: Date) => d.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
  const vevent = (e: any, uid: string, cancelado: boolean) => {
    const dia = primeiraData(e);
    const [hh, mm] = String(e.hora || "09:00").split(":").map(Number);
    const ini = new Date(Date.UTC(+dia.slice(0, 4), +dia.slice(5, 7) - 1, +dia.slice(8, 10), hh, mm));
    const fim = new Date(ini.getTime() + Math.max(5, Number(e.duracao) || 60) * 60000);
    const local = (d: Date) => carimbo(d).replace(/Z$/, "");
    const dono = pessoa(e.dono);
    const participantes = [e.dono].concat(e.convidados || []).filter((x: string, i: number, a: string[]) => x && a.indexOf(x) === i)
      .map((x: string) => pessoa(x)).filter((u: any) => emailDe(u));
    const meus = e.lembretes_pessoa && Array.isArray(e.lembretes_pessoa[uid]) ? e.lembretes_pessoa[uid] : (e.lembretes || []);
    const linhas = [
      "BEGIN:VEVENT",
      "UID:agenda-" + e.id + "@barispol.com",
      "SEQUENCE:" + (Number(e.ics_seq) || 0),
      "DTSTAMP:" + carimbo(new Date()),
      "DTSTART;TZID=Africa/Luanda:" + local(ini),
      "DTEND;TZID=Africa/Luanda:" + local(fim),
      ...(e.dia_mes ? ["RRULE:FREQ=MONTHLY;BYMONTHDAY=" + Number(e.dia_mes)] : e.dia != null ? ["RRULE:FREQ=WEEKLY;BYDAY=" + DIAS_ICS[Number(e.dia)]] : []),
      "SUMMARY:" + icsTexto(e.titulo),
      ...(e.local ? ["LOCATION:" + icsTexto(e.local)] : []),
      "DESCRIPTION:" + icsTexto((e.descricao ? e.descricao + "\n\n" : "") + "Agenda do Workspace: " + SITIO + "#/calendar"),
      "ORGANIZER;CN=" + icsTexto(dono ? dono.name : "Centro Médico Barispol") + ":mailto:geral@barispol.com",
      ...participantes.map((u: any) => "ATTENDEE;CN=" + icsTexto(u.name) + ";ROLE=REQ-PARTICIPANT;PARTSTAT=" + (u.id === e.dono ? "ACCEPTED" : "NEEDS-ACTION") + ";RSVP=FALSE:mailto:" + emailDe(u)),
      "STATUS:" + (cancelado ? "CANCELLED" : "CONFIRMED"),
      ...(e.privado ? ["CLASS:PRIVATE"] : []),
      ...(cancelado ? [] : (meus as number[]).slice(0, 5).flatMap((m) => ["BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:" + icsTexto(e.titulo), "TRIGGER:-PT" + Math.max(0, Number(m) || 0) + "M", "END:VALARM"])),
      "END:VEVENT",
    ];
    return linhas;
  };
  const calendario = (eventos: any[], uid: string, cancelado: boolean) =>
    ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Clinica Barispol Lda//Workspace//PT", "CALSCALE:GREGORIAN", "METHOD:" + (cancelado ? "CANCEL" : "REQUEST"),
      "BEGIN:VTIMEZONE", "TZID:Africa/Luanda", "BEGIN:STANDARD", "DTSTART:19700101T000000", "TZOFFSETFROM:+0100", "TZOFFSETTO:+0100", "TZNAME:WAT", "END:STANDARD", "END:VTIMEZONE",
      ...eventos.flatMap((e) => vevent(e, uid, cancelado)), "END:VCALENDAR"].map(dobrar).join("\r\n") + "\r\n";
  const duracaoTxt = (m: number) => m >= 60 && m % 60 === 0 ? (m / 60) + (m === 60 ? " hora" : " horas") : m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " minutos";
  const dadosEvento = (e: any) => tabela(
    linhaDado("Evento", escapar(e.titulo)) +
    linhaDado("Quando", escapar(quandoTexto(e))) +
    (e.duracao ? linhaDado("Duração", escapar(duracaoTxt(Number(e.duracao)))) : "") +
    (e.local ? linhaDado("Local", escapar(e.local)) : "") +
    (e.descricao ? linhaDado("Notas", escapar(e.descricao).replace(/\n/g, "<br>")) : "") +
    linhaDado("Agenda", e.privado ? "Privada (só quem está no evento a vê)" : "De toda a equipa"));
  const NOTA_ICS = "O convite segue em anexo (convite.ics): abra-o para o evento ficar também no calendário do seu e-mail ou do telemóvel.";

  if (qual === "convite" || qual === "actualizado") {
    const idsEv: number[] = (Array.isArray(corpo.eventos) ? corpo.eventos : [corpo.evento]).map(Number).filter(Boolean);
    const ids: string[] = Array.isArray(corpo.ids) ? corpo.ids.map(String) : [];
    if (!idsEv.length || !ids.length) return responder({ ok: true, qual, enviados: 0 });
    const { data: evs, error: eE } = await admin.from("agenda_eventos").select("*").in("id", idsEv).order("dia").order("id");
    if (eE || !evs || !evs.length) return responder({ erro: "Evento não encontrado." }, 404);
    const e0: any = evs[0];
    const quem = pessoa(e0.criado_por || e0.dono);
    const quemNome = quem ? String(quem.name) : "Um colega";
    const nota = typeof corpo.nota === "string" ? corpo.nota.trim().slice(0, 1500) : "";
    const titulo = evs.length > 1 ? String(e0.titulo) + " — " + (evs as any[]).map((e) => e.dia != null && !e.dia_mes ? ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"][Number(e.dia)] : dataCurta(e.data || hojeLuanda)).join(", ") + (e0.hora ? ", " + e0.hora : "")
      : String(e0.titulo) + " — " + quandoTexto(e0);
    let enviados = 0;
    const falhas: string[] = [];
    const previas: any[] = [];
    for (const uid of ids) {
      const u = pessoa(uid);
      const para = emailDe(u);
      if (!para) continue;
      const doDono = (evs as any[]).every((e) => e.dono === uid);
      const proprio = quem && quem.id === uid;
      const abertura = qual === "actualizado"
        ? "Um evento da sua agenda no Workspace mudou. Os dados novos:"
        : proprio ? "O evento ficou na sua agenda do Workspace:"
        : doDono ? "<b>" + escapar(quemNome) + "</b> pôs " + (evs.length > 1 ? "estes eventos" : "este evento") + " na sua agenda do Workspace:"
        : "Tem um convite de <b>" + escapar(quemNome) + "</b> para " + (evs.length > 1 ? "estes eventos" : "um evento") + " na Agenda do Workspace:";
      const html = envelope(
        "Olá, " + escapar(primeiro(u)) + ".",
        (nota ? paragrafo(escapar(nota).replace(/\n/g, "<br>")) : "") +
          paragrafo(abertura) + (evs as any[]).map(dadosEvento).join("") +
          paragrafo(NOTA_ICS) +
          paragrafo(doDono || qual === "actualizado" ? "No próprio evento pode escolher quando quer ser lembrado." : "Responda «Vou», «Talvez» ou «Não vou» no próprio evento. Lá pode também escolher quando quer ser lembrado.", true),
        "calendar", doDono ? "Abrir a Agenda" : "Responder na Agenda",
        qual === "actualizado" ? "Evento alterado." : "Evento na Agenda.", qual === "actualizado" ? "Evento alterado" : doDono ? "Agenda" : "Convite", "Agenda"
      );
      const ics = calendario(evs as any[], uid, false);
      const assunto = (qual === "actualizado" ? "Evento alterado: " : doDono ? "Na sua agenda: " : "Convite: ") + titulo;
      if (previa) previas.push({ para, assunto, html, ics });
      const ok = await enviar(para, assunto, html, ics);
      ok ? enviados++ : falhas.push(uid);
    }
    return responder({ ok: true, qual, eventos: idsEv, enviados, falhas: falhas.length ? falhas : undefined, ...(previa ? { previa: true, previas } : {}) });
  }

  if (qual === "cancelado") {
    const e: any = corpo.dados || null;
    const ids: string[] = Array.isArray(corpo.ids) ? corpo.ids.map(String) : [];
    if (!e || !e.id || !ids.length) return responder({ ok: true, qual, enviados: 0 });
    e.ics_seq = (Number(e.ics_seq) || 0) + 1;
    let enviados = 0;
    for (const uid of ids) {
      const u = pessoa(uid);
      const para = emailDe(u);
      if (!para) continue;
      const html = envelope(
        "Olá, " + escapar(primeiro(u)) + ".",
        paragrafo(corpo.saiu ? "Já não está neste evento da Agenda do Workspace:" : "Este evento foi retirado da Agenda do Workspace:") + dadosEvento(e) +
          paragrafo("O anexo (convite.ics) tira-o também do calendário do seu e-mail ou do telemóvel.", true),
        "calendar", "Abrir a Agenda", "Evento cancelado.", "Evento cancelado", "Agenda"
      );
      if (await enviar(para, "Cancelado: " + String(e.titulo) + " — " + quandoTexto(e), html, calendario([e], uid, true))) enviados++;
    }
    return responder({ ok: true, qual, enviados });
  }

  // Lembretes que vencem agora.
  const { data: lista, error: eL } = await admin.rpc("bsp_srv_agenda_lembretes");
  if (eL) return responder({ erro: "Não foi possível ler os lembretes: " + eL.message }, 500);
  let enviados = 0;
  for (const l of (lista || []) as any[]) {
    const u = pessoa(l.user_id);
    const para = emailDe(u);
    if (!para) continue;
    const q = luandaDe(l.ocorre);
    const html = envelope(
      escapar(l.titulo),
      paragrafo("Lembrete (" + antecedencia(Number(l.minutos)) + ") do evento da sua agenda:") +
        tabela(
          linhaDado("Quando", escapar(dataLonga(q.iso).replace(/^./, (c) => c.toUpperCase()) + ", às " + q.hora)) +
          (l.local ? linhaDado("Local", escapar(l.local)) : "") +
          (l.descricao ? linhaDado("Notas", escapar(l.descricao).replace(/\n/g, "<br>")) : "")
        ) +
        paragrafo("Pode mudar ou desligar os seus lembretes no próprio evento.", true),
      "calendar", "Abrir a Agenda", "Lembrete da Agenda.", "Lembrete", "Agenda"
    );
    if (await enviar(para, "Lembrete: " + String(l.titulo) + " — " + dataCurta(q.iso) + ", " + q.hora, html)) enviados++;
  }
  return responder({ ok: true, qual, devidos: (lista || []).length, enviados });
});
