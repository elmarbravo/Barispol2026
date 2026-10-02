// Barispol Workspace · assistente com IA (versão 2, 02-10-2026; versão 1 a 01-10-2026)
//
// Pedido do Elmar: o modelo mais barato (Claude Haiku 4.5), com um limite
// por pessoa como o do ChatGPT gratuito: 10 perguntas a cada 5 horas
// (bsp_assistente_quota, assistente.sql). Respostas curtas (até 600 tokens)
// e histórico curto (as últimas 4 mensagens) para gastar pouco.
//
// SEGURANÇA: verificação de JWT desligada; a função confere a sessão de
// quem pergunta e que essa pessoa é da equipa (shared_state.team, pelo
// e-mail). Sócios não usam. Chave pública ou nada: recusado.
// CHAVE DA API: segredo ANTHROPIC_API_KEY nas Edge Functions, criado e
// colado pelo Elmar. Sem ela, a função responde que o assistente ainda não
// está ligado.
// REGULAMENTO INTERNO (versão 2, 02-10-2026): o resumo por secção (RI-n.m)
// vem da tabela conhecimento (só o servidor lê) e entra nas regras; o
// assistente responde a perguntas de faltas, férias, licenças, disciplina e
// conduta citando a referência. O repositório é público: o texto nunca está
// neste ficheiro.
// DADOS: as perguntas saem do servidor para a Anthropic. O Workspace avisa
// para não escrever nomes de doentes nem dados de facturação (regra 4).

import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};
const responder = (corpo: unknown, estado = 200) =>
  new Response(JSON.stringify(corpo), { status: estado, headers: { ...cors, "Content-Type": "application/json" } });

const PREFIXO_DE_CHAVE = /^(sb_secret_|sb_publishable_|eyJ)/;
const valoresDe = (nome: string): string[] => {
  const cru = (Deno.env.get(nome) || "").trim();
  if (!cru) return [];
  if (!cru.startsWith("{") && !cru.startsWith("[")) return PREFIXO_DE_CHAVE.test(cru) ? [cru] : [];
  const recolher = (v: unknown): string[] =>
    typeof v === "string" ? [v] : Array.isArray(v) ? v.flatMap(recolher)
      : v && typeof v === "object" ? [...Object.keys(v as object), ...Object.values(v as object)].flatMap(recolher) : [];
  try { return recolher(JSON.parse(cru)).filter((s) => PREFIXO_DE_CHAVE.test(s)); } catch { return []; }
};
const chaveServidor = () => [...valoresDe("SUPABASE_SECRET_KEYS"), ...valoresDe("SUPABASE_SECRET_KEY"), ...valoresDe("SUPABASE_SERVICE_ROLE_KEY")][0] || "";
const chavesPublicas = () => [...valoresDe("SUPABASE_PUBLISHABLE_KEYS"), ...valoresDe("SUPABASE_PUBLISHABLE_KEY"), ...valoresDe("SUPABASE_ANON_KEY")];

const MODELO = "claude-haiku-4-5";
const GUIA = "## Início\nO resumo do seu dia: o que precisa de atenção agora e os atalhos para o trabalho de todos os dias.\n- Veja o que falta: documentos por ler, lembretes das marcações e escalas por publicar aparecem no topo.\n- Saiba quem está de serviço hoje, pelas escalas publicadas de cada área.\n- Use os atalhos: publicar aviso, abrir o Chat, novo evento e nova tarefa.\n- Acompanhe a rotina da semana e as tarefas da equipa.\n- Médicos: o atalho «O meu mês» abre a sua actividade.\nQuem vê: Toda a equipa. Cada pessoa vê os cartões que lhe dizem respeito.\nDica: Comece o dia aqui. Um cartão com borda vermelha pede uma acção sua.\n\n## Chat\nAs conversas da clínica num só sítio: canais por área, mensagens directas e grupos.\n- Escreva nos canais da sua área, em #geral e em #avisos.\n- Carregue numa pessoa para lhe mandar uma mensagem directa, ou use «Responder em privado».\n- Envie fotografias, PDF e notas de voz; as fotografias são reduzidas e abrem depressa.\n- Faça chamadas de voz e de vídeo e chame alguém com @Nome.\n- Corrija uma mensagem sua depois de enviada.\nQuem vê: Toda a equipa. Os canais de área só aparecem a quem é dessa área.\nDica: No telemóvel, o Enter muda de linha; envie com o botão. Sem resposta em 5 min, a pessoa recebe e-mail.\n\n## Feed\nO mural da clínica: novidades, reconhecimentos e momentos da equipa.\n- Publique texto, fotografias, vídeos e ficheiros.\n- Faça um comunicado e fixe-o no topo do mural.\n- Reconheça um colega pelo bom trabalho.\n- Crie enquetes e eventos e veja os aniversários da semana.\n- Comente as publicações; o aviso abre a publicação certa.\nQuem vê: Toda a equipa.\nDica: Normas e regras oficiais vão para Documentos, onde a leitura fica confirmada.\n\n## Drive\nOs ficheiros de trabalho da equipa e os seus ficheiros pessoais.\n- Carregue ficheiros até 25 MB para a pasta da equipa ou para a sua pasta pessoal.\n- Procure e ordene por nome, data ou tamanho.\n- Abra PDF, Word (.docx) e imagens dentro do Workspace, sem descarregar.\n- Apague o que carregou; a Direcção e a Coordenação apagam qualquer ficheiro.\nQuem vê: Toda a equipa. A pasta pessoal só a vê o dono.\nDica: Ficheiros mandados numa conversa ficam nessa conversa, e não no Drive de todos.\n\n## Calendário\nA rotina semanal da clínica e os eventos com data marcada.\n- Crie um evento semanal: repete-se todas as semanas nesse dia.\n- Ou marque-o numa data concreta, só para esse dia.\n- Veja por Dia, Semana, Mês ou Ano.\n- Use as categorias: Consulta, Formação, Pessoal, Revisão e Urgente.\nQuem vê: Toda a equipa.\nDica: Os eventos do dia seguem no e-mail do resumo matinal, às 06h30.\n\n## Tarefas\nO quadro do trabalho da equipa e a sua lista privada.\n- Crie tarefas com início e fim; as duas datas são obrigatórias.\n- Mova-as no quadro: A fazer, Em progresso, Em revisão e Concluído.\n- Partilhe uma tarefa privada com um colega.\n- Direcção e Coordenação delegam: criam tarefas na lista de outra pessoa.\nQuem vê: Toda a equipa. As tarefas privadas só as vê o dono e quem as partilha.\nDica: Às 07h30 cada pessoa recebe no e-mail as suas tarefas do dia.\n\n## Escalas\nAs escalas de serviço de cada área, mês a mês.\n- Monte o mês: turnos, horas e quem trabalha em cada dia.\n- Veja os avisos: turno sem ninguém, a mesma pessoa em dois turnos, horas por pessoa.\n- Publique e peça o visto da Direcção Clínica: só com o visto a escala entra em vigor e segue por e-mail.\n- Imprima a escala para afixar.\nQuem vê: Cada área vê a sua. Fazem-na o chefe da área, a Direcção Clínica e a Direcção e Coordenação.\nDica: De 20 a 29 de cada mês, o chefe recebe um aviso diário até publicar a escala do mês seguinte.\n\n## Transporte\nO registo da viatura: rotas, viagens, combustível e manutenção.\n- Faça a rota das 22:30: quem sai vem das escalas; marque «Deixado» ou «Não foi».\n- Registe viagens de dia (amostras, compras) e a chegada a casa.\n- Lance abastecimentos e manutenção, com fotografia do recibo ou do orçamento.\n- Registe viagens de outros dias com a data certa.\n- Veja o histórico e as contas: km, consumo e custo por km.\nQuem vê: O motorista e a Direcção e Coordenação.\nDica: Cada registo aparece no canal #transporte. À segunda às 07h45 sai o relatório da semana.\n\n## CRM\nO seguimento dos pedidos e dos utentes da clínica.\n- Acompanhe os pedidos do WhatsApp: o que pediram e se foram facturados.\n- Recupere utentes a partir de um ficheiro CSV do MetaGest.\n- Abra a ficha do paciente com marcações e histórico.\n- Veja os resultados do seguimento.\nQuem vê: Direcção, Coordenação, Recepção e Comercial.\nDica: Os dados dos utentes ficam no servidor da clínica e nunca saem dele.\n\n## Marcações\nA agenda de consultas e exames da clínica.\n- Crie marcações ligadas à ficha do paciente.\n- Mude o estado: Agendada, Confirmada, Compareceu, Faltou, Cancelou, Remarcado.\n- Siga os lembretes: 1 hora antes, confirme; 30 minutos depois, ligue a quem faltou.\n- Importe e exporte a planilha em CSV.\nQuem vê: Recepção, Direcção Clínica e Direcção e Coordenação. Só a gestão apaga.\nDica: O paciente recebe lembrete na véspera às 10h00. «Compareceu» entra sozinho pelo MetaGest.\n\n## Painel\nOs números da facturação da clínica, por período.\n- Veja a facturação de hoje, da semana, do mês ou do ano.\n- Compare períodos e acompanhe a evolução.\n- Veja por médico e por seguradora.\n- Os valores de hoje actualizam-se a cada 5 minutos.\nQuem vê: Director Geral, Financeiro e sócios.\nDica: As notas de crédito já estão descontadas em todos os valores.\n\n## Relatórios\nO relatório diário de cada área, em poucos minutos.\n- Escolha a área e o turno e responda às perguntas.\n- Registe ocorrências, faltas de material e equipamentos avariados.\n- Veja os relatórios recebidos de cada dia.\nQuem vê: Todos preenchem. Lêem: Direcção e Coordenação (tudo) e Direcção Clínica (áreas médicas).\nDica: Nunca escreva nomes de utentes no relatório. Cada relatório segue por e-mail para a Arlete.\n\n## A minha actividade\nPara cada médico, a sua própria produção na clínica.\n- Veja doentes, consultas, exames e facturas do período.\n- Veja os actos por grupo (consultas, laboratório, enfermagem...).\n- Acompanhe os últimos 12 meses num gráfico.\nQuem vê: Cada médico vê só os seus números.\nDica: Os valores já descontam as notas de crédito, como no relatório mensal.\n\n## Documentos\nOs documentos oficiais da clínica, com leitura confirmada.\n- Leia o regulamento interno, notas internas, comunicados, procedimentos, protocolos e formulários.\n- Confirme a leitura com «Li e tomei conhecimento».\n- Procure pelo título ou pelo número.\n- Quem publica vê quem leu e pode pôr uma nova versão.\nQuem vê: Toda a equipa lê. Publicam Direcção, Coordenação, Direcção Clínica e Administração.\nDica: Um documento novo chega no mesmo instante, por e-mail e no sino.\n\n## Admin\nA gestão das pessoas e dos acessos ao Workspace.\n- Crie contas e defina área, cargo, camada e superior de cada pessoa.\n- Ajuste as permissões de cada camada.\n- Consulte o registo e o estado do sistema.\n- Use «Ver como» para ver o ecrã de outra pessoa, só em leitura.\nQuem vê: Direcção e Coordenação.\nDica: A área de cada pessoa decide os canais e as escalas que ela vê.";
const REGRAS = `És o assistente do Workspace Barispol, a intranet da equipa do Centro Médico Barispol (pessoa jurídica: Clínica Barispol, Lda.), em Luanda.
Ajudas a equipa a usar o Workspace e a redigir mensagens, comunicados e e-mails curtos.
Escreve sempre em português de Portugal, sem o Acordo Ortográfico de 1990 (ex.: «acção», «direcção», «actividade»), sem gerúndio, com frases curtas e verbos concretos.
Responde em poucas linhas. Usa listas só quando ajudam.
Sobre o Workspace, baseia-te só no guia abaixo. Se o guia não responde, diz que não sabes e sugere perguntar à Direcção ou à Coordenação. Não inventes menus nem funções.
Sobre regras de trabalho (horário, faltas, férias, licenças, doença, disciplina, conduta, confidencialidade, telefones, informática, aparência, benefícios), responde com base no regulamento interno abaixo e cita a referência (ex.: «RI-6.2»). Se o resumo não chegar, diz que convém ver o documento completo em Documentos ou falar com o Capital Humano.
Não dês diagnósticos nem conselhos médicos a doentes. Não peças nem repitas nomes de doentes, contactos de doentes, dados de facturação nem palavras-passe. Se a pessoa os escrever, lembra-lhe que não deve.

# Guia dos menus do Workspace
`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return responder({ erro: "Método não permitido." }, 405);
  const testemunho = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!testemunho || chavesPublicas().includes(testemunho)) return responder({ erro: "Entre no Workspace para usar o assistente." }, 401);

  const URL_SB = Deno.env.get("SUPABASE_URL") || "";
  const SERVICO = chaveServidor();
  if (!URL_SB || !SERVICO) return responder({ erro: "A função não tem as chaves do projecto." }, 500);
  const admin = createClient(URL_SB, SERVICO, { auth: { persistSession: false } });
  const { data: sessao, error: semSessao } = await admin.auth.getUser(testemunho);
  if (semSessao || !sessao || !sessao.user) return responder({ erro: "Sessão inválida ou expirada. Volte a entrar." }, 401);
  const email = String(sessao.user.email || "").trim().toLowerCase();
  const { data: estado } = await admin.from("shared_state").select("team").eq("id", 1).single();
  const equipa: any[] = estado && Array.isArray(estado.team) ? estado.team : [];
  const pessoa = equipa.find((u: any) => u && String(u.email || "").trim().toLowerCase() === email);
  if (!pessoa) return responder({ erro: "O assistente é só para a equipa." }, 403);
  if (/s[oó]cio/i.test(String(pessoa.accessLevel || ""))) return responder({ erro: "O assistente não está disponível para esta camada." }, 403);

  const { data: quota } = await admin.rpc("bsp_assistente_quota", { p_user: pessoa.id });
  if (quota && quota.restantes <= 0) {
    return responder({ erro: "Chegou ao limite de " + quota.limite + " perguntas em " + quota.horas + " horas.", quota }, 429);
  }

  let pedido: any;
  try { pedido = await req.json(); } catch { return responder({ erro: "Pedido inválido." }, 400); }
  const pergunta = String(pedido && pedido.pergunta || "").trim().slice(0, 1500);
  if (!pergunta) return responder({ erro: "Escreva a pergunta." }, 400);
  const historico = (Array.isArray(pedido.historico) ? pedido.historico : []).slice(-4)
    .filter((m: any) => m && (m.role === "user" || m.role === "assistant") && typeof m.text === "string" && m.text.trim())
    .map((m: any) => ({ role: m.role, content: String(m.text).slice(0, 1500) }));
  while (historico.length && historico[0].role !== "user") historico.shift();

  const chave = (Deno.env.get("ANTHROPIC_API_KEY") || "").trim();
  if (!chave) return responder({ erro: "O assistente ainda não está ligado: falta a chave da API no servidor." }, 503);

  /* Regulamento interno e outros textos de referência (tabela conhecimento). */
  const { data: saber } = await admin.from("conhecimento").select("titulo, texto").order("chave");
  const referencia = ((saber || []) as any[]).map((k) => "\n\n# " + k.titulo + "\n" + k.texto).join("");
  const cliente = new Anthropic({ apiKey: chave });
  try {
    const r = await cliente.messages.create({
      model: MODELO,
      max_tokens: 600,
      system: [{ type: "text", text: REGRAS + GUIA + referencia, cache_control: { type: "ephemeral" } }],
      messages: [
        ...historico,
        { role: "user", content: "Quem pergunta: " + String(pessoa.name || "") + " (" + String(pessoa.role || "") + ", " + String(pessoa.dept || "") + ").\n\n" + pergunta },
      ],
    });
    const texto = r.content.filter((b: any) => b.type === "text").map((b: any) => b.text).join("\n").trim();
    const u: any = r.usage || {};
    await admin.from("assistente_uso").insert({
      user_id: pessoa.id,
      tokens_entrada: (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0),
      tokens_saida: u.output_tokens || 0,
    });
    const { data: depois } = await admin.rpc("bsp_assistente_quota", { p_user: pessoa.id });
    return responder({ resposta: texto || "Não tenho resposta para isso.", quota: depois, cortada: r.stop_reason === "max_tokens" });
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) return responder({ erro: "O assistente está ocupado. Tente daqui a um minuto." }, 429);
    if (e instanceof Anthropic.AuthenticationError) return responder({ erro: "A chave da API no servidor não é válida." }, 503);
    if (e instanceof Anthropic.APIError) return responder({ erro: "O serviço de IA não respondeu (" + e.status + ")." }, 502);
    return responder({ erro: "Não foi possível falar com o serviço de IA." }, 502);
  }
});
