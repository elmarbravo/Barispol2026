# Barispol Workspace — versão reconstruída

Intranet da equipa do Centro Médico Barispol: mural, chat por canais, tarefas, calendário, drive partilhado, directório e administração.

## Estrutura

```
workspace/
├── workspace.html                → a aplicação
├── supabase-configuracao.sql     → SQL a correr uma vez no Supabase
├── vendor/
│   ├── react.production.min.js
│   ├── react-dom.production.min.js
│   ├── supabase.js
│   └── fontes/                   → Titillium Web, 10 ficheiros
└── LEIA-ME.md
```

Tudo é servido do próprio repositório. Não há ligação a servidores externos além do Supabase da clínica.

---

## O que mudou face à versão anterior

| Antes | Agora |
|---|---|
| Três contas com palavra-passe escritas dentro do ficheiro | Nenhuma conta no código; a entrada é sempre pelo Supabase Auth |
| «Modo seguro» opcional, desligado por omissão | O modo seguro é o único modo |
| Regras de acesso `using (true)` — qualquer pessoa com a chave lia e escrevia tudo | Regras limitadas a `authenticated`: sem sessão iniciada não se lê nada |
| Ficheiros do Drive guardados em texto dentro de uma linha da base de dados, limite de 500 KB | Ficheiros no armazenamento próprio do Supabase, balde privado, limite de 25 MB, ligações assinadas válidas por uma hora |
| `do $ ... $;` no SQL, que o Postgres rejeita — o tempo real nunca chegava a ficar activo | `do $$ ... $$;` correcto |
| Empacotador de 1,75 MB com React em versão de desenvolvimento e compilação no navegador | 400 KB de aplicação já compilada, React em versão de produção, sem compilação no navegador |

O arranque deixa de esperar pela compilação: a página abre de imediato.

---

## Instalação

O guia passo a passo, escrito para quem nunca usou o Supabase, está no documento que acompanha esta entrega. Resumo:

1. Criar conta e projecto em supabase.com.
2. **SQL Editor → New query**, colar o conteúdo de `supabase-configuracao.sql`, correr.
3. **Project Settings → API**: copiar o *Project URL* e a chave *anon public*.
4. Abrir o Workspace, ir a **Admin → Sistema → Servidor partilhado**, colar as duas e guardar.
5. **Authentication → Users → Add user**: criar uma conta por colaborador.
6. Repetir o passo 4 em cada dispositivo que vá usar o Workspace.

### Regras que não se quebram

- A chave a distribuir é a **anon public**. A `service_role` nunca sai do painel do Supabase e nunca entra em nenhum ficheiro.
- Quem sai da clínica é removido em **Authentication → Users**. A partir daí não entra, em nenhum dispositivo.
- A palavra-passe `B@rispol2022`, que estava exposta na versão anterior, deve ser considerada comprometida e substituída em todo o lado.

---

## Ficheiros e armazenamento

O balde `drive` é privado. Nada é servido publicamente: cada leitura gera uma ligação assinada válida por uma hora, e só para quem tem sessão iniciada.

Limite de 25 MB por ficheiro. O plano gratuito do Supabase inclui 1 GB de armazenamento e 500 MB de base de dados — para uma equipa de 10 a 30 pessoas dá folga, mas convém ver o consumo de vez em quando em **Storage → Usage**.

Ficheiros carregados na versão antiga, que ficaram guardados em texto dentro da base de dados, continuam a abrir. Novos carregamentos vão todos para o armazenamento.

---

## Saída de emergência

Se um dispositivo ficar preso no arranque, abrir o endereço com `#reset` no fim — por exemplo `workspace.html#reset`. Isso limpa a ligação guardada nesse dispositivo e permite voltar a introduzir as chaves.

---

## O que ficou por fazer

- As tarefas, o calendário, a lista de ficheiros e a equipa continuam a partilhar uma única linha na tabela `shared_state`. Funciona bem até cerca de 30 pessoas; acima disso vale a pena separar em tabelas próprias.
- Não há perfis com permissões diferentes dentro do Workspace: quem entra vê tudo. Separar recepção, clínica e coordenação exige regras por função no Supabase.
- Não há registo de quem apagou o quê. Para uma unidade de saúde, um registo de ocorrências no Workspace é o passo seguinte natural.

---

© 2026 Centro Médico Barispol · Camama, Luanda — Angola
