// Barispol Workspace · envio de e-mail (nome no painel: notify-email)
//
// Recebe { to, subject, html } e envia pelo Resend, com o remetente
// geral@barispol.com. O remetente e o pedido ao Resend sao os de sempre:
// o dominio esta verificado no Resend e troca-los parte o envio.
//
// SEGURANCA (desde 24-09-2026): a funcao verifica sozinha quem a chama,
// e o interruptor «Verify JWT with legacy secret» ficou desligado.
//   · chave do servidor (o resumo matinal)    -> qualquer destinatario
//   · sessao de um gestor (Admin -> Sistema)  -> qualquer destinatario
//   · sessao de outro colaborador              -> so enderecos da equipa
//     (shared_state.team) ou empresa@barispol.com. E o caso das mensagens
//     directas, das tarefas atribuidas e das publicacoes no mural.
//   · chave publica ou nada                    -> recusado
//   · codigo do agendamento (x-bsp-agendamento, o do cofre, desde
//     24-09-2026) -> como a chave do servidor: e o servidor a enviar.
// ANEXOS (desde 24-09-2026): so do servidor, e so ficheiros do proprio
// site (https://barispol.com/...). A Resend vai busca-los ao endereco.
// Assim ninguem usa esta funcao para mandar correio com o dominio da
// clinica a quem esta fora dela.
// CHAVE DO RESEND (desde 24-09-2026, projecto novo): vem do segredo
// RESEND_API_KEY do painel ou, se faltar, do cofre da base de dados
// (resend_api_key, lido pela funcao bsp_resend_key, so do servidor).
// VARIOS DESTINATARIOS, CC E BCC (desde 25-09-2026): so o servidor pode
// mandar "to" como lista e usar "cc"/"bcc" (relatorios de area e avisos
// do atendimento do WhatsApp).
//
// Este ficheiro e a copia da versao publicada (versao 6, 02-10-2026). O
// lembrete da marcacao ao paciente usa o "cc" para rececao@barispol.com.
// RESPONDER PARA (versao 4, 30-09-2026): so o servidor pode mandar
// "reply_to" (relatorio semanal da viatura -> Administracao).
// CONFIRMACAO DE LEITURA (versao 5, 30-09-2026): so o servidor pode mandar
// "headers", e so Disposition-Notification-To e Return-Receipt-To, cada um
// com um endereco (guia do Workspace, confirmacao para o RH).
// CONVITE DE CALENDARIO (versao 6, 02-10-2026): so o servidor, um anexo
// .ics em base64 com content_type text/calendar (agenda-avisos).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

const EMAIL_EQUIPA = "empresa@barispol.com";

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
const chavePublica = () => chavesPublicas()[0] || "";
/* Quem se apresenta com uma chave de servidor — a nova ou a antiga —
   e o proprio servidor. */
const ehChaveDoServidor = (t: string) => !!t && chavesServidor().includes(t);
const ehChavePublica = (t: string) => !!t && chavesPublicas().includes(t);

const SITIO_ANEXOS = "https://barispol.com/";

const recusar = (erro: string, estado: number) =>
  new Response(JSON.stringify({ erro }),
    { status: estado, headers: { ...cors, "Content-Type": "application/json" } });

const listaDeEnderecos = (v: unknown): string[] =>
  (Array.isArray(v) ? v : [v]).map((x) => String(x || "").trim()).filter((x) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(x)).slice(0, 10);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return recusar("Método não permitido.", 405);

  const testemunho = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const codigoAgendamento = (req.headers.get("x-bsp-agendamento") || "").trim();
  if (!testemunho && !codigoAgendamento) return recusar("Sem autorização.", 401);
  if (!codigoAgendamento && ehChavePublica(testemunho)) return recusar("A chave pública não chega para enviar correio.", 403);

  /* O codigo do agendamento conta como o servidor. Quem confere e a base
     de dados, que so responde sim ou nao. */
  let doServidor = ehChaveDoServidor(testemunho);
  if (!doServidor && codigoAgendamento) {
    const URL_SB = Deno.env.get("SUPABASE_URL") || "";
    const SERVICO = chaveServidor();
    if (!URL_SB || !SERVICO) return recusar("A função não tem as chaves do projecto.", 500);
    const admin = createClient(URL_SB, SERVICO, { auth: { persistSession: false } });
    const { data: confere } = await admin.rpc("bsp_resumo_codigo_confere", { codigo: codigoAgendamento });
    if (confere !== true) return recusar("Código do agendamento inválido.", 403);
    doServidor = true;
  }

  let pedido: any;
  try {
    pedido = await req.json();
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: cors });
  }
  const { to, subject, html } = pedido || {};

  /* Varios destinatarios, cc e bcc: so o servidor. */
  if (!doServidor && (Array.isArray(to) || pedido.cc || pedido.bcc)) return recusar("Só o servidor envia para vários destinatários.", 403);
  const paraLista = doServidor ? listaDeEnderecos(to) : [to];
  const cc = doServidor ? listaDeEnderecos(pedido.cc || []) : [];
  const bcc = doServidor ? listaDeEnderecos(pedido.bcc || []) : [];
  /* Responder para (30-09-2026): so o servidor. O relatorio semanal da
     viatura pede ao motorista que responda a Administracao, e nao ao
     geral@. */
  const responderPara = doServidor ? listaDeEnderecos(pedido.reply_to || []) : [];
  const cabecalhos: Record<string, string> = {};
  if (doServidor && pedido.headers && typeof pedido.headers === "object") {
    for (const nome of ["Disposition-Notification-To", "Return-Receipt-To"]) {
      const v = listaDeEnderecos(pedido.headers[nome] || [])[0];
      if (v) cabecalhos[nome] = v;
    }
  }

  /* Anexos: so do servidor, so do proprio site. A excepcao e o convite de
     calendario (.ics, 02-10-2026): vem escrito pela agenda-avisos, em
     base64, e so pode ser text/calendar. */
  let anexos: Record<string, string>[] | undefined;
  if (Array.isArray(pedido && pedido.attachments) && pedido.attachments.length) {
    if (!doServidor) return recusar("Só o servidor envia anexos.", 403);
    anexos = [];
    for (const a of pedido.attachments.slice(0, 3)) {
      const nome = String(a && a.filename || "anexo").slice(0, 120);
      if (a && typeof a.content === "string") {
        if (!/\.ics$/i.test(nome) || !/^text\/calendar/i.test(String(a.content_type || "")) || a.content.length > 300000) {
          return recusar("Só convites de calendário (.ics) podem ir sem endereço.", 403);
        }
        anexos.push({ filename: nome, content: a.content, content_type: String(a.content_type) });
        continue;
      }
      const caminho = String(a && a.path || "");
      if (caminho.indexOf(SITIO_ANEXOS) !== 0) return recusar("Anexos só do site barispol.com.", 403);
      anexos.push({ filename: nome, path: caminho });
    }
  }

  if (!doServidor) {
    const URL_SB = Deno.env.get("SUPABASE_URL") || "";
    const SERVICO = chaveServidor();
    const ANON = chavePublica();
    if (!URL_SB || !SERVICO || !ANON) return recusar("A função não tem as chaves do projecto.", 500);

    const admin = createClient(URL_SB, SERVICO, { auth: { persistSession: false } });
    /* A sessao tem de ser verdadeira e estar em vigor. */
    const { data: quem, error: semSessao } = await admin.auth.getUser(testemunho);
    if (semSessao || !quem || !quem.user) return recusar("Sessão inválida ou expirada.", 401);

    const comSessao = createClient(URL_SB, ANON, {
      global: { headers: { Authorization: "Bearer " + testemunho } },
      auth: { persistSession: false },
    });
    const { data: eGestor } = await comSessao.rpc("bsp_e_gestor");
    if (eGestor !== true) {
      /* Um colaborador so avisa colegas: os enderecos da equipa e o da
         empresa. */
      const destino = String(to || "").trim().toLowerCase();
      const { data: linha } = await admin.from("shared_state").select("team").eq("id", 1).single();
      const equipa: any[] = linha && Array.isArray(linha.team) ? linha.team : [];
      const daEquipa = destino === EMAIL_EQUIPA ||
        equipa.some((u: any) => u && String(u.email || "").trim().toLowerCase() === destino);
      if (!daEquipa) return recusar("Só se enviam avisos para endereços da equipa.", 403);
    }
  }

  try {
    let key = Deno.env.get("RESEND_API_KEY") || "";
    if (!key) {
      const URL_SB = Deno.env.get("SUPABASE_URL") || "";
      const SERVICO = chaveServidor();
      if (URL_SB && SERVICO) {
        const adm = createClient(URL_SB, SERVICO, { auth: { persistSession: false } });
        const { data: doCofre } = await adm.rpc("bsp_resend_key");
        if (typeof doCofre === "string" && doCofre) key = doCofre;
      }
    }
    if (!key) return new Response(JSON.stringify({ error: "RESEND_API_KEY em falta" }),
      { status: 500, headers: cors });
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: "Bearer " + key },
      body: JSON.stringify({
        from: "Barispol Workspace <geral@barispol.com>",
        to: paraLista,
        subject: subject,
        html: html,
        ...(cc.length ? { cc } : {}),
        ...(bcc.length ? { bcc } : {}),
        ...(responderPara.length ? { reply_to: responderPara } : {}),
        ...(Object.keys(cabecalhos).length ? { headers: cabecalhos } : {}),
        ...(anexos ? { attachments: anexos } : {}),
      }),
    });
    const data = await r.json();
    return new Response(JSON.stringify(data),
      { status: r.status, headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: cors });
  }
});
