# 🔐 opencode-profiles (opencode-pf)

> Perfis **isolados** do OpenCode: conta/API, configuração e dados por perfil,
> com servidor privado (`--standalone`) — sem vazar para o daemon compartilhado.

Este documento detalha o `opencode-pf`, o CLI de perfis que **substitui o
`opencode-multi`** no repo de dotfiles, corrigindo 3 bugs de isolamento do
original.

## ⚠️ Por que isso existe: o `opencode-multi` não isola de verdade

O `opencode-multi` (github.com/dominic-codespoti/opencode-multi) foi criado
para a arquitetura **v1** do opencode (um processo por sessão). No **v2**, o
opencode roda um **background service compartilhado** que "owns sessions,
configuration, integrations, permissions and tool execution" — e o
`opencode-multi` não foi atualizado para isso. O resultado: os perfis eram
**inertes** — o cliente conectava no daemon comum (com o env original), e a
conta/API de um perfil nunca chegava a quem executava.

Prova dos 3 bugs no código do `opencode-multi`:

| # | Bug | Evidência |
| :- | :--- | :--- |
| 1 | `run` seta `XDG_DATA_HOME` no **pai** do perfil (`.../profiles`), então o opencode resolve data = `profiles/opencode` — **compartilhado entre todos os perfis** | `opencode debug paths` sob `opencode-multi run <perfil>` sempre mostra `data: .../profiles/opencode` |
| 2 | `create --init` copia os dados para a **raiz do perfil** em vez de `<perfil>/opencode/` → `auth.json` órfã | `opencode-multi list` reporta `needs-auth` mesmo com `auth.json` real presente |
| 3 | O tool ignora o background service: o cliente **conecta no daemon compartilhado** (env original) em vez de subir um servidor privado | `run` abre a TUI, mas as sessões/auth são do daemon original (`~/.local/share/opencode/opencode.db`) |

## 🧰 Solução: wrapper próprio (`scripts/opencode-pf.sh`)

Wrapper bash (~180 linhas) com **paridade 1:1 de features** do `opencode-multi`
+ as 3 correções:

```
opencode-pf <comando> [args...]

  create <nome> [--init] [--with-auth]   Cria perfil (--init: espelha ~/.config/opencode
                                         sem segredos; --with-auth: copia auth.json do padrão)
  list                                   Lista perfis e status (config/auth)
  show <nome>                            Detalhes de um perfil
  run <nome> [-- args]                   Roda opencode ISOLADO por perfil
  clone <src> <dst>                      Copia um perfil (sem auth.json/sessões)
  remove <nome> [--yes]                  Remove perfil e seus dados
  doctor                                 Diagnóstico de perfis/ambiente
```

As **3 correções deliberadas** em relação ao `opencode-multi`:

1. **`run`** exporta `OPENCODE_CONFIG_DIR` (config do perfil), `XDG_DATA_HOME` =
   **data do próprio perfil** (`~/.local/share/opencode-multi/profiles/<nome>`)
   e `OPENCODE_PROFILE`; e executa `opencode --standalone` → **servidor
   privado**, fora do background service compartilhado.
2. **`init`** espelha a config padrão para `<perfil>/` **excluindo** segredos
   (`cli.json`, `service.json`, `auth.json`) e runtime (`node_modules`,
   `package*.json`). Autenticação é feita **depois**, via `/connect` dentro do
   opencode (ou `--with-auth` para herdar o login do perfil padrão).
3. **dados de sessão** vão para `<perfil>/opencode/` — cada perfil tem o próprio
   `opencode.db`, `auth.json`, plugins instalados, etc.

### Para rodar um perfil

```bash
# cria (scaffold mínimo + subdirs de config)
opencode-pf create trabalho

# espelha a config padrão (sem segredos) e autentica do zero
opencode-pf create trabalho --init
opencode-pf run trabalho        # dentro: /connect

# herdar o login do perfil padrão (atenção: mesma conta nos dois)
opencode-pf create trabalho --init --with-auth
```

> O `run` respeita o wrapper `~/bin/opencode` (aplica o ai-jail). Use
> `opencode-pf run <nome> --no-jail` para abrir o binário direto.

## 🗂 Estrutura dos perfis

```
~/.config/opencode-multi/profiles/<nome>/     ← config (versionável)
    opencode.json(c)                          ← config do opencode
    cli.json, service.json                    ← SENSÍVEIS (mode 600, nunca versionados)
    node_modules/, package*.json              ← runtime (nunca versionados)
~/.local/share/opencode-multi/profiles/<nome>/ ← data (auth, sessões, plugins)
    opencode/auth.json                        ← credenciais deste perfil
    opencode/opencode.db                      ← sessões deste perfil
```

- **Versionados no repo**: só entram no `config/opencode-profiles.list` os
  arquivos seguros (ex.: `ogtz` espelha `opencode.jsonc`/`tui.json`/`AGENTS.md`
  da config normal — **fonte única**, e `alfokoji` tem o scaffold mínimo).
- **Nunca versionados**: `auth.json`, `cli.json`, `service.json`,
  `node_modules/`, `package*.json` — ficam locais, por perfil.

### O que NÃO é isolado (aceitável/compartilhado)

- **cache**: `~/.cache/opencode` — compartilhado entre perfis.
- **state**: `~/.local/state/opencode` — compartilhado.

## 🔩 Wiring no repo

| Arquivo | Papel |
| :--- | :--- |
| `config/opencode-profiles.list` | Definição dos symlinks por-perfil (formato `<perfil>\|<dest>\|<fonte no repo>`) |
| `scripts/install-opencode-profiles.sh` | Reconstrói os symlinks (idempotente; backup em `.bkp/`; preserva segredos locais) |
| `scripts/opencode-pf.sh` | CLI de perfis (script principal) |
| `data/.local/bin/opencode-pf` | Launcher → `~/.local/bin/opencode-pf` (via dotfile-names.list) |
| `dotfiles-menu.sh` | Comando `profiles` roda o instalador |

## 🧯 Troubleshooting

- **`doctor` avisa "background service compartilhado ATIVO"**: é o daemon
  padrão do opencode v2 rodando no env original. As sessões dele continuam no
  `~/.local/share/opencode`. Os perfis rodam via `opencode-pf run` (privado) —
  o aviso é informativo.
- **Perfil `needs-auth` com `auth.json` lá**: no `opencode-multi` isso era o
  bug 2. No `opencode-pf`, `list`/`show` checam o lugar certo:
  `<perfil>/opencode/auth.json`.
- **Resíduo `~/.local/share/opencode-multi/profiles/opencode/`**: skeleton
  criado pelo env quebrado do `opencode-multi` (bug 1). Não é usado pelos
  perfis — pode remover.
- **Dados órfãos do perfil** (ex.: `opencode.db` copiado no lugar errado pelo
  `create --init` do `opencode-multi`): não são lidos pelo `opencode-pf`;
  conferir com `opencode-pf show <nome>` e remover manualmente se confirmado.