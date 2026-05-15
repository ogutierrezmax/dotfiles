#!/usr/bin/env bash
# =============================================================================
# switch-theme.sh — Ativa um preset de tema do KDE Plasma
# =============================================================================
#
# COMO FUNCIONA:
#   O KDE Plasma registra a aparência completa do painel (cores, widgets do
#   Panel Colorizer, wallpaper, etc.) em um único arquivo monolítico:
#       ~/.config/plasma-org.kde.plasma.desktop-appletsrc
#
#   Este script substitui esse arquivo pelo preset escolhido e atualiza
#   .current-theme para registrar qual tema está ativo.
#
#   O arquivo ~/.config/plasma-org.kde.plasma.desktop-appletsrc NÃO é mais
#   um symlink gerenciado pelo dotfiles-manager — é um arquivo real que o
#   KDE pode reescrever livremente. Os presets versionados ficam em:
#       data/kde-plasma/themes/presets/<nome>.appletsrc
#
# USO:
#   ./switch-theme.sh             → mostra o tema atualmente ativo
#   ./switch-theme.sh dark        → ativa o preset "dark"
#   ./switch-theme.sh light       → ativa o preset "light"
#
# PARA ADICIONAR UM NOVO PRESET:
#   1. Ative o tema desejado pela interface do KDE
#   2. Execute: ./save-theme.sh meu-tema
#   3. Commite o novo preset: git add presets/meu-tema.appletsrc && git commit
#
# PARA RECARREGAR MANUALMENTE SEM SCRIPT:
#   kquitapp5 plasmashell && kstart5 plasmashell
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRESETS_DIR="${SCRIPT_DIR}/presets"
CURRENT_THEME_FILE="${SCRIPT_DIR}/.current-theme"
PLASMA_CONFIG="${HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"

# -----------------------------------------------------------------------------
# Sem argumento: exibe o tema atual e presets disponíveis
# -----------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
    if [[ -f "$CURRENT_THEME_FILE" ]]; then
        echo "Tema atual: $(cat "$CURRENT_THEME_FILE")"
    else
        echo "Nenhum tema ativo registrado em .current-theme."
    fi
    echo ""
    echo "Presets disponíveis:"
    for f in "${PRESETS_DIR}"/*.appletsrc; do
        [[ -f "$f" ]] || continue
        echo "  - $(basename "$f" .appletsrc)"
    done
    exit 0
fi

THEME="$1"
PRESET_FILE="${PRESETS_DIR}/${THEME}.appletsrc"

# -----------------------------------------------------------------------------
# Validação: o preset deve existir
# -----------------------------------------------------------------------------
if [[ ! -f "$PRESET_FILE" ]]; then
    echo "Erro: preset '$THEME' não encontrado em ${PRESETS_DIR}/" >&2
    echo ""
    echo "Presets disponíveis:"
    for f in "${PRESETS_DIR}"/*.appletsrc; do
        [[ -f "$f" ]] || continue
        echo "  - $(basename "$f" .appletsrc)"
    done
    exit 1
fi

# -----------------------------------------------------------------------------
# Garante que o destino é um arquivo real (não symlink)
# O dotfiles-manager antigo criava um symlink; migramos para arquivo real
# para que o KDE não sobrescreva os presets ao trocar tema pela interface.
# -----------------------------------------------------------------------------
if [[ -L "$PLASMA_CONFIG" ]]; then
    echo "Aviso: ${PLASMA_CONFIG} ainda é um symlink. Convertendo para arquivo real..." >&2
    rm "$PLASMA_CONFIG"
fi

# -----------------------------------------------------------------------------
# Aplica o preset: copia para o config live do KDE
# -----------------------------------------------------------------------------
cp "$PRESET_FILE" "$PLASMA_CONFIG"

# Registra o tema ativo (skip-worktree no Git: não gera diff)
echo "$THEME" > "$CURRENT_THEME_FILE"

echo "✓ Tema '${THEME}' aplicado em ${PLASMA_CONFIG}"

# -----------------------------------------------------------------------------
# Recarrega o Plasma Shell para aplicar imediatamente
# Tenta qdbus-qt5 (Plasma 5) e qdbus6 (Plasma 6) por compatibilidade
# -----------------------------------------------------------------------------
_reload_plasma() {
    local dbus_cmd=""
    if command -v qdbus-qt5 &>/dev/null; then
        dbus_cmd="qdbus-qt5"
    elif command -v qdbus6 &>/dev/null; then
        dbus_cmd="qdbus6"
    elif command -v qdbus &>/dev/null; then
        dbus_cmd="qdbus"
    fi

    if [[ -n "$dbus_cmd" ]]; then
        "$dbus_cmd" org.kde.plasmashell /PlasmaShell \
            org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null || true
        echo "✓ Plasma Shell recarregado via D-Bus"
    else
        echo "Aviso: qdbus não encontrado. Recarregue o Plasma manualmente:" >&2
        echo "  kquitapp5 plasmashell && kstart5 plasmashell" >&2
    fi
}

_reload_plasma
