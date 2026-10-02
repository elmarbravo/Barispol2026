// Barispol Workspace · resumo pessoal da manhã (02-10-2026)
//
// O e-mail das 06h30 (segunda a sábado, cron bsp-resumo-matinal) a cada
// pessoa: as suas tarefas por fechar e a sua agenda de hoje; e a cada área,
// as tarefas do quadro da equipa em aberto. Até 02-10-2026 saía da
// resumo-matinal e só lia o quadro da equipa (shared_state.tasks): as
// tarefas privadas (tarefas_pessoais, também as partilhadas com a pessoa)
// nunca entravam, e com o quadro vazio não saía nada a ninguém.
// Mesmas regras da resumo-matinal: toda a equipa com e-mail válido, menos
// semEmails e sócios; um envio por dia (resumos_enviados), menos com
// {"forcar": true} (botão «Enviar agora» em Admin → Sistema).
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

const COLUNAS: Record<string, string> = {
  todo: "A Fazer",
  doing: "Em Progresso",
  review: "Em Revisão",
};

function listaDeTarefas(tarefas: any[], mostrarQuem: boolean, equipa: any[]) {
  const nomeDe = (id: string) => {
    const u = equipa.find((x: any) => x.id === id);
    return u ? String(u.name || "").split(" ").slice(0, 2).join(" ") : null;
  };
  return (
    '<ul style="padding-left:18px;margin:10px 0">' +
    tarefas
      .map((t) => {
        const quem = mostrarQuem
          ? (t.assignees || []).map(nomeDe).filter(Boolean).join(", ")
          : "";
        const atrasada = t.due && String(t.due) < new Date().toISOString().slice(0, 10);
        return (
          '<li style="margin-bottom:6px"><b>' +
          escapar(t.title) +
          "</b> " +
          '<span style="color:#94A3B8">— ' +
          escapar(COLUNAS[t.onde] || t.onde) +
          (t.priority ? " · " + escapar(t.priority) : "") +
          (quem ? " · " + escapar(quem) : "") +
          "</span>" +
          (atrasada
            ? ' <span style="color:#DC2626;font-weight:bold">· em atraso</span>'
            : "") +
          "</li>"
        );
      })
      .join("") +
    "</ul>"
  );
}

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
  const luanda = new Date(Date.now() + 3600 * 1000);
  const hoje = luanda.toISOString().slice(0, 10);
  if (!forcar) {
    const { error: jaFoi } = await admin.from("resumos_enviados").insert({ dia: hoje });
    if (jaFoi) {
      const m = String(jaFoi.message || "").toLowerCase();
      if (jaFoi.code === "23505" || /duplicate key/.test(m)) return responder({ ok: true, enviados: 0, nota: "O resumo de hoje já tinha saído." });
      return responder({ erro: "Não foi possível registar o envio: " + jaFoi.message }, 500);
    }
  }

  const [{ data: linha, error }, { data: privadas }, { data: agendaLinhas }] = await Promise.all([
    admin.from("shared_state").select("team, tasks, events, camadas").eq("id", 1).single(),
    admin.from("tarefas_pessoais").select("user_id, partilhada_com, coluna, titulo, prioridade, prazo, inicio").neq("coluna", "done"),
    admin.from("agenda_eventos").select("dono, titulo, hora, dia, data, dia_mes, privado, convidados, respostas, local"),
  ]);
  if (error || !linha) return responder({ erro: "Não foi possível ler os dados." }, 500);
  const equipa: any[] = Array.isArray(linha.team) ? linha.team : [];
  const semEmails = new Set(equipa.filter((u: any) => u && u.semEmails).map((u: any) => String(u.email || "").trim().toLowerCase()));
  const daClinica = (email: unknown) => {
    const e = String(email || "").trim().toLowerCase();
    return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e) && !semEmails.has(e);
  };
  const camadas: any = (linha as any).camadas || {};
  const socio = (u: any) => !!u && (u.accessLevel === "Sócio" || !!(camadas[u.accessLevel] && camadas[u.accessLevel].soNumeros));
  const destinatarios = equipa.filter((u: any) => u && daClinica(u.email) && !socio(u));

  const tarefas: any = linha.tasks || {};
  const pendentes: any[] = [];
  for (const col of ["todo", "doing", "review"]) for (const t of tarefas[col] || []) pendentes.push({ ...t, onde: col });
  /* Tarefas privadas: do dono e de quem as partilha. Mesma forma das da
     equipa, para irem na mesma lista. */
  const pessoais = ((privadas || []) as any[]).map((p: any) => ({
    title: p.titulo, onde: p.coluna, priority: p.prioridade, due: p.prazo,
    donos: [p.user_id].concat(Array.isArray(p.partilhada_com) ? p.partilhada_com : []),
  }));

  const diaSemana = (luanda.getUTCDay() + 6) % 7;
  const eventos: any[] = Array.isArray(linha.events) ? linha.events : [];
  const doDia = eventos.filter((e: any) => e && e.data ? String(e.data) === hoje : (e.day == null ? diaSemana : Number(e.day)) === diaSemana);
  const agendaHoje = ((agendaLinhas || []) as any[]).filter((e: any) =>
    e && (e.dia_mes ? String(e.data || "") <= hoje && Number(hoje.slice(8, 10)) === Number(e.dia_mes)
      : e.data ? String(e.data) === hoje : Number(e.dia) === diaSemana));
  const agendaDe = (u: any) => {
    const meus = agendaHoje.filter((e: any) =>
      (!e.privado || e.dono === u.id || (e.convidados || []).includes(u.id)) && !(e.respostas && e.respostas[u.id] === "nao"));
    const seus = meus.filter((e: any) => e.dono === u.id || (e.convidados || []).includes(u.id)).length;
    const lista = doDia
      .map((e: any) => ({ hora: e.time || "", titulo: e.title, local: "", privado: false }))
      .concat(meus.map((e: any) => ({ hora: e.hora || "", titulo: e.titulo, local: e.local || "", privado: !!e.privado })))
      .sort((a: any, b: any) => String(a.hora).localeCompare(String(b.hora)));
    const html = lista.length
      ? '<p style="margin:0 0 6px;font-size:15px;color:#1C2033"><b>Hoje na agenda</b></p><ul style="padding-left:18px;margin:0 0 16px">' +
        lista.map((e: any) => '<li style="margin-bottom:4px;font-size:15px;color:#1C2033">' + (e.hora ? "<b>" + escapar(e.hora) + "</b> · " : "") +
          escapar(e.titulo) + (e.local ? " · " + escapar(e.local) : "") + (e.privado ? ' <span style="color:#4E5366;font-size:13px">(privado)</span>' : "") + "</li>").join("") + "</ul>"
      : "";
    return { html, seus };
  };
  const enviar = async (para: string, assunto: string, html: string) => {
    const r = await fetch(URL_SB.replace(/\/$/, "") + "/functions/v1/bright-worker", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: "Bearer " + CHAVE_SERVICO },
      body: JSON.stringify({ to: para, subject: assunto, html }),
    }).catch(() => null);
    return !!(r && r.ok);
  };

  let porPessoa = 0;
  let deEquipa = 0;
  const falhas: string[] = [];
  // 1. A cada pessoa, o que é dela: tarefas da equipa, privadas e agenda.
  for (const u of destinatarios) {
    const minhas = pendentes.filter((t) => (t.assignees || []).includes(u.id))
      .concat(pessoais.filter((p) => p.donos.includes(u.id)));
    const ag = agendaDe(u);
    if (!minhas.length && !ag.seus) continue;
    const nome = String(u.name || "").split(" ")[0];
    const ok = await enviar(
      u.email,
      minhas.length ? "As suas tarefas de hoje (" + minhas.length + ")" : "A sua agenda de hoje",
      envelope(
        "Bom dia, " + escapar(nome) + ".",
        ag.html +
          (minhas.length
            ? '<p style="margin:0;font-size:15px;color:#1C2033">Tem <b>' + minhas.length + "</b> tarefa(s) por fechar:</p>" + listaDeTarefas(minhas, false, equipa)
            : '<p style="margin:0;font-size:15px;color:#1C2033">Não tem tarefas por fechar.</p>'),
        minhas.length ? "tarefas" : "agenda",
        minhas.length ? "Ver as minhas tarefas" : "Abrir a Agenda"
      )
    );
    ok ? porPessoa++ : falhas.push(u.email);
  }

  // 2. A cada área, as tarefas do quadro da equipa em aberto (as privadas não).
  const areas = new Map<string, any[]>();
  for (const t of pendentes) {
    const seus = new Set<string>();
    for (const id of t.assignees || []) {
      const u = equipa.find((x: any) => x.id === id);
      if (u && u.dept) seus.add(String(u.dept));
    }
    for (const d of seus) {
      if (!areas.has(d)) areas.set(d, []);
      areas.get(d)!.push(t);
    }
  }
  for (const [area, lista] of areas) {
    const membros = destinatarios.filter((u: any) => u.dept === area);
    if (!membros.length) continue;
    const html = envelope(escapar(area) + " — " + lista.length + " em aberto",
      '<p style="margin:0;font-size:15px;color:#1C2033">O que a equipa tem em mãos esta manhã:</p>' + listaDeTarefas(lista, true, equipa),
      "tarefas", "Ver no Workspace");
    for (const u of membros) {
      const ok = await enviar(u.email, escapar(area) + ": " + lista.length + " tarefa(s) em aberto", html);
      ok ? deEquipa++ : falhas.push(u.email);
    }
  }

  return responder({
    ok: true, dia: hoje, pendentes: pendentes.length, privadas: pessoais.length,
    pessoais: porPessoa, deEquipa, falhas: falhas.length ? falhas : undefined, fonte_chave: fonteChaveServidor(),
  });
});
