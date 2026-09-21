# 🧩 Agent Skills Bridge

> Symlinks por-skill: cada ferramenta de IA enxerga as skills do acervo central `~/.agents/skills` sem manter cópias duplicadas.

Este documento detalha o **bridge de skills de IA** — mecanismo que elimina cópias duplicadas de skills entre ferramentas
(Claude Code, Devin, Antigravity, Cursor, etc.) apontando os diretórios de skills de cada ferramenta para a **fonte única**
versionada neste repositório.

## 🛠 Tech Stack
- **Acervo central**: `~/.agents/skills` (symlink → `dotfiles/data/.agents/skills`)
- **Configuração**: `config/agent-skills-bridge.list`
- **Script**: `scripts/install-agent-skills-bridge.sh`
- **Tipo de link**: symlink **por skill** (não por diretório inteiro) — preserva skills específicas de cada ferramenta
  (ex.: `pinokio` no Cursor) e segue o suporte oficial a symlinks por skill das ferramentas.

## 🗺 Por que existe

O kit MCP+skill do Context7 foi instalado em 9 ferramentas, criando **cópias reais duplicadas** da mesma skill em cada
diretório (`~/.claude/skills`, `~/.cursor/skills`, `~/.config/devin/skills`, `~/.agent/skills`, `~/.gemini/skills`...).
Atualizar uma skill exigia propagar a mudança em N lugares. O bridge resolve isso com uma única fonte.

### Quem lê `~/.agents/skills` nativamente (sem bridge)
- **VS Code (Copilot)**, **GitHub Copilot CLI**, **OpenCode** e **Codex** — compartilham `~/.agents/skills` nativamente.
- **Cursor** e **Gemini CLI** — também leem `~/.agents/skills`; entradas no config são espelhos **opcionais**.

### Quem precisa de bridge
- **Claude Code** — só lê `~/.claude/skills`.
- **Devin** — só lê `~/.config/devin/skills`.
- **Antigravity** — bug conhecido no CLI (google-antigravity/antigravity-cli#103): não lê `~/.agents/skills`.
  O bridge cobre os 3 caminhos que o Antigravity reconhece: `~/.agent/skills` (backward-compat),
  `~/.gemini/antigravity/skills` (global oficial do IDE) e `~/.gemini/config/skills` (2.0).

## ⚙️ Configuração: `config/agent-skills-bridge.list`

Formato: `<ferramenta>|<skill>` — a skill pode ser:
- `*` → **todas** as "leaf skills" de topo (diretórios com `SKILL.md` direto em `~/.agents/skills`);
- `<nome>` → skill leaf específica (ex.: `context7-mcp`);
- `<bundle>/<nome>` → sub-skill dentro de um bundle (ex.: `tech-domain-skills/tauri-gmail-oauth`, usada pelo Cursor).

```text
# Claude Code — só lê ~/.claude/skills → bridge completo
claude|*

# Devin — só lê ~/.config/devin/skills → bridge completo
devin|*

# Antigravity — 3 caminhos (backward-compat, IDE global, 2.0)
antigravity|*

# Cursor — espelho explícito de sub-skill de bundle (o resto vem de ~/.agents/skills)
cursor|tech-domain-skills/tauri-gmail-oauth
```

O mapa de ferramentas → diretórios fica no próprio script (`TOOL_DIRS`), separados por `:`.

## 🚀 Como funciona

```bash
# Sob demanda (menu)
dotfiles-menu.sh   # digite: skills

# Direto
bash scripts/install-agent-skills-bridge.sh
```

**Automação em máquina nova**: `scripts/install-dotfiles.sh` chama o bridge automaticamente após linkar os dotfiles
(cria o symlink `~/.agents` → `data/.agents` e depois reconstrói todos os bridges).

O script é **idempotente** e segue este estado por destino:

| Estado do destino | Ação |
|---|---|
| Symlink correto para o acervo | nada (ok) |
| Symlink errado/quebrado | relinka |
| Diretório real **idêntico** ao acervo | move para `.bkp/` datado + cria symlink (conversão) |
| Diretório real **diferente** do acervo | 🔒 alerta e **pula** (nunca destrói trabalho) |
| Symlink órfão (target não existe) | remove (link quebrado não confunde a ferramenta) |
| Diretório da ferramenta == acervo central | pula (sem bridge necessária) |

## 🔒 Guardrails (SECURITY NOTE)

- **Nunca** usa `rm -rf`; só remove symlinks gerenciados que apontam para `~/.agents/skills` cujo alvo deixou de existir.
- Diretórios reais são **sempre movidos para `.bkp/` antes** de virarem symlink (nada é apagado sem backup).
- Links são **absolutos** via `$HOME/.agents/...` → funcionam em qualquer máquina onde o repo for clonado.
- Skills fora da configuração (ex.: `pinokio`, `plantuml` no Cursor) **nunca** são tocadas.
- Se um diretório de ferramenta **já é** o acervo central (aliás/symlink, como `~/.gemini/antigravity/skills`),
  o bridge detecta e pula — proteger a fonte da verdade é prioridade.

## 📁 Arquivos envolvidos
- `config/agent-skills-bridge.list`: escopo das ferramentas (o que bridar).
- `scripts/install-agent-skills-bridge.sh`: lógica do bridge (idempotente, com backup e salvaguardas).
- `scripts/install-dotfiles.sh`: dispara o bridge ao final da instalação.
- `dotfiles-menu.sh` + `scripts/dotfiles-menu-commands.sh` + `scripts/dotfiles-menu-ui.sh`: comando `skills` no menu.
- `data/.agents/skills/`: o acervo central versionado (fonte única).

## 🩺 Validação

```bash
# Sem links quebrados nos diretórios gerenciados
find ~/.claude/skills ~/.config/devin/skills ~/.agent/skills ~/.gemini/config/skills \
     -maxdepth 1 -xtype l 2>/dev/null

# Amostra dos targets
readlink ~/.claude/skills/context7-mcp   # → ~/.agents/skills/context7-mcp
```