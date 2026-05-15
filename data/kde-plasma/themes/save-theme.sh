#!/usr/bin/env bash
# =============================================================================
# save-theme.sh — Captura o estado atual do Plasma e salva no preset
# =============================================================================
#
# COMO FUNCIONA:
#   Copia ~/.config/plasma-org.kde.plasma.desktop-appletsrc (o arquivo que
#   o KDE mantém e modifica livremente) de volta para o preset versionado
#   correspondente em presets/<tema>.appletsrc.
#
#   Use este script quando quiser "fotografar" um tema após ajustá-lo pela
#   interface do KDE e versionar a mudança no repositório.
#
# USO:
#   ./save-theme.sh              → salva no tema registrado em .current-theme
#   ./save-theme.sh dark         → força salvar como preset "dark"
#   ./save-theme.sh meu-tema     → cria/atualiza o preset "meu-tema"
#
# FLUXO RECOMENDADO APÓS SALVAR:
#   git diff data/kde-plasma/themes/presets/
#   git add data/kde-plasma/themes/presets/<tema>.appletsrc
#   git commit -m "chore(kde): atualiza preset <tema>"
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRESETS_DIR="${SCRIPT_DIR}/presets"
CURRENT_THEME_FILE="${SCRIPT_DIR}/.current-theme"
PLASMA_CONFIG="${HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"

# -----------------------------------------------------------------------------
# Determina qual preset atualizar
# -----------------------------------------------------------------------------
if [[ $# -ge 1 ]]; then
    THEME="$1"
elif [[ -f "$CURRENT_THEME_FILE" ]]; then
    THEME="$(cat "$CURRENT_THEME_FILE")"
else
    echo "Erro: .current-theme não encontrado e nenhum tema foi passado como argumento." >&2
    echo "Uso: ./save-theme.sh [nome-do-tema]" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Validação: o arquivo live do KDE deve existir
# -----------------------------------------------------------------------------
if [[ ! -f "$PLASMA_CONFIG" ]] && [[ ! -L "$PLASMA_CONFIG" ]]; then
    echo "Erro: arquivo do Plasma não encontrado em ${PLASMA_CONFIG}" >&2
    exit 1
fi

PRESET_FILE="${PRESETS_DIR}/${THEME}.appletsrc"

# Se o preset for novo, informa
if [[ ! -f "$PRESET_FILE" ]]; then
    echo "Novo preset: '${THEME}' será criado em ${PRESET_FILE}"
fi

# -----------------------------------------------------------------------------
# Copia o config atual para o preset
# -----------------------------------------------------------------------------
mkdir -p "$PRESETS_DIR"
cp "$PLASMA_CONFIG" "$PRESET_FILE"

echo "✓ Preset '${THEME}' salvo em ${PRESET_FILE}"
echo ""
echo "Para versionar a mudança, execute:"
echo "  git diff data/kde-plasma/themes/presets/${THEME}.appletsrc"
echo "  git add data/kde-plasma/themes/presets/${THEME}.appletsrc"
echo "  git commit -m \"chore(kde): atualiza preset ${THEME}\""
