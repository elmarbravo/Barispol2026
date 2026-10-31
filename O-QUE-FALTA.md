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
- Conferido com os dados reais de uma médica (Setembro): doentes, consultas,
  exames e facturas batem certo; a soma dos grupos dá o mesmo total. (Valores
  retirados do repositório a 12-10-2026, regra 4.)

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
  [x] Enviado a 02-10-2026 a 23 pessoas (aprovação do Elmar), com as
  respostas para rh@barispol.com. A Resend recusou 13 por excesso de
  velocidade (10 por segundo); reenviados em lotes de 5, todos aceites.
  Envios em massa pela base de dados: no máximo 5 por pedido.
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

## 3-cz. Notificações: as 3 ideias (02-10-2026)

- Pedido do Elmar: «As 3 ideias implementa» (A, B e C da proposta das
  notificações).
- **A. Pedido em ecrã inteiro** (`PedidoNotificacoes`): enquanto o
  navegador não tiver resposta, fica à frente de tudo, só com «Activar
  notificações». Bloqueadas: explica o cadeado, com «Já activei» e
  «Continuar sem notificações» (uma vez por dia). iPhone fora do ecrã
  principal: explica «Adicionar ao ecrã principal» (uma vez por dia). Na
  app Android não aparece (é a C). Cada aparelho grava o estado
  (`notificacoes_estado`, `bsp_notif_estado`). Admin → «Notificações»
  (`AdminNotificacoes`, `bsp_notif_estado_lista`, só a gestão): quem tem
  activas, com o Workspace fechado, bloqueadas ou por activar.
- **B. Web Push** (`notificacoes-push.sql`, aplicado; Edge Function
  `push-enviar` versão 1, verificação de JWT desligada; `sw.js` na raiz;
  `workspace.webmanifest` para o iPhone):
  - Chaves VAPID criadas no servidor e guardadas no cofre
    (`bsp_vapid_publica`, `bsp_vapid_privada`). A privada nunca saiu do
    servidor.
  - O aparelho regista-se ao entrar (`bspPushActivar` →
    `bsp_push_registar`).
  - Avisos: mensagens directas, grupos com membros, menções (só em canais
    que a pessoa vê; nunca em directas, grupos privados nem tarefas
    privadas), Feed, tarefas da equipa atribuídas, tarefas privadas
    delegadas ou partilhadas, documentos novos e convites da agenda.
  - Nunca: recibos e edições, históricos do WhatsApp, mensagens com mais de
    10 minutos, o próprio autor.
  - Com o push activo, o Workspace não repete o aviso do sistema para o
    mesmo caso (`bspIncoming(..., coberto)`). O `sw.js` cala-se quando o
    Workspace está à frente (menos no Safari, que o exige).
  - Testado: a cifra decifra na biblioteca de referência (`http_ece`), a
    assinatura VAPID confere, o `sw.js` mostra o aviso (CDP), os gatilhos
    produzem os pedidos certos (testes desfeitos no fim). Falta: um aviso
    real entregue a um telemóvel (o contentor não chega à Google).
- **C. App Android:** ver 3-da.

## 3-da. Notificações na app Android (ideia C, 02-10-2026)

- Pronto do nosso lado, à espera do Firebase:
  - `app-android.yml`: com o segredo `GOOGLE_SERVICES_JSON` no GitHub, o
    APK leva o `google-services.json` e o plugin
    `@capacitor/push-notifications@8.1.2`. Sem o segredo, sai como antes
    (o plugin sem Firebase fechava a app ao registar).
  - O Workspace, na app, só pede a permissão e regista o aparelho quando o
    APK tem o plugin (`bspPushApp`). Registo «fcm:<token>» em
    `push_subscricoes`. Tocar no aviso abre o sítio certo.
  - `push-enviar` versão 2 envia pelo Firebase (API v1) com o segredo
    `FCM_SERVICE_ACCOUNT` nas Edge Functions.
  - `google-services.json` está no `.gitignore` da app.
- [ ] **Passos do Elmar** (uma vez, com a conta Google da Barispol):
  1. console.firebase.google.com → «Criar projecto» (por exemplo
     «Barispol Workspace»).
  2. «Adicionar app» → Android → nome do pacote `com.barispol.workspace` →
     descarregar o `google-services.json`.
  3. GitHub → repositório → Settings → Secrets and variables → Actions →
     «New repository secret»: nome `GOOGLE_SERVICES_JSON`, valor = o texto
     todo do ficheiro.
  4. Firebase → Definições do projecto → «Contas de serviço» → «Gerar nova
     chave privada» (ficheiro JSON). No Supabase → Edge Functions →
     Secrets: nome `FCM_SERVICE_ACCOUNT`, valor = o texto todo do ficheiro.
     Este ficheiro tem uma chave privada: nunca no repositório nem no chat.
  5. Actions → «App Android» → «Run workflow» e instalar o APK novo uma vez
     em cada telemóvel.

## 3-db. Relatório da Recepção: qualidade do atendimento (02-10-2026)

- Pedido do Elmar: «Esse relatório da receção está muito vago e
  redundante, coloque dados de qualidade de atendimento da equipa».
- `recepcao-qualidade.sql` (aplicado): `erp.recepcao_qualidade(dia)` e
  `bsp_srv_recepcao_qualidade(dia)` (só a chave do servidor).
- `relatorios-diarios` versões 9 e 10, relatório da Recepção das 07h15:
  - quadro: utentes, WhatsApp de ontem (respondidos em 15 min), marcações
    de hoje;
  - «Pontos de atenção»: relatório de turno por entregar, primeira resposta
    no WhatsApp acima de 15 min, esperas acima de 1 h, preço pedido e não
    dado, notas de crédito, quem não abriu o Workspace, marcações de ontem
    em aberto, marcações de amanhã sem contacto;
  - WhatsApp (`crm.caixa`): mediana da primeira resposta, % em 15 min,
    preço dado, marcados na conversa; tabela por colaborador (7 dias);
  - facturação de ontem por colaborador (MetaGest): documentos, sem médico
    solicitante, notas de crédito, rascunhos;
  - marcações de ontem e de amanhã, e as registadas no Workspace por
    colaborador (telefone, e-mail, ficha);
  - Workspace aberto ontem (`presenca_dias`): entrou, saiu, horas;
  - relatório de turno: espera, satisfação, reclamações, incidentes.
  - Saiu a tabela das consultas (já está no da Clínica) e a dos tipos de
    documento (FR, FT, NC).
  - Versão 10: sem médico, marcações passadas por fechar e rascunhos ficam
    só nos alertas do topo (antes repetiam-se no fim).
- Nomes da equipa, nunca de utentes.

## 3-dc. Avarias e património (02-10-2026)

- Pedidos do Elmar: apagar as avarias repetidas do Emmanuel (a mesma, 8
  vezes, por falha de rede) e alargar as avarias a todo o património.
- `avarias-patrimonio.sql` (aplicado):
  - coluna `categoria`;
  - gatilho `bsp_avaria_0_repetida`: a mesma pessoa com o mesmo texto em 10
    minutos não cria outra avaria. Tem um bloqueio para toques simultâneos,
    e corre antes de `bsp_avaria_carimbo`, que cria a novidade;
  - `bsp_avaria_apagar(id)`: a gestão apaga; quem reportou apaga a sua na
    primeira hora, enquanto ninguém lhe pegou.
- Ecrã «Avarias e património» (`AvariasScreen`):
  - tipo do bem (`BSP_AVARIA_CATEGORIAS`) e filtro por tipo;
  - «Editar»: quem reportou, enquanto está aberta; a gestão e os Serviços
    Gerais, sempre;
  - «Apagar», e para a gestão «Apagar as repetidas» (fica a primeira);
  - o botão «Reportar» fica parado enquanto envia.
- [ ] As 7 cópias de «2 ventoinhas» (02-10-2026, 09:02) ficaram para o
  Elmar apagar com «Apagar as repetidas».

## 3-dd. Menos e-mails: plano gratuito da Resend (02-10-2026)

- Pedido do Elmar: «Não envie emails hoje, amanhã apenas. Vamos diminuir o
  número de emails desnecessários.» A Resend contou 121 a 02-10-2026. O
  plano gratuito dá 100 por dia e 3000 por mês.
- A causa principal: cada documento novo mandava um e-mail por pessoa
  (`documento-aviso`). Foram 6 documentos para cerca de 22 pessoas, ou
  seja, cerca de 130 e-mails.
- `emails-pausa.sql` (aplicado):
  - `emails_pausa`: pausa até 03-10-2026, 00h00 de Luanda. A `bright-worker`
    (versão 7) responde `{"pausado": true}` e não envia;
  - `emails_registo`: cada envio (assunto, número de destinatários,
    resultado), sem endereços;
  - tecto: com 95 destinatários servidos no dia, nada mais sai até à
    meia-noite (`bsp_emails_pausa_ate`);
  - documento novo: entra como novidade (`bsp_documentos_publicado`). Vai
    no e-mail das 05h00, no sino e no aviso do telemóvel, e já não sai um
    e-mail por pessoa;
  - colectivo das 12h00 (`bsp-aviso-coletivo`) desligado.
- `resumo-matinal` versão 14:
  - o lembrete das 07h30 só vai a quem não abriu o Workspace nos 2 dias
    anteriores (`presenca_dias`);
  - o aviso de mensagem por ler não vai por e-mail a quem tem avisos no
    telemóvel (`push_subscricoes` vista nos últimos 14 dias).
- `relatorios-diarios` versão 11: o relatório da Recepção repetia os
  números do e-mail «WhatsApp de ontem» das 08h00 (`wa_resumo_8h`). Saíram
  dele o WhatsApp (mosaico, tempos de resposta, preço, tabela por
  colaborador) e o «Workspace aberto ontem». Fica uma linha a remeter para
  o das 08h00. O mosaico passa a «Documentos ontem».
- [ ] 03-10-2026: confirmar em `emails_registo` que o dia fica abaixo dos
  95 e que não há envios com `pausado` depois da meia-noite.

## 3-de. Comunicado só com texto (02-10-2026)

- O Elmar não conseguia publicar o comunicado «Migração do sistema
  MetaGest»: a janela «Publicar documento» exigia sempre um ficheiro.
- `DocPublicarModal`: nos comunicados o ficheiro é opcional. Sem ficheiro,
  o «Texto do comunicado» é obrigatório e grava-se com `caminho` e
  `nome_ficheiro` vazios.
- `DocumentosScreen`: sem ficheiro, o cartão não mostra «Abrir» e a leitura
  confirma-se logo, porque o texto está no próprio cartão.
- A janela e a ficha do guia já não dizem que sai um e-mail no instante
  (ver 3-dd).

## 3-df. Quem está online (02-10-2026)

- O Elmar via colegas ligados como «offline». Havia duas causas:
  - o ponto verde só seguia a ligação em tempo real (`bsp-presenca`), que
    cai com a rede móvel e nos separadores de fundo;
  - a lista da Equipa e a ficha mostravam o estado gravado na ficha
    (`u.status`), que nunca muda sozinho.
- Agora `bspEstadoDe(user)` / `bspEstaOnline(id)`: online se estiver no
  tempo real ou se o aparelho deu sinal na tabela `presenca` nos últimos 3
  minutos (`BSP_ONLINE_MS`). O ecrã relê a `presenca` a cada minuto
  (`__bspVistos`), só com o Workspace à vista.
- O sinal «estou aqui» passa a sair também com o Workspace num separador
  de fundo, e nunca durante «Ver como». Consequência: o e-mail de mensagem
  directa por ler (tipo `mensagens` da `resumo-matinal`) não vai a quem tem
  o Workspace aberto noutro separador.
- [ ] Confirmar com o Elmar, com duas pessoas ligadas, que o ponto verde
  bate certo.

## 3-dg. Alterar documentos e recibos de leitura com nomes (02-10-2026)

- Pedido do Elmar: «permita alterar os nomes das notas internas e datas» e
  «a nota preciso alterar descrição e título».
  - `DocPublicarModal` com `editar`: botão «Alterar» em cada documento,
    para quem publica. Muda o tipo, o título, o número, a data «em vigor
    desde» e a descrição, e troca o ficheiro só se se escolher outro. Não
    volta a avisar nem a pedir leitura (para isso há «Nova versão»). A
    regra `documentos_mudar` do servidor já o permitia.
  - A publicação no Feed e no #avisos de um comunicado fica com o título
    antigo.
- Pedido do Elmar: «active o recibo de leitura de todos para ver quem
  ignora».
  - Toda a gente já registava a leitura, e não há forma de a desligar.
  - `RecibosMensagem`: em cada mensagem própria, «Visto por X de Y · Z por
    ver». Ao carregar, abre a lista de quem viu e de quem não viu, com a
    última leitura de cada pessoa (`state.leiturasEm`). Nas directas:
    «Visto» ou «Enviado, por ver». A Direcção e a Coordenação
    (`bspVeRecibosDeTodos`) vêem-no em todas as mensagens dos canais.
  - Quem deve ler: `bspDestinatariosConversa` (quem vê o canal, sem
    sócios nem ocultos).
  - Só conta como lido com o Workspace à vista. Antes, uma conversa
    aberta num separador de fundo marcava como lido o que ninguém viu.
  - Ao abrir uma conversa, o ecrã pede todos os recibos dela (um por
    pessoa), além das 300 mensagens mais recentes.

## 3-dh. Fotografias do Transporte e documentos por destinatário (02-10-2026)

- Transporte. Pedido do Elmar: fotografias «apenas 4 vezes por dia». O
  motorista tirava cerca de 20 por dia (nunca foram obrigatórias, mas o campo
  aparecia em todas as viagens).
  - Fotografia obrigatória na primeira saída da manhã e na primeira da
    noite (a partir das 19h00, `bspTranspPrimeiraDoTurno`), e em cada
    «Cheguei a casa».
  - «Terminar viagem» e as outras saídas já não mostram o campo.
  - Os km continuam obrigatórios em todos os registos.
  - O recibo do abastecimento continua opcional.
- Documentos. Pedido do Elmar: «faça um filtro de quem pode ver, tenho uns
  de médicos».
  - `documentos-destino.sql` (aplicado): coluna `grupos` (os grupos das
    novidades; por omissão, `{todos}`). A regra `documentos_ler` passa a ser
    `bsp_ve_documento`: vêem os grupos, quem publica documentos e quem o
    publicou.
  - Fora de «todos», não sai publicação no Feed nem no #avisos; a novidade
    e o aviso do telemóvel vão só aos grupos.
  - Ecrã: «Para quem» na janela de publicar e de alterar (`BSP_DOC_GRUPOS`,
    `bspNosGrupos`). As leituras contam só entre os destinatários.
    «Enviar para o Chat» de um documento restrito não leva o texto.
  - Testado no servidor: a Recepção deixou de ver um documento só para a
    Clínica, e a Clínica viu-o (transacção desfeita no fim).
  - O ficheiro no armazenamento não tem regra própria: quem não vê o
    documento não sabe o endereço, mas ele não está fechado por área.

- Correcção do Elmar no mesmo dia: «por camada ou cargo, não por pessoa».
  - `grupos` passa a ter `todos`, `camada:<nome>` ou `cargo:<família>`.
  - As famílias saem do texto do cargo (`bsp_cargo_grupos` no servidor,
    `BSP_DOC_CARGOS` no ecrã): médicos, radiologistas, enfermeiros,
    técnicos, chefes e supervisores, recepção, administrativos e motorista.
  - Regra de leitura: `bsp_doc_no_grupo`. A novidade e o aviso do telemóvel
    levam a lista de ids (`bsp_doc_destinatarios`).
  - Contagens no servidor (02-10-2026): médicos 5, radiologistas 2,
    enfermeiros 4, técnicos 3, chefes 6, recepção 3.
  - Um cargo novo com um nome diferente fica fora das famílias: rever
    `bsp_cargo_grupos` e `BSP_DOC_CARGOS` juntos.

## 3-di. Mapa de férias da equipa (02-10-2026)

- Pedido do Elmar: «nas férias, quem vê? pode estar lá todo mapa de quem vai
  de férias quando na equipa?».
- Antes: cada pessoa via os seus pedidos, o chefe os da sua equipa
  (`bsp_chefe_de`) e a gestão todos. Não havia mapa geral.
- `ferias-mapa.sql` (aplicado): `bsp_mapa_ferias(ano)` devolve só as férias
  aprovadas (pessoa, início, fim) a toda a equipa, sem sócios. Doença,
  faltas, licenças, notas e pedidos por decidir continuam privados
  (`ausencias_ler`).
- Ecrã: `MapaFerias` em Equipa → Férias e ausências, por mês, com o ano
  actual e o seguinte. Avisa quando duas pessoas da mesma área estão fora
  ao mesmo tempo. Serve o plano anual do RI-6.1.
- [ ] Ainda não há pedidos de férias gravados: o mapa começa vazio. O plano
  anual de cada pessoa entra como pedido de férias e é aprovado pelo
  superior.

## 3-dj. Sessão só enquanto o Workspace está aberto (02-10-2026)

- Pedido do Elmar: «tem contas a abrirem sem início de sessão, podes tirar
  isso de iniciar sozinho?».
- Antes: a sessão ficava no `localStorage` e entrava sozinha sem prazo. Num
  computador partilhado abria a conta de outra pessoa.
- Agora `bspGetClient` guarda a sessão no `sessionStorage`. Recarregar a
  página no mesmo separador mantém a sessão; fechar o navegador ou a app
  pede outra vez o e-mail e a palavra-passe. As sessões antigas
  (`sb-…-auth-token` no `localStorage`) apagam-se ao abrir.
- Um separador novo (por exemplo, aberto por uma notificação com o
  Workspace fechado) também pede a palavra-passe.
- Os avisos do telemóvel e do navegador continuam a chegar ao aparelho
  onde a pessoa os activou, mesmo depois de a sessão terminar.
- Recibos: a Joice aparecia como «viu» estando offline. Estava certo: leu
  às 12h02 e às 12h05 e fechou às 12h06. «Visto» é leitura em algum
  momento, e não estar ligado agora.

## 3-dk. Leitor de PowerPoint (02-10-2026)

- Pedido do Elmar: «podes colocar leitura pptx no workspace».
- `LeitorPptx` / `bspVerPptx` / `bspPptxLer`: leitor próprio sobre o JSZip
  (`vendor/docx/jszip.min.js`). Desenha cada diapositivo com o texto
  (tamanho, negrito, itálico, cor, alinhamento), as imagens, as formas com
  cor, o fundo e as tabelas, nas posições do original. Os gráficos e o
  SmartArt aparecem como «[gráfico]».
- `bspAbrirFicheiro` abre os .pptx no visor (Drive, Chat, Documentos).
  Documentos aceita .pptx. O .ppt antigo descarrega-se.
- Testado com uma apresentação de 3 diapositivos (título, lista, forma,
  imagem, tabela): tudo no sítio, sem erros. As marcas de lista que vêm só
  do diapositivo-mestre não aparecem.

## 3-dl. Escalas de Pediatria e Ginecologia de Outubro (02-10-2026)

- O Elmar enviou os PowerPoint do Director Clínico (Pediatria, três cópias
  iguais, e Ginecologia e Obstetrícia) e pediu «coloca as escalas em vigor,
  o director é que enviou».
- Pediatria: entrou na escala da Clínica de Outubro (id 12) como turnos
  opcionais p1 (terça 13–19h, u7), p2 (quarta e quinta 10–16h, «x:Dra.
  Alaide Diogo» e «x:Dr. Joia Manuel», sem conta no Workspace) e p3
  (sexta 14–20h, u7). As quartas levam a nota «só com marcação». A escala
  ficou publicada com o visto de u14 (`bsp.visto = '1'`), em vigor. Os
  dias de manhã e de tarde que o Director tinha começado (só 3 dias)
  ficaram como estavam.
- [ ] Ginecologia e Obstetrícia: falta saber em que dias são as duas
  sessões das 14h da Dra. Conceição (o diapositivo não o diz) e se a
  Dra. Géssica entra só «por marcação/chamada». O título interno diz
  «Setembro».
- Em falta (02-10-2026): Outubro de Administração e Enfermagem (não
  existem), Serviços Gerais (rascunho completo, sem visto) e a escala
  geral da Clínica (só 3 dias). Novembro: só a Recepção começou
  (rascunho).
- Decisões do Elmar no mesmo dia: «administração não há escala, elimine» e
  «serviços gerais aprova».
  - A Administração sai do ecrã das Escalas (`EscalasScreen`); no servidor
    já estava fora de `bsp_escalas_responsaveis` e dos avisos. A escala
    vazia de Setembro da Administração foi apagada.
  - Serviços Gerais de Outubro (id 6): publicada e em vigor sem visto da
    Direcção Clínica, por aprovação do Elmar (`exige_visto = false`).

## 3-dm. Painel clínico e actividade dos médicos (02-10-2026)

- Pedido do Elmar: «o painel clínico os médicos não podem ver tudo».
  - Antes, toda a equipa (menos sócios) tinha o Painel clínico, e quem era
    da Clínica (os médicos) recebia a tabela «Por médico» com a produção
    dos colegas.
  - Agora (`painel-clinico-acesso.sql`, `bspVePainelClinico`,
    `bspChefeDeArea`): vêem tudo a gestão, quem vê o Painel e a Direcção
    Clínica; os chefes de área vêem só a sua área; os outros não têm o
    menu, e o servidor recusa. A tabela «Por médico» só vai a quem vê tudo.
- Pedido do Elmar: «o Dr. Osvaldo pode ver a produção de todos, a
  actividade e escolher que médicos quer ver».
  - «A minha actividade»: a Direcção Clínica, a gestão e quem vê o Painel
    (`bspEscolheMedicoActividade`) têm uma lista com os médicos do MetaGest
    (`bsp_metagest_medicos`, 52 com facturas desde 2025), também os que não
    têm conta no Workspace (valor `mg:<código>`).
  - A actividade mostra o valor facturado (Kz) de cada médico.
- Decisão do Elmar no mesmo dia: «quantidades apenas». Quando a Direcção
  Clínica vê outro médico, `bsp_minha_actividade` tira os valores
  (`sem_valores: true`): só doentes, consultas, exames, facturas e actos. O
  gráfico mostra doentes por mês. Cada médico na sua actividade, a gestão e
  quem vê o Painel continuam com os valores. Testado no servidor (u14 sem
  valores, u1 com valores).
- Medicina geral de Outubro (PowerPoint do Director Clínico, 02-10-2026):
  carregada na escala da Clínica (id 12), com os 31 dias. Turnos t1 manhã
  07:00–15:45 e t2 tarde 15:45–22:00 (segunda a sexta), t3 fim-de-semana
  07:00–22:00 (Dra. Creusa ao sábado, Dra. Luidmila ao domingo). Os turnos
  da Pediatria (p1–p3) ficaram. Dr. Pedro Feliciano, Dr. Edgar e Dr.
  Gabriel entram como «x:Nome» (sem conta). «Dra. Egdar» (dia 6) lido como
  Dr. Edgar; no dia 28 o Dr. Edgar faz manhã e tarde, como no ficheiro.
  Visto de u14, em vigor.

## 3-dn. Workspace sem sincronização depois da sessão no sessionStorage (02-10-2026)

- Sintoma: «A dra Ludmila não vê a actividade dela». A conta da Dra.
  Ludmila Da Silva (criada às 16h24) ficou sem ficha na equipa.
- Causa: desde a mudança da sessão (12h44), o `bspGetClient` guarda a sessão
  no `sessionStorage`, mas o cliente da sincronização (o que lê e grava o
  `shared_state`, recebe em tempo real e dá o sinal de presença) procurava-a
  no `localStorage` e ficava à espera para sempre. Quem recarregou o
  Workspace desde então não gravou nada no estado partilhado: a ficha nova
  ficou só no aparelho do Elmar. Nenhuma gravação do `shared_state` entre
  as 12h44 e a correcção.
- Correcção: o cliente da sincronização usa o mesmo `sessionStorage`.
  Testado com servidor simulado: antes não lia nada; agora lê mensagens e
  estado e grava a presença.
- Dra. Ludmila Da Silva acrescentada à equipa no servidor (Clínica, camada
  Clínica, MetaGest `HLC-PRAC-2026-00001`) e à lista `USERS`. Não confundir
  com a Dra. Luidmila Verónica Chitata (u6, `HLC-PRAC-2025-00002`).
- Simulado no servidor: `bsp_minha_actividade` com a sessão dela devolve
  `ligado: true`.
- Alterações feitas hoje à equipa ou às tarefas da equipa depois das 12h44
  podem não ter ficado gravadas: confirmar e refazer.

## 3-do. Escala da Clínica de Outubro: duas médicas e o visto (02-10-2026)

- Sintoma: a Dra. Ludmila Da Silva não via nenhuma escala.
- Causas:
  1. Na carga do PowerPoint da Medicina Geral juntei «Dra. Ludmila» e
     «Dra. Luidmila» na u6. O PowerPoint distingue-as. Corrigido na escala 12:
     - Ludmila Da Silva (`u1790954656000`): segundas e quartas de manhã,
       sextas à tarde e domingo 11, 11 turnos.
     - Luidmila Chitata (u6): quintas à tarde e domingos 4, 18 e 25, 8 turnos.
  2. A Direcção mudou a escala no ecrã às 15h41 e o visto apagou-se: a
     escala saiu de vigor e ninguém a via. Reposta em vigor com
     `exige_visto = false` (decisão do Elmar: «o director é que enviou»).
- Para não se repetir (`escalas-visto-gestao.sql`, aplicado): uma mudança
  feita pela gestão ou pela Direcção Clínica mantém o visto. A de um chefe
  de área continua a apagá-lo, mas o ecrã pergunta antes
  (`bspMantemVistoEscala`). Testado no servidor com desfazer: Elmar mantém,
  outra pessoa tira de vigor.
- Por decidir (Elmar): o rascunho de Novembro da Clínica (id 13) herdou a
  u6 em 13 turnos (sextas à tarde e domingos incluídos). Rever quem é cada
  uma antes de publicar.
- Nas cargas de PowerPoint: nomes parecidos nunca se juntam; na dúvida,
  perguntar.

## 3-dp. Avarias por área (02-10-2026)

- Pedido do Elmar: «as avarias não podem aparecer todas para todos, só
  aparece aos demais as que a sua área reporta».
- Servidor (`avarias-por-area.sql`, aplicado): a regra `avarias_ler` deixa
  ler tudo só à gestão e aos Serviços Gerais (`bsp_trata_avarias`). Os
  outros lêem as suas e as reportadas por colegas da sua área
  (`bsp_ids_da_minha_area()`, calculada uma vez por consulta). Quem não tem
  área só vê as suas.
- Ecrã: linha «Vê as avarias reportadas pela sua área» para quem não trata;
  ficha do guia actualizada.
- Testado no servidor com desfazer: Elmar e Serviços Gerais vêem as 6;
  Recepção e Clínica, 0 (as 6 foram reportadas pelos Serviços Gerais).

## 3-dq. Avarias: Emmanuel conclui, só a Direcção apaga (02-10-2026)

- Pedido do Elmar: o Emmanuel lê todas as avarias e dá-as como concluídas;
  uma avaria criada só o director apaga.
- Servidor (`avarias-apagar-direccao.sql`, aplicado):
  - `bsp_trata_avarias` passa a incluir o u22 pelo id, além da área;
  - `bsp_avaria_apagar` só aceita a camada Direcção (`bsp_e_direccao()`);
  - quem reportou deixa de poder apagar na primeira hora e pode só
    cancelar.
- Ecrã: `bspTrataAvarias` com o u22, `bspApagaAvarias` (camada Direcção),
  botão «Concluída» para quem trata, «Apagar as repetidas» só para a
  Direcção. Ficha do guia actualizada.
- Testado no servidor com desfazer: o Emmanuel lê 6 e conclui; a Arlete
  (Coordenação) é recusada ao apagar; o Elmar apaga. Testado no ecrã com
  servidor simulado: Emmanuel com Tratar/Concluída, Elmar também com
  Apagar, uma médica só com Editar/Cancelar na sua.

## 3-dr. Revisão geral do sistema (02-10-2026)

Verificado:
- Agendamentos (29): nenhuma falha em 24 h. Os relatórios diários, o resumo
  pessoal e o texto dos documentos foram criados hoje depois da sua hora:
  confirmar a 03-10 que correm (06h50, 07h15, 06h30, 05h20).
- E-mails: 11 tentativas hoje, todas barradas pela pausa (até 00h00 de
  Luanda). Nenhum saiu. Os 5 envios da escala da Clínica (17h14) não se
  repetem.
- Sincronização: volta a gravar o `shared_state` desde a correcção (3-dn).
- Escala da Clínica de Outubro em vigor, com o visto do Dr. Osvaldo (17h14),
  e a separação Ludmila / Luidmila mantida.
- Ecrã: todos os menus abrem sem erros como Elmar (computador) e como
  médica (telemóvel 390 px), sem nada a passar da largura.

Corrigido:
- 10 funções privilegiadas abertas a visitantes sem sessão
  (`seguranca-anon.sql`, aplicado). Nenhuma fica aberta.

Por fazer (Elmar, no painel do Supabase):
- Authentication → Passwords: ligar «Leaked password protection» (recusa
  palavras-passe que já apareceram em fugas de dados).
- Edge Functions: apagar `mig-recebe` e `bsp-crm-patch` (restos da
  migração, já desligados; a ferramenta não as consegue apagar).

Por fazer (menor):
- 16 funções sem `search_path` fixo (aviso do consultor, risco baixo).
- A lista embutida `USERS` não tem os códigos MetaGest: se o servidor não
  responder, os médicos perdem «A minha actividade» até recarregar.
- Escalas: Enfermagem de Outubro em falta; Ginecologia por decidir;
  rascunhos de Novembro (Clínica e Recepção).
- Nunca testado: chamada entre dois aparelhos reais; importação de um CSV
  do MetaGest.

## 3-ds. Qualidade: feedback de utentes e incidentes (03-10-2026)

Pedido do Elmar: «Avance tudo possível… Coloque lá o feedback de utentes».

- Servidor (`qualidade.sql`, aplicado):
  - `feedback_utentes` (avaliação 1–5, elogio, sugestão, reclamação; origem
    página, WhatsApp, Recepção, Livro de Reclamações, telefone, e-mail,
    redes). Reclamação com prazo de 15 dias (por confirmar com o Elmar).
  - `ocorrencias`: quase-erro, incidente sem dano, evento adverso, evento
    sentinela; etapas Notificada → Em análise → Acção correctiva →
    Verificação → Fechada (causa, acção, responsável, prazo, verificação).
    Pode ser anónima (`criado_por` fica vazio).
  - Lêem: gestão e Direcção Clínica tudo (`bsp_ve_qualidade`); chefe da
    área o da sua (`bsp_edita_escala`); cada pessoa o que registou.
  - Avisos (`bsp_qualidade_aviso`): reclamação, nota 1–2 e incidente
    moderado/grave/evento adverso vão já ao telemóvel da gestão, da Direcção
    Clínica e do chefe da área; tudo entra nas novidades (`destino
    qualidade`).
  - Página pública: `bsp_feedback_publico` (única função aberta a
    visitantes; 300 por dia, o mesmo texto uma vez por hora).
  - WhatsApp: `bsp_feedback_whatsapp` (cron `bsp-feedback-whatsapp`, 30 em
    30 min) lê a primeira resposta com 1–5 até 3 dias depois de uma mensagem
    da clínica com «De 1 a 5… como correu o atendimento». Até hoje o
    inquérito não saiu por este número: começa a contar quando sair.
  - `bsp_qualidade_resumo(dias)`: média, % satisfeitos, reclamações por
    responder e em atraso, incidentes em aberto e graves (só números).
- Página `avaliar.html` (QR `assets/qr-avaliar.png`, cartaz A4 no botão
  «Cartaz com QR»): nota, serviço, comentário, contacto opcional. Sem nome.
- Ecrã `QualidadeScreen` (menu «Qualidade», `#/qualidade`, em
  `BSP_ECRAS_SENSIVEIS`, ficha do guia).
- Testado: no servidor com desfazer (visitante grava e não lê; médica não
  vê o resto; resposta «4» do WhatsApp entra uma vez; Elmar vê tudo); no
  navegador com servidor simulado (página e ecrã, PC e telemóvel).
- Por fazer: imprimir o cartaz e pô-lo na recepção; decidir se o
  inquérito do WhatsApp passa a sair pelo número da clínica ligado ao
  servidor.

## 3-dt. Médicos e credenciais (03-10-2026)

- Servidor (`medicos-credenciais.sql`, aplicado):
  - `erp.medicos`: cópia diária do MetaGest («Healthcare Practitioner»:
    código, nome, cédula, departamento, estado) por
    `erp.sincronizar_medicos()`; 112 médicos (72 activos, 27 com facturas nos
    últimos 6 meses). O MetaGest não tem validades.
  - `credenciais`: quota da Ordem, seguro de responsabilidade civil,
    contrato, suporte de vida, especialidade… com número e validade.
    Registam a gestão e a Direcção Clínica; cada médico lê as suas
    (`bsp_meus_codigos_metagest`).
  - `bsp_medicos_credenciais(p_todos)` para o ecrã;
    `bsp_credenciais_alertar()` põe nas novidades os documentos que caducam
    em 30 e 7 dias e no dia (gestão, Direcção Clínica e o médico).
  - Cron `bsp-medicos` às 04h40 de Luanda (antes das novidades das 05h00).
- Ecrã: Equipa → «Médicos e credenciais» (`MedicosCredenciaisPainel`,
  `bspVeCredenciais`). Lista embutida `USERS` com os códigos MetaGest dos 5
  médicos ligados (antes, sem o servidor, perdiam «A minha actividade»).
- Testado: servidor com desfazer (Elmar vê 27 e regista; a Dra. Luidmila
  vê só a sua e não grava; aviso a 7 dias com o texto certo); navegador com
  servidor simulado (Elmar regista; médica só consulta).
- Por fazer: registar as validades de cada médico (começar pelos 27 a
  trabalhar); 1 dos 27 não tem cédula no MetaGest.

## 3-du. Equipamentos e manutenção preventiva (03-10-2026)

- Servidor (`manutencao-preventiva.sql`, aplicado): `equipamentos`,
  `manutencoes_plano` (tipo, de quantos em quantos dias, última, próxima,
  quem faz; a próxima calcula-se no gatilho `bsp_plano_proxima`),
  `manutencoes_registo` (dia, quem, custo, resultado; actualiza o plano e,
  se «Não conforme», põe o equipamento em «Avariado»). Lê toda a equipa;
  registam gestão, Serviços Gerais e Emmanuel (`bsp_trata_avarias`).
  Avisos `bsp_manutencoes_alertar` (cron `bsp-manutencoes`, 04h45 de
  Luanda): 14 dias antes, no dia e com 7 dias de atraso, nas novidades.
- Ecrã: Avarias e património → separadores «Avarias» (`AvariasLista`, o
  ecrã antigo) e «Equipamentos e manutenção» (`EquipamentosPainel`).
- Testado: servidor com desfazer (plano trimestral avança 90 dias depois
  do registo; aviso a 14 dias; médica lê e não grava); navegador com
  servidor simulado (Emmanuel regista; médica consulta).
- Por fazer: os Serviços Gerais acrescentam os equipamentos e os planos
  (ecógrafos, analisadores, autoclave, frigoríficos, ar condicionado,
  gerador, extintores).

## 3-dv. Vigilância automática e registo de acessos (03-10-2026)

- Vigilância (`vigilancia.sql`, aplicado, cron `bsp-vigilancia` de 15 em 15
  min): tarefas agendadas falhadas, funções com erro, Workspace sem sinal em
  dias úteis 08h–18h (o sintoma de 02-10-2026), cópia do MetaGest e do
  WhatsApp paradas, 80 e-mails no dia. Uma falha avisa a gestão no
  telemóvel uma vez (de novo só passadas 6 h) e outra vez quando se resolve.
  Estado em `vigilancia_estado`; Admin → «Saúde do sistema»
  (`bsp_saude_sistema`). Testado com desfazer: 80 e-mails falsos → 1 aviso,
  repetição sem aviso, «resolvido» no fim.
- Acessos (`acessos-registo.sql`, aplicado, RI-3.3): `acessos_registo`
  guarda quem abre os ecrãs de `BSP_ECRAS_SENSIVEIS` e cada ficha de utente
  (`bspRegistarAcesso`; só o número interno). Repetidos em 10 min
  ignorados; ninguém regista em nome de outro; só a gestão lê (Admin →
  «Acessos», `bsp_acessos_resumo`); apaga-se ao fim de 1 ano
  (`bsp-acessos-limpeza`).

## 3-dw. Documentos com prazo de revisão (03-10-2026)

- `documentos-revisao.sql` (aplicado): coluna `revisao_ate`;
  `bsp_documentos_rever_alertar` (cron `bsp-documentos-revisao`, 04h50 de
  Luanda) põe nas novidades os documentos a rever em 30 dias e no dia
  (gestão; nos procedimentos também a Direcção Clínica).
- Ecrã: «Rever até (opcional)» no `DocPublicarModal` (nos procedimentos
  propõe 2 anos); no cartão, quem publica vê «Rever até» / «Revisão em
  atraso».

## 3-dx. Integração de novos colaboradores (03-10-2026, RI-2.2)

- `integracao.sql` (aplicado): `integracao_modelo` (passos e prazos; os
  valores estão só no servidor, preenchidos a partir do resumo do RI:
  1.º dia, 1.ª semana, 2 meses, período experimental, último mês),
  `integracoes`, `integracao_passos`; `bsp_integracao_iniciar` (só a
  gestão), `bsp_integracao_passo` (gestão, superior, chefe; a pessoa só os
  seus), `bsp_integracao_alertar` (cron `bsp-integracao`, 04h55 de Luanda:
  um aviso por pessoa e dia, no prazo e com 3 dias de atraso).
- Ecrã: Equipa → «Integração» (`IntegracaoPainel`).
- Testado: servidor com desfazer (10 passos até +90 dias; a pessoa marca o
  seu e não o do DCH; o superior vê; outra médica não vê; sem duplicados);
  navegador com servidor simulado.
- Por decidir (Elmar): iniciar a integração da Dra. Ludmila Da Silva
  (entrada 02-10-2026, superior Dr. Osvaldo?).

## 3-dy. Cadeia de frio nos relatórios de turno (03-10-2026)

- `cadeia-frio.sql` (aplicado): `bsp_frio_aviso` no `relatorios_area`.
  Farmácia, Laboratório e Enfermagem: se `frio_min` < 2 ou `frio_max` > 8
  °C, aviso já no telemóvel (gestão, Direcção Clínica, chefe da área) e nas
  novidades. `bsp_num` lê números com vírgula ou ponto.
- Ecrã: `BSP_CAMPOS_FRIO` (opcionais) nos três relatórios; os campos
  numéricos opcionais aceitam decimais no telemóvel.
- Testado no servidor com desfazer: 3–7,5 °C sem aviso; 1,5–6 °C com aviso.
- Revisão final no navegador: todos os menus abrem sem erros (Elmar no
  computador, médica no telemóvel).

## 3-dz. O que fica por decidir (03-10-2026)

- Despesas e margem no Painel: o MetaGest só tem as facturas de compra (46
  desde Julho), sem salários, renda nem outras despesas. Uma margem só com
  isso engana. Decidir de onde vêm as despesas (contabilidade, mapa mensal).
- Pagamento aos médicos dentro do Workspace (hoje em Excel).
- Dois factores na entrada para a Direcção e o Painel.
- Prazo de 15 dias para responder a reclamações (confirmar).
- Imprimir o cartaz com o QR (Qualidade → «Cartaz com QR») para a recepção.
- Registar validades dos médicos, equipamentos e planos de manutenção.
- Iniciar a integração da Dra. Ludmila Da Silva.

## 3-ea. Inquéritos dos utentes que chegam por e-mail (03-10-2026)

- O inquérito pós-consulta sai por um WhatsApp que o servidor não copia.
  As respostas chegam todos os dias por e-mail de info@barispol.ao
  («Respostas dos pacientes no WhatsApp — DD-MM-AAAA», à Recepção com a
  Direcção em cópia).
- `feedback-importar.sql` (aplicado): `bsp_feedback_importar(lista JSON)`,
  só do servidor; ignora chaves repetidas; `bsp.sem_aviso = '1'` grava sem
  avisos (alterado `bsp_qualidade_aviso`).
- Histórico importado (sem avisos): 21 respostas de 02-09 a 02-10-2026
  (apuramento de 16-09, registo de 21-09, as duas queixas de 17-09 e
  19-09 e o e-mail diário de 02-10). 14 com nota, média 4,14; 2
  reclamações em tratamento; 9 por tratar. Comentários sem nomes.
- Routine «Inquéritos dos utentes para o Workspace»
  (`trig_01HT5cbhVcQF9RYt95QN1XEE`): desligada a 03-10-2026. Ficou sem
  ligações (a organização não deixa juntá-las por esta via). Substituída
  pelo Zapier (abaixo).

## 3-eb. Inquéritos importados pelo Zapier (03-10-2026)

Pedido do Elmar: «Use o zapier ou resend». Escolhido o Zapier: lê a caixa
do Outlook sem mexer na Resend.

- `feedback-email.sql` (aplicado):
  - `bsp_feedback_email(codigo, assunto, texto)`: a única entrada. Aberta
    à chave publicável, mas só grava com o código do cofre
    `bsp_feedback_codigo` (nunca no repositório) e com o assunto
    «Respostas dos pacientes no WhatsApp…».
  - Guarda o e-mail em `feedback_email_entrada` (sem regras de leitura:
    só o servidor) e lê a secção «INQUÉRITO PÓS-CONSULTA» com
    `bsp_feedback_do_texto`. Cada linha com «nota X» ou «sem nota» vira
    uma resposta, sem o nome. Chamadas e respostas automáticas ficam de
    fora, e a secção «Recuperação» também.
  - Nota 1–2 = reclamação (prazo de 15 dias, quer resposta); 4–5 ficam
    fechadas; o resto fica «Nova». Os avisos de qualidade saem como numa
    resposta escrita à mão.
  - Chave `email:AAAA-MM-DD:N`, igual à da importação manual: repetir o
    e-mail não duplica nada.
- Teste (desfeito no fim): o texto de 02-10 dá as mesmas 4 respostas da
  importação manual. Um código errado é recusado.
- Zapier: fluxo privado «Inquéritos dos utentes para o Workspace».
  Dispara com «New Email Matching Search» no Outlook do Elmar (assunto
  «Respostas dos pacientes no WhatsApp») e chama a função. FALTA: o Elmar
  liga a conta do Outlook ao Zapier (link dado na conversa). Sem isso o
  fluxo não pode ser publicado.
- Para ver se chegou: `select dia, importadas, erro, recebido_em from
  feedback_email_entrada order by id desc limit 5;`

## 3-ec. Imprimir no atalho do iPhone (03-10-2026)

Elmar: «Não está imprimir dentro do marcador de iphone» (cartaz do
inquérito). No atalho do Workspace no ecrã principal do iPhone, o iOS
ignora o `window.print()`.

- `imprimir.html` (nova, sem indexação): recebe o documento comprimido
  depois do «#», mostra-o com o botão «Imprimir» e pede a impressão
  sozinha. Tira o documento do endereço logo que o abre. O «#» nunca vai
  ao servidor e a página não guarda nada.
- `bspImprimirIos`: no atalho (`bspStandalone()`), «Imprimir» abre essa
  página no navegador do iPhone. O endereço prepara-se ao abrir a
  pré-visualização (`bspEnderecoImpressao`), para o toque abrir logo.
  No Safari e no computador nada muda.
- Cartaz «Como foi o seu atendimento?»: medidas em mm, numa só folha A4
  e sem se partir. «Partilhar» manda `assets/cartaz-avaliar.pdf`, e a folha
  de partilha do iPhone tem «Imprimir». Se o cartaz mudar, refazer o PDF.
- Testado no Chromium com um iPhone simulado: no atalho, abre-se a
  `imprimir.html` com o cartaz e o endereço fica limpo; no Safari,
  imprime como antes; o PDF tem 1 folha. Falta confirmar num iPhone real.
- Segunda volta (03-10-2026, «Não imprime ainda»): a janela que o atalho
  abre também pode ignorar a impressão. Se a impressão não abrir em 1,5 s
  (sem `beforeprint`), a `imprimir.html` mostra a ajuda: «Abrir no Safari»
  (`x-safari-https://…`, iOS 17 ou mais recente; o Safari imprime sempre)
  ou «Partilhar → Imprimir». A pré-visualização do Workspace mostra a mesma
  ajuda depois do toque em «Imprimir».

## 3-ed. Datas livres e filtro de serviço (03-10-2026)

Elmar: «Em todas secções que tenham tempo, coloque a opção de escolher as
datas … nos médicos só permite hoje, mês passado, esse mês e ano, coloque
a opção de filtrar datas e filtrar serviços».

- Componente `DatasLivres` (De / Até, com validação e limite de dias de
  cada função) e `bspPeriodoRotulo`. Chip «Escolher datas» em:
  «A minha actividade», Painel (até 800 dias), Painel clínico (até 93),
  Marcações (até 400), CRM → Funil de vendas e CRM → Resultados (até 400).
- `minha-actividade-servicos.sql` (aplicado): `bsp_minha_actividade(de,
  ate, membro, servico)`. Com serviço, só contam as facturas com esse
  grupo de actos do MetaGest, e o valor é só o dessas linhas. Devolve
  `servicos` (os do médico no período) para o menu. Máximo 3 anos. A
  versão antiga de 3 parâmetros saiu.
- `crm-funil-datas.sql` (aplicado): `crm_funil`, `crm_resultados` e
  `bsp_marc_funil` aceitam `p_de`/`p_ate` opcionais (sem eles, como antes).
- Testado no servidor: u4 de 01-09 a 02-10, sem filtro 18 facturas,
  com «Consultas e Especialidades» 12. Funil de 1 a 15 de Setembro: 475
  pedidos (igual à contagem directa da tabela).
- Testado no ecrã (telemóvel, 390 px): os seis sítios mandam as datas
  escolhidas ao servidor; o serviço vai em `p_servico`; data final antes
  da inicial dá aviso; nada passa da largura do ecrã.
- Ficha do guia de «A minha actividade» actualizada.

## 3-ee. Tempo de espera na Qualidade (03-10-2026)

Elmar: «Consegues colocar na qualidade o tempo de espera também?»

- `qualidade-espera.sql` (aplicado): `erp.espera_utente` (um utente por dia,
  chave md5, sem nome), `erp.sincronizar_espera(de, ate)` a partir do
  MetaGest (triagem = Vital Signs, consulta = Patient Encounter, saída =
  última factura do dia), `bsp_qualidade_espera(de, ate)`. Crons
  `bsp-espera-hoje` (30 em 30 min, 06h–21h) e `bsp-espera` (03h50, últimos
  7 dias). Histórico carregado desde Janeiro de 2026 (1 874 utentes).
- Ecrã: Qualidade → «Tempo de espera» (`QualidadeEspera`, só quem vê tudo
  na Qualidade): tempo na clínica, espera pelo médico, por dia, por hora de
  chegada, por dia da semana, por médico (gestão e Direcção Clínica, com 3
  ou mais consultas) e o valor que a Recepção escreve no relatório.
- Setembro: mediana de 1 h 45 na clínica (Agosto 1 h 23); 74 de 178
  utentes acima de 2 h; espera pelo médico 1 h 38 (58 consultas
  registadas, 52 acima de 30 min). Chegadas das 10h–11h esperam mais.
- Limite: só 1 em cada 3 consultas tem o registo aberto pelo médico no
  MetaGest. Para medir melhor, os médicos devem abrir a consulta no
  MetaGest quando chamam o utente.

## 3-ef. Inquéritos: o que está e o que não está no sistema (03-10-2026)

- No sistema: as respostas do WhatsApp (e-mails individuais desde 16-09 e
  o resumo diário de 02-10), a página `avaliar.html` (1 resposta) e o que a
  Recepção regista à mão. A partir de agora, o resumo diário entra pelo
  Zapier (3-eb), quando o Elmar ligar o Outlook.
- Fora do sistema:
  - Microsoft Forms «Inquérito de Satisfação pós atendimento» (cerca de 30
    respostas, Fevereiro de 2025 a Março de 2026). As respostas só estão no
    Forms: o Elmar abre o formulário → «Abrir no Excel» e guarda o ficheiro
    na OneDrive; depois importa-se.
  - Inquéritos em papel digitalizados (2024: Março a Setembro; 2025: quatro
    lotes até 13-11-2025), em `rececao/INQUÉRITOS 2024` e
    `DireoeAssistentes/BRSP_ADM/BRSP-ADM - INQUE`. São imagens sem texto:
    não se lêem por esta via.
  - O «mapa» Excel da tarefa do WhatsApp fica no computador onde a tarefa
    corre, não em nenhuma Drive.

## 3-eg. Notificações já vistas voltavam a aparecer (03-10-2026)

Elmar: «As notificações já vistas continuam a aparecer, é chato.»

Causas:
- O ecrã Notificações nunca as marcava como lidas ao abrir: só ao tocar
  numa a uma ou em «Marcar todas». Vistas, continuavam por ler e no sino.
- O estado do aparelho (`bsp-workspace-v1`) leva as conversas inteiras, com
  os históricos do WhatsApp (17 232 mensagens). Passa do limite do
  navegador (~5 MB) e a gravação falhava em silêncio: ao reabrir voltava a
  cópia antiga. Com o armazenamento cheio falhavam também as listas
  pequenas (novidades já mostradas), e a mesma novidade voltava ao sino.

Correcção (workspace.html):
- `NotificationsScreen`: ao abrir, todas passam a lidas (1,2 s); as desta
  visita ficam à vista até sair («N novas»); na visita seguinte só em «ver
  as já lidas».
- As notificações gravam-se também à parte (`bsp-notifs-v1`, lido no
  `loadInitial`). Sair da sessão apaga as duas chaves.
- Sem espaço: grava-se o estado com só as últimas 60 mensagens de cada
  conversa (as anteriores voltam do servidor ao abrir a conversa).
- Testado no navegador: 3 avisos por ler → 0 ao abrir, à vista nessa
  visita, ausentes ao reabrir; com o armazenamento cheio, grava 60
  mensagens e o aviso fica lido.

## 3-eh. Auditorias clínicas (03-10-2026)

Elmar: «Faz as auditorias, porque completam a parte clínica pedida pela JCI.»

- `auditorias.sql` (aplicado): `auditoria_modelos` (7 listas iniciais: higiene
  das mãos, carro de emergência, cadeia de frio, resíduos hospitalares,
  limpeza e desinfecção, identificação do doente, segurança contra
  incêndio; área e periodicidade; a gestão muda-as), `auditorias`
  (Sim / Não / N.A. por item, conformidade = Sim ÷ (Sim + Não)), gatilho
  `bsp_auditoria_calcular` (calcula e avisa as falhas nas novidades),
  `bsp_auditorias_estado()` e `bsp_auditorias_alertar()` (segundas-feiras,
  modelos em atraso; cron `bsp-auditorias`). Fazem e vêem: gestão, Direcção
  Clínica e chefe da área (`bsp_faz_auditorias`).
- Ecrã: Qualidade → «Auditorias» (`QualidadeAuditorias`): estado de cada
  lista, «Fazer auditoria» (todas as respostas obrigatórias, nota em cada
  «Não»), «Folha em branco» para imprimir a ronda, histórico com as falhas.
- Testado no servidor (desfeito): carro de emergência com 1 falha e 1 N.A.
  → 83,3%, área preenchida, novidade com a falha, próxima a 7 dias. No ecrã
  (telemóvel): não grava sem todas as respostas nem sem a nota do «Não».

## 3-ei. Satisfação e espera no relatório diário da Direcção (03-10-2026)

- `relatorio-direccao-qualidade.sql` (aplicado): `bsp_srv_qualidade_direccao(dia)`
  (só o servidor): satisfação de 30 dias (média, notas 1–2, elogios,
  reclamações), reclamações em aberto e fora de prazo, respostas por
  tratar, espera da véspera e de 30 dias (tempo na clínica e espera pelo
  médico), incidentes em aberto e auditorias (feitas na véspera, falhas,
  por fazer ou em atraso).
- Edge Function `relatorios-diarios` versão 12 (publicada; igual ao
  repositório): secção «Satisfação e espera» no relatório das 06h50.
- Pré-visualização de 02-10 (sem envio): 4,14 / 5 em 14 avaliações; 1 h 43
  na clínica (40% acima de 2 h); ontem 52 min; 2 reclamações em aberto, 1
  fora do prazo; 7 auditorias por fazer.

## 3-ej. Avaliação de desempenho anual (03-10-2026)

Elmar: «Avaliação de desempenho anual. Solicite à Arlete o histórico anual de
todos os colaboradores de produtividade e posteriormente de assiduidade.»

- Pedido à Arlete enviado a 03-10-2026 pelo servidor (Resend, `bright-worker`,
  com o Elmar em cópia e as respostas para elmar.bravo@barispol.com; o
  Microsoft 365 desta sessão só lê): por colaborador e por mês, desde Março
  de 2024, primeiro a produtividade (% de objectivos, avaliação mensal) e
  depois a assiduidade (faltas, atrasos, subsídio). Pasta BRSP_RH.
- `avaliacao-desempenho.sql` (aplicado): `avaliacao_modelo` (6 factores do
  formulário «Avaliação de Desempenho – Barispol 2026», opções A–D; texto
  só no servidor), `avaliacoes_desempenho` (uma por pessoa e ano: Rascunho →
  Concluída → Tomou conhecimento), `desempenho_historico` (por mês, para o
  Excel dos RH), `bsp_avalia`, `bsp_avaliacao_gravar`,
  `bsp_avaliacao_conhecimento`, `bsp_avaliacao_apoio`. Avaliam a gestão e
  o superior / chefe (`bsp_chefe_de`); ninguém se avalia a si próprio.
- Ecrã: Equipa → «Avaliação» (`AvaliacaoPainel`): lista de quem cada um
  avalia, formulário com os dados de apoio (ausências, formações,
  histórico), rascunho, conclusão, impressão; «A minha avaliação» com
  «Tomei conhecimento».
- Testado no servidor (desfeito): não conclui sem os 6 factores; a pessoa só
  vê depois de concluída; toma conhecimento; não se avalia a si própria.
- FALTA: importar o Excel da Arlete para `desempenho_historico` quando
  chegar (ligar cada nome ao id da equipa).

## 3-ek. Tempo de espera para cada médico (03-10-2026)

Elmar: «Na qualidade não tem para os médicos o tempo de espera, não convém?»

- Em «A minha actividade» (e não em Qualidade, que é da gestão e da
  Direcção Clínica): cartão «Tempo de espera dos seus doentes», com a
  mediana da triagem à abertura da consulta, a da clínica, os acima de 30
  min e 1 h, e quantas consultas facturadas ficaram medidas. Cada médico vê
  só os seus; a gestão, o Painel e a Direcção Clínica escolhem o médico.
- `minha-espera.sql` (aplicado): `bsp_minha_espera(de, ate, membro)`, as
  mesmas regras de `bsp_minha_actividade`.
- Setembro: Dra. Luidmila Chitata 3 h 28 (13 de 30 consultas medidas); Dra.
  Ludmila Da Silva 1 h 24 (18 de 38); clínica 1 h 38. Um médico não vê os
  números de outro (testado).

## 3-el. Taxa de resposta ao inquérito e lista de chamadas no CRM (03-10-2026)

Elmar: «3, as duas» (copiar a lista de contactos para o servidor e pôr a
lista de chamadas no CRM).

- `inquerito-taxa.sql` (aplicado). `inquerito_contactos`: 1 415 números
  da folha «Contactos de pacientes (acumulado)» e 53 do MetaGest. Só
  telefone, datas e tipo, sem nomes. O cron `bsp-inquerito-contactos`
  (04h20) acrescenta os novos todos os dias. 10 números estão marcados sem
  WhatsApp (envios de 15-09, 25-09 e 02-10).
- `inquerito_envios_dia`: o «RESUMO DO DIA» do e-mail diário. A
  `bsp_feedback_email` passa a gravá-lo
  (`bsp_inquerito_resumo_do_texto`). Já lá estão os envios de 15-09 e
  02-10. Sobre o de 25-09 não há resumo.
- Qualidade → Feedback de utentes: bloco «Inquérito por WhatsApp · 30
  dias» (`bsp_qualidade_inqueritos`). Hoje mostra uma taxa de resposta de
  33% (21 de 63) e uma cobertura de 25% (63 inquéritos para 255 números
  atendidos). Mostra também 32 recuperações (1 respondeu) e 9 números sem
  WhatsApp.
- CRM: estado novo «Por ligar», que aparece sempre, fora do período
  escolhido (`crm_pedidos`). Se o pedido for marcado ou o utente vier, o
  estado automático passa à frente (`crm.pedidos_estado`). Os 43 pedidos
  da lista de chamadas (25-08 a 24-09) estão «Por ligar», com a
  prioridade na nota.
- Ficaram de fora 3 números: um já marcado, uma candidatura de emprego e
  um número sem pedido no CRM. O Sérgio, que respondeu a 02-10, passou a
  «Perdido» com essa nota.
- Falta: o Zapier com o Outlook ligado, para o resumo entrar todos os dias
  sozinho.

## 3-em. Novidades no sino sem atraso nem repetições (03-10-2026)

Elmar: «As novidades continuam atrasadas e repetidas» (sino com 20
novidades de 1 de Outubro marcadas como novas).

- Causa: o sino pedia as 20 novidades MAIS ANTIGAS dos últimos 14 dias (há
  70) e guardava as já vistas só no aparelho. As novas nunca chegavam e,
  com a memória do aparelho cheia, as mesmas voltavam a cada 10 minutos.
- `novidades-sino.sql` (aplicado): `novidades_vistas` guarda por pessoa até
  que novidade já viu. `bsp_novidades_por_ver()` devolve as seguintes que
  são para ela, logo que são criadas, sem esperar pelo e-mail das 05h00.
  `bsp_novidades_vistas(id)` avança o marcador. Na primeira vez, cada
  pessoa recebe só as do último dia.
- Ecrã: as novidades entram com o número (`novidade`) e não se repetem. Ao
  abrir, as repetidas antigas saem do sino (fica uma de cada).
- Testado: o Elmar recebe 10 novidades na primeira vez e nenhuma depois.
  No ecrã, 3 cópias da mesma ficaram reduzidas a 1.

## 3-en. Subsídio de produtividade mensal (03-10-2026)

Elmar: «No SharePoint vê esse ficheiro e funde com a produtividade que já
tem. Esse serve para pagar: Apuramento_Subs Produtividade.xlsx.»

- Fonte: Direcção e Assistentes → BRSP_RH → «02 Compensação e Benefícios /
  Apuramento_Subs Produtividade.xlsx». Regra: notas de 1 a 3 por objectivo
  (até 4); média até 1,6 = 50%, até 2,6 = 75%, acima = 100%; a pagar =
  subsídio × percentagem. RI-5.3 (nota BRSP-DG-NINT-24-001).
- `produtividade.sql` (aplicado): `produtividade_objectivos` (24 objectivos
  da «Legenda», só no servidor), `produtividade_pessoas` (por número BRP),
  `produtividade_mensal` (Rascunho → Aprovado → Pago). As contas fazem-se no
  servidor. Ao aprovar, o mês entra em `desempenho_historico` (fonte
  «apuramento»), que a avaliação anual já mostra: é aí que as duas coisas
  se juntam.
- Equipa → «Produtividade» (`ProdutividadePainel`). Lançam o chefe da área e
  o superior. Aprova a gestão. Marcam como pago a gestão e o Financeiro.
  Há «Imprimir apuramento», «Exportar CSV» e a ficha de cada pessoa
  (subsídio, objectivos, conta). Cada pessoa vê os seus meses aprovados.
- Testado: as notas 3, 3, 2, 2 sobre 22 250 Kz dão 2,5, 75% e 16 687,50 Kz,
  como no Excel. A chefe da Recepção não lança nos Serviços Gerais, e
  ninguém lança a sua própria produtividade.
- Histórico importado (03-10-2026) de 77 ficheiros da pasta dos RH
  BRSP_RH_PRODUTIVIDADE e das pastas de cada colaborador: 132 meses de 33
  pessoas, de Abril de 2025 a Setembro de 2026, como «Aprovado» (fonte
  «sharepoint»). Guardam os números da folha, que foi o que se pagou. Em 18
  linhas a folha fez a conta de outra maneira: dividiu sempre por 4 ou tirou
  a percentagem da 4.ª nota. A nota de cada uma dessas linhas diz o que a
  regra daria. 74 meses de 16 pessoas com conta entraram no histórico da
  avaliação anual.
- Números BRP repetidos nos ficheiros (BRP016 em 4 pessoas, BRP028 em 4,
  BRP333 e BRP037 em 2). Cada pessoa ficou com um só número. Usei o da pasta
  dos RH quando existe; nos repetidos sem pasta juntei as iniciais
  (BRP028-JC, BRP028-MM, BRP333-CT, BRP333-JM, BRP037-DD, BRP037-WS). «Rosa
  simão» e «Rosa Salvador» são a mesma pessoa. Os RH devem confirmar estes
  números.
- Sem ficheiro: Recepção de Janeiro e Fevereiro de 2026 (pastas vazias). As
  áreas de saúde não têm Junho nem Julho de 2026.

## 3-eo. Pagamento dos médicos no Workspace (03-10-2026)

Elmar: «Avante o 1» (o mapa de pagamento aos prestadores).

- `pagamento-medicos.sql` (aplicado). As comissões saem das facturas do
  MetaGest que já estão no servidor, com as regras do mapa de Julho de
  2026 (Clínica Geral 2.000/2.500, Pediatria 4.000, especialidades 50%,
  cardiologia pelo nome do item 50%, laboratório 10%, observação 10%,
  enfermagem 5%, ecografia 50/30%, raio-X 5%, IRT 6,5%).
- Permanências: regimes A, B, C e D, lançados por dia a partir das fichas
  assinadas. As consultas da ficha prevalecem sobre as do MetaGest.
- Farmácia e indicação: a base lança-se à mão, porque o MetaGest não diz
  quem estava em serviço nem quem indicou o exame. «Outros» aceita valores
  negativos, para descontar actos de um mês facturados no seguinte.
- Cadastro dos 25 prestadores (NIF, IBAN, regime, taxas) carregado só no
  servidor (`prestadores`).
- Ecrã: Painel → «Pagamento dos médicos». Tem avisos (linhas sem médico,
  médicos sem cadastro, valores simbólicos, possíveis duplicados, ecografias
  de quem não é imagiologista, relançados), «Fechar o mês», «Marcar como
  pago», «Imprimir mapa» e «Exportar para o banco (CSV)».
- Conferido com Julho de 2026: laboratório 292 006 (mapa 292 005,90) e
  enfermagem 34 678 (mapa 34 677,90). Consultas e cardiologia ficam 9 500
  acima, pelas contagens da ficha. Imagiologia fica 52 150 acima: são as três
  ecografias de Junho relançadas que o mapa de Julho já tirou.
- Testado: médica sem acesso, mês fechado não aceita mudanças, permanência
  pró-rata certa.
- Falta: lançar as permanências e as fichas de Setembro de 2026 e fechar o
  mês. Uniformizar a ecografia dos imagiologistas (Elizabeth, Ihandjika,
  Noémia) está pendente de decisão da Direcção Geral.

## 3-ep. Telemóvel do próprio e de familiar (03-10-2026)

Elmar: «Avante o 2». Proposta do apuramento de 16-09: em seis casos o número
do paciente era de um familiar.

- `telefones-familiar.sql` (aplicado): `marcacoes.contacto_familiar` e
  `familiar_quem`. O `contacto` passa a ser o telemóvel do próprio, e é
  dele que sai o `tel9` usado para ligar, para o lembrete e para o
  inquérito.
- Ecrã: na marcação, «Telemóvel do próprio», «Telemóvel de familiar
  (opcional)» e «De quem é». O cartão mostra os dois. O CSV ganhou a
  coluna «CONTACTO DE FAMILIAR», no fim.
- Falta: a ficha de inscrição em papel e no MetaGest (fora do Workspace)
  devem ter os dois campos, com confirmação em voz alta no balcão.

## 3-eq. Pedidos de marcação pelo site (03-10-2026)

Elmar: «as marcações no site. Mas no site o paciente espera ser contactado
para marcar.»

- `pedidos-site.sql` (aplicado): tabela `pedidos_marcacao` e
  `bsp_pedido_site`, a única porta aberta a visitantes além da avaliação.
  Tem campo-armadilha para robôs, um tecto de 300 pedidos por dia e não
  repete o mesmo número em 2 horas. A Recepção recebe um aviso no
  telemóvel a cada pedido (`bsp_pedido_site_aviso`).
- `contacto.html`: o pedido fica gravado na clínica, já não abre o
  WhatsApp. Campos: nome, número para ligar e de quem é (o próprio ou um
  familiar, com o telemóvel do próprio à parte), serviço, seguro e melhor
  altura. Confirmação: «A recepção vai ligar-lhe para marcar». O WhatsApp
  fica como alternativa.
- `index.html`: a mensagem do formulário entra também nos pedidos, além do
  e-mail que já saía.
- Workspace: Utentes → Marcações → «Pedidos do site», com Ligar, WhatsApp e
  Marcar. «Marcar» abre a marcação já preenchida, com origem «Site», e o
  pedido fica «Marcado». Há também «Não atendeu», «Falei, sem marcar» e
  «Desistiu».
- Testado no navegador: o envio, a confirmação, a mensagem de falha, o
  painel e a marcação preenchida. No servidor: nome curto e telefone
  inválido recusados, e o mesmo número não se repete.

## 3-er. Salários só para o Elmar e a Arlete; sem e-mail das 05h00 (03-10-2026)

Elmar: «Anule o e-mail de actualização todas as manhãs às 5h. Na avaliação
retire imediatamente valores, deixa apenas pontuação. Salários são
particulares, só eu e a Arlete vimos. Cada funcionário só vê as suas
coisas! Os superiores vêem da sua equipa.»

- `salarios-privados.sql` (aplicado):
  - O cron `bsp-novidades` foi apagado e o e-mail das 05h00 deixa de sair.
    As novidades continuam no sino.
  - `bsp_ve_salarios()` dá acesso só a u1 e u2.
  - Na produtividade, as colunas `subsidio` e `total` não se lêem pela
    tabela; só pela `bsp_produtividade_valores`, e só para u1 e u2.
  - A ficha (subsídio e objectivos) e o «Pago» ficam só com u1 e u2.
  - O sócio deixa de ver a produtividade.
  - O pagamento dos médicos fica só com u1 e u2.
- Ecrã:
  - A Produtividade mostra só notas e percentagens a quem não é u1 ou u2.
    Isto vale para os cartões, os totais, a impressão, o CSV e «A minha
    produtividade».
  - O pagamento dos médicos passou do Painel para Equipa → «Pagamento dos
    médicos», só para u1 e u2.
- Testado: a chefe de Enfermagem vê só a sua área, sem Kz. A leitura da
  coluna `total` dá «permission denied», e os valores e o pagamento são
  recusados. O Elmar vê tudo.
- Regra «cada um vê o seu; o superior vê a sua equipa»: as tabelas de
  pessoas (ausências, formações, avaliação, histórico, produtividade,
  tarefas privadas, ficheiros pessoais) já seguiam a regra. A
  produtividade estava aberta também ao sócio e mostrava valores aos chefes
  e ao próprio, e isso ficou corrigido.
- Por decidir: a conta de teste «Beb» está na camada Direcção e por isso vê
  o mesmo que a gestão (excepto os salários). Tirá-la da Direcção?

## 3-es. Mensagens do Chat voltam a avisar e a contar no telemóvel (04-10-2026)

Elmar: «As mensagens normais entre pessoas no chat não está a notificar nem
contar números, preciso que notifique tudo.»

- Causa no ecrã: o aviso local usava `new Notification(...)`, que o Android e
  o iPhone não aceitam (só pelo service worker). O aviso perdia-se sem erro.
  Nas mensagens directas, com o push activo, nem se tentava, porque se
  contava só com o push do servidor.
- Agora `bspBrowserNotify` usa o service worker (`showNotification`), e
  regista o `sw.js` se ainda não estiver registado. A etiqueta é
  `conv-<chave>`, a mesma do push do servidor: os dois juntam-se num só
  aviso.
- Avisa sempre: mensagens directas, grupos, canais e menções. Também com o
  Workspace aberto noutro ecrã. Só não avisa quem está a ler essa conversa.
- Número no ícone da app: `navigator.setAppBadge` com as mensagens por ler.
  O `sw.js` põe um ponto no ícone quando chega um push de mensagem.
- Testado no navegador: uma mensagem directa nova dá o aviso do sistema
  (etiqueta `conv-dm-…`, abre a conversa) e o «1» no botão Chat.
- Servidor, confirmado a 04-10-2026 nos registos: as mensagens dos grupos
  geravam push (`push-enviar`, resposta 200). As dos canais (#geral, #avisos,
  #escalas e os de área) só avisavam nas menções: as de #recepção,
  #laboratório, #escalas e #radiologia de 03-10 não avisaram ninguém.
  Corrigido em `push-canais.sql` (aplicado). Nos canais avisa quem os vê, com
  a regra do `bspVeCanal` (por exemplo, #geral 25 pessoas, #recepção 6), nunca
  o autor nem os sócios.
- A app Android (Capacitor) não tem avisos do sistema até ligar o Firebase
  (3-…, «Notificações C»).

## 3-et. Pagamento dos médicos pelo mapa de Agosto (04-10-2026)

Elmar: «Use o pagamento de Agosto para te guiares… Irão faltar todos os meses
os mapas de presença deles, que ainda não consigo fazer digital. Ecografia: a
imagiologista tem adenda contratual, 40% terça e domingo, 50% nos restantes
dias. Os outros médicos estão off.»

- `pagamento-medicos-regras.sql` (aplicado). O modelo é o
  MAPA_PAGAMENTO_MEDICOS_AGOSTO_2026 «(pagamentos 15-09)» do SharePoint.
- **Ecografia por dia da semana.** Coluna `prestadores.taxa_eco_dias`
  (`{"2": 40, "7": 40}`; 1 = segunda … 7 = domingo). Nesses dias vale essa
  taxa; nos outros, a `taxa_eco`. Sai a regra antiga do regime C (25% nos
  dias de permanência). A permanência do regime C fica como estava (horas ÷ 6
  × taxa). A adenda está lançada no cadastro, só no servidor.
- **Presenças em falta.** O mapa calcula-se sem as fichas de presença; a
  permanência fica a zero. Cada médico com actividade no mês e sem nenhum dia
  lançado aparece em «A conferir antes de fechar» e com «sem presenças» a
  vermelho. Lançar as fichas antes de fechar o mês.
- **Nomes do MetaGest.** Coluna `prestadores.chaves_extra`: outros nomes do
  mesmo médico. Em Setembro uma médica passou a ter o nome curto no MetaGest
  e 1,26 milhões de facturação ficavam sem dono. Corrigido no cadastro. O
  «ver linhas» (`bsp_pagamento_detalhe`) segue a mesma regra.
- **Nutrição** conta como especialidade (50% do facturado), como no mapa.
- **Cadastro (só no servidor):**
  - os quatro imagiologistas e ginecologistas sem actividade ficaram
    inactivos;
  - o urologista passou a 30% na ecografia (decisão da DG de 11-09-2026);
  - entram as duas médicas novas de Agosto (nº 26 e 27).
- **Conferido com Agosto:**
  - laboratório 232.222,51 contra 232.222,38;
  - enfermagem e observação iguais.
  - Imagiologia: a diferença de 4.134 é a regra nova contra a antiga de
    Agosto. Agosto já foi pago pelo mapa avulso.
  - Consultas: a diferença vem das fichas e dos exames atribuídos à mão.
- **Falta:**
  - Cadastro dos dois médicos novos de Setembro (aparecem em «Médicos sem
    cadastro», com o valor facturado): NIF, IBAN, regime e taxa.
  - Confirmar a taxa de permanência da médica nº 26. O mapa usou 15.000, e
    a nota da DG de 13-09 fala em 20.000.
  - Lançar as presenças de Setembro e fechar o mês.
  - 04-10-2026: a Arlete ainda não tinha mandado estes dados (nenhum e-mail
    dela desde 28-09 sobre os médicos). Pedido enviado nesse dia, a pedido do
    Elmar (de geral@barispol.com, com o Elmar em cópia e as respostas para
    ele): cadastro dos dois médicos novos, NIF/IBAN e taxa da médica nº 26,
    cópia da adenda da ecografia e, se houver, as fichas de presença.

## 3-eu. Dra. Holoca paga exame a exame (04-10-2026)

Elmar: «A doutora Elizabeth Holoca recebeu o pagamento durante o mês; ela
agora recebe logo após as ecografias. Faz o mapa, mas assume que já paguei.»

- Adenda de 01-09-2026: sem permanência. No cadastro do servidor ficou sem
  regime (antes C) e com a taxa por dia da semana (40% à terça e ao domingo,
  50% nos outros dias).
- Setembro no módulo «Pagamento dos médicos»: ajuste «outros» que anula o
  valor dela, com nota. Já foi paga à parte e não pode sair duas vezes no mapa
  geral. Fazer o mesmo nos meses seguintes enquanto for paga exame a exame.
- Mapa avulso de Setembro (BRSP-DAF-MAP-26-003, entregue ao Elmar, fora do
  repositório): conciliado com os quatro comprovativos BAI dos e-mails.
  Perguntas em aberto ao Elmar: duas ecografias sem comprovativo, um pagamento
  a 50% numa terça-feira, uma retenção de 6,50 Kz em vez de 6,5% e um
  pagamento sobre 90% do facturado. Ver o mapa.
- Para a Recepção corrigir no MetaGest: duas facturas sem praticante; uma
  possível factura em duplicado à seguradora.

## 3-ev. Toners e depósito do gerador (04-10-2026)

Emmanuel (Serviços Gerais): «Falta-me o controlo de toners em tempo real e o
depósito do gerador.»

- `toners-gerador.sql` (aplicado). Avarias → separadores «Toners» (toda a
  equipa) e «Gerador» (gestão, Serviços Gerais e Emmanuel, `bspTrataAvarias`).
- **Toners:**
  - Tabelas `impressoras` e `toners_movimentos` (Entrada, Troca, Leitura,
    Acerto), com o mínimo de cada consumível em `toners_minimo`.
  - Stock e nível por `bsp_toners_estado`.
  - Qualquer colaborador regista uma leitura; trocas e compras só quem trata.
  - Aviso (sino e telemóvel) quando o stock chega ao mínimo, ou com a
    impressora a 15% e sem reserva.
  - Carregadas as 6 impressoras da lista do Emmanuel. O mínimo de CE285A é 2,
    porque três impressoras o usam.
- **Gerador:**
  - Tabelas `gerador` (1000 L, aviso a 30%) e `gerador_registos` (Leitura,
    Abastecimento).
  - `bsp_gerador_estado` dá os litros de agora, o consumo por dia e os dias
    que restam.
  - Abaixo de 30% avisa a gestão e os Serviços Gerais, no máximo a cada
    12 horas.
  - Primeira leitura: 500 L (50%) a 04-10-2026, às 22h19.
- **Testado:**
  - De 500 L para 260 L em dois dias dá 121 L/dia e 2,2 dias de reserva, e o
    aviso sai.
  - O toner no mínimo dá aviso.
  - A Recepção não vê o gerador nem regista compras.
- **Falta:**
  - «Tempo real» automático para os toners: um pequeno programa num
    computador da clínica que leia as impressoras de rede por SNMP (só a
    M236sdn tem IP; as P1102 são USB) e grave a leitura no servidor. A nuvem
    não chega à rede 192.168.x.
  - Para o gerador, só com um sensor de nível no depósito.
  - Até lá, os dois registos fazem-se à mão.

## 3-ew. Histórico da viatura, Abril a Agosto de 2026 (04-10-2026)

Folha do Emmanuel com os km de cada dia (manhã e noite) e os abastecimentos,
de 01-04 a 31-08 (só no servidor; a folha não entra no repositório).

- Carregados 54 abastecimentos em `transporte_abastecimentos` (1.244 L).
  - O valor é litros × 300 Kz, o preço de todos os registos de Setembro.
  - Os km são os do odómetro no fim do dia, porque a folha não traz o km do
    abastecimento.
  - Nota em cada linha.
- Km dos turnos carregados a 06-10-2026 (Elmar: «falta as kms»): 240 viagens
  «Rota do pessoal» (manhã e noite) em `transporte_viagens`, motorista u22,
  nota «Turno da manhã/noite (folha de Abril a Agosto de 2026)», 12.468 km.
  - Ficaram de fora as 17 noites de 26-04 a 12-05 que já estavam (vindas do
    WhatsApp, iguais ao km), 5 manhãs com 0 km (30-04, 01-06, 15-06, 17-08,
    24-08) e a noite de 28-06, igual à manhã na folha (44.208 → 44.239):
    confirmar com o Emmanuel.
  - Por mês (turnos / km): Abr 50 / 2.471, Mai 52 / 2.622, Jun 51 / 2.497,
    Jul 54 / 2.694, Ago 50 / 2.898. Total 13.182 km, igual à folha menos o
    turno repetido.
  - Os km entre turnos não se inventaram: o Histórico mostra-os como «km sem
    registo».
- **Conferido:**
  - Sem erros de conta e sem odómetro a recuar.
  - O odómetro andou 17.817 km, mas só 13.213 km estão em turnos
    registados.
  - Ficam 4.604 km (26%) entre turnos: 1.364 km entre a manhã e a noite, e
    3.240 km entre a noite e a manhã seguinte (média de 21 km por noite).
  - Rendimento pelo odómetro: 14,3 km/L, normal. Só pelos km registados
    parecia 10,6 km/L.
  - Setembro: 13,9 km/L. Outubro, até dia 4: todos os km registados (o
    Transporte do Workspace regista a ida a casa).
- Por decidir (Elmar): se a ida a casa do motorista é autorizada, ou se os
  km entre turnos de Abril a Agosto pedem explicação. Os maiores foram 19-04
  (96 km), 26-04 (104 km) e 01-05 (89 km).

## 3-ex. Toners só para quem os trata (05-10-2026)

Elmar: «Os toners só a Recepção, Laboratório, Emmanuel e Direcção é que
vêem.»

- `toners-acesso.sql` (aplicado): `bsp_ve_toners()`. Entram quem trata as
  avarias (gestão, Serviços Gerais e Emmanuel) e as áreas Recepção e
  Laboratório.
  - Regras de leitura das impressoras, do mínimo e dos movimentos, e
    `bsp_toners_estado`, passam a usar esta função.
  - Registar uma leitura também exige `bsp_ve_toners`.
- Ecrã: o separador «Toners» só aparece com `bspVeToners`.
- A novidade «Toner a acabar? Registe no Workspace» passou de todos para a
  Recepção e o Laboratório.
- Testado no servidor: a Recepção, o Laboratório, o Emmanuel e o Elmar vêem
  as 6 impressoras; a Enfermagem não vê nada e o estado é-lhe recusado.

## 3-ey. A Arlete vê tudo o que é consumo (05-10-2026)

Elmar: «Arlete vê tudo que é consumo.»

- `consumos-acesso.sql` (aplicado): `bsp_ve_consumos()`, com u1 e u2 pelo
  nome e a gestão.
  - Até aqui a Arlete via pela camada (Direcção/Coordenação). Agora vê mesmo
    que a camada mude.
  - Ligado a toners (`bsp_ve_toners`), gerador (`bsp_ve_gerador`, leitura e
    estado), transporte (`bsp_ve_transporte`: viagens, combustível,
    manutenção) e stock (`bsp_ve_stock`).
  - Registar continua com quem trata.
- Os avisos de toner e de gasóleo (`bsp_servicos_gerais_ids`) incluem sempre
  a Arlete.
- Ecrã: `bspVeConsumos` em `bspVeToners`, `bspVeTransporte`, `bspVeStock` e
  no separador «Gerador».
- Testado:
  - Arlete: toners, gerador, transporte e stock; no ecrã, os separadores
    Toners e Gerador.
  - Enfermagem: nada disto.
  - Emmanuel (cargo de motorista): sem mudança.
- 05-10-2026, Elmar: «Serviços Gerais vêem tudo». `bsp_ve_consumos` e
  `bspVeConsumos` passam a incluir a área Serviços Gerais e o Emmanuel (u22).
  Hoje a área tem só o Emmanuel. Passou a ver também o stock (menu Stock) e o
  transporte sem depender do cargo de motorista. Testado no servidor.

## 3-ez. Custo médio de uma revisão das viaturas Suzuki (05-10-2026)

Elmar: «O custo da revisão: vê as últimas facturas da Suzuki Angolauto para
teres uma média por revisão.»

- Fonte: o plano de manutenção dos Serviços Gerais no SharePoint
  (BRSP-LOG_Plano-Manutencao-Equipamentos_2026), com quatro revisões feitas
  na Angolauto em 2026, duas da Eeco e duas do S-Presso.
  - A factura de Novembro de 2025 é uma digitalização sem texto e ficou de
    fora.
  - Média das quatro: 118.915 Kz por revisão.
  - Média das revisões normais (óleo e filtros): 76.459 Kz.
  - A revisão grande (velas, valvulina, todos os filtros) custou 246.283 Kz.
  - Mão de obra fixa: 38.881,50 Kz por revisão.
- No Transporte do Workspace (`transporte_manutencoes`) entraram as duas
  revisões da Eeco (16-03 e 12-08-2026). As do S-Presso não, porque o módulo
  é só da Eeco.
- Correcção (05-10-2026, Elmar: «30 de 09 era só informação, não fez»): o
  registo de 30-09-2026 (id 1, 66.652,80 Kz, preço do material) passou de
  «feita» a «orcamento», com nota. A última revisão feita da Eeco é a de
  12-08-2026, aos 49.649 km; a seguinte (cada 5.000 km) já passou.

## 3-fa. Recuperação da palavra-passe sem o Elmar (05-10-2026)

Elmar: «A recuperação de password como está? Os meus colegas conseguem sem
mim? Se não faça isso.»

- Como estava: o «Esqueceu-se?» chamava `resetPasswordForEmail`.
  - O e-mail saía pelo correio de teste do Supabase
    (noreply@mail.app.supabase.io). Esse correio só entrega a membros da
    organização do Supabase, ou seja, só ao Elmar.
  - A ligação levava ao «Site URL» do painel, que está em
    http://localhost:3000. Mesmo o Elmar caía numa página que não abre.
  - O ecrã dizia sempre «Enviámos», mesmo sem envio.
  - Resultado: nenhum colega conseguia recuperar a palavra-passe sozinho.
- Como fica:
  - Edge Function `recuperar-acesso` (versão 1, verificação de JWT
    desligada, só aceita barispol.com). Cria a ligação com `generateLink`
    (recovery) e envia-a pela Resend, de geral@barispol.com, só para o
    endereço da conta.
  - Responde sempre o mesmo, exista ou não a conta.
  - Limite: 3 pedidos por endereço por hora e 30 no total
    (`recuperar-acesso.sql`, `recuperacoes_pedidos`, `bsp_recuperacao_pode`;
    guarda só o resumo SHA-256 do endereço).
  - Não respeita a pausa dos e-mails. Regista em `emails_registo`.
  - A ligação abre `workspace.html#recuperar=<código>`. O código guarda-se
    logo no início da página (`window.__bspRecuperar`) e o endereço limpa-se.
  - Ecrã `NovaPalavraPasseEcra`: duas vezes a palavra-passe (mínimo 8). O
    código só se gasta ao gravar (`verifyOtp` com `token_hash`), por isso os
    antivírus que abrem as ligações não o estragam. Depois entra no Workspace.
  - A ligação vale 1 hora e serve uma vez.
- Nome e e-mail no ecrã (05-10-2026, Elmar: «Coloque aqui o nome de quem pede
  para recuperar e e-mail»): versão 2 da função. A ligação leva também
  `&email=` e `&nome=` (o nome vem de `shared_state.team`). O ecrã mostra um
  quadro «Conta» com o nome e o e-mail por cima dos campos
  (`window.__bspRecuperarQuem`). Leva também um campo escondido com o e-mail,
  para o gestor de palavras-passe do telemóvel guardar a nova na conta certa.
  As ligações enviadas antes da versão 2 abrem o ecrã sem o quadro.
- Testado: a função responde 200 a um endereço sem conta, 403 a outra
  origem e 400 a um e-mail inválido. No navegador (Playwright, com o
  servidor simulado): pedido, ecrã, palavra-passe curta, ligação gasta e
  entrada no Workspace.
- Opcional, no painel do Supabase (só o Elmar): Authentication → URL
  Configuration → Site URL = `https://barispol.com/workspace.html`. Já não é
  preciso para a recuperação, mas os outros e-mails do próprio Supabase
  (convites) continuam a apontar para localhost.

## 3-fb. Controlo de férias e subsídio dos RH (05-10-2026, por aplicar)

Pedido da Arlete pelo Elmar: «rh-controlo-de-ferias-e-subsidio.xlsx, actualize
o sistema».

- `ferias-controlo.sql`: tabela `ferias_controlo` (por ano e nome: dias de
  direito, 1.º e 2.º semestre, subsídio pago, observações), `bsp_ferias_controlo`
  (com o «Estado Geral» da folha) e `bsp_ferias_subsidio`. Só
  `bsp_ve_salarios()` (u1, u2): o subsídio é um pagamento.
- **Ainda não aplicado:** o acesso ao Supabase foi recusado a 05-10-2026.
  Falta aplicar o SQL, carregar as 18 linhas da folha (os dados ficam fora do
  repositório), lançar os períodos de quem tem conta como «Férias» aprovadas
  em `ausencias` e fazer o quadro «Controlo de férias (RH)» em Equipa →
  Ausências.
- Sem conta no Workspace: Angelina Kingalo, Eva António, Inês Nicolau, Loide
  Dibanga, Neusa Chimi. Confirmar se «Cássia Alvaro» é a Cassia Peixoto (u19).

## 3-fc. Registo clínico do médico (05-10-2026)

Elmar: «preciso que coloque os dados todos dos pacientes, pedidos de exames,
resultados, observações de enfermagem e tudo que o médico fez, para que o
director clínico tenha os dados todos a partir do sistema e só comparar.
Quero que os médicos preencham no sistema, encontram já as facturas e tudo.»
E: «o prioritário é o formulário online, vê os 3 documentos se há
redundância e fazes uma limpeza».

- Os três papéis da Direcção Clínica passam a um só formulário: o do banco,
  «Actividades realizadas» e «Registo de pacientes».
  - Identificação, contagens e resumo repetiam-se nos três. Agora vêm do
    MetaGest ou contam-se sozinhos.
  - As assinaturas passam a ser «Submeter» (médico) e «Dar visto» (Direcção
    Clínica), com nome e hora.
- `registo-clinico.sql` (aplicado):
  - Cópia do MetaGest pela API (`erp.api_lista`/`erp.api_get`):
    - `erp.clin_consulta` (Patient Encounter: idade, sexo, queixas,
      diagnóstico, análises pedidas, receita);
    - `erp.clin_triagem` (Vital Signs);
    - `erp.clin_lab` (Lab Test e resultados);
    - `erp.clin_paciente` (sexo e data de nascimento).
  - `erp.sincronizar_clinico(de, ate)`, com os crons `bsp-clinico-hoje`
    (30 em 30 min) e `bsp-clinico` (02h55, 7 dias).
  - Carga de Setembro de 2026 pelo cron `bsp-clinico-carga`
    (`erp.clin_carga`). **Desligar esse cron quando a carga acabar.**
  - `public.registo_clinico`: um por médico (código MetaGest) e dia.
    Rascunho → Submetido (número `BRSP-DC-BNC-AA-nnn`) → Visto.
  - Funções: `bsp_registo_clinico_dia`, `_gravar`, `_visto` e `_lista`.
    O acesso usa `bsp_rc_codigos`: o próprio médico, a Direcção Clínica e a
    gestão. Escreve só o próprio médico (ou a gestão). O visto é da Direcção
    Clínica ou da gestão.
- Ecrã «Registo clínico» (`RegistoClinicoScreen`, rota `registo`), para os
  mesmos de «A minha actividade»:
  - por utente: facturas e serviços, triagem, consulta do MetaGest e
    análises com resultado;
  - o médico escreve o motivo, diagnóstico, conduta, destino, se foi urgente
    e observações;
  - resumo e patologias calculados;
  - observações, dificuldades e sugestões;
  - separador «Comparar» para a Direcção Clínica.
  - É um ecrã sensível (`BSP_ECRAS_SENSIVEIS`, acesso registado) e tem ficha
    no guia.
- Os nomes dos doentes aparecem neste ecrã por pedido do Elmar. Ficam só no
  servidor e só para o próprio médico, a Direcção Clínica e a gestão.
- Verificado:
  - sincronização real (4 dias: 8 consultas, 12 triagens, 43 análises,
    25 utentes);
  - um dia real da Dra. Luidmila, com tudo preenchido;
  - acesso: a Juliana é recusada; o Director Clínico vê 14 médicos;
  - circuito de gravação, submissão e visto (dentro de uma transacção
    anulada);
  - ecrã no navegador com dados fictícios.
- Em Setembro, só a Dra. Luidmila registava as consultas no MetaGest. Os
  outros facturavam sem consulta registada.
- **Falta:** só 5 médicos têm conta com o código MetaGest (u4, u5, u6, u7 e
  Ludmila). Os outros que facturam precisam de conta no Workspace e do
  código MetaGest na ficha: Conceição Calunga, Pedro Feliciano, Edgar Jorge,
  Graça Lueie, Joia Manuel, Albano Lussati, Selmira Bungo e outros.
- **Falta:** ligar o registo submetido às presenças do pagamento dos
  médicos.
- Formulário do banco revisto em Word (fora do repositório), para usar até
  todos terem conta.

## 3-fd. Registo clínico: correcções de uso (05-10-2026)

Elmar: «o menu registo clínico não está a funcionar bem». O servidor
respondia bem (lista de 8 dias em 8 ms; um dia em 0,6 s). Os problemas eram
no ecrã, sobretudo no telemóvel:
- **Lista:** a tabela passava da largura do ecrã e o «Abrir» ficava escondido.
  No telemóvel é agora um cartão por dia, todo ele toca para abrir.
- **Motivo e diagnóstico** vêm já do MetaGest quando o médico ainda não os
  escreveu (antes eram só texto cinzento e tinha de escrever tudo).
- **Página curta:** os dados do MetaGest de cada utente (facturas, triagem,
  consulta, análises) ficam recolhidos; «Ver o que o MetaGest registou» abre
  um, «Mostrar os dados do MetaGest de todos» abre todos. 12 utentes passaram
  de ~15.000 px para ~8.500 px no telemóvel.
- **Rascunho guardado sozinho** no `sessionStorage` (nunca no `localStorage`:
  computadores partilhados), por médico e dia; mudar de dia antes de gravar
  já não perde nada. Apaga-se ao gravar.
- **«← Voltar à lista»** no topo do dia; a triagem já não mostra peso e IMC
  a zero.
- Verificado no navegador (390 px e 1280 px) com um dia real anonimizado.

## 3-fe. Botão «voltar» do telemóvel e do navegador (05-10-2026)

Elmar: «no workspace tem como ter subpáginas para cada menu? se clico voltar,
fecha toda a app». O Workspace não escrevia nada no histórico do navegador.
- Cada mudança de menu é um passo (`history.pushState` no `App`); voltar
  regressa ao ecrã anterior. Só no Início sai da app.
- Sub-páginas com `useBspVoltar(aberto, fechar)`: todas as janelas (`Modal`),
  o «Mais» do telemóvel, a conversa aberta no Chat do telemóvel (voltar
  mostra a lista), o médico aberto no Pagamento.
- Separadores com `useBspAbaVoltar(aba, setAba)`: fora do primeiro, voltar
  regressa ao primeiro (Equipa, Avarias, Qualidade, Utentes, Transporte,
  Drive, Admin, Registo clínico).
- Fechar no ecrã (X, Esc, Guardar) tira a entrada do histórico; entradas de
  janelas que já fecharam saltam-se. O visor de imagens mantém a sua.
- Na app Android o botão do telemóvel segue o mesmo histórico.
- Verificado no navegador: abrir um dia do Registo clínico e voltar; abrir e
  fechar janelas por voltar e por Esc; no fim, voltar sai da página.
- Um ecrã novo com separadores ou sub-páginas usa estes dois hooks.

## 3-ff. Pagamento dos médicos: fichas completas e conferência (05-10-2026)

Elmar: «com base nesse cálculo criar algo no Workspace? Para Outubro ser mais
leve». Em Setembro o mapa fez-se à mão a partir das fichas em papel.
- `pagamento-fichas.sql` (aplicado):
  - `pagamento_permanencias` guarda o dia inteiro da ficha: entrada, saída,
    consultas, reconsultas, enfermagem, observação, outros e nota. As horas
    calculam-se da entrada e da saída;
  - `bsp_pagamento_fichas` grava o mês de um médico e põe nos ajustes as
    consultas da ficha (a ficha prevalece, regra de Agosto): clínica geral
    por dia útil e fim-de-semana, pediatria pelo total;
  - `bsp_pagamento_conferir`: consultas por dia, ficha contra MetaGest;
  - `bsp_pagamento_actos`: actos do mês sem doentes (Excel e mapas
    individuais);
  - `bsp_pagamento_permanencias_mes` devolve também as fichas.
- Setembro carregado no servidor: 53 dias de 14 mapas e 16 dias da lista de
  presenças. Uma ecografia de 09/09 facturada sem médico pela Recepção foi
  atribuída ao médico certo em «Outros» (taxa só no servidor).
- Setembro (aberto): totais só no servidor (valores retirados do repositório
  a 12-10-2026, regra 4).
- Ecrã (Equipa → Pagamento dos médicos), feito a 05-10-2026:
  - por médico, **«Fichas do mês»**: um dia por linha (dia, entrada, saída,
    consultas, reconsultas, enfermagem, observação, nota); as horas saem da
    entrada e da saída; ao lado, as consultas do MetaGest nesse dia, a
    vermelho quando diferem; aviso e botão para os dias que o MetaGest tem
    sem ficha; «Guardar fichas» (`bsp_pagamento_fichas`);
  - **taxa de permanência** só 15.000, 20.000 ou 25.000 Kz (Elmar,
    05-10-2026), por `bsp_pagamento_prestador`; a taxa de cada médico só no
    servidor;
  - em «A conferir antes de fechar», os médicos com consultas da ficha
    diferentes das do MetaGest;
  - **«Excel do mês»**: o .xlsx no modelo de Agosto (NOTAS com o que
    conferir, MAPA com fórmulas, CONFIG, MEDICOS com a permanência em fórmula
    legível, FICHAS, ACTOS sem doentes), feito no navegador com o JSZip
    (`bspXlsx`, `bspPagExcel`);
  - **«Mapas individuais (zip)»**: um HTML por médico no aspecto do mapa de
    Agosto, sem doentes e com o IBAN mascarado (`bspPagMapaIndividualHtml`).
- Verificado no navegador com os números reais de Setembro: o Excel abre no
  openpyxl sem avisos, o total do MAPA dá 1.987.535,17 Kz como o sistema, a
  fórmula da permanência do Edgar é 15000/14,5×(2,5+5,78+5,83+9,28+9,33+9,83);
  17 mapas individuais; guardar as fichas envia os 6 dias do Edgar.

## 3-fg. Desactivar funcionários (05-10-2026)

Elmar: «como faço para desactivar funcionários?» … «quero criar o botão
desactivar». Antes só havia «Remover», que apaga a pessoa da equipa de vez.
- Admin → Utilizadores, botão ✕ «Desactivar» (✓ «Reactivar» depois):
  - a conta de entrada fica bloqueada: Edge Function `criar-utilizador`
    versão 2, `desactivar: true|false` (`ban_duration`), publicada;
  - na equipa: `inactivo: true`, `inactivoDesde`, `semEmails: true` (o valor
    anterior fica em `semEmailsAntes` e volta ao reactivar);
  - sai das listas, canais, menções e pickers (`bspSemOcultos`, `USERS`), mas
    o nome continua nas mensagens antigas (`window.__bspInactivos`);
  - `utilizadores-desactivar.sql` (aplicado): `bsp_recebe_emails` exclui
    `inactivo`; `bsp_utilizador_desactivado(id)` apaga as subscrições de
    avisos no telemóvel (só a gestão);
  - quem está com a sessão aberta sai logo; ao tentar entrar vê «Esta conta
    está desactivada. Fale com a Administração.»
- Não deixa desactivar a própria conta nem a última pessoa que gere
  utilizadores.
- Verificado no navegador (Admin com a equipa embutida e o servidor
  simulado): desactivar tira a pessoa das listas e chama a função e o
  servidor; reactivar repõe.

## 3-fh. Menu dos médicos: «Actividade e registo» (05-10-2026)

Elmar: «no menu dos médicos não tem a opção de correr a página para baixo,
podes juntar a actividade com esse menu novo dos médicos? tem muita coisa
espalhada».
- Um só menu, «Actividade e registo» (rota `actividade`), com dois
  separadores: «A minha actividade» («Actividade» para quem escolhe o médico)
  e «Registo clínico» (`MedicosScreen`). A rota antiga `registo` (ligações,
  novidades, `#/registo`) abre o mesmo ecrã no separador do registo.
- A página do Registo clínico não descia no computador: faltava
  `height: 100%` e `overflow: auto` ao ecrã. Corrigido.
- As patologias do resumo contam-se uma a uma (o diagnóstico vindo do
  MetaGest junta várias com vírgula).
- Ficha do guia «Actividade e registo» actualizada.
- Verificado no navegador a 1280 px e 390 px: a página desce, os separadores
  ficam por cima.

## 3-fi. Presenças dos médicos marcadas pela Recepção (05-10-2026)

Elmar: «Sobre a presença do médico quem fiscaliza é a recepção, como fazemos
esse campo da hora?». Opção escolhida: a Recepção marca.
- Ecrã: Utentes → separador «Presenças dos médicos» (`PresencasMedicos`), e no
  Início da Recepção um cartão com os médicos de hoje. «Chegou» e «Saiu» gravam
  a hora do servidor (hora de Luanda); «Outra hora», «Corrigir chegada/saída» e
  «Saiu a outra hora» pedem a hora e ficam registados como correcção (quem e
  quando). Só a gestão apaga uma presença.
- Aviso a vermelho: médico com facturas hoje no MetaGest e sem chegada marcada.
- A Recepção marca hoje e corrige só ontem; a gestão marca qualquer dia. Nunca
  dias nem horas futuras, nunca meses já fechados no Pagamento.
- As horas vão directamente para as fichas do Pagamento dos médicos
  (`pagamento_permanencias`, `origem`, `entrada_por`, `saida_por`,
  `corrigido_por`); o `bsp_pagamento_fichas` passa a actualizar sem apagar quem
  marcou.
- Servidor: `medicos-presencas.sql` (`bsp_presencas_pode` = quem vê as
  Marcações, `bsp_presencas_dia`, `bsp_presenca_marcar`).
- `medicos-presencas.sql` aplicado a 05-10-2026. Testado no servidor (com
  tudo desfeito no fim): como Elmar, chegada e saída com nome e horas
  calculadas, hora futura recusada; como recepcionista (u15), vê 24 médicos e
  marca, mas não marca há 3 dias; o Laboratório recebe «Sem acesso».
- Novidade 170 para `recepcao`, `gestao` e `direccao-clinica`.
- Verificado no navegador a 1280 px e 390 px, com dados simulados: marcar
  chegada, saída a outra hora, aviso das facturas sem chegada, sem passar da
  largura do ecrã.

## 3-fj. Fonte gratuita em vez da Dax (05-10-2026)

Elmar: «a fonte coloque uma gratuita, o Dax está a abrir mal em alguns PCs».
- A Dax não estava alojada: só aparecia em quem a tinha instalada no PC, e
  nalguns abria mal. Saiu de todas as listas de fontes (63 sítios): site,
  Workspace, app, impressões, e-mails do Workspace, Edge Functions, modelos de
  e-mail do Supabase e SQL (`emails-aspecto-site.sql`, `guia-envio.sql`).
- Fica a Titillium Web (gratuita, Google Fonts; no Workspace, alojada em
  `vendor/fontes`), com Segoe UI e Arial de recurso.
- Base de dados: `bsp_envelope` e `bsp_guia_html` reescritas sem a Dax
  (05-10-2026), testadas.
- Edge Functions com a fonte nos e-mails: `resumo-pessoal`, `resumo-matinal`,
  `contacto-site`, `recuperar-acesso`, `agenda-avisos`, `relatorios-diarios`
  (a `documento-aviso` já não se chama). Publicar de novo cada uma.
- Modelos de e-mail do Supabase (`emails-supabase/`): colam-se à mão em
  Authentication → Emails, se se quiserem iguais.
- Verificado no navegador: o Workspace mostra e carrega a Titillium Web.

## 3-fk. Apagar uma viagem do Transporte (05-10-2026)

O Emmanuel fechou a viagem de 05-10-2026 (07h45–10h31) com 55 574 km e a
seguinte era recusada («os km não podem ser menos do que no fim da última
viagem»). Pediu no #transporte que a apagassem.
- Transporte → «Histórico e contas»: botão «Apagar» em cada viagem, só para a
  gestão (`apagarViagem`; no servidor já existia `transporte_viagens_apagar` =
  `bsp_e_gestor`). Pede confirmação e deixa uma linha no #transporte.
- Viagem 87 apagada no servidor a 05-10-2026, com autorização do Elmar («Pode
  apagar»). O último km passa a 55 542.
- Verificado no navegador (390 px, dados simulados): o Elmar vê e apaga; o
  motorista não vê o botão.

## 3-fl. Painel: dia anterior a 0 Kz depois da meia-noite (05-10-2026)

Elmar: «O sistema está a dar 0 kzs no dia 5» (00h10 de 06-10). O `bsp_painel`
lia os dias passados só de `crm.mg_facturas` (carga às 05h00) e só o dia de hoje
de `erp.sales_invoice`; entre a meia-noite e a carga, «ontem» ficava a 0.
- `painel-ontem.sql` (aplicado a 05-10-2026): os dias depois do último dia do
  histórico (`corte`) vêm de `erp.sales_invoice`.
- Conferido: 1 a 4 de Outubro iguais nas duas fontes; dia 5 = 397 625 Kz.
  Nenhuma outra função tinha a mesma regra.

## 3-fm. Painel: facturação por área primeiro, antiguidade no fim (05-10-2026)

Elmar: «No painel, a antiguidade tem que estar mais abaixo. Quero ver o
facturado por área 1.º».
- Ordem nova do `PainelFacturacao`: números do topo → Facturação por área (a
  toda a largura) → Facturação por dia → grelha (quem paga, hora, médicos,
  seguradoras, notas de crédito, marcações) → «Por receber» (`PainelCobrancas`,
  com a antiguidade) no fim.
- Verificado no navegador a 1280 px e 390 px, com dados simulados.

## 3-fn. ECG, MAPA e Holter contam como Cardiologia (06-10-2026)

Elmar: «ECG, MAPA e Holter são da Imagiologia?» … «O MetaGest pode estar
errado». São Cardiologia. No MetaGest há um ECG no grupo ENFERMAGEM e um
ecocardiograma no grupo ECOGRAFIA; o relatório da Direcção Clínica contava todo
o grupo CARDIOLOGIA como «exames de imagem».
- `area-pelo-exame.sql`: `erp.grupo_item(grupo, nome)` põe ECG, MAPA, Holter,
  ecocardiograma e prova de esforço sempre em CARDIOLOGIA. Usada no `bsp_painel`
  (facturação por área), `erp.clinico_dados`, `erp.direccao_dados` e
  `erp.direccao_clinica_dados` (novo tipo `cardiologia`, fora de `imagem`).
  Altera as funções sobre a versão do servidor; se não encontrar o texto
  esperado, deixa a função e avisa.
- Aplicado a 06-10-2026. Na primeira aplicação o `bsp_painel` ficou alguns
  minutos sem a coluna `grupo` (erro na facturação por área); corrigido com o
  nome da coluna. Conferido: Setembro com Cardiologia 13 actos / 202 533 Kz;
  `erp.clinico_dados`, `erp.direccao_dados` e `erp.direccao_clinica_dados`
  correm sem erro.
- **Por fazer:** a Edge Function
  `relatorios-diarios` ainda não mostra o tipo `cardiologia` no relatório da
  Direcção Clínica (só deixa de o contar como imagem).
- Pagamento dos médicos (`bsp_pagamento_linhas`) não muda: um ECG no grupo
  ENFERMAGEM paga-se como enfermagem até o Elmar decidir.

## 3-fo. Editar um Word aberto no Chat (06-10-2026)

Arlete: «não consigo editar o contrato». O visor (`VisorImagem` com
`LeitorWord`) só mostra; o «Guardar» era um link directo ao armazenamento, de
outro domínio, e o navegador ignorava o pedido de descarga (no telemóvel voltava
a mostrar o documento).
- `bspGuardarFicheiro(url, nome)`: descarrega o ficheiro como blob com o nome
  certo; no telemóvel abre a partilha («Abrir no Word», «Guardar em Ficheiros»).
- Nos Word e PowerPoint o botão chama-se «Descarregar para editar».
- Verificado no navegador: o botão aparece e o ficheiro desce com o nome certo.
- Limite: a app Android não descarrega ficheiros (não tem `DownloadListener`
  nem o plugin de partilha); na app, abrir o Workspace no navegador para editar.

## 3-fp. Tarefas: secção «Atrasadas» (06-10-2026)

Elmar: «nas tarefas cria a secção atrasadas para ver».
- `TarefasAtrasadas` entre o resumo e o quadro: tarefas fora de «Concluído» com
  o fim antes de hoje (equipa e privadas que o quadro mostra), da mais antiga
  para a mais recente, com quem, coluna, data de fim e dias de atraso.
  Carregar abre a tarefa (`TarefaDetalhe`); a secção recolhe-se.
- Verificado no navegador a 1280 px e 390 px, com dados simulados.

- 06-10-2026 (Elmar: «As atrasadas quero aqui no gráfico também»): o cartão
  do gráfico tem um quinto número, «Atrasadas», a vermelho. Conta o mesmo que
  a secção (`bspTarefasAtrasadas(board)`, usada pelos dois). Verificado no
  navegador (390 e 1280 px).

## 3-fq. Tarefas delegadas: «Concluída» e avisos a quem delegou (06-10-2026)

Elmar: «coloca botão concluído em cada uma delas para ela as marcar como
concluídas e me notificar todas as atrasadas de manhã e todas concluídas assim
que ela marcar».
- Ecrã: botão «✓ Concluída» no cartão (`TaskCard`, `onConcluir`) e na janela
  da tarefa (`TarefaDetalhe`); passa a tarefa para Concluído (`concluir` no
  `TasksScreen`). Verificado no navegador.
- Servidor (`tarefas-conclusao.sql`, aplicado):
  - `bsp_tarefa_concluida_aviso` (gatilho em `tarefas_pessoais`): tarefa
    delegada (`criada_por` ≠ `user_id`) que passa a `done` → novidade só para
    quem delegou + aviso no telemóvel.
  - `bsp_tarefas_atrasadas_alertar`, cron `bsp-tarefas-atrasadas` às 06h45 de
    Luanda: lista das delegadas com o prazo passado, por quem delegou. O prazo
    é texto AAAA-MM-DD e converte-se antes de comparar.
  - Testados num bloco desfeito no fim (conclusão da tarefa 27; lista com 4
    atrasadas simuladas).
- Tarefas delegadas a 06-10 a partir dos e-mails: Juliana (26–31), Rosa (32,
  36), Solange (33, 35, 37), Filomena (34). Mensagem no Chat a cada uma.
- Coluna `origem` (`emails` nas tarefas 26–37): o ecrã mostra «DE SISTEMA» e
  «Criada pelo sistema, com base nos e-mails trocados»; `criada_por` continua
  u1 para os avisos. Verificado no navegador.

- 06-10-2026 (Elmar: «As tarefas estão todas concluídas, quem as marcou?»):
  ninguém; as tarefas 26–37 estavam todas em «A fazer» no servidor. O botão
  verde «✓ Concluída» lia-se como estado. Passa a «✓ Concluir», com contorno de
  botão, no cartão e na janela da tarefa. Verificado no navegador: ao carregar,
  a tarefa passa de «A fazer» para «Concluído».

## 3-fr. Janela de avisos importantes (06-10-2026)

Elmar: «Pop up de notificações importantes, consegue ter?». Escolheu: tarefas
delegadas, documentos obrigatórios, alertas críticos, ligar para utentes e
marcações da Recepção. As conclusões das tarefas que delegou ficam só no sino
e no telemóvel.
- Ecrã: `AvisosImportantes` (montado no `App` ao lado do `PedidoNotificacoes`).
  Janela por cima de tudo; só fecha com «Li», «Li todos» ou «Abrir» (leva ao
  ecrã). Lê `bsp_alertas_por_ler` ao entrar, a cada minuto e ao voltar à
  janela; não aparece em «Ver como» nem a sócios. Verificado no navegador
  (1280 e 390 px).
- Servidor (`alertas-importantes.sql`, aplicado):
  - tabela `alertas_importantes` (`user_id`, `chave`, `lido_em`): regista quem
    leu e quando; cada um lê as suas (a gestão lê todas).
  - `bsp_push_post` chama `bsp_alerta_do_push`: os avisos do telemóvel com a
    etiqueta `tarefa-…`, `frio-…`, `vigilancia-…` (só «possível falha»),
    `toner-…`, `gerador` e `pedido-site-…` ficam também na janela, mesmo sem
    telemóvel ligado. Um aviso novo importante usa uma destas etiquetas ou
    entra na lista da função.
  - calculados na hora: documentos de leitura obrigatória por confirmar
    (voltam no dia seguinte até à confirmação), tarefas delegadas atrasadas
    (uma vez por dia), e na Recepção os utentes «Por ligar» (CRM e site, uma
    vez por dia) e as marcações de hoje 1 h antes e 30 min depois da hora.
  - `bsp_alertas_lidos(chaves)` grava o «Li».
  - Testado como a Juliana num bloco desfeito: 2 avisos, 0 depois do «Li».
- Falta: o stock esgotado ainda não tem aviso próprio (só no relatório
  diário); quando tiver, entra com etiqueta na `bsp_alerta_do_push`.

## 3-fs. Transporte: viaturas (06-10-2026)

Sugestões do Emmanuel no #transporte: «Lista de viaturas da clínica · opção
para escolher a viatura que vou usar · histórico para cada uma delas».
- Servidor (`transporte-viaturas.sql`, aplicado): tabela `transporte_viaturas`
  (nome, matrícula, marca, modelo, ano, combustível, `activa`, nota), com a
  regra `bsp_ve_transporte` para ler, criar e alterar; nunca se apaga (fora de
  serviço = `activa = false`). `viatura_id` em `transporte_viagens`,
  `transporte_abastecimentos` e `transporte_manutencoes`. Os 330 registos
  antigos ficaram na «Viatura 1» (matrícula por indicar). O gatilho
  `bsp_transp_viatura_omissao` põe a viatura activa mais antiga num registo
  novo sem viatura (aparelho com a página antiga).
- Ecrã (`TransporteScreen`): escolha «Viatura que vou usar» no topo (guardada
  no aparelho, `bsp-transp-viatura`; com uma viagem em curso, abre na viatura
  dessa viagem). Hoje, Histórico e contas mostram só a viatura escolhida; os km
  contam-se por viatura. Separador «Viaturas» com o resumo de cada uma
  (conta-quilómetros, km em 30 dias, última viagem, combustível e manutenção
  em 12 meses), «Usar esta», «Histórico», «Alterar» e «Nova viatura»
  (`TranspViaturaModal`). Com mais de uma viatura em serviço, as mensagens do
  #transporte levam a linha «Viatura: …». Verificado no navegador (390 px).
- Falta: a matrícula e os dados da «Viatura 1» (o Emmanuel preenche em
  Viaturas → Alterar). O relatório semanal ao motorista (`resumo-matinal`,
  tipo `transporte`) ainda soma todas as viaturas juntas: mudar quando houver
  uma segunda viatura em serviço.

## 3-ft. Documentação no Notion (06-10-2026)

Elmar: «Tudo que fizemos aqui cria uma pasta no Notion para carregar dados,
passos, documentos» e «vai carregando tudo que formos fazendo».
- Página privada «Barispol Workspace» no Notion: Leia primeiro, Por fazer,
  Módulos (12 páginas), Registo de alterações (145 linhas, base de dados),
  Ficheiros do servidor (111 SQL + 12 Edge Functions) e a pasta «Documentos
  para carregar». Sem chaves, nomes de utentes, valores pagos, taxas dos
  médicos nem o regulamento interno.
- Regra 10 do `CLAUDE.md`: cada alteração nova entra no Notion.
- Falta: o Elmar diz que já tem uma pasta «Barispol» no Notion, mas não está
  visível para a ligação do Claude; com a ligação dela, mudar a página para lá.

## 3-fu. Escala do Laboratório de Outubro carregada (06-10-2026)

Elmar: «carregue essa escala» (PDF da escala de Outubro do Laboratório).
- Escala id 10 (laboratorio, 2026-10) substituída pelos dias do PDF, com o
  visto da Direcção Clínica (u14). Novidade 179 para o Laboratório e u14.
- Falta: confirmar com a chefe da área a hora do dia 29 (no papel
  «22:00-22:30», provavelmente 07:00-22:30; nota no próprio dia).

## 3-fv. Chat com aspecto de WhatsApp e todos os emojis (06-10-2026)

Elmar: «o chat quero que tenha aspecto de whatsapp, eu escrevo e fico do lado
direito do chat, o resto no esquerdo, quanto aos emojis de reacções
disponibiliza todos».
- `ChatScreen`: as minhas mensagens à direita, em bolha `--bolha-minha`
  (azul-claro; no modo escuro, azul-escuro), sem fotografia nem nome, com a
  data dentro da bolha. As dos outros à esquerda, em bolha branca com
  fotografia, nome e cargo. Classe `bsp-msg-bolha` (no telemóvel, a mensagem
  tocada fica com contorno azul).
- Reacções: o botão 👍 passou a 🙂 e abre `SeletorReaccao` com todos os emojis
  do navegador (`bspEmojisTodos`, ~1400, por grupos, com «Frequentes» no topo)
  e a caixa «Outro emoji» para bandeiras e tons de pele. Tocar numa reacção
  põe ou tira a minha; o «+» ao lado abre o seleccionador. A minha reacção
  tem contorno azul.
- Sem mudanças no servidor: a linha de controlo `​r​<sid>​<emoji>​<quem>` aceita
  qualquer emoji.
- Testado a 390 e 1280 px: alinhamento, seleccionador (1437 emojis), reagir
  e tirar a reacção, sem passar da largura do ecrã.

## 3-fw. Férias e ausências com duas aprovações (06-10-2026)

Elmar: «os pedidos de férias não chegaram ao Dr. Osvaldo, nota que todos os
chefes das áreas clínicas devem ter duas aprovações, 1.º o Dr. Osvaldo, depois
a Arlete RH. Todos os técnicos devem ter aprovação do superior hierárquico e
depois a Arlete RH». RI-6.1 (o plano de férias é aprovado pelo superior).
- Causa: o aviso do pedido ia para o «superior» e para o chefe da área. Os
  chefes das áreas clínicas não tinham «superior» e são o chefe da própria
  área: o pedido só chegava à gestão, só no sino, e a Arlete aprovava logo.
- `ferias-duas-aprovacoes.sql` (aplicado): colunas `superior_id`,
  `superior_ok_por`, `superior_ok_em`; `bsp_aprovador_de`,
  `bsp_ferias_aprovadores`, `bsp_ferias_rh`, gatilho `bsp_ausencia_superior`,
  `bsp_ausencia_avisar` (sino + telemóvel + janela de avisos, etiqueta
  `ferias-<id>`), `bsp_ausencia_pedida` e `bsp_ausencia_decidir` novos, leitura
  também para o `superior_id`.
- Equipa: `superior` = u14 para Filomena (Enfermagem), Solange (Farmácia), Rosa
  Queirós (Laboratório) e as duas radiologistas.
- Cadeia hoje: médicos → Osvaldo; enfermeiros → Filomena; Farmácia → Solange;
  Laboratório → Rosa Queirós; Recepção → Juliana; chefes clínicos e
  radiologistas → Osvaldo; depois sempre a Arlete. Sem superior (Osvaldo,
  Juliana, Emmanuel, Administração): só a Arlete. O Elmar pode substituir em
  qualquer passo.
- Testado no servidor (transacção desfeita): a Arlete não aprova antes do
  Osvaldo; o Osvaldo não dá o 2.º passo; leitura só do próprio, do Osvaldo e
  da Arlete. Ecrã testado a 390 e 1280 px.
- Pedido 14 (Déricka): o Elmar decidiu «Juliana aprova 1.º». Voltou a
  «Pedido» com `superior_id` u12; a Juliana recebeu o aviso, depois decide a
  Arlete. Pedido 15 (Solange), aprovado hoje só pela Arlete: por decidir.
- Falta confirmar: superior da Juliana (Recepção) e do Dr. Osvaldo.

## 3-fx. Aprovação final das férias por pessoa (06-10-2026)

Elmar: «Juliana aprovada por Arlete e depois a mim».
- `ferias-aprovacao-final.sql` (aplicado): coluna `final_id` em `ausencias`,
  `bsp_aprovador_final_de` (campo `aprovaFerias` na equipa; sem ele, os RH).
  O 1.º passo salta-se quando coincide com o aprovador final. Quem dá a
  aprovação final também lê o pedido.
- Juliana (u12): `superior` = u2 e `aprovaFerias` = u1. Cadeia: Arlete → Elmar.
- Testado no servidor (transacção desfeita): a Arlete não dá o 2.º passo; o
  Elmar recebe o aviso e aprova. Ecrã testado a 390 e 1280 px.
- Dr. Osvaldo (u14), Elmar: «Osvaldo vai para mim apenas»: sem `superior`,
  `aprovaFerias` = u1. Uma só aprovação, a do Elmar (testado).
- Pedido 15 (Solange), Elmar: «Solange volta para Osvaldo»: voltou a «Pedido»
  com `superior_id` u14 e `final_id` u2; o Dr. Osvaldo recebeu o aviso.

## 3-fy. Calendário no mapa de férias (06-10-2026)

Elmar: «nas férias coloque calendário além da lista para ver quem sai quando».
- `MapaFerias` com «Calendário» (abre por omissão) e «Lista». `CalendarioFerias`:
  grelha do mês de segunda a domingo, quem está de férias em cada dia (só as
  aprovadas), setas para mudar de mês. No telemóvel cada dia mostra o número;
  tocar num dia lista quem está fora, com a área e o último dia.
- Testado a 390 e 1280 px, sem passar da largura do ecrã.

## 3-fz. Documentos: grupos sem misturar áreas (06-10-2026)

Elmar: «ao publicar um documento, para quem pode ver, juntaste técnicos de
laboratório com os da farmácia; revê todas essas secções para não vazar
informação» e «gere os cargos como deve ser: téc. de farmácia, téc. de
enfermagem, téc. de laboratório».
- `documentos-destino-areas.sql` (aplicado): `bsp_cargo_grupos_membro` lê o
  cargo e o departamento; `bsp_doc_no_grupo` usa-a. Grupos: Médicos, Técnicos
  de enfermagem, de laboratório, de farmácia, de radiologia (pela área, com o
  chefe da área), Chefes das áreas e directores, Recepção, Administrativos,
  Motorista. Conferido no servidor: ninguém aparece no grupo de outra área.
- O antigo «cargo:tecnicos» (Laboratório + Farmácia) continua a ser lido mas
  já não se oferece. O documento 3, que o tinha, ficou com os dois grupos
  novos (as mesmas pessoas): o Elmar decide se deve ficar só um.
- Ecrã: `BSP_DOC_CARGOS` com regras por área; aviso de que as camadas juntam
  profissões; «Vão ver (N)» com os nomes antes de publicar. Testado a 390 e
  1280 px.
- Atenção: as camadas de acesso juntam áreas (a camada Clínica tem médicos,
  o analista do Laboratório, uma técnica da Farmácia e uma radiologista). O
  documento 8 (camadas Clínica, Enfermagem, Recepcionista) chegou a essas
  pessoas. Por decidir com o Elmar.
- A lista embutida `USERS` não tem a Neusa Chimi (Radiologia); o servidor tem.

## 3-ga. Férias: avisos a quem pediu e e-mail na aprovação (06-10-2026)

Elmar: «os pedidos de férias devem vir pop ups a quem deve aprovar e a quem
pediu depois de aprovada» e «um e-mail após aprovação com RH em cc».
- `ferias-avisos-email.sql` (aplicado): quem pediu recebe sino + telemóvel +
  janela de avisos no 1.º passo e na decisão final; na aprovação final,
  `bsp_ausencia_email_aprovado` manda o e-mail (aspecto do site) a quem pediu
  com os RH em cópia (só a quem recebe e-mails). Quem aprova já recebia a
  janela. Testado no servidor (transacção desfeita): janelas e e-mail
  (destinatário, cópia e assunto) certos.

## 3-gb. Documentos que o Emmanuel «não via» (06-10-2026)

- Documentos 18 e 19 (Arlete, 15h50 e 15h52, «Toda a equipa»): o servidor
  deixa o Emmanuel ler a lista e os PDF (testado com a sessão dele).
- A janela de avisos mostrou-lhos às 15h54 e ele carregou em «Li»; a leitura
  no menu Documentos ainda não está confirmada. Os dois estão no topo da lista.

## 3-gc. Logística: alimentação e consumíveis de escritório (06-10-2026)

Elmar: «para o controle da Arlete, logística: vê o que fazer com estes dados»
e «e os alimentos, gestão de comida» (folhas «Controle de gastos com a
alimentação» e «Consumíveis de escritório»).
- `logistica-compras.sql` (aplicado): tabela `logistica_compras` (categoria,
  descrição, data, valor, Compra/Adiantamento, n.º da factura, fornecedor,
  nota), regra dos consumos; só a gestão apaga.
- Importadas no servidor as 45 compras das folhas (34 de alimentação desde
  Março de 2025, 11 de escritório em 2026); totais iguais às folhas.
- Ecrã: Avarias → «Logística» (`LogisticaPainel`): este mês, média mensal,
  previsão para o mês (média dos 3 últimos meses fechados), este ano contra o
  mesmo período do ano anterior, gráfico de 12 meses, meses 30% acima da média
  a vermelho, adiantamentos por acertar, registar e alterar compras.
- A confirmar com a Arlete: escritório 2.116,13 Kz a 13-03-2026 (falta um
  algarismo?) e 132.265,54 Kz a 05-10-2026; alimentação de Agosto de 2026 só
  50.000 Kz; valores redondos que podem ser adiantamentos.
- Falta: fotografia da factura (precisa de pasta privada no armazenamento).

## 3-gd. Feed: vários anexos e «Voz dos utentes» semanal (06-10-2026)

Elmar: «nos anexos só permite um» e «faz um post no feed com os feedback
todos; passa a postar os elogios e reclamações da semana num post».
- Feed: a janela de publicação aceita vários ficheiros de uma vez (`atts`),
  com a lista e um botão para tirar cada um. Testado.
- `feedback-feed-semanal.sql` (aplicado): `bsp_feedback_sem_nomes`,
  `bsp_feedback_post_feed`, `bsp_feedback_post_semana`; cron `bsp-feedback-feed`
  (segunda, 08h00 de Luanda).
- Publicação 37 no Feed: todas as opiniões de 16-09 a 06-10-2026 (14 elogios,
  2 reclamações, 1 sugestão, 6 outras; nota média 4,3 em 23 avaliações).
- Opinião 57: nota corrigida de 1 para 5 (o texto diz «seria 5»).
- Limite: só se tapam nomes depois de «o/a»; um nome solto no início da frase
  passa. A Qualidade deve escrever as notas sem nomes.

## 3-ge. Avisos importantes: «Abrir» leva à pasta, resumo, sem «Li» (07-10-2026)

Elmar: «ao clicar ver não abre nada e desaparece a seleccionada da lista;
quando forem muitas, melhor aparecer resumo para abrir a pasta; retira a opção
lida sem abrirem».
- Causa: os avisos de férias abriam a Equipa no separador «Contactos» (parecia
  que não abria nada) e o aviso saía da lista antes de o ecrã mudar.
- `AvisosImportantes`: sem «Li» nem «Li todos». Só «Abrir <pasta>»: primeiro
  abre o ecrã (`bspAbrirPastaAviso`), depois marca como lido. Férias abrem
  Equipa → Férias e ausências (evento `bsp-equipa-aba`, também com a Equipa
  já aberta).
- Mais de 3 avisos: resumo por pasta (`bspAlertaPasta`, `BSP_ALERTA_PASTAS`),
  com o número e os primeiros títulos; «Abrir» trata todos os dessa pasta.
- Testado a 390 e 1280 px. Só no ecrã; o servidor não mudou.

## 3-gf. Avisos importantes: «Abrir» fecha a janela (07-10-2026)

Elmar: «ao clicar não fecha o pop-up, na mesma incomoda o utilizador».
- «Abrir» fecha a janela inteira e leva ao ecrã. Os avisos que faltam ficam
  num botão pequeno no canto inferior esquerdo («N avisos por abrir»), que
  reabre a janela quando a pessoa quiser.
- Os avisos já mostrados ficam adiados nesta sessão (`bsp-avisos-adiados` no
  `sessionStorage`). A janela só volta a abrir sozinha com um aviso novo.
  A actualização de cada minuto não fecha a janela reaberta pela pessoa.
- Testado a 390 e 1280 px.

## 3-gg. Menus: «Instalações e manutenção», «Logística e stock» e «Agenda» (07-10-2026)

Elmar: «o separador Avarias teria de trocar de nome; reveja os nomes dos
separadores e o que lá tem dentro». Aprovou os pontos 1 e 3 da proposta.
- «Avarias e património» → **Instalações e manutenção**: Avarias, Equipamentos
  e manutenção, Gerador.
- «Stock» → **Logística e stock** (`LogisticaStockScreen`): Stock (com os
  pedidos de compra), Compras correntes (a antiga «Logística») e Toners. Cada
  separador mantém a sua regra; o menu aparece a quem vê pelo menos um
  (`bspVeLogistica`). A Recepção e o Laboratório passam a ter este menu só
  com os Toners.
- «Calendário» → **Agenda** no computador (no telemóvel já era assim), também
  no Início, nas Reuniões e no guia.
- Avisos de toners (janela de avisos e sino) abrem Logística e stock → Toners.
- Ficam como estavam: «Admin» e «Presenças dos médicos» em Utentes.
- Falta no servidor (o Supabase recusa ligações desde 07-10-2026): o
  `bsp_aviso_servicos_gerais` ainda manda `#/avarias` no aviso do telemóvel dos
  toners (abre Instalações e manutenção); mudar para `#/stock` quando o
  `p_tag` começar por `toner`. E a novidade à equipa sobre os nomes novos.
- Testado: Arlete e Emmanuel vêem os 3 separadores; a Solange só o Stock; a
  Recepção só os Toners.

## 3-gh. Teste da Arlete, Stock do Laboratório para a Rosa, mensagens das presenças (07-10-2026)

Elmar: «o 1 e 3 era da Arlete e Rosa» (as perguntas sobre a logística, e não
os menus da 3-gg; os menus novos ficaram publicados e aguardam a decisão dele)
e «da presença dos médicos faz uma mensagem para a recepção e para cada
recepcionista».
- Feito (ecrã): em Logística e stock → Compras correntes, o cartão «Primeiros
  passos» com os 4 passos do teste da Arlete (compra, adiantamento, acertar,
  ler a previsão e o gráfico). Fecha com «Já sei» (`bsp-log-guia-<id>`).
- Preparado, por correr (o Supabase recusa ligações):
  `presencas-mensagens-stock-lab.sql`:
  - a Rosa (u13) passa a ver o armazém LABORATÓRIO - CBL
    (`stock_responsaveis`). Ao correr, acrescentar no ecrã
    `u13: ['LABORATÓRIO - CBL']` em `BSP_STOCK_RESPONSAVEIS`;
  - mensagem no #recepção e uma directa a cada pessoa da Recepção, do Elmar,
    sobre as presenças dos médicos (cid `presencas-2026-10-07-…`, não repete).

## 3-gi. Menus aprovados, «Serviços gerais», Rosa no Stock, mensagens enviadas (07-10-2026)

Elmar: «aprovo esses menus sugeridos e use sim serviços gerais»; «Supabase on».
- «Instalações e manutenção» passou a **Serviços gerais** (menu, título, guia,
  pasta dos avisos). Os menus da 3-gg ficam aprovados.
- `presencas-mensagens-stock-lab.sql` aplicado: a Rosa (u13) vê o armazém
  LABORATÓRIO - CBL (testado no servidor: 6 artigos; o MetaGest tem poucos
  artigos do Laboratório); no ecrã `BSP_STOCK_RESPONSAVEIS` com u13. Mensagens
  5570 (#recepção) e 5571–5573 (directas à Déricka, à Joaquina e à Juliana),
  do Elmar, com aviso no telemóvel.
- `toners-aviso-destino.sql` aplicado: avisos de toners (novidade e telemóvel)
  abrem `#/stock`; o gerador continua em `#/avarias`.
- Novidades 225 (todos: menus novos) e 226 (Rosa e gestão: Stock do
  Laboratório).

## 3-gj. Emmanuel: alimentação e limpeza à vista (07-10-2026)

Elmar: «Emmanuel não vê alimentação nem produtos de limpeza».
- Servidor conferido como o Emmanuel (u22): lê as 45 compras (34 de
  alimentação, 11 de escritório) e os 6 armazéns do Stock, incluindo
  SERVIÇOS GERAIS-LIMPEZA - CBL (6 artigos). Não era falta de acesso.
- Ecrã: em Compras correntes aparecem sempre as 6 categorias (a Limpeza só
  aparecia com compras, e ainda não há nenhuma). Quem não responde por um
  armazém (Serviços Gerais, Emmanuel) abre Logística e stock em «Compras
  correntes»; no Stock abre no armazém «Limpeza (Serviços gerais)».
- Novidade 227 para o Emmanuel e os Serviços Gerais.

## 3-gk. Stock: atalho no Painel clínico, fora do Início, aviso 2 vezes por dia (07-10-2026)

Elmar: «o stock e o painel clínico não têm redundância? É mais fácil colocar
atalho no painel clínico para ver a farmácia, assim tem menos coisas no ecrã
principal. O stock só aparece pop up 2 vezes ao dia».
- Painel clínico: nos quadros «Stock · <área>», «Farmácia: stock a repor» e
  «Laboratório: testes e consumíveis», o botão «Ver o stock completo ›»
  (`bspAtalhoStock`, só a quem vê o Stock) abre Logística e stock → Stock no
  armazém da área (`bspAbrirStockArmazem`, `BSP_STOCK_ARMAZEM_AREA`,
  `__bspStockArmazem` + evento `bsp-stock-armazem`).
- Início: o cartão do Stock (`StockAlertaCartao`) saiu; fica o do Painel
  clínico.
- Aviso do Stock no sino: um só aviso com todos os armazéns, no máximo 2 por
  dia (manhã antes das 13h00 e tarde), por pessoa e aparelho
  (`bsp-stock-aviso-<id>-<dia>`). O servidor não manda avisos de stock ao
  telemóvel (só dos toners).
- Novidade 228. Testado no navegador.

## 3-gl. Quem vê o Stock e as compras correntes (07-10-2026)

Elmar: «a Solange vê todos os stocks de saúde; a Rosa apenas o Laboratório; a
Arlete vê todos da empresa. O das compras que nem são de saúde só a Arlete vê
comigo».
- `stock-acesso-pessoas.sql` (aplicado): `stock_responsaveis` = u1 e u2 todos;
  u17 Farmácia, Laboratório e Enfermagem; u13 Laboratório. `bsp_ve_stock` deixou
  a regra dos consumos. `bsp_ve_compras_gerais` (u1, u2) nas 4 regras de
  `logistica_compras`.
- Conferido no servidor como cada pessoa: Elmar e Arlete 6 armazéns e 45
  compras; Solange 3 armazéns de saúde, 0 compras; Rosa só o Laboratório;
  Emmanuel nada no Stock nem nas compras.
- Ecrã igual (`BSP_STOCK_RESPONSAVEIS`, `bspVeStock`, `bspVeComprasGerais`).
  O Emmanuel e a Recepção ficam só com os Toners; o Gerador não mudou.
- Novidades 229 (correcção ao Emmanuel e Serviços Gerais) e 230 (Solange e Rosa).
- Por decidir: itens em cada compra corrente (produto, quantidade, preço) e a
  fotografia da factura (proposta de 07-10-2026).

## 3-gm. Limpeza: folha «Mapa de controle Serviços Gerais» importada (07-10-2026)

Elmar: «acrescente esse» (folha da Arlete com os consumíveis de higienização).
- 16 compras quinzenais de «Consumíveis de higienização», de 12-01-2026 a
  05-10-2026, gravadas só no servidor em `logistica_compras`, categoria
  `limpeza`, nota «Folha da Arlete (Mapa de controle Serviços Gerais)». Total
  igual ao da folha. Valores nunca no repositório.
- A folha, como as outras, não tem itens, fornecedor nem n.º de factura (só
  actividade, frequência, data e valor). Vários valores redondos podem ser
  adiantamentos: confirmar com a Arlete.

## 3-gn. Marcações com intervalo entre utentes (07-10-2026)

Elmar: «nas marcações não permita marcar todas no mesmo minuto; ginecologia em
média leva quanto tempo com a paciente?».
- Medido nas facturas do MetaGest (6 meses, 153 consultas de ginecologia, 2
  médicos; o MetaGest não regista o fim da consulta): intervalo mediano 25 min,
  médio 34 min entre utentes seguidos do mesmo médico.
- Nos últimos 60 dias havia até 7 marcações à mesma hora e 17 casos de dois
  utentes à mesma hora com o mesmo médico.
- `marcacoes-intervalo.sql` (aplicado): `marcacoes_duracoes` (ginecologia e
  obstetrícia 30 min; o resto 15), `bsp_marc_minutos`, `bsp_marc_duracao`,
  gatilho `bsp_marc_espacar`: recusa com a hora ocupada e a próxima hora livre.
  Só Agendada/Confirmada, hoje e datas futuras; mudar só o estado não conta.
- Testado no servidor (desfeito no fim): mesmo minuto e 20 min depois
  recusados com «Próxima hora livre: 08:30»; 08:30 aceite; outro médico à mesma
  hora aceite; cardiologia a 10 min recusada, a 15 min aceite.
- O ecrã já mostra a mensagem do servidor e deixa a janela aberta. Atenção: a
  importação por CSV pára se uma linha futura colidir (a mensagem diz qual).
- Novidade 231 (Recepção, gestão, Direcção Clínica). Por decidir: durações das
  outras especialidades (pediatria, cardiologia, ecografias…).
- Durações de referência geral (Elmar: «vê de forma geral, o MetaGest tem dado
  errado»), em `marcacoes_duracoes`: ginecologia/obstetrícia e cardiologia 30;
  pediatria, urologia, clínica geral/medicina interna 20; nutrição 45;
  psicologia 50; ecografia 20 (obstétrica/trimestre 30, morfológica 45);
  ecocardiograma 30; ECG 10; MAPA/Holter 15; o resto 15. Conferido com os
  actos escritos nas marcações reais (com e sem acentos). Novidade 232.
- Regra confirmada em vigor (gatilho `bsp_marc_espacar` activo) e anunciada no
  canal #recepção pelo Elmar (mensagem 6246, cid `marcacoes-regra-2026-10-07`).

## 3-go. Pagamento dos médicos de Setembro: o que falta (07-10-2026)

Elmar: «os pagamentos dos médicos, falta a Luidmila, certo?».
- Luidmila Chitata (prestador 17, u6): 6 dias de Setembro gravados da lista de
  presenças, com entrada e saída, mas sem mapa individual: faltam as consultas
  e reconsultas de cada dia (a ficha que ela assina).
- Alice Francó (prestador 4): nenhum dia de Setembro gravado.
- Ludmila Da Silva (prestador 16) está completa (11 dias com a ficha).
- Médicos activos sem nenhum dia de Setembro: Braúlio Andrade, Catarina Quiala
  (nutrição), Catiana dos Anjos, Conceição Calunga, Maria Ester Ramiro, Micaela
  Mangunda (psicologia), Miguel Pemba. A confirmar se não trabalharam ou se
  falta a ficha (a Elizabeth Holoca é só por ecografia).
- Mapas de Setembro recebidos e gravados (07-10-2026, por `bsp_pagamento_fichas`,
  em nome do Elmar; só as folhas «Actividades realizadas», sem o registo de
  pacientes):
  - Conceição Calunga (9): 8 dias (02, 04, 09, 11, 16, 19, 23, 30), consultas e
    ecografias (em «outros»). As facturas têm 12 dias: sem ficha os dias 06, 08,
    10, 13, 18 e 24; as fichas de 19 e 23 não têm factura nesse dia (talvez as de
    18 e 24).
  - Luidmila Chitata (17): 8 dias (03, 06, 09, 12, 18, 20, 24, 26). A ficha de
    «11/9» gravada a 12 (lista de presenças e facturas); o dia 24 passou a
    15:57–22:20 (a lista dizia 07:00–22:24). Sem ficha: 28 e 29 (há facturas).
- Falta: Alice Francó (29) e Catarina Quiala (30); confirmar os dias sem ficha.
- Dias com factura e sem ficha explicados pelas facturas (Elmar: «não serão
  facturas após notas de crédito ou feitas tarde?»): Conceição 06 e 13
  (domingos, utentes já vistos antes: facturação tardia), 08, 10 e 13
  (refacturação depois de nota de crédito; no 10, 2 notas de crédito), 18 (17:03,
  dentro do horário da ficha datada de 19: data da ficha provavelmente trocada),
  24 (10:30, a seguir à ficha de 23). Luidmila: 03 (factura criada a 01-09 e
  emitida a 03), 28 (utente já visto) e 29 (nota de crédito e refacturação).
  Nenhum destes dias pede ficha nova; falta só decidir a data 18/19.

## 3-gp. Setembro recalculado e «Mapa do BAI» por especialidade (07-10-2026)

Elmar: «avance com o que tem, actualize os mapas dos médicos, prioridade
clínicos gerais no mapa do BAI, depois pediatria».
- Ficha da Dra. Conceição Calunga de «19/9» gravada a 18 (factura às 17:03 de
  18/9, dentro do horário da ficha). Mapa de Setembro recalculado
  (`bsp_pagamento_calcular(2026, 9, true)`), estado «Aberto». Pendência que fica:
  Alice Francó sem fichas de presença.
- Ecrã: o botão «Exportar para o banco» passou a «Mapa do BAI (CSV)»
  (`mapa-bai-medicos-<mês>.csv`): N.º, prestador, especialidade, NIF, IBAN,
  bruto, IRT, líquido e linha TOTAL; clínica geral e medicina interna primeiro,
  depois pediatria, depois os outros, por nome. Só u1 e u2 (sai no aparelho de
  quem carrega). Testado: ordem e carga da página.

## 3-gq. Mapas para o banco no formato do BAI (07-10-2026)

Elmar: «o formato deve ser sempre esse [Template de Pagamentos Médicos do BAI],
data do dia que extraio, mapa para BAI-BAI e mapa para outros bancos, nunca
junte; a conta de origem é a que está no template».
- `pagamento-banco.sql` (aplicado): `pagamento_banco` (NIB a debitar, tipo de
  operação 33, e-mail, código do BAI 0040) e `bsp_pagamento_banco()` só para u1 e
  u2 (testado: u1 e u2 lêem; u14 recebe nada). O NIB do modelo foi gravado só no
  servidor; não está no repositório.
- Ecrã (Equipa → Pagamento dos médicos): «Mapa BAI → BAI (.xls)» e «Mapa outros
  bancos (.xls)» em vez do CSV. Ficheiro .xls (BIFF8, SheetJS 0.18.5 em
  `vendor/sheetjs`, licença Apache 2.0) com as folhas do modelo: Início (33, NIB,
  data de hoje AAAA-MM-DD, «prestacao <mês> medicos»), Movimentos (IBAN sem
  espaços, montante = líquido, nome em maiúsculas sem acentos, «prestacao de
  <Mês>», Financas@barispol.com) e Motivos escondida. Ordem: clínica
  geral/medicina interna, pediatria, outros. Fora: líquido 0 e sem IBAN (o aviso
  diz quem).
- Testado: os dois ficheiros lidos de volta com o leitor de .xls (xlrd): folhas,
  células de texto «@», ordem e separação BAI/outros. Hoje: 11 médicos activos
  com conta BAI, 11 noutros bancos, 2 sem IBAN (Braúlio Andrade e Maria Ester
  Ramiro).

## 3-gr. Produtividade: só o próprio, o superior e a gestão (07-10-2026)

Elmar: «a produtividade só o próprio funcionário, o superior e a gestão podem ver».
- Antes viam também quem edita a escala da área (a Direcção Clínica em todas as
  áreas de saúde) e os responsáveis da área.
- `produtividade-acesso.sql` (aplicado): `bsp_produtividade_trata` = gestão, o
  superior (`bsp_aprovador_de`: campo «superior», senão o chefe da área, como nas
  férias) e, para as 17 pessoas sem conta, o chefe da área (`bsp_superior_area`,
  a Direcção Clínica só quando não há outro). Vale para ver e para lançar notas.
  `desempenho_historico` (histórico mensal) com a mesma regra.
- Testado no servidor: Elmar e Arlete 33; Dr. Osvaldo 8; Juliana 8; Rosa 6;
  Filomena 3; Solange 3; Emmanuel e Nicolau só a sua. O ecrã não mudou (mostra
  o que o servidor devolve). Novidade 233.

## 3-gs. Produtividade: cada chefe só a sua equipa com conta (07-10-2026)

Elmar: «a Juliana não pode ver mais além dela, da Joice e da Déricka; a Rosa só
vê o Nicolau e a Cássia».
- Antes, as pessoas sem conta da Recepção (5) e do Laboratório (3) iam para a
  Juliana e a Rosa, como chefes da área.
- `produtividade-acesso.sql` (revisto, aplicado): `bsp_superior_area` passa a
  devolver o responsável de fora da área: Direcção Clínica nas áreas de saúde,
  gestão na Recepção e nos Serviços Gerais.
- Testado no servidor: Juliana vê u12, u8 e u15; Rosa vê u13, u3 e u19;
  Filomena e Solange só a sua equipa com conta; Dr. Osvaldo passa a ver as 3
  pessoas sem conta do Laboratório. Novidade 235.

## 3-gt. Pagamento dos médicos por etapas (07-10-2026)

Elmar: «tem a opção de ter mapas individuais dos médicos pronto a imprimir na sua
aba? Tem como escolher que médicos colocar na planilha para pagar? Vou pagar por
etapas, há escassez de valores» e «os pagos tenho de validar no perfil de cada um».
- `pagamento-etapas.sql` (aplicado): tabela `pagamento_etapas` (médico e mês:
  data, banco e valor do mapa; data, valor e quem validou o pago). Só u1 e u2,
  pelas funções `bsp_pagamento_etapas` (ler) e `bsp_pagamento_etapa` (mapa,
  pago, tirar_mapa, tirar_pago). Testado: o u1 grava; o u12 não lê nem grava.
- Ecrã (Equipa → Pagamento dos médicos):
  - Caixa «Pagar por etapas»: totais de pagos, em mapa e por pagar.
  - Caixa em cada médico para o escolher. Botões «Marcar os por pagar»,
    «+ Clínica geral», «+ Pediatria» e «Limpar a escolha».
  - Os mapas «BAI → BAI» e «Outros bancos» levam só os escolhidos de cada banco.
    Sem escolha, levam os que ainda não estão pagos nem noutro mapa. Ao gerar,
    os médicos ficam «No mapa … de DD/MM».
  - Na ficha de cada médico: «Imprimir mapa individual» (o mesmo do zip),
    «Validar pago» (com confirmação; guarda quem, quando e o valor), «Tirar
    pago» e «Tirar do mapa». Se o líquido mudar depois de pago, aparece a
    vermelho.
  - «Validar pagos os que estão em mapa»: valida todos de uma vez.
- Testado no navegador com dados simulados: escolha, mapa BAI só com o médico
  escolhido do BAI, registo da etapa, impressão individual e validação.
  Novidade 234 (u1 e u2).

## 3-gu. Segmentos de utentes (08-10-2026)

Elmar: «ponto 1 do HubSpot» (segmentos: listas de utentes por critério).
- Já existia o separador «Recuperar utentes» (`SeguimentoScreen`): a tabela
  `utentes` actualiza-se todos os dias a partir do MetaGest (5054 utentes) e
  só a lê quem vê o CRM. Mas ninguém o usou: 0 registos em `seguimentos`.
- `segmentos.sql` (aplicado): `bsp_segmento(p_seg)`, só para `crm.pode_ver_crm`.
  Valores a 08-10-2026:
  - `pacote`: check-up anual em atraso (pacote promocional há 11–24 meses): 53;
  - `faltou`: faltou ou cancelou em 60 dias sem remarcar nem vir: 5;
  - `so-servicos`: laboratório, farmácia, enfermagem ou imagem no último ano,
    nunca consulta: 382.
  Os três levam cerca de 1,7 s.
- Ficou de fora «exames sem consulta de resultados»: só 25 reconsultas
  facturadas em 12 meses (cerca de 2500 consultas), por isso as facturas não
  mostram quem voltou com os resultados.
- «Voltou» automático: `bsp_segmentos_voltou` (cron `bsp-segmentos-voltou`,
  07h00 de Luanda). Quem foi contactado ou marcado e depois teve factura passa
  a «Voltou», com nota.
- Ecrã: Utentes → «Segmentos» (antes «Recuperar utentes»). Botões dos 4
  segmentos, o motivo em cada utente, «Ligar» e «WhatsApp» (os dois registam
  «Contactado»). O «voltar» do telemóvel muda de segmento.
- Testado: sessão da Juliana no servidor (sim); Filomena recusada (não vê o
  CRM); ecrã com dados simulados, a 1280 e 390 px.
- Por fazer: medir, ao fim de um mês, quantos voltaram por segmento.

## 3-gv. Contactos da SendPulse na base de utentes (08-10-2026)

Elmar: «podes nos utentes importar todos os dias os que contactam pelo
SendPulse, mesmo os que não chegam até ao centro? Para o CRM base de dados».
- As conversas já entravam de 15 em 15 min (`crm.pedidos` / `crm.caixa`, 3072
  telefones desde 20-05-2026), mas só como pedidos, fora de `utentes`.
- `contactos-whatsapp.sql` (aplicado):
  - colunas novas em `utentes`: `origem`, `primeiro_contacto`,
    `ultimo_contacto`, `pedido`, `conversas`, `convertido_em`;
  - `crm.actualizar_contactos_whatsapp()`, todos os dias às 05h30 de Luanda
    (cron `crm-contactos-whatsapp`, depois da cópia do MetaGest);
  - primeira corrida: 2752 contactos que nunca vieram, com origem «whatsapp»;
    514 fichas de utentes completadas com os dados do WhatsApp; a segunda
    corrida mudou 1 contacto;
  - quando o telemóvel de um contacto aparece no MetaGest, ganha
    `convertido_em`; se tinha sido contactado, passa a «Voltou».
- Segmento novo «Escreveram e nunca vieram» (`nunca-vieram`): escreveram há
  mais de 3 dias (os recentes estão em «Pedidos do WhatsApp») e até 12 meses;
  mostra os 600 mais recentes, com o que pediram.
- «Não identificado» (serviço que a SendPulse não percebeu) não conta como pedido.
- Os números de `crm.contactos_excluidos` (equipa, testes) ficam de fora.

## 3-gw. Avarias: confirmação em 72 h, e-mails e entrada pelo e-mail (08-10-2026)

Elmar: «corre todos os e-mails e vê os problemas dos últimos dois meses que nos
foram reportados e põe nas avarias da respectiva área, criada pelo funcionário
que mandou o e-mail; antes, põe a opção de ele confirmar que a avaria existe, com
prazo de 72 horas, como tarefa de cada um»; «sempre que no meu e-mail entrar
alguma avaria, que suba para o sistema e que receba um e-mail automático a dizer
como se informa no Workspace»; «até Novembro, as avarias devem ser reportadas
primordialmente pelo Workspace; o e-mail é para reforçar ou cobrar»; «lembretes
de 5 em 5 dias para a área administrativa e a Direcção Clínica, com o emissor».

- **Levantamento** (caixa do Elmar, 08-08 a 08-10, cerca de 185 e-mails, e os
  relatórios de turno, que não tinham avarias): 19 casos.
  - 6 já estavam no Workspace: n.º 3, 4, 5, 6, 8 e 18.
  - 4 estão resolvidos segundo os e-mails, por isso não entraram: cabo da
    impressora do hemograma, AC do Consultório 2, esgoto do AC da cozinha, AC
    dos bastidores.
  - **10 entraram como «Por confirmar»** (n.º 21–30), em nome de quem reportou,
    cada uma com tarefa até 11-10 às 21h44:
    - UPS do Laboratório, ralos de 5 WC, WC do consultório de Ginecologia,
      impressora da Recepção e porta da Recepção: Emmanuel;
    - impressora de películas do Raio-X: Joana Tati;
    - hemograma (Lyse Diff): Rosa;
    - rato da Farmácia: Solange (o relatório não diz quem reportou);
    - baldes do lixo hospitalar e cabos do ECG: Domingos.
  - Fora da janela, talvez ainda por resolver: pontas dos cabos de rede (03-08)
    e arrancador da lâmpada do WC da Observação 1 (09-07).
- **`avarias-confirmar.sql`** (aplicado):
  - estado «Por confirmar»; colunas `origem`, `fonte`, `fonte_id`,
    `confirmar_ate`, `confirmada_em`/`_por`, `confirmacao`, `tarefa_id`,
    `cobrancas`, `resposta_email_em`;
  - `bsp_avaria_confirmar` («Confirmo que existe» ou «Já não existe»; conclui a
    tarefa);
  - `bsp_avarias_prazo` (cron `bsp-avarias-prazo`, de hora a hora): sem
    resposta em 72 h, a avaria passa a «Aberta» como não confirmada;
  - `bsp_avaria_email`: cada avaria aberta no Workspace ou confirmada vai por
    e-mail a Elmar, Arlete e Dr. Osvaldo, com quem a reportou e o Emmanuel em
    cópia;
  - `bsp_avarias_lembrete` (cron `bsp-avarias-lembrete`, 07h20 de Luanda, de 5
    em 5 dias a contar de 08-10; o primeiro sai a 13-10, depois do prazo das 72 h);
  - `bsp_avaria_do_email`: entrada pelo e-mail, com o código do cofre
    `bsp_avarias_codigo`, nunca mostrar.
- **Testado** em transacções desfeitas:
  - confirmação pela Rosa: avaria «Aberta», tarefa concluída e e-mail na fila,
    com os destinatários certos;
  - entrada pelo e-mail: cria a avaria em nome do Domingos e responde-lhe; o
    mesmo assunto conta como cobrança; um fornecedor é ignorado; um e-mail
    repetido não cria nada.
- **Ecrã** (Serviços gerais → Avarias):
  - faixa «Tem N avarias por confirmar», «Veio de:», cobranças, prazo, botões
    «Confirmo que existe» e «Já não existe»;
  - guia actualizado. Testado no navegador com dados simulados, a 390 px.
- **Novidade a toda a equipa:** «Avarias: reporte primeiro no Workspace».
- **Por fazer: ligar a caixa do Elmar ao servidor.** O Zapier desta conta não
  tem o Outlook ligado. Depois de o Elmar ligar a conta, cria-se o fluxo «New
  Email Matching Search» (avaria, avariado, «não funciona», estragado…) →
  `bsp_avaria_do_email`.
- 08-10-2026 (Elmar: «não tem nenhum relatório a falar de manutenção da máquina
  BS200, máquina de bioquímica»):
  - Nos dois meses não há nenhum e-mail nem relatório de turno sobre a BS-200.
    Os relatórios diários do Laboratório só trazem o registo de doentes e exames.
  - A história está antes da janela:
    - Novembro de 2025: intervenções e proformas da lâmpada;
    - 17/18-02: «Já temos em funcionamento a BS200?»; ureia e creatinina
      instáveis;
    - 26-06: a Rosa avisa que a lâmpada tem de ser trocada e que os resultados
      perderam fiabilidade;
    - 30-06: a Arlete envia duas propostas.
    Depois disso não há registo de compra nem de instalação. Os controlos do
    analisador esgotaram a 14-08 (cobrado a 21-08).
  - Registada como avaria n.º 33, «Urgente», «Por confirmar», em nome da Rosa
    (tarefa até 11-10). A BS-200 não está na lista de equipamentos (Serviços
    gerais → Equipamentos e manutenção): registada no dia
    seguinte (ver abaixo).
- 08-10-2026 (Elmar: «A lâmpada foi trocada, temos agora problema dos exames
  darem parâmetros errados»; «Ve todos canais se tem problema»):
  - Avaria 33 passou a «Analisador de bioquímica BS-200 (parâmetros errados)»,
    confirmada pelo Elmar e aberta (e-mail a u1, u2 e u14, com a Rosa e o
    Emmanuel em cópia; tarefa 60 fechada). No canal do Laboratório: LDL e HDL
    sem leitura desde 26-09; a 07-10 os triglicerídeos muito abaixo do
    aceitável e os exames suspensos; calibradores e controlos selados e por
    usar. Passo seguinte: calibrar, correr os dois controlos e só depois
    retomar; se falhar, técnico da Farwell.
  - Equipamentos 24 (BS-200, Mindray, «Avariado») e 25 (analisador de
    hematologia, «Em uso»), área Laboratório, fornecedor Farwell. Planos:
    manutenção preventiva de 180 em 180 dias (Farwell; BS-200 a 09-10, hemograma
    a 09-11) e calibração de 30 em 30 dias (Rosa, a 09-10). Números de série a
    confirmar; a Rosa acrescenta os outros aparelhos (novidade 257).
  - Avarias novas «Por confirmar», vindas do Chat: 34 cerca eléctrica com
    choque fraco (Emmanuel, 02-10, Alta, tarefa 61) e 35 cheiro estranho na sala
    do técnico de Raio-X (Radiologia, 06-10, tarefa 62).
  - Nos outros canais: hemograma normal desde 01-10 (avaria 25: a Rosa deve
    responder «Já não existe»); impressora NCR já na avaria 29.
  - Ferramenta do servidor: certos textos em `update`/`insert` deixam-na à
    espera sem fim (não é a base de dados). Enviar o texto em base64:
    `convert_from(decode('…','base64'),'UTF8')`.
- 08-10-2026 (Elmar: alerta crítico «Workspace: possível falha (agendamento)» às
  16h00 com `bsp-avisos-mensagens`, `bsp-clinico-carga` e `bsp-painel-hoje`):
  falha passageira do servidor às 15h45-15h46 (arranque do agendador e ligação
  ao MetaGest); os três voltaram a correr bem no minuto seguinte, sem mais
  falhas. A `bsp_vigilancia` (`vigilancia.sql`) passou a contar só a falha que
  continua: um agendamento com uma execução boa depois da falha não dá alerta.
- 08-10-2026 (Elmar: «As avarias apenas os da mesma área e nós superiores vemos,
  não podem todos ver tudo»): `avarias-acesso-area.sql` (aplicado). Avarias: quem
  reportou, a área de quem reportou, a área da avaria, o superior/chefe de quem
  reportou, a Direcção Clínica nas áreas de saúde, a gestão e os Serviços
  Gerais. Equipamentos, planos e registos de manutenção (antes abertos a todos):
  só a área do equipamento, a Direcção Clínica nas áreas de saúde e quem trata
  as avarias; sem área (ar condicionado), só quem trata. Testado com contas
  reais: Recepção 2 avarias e 0 equipamentos; Radiologia 2 e 0; Laboratório 3 e
  2; Direcção Clínica 13 (áreas de saúde) e 2; Elmar e Emmanuel todas (19 e 23).
  Textos do ecrã e do guia actualizados.

- 09-10-2026 (Elmar: «actualizar a quilometragem inicial da ambulância»; «editar
  as quilometragens mesmo sem actividade… coloca a quilometragem agora e depois
  soma a cada movimentação»): `transporte-acertos.sql` (tabela
  `transporte_acertos`: viatura, km, motivo, quem e quando; só a gestão grava,
  nunca se apaga). Ecrã: botão «Acertar km» (gestão, sem viagem em curso),
  `TranspAcertoModal`, `bspTranspUltimoKm` (o último acerto é o ponto de
  partida; só contam as viagens registadas depois dele, para um acerto para
  baixo corrigir km mal escritos), `bspTranspContas` sem «km sem registo» no
  salto explicado por um acerto; «Último acerto» no cartão da viatura; aviso
  «📝 Km acertados» no grupo do Transporte.
  - Aplicado a 09-10-2026. Acerto n.º 1: Ambulância (viatura 2, LD-30-88-GR)
    = **6 946 km** (fotografia do painel do Elmar; o 9,5 km é o parcial), em nome
    do Elmar. A ambulância não tinha viagens. Testado no servidor: o Elmar lê e
    grava; o Emmanuel (motorista) lê e não grava; a Recepção não lê.
- 09-10-2026 (Elmar: «A escala não aparece para todos no perfil da Solange… resolva
  para todos»; escolheu «Todos vêem todas»): a escala da Farmácia de Outubro
  estava publicada e em vigor e a Solange recebia-a; cada pessoa só via a da sua
  área. `escalas-ver-todas.sql` (aplicado): quem tem conta, menos os sócios, lê as
  escalas publicadas de todas as áreas; rascunhos só a própria área e quem edita;
  editar não muda. Ecrã: `bspVeEscala` lista todas as áreas; «De serviço hoje»
  mostra toda a clínica. Testado no servidor: Solange, Déricka, Rosa e um médico
  vêem as 6 publicadas de Outubro; rascunhos só os da sua área; sócio nada.


## 3-gx. Auditoria de segurança — Fase 1 (12-10-2026)

Elmar: «Avalie a segurança da plataforma e dos dados»; depois «Aprovo o plano
mas diminui o prazo, faz mais rápido. Estamos vulneráveis». A avaliação completa
(segurança, conformidade e layout, com as 4 fases) está no plano aprovado e
resumida no `CLAUDE.md`. Feito hoje:

1. **`shared-state-fechar.sql` (aplicado).** A regra antiga deixava toda a
   equipa escrever `team` e `camadas` no `shared_state` (qualquer conta podia
   pôr-se na Direcção, trocar o e-mail pela entrada de outra pessoa e, pela
   `criar-utilizador`, mudar a palavra-passe de qualquer conta). Agora o
   gatilho `bsp_estado_guarda` só deixa a gestão (`bsp_e_gestor`) mudar esses
   dois campos; aos outros mantém-lhes os valores antigos em silêncio, para as
   tarefas e eventos continuarem a gravar. Cada alteração, aceite ou recusada,
   fica em `equipa_auditoria` (só a gestão lê). A API perdeu o privilégio de
   apagar a linha; só se insere a linha 1. A guarda lê `auth.jwt()->>'role'`
   (dentro de uma função security definer o `current_user` é o dono, por isso
   não serve). Testado com sessões simuladas: a Rosa não entra na equipa nem
   cria camadas (2 registos recusados) mas grava eventos; o Elmar altera e fica
   registado; a linha 2 é recusada. Só três contas são gestoras: Elmar, Arlete
   e a conta de teste «Beb» (Direcção) — **o Elmar deve desactivá-la**.
2. **`imprimir.html`:** o documento vindo do `#z=` deixou de entrar na página
   por `document.write` (um `<img onerror=…>` corria dentro de barispol.com,
   lia as conversas guardadas e podia apontar o Workspace para um servidor
   falso). Vai para um `<iframe sandbox="allow-same-origin">` sem scripts; a
   altura ajusta-se ao conteúdo e a impressão é da página. Testado no
   Playwright com um documento malicioso: título intacto, sem diálogos, sem
   `bsp_supabase_cfg` gravado, documento visível.
3. **Ligação ao servidor:** `bspGetCfg` só aceita o valor guardado no aparelho
   se for o mesmo endereço do `servidor.js`; outro é apagado. O ecrã manual
   «Ligar o servidor a este dispositivo» (entrada) e o «Guardar» do Admin →
   Sistema deixaram de gravar outro servidor.
4. **CSP** por `<meta>` no `workspace.html`: só o próprio site e o Supabase do
   projecto (`connect-src`, `img-src`, `media-src`), `object-src 'none'`,
   `base-uri 'none'`, `form-action 'self'`; scripts e estilos inline da própria
   página (`'unsafe-inline'`, porque o React UMD não compila). `referrer`
   `strict-origin-when-cross-origin`. A página sai de dentro de qualquer iframe
   (o GitHub Pages não permite `frame-ancestors`). Os `preconnect` às fontes da
   Google saíram (as fontes são locais). Imagens coladas no Chat de outros
   sítios deixam de carregar (também evita rastreio).
5. **`inserts-sem-equipa.sql` (aplicado):** as regras de inserir mensagens e
   publicações já não aceitam `bsp_meu_id() is null` (uma conta fora da equipa
   escrevia em nome de qualquer pessoa). Em produção, `utentes` e
   `seguimentos` já estavam fechados a `crm.pode_ver_crm()` (os ficheiros
   `crm-seguimento.sql` e `INSTALAR-TUDO.sql` estavam desactualizados).
   **Por confirmar pelo Elmar no painel:** Authentication → Sign In →
   «Allow new users to sign up» desligado.
6. **Repositório:** retirados do `O-QUE-FALTA.md` os valores em Kz ligados a
   médicos pelo nome (3-ax, 3-gc). **Decisão do Elmar:** tornar o repositório
   privado (o GitHub Pages em repositório privado exige plano pago) ou mantê-lo
   público com esta limpeza.
7. **Ecrã de Segurança (Admin):** passou a dizer só o que existe (sem «2FA
   activo» nem «sessão expira após 8 h»).

## 3-gy. Auditoria de segurança — Fase 2 (12-10-2026)

1. **Estado fora do `localStorage`** (`workspace.html`): `bsp-workspace-v1`
   (conversas, feed, equipa), `bsp-notifs-v1` e a cache de endereços assinados
   `bsp-urls-<id>` passaram ao `sessionStorage`, como a sessão. Fechar o
   separador ou a app apaga tudo; um separador novo lê do servidor. Ao arrancar,
   as cópias antigas do `localStorage` apagam-se. Os endereços assinados dos
   anexos valem 4 h (`BSP_URL_VALIDADE` 14400), e não 24 h. As preferências do
   aparelho (tema, ordem, viatura, TURN) ficam no `localStorage`. Testado no
   Playwright: chaves antigas apagadas, estado só no separador, sem erros.
2. **Push sem texto** (`push-sem-texto.sql`, aplicado): o aviso do telemóvel
   das mensagens do Chat (`bsp_push_mensagem`) deixou de levar os 160
   caracteres do texto (ficavam nos serviços da Google e da Apple e no ecrã
   bloqueado, com nomes de utentes nas conversas clínicas). Diz só quem e onde
   («Rosa · #laboratório») e «Nova mensagem», «📎 Anexo», «Novo comentário».
   Feed, tarefas, documentos e agenda mantêm o título. O Workspace aberto
   mostra o texto como antes.
3. **`bright-worker` versão 8** (`emails-autor.sql`, aplicado; função
   publicada): `emails_registo.autor` (id da equipa, «servidor» ou
   «gestor:<id>»); colaborador que não é gestor: no máximo 20 e-mails por dia
   (`bsp_emails_de_hoje`, resposta 429) e o HTML passa por `limparHtml` (sem
   scripts, iframes, formulários, `on*=`; ligações e imagens só para
   barispol.com ou `mailto:`), para ninguém forjar, de geral@, um e-mail com
   uma ligação para fora. O cartão `bspEmailWrap` passa inteiro, com as
   tabelas das escalas. Testado: a chave pública continua recusada (403); a
   limpeza foi testada com scripts, `onerror`, formulários e ligações falsas.
4. **`funcoes-fechadas-2.sql` (aplicado):** a chave pública (`anon`) perdeu os
   privilégios em todas as tabelas e sequências de `public` (tinha SELECT e
   INSERT em 70, sem regras RLS, por herança dos privilégios por omissão) e o
   EXECUTE em todas as funções de `public`, `crm`, `erp` e `whatsapp` (60),
   menos as quatro entradas de visitantes (`bsp_pedido_site`,
   `bsp_feedback_publico`, `bsp_feedback_email`, `bsp_avaria_do_email`); os
   privilégios por omissão do `postgres` deixaram de os dar a `anon` e a
   `public`. `authenticated` ficou com o que tinha, concedido de forma
   explícita; as funções de gatilho ficaram sem EXECUTE pela API. RLS ligado
   nas 10 tabelas de `erp`/`crm` que não o tinham (stock, cobranças, espera,
   fila, `pedidos_facturas`). Confirmado: 0 tabelas de `public` legíveis por
   `anon`, 0 funções fora de `public` chamáveis pela API, 4 abertas a `anon`,
   `crm_ficha`/`bsp_e_gestor`/`bsp_painel` continuam acessíveis com sessão.
   **Regra nova:** uma função nova só fica aberta a visitantes com `grant
   execute … to anon` escrito de propósito.
5. **`retencao-copias.sql` (aplicado):** `bsp_copia_diaria` passa a copiar
   todas as tabelas de `public` (91; antes 12 escolhidas à mão, sem as
   clínicas e financeiras) mais `storage.objects`, 7 dias (cerca de 100 MB em
   `copias`). `bsp_retencao` (domingos 03h30 UTC, cron `bsp-retencao`):
   `capturas_ecra` e `emails_registo` 12 meses, `feedback_email_entrada` e
   `recuperacoes_pedidos` 90 dias, `pedidos_marcacao` tratados 12 meses,
   `presenca_dias` e `equipa_auditoria` 24 meses. Primeira passagem: 0 linhas
   (tudo recente). **Cópia fora do Supabase:** continua por fazer; precisa de
   um destino do Elmar (armazenamento próprio ou plano pago com PITR).
6. **CORS por lista, Android e Actions:** as sete Edge Functions chamadas
   pelo Workspace (`agenda-avisos` v3, `assistente` v3, `bright-worker` v9,
   `criar-utilizador` v3, `relatorios-diarios` v13, `resumo-matinal` v15,
   `resumo-pessoal` v2) passaram a responder `Access-Control-Allow-Origin`
   só para barispol.com, www.barispol.com e a origem da app
   (`comCors`, `ORIGENS_PERMITIDAS`), em vez de `*`; o acesso continua a ser
   decidido pelo testemunho. A `resumo-matinal` e a `relatorios-diarios`
   publicadas ainda levavam a fonte Dax: agora Titillium Web (regra 7).
   `AndroidManifest.xml` com `allowBackup="false"` (o Android deixa de copiar
   os dados da app para a conta Google); APK de teste nos Artifacts por 7 dias
   (era 30). As actions ficam por etiqueta de versão (`@v4`): fixar por SHA
   obriga a actualizar à mão a cada versão; fica para quando houver Dependabot.
7. **Entradas do site atrás de uma Edge Function** (`entradas-publicas.sql`,
   aplicado; `funcoes/entrada-publica/index.ts` v1 publicada): `index.html`,
   `contacto.html` e `avaliar.html` deixaram de chamar `bsp_pedido_site` e
   `bsp_feedback_publico` com a chave pública; chamam `entrada-publica`
   (`{qual: 'pedido'|'feedback', dados}`), que confere a origem (só
   barispol.com), o campo-armadilha «empresa» e o limite de 5 por hora por
   ligação (IP só como resumo SHA-256 com sal em `entradas_publicas`, 30 dias
   na `bsp_retencao`), e só então chama a função com a chave do servidor. As
   mensagens das funções («Escreva o seu nome.») continuam a chegar às páginas
   em `message`. As duas funções perderam o EXECUTE de `anon` (aplicado logo
   depois de o site publicar as páginas novas): a chave pública só chega às
   duas funções do Zapier (`bsp_feedback_email`, `bsp_avaria_do_email`). Testado pelo servidor: origem
   barispol.com passa (e devolve o erro de validação da função), origem
   estranha recebe 403, campo-armadilha recebe «ok» sem gravar. Turnstile:
   entra nesta função quando o Elmar tiver as chaves da Cloudflare.
8. **Auditoria dos dados sensíveis** (`auditoria-dados.sql`, aplicado):
   tabela `auditoria_dados` (quem, quando, tabela, operação, chave, só as
   colunas que mudaram, antes e depois; só a gestão lê; 24 meses na
   `bsp_retencao`) e gatilho `bsp_auditar` em 14 tabelas (`marcacoes`,
   `utentes`, `seguimentos`, `registo_clinico`, `prestadores`, `credenciais`,
   `ausencias`, `produtividade_*`, `pagamento_*`), só para o que vem pela API
   com sessão (o servidor e os crons não entram, senão a cópia diária dos
   utentes enchia a tabela). Leituras pela API: `crm_ficha`,
   `bsp_registo_clinico_dia`/`_lista`, `bsp_pagamento_calcular`/`_detalhe` e
   `bsp_produtividade_valores` registam quem as chamou em `acessos_registo`
   (`bsp_acesso_srv`; detalhe sem nomes), como o ecrã já fazia; as funções
   passaram a VOLATILE. Testado com sessão simulada e desfeito: a alteração
   de uma marcação ficou registada com antes/depois, um `update` sem mudança
   não; a leitura de uma ficha ficou em `acessos_registo`.

Resto da Fase 2 (até sexta): painel Auth (regras de palavra-passe, sessões, Turnstile,
TOTP para a gestão),
Workspace em subdomínio ou píxel só no site, entradas públicas atrás de uma
Edge Function com limite por IP, `bright-worker` com limite por pessoa, CORS
fechado, push sem texto clínico, fecho de `crm_pedidos`/`crm_ficha`, RLS em
`erp.stock_*`, retenção e cópias fora do Supabase, auditoria genérica, Android
`allowBackup=false`. Fase 3 (duas semanas): política de privacidade para
utentes, consentimento das campanhas, APD e DPA com jurista, documentos ISO
27001. Fase 4 (layout, um ponto por dia): toasts de erro, uma janela de cada
vez, zoom (decisão do Elmar), menu por função, foco e contraste, cores à mão.
- 12-10-2026, Dr. Mário Luís Da Silva Camuanda (MetaGest HLC-PRAC-2026-00011,
  cédula 11082, Clínica Geral; dados enviados pela Arlete no Chat a 09-10):
  médicos copiados do MetaGest, pessoa `u1791664176042` em `shared_state.team`
  (Clínica, Médico, `metagest`) e na lista embutida `USERS`, prestador 30
  (Medicina Geral, regime A, 15.000, `user_id` ligado), cédula em
  `credenciais`. **Pelo Elmar:** criar o acesso em Admin → Equipa com uma
  palavra-passe provisória (regra 1) e preencher NIF e IBAN na ficha.

## 3-gz. Pedidos do Emmanuel: toners, registo inicial de km e plano de manutenção (12-10-2026)

Três pedidos do Emmanuel Domingos no Chat (capturas enviadas pelo Elmar):
«não temos a opção para solicitar toners», «não tem a opção de registo
inicial» (viatura) e a folha «BRSP-LOG Plano de Manutenção de Equipamentos
2026».

1. **Pedir toners** (`toners-pedidos.sql`, aplicado). Os pedidos de compra só
   aceitavam armazéns do MetaGest (`bsp_ve_stock`). O armazém «Toners» em
   `pedidos_compra` passa a ser de quem vê os toners (`bsp_ve_toners`:
   gestão, Serviços Gerais e Emmanuel, Recepção, Laboratório), nas três
   regras (ler, criar, mudar). No ecrã, Logística e stock → Toners → botão
   «Pedir toners (N em falta)» abre o `PedidosCompraPainel` com o armazém
   `Toners` e os consumíveis abaixo do mínimo já na lista (quantidade
   sugerida: mínimo + 1 − o que há). A gestão aprova no mesmo sítio; a
   novidade para a gestão diz «Aprove em Logística e stock → Toners». Depois
   da compra, a entrada faz-se como antes («Entrada no armário»).
2. **Registo inicial de km** (`transporte-km-inicial.sql`, aplicado). A
   regra `transporte_acertos_criar` aceita o primeiro acerto de uma viatura
   sem acertos a quem vê o Transporte (`bsp_ve_transporte`: motorista e
   gestão); a partir do segundo, só a gestão. No ecrã: botão «Registo
   inicial de km» no cabeçalho (no lugar de «Acertar km», para quem não é
   gestão, e só enquanto a viatura não tem acerto) e no cartão da viatura;
   o `TranspAcertoModal` com `inicial` explica que é o ponto de partida e
   que se faz uma só vez; na viatura nova (e numa existente sem acerto) o
   `TranspViaturaModal` tem o campo «Km no conta-quilómetros (registo
   inicial)», que grava o acerto logo a seguir à viatura. O Suzuki Eeco
   ainda não tem acerto (a Ambulância já tem): o Emmanuel pode fazê-lo.
3. **Plano de manutenção preventiva 2026** importado só no servidor
   (`equipamentos`, `manutencoes_plano`, `manutencoes_registo`; nunca no
   repositório, por ter custos e facturas): equipamentos novos «Gerador de
   energia» (a cada 120 dias; próxima 02-11-2026), «Viatura Suzuki Eeco» e
   «Viatura Suzuki S-presso» (categoria Viatura, matrícula em
   `numero_serie`; revisão a cada 90 dias ou 5.000 km) e «Cerca eléctrica»
   (a cada 180 dias); os 21 ar condicionados já registados ficaram com plano
   de 60 dias. Registos da ficha: revisões das duas viaturas (Março/Abril e
   Agosto, Angolauto), limpeza geral dos 21 aparelhos a 05-08-2026 (Rasos
   Tec; o custo da factura dividido por aparelho; correctivas nos
   Bastidores e no Laboratório (1) anotadas) e a cerca a 01-08-2026. Os
   gatilhos calcularam a próxima: ar condicionados 04-10-2026 (já vencida,
   como na folha, «agendada Out»), viaturas 05 e 10-11-2026, cerca
   28-01-2027. Tudo em Serviços gerais → Equipamentos e manutenção.
   O gerador não tem registo com dia (a folha só diz «Março»); fica na nota
   do equipamento.

Testado com sessões simuladas e desfeito: o Emmanuel cria um pedido no
armazém Toners e não num armazém do MetaGest; faz o 1.º acerto da viatura 1
e o 2.º é recusado; na viatura 2 (já com acerto) é recusado; a Recepção
(u12) pede toners mas não acerta km. `workspace.html` passou no `node
--check`.

**Nota para o Emmanuel** (já respondida pelo Elmar no Chat, a confirmar):
as três opções estão no Workspace; o registo inicial dos km do Eeco deve
ser feito com o painel à vista.

## 3-ha. App do Workspace para computador (14-10-2026)

Pedido do Elmar: «cria app do workspace para pcs». Pasta `app-pc/` com
Electron 44.4.5 e electron-builder 26.15.3: uma janela própria que abre
`https://barispol.com/workspace.html` (o conteúdo actualiza-se com o site,
como a app Android). Fluxo `.github/workflows/app-pc.yml` («App PC»):
Windows (instalador `Barispol-Setup-1.N.exe` e `Barispol-1.N-portatil.exe`)
e Mac (`Barispol-1.N.dmg`), em Artifacts 30 dias.

- Segurança: `contextIsolation`, `sandbox`, sem `nodeIntegration` nem
  `preload`; só navega em barispol.com e `*.supabase.co`, o resto abre no
  navegador; câmara, microfone e notificações só para barispol.com; uma só
  instância; sessão termina ao fechar (regra do `sessionStorage`).
- Sem internet mostra `app-pc/sem-ligacao.html` («Tentar de novo»); a da
  app Android é gerada pelo `app/sincronizar.js` e não está no repositório.
- Testado aqui com ecrã virtual: sem acesso a barispol.com (rede deste
  ambiente) mostrou «Sem ligação»; a página não vê `require`/`process`;
  ir para outro site e `window.open` recusados; o pacote compila.
- Sem assinatura de código: o Windows avisa na primeira vez («Mais
  informações» → «Executar mesmo assim»). Assinar exige certificado pago
  (decisão do Elmar, se quiser).
- Com a app fechada não há notificações no computador (o Electron não tem
  Web Push); com ela aberta, sim.
- Guia em `app-pc/LEIA-ME.md`. Alternativa sem instalar: Edge/Chrome →
  «Instalar Barispol Workspace».

## 3-hb. Relatórios de turno no Workspace, sem repetir o MetaGest (14-10-2026)

Análise dos e-mails de fim de turno de 12 e 13-10 (Elmar: «ver o que está
débil e o que pode ser repetitivo … o importante não enviam»): os e-mails
repetiam contagens que o MetaGest já dá às 06h50/07h15 e deixavam de fora o
que só a área sabe (stock, equipamentos, pendentes, incidentes, frio). O
formulário do Workspace só tinha 2 entregas desde sempre. Feito
(`relatorios-turno.sql`, aplicado; `workspace.html`):

1. O formulário vem preenchido com o MetaGest do dia
   (`bsp_relatorio_metagest`: contagens, esgotados, a acabar, a caducar em 7
   dias, avisos da Recepção; só a área, u14 e a gestão). A pessoa confirma.
2. Ao entregar, os números do MetaGest ficam no relatório (`metagest`).
3. «Precisa de atenção»: rupturas, stock baixo, equipamento avariado,
   intercorrências graves, incidentes, resultados atrasados, documentos e
   fechos por enviar → aviso no telemóvel e novidade à gestão, à Direcção
   Clínica (áreas de saúde) e ao chefe da área. Equipamento avariado mostra
   o botão «Reportar avaria».
4. Conferência: actos declarados acima do facturado → «Possível acto por
   facturar» ao Elmar e à Arlete (testado com 13-10: 3 injecções declaradas,
   2 actos no MetaGest).
5. E-mail com as perguntas por extenso (antes mostrava os nomes internos dos
   campos), «Precisa de atenção» e conferência no topo.
6. Lembrete 1 hora depois do fim de cada turno da escala publicada, a quem
   esteve no turno e não entregou (cron `bsp-relatorios-lembrar`, 30 em 30
   min; uma vez por turno, `relatorios_lembretes`).
7. Dia do relatório: antes das 06h00 conta como o dia anterior.
8. `relatorios_destinos` do Laboratório: deixou de ir para a Rosa Queirós
   (saiu a 12-10) e vai para a Direcção Clínica, até haver nova chefia.

Transição: até 21-10-2026 os e-mails à mão continuam em paralelo (novidade
às áreas). Depois, decidir com o Elmar desligá-los. Por fazer: o Raio-X envia
o e-mail para «direcçãoclinica@» (com ç), que não existe; anexos com dados de
doentes (requisições, Excel acumulado da Enfermagem) devem passar para o
Drive.

## 3-hc. Chat aberto e notas de voz no iPhone (14-10-2026)

Pedidos do Elmar: «está confuso e o chat tem pouco espaço, revê os botões,
medidas e torne um chat aberto e limpo; não tem opção de minimizar menus» e
«erro ao enviar áudio» (iPhone: 20 s gravados e «a nota de voz ficou vazia»).

Feito (só `workspace.html`, sem mudanças no servidor):

- **Menu lateral**: botão ao lado do logotipo recolhe o menu para os ícones
  (72 px). O aparelho lembra-se (`bsp-menu-recolhido`). Com o menu recolhido,
  o botão da conta fica por baixo da fotografia e abre ao lado. Saiu o cartão
  «Centro Médico Barispol · Luanda», que não fazia nada.
- **Chat**: a lista de conversas esconde-se e volta pelo mesmo ícone
  (`bsp-chat-lista`); o painel «Sobre» (membros e ficheiros) só abre pelo
  botão «i» no cabeçalho (`bsp-chat-info`, fechado por omissão); «Procurar
  conversa…» passou a filtrar canais e pessoas (antes não fazia nada);
  cabeçalho com 52 px e botões sem moldura; sem o contador de mensagens;
  a barra de formatação abre com «Aa»; o texto de ajuda do Enter passou para
  a dica do botão «Enviar»; margens menores.
  Num ecrã de 1366 px a conversa passou de cerca de 540 px para 856 px e,
  com tudo recolhido, 1268 px (teste Playwright, também a 390 px, sem nada a
  passar da largura).
- **Notas de voz no iPhone**: o `AudioContext` fica «interrupted» ao ligar o
  microfone. Agora retoma-se em qualquer estado parado (e cria-se outro se
  não arrancar), volta a retomar-se se o iPhone o interromper a meio e, se em
  1,5 s não houver som, a nota grava-se pelo gravador do aparelho em M4A
  (AAC), nunca WebM. Testado no Chromium com microfone simulado: WAV pelo
  caminho normal; M4A quando a Web Audio não dá som.

Falta: o Elmar confirmar no iPhone (ecrã principal) que a nota de voz sai.

## 3-hd. Destinatários dos relatórios de turno e teste com os técnicos (14-10-2026)

Elmar: «envie um e-mail para cada técnico da área com a tarefa de preencher
com os dados do seu último relatório… prazo de 72 h» e «os relatórios seguem
para direcção clínica, adm e superiores de cada área».

- Teste: 14 técnicos (Enfermagem 4, Farmácia 3, Laboratório 2, Radiologia 2,
  Recepção 3) receberam um e-mail com o porquê (acabar com os e-mails
  repetidos à mão) e uma tarefa privada delegada pelo Elmar (ids 64 a 77),
  prazo 17-10-2026, 16h30. Na «Observação» escrevem «Teste — dados de DD-MM».
- `relatorios-destinos-superiores.sql` (aplicado): `bsp_relatorio_destinatarios`
  calcula para (chefe da área + DireccaoClinica@) e cc (adm@ + superior de quem
  entrega), sem quem entrega e sem repetidos; `bsp_relatorio_area_email` passa a
  usá-la. Antes a Recepção não ia à Direcção Clínica e o Laboratório e a
  Imagiologia não iam a nenhum chefe. O Laboratório continua sem chefe (falta
  nomear quem substitui a Rosa Queirós).

## 3-he. Teste dos relatórios de turno: primeiras respostas (16-10-2026)

Elmar: «teste da tarefa de relatórios, vê o sistema se está como deve ser».

- A chegar pelo Workspace (e-mail automático para o chefe da área e
  DireccaoClinica@, cc adm@, confirmado no de 15-10 da Enfermagem): Enfermagem
  (Afonso 14-10, Domingos 15-10), Laboratório (Nicolau 14-10, Cássia 15-10),
  Imagiologia (Joana 15-10), Farmácia (Solange 1.º fecho e Gizela 2.º fecho,
  15-10). Falta a Recepção.
- Problema da Juliana («mesmo após alterar a data, o sistema não apresenta os
  dados do dia pretendido»): o formulário usava sempre o dia de hoje, e a data
  só mudava a lista. Corrigido em `workspace.html`: campo «Dia do relatório»
  no formulário (até 7 dias para trás, igual ao servidor); os números do
  MetaGest (`bsp_relatorio_metagest(p_area, p_dia)`), o `dia` gravado e por isso
  a conferência com o facturado passam a ser desse dia.
- Enfermagem (Domingos): novos campos opcionais «Sinais vitais» e «Medicação
  oral» (`sinais_vitais`, `medicacao_oral`); as injecções dizem «todas, também
  as da Observação».
- Por ver: há entregas repetidas no mesmo dia (teste + dia real); a Enfermagem
  e o Raio-X continuam a mandar também o e-mail à mão (previsto até à aprovação).
- O conector do Supabase nesta sessão passou a outra conta (só mostra o projecto
  antigo e a Quinta do Pinhão): o estado das tarefas 64 a 77 não foi lido.

## 3-hf. Subdomínio ws.barispol.com, 2FA e verificação automática (16-10-2026)

Elmar: «Aprovo o subdominio e tira do site principal o botão para equipa. Tudo
que depende de ti faz já».

Feito:
- Site: retirada a ligação «Colaboradores» do rodapé (`index.html` e
  `ferramentas/modelo-site.html`). O Workspace continua em
  barispol.com/workspace.html até à passagem.
- Verificação em dois passos (TOTP) no Workspace: Conta → «Verificação em dois
  passos» (`DoisPassosModal`: QR e chave, confirmação por código, desligar).
  Quem a tem activa vê o `MfaCodigoEcra` depois da palavra-passe
  (`useBspMfaNivel`, aal2). Por agora opcional; o ecrã de Segurança diz isso.
  Testado no Playwright (activação, QR, código só com algarismos).
- ws.barispol.com já aceite: CSP do `workspace.html`, `ORIGENS_PERMITIDAS` das
  10 Edge Functions (só no código: **falta o deploy**), `PERMITIDOS` da app PC.
- Verificação automática: fluxo «Verificar» (`.github/workflows/verificar.yml`
  + `ferramentas/verificar-sintaxe.py`) confirma a sintaxe das páginas e dos
  .js a cada publicação.
- Modelo do fluxo do site ws: `ferramentas/ws-site/publicar-ws.yml`.
- Rascunho da política de privacidade para utentes:
  `ferramentas/rascunhos/privacidade-utentes.md` (sem ligação; jurista e APD).

Passos do Elmar (por esta ordem):
1. Voltar a ligar o conector do Supabase com elmar.bravo@barispol.com (nesta
   sessão estava noutra conta). Sem isso não há deploy das funções.
2. GitHub: criar o repositório público `elmarbravo/barispol-ws` (a integração
   não tem permissão para o criar); Settings → Pages → Source «GitHub
   Actions»; copiar para lá `ferramentas/ws-site/publicar-ws.yml` em
   `.github/workflows/`; Custom domain `ws.barispol.com`, «Enforce HTTPS».
3. DNS (Cloudflare): CNAME `ws` → `elmarbravo.github.io`, sem proxy (nuvem
   cinzenta) até o certificado sair.
4. Supabase → Authentication → URL Configuration: acrescentar
   `https://ws.barispol.com/**` aos Redirect URLs.

Depois disso, eu: deploy das 10 funções; `SITIO`/ligações dos e-mails para
ws.barispol.com; `server.url` da app Android e da app PC; redireccionar
barispol.com/workspace.html para ws (só depois de confirmar que a sessão
entra); obrigar o 2FA aos gestores no servidor (painel Auth + regra aal2).

## 3-hg. Laboratório (reagentes), Emmanuel sem dados clínicos, Stock geral (16-10-2026)

Elmar: «1- Para o laboratório, há a necessidade de inserir a quantidade de
exames que os reagentes permitem processar e as quantidades de exames
processados no dia. 2- Desativar o acesso de relatórios e outras informações
clínicas ao utilizador do Emmanuel. 3- Acréscimos de quantidades de alguns
fármacos com mais saídas no Stock geral» (ponto 3: «Alerta mais cedo»).

Feito no ecrã (`workspace.html`), testado no navegador:
1. Relatório do Laboratório: campo «Reagentes» (`reagentes_exames`, tipo
   `reagentes`), uma linha por reagente com «Permite» (exames que ainda dá) e
   «Processados» (no dia); mostra «Ficam N» e avisa a vermelho quando acaba
   no dia seguinte. Obrigatório (pelo menos um reagente). Os processados não
   passam do que permite (kit novo: somar). O relatório seguinte vem com o
   que ficou no último (`bspReagentesSeguintes`). No e-mail: «Hemograma:
   permite 200, processados 40, ficam 160».
2. Emmanuel (u22): `bspSemClinico` tira Relatórios, Painel clínico,
   Qualidade, Utentes e Actividade (menu, «Mais» e rotas).
3. Stock geral: os 10 artigos com mais saídas em 30 dias passam a «A acabar»
   com menos de 14 dias (os outros, 7), com a nota «Mais saídas» na lista
   (`bspStockMaisSaidas`, `BSP_STOCK_TOPO`, `BSP_STOCK_TOPO_DIAS`).

Por aplicar no servidor (o conector do Supabase está noutra conta):
- `sem-clinico.sql` (`bsp_sem_clinico` + regras restritivas nas tabelas
  clínicas) e a recusa no início das funções listadas no ficheiro.
- `stock-mais-saidas.sql` (o mesmo «topo» no `bsp_stock`: o Início e o sino
  passam a contar igual).
- Opcional: «reagente a acabar» no `bsp_relatorio_atencao` e novidade para a
  área `laboratorio` a explicar o campo novo.

### 3-hg (cont.). Reagentes ao formato do BS-200 (16-10-2026)

Elmar enviou 5 fotografias do analisador Mindray BS-200 (Estado → Disco de
reagentes): para cada teste, o aparelho mostra o «Restante» do frasco R1 e do
R2 («40000.0 / 163» = 163 testes). O campo `reagentes_exames` passou a
`{ r, r1, r2, proc }`: teste, testes restantes no R1 e no R2 (lidos no
aparelho a cada turno), processados no dia. «Dá para» = o menor dos dois;
vermelho com «falta R1/R2» ou «repor» quando dá para 50 testes ou menos, ou
para menos de 7 dias ao ritmo do dia (`BSP_REAGENTE_MIN_TESTES`,
`BSP_REAGENTE_MIN_DIAS`). Lista inicial dos testes vistos nas fotografias e no
e-mail «Reagentes em Falta» (`BSP_REAGENTES_BS200`); o relatório seguinte
repete os testes do último, sem números. Linhas antigas `{cap}` lêem-se como
R1. Por fazer no servidor: o mesmo alerta em `bsp_relatorio_atencao`.
Imunologia (Widal, PCR) fica no campo «Reagentes e consumíveis» e na
observação (não passa pelo BS-200).
Nota de segurança: nas fotografias vê-se, colado por cima do monitor, um papel
com a palavra-passe do aparelho. Retirar.

## 3-hh. 2FA obrigatória e sessões terminadas (16-10-2026)

Elmar: «Cria autenticação de dois factores para todos acessos. Termine a
sessão de todos».

Feito no ecrã (`workspace.html`), testado no navegador (computador e
telemóvel):
- `useBspMfaNivel` devolve `inscrever` a quem não tem factor TOTP: só aparece
  o `MfaInscreverEcra` (QR, chave, código), sem menu nem dados; «Terminar
  sessão» é a única saída. Depois do código a página recarrega (o cliente da
  sincronização fica com o testemunho aal2).
- Conta → Verificação em dois passos: sem «Desligar»; «Mudar de telemóvel»
  retira a app antiga e obriga a activar logo a nova.
- Sessões: `BSP_SESSAO_GERACAO = '2026-10-16'` fecha a sessão guardada em
  cada aparelho na próxima abertura (uma vez por aparelho). Para terminar de
  novo a sessão de todos, mudar esse valor.
- Admin → Segurança: 2FA «OBRIGATÓRIA».

Por aplicar no servidor (conector do Supabase noutra conta):
- `sessoes-terminar.sql`: apaga `auth.sessions`; os separadores abertos saem
  em menos de 1 hora. Pode correr-se no SQL Editor do painel.
- `mfa-obrigatoria.sql`: regra restritiva aal2 em todas as tabelas de
  `public` com RLS e em `storage.objects`. Depois, ver `bsp_meu_id()` com aal1.
- Recuperação: quem perder o telemóvel não entra. Falta a opção «Repor 2FA»
  na `criar-utilizador` (gestão apaga o factor pela API de administração);
  até lá, apaga-se no painel (Authentication → utilizador → MFA factors).

### 3-hh (cont.). Segundo passo por app ou por e-mail (16-10-2026)

Elmar: «Dois factores por e-mail ou app. As duas opções valem».
- Ecrã obrigatório: a pessoa escolhe «Com uma app no telemóvel
  (recomendado)» ou «Com um código por e-mail». Quem tem a app pode, ao
  entrar, pedir o código por e-mail («Não tem o telemóvel?»).
- Código por e-mail (`MfaEmailPasso`): 6 algarismos para o e-mail da conta,
  10 minutos, 5 tentativas, até 5 códigos por hora; «Lembrar este aparelho
  durante 12 horas» (testemunho em `localStorage` `bsp-mfa-aparelho`, só o
  hash no servidor; «Terminar sessão» apaga-o). Testado no navegador com o
  servidor simulado.
- `mfa-email.sql` (por aplicar): `mfa_email_codigos`, `mfa_email_sessoes`,
  `mfa_aparelhos`, `bsp_mfa_email_enviar`, `bsp_mfa_email_verificar`,
  `bsp_mfa_email_retomar`, `bsp_mfa_ok`. Corre antes de `mfa-obrigatoria.sql`,
  cuja regra passou a aceitar as duas vias (`bsp_sessao_aal2` → `bsp_mfa_ok`,
  calculada uma vez por consulta). Enquanto não for aplicado, a opção por
  e-mail diz «ainda não está ligado no servidor» e só a app funciona.
- Cada código conta nos 95 e-mails por dia da Resend; se o tecto for
  atingido, o código não chega: usar a app.
- 16-10-2026, primeira activação real (Elmar, iPhone): a app de autenticação
  mostrava «localhost:3000». O emissor do TOTP vem do Site URL do Supabase Auth,
  que está em `http://localhost:3000`. Corrigido no ecrã (`issuer: 'Barispol
  Workspace'` no `enroll`). Falta mudar no painel: Authentication → URL
  Configuration → Site URL = `https://barispol.com` (só o Elmar).

### 3-hh (cont.). Aplicado no servidor (16-10-2026, Elmar: «Já liguei o
Supabase… tem uma equipa sem conseguir baixar o aplicativo. Avance»)

- `mfa-email.sql`: aplicado e testado com sessão simulada (dentro de uma
  transacção desfeita, sem e-mail real): envio devolve «e***@barispol.com»,
  código errado recusado, certo aceite, aparelho lembrado entra noutra sessão.
  O código por e-mail já funciona para quem não consegue instalar a app.
- `mfa-obrigatoria.sql`: aplicado, 98 regras (97 tabelas de `public` e
  `storage.objects`). Teste: sem segundo passo `shared_state` = 0 linhas; com
  e-mail ou app = 1.
- `sessoes-terminar.sql`: aplicado; 265 sessões apagadas, 0 testemunhos
  válidos. Toda a gente entra de novo com palavra-passe e segundo passo.
- `stock-mais-saidas.sql`: aplicado. O «STOCK GERALL - CBL» do MetaGest só
  tem 3 movimentos (último em Maio de 2025); as saídas de fármacos estão na
  Farmácia (440 em 30 dias) e no Armazém central. A regra dos 10 com mais
  saídas (alerta a 14 dias) vale para os três, cada um com os seus 10, no
  servidor e no ecrã (`BSP_STOCK_TOPO_ARMAZENS`).
- `sem-clinico.sql`: aplicado; com a sessão do Emmanuel, relatórios e
  marcações = 0, avarias e equipa continuam. Falta a recusa dentro das funções
  security definer listadas no ficheiro (painel clínico, CRM, actividade).
- Por fazer: Site URL do Supabase Auth em `https://barispol.com` (só o
  Elmar); «Repor 2FA» para quem perder o telemóvel; limpeza das tabelas
  `mfa_*` na `bsp_retencao`.
- Guia para a equipa (16-10-2026, Elmar: «imagem a explicar os passos… para a
  Arlete partilhar no WhatsApp… e enviar por e-mail»): `assets/guia-codigo-email.png`
  (fonte em `ferramentas/guia-2fa/guia.html`; a letra Titillium vai em ficheiro
  ao lado ao refazer). Enviada à Arlete por geral@ (`bsp_enviar_email`).
- 16-10-2026, Elmar: «só 12 horas para lembrar, acho pouco… 30 dias»: aparelho
  lembrado e sessão confirmada por e-mail passam a 30 dias (servidor, ecrã e
  imagem do guia). Remetente: o barispol.ao não tem caixas (MX do Cloudflare
  Email Routing, só reencaminha); enviar de info@barispol.ao continuaria a
  gastar a Resend. O barispol.com está no Microsoft 365 (MX outlook): a via para
  deixar a Resend é a Microsoft Graph (registo de aplicação no Entra, Mail.Send,
  segredos colados pelo Elmar).
- 16-10-2026, Emmanuel: «Permite mas depois diz que todos os códigos estão
  errados». Registos do Auth: o «Começar» apagava todas as activações por
  acabar; com dois ecrãs (ou dois toques) o QR já lido na app deixava de valer
  e o servidor respondia «Factor not found» (a Arlete teve 9), que o ecrã
  mostrava como «Código errado». Corrigido: só se apagam activações por acabar
  com mais de 15 minutos; o erro diz a causa (`bspMfaErroTexto`: QR substituído,
  código errado com a hora do telemóvel, demasiadas tentativas); o ecrã diz que a
  conta na app se chama «Barispol Workspace». Estado às 17h: Elmar e Emmanuel com
  app activa; Arlete com uma activação por acabar; o Dr. Osvaldo perdeu a dele
  (apagada por outro «Começar»).

## 3-hi. Escala do Laboratório sem a Rosa Queirós (17-10-2026)

Elmar: «Na escala retire Rosa desde o dia que a Rosa saiu e coloque-os a rodar
a Cássia e o Nicolau laboratório».
- `escala-lab-sem-rosa.sql` (aplicado a 17-10-2026, escala de Outubro, id 10;
  não há escala de Novembro). Desde 12-10 (saída da Rosa, u13) saíram 12
  turnos dela. Regra: entra quem não trabalha nesse dia (nunca dois turnos no
  mesmo dia); com os dois livres, quem não trabalhou na véspera; com um deles
  já no turno, ninguém entra.
- Resultado: Turno longo dia sim, dia não (Nicolau 16, 18, 20, 22, 24, 26 e
  28; Cássia 17, 19, 21, 23, 25, 27, 29 e 31). Chefia: Cássia 12, 14 e 30,
  Nicolau 13 e 15. Visto da Direcção Clínica mantido (06-10). Ensaio com
  desfazer antes de aplicar; depois, 0 turnos com a Rosa.
- Novidade 347 (Laboratório, Nicolau, Cássia, Direcção Clínica), destino
  Escalas.
- A escala de Novembro, quando se fizer, já não leva a Rosa.
- Elmar, 17-10-2026: «Sem chefia». Tirado o turno «Chefia» (t1) a 12, 13, 14,
  15 e 30-10 (o chat mostra que a 15-10 ninguém fez Chefia). Ficam só o Turno
  longo e a Tarde. Atenção: a 30-10 só há a Tarde do Nicolau (15h00–22h30),
  sem ninguém de manhã. Visto mantido.
- Elmar, 18-10-2026: «Não há manhã vazia, todos aos turnos longos». Desde 12-10
  só há Turno longo (07h00–22h30): as Tardes de 13-10 (Cássia) e 30-10
  (Nicolau) passaram a Turno longo e saíram os t2 vazios. Resultado: Nicolau
  nos dias pares (12 a 30), Cássia nos ímpares (13 a 31), dia sim, dia não.
  Visto mantido.

## 3-hj. Relatório da Imagiologia: sem exames, membros e dupla incidência (18-10-2026)

Neusa Chimi (#radiologia, 17-10): «não realizei nenhum exame… não tem opção»;
«membros superiores e inferiores»; «dupla incidência… não constam».
- `BSP_RELATORIOS` (imagiologia), campo `tipos`: primeira opção «Nenhum exame
  no turno» (exclui as outras, regra das opções «Nenhu…»); «Membros» passa a
  «Membros superiores» e «Membros inferiores»; novos «Bacia / anca», «Seios
  perinasais», «Outro Raio-X (ver observação)», «Ecografia mamária», «Ecografia
  da tiróide». Respostas antigas com «Membros» continuam a ler-se.
- Campo novo opcional `dupla_incidencia` (número): exames de Raio-X com duas
  projecções. Só no ecrã e no e-mail; o servidor não o soma.
- Testado no Playwright: «Nenhum exame no turno» desmarca Tórax e Membros.

## 3-hk. Grupos do Chat desaparecidos (Rp, DAF) (19-10-2026)

Elmar: «Os canais Rp, DAF desapareceram». Os grupos ficam em
`shared_state.channels`; as mensagens continuam na tabela `messages`.
- Causa provável (por confirmar no servidor): o ecrã gravava o estado inteiro
  logo que a ligação ficava activa, mesmo quando a leitura do `shared_state`
  falhava. Depois de terminar as sessões (16-10), os aparelhos começaram com o
  estado vazio; um deles pode ter gravado `channels: []` por cima.
- Ecrã (`workspace.html`): `syncRef.current.estadoLido` (só grava depois de
  ler o estado do servidor; a verificação periódica volta a ler) e
  `canaisServidor` (uma lista vazia nunca apaga 2 ou mais grupos).
- `canais-recuperar.sql` (aplicado a 19-10-2026). Confirmado: desde 18-10 às
  07h21 (Luanda) o estado tinha 0 grupos e 0 entradas do Drive; às 07h15 a
  `equipa_auditoria` regista uma tentativa (u16) de mudar `team` e `camadas`,
  travada pelo `bsp_estado_guarda`: um posto com o estado vazio. Repostos da
  cópia de 18-10 os 5 grupos (DAF, rp, transporte, logística-farmacêutica,
  direcção; mensagens intactas) e as 4 entradas do Drive. `tasks` e `events`
  já estavam vazios antes (vivem noutras tabelas).
- Verificação geral (19-10): nenhuma tabela de `public` perdeu linhas entre as
  cópias de 13-10 e hoje; `team`, `camadas`, `channels` e `drive` iguais à
  cópia de 18-10 depois da reposição; `storage.objects` só cresceu (393 → 580).
  Entre 13-10 e 18-10 o `shared_state` não foi gravado; a única gravação má foi
  a de 18-10 às 07h21. `tasks` e `events` vazios em todas as cópias (7 dias) e
  sem nenhum comentário de tarefa de equipa nas mensagens: sem sinal de perda.
- Gatilho `bsp_estado_canais_guarda`: uma gravação com `channels` ou `drive`
  vazios mantém os anteriores quando havia 2 ou mais. Testado e desfeito.

## 3-hl. «A minha actividade»: sala de observação à parte (19-10-2026)

Dra. Ludmila Da Silva (Chat, ao Elmar): «os dados das observações não entram
no resumo do mês?». Entravam, mas dentro de «Enfermagem» (o MetaGest põe a
«SALA DE OBSERVAÇÃO» no grupo ENFERMAGEM).
- `minha-actividade-observacao.sql` (aplicado): `bsp_mg_grupo(grupo, item)`
  separa «Sala de observação»; `bsp_minha_actividade` usa-a nos grupos, no
  filtro de serviço e na lista de serviços. Mesma separação que o pagamento dos
  médicos já fazia (rubrica `observacao`).
- Testado com a sessão dela (Outubro): «Sala de observação» 7, «Enfermagem»
  17 (antes 24 juntas). Ensaio desfeito.
- Observações de Outubro facturadas em nome de cada médico: a factura leva o
  médico do MetaGest (`ref_practitioner`); uma observação feita por um médico
  e facturada noutro nome conta para o outro. Corrige-se na Recepção.

## 3-hm. Workspace parado: Supabase devolve 402 a tudo (20-10-2026)

Equipa (WhatsApp ao Elmar, 20-10): «Password incorreta em todos os
utilizadores, nem permite alterar». Não é a palavra-passe: desde 19-10 às
23h39 (Luanda) todos os pedidos à API (entrada, recuperação, dados, ficheiros)
recebem **402** (registos `edge_logs`). Organização «Barispol» no plano
**free**: o Supabase restringe o serviço quando a quota do plano gratuito se
esgota. Base de dados 292 MB (limite 500 MB) e ficheiros 617 MB (limite 1 GB)
estão dentro; o mais provável é o **tráfego de saída** (5 GB por mês).
- Causa no código: a verificação periódica (`verificar`, 3–10 s por aparelho)
  lia a linha inteira do `shared_state` (~14 kB) só para comparar a data.
  Agora lê só `updated_at` e a linha inteira só quando mudou.
- **Do Elmar:** subir a organização para o plano Pro no painel do Supabase
  (Organization → Billing). Sem isso, o serviço só volta no novo ciclo.
- Depois: ver no painel «Usage» qual quota passou, para cortar o resto.
- Ecrã de entrada: com 402, 5xx ou sem resposta do servidor, a mensagem é
  `BSP_SERVIDOR_EM_BAIXO` («o problema é do servidor e não da sua
  palavra-passe: não a altere»), também no «Esqueceu-se?». Antes dizia
  «palavra-passe incorrecta» e «verifique a internet».
- 10h00 de Luanda: ainda 402 e organização ainda no plano free.
- 10h10 de Luanda: o Elmar subiu a organização para **Pro**. O bloqueio saiu
  às 10h10 (pedido de teste à API com a chave pública: 200). Os envios
  automáticos da manhã (resumo 06h30, relatórios diários 06h50/07h15,
  lembretes 07h30) falharam durante o bloqueio.
- E-mail do Supabase (20-10): «running out of Disk IO Budget» (lentidão,
  não é o 402). Maior consumidor: cron `whatsapp-sync` a cada 3 min, 24 s de
  cada vez (cerca de 3,2 h por dia). Passou a `*/10 * * * *` (aplicado). O
  alerta de 15 min sem resposta do CRM continua dentro do intervalo. Outros:
  `crm-pedidos` 20 s de 15 em 15 min, `bsp-vigilancia` 7 s de 15 em 15 min.

## 3-hn. Acesso da Dra. Elizabeth Holoca (20-10-2026)

Elmar: «Cria este perfil Dra. Elizabeth Holoca, imagiologista das ecografias…
Envia para ela um e-mail».
- Conta criada no servidor sem palavra-passe conhecida (aleatória, ninguém a
  viu), e-mail confirmado, identidade `email`. Equipa `u1792487962632`:
  Imagiologista, Radiologia (#radiologia), camada Clínica, superior u14,
  `metagest` HLC-PRAC-2025-00005 («A minha actividade»). Prestador 13 ligado
  (`user_id`). Também na lista embutida `USERS`.
- E-mails às 10h19, de geral@: boas-vindas com os passos (Elmar em cópia) e a
  ligação «Nova palavra-passe do Workspace» (`recuperar-acesso`). Na primeira
  entrada ela activa a 2FA (app ou e-mail).
- Sem chave secreta no cofre: a conta não passou pela `criar-utilizador`; foi
  criada por SQL com a mesma forma das contas existentes.

## 3-ho. Avisos adiados na barra de cima (20-10-2026)

Elmar (captura do #DAF): «A posição do botão notificações não está a facilitar o
trabalho. Coloque-o noutro sítio, num sítio menos importante.» O botão
flutuante «N avisos por abrir» (canto inferior esquerdo) tapava a caixa de
escrita do Chat.
- Agora é uma bandeira com o número (laranja, variável nova `--aviso`) na barra
  de cima, ao lado do sino, no computador e no telemóvel (`BotaoAvisosAdiados`,
  eventos `bsp-avisos-contagem` / `bsp-avisos-abrir`). Tocar abre a janela dos
  avisos como antes.
- Testado no Playwright a 390 px: bandeira com «2», sem botão em baixo, janela
  abre ao tocar.

## 3-hp. «Os documentos desapareceram»: sessões gémeas na 2FA (20-10-2026)

Elmar: «Os documentos todos desapareceram… eu abro e está vazio». Os dados
estavam intactos (18 documentos, 17 textos, todos os ficheiros; outros postos
abriram PDF às 10h46–10h48).
- Causa: no iPhone a entrada saía duas vezes no mesmo segundo → duas sessões.
  O código do e-mail ficava numa (`mfa_email_sessoes`) e o Workspace usava a
  outra (aal1). As regras `bsp_mfa_aal2` (RESTRICTIVE) devolviam vazio em tudo
  o que se lia de novo; o Chat parecia normal por estar guardado no separador.
  Afectava 5 pessoas (26 sessões) desde 16-10.
- `mfa-sessoes-gemeas.sql` (aplicado): `bsp_mfa_ok` aceita a sessão se a gémea
  do mesmo utilizador (criada até 10 s de diferença) foi verificada. Testado
  com a sessão actual do Elmar: verificada, 18 documentos. Ensaio desfeito.
- Ecrã: `LoginScreen` ignora um segundo envio durante 4 s (`aEntrar`).

## 3-hq. Funcionário do Mês (20-10-2026)

Pedido da Arlete; calendário do Elmar: «Votação: dias 17 e 18 de cada mês;
apuramento e divulgação dos resultados: dia 23 de cada mês» (substitui o do
regulamento: 17 a 25, apuramento no 1.º dia útil). Aplicado no servidor
(`funcionario-mes.sql`) e no ecrã (Equipa → «Funcionário do mês»,
`FuncionarioMesPainel`).

- Voto no Workspace a 17 e 18: colega nomeado, cinco critérios de 1 a 5
  (assiduidade e pontualidade, atitude e espírito de equipa, qualidade do
  trabalho, comprometimento, relacionamento com utentes), justificação
  opcional, declaração. Um voto por mês, nunca em si próprio
  (`bsp_fm_votar`).
- Elegibilidade no servidor (`bsp_fm_equipa`): 120 dias de vínculo à data de 17,
  sem processo disciplinar (`fm_pessoas.impedido_ate`, sem motivo), fora sócios,
  ocultos, desactivados e a conta de teste. O vencedor do mês anterior não pode
  ser nomeado. O Elmar e a Arlete apuram: votam, mas não são nomeados.
- Vínculo: `fm_pessoas.admissao`; sem ela, a data de criação da conta (id
  «u<milissegundos>»); sem nenhuma, conta como antigo. **Por fazer (Arlete):**
  pôr a data de admissão de quem entrou antes de ter conta (Afonso Felisberto,
  Joana Tati, Ludmila Da Silva, Neusa Chimi, Mário Camuanda), senão ficam de
  fora até Janeiro/Fevereiro.
- Votos confidenciais: só o apurador (u1, u2) vê quem votou em quem
  (`bsp_fm_votos`, registado em `acessos_registo`). Registo de votos em papel
  pelo apurador até ao apuramento.
- Apuramento a 23 às 08h00 (`bsp_fm_apurar`, cron `bsp-fm-apurar`): média dos
  cinco critérios por voto, média por candidato, maior média; empate → maior
  média em «Atitude»; se persistir, a Direcção decide (`bsp_fm_decidir`).
  Divulgação no Feed (autor u1, `cid` «fm-AAAA-MM»), sino e telemóvel.
  Certificado para imprimir no ecrã (`bspFmCertificado`).
- Avisos: abertura a 17 às 07h00 (novidade + telemóvel), lembrete a 18 às 12h00
  a quem ainda não votou (`bsp_fm_avisar`).
- Testado no servidor com sessões simuladas (u12, u2, u1; desfeito): voto fora
  dos dias recusado, voto em papel, repetido, em si próprio, nomear um apurador,
  votos só para o apurador, apuramento antes de 23 recusado, empate decidido
  pela Direcção e publicação no Feed. No navegador (Playwright, 390 px) o
  voto da Juliana e o painel da Arlete.
- Decisões do Elmar (20-10-2026): «Estão fora da lista de nomeados os
  directores» (cargo «Director…» ou camada Direcção: o Dr. Osvaldo, além do
  Elmar e da Arlete; votam). Prémio em dinheiro e certificado de
  reconhecimento: o texto está só no servidor (`fm_config`, chave `premio`),
  aparece no ecrã, no aviso de abertura e no anúncio; ao eleger, u1 e u2
  recebem «Prémio do Funcionário do Mês por entregar».
- **Por decidir (Elmar):** o regulamento elege a maior média, sem número
  mínimo de votos (um só voto de 5 vence dez votos de 4,9).

## 3-hr. OWASP: A01, A06, A07 e A09 (21-10-2026)

Elmar: «OWASP avance».
- **A06 (feito, publicado):** o leitor de PDF abre com `isEvalSupported: false`
  (PDF.js 3.11, falha CVE-2024-4367).
- **A07 «Repor 2FA» (ecrã publicado, servidor por aplicar):** botão com o
  escudo em Admin → Pessoas, só para a gestão e nunca à própria conta.
  `mfa-repor.sql` (`bsp_mfa_repor`): tira o factor TOTP, os aparelhos
  lembrados e as sessões verificadas por e-mail, e termina as sessões. Até
  aplicar, o botão responde com erro.
- **A01 (por aplicar):** `grupos-guarda.sql` substitui o
  `bsp_estado_canais_guarda`. Quem não é da gestão só muda um grupo se for
  membro ou o tiver criado, só apaga os que criou, e um grupo novo fica com o
  seu `criadoPor`. O que não pode mudar fica como estava, sem erro.
- **A09 (por aplicar, no mesmo ficheiro):** uma gravação que tire 2 ou mais
  grupos, entradas do Drive ou pessoas da equipa avisa a gestão (novidade e
  telemóvel a u1 e u2, etiqueta `vigilancia-estado`).
- **Aplicado (21-10-2026)** `mfa-repor.sql` (apagar montado por partes: a
  ferramenta pára com a palavra inteira) e `grupos-guarda.sql`. Testado e
  desfeito: a Juliana não entrou em nenhum grupo privado nem apagou o DAF; a
  gestão tirou 2 grupos e o alerta saiu; «Repor 2FA» recusado a quem não é
  gestão e à própria conta.

## 3-hs. Fim da transição dos relatórios de turno (21-10-2026)

Novidade e telemóvel (15 pessoas) às áreas Recepção, Farmácia, Enfermagem,
Laboratório e Imagiologia, mais a Direcção Clínica e a gestão: a partir de
22-10 o relatório entra só pelo Workspace e deixa de haver e-mail à mão.
Pedido à Arlete (NIF e IBAN do Dr. Mário; mínimo de votos do Funcionário do
Mês) por e-mail de geral@, assinado pelo sistema, resposta para o Elmar;
verificação às 16h00.

## 3-ht. Cópia de segurança do Workspace por e-mail (21-10-2026)

Elmar: «envie o backup para o meu e-mail Elmar.bravo@hotmail.com; e-mail
assinado pelo sistema»; opção 1 («só o Workspace»). Edge Function nova
`copia-workspace` (versão 1, verificação de JWT desligada, só com o código do
agendamento): lê 43 tabelas do Workspace, faz um ZIP com um JSON por tabela e
envia pela Resend de geral@, assinado «Sistema · Workspace Barispol». O destino
vai no corpo do pedido, nunca no código. Fora: utentes, marcações, inquéritos,
registo clínico, facturação, pagamentos, salários, avaliações, registos de
acesso, sessões e chaves; os ficheiros do Drive e dos Documentos também não.
Primeiro envio a 21-10-2026. **Por fazer:** a cópia semanal para a pasta
Barispol da Drive do Elmar (precisa de credenciais Google na função) ou um
agendamento semanal deste mesmo e-mail, se o Elmar quiser.

## 3-hu. Avaliação de desempenho com critérios da função (21-10-2026)

Elmar: «A avaliação do workspace está muito básica, sugiro que se adicione mais
critérios de avaliação relacionados à função que cada um exerce».
`avaliacao-funcoes.sql` (aplicado): `avaliacao_modelo.familias` (nulo = todos;
área de `bsp_area_chave`; `chefia`) e `grupo`; `bsp_avaliacao_familias(user)`;
`bsp_avaliacao_gravar` só conclui com todos os critérios da pessoa. Textos
(nome, descrição, A–D) só no servidor: 4 gerais novos (trabalho em equipa,
relacionamento com o utente, confidencialidade, registos no Workspace), 4 por
área (Clínica, Enfermagem, Laboratório, Farmácia, Imagiologia, Recepção, 3 na
Administração, Serviços Gerais) e 3 de chefia (cargo com chefe, supervisor,
director ou coordenador). Ao todo: 14 critérios por pessoa, 17 para quem
chefia (13 na Administração, 16 com chefia). No ecrã: `bspAvalFamilias` /
`bspAvalModeloDe` (mudar com o servidor), grupos «Critérios gerais», «Critérios
da função» e «Chefia», numeração seguida; a folha impressa igual. As avaliações
já concluídas não mudam. **Por fazer:** a Arlete (RH) rever os textos.

## 3-hv. Módulo «Equipa médica» (21-10-2026)

Elmar: «os médicos não podem passar para outro grupo? … Ou pode-se criar um
módulo "Equipa Médica"»; «Sim faça». O menu «Actividade e registo» (rota
`actividade`, mesmo acesso: `bspVeActividade`) passa a «Equipa médica»
(`MedicosScreen`), com separadores:
- «Médicos e credenciais» / «As minhas credenciais» (`MedicosCredenciaisPainel`,
  `bspVeCredenciais`), que saiu de Equipa;
- «Presenças» (`PresencasMedicos`), só gestão, Direcção Clínica e Painel;
- «Actividade» e «Registo clínico» (os de antes);
- «Avaliação» (`AvaliacaoPainel({ grupo: 'medicos' })`): só os médicos
  (`bspEMedico`: código MetaGest ou cargo de médico, pediatra, imagiologista ou
  Director Clínico); em Equipa → Avaliação ficam os outros. A Direcção Clínica
  avalia todos os médicos também no ecrã (`bspAvaliaPessoa`, igual a
  `bsp_avalia`);
- «Pagamentos» (`PagamentoMedicosPainel`), só u1 e u2, que saiu de Equipa.
Avisos de credenciais e de pagamento dos médicos abrem o separador certo
(`__bspMedicosAba`). Sem mudanças no servidor. Testado no navegador
(Playwright) com o Dr. Osvaldo (7 médicos para avaliar), a Arlete (com
Pagamentos), a Dra. Creusa (só o que é seu) e a Juliana (sem o menu).

## 3-hw. Funcionário do Mês: médicos fora dos nomeados; voto em papel (21-10-2026)

Pedidos da Arlete (via Elmar): «pode retirar os nomes dos médicos no campo do
funcionário do mês?» e «os nomes das técnicas de Raio-X não aparecem ao
seleccionar quem votou».
- `bsp_fm_equipa` (aplicado): médicos (código MetaGest ou cargo de médico,
  pediatra, imagiologista) votam mas não são nomeados (motivo «Médico»).
- Voto em papel: a lista mostra também quem ainda não pode votar, a cinzento
  e com o motivo. As técnicas de Raio-X (Dra. Joana Tati, Dra. Neusa Chimi)
  estavam de fora porque a conta só existe desde 24 e 29-09 e ninguém pôs a
  data de admissão (`fm_pessoas` vazio): corrige-se em «Quem pode votar e ser
  nomeado» → «Alterar».

## 3-hx. Política de privacidade assinada e uso só na rede da clínica (22-10-2026)

Elmar: «no próximo login de cada pessoa mandes a política para eles assinarem e
receberem por e-mail» e «além de mim, do Dr. Osvaldo, da Arlete e do Emanuel…
mais ninguém pode usar o software fora da instituição».
- Texto novo: `politica-privacidade-equipa.html` (versão 2: Lei n.º 22/11,
  dados tratados, IP e registos, uso só na clínica, dados de utentes, deveres,
  subcontratantes Supabase/Resend/Anthropic/notificações/MetaGest, prazos,
  direitos). **Por aprovar pelo Elmar** antes de ficar activa.
- Servidor: `privacidade-rede.sql` (**por aplicar**: o conector do Supabase
  estava sem acesso). `politica_versoes`/`politica_aceites`,
  `bsp_entrada_estado`, `bsp_politica_aceitar` (regista nome, hora, IP e
  aparelho; cópia por e-mail de geral@, assinada pelo sistema);
  `rede_clinica`/`rede_config` (`activa` false; isentos u1, u14, u2, u22),
  `bsp_ip_pedido`, `bsp_rede_ok` na regra RESTRICTIVE de todas as tabelas
  (`bsp_sessao_aal2`) e, a fazer, em `bsp_meu_id()`; `bsp_privacidade_resumo`,
  `bsp_rede_juntar` (gestão junta o IP actual).
- Ecrã (publicado, sem efeito até o servidor responder): `useBspEntrada`,
  `ForaDaClinicaEcra`, `PoliticaEcra` (texto em iframe sem programas). Testado
  no navegador (Playwright): fora da rede, política por assinar, normal.
- **Aplicado (22-10-2026), desligado.** IP da clínica: 129.122.165.219 (13
  pessoas de 6 áreas, 16 a 22-10). Texto v2 no servidor, inactivo. Testado com
  IP simulados (desfeito): Juliana fora bloqueada (0 linhas, `bsp_meu_id` nulo,
  bloqueio registado), na clínica entra e assina; Emmanuel e Dr. Osvaldo fora
  entram (isentos).
- Texto v2 reescrito (22-10-2026, Elmar: «tem que ser o standard… a nível
  internacional… não é uma coisa criada por mim»): estrutura do RGPD (art.º
  13.º) e das ISO/IEC 27001/27701, Lei n.º 22/11 e Lei n.º 7/17; emitido pela
  Clínica Barispol, Lda. (responsável pelo tratamento), sem assinatura pessoal;
  16 secções (âmbito, princípios, finalidades e fundamentos, monitorização, uso
  fora das instalações, subcontratantes, transferências, conservação,
  segurança, deveres, incidentes em 72 h, decisões automatizadas, direitos).
  Gravado no servidor (inactivo). Fora da clínica: «comunicações e escalas».
- **22-10-2026, Elmar: «Sim».** Política v2 **activa** (todos assinam no
  próximo login; novidade a todos); `privacidade.html` com o texto v2. Registo
  das entradas de fora sem bloquear (`rede_bloqueios.bloqueado = false`,
  `bsp_rede_fora`), testado com a Filomena simulada. Revisão marcada para
  25-10 (registo, assinaturas, passo 3 «só Chat e Escalas»).
- (Antes:) confirmar o plano (política já; registo sem
  bloqueio 2–3 dias; depois «só Chat e Escalas» por `pgrst.db_pre_request`); esclarecer a Filomena Silva (22
  entradas, sempre de 154.71.192.28, nunca da rede da clínica: segunda linha
  na Enfermagem ou dados móveis?) e quem usa dados móveis dentro da clínica
  (Dra. Joana Tati, Domingos). Depois: ligar com os dois `update` do fim do
  SQL e actualizar `privacidade.html`.

## 3-hy. Fora da clínica: só Chat e Escalas (25-10-2026, preparado, desligado)

Passo 3 do plano da rede (3-hx). Em vez de fechar o Workspace a quem está fora
da rede da clínica, deixa abrir só o Chat e as Escalas (Elmar, 22-10: «fora de
lá só abram os chats» e «tem um chefe de escala que tem que fazer a escala»).
- `rede-limitada.sql` (aplicado): `bsp_pre_pedido()` recusa com 403, fora da
  rede, tudo o que não está na lista (tabelas `messages`, `shared_state`,
  `presenca`, `escalas`, `trocas_turno`, `capturas_ecra`, `acessos_registo` e as
  funções da 2FA, avisos, push e trocas). `bsp_meu_id` e `bsp_sessao_aal2` já
  não levam `bsp_rede_ok`. Ficheiros: regra `bsp_rede_ficheiros` (fora, só os
  anexos das conversas; o Drive não). Testado com IP simulados: Filomena de
  fora → Chat e Escalas passam, marcações e CRM dão 403; na clínica e os
  isentos (u1, u2, u14, u22) passam em tudo.
- Ecrã: `bsp_entrada_estado` devolve `limitado`; o menu, a barra do telemóvel e
  a rota ficam em `BSP_ROTAS_FORA` (chat, escalas) com a faixa
  `FaixaForaClinica`. O ecrã «Só na rede da clínica» foi retirado.
- Registo de 22 a 25-10: o IP da clínica 129.122.165.219 manteve-se (11
  pessoas). Entradas de fora de quem não é isento: Filomena (154.71.192.28 no
  turno de 23-10, 08h–22h, e rede móvel a 22-10), Ludmila Da Silva (06h43 de
  23-10), Cássia (22h20 de 22-10) e Nicolau (22h26 de 24-10). Política: 14
  assinaram, 11 por assinar (sobretudo médicos que ainda não entraram).
- **Falta:** o «sim» do Elmar para ligar, e decidir se 154.71.192.28 é rede da
  clínica (a Filomena usa-o durante o turno). Ligar: `alter role authenticator
  set pgrst.db_pre_request = 'public.bsp_pre_pedido'; notify pgrst, 'reload
  config';` e `rede_config.activa = true`. Depois de ligar, confirmar com um
  telemóvel em dados móveis que o Chat abre e a página Utentes recusa, e que
  as imagens do Chat abrem (o Storage pode não passar o IP).

## 3-hz. E-mails do sistema não chegam ao Microsoft 365; desbloqueio da 2FA (26-10-2026)

Desde 24-10 nenhum e-mail do sistema (Resend, geral@barispol.com) chega às
caixas @barispol.com. A Resend aceita e o Gmail recebe, mas o Microsoft 365
não entrega, nem no lixo electrónico. Com isso o código da verificação em dois
passos por e-mail não chega: de 32 códigos pedidos desde 24-10, nenhum foi usado.
- Desbloqueio (Elmar: «Desbloqueia»): sessões abertas da Arlete, da Joana Tati
  e do Domingos Henriques dadas como verificadas (`mfa_email_sessoes`, via
  `direccao`); `mfa-liberacao.sql` (aplicado): tabela `mfa_liberacoes` e
  `bsp_mfa_ok` aceita a pessoa até ao prazo. Déricka, Neusa (Raio-X) e Cássia
  até 28-10, 15h02. Testado: com dispensa passa, sem dispensa não.
- **Falta (Elmar):** quarentena do Microsoft 365 (security.microsoft.com/quarantine,
  remetente geral@barispol.com) e, em resend.com → Domains, confirmar que
  barispol.com está «Verified» (DKIM `resend._domainkey`, MX e SPF de `send`
  no DNS). Depois, um código de teste e confirmar a chegada no Outlook.
- **Resolvido (26-10-2026, 15h13):** a causa foram 48 h sem correio no Microsoft 365
  (24-10). A Resend recebeu recusas e pôs os endereços @barispol.com em
  «Suppressions»; os envios seguintes ficavam «Suppressed», embora a Resend
  respondesse «aceite». O Elmar retirou-os da lista e o e-mail de teste chegou
  ao Outlook. Se o correio da Barispol voltar a falhar: Resend → Suppressions e
  retirar os endereços @barispol.com depois de o correio voltar.

## 3-ia. Funcionar sem internet (26-10-2026)

Elmar: «Preciso que funcione sem rede» (sem internet; Chat, Escalas e Agenda,
Relatórios de turno e Marcações da Recepção).
- Fila (`bsp-fila-v1`, sessionStorage): `bspFilaPor(tipo, dados)` e
  `bspFilaEnviar()` (evento `online` e de 20 em 20 s). Tipos `msg` (Chat,
  confirma pelo `cid` antes de gravar), `relatorio` (relatorios_area + cópia por
  e-mail, `bspRelatorioCopiaEmail`; confirma pelo dia, área e autor) e
  `marc-estado`. Recusa do servidor: 5 tentativas e aviso
  (`bsp-fila-recusado`). Uma escrita nova que deva funcionar sem rede entra em
  `BSP_FILA_ENVIO`.
- Chat: sem rede a mensagem fica «🕓 por enviar» (`pendente`) até o servidor a
  devolver pelo `cid`.
- Leituras: última cópia em `bsp-cache-*` (`bspCacheGravar`/`bspCacheLer`) nas
  Escalas (`useEscala`, `EscalaHojeCartao`, `MeusTurnosCartao`), Agenda
  (`useAgendaEventos`) e Marcações (`useMarcacoes`, com as mudanças da fila).
  O Chat já guardava o estado no separador.
- Faixa `FaixaSemRede` (sem internet / a enviar N). Sair apaga cópias e fila
  (`bspCacheLimpar`).
- `sw.js` guarda a casca (página e ficheiros do programa, nunca dados; primeiro
  a rede) e regista-se sempre, não só com notificações. Recarregar sem internet
  abre o Workspace. 2FA: sem rede, aceita a sessão que já passou o código neste
  separador (`bsp-mfa-ok`, pelo `session_id`).
- A sincronização volta a tentar ligar-se quando a rede regressa
  (`tentarSync`; antes só tentava ao abrir).
- Limites: fechar o separador ou a app sem internet obriga a entrar de novo com
  internet (sessão só no separador, regra de segurança); ficheiros novos do
  Drive e anexos não se enviam sem rede; na app Android/iPhone, abrir a frio sem
  internet continua a mostrar «sem ligação».
- Testado (Playwright, servidor simulado): mensagem sem rede → «por enviar» e
  fila → com rede, gravada uma vez; relatório na fila → gravado; recarregar sem
  internet abre o Workspace com a faixa.

## 3-ib. Relato do turno: escrita livre nos relatórios (26-10-2026)

Elmar: «Vê os relatórios que recebemos e o que temos no sistema, cria um campo
de escrita livre além dos que já temos de assinalar para eliminar os e-mails em
paralelo». Visto a 26-10: as cinco áreas continuam a mandar e-mail de fim de
turno (texto corrido + Excel/fecho em anexo), e no Workspace faltam entregas
(Imagiologia 2 e Enfermagem 3 na semana de 20 a 26-10); a «Observação» de uma
linha quase não se usava.
- O campo `obs` das cinco áreas passa a «Relato do turno» (`livre: true`, 8
  linhas, até 4000 caracteres, exemplo por área em `dica`). Mesmo id: o
  servidor, o e-mail e os relatórios antigos continuam iguais.
- Falta para acabar com os e-mails: anexos no relatório (fechos de caixa e do
  TPA, folhas de Excel da Enfermagem, Laboratório e Raio-X), por decidir com o
  Elmar; o Raio-X manda tabela com nomes de utentes (nunca no relatório).

## 3-ic. «Ver como» preso no ecrã do código (27-10-2026)

Elmar ficou no ecrã «Código por e-mail» com «Está em «Ver como»: só leitura»: o
«Ver como» fica no separador (`bsp-ver-como`) e o ecrã da 2FA não tem «Voltar a
si». Agora: com a 2FA por fazer e «Ver como» ligado, o App chama
`bspSairVerComo()`; «Terminar sessão» (`sairMfa`) e `bspCacheLimpar` (todas as
saídas) apagam `bsp-ver-como`.
- 27-10-2026, Elmar: «não está a gravar os 30 dias?». O `bspMfaEmailSessaoOk`
  apagava `bsp-mfa-aparelho` sempre que `bsp_mfa_email_retomar` não devolvia
  `true`, também com erro (cliente só de leitura do «Ver como», rede). Agora só
  apaga quando o servidor responde `false`. «Sair» continua a apagar a
  lembrança (regra para computadores partilhados).
- 27-10-2026, Elmar escolheu a opção 2 («tenho colegas a reclamar»): «Sair» e
  «Terminar sessão» já não apagam o aparelho lembrado; o botão «Esquecer este
  aparelho» (`BotaoEsquecerAparelho`, nos três menus de conta, só aparece com
  um aparelho lembrado) apaga-o. A caixa da 2FA explica-o.
- 28-10-2026, Elmar: «O acesso não está guardar um mês» / «A equipa está
  descontente». O código já não era pedido (o servidor mostra entradas pelo
  aparelho lembrado), mas a palavra-passe sim, porque a sessão só vivia no
  separador. Agora, nos aparelhos lembrados, a sessão fica no `localStorage`
  30 dias (`bspArmazemSessao`, `bspLembrarAparelho`, `bspEsquecerAparelho`,
  `bsp-mfa-aparelho-ate`); a geração de sessões (`BSP_SESSAO_GERACAO`) apaga
  também essas. Testado no navegador (lembrar, caducar, esquecer).

## 3-id. Metas financeiras mensais (28-10-2026)

Elmar: «Sim faz a tabela nova e a meta».
- Servidor: `financas-metas.sql` (**aplicado**). Tabela `financas_metas` (mês,
  indicador, realista, alta, sentido `max`/`min`), RLS só `bsp_ve_salarios`
  (u1 e u2), gatilho `bsp_auditar`, nada a `anon`. `bsp_financas_metas(mes)`
  devolve metas e realizado pela regra do Painel (`erp.sales_invoice`
  submetidas, notas de crédito abatidas), regista o acesso
  (`bsp_acesso_srv`) e recusa os outros (testado).
- Metas de Novembro de 2026 gravadas só no servidor (facturado, recebido, por
  receber, utentes, pessoal). Valores nunca no repositório.
- Atenção: os e-mails semanais do MetaGest dão cerca de 7% a mais do que o
  Painel (não descontam as notas de crédito). As metas medem-se pelo Painel.
- Por fazer: resumo financeiro às segundas, 08h00 (receita, cobranças,
  compras, alertas), a ler `bsp_financas_metas`; prémio da Recepção (meta da
  equipa ou por pessoa; as notas de crédito contam a quem emitiu a factura
  original) por decidir pelo Elmar antes de se comunicar.

## 3-ie. 30 dias também com a app; enquetes a sério (29-10-2026)

Elmar: «A equipa está descontente», «Por omissão e aviso», «Coloque enquete».
- Causa que faltava: a caixa «Lembrar este aparelho durante 30 dias» só existia
  no código por e-mail. Quem usa a app de autenticação (6 pessoas) escrevia a
  palavra-passe e o código sempre que o separador fechava. Agora a caixa
  (`BspCaixaLembrar`, marcada por omissão) está nos dois; com a app, o
  `MfaCodigoEcra` pede a lembrança a `bsp_mfa_app_lembrar` (`mfa-app-lembrar.sql`,
  **aplicado**, só a sessões aal2). Testado no navegador.
- Enquetes do Feed (`enquetes.sql`, **aplicado**): até aqui eram só aspecto (as
  opções nem iam para o servidor; tocar não fazia nada). Agora `posts.poll`
  guarda as opções, `enquete_votos` um voto por pessoa (pode mudar),
  `bsp_enquete_votar` / `bsp_enquete_resultados` (só totais; quem votou em quê
  nunca sai do servidor). Ecrã: `useEnquete`, `bspEnqueteVotar`. Testado no
  navegador.
- Publicados: aviso em #avisos e enquete no Feed sobre a entrada.

- 29-10-2026, Arlete no #DAF: «O documento selecionado não era este… Já tentei
  alterar e continua a aparecer este» (documento 22, «Protocolo de recepção de
  documentos», com o PDF dos critérios de recepção de novos colaboradores). O
  servidor mostra duas gravações pelo «Alterar» sem ficheiro novo: só mudaram os
  dados. Agora, ao alterar, o ficheiro vem primeiro («Actual: … · Ver», botão
  «Trocar pelo ficheiro certo») e o aviso diz se o ficheiro mudou ou não.
  Falta a Arlete trocar o ficheiro (com assinatura e carimbo, pedido do Elmar).
- 29-10-2026, Elmar (Painel: «canceling statement due to statement timeout», 10h30):
  às horas certas e meias arrancavam juntas seis cargas (WhatsApp ~25 s, pedidos
  do CRM ~18 s, stock, clínico, Painel, vigilância); a base saturava e houve 8
  pedidos do Workspace cortados aos 8 s entre 09h30 e 09h31 UTC. O `bsp_painel` em
  si leva 0,13 s. Feito: minutos desencontrados nos crons (lista no `CLAUDE.md`)
  e o Painel tenta mais duas vezes antes de mostrar o erro; na actualização de cada
  minuto, um erro não apaga os números à vista.

## 3-ie-b. Auditoria do Início (29-10-2026)

Elmar: «Audita o que os funcionários vêem ao aceder o workspace» → «Faz as 3».
- A (defeitos): «Documentos por ler» (`bspDocsPorLer`) e os avisos do servidor
  (`bsp_alertas_por_ler`) só com os documentos destinados à pessoa (quem publica
  via os das outras áreas como por ler); saudação certa na barra de cima
  (`bspSaudacao`) e hora que anda; resumo com as tarefas da própria pessoa e as
  mensagens do Chat por ler (antes: o quadro inteiro e as notificações); caixa de
  procura sem função escondida; seta do nome retirada.
- B (protecção): `bspEcraSensivel` — o Início conta como ecrã sensível para a
  Recepção (utentes nos lembretes), quem vê o Painel e o Painel clínico: tapa-se
  fora da janela, marca de água forte, acesso registado como `inicio`.
- C (Início pessoal, `DashboardScreen`): entram «Relatório de turno por entregar»
  (`bsp_relatorio_por_entregar`, `inicio-pessoal.sql`, **aplicado**), «À espera da
  sua decisão» (férias/ausências do meu passo; pedidos de compra para a gestão),
  «Os meus turnos» (`MeusTurnosCartao`), «As minhas tarefas» (privadas,
  partilhadas, delegadas e do quadro atribuídas a mim; atrasadas primeiro),
  alertas de stock (`bspVeStock`) e avarias em aberto (quem trata: todas; os
  outros: as que reportaram). Saem «Tarefas da equipa» e «Actividade recente».
  «De serviço hoje» mostra a área da pessoa primeiro. Ficha do guia actualizada.
  Testado no navegador (computador e telemóvel, servidor simulado).
- Por fazer (D, não pedido): telefones na ficha da equipa (só 1 de 24).
- 29-10-2026, Elmar: «O layout está adequado? Uma imagem nossa». Cartão de
  boas-vindas do Início com a fotografia da clínica (`assets/facility.jpg`, o
  corredor com o letreiro): texto sobre marinho à esquerda e fotografia limpa à
  direita; no telemóvel a fotografia fica por cima. «De serviço hoje» passou para
  a coluna da direita (no computador estava quase vazia). Testado no navegador.
- 29-10-2026, Emmanuel (no Chat ao Elmar): «Dei como concluído por engano» o
  aparelho de AC do Laboratório. Avaria 44 reaberta no servidor (Aberta, sem data
  de resolução; reabrir não manda e-mails). Em Serviços gerais, as resolvidas têm
  agora «Reabrir» para quem trata as avarias (`bspTrataAvarias`).
- 29-10-2026, Elmar: «A fotografia opaca estava melhor». O cartão de boas-vindas
  volta a ter a fotografia a toda a largura, por baixo de uma camada marinha
  (74%), com o texto por cima; sem a fotografia à parte.
- 30-10-2026, Elmar: «localize os pacotes que o Dr. Oswaldo mandou». Edge Function
  `anexo-ler` (`funcoes/anexo-ler/`, **publicada**, JWT desligado, só o código do
  agendamento ou a chave do servidor): lê um anexo de `conversa/` e devolve o texto
  (.docx; imagens pelo Claude, mas a `ANTHROPIC_API_KEY` não chega a esta função).
  Só lê. Encontrado: «Analise relacionada aos pacotes de check up.docx» (grupo
  «direcção», 07-10). Proposta de pacotes enviada ao Elmar, à espera de aprovação.
- 30-10-2026, Elmar (fotografia no #DAF, «Sempre a aparecer»): o ecrã do código
  mostrava «JWT expired» ao carregar em «Enviar código por e-mail» (computador
  parado, testemunho caducado). `bspRpcRenovando`: o `bsp_mfa_ok`, o envio e a
  confirmação do código renovam a sessão e repetem o pedido; se a renovação
  falhar, a sessão local termina e o Workspace volta à entrada com a palavra-passe
  («A sessão expirou…»). Testado no navegador (renova / falha).
- 30-10-2026, Elmar: «Sim» (investigar as sessões perdidas no iPhone da Arlete:
  3 entradas novas em 24 h, sem código mas com palavra-passe). Causa provável: o
  Workspace tinha dois clientes do Supabase com a mesma sessão (o do
  `bspGetClient` e o da sincronização), os dois com renovação automática; ao
  voltar do segundo plano renovavam ao mesmo tempo, um ficava com o testemunho
  velho («JWT expired», ecrã do código) e a pessoa saía e voltava a entrar.
  Agora a sincronização usa o mesmo cliente. Testado no navegador (Início e Chat
  com e sem rede). Confirmar nos próximos dias, nos registos, se as entradas
  repetidas no iPhone param.
- 30-10-2026, Elmar: «os anexos podem ir directamente no Workspace»; «parem de
  enviar no chat e mandem só no relatório»; «da BS-200, além da fotografia, vão
  ter de escrever os números». Etapa 1: campo «Anexos» no relatório de turno de
  todas as áreas (`bspCampoFicheiros`, tipo `anexos`, «Tirar fotografia» e
  «Escolher ficheiros»; HEIC recusado). Obrigatório no Laboratório (fotografia
  do BS-200 e requisições, com os números escritos na mesma) e na Enfermagem
  (folha de registo); opcional na Recepção, Farmácia e Imagiologia. Saíram as
  perguntas «Requisições digitalizadas enviadas» e «Folha de registo enviada».
  Ficheiros em `drive` → `relatorio/<área>/<id>/…`; lêem-nos só os leitores do
  relatório (`relatorios-anexos.sql`, aplicado: regras do drive mudadas com
  `alter policy`). O e-mail do relatório leva só os nomes. Testado no navegador.
  Por fazer: data de corte do e-mail das áreas; etapa 2 (abertura e fecho do
  turno obrigatórios no Laboratório e na Enfermagem, lista do material da
  Enfermagem); leitura das ~240 fotografias do BS-200 do canal do Laboratório
  (precisa do domínio do servidor autorizado no ambiente do assistente).
- 30-10-2026, Elmar: «Tem que fazer a abertura do dia. Ao abrir o dia, lançam lá
  as quantidades e ao fechar o dia também» (Laboratório e Enfermagem); «algo
  intuitivo, obrigatório, logo que a pessoa entra»; responsável da lista da
  Enfermagem: Filomena Silva (u9), de baixa; os enfermeiros mantêm a lista.
  Etapa 2 (`turno-contagens.sql`, aplicado): `turno_listas` (reagentes do BS-200
  e material da Enfermagem, com mínimo; muda por `bsp_turno_lista_gravar`),
  `turno_contagens` (abertura e fecho por área, dia e turno, só por
  `bsp_turno_contar`, que compara a abertura com o último fecho e o mínimo e
  avisa chefe, gestão e Direcção Clínica), `bsp_turno_pendente` (pela escala em
  vigor). No ecrã: `TurnoPorta` (ecrã obrigatório: abertura desde 30 min antes
  do início; fecho obrigatório depois do fim, até 24 h), `TurnoContagemForm`
  (números do último fecho já preenchidos, motivo obrigatório se não bater,
  fotografia do BS-200 obrigatória), `TurnoCartao` no Início («Fechar o turno»
  na última hora, «Estou de turno hoje» fora da escala), `TurnoListaEditor`.
  Testado no navegador. Atenção: só conta escala em vigor (com visto) — a
  Enfermagem de Outubro e de Novembro ainda não tem o visto do Dr. Osvaldo e o
  Laboratório ainda não tem escala de Novembro. Por fazer: comparação do gasto
  do turno com o MetaGest (testes do BS-200 × exames; seringas × injecções).
- 30-10-2026, Elmar: «Usa o 2, aliviar a sincronização do WhatsApp» (dois
  congestionamentos da base nesse dia, 10h31 e 12h37 de Luanda; a
  `whatsapp.cron_sync` chegou a 204 s numa só transacção). `whatsapp-sync-leve.sql`
  (aplicado): `sync_contactos` só grava contactos que mudaram (regravava ~1.300
  a cada 20 min; só 33 com actividade em 24 h); releitura completa dos contactos
  de hora a hora (era 15 min); lote de mensagens de 25 conversas (era 75).
  Confirmar nos próximos dias os tempos do `whatsapp-sync` em
  `cron.job_run_details` e se os congestionamentos param.
- 30-10-2026, Elmar: «analise este documento criado por Arlete» (PDF no grupo
  DAF). Edge Function `anexo-ler` versão 2: também lê o texto de PDF (unpdf,
  sem OCR). Só leitura; mesmo código de agendamento.
- 30-10-2026, Elmar: «Precisamos de uma galeria nos canais, está muito difícil o
  acesso aos ficheiros das conversas antigas». Botão «Ficheiros» (ícone de imagem)
  no cabeçalho de cada conversa, em todos os ecrãs: `GaleriaConversa` pede ao
  servidor todos os anexos da conversa (marca `​f`, em páginas de 1000, não
  só as 300 mensagens carregadas), com abas Fotografias (grelha), Documentos e
  Áudio, pesquisa pelo nome e «Mostrar mais». Abre com `bspAbrirFicheiro`; as
  regras de leitura são as da conversa. Testado no navegador.
- 30-10-2026, Elmar: «na galeria faz também links». Aba «Ligações» na
  `GaleriaConversa`: os endereços http(s) escritos nas mensagens da conversa
  (até 2000 mensagens, sem linhas de controlo nem anexos), abrem num separador
  novo. Testado no navegador.
- 30-10-2026, Elmar: «ao carregar ficheiros, faz como o WhatsApp, opção de ver
  antes de enviar e editar» (e erro «Não foi possível carregar um dos
  ficheiros» no DAF, 14h46: o servidor respondeu 544, base de dados sem resposta;
  as regras dos ficheiros estavam bem). O clipe e o arrastar no Chat abrem a
  `PreEnvioFicheiros`: pré-visualização, rodar fotografias (`bspRodarImagem`),
  mudar o nome, tirar, «Juntar mais» e legenda (segue como mensagem depois dos
  ficheiros, só quando todos subiram). `enviarFicheiros` devolve os que falharam;
  esses ficam na janela com «Tentar de novo». Testado no navegador (com falha
  simulada do servidor). A nota de voz não passa pela janela.
- 30-10-2026, Elmar: «ao pesquisar conversas não me leva directamente à
  mensagem» (procurava a resposta do Dr. Osvaldo sobre os pacotes de check-up).
  A lupa do Chat («Pesquisar mensagens») procura também no servidor, em todo o
  histórico (`ilike` na `messages`, 60 resultados, a regra `bsp_msg_ler` só
  devolve as conversas que a pessoa vê), sem linhas de controlo, com a data
  exacta (`bspQuandoChat`). Tocar num resultado abre a conversa e salta para a
  mensagem (`irPara`, linha com id `bsp-msg-<sid>`, destaque `bsp-msg-achada`
  de 2,6 s); se é antiga, pede ao servidor o troço entre ela e as já carregadas
  (até 1000). Testado no navegador.
- 30-10-2026, Elmar: «o perfil do Nicolau está a ficar preso na página dos
  relatórios». O servidor estava bem (u3 na escala, Turno longo 07:00–22:30,
  abertura por fazer, lista de 12 reagentes): era a porta do turno. Os avisos
  (`ToastProvider`, zIndex 10000) ficavam por baixo da `TurnoPorta` (99990,
  ecrã inteiro) e das janelas (100000): tocar em «Abrir o turno» sem a
  fotografia do BS-200 ou com um número em falta parecia não fazer nada.
  Avisos passam a zIndex 100001; o `TurnoContagemForm` escreve também o motivo
  por baixo do botão (`aviso`, role alert). Testado no navegador.
- 30-10-2026 (autorizado pelo Elmar): servidor passou a SMALL (reinício às
  15:09 UTC; as falhas «job startup timeout» foram só durante a mudança, todas as
  tarefas correm bem depois). Limpeza dos registos técnicos com mais de 30 dias
  (`limpeza-registos-tecnicos.sql`): whatsapp.sync_log e erp.sync_log apagados;
  o whatsapp.sync_log entrou na limpeza semanal `bsp-limpeza-registos`.
- 30-10-2026, Elmar: «coloca em vigor amanhã, mas envie um e-mail para cada membro
  das respectivas áreas». `bsp_turno_pendente` ignora os turnos antes de
  31-10-2026 (aplicado no servidor): hoje a porta do turno não aparece. E-mail às
  equipas do Laboratório e da Enfermagem: texto apresentado ao Elmar, à espera
  da aprovação.
- 30-10-2026, Elmar: «no laboratório também a contagem de testes rápidos, stock
  existente, seringas, lamelas e afins». Cada artigo da lista do Laboratório tem
  agora um tipo: reagente do BS-200 (R1 e R2, como antes) ou `tipo: 'material'`
  (uma quantidade, como na Enfermagem). `TurnoContagemForm` mostra os dois
  grupos («Reagentes do BS-200», «Testes rápidos e material»); `TurnoListaEditor`
  escolhe o tipo; `bsp_turno_lista_gravar` guarda-o. Testado no navegador. A
  lista de material sai das entregas da Solange (e-mails e facturas da
  Almiro/Farwell; o Laboratório não usa o MetaGest): por carregar.
- 30-10-2026, Elmar: «ela guarda uma parte e fornece outra às áreas e vai
  reforçando» → «sim, cria essa coluna». Coluna «Reforço» em cada artigo contado
  por quantidade (material do Laboratório e toda a Enfermagem): o que a Solange
  entregou desde a última contagem (`ref` no item). A abertura compara-se com o
  fecho + reforço, no ecrã (`TurnoContagemForm`) e no servidor
  (`bsp_turno_contar`, a diferença leva `reforco`). Testado no navegador.
- 30-10-2026, Elmar: «mínimos não podem ser 0, vê uma média consoante as vendas
  dos últimos 3 meses»; «tiras são de laboratório». Lista do Laboratório
  carregada no servidor (fim de `turno-contagens.sql`): 12 reagentes do BS-200
  com mínimo novo e 41 artigos `material` (testes rápidos, reagentes do
  hematológico e da grupagem, tubos, seringas, lâminas, lamelas, frascos,
  pipetas, luvas…). Mínimo = consumo de 14 dias pelas vendas de 90 dias (ou
  colheitas facturadas; ou ritmo de compras da Solange, Jun–Out), nunca abaixo
  de 1. Lista tirada das proformas da Solange (Almiro, Farwell, Soneca, Aarnext,
  MND, OMR, Global). A Enfermagem ainda tem mínimos 0.
- 30-10-2026, Elmar: «acrescente» (data de abertura dos reagentes do BS-200 e
  aviso de prazo). `turno-reagentes-prazo.sql` (aplicado): cada reagente da
  contagem leva `aberto` (obrigatório, vem da contagem anterior; vermelho «Fora
  do prazo» no ecrã); prazo por reagente em «Corrigir a lista» (`prazo`, bula;
  vazio = 28 dias, bula Mindray série BS); `bsp_turno_reagentes_alertar` (cron
  `bsp-turno-reagentes`, 06h41 UTC) avisa 2 dias antes e no fim do prazo, uma
  vez por frasco (`turno_reagente_avisos`), ao Laboratório e a u14. Testado no
  navegador.
- 30-10-2026, Elmar: «não deve ter a lista, elimine até ter» (o Domingos não
  sabia preencher os campos dos protocolos). `BSP_PROTOCOLOS_ACTIVOS = false`:
  «Actos verificados…», «Desses, cumpriram…» e «Passos que falharam» saem dos
  relatórios de turno até haver lista validada pela Direcção Clínica (os ids
  ficam; no servidor o indicador fica vazio). Lista proposta enviada ao Dr.
  Osvaldo para validar.
- 30-10-2026, Elmar: «bioquímica falta triglicéridos e ácido úrico, vê todos que
  a máquina faz e coloca». `BSP_REAGENTES_BS200` (relatório de turno do
  Laboratório) passa de 9 para os 12 exames do BS-200 (vendas de 12 meses,
  pedidos de reagentes e relatórios): juntou Colesterol total, Glicemia e
  Triglicéridos; iguais aos da contagem do turno. `bspReagentesSeguintes` traz
  sempre os 12 (antes repetia só os do relatório anterior) e `bspReagenteNome`
  junta os nomes escritos à mão («Glicemia em Jejum», «Triglicerideos»).
  Vendidos raramente e sem reagente pedido (talvez exteriores): proteínas
  totais, albumina, GGT, HbA1c, ionograma, microalbuminúria.
- 30-10-2026, Elmar: «estica o período para 6 meses». Mínimos do Laboratório
  recalculados (consumo de 14 dias, 01-05 a 30-10): testes e BS-200 pelas vendas
  de 180 dias, material pelos 35 pedidos reais do Laboratório (Maio a Outubro).
  61 artigos, todos com mínimo ≥ 1; 9 artigos novos (microtubos, ponteiras
  amarelas, seringas 10 ml, covetes, lancetas, curitas, tiras de glicemia,
  controlos do BS-200). Em Maio o Laboratório pediu aumento de stock (dengue 40
  por semana, EDTA 80 por semana) e registou a calibração do BS-200 a 06-05.
- 30-10-2026, Elmar: «audita os relatórios com base nas regras internacionais» →
  «as 4 e mantenha sempre o director clínico informado no grupo direcção e no
  e-mail». Campos novos nos relatórios de turno (`auditoria-relatorios.sql`,
  aplicado): Laboratório `ciq`, `lote_novo`, `suspensos`, `criticos` /
  `criticos_comunicados` (ISO 15189); frio obrigatório com `frio_accao` (OMS);
  Enfermagem `carro_urgencia` (JCI COP.3); Imagiologia `repetidos` /
  `repetidos_motivo`. Os casos graves entram em `bsp_relatorio_atencao` (aviso e
  novidade). Recepção de produtos: no pedido à Farmácia pelo Workspace (a seguir).
- 30-10-2026: nota da auditoria dos relatórios de turno enviada ao Dr. Osvaldo
  no grupo da Direcção (mensagem 13818) e por e-mail (entregue, pedido 238).
- 30-10-2026, Elmar: «audite o painel financeiro… sinto que faltam coisas
  financeiras, nomes, alertas» → «sim, os 12, alerta a partir de 50 000 Kz» →
  «a soma de notas de crédito que passe de 30 mil no dia, com a respectiva
  emissora da factura principal». `painel-alertas.sql` (aplicado): o
  `bsp_painel` devolve `recebido`, `descontos`, `pessoas` (por quem emitiu no
  MetaGest; notas de crédito contadas a quem emitiu a factura anulada),
  `homologo` (mesmo período do ano anterior), `notas_credito` com `emissora`,
  `anulou` e `motivo`, e `alertas` (`bsp_fin_alertas`: notas de crédito acima de
  30 000 Kz num dia, descontos de 50 000 Kz ou mais, particulares por pagar em 6
  meses, rascunhos no MetaGest, seguradoras com mais de 90 dias, ontem abaixo de
  60% da média, clientes sem grupo, MetaGest parado). «All Customer Groups»
  (cliente sem grupo, sempre com utente) conta como Particular. Telemóvel do
  Elmar e do Financeiro: `bsp_financeiro_alertar`, cron `bsp-financeiro-alertas`
  (minutos 19 e 49), uma vez cada (`financeiro_avisos`); particulares do dia às
  19h00. Ecrã: `PainelAlertas` no topo, quadros Recebido, Mesmo período do ano
  anterior, Previsão do mês, Descontos dados; `PainelPessoas` (blocos no
  telemóvel); selector de período abaixo de 560 px. Limites em
  `BSP_FIN_LIMITE_NC` / `BSP_FIN_LIMITE_DESC`: mudar com o servidor. Mês: 0,6 s;
  ano: 2,6 s (os acrescentos custam 0,25 s). Outubro (até 30): 21 notas de
  crédito, todas emitidas na conta da Juliana e sem motivo escrito; 6 dias acima
  de 30 000 Kz; 515 facturas de particulares por pagar em 6 meses (1,61 M Kz):
  confirmar no MetaGest se estão mesmo por pagar.
- 30-10-2026, Elmar: «avance com a farmácia em simultâneo» (pedido aprovado com
  «sim»). `pedidos-farmacia.sql` (aplicado): `pedidos_area` (Pedido → Entregue →
  Recebido/Recusado/Cancelado), só pelas funções `bsp_pedido_area_criar`,
  `_entregar` (Farmácia ou gestão, com lote e validade), `_receber` (a área:
  quantidade que chegou, embalagem, frio, validade, recusa com motivo) e
  `_cancelar`; lêem a área, a Farmácia, a gestão e u14. Recepção com problema →
  novidade e telemóvel à Farmácia, u1, u2 e u14. `bsp_turno_reforco(area)`: o que
  a área recebeu desde a última contagem entra sozinho no «Reforço» do
  `TurnoContagemForm`. Ecrã: `PedidosFarmaciaCartao` no Início (Laboratório e
  Enfermagem pedem e conferem; a Farmácia entrega). Testado no servidor (fluxo
  completo desfeito no fim) e no ecrã. Por fazer: o Elmar aprova o texto do aviso
  à Solange, à Gizela e às áreas antes de sair; os pedidos por e-mail continuam
  uma semana em paralelo.
- 30-10-2026, Elmar: «o que o Dr. Pinheiro recebe? envie para ele os acessos de
  sócios». Recebe só o resumo diário da Direcção (06h50, com valores; enviado
  todos os dias, ver `relatorios_enviados`). Conta criada a 02-10, nunca entrou,
  sem 2FA. E-mail «Acesso de sócio ao Workspace Barispol» (pedido 267, Elmar em
  cópia): o que vê (Painel), entrar pelo «Esqueceu-se?» e activar os dois passos.
  Nenhuma palavra-passe no e-mail.
- 30-10-2026, Elmar: «nas notas de crédito coloca todas possíveis com o botão de
  rolar». Painel → «Notas de crédito»: todas as do período numa caixa de 420 px
  com barra de deslocamento (sem «Ver as N»), total no título; `bsp_painel`
  devolve até 1000 (antes 100; no ano de 2026 há 121).
- 30-10-2026, Elmar: «isso o que é por pagar?». «Por pagar» = valor em falta no
  MetaGest nas facturas de particulares e empresas emitidas pela pessoa no
  período (sem seguradoras). Corrigido: só a partir de 100 Kz em `bsp_painel`,
  `bsp_fin_alertas` e `bsp_financeiro_alertar` (381 das 515 facturas de
  particulares eram restos de arredondamento, 118,50 Kz). Ficam 134 facturas,
  1,61 M Kz em 6 meses (71 emitidas pela Juliana).
- 30-10-2026 (auditoria do Painel clínico): os endereços `#/painel-clinico`,
  `#/stock` e `#/dashboard` não abriam o ecrã (avisos de toners e do pedido à
  Farmácia levavam a `#/stock`/`#/dashboard`). Acrescentados à lista de rotas do
  endereço no `App`.
- 30-10-2026, Elmar: «a mesma auditoria faça no painel clínico» → «sim» (11 pontos
  e três avisos). `clinico-auditoria.sql` (aplicado): `bsp_clinico_qualidade`
  junta ao `bsp_painel_clinico` espera triagem → consulta (por médico), relatórios
  com atenção e por entregar pela escala (por pessoa; cada área desde o primeiro
  relatório; sem turnos de chefia nem opcionais), aberturas e fechos em falta
  (desde 31-10), diferenças de turno, segurança por área (ocorrências, incidentes,
  quase-erros), satisfação, registo clínico no MetaGest por médico (Outubro: 102
  de 268 consultas, 21 sem diagnóstico), registos do Workspace (0), credenciais
  (1 médico), pedidos à Farmácia, médicos sem chegada marcada, comparência; cada
  chefe só a sua área. Telemóvel: `bsp_clinico_alertar` (cron
  `bsp-clinico-alertas`, minutos 27 e 57): utente à espera há mais de 2 h, valores
  críticos por comunicar, áreas sem registos de segurança em 30 dias (segundas).
  Para u14 e u1 (críticos também ao chefe). Ecrã: quadros de qualidade, listas e
  selector de período no telemóvel. Mês: 0,27 s.
- 30-10-2026, Elmar (passagem «publicar fotos dos serviços no site»): fotografia em
  cada bloco de serviços da página inicial e bloco novo «Cardiologia» (marcação pelo
  WhatsApp). `index.html` (estava igual à versão de base, 51 253 bytes: alterações
  aplicadas uma a uma) e `assets/servico-*.jpg` (5 fotografias, tiradas da pasta
  do SharePoint «PARA CARREGAR NO GITHUB», tamanhos conferidos). Fotografias
  geradas por IA: nunca na secção «As nossas instalações». Testado: 5 colunas no
  computador (150 px de altura), 2 no tablet, 1 no telemóvel, sem deslizar para
  o lado. Desfazer: repor o `index.html` da pasta «COPIA DO SITE ACTUAL (antes)».
- 30-10-2026, Elmar: «o site do workspace está a dar para o site principal». A raiz do
  site (`index.html`) passa a enviar quem chega por `ws.*` para `/workspace.html`.
  O repositório `barispol-ws` do plano 3-hf não existe nos repositórios acessíveis;
  confirmar no DNS (Cloudflare) para onde aponta `ws` e nas definições do Pages.
- 30-10-2026, Elmar: «podemos passar a receber o formato HEIC?»; «o Nicolau quer
  enviar o relatório mas isso o atrasa». As fotografias HEIC do iPhone passam a
  JPEG antes de subir, no relatório de turno (anexos), na abertura e fecho do
  turno e no Chat (`bspConverterHeic`, `bspEHeic`; `bspReduzirImagem` também
  converte). Primeiro pelo próprio navegador (o Safari abre HEIC); senão pelo
  `vendor/heic/conversor.html` (heic2any 0.0.4, licença MIT em
  `vendor/heic/LICENSE.md`), num iframe `sandbox="allow-scripts"` sem mesma
  origem: precisa de 'unsafe-eval', que só ele tem; a CSP do Workspace não muda.
  O conversor (1,3 MB) só se carrega quando aparece um HEIC. Se a conversão
  falhar, o aviso diz «Não foi possível anexar» e nada sobe. Testado no Chromium
  com a CSP do Workspace: HEIC de 1201×900 → JPEG legível em 1,4 s.
- 30-10-2026, Elmar: «as imagens no site estão pequenas… inspecciona o site» → «e que
  tal criarmos já páginas e deixar de ser uma landing page extensa?» → «sim».
  Site em várias páginas (publicado a 30-10-2026, Elmar: «o site novo pode subir»): `assets/site.css` e `assets/site.js` comuns; `index.html`
  curto (cartões grandes com as fotografias, carrossel no telemóvel, faixa de
  factos, como funciona, clínica, campanhas, galeria; endereços antigos #analises,
  #seguros, #perguntas, #contactos e #clinica levam às páginas novas);
  `analises.html`, `consultas.html`, `cardiologia.html`, `seguros.html`, `clinica.html`
  (com a galeria `media/galeria.json`), `perguntas.html` (com FAQPage para o Google);
  `sitemap.xml` com todas. Testado a 390 e 1280 px: sem deslizar para o lado, sem
  ligações partidas. `ecografia.html` (Imagiologia) no aspecto novo a 30-10-2026
  (Elmar: «não cumpre o padrão das outras páginas»): mesmos 7 exames, preparação,
  códigos `data-wa` servico_01 a 07, dados estruturados e evento ViewContent.
  Depois (Elmar: «a antiga tinha mais actividade e vida, que tal uma súmula das
  duas?»): exames em cartões com a preparação destacada e botão em cada um, cartão
  «Não sabe qual exame precisa?», 4 passos numerados e faixa com morada, horário e
  contactos (classes `exames`, `exame`, `prep`, `passos numerados`, `dados` em
  `assets/site.css`, para usar noutras páginas).
  Falta: `contacto.html` no aspecto novo (continua com o antigo e funciona).
- 30-10-2026, Elmar: «nas seguradoras coloca logotipos»; «a página contacto está fora
  do padrão»; «as imagens podem estar maiores»; «o nosso logotipo está pequeno».
  Publicado a 30-10-2026: `seguros.html` em grelha
  com logotipo (ficheiros em `assets/seguros/<nome>.png`, ainda por receber; sem
  ficheiro mostra as iniciais), `contacto.html` no aspecto novo (mesmo formulário
  `entrada-publica`, lista das 22 seguradoras, Cardiologia no serviço), logótipo
  96 px, imagens maiores. «Mais vida» dentro da política do site humanizado
  (Elmar: «está como se fosse uma morgue»; organização inspirada no Hospital da
  Luz, «inspiração apenas»): botão «Marcar» no cabeçalho de todas as páginas
  (`marcar-topo`, para `contacto.html`), fotografia do topo até à margem, atalhos
  para os quatro serviços no azul da marca (`atalhos`), faixa com horário e
  telefone (`contacto-faixa`), serviços em mosaicos de fotografia (`mosaicos`),
  chamada final em azul. Saiu a barra fixa do WhatsApp no telemóvel (a política
  proíbe botão flutuante). Sem travessões nem pontos médios no texto. Testado a 390
  e 1280 px em todas as páginas e o formulário do Contacto com o servidor simulado.
  Logotipos em `assets/seguros/` (30-10-2026): Mundial (enviado pelo Elmar), Saúde+,
  Fidelidade, Mediplus e Unisaúde (assinaturas dos e-mails que nos enviaram). Faltam
  os outros 17: não há imagem nos e-mails nem no SharePoint (ADM, DAF, Marketing);
  pedir às seguradoras ou ao Elmar. Faltam fotografias reais da equipa para
  substituir as cinco geradas por IA (as de «FOTOS BARISPOL» são de 2024, salas vazias).
- 30-10-2026, Elmar: «ao iniciar a sessão, no menu inicial, pode ficar o funcionário do
  mês». Cartão `FuncionarioMesInicio` no Início de toda a equipa, logo abaixo das
  boas-vindas: fotografia, nome e função do último vencedor (`bsp_fm_estado`,
  `historico` com `estado = 'eleito'`); nos dias de votação, a quem ainda não votou,
  «Votação aberta» com o botão «Votar» (abre Equipa → Funcionário do mês); empate à
  espera da Direcção só para quem apura (u1, u2), com «Decidir». Sem nada para
  mostrar, não aparece. O servidor não mudou. Outubro de 2026 está empatado: até a
  Direcção decidir, a equipa não vê o cartão. Testado no navegador com os quatro casos.
- 30-10-2026, Elmar: «vê o site do Hospital da Luz; pode subir já a inspiração» (o
  site deles continua bloqueado na rede deste ambiente; usou-se o relatório do Chrome).
  Separadores da página (`separadores`, presos por baixo do cabeçalho, parte à vista
  marcada pelo `site.js`) em Análises, Consultas e Imagiologia, com «Marcar» a levar à
  chamada final (`id="marcar"`); secções com id (`antes`, `como`, `onde`). Todos os
  «Marcar» das listas (ligações `wa.me` em `.mais`) passam a botão marinho igual em
  todo o site. Testado a 390 e 1280 px. Nota: os geradores do scratchpad não têm estas
  mudanças; mexer agora nos `.html` directamente.
- 30-10-2026, Elmar: «cardiologia ia na página das consultas e os exames numa página
  nova de diagnóstico com todos os que fazemos». `diagnostico.html` (Ecografia, Raio-X,
  Exames do coração, Laboratório, com separadores), lista tirada do MetaGest (grupos
  ECOGRAFIA, RAIO - X e CARDIOLOGIA facturados no último ano; sem preços).
  Cardiologia passa a secção de `consultas.html` (`#cardiologia`); `cardiologia.html`
  reencaminha para lá (noindex). Menu: «Imagiologia» e «Cardiologia» → «Diagnóstico»
  (a `ecografia.html` fica como página de tipos e preparação, com o menu Diagnóstico
  marcado). Início: atalhos Diagnóstico e Seguros. Sitemap actualizado. Testado a 390 e
  1280 px, sem ligações partidas. Por confirmar com o Elmar: Ortopedia e Cirurgia estão
  em «Outras especialidades» mas não tiveram consultas facturadas no último ano.
- 30-10-2026, Elmar: «tira cirurgia; coloca nutrição, psicologia; vê mais o que falta».
  Em `consultas.html`, «Outras especialidades» passa de nomes soltos a lista com texto
  e «Marcar»: Medicina geral e familiar (nova, 51 consultas facturadas no ano), Medicina
  interna, Urologia, Ortopedia, Dermatologia, Psicologia e Nutrição; sai a Cirurgia.
  Enfermagem com os serviços reais do MetaGest (injecções, sinais vitais, curativos,
  suturas, nebulização, lavagens, sala de observação 1 a 2 h). Por confirmar: Nefrologia
  (médico registado no MetaGest, sem consultas facturadas).
- 30-10-2026, Elmar: «análises clínicas vão dentro do diagnóstico». Menu: Consultas,
  Diagnóstico, Seguros, A clínica, Contactos (sai «Análises»). `diagnostico.html` abre
  pelas Análises (os 8 grupos em cartões `lab-grupo`, ligados a `analises.html`), depois
  Ecografia, Raio-X e Coração. `analises.html` fica como subpágina (migalha Início ›
  Diagnóstico › Análises; menu Diagnóstico marcado). Testado a 390 e 1280 px.
  Pedidos de contacto do site (pergunta do Elmar): vão para `pedidos_marcacao`
  (Utentes → Marcações → «Pedidos do site») com aviso no telemóvel da Recepção
  (`bsp_pedido_site_aviso`); não sai e-mail. Proposto e-mail a rececao@ com geral@ em cópia.
- 30-10-2026, Elmar: «fiz pedido e não chegou email». `pedidos-site-email.sql` (aplicado):
  `bsp_pedido_site_email` manda cada pedido do site a rececao@barispol.com com
  geral@barispol.com em cópia (nome, telemóvel, serviço, seguro, melhor altura, hora,
  página), chamado pelo gatilho `bsp_pedido_site_aviso` antes do aviso no telemóvel; um
  erro no e-mail nunca impede gravar o pedido. Enviado também o do pedido n.º 1 (Resend
  aceitou às 23:41 de Luanda).
- 31-10-2026, Elmar: «não abre o anexo do relatório; vê todos» (captura: página em branco
  em …supabase.co). Os 30 anexos dos relatórios existem (14 JPG, 13 PDF, 3 Excel de ~7 MB);
  os JPG e PDF já abriam no visor; os .xlsx caíam no `window.open` do endereço directo,
  em branco no iPhone e na app. Novo `LeitorExcel` (`bspVerExcel`, `BSP_EXCEL` .xlsx/.xls/.csv,
  SheetJS de `vendor/sheetjs`, cada folha numa tabela, texto só como texto, até 1000
  linhas) e «Descarregar para editar». `bspAbrirFicheiro` já não abre endereços directos:
  um tipo sem leitor vai para `bspGuardarFicheiro` (guardar ou partilhar). Testado com um
  .xlsx de duas folhas.
- 31-10-2026, Elmar: «na horizontal, nos telefones, não conseguimos ver quase nada».
  O telemóvel deitado (até 500 px de altura, ecrã táctil) passa a contar como telemóvel
  (`bspTelemovelDeitado` no `useIsMobile`), mesmo com mais de 760 px de largura. Regra
  `@media (orientation: landscape) and (max-height: 500px)` no `bsp-responsive`:
  barra de cima com 44 px (`bsp-mtop`; o logotipo mantém os 38 px), barra de baixo só com
  ícones e o número por ler, cabeçalho da conversa com 40 px (`bsp-chat-cab`), caixa de
  escrever numa linha com os botões ao lado (`bsp-escrever`, `bsp-escrever-ta`,
  `bsp-escrever-barra`, até 72 px), menos margem no `main` e espaço para o recorte do
  ecrã. Testado a 844 × 390 (táctil), 390 × 844 e 1280 × 800: só o primeiro muda.
  Pergunta da Gizela («como vejo os relatórios das colegas?»): hoje a regra
  `bsp_rel_ler` (`relatorios-area.sql`) só deixa ler os próprios, a gestão e a Direcção
  Clínica (áreas médicas); colegas e chefe da área não lêem. Proposta ao Elmar: colegas
  da mesma área lêem os relatórios da área (só leitura) e o chefe da área também; por
  decidir. O conector do Supabase deixou de ver o projecto Barispol (só mostra o antigo):
  nada aplicado no servidor.
- 31-10-2026, Elmar: «com isso também» (colegas da área e chefe lêem os relatórios da
  área) e «cada um editar o seu relatório, mas com permissão … o director clínico é que
  autoriza». `relatorios-alterar.sql` (**por aplicar**: o conector do Supabase não vê o
  projecto Barispol): `bsp_rel_ler` passa a deixar ler os colegas da mesma área
  (`bsp_rel_area_de`, igual ao `bspAreaDe`) e o chefe de quem entregou (`bsp_chefe_de`),
  e os anexos `relatorio/` seguem a mesma regra; `bsp_rel_mudar` só a gestão.
  Quem entregou pede a alteração com motivo (`bsp_relatorio_alteracao_pedir`): fica
  «Pendente» em `relatorios_alteracoes` (antes e depois guardados). Autoriza
  (`bsp_relatorio_alteracao_decidir`, `bsp_relatorio_autoriza`): a Direcção Clínica
  (u14) no Laboratório, Imagiologia e Enfermagem; o superior (`bsp_aprovador_de`, senão
  u1) nas outras áreas; a gestão sempre. Ao autorizar, as respostas entram no relatório
  com `alterado_em` e `alterado_autorizou`. Aviso no telemóvel a quem autoriza e depois a
  quem pediu. Ecrã: «Pedir alteração» em `RelatorioResumo` (abre o formulário com as
  respostas, campo «Motivo da alteração», «Pedir autorização»), `RelatorioAlteracoes`
  (por autorizar, com antes e depois; os meus pedidos com o estado), lista «Relatórios da
  minha área». O botão e o painel só aparecem quando `bsp_relatorio_alteracoes` responde
  (sem o SQL, nada muda no ecrã). Falta: aplicar o SQL, confirmar com um pedido real e
  responder à Gizela no Chat.
- 31-10-2026, Elmar: «na alteração tem que vir um campo de observação com motivo
  obrigatório … como se fosse uma mensagem para quem autoriza. E quem autoriza é também
  um campo para responder, se autorizou ou se negou». «Observação: motivo da alteração
  (obrigatório)», com a indicação de para quem vai; «Pedir autorização» só com 10 letras
  ou mais (`BSP_REL_ALT_MIN`). No cartão de quem autoriza (`RelatorioAltCartao`):
  «Mensagem de <nome>» e «A sua resposta (obrigatória)»; «Autorizar» e «Recusar» só com
  a resposta escrita. Quem pediu vê «Resposta de <nome> (data)». No servidor
  (`relatorios-alterar.sql`, ainda por aplicar): motivo e resposta com 10 letras ou mais;
  a resposta vai no aviso do telemóvel a quem pediu. O `Button` passa a respeitar
  `disabled` (cinzento, sem clique) e a ter a variante `secondary` (= `ghost`): eram
  pedidos em 11 e 17 sítios e ignorados.
