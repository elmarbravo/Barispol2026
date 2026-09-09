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
- [ ] **0.4** Na página *API Keys*, separador *Publishable and secret*,
      criar uma chave **secret** (botão do género *Create new secret
      key*; nome sugerido `resumo-matinal`). Ela só é mostrada uma vez.
      **Não a copiar para a conversa.** Copiá-la directamente para a linha
      22 do `agendar-resumo.sql` no passo 3, e a mais nada.
- [ ] **0.5** Instalar as duas Edge Functions do passo 2. Sem isto,
      deixam de funcionar no passo seguinte. (Podem ser instaladas já
      aqui; o passo 2 fica então feito.)
- [ ] **0.6** Só com 0.1 a 0.5 confirmados: *API Keys* → separador
      *«Legacy anon, service_role»* → **Disable JWT-based API keys** →
      confirmar. É neste instante que a chave que saiu deixa de valer.
      *Confirmação:* voltar ao Workspace, recarregar à força, e o
      indicador em Admin → Sistema continuar verde.

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
| `bright-worker` | *(já existe no projecto)* | Enviar e-mails | instalada |

- [ ] `criar-utilizador`
- [ ] `resumo-matinal`

As duas aceitam tanto as chaves antigas como as novas, por isso podem ser
instaladas antes ou depois do passo 0.

---

## 3. O resumo matinal — um ficheiro com UMA linha a mudar

- [ ] **SQL Editor** → colar [`agendar-resumo.sql`](agendar-resumo.sql).
      Antes de **Run**, mudar **só a linha 22**: substituir `COLE_AQUI`
      pela chave **secret** do passo 0.4, mantendo as aspas.

O ficheiro recusa correr se a chave não estiver lá, ou se for a pública
por engano. No fim, a coluna `para_onde` tem de mostrar o endereço do
projecto.

Sai às 06h30 de Luanda, de segunda a sábado. Para o ver sem esperar:
**Admin → Sistema → «Enviar o resumo matinal agora»**.

> Já foi corrido uma vez com `<PROJECTO>` e `<SERVICE>` por preencher —
> ficou um agendamento activo que falha em silêncio. Correr o ficheiro
> outra vez, com a chave, substitui-o.

---

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
