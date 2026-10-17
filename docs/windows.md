# 🪟 Windows (nativo)

> Fluxo de instalação **independente** do Linux: lista própria (`config/dotfile-names-windows.list`), scripts próprios (`.ps1`) e fallback de links que funciona **sem admin**.

Este documento detalha a adaptação do repo (Linux-first) para Windows nativo. Os fluxos Linux
(`scripts/install-dotfiles.sh` + `config/dotfile-names.list`) e os `.sh` em geral são **intocados** —
o Windows nunca os lê nem os modifica, e vice-versa.

## 🛠 Tech Stack
- **Lista**: `config/dotfile-names-windows.list` — 13 entradas, formato `<src em data/>|<dest>`
- **Instalador**: `scripts/install-dotfiles.ps1` (`-Yes` / `-Status` / `-Remove`)
- **Biblioteca**: `scripts/dotfiles-lib.ps1` (funções compartilhadas pelos `.ps1`)
- **Bridge de skills**: `scripts/install-agent-skills-bridge.ps1` (port 1:1 do `.sh`; usa `config/agent-skills-bridge.list` **compartilhado** entre OSes)
- **Git config**: `data/windows/gitconfig` (autocontido — o `data/gitconfig` Linux é puro bash)
- **Destinos**: `~` (home) e `%APPDATA%` (Cursor)

## 🗺 Por que existe

O repo assume Linux (`ln -s`, `$HOME`, caminhos XDG). No Windows nativo:

- **Symlink sem admin falha nesta máquina** (Developer Mode no registro
  `AllowDevelopmentWithoutDevLicense=1` exige re-login p/ valer). Logo, o instalador precisa de
  fallback: **dirs → Junction** (funciona sem admin, testado), **files → cópia** com aviso.
- **PS 5.1 lê `.ps1` sem BOM como ANSI** → os 3 scripts `.ps1` carregam UTF-8 BOM obrigatório.
- **Colons são ilegais em nomes de arquivo Windows** → slug de backup usa `HH-MM` (não `HH:mm` como no bash).
- OpenCode no Windows lê `~/.config/opencode`; WezTerm lê `~/.wezterm.lua` (docs oficiais confirmados).

## ⚙️ Configuração: `config/dotfile-names-windows.list`

Formato: `<src relativo a data/>|<destino>` — destino aceita `~` (expandido) e `%APPDATA%` (expandido).

```text
windows/gitconfig|~/.gitconfig
.agents|~/.agents
.config/opencode/plugins/token-daily|~/.config/opencode/plugins/token-daily
.config/Cursor/User/settings.json|%APPDATA%/Cursor/User/settings.json
wezterm.lua|~/.wezterm.lua
```

Adicionar um dotfile novo = 1 linha aqui (+ o arquivo em `data/`). O fluxo Linux continua sendo a
lista `config/dotfile-names.list` — as duas coexistem sem se tocar.

## 🚀 Como funciona

```powershell
# Aplica (confirma antes)
scripts\install-dotfiles.ps1

# Não interativo (CI / máquina nova)
scripts\install-dotfiles.ps1 -Yes

# Diagnóstico read-only
scripts\install-dotfiles.ps1 -Status

# Remove APENAS links que apontam para este repositório
scripts\install-dotfiles.ps1 -Remove

# Bridge de skills (também roda sozinho ao final do -Yes)
scripts\install-agent-skills-bridge.ps1           # aplica
scripts\install-agent-skills-bridge.ps1 -DryRun   # mostra o que faria
scripts\install-agent-skills-bridge.ps1 -Doctor   # read-only, exit 1 se houver drift
```

### Cadeia de fallback de links

| Tentativa | Quando | Sem admin? |
|---|---|---|
| **symlink** | sempre tenta primeiro | só com Developer Mode ativo (após re-login) |
| **junction** | só para diretórios | ✅ sim |
| **cópia** | só para arquivos (com aviso) | ✅ sim |

- **Promoção cópia → symlink**: se numa re-execução o symlink passar a funcionar, cópias idênticas
  (state `installed` sem link) são promovidas a symlink reais, **com backup antes**.
- Junctions são removidas com `.Delete()` no reparse point (nunca `Remove-Item -Recurse` em links —
  isso apagaria o conteúdo do alvo).

### Estados por entrada

| Estado | Significado | Apply faz |
|---|---|---|
| `not_installed` | destino não existe | linka (com fallback) |
| `installed` | link certo **ou** cópia idêntica (hash SHA256) | nada (promove cópia→symlink se possível) |
| `wrong_target` | link aponta para outro lugar | relinka |
| `blocking_file` | arquivo/dir **real** e diferente | backup em `.bkp/` + substitui por link |
| `unavailable` | fonte não existe em `data/` | pula com aviso |

## 🔒 Guardrails (SECURITY NOTE)

- **Nunca** apaga sem backup: conteúdo real vai para `<repo>/.bkp/<nome>_<dd-MM-yyyy_HH-MM>` antes.
- **Nunca** toca conteúdo real divergente em `-Remove` (só remove links apontando para o repo).
- **Nunca** modifica scripts/listas `.sh` ou o fluxo Linux.
- Idempotente: re-executar é no-op (`installed=13`, zero backups novos).
- Reversível: `-Remove` + backups manuais em `.bkp/`.

## 🧩 Bridge de skills no Windows

O bridge usa a **mesma** `config/agent-skills-bridge.list` do Linux (caminhos `~` portáveis).
Estado real desta máquina: **79 skills** (11 leaves + 15 bundles) × 7 roots = **475 links**, manifest
Antigravity com 16 entries. OpenCode/Codex/Cursor/Copilot core leem `~/.agents/skills` nativamente;
Claude/Devin/Antigravity/Copilot(cheio) dependem do bridge — igual ao Linux.

## 🩺 Sintomas conhecidos

| Sintoma | Causa | O que fazer |
|---|---|---|
| Saída com `???`/mojibake nos `.ps1` | script salvo sem BOM (PS 5.1 lê como ANSI) | `[IO.File]::WriteAllBytes` com `0xEF,0xBB,0xBF` no início |
| `symlink ... Permission denied` | Developer Mode ainda não ativo nesta sessão | re-login; até lá o fallback copia/junction mantém tudo funcionando |
| `.ps1` não roda: "running scripts is disabled" | ExecutionPolicy restritiva | `powershell -ExecutionPolicy Bypass -File scripts\install-dotfiles.ps1` |
| Cursor não enxerga settings linkados | app fecha e reabre o settings a partir do disco | reiniciar o Cursor após o apply |

## 📁 Arquivos envolvidos (novos/alterados)

- `config/dotfile-names-windows.list` — lista Windows (novo)
- `data/windows/gitconfig` — gitconfig Windows com `editor = vim` (novo; `data/gitconfig` é Linux-only)
- `scripts/dotfiles-lib.ps1` — biblioteca PS (novo)
- `scripts/install-dotfiles.ps1` — instalador Windows (novo)
- `scripts/install-agent-skills-bridge.ps1` — bridge PS (novo)
- `data/wezterm.lua` — **único arquivo compartilhado alterado**: guarda OS em `default_prog`
  (`target_triple:find('windows')` → `powershell.exe`, senão `zsh`) — 2 linhas, sem efeito no Linux
- `.bkp/` — backups datados (gitignored)

Fora de escopo nesta iteração: OpenCode profiles (`opencode-pf`), autostart/KDE, `dotfiles-menu.sh`.
