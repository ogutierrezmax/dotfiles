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
exec "$bin" "$@" --standalone          # servidor privado — `--standalone` no FIM
```

> `--standalone` é posicionado **após** os args: o CLI do opencode v2 rejeita o
> flag antes de um subcomando (`opencode --standalone auth list` → *Unrecognized
> flag*), mas aceita no fim (`opencode auth list --standalone`). Isso garante que
> `run <perfil> <subcomando>` (ex.: `run ogtz auth list`) funcione — e o TUI puro
> (`run ogtz`) vira `opencode --standalone`, idêntico ao comportamento anterior.

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
- **Onde vivem as credenciais (v2)**: no opencode v2, auth fica na tabela
  `credential` do SQLite (`<perfil>/opencode/opencode.db`) — o `auth.json` é o
  formato **legado do V1**, importado na migração. Não existe export/import no CLI.
- **Arquivos excluídos (sensíveis/gerados)**: `cli.json`, `service.json`
  (mode 600), `node_modules/`, `package.json`, `package-lock.json`, `.gitignore`
  — ficam locais por perfil; o instalador **nunca os toca**.
- **Credenciais só entram com opt-in explícito**: `create --init` e
  `create --with-auth` copiam do perfil padrão **apenas a tabela `credential`**
  do SQLite (sem sessões/storage de mensagens) + `auth.json` legado, se presente.
  Sem esses flags, o script nunca lê/escreve/versiona segredos.
- **Guardrails aplicados**: header `SECURITY NOTE` no topo dos scripts; validação
  de nome de perfil (regex `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`); `remove` exige
  confirmação (ou `--yes` explícito) e usa `${CONFIG_ROOT:?}`/`${DATA_ROOT:?}`
  contra `rm -rf /`; `clone` **não propaga** `auth.json` nem o banco de sessões
  (login novo via `/connect`); `--init` copia config **sem** segredos de
  config/runtime (`cli.json`, `service.json`, `node_modules/`).

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
   opencode-pf create trabalho --init   # espelha config do padrão + credenciais (SQLite 'credential' + auth.json legado)
   opencode-pf run trabalho auth list   # providers deste perfil (servidor privado)
   opencode-pf run trabalho             # TUI; dentro: /connect para adicionar outra conta
   ```

## 🔧 Como adicionar um novo perfil ao repo

1. **Crie o arquivo scaffold** no repo (copie o padrão existente):
   ```bash
   cp data/.config/opencode-multi/profiles/alfokoji/opencode.json \
      data/.config/opencode-multi/profiles/<nome>/opencode.json
   mkdir -p data/.config/opencode-multi/profiles/<nome>
   ```
2. **Liste os arquivos versionados** em `config/opencode-profiles.list`:
   ```
   <nome>|opencode.json|data/.config/opencode-multi/profiles/<nome>/opencode.json
   # Para espelhar a config normal (fonte única):
   <nome>|opencode.jsonc|data/.config/opencode/opencode.jsonc
   <nome>|tui.json|data/.config/opencode/tui.json
   ```
3. **Commit** os novos arquivos + a lista atualizada.
4. **Execute** `opencode-pf doctor` ou `./scripts/install-opencode-profiles.sh`
   para criar os symlinks no ambiente.

## 🔐 Como saber em qual perfil estou (badge dentro do opencode)

O `opencode-pf run <perfil>` exporta `OPENCODE_PROFILE` antes do `exec`, e um
**plugin CLI (TUI)** versionado renderiza um badge com o nome do perfil **dentro
do próprio opencode** — sem tocar no título da janela/terminal.

- **O que mostra**: `🔐 <perfil>` no rodapé da home e junto ao prompt (slots
  `home.footer.status` / `prompt.footer.status` — *status contributions*, após
  os health indicators e antes da versão).
- **Jail vs `--no-jail`**: o ícone reflete o sandbox via `OPENCODE_PF_JAIL`
  (exportado pelo script): `🔐 <perfil>` com ai-jail ativo; `🤞 <perfil>`
  (dedos cruzados) com `--no-jail` — binário direto, sem sandbox. Ausente →
  `🔐` (conservador).
- **Quando aparece**: somente com `OPENCODE_PROFILE` setado (via `opencode-pf run`).
  `opencode` puro (sem perfil) não renderiza nada.
- **Como funciona a descoberta**: o plugin é carregado automaticamente de
  `<config-dir>/plugins/profile-status/tui.tsx`, onde `<config-dir>` é o
  `OPENCODE_CONFIG_DIR` do perfil (`~/.config/opencode-multi/profiles/<nome>`).
  O `.tsx` com JSX é aceito pelo discovery do v2.0.12 sem build prévio.
- **Fonte única**: `data/.config/opencode/plugins/profile-status/tui.tsx`;
  `plugins/profile-status` em cada perfil é symlink criado pelo
  `install-opencode-profiles.sh`. Nada é adicionado ao `cli.json` (sensível/local).
- **Perfil novo**: basta incluir no `config/opencode-profiles.list` e rodar o
  instalador:
  ```
  <nome>|plugins/profile-status|data/.config/opencode/plugins/profile-status
  ```

## 📖 Paridade de features com o `opencode-multi`

| `opencode-multi` | `opencode-pf` | Correção vs. original |
| :--- | :--- | :--- |
| `create <n>` | `create <n>` | idem (scaffold + subdirs) |
| `create <n> --init` | `create <n> --init [--with-auth]` | dados copiados para `<perfil>/opencode/` (não raiz); sem segredos de config/runtime — **e agora copia credenciais** (SQLite `credential` + auth.json legado) |
| `list` | `list` | status checa `<perfil>/opencode/auth.json` **ou** a tabela `credential` do SQLite do perfil |
| `show <n>` | `show <n>` | idem + auth/tamanho |
| `run <n>` | `run <n> [-- args]` | `XDG_DATA_HOME` **por perfil** + `--standalone` no fim dos args (aceita subcomandos: `run <n> auth list`) |
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
| Auth/sessões/dados (`XDG_DATA_HOME` → `<perfil>/opencode/`; credenciais na tabela `credential` do SQLite + `auth.json` legado) | State (`~/.local/state/opencode`) |
| Servidor (`--standalone` — privado) | Daemon padrão do opencode v2 (outro processo, env original) |

## 📐 Diagramas

- [📐 Arquitetura do isolamento](./uml-arquitetura.md) — o que cada perfil vê
  (config/dados privados) e o que o wrapper contorna (daemon compartilhado).
- [📐 Sequência do `run` (quebrado × corrigido)](./uml-sequencia.md) — fluxo do
  `opencode-multi` (perfil inerte) versus o `opencode-pf` (servidor privado com
  env do perfil).
- [📐 Ciclo de vida do perfil](./uml-ciclo-de-vida.md) — estados
  `missing`/`needs-auth`/`healthy` e as transições de cada comando da CLI.

## 🧯 Troubleshooting

- **`doctor` avisa "background service compartilhado ATIVO"**: é o daemon padrão
  do opencode v2. Sessões dele seguem em `~/.local/share/opencode/`; os perfis
  rodam privados via `opencode-pf run` — o aviso é informativo.
- **Perfil `needs-auth` com credencial presente**: no `opencode-multi` era o
  bug 2 (auth órfã na raiz). Aqui `list`/`show` checam o lugar certo —
  `<perfil>/opencode/auth.json` **ou** a tabela `credential` do SQLite
  (`<perfil>/opencode/opencode.db`), que é onde o v2 guarda auth de verdade.
- **Resíduos de execução antiga** (artefatos do env quebrado do `opencode-multi`,
  **não usados pelo `opencode-pf`** — conferir e remover manualmente, com
  confirmação, para liberar ~2,4 GB):
  ```bash
  # skeleton compartilhado (bug 1) — 16K
  ~/.local/share/opencode-multi/profiles/opencode
  # dados órfãos do perfil (bug 2: cópia no lugar errado) — ~2,4 GB
  ~/.local/share/opencode-multi/profiles/ogtz          # (2,4 GB de opencode.db)
  # artefatos pequenos do mesmo env quebrado
  ~/.local/share/opencode-multi/profiles/opencode-multi
  ~/.local/share/opencode-multi/profiles/opentui
  ```
  Os dados **reais** ficam em `~/.local/share/opencode/` (auth + `opencode.db` do
  daemon) — **não** removê-los.

---
*Este documento foi gerado durante o onboarding do opencode-profiles nos dotfiles.*