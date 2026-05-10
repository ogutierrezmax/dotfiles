# 🐉 KDE Plasma (Desktop Environment)

> Configurações visuais, atalhos e comportamento do ambiente KDE Plasma organizadas via dotfiles manager.

Este documento detalha a configuração atual do `KDE Plasma`, gerenciada como um "pacote" agrupado na pasta `kde-plasma/`.

## 🛠 Tech Stack
- **Desktop Environment**: KDE Plasma
- **Window Manager**: KWin
- **Framework**: Qt / KDE Frameworks

## ⚡ Configuração Atual (`data/kde-plasma/.config/`)

O KDE espalha suas configurações em múltiplos arquivos. Em vez de versionar todo o diretório de configurações (que contém muito lixo gerado dinamicamente), focamos apenas nos vitais:

```ini
# kdeglobals (Cores e tema geral - Exemplo)
[General]
ColorScheme=BreezeDark
Name=Breeze Dark
```

## 🗺 Estrutura de Arquivos
- `data/kde-plasma/.config/kdeglobals`: Preferências gerais, tema, cores, fontes.
- `data/kde-plasma/.config/kwinrc`: Comportamento do gerenciador de janelas e efeitos.
- `data/kde-plasma/.config/kwinrulesrc`: Regras específicas para janelas (ex: transparência).
- `data/kde-plasma/.config/kglobalshortcutsrc`: Atalhos globais de teclado do sistema.
- `data/kde-plasma/.config/plasmashellrc`: Configurações gerais da interface e do painel.
- `data/kde-plasma/.config/plasma-org.kde.plasma.desktop-appletsrc`: Widgets e disposição visual do desktop.

## 🔒 Segurança
- **Arquivos versionados**: `kdeglobals`, `kwinrc`, `kwinrulesrc`, `kglobalshortcutsrc`, `plasmashellrc`, `plasma-org.kde.plasma.desktop-appletsrc`.
- **Arquivos excluídos**: Todos os outros da pasta `~/.config/` e `.local/share/` gerados pelo KDE, pois contêm dados voláteis de histórico, resolução específica de hardware, credenciais do kwallet ou estado da sessão. Nenhuma credencial foi encontrada nos arquivos versionados.
- **Guardrails aplicados**: Nenhum comentário SECURITY NOTE pôde ser injetado diretamente nos INIs nativos para não quebrar o parser do KDE, mas a lista restrita de arquivos no `config/dotfile-names.list` garante que outras informações sensíveis do sistema não vazem.

## 🚀 Como instalar (Manual)

1. **Instale o programa**:
   O KDE Plasma costuma ser a base do sistema nativo (ex: Kubuntu, KDE Neon, Arch KDE).
2. **Ative os symlinks**:
   ```bash
   ./scripts/install-dotfiles.sh
   # Ou use a interface principal:
   ./dotfiles-menu.sh
   ```

## 📖 Comportamento do Script de Dotfiles

O script base do repositório (`scripts/dotfiles-lib.sh`) foi aprimorado para suportar pastas "agrupadoras" (pacotes) num estilo semelhante ao GNU Stow. Os arquivos declarados como `kde-plasma/.config/arquivo` em `config/dotfile-names.list` perdem o prefixo e são linkados corretamente para o destino `~/.config/arquivo`. Isso previne que a pasta `kde-plasma` seja injetada no caminho final.

---
*Este documento foi gerado durante o onboarding do KDE Plasma nos dotfiles.*
