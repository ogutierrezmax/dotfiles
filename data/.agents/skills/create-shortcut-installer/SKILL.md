---
name: create-shortcut-installer
description: >-
  Gera ou revisa um script bash de instalação de atalhos no Linux (freedesktop):
  comando em ~/.local/bin e entrada .desktop no menu de aplicações. Usa quando o
  usuário pedir atalho no menu iniciar, comando global no terminal, instalar
  launcher, .desktop, XDG, ou padrão parecido com install-*-shortcuts.sh.
---

# Instalador genérico de atalhos (Linux / freedesktop)

## Objetivo

Produzir um script **`install-<nome>-shortcuts.sh`** (ou nome alinhado ao projeto) que:

1. Instala um **wrapper executável** em `~/.local/bin/<comando>` para o usuário poder rodar **`comando`** no terminal de qualquer diretório.
2. Opcionalmente instala **`~/.local/share/applications/<comando>.desktop`** para aparecer no **menu de aplicações** (GNOME, KDE, XFCE, etc.).

Não exige root. Respeita **`XDG_DATA_HOME`** e **`XDG_BIN_HOME`** quando definidos (fallback: `~/.local`).

## Quando usar GUI + terminal

| Caso | `.desktop` | `Terminal=` |
| ---- | ---------- | ----------- |
| Script TUI (menu ncurses, `read`, etc.) | Sim | `true` |
| App gráfico (Electron, GTK, etc.) | Sim | `false` |
| Só CLI, usuário não quer menu | Não | — |

## Contrato do script

- **`set -euo pipefail`** e `SCRIPT_DIR` via `"${BASH_SOURCE[0]}"`.
- Resolver o **script alvo** com caminho absoluto (ex.: `"$SCRIPT_DIR/meu-tool.sh"`); validar com `-f` antes de instalar.
- **Wrapper** em `$BIN_DIR/<comando>`:
  - Shebang `#!/usr/bin/env bash`.
  - Comentário de que foi gerado pelo instalador e que deve **reinstalar** se o repositório mudar de lugar.
  - Corpo: `exec bash $(printf '%q' "$TARGET_SCRIPT") "$@"` (ou `exec` direto se o alvo for binário e executável).
- **`chmod +x`** no wrapper após escrever.
- **Arquivo `.desktop`** (se aplicável):
  - `Exec="$WRAPPER"` (caminho absoluto do wrapper; aspas para suportar espaços raros no home).
  - `Name`, `Comment`, `Categories`, `Keywords` coerentes com o projeto.
  - `Version=1.0`, `Type=Application`.
- Após escrever o `.desktop`, se existir o comando: `update-desktop-database "$APP_DIR" 2>/dev/null || true`.
- **`--remove` / `--uninstall`**: remover os mesmos arquivos criados (wrapper + `.desktop` se houver), depois `update-desktop-database` como na instalação.
- **`-h` / `--help`**: uso curto.
- Ao final da instalação: se **`$BIN_DIR`** não estiver em **`$PATH`**, imprimir lembrete de `export PATH="$HOME/.local/bin:$PATH"` (ou o valor real de `BIN_DIR`).

## Parâmetros a inferir ou perguntar

| Parâmetro | Exemplo (placeholders; adapte ao projeto) |
| --------- | ------- |
| Nome do comando (basename em `~/.local/bin`) | `widget-sync`, `widget-cli` |
| Script ou binário alvo | `launch.sh`, `bin/entry` |
| Nome exibido no menu | Ex.: `Widget CLI` — texto curto para o usuário; pode diferir do nome da pasta do repo |
| Comentário do `.desktop` | Uma linha descrevendo a ação |
| Terminal ou não | `Terminal=true` / `false` |

## Nomes de arquivo

- Instalador: `install-<slug>-shortcuts.sh` na raiz do subprojeto ou pasta do app.
- Desktop: `<comando>.desktop` (mesmo slug do binário ajuda o usuário a achar).

## O que não fazer

- Não hardcodar usuário; usar `$HOME` e variáveis XDG.
- Não instalar em `/usr/local` sem o usuário pedir explicitamente (preferir user-local).
- Não editar o repositório alvo só para “encaixar” a skill; a skill orienta o agente ao criar/revisar o instalador.

## Verificação rápida

- Rodar o instalador em modo instalação; checar que o wrapper existe e que a primeira linha executável aponta para o alvo correto.
- `bash -n` no wrapper gerado.
- Se houver `.desktop`, `desktop-file-validate` se estiver disponível (opcional).

## Referência de layout

```
BIN_DIR=${XDG_BIN_HOME:-$HOME/.local/bin}
APP_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/applications
WRAPPER="$BIN_DIR/<comando>"
DESKTOP="$APP_DIR/<comando>.desktop"
```
