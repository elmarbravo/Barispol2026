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

### 2. Correr o `ficheiros-pessoais.sql`

Traz a gaveta pessoal do Drive e fecha os anexos das conversas.

**É este ficheiro que faz o «privado» querer dizer privado.** Sem ele,
tudo o que entra no armazenamento é legível por qualquer pessoa com sessão
iniciada, e um documento anexado numa mensagem directa fica ao alcance de
toda a gente.

Mesmo caminho: **SQL Editor** → **+ New query** → colar
[`ficheiros-pessoais.sql`](ficheiros-pessoais.sql) → **RUN**.

No fim deve dizer `protegida = true` e listar as três regras do
armazenamento. Os ficheiros que já lá estavam continuam a ser da equipa —
nada se perde.

### 3. Correr o `FALTA-CORRER.sql`

Um só ficheiro, **sem nada para preencher**. Traz as pastas na área
pessoal do Drive e faz com que, no Drive da equipa, só quem carregou o
ficheiro — e as camadas com a permissão **«Apagar ficheiros da equipa»** —
o possam apagar.

Uma ressalva que convém saber: os ficheiros que **já lá estão** não têm no
armazenamento nada que diga quem os carregou. Neles, a regra é só a do
ecrã — o botão não aparece a quem não deve, mas o servidor não o pode
impedir. A partir de agora, todos os novos ficam protegidos dos dois
lados.

### 4. Correr o `editar-mensagens.sql`

Sem nada para preencher. Traz a regra que deixa cada pessoa **editar as
suas próprias mensagens** — e só as suas. Sem ela, o botão de editar
aparece mas o servidor recusa em silêncio, e o texto novo fica só no
aparelho de quem o escreveu.

### 5. O resumo matinal

Duas partes: a função que o escreve e o agendamento que a acorda.

1. **Edge Functions** → **Deploy a new function**, nome exacto
   `resumo-matinal`, colar
   [`funcoes/resumo-matinal/index.ts`](funcoes/resumo-matinal/index.ts).
2. **SQL Editor** → colar [`agendar-resumo.sql`](agendar-resumo.sql).
   **Este tem uma linha para mudar: a 22**, onde se cola a chave
   `service_role` (*Project Settings → API → service_role → Reveal*). O
   ficheiro pára com um aviso claro se ela não estiver lá, ou se for a
   chave errada — mais vale parar do que ficar com um agendamento activo
   que falha todas as manhãs em silêncio. A chave fica guardada dentro do
   próprio Supabase, e nunca no site nem no repositório.

Sai às 06h30 de Luanda, de segunda a sábado. Cada pessoa recebe as tarefas
que lhe estão atribuídas e por fechar; cada equipa recebe o que está em
aberto na sua área, e recebe-o toda a gente dessa área — não só quem tem a
tarefa em mãos. Quem não tiver nada não recebe nada: uma caixa de correio
com um «não tem nada» diário acaba por ser ignorada, e com ela os dias em
que há mesmo alguma coisa.

Em **Admin → Sistema** há o botão **«Enviar o resumo matinal agora»**, para
o ver acontecer sem esperar pelo dia seguinte.

### 6. Instalar a função `criar-utilizador`

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
| 3 | [`ficheiros-pessoais.sql`](ficheiros-pessoais.sql) | Gaveta pessoal do Drive e anexos fechados na conversa |
| 4 | [`FALTA-CORRER.sql`](FALTA-CORRER.sql) | Pastas na área pessoal, e quem pode apagar no Drive da equipa |
| 5 | [`editar-mensagens.sql`](editar-mensagens.sql) | Editar a própria mensagem no Chat |
| 6 | [`agendar-resumo.sql`](agendar-resumo.sql) | O resumo matinal por e-mail |

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
-- 1. Todas devem estar protegidas
select tablename, rowsecurity as protegida
from pg_tables
where schemaname = 'public'
order by tablename;

-- 2. A CONSULTA MAIS ÚTIL DE TODAS.
--    As regras traduzem o e-mail de login para o id do directório. Quando
--    os dois não batem certo, a pessoa entra mas fica sem ver as suas
--    mensagens directas nem as suas tarefas pessoais — e nada no ecrã lhe
--    explica porquê. Isto mostra quem está nessa situação.
with directorio as (
  select e->>'name' as nome, lower(e->>'email') as email
  from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
  where s.id = 1 and e->>'email' is not null
),
contas as (
  select lower(email) as email from auth.users where email is not null
)
select
  coalesce(d.nome, '(sem ficha no directório)') as pessoa,
  d.email as no_directorio,
  c.email as no_login,
  case
    when d.email is null then 'entra, mas o servidor não sabe quem é'
    when c.email is null then 'está no directório e não consegue entrar'
    else 'ok'
  end as estado
from directorio d
full outer join contas c on c.email = d.email
order by 4, 1;

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

**Um aparelho diz «Desligado · modo local».** Está a usar uma versão antiga
da página, guardada na memória do navegador. O sintoma é característico: a
pessoa entra com a palavra-passe e consegue escrever, mas não recebe nada —
as mensagens dos outros nunca lhe aparecem. Recarregue à força (no telemóvel,
fechar o separador e voltar a abrir; no computador, `Ctrl`+`Shift`+`R`, ou
`Cmd`+`Shift`+`R` no Mac). Em **Admin → Sistema**, uma versão em dia diz que
a ligação vem do `servidor.js` e o indicador fica verde — os campos do
endereço e da chave aparecem preenchidos, e não é preciso lá tocar.

**Alguém não vê as suas mensagens directas, ou as suas tarefas pessoais.** O
e-mail com que essa pessoa entra não é o mesmo que está em
Admin → Utilizadores. As regras do servidor traduzem uma coisa na outra pelo
e-mail. Corrigir no directório resolve na hora.

**Criar utilizador dá erro.** A função `criar-utilizador` não está instalada,
ou tem outro nome. Tem de se chamar exactamente assim.

**O ecrã Seguimento diz que faltam tabelas.** O `INSTALAR-TUDO.sql` ainda não
correu.

**Um ecrã abre em branco.** A partir de agora não abre: aparece uma caixa com
a mensagem do erro e um botão para a copiar. Envie essa mensagem — é ela que
diz o que se passou.

Se for o **Chat** ou as **Permissões**, a causa conhecida são camadas de
acesso gravadas sem a lista de canais, pela primeira versão do
`camadas-editaveis.sql`. A aplicação já aguenta esses dados, mas convém
corrigi-los na base: corra o [`reparar-camadas.sql`](reparar-camadas.sql). Ele
acrescenta o que falta **sem apagar nada**, e mostra antes e depois.

**Grupos privados que desapareceram de um aparelho.** Foram criados enquanto
esse aparelho estava em «modo local» — nunca chegaram ao servidor, e ao ligar‑se
ele passou a usar a lista partilhada. Basta criá-los outra vez, uma só vez, em
qualquer aparelho ligado: daí em diante aparecem em todos.

**As mensagens chegam com atraso, ou parecem não chegar a alguns
aparelhos.** O indicador em Admin → Sistema diz qual dos dois casos é:

- *«sem tempo real, mensagens com atraso»* — a subscrição não ligou, e é a
  sondagem de recurso que está a fazer o trabalho. Corra o
  [`tempo-real.sql`](tempo-real.sql): quase sempre falta pôr as tabelas na
  publicação do tempo real.
- *«tempo real activo»* — a entrega é imediata. Se ainda assim alguém não
  recebe, é o e-mail dessa pessoa que não bate certo: o tempo real também
  respeita as regras de segurança, e sem saber quem ela é não lhe entrega
  nada. Use a consulta de diagnóstico acima.

Em qualquer dos casos, num telemóvel a página é suspensa em segundo plano
e a ligação adormece. Ao voltar à aplicação, ela vai buscar de imediato o
que ficou para trás.

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
