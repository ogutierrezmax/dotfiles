# 🐉 KDE Plasma (Desktop Environment)

> Configurações visuais, atalhos e comportamento do ambiente KDE Plasma organizadas via dotfiles manager.

Este documento detalha a configuração atual do `KDE Plasma`, gerenciada como um "pacote" agrupado na pasta `kde-plasma/`.

## 🛠 Tech Stack
- **Desktop Environment**: KDE Plasma
- **Window Manager**: KWin
- **Framework**: Qt / KDE Frameworks

---

## 🗺 Estrutura de Arquivos

### Configs estáticos (symlinks via dotfiles-manager)

| Arquivo | Propósito |
| :--- | :--- |
| `data/kde-plasma/.config/kdeglobals` | Preferências gerais, tema, cores, fontes |
| `data/kde-plasma/.config/kwinrc` | Comportamento do gerenciador de janelas e efeitos |
| `data/kde-plasma/.config/kwinrulesrc` | Regras específicas para janelas (ex: transparência) |
| `data/kde-plasma/.config/kglobalshortcutsrc` | Atalhos globais de teclado do sistema |
| `data/kde-plasma/.config/plasmashellrc` | Configurações gerais da interface e do painel |

### Sistema de Presets de Tema (gerenciado separadamente)

O arquivo `plasma-org.kde.plasma.desktop-appletsrc` contém toda a aparência do painel
(Panel Colorizer, disposição de widgets, wallpaper, etc.) e é reescrito integralmente
pelo KDE a cada troca de tema. Por isso, ele **não é gerenciado como symlink** —
em vez disso, usa um sistema de presets dedicado:

```
data/kde-plasma/themes/
├── .current-theme          ← qual tema está ativo agora (git skip-worktree)
├── switch-theme.sh         ← script para trocar de tema
├── save-theme.sh           ← script para salvar o estado atual como preset
└── presets/
    ├── dark.appletsrc      ← snapshot completo do tema escuro
    └── light.appletsrc     ← snapshot completo do tema claro
```

#### Por que essa separação?

- Os presets (`*.appletsrc`) são **totalmente versionados** e só mudam quando você deliberadamente salva um ajuste.
- O arquivo live (`~/.config/plasma-org.kde.plasma.desktop-appletsrc`) é um **arquivo real** (não symlink), que o KDE escreve livremente sem afetar o repositório.
- O `.current-theme` tem `git skip-worktree` ativo: registra o tema ativo localmente, mas trocas não aparecem no `git status`.

---

## 🎨 Como usar os Presets de Tema

### Trocar de tema
```bash
# A partir da raiz do repositório:
data/kde-plasma/themes/switch-theme.sh dark
data/kde-plasma/themes/switch-theme.sh light

# Ver qual tema está ativo e presets disponíveis:
data/kde-plasma/themes/switch-theme.sh
```

### Salvar ajustes feitos pela interface do KDE
```bash
# 1. Faça os ajustes visuais que quiser via System Settings / Panel Colorizer
# 2. Salve o estado atual no preset correspondente:
data/kde-plasma/themes/save-theme.sh

# 3. Revise e commite:
git diff data/kde-plasma/themes/presets/
git add data/kde-plasma/themes/presets/<tema>.appletsrc
git commit -m "chore(kde): atualiza preset <tema>"
```

### Adicionar um novo preset
```bash
# 1. Configure o tema desejado pela interface do KDE
# 2. Salve com um nome novo:
data/kde-plasma/themes/save-theme.sh meu-tema

# 3. Commite o novo arquivo:
git add data/kde-plasma/themes/presets/meu-tema.appletsrc
git commit -m "chore(kde): adiciona preset meu-tema"
```

---

## 🚀 Como instalar em uma nova máquina

1. **Clone o repositório e instale os symlinks estáticos**:
   ```bash
   git clone https://github.com/ogutierrezmax/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ./scripts/install-dotfiles.sh
   ```

2. **Aplique o preset de tema desejado**:
   ```bash
   data/kde-plasma/themes/switch-theme.sh dark
   ```

3. **Re-aplique o skip-worktree no `.current-theme`** (necessário após clone):
   ```bash
   git update-index --skip-worktree data/kde-plasma/themes/.current-theme
   ```

---

## 🔒 Segurança

- **Arquivos versionados como symlink**: `kdeglobals`, `kwinrc`, `kwinrulesrc`, `kglobalshortcutsrc`, `plasmashellrc`.
- **Arquivo de presets versionado diretamente**: `themes/presets/*.appletsrc` (sem symlink).
- **Arquivo com skip-worktree**: `themes/.current-theme` — commitado com valor padrão, mas mudanças locais são ignoradas pelo Git.
- **Arquivo excluído do versionamento**: `~/.config/plasma-org.kde.plasma.desktop-appletsrc` — arquivo real que o KDE gerencia livremente.
- **Arquivos excluídos (demais)**: Todo o restante de `~/.config/` e `.local/share/` gerado pelo KDE (dados voláteis, sessão, kwallet).

## 📖 Comportamento do Script de Dotfiles

O script base (`scripts/dotfiles-lib.sh`) suporta pastas "agrupadoras" (pacotes) ao estilo GNU Stow.
Arquivos declarados como `kde-plasma/.config/arquivo` em `config/dotfile-names.list` perdem o prefixo
e são linkados para `~/.config/arquivo`, sem que a pasta `kde-plasma` apareça no caminho final.

---
*Atualizado durante a implementação do sistema de presets de tema.*
