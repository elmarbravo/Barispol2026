# Barispol Workspace para computador

App de Windows e Mac do Workspace (14-10-2026). É só uma janela própria que
abre `https://barispol.com/workspace.html`, como a app Android (`app/`). O
conteúdo vem sempre do site: cada publicação em `main` chega à app sem
reinstalar. Só é preciso compilar de novo quando esta pasta muda.

## Onde se tira

GitHub → separador **Actions** → fluxo **App PC** → a execução mais recente
→ **Artifacts** no fim da página:

| Ficheiro | Para quê |
| --- | --- |
| `Barispol-Setup-1.N.exe` | Instalador para Windows. Cria o atalho «Barispol Workspace» no ambiente de trabalho e no menu Iniciar. Não pede administrador. |
| `Barispol-1.N-portatil.exe` | Windows sem instalar: abre directamente (útil em computadores partilhados). |
| `Barispol-1.N.dmg` | Mac: arrastar o Barispol para Aplicações. |

O GitHub entrega os ficheiros dentro de um .zip: abrir o .zip primeiro.

## O aviso do Windows na primeira vez

A app não tem assinatura de código (é um certificado pago). Na primeira vez
o Windows mostra «O Windows protegeu o computador»: carregar em **Mais
informações** e depois **Executar mesmo assim**. No Mac: botão direito na app
→ **Abrir** → **Abrir** (ou Definições do Sistema → Privacidade e segurança →
«Abrir mesmo assim»).

## O que faz e o que não faz

- Janela própria, uma só (abrir outra vez traz a que está aberta).
- Chamadas, notas de voz, câmara e notificações funcionam, só para barispol.com.
- Imprimir, guardar ficheiros e copiar/colar funcionam como no navegador.
- Ligações para outros sites abrem no navegador do computador.
- Sem internet mostra «Sem ligação» com «Tentar de novo».
- Fechar a app termina a sessão, como fechar o separador (regra de segurança
  do Workspace: a sessão nunca fica guardada no computador).
- As notificações aparecem com a app aberta, mesmo minimizada. Com a app
  fechada não chegam ao computador (a técnica de envio do navegador não
  existe nesta app): ficam o telemóvel e o e-mail.

## Alternativa sem instalar nada

No Edge ou no Chrome, com o Workspace aberto: menu **⋯** → **Aplicações** →
**Instalar Barispol Workspace**. Fica igualmente com janela e ícone próprios.

## Segurança (para quem mexer no código)

`main.js` é o único código. A página nunca tem acesso ao sistema:
`contextIsolation`, `sandbox`, sem `nodeIntegration` e sem `preload`. Nunca
mudar isto: qualquer falha no site passaria a mexer no computador. A lista
de endereços permitidos está em `PERMITIDOS`.

## Experimentar no computador de quem programa

```
cd app-pc
npm ci
npm run iniciar
```
