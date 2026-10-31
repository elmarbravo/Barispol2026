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
7. Marca: Titillium Web, gratuita (com Segoe UI/Arial de recurso). Todas as
   páginas, o Workspace e os e-mails usam "Titillium Web","Segoe UI",Arial.
   Nunca voltar a pôr a Dax (Elmar, 05-10-2026: «coloque uma gratuita, o Dax
   está a abrir mal em alguns PCs»). Cores: azul-marinho #292F58 e #273069,
   azul #2291CE. Nos e-mails, o logotipo `assets/logo-barispol.png` no topo.
8. Antes de cada alteração, dizer o que se vai fazer. Depois, dizer o que
   se confirmou. Se o ecrã ou o código não corresponder ao descrito, parar
   e descrever.
9. Sempre que se mexe no código, actualizar `O-QUE-FALTA.md` na mesma
   alteração.
10. Notion (Elmar, 06-10-2026: «vai carregando tudo que formos fazendo»):
   cada alteração entra também na página privada «Barispol Workspace» do
   Notion (id `3f1d81c4-3cc2-812f-8881-f48f3cfc301a`): uma linha na base
   «Registo de alterações» (data source `e4b100cf-4d80-477c-940e-f10aee4c8769`:
   Alteração, Código, Data, Área, Ficheiros, Resumo); um ficheiro SQL ou Edge
   Function novo entra em «Ficheiros do servidor» (data source
   `edd8c523-ea66-4bf2-bb23-3922bef4c0b7`: Ficheiro, Tipo, Data, Para que
   serve); e, quando mudar, a página «Por fazer» e o módulo da área. Nunca
   lá: chaves, palavras-passe, nomes de utentes, valores pagos, taxas dos
   médicos nem o texto do regulamento interno.
11. Assuntos da Barispol só saem pela Barispol: o Workspace (Chat,
   `bsp_enviar_email`, geral@barispol.com) ou o correio @barispol.com. Nunca
   enviar e-mails do Gmail pessoal do Elmar (nem de outra conta pessoal) sem
   autorização expressa dele na própria conversa (Elmar, 16-10-2026: «Não
   envies e-mails do meu Gmail sem a minha autorização»). Se o Workspace e o
   correio da Barispol não estiverem disponíveis, a mensagem fica pendente e
   diz-se ao Elmar. E-mails que o assistente manda em nome do Elmar vão
   assinados pelo sistema («Sistema · Workspace Barispol»), nunca com o nome
   dele (Elmar, 21-10-2026: «E-mail assinado pelo sistema, nunca por mim»).

## Segurança (auditoria de 12-10-2026, Elmar: «estamos vulneráveis»)

- `shared_state` (`shared-state-fechar.sql`): só a gestão muda `team` e
  `camadas`; o gatilho `bsp_estado_guarda` mantém os valores antigos a quem não
  é gestor (sem erro, para as tarefas gravarem) e regista tudo em
  `equipa_auditoria`. Nunca voltar a `using (true) with check (true)` nessa
  tabela nem correr de novo `supabase-configuracao.sql` (reabre tudo). Dentro
  de funções security definer usar `auth.jwt()->>'role'`, nunca `current_user`.
- Regras de inserir nunca com `or bsp_meu_id() is null` (`inserts-sem-equipa.sql`).
- `imprimir.html`: o documento do `#z=` vai sempre para um `<iframe sandbox>`
  sem scripts; nunca `document.write` nem `innerHTML` com o que vem do endereço.
- Ligação ao servidor: só a do `servidor.js` (`bspGetCfg` ignora outro URL
  guardado); o ecrã manual de ligação foi retirado e não volta.
- `workspace.html` tem Content-Security-Policy por `<meta>`: um host novo
  (imagens, ligações, iframes) entra na CSP ou não carrega. Scripts só locais
  (`vendor/`), nunca CDN. A página sai de dentro de iframes.
- O ecrã Admin → Segurança só diz o que existe de facto.
- Contas gestoras: Elmar, Arlete e a conta de teste «Beb» (a desactivar).
- 2FA obrigatória para todos (16-10-2026, 3-hh, Elmar: «autenticação de dois
  factores para todos acessos»): sem factor TOTP só abre o `MfaInscreverEcra`;
  com factor, o `MfaCodigoEcra` (`useBspMfaNivel`, aal2); depois do código a
  página recarrega. Nunca voltar a pôr «Desligar» (só «Mudar de telemóvel»).
  Duas vias valem (Elmar: «por e-mail ou app»): app (aal2) ou código por e-mail
  (`MfaEmailPasso`, `mfa-email.sql`, `bsp_mfa_ok`; aparelho lembrado 30 dias em
  `bsp-mfa-aparelho`; desde 27-10-2026 «Sair» já não o apaga, só Conta →
  «Esquecer este aparelho», `BotaoEsquecerAparelho`, e um erro nunca o apaga).
  Dispensa temporária (`mfa-liberacao.sql`, 26-10-2026): `mfa_liberacoes` com prazo
  curto, só por decisão da Direcção, quando o e-mail do código não chega.
  No servidor, `mfa-obrigatoria.sql` (regra aal2). Sessões gémeas (20-10-2026,
  `mfa-sessoes-gemeas.sql`): a entrada no iPhone saía duas vezes; `bsp_mfa_ok`
  aceita a gémea verificada (10 s) e a entrada ignora o 2.º envio (`aEntrar`). Terminar a sessão de todos:
  mudar `BSP_SESSAO_GERACAO` e correr `sessoes-terminar.sql`. Workspace a mudar para `ws.barispol.com` (aprovado pelo Elmar; o site
  já não liga à equipa): um host novo entra na CSP, nas `ORIGENS_PERMITIDAS` e
  no `PERMITIDOS` da app PC. O fluxo «Verificar» confirma a sintaxe a cada push.
- Rede da clínica (25-10-2026, `rede-limitada.sql`): fora da rede (e não isento) só
  Chat e Escalas: `bsp_pre_pedido` (pgrst.db_pre_request) e `BSP_ROTAS_FORA` no ecrã;
  uma tabela ou função nova do Chat ou das Escalas entra nas duas listas. Nunca
  voltar a pôr `bsp_rede_ok` em `bsp_meu_id`/`bsp_sessao_aal2` (fechava o Chat).
- Sem internet (26-10-2026, 3-ia): fila `bsp-fila-v1` (`bspFilaPor`, `BSP_FILA_ENVIO`:
  Chat, relatórios, estado das marcações) e cópias `bsp-cache-*`, só no separador;
  `sw.js` guarda só a casca (nunca dados). Escrita nova que deva funcionar sem
  rede entra em `BSP_FILA_ENVIO` e confirma se já chegou antes de gravar.
- Estado, notificações e endereços assinados só no `sessionStorage`
  (12-10-2026, Fase 2 em `O-QUE-FALTA.md` 3-gy); endereços de 4 h.
- Push das mensagens sem texto (`push-sem-texto.sql`): «Nova mensagem» e o
  autor; nunca voltar a pôr o texto no `corpo` do `bsp_push_mensagem`.
- `bright-worker` v8 (`emails-autor.sql`): `emails_registo.autor`, 20 por
  dia a quem não é gestor, HTML limpo (`limparHtml`: ligações só barispol.com).
- Chave pública fechada (`funcoes-fechadas-2.sql`): `anon` não tem tabelas nem
  funções de `public`, nem por omissão; só `bsp_pedido_site`,
  `bsp_feedback_publico`, `bsp_feedback_email` e `bsp_avaria_do_email`. Uma
  `crm`, `erp` e `whatsapp` nunca chamáveis pela API; toda a tabela com RLS.
  Desde o ponto 7 da Fase 2 só `bsp_feedback_email` e `bsp_avaria_do_email`
  (Zapier, com código do cofre) ficam a `anon`; o site entra pela Edge
  Function `entrada-publica` (`entradas-publicas.sql`: origem, campo-armadilha,
  5 por hora por ligação). Uma entrada nova para visitantes passa por ela,
  nunca por `grant execute … to anon`.
- Cópia diária de todas as tabelas de `public` (7 dias) e retenção semanal
  `bsp_retencao` (`retencao-copias.sql`); uma tabela nova com prazo de vida
  entra na lista `regras` dessa função.
- Auditoria (`auditoria-dados.sql`): `auditoria_dados` + gatilho `bsp_auditar`
  (só API com sessão) nas tabelas de utentes, clínicas e de pagamentos; uma
  tabela nova desse tipo leva o mesmo gatilho. Uma função nova que devolva
  dados sensíveis chama `bsp_acesso_srv(ecra, detalhe)` no início (detalhe
  sem nomes) e é VOLATILE.
- CORS nas Edge Functions: `comCors` + `ORIGENS_PERMITIDAS` (barispol.com,
  www, app); uma função nova chamada pelo navegador usa o mesmo embrulho,
  nunca `"*"`. Android `allowBackup="false"`.
- Por fazer (fases 2 a 4 do plano, em `O-QUE-FALTA.md` 3-gy): painel Auth
  (2FA, sessões, Turnstile), píxel da Meta fora
  do domínio do Workspace, entradas públicas atrás de Edge Function, CORS,
  retenção e cópias, política de privacidade para utentes, APD.

## Quem vê o quê (03-10-2026, Elmar: «cada funcionário só vê as suas coisas; os superiores vêem da sua equipa»)

- Dados de pessoas (ausências, formações, avaliação, produtividade, tarefas
  privadas, ficheiros pessoais): o próprio, o superior (`superior` na
  equipa), o chefe da área (`bsp_chefe_de` / `bsp_edita_escala`) e a gestão
  (Director Geral e RH). Nunca «todos os autenticados».
- Salários e valores pagos: só o Elmar (u1) e a Arlete (u2), `bsp_ve_salarios`.
- Consumos (toners, gerador, combustível e viatura): o Elmar, a Arlete e
  o Emmanuel pelo nome, a área Serviços Gerais e a gestão: `bsp_ve_consumos` / `bspVeConsumos`
  (`consumos-acesso.sql`, 05-10-2026). Um consumo novo usa esta regra.
- Stock e compras correntes (07-10-2026, `stock-acesso-pessoas.sql`): Stock só
  por `stock_responsaveis` (Elmar e Arlete todos os armazéns; Solange Farmácia,
  Laboratório e Enfermagem; Rosa Laboratório), sem a regra dos consumos; compras
  correntes (alimentação, limpeza, escritório, água, gás) só u1 e u2
  (`bsp_ve_compras_gerais` / `bspVeComprasGerais`).
- Produtividade (07-10-2026): o próprio, o superior e a gestão. Quem não tem
  conta vai para o responsável de fora da área (`bsp_superior_area`: Direcção
  Clínica ou gestão), nunca para o chefe da própria área (a Juliana vê só ela, a
  Joaquina e a Déricka; a Rosa só ela, o Nicolau e a Cássia).
- Qualquer tabela nova com dados de uma pessoa segue esta regra no servidor
  (RLS) e no ecrã.

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
  - `recuperar-acesso` (05-10-2026, `recuperar-acesso.sql`): o «Esqueceu-se?».
    Ligação de recuperação (`generateLink`) pela Resend, de geral@, só para
    o endereço da conta; abre `workspace.html#recuperar=<código>` e o
    `NovaPalavraPasseEcra` gasta o código só ao gravar (`verifyOtp`). Nunca
    voltar ao `resetPasswordForEmail` (correio do Supabase só entrega ao
    Elmar e a ligação ia para localhost).
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
  Os avisos (`ToastProvider`) ficam acima, com 100001 (30-10-2026: por baixo
  da `TurnoPorta` não se viam e o Nicolau ficou preso). Nunca baixar.
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
- Sessão (02-10-2026): no `sessionStorage` (`bspArmazemSessao`). Um só cliente
  do Supabase por separador (30-10-2026): a sincronização usa o `__bspClient` do
  `bspGetClient`; nunca voltar a criar um segundo `createClient` com a mesma
  sessão (os dois renovavam-na ao voltar do segundo plano e a sessão caía no
  iPhone, com «JWT expired»). Excepção aprovada pelo Elmar
  (28-10-2026, «A equipa está descontente»): nos aparelhos lembrados (caixa dos
  30 dias, `bspAparelhoLembrado`) a sessão fica no `localStorage` até ao fim do
  prazo (`bsp-mfa-aparelho-ate`); «Esquecer este aparelho» e o fim do prazo
  devolvem-na ao separador (`bspEsquecerAparelho`). A caixa (`BspCaixaLembrar`, marcada por
  omissão, 29-10-2026) está no código por e-mail e no da app
  (`bsp_mfa_app_lembrar`, `mfa-app-lembrar.sql`). Sem a caixa, nunca no
  `localStorage` (contas abriam sozinhas em computadores partilhados).
- Quem está online (02-10-2026): sempre `bspEstadoDe(user)` /
  `bspEstaOnline(id)` (tempo real ou sinal na `presenca` há menos de 3
  min), nunca `user.status` sozinho, que é o que ficou gravado na ficha.
- Recibos de leitura (02-10-2026): `RecibosMensagem` em cada mensagem
  própria (gestão: em todas as dos canais, `bspVeRecibosDeTodos`); quem
  deve ler vem de `bspDestinatariosConversa`. Só se marca como lido com o
  Workspace à vista (`marcarLido` nunca com `document.hidden`).
- Notificações (03-10-2026): abrir o ecrã marca-as lidas (`eNova` mantém
  as desta visita à vista); gravam-se também em `bsp-notifs-v1` (sair da
  sessão apaga-a). Sem espaço no aparelho, o estado grava-se com só as
  últimas 60 mensagens por conversa. Nunca pôr no estado coisas grandes
  sem pensar no limite de ~5 MB. Desde 12-10-2026 o estado
  (`bsp-workspace-v1`), as notificações e os `bsp-urls-<id>` estão no
  `sessionStorage` (auditoria): nunca voltar ao `localStorage` para dados;
  lá ficam só preferências do aparelho.
- Avisos das mensagens (04-10-2026, Elmar: «as mensagens normais entre pessoas
  no chat não está a notificar»): `bspBrowserNotify` só pelo service worker
  (`showNotification`; o `new Notification` não existe no telemóvel), com a
  etiqueta `conv-<chave>` igual ao push do servidor (os dois juntam-se num só).
  Avisa sempre, menos quem está a ler essa conversa (`__bspPagina`,
  `__bspConvAberta`). No servidor, o `bsp_push_mensagem` avisa também nos
  canais quem os vê (`push-canais.sql`, mesma regra do `bspVeCanal`). Número no ícone da app: `navigator.setAppBadge` em
  `useChatPorLer`; o `sw.js` põe um ponto quando chega uma mensagem.
- Abrir uma conversa directa de qualquer ecrã: `bspConversaCom(id)`.
- Pesquisa do Chat (30-10-2026, Elmar: «não me leva directamente à mensagem»):
  procura no servidor em todo o histórico e salta para a mensagem (`irPara`,
  id `bsp-msg-<sid>` na linha, `bsp-msg-achada`). Nunca tirar o id das linhas.
- Chat aberto (14-10-2026, Elmar: «o chat tem pouco espaço… não tem opção de
  minimizar menus»): menu lateral recolhe para ícones (`bsp-menu-recolhido`),
  lista de conversas esconde-se (`bsp-chat-lista`) e o painel «Sobre» abre só
  pelo botão «i» (`bsp-chat-info`, fechado por omissão), todos por
  `useBspPrefSimNao` (preferência do aparelho); formatação atrás de «Aa»;
  «Procurar conversa…» filtra canais e pessoas. Botões do cabeçalho sem
  moldura (32 px).
- Enquetes do Feed (29-10-2026, `enquetes.sql`): opções em `posts.poll`, votos
  em `enquete_votos` só por `bsp_enquete_votar`; totais por
  `bsp_enquete_resultados` (`useEnquete`). Quem votou em quê nunca se mostra.
- Anexos do Feed (06-10-2026): `ComposePostModal` aceita vários (`atts`); cada
  um vai para o Drive e entra no texto como `[anexo:nome]`.
- Aspecto do Chat (06-10-2026, Elmar: «eu escrevo e fico do lado direito»):
  as minhas mensagens à direita (`bsp-msg-bolha`, `--bolha-minha`, data dentro
  da bolha), as dos outros à esquerda com fotografia e nome. Reacções com
  todos os emojis (`SeletorReaccao`, `bspEmojisTodos`); tocar numa reacção
  alterna a minha.
- Botão «voltar» (05-10-2026): cada menu é uma entrada no histórico (`App`);
  sub-páginas com `useBspVoltar(aberto, fechar)` (já em todas as `Modal`, no
  «Mais», no Chat do telemóvel) e separadores com `useBspAbaVoltar(aba,
  setAba)`. Um ecrã novo com separadores ou sub-páginas usa-os; nunca
  `history.pushState` à mão.
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
  leitor próprio sobre o JSZip, 02-10-2026). Excel .xlsx/.xls/.csv em `bspVerExcel` (`LeitorExcel`, SheetJS, 31-10-2026). `bspAbrirFicheiro` escolhe sozinho e, sem leitor, guarda ou partilha (`bspGuardarFicheiro`): nunca abrir o endereço directo, que fica em branco no iPhone e na app.
  O «Guardar» do visor é `bspGuardarFicheiro` (blob com o nome certo, partilha no
  telemóvel; nos Word «Descarregar para editar», 06-10-2026): nunca um link directo.
- Logotipo (02-10-2026): `BarispolLogo` com `sm` 38, `md` 64, `lg` 104 px;
  no site, 72 px no cabeçalho (60 no telemóvel). Nunca voltar a tamanhos
  menores (pedido do Elmar). Círculo branco sempre com 13% de margem
  (`--bsp-logo-pad`) e nunca `border-radius` na própria imagem: cortava as letras.
- Telemóvel deitado (31-10-2026, Elmar: «na horizontal não se vê quase nada»):
  `bspTelemovelDeitado` conta como telemóvel; regra `@media (orientation: landscape) and
  (max-height: 500px)` encolhe `bsp-mtop`, `bsp-mnav` (só ícones), `bsp-chat-cab` e põe
  `bsp-escrever` numa linha. Um ecrã novo com cabeçalho ou barra fixa entra nessa regra.
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
- App para computador (14-10-2026, `app-pc/`, Electron): janela própria que
  abre o mesmo `workspace.html`; instalador Windows, portátil e .dmg do Mac
  em Actions → «App PC» → Artifacts. Nunca `nodeIntegration`, `preload` nem
  `sandbox: false` (a página não toca no computador); endereços permitidos em
  `PERMITIDOS` (`app-pc/main.js`). Sem Web Push com a app fechada.
- Relatórios por área: ecrã `relatorios` (`RelatoriosScreen`), perguntas em
  `BSP_RELATORIOS`, respostas na tabela `relatorios_area`
  (`relatorios-area.sql`). Sem nomes de utentes.
  Relatórios de turno (14-10-2026, `relatorios-turno.sql`, Elmar: «o importante
  não enviam»): o formulário vem preenchido com o MetaGest
  (`bsp_relatorio_metagest`, `BSP_REL_MG_CAMPOS`, `RelatorioMetaGest`) e
  substitui o e-mail escrito à mão; dia do relatório por `bspDiaRelatorio`
  (antes das 06h00 = dia anterior, igual ao servidor); o formulário tem «Dia do
  relatório» (`diaForm`, até 7 dias para trás, 16-10-2026): MetaGest, `dia`
  gravado e conferência são desse dia. Ao entregar:
  `metagest` guardado, «precisa de atenção» (`bsp_relatorio_atencao`, aviso e
  novidade), conferência com o facturado (`bsp_relatorio_conferir` →
  «Possível acto por facturar» a u1 e u2), e-mail com as perguntas por extenso
  (`resumo`). Lembrete 1 h após o fim de cada turno da escala publicada
  (`bsp_relatorios_lembrar`, cron `bsp-relatorios-lembrar`). Um campo novo com
  stock, equipamento ou incidentes entra também em `bsp_relatorio_atencao`. Lêem: Direcção e
  Coordenação tudo; Direcção Clínica (Osvaldo Pacheco, u14,
  `BSP_RELATORIOS_DIRECCAO_CLINICA` / `bsp_le_areas_medicas()`) as áreas
  médicas. E-mail de cada relatório (14-10-2026,
  `relatorios-destinos-superiores.sql`, Elmar: «seguem para direcção clínica,
  adm e superiores de cada área»): para o chefe da área (`relatorios_destinos`)
  e DireccaoClinica@, cc adm@ e o superior de quem entrega (campo `superior`),
  por `bsp_relatorio_destinatarios(area, user)`; nunca para quem entrega.
  Anexos do relatório (30-10-2026, `relatorios-anexos.sql`, Elmar: «parem de enviar
  no chat e mandem só no relatório»): campo tipo `anexos` (`bspCampoFicheiros`,
  id `ficheiros`), ficheiros em `drive` → `relatorio/<área>/<id>/…`, lidos só por
  quem lê o relatório; nunca guardar HEIC (30-10-2026: `bspConverterHeic` passa-o a
  JPEG antes de subir, pelo navegador ou pelo `vendor/heic/conversor.html` num
  iframe `sandbox` sem mesma origem, o único sítio com 'unsafe-eval'; nunca pôr
  'unsafe-eval' na CSP do Workspace) nem mandar os ficheiros por e-mail.
  Obrigatório no Laboratório e na Enfermagem.
  Abertura e fecho do turno (30-10-2026, `turno-contagens.sql`, Elmar: «ao abrir o
  dia lançam as quantidades e ao fechar também», «obrigatório»): Laboratório e
  Enfermagem; `TurnoPorta` tapa o Workspace (abertura e fecho em atraso) pela
  escala em vigor (`bsp_turno_pendente`); gravar só por `bsp_turno_contar`
  (passagem de turno e mínimo avisam chefe, gestão e u14); listas em
  `turno_listas` (`bsp_turno_lista_gravar`; Enfermagem: Filomena u9 e os
  enfermeiros). Fotografia do BS-200 obrigatória e números escritos.
  Em vigor desde 31-10-2026. No Laboratório, artigos `tipo: 'material'` contam-se
  por quantidade (testes rápidos, lamelas…); todo o artigo por quantidade tem
  «Reforço» (`ref`, entregas da Solange): a abertura compara com fecho + reforço.
  Reagentes com `aberto` (data do frasco, obrigatória) e `prazo` na lista (bula;
  vazio = 28 dias); aviso `bsp_turno_reagentes_alertar` (`turno-reagentes-prazo.sql`).
  Campos dos protocolos desligados (`BSP_PROTOCOLOS_ACTIVOS`) até a Direcção
  Clínica validar a lista (Elmar, 30-10-2026).
  Auditoria (30-10-2026, `auditoria-relatorios.sql`): `BSP_CAMPOS_LAB_QUALIDADE`
  (CIQ, lote novo, suspensos, valores críticos), frio obrigatório com `frio_accao`,
  `BSP_CAMPOS_CARRO` (Enfermagem), `BSP_CAMPOS_RX_REPETIDOS`; ids lidos por
  `bsp_relatorio_atencao`. A Direcção Clínica (u14) é informada de cada mudança
  no grupo da Direcção e por e-mail (Elmar: «mantenha sempre»).
  Reagentes do Laboratório (16-10-2026, fotografias do BS-200): campo tipo
  `reagentes` (`reagentes_exames`: `[{r, r1, r2, proc}]`, testes restantes no
  R1 e no R2 lidos no aparelho; dá para = o menor), `bspReagentesLimpos`,
  `bspReagenteAlerta`, lista `BSP_REAGENTES_BS200`.
  Os 12 do BS-200 (30-10-2026) são os mesmos em `BSP_REAGENTES_BS200` e em
  `turno_listas`: mudar os dois juntos; nomes à mão por `bspReagenteNome`.
  Sem informação clínica (16-10-2026, `sem-clinico.sql`): `bspSemClinico` /
  `bsp_sem_clinico` (u22, Emmanuel) tira Relatórios, Painel clínico, Qualidade,
  Utentes e Actividade; um ecrã clínico novo verifica-o.
- Apresentação do Workspace (25-09-2026): cores oficiais nas variáveis
  (`--navy` #292F58, `--accent` #2291CE), letra Titillium Web, sem gradientes nem
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
- Tarefas delegadas (06-10-2026, `tarefas-conclusao.sql`): «✓ Concluir» no cartão e
  na janela; ao concluir, quem delegou recebe aviso (`bsp_tarefa_concluida_aviso`);
  às 06h45 a lista das atrasadas (`bsp_tarefas_atrasadas_alertar`). O `prazo` das
  privadas é texto: converter antes de comparar. Secção «Atrasadas» no quadro.
  `origem = 'emails'`: tarefa criada pelo sistema a partir dos e-mails; o ecrã mostra
  «Sistema», mas `criada_por` é quem recebe os avisos.
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
  Intervalo entre utentes (07-10-2026, `marcacoes-intervalo.sql`, Elmar: «não
  permita marcar todas no mesmo minuto»): gatilho `bsp_marc_espacar` recusa duas
  marcações em aberto do mesmo médico (sem médico: mesmo acto) no mesmo dia mais
  perto do que `bsp_marc_duracao(acto)` (tabela `marcacoes_duracoes`, durações de
  referência geral por especialidade e exame, o maior que bater; sem padrão, 15
  min; o MetaGest não mede a duração) e diz a próxima hora livre. Só hoje e datas
  futuras; `set_config('bsp.marc_livre', '1', true)` para passar por cima.
  Telemóvel do próprio (`contacto`, de onde sai o `tel9`) e de familiar
  (`contacto_familiar`, `familiar_quem`), 03-10-2026, `telefones-familiar.sql`.
  Pedidos do site (03-10-2026, `pedidos-site.sql`): `contacto.html` e a página
  inicial gravam por `bsp_pedido_site` (aberta a visitantes) em
  `pedidos_marcacao`; aviso no telemóvel da Recepção e, desde 30-10-2026
  (`pedidos-site-email.sql`, `bsp_pedido_site_email`), e-mail a rececao@ com geral@ em
  cópia; `PedidosSitePainel` em Marcações, tratado por `bsp_pedido_site_tratar`. O
  utente espera a chamada.
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
  e `bspVeEscala`/`bsp_ve_escala`. Desde 09-10-2026 (`escalas-ver-todas.sql`,
  Elmar: «Todos vêem todas») toda a equipa lê as publicadas de todas as áreas;
  os rascunhos só a própria área e quem edita. Ecrã `EscalasScreen`; papel
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
  Viaturas (06-10-2026, `transporte-viaturas.sql`): `transporte_viaturas` e
  `viatura_id` nas viagens, abastecimentos e manutenções; os km contam-se por
  viatura (cada uma tem o seu conta-quilómetros). No ecrã, a viatura escolhida
  (`bsp-transp-viatura`) filtra tudo; qualquer conta nova de km é por viatura.
  Acertos de km (09-10-2026, `transporte-acertos.sql`): «Acertar km» só da
  gestão; o último acerto é o ponto de partida e só contam as viagens
  registadas depois dele (`bspTranspUltimoKm`); nunca se apagam.
  Registo inicial (12-10-2026, `transporte-km-inicial.sql`, pedido do
  Emmanuel): o primeiro acerto de uma viatura sem acertos pode ser do
  motorista (`bsp_ve_transporte`); botão «Registo inicial de km» e campo na
  viatura nova (`TranspViaturaModal`, `TranspAcertoModal` com `inicial`).
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
  `direccao-clinica`, uma área de `bsp_area_chave` ou um id). Aparece no
  sino (tipo `sistema`). O e-mail das 05h00 foi desligado a 03-10-2026 (Elmar:
  «Anule o e-mail de actualização todas as manhãs às 5h»; cron `bsp-novidades`
  apagado): não voltar a agendá-lo.
  No sino (03-10-2026, `novidades-sino.sql`): só por `bsp_novidades_por_ver` /
  `bsp_novidades_vistas` (marcador por pessoa no servidor), logo que é criada;
  nunca voltar a ler a tabela pela ordem antiga nem guardar o «já vi» só no aparelho.
- Painel financeiro (27-09-2026, `painel.sql`): `bsp_painel(de, ate)`,
  só `bsp_ve_painel()` = Elmar (u1), departamento Financeiro e sócios
  (decisão do Elmar; a gestão por si só não vê; ecrã: `bspVePainel`); histórico em `crm.mg_*`, hoje em `erp.sales_invoice`
  (cron `bsp-painel-hoje`, 5 em 5 min). Médicos e seguradoras vêm de
  `erp.sales_invoice` (histórico desde 2022, `metagest-historico.sql`),
  nunca de `crm.mg_consultas`, que está incompleto. Ecrã `painel` (`PainelScreen`,
  `PainelColunas`, `PainelBarras`), cores `--serie-1..4`.
  Alertas e nomes (30-10-2026, `painel-alertas.sql`, Elmar: «faltam coisas
  financeiras, nomes, alertas»): `bsp_fin_alertas` (`PainelAlertas` no topo),
  `pessoas` por quem emitiu (`owner`, `bsp_fin_pessoa`; as notas de crédito
  contam a quem emitiu a factura anulada), recebido, descontos, ano anterior.
  Notas de crédito: alerta quando a soma do dia passa de 30 000 Kz; descontos de
  50 000 Kz ou mais (`BSP_FIN_LIMITE_NC`/`_DESC`, mudar com o servidor);
  telemóvel por `bsp_financeiro_alertar` (cron `bsp-financeiro-alertas`).
  «All Customer Groups» conta como Particular. Nomes só da equipa, nunca de utentes.
- Stock (01-10-2026, `stock.sql`): saldo pelo último movimento do MetaGest
  (`erp.stock_mov`, cron `bsp-stock`); `bsp_stock()` / `bsp_stock_resumo()`;
  quem vê: `stock_responsaveis` + gestão (`bsp_ve_stock`) e, no ecrã,
  `bspVeStock` / `BSP_STOCK_RESPONSAVEIS`. Ecrã `StockScreen`, Início
  `StockAlertaCartao`. Stock geral (16-10-2026, `stock-mais-saidas.sql`): os
  10 artigos com mais saídas passam a «A acabar» com menos de 14 dias
  (`bspStockMaisSaidas`); mudar os dois lados juntos.
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
- Agendamentos desencontrados (29-10-2026, Painel com «statement timeout» às
  10h30): as cargas pesadas não arrancam no mesmo minuto (whatsapp-sync 3/13…,
  crm-pedidos 7/22…, bsp-painel-hoje 1/6…, bsp-stock 9/24…, bsp-vigilancia
  14/29…, bsp-clinico-hoje 17 e 47). Um cron novo de carga escolhe um minuto livre,
  nunca :00 nem :30.
- Funções com filtro de acesso (01-10-2026): calcular primeiro o que a
  pessoa vê (CTE com `offset 0`), nunca uma função de acesso por linha numa
  tabela grande (o Stock levava 10 s).
- Funil de vendas (01-10-2026, `crm-funil.sql`): `crm_funil(dias, origem,
  servico)` sobre `crm.caixa`; separador `CrmFunil` no CRM. Cada pedido
  conta na etapa mais avançada.
- Início pessoal (29-10-2026, auditoria, `inicio-pessoal.sql`): primeiro o que é
  da pessoa (relatório por entregar `bsp_relatorio_por_entregar`, «À espera da
  sua decisão», documentos por ler, os meus turnos, as minhas tarefas com as
  privadas `useMinhasTarefas`), depois os cartões da função (Painel, clínico,
  stock, avarias). Nunca voltar a pôr o quadro inteiro da equipa nem dados só
  deste aparelho no Início. Documentos por ler só os do grupo da pessoa
  (`bspNosGrupos`; no servidor `bsp_doc_no_grupo` no `bsp_alertas_por_ler`).
  O Início é sensível para a Recepção e para quem vê o Painel (`bspEcraSensivel`).
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
  Taxa de resposta (03-10-2026, `inquerito-taxa.sql`): `inquerito_contactos`
  (só telefone e datas, cron `bsp-inquerito-contactos`), `inquerito_envios_dia`
  (o «RESUMO DO DIA» do e-mail, lido pela `bsp_feedback_email`),
  `bsp_qualidade_inqueritos`. CRM com estado «Por ligar» (sempre visível;
  o automático «Marcado»/«Compareceu» passa à frente). Mudar um estado do
  CRM: `BSP_CRM_ESTADOS` e a regra `pedido_notas_estado_check`, juntos.
  Tempo de espera (03-10-2026, `qualidade-espera.sql`): `erp.espera_utente`
  (triagem, consulta e última factura do MetaGest, sem nomes),
  `bsp_qualidade_espera(de, ate)`, separador `QualidadeEspera`.
  Voz dos utentes no Feed (06-10-2026, `feedback-feed-semanal.sql`):
  `bsp_feedback_post_feed(de, ate)` publica elogios, reclamações, sugestões e
  outras opiniões numa só publicação (autor u1, `cid` «fb-<de>-<ate>», nunca
  duas vezes); cron `bsp-feedback-feed` à segunda às 08h00 (semana anterior, a
  partir do fim da última). Nomes de utentes tapados por `bsp_feedback_sem_nomes`
  («o/a <Nome>» → «o/a utente», salvo a equipa); nunca telefones nem médicos.
  Auditorias (03-10-2026, `auditorias.sql`): `auditoria_modelos` + `auditorias`
  (respostas `{item: {r: sim|nao|na, n}}`); a conformidade calcula-se no
  servidor (`bsp_auditoria_calcular`); `bsp_faz_auditorias(area)` /
  `bspFazAuditorias`; separador `QualidadeAuditorias`.
- Segmentos (08-10-2026, `segmentos.sql`, Elmar: «ponto 1 do HubSpot»): o
  separador «Segmentos» de Utentes (antigo «Recuperar utentes», `SeguimentoScreen`,
  `BSP_SEGMENTOS`). `bsp_segmento(p_seg)` (só `crm.pode_ver_crm`) devolve ids de
  `utentes` com o motivo: `pacote` (pacote promocional há 11–24 meses),
  `faltou` (faltou/cancelou em 60 dias, sem remarcar nem vir; pelo `tel9`),
  `so-servicos` (laboratório, farmácia, enfermagem ou imagem no último ano, nunca
  consulta). `utentes.chave` = `erp.sales_invoice.patient`; a tabela já se
  actualiza todos os dias. Chamadas em `seguimentos`; «Voltou» automático por
  `bsp_segmentos_voltou` (cron `bsp-segmentos-voltou`, 07h00). As reconsultas quase
  nunca se facturam: nenhum segmento pode depender de «voltou à consulta».
  Contactos do WhatsApp (08-10-2026, `contactos-whatsapp.sql`, Elmar: «importar
  todos os dias os que contactam pelo SendPulse, mesmo os que não chegam»):
  `crm.actualizar_contactos_whatsapp` (cron `crm-contactos-whatsapp`, 05h30) lê
  `crm.caixa` e grava em `utentes` com `origem = 'whatsapp'`, chave `wa:<tel9>`,
  `primeiro_contacto`/`ultimo_contacto`/`pedido`/`conversas`; quem já é utente
  fica só com esses campos; `convertido_em` quando o telemóvel aparece no MetaGest.
  Segmento `nunca-vieram`. Qualquer leitura nova de `utentes` tem de contar com
  linhas sem `ultima_visita` (origem whatsapp).
- Médicos e credenciais (03-10-2026, `medicos-credenciais.sql`): `erp.medicos`
  copiado do MetaGest todos os dias; validades em `credenciais` (gestão e
  u14 registam, cada médico lê as suas); avisos por `bsp_credenciais_alertar`
  nas novidades. Ecrã Equipa → `MedicosCredenciaisPainel`.
- Equipa médica (21-10-2026, Elmar: «criar um módulo "Equipa Médica"»): a rota
  `actividade` chama-se «Equipa médica» (`MedicosScreen`): credenciais,
  presenças, actividade, registo clínico, avaliação só dos médicos
  (`bspEMedico`) e pagamentos (u1/u2). Em Equipa ficam os outros; nunca voltar a
  pôr credenciais nem pagamentos dos médicos em Equipa.
- Menus (07-10-2026, Elmar: «o separador Avarias teria de trocar de nome»): a rota
  `avarias` chama-se «Serviços gerais» (Avarias, Equipamentos e
  manutenção, Gerador; aprovado pelo Elmar); a rota `stock` chama-se «Logística e stock»
  (`LogisticaStockScreen`: Stock com os pedidos de compra, Compras correntes,
  Toners; menu por `bspVeLogistica`, separador por `__bspStockAba` + evento
  `bsp-stock-aba`); «Calendário» passou a «Agenda» em todo o lado. Os ids das
  rotas não mudaram. Avisos de toners vão para `#/stock` (`toners-aviso-destino.sql`).
- Avarias por confirmar e e-mails (08-10-2026, `avarias-confirmar.sql`, Elmar:
  «as avarias devem ser reportadas primordialmente pelo Workspace; o e-mail é para
  reforçar ou cobrar»): estado «Por confirmar» (avaria vinda de e-mail ou relatório,
  `origem`/`fonte`), 72 h (`confirmar_ate`) para quem reportou responder por
  `bsp_avaria_confirmar` (tarefa privada `tarefa_id`, origem `emails`); sem resposta,
  `bsp_avarias_prazo` (de hora a hora) passa a «Aberta» com `confirmacao =
  'sem-resposta'`. Cada avaria aberta → e-mail (`bsp_avaria_email`) a u1, u2 e u14,
  com quem reportou e u22 em cópia; lembrete `bsp_avarias_lembrete` de 5 em 5 dias
  desde 08-10-2026 (cron `bsp-avarias-lembrete`, 07h20). Entrada pelo e-mail:
  `bsp_avaria_do_email` (código no cofre `bsp_avarias_codigo`, nunca mostrar; só
  remetentes da equipa, comparados sem pontos antes do @; mesmo assunto = cobrança)
  responde a quem escreveu com o modo de reportar. A mudança de estado por quem não
  trata as avarias só passa com `bsp.avaria_confirmar = '1'` (dentro das funções).
- Equipamentos e manutenção preventiva (03-10-2026, `manutencao-preventiva.sql`):
  `equipamentos`, `manutencoes_plano`, `manutencoes_registo`; ecrã Avarias →
  `EquipamentosPainel` (o ecrã antigo chama-se `AvariasLista`).
  Quem vê (08-10-2026, `avarias-acesso-area.sql`, Elmar: «As avarias apenas os
  da mesma área e nós superiores vemos»): avarias pela área de quem reportou e
  pela coluna `area`, mais o superior (`bsp_chefe_de`), a Direcção Clínica nas
  áreas de saúde e quem trata; equipamentos, planos e registos só da área (sem
  área: só quem trata). Nunca voltar a abrir a toda a equipa.
  Plano 2026 do Emmanuel (12-10-2026) importado só no servidor: gerador,
  viaturas (categoria `Viatura`, matrícula em `numero_serie`), cerca eléctrica
  e os 21 ar condicionados com plano e registos; custos e facturas nunca no
  repositório.
- Toners e gerador (04-10-2026, `toners-gerador.sql`): Logística e stock → `TonersPainel`
  (só Recepção, Laboratório, Serviços Gerais e gestão: `bspVeToners` /
  `bsp_ve_toners`, `toners-acesso.sql`, 05-10-2026) e `GeradorPainel` (só
  `bspTrataAvarias`). Stock e níveis por movimentos (`bsp_toners_estado`);
  depósito por leituras e abastecimentos (`bsp_gerador_estado`). Avisos por
  `bsp_aviso_servicos_gerais` (novidade + telemóvel). Leitura automática das
  impressoras ainda não existe (precisa de programa local).
  Pedir toners (12-10-2026, `toners-pedidos.sql`): pedido de compra no armazém
  `Toners` de `pedidos_compra`, aberto a `bsp_ve_toners` (não a
  `bsp_ve_stock`); no ecrã, «Pedir toners» em `TonersPainel` usa o
  `PedidosCompraPainel` com `armazem: 'Toners'`.
- Pedido à Farmácia (30-10-2026, `pedidos-farmacia.sql`): `pedidos_area` só pelas
  funções `bsp_pedido_area_*` (área pede → Farmácia entrega com lote e validade →
  área confere quantidade, embalagem, frio e validade); `PedidosFarmaciaCartao` no
  Início; o recebido entra no «Reforço» do turno (`bsp_turno_reforco`). Uma área
  nova que peça entra em `BSP_PEDIDO_AREAS` e na regra de `bsp_pedido_area_criar`.
- Logística (06-10-2026, `logistica-compras.sql`): Logística e stock → «Compras
  correntes» (`LogisticaPainel`), compras de alimentação, consumíveis de escritório,
  limpeza, água e gás (`logistica_compras`, `BSP_LOGISTICA_CATS`), só o Elmar e
  a Arlete (`bsp_ve_compras_gerais`, 07-10-2026). Média e previsão só com
  meses fechados (`bspLogMeses`). As compras antigas vieram das folhas da Arlete
  (nota «Folha da Arlete»), importadas só no servidor: valores nunca no repositório.
- Vigilância (03-10-2026, `vigilancia.sql`): `bsp_vigilancia` de 15 em 15 min,
  avisa a gestão no telemóvel; Admin → «Saúde do sistema». Uma verificação
  nova entra em `bsp_vigilancia` e em `BSP_VIGILANCIA_NOMES`. Agendamentos
  (08-10-2026): só conta a falha sem execução boa depois (falhas passageiras
  não dão alerta crítico).
- Registo de acessos (03-10-2026, `acessos-registo.sql`, RI-3.3):
  `bspRegistarAcesso(ecra, detalhe)`; um ecrã novo com dados sensíveis entra
  em `BSP_ECRAS_SENSIVEIS` e passa a ser registado. Detalhe nunca com nomes.
- Avaliação de desempenho (03-10-2026, `avaliacao-desempenho.sql`, RI-5.3):
  factores só no servidor (`avaliacao_modelo`); escrita só por
  `bsp_avaliacao_gravar` / `bsp_avaliacao_conhecimento`; histórico mensal
  dos RH em `desempenho_historico`; Equipa → `AvaliacaoPainel`.
- Subsídio de produtividade (03-10-2026, `produtividade.sql`, RI-5.3): regra
  do ficheiro dos RH «Apuramento_Subs Produtividade» (notas 1–3 por objectivo;
  média até 1,6 = 50%, até 2,6 = 75%, acima = 100%; a pagar = subsídio × %),
  calculada no servidor (`bsp_produtividade_calcular`) e repetida no ecrã
  (`bspProdPercentagem`): mudar as duas juntas. Tabelas `produtividade_pessoas`
  (por número BRP; `user_id` só quem tem conta), `produtividade_mensal`
  (Rascunho → Aprovado → Pago), `produtividade_objectivos` (catálogo, só no
  servidor). Escrita só por `bsp_produtividade_gravar` / `_estado` / `_pessoa`.
  Quem vê (07-10-2026, `produtividade-acesso.sql`, Elmar: «só o próprio, o
  superior e a gestão»): `bsp_produtividade_trata` = gestão, o superior
  (`bsp_aprovador_de`) e, para quem não tem conta, o chefe da área
  (`bsp_superior_area`); o mesmo no histórico (`desempenho_historico`). Nunca
  voltar a dar acesso a quem só edita a escala da área.
  Ao aprovar, o mês entra em `desempenho_historico` (fonte `apuramento`), que a
  avaliação anual lê. Equipa → `ProdutividadePainel`. Valores nunca no repositório.
  Salários (03-10-2026, `salarios-privados.sql`, Elmar: «Salários são
  particulares, só eu e a Arlete vimos»): qualquer valor pago (subsídio, total,
  pagamento dos médicos) só para `bsp_ve_salarios()` / `bspVeSalarios` = u1 e u2,
  nunca pela camada. As colunas com Kz não se lêem pela tabela (privilégio por
  coluna); só `bsp_produtividade_valores`. Os outros vêem notas e percentagens.
- Pagamento dos médicos (03-10-2026, `pagamento-medicos.sql`): Equipa →
  «Pagamento dos médicos» (`PagamentoMedicosPainel`), só u1 e u2
  (`bsp_pagamento_acesso` = `bsp_ve_salarios`). Comissões das facturas do MetaGest pelo
  `practitioner_name` (= chave do Query Report) e pelas regras de Julho de 2026
  (`bsp_pagamento_linhas` classifica; cardiologia pelo nome do item);
  permanências e consultas da ficha lançadas à mão (`pagamento_permanencias`,
  `pagamento_ajustes`; a ficha prevalece); `bsp_pagamento_calcular`,
  `bsp_pagamento_fechar` (Fechado → Pago, guarda o mapa). Cadastro com NIF e
  IBAN só no servidor (`prestadores`).
  Farmácia e indicação: base à mão (o MetaGest não as diz). Conferido com
  Julho de 2026: laboratório e enfermagem iguais ao cêntimo.
  Regras do mapa de Agosto (04-10-2026, `pagamento-medicos-regras.sql`):
  ecografia por dia da semana em `taxa_eco_dias` (adenda; sobrepõe-se à
  `taxa_eco`), outros nomes do MetaGest em `chaves_extra` (contam como a
  chave, também no `bsp_pagamento_detalhe`), nutrição como especialidade.
  As fichas de presença podem faltar: o mapa calcula-se na mesma e o médico
  aparece em `pendencias.sem_presencas` / `sem_presenca`.
  Fichas completas (05-10-2026, `pagamento-fichas.sql`): entrada, saída e
  quantidades por dia em `pagamento_permanencias`, gravadas só por
  `bsp_pagamento_fichas` (as consultas da ficha vão para os ajustes);
  `bsp_pagamento_conferir` (ficha × MetaGest), `bsp_pagamento_actos` (sem
  doentes). «Excel do mês» e «Mapas individuais» saem do ecrã (`bspPagExcel`,
  `bspPagMapasZip`). Mapas para o banco (07-10-2026, `pagamento-banco.sql`, Elmar:
  «o formato deve ser sempre esse; BAI-BAI e outros bancos, nunca junte»):
  `bspPagMapaBanco` faz o .xls (SheetJS, `vendor/sheetjs`) igual ao «Template de
  Pagamentos Médicos do BAI» (Início, Movimentos, Motivos escondida), com a data
  do dia em que se tira; BAI = código 0040 no IBAN; ordem clínica geral/medicina
  interna, pediatria, outros. NIB a debitar só no servidor (`pagamento_banco`,
  `bsp_pagamento_banco`, u1 e u2): nunca no repositório.
  Por etapas (07-10-2026, `pagamento-etapas.sql`, Elmar: «vou pagar por etapas»;
  «os pagos tenho de validar no perfil de cada um»): `pagamento_etapas` (mapa do
  banco e pago por médico e mês), só por `bsp_pagamento_etapas` /
  `bsp_pagamento_etapa`, u1 e u2. O mapa do banco leva só os médicos escolhidos
  (caixa na lista; sem escolha, os que não estão pagos nem noutro mapa) e regista a
  etapa; «Validar pago» e «Imprimir mapa individual» na ficha de cada médico
  (`bspPagEtapa`). Taxas de permanência: 15.000, 20.000 ou 25.000. Médico «off» =
  `activo = false`, nunca apagar.
  Presenças (05-10-2026, `medicos-presencas.sql`): a Recepção marca «Chegou»/«Saiu»
  (`PresencasMedicos`, Utentes e Início) por `bsp_presenca_marcar`, com hora do
  servidor; correcções ficam com `corrigido_por`. Vão para `pagamento_permanencias`;
  o `bsp_pagamento_fichas` actualiza sem apagar quem marcou.
- Funcionário do Mês (20-10-2026, `funcionario-mes.sql`, pedido da Arlete;
  Elmar: «Votação: dias 17 e 18; apuramento e divulgação: dia 23»): Equipa →
  `FuncionarioMesPainel`. Tudo no servidor (`bsp_fm_estado`, `bsp_fm_votar`,
  `bsp_fm_equipa`: 120 dias de vínculo por `fm_pessoas.admissao` ou criação da
  conta, `impedido_ate` sem motivo); votos só para o apurador u1/u2
  (`bsp_fm_votos`), que também regista os de papel; apuramento a 23
  (`bsp_fm_apurar`, empate → «Atitude», depois `bsp_fm_decidir` da Direcção).
  Mudar os dias = mudar `bsp_fm_votar`, `bsp_fm_estado` e os crons `bsp-fm-*`.
  No Início de todos (30-10-2026): `FuncionarioMesInicio` (último vencedor, convite a
  votar, empate só para quem apura), sobre o mesmo `bsp_fm_estado`.
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
  Duas aprovações (06-10-2026, `ferias-duas-aprovacoes.sql`, Elmar: «1.º o Dr.
  Osvaldo, depois a Arlete RH»): 1.º passo do superior gravado no pedido
  (`superior_id` = `bsp_aprovador_de`: campo `superior`, senão o chefe da área;
  chefes clínicos e radiologistas com `superior` u14), marcado em
  `superior_ok_em` (o estado fica «Pedido»: a regra `ausencias_estado_check`
  não muda); 2.º passo de `final_id` = `bsp_aprovador_final_de` (campo
  `aprovaFerias` na equipa, senão os RH, `bsp_ferias_rh` = u2;
  `ferias-aprovacao-final.sql`: a Juliana tem Arlete → Elmar; o Dr. Osvaldo só
  o Elmar). Quem pediu recebe janela de aviso a cada passo e, na aprovação
  final, e-mail com os RH em cópia (`ferias-avisos-email.sql`,
  `bsp_ausencia_email_aprovado`). O u1 substitui
  em qualquer passo. Ecrã: `bspAusenciaPasso`, `bspAusenciaDecideEu`. Avisos com
  etiqueta `ferias-<id>` (sino, telemóvel, janela de avisos importantes).
  Nas funções pela ferramenta do servidor, nunca a palavra `drop` (fica à
  espera de confirmação): `create or replace trigger`, `alter policy`.
  Mapa de férias (02-10-2026, `ferias-mapa.sql`): `bsp_mapa_ferias(ano)` /
  `MapaFerias` (vista «Calendário», `CalendarioFerias`, e «Lista», 06-10-2026);
  toda a equipa vê só as férias aprovadas (pessoa e datas). Os
  outros tipos de ausência nunca entram no mapa.
- Relatórios diários (02-10-2026, `relatorios-diarios.sql`, Edge Function
  `relatorios-diarios`): Direcção 06h50 (sócios + Director, com valores) e
  áreas 07h15 (chefes, sem valores, adm@barispol.com em cópia), em vez do
  Zapier. A Imagiologia vai para a Direcção Clínica (u14, `PARA_AREA`).
  O da Clínica leva a gestão clínica de 30 dias (`direccao-clinica.sql`,
  `bsp_srv_direccao_clinica`, modelo JCI/OMS), sempre com números reais ao lado
  de cada percentagem (pedido do Elmar). Endereços extra só no servidor (`relatorios_diarios_destinos`;
  `relatorios_destinos` é dos relatórios por área, outra coisa).
  Desde a versão 12 (03-10-2026) o da Direcção leva «Satisfação e espera»
  (`bsp_srv_qualidade_direccao`).
  O da Recepção mede a qualidade do atendimento por colaborador
  (`recepcao-qualidade.sql`, `bsp_srv_recepcao_qualidade`: facturação,
  marcações, relatório de turno). Desde a versão 11 sem WhatsApp nem
  «Workspace aberto»: estão só no e-mail das 08h00 (`wa_resumo_8h`).
  Painel clínico: `PainelClinicoScreen` / `bsp_painel_clinico` sobre
  `erp.clinico_dados`; nunca Kz nem nomes de utentes.
  Auditoria (30-10-2026, `clinico-auditoria.sql`): `bsp_clinico_qualidade` junta
  espera, relatórios e turnos em falta por pessoa, segurança, satisfação, registo
  clínico por médico, pedidos à Farmácia e presenças; telemóvel por
  `bsp_clinico_alertar` (cron `bsp-clinico-alertas`). Cada chefe só a sua área. Os quadros da
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
- Avisos importantes (06-10-2026, `alertas-importantes.sql`): janela
  `AvisosImportantes` que só fecha com «Li» (`bsp_alertas_lidos`, regista quem
  e quando). Entram pela etiqueta do `bsp_push_post` (`bsp_alerta_do_push`:
  `tarefa-`, `frio-`, `vigilancia-`, `toner-`, `gerador`, `pedido-site-`) e
  pelos calculados em `bsp_alertas_por_ler` (documentos obrigatórios, tarefas
  delegadas atrasadas, «Por ligar» e marcações da Recepção). As conclusões das
  tarefas delegadas ficam fora (só sino e telemóvel, decisão do Elmar).
  Sem «Li» (07-10-2026, Elmar: «retira a opção lida sem abrirem»): só «Abrir»,
  que vai à pasta (`bspAbrirPastaAviso`, `BSP_ALERTA_PASTAS`; férias →
  Equipa → Férias e ausências) e só depois marca lido; com mais de 3, resumo
  por pasta. Um tipo de aviso novo leva a sua pasta em `bspAlertaPasta`.
  «Abrir» fecha a janela inteira (07-10-2026, Elmar: «não fecha o pop-up,
  incomoda»); os restantes ficam numa bandeira com o número na barra de cima, ao lado
  do sino (`BotaoAvisosAdiados`, 20-10-2026, Elmar: o botão no canto tapava a
  caixa do Chat; nunca voltar a pô-lo por cima do conteúdo), e só um aviso novo
  reabre a janela (`bsp-avisos-adiados`, por sessão).
- Desactivados (05-10-2026, `utilizadores-desactivar.sql`): `inactivo: true` na
  equipa + conta bloqueada (`criar-utilizador` com `desactivar`); fora das listas
  por `bspSemOcultos`, nome nas mensagens por `__bspInactivos`. Nunca apagar
  para «desactivar».
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
  decisão do Elmar); `bsp_doc_no_grupo`/`bsp_cargo_grupos_membro` no servidor e
  `bspNosGrupos`/`BSP_DOC_CARGOS` no ecrã, mudar os dois juntos. Desde
  06-10-2026 (`documentos-destino-areas.sql`, Elmar: «juntaste técnicos de
  laboratório com os da farmácia») os grupos das áreas de saúde saem do
  departamento (Técnicos de enfermagem, de laboratório, de farmácia, de
  radiologia), com o chefe da área; nunca juntar áreas num grupo. A janela
  mostra «Vão ver (N)» com os nomes antes de publicar. Fora de
  «todos», nada vai para o Feed nem #avisos.
- Registo clínico (05-10-2026, `registo-clinico.sql`): ecrã `registo`
  (`RegistoClinicoScreen`), um registo por médico e dia (`registo_clinico`,
  número `BRSP-DC-BNC-AA-nnn`, Rascunho → Submetido → Visto). Cópia do MetaGest
  em `erp.clin_consulta`/`clin_triagem`/`clin_lab`/`clin_paciente`
  (`erp.sincronizar_clinico`). Acesso só por `bsp_rc_codigos` (o próprio médico,
  Direcção Clínica, gestão); ecrã sensível. Motivo e diagnóstico vêm do
  MetaGest; rascunho só no `sessionStorage` (`bspRcRascunhoGravar`). Substitui os papéis do banco,
  «Actividades realizadas» e «Registo de pacientes».
- «A minha actividade» (30-09-2026, `minha-actividade.sql`): médicos vêem
  só a sua produção (`bsp_minha_actividade`, sem notas de crédito, igual ao
  Painel). Ligação pelo campo `metagest` (códigos `ref_practitioner`) na
  pessoa; menu só com `bspVeActividade`. Nunca abrir `erp.*` a quem entra.
  A Direcção Clínica, a gestão e quem vê o Painel escolhem o médico
  (`bspEscolheMedicoActividade`, `bsp_metagest_medicos`, membro
  `mg:<código>`), 02-10-2026. A Direcção Clínica vê os outros médicos só
  com quantidades, sem Kz (`sem_valores`, decisão do Elmar).
  Grupos pelo `bsp_mg_grupo` (19-10-2026, `minha-actividade-observacao.sql`): a
  «Sala de observação» aparece à parte da Enfermagem.
  Datas livres e serviço (03-10-2026, `minha-actividade-servicos.sql`):
  `bsp_minha_actividade(de, ate, membro, servico)`. Nos ecrãs com período,
  a opção «Escolher datas» usa sempre `DatasLivres` (com o limite de dias da
  função do servidor); o CRM passa `p_de`/`p_ate` (`crm-funil-datas.sql`).
  Espera dos doentes de cada médico (03-10-2026, `minha-espera.sql`):
  `bsp_minha_espera(de, ate, membro)`, cartão em «A minha actividade».
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
- Galeria da conversa (30-10-2026, Elmar: «está muito difícil o acesso aos
  ficheiros das conversas antigas»): botão «Ficheiros» no cabeçalho do Chat,
  `GaleriaConversa` lê do servidor todos os anexos da conversa (não só as 300
  carregadas). Um tipo novo de anexo tem de manter a marca `\u200bf`.
- Ver antes de enviar (30-10-2026, Elmar: «faz como o WhatsApp»): o clipe e o
  arrastar abrem `PreEnvioFicheiros` (rodar, nome, tirar, legenda); nada sobe
  antes de «Enviar»; os que falham ficam para «Tentar de novo».
- Anexos no chat: `enviarFicheiros(lista, opc)` no `ChatScreen` serve o
  clipe (vários ficheiros), o arrastar com o rato e as notas de voz
  (27-09-2026: `comecarGravacao`, `bspMensagemNotaVoz`, `bspEAudio`,
  `AudioAnexo`). Desde 28-09-2026 as notas gravam-se em WAV
  (`bspWavDeAmostras`), porque o WebM não tocava no iPhone. Nunca voltar
  ao `MediaRecorder` como via principal. Excepção (14-10-2026, Elmar: «erro
  ao enviar audio» no iPhone): o iOS põe o `AudioContext` em «interrupted» ao
  ligar o microfone; retoma-se em qualquer estado parado e, se em 1,5 s não
  houver som, grava-se pelo `MediaRecorder` só em MP4/AAC (`.m4a`), nunca WebM.
  Fotografias do Chat reduzidas antes de subir (`bspReduzirImagem`,
  30-09-2026); endereços assinados em lote (`bspSignedUrlEmLote`). Endereços de
  4 h guardados no separador por pessoa (`bsp-urls-<id>`, 01-10-2026, para
  não gastar tráfego; 24 h → 4 h e `sessionStorage` a 12-10-2026); nunca
  voltar a endereços de 1 h só em memória.
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
