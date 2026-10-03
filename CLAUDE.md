# Barispol2026 — contexto para o assistente

Este ficheiro é lido automaticamente pelo Claude Code em cada tarefa. Tem as
regras aprovadas pelo Elmar Bravo e o estado do projecto. O passo a passo do
servidor está em `O-QUE-FALTA.md`, e esse ficheiro prevalece. O texto
completo de 24 a 28-09-2026 está em `historico-2026-09.md` (02-10-2026).

## Regras (aprovadas pelo Elmar, não negociáveis)

1. Nunca escrever, pedir, mostrar nem guardar no repositório nenhuma chave
   que comece por `sb_secret_` nem por `eyJ`, nem palavras-passe. A chave
   secreta é criada e colada pelo Elmar, e mais ninguém. A chave
   `sb_publishable_` é pública e pode aparecer.
2. Nunca carregar em «Disable JWT-based API keys» (passo 0.6) sem
   autorização expressa do Elmar na própria conversa.
3. Nenhum e-mail sai para terceiros sem aprovação prévia do Elmar.
4. Dados privados da clínica (nomes de pacientes, facturação) não saem do
   servidor e não entram no repositório.
5. Língua: português de Portugal, sem o Acordo Ortográfico de 1990, sem
   gerúndio. Frases curtas, verbos concretos.
6. A pessoa jurídica é sempre «Clínica Barispol, Lda.», NIF 5000999687.
   «Centro Médico Barispol» é só a marca.
7. Marca: Titillium Web (com Segoe UI/Arial de recurso). Todas as páginas
   do site usam "Dax","Titillium Web","Segoe UI",Arial (02-10-2026). Cores:
   azul-marinho #292F58 e #273069, azul #2291CE. Nos e-mails, a fonte é
   Dax (pedido do Elmar, 24-09-2026), com Titillium Web, Segoe UI e Arial
   de recurso, e o logotipo `assets/logo-barispol.png` no topo.
8. Antes de cada alteração, dizer o que se vai fazer. Depois, dizer o que
   se confirmou. Se o ecrã ou o código não corresponder ao descrito, parar
   e descrever.
9. Sempre que se mexe no código, actualizar `O-QUE-FALTA.md` na mesma
   alteração.

## Regulamento interno (02-10-2026)

- O repositório é público: o regulamento e as notas internas nunca entram
  nele (RI-4.8, foro interno). Ficam só no servidor.
- Resumo por secção (referências **RI-n.m**, com os prazos, números e quem
  decide): `select texto from public.conhecimento where chave =
  'regulamento-interno'`. Consultá-lo sempre que um pedido toque em
  horários, faltas, férias, licenças, disciplina, confidencialidade,
  telefones, informática, aparência, benefícios ou conduta, e citar a
  referência RI. Não é preciso ler o documento inteiro. O assistente do
  Workspace lê a mesma tabela.
- Texto integral: `documentos_texto` (documento 1), preenchido pela Edge
  Function `documento-texto`. Em dúvida, prevalece o original.
- Qualquer função nova do Workspace sobre pessoas (ausências, férias,
  faltas, escalas) segue os prazos do resumo. Ler a tabela antes de
  escrever o código; os números não se copiam para o repositório.

## O que é

- `barispol.com` é servido pelo GitHub Pages a partir de `main` (ficheiro
  `CNAME`). Um commit em `main` publica o site.
- `workspace.html` é a intranet da equipa: mural, chat, tarefas,
  calendário, drive, directório e administração. Uma só página em React
  (versão UMD, `React.createElement`, sem compilação), com cerca de 626 KB.
- `servidor.js` liga ao Supabase: projecto **Barispol**
  `gnqleaxrtuerlcrriqqs` (eu-west-3), na organização da conta
  elmar.bravo@barispol.com, chave publicável `sb_publishable_z60zTAY…`.
  Desde 24-09-2026. O projecto antigo `ferqkmfntcockmhviscf` já não se
  usa: o `servidor.js` apaga dos aparelhos a ligação antiga guardada.
- `funcoes/` guarda o código das Edge Functions:
  - `criar-utilizador`: verificação de JWT desligada, tem autenticação
    própria.
  - `resumo-matinal`: verificação de JWT desligada. Devolve
    `fonte_chave` e filtra os eventos pelo dia da semana. A versão 5
    (24-09-2026) aceita o código do agendamento no cabeçalho
    `x-bsp-agendamento`, guardado no Vault como `bsp_resumo_agendamento`
    e conferido por `bsp_resumo_codigo_confere` (ver
    `agendar-resumo-sem-chave.sql`). Nunca mostrar esse código.
  - `bright-worker` (envia pela Resend, remetente geral@barispol.com, que
    não se muda): versão 5 (30-09-2026, aceita `reply_to` e os cabeçalhos
    de confirmação de leitura só do servidor),
    verificação de JWT desligada e
    autenticação própria em `funcoes/bright-worker/index.ts`. Chave do
    servidor ou sessão de gestor: qualquer destinatário. Sessão de outro
    colaborador: só endereços de `shared_state.team` ou
    empresa@barispol.com. Chave pública: recusada.
  - `assistente` (01-10-2026): IA (Claude Haiku 4.5) com limite de 10
    perguntas a cada 5 horas por pessoa (`assistente.sql`); verificação de
    JWT desligada, autenticação própria; chave `ANTHROPIC_API_KEY` nos
    segredos das funções (colada pelo Elmar). Painel `AssistentePainel`.
  - Orçamento de e-mails (02-10-2026, `emails-pausa.sql`): plano gratuito da
    Resend (100 por dia). A `bright-worker` versão 7 consulta
    `bsp_emails_pausa_ate()` (pausa marcada ou tecto de 95 por dia) e
    regista cada envio em `emails_registo`. Nada novo manda um e-mail por
    pessoa: documentos e avisos gerais vão por `novidades` (um e-mail às
    05h00), sino e telemóvel. A `documento-aviso` já não se chama; o
    colectivo das 12h00 está desligado. O WhatsApp está só no e-mail das
    08h00 (`wa_resumo_8h`), nunca no relatório da Recepção.
  - `contacto-site` (caixa de contacto do site): versão 5 (26-09-2026),
    para rececao@barispol.com com geral@barispol.com em cópia; aspecto
    igual ao site. Verificação de JWT desligada, só aceita barispol.com.
- As funções lêem as chaves de `SUPABASE_SECRET_KEYS` e
  `SUPABASE_PUBLISHABLE_KEYS` (plural, dicionários JSON). Os nomes antigos
  `SUPABASE_SERVICE_ROLE_KEY` e `SUPABASE_ANON_KEY` só servem de recurso.

## Pormenores do código que já causaram erros

- Linhas de controlo na tabela `messages`, com o separador `​`:
  - `​l​<id>` é um recibo de leitura
  - `​e​<id>​<texto>` é uma edição
  - `​r…` e `​p…` são reacções
  
  Nunca se mostram nem contam como por ler: usar `bspLinhaDeControlo()`.
  A excepção é `​f…`, que é um anexo e portanto uma mensagem real.
- Datas exactas em todo o lado («24 set 2026, 13:41»), nunca «agora» nem
  «há x min» (pedido do Elmar, 24-09-2026). `bspDataExacta`, `bspQuando`,
  `bspQuandoChat(iso, alternativa)` e `fmtTs` dão todas esse formato.
  Tudo o que se cria guarda o instante (`iso`, `criado`, `ts` ISO).
  Mostrar sempre `bspQuandoChat(m.iso, m.ts)`, nunca `m.ts` sozinho. No
  chat há separador por dia (`bspDiaExtenso`). Meses com maiúscula.
- O contador do botão Chat vem de `bspTotalPorLer()` e `useChatPorLer()`.
- `Modal` abre por `ReactDOM.createPortal` no `body`, com zIndex 100000.
  Abaixo de 640 px ocupa o ecrã inteiro.
- Departamentos em `DEPARTMENTS` (inclui `radiologia`, `laboratorio` e
  `servicos-gerais`). O departamento
  actual de uma pessoa nunca desaparece do selector.
- Aspecto dos e-mails (26-09-2026): o do site (branco, linhas finas,
  cantos rectos, etiqueta azul, rodapé marinho). Está em três sítios que
  mudam juntos: `bspEmailWrap` (workspace.html), `envelope`
  (resumo-matinal) e `bsp_envelope` (base de dados).
- O envio de e-mail pela aplicação usa o token da sessão
  (`bspTestemunho`). O cartão é `bspEmailWrap`, igual ao `envelope` da
  `resumo-matinal`. Texto escrito por alguém passa por `bspEmailTexto`
  (sem HTML, com mudanças de linha, sem cortes).
- A `resumo-matinal` tem três tipos (campo `tipo` do corpo): resumo
  (06h30, seg–sáb; desde 02-10-2026 sai pela Edge Function `resumo-pessoal`,
  com as tarefas privadas, e o cron `bsp-resumo-matinal` chama-a), `lembrete` (07h30, todos os dias, um por pessoa pelo
  nome) e `coletivo` (12h00, seg/qua/sex, «Olá, equipa»). Registos por
  dia: `resumos_enviados`, `lembretes_enviados`, `coletivos_enviados`.
  Desde 30-09-2026 (versão 10, decisão do Elmar) vão para toda a equipa
  com e-mail válido, também os endereços pessoais dos médicos; fica de
  fora quem tem `semEmails: true` na equipa (a conta de teste «Beb»).
  Mesma regra na base de dados: `bsp_recebe_emails` (`emails-toda-equipa.sql`).
- Tipo `mensagens` da `resumo-matinal` (versão 8, a cada minuto): e-mail
  de mensagem directa só após 5 min sem resposta/leitura e com a pessoa
  offline (tabela `presenca`, sinal a cada minuto). Registo em
  `avisos_mensagens`. O Workspace já não envia esse e-mail directamente.
- Som das notificações: um só `AudioContext` (`bspAudio`), desbloqueado
  no primeiro toque (`bspDesbloquearSom`). Nunca criar um por aviso.
- Sessão (02-10-2026): só no `sessionStorage` (`bspGetClient` e o cliente da
  sincronização, os dois com o mesmo armazém; com armazéns diferentes o
  Workspace parava de sincronizar); nunca voltar
  a guardar a sessão no `localStorage` (contas abriam sozinhas em
  computadores partilhados).
- Quem está online (02-10-2026): sempre `bspEstadoDe(user)` /
  `bspEstaOnline(id)` (tempo real ou sinal na `presenca` há menos de 3
  min), nunca `user.status` sozinho, que é o que ficou gravado na ficha.
- Recibos de leitura (02-10-2026): `RecibosMensagem` em cada mensagem
  própria (gestão: em todas as dos canais, `bspVeRecibosDeTodos`); quem
  deve ler vem de `bspDestinatariosConversa`. Só se marca como lido com o
  Workspace à vista (`marcarLido` nunca com `document.hidden`).
- Abrir uma conversa directa de qualquer ecrã: `bspConversaCom(id)`.
- Grupos do Chat (30-09-2026): editam-se com `NovoGrupoModal` (`inicial`) e
  `actions.editarCanal`; o servidor segue o id e os membros, não o nome. Um
  grupo com papel no sistema leva `funcao` (o do Transporte:
  `funcao: 'transporte'`); nunca procurar um grupo só pelo nome.
- Enter no Chat (30-09-2026): usar `bspEnterEnvia(e)`. Em ecrãs tácteis o
  Enter muda de linha e envia-se com o botão; no computador, Enter envia.
- Chamadas: `bspToqueChamada('recebida' | 'a-chamar')`, sempre com som,
  mesmo com o som das notificações desligado.
- Notificações de mensagens lidas saem com `bspSemNotifsLidas(s)`. Esta
  função só corre quando a leitura muda. Comentários do Feed (conversa
  `post-<id>`) geram notificações com `post`: abrem a publicação, nunca
  o Chat.
- Imagens abrem em `bspVerImagem(url, nome)` (o `VisorImagem`), nunca
  com `window.open`: na app, isso prende o Workspace.
  PDF abrem em `bspVerPdf(url, nome)` (`LeitorPdf`, PDF.js em
  `vendor/pdfjs`, 30-09-2026). Word .docx em `bspVerWord(url, nome)`
  (`LeitorWord`, `vendor/docx`, 01-10-2026); o .doc antigo é recusado nas
  conversas. PowerPoint .pptx em `bspVerPptx(url, nome)` (`LeitorPptx`,
  leitor próprio sobre o JSZip, 02-10-2026). `bspAbrirFicheiro` escolhe sozinho.
- Logotipo (02-10-2026): `BarispolLogo` com `sm` 38, `md` 64, `lg` 104 px;
  no site, 72 px no cabeçalho (60 no telemóvel). Nunca voltar a tamanhos
  menores (pedido do Elmar). Círculo branco sempre com 13% de margem
  (`--bsp-logo-pad`) e nunca `border-radius` na própria imagem: cortava as letras.
- Sem zoom no telemóvel (30-09-2026): `viewport` com `maximum-scale=1,
  user-scalable=no`, `gesturestart` bloqueado e caixas de escrita com 16 px
  (abaixo disso o iPhone amplia). Nada pode passar da largura do ecrã.
- No telemóvel, `main > div` tem altura automática. O Chat é a excepção
  (classe `bsp-chat-ecra`) e abre na lista de conversas.
- Respostas no Chat (30-09-2026): sem tópicos. «Responder» cita na própria
  conversa com a primeira linha «> Nome: excerto» (`bspCitacao`); avisos e
  pré-visualizações usam `bspTextoResumo`. Nunca voltar a pôr comentários
  numa conversa à parte (`th~…`).
- Menções no chat: lista em `ChatScreen` (`detectarMencao`,
  `candidatosMencao`, `escolherMencao`); escreve «@Nome Apelido». O
  `notifMsg` marca como `mention` quem aparece assim no texto.
- A app (Capacitor 8, `app/`) abre `https://barispol.com/workspace.html`
  (`server.url`): actualiza-se com o site. Sem internet mostra
  `sem-ligacao.html`. O APK sai em Actions → «App Android» → Artifacts.
- Relatórios por área: ecrã `relatorios` (`RelatoriosScreen`), perguntas em
  `BSP_RELATORIOS`, respostas na tabela `relatorios_area`
  (`relatorios-area.sql`). Sem nomes de utentes. Lêem: Direcção e
  Coordenação tudo; Direcção Clínica (Osvaldo Pacheco, u14,
  `BSP_RELATORIOS_DIRECCAO_CLINICA` / `bsp_le_areas_medicas()`) as áreas
  médicas; a Arlete (u2) recebe cada um por e-mail.
- Apresentação do Workspace (25-09-2026): cores oficiais nas variáveis
  (`--navy` #292F58, `--accent` #2291CE), letra Dax, sem gradientes nem
  animação de ecrã, e botão principal marinho (#273069). Cores novas vão
  para as variáveis, e nunca escritas à mão no código.
  Modo escuro (25-09-2026): `html[data-tema="escuro"]` troca as
  variáveis; por isso nenhuma cor de fundo ou de texto se escreve à mão
  (`--navy-texto` para texto marinho, `--texto-sobre-pastel` sobre
  fundos pastel). Tema em `useTema()` / `bsp-tema`; no site, `bsp-site-tema`.
- Listas por ordem alfabética (25-09-2026): `USERS`, `state.team`,
  `DEPARTMENTS`, `CHANNELS` e `BSP_RELATORIOS` são ordenados na origem com
  `bspPorNome` / `bspCompararTexto`. Nunca usar `USERS[0]` como «o
  utilizador principal». Os estados do CRM mantêm a ordem do processo
  (o primeiro é o valor por omissão); só os menus os mostram por ordem. Nas listas com
  «Ordenar:» usar `bspOrdenar` + `useOrdem` + `OrdemSelect` (25-09-2026).
- Lista embutida `USERS` (29-09-2026): departamento e camada iguais aos
  do servidor. É o recurso quando o `shared_state` não chega; sem
  departamento a pessoa perde o canal da sua área.
- Canais de área pela função (25-09-2026): o departamento da pessoa
  decide (`bspVeCanal` + `bspAreaChave`, e no servidor `bsp_ve_conversa`
  com `bsp_area_chave`/`bsp_minha_area`). Direcção e Coordenação vêem
  todos; a Direcção Clínica (u14) vê os da saúde. Mudar os dois lados
  juntos. Campo `superior` na equipa (Emmanuel → Arlete, u2).
- Calendário (opção C, aprovada): os eventos são rotina semanal. Cada
  evento tem um dia da semana e repete-se todas as semanas nesse dia.
  Desde 25-09-2026 um evento também pode ser «Numa data» (campo `data`,
  AAAA-MM-DD): usar `bspEventoNoDia()` para saber se aparece num dia, e
  a `resumo-matinal` só o anuncia nesse dia.
  Vistas Dia, Semana, Mês e Ano (25-09-2026): usar `bspEventoNaData(e,
  iso, todayIdx)` para uma data concreta.
  Agenda privada (01-10-2026, `agenda-privada.sql`): eventos novos na tabela
  `agenda_eventos` (privado/público, convidados, respostas), com as regras das
  tarefas privadas; `useAgendaEventos`, `bspAgendaParaEvento` (mesma forma dos
  eventos antigos, com `origem: 'agenda'`), `bspEventoNaAgenda`,
  `bspPodeMudarEvento`, `EventoDetalhe`, `useProximosEventos`. Os eventos
  antigos (`state.todayEvents`) têm `origem: 'equipa'`. Qualquer consumidor
  novo da agenda junta os dois e filtra com `bspEventoNaAgenda`.
  Mensais: `dia_mes` (início em `data`), no ecrã `e.diaMes`/`e.desde`.
  Lembretes (02-10-2026, `agenda-lembretes.sql`): `lembretes` do evento e
  `lembretes_pessoa` por pessoa (`bsp_evento_lembretes`, `BSP_LEMBRETES`,
  `bspLembretesDevidos`); e-mail pela Edge Function `agenda-avisos`
  (lembretes de 5 em 5 min e convite no instante, gatilho
  `bsp_agenda_convite_aviso`).
  Convite de calendário (02-10-2026, `agenda-convites-email.sql`): criar,
  mudar e apagar um evento manda `convite.ics` por e-mail ao dono e aos
  convidados (UID `agenda-<id>@barispol.com`, `ics_seq`). Para gravar sem
  e-mail: `set_config('bsp.sem_convite', '1', true)`.
- Tarefas privadas partilhadas: coluna `partilhada_com` em
  `tarefas_pessoais` (`tarefas-partilhadas.sql`). Editar uma tarefa
  privada vai por `pess.actualizar`, nunca por `actions.updateTask`. A edição
  também muda `user_id` e `partilhada_com` (todos os da tarefa; só quem
  delega muda o dono).
- Tarefas com descrição e comentários (01-10-2026, `tarefas-comentarios.sql`):
  `desc` (equipa) / `descricao` (privadas); janela `TarefaDetalhe`;
  comentários na conversa `tarefa-<id>` (privadas: `tarefa-p<id>`, só quem
  vê a tarefa, em `bsp_ve_conversa`); «Levar para o Chat» termina com
  `[tarefa:<id>]` (`bspTarefaDaMensagem`, `bspAbrirTarefa`).
- Datas das tarefas (28-09-2026): início e fim obrigatórios
  (`bspTarefaErroDatas` no `TaskComposer`; gatilho `bsp_tarefa_datas`,
  `tarefas-datas.sql`). Equipa: `start`/`due`; privadas: `inicio`/`prazo`.
- Marcações (26-09-2026): tabela `marcacoes` no Supabase
  (`marcacoes.sql`), ecrã `marcacoes` (`MarcacoesScreen`). Acesso igual
  nos dois lados: `bspVeMarcacoes` (Recepção, u14, gestão) e
  `bsp_ve_marcacoes()`; só a gestão apaga. Estados da planilha:
  `Agendada` (omissão), `Confirmada`, Compareceu, Faltou, Cancelou,
  Remarcado; colunas `entidade`, `seguradora`, `rececionista`. Agosto e
  Setembro já importados (26-09-2026). Ligadas à ficha (27-09-2026,
  `marcacoes-ficha.sql`): `email`, `paciente_id`, `tel9`; `crm_ficha`
  devolve `marcacoes`; `bsp_marc_sugerir`; «Compareceu» automático pelo
  MetaGest (`bsp_marcacoes_comparecer`, cron `bsp-marcacoes-metagest`).
  Lembretes para a Recepção (29-09-2026): 1 h antes e 30 min depois de
  cada marcação de hoje em aberto (`bspMarcLembretes`, `MarcLembretes`,
  sino com `lembrete: true`; no Início, `MarcLembretesInicio`, 30-09-2026).
  Cores de aviso nas variáveis `--perigo` e `--sucesso`. A planilha entra e sai por CSV
  (`bspLerCsvLinhas`, `bspMarcDoCsv`, `bspMarcCsv`; o `bspLerCsv` é do CRM e
  devolve `{cabecalho, linhas}`: nunca repetir o nome). Nomes de doentes nunca no
  repositório. Lembrete ao paciente (28-09-2026, `marcacoes-lembrete.sql`):
  na véspera às 10h00 (`bsp-marcacoes-lembrete`, tipo `marcacoes` da
  `resumo-matinal`), com rececao@barispol.com em cópia e link do GPS;
  nunca no momento da marcação.
- Escalas de serviço (28-09-2026, `escalas.sql`): tabela `escalas` (área +
  mês; `turnos` com `semana` 0 = Domingo; `dias[iso][turno]` = ids, `_n` =
  nota). Acesso igual nos dois lados: `bspEditaEscala`/`bsp_edita_escala`
  e `bspVeEscala`/`bsp_ve_escala`. Ecrã `EscalasScreen`; papel
  `bspEscalaHtml`; e-mail `bspEscalaEmailCorpo` com `bspEmailWrap(..., true)`;
  Início `EscalaHojeCartao`. Imprimir só por `bspImprimirHtml`.
  Alerta aos chefes (30-09-2026, `escalas-alerta.sql`): dias 20 a 29,
  novidade por área sem a escala do mês seguinte publicada
  (`bsp_escalas_responsaveis`, `bsp_escalas_alertar`, cron
  `bsp-escalas-alerta`); no Início, `EscalasPorPublicarCartao`.
  Visto da Direcção Clínica (30-09-2026, `escalas-visto.sql`): u14 edita
  todas as áreas e dá o visto (`bsp_escala_dar_visto`); sem visto a escala
  não está em vigor (`bsp_escala_em_vigor` / `bspEscalaEmVigor`). Qualquer
  consumidor novo das escalas usa só as que estão em vigor. Mudar turnos ou
  dias apaga o visto, excepto quando quem muda é a gestão ou a Direcção
  Clínica (`escalas-visto-gestao.sql`, `bspMantemVistoEscala`, 02-10-2026).
  Nas cargas de PowerPoint, «Ludmila» (Da Silva) e «Luidmila» (Chitata, u6)
  são pessoas diferentes.
  A Administração não tem escala (Elmar, 02-10-2026): fora do ecrã e dos
  avisos.
  Trocas de turno (01-10-2026, `trocas-turno.sql`): pedido → colega aceita →
  Direcção Clínica aprova (`bsp_troca_decidir` aplica com `bsp.visto = '1'`,
  o visto mantém-se). Painel `TrocasTurnoPainel` em Escalas.
- Transporte (29-09-2026, `transporte.sql`): `transporte_viagens`,
  `transporte_abastecimentos`, `transporte_zonas`; acesso
  `bspVeTransporte`/`bsp_ve_transporte` (gestão e cargo «motorista»).
  Quem sai à noite vem de `bsp_transporte_saidas(dia)`. Bairros são dados
  pessoais: nunca no repositório. O dia de serviço é `bspDiaServico()`.
  Manutenção (30-09-2026, `transporte-manutencao.sql`):
  `transporte_manutencoes` (orçamento → aprovada → feita; só a gestão
  aprova). Relatório semanal ao motorista, segunda às 07h45, tipo
  `transporte` da `resumo-matinal` (versão 9), com a Administração em cópia
  e como `reply_to`; `{"previa": true}` mostra sem enviar.
  No Chat (01-10-2026), as mensagens do Transporte (começam por 🚗 ⛽ 📝 🔧 🏠)
  mostram-se como cartões (`bspRegistoDaMensagem`, `CartaoRegisto`): manter
  esses símbolos no início e os campos como «Nome: valor», uma linha cada.
  Viagens de outros dias (30-09-2026): «Data da viagem» no
  `TranspIniciarModal` (viagem inteira de uma vez); abastecimento com data e
  hora. Percurso «origem → destino» por `bspTranspPercurso`.
  Fotografias (02-10-2026): só 4 por dia, na primeira saída de cada turno
  (`bspTranspPrimeiraDoTurno`) e no «Cheguei a casa». Os km são sempre
  obrigatórios.
- «Ver como» (28-09-2026): `bspEmVerComo()` é só leitura. Qualquer escrita
  nova ao servidor tem de passar por `bspGetClient()` (que a bloqueia) ou
  verificar `bspEmVerComo()`; funções RPC novas que só lêem vão para
  `BSP_RPC_LEITURA`. Nunca gravar o `shared_state` nem anunciar presença
  durante a vista.
- Novidades do sistema (27-09-2026, `novidades.sql`): cada alteração que
  muda o trabalho de alguém leva um `insert into public.novidades (titulo,
  texto, grupos, destino)` com os grupos afectados (`todos`, `gestao`,
  `direccao-clinica`, uma área de `bsp_area_chave` ou um id). Sai por
  e-mail às 05h00 (`bsp-novidades`, tipo `novidades` da `resumo-matinal`)
  só quando há, e aparece no sino (tipo `sistema`).
- Painel financeiro (27-09-2026, `painel.sql`): `bsp_painel(de, ate)`,
  só `bsp_ve_painel()` = Elmar (u1), departamento Financeiro e sócios
  (decisão do Elmar; a gestão por si só não vê; ecrã: `bspVePainel`); histórico em `crm.mg_*`, hoje em `erp.sales_invoice`
  (cron `bsp-painel-hoje`, 5 em 5 min). Médicos e seguradoras vêm de
  `erp.sales_invoice` (histórico desde 2022, `metagest-historico.sql`),
  nunca de `crm.mg_consultas`, que está incompleto. Ecrã `painel` (`PainelScreen`,
  `PainelColunas`, `PainelBarras`), cores `--serie-1..4`.
- Stock (01-10-2026, `stock.sql`): saldo pelo último movimento do MetaGest
  (`erp.stock_mov`, cron `bsp-stock`); `bsp_stock()` / `bsp_stock_resumo()`;
  quem vê: `stock_responsaveis` + gestão (`bsp_ve_stock`) e, no ecrã,
  `bspVeStock` / `BSP_STOCK_RESPONSAVEIS`. Ecrã `StockScreen`, Início
  `StockAlertaCartao`.
  Validades (01-10-2026, `stock-validades.sql`): lote em `erp.stock_mov.batch_no`,
  quantidade do lote por armazém pela soma dos movimentos, `bsp_stock_lotes()`,
  estado `caducado` antes de todos. `stock.sql` corre-se antes de
  `stock-validades.sql`.
- Facturas por receber (01-10-2026, `cobrancas.sql`): acerto diário
  `erp.reconciliar_cobrancas` (a cópia `erp.sales_invoice` só relê 7 dias);
  `bsp_cobrancas()` no Painel (`PainelCobrancas`). Sem e-mail de
  cobranças (decisão do Elmar): `bsp_cobrancas_email` existe mas não se
  agenda. Utentes
  nunca com nome. Nas funções SQL do servidor, nunca a palavra `truncate`
  (a ferramenta fica à espera de confirmação).
- Funções com filtro de acesso (01-10-2026): calcular primeiro o que a
  pessoa vê (CTE com `offset 0`), nunca uma função de acesso por linha numa
  tabela grande (o Stock levava 10 s).
- Funil de vendas (01-10-2026, `crm-funil.sql`): `crm_funil(dias, origem,
  servico)` sobre `crm.caixa`; separador `CrmFunil` no CRM. Cada pedido
  conta na etapa mais avançada.
- Barra do telemóvel (01-10-2026): Início, Chat, Tarefas, Feed, Mais (a
  Agenda está em «Mais»); no Início, `FeedInicioCartao`.
- Menu «Utentes» (01-10-2026): CRM + Marcações num só item (`seguimento`,
  separadores em `CrmScreen({ inicial })`); a rota `marcacoes` abre o
  separador Marcações. Directório no menu como «Equipa».
- Avarias e património (02-10-2026, `avarias-patrimonio.sql`): `categoria`
  (`BSP_AVARIA_CATEGORIAS`), repetidos bloqueados no servidor
  (`bsp_avaria_0_repetida`), apagar só por `bsp_avaria_apagar` e só a camada
  Direcção (`bsp_e_direccao`/`bspApagaAvarias`; quem reportou cancela). O
  Emmanuel (u22) trata e conclui todas (`avarias-apagar-direccao.sql`).
- Qualidade (03-10-2026, `qualidade.sql`): `feedback_utentes` e `ocorrencias`,
  ecrã `QualidadeScreen` (`bspVeQualidade`/`bsp_ve_qualidade` = gestão + u14;
  chefe da área pela `bsp_edita_escala`). Página pública `avaliar.html` só
  por `bsp_feedback_publico` (a única função aberta a visitantes). Respostas
  do inquérito no WhatsApp por `bsp_feedback_whatsapp` (texto «De 1 a 5…
  como correu o atendimento»: não mudar sem mudar a função). Nomes de
  utentes nunca.
  Inquéritos por e-mail (03-10-2026, `feedback-email.sql`): o Zapier manda o
  e-mail diário de info@barispol.ao a `bsp_feedback_email(codigo, assunto,
  texto)`, com o código do cofre `bsp_feedback_codigo` (nunca mostrar).
  O formato das linhas («N. Nome (tel), consulta a DD-MM: nota X…») está em
  `bsp_feedback_do_texto`: se o e-mail mudar, mudar a função.
- Médicos e credenciais (03-10-2026, `medicos-credenciais.sql`): `erp.medicos`
  copiado do MetaGest todos os dias; validades em `credenciais` (gestão e
  u14 registam, cada médico lê as suas); avisos por `bsp_credenciais_alertar`
  nas novidades. Ecrã Equipa → `MedicosCredenciaisPainel`.
- Equipamentos e manutenção preventiva (03-10-2026, `manutencao-preventiva.sql`):
  `equipamentos`, `manutencoes_plano`, `manutencoes_registo`; ecrã Avarias →
  `EquipamentosPainel` (o ecrã antigo chama-se `AvariasLista`).
- Vigilância (03-10-2026, `vigilancia.sql`): `bsp_vigilancia` de 15 em 15 min,
  avisa a gestão no telemóvel; Admin → «Saúde do sistema». Uma verificação
  nova entra em `bsp_vigilancia` e em `BSP_VIGILANCIA_NOMES`.
- Registo de acessos (03-10-2026, `acessos-registo.sql`, RI-3.3):
  `bspRegistarAcesso(ecra, detalhe)`; um ecrã novo com dados sensíveis entra
  em `BSP_ECRAS_SENSIVEIS` e passa a ser registado. Detalhe nunca com nomes.
- Integração (03-10-2026, `integracao.sql`, RI-2.2): modelo de passos só no
  servidor (`integracao_modelo`); Equipa → `IntegracaoPainel`. Documentos com
  `revisao_ate` (`documentos-revisao.sql`).
- Registos da equipa (01-10-2026, `equipa-registos.sql`): `ausencias`,
  `formacoes`, `avarias`, `pedidos_compra`. Quem decide: `bsp_chefe_de`
  (gestão, superior, chefe da área). Ecrãs: `EquipaScreen` (Contactos,
  `AusenciasPainel`, `FormacoesPainel`), `AvariasScreen`
  (`bspTrataAvarias` = gestão + Serviços Gerais, que vêem todas; os outros só
  as da sua área, `avarias-por-area.sql`, 02-10-2026), Stock →
  `PedidosCompraPainel` (só a gestão aprova).
  Mapa de férias (02-10-2026, `ferias-mapa.sql`): `bsp_mapa_ferias(ano)` /
  `MapaFerias`; toda a equipa vê só as férias aprovadas (pessoa e datas). Os
  outros tipos de ausência nunca entram no mapa.
- Relatórios diários (02-10-2026, `relatorios-diarios.sql`, Edge Function
  `relatorios-diarios`): Direcção 06h50 (sócios + Director, com valores) e
  áreas 07h15 (chefes, sem valores, adm@barispol.com em cópia), em vez do
  Zapier. A Imagiologia vai para a Direcção Clínica (u14, `PARA_AREA`).
  O da Clínica leva a gestão clínica de 30 dias (`direccao-clinica.sql`,
  `bsp_srv_direccao_clinica`, modelo JCI/OMS), sempre com números reais ao lado
  de cada percentagem (pedido do Elmar). Endereços extra só no servidor (`relatorios_diarios_destinos`;
  `relatorios_destinos` é dos relatórios por área, outra coisa).
  O da Recepção mede a qualidade do atendimento por colaborador
  (`recepcao-qualidade.sql`, `bsp_srv_recepcao_qualidade`: facturação,
  marcações, relatório de turno). Desde a versão 11 sem WhatsApp nem
  «Workspace aberto»: estão só no e-mail das 08h00 (`wa_resumo_8h`).
  Painel clínico: `PainelClinicoScreen` / `bsp_painel_clinico` sobre
  `erp.clinico_dados`; nunca Kz nem nomes de utentes. Os quadros da
  Recepção, Farmácia e Laboratório vêm de `erp.clinico_extra` (campo
  `extra`, filtrado por área no `bsp_painel_clinico`).
- Cadeia de frio (03-10-2026, `cadeia-frio.sql`): `frio_min`/`frio_max` nos
  relatórios da Farmácia, Laboratório e Enfermagem (`BSP_CAMPOS_FRIO`); fora
  de 2–8 °C, `bsp_frio_aviso` avisa logo.
- Qualidade clínica (02-10-2026, `qualidade-clinica.sql`): campos dos
  relatórios de turno em `BSP_CAMPOS_AREA` (incidentes, satisfação, espera,
  laboratório, protocolos), somados por `erp.qualidade_clinica_dados` e
  juntos em `bsp_srv_direccao_clinica` (chave `qualidade`). Mudar os ids
  dos dois lados juntos. Campo de relatório com `opcional: true` não é
  obrigatório.
- Notificações (02-10-2026, `notificacoes-push.sql`): Web Push pela Edge
  Function `push-enviar` (chaves VAPID só no cofre), `sw.js` na raiz,
  `workspace.webmanifest`. Gatilhos `bsp_push_*` chamam `bsp_push_post`. Um
  aviso novo do servidor entra num gatilho e, no ecrã, `bspIncoming(t, c,
  true)` para não sair duas vezes. Menções nunca avisam quem não vê a
  conversa. Pedido em ecrã inteiro `PedidoNotificacoes`; lista em Admin →
  Notificações. Envios em massa pela base de dados: no máximo 5 por pedido
  (a Resend aceita 10 por segundo).
- Pessoas invisíveis (02-10-2026): `oculto: true` na equipa (o sócio
  Francisco Pinheiro). Esconder só no ecrã com `bspSemOcultos`/`bspOculto`;
  nunca tirar da `state.team`, que se grava inteira.
- Sócios (27-09-2026, `socios.sql`): camada «Sócio» (`soNumeros`), só o
  Painel. Servidor: `bsp_e_socio`, `bsp_membro_e_socio`; ecrã: `bspESocio`,
  `bspVePainel`. Nunca usar a camada de sócio como camada de recurso.
- CRM, pedidos do WhatsApp (29-09-2026, `crm-pedidos.sql`): o serviço
  sai de `crm.servico_do_texto` (palavras inteiras: «osso» apanhava
  «posso») e do anúncio (`crm.servico_do_anuncio`, sem a morada); o
  facturado sai das linhas da factura (`crm.servico_do_item`) e cada
  factura conta uma vez (`crm.pedidos_facturas`).
- Qualquer `update` ao `shared_state` feito no servidor tem de pôr
  `updated_at = now()`: os postos só relêem o estado quando essa data
  muda, e um posto com o estado antigo pode sobrepô-lo ao gravar.
- Históricos do WhatsApp: `ferramentas/whatsapp-importar.py` (ids
  negativos, `cid` «wa-<canal>-n»; bases usadas até 6000000, a seguinte
  é 7000000; procurar palavras-passe soltas antes de aplicar). Ao abrir uma conversa, o `ChatScreen`
  pede as 300 mais recentes dessa conversa: um aparelho aberto nunca
  recebia as importadas.
- Leitura de `messages` (29-09-2026, `mensagens-leitura-rapida.sql`): a
  regra `bsp_msg_ler` usa `bsp_conversas_que_vejo()` (lista calculada uma
  vez por consulta). Nunca voltar a chamar `bsp_ve_conversa` por linha:
  com os históricos, a carga passava os 8 s e o Chat parava.
- Documentos da clínica (30-09-2026, `documentos.sql`): menu «Documentos»
  (`DocumentosScreen`). Publicam Direcção, Coordenação, Direcção Clínica e
  Administração (`bspPublicaDocumentos` / `bsp_publica_documentos`); leitura
  obrigatória (`documentos_leituras`). Desde 02-10-2026 o aviso vai por
  `novidades` (e-mail das 05h00), sino e telemóvel; a Edge Function
  `documento-aviso` já não se chama (`emails-pausa.sql`).
  Um comunicado pode ser só texto (`caminho` vazio): sem «Abrir», e a
  leitura confirma-se no cartão.
  «Alterar» (`DocPublicarModal` com `editar`) muda título, número, data e
  descrição sem pedir nova leitura.
  Para quem (02-10-2026, `documentos-destino.sql`): coluna `grupos` com
  `todos`, `camada:<nome>` ou `cargo:<família>` (nunca pessoas nem áreas,
  decisão do Elmar); `bsp_doc_no_grupo`/`bsp_cargo_grupos` no servidor e
  `bspNosGrupos`/`BSP_DOC_CARGOS` no ecrã, mudar os dois juntos. Fora de
  «todos», nada vai para o Feed nem #avisos.
- «A minha actividade» (30-09-2026, `minha-actividade.sql`): médicos vêem
  só a sua produção (`bsp_minha_actividade`, sem notas de crédito, igual ao
  Painel). Ligação pelo campo `metagest` (códigos `ref_practitioner`) na
  pessoa; menu só com `bspVeActividade`. Nunca abrir `erp.*` a quem entra.
  A Direcção Clínica, a gestão e quem vê o Painel escolhem o médico
  (`bspEscolheMedicoActividade`, `bsp_metagest_medicos`, membro
  `mg:<código>`), 02-10-2026. A Direcção Clínica vê os outros médicos só
  com quantidades, sem Kz (`sem_valores`, decisão do Elmar).
  Painel clínico (02-10-2026, `painel-clinico-acesso.sql`): só gestão, Painel,
  Direcção Clínica e chefes de área (só a sua); a produção por médico só a
  quem vê tudo.
- Prints de ecrã (30-09-2026): a app Android tem `FLAG_SECURE` na
  `MainActivity`. No navegador, `ProteccaoEcra` em todos os ecrãs: marca de
  água (`MarcaDagua`, uma só linha ao centro, nunca repetida), PrintScreen escurece e regista em `capturas_ecra`,
  impressão em branco; nos ecrãs de `BSP_ECRAS_SENSIVEIS` o conteúdo tapa-se
  quando a janela perde o foco. Um ecrã novo com dados sensíveis entra nessa
  lista. Imprimir documentos só por `bspImprimirHtml` (iframe próprio; no iPhone/iPad,
  camada `bspImprimirIos`, porque o Safari imprime a página principal); no atalho do ecrã principal do iPhone o `window.print()` não faz nada, e o «Imprimir» abre `imprimir.html#z=…` com o documento comprimido, `bspEnderecoImpressao`, 03-10-2026). `bspImprimirHtml(html, { pdf })` partilha um PDF pronto no iPhone (cartaz: `assets/cartaz-avaliar.pdf`, refazer se o cartaz mudar). Listas em tabela para imprimir: `bspTabelaImpressao`.
- Guia por e-mail (30-09-2026, `guia-envio.sql`): imagens em `guia/`,
  fila `guia_envios`, confirmações `guia_recepcoes` (#confirmar-guia).
- Acesso guiado (30-09-2026): `GuiaEcra` + `BSP_GUIA_FICHAS` (texto de cada
  menu) + `BotaoGuia` («?» no topo). Um menu novo ou mudado leva a sua ficha.
- Anexos no chat: `enviarFicheiros(lista, opc)` no `ChatScreen` serve o
  clipe (vários ficheiros), o arrastar com o rato e as notas de voz
  (27-09-2026: `comecarGravacao`, `bspMensagemNotaVoz`, `bspEAudio`,
  `AudioAnexo`). Desde 28-09-2026 as notas gravam-se em WAV
  (`bspWavDeAmostras`), porque o WebM não tocava no iPhone. Nunca voltar
  ao `MediaRecorder`.
  Fotografias do Chat reduzidas antes de subir (`bspReduzirImagem`,
  30-09-2026); endereços assinados em lote (`bspSignedUrlEmLote`). Endereços de
  24 h guardados no aparelho por pessoa (`bsp-urls-<id>`, 01-10-2026, para
  não gastar tráfego); nunca voltar a endereços de 1 h só em memória.
  Imagens acima de 600 KB aparecem como cartão «toque para ver»
  (`AnexoMensagem`, `bspTamanhoFicheiro` → `bsp_tamanho_ficheiros`,
  `trafego.sql`). Uma
  mensagem de quem já saiu da equipa mostra «Antigo colaborador».

## Decisões aprovadas

- Chave publicável «barispol» em `servidor.js` (07-09-2026).
- Mudança para o projecto Supabase «Barispol» (`gnqleaxrtuerlcrriqqs`),
  numa organização nova (24-09-2026).
- Calendário com o texto da opção C (rotina semanal).
- Datas nos chats, e não apenas horas.
- Número de mensagens por ler no botão Chat.
- Janelas em ecrã inteiro no telemóvel.
- Departamento Radiologia.
- Linhas de controlo escondidas, sem apagar dados.
- Regra `bsp_msg_editar`: só o autor edita a sua mensagem (aplicada em
  23-09-2026).
- A separação da equipa por áreas deve basear-se na caixa de correio da
  Barispol, e não no directório.
- Aspecto dos e-mails igual ao site (branco, linhas finas, cantos rectos,
  etiqueta azul, rodapé marinho): aprovado pelo Elmar a 26-09-2026. Vale
  para todos os e-mails automáticos e para a caixa de contacto do site.
- Direcção e Coordenação vêem as tarefas privadas de todos e delegam
  (criam na lista de outra pessoa). Regras em `tarefas-delegar.sql`,
  função `bsp_ve_tarefas_pessoais()`, coluna `criada_por` (24-09-2026).

- E-mails automáticos para toda a equipa, e não só @barispol.com: os
  médicos usam endereços pessoais (Elmar, 30-09-2026).

## Por fazer

0. **Migração (24-09-2026):** apagar a função `mig-recebe` do projecto
   novo quando a cópia dos ficheiros acabar (o código dela caduca a
   27-09-2026). Confirmar que o projecto antigo está pausado ou sem os
   agendamentos `bsp-…`, para não haver e-mails a dobrar.
1. **Resumo matinal:** agendado sem chave secreta em 24-09-2026 (passo 3
   do `O-QUE-FALTA.md`). `fonte_chave` = `SUPABASE_SECRET_KEYS`.
2. Os envios reais já funcionam (lembrete e colectivo, 24-09-2026, 17
   destinatários). Confirmar os agendados a 25-09-2026 em
   `net._http_response`: resumo 06h30, lembrete 07h30 (`lembrados` = 17),
   colectivo 12h00. Sem `falhas`.
3. Passo 0.6: só com autorização expressa do Elmar. Antes, testar a
   `criar-utilizador` (0.5-e).
4. Departamentos de toda a equipa já estão em `shared_state.team`
   (29-09-2026) e copiados para a lista embutida `USERS` (Afonso Felisberto
   e Joana Tati acrescentados a 30-09-2026). Falta o cargo da
   Gizela Joaquim. Confirmar a conta «Beb» (beb@beb.com) na camada
   Direcção. (Catarina Ndundu Baptista: eliminada a 24-09-2026.)
5. Decidir se se cria o canal `#radiologia`.
6. Tarefas a partir de e-mails, no Workspace de cada pessoa. Falta decidir
   entre uma caixa por pessoa e uma caixa partilhada; a via recomendada é
   o Power Automate.
7. Nunca testado: uma chamada entre dois aparelhos reais e a importação
   de um CSV do MetaGest.
