# Publicar a app — passo a passo

Escrito para ser seguido por uma pessoa **ou por um assistente no
navegador** (Claude no Chrome). Não é preciso Android Studio, Mac, nem
qualquer programa instalado: tudo acontece no GitHub e nas lojas.

> ## Regras para o assistente
> 1. A **frase de assinatura** (passo 1.1) é um segredo. Escreve-se **uma
>    vez** no campo do GitHub e mais em lado nenhum. Não a copiar para a
>    conversa.
> 2. Um passo de cada vez. Confirmar o resultado antes de avançar. Se o
>    ecrã não for como está descrito, parar e descrevê-lo.
> 3. Sessões necessárias: GitHub (`elmarbravo/Barispol2026`, com
>    permissão de escrita) e, mais tarde, a Play Console.

---

## Fase 1 — A app nos telemóveis da equipa (hoje, sem loja)

Um APK instalável directamente. Serve para a equipa começar a usar a app
e para tirar as capturas de ecrã da loja.

- [ ] **1.0** GitHub → repositório → separador **Actions**. Se aparecer um
      botão verde *«I understand my workflows, go ahead and enable them»*,
      carregar.
- [ ] **1.1** GitHub → **Settings** → **Secrets and variables** →
      **Actions** → **New repository secret**. Nome: `ANDROID_KEYSTORE_PASSWORD`.
      Valor: uma frase longa, **16 caracteres ou mais**, inventada agora e
      guardada em lugar seguro pela pessoa (é a chave da app para sempre).
      **Add secret**.
- [ ] **1.2** **Actions** → na lista da esquerda, **«App Android · gerar
      chave (uma vez)»** → **Run workflow** → **Run workflow**. Esperar
      ~1 minuto. *Confirmação:* um visto verde, e no repositório aparece
      um commit novo *«App Android: chave de envio, cifrada»* com o
      ficheiro `app/android/chave-de-envio.keystore.enc`.
      Se der vermelho, abrir a execução e ler a mensagem: diz exactamente
      o que faltou.
- [ ] **1.3** **Actions** → **«App Android»** → **Run workflow** → **Run
      workflow**. Esperar 5 a 10 minutos.
- [ ] **1.4** Abrir a execução terminada. No fim da página, em
      **Artifacts**, há dois ficheiros:
      - `barispol-teste-1.N-apk` — **instala-se directamente** num Android
      - `barispol-play-1.N-aab` — é o que sobe para a Play Store
      *Confirmação:* os dois existem. Se só existir o primeiro, o passo
      1.2 não ficou bem.
- [ ] **1.5** Descarregar o `…-apk`, descomprimir o `.zip`, e enviar o
      `app-debug.apk` para um telemóvel Android (WhatsApp, e-mail, cabo).
      No telemóvel: abrir o ficheiro → aceitar *«instalar de origem
      desconhecida»* → instalar. Abre já ligada ao servidor; só pede
      e-mail e palavra-passe.

A partir daqui, **sempre que o site mudar, o APK e o AAB refazem-se
sozinhos** — basta ir buscá-los aos Artifacts da execução mais recente.

---

## Fase 2 — Play Store (Android)

Precisa de uma **conta de programador Google Play** (pagamento único,
cerca de 25 USD, com verificação de identidade — só a pessoa a pode
criar).

- [ ] **2.1** [play.google.com/console](https://play.google.com/console)
      → **Create app** → nome *Barispol* · idioma *Português (Portugal)*
      · **App** · **Free** → aceitar as declarações → **Create app**.
- [ ] **2.2** Painel da app → **Set up your app** → percorrer cada item.
      As respostas estão em [`FICHA.md`](FICHA.md): política de
      privacidade, acesso à app (a conta de demonstração), anúncios
      (não), classificação de conteúdo, público-alvo (adultos, 18+),
      segurança dos dados, categoria e contactos.
- [ ] **2.3** **Main store listing** → colar os textos de `FICHA.md` →
      ícone `lojas/play-icone-512.png` → capturas de ecrã tiradas na
      fase 1 → uma imagem de destaque 1024×500 (pode ser o logótipo
      centrado sobre fundo azul-escuro `#002060`).
- [ ] **2.4** **Testing → Internal testing** → **Create new release** →
      aceitar o *Play App Signing* → carregar o `app-release.aab` do
      artifact `…-aab` → **Next** → **Save** → **Review release** →
      **Start rollout to Internal testing**. Acrescentar os e-mails da
      equipa à lista de testers. *Confirmação:* aparece uma ligação de
      convite; quem a abrir no Android instala a app pela Play Store.
- [ ] **2.5** Quando estiver satisfeito: **Production** → **Create new
      release** → o mesmo AAB → **Start rollout to Production**. A
      revisão do Google leva de horas a alguns dias.

**Actualizações:** cada nova execução do «App Android» produz um AAB
com número de versão maior. Repetir 2.4 ou 2.5 com o novo ficheiro.

---

## Fase 3 — App Store (iPhone)

É a parte que **não se resolve só com o navegador**, e convém sabê-lo
antes de pagar.

Precisa de:
1. **Apple Developer Program** — anuidade (99 USD), em nome da empresa
   (exige o D-U-N-S da empresa) ou de uma pessoa.
2. **Certificados e perfis de assinatura** dessa conta, colocados como
   segredos no GitHub — configuração técnica de várias etapas que ainda
   não está montada neste repositório.
3. O **ícone 1024×1024 regenerado do vectorial** (ver `FICHA.md`).

O fluxo **«App iOS»** já existe e prova que o projecto compila num Mac da
nuvem; falta-lhe a assinatura. Quando a conta Apple existir, esse é o
próximo trabalho a pedir.

Alternativa mais barata para uma equipa pequena: a app iPhone pode
esperar. No iPhone, o `barispol.com/workspace.html` **adicionado ao ecrã
principal** (Safari → Partilhar → *Adicionar ao ecrã principal*) abre em
ecrã inteiro, com ícone, e faz chamadas — para o dia-a-dia, quase não se
distingue de uma app instalada.

---

## Se alguma coisa correr mal

| O que aparece | O que quer dizer |
| --- | --- |
| Execução vermelha no passo *«Verificar a frase»* | Falta o segredo `ANDROID_KEYSTORE_PASSWORD`, ou tem menos de 16 caracteres |
| Execução vermelha no passo *«Recusar se já existir»* | A chave já foi gerada antes. Não gerar outra: usar a que existe |
| Só aparece o artifact `…-apk` | A chave não existe ou o segredo está errado; ver o aviso amarelo na execução |
| A Play Console recusa o AAB: *«versionCode already used»* | Correr o «App Android» outra vez; o número sobe sozinho |
| A Play Console recusa: *«not signed»* | O AAB é de uma execução sem chave; repetir 1.2 e 1.3 |
