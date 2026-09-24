# bright-worker — falta-lhe verificar quem a chama

> **Feito em 24-09-2026.** O código completo está em
> [`bright-worker/index.ts`](bright-worker/index.ts) e foi publicado como
> versão 5, com a verificação de JWT desligada. Uma diferença em relação
> ao plano abaixo: a sessão de um colaborador que não é gestor também é
> aceite, mas só para endereços da equipa ou empresa@barispol.com. Só
> gestores teria parado os avisos de mensagens directas, tarefas e
> mural, que são enviados a partir da sessão de qualquer pessoa. Este
> documento fica como registo.

## O problema

A função `bright-worker` (nome visível no painel: `notify-email`) recebe
`to`, `subject` e `html`, vai buscar a `RESEND_API_KEY` e envia. Nunca lê o
cabeçalho `Authorization`. Não verifica quem está do outro lado.

A única coisa que hoje a protege é o interruptor **«Verify JWT with legacy
secret»** do painel. Esse interruptor deixa de ter efeito no dia em que as
chaves JWT forem desligadas (passo 0.6 do `O-QUE-FALTA.md`). A partir daí,
ou fica a recusar tudo, ou — se for desligado — fica um endereço público
por onde qualquer pessoa manda e-mails com o domínio da clínica.

Há ainda um efeito imediato, anterior ao 0.6: desde que o `servidor.js`
passou a levar a chave publicável, o Workspace chama esta função com essa
chave. Não sendo um JWT, o interruptor recusa-a. O envio de e-mails a
partir da aplicação está parado desde esse momento, e em silêncio — o
`bspSendEmail` engolia o erro com um `.catch(() => {})`.

## O que fazer

O código de envio fica como está — incluindo o remetente (`from`), que não
deve ser tocado: o domínio está verificado no Resend e trocá-lo parte o
envio.

Acrescenta-se verificação própria à entrada. Depois disso, o interruptor
«Verify JWT with legacy secret» pode ser desligado nesta função, como já foi
nas outras duas.

### 1. No topo do ficheiro, junto aos outros `import`

```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
```

### 2. A seguir ao `const cors = { ... }`, antes do `Deno.serve`

Colar o bloco de leitura de chaves que está em
`funcoes/criar-utilizador/index.ts` (as funções `valoresDe`,
`chavesServidor`, `chavesPublicas`, `chavePublica`, `ehChaveDoServidor` e
`ehChavePublica`). É o mesmo bloco, sem alterações.

### 3. Dentro do `Deno.serve`, logo a seguir ao tratamento do `OPTIONS`

```ts
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ erro: "Método não permitido." }),
      { status: 405, headers: { ...cors, "Content-Type": "application/json" } });
  }

  /* Quem pode mandar enviar correio: o servidor (é o caso do resumo
     matinal, que chama esta função com a chave de servidor) ou um gestor
     com sessão aberta no Workspace. A chave publicável não serve: está à
     vista no servidor.js. */
  const testemunho = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!testemunho) {
    return new Response(JSON.stringify({ erro: "Sem autorização." }),
      { status: 401, headers: { ...cors, "Content-Type": "application/json" } });
  }

  if (!ehChaveDoServidor(testemunho)) {
    if (ehChavePublica(testemunho)) {
      return new Response(JSON.stringify({ erro: "A chave pública não chega para enviar correio." }),
        { status: 403, headers: { ...cors, "Content-Type": "application/json" } });
    }
    const URL_SB = Deno.env.get("SUPABASE_URL") || "";
    const ANON = chavePublica();
    if (!URL_SB || !ANON) {
      return new Response(JSON.stringify({ erro: "A função não tem as chaves do projecto." }),
        { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
    }
    const comSessao = createClient(URL_SB, ANON, {
      global: { headers: { Authorization: "Bearer " + testemunho } },
      auth: { persistSession: false },
    });
    const { data: eGestor } = await comSessao.rpc("bsp_e_gestor");
    if (eGestor !== true) {
      return new Response(JSON.stringify({ erro: "Só um gestor pode enviar correio." }),
        { status: 403, headers: { ...cors, "Content-Type": "application/json" } });
    }
  }
```

A função `bsp_e_gestor()` já existe na base de dados — está no
`INSTALAR-TUDO.sql`, linha 60.

## Porque não vem aqui o ficheiro inteiro

O código desta função só existe no painel do Supabase; não está neste
repositório. Foi lido no separador **Code** da função, mas não copiado. O
remetente (`from`) e os detalhes do pedido ao Resend ficam por isso fora
deste documento, para não se escrever de cor aquilo que já funciona.

Depois de aplicar a alteração, vale a pena guardar o ficheiro completo em
`funcoes/bright-worker/index.ts`, para a próxima pessoa não ter de o ir
buscar ao painel.
