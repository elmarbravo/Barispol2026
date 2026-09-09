# App nativa do Centro Médico Barispol

Invólucro nativo (Android e iOS) do Barispol Workspace, feito com
[Capacitor](https://capacitorjs.com). O `workspace.html` na raiz do repositório
continua a ser a **fonte única**: edita-se lá, corre-se um comando aqui, e a app
leva a versão nova. Não há código duplicado.

---

## O que já está feito

- Projectos Android e iOS gerados e configurados
- Identificador `com.barispol.workspace`, nome **Barispol**
- Ícones em todos os tamanhos, gerados a partir de `assets/logo-barispol.png`
- Permissões de câmara e microfone declaradas nas duas plataformas — sem elas
  as chamadas falham em silêncio dentro da WebView
- Script que sincroniza o site para dentro da app e, se quiser, semeia a ligação
  ao servidor para o utilizador não ter de a escrever

## Como se compila — na nuvem, sem instalar nada

O GitHub compila a app sozinho, num servidor dele, sempre que o site muda
ou a pedido. Não é preciso Android Studio, Mac, nem computador próprio.

| Fluxo (separador *Actions*) | Faz |
| --- | --- |
| **App Android** | Produz o APK de teste (instala-se directamente) e, havendo chave, o AAB assinado para a Play Store |
| **App Android · gerar chave (uma vez)** | Cria a chave de assinatura e guarda-a **cifrada** no repositório |
| **App iOS** | Compila num Mac da nuvem, sem assinatura — prova que o projecto está são |

**O passo a passo completo, incluindo as lojas, está em
[`lojas/PUBLICAR.md`](lojas/PUBLICAR.md).** Os textos da ficha da loja
estão em [`lojas/FICHA.md`](lojas/FICHA.md).

### A chave de assinatura Android

Vive em `android/chave-de-envio.keystore.enc`, cifrada com AES-256 e uma
frase que só existe no segredo `ANDROID_KEYSTORE_PASSWORD` do GitHub. O
repositório é público e mesmo assim a chave não se lê sem a frase; e
ninguém tem de descarregar nem colar ficheiros. **A frase é a chave da
app para sempre**: guardá-la fora do GitHub, com cópia.

O que está abaixo — Android Studio e Xcode — continua válido para quem
preferir compilar num computador próprio, mas deixou de ser necessário.

---

## Preparar

```bash
cd app
npm install
```

### Ligação ao servidor

Já não há nada a preencher: a app leva o `servidor.js` da raiz do
repositório, o mesmo que o site usa, e arranca ligada. O `servidor.json`
só serve para quem quiser apontar a app a **outro** servidor; deixa-se
vazio.

### Sincronizar

Sempre que o `workspace.html` mudar:

```bash
npm run sincronizar
```

---

## Android

**Precisa de:** [Android Studio](https://developer.android.com/studio) (Windows,
macOS ou Linux).

```bash
npm run abrir:android
```

No Android Studio: *Build → Generate Signed App Bundle* → cria a chave de
assinatura na primeira vez e **guarde-a em lugar seguro**. Sem ela não é
possível publicar actualizações, e não há forma de a recuperar.

O ficheiro `.aab` resultante sobe para a
[Play Console](https://play.google.com/console) (conta de programador: pagamento
único). Para instalar directamente nos telemóveis da equipa sem passar pela
loja, use *Build → Build APK* e distribua o `.apk`.

O ícone da ficha da loja (512×512) está em `lojas/play-icone-512.png`.

## iOS

**Precisa de:** um Mac com Xcode, e conta no
[Apple Developer Program](https://developer.apple.com/programs/) (anuidade).

```bash
sudo gem install cocoapods   # só na primeira vez
npm run abrir:ios
```

No Xcode: escolha a equipa de assinatura em *Signing & Capabilities*, depois
*Product → Archive* e siga para o App Store Connect.

---

## Três avisos que poupam semanas

### 1. A Apple rejeita sites embrulhados

A directriz [4.2 (Minimum
Functionality)](https://developer.apple.com/app-store/review/guidelines/#minimum-functionality)
recusa apps que sejam apenas um sítio dentro de uma WebView. Esta app tem
argumentos a seu favor — usa câmara e microfone para chamadas reais, que é
funcionalidade nativa — mas convém que isso se veja nas capturas de ecrã e no
texto da submissão. Descreva a app pelo que ela faz (chamadas, mensagens,
tarefas da equipa clínica), não como «o nosso site».

O Google Play é bastante mais permissivo neste ponto.

### 2. É uma ferramenta interna numa loja pública

O workspace é para a equipa do centro médico, não para o público. Isso levanta
duas questões práticas:

- **Os revisores precisam de entrar.** Crie uma conta de demonstração no
  Supabase e forneça as credenciais no App Store Connect e na Play Console. Sem
  isso, a submissão é recusada por não ser possível avaliar a app.
- **Talvez nem queira uma loja pública.** Para uso interno existem caminhos
  melhores: no Android, distribuir o `.apk` directamente ou usar um canal
  fechado na Play Console; no iOS, o TestFlight (até 100 pessoas, sem revisão
  completa) ou o Apple Business Manager. Vale a pena pensar nisto antes de pagar
  as contas de programador.

### 3. O ícone de 1024 é ampliado

O logótipo original tem 420×428. O ícone da App Store exige 1024×1024, e o que
está em `ios/App/App/Assets.xcassets/AppIcon.appiconset/` foi ampliado a partir
daquele — fica suave, e a Apple é exigente com a nitidez dos ícones.

**Peça a quem fez o logótipo o ficheiro vectorial** (`.ai`, `.svg` ou `.pdf`) e
regenere os ícones a partir dele. Os tamanhos Android estão todos abaixo dos 432
píxeis e não sofrem com isto; o problema é só o do iOS.

---

## Antes de submeter

- [ ] Testar uma chamada entre dois aparelhos reais, um Android e um iPhone
- [ ] Confirmar que a autorização de câmara e microfone é pedida e funciona
- [ ] Verificar o comportamento sem rede, e ao recuperar a rede
- [ ] Criar a conta de demonstração para os revisores (ver `lojas/FICHA.md`)
- [ ] Substituir o ícone de 1024 por um gerado do vectorial
- [ ] Guardar a **frase** `ANDROID_KEYSTORE_PASSWORD` em local seguro e com cópia
- [ ] A política de privacidade está em https://barispol.com/privacidade.html

## Estrutura

```
app/
  sincronizar.js        copia o site para www/ e semeia a ligação
  servidor.json         dados do Supabase (opcional)
  capacitor.config.json identificador, nome, esquema
  android/              projecto Android Studio
  ios/                  projecto Xcode
  lojas/                ícone 512, textos da ficha (FICHA.md) e o passo a passo (PUBLICAR.md)
  android/chave-de-envio.keystore.enc   chave de assinatura, cifrada (gerada pelo fluxo)
  www/                  gerado — não editar, não versionado
```
