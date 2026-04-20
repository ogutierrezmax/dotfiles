#!/usr/bin/env bash
#
# Instalador de atalhos para o Dotfiles Menu.
# Cria um wrapper em ~/.local/bin e um arquivo .desktop para o menu de aplicações.
#
# Gerado para seguir o padrão de freedesktop (XDG).

set -euo pipefail

# --- Configurações ---
CMD_NAME="dotfiles-menu"
DISPLAY_NAME="Dotfiles Menu"
COMMENT="Manage and install dotfiles interactively"
TARGET_FILENAME="dotfiles-menu.sh"
CATEGORIES="System;Settings;"
KEYWORDS="dotfiles;config;setup;terminal;"

# Caminhos XDG
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

# Caminho absoluto do diretório deste script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PATH="$SCRIPT_DIR/$TARGET_FILENAME"

WRAPPER_PATH="$BIN_DIR/$CMD_NAME"
DESKTOP_PATH="$APP_DIR/$CMD_NAME.desktop"

# --- Funções ---

show_help() {
    cat <<EOF
Uso: $(basename "$0") [OPÇÕES]

Instala ou remove atalhos para o $DISPLAY_NAME.

Opções:
  -r, --remove, --uninstall   Remove os atalhos instalados.
  -h, --help                  Mostra esta mensagem de ajuda.

Arquivos afetados:
  Executável: $WRAPPER_PATH
  Desktop:    $DESKTOP_PATH
EOF
}

remove_shortcuts() {
    echo "Removendo atalhos..."
    local removed=0

    if [[ -f "$WRAPPER_PATH" ]]; then
        rm -v "$WRAPPER_PATH"
        removed=1
    fi

    if [[ -f "$DESKTOP_PATH" ]]; then
        rm -v "$DESKTOP_PATH"
        removed=1
    fi

    if [[ $removed -eq 1 ]]; then
        update-desktop-database "$APP_DIR" 2>/dev/null || true
        echo "Atalhos removidos com sucesso."
    else
        echo "Nenhum atalho encontrado para remover."
    fi
}

install_shortcuts() {
    # Validação
    if [[ ! -f "$TARGET_PATH" ]]; then
        echo "Erro: Script alvo não encontrado em $TARGET_PATH" >&2
        exit 1
    fi

    # Garantir que os diretórios existem
    mkdir -p "$BIN_DIR"
    mkdir -p "$APP_DIR"

    echo "Instalando wrapper em $WRAPPER_PATH..."
    cat <<EOF > "$WRAPPER_PATH"
#!/usr/bin/env bash
# Wrapper gerado automaticamente para $DISPLAY_NAME.
# Se o repositório mudar de lugar, execute o instalador novamente.
exec bash $(printf '%q' "$TARGET_PATH") "\$@"
EOF
    chmod +x "$WRAPPER_PATH"

    echo "Instalando arquivo .desktop em $DESKTOP_PATH..."
    cat <<EOF > "$DESKTOP_PATH"
[Desktop Entry]
Version=1.0
Type=Application
Name=$DISPLAY_NAME
Comment=$COMMENT
Exec="$WRAPPER_PATH"
Icon=utilities-terminal
Terminal=true
Categories=$CATEGORIES
Keywords=$KEYWORDS
EOF

    update-desktop-database "$APP_DIR" 2>/dev/null || true

    echo ""
    echo "Instalação concluída!"
    echo "Agora você pode rodar '$CMD_NAME' no terminal ou encontrá-lo no menu de aplicações."
    
    # Verificar se BIN_DIR está no PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo ""
        echo "AVISO: O diretório $BIN_DIR não parece estar no seu PATH."
        echo "Adicione a seguinte linha ao seu ~/.bashrc ou ~/.zshrc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

# --- Main ---

case "${1:-}" in
    -r|--remove|--uninstall)
        remove_shortcuts
        ;;
    -h|--help)
        show_help
        ;;
    "")
        install_shortcuts
        ;;
    *)
        echo "Opção inválida: $1"
        show_help
        exit 1
        ;;
esac
