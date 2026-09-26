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
- [ ] Próximo passo, aprovado pelo Elmar a 26-09-2026 (parado: o conector
      do Supabase passou para a conta elmar.bravo30@gmail.com e deixou de
      ver o projecto Barispol; religar com elmar.bravo@barispol.com):
      1. Marcações na ficha do paciente (CRM), pelo telefone (`tel9`), e
         botão «Ficha» em cada marcação. Só para quem vê as Marcações.
      2. «Compareceu» automático quando o MetaGest tem factura ou consulta
         desse telefone no dia marcado (só Agendada/Confirmada).
      3. Nova marcação: sugerir o paciente do MetaGest pelo nome ou
         telefone e preencher nome, contacto, sexo e e-mail.
      4. Campo **E-mail** do paciente na marcação, para estimular o uso:
         validado, preenchido da ficha quando existir, aviso «sem e-mail»
         na linha e contagem de marcações com e-mail. Coluna `email` em
         `marcacoes` primeiro no servidor, depois o ecrã (o ecrã antes da
         coluna partia as gravações). E-mail de confirmação ao paciente só
         com texto aprovado pelo Elmar (regra 3).


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
