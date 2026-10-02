// Barispol Workspace · avisos da Agenda (02-10-2026, agenda-lembretes.sql)
//
// Pedido do Elmar: lembretes nos eventos, à escolha, e e-mail sempre que
// alguém é convidado. Pelo campo "qual" do corpo:
//   · "convite" (gatilho bsp_agenda_convite_aviso, no instante): e-mail a
//     cada pessoa nova em convidados ({"evento": id, "ids": [...]}).
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
  const qual = corpo && corpo.qual === "convite" ? "convite" : "lembretes";

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
  const enviar = async (para: string, assunto: string, html: string) => {
    const r = await fetch(URL_SB.replace(/\/$/, "") + "/functions/v1/bright-worker", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: "Bearer " + CHAVE_SERVICO },
      body: JSON.stringify({ to: para, subject: assunto, html }),
    }).catch(() => null);
    return !!(r && r.ok);
  };

  if (qual === "convite") {
    const id = Number(corpo.evento);
    const ids: string[] = Array.isArray(corpo.ids) ? corpo.ids.map(String) : [];
    if (!id || !ids.length) return responder({ ok: true, qual, enviados: 0 });
    const { data: e, error: eE } = await admin.from("agenda_eventos").select("*").eq("id", id).single();
    if (eE || !e) return responder({ erro: "Evento não encontrado." }, 404);
    const quem = pessoa(e.criado_por || e.dono);
    const quemNome = quem ? String(quem.name) : "Um colega";
    let enviados = 0;
    const falhas: string[] = [];
    for (const uid of ids) {
      const u = pessoa(uid);
      const para = emailDe(u);
      if (!para) continue;
      const html = envelope(
        "Olá, " + escapar(primeiro(u)) + ".",
        paragrafo("<b>" + escapar(quemNome) + "</b> convidou-o para um evento na Agenda do Workspace:") +
          tabela(
            linhaDado("Evento", escapar(e.titulo)) +
            linhaDado("Quando", escapar(quandoTexto(e))) +
            (e.duracao ? linhaDado("Duração", escapar(e.duracao >= 60 && e.duracao % 60 === 0 ? (e.duracao / 60) + (e.duracao === 60 ? " hora" : " horas") : e.duracao + " minutos")) : "") +
            (e.local ? linhaDado("Local", escapar(e.local)) : "") +
            (e.descricao ? linhaDado("Notas", escapar(e.descricao).replace(/\n/g, "<br>")) : "") +
            linhaDado("Agenda", e.privado ? "Privada (só os convidados vêem)" : "De toda a equipa")
          ) +
          paragrafo("Responda «Vou», «Talvez» ou «Não vou» no próprio evento. Lá pode também escolher quando quer ser lembrado.", true),
        "calendar", "Responder na Agenda", "Convite para um evento.", "Convite", "Agenda"
      );
      const ok = await enviar(para, "Convite: " + String(e.titulo) + " — " + quandoTexto(e), html);
      ok ? enviados++ : falhas.push(uid);
    }
    return responder({ ok: true, qual, evento: id, enviados, falhas: falhas.length ? falhas : undefined });
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
