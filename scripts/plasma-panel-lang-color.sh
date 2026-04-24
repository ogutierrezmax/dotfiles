#!/usr/bin/env bash

# Script para mudar o preset do Panel Colorizer baseado no idioma do teclado
# Desenvolvido para KDE Plasma 6

# --- CONFIGURAÇÃO ---
# Caminhos para os presets (ajuste conforme seu gosto)
# Você pode encontrar presets em:
# ~/.local/share/plasma/plasmoids/luisbocanegra.panel.colorizer/contents/ui/presets/
# ou criar os seus em ~/.config/panel-colorizer/presets/

PRESETS_BASE="$HOME/.local/share/plasma/plasmoids/luisbocanegra.panel.colorizer/contents/ui/presets"

# Preset para Inglês (Layout 0)
PRESET_EN="$PRESETS_BASE/Pulse"
# Preset para Português (Layout 1)
PRESET_PT="$PRESETS_BASE/Bliss"

# --- FUNÇÕES ---

apply_preset() {
    local preset_path="$1"
    if [ -d "$preset_path" ]; then
        echo "Aplicando preset: $(basename "$preset_path")"
        dbus-send --session --type=signal /preset luisbocanegra.panel.colorizer.all.preset string:"$preset_path"
    else
        echo "Erro: Preset não encontrado em $preset_path"
    fi
}

# --- INÍCIO ---

echo "Iniciando monitor de idioma do KDE..."

# Aplica o preset inicial baseado no layout atual
CURRENT_INDEX=$(gdbus call --session --dest org.kde.keyboard --object-path /Layouts --method org.kde.KeyboardLayouts.getLayout)
# gdbus retorna algo como (uint32 0,)
INDEX=$(echo "$CURRENT_INDEX" | grep -oP "\d+")

if [ "$INDEX" == "0" ]; then
    apply_preset "$PRESET_EN"
else
    apply_preset "$PRESET_PT"
fi

# Monitora mudanças futuras
dbus-monitor --session "interface='org.kde.KeyboardLayouts',member='layoutChanged'" | \
while read -r line; do
    # Quando o sinal layoutChanged é emitido, ele vem com o novo index como argumento
    if echo "$line" | grep -q "uint32"; then
        # Extrai o índice do layout
        NEW_INDEX=$(echo "$line" | grep -oP "uint32 \K\d+")
        echo "Layout alterado para index: $NEW_INDEX"
        
        if [ "$NEW_INDEX" == "0" ]; then
            apply_preset "$PRESET_EN"
        elif [ "$NEW_INDEX" == "1" ]; then
            apply_preset "$PRESET_PT"
        fi
    fi
done
