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
// Versao 11 (01-10-2026): o resumo leva a agenda de cada pessoa, com os
// eventos de agenda_eventos que ela pode ver (agenda-privada.sql).
// Versao 12 (01-10-2026): eventos de todos os meses (dia_mes).
// Desde a versao 10 (30-09-2026) os envios vao para toda a equipa com
// e-mail valido, tambem os enderecos pessoais dos medicos (decisao do
// Elmar), menos quem tem a marca semEmails.
//
// ASPECTO (26-09-2026): igual ao site novo e a caixa de contacto.
//
// MUDANCA DE SERVIDOR (25-09-2026 a 01-10-2026): o lembrete diario pede
// tambem que cada pessoa termine a sessao e volte a entrar.
//
// EVENTOS COM DATA (25-09-2026): um evento pode repetir-se todas as
// semanas (campo day) ou ser so numa data (campo data, AAAA-MM-DD). Os
// com data so entram no resumo nesse dia.
//
// AVISO DE MENSAGENS DIRECTAS (desde 24-09-2026), "tipo": "mensagens", a
// cada minuto (bsp-avisos-mensagens). So avisa por e-mail quem recebeu uma
// mensagem directa ha mais de 5 minutos, nao respondeu nem a leu, e esta
// offline (sem sinal de presenca ha mais de 2 minutos). Varias mensagens do
// mesmo colega vao num so e-mail. O que ja foi avisado fica em
// avisos_mensagens, para nunca avisar duas vezes.
// Cada tipo tem o seu registo por dia: lembretes_enviados e
// coletivos_enviados.
//
// NOVIDADES DO SISTEMA (27-09-2026), "tipo": "novidades", as 05h00 de
// Luanda (bsp-novidades). Envia a cada pessoa, uma vez, as actualizacoes do
// Workspace da tabela novidades que dizem respeito aos seus grupos (ver
// novidades.sql). Sem novidades por enviar, nao sai nada. A base de dados
// marca-as como enviadas antes do envio (bsp_novidades_reclamar), para um
// agendamento repetido nao as mandar duas vezes.
//
// SOCIOS (27-09-2026, versao 7): quem tem a categoria «Sócio» nao recebe
// lembretes, avisos, resumos nem avisos de mensagens.
//
// LEMBRETE AOS PACIENTES (28-09-2026, versao 8), "tipo": "marcacoes", as
// 10h00 de Luanda (bsp-marcacoes-lembrete). A unica excepcao a regra do
// @barispol.com, aprovada pelo Elmar com o texto: cada marcacao Agendada ou
// Confirmada de amanha (ou do dia em corpo.dia) com e-mail recebe um
// lembrete com a data, a hora, o acto e o link do GPS, sempre com
// rececao@barispol.com em copia. Um por marcacao (marcacoes-lembrete.sql).
//
// FIM DOS GRUPOS DE WHATSAPP (28-09-2026): o lembrete diario e o aviso
// colectivo dizem que a 1 de Outubro de 2026 os grupos de WhatsApp deixam
// de existir e que se usam so o Workspace e os e-mails.
//
// RELATORIO DA VIATURA (30-09-2026, versao 9), "tipo": "transporte":
// segunda-feira as 07h45 (bsp-transporte-semana), ao motorista com a
// Administracao em copia (transporte-manutencao.sql).
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
  const tipo = corpo && (corpo.tipo === "lembrete" || corpo.tipo === "coletivo" || corpo.tipo === "mensagens" || corpo.tipo === "novidades" || corpo.tipo === "marcacoes" || corpo.tipo === "transporte") ? corpo.tipo : "resumo";
  const lembrete = tipo !== "resumo";

  /* Uma vez por dia. O agendamento pode disparar mais do que uma vez —
     por uma repetição, por uma reinstalação — e ninguém quer o mesmo
     e-mail três vezes antes do café. O botão "Enviar agora" passa à
     frente disto, que é para isso que serve. */
  const hoje = new Date().toISOString().slice(0, 10);
  const registo = ({ resumo: "resumos_enviados", lembrete: "lembretes_enviados", coletivo: "coletivos_enviados" } as Record<string, string>)[tipo];
  if (!forcar && tipo !== "mensagens" && tipo !== "novidades" && tipo !== "marcacoes" && tipo !== "transporte") {
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
    .select("team, tasks, events, drive, camadas")
    .eq("id", 1)
    .single();
  if (error || !linha) return responder({ erro: "Não foi possível ler os dados." }, 500);

  const equipa: any[] = Array.isArray(linha.team) ? linha.team : [];
  /* Quem recebe os e-mails automaticos (versao 10, 30-09-2026): toda a
     equipa com um e-mail valido, e nao so @barispol.com (decisao do Elmar:
     os medicos usam enderecos pessoais). Fica de fora quem tem a marca
     semEmails (a conta de teste «Beb»). A mesma regra esta na base de
     dados (bsp_recebe_emails, emails-toda-equipa.sql). */
  const semEmails = new Set(equipa.filter((u: any) => u && u.semEmails).map((u: any) => String(u.email || "").trim().toLowerCase()));
  const daClinica = (email: unknown) => {
    const e = String(email || "").trim().toLowerCase();
    return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e) && !semEmails.has(e);
  };
  /* Socios (27-09-2026, socios.sql): vem so os numeros do Painel e nao
     recebem nada do dia-a-dia (lembretes, avisos, resumos, mensagens). As
     novidades chegam-lhes pelo grupo 'socios', filtrado na base de dados. */
  const camadas: any = (linha as any).camadas || {};
  const socio = (u: any) => !!u && (u.accessLevel === "Sócio" || !!(camadas[u.accessLevel] && camadas[u.accessLevel].soNumeros));
  const destinatarios = equipa.filter((u: any) => u && daClinica(u.email) && !socio(u));
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
  const doDia = eventos.filter((e: any) =>
    e && e.data ? String(e.data) === hoje : (e.day == null ? diaSemana : Number(e.day)) === diaSemana);
  /* AGENDA DE CADA PESSOA (versao 11, 01-10-2026, agenda-privada.sql):
     alem dos eventos da equipa (shared_state.events), os da tabela
     agenda_eventos que a pessoa pode ver: publicos, seus e aqueles para
     que foi convidada (menos os que recusou). Os privados dos outros nunca
     entram. Quem nao tem tarefas mas tem um evento seu ou um convite hoje
     tambem recebe o resumo. */
  let agendaHoje: any[] = [];
  const agendaDe = (u: any) => {
    const meus = agendaHoje.filter((e: any) =>
      (!e.privado || e.dono === u.id || (e.convidados || []).includes(u.id)) && !(e.respostas && e.respostas[u.id] === "nao"));
    const pessoais = meus.filter((e: any) => e.dono === u.id || (e.convidados || []).includes(u.id)).length;
    const lista = doDia
      .map((e: any) => ({ hora: e.time || "", titulo: e.title, local: "", privado: false }))
      .concat(meus.map((e: any) => ({ hora: e.hora || "", titulo: e.titulo, local: e.local || "", privado: !!e.privado })))
      .sort((a: any, b: any) => String(a.hora).localeCompare(String(b.hora)));
    const html = lista.length
      ? '<p style="margin:0 0 6px;font-size:15px;color:#1C2033"><b>Hoje na agenda</b></p><ul style="padding-left:18px;margin:0 0 16px">' +
        lista
          .map(
            (e: any) =>
              '<li style="margin-bottom:4px;font-size:15px;color:#1C2033">' +
              (e.hora ? "<b>" + escapar(e.hora) + "</b> · " : "") +
              escapar(e.titulo) +
              (e.local ? " · " + escapar(e.local) : "") +
              (e.privado ? ' <span style="color:#4E5366;font-size:13px">(privado)</span>' : "") +
              "</li>"
          )
          .join("") +
        "</ul>"
      : "";
    return { html, pessoais };
  };

  const enviar = async (para: string, assunto: string, html: string, cc?: string[]) => {
    try {
      const r = await fetch(URL_SB.replace(/\/$/, "") + "/functions/v1/bright-worker", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer " + CHAVE_SERVICO,
        },
        body: JSON.stringify({ to: para, subject: assunto, html, ...(cc && cc.length ? { cc } : {}) }),
      });
      return r.ok;
    } catch (_) {
      return false;
    }
  };

  /* Lembrete da marcacao ao paciente (28-09-2026). Texto aprovado pelo
     Elmar; a recepcao vai sempre em copia. */
  if (tipo === "marcacoes") {
    const luanda = new Date(Date.now() + 3600 * 1000);
    const amanha = new Date(Date.UTC(luanda.getUTCFullYear(), luanda.getUTCMonth(), luanda.getUTCDate() + 1)).toISOString().slice(0, 10);
    const dia = corpo && /^\d{4}-\d{2}-\d{2}$/.test(String(corpo.dia || "")) ? String(corpo.dia) : amanha;
    const { data: lista, error: eM } = await admin.rpc("bsp_marc_lembretes_reclamar", { p_dia: dia });
    if (eM) return responder({ erro: "Não foi possível ler as marcações: " + eM.message }, 500);
    const MESES = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
    const MESES_C = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
    const SEMANA = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"];
    const d = new Date(dia + "T12:00:00Z");
    const dataLonga = SEMANA[d.getUTCDay()] + ", " + d.getUTCDate() + " de " + MESES[d.getUTCMonth()] + " de " + d.getUTCFullYear();
    const dataCurta = d.getUTCDate() + " " + MESES_C[d.getUTCMonth()] + " " + d.getUTCFullYear();
    const PEQUENAS = ["de", "da", "do", "das", "dos", "e"];
    const nomeProprio = (t: string) => t.toLowerCase().split(/\s+/).filter(Boolean)
      .map((w, i) => i > 0 && PEQUENAS.includes(w) ? w : w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
    const frase = (t: string) => { const x = String(t || "").trim().toLowerCase(); return x ? x.charAt(0).toUpperCase() + x.slice(1) : ""; };
    /* Direcções no Google Maps: no telemóvel abre o GPS ja com o destino. */
    const GPS = "https://www.google.com/maps/dir/?api=1&destination=-8.945743,13.240542";
    const botaoGps =
      '<a href="' + GPS + '" style="display:inline-block;padding:12px 22px;border-radius:2px;background:' + MARINHO_BOTAO + ';border:1px solid ' + MARINHO_BOTAO + ';font-family:' + FONTE + ';font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none">Abrir o caminho no GPS</a>' +
      '<p style="margin:10px 0 0;font-family:' + FONTE + ';font-size:11px;color:#8A8F9E;word-break:break-all">' + GPS + "</p>";
    const linhaDado = (rotulo: string, valor: string) =>
      '<tr><td style="padding:6px 16px 6px 0;font-family:' + FONTE + ';font-size:15px;font-weight:700;color:' + MARINHO + ';vertical-align:top;white-space:nowrap">' + rotulo + '</td><td style="padding:6px 0;font-family:' + FONTE + ';font-size:15px;color:' + TEXTO + '">' + valor + "</td></tr>";
    let enviadosM = 0;
    const falhasM: string[] = [];
    for (const m of (lista || []) as any[]) {
      const primeiro = nomeProprio(String(m.nome || "").trim().split(/\s+/)[0] || "");
      const medico = nomeProprio(String(m.medico || "").trim());
      const hora = String(m.hora || "").trim();
      const tabela =
        '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:4px 0 16px;border-top:1px solid ' + LINHA + ';border-bottom:1px solid ' + LINHA + '">' +
        linhaDado("Acto", escapar(frase(m.acto))) +
        linhaDado("Data", escapar(dataLonga)) +
        (hora ? linhaDado("Hora", escapar(hora)) : "") +
        (medico ? linhaDado("Médico", escapar(medico)) : "") +
        "</table>";
      const html = envelope(
        primeiro ? "Olá, " + escapar(primeiro) + "." : "Olá.",
        paragrafo("Lembramos a sua marcação no Centro Médico Barispol:") +
          tabela +
          paragrafo("Chegue 15 minutos antes, com o documento de identificação e, se tiver seguro, o cartão.") +
          paragrafo("Se não puder vir, avise-nos para remarcar: +244 946 373 631 (Recepção e WhatsApp) ou +244 959 573 631.") +
          paragrafo("Morada: Bairro Bom Sossego, Casa 186, Camama, Luanda. O botão abaixo abre o caminho no GPS do telemóvel.", true),
        undefined,
        undefined,
        "Lembrete da sua marcação.",
        "Lembrete de marcação",
        "Camama, Luanda",
        botaoGps
      );
      const ok = await enviar(
        m.email,
        "Lembrete da sua marcação — Centro Médico Barispol, " + dataCurta + (hora ? ", " + hora : ""),
        html,
        ["rececao@barispol.com"]
      );
      await admin.rpc("bsp_marc_lembrete_registar", { p_id: m.marcacao_id, p_dia: dia, p_ok: ok });
      ok ? enviadosM++ : falhasM.push(String(m.marcacao_id));
    }
    return responder({ ok: true, tipo, dia, enviados: enviadosM, falhas: falhasM.length ? falhasM : undefined });
  }

  /* Relatorio semanal da viatura (30-09-2026, transporte-manutencao.sql).
     Segunda-feira: o consumo da semana anterior (segunda a domingo) vai
     para o motorista, com a Administracao em copia e como «responder
     para». Pede-lhe a informacao da viatura. Uma vez por semana
     (transporte_semana_enviados); «previa» devolve o e-mail sem enviar. */
  if (tipo === "transporte") {
    const previa = corpo && corpo.previa === true;
    const luanda = new Date(Date.now() + 3600 * 1000);
    const hojeL = new Date(Date.UTC(luanda.getUTCFullYear(), luanda.getUTCMonth(), luanda.getUTCDate()));
    const dSem = (hojeL.getUTCDay() + 6) % 7;
    const segundaEsta = new Date(hojeL.getTime() - dSem * 86400000);
    const de = corpo && /^\d{4}-\d{2}-\d{2}$/.test(String(corpo.semana || "")) ? String(corpo.semana)
      : new Date(segundaEsta.getTime() - 7 * 86400000).toISOString().slice(0, 10);
    const ate = new Date(new Date(de + "T00:00:00Z").getTime() + 6 * 86400000).toISOString().slice(0, 10);
    const normal = (t: unknown) => String(t || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim();
    const para = destinatarios.filter((u: any) => /motorista/i.test(String(u.role || ""))).map((u: any) => String(u.email).trim());
    const adm = destinatarios.filter((u: any) => normal(u.dept) === "administracao").map((u: any) => String(u.email).trim()).filter((e: string) => para.indexOf(e) === -1);
    if (!para.length) return responder({ ok: true, tipo, enviados: 0, nota: "Ninguém com o cargo de motorista e e-mail da clínica." });
    if (!previa && !forcar) {
      const { error: jaFoi } = await admin.from("transporte_semana_enviados").insert({ semana: de, para: para.join(", ") });
      if (jaFoi) {
        const m = String(jaFoi.message || "").toLowerCase();
        if (jaFoi.code === "23505" || /duplicate key/.test(m)) return responder({ ok: true, tipo, enviados: 0, nota: "O relatório desta semana já tinha saído." });
        return responder({ erro: "Não foi possível registar o envio: " + jaFoi.message }, 500);
      }
    }
    const [rv, rAntes, ra, rm] = await Promise.all([
      admin.from("transporte_viagens").select("tipo, km_inicio, km_fim, data").gte("data", de).lte("data", ate).not("km_fim", "is", null).order("km_inicio"),
      admin.from("transporte_viagens").select("km_fim").lt("data", de).not("km_fim", "is", null).order("km_fim", { ascending: false }).limit(1),
      admin.from("transporte_abastecimentos").select("km, litros, valor, quando").gte("quando", de + "T00:00:00+01:00").lte("quando", ate + "T23:59:59+01:00").order("quando"),
      admin.from("transporte_manutencoes").select("*").order("data", { ascending: false }).limit(200),
    ]);
    const erroT = rv.error || rAntes.error || ra.error;
    if (erroT) return responder({ erro: "Não foi possível ler o transporte: " + erroT.message }, 500);
    const viagens: any[] = rv.data || [];
    const abast: any[] = ra.data || [];
    const manut: any[] = rm.error ? [] : (rm.data || []);
    const porTipo: Record<string, number> = {};
    viagens.forEach((v) => { porTipo[v.tipo] = (porTipo[v.tipo] || 0) + (v.km_fim - v.km_inicio); });
    const registados = Object.values(porTipo).reduce((a, b) => a + b, 0);
    const kmFim = viagens.reduce((m, v) => Math.max(m, v.km_fim), 0);
    const kmAntes = rAntes.data && rAntes.data[0] ? Number(rAntes.data[0].km_fim) : (viagens[0] ? viagens[0].km_inicio : 0);
    const total = kmFim && kmAntes ? Math.max(registados, kmFim - kmAntes) : registados;
    const semRegisto = Math.max(0, total - registados);
    const litros = abast.reduce((a, x) => a + Number(x.litros || 0), 0);
    const valorComb = abast.reduce((a, x) => a + Number(x.valor || 0), 0);
    const feitas = manut.filter((m) => m.estado === "feita" && m.data >= de && m.data <= ate);
    const valorManut = feitas.reduce((a, m) => a + Number(m.valor || 0), 0);
    const pendentes = manut.filter((m) => m.estado === "orcamento" || m.estado === "aprovada");
    const prox = manut.filter((m) => m.estado === "feita" && (m.proxima_km || m.proxima_data))[0];
    const n1 = (v: number, casas = 0) => v.toLocaleString("pt-PT", { minimumFractionDigits: casas, maximumFractionDigits: casas });
    const kz = (v: number) => n1(Math.round(v)) + " Kz";
    const MESES_C = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
    const dc = (iso: string) => { const d = new Date(iso + "T12:00:00Z"); return d.getUTCDate() + " " + MESES_C[d.getUTCMonth()] + " " + d.getUTCFullYear(); };
    const linhaDado = (rotulo: string, valor: string, perigo = false) =>
      '<tr><td style="padding:6px 16px 6px 0;font-family:' + FONTE + ';font-size:15px;font-weight:700;color:' + MARINHO + ';vertical-align:top">' + rotulo + '</td><td style="padding:6px 0;font-family:' + FONTE + ';font-size:15px;color:' + (perigo ? "#B42318" : TEXTO) + '">' + valor + "</td></tr>";
    const tabela = (linhas: string) => '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:4px 0 18px;border-top:1px solid ' + LINHA + ';border-bottom:1px solid ' + LINHA + '">' + linhas + "</table>";
    const subtitulo = (t: string) => '<p style="margin:18px 0 6px;font-family:' + FONTE + ';font-size:15px;font-weight:700;color:' + MARINHO + '">' + t + "</p>";
    const servicoDia = (porTipo.amostras || 0) + (porTipo.compras || 0) + (porTipo.outro || 0) + (porTipo.ligacao || 0);
    const consumo =
      linhaDado("Km percorridos", total ? n1(total) + " km" + (kmFim ? " (de " + n1(kmAntes) + " a " + n1(kmFim) + ")" : "") : "Sem viagens registadas") +
      (total ? linhaDado("Rota do pessoal", n1(porTipo.pessoal || 0) + " km") + linhaDado("Serviço de dia", n1(servicoDia) + " km") + linhaDado("Para casa", n1(porTipo.casa || 0) + " km") : "") +
      (semRegisto ? linhaDado("Sem registo", n1(semRegisto) + " km", true) : "") +
      linhaDado("Combustível", litros ? n1(litros, 1) + " L · " + kz(valorComb) + " (" + abast.length + (abast.length === 1 ? " abastecimento" : " abastecimentos") + ")" : "Sem abastecimentos registados") +
      (litros && total ? linhaDado("Consumo", n1(total / litros, 1) + " km por litro · " + n1(valorComb / total, 1) + " Kz por km") : "") +
      linhaDado("Manutenção feita", feitas.length ? kz(valorManut) + " · " + feitas.map((m) => escapar(m.descricao)).join("; ") : "Nenhuma registada") +
      (total && (valorComb + valorManut) ? linhaDado("Custo total por km", n1((valorComb + valorManut) / total, 1) + " Kz") : "");
    const pend = pendentes.length
      ? subtitulo("Manutenção em aberto") + '<ul style="padding-left:18px;margin:0 0 16px">' + pendentes.map((m) =>
          '<li style="margin-bottom:4px;font-family:' + FONTE + ';font-size:15px;color:' + TEXTO + '">' + (m.estado === "orcamento" ? "Orçamento por aprovar" : "Aprovada, por fazer") + " · " + kz(Number(m.valor || 0)) + " · " + escapar(m.descricao) + (m.oficina ? " (" + escapar(m.oficina) + ")" : "") + " · " + dc(m.data) + "</li>").join("") + "</ul>"
      : "";
    const proxTxt = prox ? paragrafo("<b>Próxima revisão:</b> " + [prox.proxima_km ? n1(prox.proxima_km) + " km" : "", prox.proxima_data ? dc(prox.proxima_data) : ""].filter(Boolean).join(" ou ") + (kmFim && prox.proxima_km ? " (faltam " + n1(prox.proxima_km - kmFim) + " km)" : "") + ".") : "";
    const pedidos = [
      "Os km de hoje no conta-quilómetros, com fotografia.",
      "Óleo, água, travões, pneus e luzes: em ordem, ou o que falta.",
      "Manutenção feita ou necessária, com o orçamento ou a factura.",
      "Avarias, riscos, multas ou acidentes da semana.",
      "Documentos da viatura: seguro, inspecção e taxa de circulação, com o prazo de cada um.",
      "Abastecimentos ou viagens que ficaram por registar.",
    ];
    const listaPedidos = '<ol style="padding-left:20px;margin:0 0 14px">' + pedidos.map((t) => '<li style="margin-bottom:6px;font-family:' + FONTE + ';font-size:15px;line-height:1.5;color:' + TEXTO + '">' + t + "</li>").join("") + "</ol>";
    const primeiro = (email: string) => { const u = destinatarios.find((x: any) => String(x.email).trim() === email); return u ? String(u.name).split(" ")[0] : ""; };
    const nome = primeiro(para[0]);
    const html = envelope(
      nome ? "Bom dia, " + escapar(nome) + "." : "Bom dia.",
      paragrafo("Este é o relatório da viatura da semana de " + dc(de) + " a " + dc(ate) + ", feito com o que ficou registado no ecrã Transporte do Workspace.") +
        subtitulo("Consumo da semana") + tabela(consumo) + pend + proxTxt +
        subtitulo("Envie-nos até quarta-feira") +
        paragrafo("Responda a este e-mail (a resposta vai para a Administração) com:") + listaPedidos +
        paragrafo("Manutenção e abastecimentos registam-se também no Workspace, em Transporte, com a fotografia do recibo.", true),
      "transporte",
      "Abrir o Transporte",
      "Relatório semanal da viatura, todas as segundas-feiras.",
      "Relatório da viatura"
    );
    const assunto = "Relatório da viatura: semana de " + dc(de) + " a " + dc(ate);
    if (previa) return responder({ ok: true, tipo, previa: true, para, cc: adm, assunto, semana: de, total, litros, valorComb, valorManut, html });
    const r = await fetch(URL_SB.replace(/\/$/, "") + "/functions/v1/bright-worker", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: "Bearer " + CHAVE_SERVICO },
      body: JSON.stringify({ to: para, subject: assunto, html, ...(adm.length ? { cc: adm, reply_to: adm } : {}) }),
    }).catch(() => null);
    const ok = !!(r && r.ok);
    await admin.from("transporte_semana_enviados").update({ ok, para: para.concat(adm).join(", ") }).eq("semana", de);
    return responder({ ok, tipo, semana: de, para, cc: adm, enviados: ok ? 1 : 0 });
  }

  /* Novidades do sistema: so quando ha, a quem dizem respeito. */
  if (tipo === "novidades") {
    const { data: porPessoa, error: eN } = await admin.rpc("bsp_novidades_reclamar");
    if (eN) return responder({ erro: "Não foi possível ler as novidades: " + eN.message }, 500);
    const lista: any[] = Array.isArray(porPessoa) ? porPessoa : [];
    if (!lista.length) return responder({ ok: true, tipo, enviados: 0, nota: "Sem novidades por enviar." });
    let enviadosN = 0;
    const falhasN: string[] = [];
    const todasIds = new Set<number>();
    for (const p of lista) {
      const novs: any[] = Array.isArray(p.novidades) ? p.novidades : [];
      if (!novs.length || !daClinica(p.email)) continue;
      novs.forEach((n: any) => todasIds.add(Number(n.id)));
      const nome = String(p.nome || "").split(" ")[0];
      const blocos = novs.map((n: any) => {
        const pars = String(n.texto || "").split(/\n\s*\n/).map((t) => t.trim()).filter(Boolean);
        return '<div style="margin:0 0 20px;padding:0 0 0 14px;border-left:3px solid ' + AZUL + '">' +
          '<p style="margin:0 0 6px;font-family:' + FONTE + ';font-size:17px;font-weight:700;color:' + MARINHO + '">' + escapar(n.titulo) + "</p>" +
          pars.map((t, i) => paragrafo(escapar(t).replace(/\n/g, "<br>"), i === pars.length - 1)).join("") +
          "</div>";
      }).join("");
      const destino = novs.length === 1 && novs[0].destino ? String(novs[0].destino) : "";
      const html = envelope(
        "Bom dia, " + escapar(nome) + ".",
        paragrafo(novs.length === 1 ? "Há uma novidade no Workspace que muda o seu trabalho:" : "Há " + novs.length + " novidades no Workspace que mudam o seu trabalho:") + blocos,
        destino || "notificacoes",
        destino ? "Ver no Workspace" : "Abrir o Workspace",
        "Aviso de actualização do sistema, só quando há novidades.",
        "Novidades do Workspace"
      );
      const assunto = novs.length === 1 ? "Novidade no Workspace: " + String(novs[0].titulo) : novs.length + " novidades no Workspace";
      const ok = await enviar(p.email, assunto, html);
      ok ? enviadosN++ : falhasN.push(p.email);
    }
    await admin.rpc("bsp_novidades_registar", { ids: Array.from(todasIds), n: enviadosN });
    return responder({ ok: true, tipo, novidades: todasIds.size, enviados: enviadosN, falhas: falhasN.length ? falhasN : undefined });
  }

  /* Mensagens directas por responder, a quem esta offline. */
  if (tipo === "mensagens") {
    const agoraMs = Date.now();
    const desde = new Date(agoraMs - 60 * 60000).toISOString();
    const ate = new Date(agoraMs - 5 * 60000).toISOString();
    /* As linhas de controlo (leitura, edicao, reaccoes) nao sao mensagens;
       os anexos sao. */
    const controlo = (t: unknown) => {
      const x = String(t || "");
      return x.length > 2 && x.charAt(0) === "\u200b" && x.charAt(2) === "\u200b" && "lrpe".indexOf(x.charAt(1)) !== -1;
    };
    const textoVisivel = (t: unknown) => {
      const x = String(t || "");
      /* O anexo vai no fim, depois da marca: mostra-se so o texto antes
         dela («Partilhou o ficheiro…», «🎤 Nota de voz (0:12).»). */
      const i = x.indexOf("\u200bf\u200b");
      if (i === 0) return "📎 Enviou um anexo.";
      return (i > 0 ? x.slice(0, i) : x).replace(/\u200b/g, "");
    };
    const { data: candidatas, error: e1 } = await admin
      .from("messages")
      .select("id, conv_key, user_id, text, created_at")
      .like("conv_key", "dm-%")
      .gte("created_at", desde)
      .lte("created_at", ate)
      .order("id", { ascending: true })
      .limit(500);
    if (e1) return responder({ erro: "Não foi possível ler as mensagens: " + e1.message }, 500);
    const reais = (candidatas || []).filter((m: any) => !controlo(m.text));
    if (!reais.length) return responder({ ok: true, tipo, avisados: 0 });

    const ids = reais.map((m: any) => m.id);
    const { data: jaAvisadas } = await admin.from("avisos_mensagens").select("msg_id").in("msg_id", ids);
    const avisadas = new Set((jaAvisadas || []).map((r: any) => r.msg_id));
    const porAvisar = reais.filter((m: any) => !avisadas.has(m.id));
    if (!porAvisar.length) return responder({ ok: true, tipo, avisados: 0 });

    /* Tudo o que o destinatario escreveu depois, na mesma conversa —
       resposta ou recibo de leitura — quer dizer que ja viu. */
    const convs = Array.from(new Set(porAvisar.map((m: any) => m.conv_key)));
    const menorId = Math.min(...porAvisar.map((m: any) => m.id));
    const { data: depois } = await admin
      .from("messages")
      .select("id, conv_key, user_id")
      .in("conv_key", convs)
      .gt("id", menorId);
    const { data: presencas } = await admin.from("presenca").select("user_id, visto_em");
    const vistoEm = new Map((presencas || []).map((r: any) => [r.user_id, new Date(r.visto_em).getTime()]));
    const online = (id: string) => (vistoEm.get(id) || 0) > agoraMs - 2 * 60000;

    const grupos = new Map<string, any[]>();
    const semAviso: number[] = [];
    for (const m of porAvisar) {
      const par = String(m.conv_key).slice(3).split("_");
      const para = par.find((x) => x && x !== m.user_id);
      if (!para) { semAviso.push(m.id); continue; }
      const viu = (depois || []).some((d: any) => d.conv_key === m.conv_key && d.user_id === para && d.id > m.id);
      if (viu) { semAviso.push(m.id); continue; }
      if (online(para)) continue; // ainda pode responder; volta a ver no minuto seguinte
      const chave = para + "|" + m.conv_key;
      if (!grupos.has(chave)) grupos.set(chave, []);
      grupos.get(chave)!.push(m);
    }
    /* O que ja nao precisa de aviso fica marcado, para nao voltar a ser visto. */
    if (semAviso.length) await admin.from("avisos_mensagens").upsert(semAviso.map((id) => ({ msg_id: id, enviado: false })));

    let avisados = 0;
    const falhasMsg: string[] = [];
    for (const [chave, lista] of grupos) {
      const [paraId, conv] = chave.split("|");
      const dest = equipa.find((u: any) => u && u.id === paraId);
      const rem = equipa.find((u: any) => u && u.id === lista[0].user_id);
      const ids2 = lista.map((m: any) => m.id);
      if (!dest || !daClinica(dest.email) || socio(dest)) {
        await admin.from("avisos_mensagens").upsert(ids2.map((id: number) => ({ msg_id: id, enviado: false })));
        continue;
      }
      const nomeRem = rem ? String(rem.name || "Um colega") : "Um colega";
      const primeiro = nomeRem.split(" ")[0];
      const itens = lista.slice(-5).map((m: any) => {
        const d = new Date(m.created_at);
        const hora = d.toLocaleString("pt-PT", { timeZone: "Africa/Luanda", day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
        const t = textoVisivel(m.text);
        return '<li style="margin-bottom:8px"><span style="color:#94A3B8;font-size:12px">' + escapar(hora) + "</span><br>" +
          escapar(t.length > 300 ? t.slice(0, 300) + "…" : t).replace(/\n/g, "<br>") + "</li>";
      }).join("");
      const html = envelope(
        "Mensagem de " + escapar(nomeRem),
        paragrafo(escapar(primeiro) + " enviou-lhe " + (lista.length === 1 ? "uma mensagem" : lista.length + " mensagens") + " no Workspace, ainda por ler:") +
          '<ul style="padding-left:18px;margin:6px 0 0;font-family:' + FONTE + ';font-size:15px;line-height:1.5;color:' + TEXTO + '">' + itens + "</ul>",
        "chat/" + conv,
        "Responder a " + escapar(primeiro),
        "Aviso enviado porque a mensagem ficou 5 minutos por ler e estava offline.",
        "Mensagem no Workspace"
      );
      const ok = await enviar(dest.email, "[Workspace] " + primeiro + " enviou-lhe " + (lista.length === 1 ? "uma mensagem" : lista.length + " mensagens"), html);
      if (ok) {
        avisados++;
        await admin.from("avisos_mensagens").upsert(ids2.map((id: number) => ({ msg_id: id, enviado: true })));
      } else falhasMsg.push(dest.email);
    }
    return responder({ ok: true, tipo, avisados, falhas: falhasMsg.length ? falhasMsg : undefined });
  }

  /* O lembrete vai para toda a gente, tenha ou nao tarefas: um e-mail por
     pessoa, tratada pelo nome. Curto: serve para a pessoa abrir o
     Workspace antes de comecar o dia, e avisa que o WhatsApp deixa em
     breve de ser o canal interno. */
  if (lembrete) {
    let lembrados = 0;
    const falhasLembrete: string[] = [];
    /* Mudanca de servidor (25-09 a 01-10-2026): pedir que cada pessoa
       termine a sessao e volte a entrar. */
    const mudanca = hoje <= "2026-10-01"
      ? paragrafo("<b>Mudámos o Workspace de servidor.</b> Se ainda não o fez, termine a sessão (menu Mais → Terminar sessão) e volte a entrar com o mesmo e-mail e a mesma palavra-passe. No telemóvel, feche a aplicação por completo antes de a abrir de novo.")
      : "";
    /* Fim dos grupos de WhatsApp (pedido do Elmar, 28-09-2026). */
    const whatsapp = hoje < "2026-10-01"
      ? "<b>A 1 de Outubro os grupos de WhatsApp da equipa deixam de existir.</b> A partir desse dia, usem apenas o Workspace e os e-mails da clínica."
      : hoje === "2026-10-01"
        ? "<b>A partir de hoje, 1 de Outubro, os grupos de WhatsApp da equipa deixam de existir.</b> Usem apenas o Workspace e os e-mails da clínica."
        : "<b>Os grupos de WhatsApp da equipa já não existem.</b> Usem apenas o Workspace e os e-mails da clínica.";
    const coletivo = envelope(
      "Olá, equipa.",
      paragrafo("O Workspace é o nosso ponto de encontro. Entrem todos os dias: é lá que estão as mensagens, as tarefas e a agenda da clínica.") +
        paragrafo(whatsapp + " Para falar com os colegas e com as equipas, usem o Chat do Workspace.") +
        paragrafo("Se tiverem dificuldade em entrar, falem com a Administração.", true),
      "chat",
      "Abrir o Chat do Workspace",
      "Aviso a toda a equipa.",
      "Aviso à equipa"
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
              mudanca +
              paragrafo(whatsapp, true),
            "chat",
            "Entrar no Workspace",
            "Lembrete diário.",
            "Lembrete diário"
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

  // 1. A cada pessoa, o que é dela (tarefas e agenda).
  const { data: agendaLinhas } = await admin
    .from("agenda_eventos")
    .select("dono, titulo, hora, dia, data, dia_mes, privado, convidados, respostas, local");
  /* dia_mes: todos os meses nesse dia, a partir de data. */
  agendaHoje = ((agendaLinhas || []) as any[]).filter((e: any) =>
    e && (e.dia_mes ? String(e.data || "") <= hoje && Number(hoje.slice(8, 10)) === Number(e.dia_mes)
      : e.data ? String(e.data) === hoje : Number(e.dia) === diaSemana));
  for (const u of destinatarios) {
    const minhas = pendentes.filter((t) => (t.assignees || []).includes(u.id));
    const ag = agendaDe(u);
    if (!minhas.length && !ag.pessoais) continue;
    const nome = String(u.name || "").split(" ")[0];
    const ok = await enviar(
      u.email,
      minhas.length ? "As suas tarefas de hoje (" + minhas.length + ")" : "A sua agenda de hoje",
      envelope(
        "Bom dia, " + escapar(nome) + ".",
        ag.html +
          (minhas.length
            ? '<p style="margin:0;font-size:15px;color:#1C2033">Tem <b>' +
              minhas.length +
              "</b> tarefa(s) por fechar:</p>" +
              listaDeTarefas(minhas, false, equipa)
            : '<p style="margin:0;font-size:15px;color:#1C2033">Não tem tarefas por fechar.</p>'),
        minhas.length ? "tarefas" : "agenda",
        minhas.length ? "Ver as minhas tarefas" : "Abrir a Agenda"
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
      '<p style="margin:0;font-size:15px;color:#1C2033">O que a equipa tem em mãos esta manhã:</p>' +
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
