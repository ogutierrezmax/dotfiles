# 🔐 opencode-pf (Perfis Isolados do OpenCode)

> Perfis **isolados** do OpenCode: conta/API, configuração e dados por perfil, com
> servidor privado (`--standalone`) — sem vazar para o daemon compartilhado.

Este documento detalha a configuração atual do `opencode-pf`, o CLI de perfis do
OpenCode versionado nos dotfiles, que **substitui o `opencode-multi`** (broken no
opencode v2) com paridade total de features e 3 correções de isolamento.

## 🛠 Tech Stack
- **CLI**: [OpenCode](https://opencode.ai) v2+ (background service compartilhado por padrão)
- **Substituído**: [`opencode-multi`](https://github.com/dominic-codespoti/opencode-multi) — tool em Rust cujos 3 bugs de isolamento motivaram o wrapper
- **Wrapper**: Bash (`scripts/opencode-pf.sh`, ~190 linhas, `set -euo pipefail`, ShellCheck-clean)
- **Sandbox**: `ai-jail` (`~/bin/opencode` aplica o bubblewrap; `run --no-jail` abre o binário direto)

## ⚡ Configuração Atual (`scripts/opencode-pf.sh`)

O coração da correção é o comando `run`, que exporta o ambiente **do perfil** e
executa o opencode com **servidor privado** (fora do daemon compartilhado):

```bash
export OPENCODE_CONFIG_DIR="$cfg"      # config do perfil
export XDG_DATA_HOME="$data"           # data DO PERFIL (não o pai!)
export OPENCODE_PROFILE="$name"
exec "$bin" --standalone "$@"          # servidor privado — fora do daemon comum
```

Os perfis espelhados são declarados em `config/opencode-profiles.list`:

```
# formato: <perfil>|<dest relativo ao perfil>|<fonte relativa no repo>
ogtz|opencode.jsonc|data/.config/opencode/opencode.jsonc
ogtz|tui.json|data/.config/opencode/tui.json
ogtz|AGENTS.md|data/.config/opencode/AGENTS.md
ogtz|rules/agents-symlink.mdc|data/.config/opencode/rules/agents-symlink.mdc
alfokoji|opencode.json|data/.config/opencode-multi/profiles/alfokoji/opencode.json
```

> `ogtz` espelha a config normal por **fonte única** (symlinks para os MESMOS
> arquivos do repo); `alfokoji` tem scaffold mínimo versionado.

## 🗺 Estrutura de Arquivos

**No repositório:**
- `scripts/opencode-pf.sh`: CLI principal (`create/list/show/run/clone/remove/doctor`)
- `scripts/install-opencode-profiles.sh`: reconstrói os symlinks por-perfil (idempotente, backup em `.bkp/`)
- `config/opencode-profiles.list`: declaração `<perfil>|<dest>|<fonte>` dos arquivos versionados
- `data/.local/bin/opencode-pf`: launcher → `~/.local/bin/opencode-pf` (via `dotfile-names.list`)
- `data/.config/opencode-multi/profiles/alfokoji/opencode.json`: scaffold mínimo (só `$schema`)

**No ambiente (por perfil):**

```
~/.config/opencode-multi/profiles/<nome>/       ← config (parcialmente versionável)
    opencode.json(c)                 config do opencode
    cli.json, service.json           SENSÍVEIS (mode 600, nunca versionados)
    node_modules/, package*.json     runtime (nunca versionados)
~/.local/share/opencode-multi/profiles/<nome>/   ← data (auth, sessões)
    opencode/auth.json               credenciais DESTE perfil
    opencode/opencode.db             sessões DESTE perfil
```

## 🔒 Segurança

- **Arquivos versionados**: apenas os declarados em `config/opencode-profiles.list`
  (configs de `ogtz`/`alfokoji` + scaffold) e o próprio código dos scripts — todos
  auditados sem segredos nem caminhos absolutos de máquina.
- **Arquivos excluídos (sensíveis/gerados)**: `auth.json`, `cli.json`,
  `service.json` (mode 600), `node_modules/`, `package.json`, `package-lock.json`,
  `.gitignore` — ficam locais por perfil; o instalador **nunca os toca**.
- **Guardrails aplicados**: header `SECURITY NOTE` no topo dos scripts; validação
  de nome de perfil (regex `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`); `remove` exige
  confirmação (ou `--yes` explícito) e usa `${CONFIG_ROOT:?}`/`${DATA_ROOT:?}`
  contra `rm -rf /`; `clone` **não propaga** `auth.json` nem o banco de sessões
  (login novo via `/connect`); `--init` copia config **sem** segredos/runtime.

## 🚀 Como instalar (Manual)

1. **Instale o OpenCode v2** (o launcher usa o binário do PATH ou
   `~/.opencode/bin/opencode`).
2. **Ative os symlinks** (config principal + launcher `opencode-pf`):
   ```bash
   ./dotfiles-menu.sh        # ou ./scripts/install-dotfiles.sh
   ```
3. **Reconstrua os perfis versionados** (ou use o comando `profiles` no menu):
   ```bash
   ./scripts/install-opencode-profiles.sh
   ```
4. **Crie/use um perfil**:
   ```bash
   opencode-pf create trabalho --init   # espelha config padrão (sem segredos)
   opencode-pf run trabalho             # dentro: /connect para autenticar
   ```

## 📖 Paridade de features com o `opencode-multi`

| `opencode-multi` | `opencode-pf` | Correção vs. original |
| :--- | :--- | :--- |
| `create <n>` | `create <n>` | idem (scaffold + subdirs) |
| `create <n> --init` | `create <n> --init [--with-auth]` | dados copiados para `<perfil>/opencode/` (não raiz); sem segredos/runtime |
| `list` | `list` | status checa `<perfil>/opencode/auth.json` (lugar certo) |
| `show <n>` | `show <n>` | idem + auth/tamanho |
| `run <n>` | `run <n> [-- args]` | `XDG_DATA_HOME` **por perfil** + `--standalone` (servidor privado) |
| `clone <a> <b>` | `clone <a> <b>` | copia config sem credenciais; auth novo |
| `remove <n>` | `remove <n> [--yes]` | idem + confirmação explícita |
| — | `doctor` | diagnóstico: daemon compartilhado, resíduos, status dos perfis |
| `-a/--all` variantes | (não portadas) | argumentos globais não fazem sentido no wrapper |

## 📖 Por que wrapper e não plugin/fork

- **Plugin inviável**: roda dentro do processo opencode — tarde demais para
  redirecionar env/auth/daemon decididos no startup.
- **Fork descartado**: herdar projeto Rust (~centenas de linhas de infra) para
  ~30 linhas de lógica corrigida seria overkill.
- **Wrapper no dotfiles**: ~190 linhas de Bash com paridade 1:1, versionado
  junto com os perfis, usando as fronteiras de segurança existentes do repo.

## 📖 O que é isolado × o que não é

| Isolado por perfil | Compartilhado (aceitável) |
| :--- | :--- |
| Config (`OPENCODE_CONFIG_DIR`) | Cache (`~/.cache/opencode`) |
| Auth/sessões/dados (`XDG_DATA_HOME` → `<perfil>/opencode/`) | State (`~/.local/state/opencode`) |
| Servidor (`--standalone` — privado) | Daemon padrão do opencode v2 (outro processo, env original) |

## 🧯 Troubleshooting

- **`doctor` avisa "background service compartilhado ATIVO"**: é o daemon padrão
  do opencode v2. Sessões dele seguem em `~/.local/share/opencode/`; os perfis
  rodam privados via `opencode-pf run` — o aviso é informativo.
- **Perfil `needs-auth` com `auth.json` presente**: no `opencode-multi` era o
  bug 2 (auth órfã na raiz). Aqui `list`/`show` checam o lugar certo
  (`<perfil>/opencode/auth.json`).
- **Resíduos de execução antiga**: `~/.local/share/opencode-multi/profiles/opencode/`
  (skeleton do env quebrado), dados órfãos de perfis (ex.: `opencode.db` copiada
  pelo `--init` original) — não são lidos pelo `opencode-pf`; conferir com
  `opencode-pf show <nome>` e remover manualmente.

---
*Este documento foi gerado durante o onboarding do opencode-profiles nos dotfiles.*