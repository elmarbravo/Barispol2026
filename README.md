# Centro Médico Barispol — Website

Pacote pronto para publicar. Tudo o que precisas está nesta pasta.

## 📁 Estrutura

```
barispol-website/
├── index.html        → Site público (página principal)
├── workspace.html    → Intranet "Barispol Workspace" (área interna)
├── assets/
│   ├── logo-barispol.png
│   └── facility.jpg
└── README.md         → Este ficheiro
```

> **Nota:** o `index.html` é autossuficiente — o logótipo e as imagens já estão embutidos no próprio ficheiro. A pasta `assets/` contém os originais, caso precises deles no futuro.

---

## 🚀 Como publicar no GitHub Pages

1. Cria (ou abre) o teu repositório no GitHub.
2. Coloca **o conteúdo desta pasta** na raiz do repositório (o `index.html` tem de ficar na raiz).
3. No GitHub: **Settings → Pages**.
4. Em *Build and deployment* → *Source*: escolhe **Deploy from a branch**.
5. Branch: **main** · pasta: **/ (root)** → **Save**.
6. Aguarda 1–2 minutos. O site fica disponível em `https://<utilizador>.github.io/<repositorio>/`.

### 🌐 Domínio próprio
1. Em **Settings → Pages → Custom domain**, escreve o teu domínio (ex: `www.barispol.com`) e **Save**.
   - Isto cria automaticamente um ficheiro `CNAME` no repositório.
2. No teu fornecedor de domínio, aponta o DNS para o GitHub Pages:
   - Registo **CNAME**: `www` → `<utilizador>.github.io`
   - (Para o domínio raiz, cria registos **A** para os IPs do GitHub Pages.)
3. Ativa **Enforce HTTPS** depois do domínio validar.

---

## 🔗 Ligações configuradas

| Onde | Liga a |
|---|---|
| Portal → **MetaGest** | `https://barispol.angolaerp.co.ao/app/metagest` (abre em nova aba) |
| Portal → **Barispol Workspace** | `workspace.html` (a intranet, neste mesmo repositório) |
| Secção **Inquérito** | O teu formulário do **Microsoft Forms** (embebido) |
| Portal → **Respostas ao Inquérito** | Abre o **Microsoft Forms** para veres as respostas |

> Para trocar o formulário do inquérito, procura `MS_FORM_ID` no `index.html` e substitui pelo `id=` do teu link do Forms.

---

## 🔐 Gestão de acessos (Área Reservada)

### Como funciona AGORA (protótipo)
- Entra em **Área Reservada** → faz login com a conta **Administrador**.
- Abre **Gestão de Acessos**: adiciona/remove colaboradores e define o **perfil** de cada um.
- Perfis e o que cada um vê:

| Perfil | MetaGest | Workspace | Gestor de Conteúdo | Inquéritos | Gerir acessos |
|---|:--:|:--:|:--:|:--:|:--:|
| **Administrador (TI)** | ✔ | ✔ | ✔ | ✔ | ✔ |
| **Receção** | ✔ | — | — | — | — |
| **Clínico** (médico/enfermagem) | — | ✔ | — | — | — |
| **Marketing** | — | ✔ | ✔ | ✔ | — |
| **Gestor / Coordenação** | ✔ | ✔ | ✔ | ✔ | — |

⚠️ **Importante:** neste protótipo, os utilizadores e as campanhas ficam guardados **no navegador** (localStorage) de cada dispositivo. Serve para demonstrar o funcionamento — **não é ainda uma autenticação real partilhada**.

### Para PRODUÇÃO (recomendado)
Como já usam **Microsoft (Forms / 365)**, o caminho mais natural é:
- **Microsoft Entra ID (Azure AD) — início de sessão único (SSO):** cada colaborador entra com a sua conta Microsoft do Barispol. A gestão de quem tem acesso passa a ser feita no **portal de administração da Microsoft 365**, e os perfis acima mapeiam-se a **grupos** do Entra.
- O ecrã de login já desenhado liga-se a este sistema na fase de implementação (com um programador).

Alternativas: um backend próprio, ou um serviço de autenticação (Auth0, Firebase). Em todos os casos, o **design já está pronto** — falta apenas a ligação técnica.

---

## ✏️ Editar campanhas (sem código)
Área Reservada → login (Admin ou Marketing) → **Gestor de Conteúdo**. Cria campanhas com título, descrição, período, origem (Instagram/TikTok/WhatsApp) e **link direto** para o post. Aparecem logo na secção *Campanhas* do site.

(Tal como os acessos, as campanhas criadas no protótipo ficam no navegador; em produção ligam-se ao mesmo backend.)

---

© 2026 Centro Médico Barispol · Camama, Luanda — Angola
