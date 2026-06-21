# WezTerm (GPU-Accelerated Terminal Emulator)

> Terminal moderno e rápido configurado via Lua, substituindo o Konsole como terminal padrão.

## Tech Stack

- **Terminal**: WezTerm 20240203
- **Config**: Lua (`~/.wezterm.lua`)
- **Tema**: Kanagawa (Gogh)

## Configuração Atual (`data/wezterm.lua`)

A configuração está em `data/wezterm.lua` e é sincronizada via symlink para `~/.wezterm.lua`.

### Aparência
- **Tema**: Kanagawa (Gogh) (Gogh)
- **Fonte**: MesloLGS Nerd Font 13pt
- **Opacidade**: 88% com background escuro
- **Tab bar**: Inferior com fancy tabs
- **Padding**: 6px em todos os lados
- **Janela**: Sem decorações (apenas redimensionável)

### Comportamento
- **Scrollback**: 10.000 linhas
- **Cursor**: Bloco piscante
- **FPS**: 120
- **Shell padrão**: zsh
- **Confirmação de fechamento**: nunca

### Atalhos (Leader: `Ctrl+a`)

O WezTerm usa uma tecla **Leader** (`Ctrl+a`) para comandos de gerenciamento de painéis, similar ao tmux:

| Atalho | Ação |
|--------|------|
| `Ctrl+a` `\|` | Dividir painel horizontalmente |
| `Ctrl+a` `-` | Dividir painel verticalmente |
| `Ctrl+a` `h/j/k/l` | Navegar entre painéis |
| `Ctrl+a` `z` | Zoom no painel ativo |
| `Ctrl+a` `q` | Fechar painel |
| `Ctrl+a` `x` | Modo cópia |
| `Ctrl+Shift+a` | Selecionar tudo e copiar |
| `Ctrl+Shift+c` | Copiar |
| `Ctrl+Shift+v` | Colar |
| `Ctrl+Shift+n` | Nova janela |
| `Ctrl+Shift+t` | Nova aba |
| `Ctrl+Shift+w` | Fechar aba |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Alternar abas |
| `Ctrl+Shift+PageUp/Down` | Scroll por página |

> **Nota**: `Ctrl+K` e `Ctrl+L` são desabilitados como defaults para evitar conflitos. `Ctrl+Shift+A` é um binding customizado via callback Lua (copia silenciosa, sem feedback visual de seleção).

### Mouse
- `Ctrl+Clique`: Abrir link sob o cursor

## Estado no Repositório

- `data/wezterm.lua`: Configuração principal
- `~/.wezterm.lua`: Symlink para o arquivo em `data/`
- `config/dotfile-names.list`: Inclui entrada `wezterm.lua`

## Substituição do Konsole

O WezTerm substitui o Konsole como terminal padrão:

1. Atalho `Meta+T` no KDE agora abre WezTerm
2. Launcher do painel KDE atualizado para WezTerm
3. Terminal padrão do sistema alterado via `update-alternatives`

Para trocar o terminal padrão manualmente:
```bash
sudo update-alternatives --set x-terminal-emulator /usr/bin/open-wezterm-here
```
