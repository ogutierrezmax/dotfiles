# 📐 Diagrama de Estados — Ciclo de Vida de um Perfil

> Os estados correspondem ao status que `opencode-pf list` reporta para cada
> perfil (`missing` → `needs-auth` → `healthy`), e as transições aos comandos
> da CLI.

```mermaid
stateDiagram-v2
    direction LR
    [*] --> missing : sem diretório em ~/.config/opencode-multi/profiles/

    missing --> needs_auth : create &lt;perfil&gt; [--init]
    missing --> needs_auth : clone &lt;origem&gt; &lt;destino&gt; (sem credenciais)

    needs_auth --> healthy : run &lt;perfil&gt; + /connect\n(auth.json em &lt;perfil&gt;/opencode/)
    needs_auth --> healthy : create --with-auth\n(herda login do perfil padrão)

    healthy --> needs_auth : auth.json removido / expirado

    healthy --> missing : remove &lt;perfil&gt; [--yes]
    needs_auth --> missing : remove &lt;perfil&gt; [--yes]
```

## Observações

- **`missing`** — sem `opencode.json(c)` no perfil: a CLI se recusa a `run`
  ("crie com `opencode-pf create <perfil>`").
- **`needs-auth`** — config presente, mas `auth.json` ausente em
  `<perfil>/opencode/`: `list` mostra `needs-auth`.
- **`healthy`** — `auth.json` presente no lugar certo: `list` mostra `healthy`.
- `create --init` produz config espelhada **sem segredos** (a transição
  `create` → `needs_auth` vale para os dois casos); `--with-auth` é a única
  transição que já nasce em `healthy`.
- `clone` nasce em `needs_auth` de propósito: **não propaga credenciais** nem o
  banco de sessões (login novo via `/connect`).
- `list`, `show` e `doctor` são comandos de leitura — não alteram o estado.

---
*Diagrama gerado durante o onboarding do opencode-profiles nos dotfiles.*