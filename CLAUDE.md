# Barispol2026 — contexto para o assistente

Este ficheiro é lido automaticamente pelo Claude Code em cada tarefa. Tem as
regras aprovadas pelo Elmar Bravo e o estado do projecto. O passo a passo do
servidor está em `O-QUE-FALTA.md`, e esse ficheiro prevalece.

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
7. Marca: Titillium Web (com Segoe UI/Arial de recurso). Cores:
   azul-marinho #292F58 e #273069, azul #2291CE. Nos e-mails, a fonte é
   Dax (pedido do Elmar, 24-09-2026), com Titillium Web, Segoe UI e Arial
   de recurso, e o logotipo `assets/logo-barispol.png` no topo.
8. Antes de cada alteração, dizer o que se vai fazer. Depois, dizer o que
   se confirmou. Se o ecrã ou o código não corresponder ao descrito, parar
   e descrever.
9. Sempre que se mexe no código, actualizar `O-QUE-FALTA.md` na mesma
   alteração.

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
    não se muda): versão 5 (24-09-2026), verificação de JWT desligada e
    autenticação própria em `funcoes/bright-worker/index.ts`. Chave do
    servidor ou sessão de gestor: qualquer destinatário. Sessão de outro
    colaborador: só endereços de `shared_state.team` ou
    empresa@barispol.com. Chave pública: recusada.
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
- O envio de e-mail pela aplicação usa o token da sessão
  (`bspTestemunho`). O cartão é `bspEmailWrap`, igual ao `envelope` da
  `resumo-matinal`. Texto escrito por alguém passa por `bspEmailTexto`
  (sem HTML, com mudanças de linha, sem cortes).
- A `resumo-matinal` tem três tipos (campo `tipo` do corpo): resumo
  (06h30, seg–sáb), `lembrete` (07h30, todos os dias, um por pessoa pelo
  nome) e `coletivo` (12h00, seg/qua/sex, «Olá, equipa»). Registos por
  dia: `resumos_enviados`, `lembretes_enviados`, `coletivos_enviados`.
  Todos só para endereços @barispol.com (versão 7).
- Tipo `mensagens` da `resumo-matinal` (versão 8, a cada minuto): e-mail
  de mensagem directa só após 5 min sem resposta/leitura e com a pessoa
  offline (tabela `presenca`, sinal a cada minuto). Registo em
  `avisos_mensagens`. O Workspace já não envia esse e-mail directamente.
- Som das notificações: um só `AudioContext` (`bspAudio`), desbloqueado
  no primeiro toque (`bspDesbloquearSom`). Nunca criar um por aviso.
- Abrir uma conversa directa de qualquer ecrã: `bspConversaCom(id)`.
- Chamadas: `bspToqueChamada('recebida' | 'a-chamar')`, sempre com som,
  mesmo com o som das notificações desligado.
- Notificações de mensagens lidas saem com `bspSemNotifsLidas(s)`. Esta
  função só corre quando a leitura muda. Comentários do Feed (conversa
  `post-<id>`) geram notificações com `post`: abrem a publicação, nunca
  o Chat.
- Imagens abrem em `bspVerImagem(url, nome)` (o `VisorImagem`), nunca
  com `window.open`: na app, isso prende o Workspace.
- No telemóvel, `main > div` tem altura automática. O Chat é a excepção
  (classe `bsp-chat-ecra`) e abre na lista de conversas.
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
- Tarefas privadas partilhadas: coluna `partilhada_com` em
  `tarefas_pessoais` (`tarefas-partilhadas.sql`). Editar uma tarefa
  privada vai por `pess.actualizar`, nunca por `actions.updateTask`. A edição
  também muda `user_id` e `partilhada_com` (todos os da tarefa; só quem
  delega muda o dono).
- Anexos no chat: `enviarFicheiros(lista)` no `ChatScreen` serve o clipe
  (vários ficheiros) e o arrastar com o rato.

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
- Direcção e Coordenação vêem as tarefas privadas de todos e delegam
  (criam na lista de outra pessoa). Regras em `tarefas-delegar.sql`,
  função `bsp_ve_tarefas_pessoais()`, coluna `criada_por` (24-09-2026).

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
4. Departamento e cargo de 7 pessoas: Cassia Peixoto, Filomena Silva,
   Gizela Joaquim, Juliana Lourenço (Supervisora da Recepção), Paulo
   Manuel, Rosa Queirós e Solange Orlando. Ficam em `shared_state.team`.
   (Osvaldo Pacheco: Director Clínico, Clínica. Catarina Ndundu Baptista:
   eliminada a 24-09-2026.)
5. Decidir se se cria o canal `#radiologia`.
6. Tarefas a partir de e-mails, no Workspace de cada pessoa. Falta decidir
   entre uma caixa por pessoa e uma caixa partilhada; a via recomendada é
   o Power Automate.
7. Nunca testado: uma chamada entre dois aparelhos reais e a importação
   de um CSV do MetaGest.
