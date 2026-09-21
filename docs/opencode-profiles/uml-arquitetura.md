# 📐 Diagrama de Arquitetura — Isolamento por Perfil

> Como o `opencode-pf` expõe a cada perfil apenas a sua config/dados, iniciando
> um **servidor privado** (`--standalone`) em vez de conectar no daemon
> compartilhado do opencode v2.

```mermaid
flowchart TB
    U["Usuário\nopencode-pf run &lt;perfil&gt;"]
    RUN["opencode-pf run\nvalida nome → exporta env → exec --standalone"]

    subgraph CFG["CONFIG — ~/.config/opencode-multi/profiles/&lt;perfil&gt;"]
        C1["opencode.json(c)\nversionado (ogtz: symlink fonte única)"]
        C2["cli.json · service.json\nlocais · mode 600 · nunca versionados"]
        C3["node_modules · package*.json\nruntime · locais · nunca versionados"]
    end

    subgraph DAT["DATA — ~/.local/share/opencode-multi/profiles/&lt;perfil&gt;/opencode"]
        D1["auth.json\ncredenciais DO PERFIL"]
        D2["opencode.db\nsessões DO PERFIL"]
    end

    SVC["opencode --standalone\nSERVIDOR PRIVADO (nasce com o env do perfil)"]

    subgraph DAE["daemon compartilhado do opencode v2 — NÃO usado pelo perfil"]
        E1["env original (sem OPENCODE_CONFIG_DIR / XDG_DATA_HOME do perfil)"]
        E2["~/.local/share/opencode/*\nauth e sessões do perfil padrão"]
    end

    U --> RUN
    RUN -->|"env:\nOPENCODE_CONFIG_DIR\nXDG_DATA_HOME=&lt;perfil&gt;\nOPENCODE_PROFILE"| SVC
    SVC -->|"lê"| C1
    SVC -.->|"lê (local)"| C2
    SVC -.->|"runtime local"| C3
    SVC -->|"lê/grava"| D1
    SVC -->|"lê/grava"| D2
    SVC -. "--standalone: não conecta" .-> DAE
```

## Leitura do diagrama

| Elemento | Significado |
| :--- | :--- |
| **Linha sólida para config/dados** | O servidor privado lê/grava **somente** o que está dentro do perfil |
| **Linha tracejada para `cli.json`/`service.json`/runtime** | Existem locais (por perfil), mas são sensíveis/gerados — nunca versionados |
| **Tracejado `--standalone` → daemon** | O que o **bug #3** do `opencode-multi` fazia era conectar nesse daemon; o correto é **não** conectar (servidor privado) |
| **`DAE` (daemon compartilhado)** | Continua servindo sessões do perfil padrão (env original) — não é tocado pelos perfis |

## Por que XDG_DATA_HOME é o ponto crítico

O opencode v2 resolve o diretório de dados como `$XDG_DATA_HOME/opencode`. O
`opencode-multi` setava `XDG_DATA_HOME` no **pai** dos perfis
(`.../profiles/`), então todos os perfis resolviam o mesmo
`.../profiles/opencode/` (bug #1). O `opencode-pf run` aponta
`XDG_DATA_HOME` para o **próprio perfil** (`.../profiles/<perfil>`), fazendo o
opencode resolver `.../profiles/<perfil>/opencode/` — auth e sessões ficam
**isolados por perfil**.

---
*Diagrama gerado durante o onboarding do opencode-profiles nos dotfiles.*