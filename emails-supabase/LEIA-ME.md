# E-mails do Supabase com o aspecto aprovado (26-09-2026)

Modelos para colar no painel do Supabase, projecto Barispol
(`gnqleaxrtuerlcrriqqs`): **Authentication → Emails** (Templates).
Em cada modelo: apagar o que lá estiver, colar o assunto e o HTML deste
ficheiro, e carregar em **Save**. As partes `{{ .ConfirmationURL }}`,
`{{ .Email }}` e `{{ .NewEmail }}` ficam como estão: o Supabase
troca-as ao enviar.

| Modelo no painel | Assunto | Ficheiro |
|---|---|---|
| Reset Password | Repor a palavra-passe do Workspace | `repor-palavra-passe.html` |
| Confirm signup | Confirme a sua conta do Workspace | `confirmar-conta.html` |
| Invite user | Convite para o Workspace da equipa | `convite.html` |
| Magic Link | A sua ligação para entrar no Workspace | `ligacao-de-entrada.html` |
| Change Email Address | Confirme o novo endereço de e-mail | `mudar-email.html` |

Aspecto aprovado pelo Elmar a 26-09-2026 (ver `CLAUDE.md`).
