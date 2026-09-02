// Barispol Workspace · resumo matinal por e-mail
//
// PORQUE EXISTE: havia um botao em Admin -> Sistema que enviava os
// lembretes, e alguem tinha de se lembrar de lhe carregar. Um lembrete de
// que e preciso lembrar-se nao e um lembrete.
//
// Esta funcao corre sozinha, de madrugada, e envia dois tipos de mensagem:
//
//   1. A CADA PESSOA, as tarefas que lhe estao atribuidas e por fechar.
//      Quem nao tiver nenhuma nao recebe nada — uma caixa de correio com
//      um "nao tem nada" diario acaba por ser ignorada, e com ela os dias
//      em que ha mesmo alguma coisa.
//
//   2. A CADA EQUIPA, o que esta em aberto na area dela, a toda a gente
//      dessa area. Assim ninguem depende de uma so pessoa para saber o
//      que a equipa tem em maos. A area de uma tarefa e a de quem esta
//      encarregado dela.
//
// Leva tambem as escalas fixadas no mural e o que esta marcado para hoje,
// que e o que se quer saber antes de comecar o dia.
//
// COMO INSTALAR (uma vez):
//   1. No Supabase: Edge Functions -> Deploy a new function
//   2. Nome exacto: resumo-matinal
//   3. Cole este ficheiro e faca Deploy
//   4. Correr o resumo-matinal.sql, que marca a hora a que isto acontece
//
// SEGURANCA: so aceita quem se apresente com a chave service_role (e o
// caso do agendamento) ou com a sessao de alguem que a plataforma
// reconheca como gestor (e o caso do botao "Enviar agora"). Com a chave
// anonima sozinha nao envia nada — senao qualquer pessoa podia fazer
// chegar correio a clinica inteira.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cabecalhos = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const responder = (corpo: unknown, estado = 200) =>
  new Response(JSON.stringify(corpo), { status: estado, headers: cabecalhos });

const COLUNAS: Record<string, string> = {
  todo: "A Fazer",
  doing: "Em Progresso",
  review: "Em Revisão",
};

const escapar = (t: unknown) =>
  String(t ?? "").replace(/[&<>"]/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c] as string)
  );

/* O botao que leva a pessoa ao sitio, em vez de a mandar procurar. */
const SITIO = "https://barispol.com/workspace.html";
function botao(destino: string, rotulo: string) {
  const href = SITIO + "#/" + destino;
  return (
    '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:18px 0 0"><tr><td style="border-radius:8px;background:#002060">' +
    '<a href="' + href + '" style="display:inline-block;padding:11px 22px;font-family:Arial,sans-serif;font-size:14px;font-weight:bold;color:#ffffff;text-decoration:none;border-radius:8px">' +
    rotulo + "</a></td></tr></table>" +
    '<p style="margin:8px 0 0;font-size:11px;color:#94A3B8;word-break:break-all">' + href + "</p>"
  );
}
/* O mesmo cartao azul dos outros avisos, para nao parecer que vem de
   outro sitio qualquer. */
function envelope(titulo: string, corpo: string, destino?: string, rotulo?: string) {
  return (
    '<div style="font-family:Arial,sans-serif;max-width:560px;margin:0 auto;border:1px solid #E2E8F0;border-radius:12px;overflow:hidden">' +
    '<div style="background:#002060;color:#fff;padding:16px 20px;font-size:16px;font-weight:bold">Centro Médico Barispol — Workspace</div>' +
    '<div style="padding:20px;color:#0F172A"><h2 style="margin:0 0 12px;font-size:17px">' +
    titulo +
    "</h2>" +
    corpo +
    (destino ? botao(destino, rotulo || "Abrir no Workspace") : "") +
    '<p style="margin:20px 0 0;font-size:12px;color:#94A3B8">Este é o resumo automático da manhã.</p></div></div>'
  );
}

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

/* A chave do servidor mudou de nome quando o Supabase passou das chaves
   antigas (anon / service_role, em formato JWT) para as novas
   (publishable / secret). Depois de desligar as antigas, e a
   SUPABASE_SECRET_KEY que vale; antes disso, a SUPABASE_SERVICE_ROLE_KEY.

   Aceitam-se as duas, pela mesma razao por que se aceita um e-mail
   antigo e um novo durante uma mudanca: para nada parar no intervalo. */
const chaveServidor = () =>
  Deno.env.get("SUPABASE_SECRET_KEY") ||
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const chavePublica = () =>
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ||
  Deno.env.get("SUPABASE_ANON_KEY") || "";
/* Quem se apresenta com uma chave de servidor — a nova ou a antiga —
   e o proprio servidor. */
const ehChaveDoServidor = (t: string) =>
  !!t && (t === Deno.env.get("SUPABASE_SECRET_KEY") ||
          t === Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
const ehChavePublica = (t: string) =>
  !!t && (t === Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ||
          t === Deno.env.get("SUPABASE_ANON_KEY"));

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
  if (!testemunho) return responder({ erro: "Sem autorização." }, 401);

  const admin = createClient(URL_SB, CHAVE_SERVICO, {
    auth: { persistSession: false },
  });

  /* Quem pode mandar isto correr: o agendamento (chave service_role) ou
     um gestor a carregar no botão. */
  let autorizado = ehChaveDoServidor(testemunho);
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

  /* Uma vez por dia. O agendamento pode disparar mais do que uma vez —
     por uma repetição, por uma reinstalação — e ninguém quer o mesmo
     e-mail três vezes antes do café. O botão "Enviar agora" passa à
     frente disto, que é para isso que serve. */
  const hoje = new Date().toISOString().slice(0, 10);
  if (!forcar) {
    const { error: jaFoi } = await admin
      .from("resumos_enviados")
      .insert({ dia: hoje });
    if (jaFoi) {
      /* Só a chave repetida quer dizer "já saiu hoje". Qualquer outro
         erro — a tabela não existe, por exemplo — não pode calar o envio
         em silêncio: era assim que uma instalação incompleta ficava a
         não mandar nada, todas as manhãs, sem ninguém perceber. */
      const m = String(jaFoi.message || "").toLowerCase();
      const jaSaiu = jaFoi.code === "23505" || /duplicate key|already exists/.test(m);
      if (jaSaiu) {
        return responder({ ok: true, enviados: 0, nota: "O resumo de hoje já tinha saído." });
      }
      if (/relation|does not exist|schema cache/.test(m)) {
        return responder({
          erro: "Falta a tabela resumos_enviados. Corra o agendar-resumo.sql no SQL Editor.",
        }, 500);
      }
      return responder({ erro: "Não foi possível registar o envio: " + jaFoi.message }, 500);
    }
  }

  const { data: linha, error } = await admin
    .from("shared_state")
    .select("team, tasks, events, drive")
    .eq("id", 1)
    .single();
  if (error || !linha) return responder({ erro: "Não foi possível ler os dados." }, 500);

  const equipa: any[] = Array.isArray(linha.team) ? linha.team : [];
  const tarefas: any = linha.tasks || {};
  const eventos: any[] = Array.isArray(linha.events) ? linha.events : [];

  /* Só o que está por fechar. A coluna "done" não interessa de manhã. */
  const pendentes: any[] = [];
  for (const col of ["todo", "doing", "review"]) {
    for (const t of tarefas[col] || []) pendentes.push({ ...t, onde: col });
  }

  const doDia = eventos.filter((e: any) => !e.date || String(e.date) === hoje);
  const blocoDia = doDia.length
    ? '<p style="margin:0 0 6px;font-size:14px;color:#0F172A"><b>Hoje na agenda</b></p><ul style="padding-left:18px;margin:0 0 16px">' +
      doDia
        .map(
          (e: any) =>
            '<li style="margin-bottom:4px;font-size:14px;color:#475569">' +
            (e.time ? "<b>" + escapar(e.time) + "</b> · " : "") +
            escapar(e.title) +
            "</li>"
        )
        .join("") +
      "</ul>"
    : "";

  const enviar = async (para: string, assunto: string, html: string) => {
    try {
      const r = await fetch(URL_SB.replace(/\/$/, "") + "/functions/v1/bright-worker", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer " + CHAVE_SERVICO,
        },
        body: JSON.stringify({ to: para, subject: assunto, html }),
      });
      return r.ok;
    } catch (_) {
      return false;
    }
  };

  let pessoais = 0;
  let deEquipa = 0;
  const falhas: string[] = [];

  // 1. A cada pessoa, o que é dela.
  for (const u of equipa) {
    if (!u || !u.email) continue;
    const minhas = pendentes.filter((t) => (t.assignees || []).includes(u.id));
    if (!minhas.length) continue;
    const nome = String(u.name || "").split(" ")[0];
    const ok = await enviar(
      u.email,
      "As suas tarefas de hoje (" + minhas.length + ")",
      envelope(
        "Bom dia, " + escapar(nome) + ".",
        blocoDia +
          '<p style="margin:0;font-size:14px;color:#475569">Tem <b>' +
          minhas.length +
          "</b> tarefa(s) por fechar:</p>" +
          listaDeTarefas(minhas, false, equipa),
        "tarefas",
        "Ver as minhas tarefas"
      )
    );
    ok ? pessoais++ : falhas.push(u.email);
  }

  // 2. A cada equipa, o que está em aberto na área dela — a toda a gente
  //    dessa área, e não só a quem tem a tarefa em mãos.
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
    const membros = equipa.filter((u: any) => u && u.email && u.dept === area);
    if (!membros.length) continue;
    const html = envelope(
      escapar(area) + " — " + lista.length + " em aberto",
      '<p style="margin:0;font-size:14px;color:#475569">O que a equipa tem em mãos esta manhã:</p>' +
        listaDeTarefas(lista, true, equipa),
      "tarefas",
      "Ver no Workspace"
    );
    for (const u of membros) {
      const ok = await enviar(u.email, escapar(area) + ": " + lista.length + " tarefa(s) em aberto", html);
      ok ? deEquipa++ : falhas.push(u.email);
    }
  }

  return responder({
    ok: true,
    dia: hoje,
    pendentes: pendentes.length,
    pessoais,
    deEquipa,
    falhas: falhas.length ? falhas : undefined,
  });
});
