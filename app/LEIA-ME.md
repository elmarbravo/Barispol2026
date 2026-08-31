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

## O que falta, e não pode ser feito aqui

Esta máquina não tem SDK Android nem Xcode, e o iOS **só compila em macOS**.
Os passos abaixo têm de correr noutro computador.

---

## Preparar

```bash
cd app
npm install
```

### Ligar ao servidor (opcional, mas recomendado)

Abra `servidor.json` e preencha com os dados do vosso projecto Supabase:

```json
{ "url": "https://xxxxxxxx.supabase.co", "key": "eyJ..." }
```

A chave é a **anon public** — nunca a `service_role`. Com isto preenchido, a app
arranca já ligada e o utilizador só vê o ecrã de entrada. Deixando vazio, a app
pede a ligação no primeiro arranque, como o site faz hoje.

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
- [ ] Criar a conta de demonstração para os revisores
- [ ] Substituir o ícone de 1024 por um gerado do vectorial
- [ ] Guardar a chave de assinatura Android em local seguro e com cópia

## Estrutura

```
app/
  sincronizar.js        copia o site para www/ e semeia a ligação
  servidor.json         dados do Supabase (opcional)
  capacitor.config.json identificador, nome, esquema
  android/              projecto Android Studio
  ios/                  projecto Xcode
  lojas/                ícone 512 para a ficha da Play Store
  www/                  gerado — não editar, não versionado
```
