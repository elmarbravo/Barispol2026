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

## Pendentes de Setembro (arquivo de 02-10-2026)

As secções 3-b a 3-am, 4-b e 4-c (24 a 28-09-2026) passaram para
`historico-2026-09.md`, com o texto completo. Ficam aqui só as tarefas
que estavam por fazer, com a secção de origem. Ao fechar uma, marcar
`[x]` aqui.

**3-b. Avisos a toda a equipa por e-mail (24-09-2026)**

- [ ] **Confirmar os primeiros envios reais**: lembrete a 25-09 às 07h30;
      colectivo a 25-09 (sexta) às 12h00. Consulta: `select status_code,
      content from net._http_response order by created desc limit 5;` —
      `lembrados` deve ser 17 e sem `falhas`.

**3-c. Direcção e Coordenação vêem e delegam tarefas (24-09-2026)**

- [ ] Por confirmar num aparelho real: delegar uma tarefa e vê-la no
      telemóvel da pessoa.

**3-e. Relatórios padrão por área (24-09-2026)**

- [ ] Por decidir: se os anexos (Excel, PDF das requisições) passam a ir
      pelo Drive.
- [ ] A Solange e a Gizela (Farmácia) estão sem departamento: o
      formulário abre-lhes pela Recepção até isso ser preenchido.

**3-f. App Android (24-09-2026)**

- [ ] Por confirmar num Android real: entrar, receber mensagens, fazer
      uma chamada (microfone) e ver a página sem internet.

**3-g. «As mensagens aparecem codificadas» (Arlete, 24-09-2026)**

- [ ] Pedir à Arlete que recarregue à força (computador: Ctrl+Shift+R;
      telemóvel: fechar o separador e reabrir). Se continuar, pedir uma
      captura do sítio onde aparece.

**3-i. Menções com «@» no chat (24-09-2026)**

- [ ] Por confirmar com duas pessoas reais: a notificação de menção.

**3-k. Telemóvel, chamadas com som, notificações e imagens (24-09-2026)**

- [ ] **Avisos com a app fechada** (como o WhatsApp): ainda não. Precisa
      de notificações push. No Android isso passa pelo Firebase Cloud
      Messaging: um projecto Firebase da clínica, criado pelo Elmar, e o
      ficheiro `google-services.json` na app. No iPhone (ecrã principal)
      usa-se Web Push, que o iOS 16.4 ou superior aceita. Até lá, o
      e-mail após 5 minutos offline (3-d) cobre as mensagens directas.
- [ ] Confirmar num telemóvel real: o toque de uma chamada a entrar e a
      sair, e o visor de imagens na app Android.

**3-l. Projecto Supabase novo (24-09-2026)**

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

**3-m. Site novo e caixa de contacto (25-09-2026)**

- [ ] **Envio pelo SMTP da caixa (opcional):** o Elmar cola no painel
      (Edge Functions → Secrets) `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS` e,
      se preciso, `SMTP_PORT` = 465 e `SMTP_FROM`. As funções **não podem
      usar as portas 25 e 587**. Sem os segredos, sai pela Resend, de
      geral@barispol.com.
- [ ] Confirmar a Medicare e se a Caixa Social de Catoca deve entrar.
- [ ] Fotografias da equipa e dos serviços, com autorização. A fotografia
      da sala de espera com utentes **não** se usa: mostra pessoas e
      crianças identificáveis.
- [ ] Rever `contacto.html` e `ecografia.html` no mesmo estilo.

**3-p. Chat, tarefas e calendário (25-09-2026)**

- [ ] Confirmar num aparelho real: arrastar ficheiros no chat e criar uma
      tarefa partilhada entre duas pessoas.

**3-r. Canais de área pela função (25-09-2026)**

- [ ] Decidir se os Serviços Gerais precisam de um canal próprio.

**3-t. Campanhas do site com hora de fim e cartaz (25-09-2026)**

- [ ] Depois de 31-10-2026: apagar `outubro-rosa.html` e
      `assets/outubro-rosa.*`, e tirar a entrada de `campanhas.json`.
- [ ] Confirmar com a recepção que o desconto está criado no MetaGest
      (nota do ficheiro de textos).

**3-x. Modo escuro no Workspace e no site (25-09-2026)**

- [ ] `contacto.html` e `ecografia.html` ainda têm o estilo antigo e não
      têm modo escuro (entram quando forem refeitas).

**3-aa. Todos os e-mails com o aspecto do site (26-09-2026)**

- [ ] Os e-mails do próprio Supabase (repor a palavra-passe, confirmar
      conta, convite, ligação de entrada, mudar e-mail) têm modelos no
      painel. Estão prontos em `emails-supabase/` (ver o `LEIA-ME.md`):
      o Elmar cola-os em Authentication → Emails. Daqui não se consegue
      gravar a configuração de autenticação.

**3-ac. Marcações dentro do Workspace (26-09-2026)**

- [ ] Janeiro a Julho: só estão na «MARCAÇÕES - 2026.xlsx» (66 MB), que
      o conector não consegue ler. No Excel: Ficheiro → Guardar como → CSV
      (uma folha de cada vez) e «Importar CSV» no ecrã; ou copiar esses
      meses para uma planilha pequena no SharePoint e pedir a importação.
- [ ] Confirmar com a Recepção as marcações antigas que ficaram
      «Agendada» sem estado na planilha.
- [ ] Com `paciente_id`, o «Compareceu» usa só esse paciente; sem ele usa
      o telefone, e uma família com o mesmo número pode dar um falso
      Compareceu. Escolher o paciente na sugestão evita isso.

**3-ad. Cópias de segurança (26-09-2026)**

- [ ] Opção A: plano Pro do Supabase (cópias diárias de 7 dias).
- [ ] Opção B: ligação ao Microsoft 365 (aplicação no Entra ID com acesso
      só ao site da Recepção/Direcção; o Elmar cola o segredo). Serve
      também para ler a planilha das marcações de hora a hora até a
      Recepção passar só para o Workspace.

**3-ae. Novidades do sistema (27-09-2026)**

- [ ] Confirmar a 28-09 em `net._http_response` a resposta do tipo
      novidades (`enviados` = número de pessoas, sem `falhas`).

**3-af. Notas de voz no Chat (27-09-2026)**

- [ ] Testar num iPhone real: o Safari antigo (antes do iOS 17.4) pode
      não tocar as notas gravadas em WebM noutros aparelhos.
- [ ] Confirmar com o Elmar num iPhone e num Android reais. A nota WebM
      de 28-09 pode continuar sem tocar nalguns aparelhos: aí aparece o
      cartão para a descarregar.

**3-ah. Sócios e notas de crédito (27-09-2026)**

- [ ] Pôr no departamento Financeiro quem trata das finanças (Admin →
      Pessoas); hoje ninguém está nele.
- [ ] Atribuir a categoria «Sócio» às pessoas certas (Admin → Pessoas).

**3-ai. Tarefas com data de início e de fim (28-09-2026)**

- [ ] Preencher a data de fim nas 4 tarefas privadas antigas.

**3-aj. Lembrete da marcação ao paciente e fim dos grupos de WhatsApp (28-09-2026)**

- [ ] O remetente continua «Barispol Workspace <geral@barispol.com>».
      Para os pacientes, «Centro Médico Barispol» seria mais claro: só
      com o acordo do Elmar.
- [ ] Confirmar a 29-09 em `net._http_response` o envio das 10h00.

**3-ak. Escalas de serviço (28-09-2026)**

- [ ] A Juliana preencher e publicar a escala de Outubro.
- [ ] Testar a impressão num telemóvel real.

**3-am. Escalas do Laboratório e dos Serviços Gerais (28-09-2026)**

- [ ] Decidir se Maria, Angelina, Inês e Loide entram na equipa (com
      e-mail, para receberem a escala) e publicar a de Outubro.

## 4. Em cada aparelho

- [ ] Recarregar à força (telemóvel: fechar o separador e reabrir;
      computador: `Ctrl`+`Shift`+`R`). Sem isto a página velha continua
      a mostrar «agora» em todas as notificações e a esconder o resto.
- [ ] Recriar os grupos privados que se perderam. Foram criados num
      telemóvel enquanto ele estava em «modo local» e nunca chegaram ao
      servidor. Uma vez, em qualquer aparelho, chega.

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

## 3-bp. Grupo «direcção» e históricos da Direcção e da Radiologia (30-09-2026)

- Pedido do Elmar: criar o grupo «direcção» com o Osvaldo e a Arlete, e
  importar os históricos do WhatsApp «Direcção» e «DC IMG - RAIO X».
- Grupo novo `g-1790807774479` «direcção» (privado; membros u1, u14, u2),
  criado no servidor com `updated_at = now()`. O antigo «direcção» é o
  «DAF» (3-bo).
- «Direcção» → grupo «direcção»: 2061 mensagens, de 12-04-2025 a
  28-09-2026, ids de -6000000 a -6002060 (`--base 6000000`, `cid`
  «wa-direccao-n»). Com conta: Elmar (u1), Arlete (u2), Osvaldo (u14); sem
  conta: Dra Alda Mendes, Cris Sassuco, Dra Alice Paulo, Dr Pedro Feliciano,
  Cristóvão (Africell), Samuela Saitumbo. Uma palavra-passe do Wi-Fi
  (20-10-2025) ficou «[removida na importação]».
- «DC IMG - RAIO X» → canal #radiologia (`c-radiologia`): 363 mensagens, de
  17-04-2025 a 30-08-2026, ids de -5000000 a -5000362 (`--base 5000000`).
  Com conta: Neusa (u1790255566296), Elmar, Arlete, Osvaldo; sem conta: Dra
  Alda Mendes, Dr Pedro Feliciano, Celésia (Raio X) e três números de
  telefone («x:+244 …»). Ficaram de fora 7 linhas automáticas que o filtro
  não apanhou («Removeu … do grupo», «Alterou as definições deste grupo»);
  a ferramenta já as tira (`SIS` em `ferramentas/whatsapp-importar.py`).
- Próximo `--base` livre: 7000000.

## 3-bq. Chat: sem tópicos; respostas com citação na conversa (30-09-2026)

- Pedido do Elmar: eliminar a opção de comentar uma mensagem ou imagem, ou
  pôr o comentário na conversa, visível a todos.
- O botão «Tópico» saiu (o `TopicoPanel` fica no código, sem entrada). O
  «Responder» (seta) põe a barra «A responder a Nome: excerto» por cima da
  caixa; a mensagem sai na própria conversa, com a primeira linha
  «> Nome: excerto» (`bspCitacao`, `bspExcertoParaCitar`), que o Chat mostra
  como bloco de citação. Imagens e ficheiros citam-se como «📷/📎 nome».
  Avisos e pré-visualizações mostram só a resposta (`bspTextoResumo`).
- Os 6 comentários que havia em tópicos (`th~…`, 28 a 30-09-2026) passaram
  para as conversas de origem, com a citação e a data original.
- Testado: a resposta sai na conversa com a citação; a citação aparece como
  bloco; o botão «Tópico» já não existe.

## 3-br. Word dentro do Workspace; .doc recusado nas conversas (01-10-2026)

- Pedido do Elmar: abrir ficheiros do Word dentro do sistema, como os PDF;
  se não der, não os aceitar nas conversas, só no Drive.
- `.docx` abre no visor (`bspVerWord`, `LeitorWord`), com `docx-preview`
  0.4.1 (Apache 2.0) e JSZip 3.10.2 (MIT), em `vendor/docx`, carregados só
  no primeiro Word. A página ajusta-se à largura do ecrã; botões − e +.
  `bspAbrirFicheiro` escolhe sozinho (Chat, Drive, Documentos).
- `.doc` (Word 97-2003) não se mostra no navegador: `enviarFicheiros`
  recusa-o nas conversas, com o conselho de guardar como .docx ou PDF; o
  Drive continua a aceitá-lo (para descarregar).
- Guia: a ficha do Drive diz «PDF, Word (.docx) e imagens».
- Testado: .docx com título, texto e tabela abre no computador e no
  telemóvel (cabe na largura); .doc recusado no Chat com a explicação.
- Excel e PowerPoint continuam a descarregar-se (decisão por tomar).

## 3-bs. Assistente com IA (01-10-2026) — falta a chave

- Pedido do Elmar: IA no sistema, a mais barata, com um limite por pessoa
  como o do ChatGPT gratuito.
- Modelo: Claude Haiku 4.5 (`claude-haiku-4-5`, 1 USD / 5 USD por milhão de
  tokens de entrada / saída). Respostas até 600 tokens; só as últimas 4
  mensagens seguem com cada pergunta; o guia dos menus vai nas instruções
  (com cache).
- Limite: 10 perguntas a cada 5 horas por pessoa (`assistente.sql`:
  `assistente_uso`, `bsp_assistente_quota`). Sócios não usam; o «Ver como»
  não pergunta.
- Edge Function `assistente` (versão 1, verificação de JWT desligada, com
  autenticação própria: sessão + pessoa da equipa). Testada: sem sessão
  responde 401.
- Workspace: botão de faísca «Assistente» no topo (computador e telemóvel),
  `AssistentePainel` com o aviso de não escrever nomes de doentes nem dados
  de facturação (as perguntas saem do servidor).
- **Por fazer (Elmar):** criar a chave em console.anthropic.com → API Keys,
  pôr um limite de gasto mensal na consola (ex.: 20 USD), e colá-la em
  Supabase → Edge Functions → Secrets com o nome `ANTHROPIC_API_KEY`. Sem a
  chave, o painel responde «O assistente ainda não está ligado».
- Depois da chave: testar uma pergunta e lançar a novidade a `todos`.

## 3-bt. Histórico do WhatsApp «DAF» (01-10-2026)

- Pedido do Elmar: importar o histórico «BRSP - DAF 1.º» para o grupo
  «DAF» (`g-1788271279015`). 4017 mensagens, de 03-09-2025 a 28-09-2026,
  ids de -7000000 a -7004016 (`--base 7000000`, `cid` «wa-daf-n»).
- Revisão de credenciais (com o texto tapado): a senha de um PC, outras
  senhas e o código do cartão do banco (duas respostas) ficaram
  «[removida na importação]». Ficaram montantes, referências de
  pagamento, quatro IBAN (por decidir com o Elmar) e o nome de utilizador
  «administrator».
- O importador passa a tirar os caracteres de uso privado (U+E000 a
  U+F8FF, emojis antigos de telemóvel): não aparecem em nenhum ecrã e
  perdiam-se no envio do SQL, o que estragava a conferência por md5.
- Os 9 blocos (`wa_daf_b0` a `wa_daf_b8`) aplicados por ordem, cada um
  conferido pelo número e pelo md5: 4017 mensagens no servidor.
- Por decidir com o Elmar: tapar a ligação do Teams com a senha embutida
  na mensagem 751 da Direcção (`wa-direccao-751`).
- Próximo `--base` livre: 8000000.

## 3-bu. Tarefas: descrição, comentários e «Levar para o Chat» (01-10-2026)

- Pedido do Elmar: campo descrição, comentar dentro da própria tarefa (como
  o Kanban do Teams) e levar a tarefa para o Chat.
- Descrição: campo novo no `TaskComposer`. Tarefas da equipa guardam-na no
  estado partilhado (`desc`); as privadas na coluna `descricao` de
  `tarefas_pessoais` (`tarefas-comentarios.sql`, aplicado). O cartão mostra
  as duas primeiras linhas e o número de comentários.
- Carregar numa tarefa abre o `TarefaDetalhe`: coluna, prioridade, datas,
  pessoas, descrição, quem a criou e os comentários. «Editar» abre o
  formulário; «Levar para o Chat» envia a tarefa a um canal, grupo ou
  colega, com o botão «Abrir a tarefa» (linha `[tarefa:<id>]`,
  `bspTarefaDaMensagem`, `bspAbrirTarefa`).
- Comentários: mensagens na conversa `tarefa-<id>` (equipa: `tarefa-t…`,
  privada: `tarefa-p<id>`). No servidor, `bsp_ve_conversa` deixa ler os de
  uma tarefa privada só a quem vê a tarefa (testado: dono e Direcção sim,
  outro colega não). Aviso no sino (tipo `task`, abre a tarefa) a quem
  está na tarefa, a quem a criou (`criadoPor`, novo), a quem já comentou e
  a quem foi mencionado.
- Chat: as mensagens passam a mostrar as mudanças de linha (`pre-wrap`).
- Testado no navegador (servidor simulado): criar, abrir, comentar, citar,
  levar para #geral e voltar à tarefa pelo botão; telemóvel em ecrã inteiro.

## 3-bv. Stock do MetaGest no Workspace (01-10-2026)

- Pedido do Elmar: a Arlete e a Solange recebem no Workspace o relatório e
  os alertas de stock.
- O utilizador da API não lê o «Bin» (403). O saldo sai do último movimento
  de cada artigo em cada armazém (Stock Ledger Entry). `stock.sql`, aplicado:
  `erp.stock_mov`, `erp.stock_artigo`, `erp.stock_lote`,
  `erp.sincronizar_stock()` (agendamento `bsp-stock`, 15 em 15 min; a
  primeira cópia levou 18 s: 10 419 movimentos, 3066 artigos, 905 lotes).
- Quem vê: `public.stock_responsaveis` (Arlete u2 = todos; Solange u17 =
  FARMÁCIA - CBL) e a gestão, em `bsp_ve_stock`. Testado: a Arlete vê os 6
  armazéns, a Solange só a Farmácia, outra colega nada. No ecrã:
  `bspVeStock` / `BSP_STOCK_RESPONSAVEIS` (mudar os dois lados juntos).
- Relatório: `bsp_stock()` (saldo, saídas de 30 dias, dias que dura, lote
  mais próximo, estado). Esgotado = 0 com saídas em 30 dias; a acabar = dura
  menos de 7 dias; lote a caducar = validade até 60 dias.
- Ecrã «Stock» (`StockScreen`): armazéns, alertas, procura, ordenar,
  imprimir. Início: `StockAlertaCartao`. Sino: aviso quando os alertas sobem
  (uma vez por dia por armazém). Ficha no guia.
- Em 01-10-2026: Farmácia com 12 esgotados, 3 a acabar e 56 com lote a
  caducar; nos outros armazéns, nada.
- Os papéis do utilizador da API no MetaGest (Gestor de Contas, Gestor de
  Stock, Gestor do Item, Médico…) deixam gravar. O Workspace só lê.

## 3-bw. Feed mais perto e funil de vendas (01-10-2026)

- Pedido do Elmar: «o Feed está longe» e «preciso ter um funil de vendas».
- Feed: na barra do telemóvel (`MobileNav`) passa a estar o Feed no lugar
  da Agenda; a Agenda fica em «Mais». No Início, `FeedInicioCartao` mostra
  as 2 publicações mais recentes (as fixadas primeiro); carregar numa abre-a
  no Feed com os comentários.
- Funil de vendas: separador «Funil de vendas» no CRM (`CrmFunil`), função
  `crm_funil(dias, origem, serviço)` (`crm-funil.sql`, aplicado; só quem vê
  o CRM, testado). Etapas: escreveram → respondidos por uma pessoa →
  marcados → vieram e pagaram (factura nos 30 dias). Perdas: sem resposta,
  respondidos sem marcação, marcados que não vieram; os últimos 7 dias
  contam «em curso». Também: facturado, valor por quem veio, tempo de
  resposta (mediana), resposta em 15 min, preço dado a quem pediu, por quem
  respondeu e semana a semana.
- Números reais dos últimos 30 dias (01-10-2026): 539 escreveram, 449
  respondidos, 63 marcados, 51 vieram; 353 respondidos sem marcação;
  resposta mediana de 68 minutos.

## 3-bx. Seguimento da auditoria (01-10-2026, «faz todos eles»)

- Guião de marcação (CRM → Pedidos): nos pedidos «Novo» e «Em contacto», o
  botão «Propor marcação» abre o WhatsApp da pessoa com a mensagem pronta
  (`bspCrmGuiao`: nome, serviço e a pergunta «amanhã de manhã ou à
  tarde?») e copia-a. Sem preços nem vagas escritos à mão.
- Aviso de 15 minutos: para a Recepção, no horário 07h30–22h00, um aviso no
  sino e no aparelho por cada pedido «Novo» sem resposta de uma pessoa há
  mais de 15 min (até 6 h). Verifica de 3 em 3 min (`crm_pedidos(1)`).
- Funil das marcações, todas as vias (CRM → Funil de vendas, só para quem
  vê as marcações): `bsp_marc_funil(dias)` em `crm-funil.sql` (aplicado,
  testado: Recepção vê, Laboratório recusado). Marcadas, compareceram,
  faltaram, cancelaram, «por actualizar» (data passada e ainda agendadas) e
  por via. Em 01-10-2026, nos últimos 60 dias: 144 marcadas, 81
  compareceram, 43 por actualizar.
- Menu «Utentes»: CRM e Marcações num só item (`id: 'seguimento'`,
  `utentesOnly`), com os separadores Marcações (quem tem `bspVeMarcacoes`),
  Pedidos, Funil, Recuperar, Fichas e Resultados (quem tem `bspVeCrm`). A
  rota `marcacoes` continua a existir (avisos, e-mails) e abre o mesmo ecrã
  no separador Marcações (`CrmScreen({ inicial })`). O Directório entrou no
  menu como «Equipa». No «Mais» do telemóvel: Utentes, Agenda, Stock e
  Equipa (o Feed saiu de lá, está na barra).
- Comunicado oficial só em Documentos (`comunicados-documentos.sql`,
  aplicado; testado numa transacção desfeita): publicar em Documentos um
  documento «comunicado» cria a publicação no Feed e a mensagem em #avisos,
  com a linha `[documento:<id>]` → botão «Abrir o documento»
  (`bspDocumentoDaMensagem`, `bspAbrirDocumento`, `BotaoDocumento`). O
  botão «Comunicado» do Feed leva a Documentos. Falta decidir com o Elmar
  se se apagam as pastas «Comunicados» e «Protocolos» do Drive (nada mudado).
- Turnos no Calendário: `MeusTurnosCartao` no topo do Calendário, com os
  turnos da própria pessoa nas escalas em vigor (com visto) deste mês e do
  seguinte; 7 dias numa fila, «Ver todos» mostra o resto. Escalas sem visto
  não aparecem (regra de `bspEscalaEmVigor`).
- Férias e ausências, formações, avarias e pedidos de compra
  (`equipa-registos.sql`, aplicado em partes; testado no servidor numa
  transacção desfeita e no navegador). Quem decide (`bsp_chefe_de`): a
  gestão, o superior directo e o chefe da área (`bsp_escalas_responsaveis`);
  ninguém decide os seus pedidos. Avisos pelas novidades.
  - Equipa (`EquipaScreen`): Contactos (o Directório), Férias e ausências
    (`AusenciasPainel`: pedir, para decidir, quem vai estar fora 30 dias, os
    meus pedidos; `bsp_ausencia_decidir`) e Formações (`FormacoesPainel`:
    horas por pessoa, certificados a caducar em 60 dias).
  - Avarias (menu novo, `AvariasScreen`): toda a equipa reporta; a gestão e
    os Serviços Gerais tratam (`bsp_trata_avarias` / `bspTrataAvarias`):
    estado, quem trata, custo, o que se fez; quem reportou recebe o aviso
    quando fica resolvida.
  - Stock → Pedidos de compra (`PedidosCompraPainel`): o pedido vem dos
    artigos esgotados e a acabar (quantidade sugerida = saídas de 30 dias
    menos o saldo); só a gestão aprova; depois Comprado e Recebido.
- Trocas de turno (`trocas-turno.sql`, aplicado; testado numa transacção
  desfeita: a troca entra na escala, o visto mantém-se e a escala continua
  em vigor; notas da escala registam a troca). Fluxo: quem está no turno
  pede (`bsp_troca_pedir`, com turno do colega em troca opcional) → o colega
  aceita (`bsp_troca_responder`) → a Direcção Clínica aprova
  (`bsp_troca_decidir`, aplica com `bsp.visto = '1'`). Painel
  `TrocasTurnoPainel` no topo de Escalas. Avisos pelas novidades.
- Escalas de Outubro em vigor sem visto (decisão do Elmar, 01-10-2026):
  Recepção (7), Laboratório (10) e Raio X (11) passaram a
  `exige_visto = false`, com a nota na escala; nenhum visto foi registado em
  nome da Direcção Clínica. O ecrã diz «Em vigor sem visto da Direcção
  Clínica». Para voltar a exigir: `exige_visto = true` (com `bsp.visto = '1'`).

## 3-by. Organograma escondido (01-10-2026)

- Pedido do Elmar: «por agora oculte o organograma de todos». O Directório
  (menu «Equipa» → Contactos) deixa de mostrar o botão «Organigrama».
- Interruptor: `BSP_ORGANOGRAMA_VISIVEL = false` (junto de `OrgChart`).
- Porquê: o `OrgChart` veio do ficheiro de origem (23-09-2026), com nomes
  e contagens escritos à mão e o Nicolau no topo.
- Falta: refazer o `OrgChart` pelo desenho do Elmar, com os dados da equipa
  (campo `superior`). A Arlete fica ao nível dos chefes de área. Os sócios
  não aparecem. Depois, pôr `BSP_ORGANOGRAMA_VISIVEL = true`.

## 3-bz. Fiscalização de 01-10-2026: duas fugas fechadas

- `bsp_wa_linhas` (nomes e telefones de quem escreveu ao WhatsApp) e
  `bsp_entradas_rececao` (hora de entrada da Recepção) respondiam a qualquer
  um com a chave publicável. Fechadas (`funcoes-fechadas.sql`); os e-mails
  das 8h e das 16h correm como dono e continuam.
- Por fazer, em segurança:
  - Apagar as funções `mig-recebe` e `bsp-crm-patch` (migração, já não
    servem).
  - Ligar a protecção contra palavras-passe divulgadas (Auth → Providers →
    Email → «Prevent use of leaked passwords»). Só o Elmar.
  - Tirar o acesso de visitante às restantes funções `security definer`
    que só servem quem tem sessão (testadas: recusam ou devolvem vazio).
  - Fixar o `search_path` de 16 funções.

## 3-ca. Stock: ecrã caía no limite de tempo (01-10-2026)

- O Elmar viu «canceling statement due to statement timeout» no Stock.
  `bsp_stock()` levava 10 s (limite das sessões: 8 s): o planeador chamava
  `bsp_ve_stock` para cada um dos 10 mil movimentos.
- Correcção em `stock.sql`: os armazéns permitidos calculam-se uma vez (CTE
  `arm` com `offset 0`). Agora 0,08 s. Acessos iguais: Elmar 946 linhas,
  Solange 766 (só Farmácia), Cassia 0.
- Regra para funções novas: nunca filtrar por uma função de acesso linha a
  linha numa tabela grande; calcular primeiro o que a pessoa vê.

## 3-cb. Facturas por receber: Painel e e-mail da manhã (01-10-2026)

- Pedido do Elmar («Faz»). Ficheiro `cobrancas.sql`, aplicado.
- Acerto com o MetaGest (`erp.reconciliar_cobrancas`, cron
  `bsp-cobrancas-acerto` às 05h50 e 13h50): a cópia só relia 7 dias, por
  isso uma factura antiga paga depois ficava em aberto. Primeiro acerto:
  9 994 em aberto no MetaGest, 5 passaram a pagas, 9 645 ganharam a data de
  vencimento. Se o MetaGest falhar a meio, pára e não muda nada.
- Números: `erp.cobrancas_dados()`; no ecrã `bsp_cobrancas()` (só
  `bsp_ve_painel`), cartão `PainelCobrancas` no Painel.
- E-mail: `bsp_cobrancas_email(true)`, cron `bsp-cobrancas`, segunda a sexta
  às 06h40, só para quem vê o Painel (hoje só o Elmar; quem entrar no
  Financeiro passa a receber). `bsp_cobrancas_email(false)` mostra sem enviar.
- Utentes nunca com nome: só seguradoras e empresas com nome de empresa
  aparecem; um cliente com nome de pessoa no grupo Seguradora conta como
  particular. Nomes da mesma seguradora juntam-se como em `bspNomeSeguradora`.
- Valores de 01-10-2026: 110,0 M Kz por receber, 98,5 M vencidos, 67 M com
  mais de um ano.
- Por fazer (MetaGest, Financeiro): limpar a dívida antiga incobrável;
  juntar clientes duplicados da mesma seguradora (ENSA, NOSSA); tirar do
  grupo Seguradora os clientes que são pessoas; corrigir a factura com
  vencimento em 2006.
- Correcção (01-10-2026, Elmar: «Não faz email de cobrança»): o cron
  `bsp-cobrancas` foi apagado antes do primeiro envio. Ficam o acerto e o
  cartão no Painel. A novidade deixou de falar do e-mail.

## 3-cc. Stock: validades por lote e por armazém (01-10-2026)

- Pergunta do Elmar: «O prazo de validade dos produtos convém que apareçam».
  Já aparecia, mas só o primeiro lote, numa coluna escondida no telemóvel e
  com a quantidade do lote em todos os armazéns.
- `stock-validades.sql` (aplicado): `erp.stock_mov.batch_no` (a sincronização
  traz o lote; histórico preenchido: 5 374 movimentos); lotes por armazém pela
  soma dos movimentos (os 905 lotes batem com o MetaGest); `bsp_stock_lotes()`;
  estado `caducado` em `bsp_stock` e `bsp_stock_resumo`.
- Ecrã: validade por baixo do nome do artigo; caixa «Com lote caducado»;
  caixa «Validades (lote a lote)» com prazo (60 dias, 6 meses, 1 ano, todos)
  e impressão; o sino e o Início contam os caducados.
- Hoje: 586 lotes com quantidade, 57 caducam em 60 dias, nenhum caducado.

## 3-cd. Fiscalização: passos A e B (01-10-2026)

- B1 «apaga»: `mig-recebe` e `bsp-crm-patch` passaram a recusar tudo (versão
  2, 410, verificação de JWT); as funções `_mig_*` ficaram sem execução para
  todos. As ferramentas daqui não apagam Edge Functions nem fazem `drop`
  (ficam à espera de confirmação). **Falta o Elmar:** Supabase → Edge
  Functions → `mig-recebe` → Delete; o mesmo para `bsp-crm-patch`.
- B2 «liga»: só no painel. **Falta o Elmar:** Authentication → Sign In /
  Providers → Email → «Prevent use of leaked passwords» → Save (pede o plano
  Pro).
- B3 «tira o acesso»: nenhuma função `bsp_*` com privilégios fica aberta a
  visitantes (`funcoes-fechadas.sql`). Testado: com sessão funcionam
  mensagens, novidades, stock e o gatilho das avarias; sem sessão, recusado.
- A1: a dívida antiga fica com a contabilista.
- A2 «junta»: no MetaGest a ENSA e a NOSSA já são um só cliente cada; os
  «duplicados» eram o nome escrito na factura. As cobranças agrupam agora
  pelo código do cliente (nunca pelo nome da factura, que pode ser o do
  utente). Unisaúde: NIF diferentes no MetaGest, por isso são entidades
  diferentes e ficam separadas (Elmar: «se for [o mesmo NIF] é a mesma
  coisa»; não é).
- A3: o cliente «PACOTE FP» é um plano de saúde familiar: tabela
  `erp.cobrancas_planos` (só no servidor), mostrado como «Pacote FP (plano de
  saúde familiar)».

## 3-ce. Imprimir no iPhone e no iPad (01-10-2026)

- O Elmar: «Os botões imprimir … iphone não funcionam». O Safari imprime a
  página principal e não o iframe; a página principal imprime em branco
  (`ProteccaoEcra`).
- `bspImprimirHtml` no iOS chama `bspImprimirIos`: camada `#bsp-impressao`
  (Shadow DOM, estilos isolados; `body` passa a `.bsp-imp-corpo`, `@page` vai
  para a cabeça), botões Fechar, Partilhar (menu de partilha) e Imprimir
  (`window.print()` no toque). Variáveis `--papel`, `--papel-texto`.
- Testado no Chromium a fazer de iPhone: só o documento sai no papel; a escala
  (documento completo) também. **Falta confirmar num iPhone real**, também
  na aplicação do ecrã principal.

## 3-cf. Registos do Transporte em cartões no Chat (01-10-2026)

- Pedido do Elmar: «uma espécie de linha de tempo menos confusa no chat».
  As mensagens seguidas da mesma pessoa juntavam-se sem hora e os registos
  pareciam um só texto.
- `bspRegistoDaMensagem` + `CartaoRegisto`: mensagens que começam por 🚗,
  ⛽, 📝, 🔧 ou 🏠 mostram-se como cartão (barra de cor por tipo, título,
  hora sempre visível, campos em duas colunas); 10 px entre cartões seguidos.
  O texto guardado não muda, por isso vale também para os registos antigos.
- O iPhone do Elmar mostrava «Agenda» na barra de baixo: era uma versão
  guardada antiga (o código tem «Feed» desde 01-10-2026). Recarregar.

## 3-cg. Agenda privada e pública, com convidados (01-10-2026)

- Pedido do Elmar: «A mesma privacidade das tarefas quero no calendário,
  agendas privadas e agendas públicas, convidar pessoas para o evento».
- Servidor (`agenda-privada.sql`, aplicado): tabela `agenda_eventos` (dono,
  criado_por, título, descrição, local, categoria, hora, duração, dia ou
  data, privado, convidados, respostas). Regras como `tarefas_pessoais`:
  privado só para dono, quem criou, convidados e `bsp_ve_tarefas_pessoais()`
  (Direcção e Coordenação, que também põem eventos na agenda de outra
  pessoa); público para todos. `bsp_evento_responder` (só o convidado, por
  si). Gatilho `bsp_agenda_carimbo`: novidade «Convite: …» aos convidados,
  «Novo na sua agenda» ao dono quando outro põe, «Resposta a um convite» ao
  dono. Tempo real ligado. Testado com Cassia, Juliana, Solange e Elmar.
- Ecrã: `useAgendaEventos`, `CalEventModal` (criar e mudar; «Quem vê», «Na
  agenda de», «Convidar», «Local», «Descrição»), `EventoDetalhe` (respostas
  dos convidados, Vou/Talvez/Não vou, Mudar, Apagar com confirmação). Tocar
  num evento abre o detalhe (o X que apagava sem perguntar saiu). Seletor
  «Agenda de» para quem vê as agendas de todos. Início e Feed: «Próximos 7
  dias» (`useProximosEventos`). Os eventos antigos da equipa
  (`shared_state.events`) continuam; ao mudá-los passam para a tabela nova.
- `resumo-matinal` versão 11: «Hoje na agenda» por pessoa, com os eventos
  que ela pode ver; quem não tem tarefas mas tem evento seu ou convite hoje
  também recebe. A versão publicada é igual ao repositório.
- Novidade a toda a equipa (id 79).

## 3-ch. Aviso de versão nova (01-10-2026)

- O Elmar: «Nem permite editar o evento». No teste, «Mudar» e «Guardar»
  funcionam; o iPhone dele estava na versão antiga (como a barra com
  «Agenda»). Não havia forma de um aparelho aberto saber que saiu versão nova.
- `AvisoVersaoNova` (ao lado de `ProteccaoEcra`): de 5 em 5 minutos e ao
  voltar ao ecrã, `HEAD` ao `workspace.html` sem cache; se a ETag (ou
  Last-Modified) mudou, faixa «Há uma versão nova do Workspace» com
  «Actualizar». Nunca recarrega sozinho.

## 3-ci. Agenda: «Todos os meses» e eventos do Gmail (01-10-2026)

- Pedido do Elmar: pôr as marcações da Barispol do 365 e do Gmail no
  calendário privado dele, com os membros convidados.
- **365: não ligado** nesta sessão (o conector Microsoft 365 pede
  autorização nas definições de conectores do claude.ai). As reuniões do
  plano «Barispol · …» (reunião de direcção, fecho mensal, acções) foram
  apagadas do Gmail a 29-09 e devem estar no calendário do 365.
- **Gmail:** só duas séries são da Barispol; criadas na agenda privada do
  Elmar (ids na tabela, `dia_mes`): «Fichas e relatórios para o mapa de
  pagamento dos médicos» (dia 1, 08h00, convidada a Juliana; a caixa
  financas@barispol.com não é membro da equipa) e «Iniciar mapa de pagamento
  dos médicos» (dia 3, 09h00). O resto do Gmail é pessoal ou de outros
  negócios (Evolutiva, Quinta do Pinhão, AIEC) e ficou de fora.
- Novo: eventos «Todos os meses» (coluna `dia_mes`, início em `data`);
  `bspEventoNaData`/`bspEventoNoDia` tratam `e.diaMes`/`e.desde`; botão
  «Todos os meses» no formulário. `resumo-matinal` versão 12 (igual ao
  repositório) conta-os.

## 3-cj. Impressão do Stock em A4 alinhada (01-10-2026)

- A impressão no iPhone já sai (camada `bspImprimirIos`), mas a tabela vinha
  desalinhada: sem larguras, células a meia altura, datas e estados partidos.
- `bspTabelaImpressao(titulo, sub, colunas, linhas, opc)`: A4 ao alto (ou
  deitado), larguras fixas, alinhado ao topo, números à direita e sem partir,
  linhas alternadas, cabeçalho repetido por página, total de linhas. Usada em
  «Imprimir a lista» do Stock e das Validades. Usar nas listas novas.

## 3-ck. Tráfego do Supabase acima do plano (01-10-2026)

- O Elmar: «8 GB de 5». Não é espaço (base de dados 205 MB de 500 MB;
  ficheiros 231 MB de 1 GB): é o tráfego de saída («Egress», 5 GB por mês
  no plano gratuito).
- Causa principal: fotografias do Chat (pasta `conversa`, 164 MB, média 1,6
  MB, as anteriores a 30-09 sem redução) descarregadas de novo em cada
  abertura, porque o endereço assinado mudava a cada vez (1 hora, só em
  memória).
- Correcção: endereços de 24 h guardados no aparelho por pessoa
  (`bsp-urls-<id>`, `bspUrlCachePreparar`/`Gravar`/`Limpar`, apagados ao
  sair); ficheiros novos com `cacheControl` de um ano (nome único).
- Pode libertar espaço (decisão do Elmar): vídeos .mov no Chat (23 MB e
  6,6 MB), `app-debug.apk` antigo (4,6 MB), arquivo do projecto antigo em
  `privado/u1/arquivo-supabase-antigo-2026-09-24` (8,9 MB, cópia de
  segurança da migração). Registos do cron (`cron.job_run_details`, 9,8 MB)
  já se limpam ao domingo.
- Registos de 24 h: 2,77 GB em descargas de ficheiros, 1 559 pedidos, todos
  fora da cache. Nove imagens PNG do #geral (campanha Outubro Rosa, cerca de
  2,2 MB cada) foram descarregadas 93 a 116 vezes cada (cerca de 1,85 GB).
- Segunda correcção: imagens do Chat acima de 600 KB já não descarregam
  sozinhas; aparecem como cartão «Imagem · 2,1 MB · toque para ver»
  (`AnexoMensagem`). O tamanho vem de `bsp_tamanho_ficheiros`
  (`trafego.sql`, com as permissões de quem chama: só os ficheiros que a
  pessoa pode ver) e fica guardado no aparelho (`bsp-tamanhos`).
- Por decidir (Elmar): apagar as nove imagens pesadas do #geral, ou
  reenviá-las (o Chat já as reduz ao subir). O excedente deste ciclo (até
  24-10-2026) já existe; no plano gratuito o Supabase pode limitar o
  projecto. A alternativa é o plano Pro.

## 3-cl. Logotipo maior; documentação arquivada (02-10-2026)

- O Elmar: «o logo mais expressivo e respeitado, estão muito pequenos».
- Site: cabeçalho de 48 para 72 px (60 px no telemóvel; barra de 72 para
  92 px, menu do telemóvel em `top:100%`), rodapé de 52 para 76 px;
  `contacto.html` e `ecografia.html` de 42 para 64 px; `gestor.html` de 40
  para 60 px.
- Workspace (`BarispolLogo`): `sm` 38, `md` 64, `lg` 104 px. Menu lateral
  recolhido mostra o logotipo em vez da letra «B»; caixa da entrada no
  telemóvel com 92 px; cartão da clínica no menu com 36 px.
- Confirmado em capturas a 390 e a 1366 px: nada passa da largura do ecrã.
- Secções 3-b a 3-am, 4-b e 4-c passaram para `historico-2026-09.md`; as
  tarefas por fazer ficaram em «Pendentes de Setembro» (acima).

## 3-cm. Mesmas fontes em todas as páginas do site (02-10-2026)

- Contacto, Ecografia, Gestor, Outubro Rosa e Privacidade passam a usar a
  ordem da página de início: Dax, Titillium Web, Segoe UI, Arial. A
  Privacidade (antes só Arial) carrega a Titillium Web do Google Fonts.
- A Dax só aparece em aparelhos que a tenham instalada: o site não tem os
  ficheiros. Para a mostrar a todos, falta a licença web da Dax (ficheiros
  `.woff2`) — a pedir ao Elmar.

## 3-cn. Logotipo cortado no site (02-10-2026)

- O círculo branco (`border-radius:50%` na própria imagem) cortava as letras
  «CENTRO MÉDICO» e «BARISPOL» no rodapé, no cabeçalho em modo escuro e em
  `gestor.html`. Agora o círculo é pintado por trás
  (`radial-gradient(circle,#fff 70.5%,transparent 71%)`) com mais margem, e a
  imagem nunca se recorta. Confirmado em capturas, claro e escuro.
- Regra: nunca pôr `border-radius` na imagem do logotipo.

## 3-co. Logotipo cortado no Workspace (02-10-2026)

- No modo escuro (margem de 2 px) e sobre fundo marinho (10%), o círculo
  branco encostava às letras «CENTRO MÉDICO» e «BARISPOL». `BarispolLogo`
  passa a ter sempre 13% de margem (`--bsp-logo-pad`), também na regra do
  modo escuro. Confirmado em capturas a 390 e 1366 px, claro e escuro.

## 3-cp. Relatórios do Zapier no Supabase, sócio invisível e Painel clínico (02-10-2026)

- **O que parou.** Os relatórios enviados por info@barispol.ao através do
  Zapier pararam a 28-09-2026 às 08h21: o plano ficou sem tarefas (aviso
  de 08h16) e as tarefas agendadas foram depois apagadas. Pararam também,
  pelo Gmail, «Resumo diário das caixas» (24-09), «Contactos de pacientes»
  para adm@ (22-09), o pipeline da Evolutiva (18-09) e os relatórios
  diários da Quinta do Pinhão (28-09). Os dois do MetaGest (Direcção às
  05h e actividade clínica às 07h) continuam.
- **Novo: `relatorios-diarios.sql` + Edge Function `relatorios-diarios`**
  (verificação de JWT desligada, mesma autenticação da resumo-matinal):
  - `erp.direccao_dados(dia)` e `erp.clinico_dados(de, ate)`, só com a
    chave do servidor (atalhos `bsp_srv_*`).
  - 06h50 (`bsp-relatorio-direccao`): resumo do dia anterior aos sócios,
    com o Director em cópia, mais `relatorios_diarios_destinos` (o Gmail
    do Director, guardado só no servidor). Números iguais ao Painel: o
    relatório do MetaGest conta duas vezes o POS da farmácia.
  - 07h15 (`bsp-relatorio-areas`): a cada chefe de área
    (`bsp_escalas_responsaveis`) o da sua área, sem valores, com
    adm@barispol.com em cópia. Imagiologia só com actos; Serviços Gerais
    só com alertas de stock.
  - Um envio por dia e destino (`relatorios_enviados`); `{"previa": true}`
    mostra sem enviar; `{"dia": "AAAA-MM-DD"}`; `{"forcar": true}`.
- **Sócio invisível:** Francisco Pinheiro (`u1790922653166`, camada
  «Sócio», `oculto: true` em `shared_state.team`). Recebe o resumo da
  Direcção e vê só o Painel. Não aparece a ninguém (`bspOculto`,
  `bspSemOcultos`; `USERS` sem ocultos); em Admin → Utilizadores só o
  Elmar (u1) o vê. A equipa grava-se sempre inteira.
- [ ] **Elmar:** criar o acesso do sócio em Admin → Utilizadores →
  Francisco Pinheiro (palavra-passe escolhida pelo Elmar).
- **Painel clínico** (menu «Painel clínico», `PainelClinicoScreen`;
  Início `PainelClinicoCartao`): números sem valores e alertas (esgotados,
  lotes caducados ou a caducar em 30 dias, a acabar em 7 dias, facturas
  sem médico, marcações por confirmar, dia 30% abaixo da média).
  `bsp_painel_clinico(de, ate)`: cada pessoa recebe a sua área (e as que
  chefia; a Clínica também Laboratório e Recepção); gestão, Painel e
  Direcção Clínica vêem todas. Em `BSP_ECRAS_SENSIVEIS` e no guia.
- Fica de fora (precisava de ler as caixas de correio): o relatório das
  16h30 com os pendentes da Arlete e o «Resumo diário das caixas».

## 3-cq. Lembretes nos eventos, convites por e-mail, resumo das tarefas e relatórios das áreas (02-10-2026)

- **Lembretes** (`agenda-lembretes.sql`, aplicado): colunas
  `agenda_eventos.lembretes` (os de quem cria) e `lembretes_pessoa`
  (`{id: [minutos]}`, cada pessoa muda os seus por
  `bsp_evento_lembretes`). Opções em `BSP_LEMBRETES`: na hora, 5, 15 e 30
  min, 1 e 2 horas, 1 e 2 dias, 1 semana (por omissão, 30 min). Campo
  «Lembretes» no `CalEventModal`; «Os meus lembretes» no `EventoDetalhe`.
  Sino e notificação: o Workspace aberto verifica de 30 em 30 s
  (`bspLembretesDevidos`, vistos em `bsp-lembretes-vistos-<id>`). E-mail:
  cron `bsp-agenda-lembretes` (5 em 5 min) → Edge Function `agenda-avisos`
  (`{"qual":"lembretes"}`) → `bsp_srv_agenda_lembretes()`, que marca cada
  aviso em `agenda_lembretes_enviados` (nunca dois iguais).
- **Convite por e-mail no instante:** gatilho `bsp_agenda_convite_aviso`
  (só convidados novos) → `agenda-avisos` (`{"qual":"convite"}`). A
  novidade do convite fica marcada como enviada para não repetir às 05h00.
- **Tarefas por e-mail:** o resumo das 06h30 só lia o quadro da equipa,
  que está vazio; as tarefas privadas ficavam de fora e nada saía. Nova
  Edge Function `resumo-pessoal` (`resumo-pessoal.sql`: o cron
  `bsp-resumo-matinal` passa a chamá-la): tarefas da equipa, privadas
  (dono e `partilhada_com`) e agenda de cada pessoa. A 02-10-2026 saíram 7
  e-mails. O botão do Admin chama a `resumo-pessoal`. A `resumo-matinal`
  continua com os outros tipos (lembrete, colectivo, mensagens, etc.).
- **Relatórios das áreas mais completos** (comparados com os de
  info@barispol.com de 26 e 27-09): `erp.clinico_extra(de, ate)` dentro de
  `clinico_dados` e `bsp_painel_clinico` (filtrado por área):
  - Recepção: documentos FR/FT/NC, marcações passadas por fechar (por
    mês, alerta), rascunhos no MetaGest desde Julho;
  - Farmácia: vendido com o stock que fica; stock a repor (stock, saídas
    em 30 dias, dá para);
  - Laboratório: testes e consumíveis.
  No e-mail das 07h15 (`relatorios-diarios` versão 2) e no Painel clínico.
- Não se refaz: ocorrências e fechos de turno (vinham do correio) e as
  listas com nomes de utentes (fichas por corrigir, exames por lançar).

## 3-cr. Eventos no calendário do e-mail e «Solicitação de material» (02-10-2026)

- **Pedido do Elmar:** «Tudo que for evento de um funcionário coloque no
  seu email ou faça convite no seu Email». Novo `agenda-convites-email.sql`
  (aplicado): cada evento da Agenda (`agenda_eventos`) manda por e-mail o
  convite de calendário `convite.ics` a quem está nele.
  - Criar: o dono e os convidados (Edge Function `agenda-avisos`,
    `qual` «convite»; o dono recebe «Na sua agenda»).
  - Mudar hora, dia, data, duração, título ou local: `ics_seq` sobe
    (gatilho `bsp_agenda_ics_seq`) e quem está no evento recebe «Evento
    alterado» com o mesmo UID (`agenda-<id>@barispol.com`).
  - Sair do evento ou apagá-lo: «Cancelado» com `METHOD:CANCEL`.
  - Para gravar sem e-mail: `select set_config('bsp.sem_convite', '1', true)`
    na mesma transacção.
  - `bright-worker` versão 6: aceita um anexo `.ics` em base64
    (`text/calendar`), só do servidor.
- **«Solicitação de material»** (pedido do Elmar, era um evento do iPhone da
  Arlete): evento, e não tarefa, porque tem hora fixa e repete-se. Três
  eventos na agenda da Arlete (u2), com a Solange Orlando (u17)
  convidada: segunda, quarta e sexta, 08h00–10h30, na Clínica, lembrete
  30 min antes (ids 10, 11 e 12). As duas receberam um só e-mail com o
  aviso de que passa a estar no Workspace e o convite.
- [ ] A Arlete pode apagar o evento antigo do iPhone, para não o ter a
  dobrar.
- Os eventos antigos da equipa (`state.todayEvents`) não mandam convite.

## 3-cs. O Workspace aberto todo o dia (02-10-2026)

- **Pedido do Elmar:** o e-mail diário deve dizer que o Workspace fica
  aberto no computador todo o dia, porque é uma ferramenta de trabalho.
  `resumo-matinal` versão 13: o lembrete das 07h30 e o aviso colectivo
  (seg/qua/sex, 12h00) levam essa frase. Quem não trabalha ao computador
  mantém a aplicação aberta no telemóvel.
- Comunicado isolado de hoje, assinado «Recursos Humanos», com resposta
  para a Arlete (RH, u2): pré-visualização enviada ao Elmar a 02-10-2026.
  [ ] Envio a toda a equipa depois da aprovação do Elmar (regra 3).
- Botão do sino: «Activar notificações» (antes «Ativar», fora da regra 5).

## 3-ct. Relatório de Imagiologia para a Direcção Clínica (02-10-2026)

- Pedido do Elmar: o relatório diário de Imagiologia (07h15) vai para o
  Director Clínico, Osvaldo Pacheco (u14), com adm@barispol.com em cópia.
  Antes ia para a Arlete (u2), responsável da área nas escalas.
- `relatorios-diarios` versão 3: `PARA_AREA` (`radiologia` → `u14`). As
  outras áreas continuam com o responsável da escala
  (`bsp_escalas_responsaveis`).

## 3-cu. Gestão clínica no relatório da Direcção Clínica (02-10-2026)

- Pedido do Elmar: ver o que falta no relatório da Direcção Clínica e o
  que é útil em gestão clínica internacional. Novo `direccao-clinica.sql`
  (aplicado): `erp.direccao_clinica_dados(dia)` e
  `bsp_srv_direccao_clinica(dia)`, 30 dias até ao dia, modelo JCI/OMS:
  - Acesso: faltas (referência abaixo de 10%), cancelamentos, espera
    entre o contacto e a consulta (mediana e média).
  - Continuidade: utentes novos, reconsulta em 7 e em 30 dias.
  - Prática clínica: exames de laboratório por consulta, imagem por 100
    consultas, exames enviados para fora, pedidos por médico.
  - Rastreabilidade: facturas clínicas com médico solicitante
    (referência 100%).
  - Governação: escalas à espera do visto, trocas por aprovar,
    relatórios de turno, avarias, formações, ausências.
  - Alertas quando passa da referência.
  No relatório da Clínica das 07h15 (`relatorios-diarios` versão 4), que
  vai para a Direcção Clínica (u14). Cerca de 7 s de cálculo.
- Falta para o modelo internacional (não há dados no sistema):
  - satisfação do utente;
  - incidentes e eventos adversos;
  - tempo de espera na sala;
  - tempo de entrega dos resultados do laboratório;
  - cumprimento de protocolos.
  Os relatórios de turno das áreas médicas (menu Relatórios) nunca foram
  preenchidos.
- **Números reais** (02-10-2026, pedido do Elmar: «além de % coloque
  números reais»). `relatorios-diarios` versão 5. Cada percentagem leva a
  contagem ao lado («6 de 235 utentes»). Secções novas no relatório da
  Clínica, todas com contagens e sem valores:
  - comparação com os 30 dias anteriores (atendimentos, consultas,
    exames, imagem, marcações, faltas, cancelamentos), com a diferença
    em números e em %;
  - afluência por dia da semana (total e média por dia) e por hora;
  - consultas por tipo (30 dias contra os anteriores);
  - exames de laboratório, de imagem e enviados para fora mais pedidos;
  - marcações por médico (compareceu, faltou, cancelou);
  - utentes por financiador (particular, seguradora, empresa) e por
    seguradora;
  - dias com consultas e consultas por dia de cada médico.

## 3-cv. Regulamento interno nas regras do sistema (02-10-2026)

- Pedido do Elmar: «colocar o regulamento interno nas regras do sistema;
  ler os artigos e, sempre que necessário, usar sem ter de ir ler todo
  ele».
- **O texto não está no repositório.** O repositório é público (serve
  barispol.com) e o regulamento é do foro interno. Fica no servidor:
  - `documentos_texto` (`documentos-texto.sql`, aplicado): o texto de
    cada documento de Documentos. Só o servidor lê.
  - `conhecimento` (mesmo ficheiro): resumo por secção, chave
    `regulamento-interno`, com as referências RI-1 a RI-10, as notas
    internas e onde o Workspace já as aplica. Para ler:
    `select texto from public.conhecimento where chave = 'regulamento-interno'`.
- Edge Function `documento-texto` (versão 3, verificação de JWT
  desligada, autenticação própria): lê os .docx e os PDF de
  `documentos/` (nunca os anexos do Chat). Os PDF digitalizados ficam
  `pdf-sem-texto` até haver `ANTHROPIC_API_KEY`; com a chave, o Claude
  transcreve-os. Cron `bsp-documentos-texto` às 04h20 UTC (05h20 de
  Luanda), aplicado e activo.
- `assistente` versão 2: junta o `conhecimento` às regras e responde às
  perguntas sobre regras de trabalho com a referência «RI-x.y».
- Estado: o regulamento (.docx, 62 502 caracteres) está lido. As 8 notas
  internas em PDF são digitalizações e esperam pela chave da Anthropic
  (colada pelo Elmar). Duas notas têm o mesmo número
  (BRSP-DG-NINT-24-001): falta renumerar uma.

## 3-cw. Documentos: enviar para o Chat (02-10-2026)

- Pedido do Elmar: «coloque a opção de enviar o documento para o chat,
  um atalho ou algo parecido».
- `DocumentosScreen`: botão «Enviar para o Chat» em cada documento em
  vigor (fora da vista «Ver como»). Escolhe-se o canal, o grupo ou a
  pessoa. A mensagem leva o título, o número, a descrição curta, a
  categoria e a data de entrada em vigor, e termina com
  `[documento:<id>]`, que o Chat troca pelo botão «Abrir o documento»
  (`BotaoDocumento`). O ficheiro não se copia para o Chat: abre sempre a
  versão em vigor e a leitura continua a contar em Documentos.
- Ficha do guia de Documentos actualizada.

## 3-cx. Qualidade clínica: as 5 etapas (02-10-2026)

- Pedido do Elmar: «avance com as 5 etapas» (o que faltava no relatório
  da Direcção Clínica para o modelo internacional).
- Relatórios de turno (`BSP_RELATORIOS`, campos de `BSP_CAMPOS_AREA`):
  1. Incidentes: `incidentes`, `quase_erros`, `incidente_tipo` (todas as
     áreas).
  2. Satisfação: `satisf_resp`, `satisf_ok`, `reclamacoes` (Recepção).
  3. Espera: `espera_min`, `espera_30` (Recepção).
  4. Laboratório: `amostras`, `amostras_rejeitadas`,
     `resultados_entregues`, `resultados_atraso`, `tat_horas` (este é
     opcional, campo `opcional: true`).
  5. Protocolos: `prot_verificados`, `prot_conformes`, `prot_falhas`
     (Farmácia, Laboratório, Imagiologia, Enfermagem).
  A parte nunca passa do todo (o ecrã recusa). Só números, sem nomes.
- `qualidade-clinica.sql` (aplicado): `erp.qualidade_clinica_dados(dia)`,
  30 dias e os 30 anteriores, com alertas (incidentes com dano; satisfação
  abaixo de 85%; mais de 20% com espera acima de 30 min; resultados no
  prazo abaixo de 95%; amostras rejeitadas a partir de 2%; protocolos
  abaixo de 95%). `bsp_srv_direccao_clinica` junta a chave `qualidade`.
  Os ids dos campos são lidos pelo servidor: mudar os dois lados juntos.
- Espera pelo MetaGest: não há hora de chegada. A permanência (primeira à
  última factura do mesmo utente no mesmo dia, só com mais de uma) dá
  uma aproximação: mediana de 20 min em 30 dias (28 nos 30 anteriores),
  30 de 116 utentes acima de 1 h. A hora das marcações não serve: só uma
  marcação «Compareceu» tem a ficha ligada.
- O Drive tem a lista de contactos de utentes do WhatsApp (nomes,
  telefones, datas). Não tem respostas de satisfação. Não entra no
  repositório. A satisfação conta-se pela Recepção no relatório de turno.
- `relatorios-diarios` versão 7: secção «Qualidade e segurança do utente»
  no relatório da Clínica (Direcção Clínica), com «Sem dados ainda»
  enquanto as áreas não preencherem. Novidade às áreas de saúde, à
  Recepção, à Direcção Clínica e à gestão.
- Por fazer: notificação individual de incidentes, com análise da causa
  (ficha própria), se a Direcção Clínica a quiser.

## 3-cy. Relatório da Clínica: todas as áreas no quadro (02-10-2026)

- Pedido do Elmar (imagem do quadro com Utentes, Consultas e Exames de
  laboratório): «neste campo coloque todas as áreas que temos no centro».
- `relatorios-diarios` versão 8: o quadro do relatório da Clínica tem três
  linhas. Utentes, Consultas, Laboratório (exames e utentes); Raio-X,
  Ecografias, Cardiologia; Enfermagem (actos e utentes), Farmácia
  (unidades e utentes), Exames enviados para fora. Números do MetaGest
  (`bsp_srv_clinico_dados`), sem valores.
