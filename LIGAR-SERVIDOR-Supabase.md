# Instalação e manutenção do servidor

O Barispol Workspace guarda tudo num projecto **Supabase**. Este guia é para
quem administra: instalar de raiz, ou pôr em dia uma instalação que já existe.

**A ligação já não se configura em cada aparelho.** O endereço e a chave vivem
no ficheiro `servidor.js`, definidos uma vez para toda a gente. Quem abrir o
`barispol.com` entra já ligado.

---

## Se já está a funcionar, é só isto

Falta correr um ficheiro e instalar uma função. Vinte minutos.

### 1. Correr o `INSTALAR-TUDO.sql`

Traz as regras por conversa, as camadas de acesso editáveis, o Seguimento de
utentes e as tarefas pessoais.

**As regras por conversa são as que fecham os grupos privados e as mensagens
directas do lado do servidor.** Sem elas, um grupo privado é privado apenas no
ecrã: alguém com sessão iniciada conseguiria ler as mensagens pela API.

1. **[supabase.com/dashboard](https://supabase.com/dashboard)** → o projecto
2. Barra da esquerda → **SQL Editor** → **+ New query**
3. Abra o [`INSTALAR-TUDO.sql`](INSTALAR-TUDO.sql), carregue em **Raw**,
   seleccione tudo e copie
4. Cole e **RUN**

No fim aparecem seis linhas — `messages`, `posts`, `seguimentos`,
`shared_state`, `tarefas_pessoais`, `utentes` — todas com `protegida = true`.
É essa a confirmação de que correu bem.

Depois de correr, confirme que consegue ver as suas mensagens directas. Se
alguém deixar de as ver, é porque o e-mail de login dessa pessoa não coincide
com o que está em Admin → Utilizadores — as regras traduzem uma coisa na outra
pelo e-mail.

O ficheiro pode correr as vezes que forem precisas sem estragar nada, e
começa por verificar se falta algum passo anterior.

### 2. Instalar a função `criar-utilizador`

Sem ela, acrescentar alguém em Admin → Utilizadores põe a pessoa no
directório mas **não lhe cria a conta**: ela não consegue entrar.

1. Barra da esquerda → **Edge Functions** → **Deploy a new function**
2. Nome **exactamente** `criar-utilizador` — com hífen, sem acentos
3. Apague o exemplo e cole
   [`funcoes/criar-utilizador/index.ts`](funcoes/criar-utilizador/index.ts)
4. **Deploy**

Não é preciso configurar chaves: o Supabase fornece à função as que ela
precisa.

---

## Instalar de raiz, num projecto novo

### 1. Criar o projecto

Em **[supabase.com](https://supabase.com)** → **New project**. Guarde a
palavra-passe da base de dados. Escolha a região mais próxima — para Angola,
a Europa Ocidental é a menos má.

### 2. Correr os ficheiros, por esta ordem

| Ordem | Ficheiro | Para quê |
| --- | --- | --- |
| 1 | [`supabase-configuracao.sql`](supabase-configuracao.sql) | Tabelas, armazenamento de ficheiros e tempo real |
| 2 | [`INSTALAR-TUDO.sql`](INSTALAR-TUDO.sql) | Regras por conversa, camadas editáveis, CRM e tarefas pessoais |

O `INSTALAR-TUDO.sql` verifica se as tabelas base existem e pára com um aviso
claro se o 1 ainda não tiver corrido.

### 3. Instalar as funções

**`criar-utilizador`** — como acima.

**`bright-worker`** — a que envia os e-mails. Se ainda não existir, os avisos
por e-mail não saem, e o resto funciona na mesma. Há um teste em
**Admin → Sistema** que envia uma mensagem de prova.

### 4. Apontar o site ao projecto

Abra o [`servidor.js`](servidor.js) e ponha lá o **Project URL** e a chave
**anon public**, que estão em *Project Settings → API*. Depois envie para o
GitHub. É a única vez que isto se faz.

### 5. Criar a primeira conta

O primeiro login tem de ser criado à mão, porque ainda não há ninguém para o
fazer pela aplicação: **Authentication → Users → Add user**. Use um e-mail
que já esteja em Admin → Utilizadores, e marque **Auto Confirm User**.

---

## Sobre a chave estar à vista no repositório

A chave `anon public` está no `servidor.js`, num repositório público, e isso
está correcto. É assim que todas as aplicações Supabase funcionam: essa chave
vai no código de qualquer sítio que use Supabase, e não dá acesso a nada por
si só — só permite falar com o servidor.

**Quem protege os dados são as regras da base de dados**, e todas exigem
sessão iniciada. Sem e-mail e palavra-passe válidos, a chave sozinha não lê
uma única mensagem.

O que **nunca** pode sair do Supabase é a chave **`service_role`**. Essa
contorna todas as regras. Vive apenas dentro das Edge Functions, onde o
Supabase a fornece sozinho.

Como a segurança assenta inteiramente nas regras, os ficheiros SQL de
segurança deixam de ser opcionais: são a fechadura.

---

## Conferir que está tudo de pé

No **SQL Editor**:

```sql
-- Todas devem estar protegidas
select tablename, rowsecurity as protegida
from pg_tables
where schemaname = 'public'
order by tablename;

-- Quem o servidor considera gestor. Se alguém aparecer errado, o e-mail
-- em Admin -> Utilizadores não coincide com o e-mail de login.
select e->>'name' as pessoa, e->>'accessLevel' as camada,
       coalesce((s.camadas -> (e->>'accessLevel') ->> 'podeGerirUtilizadores')::boolean, false) as gestor
from shared_state s, jsonb_array_elements(coalesce(s.team,'[]'::jsonb)) e
where s.id = 1
order by 3 desc, 1;
```

---

## Quando alguma coisa não funciona

**Um aparelho pede o endereço e a chave.** Tem uma ligação antiga guardada.
Abra `barispol.com/workspace.html#reset` nesse aparelho.

**Alguém não vê as suas mensagens directas, ou as suas tarefas pessoais.** O
e-mail com que essa pessoa entra não é o mesmo que está em
Admin → Utilizadores. As regras do servidor traduzem uma coisa na outra pelo
e-mail. Corrigir no directório resolve na hora.

**Criar utilizador dá erro.** A função `criar-utilizador` não está instalada,
ou tem outro nome. Tem de se chamar exactamente assim.

**O ecrã Seguimento diz que faltam tabelas.** O `INSTALAR-TUDO.sql` ainda não
correu.

**As mensagens não aparecem noutro aparelho.** Faltam as linhas do tempo real
no `supabase-configuracao.sql` (`alter publication … add table …`).

**Uma camada nova de gestão não consegue administrar nada.** O
`INSTALAR-TUDO.sql` não correu: o servidor ainda decide quem é gestor por uma
lista de nomes fixa, e não conhece a camada nova.

---

## Cópia de segurança

O plano gratuito do Supabase não guarda cópias automáticas. Em
**Admin → Sistema** há um botão que descarrega tudo num ficheiro. Uma vez por
semana, guardado fora do computador da clínica.

Se a cópia sair vazia ou avisar que atingiu um limite, o botão diz-lho — não
descarrega um ficheiro incompleto em silêncio.
