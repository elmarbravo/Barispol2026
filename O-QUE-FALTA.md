# O que falta fazer — por esta ordem

Uma lista só. Vá riscando. Cada passo diz o que traz e como se confirma.

> ## Para um assistente que esteja a seguir isto no navegador
>
> Regras, antes de começar:
>
> 1. **Nunca copie para a conversa nenhuma chave que comece por
>    `sb_secret_` nem por `eyJ`.** Cola-se directamente no sítio indicado
>    e mais nada. A chave `sb_publishable_` é pública e pode ser mostrada.
> 2. Faça um passo de cada vez, **confirme o resultado esperado** antes
>    de avançar, e **pare e descreva o ecrã** se aparecer algo diferente
>    do que está escrito aqui.
> 3. Não carregue em «Disable JWT-based API keys» antes de os passos 0.1 a
>    0.5 estarem confirmados. É irreversível e desliga tudo o que ainda
>    usar as chaves antigas.
> 4. As sessões necessárias: o painel do Supabase
>    ([supabase.com/dashboard](https://supabase.com/dashboard), projecto
>    *elmarbravo's Project*) e o GitHub (repositório
>    `elmarbravo/Barispol2026`). Se alguma pedir login, pare e peça à
>    pessoa que entre.

Tudo o que está no código já está no ar em `barispol.com` (no `main` deste
repositório). O que falta são passos que **só o administrador do projecto
Supabase pode dar**, porque exigem entrar no painel.

> Para quem lê isto sem contexto: o Supabase é o servidor onde vivem os
> dados. O painel é [supabase.com/dashboard](https://supabase.com/dashboard).
> O **SQL Editor** é uma página desse painel onde se colam ficheiros de
> texto e se carrega em **Run**.

---

## 0. Urgente — trocar a chave de servidor que saiu

A chave `service_role` foi enviada por mensagem no dia 3 de Setembro e por
isso deixou de ser secreta. **Enquanto não for substituída, quem a tiver lê
e apaga tudo o que está na base de dados**, incluindo ficheiros pessoais e
anexos de conversas. Vale até 2036.

O projecto já migrou para o sistema novo de chaves, por isso o caminho é:

- [ ] **0.1** Painel → Project Settings → **API Keys** → separador
      *«Publishable and secret API keys»* → copiar a chave **publishable**
      (começa por `sb_publishable_`). Esta é pública.
- [ ] **0.2** Pôr essa chave no `servidor.js`. No GitHub:
      [`elmarbravo/Barispol2026/blob/main/servidor.js`](https://github.com/elmarbravo/Barispol2026/blob/main/servidor.js)
      → ícone do lápis (*Edit this file*) → na linha que começa por
      `  key: "`, substituir **só o que está entre as aspas** pela chave
      `sb_publishable_…` → **Commit changes** → mensagem
      `Passar a chave publica para o formato novo` → **Commit directly to
      the main branch** → **Commit changes**.
      *Confirmação:* voltar a abrir o ficheiro e ver a linha `key:` com a
      chave nova. O site actualiza-se sozinho em cerca de um minuto.
- [ ] **0.3** Abrir [barispol.com/workspace.html](https://barispol.com/workspace.html)
      numa janela nova, recarregar à força (`Ctrl`+`Shift`+`R`), entrar,
      e confirmar que o Chat mostra mensagens e o Drive mostra ficheiros.
      Em **Admin → Sistema** o indicador tem de estar verde: *«Ligado ·
      tempo real activo»*. Se estiver cinzento ou vermelho, **parar** —
      a chave está errada e o passo 0.6 desligaria o site.
- [x] **0.4** ~~Criar uma chave **secret** para o resumo matinal.~~
      **Deixou de ser preciso em 24-09-2026.** O agendamento passou a
      usar um código gerado pela própria base de dados e guardado no
      cofre (Vault). Ver o passo 3.
- [x] **0.5** Instalar as duas Edge Functions do passo 2. Sem isto,
      deixam de funcionar no passo seguinte. (Podem ser instaladas já
      aqui; o passo 2 fica então feito.)
      **Feito em 11-09-2026.** As duas ficaram activas com os nomes
      exactos.
- [ ] **0.5-b** Em cada uma das três funções, separador *Settings*,
      interruptor **«Verify JWT with legacy secret»**. Este interruptor
      não estava previsto nesta lista e exige um JWT assinado pelo
      segredo antigo — coisa que deixa de existir no 0.6.
      - [x] `criar-utilizador` — desligado em 11-09-2026
      - [x] `resumo-matinal` — desligado em 11-09-2026
      - [x] `bright-worker` — desligado em 24-09-2026, ao publicar a
            versão 5 com verificação própria
            ([`funcoes/bright-worker/index.ts`](funcoes/bright-worker/index.ts)).
            Confirmado: sem autorização 401, com a chave pública 403, com
            um testemunho falso 401.
- [x] **0.5-c** Publicar as correcções de leitura de chaves nas duas
      funções e voltar a fazer Deploy de ambas. Ver a nota em baixo, no
      passo 2. **Feito em 14-09-2026** — `criar-utilizador` e
      `resumo-matinal` publicadas com o código do repositório, `sha256`
      conferido antes de cada Deploy.
- [x] **0.5-d** Teste de e-mail em Admin → Sistema, 14-09-2026: **HTTP
      200**, o Resend aceitou o envio. O envio a partir da aplicação,
      parado desde 07-09, voltou. Nota: este teste passa pela
      `bright-worker` com o testemunho da sessão, que hoje ainda é um JWT
      assinado pelo segredo antigo — é por isso que o cadeado a deixa
      passar. Depois do 0.6 deixa de passar; o 0.5-b mantém-se
      obrigatório.
- [ ] **0.5-e** Testar a leitura das chaves no plural nas duas funções.
      **`resumo-matinal`: confirmado em 24-09-2026** (`fonte_chave` =
      `SUPABASE_SECRET_KEYS`). Falta a `criar-utilizador`.
      O teste de e-mail não as exercita. O caminho mais directo é
      «Enviar o resumo matinal agora» em Admin → Sistema — mas envia
      e-mails reais a toda a equipa, por isso é decisão da Direcção.
- [ ] **0.6** Só com 0.1 a 0.5-c confirmados: *API Keys* → separador
      *«Legacy anon, service_role»* → **Disable JWT-based API keys** →
      confirmar. É neste instante que a chave que saiu deixa de valer.
      *Confirmação:* voltar ao Workspace, recarregar à força, e o
      indicador em Admin → Sistema continuar verde; depois, em
      **Admin → Sistema**, carregar em *«Enviar o resumo matinal agora»*
      e confirmar que o e-mail chega.

---

## 1. Um ficheiro SQL sem nada a preencher

- [ ] Painel → **SQL Editor** → **+ New query** → colar
      [`FALTA-CORRER.sql`](FALTA-CORRER.sql) inteiro → **Run**.

Traz: pastas na área pessoal do Drive · só quem carregou (e quem tiver a
permissão) apaga no Drive da equipa · editar a própria mensagem · a
Direcção vê as tarefas pessoais.

Pode correr as vezes que quiser. No fim aparece uma lista de colunas e
regras; entre elas têm de estar `bsp_msg_editar UPDATE` e
`bsp_tp_ler SELECT`.

---

## 2. As Edge Functions (o código que corre no servidor)

Painel → **Edge Functions** → **Deploy a new function** (ou *Create a
new function*, conforme o painel) → escolher a opção de escrever o código
no próprio painel (*via Editor*) → nome exacto → apagar o exemplo → colar
o ficheiro inteiro (no GitHub, abrir o ficheiro → **Raw** → seleccionar
tudo → copiar) → **Deploy**. Uma de cada vez.

*Confirmação:* a função aparece na lista com o nome exacto e estado
activo. Se uma delas já existir, abri-la, substituir o código pelo do
repositório e voltar a fazer Deploy.

| Nome exacto | Ficheiro | Para quê | Estado |
| --- | --- | --- | --- |
| `criar-utilizador` | [`funcoes/criar-utilizador/index.ts`](funcoes/criar-utilizador/index.ts) | Criar logins a partir de Admin → Utilizadores | **nunca foi instalada** — sem ela, acrescentar alguém não lhe cria conta |
| `resumo-matinal` | [`funcoes/resumo-matinal/index.ts`](funcoes/resumo-matinal/index.ts) | O e-mail da manhã | **nunca foi instalada** |
| `bright-worker` | [`funcoes/bright-worker/index.ts`](funcoes/bright-worker/index.ts) | Enviar e-mails | instalada; versão 5 com verificação própria desde 24-09-2026 |

- [ ] `criar-utilizador`
- [ ] `resumo-matinal`

As duas podem ser instaladas antes ou depois do passo 0.

> **Correcção de 11-09-2026.** Aqui dizia-se que as duas funções aceitavam
> tanto as chaves antigas como as novas. Não era verdade. O código
> procurava `SUPABASE_SECRET_KEY` e `SUPABASE_PUBLISHABLE_KEY`, no
> singular. O Supabase injecta `SUPABASE_SECRET_KEYS` e
> `SUPABASE_PUBLISHABLE_KEYS`, no plural e com um dicionário JSON lá
> dentro. As funções aguentavam-se apenas pela segunda tentativa do
> código, que caía nas variáveis antigas — as mesmas que o passo 0.6
> apaga. No dia do 0.6 as duas passariam a responder *«A função não tem as
> chaves do projecto»* com HTTP 500.
>
> Os ficheiros já estão corrigidos neste repositório: leem os nomes no
> plural, tratam-nos como JSON e mantêm os antigos como recurso durante a
> transição. **É preciso voltar a fazer Deploy das duas** para que a
> correcção chegue ao servidor.

> **Resolvido em 24-09-2026** (versão 5, verificação de JWT desligada).
> Aceita a chave do servidor e a sessão de um gestor, para qualquer
> destinatário. A sessão de outro colaborador só envia para endereços de
> `shared_state.team` ou para `empresa@barispol.com`, que são os avisos
> que a aplicação manda (mensagens directas, tarefas, mural). A chave
> pública e os testemunhos falsos são recusados. O painel passou a
> mostrar o nome `bright-worker` em vez de `notify-email`; o endereço é
> o mesmo. O texto seguinte fica como registo.
>
> **A `bright-worker` não verifica quem a chama.** Recebe destinatário,
> assunto e corpo, e envia. O interruptor do painel é a única barreira, e
> essa cai no 0.6. Além disso, desde que o `servidor.js` passou a levar a
> chave publicável, o Workspace chama-a com uma chave que o interruptor
> recusa: o envio de e-mails a partir da aplicação está parado desde esse
> momento, e sem dar erro visível. O que fazer está em
> [`funcoes/bright-worker-ACRESCENTAR-verificacao.md`](funcoes/bright-worker-ACRESCENTAR-verificacao.md).

---

## 3. O resumo matinal — agendado sem chave secreta

- [x] **Feito em 24-09-2026, directamente no servidor**, com
      [`agendar-resumo-sem-chave.sql`](agendar-resumo-sem-chave.sql).
      Não há nada para colar:
      - a base de dados gerou um código aleatório e guardou-o no cofre
        (Vault), com o nome `bsp_resumo_agendamento`;
      - o agendamento `bsp-resumo-matinal` vai buscá-lo ao cofre no
        momento em que corre e envia-o no cabeçalho `x-bsp-agendamento`.
        O código não fica escrito no agendamento;
      - a função `resumo-matinal` (versão 5) confere-o pela
        `bsp_resumo_codigo_confere`, que só a chave do servidor pode
        chamar e que responde apenas sim ou não.

      O agendamento antigo, com `<PROJECTO>` por preencher, foi
      substituído. O `agendar-resumo.sql` já não é preciso. A chave
      service_role continua a ser aceite, por isso quem o correr com a
      chave não estraga nada.

      *Confirmado em 24-09-2026:* com o código certo, HTTP 200 («O resumo
      de hoje já tinha saído», porque o dia foi marcado antes do teste
      para não sair correio). Com um código errado, HTTP 403.
      `fonte_chave` = `SUPABASE_SECRET_KEYS`.

- [x] **Os e-mails em si.** A função pede cada envio à `bright-worker`
      com a chave nova (`sb_secret_…`). Até 24-09-2026 a `bright-worker`
      tinha a verificação de JWT ligada e recusava-a. **Resolvido no
      mesmo dia**: a `bright-worker` versão 5 aceita a chave do servidor.
- [ ] **Confirmar o primeiro envio real** na manhã de 25-09-2026, com a
      consulta em baixo: `pessoais` e `deEquipa` acima de zero e sem
      `falhas`. Não foi testado antes para não mandar correio à equipa.

Sai às 06h30 de Luanda, de segunda a sábado. Para ver como correu:

```sql
select status_code, content, created from net._http_response
order by created desc limit 5;
```

---

## 3-b. Avisos a toda a equipa por e-mail (24-09-2026)

Pedido pelo Elmar em 24-09-2026. Feito directamente no servidor, com o
bloco 4 do [`agendar-resumo-sem-chave.sql`](agendar-resumo-sem-chave.sql)
e a `resumo-matinal` versão 6.

- [x] **Lembrete diário** (`bsp-lembrete-diario`): 07h30 de Luanda,
      todos os dias, domingo incluído. Um e-mail por pessoa, tratada pelo
      primeiro nome: entrar no Workspace, e o aviso de que em breve
      deixaremos de usar o WhatsApp para a comunicação interna.
- [x] **Aviso colectivo** (`bsp-aviso-coletivo`): 12h00 de Luanda,
      segunda, quarta e sexta. A mesma mensagem para todos («Olá,
      equipa»), com o mesmo aviso sobre o WhatsApp. Sai um e-mail por
      endereço, para ninguém ver os endereços dos colegas. Os dias foram
      escolhidos pelo assistente; mudam-se na linha do `cron.schedule`.
- [x] **Só para endereços @barispol.com** (decisão do Elmar, 24-09-2026,
      `resumo-matinal` versão 7). Vale para o resumo, o lembrete e o
      colectivo. Das 22 pessoas, 17 têm endereço da clínica; as 5 com
      endereço pessoal (Gmail, Hotmail) deixam de receber estes e-mails,
      mas continuam na equipa e nas listas de tarefas.
- [x] Cada tipo tem o seu registo por dia (`lembretes_enviados`,
      `coletivos_enviados`), para não sair duas vezes.
      *Confirmado em 24-09-2026:* os dois tipos respondem HTTP 200 com o
      código do agendamento (o dia foi marcado antes, para não sair
      correio).
- [ ] **Confirmar os primeiros envios reais**: lembrete a 25-09 às 07h30;
      colectivo a 25-09 (sexta) às 12h00. Consulta: `select status_code,
      content from net._http_response order by created desc limit 5;` —
      `lembrados` deve ser 17 e sem `falhas`.

**Novo visual de todos os e-mails** (resumo, lembrete, colectivo e os da
aplicação: mural, mensagens directas, tarefas, testes): logotipo do site
(`assets/logo-barispol.png`) no topo, linha azul #2291CE, texto em
#292F58, botão #273069, rodapé com «Clínica Barispol, Lda. · NIF
5000999687». Fonte Dax, pedida pelo Elmar, com Titillium Web, Segoe UI e
Arial de recurso: a Dax só aparece a quem a tiver instalada.

**Datas exactas em todo o lado** (pedido do Elmar, 24-09-2026): chat,
mural, notificações, «Actividade recente», Drive — sempre «24 set 2026,
13:41». Antes via-se «agora», «há 12 min» ou só a hora.
- As publicações e os ficheiros da equipa guardavam a palavra «Agora»
  em vez da data. Passaram a guardar o instante (`iso`, `criado`).
- Cópias antigas guardadas no aparelho recebem a data do servidor quando
  este as volta a enviar.
- A «Actividade recente» usa as publicações do servidor (iguais em todos
  os aparelhos, com data). As entradas antigas sem data, gravadas só com
  «agora», deixam de aparecer.
- O único ficheiro do Drive da equipa sem data recebeu a data do
  armazenamento (1 set 2026, 17:10).
- **Chat (24-09-2026, segunda volta):** as mensagens não mostravam data
  nenhuma. O cabeçalho usava o campo antigo `ts` (só a hora, ou vazio nas
  cópias guardadas no aparelho). Agora: data exacta em cada mensagem,
  separador entre dias («Quinta-feira, 24 de Setembro de 2026») e as
  mensagens seguidas só se agrupam no mesmo dia e com menos de 10
  minutos entre elas. Meses com maiúscula (Set, Setembro).
  *Confirmado* num browser de teste, com o tamanho de telemóvel e de
  computador, com mensagens de exemplo de três dias.
- **Erro corrigido:** o código que regista se o «tempo real» está ligado
  estava colado no canal das chamadas, onde o `syncRef` não existe. Dava
  «syncRef is not defined» a cada mudança de estado, e a verificação
  periódica nunca abrandava. Passou para o canal do chat e só mexe na
  cadência da verificação periódica.
- Por confirmar num aparelho real: abrir o Workspace e ver a
  «Actividade recente» e o chat com datas.

**Mural:** o e-mail de uma publicação cortava o texto aos 400 caracteres
e juntava os parágrafos numa linha. Passou a levar o texto inteiro, com
as mudanças de linha (`bspEmailTexto` no `workspace.html`).

---

## 3-c. Direcção e Coordenação vêem e delegam tarefas (24-09-2026)

Pedido do Elmar. Aplicado no servidor com
[`tarefas-delegar.sql`](tarefas-delegar.sql).

- [x] As tarefas privadas (`tarefas_pessoais`) eram só do dono: nem a
      Direcção as via, apesar de o Workspace dizer o contrário. Agora a
      Direcção e a Coordenação vêem as de todos, criam na lista de outra
      pessoa (delegam), movem e apagam. Os colegas da Clínica e das
      Operações continuam a ver só as suas.
- [x] Nova função `bsp_ve_tarefas_pessoais()`, com a mesma lógica da
      `bsp_e_gestor`, lida na camada da pessoa (`podeVerTarefasPessoais`).
      As camadas gravadas passaram a ter essa opção ligada na Direcção e
      na Coordenação e desligada nas outras.
- [x] Coluna `criada_por`: quem delegou. Ninguém consegue gravar uma
      tarefa em nome de outro.
- [x] No Workspace: «Tarefa privada» com o campo «Para quem» para a
      Direcção e a Coordenação; e-mail à pessoa a quem se delega; o cartão
      mostra de quem é e quem a delegou.
- *Confirmado no servidor em 24-09-2026*, dentro de uma transacção
  desfeita no fim: a Direcção delega a alguém das Operações; essa pessoa
  vê a tarefa; outro colega das Operações não a vê; alguém das Operações
  que tente delegar é recusado.
- [ ] Por confirmar num aparelho real: delegar uma tarefa e vê-la no
      telemóvel da pessoa.

---

## 3-d. Envio de 24-09-2026 à tarde

- [x] **E-mails programados enviados agora**, a pedido do Elmar: lembrete
      e aviso colectivo, 17 destinatários cada, sem falhas (HTTP 200). É a
      primeira prova do caminho completo: agendamento → função →
      `bright-worker` → Resend.
- [x] **Aviso por e-mail das mensagens directas só depois de 5 minutos,
      sem resposta e com a pessoa offline** (pedido do Elmar). Aplicado
      com [`avisos-mensagens.sql`](avisos-mensagens.sql) e a
      `resumo-matinal` versão 8 (tipo `mensagens`, agendamento
      `bsp-avisos-mensagens` a cada minuto).
      - O Workspace deixou de enviar o e-mail no momento da mensagem.
      - Presença: com o Workspace aberto e à vista, a aplicação regista
        «estou aqui» a cada minuto (tabela `presenca`). Sem sinal há mais
        de 2 minutos = offline.
      - Resposta ou recibo de leitura do destinatário na mesma conversa =
        já viu, não há e-mail.
      - Várias mensagens do mesmo colega vão num só e-mail. O que já foi
        tratado fica em `avisos_mensagens` (as 124+ mensagens que já
        existiam foram marcadas, para não sair nenhum aviso atrasado).
      - Só para endereços @barispol.com.
      - Limpeza semanal (`bsp-limpeza-registos`, domingo 03h00 UTC).
      - *Confirmado:* a função responde HTTP 200 com 0 avisos.
      - [ ] Por confirmar com duas pessoas reais: mandar uma mensagem a
        alguém com o Workspace fechado e ver o e-mail 5–6 minutos depois.
- [x] **Som das notificações dentro da plataforma.** Criava-se um som novo
      a cada aviso, e os browsers bloqueiam som que não venha de um toque
      da pessoa: não se ouvia nada. Agora há um só leitor de som,
      desbloqueado no primeiro toque ou clique na página, e o volume
      subiu de 7% para 25%. No iPhone, o botão de silêncio lateral
      continua a calar o som.
      - [ ] Por confirmar num aparelho real (o browser de teste não aplica
        o bloqueio de som).
- [x] **Botões sem acção:** no painel do contacto de uma conversa
      directa (ligar, vídeo, e-mail) e no Directório (mensagem, chamada,
      vídeo). Agora ligam, abrem a conversa ou o e-mail. *Confirmado* num
      browser de teste.

---

## 3-e. Relatórios padrão por área (24-09-2026)

Pedido do Elmar: relatórios de escolha múltipla por área, com base nos
e-mails diários que cada área envia (lidos na caixa do Elmar: Laboratório,
Raio-X, Farmácia, Enfermagem, fechos da Recepção, e as análises
automáticas por área de info@barispol.ao).

- [x] Novo ecrã **Relatórios** (menu lateral; no telemóvel em «Mais»).
      Cinco formulários: Recepção / Caixa, Farmácia, Laboratório,
      Imagiologia (Raio-X e Ecografia), Enfermagem. Quase tudo escolha
      múltipla e contagens; uma observação curta opcional. Nunca pede
      nomes de utentes. As perguntas estão em `BSP_RELATORIOS`, no
      `workspace.html`.
- [x] O formulário abre na área da pessoa (pelo cargo e departamento).
- [x] Tabela `relatorios_area` ([`relatorios-area.sql`](relatorios-area.sql)):
      cada pessoa vê os seus; a Direcção e a Coordenação vêem todos, por
      dia, com a lista das áreas **em falta**. Só se envia em nome
      próprio. *Confirmado no servidor* (transacção desfeita): autor vê,
      em nome de outro recusado, colega não vê, Direcção vê.
- [x] *Confirmado* num browser de teste (telemóvel e computador): o
      formulário marca as escolhas e não deixa enviar com respostas em
      falta.
- [x] **Quem lê** (decisão do Elmar, 24-09-2026): a Direcção Geral
      (Elmar) e a Coordenação (Arlete) lêem tudo; a **Direcção Clínica —
      Osvaldo Pacheco (u14)** — lê Laboratório, Imagiologia e Enfermagem;
      cada pessoa lê os seus. A **Arlete recebe cada relatório por
      e-mail** (`BSP_RELATORIOS_EMAIL`). No servidor:
      `bsp_le_areas_medicas()`. *Confirmado* (transacção desfeita): o
      Osvaldo vê o Laboratório e não a Recepção; uma médica não vê.
- [x] Ficha do Osvaldo: cargo «Director Clínico», departamento «Clínica».
      A camada continua «Operações» (mudar mexe noutras permissões; fica
      para decisão do Elmar).
- [x] **Catarina Ndundu Baptista eliminada** (decisão do Elmar,
      24-09-2026). Já tinha saído da lista da equipa; a conta de acesso
      (criada e usada só a 29-08-2026, sem ficheiros) foi apagada.
      *Confirmado:* 21 pessoas na equipa, 21 contas, nenhuma conta fora da
      equipa.
- [ ] Por decidir: se os anexos (Excel, PDF das requisições) passam a ir
      pelo Drive.
- [ ] A Solange e a Gizela (Farmácia) estão sem departamento: o
      formulário abre-lhes pela Recepção até isso ser preenchido.

---

## 3-f. App Android (24-09-2026)

- [x] O fluxo «App Android» falhava em todas as execuções: o
      `android-actions/setup-android@v3` pedia o pacote `tools`, que já
      não existe nas `cmdline-tools` 16.0. Corrigido em
      `.github/workflows/app-android.yml` (`packages: 'platform-tools'`).
- O APK de teste não precisa da chave de assinatura: sai a cada
  alteração do site, em Actions → «App Android» → Artifacts. A chave
  (`app/lojas/PUBLICAR.md`, passos 1.1 e 1.2, só o Elmar) só é precisa
  para a Play Store.
- Atenção: o APK de teste é assinado com uma chave de depuração que muda
  a cada compilação. Para instalar uma versão nova, pode ser preciso
  desinstalar a anterior.
- [x] **A app actualiza-se sozinha** (decisão do Elmar, 24-09-2026). Em
      `app/capacitor.config.json`, `server.url` passou a
      `https://barispol.com/workspace.html`: a app abre o site, e cada
      alteração chega aos telemóveis sem instalar nada. Sem internet
      aparece `sem-ligacao.html` (criada pelo `sincronizar.js`), com
      «Tentar de novo». O APK instala-se **uma vez**; só é preciso outro
      se mudar a parte nativa (ícone, permissões, nome).
- Quem instalou o APK 1.15 ou anterior tem de instalar uma vez o
  seguinte, porque esses ainda levavam a cópia fixa do site.
- A sessão da app antiga não passa para a nova: é preciso entrar outra
  vez com e-mail e palavra-passe.
- [ ] Por confirmar num Android real: entrar, receber mensagens, fazer
      uma chamada (microfone) e ver a página sem internet.

---

## 3-g. «As mensagens aparecem codificadas» (Arlete, 24-09-2026)

- No servidor as mensagens estão em texto normal. O que aparece
  «codificado» são as linhas internas (recibos de leitura, edições,
  reacções), que as versões anteriores deixavam passar.
- [x] Filtro `bspLinhaDeControlo` também nos tópicos, no contador de
      respostas, na pesquisa do chat e nos comentários do mural.
- [x] As notificações antigas gravadas no aparelho com o texto dessas
      linhas («l745», «e747A Neusa…») saem ao abrir o Workspace.
      *Confirmado* num browser de teste.
- [ ] Pedir à Arlete que recarregue à força (computador: Ctrl+Shift+R;
      telemóvel: fechar o separador e reabrir). Se continuar, pedir uma
      captura do sítio onde aparece.

---

## 3-h. iPhone: ecrã principal (24-09-2026)

- [x] O `workspace.html` passou a ter o ícone da Barispol
      (`assets/icone-app.png`, o mesmo da Play Store, com fundo branco) e
      as marcas para o iPhone abrir em ecrã inteiro com o nome «Barispol».
      Antes, «Adicionar ao ecrã principal» ficava com uma miniatura da
      página e abria com a barra do Safari.
- [x] Imagem com os passos para a equipa:
      [`instalar-no-iphone.png`](instalar-no-iphone.png), também em
      `barispol.com/instalar-no-iphone.png`.
- Quem já tinha adicionado o atalho antes tem de o apagar e adicionar de
  novo para ficar com o ícone.

---

## 3-i. Menções com «@» no chat (24-09-2026)

- [x] O «@» não fazia nada: o botão só escrevia o símbolo. Agora, ao
      escrever «@» (ou carregar no botão), aparece a lista das pessoas da
      conversa, filtrada pelo que se escreve («@ar» → as Arletes).
      Escolhe-se com o toque, o rato, as setas, Enter ou Tab; entra
      «@Nome Apelido», realçado a azul na mensagem.
- [x] Quem é mencionado recebe o aviso como «Menção» («mencionou-o em
      #geral»), em vez de «Mensagem».
- *Confirmado* num browser de teste: «@ar» mostra as duas Arletes;
  Enter escreve «@Arlete Tatiana »; o botão «@» abre a lista.
- [ ] Por confirmar com duas pessoas reais: a notificação de menção.
- [x] Feed: o texto das publicações passou a mostrar ligações clicáveis e
      imagens por ligação (como o chat). Publicado no Feed, a pedido do
      Elmar, o comunicado «Workspace no iPhone» com a imagem dos passos.

---

## 3-j. Comunicado do iPhone, anexos e registo de actividade (24-09-2026)

- [x] Comunicado «Workspace no iPhone» publicado no Feed e enviado por
      e-mail, com a imagem **anexada**, aos 17 colaboradores @barispol.com
      (a pedido do Elmar). O primeiro envio conjunto bateu no limite da
      Resend (10 por segundo): 6 foram reenviados à parte.
- [x] `bright-worker` versão 7: aceita o código do agendamento (como o
      servidor) e **anexos**, só do servidor e só de ficheiros do próprio
      site (`https://barispol.com/...`).
- [x] Admin → Registo de actividade: apagadas as 4 entradas inventadas que
      estavam no código («editou escala», «aprovou contrato»…). Mostra só
      actividade real, com data exacta (publicações do servidor e acções
      deste aparelho com data). O botão «Exportar» passou a descarregar
      um CSV.
- Atenção a envios em lote pela Resend: no máximo 10 por segundo. A
  `resumo-matinal` envia um de cada vez, por isso não é afectada.

---

## 3-k. Telemóvel, chamadas com som, notificações e imagens (24-09-2026)

- [x] **Notificações lidas saem da lista.** Uma notificação de mensagem
      ou menção sai quando a conversa dela já não tem nada por ler. Se
      ler noutro aparelho, sai também neste (pelo recibo de leitura).
- [x] **Comentários no Feed** (os parabéns à Funcionária do Mês): a
      notificação abria o Chat num canal «#post-17» que não existe.
      Agora abre o Feed na própria publicação, com os comentários à
      vista. O mesmo vale para as notificações de novas publicações.
- [x] **Chamadas com som.** Quem recebe ouve um toque logo, e depois a
      cada 3 segundos, com vibração no Android. Quem liga ouve o sinal
      de chamada. Toca mesmo com o som das notificações desligado.
- [x] **Imagens do chat:** abrem num visor dentro do Workspace, à medida
      do ecrã, com «Fechar» e «Guardar». Fecham também com o botão
      Voltar do Android. Antes abria-se o original numa janela nova, e
      na app isso substituía o Workspace sem forma de voltar. As imagens
      do Feed abrem no mesmo visor.
- [x] **Telemóvel:** o Chat abre na lista de conversas (como no
      WhatsApp) e tem uma seta para voltar. A conversa ocupa o ecrã, com
      a caixa de escrever sempre em baixo (antes o cartão encolhia à
      altura do texto). Sino com o número de notificações no topo.
- [x] **CRM (Seguimento) no telemóvel:** estava só na barra lateral do
      computador. Passou a estar em «Mais», com o título certo no topo.
- [x] **Eliminar relatórios:** botão «Eliminar» em cada relatório
      recebido, com confirmação. Aparece a quem o servidor deixa apagar
      (`bsp_rel_apagar`): o autor, no próprio dia; a Direcção e a
      Coordenação, sempre. Se o servidor recusar, a pessoa vê o aviso.
- [x] Reposta a função `bspBrowserNotify` (aviso do sistema com a página
      escondida). Foi apagada por engano no envio do som, mais cedo no
      mesmo dia, e cada mensagem recebida dava erro a seguir ao som.
- [ ] **Avisos com a app fechada** (como o WhatsApp): ainda não. Precisa
      de notificações push. No Android isso passa pelo Firebase Cloud
      Messaging: um projecto Firebase da clínica, criado pelo Elmar, e o
      ficheiro `google-services.json` na app. No iPhone (ecrã principal)
      usa-se Web Push, que o iOS 16.4 ou superior aceita. Até lá, o
      e-mail após 5 minutos offline (3-d) cobre as mensagens directas.
- [ ] Confirmar num telemóvel real: o toque de uma chamada a entrar e a
      sair, e o visor de imagens na app Android.

---

## 3-l. Projecto Supabase novo (24-09-2026)

O Workspace passou para o projecto **Barispol** (`gnqleaxrtuerlcrriqqs`,
eu-west-3), numa organização nova. O `servidor.js` aponta para ele e
apaga dos aparelhos a ligação antiga guardada.

Verificado no projecto novo, a 24-09-2026 às 23h40:
- [x] Tabelas do Workspace, 21 utilizadores, Vault com o código do
      agendamento e a chave da Resend.
- [x] Funções activas: `bright-worker`, `resumo-matinal`,
      `criar-utilizador`.
- [x] Agendamentos `bsp-…` (resumo, lembrete, colectivo, avisos de
      mensagens, limpeza) apontam para o projecto novo. 32 chamadas em
      30 minutos, todas com resposta 200.
- [x] Os ficheiros SQL deste repositório passaram a apontar para o
      projecto novo.
- [ ] Apagar a função `mig-recebe` (Edge Functions → mig-recebe →
      Delete) quando a cópia dos ficheiros do Drive acabar. Só aceita
      pedidos com o código da migração, que caduca a 27-09-2026, mas
      grava ficheiros e palavras-passe.
- [ ] Confirmar no painel da organização antiga que o projecto
      `ferqkmfntcockmhviscf` está pausado, ou que os agendamentos `bsp-…`
      estão desligados. Se não estiverem, a equipa recebe os e-mails da
      manhã a dobrar.
- [ ] 25-09-2026: confirmar os envios da manhã em `net._http_response`
      do projecto **novo**.

---

## 3-m. Site novo e caixa de contacto (25-09-2026)

O barispol.com foi refeito no estilo de empresa internacional (skill
site-humanizado-corporativo):
- fundo claro, com faixas escuras só no topo, numa chamada e no rodapé;
- listas com linhas finas, texto sem travessões nem gerúndios;
- menu «Menu» no telemóvel;
- fotografias reais: a sala de espera vazia e a fachada.

O `index.html` gera-se com `ferramentas/gerar-site.py` a partir de
`ferramentas/modelo-site.html`. Para mudar serviços, análises, seguros
ou perguntas, editar o gerador e correr
`python3 ferramentas/gerar-site.py`.

**Caixa de contacto:** o paciente escreve o que quiser e a mensagem
chega por e-mail a **geral@barispol.com**, o endereço que os pacientes
usam (decisão do Elmar, 25-09-2026). O WhatsApp fica como alternativa.
- [x] Tabela `contactos_site` (`contactos-site.sql`), aplicada no projecto
      novo. Só a Direcção e a Coordenação lêem. Limpeza ao fim de 12
      meses (`bsp-limpeza-contactos`).
- [x] Função `contacto-site` (`funcoes/contacto-site/index.ts`), versão 4,
      sem verificação de JWT e com protecções próprias:
      - só aceita pedidos de barispol.com;
      - tem um campo escondido que só os robôs preenchem;
      - aceita 3 mensagens por hora por ligação e 30 por hora no total.
      Envia só para geral@barispol.com e nunca escreve ao paciente.
- [x] Testado a 25-09-2026: origem errada recusada (403), robô ignorado,
      mensagem sem contacto recusada, mensagens «TESTE» enviadas.
- [ ] **Envio pelo SMTP da caixa (opcional):** o Elmar cola no painel
      (Edge Functions → Secrets) `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS` e,
      se preciso, `SMTP_PORT` = 465 e `SMTP_FROM`. As funções **não podem
      usar as portas 25 e 587**. Sem os segredos, sai pela Resend, de
      geral@barispol.com.

**Seguros e planos de saúde:** a lista vem da facturação do MetaGest
(`crm.mg_facturas`, grupo de cliente «Seguradora», desde 2022) e do que
o Elmar confirmou. São 22 nomes. Ficam de fora:
- o BNA e o Fundo de Pensões do BNA (por decisão do Elmar);
- a Quinta do Pinhão e os Funcionários da Barispol;
- a Caixa Social de Catoca, a SONILS (sem facturas desde 2024) e
  clientes particulares ou empresas que não são seguradoras.
A Medicare foi confirmada pelo Elmar, mas não aparece na facturação.
- [ ] Confirmar a Medicare e se a Caixa Social de Catoca deve entrar.
- [ ] Fotografias da equipa e dos serviços, com autorização. A fotografia
      da sala de espera com utentes **não** se usa: mostra pessoas e
      crianças identificáveis.
- [ ] Rever `contacto.html` e `ecografia.html` no mesmo estilo.

---

## 3-n. Apresentação do Workspace (25-09-2026)

Só muda o aspecto. Ficam iguais as funções, as regras, o servidor, as
notificações e os dados.
- [x] Cores oficiais: marinho #292F58 e #273069, azul #2291CE, fundos
      neutros claros. Estão nas variáveis e nas cores escritas no código.
- [x] Tipo de letra Dax, com Titillium Web, Segoe UI e Arial de recurso.
- [x] Sem gradientes nem círculos de brilho: entrada, faixa do Início,
      cartão de reconhecimento e gráficos passam a cores lisas. Os ecrãs
      de chamada ficam como estavam.
- [x] Sem animação ao mudar de ecrã. Cartões, janelas e botões com
      cantos mais discretos. Os botões principais passam a marinho, que
      se lê melhor que o branco sobre o azul claro.
- [x] Entrada: sai a grelha decorativa. A etiqueta passa a «Workspace da
      equipa». Saem os números inventados (38 colaboradores e 8
      departamentos; a equipa tem 21 pessoas).
- [x] Verificado em computador e telemóvel: sem erros. As menções, as
      notificações e o visor de imagens funcionam como antes.

---

## 3-o. WhatsApp (SendPulse) a cada 15 minutos (25-09-2026)

- [x] O agendamento `whatsapp-sync` corre a cada 3 minutos e traz as
      mensagens novas. A lista de contactos com actividade nova passou a
      ser pedida à SendPulse **a cada 15 minutos**, em vez de a cada hora
      (`whatsapp-sync-15min.sql`, função `whatsapp.cron_sync`). Uma
      mensagem nova aparece no Workspace no máximo cerca de 15 minutos
      depois.
- [x] Confirmado a 25-09-2026: a pergunta de contactos correu sozinha às
      10h21, sem erros. A mensagem de teste do Elmar das 10h04 chegou.
- Só lê dados da SendPulse. Não envia mensagens e não usa inteligência
  artificial.

---

## 3-p. Chat, tarefas e calendário (25-09-2026)

- [x] **Chat:** vários ficheiros de uma vez pelo clipe (até 10, 25 MB cada)
      e arrastar com o rato para a conversa. Aparece a faixa «Largue aqui
      os ficheiros» e um aviso «A carregar N ficheiros».
- [x] **Tarefas com prazo:** campo «Prazo (opcional)» nas tarefas da
      equipa e nas privadas. O cartão mostra «Prazo: 30 Set 2026», a
      vermelho e com «em atraso» quando já passou.
- [x] **Tarefa privada para várias pessoas:** a Direcção e a Coordenação
      escolhem uma ou mais pessoas. Com várias, a tarefa é partilhada.
      Os outros colegas podem partilhar as suas tarefas privadas. Todos os
      que estão na tarefa a vêem e actualizam. Só o dono, a Direcção e a
      Coordenação a apagam. Coluna `partilhada_com` e regras em
      `tarefas-partilhadas.sql`, testadas a 25-09-2026: o dono vê, muda e
      apaga; quem partilha vê e muda, mas não apaga; um terceiro não vê.
- [x] Corrigido: editar uma tarefa privada não gravava, porque ia para o
      quadro da equipa.
- [x] **Eventos numa data:** no «Novo evento», «Todas as semanas» (a
      regra, opção C) ou «Numa data». Os com data só aparecem na semana
      dessa data, e há a lista «Próximos com data». A `resumo-matinal`
      (versão 3 no projecto novo) só os anuncia nesse dia.
- [ ] Confirmar num aparelho real: arrastar ficheiros no chat e criar uma
      tarefa partilhada entre duas pessoas.

---

## 3-q. Listas por ordem alfabética (25-09-2026)

- [x] Por ordem alfabética:
      - **Pessoas**, em todo o lado: chat, mensagens directas, membros,
        menções, Directório, Administração e escolha de pessoas nas
        tarefas. Nas tarefas, «Eu» continua em primeiro.
      - **Departamentos, canais, categorias dos eventos e áreas dos
        relatórios.**
      - **Opções dos menus:** estados do CRM, departamento de um grupo
        novo, pastas do Drive, estilo, densidade e presença.
      - **Opções de ordenar do Drive:** «Maiores», «Mais recentes»,
        «Nome». A ordenação por omissão continua «Nome».
- Ficam na ordem natural, porque a têm: dias da semana, meses, horas,
  colunas do quadro (A Fazer → Concluído), prioridades, períodos do CRM
  («Há mais de 3 meses»…), camadas de acesso (por hierarquia), a
  actividade (por data) e a lista de seguimento do CRM (por prioridade:
  quem não volta há mais tempo).
- Função `bspCompararTexto` / `bspPorNome` (português, sem distinguir
  acentos nem maiúsculas).

---

## 3-r. Canais de área pela função (25-09-2026)

- [x] Cada canal de área é só de quem trabalha nessa área, pelo
      departamento da pessoa (a função):
      - #clínica: médicos;
      - #enfermagem: enfermeiros;
      - #farmácia: farmácia;
      - #laboratório: laboratório;
      - #radiologia: radiologia;
      - #recepção: recepcionistas e a supervisora.
      #laboratório e #radiologia são novos.
- [x] Vêem todos os canais de área: a Direcção e a Coordenação. A
      Direcção Clínica (Osvaldo Pacheco) vê todos os da saúde: clínica,
      enfermagem, farmácia, laboratório e radiologia.
- [x] #geral, #avisos e #escalas: toda a gente, como antes.
- [x] **Regra também no servidor** (`canais-por-funcao.sql`,
      `bsp_ve_conversa`, `bsp_area_chave`, `bsp_minha_area`). Antes, o
      servidor deixava qualquer colega ler os canais de área e só o ecrã
      os escondia. Matriz testada a 25-09-2026, pessoa a pessoa, igual no
      servidor e no Workspace.
- [x] Nicolau Castigo (analista de laboratório): departamento
      Laboratório.
- [x] Emmanuel Domingos: departamento **Serviços Gerais**, responde à
      Arlete Tatiana (campo `superior` = u2, mostrado no Directório).
- Os ajustes à mão antigos que retiravam alguém do canal da própria
  área (por exemplo, a Rosa Simão no #farmácia) deixam de contar: a
  função manda. «Dar um canal» no Admin (`extraCanais`) continua a
  funcionar.
- [ ] Decidir se os Serviços Gerais precisam de um canal próprio.


## 3-s. CRM legível no telemóvel (25-09-2026)

No telemóvel, cada pedido do CRM tinha duas colunas. Os botões (estado,
WhatsApp, telefone, menu e nota) ocupavam quase toda a largura. O nome e
a data ficavam numa coluna estreita, uma palavra por linha, e a data
ficava por baixo do estado.

- Abaixo de 640 px a linha (`bsp-crm-linha`) passa a uma só coluna:
  texto em cima, botões por baixo numa linha (`bsp-crm-accoes`). O
  distintivo do estado some no telemóvel, porque o menu já o mostra.
- A data do CRM (`bspCrmQuando`) passa a usar `bspDataExacta`:
  «25 Set 2026, 13:50», como no resto do Workspace.
- O computador fica igual.
- Confirmado com Playwright a 390 px e a 1366 px, com dados fictícios:
  texto com 336 px de largura, sem deslocamento horizontal, sem erros.


## 3-t. Campanhas do site com hora de fim e cartaz (25-09-2026)

Pedido do Elmar: pôr no site a campanha Outubro Rosa e retirá-la a
31-10-2026 às 20h00.

- `index.html` e `ferramentas/modelo-site.html`: o `fim` de
  `campanhas.json` aceita hora («2026-10-31T20:00:00+01:00»). Só com a
  data, a campanha sai no fim do dia, hora de Luanda. Campo novo
  `imagem`: o cartaz no topo do cartão.
- Confirmado com Playwright: às 19h59 de Luanda a campanha aparece, às
  20h00 desaparece.
- Publicada no mesmo dia com o texto oficial do SharePoint
  (08_MARKETING, «COPYS CAMPANHAS CHECK-UP E OUTUBRO ROSA 2026.txt»):
  consulta de ginecologia a 12.450 Kz (em vez de 24.900) e 50 % nas
  análises complementares, de 1 a 31 de Outubro. Sai a 31-10-2026, 20h00.
  Campos novos `itens` e `cor`; a secção subiu para logo abaixo da
  abertura.
- Cartaz (post 4x5 do feed, enviado pelo Elmar na conversa):
  `assets/outubro-rosa.webp`, 960×1200, 75 KB. No computador fica à
  esquerda do texto; no telemóvel, por cima. Campo `imagemAlt` para o
  texto alternativo.
- Texto: a legenda oficial do post (secção 5 do ficheiro de textos),
  sem emojis nem hashtags. `resumo` e `fecho` aceitam vários parágrafos.
- Links para partilhar: `https://barispol.com/outubro-rosa`
  (`outubro-rosa.html`: pré-visualização com o cartaz
  `assets/outubro-rosa.jpg` no WhatsApp e nas redes, depois leva a
  `/#campanhas`) e `https://barispol.com/#campanhas` (o site desce até à
  secção quando esta aparece). Confirmado com Playwright no telemóvel e
  no computador.
- [ ] Depois de 31-10-2026: apagar `outubro-rosa.html` e
      `assets/outubro-rosa.*`, e tirar a entrada de `campanhas.json`.
- [ ] Confirmar com a recepção que o desconto está criado no MetaGest
      (nota do ficheiro de textos).


## 3-u. Editar tarefas privadas (25-09-2026)

O Elmar não conseguia editar a tarefa privada «Cobrança ADV». O servidor
deixa (teste desfeito: 1 linha mudada) e o ecrã gravava título, coluna,
prioridade e prazo, mas o formulário não tinha as pessoas e não dizia
que tinha gravado.

- Editar uma tarefa privada mostra «Para quem» (Direcção e Coordenação)
  ou «Partilhar com» (o dono), já preenchido com o dono (`user_id`) e
  `partilhada_com`. Só o dono e quem delega mudam as pessoas.
- `pess.actualizar` pede as linhas de volta: sem linhas, avisa que não
  há permissão. Depois de gravar aparece «Tarefa actualizada.».
- O campo do prazo deixa de ficar mais largo no iPhone.
- Confirmado com Playwright a 390 px: o pedido leva
  `partilhada_com: ["u2"]` quando se junta a Arlete; título e prazo com
  310 px; testes anteriores iguais.


## 3-v. Agenda por dia, semana, mês e ano; tarefas editáveis por todos os da tarefa (25-09-2026)

- Calendário: escolha Dia · Semana · Mês · Ano, setas ‹ › e «Hoje».
  `AgendaDia`, `WeekGrid` (agora com a data de cada dia), `AgendaMes` e
  `AgendaAno`. Um evento semanal aparece em todas as datas desse dia da
  semana; um evento com data, só nessa data (`bspEventoNaData`). No Ano,
  o destaque marca só os eventos com data. Carregar num mês abre o Mês;
  num dia, o Dia. A vista fica guardada no aparelho
  (`bsp-agenda-vista`); no telemóvel começa em Dia.
- Tarefas privadas: todos os que estão na tarefa (dono, partilhada,
  Direcção e Coordenação) editam tudo depois de criada, pessoas
  incluídas. Quem não delega mantém o dono e fica na tarefa.
- Confirmado com Playwright a 390 px e a 1366 px: as quatro vistas sem
  deslocamento horizontal, Ano → Mês → Dia, setas, «Hoje»; testes
  anteriores iguais.


## 3-w. Escolher a ordem das listas (25-09-2026)

As listas abrem por ordem alfabética (3-q), mas agora cada uma tem
«Ordenar:» para mudar. `bspOrdenar(lista, modo, campos)`, `useOrdem` (a
escolha fica guardada no aparelho, `bsp-ordem-<lista>`) e `OrdemSelect`.

- Drive: nome A–Z / Z–A, mais recentes / mais antigos, maiores / menores.
- Directório: nome A–Z / Z–A, departamento A–Z / Z–A, cargo. A pesquisa
  do Directório passou a funcionar (antes não fazia nada).
- CRM · Pedidos do WhatsApp: mais recentes / antigos, nome, mais tempo
  sem resposta. CRM · Recuperar utentes: há mais / menos tempo, nome,
  mais visitas. CRM · Fichas: nome, última vez, mais vezes.
- Admin → Utilizadores: nome A–Z / Z–A, cargo, departamento, acesso,
  aniversário (Jan–Dez), e caixa de procura. O «Exportar CSV» sai com
  todos, na ordem escolhida. As contas de segurança (não tirar o último
  administrador) usam sempre a equipa toda, nunca a lista filtrada.
- Campos vazios ficam sempre no fim.
- Confirmado com Playwright; testes anteriores iguais.


## 3-x. Modo escuro no Workspace e no site (25-09-2026)

- Workspace: Tweaks → Aparência → Tema (Claro, Escuro, Automático) e
  botão da lua/sol na barra de cima (computador e telemóvel). Guardado no
  aparelho (`bsp-tema`), aplicado antes de desenhar (sem clarão branco).
  `html[data-tema="escuro"]` troca as variáveis (`--bg`, `--surface`,
  `--text-…`, `--border`, `--navy`); variáveis novas `--navy-texto`,
  `--texto-sobre-pastel`, `--scroll`. O logotipo leva um círculo branco.
  Por omissão fica claro.
- Site (`index.html` e `ferramentas/modelo-site.html`): botão da lua no
  cabeçalho, guardado em `bsp-site-tema`. Variáveis novas `--titulo`,
  `--ligacao`, `--topo`, `--campo`, `--campo-borda`. A abertura, a chamada
  e o rodapé continuam em marinho. Por omissão fica claro.
- Confirmado com Playwright (Início, Chat, Feed, Drive, Calendário,
  Tarefas, CRM, Relatórios, Admin, janela de nova tarefa; site no
  telemóvel e no computador): sem erros nem deslocamento horizontal.
- [ ] `contacto.html` e `ecografia.html` ainda têm o estilo antigo e não
      têm modo escuro (entram quando forem refeitas).


## 3-y. Assunto da caixa de contacto com os serviços do MetaGest (26-09-2026)

O menu «Assunto» do site tinha 7 opções. Passa a 27, em quatro grupos,
com o que tem factura no MetaGest nos últimos 12 meses
(`crm.mg_factura_itens`, `erp.sales_invoice_item`, `crm.mg_consultas`):

- Análises clínicas: geral e os 8 grupos do site (check-up, grávida,
  pré-operatório, febre, diabetes, mulher, homem, admissão).
- Consultas: clínica geral, medicina interna, pediatria, ginecologia e
  obstetrícia, cardiologia, urologia, ortopedia, dermatologia,
  psicologia, nutrição.
- Exames: ecografia, raio-X, electrocardiograma, Holter ou MAPA.
- Outros: enfermagem, farmácia interna, ainda não sei, outro assunto.

Ficam de fora os grupos sem movimento num ano: banco de urgência
(último em Abr 2025), cirurgia (último em Ago 2025), otorrino (2022).
A função `contacto-site` aceita qualquer assunto até 80 letras (o mais
longo tem 43). Confirmado com Playwright.


## 3-z. Caixa de contacto: rececao@ com geral@ em cópia e e-mail novo (26-09-2026)

- `contacto-site` versão 5 (publicada): envia para
  **rececao@barispol.com** com **geral@barispol.com em cópia** (antes só
  geral@). O remetente continua geral@barispol.com; o e-mail do paciente
  entra como «responder a».
- Aspecto igual ao do site novo: cabeçalho com logotipo e «Camama,
  Luanda», fundo branco, linhas finas, cantos rectos, título = assunto,
  data exacta de Luanda, tabela de dados, mensagem com filete azul,
  botões «Responder a <nome>», «Ligar» e «WhatsApp», rodapé marinho com
  morada, horário e NIF.
- Confirmado: teste real (origem «teste», id 4) chegou às 11:05 com
  Para: rececao@barispol.com e Cc: geral@barispol.com.


## 3-aa. Todos os e-mails com o aspecto do site (26-09-2026)

O desenho da caixa de contacto (3-z) passa a todos os e-mails: fundo
branco sobre cinzento claro, linhas finas, cantos rectos, cabeçalho com o
logotipo pequeno e «Centro Médico Barispol / Workspace da equipa»,
etiqueta azul, título marinho de 24 px, botão marinho recto e rodapé
marinho com «Clínica Barispol, Lda. · NIF 5000999687». Três sítios, a
mudar sempre juntos:

- `workspace.html` → `bspEmailWrap` / `bspEmailBotao` (tarefas, Feed,
  relatórios, testes do Admin). A etiqueta sai do destino (Tarefas, Feed
  do Workspace, Relatórios…).
- `funcoes/resumo-matinal` → `envelope` (versão 4, publicada): resumo da
  manhã, lembrete diário, aviso à equipa, mensagens por ler.
- `emails-aspecto-site.sql` → `bsp_envelope` (relatórios do WhatsApp) e,
  dentro de `wa_resumo_8h`, `wa_alerta_historico` e `bsp_wa_tabela`, o
  cinzento antigo e os cantos redondos. Aplicado.
- Confirmado: a `resumo-matinal` v4 correu às 10:42 sem erro; teste
  enviado só ao Elmar («[Teste] Novo aspecto dos e-mails do Workspace»).
- Aprovado pelo Elmar a 26-09-2026.
- [ ] Os e-mails do próprio Supabase (repor a palavra-passe, confirmar
      conta, convite, ligação de entrada, mudar e-mail) têm modelos no
      painel. Estão prontos em `emails-supabase/` (ver o `LEIA-ME.md`):
      o Elmar cola-os em Authentication → Emails. Daqui não se consegue
      gravar a configuração de autenticação.


## 3-ab. Tarefa concluída não fica «em atraso» (26-09-2026)

O cartão da tarefa pintava de vermelho «em atraso» todas as tarefas com
prazo passado, mesmo em «Concluído» (lia `t.done`, que nunca existe). O
quadro passa agora `concluida` ao `TaskCard`: em «Concluído» mostra só o
prazo. Confirmado com Playwright: a mesma data passada aparece «em
atraso» em «A Fazer» e sem aviso em «Concluído».


## 3-ac. Marcações dentro do Workspace (26-09-2026)

Pedido do Elmar: as marcações dentro do Workspace, só para a Recepção, a
Direcção Clínica e a gestão. A primeira via (a planilha do SharePoint
aberta dentro do Workspace) não abria; o Elmar pediu outra forma, com os
dados no Supabase e CSV.

- Tabela `marcacoes` (`marcacoes.sql`, aplicado): dia que contactou,
  data marcada, hora, sexo, acto médico, nome, contacto, médico,
  entidade (Particular, Seguro, Cartão), seguradora, rececionista, estado
  (Agendada, Confirmada, Compareceu, Faltou, Cancelou, Remarcado),
  observações, origem, quem criou e quem alterou. Regras:
  `bsp_ve_marcacoes()` = gestão (`bsp_e_gestor`), Direcção Clínica
  (`bsp_le_areas_medicas`) ou área Recepção (`bsp_minha_area`). Só a
  gestão apaga. Testado no servidor (teste desfeito): Juliana e Osvaldo
  lêem e criam, não apagam; Elmar apaga; Domingos e Rosa não vêem nada.
- Ecrã «Marcações» (`MarcacoesScreen`, `useMarcacoes`, `MarcacaoModal`):
  períodos (hoje, amanhã, semana, 30 dias, mês, ano) ou um dia, procura,
  filtro por estado, lista por dia, estado a mudar na própria linha,
  botão WhatsApp, nova marcação e edição. Actualiza a cada minuto.
- «Importar CSV»: a planilha antiga, guardada como CSV no Excel. Lê os
  blocos de cada mês (cabeçalho repetido), datas dd/mm/aaaa ou do Excel,
  CSV em UTF-8 ou Windows-1252; não repete o que já existe (mesma data,
  hora e nome). Os dados vão do aparelho directamente para o Supabase e
  não passam pelo repositório.
- «Exportar CSV»: o que está no ecrã, com as colunas da planilha, para
  abrir no Excel.
- Confirmado com Playwright (servidor simulado) no computador e no
  telemóvel: criar, mudar estado, importar (4 linhas, 1 repetida fora,
  2 vazias ignoradas), exportar.
- [x] Importadas a 26-09-2026, directamente no servidor, as marcações de
      Agosto e Setembro da «MARCAÇÕES - 2026 (reformulado).xlsx»: 143
      linhas, 141 marcações (2 estavam nas duas folhas). Estado vazio com
      «CANCELADO» na observação passou a Cancelou; o resto vazio ficou
      Agendada. Nomes de médicos e rececionistas uniformizados pela folha
      LISTAS. O registo da migração foi limpo (os dados ficam só na
      tabela). Agosto: 36 agendadas, 28 compareceram, 8 canceladas, 1
      remarcada. Setembro: 22, 33, 8, 3 faltas, 1 remarcada. Outubro: 1.
- [ ] Janeiro a Julho: só estão na «MARCAÇÕES - 2026.xlsx» (66 MB), que
      o conector não consegue ler. No Excel: Ficheiro → Guardar como → CSV
      (uma folha de cada vez) e «Importar CSV» no ecrã; ou copiar esses
      meses para uma planilha pequena no SharePoint e pedir a importação.
- [ ] Confirmar com a Recepção as marcações antigas que ficaram
      «Agendada» sem estado na planilha.
- [x] Marcações ligadas à ficha (27-09-2026, `marcacoes-ficha.sql`,
      aplicado). Colunas `email` (validado no servidor), `paciente_id`
      (MetaGest) e `tel9` (calculada do contacto).
      1. A ficha do paciente (`crm_ficha`) traz as marcações do mesmo
         telefone ou paciente, só a quem vê as Marcações
         (`ve_marcacoes`); botão «Ficha» em cada marcação para quem vê o
         CRM. O Osvaldo (u14) vê as Marcações mas não o CRM: sem botão.
      2. «Compareceu» automático: `bsp_marcacoes_comparecer()`, agendada
         em `bsp-marcacoes-metagest` (04h30 UTC, depois da sincronização
         do MetaGest). Só Agendada/Confirmada; `alterado_por` = 'MetaGest'
         e o ecrã mostra «✓ confirmado pelo MetaGest». Conferido antes:
         36 das 61 «Compareceu» manuais batem com o MetaGest e nenhuma
         das 21 canceladas/faltas/remarcadas. Primeira execução: 14
         marcações passaram a Compareceu.
      3. Nova marcação: `bsp_marc_sugerir(q)` sugere pacientes do MetaGest
         e de marcações anteriores pelo nome ou telefone; escolher liga à
         ficha (`paciente_id`) e preenche contacto, e-mail e sexo (estes
         dois vêm de marcações anteriores: o MetaGest não os tem).
      4. E-mail do paciente: campo com verificação, aviso «sem e-mail» nas
         marcações Agendada/Confirmada, botão «Sem e-mail» e contagem
         «Com e-mail: x de y». Entra e sai no CSV.
      Testado no servidor (teste desfeito): Juliana e Elmar sugerem e vêem
      as marcações na ficha; Osvaldo sugere, sem ficha; Domingos nada;
      e-mail inválido recusado. Ecrã testado no computador e telemóvel.
- [x] Valor pago (27-09-2026): `bsp_marc_valores(de, ate)` devolve, por
      marcação já passada, o total facturado pelo MetaGest ao paciente no
      dia marcado e os actos com o preço de cada um. Só para quem vê as
      Marcações e o CRM (Recepção e gestão). Conferido: 50 marcações com
      valor, a soma dos actos bate com o total de cada factura. No ecrã,
      «Pago … Kz · actos»; no CSV, a coluna «VALOR PAGO (KZ)». Novidade
      registada para 28-09 às 05h00 (Recepção e gestão).
- [x] E-mail ao paciente (28-09-2026): texto aprovado pelo Elmar. Não sai
      quando se faz a marcação: sai na véspera (ver 3-aj).
- [ ] Com `paciente_id`, o «Compareceu» usa só esse paciente; sem ele usa
      o telefone, e uma família com o mesmo número pode dar um falso
      Compareceu. Escolher o paciente na sugestão evita isso.


## 3-ad. Cópias de segurança (26-09-2026)

O projecto Supabase está no plano gratuito: não há cópias automáticas que
se possam repor. Base de dados: 133 MB; ficheiros do Drive: 91 MB.

- Feito: `copias-diarias.sql` (aplicado). Todas as noites às 03h00 de
  Luanda (`bsp-copia-diaria`), `bsp_copia_diaria()` copia as tabelas do
  Workspace (shared_state, messages, posts, tarefas_pessoais, marcacoes,
  relatorios_area, relatorios_destinos, contactos_site, utentes,
  seguimentos, ficheiros_pessoais e a lista do storage) para o esquema
  `copias` (`copias.<tabela>_AAAAMMDD`) e guarda 7 dias. Primeira cópia a
  26-09-2026: 12 tabelas, 1,3 MB. O esquema não está exposto na API.
  WhatsApp e MetaGest ficam de fora: voltam a vir das origens.
- Isto protege contra um apagamento ou um erro, não contra perder o
  projecto. Falta uma cópia fora do Supabase:
- [ ] Opção A: plano Pro do Supabase (cópias diárias de 7 dias).
- [ ] Opção B: ligação ao Microsoft 365 (aplicação no Entra ID com acesso
      só ao site da Recepção/Direcção; o Elmar cola o segredo). Serve
      também para ler a planilha das marcações de hora a hora até a
      Recepção passar só para o Workspace.

---

## 4. Em cada aparelho

- [ ] Recarregar à força (telemóvel: fechar o separador e reabrir;
      computador: `Ctrl`+`Shift`+`R`). Sem isto a página velha continua
      a mostrar «agora» em todas as notificações e a esconder o resto.
- [ ] Recriar os grupos privados que se perderam. Foram criados num
      telemóvel enquanto ele estava em «modo local» e nunca chegaram ao
      servidor. Uma vez, em qualquer aparelho, chega.

---

## 4-b. O calendário — o que era e o que passou a dizer

O ecrã de Início contava 2 eventos «hoje» e o Calendário respondia «0
eventos agendados» no mesmo dia. Não era cache. São duas contas
diferentes sobre os mesmos dados:

- Um evento não tem data. Guarda `title`, `day` (0 a 6, de Segunda a
  Domingo), `time`, `dur` e `cat`. Nada mais. Cada evento repete-se todas
  as semanas no mesmo dia.
- O Início pegava nos primeiros cinco eventos da lista inteira, sem
  filtro, e chamava-lhes «hoje».
- A lista «Próximos eventos» era ordenada só pela hora, misturados todos
  os dias da semana.
- A variável chama-se `todayEvents` mas guarda todos os eventos. O ecrã
  de Início leu o nome à letra.

**Decisão de 12-09-2026:** assumir a rotina semanal e dizê-lo no ecrã, em
vez de acrescentar datas. Ficou assim:

- No Início, «Próximos eventos» passou a «Rotina da semana», e cada linha
  mostra o dia (`Qua · 11:00`).
- O resumo deixou de dizer «hoje» e diz «na rotina da semana».
- No Calendário, o título passou a «Rotina semanal da equipa», com uma
  nota por baixo do quadro «Hoje» a explicar que os eventos se repetem
  todas as semanas e que não há datas.

Fica por decidir, se um dia for preciso marcar consultas em dias certos:
acrescentar campo de data, navegação entre semanas e números de dia na
grelha, com migração dos eventos que já lá estão.

---

## 4-c. Verificação de 23/24-09-2026 (feita directamente no servidor)

- A regra `bsp_msg_editar` (passo 1) não existia: editar a própria
  mensagem falhava em silêncio. **Aplicada em 23-09-2026.** As restantes
  regras do `FALTA-CORRER.sql` já estavam no servidor.
- **O resumo matinal nunca saiu.** O agendamento `bsp-resumo-matinal`
  falhava todas as manhãs com `invalid URL "<PROJECTO>/functions/v1/..."`:
  o `agendar-resumo.sql` foi corrido com os campos por preencher.
  **Substituído em 24-09-2026** por um agendamento sem chave secreta
  (passo 3). A `bright-worker` passou a ter verificação própria no mesmo
  dia, com o interruptor de JWT desligado.
- 21 pessoas no directório, 21 contas: ninguém fica sem acesso.
- 9 pessoas sem departamento e com o cargo «Colaborador(a)» — por
  preencher em Admin → Utilizadores.
- No telemóvel, as janelas (editar utilizador, novo evento…) ficavam por
  baixo das barras de cima e de baixo, e o botão Guardar escondido.
  Passaram a abrir em ecrã inteiro no telemóvel.
- Departamento **Radiologia** acrescentado. O departamento que uma pessoa
  já tem nunca desaparece da lista ao editar, mesmo que não esteja entre
  os previstos.
- O botão Chat (barra de baixo no telemóvel e barra lateral no computador)
  passou a mostrar quantas mensagens estão por ler, somando os canais que
  a pessoa vê e as suas conversas directas.
- No chat apareciam textos como «l745» ou «e747A Neusa não tem perfil».
  São linhas internas (recibo de leitura, edição, reacção) que a aplicação
  grava na tabela das mensagens e devia esconder. Quando a mesma linha
  chegava duas vezes — pelo tempo real e pela sondagem — a segunda passava
  sem filtro. Passaram a ficar sempre escondidas, e deixaram de contar para
  o número de mensagens por ler.

---

## 5. Por testar a sério (nunca foi feito)

- [ ] **Uma chamada entre dois aparelhos reais.** A lógica foi verificada,
      mas uma chamada precisa de dois telemóveis e ninguém a fez ainda.
      Se a imagem vier desfocada numa rede fraca, o passo seguinte é o
      servidor TURN (Admin → Sistema).
- [ ] **Importar um CSV pequeno do MetaGest** no Seguimento.

---

## 6. Fora do alcance deste repositório

- **A app nas lojas — já não é «fora do alcance».** O GitHub compila a
  app Android sozinho, na nuvem. O passo a passo, escrito para ser
  seguido no navegador, está em
  [`app/lojas/PUBLICAR.md`](app/lojas/PUBLICAR.md): primeiro a app nos
  telemóveis da equipa (hoje), depois a Play Store. O iPhone continua a
  depender de uma conta Apple paga e de configuração adicional; está lá
  explicado, com a alternativa.
- **Chamadas de grupo.** Duas pessoas ligam-se directamente; três ou mais
  precisam de um servidor a misturar som e imagem. Não se resolve com
  código: é um serviço a contratar (JaaS, do Jitsi, é o mais directo).

---

## Como saber se está tudo bem

No **SQL Editor**, a consulta mais útil de todas — mostra quem entra com
um e-mail diferente do que está no directório, que é a causa de quase
todos os «não vejo isto»:

```sql
select e->>'name' as pessoa, lower(e->>'email') as no_directorio,
       (select 1 from auth.users a where lower(a.email) = lower(e->>'email')) as tem_conta
from shared_state s, jsonb_array_elements(coalesce(s.team,'[]'::jsonb)) e
where s.id = 1
order by 3 nulls first, 1;
```

Quem aparecer com `tem_conta` vazio não vê mensagens directas, anexos nem
tarefas pessoais. Corrigir o e-mail em Admin → Utilizadores resolve na
hora.

O guia completo, com os erros conhecidos e o que cada um quer dizer, está
em [`LIGAR-SERVIDOR-Supabase.md`](LIGAR-SERVIDOR-Supabase.md).


## 3-ae. Novidades do sistema (27-09-2026)

Pedido do Elmar: avisar os grupos afectados por cada actualização, uma vez
por dia às 05h00, só quando há novidades.

- Tabela `novidades` (`novidades.sql`, aplicado): título, texto
  (parágrafos separados por linha em branco), `grupos` e `destino` (ecrã
  do Workspace). Grupos: `todos`, `gestao`, `direccao-clinica`, uma área
  (`bsp_area_chave`: `recepcao`, `enfermagem`, `laboratorio`…) ou um id
  (`u12`). Só a gestão cria, muda e apaga, e só antes de enviada.
- Agendamento `bsp-novidades` (04h00 UTC = 05h00 de Luanda) chama a
  `resumo-matinal` com `"tipo": "novidades"` (versão 5 da função,
  27-09-2026). `bsp_novidades_reclamar()` marca as por enviar como
  enviadas e devolve, por pessoa @barispol.com, as que lhe dizem respeito;
  sai um e-mail por pessoa com todas. Sem novidades, não sai nada.
- No Workspace, as novidades enviadas aparecem no sino (tipo «Novidade»,
  filtro «Novidades») a quem dizem respeito, uma vez por pessoa, e abrem o
  ecrã do `destino`.
- Testado (teste desfeito): grupos certos (Marcações → Recepção, Osvaldo e
  gestão; Enfermagem → só Enfermagem), segunda chamada sem envios, cada um
  vê no sino só as suas. Chamada real sem novidades: «Sem novidades por
  enviar». Ecrã testado no computador e telemóvel.
- Primeira novidade: «Marcações ligadas à ficha do paciente» (Recepção,
  Direcção Clínica e gestão). A pedido do Elmar, enviada logo a
  27-09-2026 às 12h18: 6 e-mails, sem falhas (a conta «Beb» não tem
  endereço @barispol.com e não recebe).
- [ ] Confirmar a 28-09 em `net._http_response` a resposta do tipo
      novidades (`enviados` = número de pessoas, sem `falhas`).
- Regra: cada alteração que muda o trabalho de alguém leva uma linha em
  `novidades`, com os grupos certos, na mesma alteração.


## 3-af. Notas de voz no Chat (27-09-2026)

Pedido do Elmar: enviar áudio nos chats.

- Botão do microfone ao lado do clipe (`comecarGravacao` no
  `ChatScreen`). Grava com `MediaRecorder` até 5 minutos; barra com o
  tempo, «Cancelar» e «Enviar nota». Vai como anexo da conversa onde
  começou, pelo mesmo `enviarFicheiros` (com `opc.conv` e `opc.texto`),
  com o texto «🎤 Nota de voz (m:ss).» (`bspMensagemNotaVoz`).
- Formato: WebM/Opus no Chrome, Edge e Android; MP4/AAC no Safari
  (iPhone). Ficheiro `nota-de-voz-AAAAMMDD-HHMMSS.webm|m4a`.
- Na mensagem, `AudioAnexo` mostra um leitor (`<audio controls>`) com
  endereço assinado. O WebM do Chrome vem sem duração: o leitor salta ao
  fim e volta ao início para a calcular. Se o aparelho não tocar o
  formato, aparece o cartão do ficheiro para descarregar.
- A app Android já tinha `RECORD_AUDIO` (chamadas).
- `resumo-matinal` versão 6: os e-mails de mensagem por ler mostram só o
  texto antes do anexo («🎤 Nota de voz (0:12).», «Partilhou o
  ficheiro…»), e já não o caminho interno do ficheiro.
- Testado com microfone simulado no computador e no telemóvel: grava,
  envia (cerca de 12 KB por segundo), mostra o texto e o leitor com a
  duração certa, sem erros.
- Novidade registada para toda a equipa (sai a 28-09 às 05h00).
- [ ] Testar num iPhone real: o Safari antigo (antes do iOS 17.4) pode
      não tocar as notas gravadas em WebM noutros aparelhos.

### Correcção de 28-09-2026: «O áudio no chat não se ouve»

- Causa provável: a única nota enviada (28-09, 07h06) ficou em WebM, que
  o iPhone e alguns telemóveis não tocam.
- A gravação passa a WAV (PCM 16 bits, mono, 16 kHz), que todos os
  aparelhos tocam. Lê o microfone pela Web Audio (`AudioContext` +
  `ScriptProcessor`) e monta o ficheiro em `bspWavDeAmostras`. Sobe o
  volume das gravações baixas (até 6 vezes, pico a 0,9). Ficheiro
  `nota-de-voz-AAAAMMDD-HHMMSS.wav`, `audio/wav`, cerca de 32 KB por
  segundo (5 minutos ≈ 10 MB, abaixo do limite de 25 MB).
- O `AudioContext` da gravação nasce no próprio toque, antes do pedido
  do microfone (no iPhone, criado depois, grava silêncio), e fecha-se no
  fim. O dos avisos continua a ser o `bspAudio`.
- O leitor mantém o acerto da duração para as notas WebM antigas.
- Testado com microfone simulado, no computador e no telemóvel: ficheiro
  WAV com som (pico 32645 de 32767), duração certa no leitor (2,6 s),
  sem erros.
- [ ] Confirmar com o Elmar num iPhone e num Android reais. A nota WebM
      de 28-09 pode continuar sem tocar nalguns aparelhos: aí aparece o
      cartão para a descarregar.


## 3-ag. Painel da gestão (27-09-2026)

Pedido do Elmar: um painel com gráficos para a gestão e a Direcção verem o
MetaGest em tempo real.

- `painel.sql` (aplicado): `bsp_painel(de, ate)` só para a gestão
  (`bsp_e_gestor`). Dias anteriores do histórico `crm.mg_*` (desde
  2022); hoje do `erp.sales_invoice`, que o agendamento `bsp-painel-hoje`
  vai buscar à API do MetaGest de 5 em 5 minutos, das 06h00 às 22h00 de
  Luanda (`bsp_painel_sincronizar_hoje`, cerca de 1,5 s). As duas fontes
  batem ao cêntimo (conferido em Setembro). `bsp-painel-limpeza` apaga o
  registo de sincronizações com mais de 30 dias.
- Ecrã «Painel» (`PainelScreen`, menu só para a gestão): períodos (hoje,
  ontem, 7 e 30 dias, este mês, mês anterior, este ano); facturado líquido
  com comparação com o período anterior, atendimentos (pacientes por
  dia), valor médio, facturas, em dívida e devoluções; facturação por dia
  (com tabela), por área, quem paga (particular, seguro, empresas),
  movimento por hora, consultas por médico e marcações. Com hoje no
  período, volta a ler a cada minuto. Sem nomes de doentes.
- Cores dos gráficos nas variáveis `--serie-1..4` (claro e escuro),
  validadas para daltonismo com o azul da marca em primeiro.
- Testado no servidor: Setembro em 0,3 s, o ano em 1,2 s, hoje em 4 ms;
  a Juliana (Recepção) é recusada. Ecrã testado no computador, telemóvel
  e modo escuro, sem erros.
- Limites: «Em dívida» e «Movimento por hora» só existem desde
  01-09-2026 (início do `erp`); «Consultas por médico» até ontem vem das
  consultas do MetaGest e hoje das facturas com médico.


## 3-ah. Sócios e notas de crédito (27-09-2026)

Pedido do Elmar: uma categoria de sócios que vê só números, e as notas de
crédito no Painel, a vermelho.

- Categoria «Sócio» (`socios.sql`, aplicado): camada nova com
  `soNumeros`, escolhida no Admin como as outras. No servidor
  (`bsp_e_socio`): vê o `bsp_painel`; não vê conversas
  (`bsp_ve_conversa`), Feed nem Drive; Marcações, CRM e tarefas privadas
  já eram fechadas; só recebe novidades do grupo `socios`; a
  `resumo-matinal` (versão 7) não lhe manda lembretes, resumos nem avisos
  de mensagens. No ecrã (`bspESocio`, `bspVePainel`): só o Painel, sem
  barra de baixo no telemóvel, sem pesquisa nem nova mensagem.
- Uma pessoa com categoria que já não existe nunca cai na de sócio
  (`bspCamadaBase` exclui-a), porque essa vê os números.
- Testado no servidor (teste desfeito, Domingos como sócio): vê o painel
  e as 19 notas de crédito de Setembro; 0 conversas, publicações,
  ficheiros, mensagens e marcações; a Juliana continua a ver tudo. Ecrã
  testado como sócio no computador e no telemóvel.
- Limite: o estado partilhado (equipa, tarefas da equipa, agenda) continua
  legível pela API a quem entra, porque o Workspace precisa dele para
  arrancar; o ecrã do sócio não o mostra.
- Notas de crédito no Painel: cartão a vermelho («− valor», número de
  notas), lista com data, número, factura anulada e valor a vermelho
  (8 primeiras, «Ver as N»), coluna a vermelho na tabela diária e linha a
  vermelho na caixa de cada dia do gráfico.
- Correcção (27-09-2026): a categoria estava no servidor mas não aparecia
  no Admin, porque o `socios.sql` mudou as camadas sem mudar o
  `updated_at` do `shared_state`, e os postos só relêem o estado quando
  essa data muda. `updated_at` actualizado; `bspCamadas()` junta sempre a
  «Sócio» a uma lista antiga; e a gravação do estado nunca a apaga no
  servidor. Regra: qualquer `update` ao `shared_state` feito no servidor
  tem de pôr `updated_at = now()`.
- Atalho do Painel no Início (27-09-2026, `PainelAtalho`): para quem vê
  o Painel, cartão no topo com o facturado e os atendimentos de hoje, as
  notas de crédito a vermelho quando há, e o botão «Abrir o Painel». Lê o
  servidor a cada 5 minutos. Testado no computador e no telemóvel.
- Quem vê o Painel (decisão do Elmar, 27-09-2026): só o Elmar (u1), o
  departamento Financeiro e os sócios. A gestão, por si só, deixou de o
  ver (Arlete Tatiana e «Beb» perderam o acesso). Servidor:
  `bsp_ve_painel()` (`socios.sql`), usado pelo `bsp_painel`; ecrã:
  `bspVePainel`. Departamento «Financeiro» acrescentado ao `DEPARTMENTS`.
  O ecrã passou a chamar-se «Painel financeiro». As novidades do Painel
  por enviar vão só para `u1`, `financeiro` e `socios`. Testado no
  servidor (Juliana como Financeiro e Domingos como sócio vêem; Arlete,
  «Beb», Osvaldo e Déricka não) e no ecrã (u1 vê menu e atalho; u2 e u14
  não).
- [ ] Pôr no departamento Financeiro quem trata das finanças (Admin →
      Pessoas); hoje ninguém está nele.
- [ ] Atribuir a categoria «Sócio» às pessoas certas (Admin → Pessoas).


## 3-ai. Tarefas com data de início e de fim (28-09-2026)

Pedido do Elmar: as tarefas têm de ter, obrigatoriamente, data de início
e de fim.

- «Nova tarefa» e «Editar tarefa» (`TaskComposer`) têm «Data de início»
  (hoje, por omissão) e «Data de fim», as duas obrigatórias. Sem uma
  delas, ou com o fim antes do início, não grava e diz porquê
  (`bspTarefaErroDatas`, campos em `CampoDataTarefa`).
- Tarefas da equipa: `start` e `due` em `shared_state.tasks`. Tarefas
  privadas: colunas `inicio` e `prazo` em `tarefas_pessoais`
  (`tarefas-datas.sql`).
- Servidor: o gatilho `bsp_tarefa_datas` recusa uma tarefa privada nova
  sem as duas datas ou com o fim antes do início. Mover no quadro não
  pede datas; mudar as datas pede as duas.
- As 8 tarefas privadas que já existiam receberam como início o dia em
  que foram criadas. 4 não têm fim: o cartão diz «Sem data de fim: edite
  a tarefa», a vermelho, e ao editar é preciso preenchê-lo. O quadro da
  equipa estava vazio.
- O cartão mostra «Início: … · Fim: …»; o fim fica a vermelho quando
  passou. Os e-mails de tarefa delegada ou atribuída dizem as duas datas.
- Testado no computador e no telemóvel: cartões, recusa sem fim, recusa
  com fim antes do início, gravação de uma tarefa antiga e criação de uma
  nova.
- Novidade registada para toda a equipa (sai a 29-09 às 05h00).
- [ ] Preencher a data de fim nas 4 tarefas privadas antigas.

## 3-aj. Lembrete da marcação ao paciente e fim dos grupos de WhatsApp (28-09-2026)

Pedidos do Elmar: o e-mail da marcação não sai logo a seguir à marcação;
vai para quem tem e-mail, sempre com rececao@barispol.com em cópia e com
o link do GPS. Texto aprovado («a msg está apta»).

- `marcacoes-lembrete.sql` (aplicado): tabela `marcacoes_lembretes` (um
  lembrete por marcação, data e hora; se a marcação mudar de data ou de
  hora, sai outro), `bsp_marc_lembretes_reclamar(dia)` e
  `bsp_marc_lembrete_registar` (só o servidor), e o agendamento
  `bsp-marcacoes-lembrete` todos os dias às 10h00 de Luanda (09h00 UTC)
  para as marcações Agendada/Confirmada do dia seguinte com e-mail.
- `resumo-matinal` versão 8: tipo `marcacoes` (aceita `dia` no corpo).
  E-mail com acto, data, hora, médico, chegada 15 minutos antes,
  telefones, morada e botão «Abrir o caminho no GPS»
  (https://www.google.com/maps/dir/?api=1&destination=-8.945743,13.240542,
  as coordenadas do site). Cópia para rececao@barispol.com. É a única
  excepção à regra dos envios só para @barispol.com.
- `bright-worker`: a versão publicada (3) já aceitava `cc` do servidor; o
  ficheiro do repositório estava atrasado e foi posto igual.
- Enviado a 28-09-2026 às 14h40: 1 lembrete para a marcação de 29-09
  (a única de hoje e amanhã com e-mail; a de hoje, 16h00, não tem
  e-mail). Resposta 200 da Resend.
- Lembrete diário das 07h30 e aviso colectivo: «A 1 de Outubro os grupos
  de WhatsApp da equipa deixam de existir. A partir desse dia, usem
  apenas o Workspace e os e-mails da clínica.» A 1 de Outubro diz «A
  partir de hoje…»; depois, «já não existem».
- Novidade registada para a Recepção e a gestão (sai a 29-09 às 05h00).
- [ ] O remetente continua «Barispol Workspace <geral@barispol.com>».
      Para os pacientes, «Centro Médico Barispol» seria mais claro: só
      com o acordo do Elmar.
- [ ] Confirmar a 29-09 em `net._http_response` o envio das 10h00.

## 3-ak. Escalas de serviço (28-09-2026)

Pedido do Elmar: o superior preenche a escala no Workspace e envia-a por
e-mail ou imprime-a. Modelo: «ESCALA DA RECEPÇÃO - SETEMBRO 2026.xlsx».

- `escalas.sql` (aplicado): tabela `escalas` (uma por área e mês; turnos,
  dias, notas, rascunho/publicada). `bsp_edita_escala(area)`: gestão,
  cargo de chefia na área (chefe, supervisor(a), coordenador(a),
  director(a), responsável) ou superior de alguém da área.
  `bsp_ve_escala(area)`: estes e toda a gente da área; sócios não.
  Só a gestão apaga. Testado no servidor (teste desfeito): Juliana edita
  a Recepção; Joaquina e Déricka vêem mas não mudam; Filomena só a
  Enfermagem; Elmar e Arlete todas; Osvaldo, Domingos e Emmanuel não vêem
  a da Recepção.
- A escala da Recepção de Setembro de 2026 foi importada do Excel
  (publicada): Juliana 08:00–17:45 de segunda a sexta (horário dado pelo
  Elmar a 28-09-2026: o Excel dizia 08:00–17:30); Joaquina Joice e
  Déricka Domingos 07:00–22:30, dia sim, dia não. Numa escala nova da
  Recepção e das áreas de saúde (Clínica, Enfermagem, Farmácia,
  Laboratório, Radiologia), o ecrã propõe «Chefia» de segunda a sexta
  (Recepção 08:00–17:45; saúde 07:00–15:00) e «Turno longo» 07:00–22:30
  todos os dias (`bspTurnosPadrao`; Elmar, 28-09-2026). É só o ponto de
  partida: cada chefe acerta os horários em «Turnos».
- Ecrã «Escalas» (`EscalasScreen`, menu e «Mais» no telemóvel, rota
  `#/escalas`): grelha do mês de segunda a domingo (no telemóvel, lista
  por dia), turnos com cores (`--serie-1..4`), hoje em destaque. Quem
  preenche carrega num dia e escolhe as pessoas de cada turno, com nota
  do dia e «aplicar a todas as quartas-feiras». Grava sozinho.
  - «Preencher automaticamente» (`bspEscalaPreencher`): rotação (uma
    pessoa por dia, pela ordem) ou fixo, só nos dias do turno.
  - «Continuar Setembro» (`bspEscalaContinuar`): reconhece a rotação do
    mês anterior e continua-a (Outubro começa na Joaquina, a seguir à
    Déricka de 30 de Setembro).
  - «Turnos»: nome, horas e dias da semana de cada turno.
  - Avisos (`bspEscalaAnalise`): turno sem ninguém, a mesma pessoa em
    dois turnos ao mesmo tempo, mais de 6 dias seguidos. Por pessoa:
    dias, horas e fins-de-semana.
  - «Publicar»: cada pessoa da escala (e, se se quiser, toda a área)
    recebe por e-mail os seus turnos e a escala completa; quem publica
    recebe uma cópia. `bspEmailWrap` ganhou o parâmetro `bloco`.
  - «Imprimir» (A4 deitado, uma folha, com logotipo, legenda, horas por
    pessoa e linha para assinar) e «Descarregar HTML» (`bspEscalaHtml`).
    Imprime por uma moldura escondida (`bspImprimirHtml`), sem abrir
    janela. Na app Android a impressão pode não abrir: usar
    «Descarregar HTML».
- Início: cartão «De serviço hoje» (`EscalaHojeCartao`) com as escalas
  publicadas que a pessoa pode ver.
- Testado no computador e no telemóvel com dados simulados: Setembro
  (Juliana 22 dias, agora 214h30; Joaquina e Déricka 15 dias/232h30), Outubro pela
  continuação, publicação com 4 e-mails, HTML de uma página A4. Sem erros.
- Novidade registada para toda a equipa (sai a 29-09 às 05h00).
- [ ] A Juliana preencher e publicar a escala de Outubro.
- [ ] Testar a impressão num telemóvel real.

## 3-al. «Ver como» outra pessoa (28-09-2026)

Pedido do Elmar: a Direcção vê o Workspace com os olhos de outra camada ou
de outra área.

- Botão do olho na barra de cima (computador e telemóvel), só para quem
  tem a camada Direcção ou `podeVerSistema` (`bspPodeVerComo`). Escolhe-se
  uma pessoa, ou uma camada e uma área (pessoa fictícia `u-vista`).
- A página recarrega como essa pessoa (`sessionStorage` `bsp-ver-como`;
  `bspUtilizadorVista`): menus, canais, ecrãs e permissões dela. Faixa
  em baixo «A ver como … · só leitura · Voltar a mim» (`FaixaVerComo`).
- Só leitura (`bspClienteSoLeitura`): o cliente do servidor recusa
  insert/update/upsert/delete, uploads e funções que mudam dados (só
  passam as de leitura, `BSP_RPC_LEITURA`); o estado partilhado não se
  grava; não se anuncia presença nem se liga o canal das chamadas; não
  saem e-mails nem se criam contas. Sair recarrega e descarta o que se
  mexeu.
- Limite: o servidor responde com as permissões de quem está na sessão
  (o Elmar). O ecrã filtra como a pessoa veria, mas um ecrã pode mostrar
  mais do que ela vê de facto. A faixa explica-o («O que isto mostra?»).
- Quem não é da Direcção e tenha a vista guardada sai dela sozinho.
- Testado no computador e no telemóvel: vista da Joaquina (sem Admin,
  Painel nem CRM), três gravações recusadas, regresso ao Elmar.

## 3-am. Escalas do Laboratório e dos Serviços Gerais (28-09-2026)

- Turnos que podem ficar vazios (`opcional`, caixa «Pode ficar vazio» em
  «Turnos»): não dão aviso nem aparecem vazios na grelha nem no papel.
- Pessoas sem conta no Workspace entram na escala só pelo nome (id
  `x:Nome`, campo «Nome de quem não tem conta» ao escolher pessoas). Não
  recebem e-mail.
- Laboratório, Setembro de 2026 (do PDF assinado pela Rosa Queirós e pelo
  Osvaldo Pacheco), publicada, sem e-mails: Chefia 07:00–15:45 e Chefia
  (até às 15:00) 07:00–15:00 para a Rosa; Turno longo 07:00–22:30 e Tarde
  15:00–22:30 para a Cássia e o Nicolau. No PDF, o dia 28 aparece como
  «24» e os dias 2 e 10 trazem um «2» antes do nome: lidos como gralhas.
- Serviços Gerais, Outubro de 2026 (do Excel), em rascunho: Manhã
  07:00–15:45 (duas pessoas) e Tarde 15:00–22:30, com Maria, Angelina,
  Inês e Loide, que não estão na equipa do Workspace (entram como
  pessoas sem conta).
- [ ] Decidir se Maria, Angelina, Inês e Loide entram na equipa (com
      e-mail, para receberem a escala) e publicar a de Outubro.
- Há rascunhos de Setembro feitos no ecrã: Administração e Clínica
  vazios, Enfermagem com 30 dias. Não foram mexidos.

## 3-an. Transporte (29-09-2026)

Pedido do motorista (Emmanuel, u22): reportar as rotas. Respostas do
Elmar: transporte de pessoal, amostras e compras (nunca doentes); pessoal
só de quem sai às 22:30; as rotas mudam com as pessoas de serviço.

- Feito: grupo privado `#transporte` (id `g-1790640961575`) no
  `shared_state.channels`, com Emmanuel (u22), Arlete (u2) e Elmar (u1);
  a Direcção e a Coordenação vêem os grupos privados.
- Feito (29-09-2026): `transporte.sql` (aplicado) e ecrã «Transporte»
  (`TransporteScreen`, menu só para o motorista e a gestão,
  `bspVeTransporte` / `bsp_ve_transporte`).
  - Tabelas `transporte_viagens` (tipo pessoal, amostras, compras, outro,
    casa, ligacao; km de início e fim; paragens com «deixado às» e «não
    foi»; fotografias em `privado/<motorista>/transporte/`),
    `transporte_abastecimentos` (km, litros, Kz, recibo) e
    `transporte_zonas` (bairro por pessoa, dado pessoal).
  - `bsp_transporte_saidas(dia)`: quem sai às 22:00 ou depois, pelas
    escalas publicadas de todas as áreas (o motorista não vê as escalas).
  - Hoje: «Iniciar a rota» com as pessoas das escalas e o bairro;
    «Deixado» e «Não foi» por pessoa; ordem com ▲▼; «Terminar viagem» com
    km, fotografia e ocorrências; o resumo vai para o grupo #transporte.
    Amostras, Compras, Outro serviço, Cheguei a casa e Abastecimento.
  - Se os km não continuam da última viagem, pede o motivo e regista a
    diferença como «Km entre viagens».
  - Histórico e contas por mês: km por tipo, pessoas levadas, km sem
    registo (a vermelho, entre as viagens), combustível e consumo.
  - Bairros: lista editável, só para o motorista e a gestão.
  - Histórico de 24 a 28-09-2026 carregado do WhatsApp (DAF - Relações
    Públicas): 357 km, 169 km de rotas, 51 km para casa, 137 km sem
    registo (45 + 19 + 5 + 68). A noite de 26 não trazia a lista de
    pessoas. Nomes e bairros só na base de dados.
  - Testado no telemóvel e no computador como o Emmanuel: lista das 22:30
    pelas escalas, pedido de motivo (17 km), rota com «Deixado», fim de
    viagem, contas do mês. Sem erros.
- A «Rosa (Mufulama)» do dia 24 é a Rosa Queirós (u13, Laboratório):
  corrigido na viagem e nos bairros (29-09-2026). Joana e Isabel são do
  Raio X e Afonso é enfermeiro, todos sem conta.
- Feito (29-09-2026, pedido do Elmar): alterações na rota e verificação.
  «Juntar pessoa» (`TranspJuntarModal`) com motivo; «Não foi» pede o
  motivo (`BSP_TRANSP_MOTIVOS`: por conta própria, faltou, trocou de
  turno, ficou na clínica, outro) e, se trocou ou faltou, quem ficou no
  lugar dela. Quem não está na escala publicada do dia fica marcado «fora
  da escala» (`fora_escala`). O resumo no #transporte e o histórico dizem
  «Usaram · Não usaram · Fora da escala» (`bspTranspVerificacao`), para a
  chefe da área acertar a escala. «Abastecimento» também durante a rota;
  ao gravar mostra os km e os km por litro desde o abastecimento
  anterior. Testado no telemóvel.
- [ ] Pedir ao Emmanuel que registe os abastecimentos, para haver consumo.

## 3-ao. Chat preparado para históricos do WhatsApp (29-09-2026)

Pedido do Elmar: importar as conversas dos grupos de WhatsApp para os
canais do Workspace.

- Ao abrir, o Workspace carrega as 3000 mensagens mais recentes (antes: as
  2000 mais antigas, o que esconderia as de hoje depois de importar anos
  de histórico). Em cada conversa, «Ver mensagens anteriores»
  (`VerAnteriores`, 300 de cada vez).
- Mensagens mais antigas do que a última vão para o seu lugar, pela data.
- Mensagens com mais de 15 minutos não tocam nem vão para o sino.
- Remetentes sem conta: `user_id` «x:Nome» (`userById` devolve o nome).
- Importado (29-09-2026): «WhatsApp Chat - Farmácia Barispol» para o
  canal #farmácia (`c-farmacia`), confirmado pelo Elmar: 921 mensagens,
  de 18-02-2025 a 27-08-2026. Solange (u17), Gizela (u18), Elmar (u1),
  Arlete (u2), Rosa Simão (u16) e Osvaldo (u14) com a sua conta; Dra Alda
  Mendes, Catarina Baptista e Dr Pedro Feliciano como «x:Nome». Ficaram de
  fora 29 linhas automáticas (entradas e saídas do grupo, chamadas,
  mensagens eliminadas). Imagens e documentos não vieram na exportação:
  «📷 Imagem (não veio na exportação do WhatsApp)» ou o nome do ficheiro.
- Método (para os próximos históricos): cada mensagem com a data original,
  `cid` «wa-<canal>-<n>» (não repete se se correr outra vez) e `id`
  negativo (`overriding system value`; Farmácia de -1000000 a -1000920;
  os próximos canais a partir de -2000000, -3000000…). Com o `id`
  negativo, nenhuma versão do Workspace as conta como por ler nem as
  avisa. Durante a gravação, `messages` sai da publicação
  `supabase_realtime` e volta a entrar no fim. O texto das conversas fica
  só na base de dados, nunca no repositório.
- Importado (29-09-2026): «WhatsApp Chat - DC - LABORATÓRIO» para o
  canal #laboratório (`c-laboratorio`): 1644 mensagens, de 18-02-2025 a
  29-09-2026, ids de -2000000 a -2001644 (o -2001183 ficou vazio: era uma
  linha automática). Com conta: Rosa Queirós (u13), Elmar (u1), Nicolau
  (u3, «Nicolau Mateus» no WhatsApp), Arlete (u2), Cássia (u19) e Osvaldo
  (u14); sem conta («x:Nome»): Edgar, Dra Alda Mendes, Helder Noy, Maria
  Miguel, Latídia Ernesto, Dr Pedro Feliciano, Juliana Lue e Dra Alice
  Paulo. Ficaram de fora 75 linhas (automáticas, eliminadas ou vazias). Uma palavra-passe escrita
  no grupo (19-02-2026) ficou como «[removida na importação]». Cada bloco
  foi conferido com uma soma MD5 contra o ficheiro.
- Ferramenta (30-09-2026): `ferramentas/whatsapp-importar.py` faz tudo o
  que se fez à mão na Farmácia e no Laboratório (linhas automáticas,
  anexos, palavras-passe, blocos de 450, soma MD5 e consulta de
  conferência). O mapa de remetentes (nome no WhatsApp → id ou «x:Nome»)
  fica fora do repositório. Próximo `--base` livre: 5000000.
- Importado (30-09-2026): «WhatsApp Chat - DC - Enfermagem Barispol» para
  o canal #enfermagem (`c-enfermagem`): 648 mensagens, de 10-06-2025 a
  28-09-2026, ids de -3000000 a -3000647 (`--base 3000000`). Com conta:
  Elmar (u1), Arlete (u2), Osvaldo (u14) e u9, u10 e u11 («Paulo Focante»
  no WhatsApp é o Paulo Manuel, u11); sem conta: Dra Alda Mendes.
- Importado (30-09-2026): «WhatsApp Chat - RP» («DAF - RELAÇÕES PÚBLICAS -
  BARISPOL») para o grupo «rp» (`g-1790353145179`): 6416 mensagens, de
  07-04-2025 a 29-09-2026, ids de -4000000 a -4006415 (`--base 4000000`).
  Com conta: Emmanuel (u22, dois números), Arlete (u2) e Elmar (u1); sem
  conta: «Aurélio (motorista)». Três palavras-passe ou códigos escritos no
  grupo e uma chave `eyJ…` do projecto antigo ficaram como «[removida na
  importação]». Os 15 blocos foram conferidos com a soma MD5.
- A ferramenta passou a (30-09-2026): normalizar os acentos (NFC; na
  Enfermagem um «ú» decomposto estragava a soma); tapar sozinha qualquer
  `eyJ…` ou `sb_secret_…`; escrever os caracteres invisíveis (espaço
  inseparável, U+2060, U+200B, tabulação) como «§a0§», «§2060§»… que o SQL
  repõe com `chr()`, porque se perdiam ao copiar o bloco. Antes de aplicar,
  procurar à mão palavras-passe soltas (uma linha só com a palavra-passe
  não tem «senha:» à frente e escapa ao filtro).
- Histórico que não aparecia (30-09-2026, a Gizela não via o da
  Farmácia): um aparelho já aberto só pedia mensagens com id maior do que
  o último, e as importadas têm ids negativos; o tempo real estava
  desligado durante a importação. Agora, ao abrir uma conversa, o
  Workspace pede as 300 mais recentes dessa conversa ao servidor.
- «Ver mensagens anteriores» parecia não abrir (30-09-2026): as mensagens
  entravam, mas a conversa saltava para o fundo. Agora só desce quando
  chega uma mensagem nova no fim; as antigas entram por cima e a vista
  fica no mesmo sítio.
- Testado com servidor simulado: ordem, nomes sem conta e botão.

## 3-ap. Painel com todos os médicos e seguradoras; lembretes das marcações (29-09-2026)

Pedido do Elmar: «No relatório painel faltam dados, no MetaGest ontem teve
mais médicos, hoje só vejo 1» e «um lembrete nas marcações, 1 hora antes e
30 min após, para ligarem e actualizarem o estado».

**Painel (`painel.sql`, `bsp_painel`):**
- Causa: os médicos vinham de `crm.mg_consultas`, que só tem uma parte
  das consultas (28-09: 4 consultas, 1 médico). As facturas têm o médico.
- Agora: «Atendimentos por médico» sai de `erp.sales_invoice` (médico da
  factura, sem «EXTERNO»), com atendimentos (doente por dia) e valor. A
  28-09 dá 4 médicos; em Setembro, 17.
- Novo cartão «Seguradoras»: valor, número de facturas e co-pagamento de
  cada uma (17 em Setembro). Nome curto com `bspNomeSeguradora`.
- Histórico (`metagest-historico.sql`): `erp.sales_invoice` só tinha
  Setembro de 2026. A fila `erp.historico_fila` traz Agosto de 2022 a
  Agosto de 2026, um mês por minuto (agendamento
  `bsp-metagest-historico`, que se apaga quando acaba). Sem o documento
  original (`raw`) antes de Setembro de 2026, para poupar espaço.
  Andamento: `select * from erp.historico_fila order by mes desc`.
- **Por confirmar:** a fila acabou sem `erro`, e os totais por mês de
  `erp.sales_invoice` batem com `crm.mg_facturas`.
- Hoje de manhã não havia facturas às 09h10: é normal (a primeira
  factura sai entre as 08h00 e as 11h45). A sincronização de 5 em 5
  minutos corre sem erros.

**Lembretes das marcações (`workspace.html`):**
- No topo do ecrã Marcações, «Lembretes de hoje» (`MarcLembretes`,
  `bspMarcLembretes`): «Daqui a menos de 1 hora» (ligar ao paciente e
  avisar o médico; botão «Confirmada») e «Passaram 30 minutos» (ligar e
  mudar o estado: Compareceu, Faltou, Remarcado, Cancelou). Contam só as
  marcações de hoje em «Agendada» ou «Confirmada»; mudar o estado apaga
  o lembrete. Botões «Ligar» e «WhatsApp».
- Quem é da Recepção recebe cada lembrete no sino (etiqueta «Lembrete»),
  com som, uma vez por aparelho. Nada durante o «Ver como».
- Novidade «Lembretes das marcações» (Recepção e gestão), em
  `marcacoes-lembrete.sql`.
- Testado com servidor simulado (PC e telemóvel): lembretes certos, sino,
  botões de estado; sem erros nem página mais larga do que o ecrã.

## 3-aq. CRM: serviço certo e facturado por acto (29-09-2026)

Pedido do Elmar: «no WhatsApp tem dados irreais, não facturamos com
ortopedia e tem valores, facturamos com ecografia e está vazio».

- Causa 1: a regra de Ortopedia procurava «osso», que está dentro de
  «posso» («Posso saber mais informações?», a frase dos anúncios) e de
  «Bom Sossego» (a morada). 599 das 716 conversas de Ortopedia eram isso.
- Causa 2: o texto do anúncio não contava; os anúncios de ecografia caíam
  noutro serviço.
- Causa 3: o valor ficava preso ao serviço da conversa; quem escreveu
  «quero marcar» e fez uma ecografia não contava na Ecografia. Quem
  escreveu várias vezes contava a mesma factura várias vezes.
- Correcção (`crm-pedidos.sql`, aplicado no mesmo dia):
  `crm.servico_do_texto` (palavras inteiras), `crm.servico_do_anuncio`
  (sem a morada), `crm.servico_do_item` (serviço de cada linha da
  factura), tabela `crm.pedidos_facturas` e nova `crm.gerar_pedidos`.
  `crm_resultados` soma cada factura uma só vez e devolve `por_acto`.
- Ecrã CRM → Resultados: nova tabela «O que foi facturado, por acto»; a
  coluna da tabela por serviço pedido passa a «Pagaram (tudo)».
- Depois da correcção (desde 20-05-2026): Ortopedia 16 pedidos, 0 Kz;
  Ecografia 1020 pedidos. Nos últimos 90 dias, quem escreveu fez 23
  ecografias (486 671 Kz).
- Limite que fica: a ligação conversa → factura faz-se pelo telefone. Das
  77 facturas de ecografia desde 20-05, 29 são de telefones sem conversa
  no WhatsApp (outro número, ou marcaram por outra via).

## 3-ar. Escalas e presença (por decidir, 29-09-2026)

Pergunta do Elmar: marcar ausente quem não abriu o sistema no dia,
sabendo que há biométrico.

- Já existe `presenca_dias` (primeira e última abertura do Workspace por
  pessoa e dia, desde 24-09-2026).
- Abrir o Workspace não prova presença (abre-se no telemóvel em casa) e
  quem não tem conta nunca aparece. O biométrico é a fonte certa.
- Proposta: ligar o biométrico (marca/modelo e forma de exportação por
  saber) e, até lá, mostrar na escala «sem sinal no Workspace» 30 min
  depois da hora de entrada, sem chamar ausência. À espera do Elmar.

## 3-as. Transporte no chat, consultas no Painel e PDF na Drive (30-09-2026)

- Transporte: cada registo do motorista vai para o grupo #transporte
  (`avisarChat` no `TransporteScreen`): saída (com quem leva e km sem
  registo), abastecimento (litros, valor, km/L), fim da viagem (já
  existia) e ida para casa. Até 30-09-2026 o Emmanuel ainda não tinha
  registado nada no ecrã: as 8 viagens lá são o histórico carregado.
- Painel (`bsp_painel`, `painel.sql`): «Consultas por médico» conta os
  doentes com um acto do grupo CONSULTAS pago; os outros doentes do
  médico aparecem como «só exames»; facturas anuladas por nota de crédito
  não contam. Pedido do Elmar: a Luidmila (Verónica Chitata) a 28-09 teve
  só exames. Atenção: há duas médicas parecidas no MetaGest, «Ludmila Da
  Silva» e «Luidmila Verónica Chitata».
- Leitor de PDF dentro do Workspace (`bspVerPdf`, `LeitorPdf`, PDF.js
  3.11.174 em `vendor/pdfjs`, licença Apache 2.0): qualquer PDF da Drive
  ou do chat abre no visor, com zoom, sem sair da app.
- Testado com servidor simulado (PC e telemóvel), sem erros.

## 3-at. Chat parado para quem não é da gestão (29-09-2026)

- Sintoma: a Gizela (Farmácia) não via o histórico importado, nem
  mensagens novas sem recarregar.
- Causa: a regra de leitura `bsp_msg_ler` chamava `bsp_ve_conversa` em
  cada linha de `messages`. Com os históricos do WhatsApp (cerca de
  13 000 linhas), a primeira carga («as 3000 mais recentes») levava
  19,7 s para quem não é da gestão. O limite é 8 s: o servidor devolvia
  erro 500. Com esse erro, o Workspace parava o arranque: sem tempo real,
  sem equipa do servidor e sem o histórico ao abrir a conversa.
- Servidor (`mensagens-leitura-rapida.sql`, aplicado): a função
  `bsp_conversas_que_vejo()` calcula uma vez por consulta a lista das
  conversas que a pessoa vê (uma chamada a `bsp_ve_conversa` por
  conversa, com `materialized`, porque sem isso o Postgres voltava a
  chamá-la em cada linha). A regra só compara a chave. A carga passou de
  19,7 s para 63 ms. Acesso conferido: a Gizela vê as suas conversas e a
  #farmácia (928), e nada do Laboratório, das RP, da Enfermagem nem
  directas alheias; o Emmanuel vê as RP, o #transporte e as suas.
- Workspace: se a primeira carga falhar, o resto arranca na mesma, e o
  histórico de cada conversa entra ao abri-la.
- Testado com servidor simulado que devolve erro 500 na primeira carga:
  a versão nova mostra a #farmácia e o histórico; a antiga nem mostrava
  o canal.
- A quem ainda não vê: recarregar a página (Ctrl+F5 no PC; na app,
  fechar e abrir).
- Regra para o futuro: nenhuma regra de acesso de uma tabela grande
  chama uma função por linha. Calcular a lista uma vez com `(select …)`.

## 3-au. Departamentos nas Permissões; a Rosa Queirós sem a sua área (29-09-2026)

- Sintoma: a Rosa Queirós (Laboratório) não via nada da sua área.
- Causa: a mesma da 3-at. Com a primeira carga a falhar, o Workspace não
  recebia a equipa do servidor e usava a lista embutida na página, onde
  12 pessoas (entre elas a Rosa) não tinham departamento. Sem
  departamento, o #laboratório não aparecia.
- O servidor estava certo para as 24 pessoas (simulado pessoa a pessoa:
  canais de área, escala da área, marcações).
- Lista embutida (`USERS`): departamento e camada iguais aos do servidor
  para u1, u8–u19 e u22. Testado com o servidor a falhar em tudo: a Rosa
  vê o #laboratório.
- Admin → Permissões: cada camada mostra os departamentos, as pessoas de
  cada um e o canal de área que abre (e os canais a mais, como os da
  Direcção Clínica). Antes mostrava a lista antiga de canais da camada,
  que desde 25-09-2026 já não decide nada: decide o departamento.
- Por rever no Admin (dados, não código):
  - «Beb» (beb@beb.com, cargo «leitor») está na camada Direcção: vê e
    administra tudo. Confirmar se é para ficar.
  - Gizela Joaquim continua sem cargo («Colaborador(a)»).
  - «Retirar acesso» antigo em canais de área (Rosa Simão: #farmácia;
    Emmanuel: #escalas e outros) não tem efeito nos canais de área e o
    servidor ignora-o; o #escalas do Emmanuel só some no ecrã.

## 3-av. Manutenção da viatura e relatório semanal ao motorista (30-09-2026)

- Pedido do Elmar a partir da mensagem do Emmanuel no #transporte (orçamento
  da Suzuki para a manutenção do Suzuki Eeco, 66 652,8 Kz).
- Servidor (`transporte-manutencao.sql`, aplicado):
  - tabela `transporte_manutencoes` (data, estado `orcamento` / `aprovada`
    / `feita`, km, descrição, valor, oficina, fotografia, próxima revisão
    em km ou data, nota). Mesmo acesso do transporte; só a gestão apaga e
    só a gestão aprova um orçamento (gatilho `bsp_transporte_carimbo`);
  - o orçamento de 30-09-2026 ficou registado como primeiro registo
    (por aprovar);
  - `transporte_semana_enviados`: um relatório por semana;
  - agendamento `bsp-transporte-semana`: segunda-feira, 07h45 de Luanda
    (06h45 UTC), tipo `transporte` da `resumo-matinal`.
- `resumo-matinal` versão 9: tipo `transporte`. Consumo da semana anterior
  (segunda a domingo): km por tipo, km sem registo, combustível, consumo,
  manutenção feita, custo por km, orçamentos em aberto e próxima revisão.
  Pede ao motorista, até quarta-feira: km com fotografia, óleo/água/
  travões/pneus/luzes, manutenção, avarias e multas, prazos dos
  documentos, registos em falta. Para: quem tem o cargo «motorista»
  (Emmanuel); cópia e «responder para»: o departamento Administração com
  e-mail da clínica (Arlete e Elmar). `{"previa": true}` devolve o e-mail
  sem o enviar (conferida a 30-09-2026: 237 km na semana de 21 a 27 Set).
- `bright-worker` versão 4: aceita `reply_to`, só do servidor.
- Workspace, ecrã Transporte: botão «Manutenção» (`TranspManutModal`, vai
  também para o #transporte); em «Hoje», aviso da revisão perto (500 km
  ou 14 dias, `bspManutProxima`) e orçamentos por aprovar (botão
  «Aprovar» só para a gestão); em «Histórico», a manutenção do mês e o
  custo por km com combustível e manutenção.
- Testado com servidor simulado (Emmanuel regista; Elmar vê «Aprovar»).
- Por decidir: o primeiro envio real sai segunda-feira, 5 Out 2026, 07h45.

## 3-aw. Conta da Dra. Luidmila (30-09-2026)

- A conta já existia (criada a 29-08-2026, confirmada, nunca usada). A
  palavra-passe foi trocada pela que o Elmar definiu: só o hash bcrypt foi
  para o servidor; a palavra-passe não está em lado nenhum do repositório.
- Acesso clínico: camada «Clínica», departamento Clínica, cargo Médica
  (já estava assim em `shared_state.team`, u6).
- E-mail de boas-vindas enviado pela `bright-worker` (aspecto do site,
  «responder para» a Arlete), com aprovação do Elmar (endereço fora da
  clínica). O e-mail não leva a palavra-passe e pede que ela a mude no
  primeiro acesso (menu da conta → «Alterar palavra-passe»).

## 3-ax. E-mails automáticos também para os médicos (30-09-2026)

- Decisão do Elmar: «Podes quebrar a regra de comunicar fora da
  barispol.com, vou inserir agora os médicos todos».
- `resumo-matinal` versão 10 e `bsp_novidades_reclamar`
  (`emails-toda-equipa.sql`, aplicado): recebe quem está na equipa com um
  e-mail válido, não é sócio e não tem `semEmails: true`. Função nova
  `bsp_recebe_emails(e)`.
- A conta de teste «Beb» (beb@beb.com, um domínio real de fora) ficou com
  `semEmails: true`. Conferido: as quatro médicas com Gmail ou Hotmail
  passam a receber; o «Beb» não.
- Cargo da Dra. Luidmila: «Médica clínica geral, interna de ginecologia e
  obstetrícia» (servidor, com `updated_at = now()`, e lista `USERS`).
- Para marcar outra conta sem e-mails: pôr `semEmails: true` na pessoa, em
  `shared_state.team` (ainda sem botão no Admin).

## 3-ay. Documentos da clínica (30-09-2026)

- Pedido do Elmar: um sítio para o regulamento interno, notas internas,
  comunicados e o resto, acessível a todos. Não vai para uma secção RH
  (dados pessoais), mas para o menu «Documentos».
- Servidor (`documentos.sql`, aplicado): tabelas `documentos` e
  `documentos_leituras`; `bsp_publica_documentos()` = Direcção e
  Coordenação (`bsp_e_gestor`), Direcção Clínica (u14) e departamento
  Administração; toda a equipa lê (sócios não). Ficheiros no bucket
  `drive`, pasta `documentos/`: só quem publica grava e apaga (regras
  `bsp_drive_criar` e `bsp_drive_apagar` refeitas). Tabela no tempo real.
  Conferido pessoa a pessoa: publicam Arlete, Elmar, Osvaldo e «Beb»;
  as outras 20 pessoas só lêem.
- Aviso no instante: o gatilho `bsp_documentos_publicado` chama a Edge
  Function nova `documento-aviso` (versão 1, verificação de JWT desligada,
  só aceita o código do agendamento ou a chave do servidor). Envia um
  e-mail a cada pessoa (menos sócios, `semEmails` e quem publicou), um de
  cada vez (limite da Resend), uma vez por documento (`aviso_enviado_em`).
  No Workspace, o sino toca logo (tempo real, canal `bsp-documentos`).
- Leitura obrigatória: «Li e tomei conhecimento» só depois de abrir o
  documento; quem publica vê «Leituras: x de y», com quem confirmou (data
  e hora) e quem falta. «Nova versão» arquiva a anterior e volta a pedir
  a leitura; «Arquivar» tira-a da lista.
- Workspace: `DocumentosScreen`, `DocPublicarModal`, `DocsPorLerCartao`
  (Início), número por ler no menu (`bspDocsPorLer`), endereço
  `#/documentos`.
- Testado com servidor simulado: a Gizela confirma só depois de abrir; o
  Elmar publica (ficheiro em `documentos/`, registo na tabela) e vê as
  leituras.
- Dra. Luidmila: e-mail de boas-vindas reenviado a 30-09-2026, 11h22, com
  o Elmar em cópia (o primeiro saiu às 11h15; ver «Spam» no Gmail).

## 3-az. «A minha actividade» dos médicos (30-09-2026)

- Pedido do Elmar: cada médico vê o que gerou. Decisão: volumes e valor
  facturado dos seus actos (já vai no relatório mensal deles), sempre sem
  as facturas anuladas por nota de crédito. Nunca a facturação da
  clínica, outros médicos, seguradoras nem nomes de doentes.
- Servidor (`minha-actividade.sql`, aplicado):
  `bsp_minha_actividade(de, ate, membro)` devolve só os totais do médico
  (doentes, consultas, só exames, facturas, valor, actos por grupo, 12
  meses). O médico só pede os seus (recusa conferida); a gestão e quem vê
  o Painel podem pedir os de outra pessoa (para o «Ver como»). As tabelas
  `erp.*` continuam fechadas a quem entra (conferido: «permission denied
  for schema erp»). `bsp_metagest_medicos()` lista os médicos do MetaGest
  (só a gestão; nome, código e número de facturas, sem valores).
- Ligação: campo `metagest` (códigos `ref_practitioner`) em
  `shared_state.team`, posto no Admin → Utilizadores → «Médico no
  MetaGest». Já ligadas: Maria Henriqueta (u4), Creusa (u5), Luidmila
  (u6) e Siomara (u7). Atenção a nomes parecidos no MetaGest («Ludmila Da
  Silva» não é a Luidmila) e a médicos com dois códigos (Pedro Feliciano).
- Workspace: menu «A minha actividade» (`ActividadeScreen`) só para quem
  tem `metagest`; períodos Hoje, Esta semana, Este mês, Mês anterior,
  Este ano; gráfico dos últimos 12 meses (`PainelColunas`).
- Conferido com os dados reais da Luidmila (Setembro): 29 doentes, 29
  consultas, 2 só exames, 49 facturas, 962 602 Kz; a soma dos grupos dá o
  mesmo total.

## 3-ba. Chat: conversar ao carregar na pessoa e responder em privado; atalho dos médicos; escala da Farmácia (30-09-2026)

- Chat: carregar no nome ou na fotografia de quem escreveu, ou numa pessoa
  da lista de membros do canal, abre a conversa directa com ela
  (`bspPodeConversar` + `bspConversaCom`; os remetentes «x:Nome» dos
  históricos não têm conta e ficam de fora).
- Chat: botão «Responder em privado» (cadeado) nas mensagens de um canal
  escritas por outra pessoa: abre a conversa directa com o autor, com a
  mensagem citada no campo de escrita (`window.__bspRascunhoDm`).
- Correcção: a ficha da conversa directa (`DmInfo`) e outros dois sítios
  liam `STATUS_META[status]` sem recurso e fechavam o ecrã a quem não
  tivesse estado gravado. Hoje as 24 pessoas têm; ficou protegido na mesma.
- Início dos médicos: cartão «O meu mês» (`ActividadeAtalho`) com doentes,
  consultas e valor dos seus actos, e o botão «Abrir o meu painel».
- Escala da Farmácia de Outubro de 2026 (PDF assinado pela Solange
  Orlando e pelo Director Clínico a 24-09-2026) carregada e publicada:
  turnos Manhã 07:00–15:45 e Tarde 15:00–22:30 (seg–sex) e Turno longo
  07:00–22:30 (todos os dias); Solange (u17), Gizela (u18) e Rosa Simão
  (u16). Duas horas mal escritas no papel («22H300», «2230») ficaram 22:30.
- Testado com servidor simulado (Luidmila: «Responder em privado» abre a
  conversa com o Elmar e a citação; o nome abre a conversa; o cartão
  aparece no Início).

## 3-bb. Prints de ecrã (30-09-2026)

- Decisão do Elmar: bloqueio na app Android e marca de água nos ecrãs
  sensíveis.
- App Android: `FLAG_SECURE` na `MainActivity`
  (`app/android/app/src/main/java/com/barispol/workspace/MainActivity.java`).
  Bloqueia prints e gravações de ecrã e esconde o conteúdo na lista de
  apps abertas. Só vale com o APK novo (Actions → «App Android» →
  Artifacts): cada telemóvel Android tem de o instalar por cima.
- Navegador e iPhone: não há forma de bloquear. Marca de água
  (`MarcaDagua`) no Painel, A minha actividade, CRM e Marcações
  (`BSP_ECRAS_SENSIVEIS`): nome de quem tem a sessão aberta (no «Ver
  como», quem está a ver: `window.__bspQuemEsta`) e data e hora, em
  diagonal, a 7 % de opacidade, por cima também das janelas e sem apanhar
  os cliques. Testado (Luidmila: aparece e os botões respondem; não
  aparece nos Documentos).

## 3-bc. Protecção contra prints para todos (30-09-2026)

- Pedido do Elmar: «o bloqueio para todos os utilizadores». Bloquear é só
  possível na app Android (FLAG_SECURE, 3-bb). No navegador e no iPhone o
  sistema tira a fotografia antes de o Workspace saber; o que ficou
  (`ProteccaoEcra`, em todos os ecrãs depois de entrar):
  - marca de água em todos os ecrãs (7 % nos sensíveis, 4,5 % nos outros);
  - PrintScreen no computador: ecrã escuro 1,5 s, área de transferência
    limpa e registo em `capturas_ecra` (`capturas.sql`; cada pessoa grava
    as suas, só a gestão lê). Atenção: no Windows a imagem pode sair antes
    de o ecrã escurecer; o registo e a marca de água ficam na mesma;
  - nos ecrãs sensíveis (`BSP_ECRAS_SENSIVEIS`), conteúdo tapado quando a
    janela perde o foco (Ferramenta de Recorte, mudar de app no
    telemóvel). Nos outros não, por causa do MetaGest ao lado;
  - Ctrl+P sai em branco e fica registado; as escalas imprimem-se num
    iframe próprio e continuam a imprimir.
- Testado com servidor simulado (registo gravado, ecrã escuro e depois
  normal, tapado só nos sensíveis, marca de água no Chat).
- Ver as tentativas: `select * from capturas_ecra order by quando desc`
  (ainda sem ecrã no Admin).

## 3-bd. Marca de água discreta e imagens mais rápidas no Chat (30-09-2026)

- Pedido do Elmar: «está feio o nome a repetir» e «as imagens demoram a
  abrir nos chats».
- Marca de água (`MarcaDagua`): uma só linha, diagonal, ao centro, com o
  nome e, por baixo, a data e hora. Sem repetição. 8 % nos ecrãs
  sensíveis, 6 % nos outros.
- Imagens no Chat:
  - as fotografias reduzem-se antes de subir (`bspReduzirImagem`: lado
    maior até 1600 px, JPEG a 82 %; só JPEG, PNG e WebP acima de 400 KB).
    Uma foto de telemóvel com 3 a 5 MB passa a poucas centenas de KB. Só
    no Chat: o Drive e os Documentos guardam o original;
  - os endereços assinados de vários anexos pedem-se de uma vez
    (`bspSignedUrlEmLote`, `createSignedUrls`). Antes, cada imagem fazia o
    seu pedido. As imagens já enviadas continuam grandes, mas abrem com
    um só pedido.
- Correcção: uma mensagem de alguém que já não está na equipa impedia o
  canal de abrir. Aparece agora como «Antigo colaborador».
- Testado com servidor simulado: seis imagens num só pedido, foto de
  4000×3000 reduzida a 1600×1200, GIF intacto, marca de água única.

## 3-be. Lembretes das marcações no Início (30-09-2026)

- Pedido do Elmar: os lembretes de ligar aos pacientes também no Início,
  «para despertar as colegas».
- `MarcLembretesInicio`: o mesmo cartão do ecrã Marcações
  (`MarcLembretes`), no topo do Início, só para quem é da Recepção (como
  o sino). Botões Ligar, WhatsApp e estado; ligação «Marcações →».
  Sem lembretes em curso, o cartão não aparece. Actualiza-se a cada
  minuto.
- Novidade registada para a Recepção.
- Testado com servidor simulado: aparece à Recepção (computador e
  telemóvel), não aparece à Farmácia, a ligação abre as Marcações.

## 3-bf. Afonso Felisberto e Joana Tati na lista embutida (30-09-2026)

- As duas contas foram criadas a 29-09-2026 no Admin: Afonso Felisberto
  (Enfermeiro, Enfermagem) e Joana Carlos Fonseca Tati (Radiologista,
  Radiologia). No servidor estavam certas; faltavam na lista embutida
  `USERS`, o recurso quando o `shared_state` não chega ao aparelho.
  Acrescentadas com os ids, a área e a camada do servidor.
- Conferido no servidor, como o Afonso: vê o canal #enfermagem e lê as 648
  mensagens (históricos do WhatsApp incluídos).
- A exportação do grupo «DC - Enfermagem Barispol» de 30-09-2026 (16 a 28
  de Setembro) já estava toda importada. Nada a acrescentar.

## 3-bg. Transporte: viagens de outros dias e percurso com origem (30-09-2026)

- Pedido do Elmar: o motorista lança os dados antigos, com a data certa.
  - `TranspIniciarModal` tem «Data da viagem» (até hoje). Num dia anterior
    pede a viagem inteira: tipo, km à saída e à chegada, horas de saída e de
    chegada (a rota que passa a meia-noite acaba no dia seguinte), destino,
    quem foi (escalas desse dia) e nota. Não cria «km entre viagens» nem
    exige km acima do último registo; recusa km que já estão noutra viagem.
  - Botão «Viagem de outro dia» (abre em ontem).
  - Abastecimento com data e hora (por omissão, agora).
  - O aviso no #transporte começa por «📝 Registo de <data>».
- Rota NCR → Ygeia (30-09-2026): os km estavam certos (Clínica → NCR 13 km,
  NCR → Ygeia 15 km, Ygeia → Clínica 7 km, sem falhas). O ecrã só mostrava
  o destino, e «Compras · Ygeia» parecia uma ida da clínica. Agora mostra o
  percurso (`bspTranspOrigem` / `bspTranspPercurso`): a origem é o destino
  da viagem anterior do mesmo dia que acabou nesses km. No Histórico, na
  viagem em curso e nos avisos do #transporte.
- Testado com servidor simulado, como o motorista.

## 3-bh. Chat: várias linhas no telemóvel (30-09-2026)

- Pedido do Elmar: no telemóvel o Enter enviava logo e não havia forma de
  escrever várias linhas (não há Shift).
- `bspEnterEnvia(e)` / `bspEcraTactil()`: em ecrãs tácteis (telemóvel,
  tablet) o Enter muda de linha e a mensagem sai com o botão Enviar. No
  computador continua: Enter envia, Shift+Enter muda de linha. Vale para a
  caixa do Chat e para a edição de uma mensagem.
- Testado com servidor simulado: no computador, Enter envia e Shift+Enter
  muda de linha; no telemóvel, Enter muda de linha e o botão envia as
  duas linhas juntas.

## 3-bi. Alerta das escalas aos chefes de área e correcções da auditoria (30-09-2026)

- Pedido do Elmar: alertas de 20 a 29 de cada mês para os chefes fazerem
  as escalas no sistema. `escalas-alerta.sql` (aplicado):
  - `bsp_escalas_responsaveis()`: por área (sem a Administração), quem tem
    cargo de chefia nessa área ou é superior de alguém dela. Área sem chefe
    (hoje a Radiologia) vai para a Arlete (u2), que faz escalas de todas.
    Hoje: Clínica u14, Enfermagem u9, Farmácia u17, Laboratório u13,
    Radiologia u2, Recepção u12, Serviços Gerais u2.
  - `bsp_escalas_alertar()`: dias 20 a 29, uma novidade por área cuja escala
    do mês seguinte não está publicada, só para os responsáveis; diz se já
    há rascunho e quantos dias faltam. Uma por área e por dia.
  - Cron `bsp-escalas-alerta` às 04h55 de Luanda (`55 3 20-29 * *`); as
    novidades saem por e-mail às 05h00 e ficam no sino.
  - Início: `EscalasPorPublicarCartao` a partir do dia 20 (chefe: a sua
    área; gestão: todas), com «Fazer escalas».
  - Testado: 7 alertas no dia 20 simulado, 0 na repetição e fora de 20–29
    (sem gravar); cartão certo para a Recepção, a Farmácia e a Direcção.
- Correcções encontradas na auditoria:
  - `bspLerCsv` estava declarada duas vezes; a das Marcações apagava a do
    CRM e a importação «Recuperar utentes» parava. A das Marcações chama-se
    agora `bspLerCsvLinhas`.
  - O botão «Mais» do telemóvel não ficava marcado em CRM, Marcações,
    Painel, A minha actividade e Documentos.

## 3-bj. Auditoria dos menus (30-09-2026) — propostas por decidir

Corrigido já (3-bi): `bspLerCsv` repetida (importação do CRM parada) e o
botão «Mais» do telemóvel.

Por decidir pelo Elmar (nada mudado):
1. Comunicados em quatro sítios: Feed (tipo «comunicado», sem leitura
   confirmada), Documentos (categoria «comunicado», com leitura), canal
   #avisos e a pasta Drive «Administração/Comunicados». Proposta: o
   comunicado oficial vive em Documentos; o Feed e o #avisos só apontam
   para ele; retirar as pastas Comunicados e Protocolos do Drive.
2. CRM e Marcações usam a mesma ficha do paciente, com regras de acesso
   quase iguais (`bspVeCrm` / `bspVeMarcacoes`). Proposta: um menu
   «Utentes» com separadores Marcações, Pedidos e Recuperar.
3. Directório (lista de contactos e organograma) não tem entrada em menu
   nenhum; Reuniões (`MeetingsScreen`) também não. Proposta: pôr o
   Directório como «Equipa» no menu «Mais»; decidir se Reuniões fica ou sai.
4. Calendário não mostra os turnos: proposta de mostrar no Calendário os
   turnos da própria pessoa (das escalas publicadas).
5. «Relatórios» é o relatório diário das áreas: proposta de lhe chamar
   «Relatório diário», para não se confundir com o Painel.
6. Funções em falta: pedidos de férias e ausências; trocas de turno nas
   escalas; registo de stock/material e de avarias com seguimento (hoje só
   respostas no relatório); formações por pessoa.
7. Código repetido (sem efeito para quem usa, a arrumar aos poucos): dois
   formatos de Kz (`bspPainelKz`, `bspCrmKz`), vários formatos de data,
   estilos de botões e campos copiados por ecrã.

Guia do Workspace (30-09-2026): 16 imagens (mapa dos menus e uma ficha por
menu), 1080×1350, entregues ao Elmar. Não estão no site nem em Documentos.

## 3-bk. Escalas: visto da Direcção Clínica (30-09-2026)

- Pedido do Elmar: a Direcção Clínica altera as escalas de todas as áreas e
  dá o visto a cada escala publicada (assinatura digital com dia e hora).
  Sem visto, a escala não entra em vigor. `escalas-visto.sql` (aplicado):
  - colunas `visto_em`, `visto_por`, `exige_visto`, `enviar_para`;
  - `bsp_edita_escala`: + `bsp_le_areas_medicas()` (u14 edita todas);
  - `bsp_escala_dar_visto(id)`: só u14, só escala publicada; o gatilho
    `bsp_escalas_alterado` impede gravar o visto por outra via e apaga-o
    quando mudam turnos, dias, estado, mês ou área (as notas não);
  - `bsp_escala_em_vigor(estado, visto_em, exige_visto)`; o transporte das
    22:30 (`bsp_transporte_saidas`) só usa escalas em vigor;
  - as escalas publicadas antes da regra (Farmácia de Outubro; Laboratório
    e Recepção de Setembro) ficaram com `exige_visto = false`: em vigor até
    serem alteradas;
  - alertas de 20 a 29: aos chefes diz que a escala precisa de visto; à
    Direcção Clínica, «Escalas de <mês> à espera do seu visto».
- Ecrã: estado «Aguarda o visto…» / «Visto da Direcção Clínica: nome, data
  e hora»; botão «Dar visto» (só u14); ao publicar, o chefe «Publica e pede
  visto» (e-mail ao Osvaldo) e a equipa só recebe a escala depois do visto;
  o Osvaldo «Publica com o meu visto». Impressão com o visto no rodapé e na
  assinatura. Início do Osvaldo: `EscalasPorAprovarCartao` (abre a escala).
  «De serviço hoje» só mostra escalas em vigor.
- Lista embutida `USERS`: cargos de chefia da Solange (u17), Filomena (u9)
  e Rosa Queirós (u13), iguais aos do servidor.
- Testado: no servidor (transacção desfeita), a Solange não consegue pôr o
  visto; uma alteração apaga-o; o Osvaldo edita todas as áreas e dá o visto.
  No ecrã: a Rosa publica e só o Osvaldo recebe o pedido; o Osvaldo dá o
  visto no Início e a escala segue para a equipa com o carimbo.

## 3-bl. Acesso guiado (30-09-2026)

- Pedido do Elmar: guia na próxima vez que cada pessoa abrir cada área.
- `GuiaEcra` (no router, ao lado de `ProteccaoEcra`): na primeira vez em
  cada menu abre uma janela com o guia desse menu (`BSP_GUIA`, o mesmo texto
  das imagens do «Guia do Workspace»). «Percebi» marca como visto neste
  aparelho (`bsp-guia-vistos-<id>`); o botão «?» ao lado do título (no
  computador e no telemóvel) volta a abri-lo. Não abre no «Ver como».
- Quando se muda o que um menu faz, actualizar a ficha em `BSP_GUIA_FICHAS`
  (e a imagem do guia, se for distribuída).
- A ficha das Escalas já fala do visto da Direcção Clínica.
- Testado: aparece na 1.ª vez no Início e no Chat, não volta depois de
  «Percebi», o «?» reabre.

## 3-bm. Sem zoom no telemóvel (30-09-2026)

- Pedido do Elmar: o sistema fazia zoom no telefone (o iPhone ampliava ao
  tocar numa caixa de escrita com letra abaixo de 16 px e não voltava).
- `viewport`: `maximum-scale=1, user-scalable=no, viewport-fit=cover`;
  bloqueio do gesto de dois dedos no Safari (`gesturestart`); `touch-action:
  manipulation` (sem zoom por toque duplo); `html, body` sem largura a mais
  (`overflow-x: hidden`); no telemóvel, `input`, `textarea` e `select` com
  16 px.
- Regra: nenhuma caixa de escrita nova abaixo de 16 px no telemóvel (a regra
  CSS já o força).
- Testado a 390 px: Início, Chat (lista e conversa), Tarefas e Mais sem nada
  fora da largura; a caixa do Chat fica com 16 px.

## 3-bn. Guia do Workspace por e-mail, com confirmação de recepção (30-09-2026)

- Pedido do Elmar: enviar as imagens do guia a cada colaborador, cada um só
  com os menus a que tem acesso, com o RH em cópia e confirmação de recepção
  obrigatória.
- Imagens em `guia/` (site público, sem dados de doentes nem de facturação).
- Menus de cada pessoa: as regras do Workspace (`NAV_ITEMS` + `bspVe*`)
  aplicadas à equipa do dia. 23 pessoas (a conta «Beb» fica de fora).
- `guia-envio.sql` (aplicado): `guia_envios` (fila com os menus de cada um),
  `guia_recepcoes` (confirmações), `bsp_guia_html`, `bsp_guia_enviar_proximo`
  e o agendamento `bsp-guia-envio` (um e-mail a cada 10 s; apaga-se sozinho).
  Cada e-mail vai com o RH (u2) em cópia e como resposta, e pede a
  confirmação de leitura ao programa de e-mail (cabeçalhos
  Disposition-Notification-To e Return-Receipt-To para o RH).
- `bright-worker` versão 5: aceita `headers` só do servidor, e só esses dois,
  com um endereço.
- Workspace: o botão do e-mail abre `#confirmar-guia` e grava a confirmação;
  `GuiaRecepcaoCartao` pede-a no Início a quem ainda não confirmou;
  `GuiaRecepcoesRhCartao` mostra ao RH e à gestão quem confirmou e quem falta.
- Testado com servidor simulado: confirmação pelo botão do e-mail, cartão
  no Início, contagem do RH.

## 3-bo. Editar grupos do Chat; «direcção» passa a «DAF» (30-09-2026)

- Pedido do Elmar: poder mudar o nome dos canais; o grupo «direcção» passa a
  «DAF» (vai criar um grupo «direcção» novo com a Direcção Clínica e a
  Arlete).
- `NovoGrupoModal` também edita (prop `inicial`): nome (fica como foi
  escrito, ex.: «DAF»), descrição e membros. Botão de lápis no topo da
  conversa, para quem criou o grupo e para a Direcção e Coordenação (as
  mesmas que o podem apagar). Acção `editarCanal` (mesmo id).
- O acesso no servidor (`bsp_ve_conversa`) segue o id e os membros, nunca o
  nome: mudar o nome não mexe no histórico nem em quem vê.
- Grupo do Transporte marcado com `funcao: 'transporte'`: os avisos das
  viagens já não dependem do nome.
- No servidor (30-09-2026): `g-1788271279015` «direcção» → «DAF» (membros
  u1 e u2, sem mudança), com `updated_at = now()`.
- Os canais fixos (#geral, #avisos e os das áreas) continuam com o nome do
  código; os grupos criados no Workspace mudam-se pelo lápis.
- Testado: o Elmar abre o grupo, muda para «DAF» e grava; os membros e o
  grupo do Transporte ficam iguais.
