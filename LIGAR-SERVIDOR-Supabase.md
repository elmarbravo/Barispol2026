# Ligar o Barispol Workspace a um servidor real (Supabase)

Com o servidor ligado, o **chat e o mural (Feed) passam a funcionar em tempo real entre todos** — telemóveis, computadores, qualquer pessoa da equipa vê as mesmas mensagens. Sem servidor, o Workspace continua a funcionar, mas só **neste dispositivo**.

Demora ~5 minutos. Só precisa de fazer isto **uma vez**.

---

## Passo 1 — Criar conta Supabase (grátis)
1. Vá a **https://supabase.com** → **Start your project** → entre com o GitHub ou e-mail.
2. **New project**:
   - **Name:** `barispol-workspace`
   - **Database Password:** escolha uma forte e **guarde-a**.
   - **Region:** escolha a mais próxima (ex.: *West EU (London)*).
3. Espere ~2 min enquanto o projeto é criado.

## Passo 2 — Criar as tabelas
1. No menu lateral do Supabase, abra **SQL Editor** → **New query**.
2. No Workspace: **Admin → Sistema → Servidor partilhado → "Copiar SQL de configuração"**.
3. Cole o SQL no editor do Supabase e clique **Run**. Deve aparecer *Success*.

## Passo 3 — Obter as 2 chaves
No Supabase: **Project Settings (engrenagem) → API**. Vai precisar de:
- **Project URL** — algo como `https://xxxxxxxx.supabase.co`
- **anon public** (a chave que começa por `eyJ…`) — **use só esta**, nunca a `service_role`.

## Passo 4 — Ligar no Workspace
1. No Workspace: **Admin → Sistema → Servidor partilhado**.
2. Cole o **URL do projeto** e a **Chave anónima**.
3. **Guardar e ligar.** A página recarrega e o estado fica **🟢 Ligado · tempo real activo**.
4. Faça o mesmo (Passo 4) em **cada dispositivo** que vá usar o Workspace — basta colar as mesmas 2 chaves.

---

## Verificar
Abra o Workspace em dois dispositivos (ou dois separadores), entre no mesmo canal de chat e envie uma mensagem. Deve aparecer **nos dois em segundos**. ✅

## Notas de segurança
- A configuração atual deixa as tabelas **abertas** (qualquer pessoa com as chaves lê/escreve). É adequado para uso interno com as chaves só na mão da equipa.
- Para reforçar (recomendado numa fase seguinte): ativar **Supabase Auth** e regras de acesso por utilizador. Posso tratar disto quando quiser.
- **Nunca** publique a chave `service_role` nem a coloque no site público.

## Resolução de problemas
- **"Erro de ligação"** → confirme que correu o SQL (Passo 2) e que copiou o **anon public** (não a service_role).
- **Mensagens não aparecem noutro dispositivo** → confirme que correu as 2 últimas linhas do SQL (`alter publication … add table …`), que ativam o tempo real.
- **Sem internet** → o servidor precisa de ligação; offline, o Workspace volta ao modo local.
