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
