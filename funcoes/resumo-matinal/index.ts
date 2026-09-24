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
// AVISOS A TODA A EQUIPA (desde 24-09-2026), pelo campo "tipo" do corpo:
//   · "lembrete": um e-mail por pessoa, tratada pelo nome, para entrar no
//     Workspace. 07h30 de Luanda, todos os dias (bsp-lembrete-diario).
//   · "coletivo": a mesma mensagem para todos («Olá, equipa»), sobre o
//     Workspace como canal interno. 12h00 de Luanda, segunda, quarta e
//     sexta (bsp-aviso-coletivo).
// Os dois avisam que o WhatsApp deixa em breve de ser o canal interno.
// Sai um e-mail por endereco, para ninguem ver os enderecos dos outros.
// Todos os envios desta funcao vao so para enderecos @barispol.com.
// Cada tipo tem o seu registo por dia: lembretes_enviados e
// coletivos_enviados.
//
// COMO INSTALAR (uma vez):
//   1. No Supabase: Edge Functions -> Deploy a new function
//   2. Nome exacto: resumo-matinal
//   3. Cole este ficheiro e faca Deploy
//   4. Correr o resumo-matinal.sql, que marca a hora a que isto acontece
//
// SEGURANCA: so aceita tres coisas. O codigo do agendamento, no cabecalho
// x-bsp-agendamento, que a base de dados gera e guarda no cofre (ver o
// agendar-resumo-sem-chave.sql). A chave service_role. Ou a sessao de
// alguem que a plataforma reconheca como gestor (e o caso do botao
// "Enviar agora"). Com a chave anonima sozinha nao envia nada — senao
// qualquer pessoa podia fazer chegar correio a clinica inteira.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cabecalhos = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-bsp-agendamento",
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

/* A marca: as cores do logotipo e a fonte Dax, com Titillium Web, Segoe UI
   e Arial de recurso. A Dax so aparece a quem a tiver instalada — um
   e-mail nao leva fontes consigo, e o Gmail e o Outlook ignoram as da
   rede. O logotipo vem do proprio site. */
const MARINHO = "#292F58";
const MARINHO_BOTAO = "#273069";
const AZUL = "#2291CE";
const FONTE = "Dax,'Dax Pro','Titillium Web','Segoe UI',Arial,sans-serif";
const LOGOTIPO = "https://barispol.com/assets/logo-barispol.png";

/* O botao que leva a pessoa ao sitio, em vez de a mandar procurar. */
const SITIO = "https://barispol.com/workspace.html";
function botao(destino: string, rotulo: string) {
  const href = SITIO + "#/" + destino;
  return (
    '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:22px 0 0"><tr><td style="border-radius:8px;background:' + MARINHO_BOTAO + '">' +
    '<a href="' + href + '" style="display:inline-block;padding:12px 26px;font-family:' + FONTE + ';font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;border-radius:8px">' +
    rotulo + "</a></td></tr></table>" +
    '<p style="margin:8px 0 0;font-family:' + FONTE + ';font-size:11px;color:#94A3B8;word-break:break-all">' + href + "</p>"
  );
}
/* O cartao de todos os e-mails desta funcao: logotipo em cima, a linha
   azul da marca, texto em azul-marinho, e a pessoa juridica no fim. */
function envelope(titulo: string, corpo: string, destino?: string, rotulo?: string, rodape?: string) {
  return (
    '<div style="background:#F3F6FB;padding:24px 12px">' +
    '<div style="font-family:' + FONTE + ';max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #DFE6F0;border-radius:12px;overflow:hidden">' +
    '<div style="padding:22px 20px 16px;text-align:center;background:#ffffff">' +
    '<img src="' + LOGOTIPO + '" width="84" height="86" alt="Centro Médico Barispol" style="display:inline-block;border:0;width:84px;height:auto">' +
    "</div>" +
    '<div style="height:4px;background:' + AZUL + ';line-height:4px;font-size:0">&nbsp;</div>' +
    '<div style="padding:24px 24px 26px;color:' + MARINHO + '"><h2 style="margin:0 0 14px;font-family:' + FONTE + ';font-size:20px;font-weight:bold;color:' + MARINHO + '">' +
    titulo +
    "</h2>" +
    corpo +
    (destino ? botao(destino, rotulo || "Abrir no Workspace") : "") +
    "</div>" +
    '<div style="padding:14px 24px;background:' + MARINHO + ';color:#ffffff;font-family:' + FONTE + ';font-size:12px;line-height:1.5">' +
    "<b>Centro Médico Barispol</b> — Workspace<br>" +
    '<span style="color:#C9D3E6">' + (rodape || "Este é o resumo automático da manhã.") + " Clínica Barispol, Lda. · NIF 5000999687</span>" +
    "</div></div></div>"
  );
}

/* Paragrafo de texto corrido, na fonte e na cor da marca. */
const paragrafo = (t: string, fim = false) =>
  '<p style="margin:0' + (fim ? "" : " 0 12px") + ";font-family:" + FONTE + ";font-size:15px;line-height:1.6;color:" + MARINHO + '">' + t + "</p>";

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
  const tipo = corpo && (corpo.tipo === "lembrete" || corpo.tipo === "coletivo") ? corpo.tipo : "resumo";
  const lembrete = tipo !== "resumo";

  /* Uma vez por dia. O agendamento pode disparar mais do que uma vez —
     por uma repetição, por uma reinstalação — e ninguém quer o mesmo
     e-mail três vezes antes do café. O botão "Enviar agora" passa à
     frente disto, que é para isso que serve. */
  const hoje = new Date().toISOString().slice(0, 10);
  const registo = ({ resumo: "resumos_enviados", lembrete: "lembretes_enviados", coletivo: "coletivos_enviados" } as Record<string, string>)[tipo];
  if (!forcar) {
    const { error: jaFoi } = await admin
      .from(registo)
      .insert({ dia: hoje });
    if (jaFoi) {
      /* Só a chave repetida quer dizer "já saiu hoje". Qualquer outro
         erro — a tabela não existe, por exemplo — não pode calar o envio
         em silêncio: era assim que uma instalação incompleta ficava a
         não mandar nada, todas as manhãs, sem ninguém perceber. */
      const m = String(jaFoi.message || "").toLowerCase();
      const jaSaiu = jaFoi.code === "23505" || /duplicate key|already exists/.test(m);
      if (jaSaiu) {
        return responder({
          ok: true,
          enviados: 0,
          nota: lembrete ? "O aviso (" + tipo + ") de hoje já tinha saído." : "O resumo de hoje já tinha saído.",
          fonte_chave: fonteChaveServidor(),
        });
      }
      if (/relation|does not exist|schema cache/.test(m)) {
        return responder({
          erro: "Falta a tabela " + registo + ". Corra o agendar-resumo-sem-chave.sql no SQL Editor.",
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
  /* Os e-mails automaticos so vao para enderecos da clinica
     (@barispol.com), por decisao do Elmar de 24-09-2026. Quem tem um
     endereco pessoal continua na equipa e aparece nas listas dos colegas,
     mas nao recebe estes e-mails. */
  const daClinica = (email: unknown) => /@barispol\.com$/i.test(String(email || "").trim());
  const destinatarios = equipa.filter((u: any) => u && daClinica(u.email));
  const tarefas: any = linha.tasks || {};
  const eventos: any[] = Array.isArray(linha.events) ? linha.events : [];

  /* Só o que está por fechar. A coluna "done" não interessa de manhã. */
  const pendentes: any[] = [];
  for (const col of ["todo", "doing", "review"]) {
    for (const t of tarefas[col] || []) pendentes.push({ ...t, onde: col });
  }

  /* Os eventos nao tem data: tem dia da semana (0 = Segunda). A aplicacao
     mostra-os assim e o resumo tem de contar da mesma maneira, senao
     anuncia todos os eventos todos os dias. */
  const diaSemana = (new Date().getUTCDay() + 6) % 7;
  const doDia = eventos.filter((e: any) => (e.day == null ? diaSemana : Number(e.day)) === diaSemana);
  const blocoDia = doDia.length
    ? '<p style="margin:0 0 6px;font-size:14px;color:#292F58"><b>Hoje na agenda</b></p><ul style="padding-left:18px;margin:0 0 16px">' +
      doDia
        .map(
          (e: any) =>
            '<li style="margin-bottom:4px;font-size:14px;color:#292F58">' +
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

  /* O lembrete vai para toda a gente, tenha ou nao tarefas: um e-mail por
     pessoa, tratada pelo nome. Curto: serve para a pessoa abrir o
     Workspace antes de comecar o dia, e avisa que o WhatsApp deixa em
     breve de ser o canal interno. */
  if (lembrete) {
    let lembrados = 0;
    const falhasLembrete: string[] = [];
    const coletivo = envelope(
      "Olá, equipa.",
      paragrafo("O Workspace é o nosso ponto de encontro. Entrem todos os dias: é lá que estão as mensagens, as tarefas e a agenda da clínica.") +
        paragrafo("<b>Em breve deixaremos de usar o WhatsApp</b> para a comunicação interna. Usem já o Chat do Workspace para falar com os colegas e com as equipas.") +
        paragrafo("Se tiverem dificuldade em entrar, falem com a Administração.", true),
      "chat",
      "Abrir o Chat do Workspace",
      "Aviso a toda a equipa."
    );
    for (const u of destinatarios) {
      const nome = String(u.name || "").split(" ")[0];
      const ok = tipo === "coletivo"
        ? await enviar(u.email, "Equipa Barispol: o Workspace é o nosso canal", coletivo)
        : await enviar(
          u.email,
          "Bom dia — o Workspace espera por si",
          envelope(
            "Bom dia, " + escapar(nome) + ".",
            paragrafo("Antes de começar o dia, entre no Workspace. Veja as mensagens, as tarefas e a agenda de hoje.") +
              paragrafo("<b>Em breve deixaremos de usar o WhatsApp</b> para a comunicação interna. As conversas da equipa passam a ser feitas no Chat do Workspace.", true),
            "chat",
            "Entrar no Workspace",
            "Lembrete diário."
          )
        );
      ok ? lembrados++ : falhasLembrete.push(u.email);
    }
    return responder({
      ok: true,
      dia: hoje,
      tipo,
      lembrados,
      falhas: falhasLembrete.length ? falhasLembrete : undefined,
      fonte_chave: fonteChaveServidor(),
    });
  }

  let pessoais = 0;
  let deEquipa = 0;
  const falhas: string[] = [];

  // 1. A cada pessoa, o que é dela.
  for (const u of destinatarios) {
    const minhas = pendentes.filter((t) => (t.assignees || []).includes(u.id));
    if (!minhas.length) continue;
    const nome = String(u.name || "").split(" ")[0];
    const ok = await enviar(
      u.email,
      "As suas tarefas de hoje (" + minhas.length + ")",
      envelope(
        "Bom dia, " + escapar(nome) + ".",
        blocoDia +
          '<p style="margin:0;font-size:14px;color:#292F58">Tem <b>' +
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
    const membros = destinatarios.filter((u: any) => u.dept === area);
    if (!membros.length) continue;
    const html = envelope(
      escapar(area) + " — " + lista.length + " em aberto",
      '<p style="margin:0;font-size:14px;color:#292F58">O que a equipa tem em mãos esta manhã:</p>' +
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
    fonte_chave: fonteChaveServidor(),
  });
});
