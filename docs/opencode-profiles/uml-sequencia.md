# 📐 Diagrama de Sequência — `run`: fluxo quebrado × fluxo corrigido

> O mesmo comando "rodar um perfil" — antes (`opencode-multi`, quebrado no
> opencode v2) e depois (`opencode-pf`, corrigido).

## Fluxo quebrado — `opencode-multi run <perfil>`

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant OM as opencode-multi run <perfil>
    participant SVC as daemon compartilhado (env ORIGINAL)
    participant DB as ~/.local/share/opencode/opencode.db

    U->>OM: opencode-multi run <perfil>
    OM->>OM: XDG_DATA_HOME = PAI dos perfis (profiles/)
    Note over OM: bug 1 — data resolvida = profiles/opencode\n(compartilhada entre TODOS os perfis)
    OM->>SVC: conecta no daemon já ativo (sem --standalone)
    Note over OM: bug 3 — o env do perfil\nNUNCA chega a quem executa
    SVC->>DB: sessões/auth do env ORIGINAL
    SVC-->>U: TUI usa a conta padrão — perfil é INERTE
```

## Fluxo corrigido — `opencode-pf run <perfil>`

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant PF as opencode-pf run <perfil>
    participant OP as opencode --standalone (servidor privado)
    participant CFG as config do perfil (~/.config/opencode-multi/profiles/<perfil>)
    participant DAT as data do perfil (.../profiles/<perfil>/opencode)

    U->>PF: opencode-pf run <perfil> [-- args]
    PF->>PF: valida nome (regex) e existência do perfil
    PF->>PF: exporta OPENCODE_CONFIG_DIR, XDG_DATA_HOME=<perfil>, OPENCODE_PROFILE
    PF->>OP: exec opencode --standalone <args>
    OP->>CFG: lê opencode.json(c) DO PERFIL
    OP->>DAT: lê auth.json DO PERFIL (credenciais certas)
    OP->>DAT: grava sessões em opencode.db DO PERFIL
    OP-->>U: TUI isolada — o servidor NASCEU com o env do perfil
```

## O que muda entre os dois fluxos

| # | `opencode-multi` (quebrado) | `opencode-pf` (corrigido) |
| :- | :--- | :--- |
| 1 | `XDG_DATA_HOME` aponta para o **pai** (`profiles/`) → data compartilhada | Aponta para o **próprio perfil** (`profiles/<perfil>`) → data privada |
| 2 | — | `auth.json` lido do lugar **certo** (`<perfil>/opencode/auth.json`) — era o bug #2 (auth órfã na raiz do perfil) |
| 3 | Conecta no **daemon compartilhado** (env original) | Sobe **servidor privado** com `--standalone` — o env do perfil chega ao processo que executa |

---
*Diagrama gerado durante o onboarding do opencode-profiles nos dotfiles.*