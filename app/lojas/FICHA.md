# Ficha da loja — textos prontos a colar

Os mesmos textos servem para a Play Store e para a App Store. Estão
escritos para o revisor perceber que **não é um site embrulhado**: é uma
ferramenta de equipa com chamadas, mensagens e tarefas.

---

## Identificação

| Campo | Valor |
| --- | --- |
| Nome da app | **Barispol** |
| Identificador | `com.barispol.workspace` |
| Categoria | Produtividade *(Play)* · Business *(App Store)* |
| E-mail de contacto | rh@barispol.com |
| Sítio | https://barispol.com |
| Política de privacidade | https://barispol.com/privacidade.html |
| Público | Colaboradores do Centro Médico Barispol. Não é para utentes. |
| Classificação etária | Sem conteúdo sensível; questionário responde-se «não» a tudo |

## Descrição curta (máx. 80 caracteres)

```
A equipa do Centro Médico Barispol, ligada: chat, chamadas e tarefas.
```

## Descrição completa

```
Barispol é a aplicação interna da equipa do Centro Médico Barispol, em Luanda.

Serve para a equipa clínica e administrativa trabalhar junta ao longo do dia:

• Chat por canais e mensagens directas, com reacções, tópicos e anexos
• Chamadas de voz e vídeo entre colegas, directamente na app
• Grupos privados para assuntos reservados
• Mural com comunicados e escalas fixadas
• Tarefas da equipa e tarefas pessoais
• Agenda partilhada
• Drive da equipa e área pessoal de ficheiros, com pastas
• Seguimento de utentes (retorno e acompanhamento)
• Resumo diário por e-mail, de manhã, com as tarefas de cada pessoa

Só entra quem tiver conta criada pela Direcção do centro. A app não se destina ao público nem a utentes.

Câmara e microfone são usados apenas durante as chamadas, e só com a sua autorização. Não há anúncios nem rastreio.
```

## Novidades (primeira versão)

```
Primeira versão da app da equipa Barispol.
```

## Conta de demonstração para o revisor

**Obrigatória.** Sem ela a submissão é recusada em ambas as lojas, porque
o revisor não consegue entrar.

1. Em **Admin → Utilizadores**, criar uma pessoa chamada *Revisor Loja*,
   camada *Operações*, com um e-mail que exista (por exemplo
   `revisor@barispol.com`) e uma palavra-passe.
2. Colar esse e-mail e palavra-passe no campo *«Instruções para a
   revisão»* / *«App access»* da loja.
3. Escrever também: *«Aplicação interna de uma clínica. Entre com as
   credenciais acima. Para testar uma chamada, abra o Chat, escolha uma
   pessoa e carregue no telefone; a outra pessoa pode não atender, mas a
   app pede câmara e microfone e mostra a chamada a tocar.»*
4. Apagar essa pessoa depois de a app estar aprovada.

## Capturas de ecrã (têm de ser feitas na app instalada)

Mínimo 2 por loja; o ideal são 5. Do telemóvel, em modo vertical:

1. Chat, com um canal aberto e mensagens
2. Uma chamada a decorrer (ou a tocar)
3. O mural, com um comunicado fixado
4. As tarefas
5. O Drive, na área pessoal com pastas

Não é preciso enquadrar em molduras de telemóvel: a captura simples do
ecrã serve. Tirar com uma conta que tenha dados reais mas **sem nomes de
utentes visíveis** — usar o Seguimento apenas se estiver vazio.

## Ícones

| Loja | Ficheiro | Estado |
| --- | --- | --- |
| Play Store (512×512) | `lojas/play-icone-512.png` | pronto |
| App Store (1024×1024) | `ios/App/App/Assets.xcassets/AppIcon.appiconset/` | **ampliado do logótipo original** — pedir o ficheiro vectorial a quem fez o logótipo e regenerar, senão a Apple pode recusar por falta de nitidez |

## Ficha «Segurança dos dados» (Play) e «Privacidade» (App Store)

Responder com base na política de privacidade:

| Pergunta | Resposta |
| --- | --- |
| Recolhe dados? | Sim |
| Quais? | Nome, e-mail, mensagens, ficheiros, áudio/vídeo (só em chamada, não guardado) |
| Partilha com terceiros? | Não |
| Cifrado em trânsito? | Sim |
| O utilizador pode pedir a eliminação? | Sim, por e-mail (rh@barispol.com) |
| Usa para publicidade ou rastreio? | Não |
| Ligado à identidade do utilizador? | Sim (é uma app de equipa com login) |
