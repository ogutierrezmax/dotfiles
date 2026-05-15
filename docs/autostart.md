# 🚀 Inicialização Automática (Autostart)

> Gerencia aplicativos e scripts que iniciam automaticamente ao logar no ambiente desktop Linux.

Este documento detalha as configurações de autostart gerenciadas por estes dotfiles, localizadas no diretório padrão XDG.

## 🛠 Tech Stack
- **Padrão**: [XDG Autostart Specification](https://specifications.freedesktop.org/autostart-spec/autostart-spec-latest.html)
- **Formato**: Desktop Entry Files (.desktop)

## ⚡ Configuração Atual (`~/.config/autostart/`)

Os arquivos `.desktop` definem como cada aplicação deve ser iniciada. Abaixo, um exemplo de um dos arquivos gerenciados:

```ini
[Desktop Entry]
Type=Application
Exec=/home/alfo/_Dev/dotfiles/scripts/plasma-panel-lang-color.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Panel Color by Language
Comment=Changes taskbar color when switching keyboard language
Icon=preferences-desktop-keyboard
Categories=Settings;
X-KDE-Autostart-after=panel
```

## 🗺 Estrutura de Arquivos
- `data/.config/autostart/alfocards.desktop`: Inicia o aplicativo AlfoCards.
- `data/.config/autostart/Hydration Tracker.desktop`: Inicia o widget de hidratação.
- `data/.config/autostart/obsidian.desktop`: Inicia o Obsidian.
- `data/.config/autostart/plasma-panel-lang-color.desktop`: Inicia o script de cor da barra por idioma.

## 🔒 Segurança
- **Arquivos versionados**: Todos os arquivos `.desktop` em `~/.config/autostart/`.
- **Arquivos excluídos**: Arquivos de backup (`*.bak`) e temporários.
- **Guardrails aplicados**: 
    - `SECURITY NOTE`: Alerta sobre não colocar segredos (tokens/senhas) no campo `Exec=`.
    - `DANGER ZONE`: Alerta em comandos que executam binários ou scripts locais.

## 🚀 Como instalar (Manual)

1. **Certifique-se de que os programas estão instalados**:
   - `AlfoCards`, `Hydration Tracker`, `Obsidian`.
2. **Ative os symlinks**:
   ```bash
   ./dotfiles-menu.sh
   # Selecione o número correspondente aos arquivos de Autostart
   ```

---
*Este documento foi gerado durante o onboarding de Autostart nos dotfiles.*
