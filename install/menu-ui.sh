#!/usr/bin/env bash
# Cores e rótulos do menu interativo (dotfiles-menu.sh).
# Estados vêm de dotfiles_status_for_file (install/lib.sh).
# shellcheck disable=SC2034  # R, B, C_* são globais intencionais para printf

# --- Cores ANSI (só se stdout for TTY e NO_COLOR não estiver definido) ---
dotfiles_term_colors_init() {
    if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
        R=$'\033[0m'
        B=$'\033[1m'
        C_INST=$'\033[32m'    # verde — instalado
        C_NONE=$'\033[33m'    # amarelo — falta instalar
        C_MISS=$'\033[90m'    # cinza — sem fonte em data/
        C_WRONG=$'\033[35m'   # magenta — link errado
        C_BLOCK=$'\033[31m'   # vermelho — ficheiro bloqueia
        C_IMP=$'\033[36m'   # ciano — só em ~, pode importar
    else
        R= B= C_INST= C_NONE= C_MISS= C_WRONG= C_BLOCK= C_IMP=
    fi
}

# Cor só para marcador/descrição; o nome do ficheiro fica sem cor (alinhamento em colunas).
dotfiles_status_color() {
    case "$1" in
        installed) echo "$C_INST" ;;
        not_installed) echo "$C_NONE" ;;
        importable) echo "$C_IMP" ;;
        unavailable) echo "$C_MISS" ;;
        wrong_target) echo "$C_WRONG" ;;
        blocking_file) echo "$C_BLOCK" ;;
        *) echo "" ;;
    esac
}

# Colunas à direita: origem, Linked (checkbox), ação sugerida.
dotfiles_status_source() {
    case "$1" in
        installed|not_installed|wrong_target) echo "data" ;;
        importable) echo "~" ;;
        unavailable) echo "none" ;;
        blocking_file) echo "~ & data" ;;
        *) echo "?" ;;
    esac
}

# Coluna Linked: ☑ = symlink ok, ☐ = sem link (ou bloqueado).
dotfiles_status_linked_checkbox() {
    case "$1" in
        installed|wrong_target) echo $'☑' ;;
        not_installed|importable|unavailable|blocking_file) echo $'☐' ;;
        *) echo "?" ;;
    esac
}

dotfiles_status_action() {
    case "$1" in
        importable) echo "move and link" ;;
        unavailable) echo "create file" ;;
        blocking_file) echo "local backup and replace" ;;
        installed|not_installed|wrong_target) echo "—" ;;
        *) echo "?" ;;
    esac
}

# Símbolo curto ([✓], [ ], …) à esquerda do nome.
dotfiles_status_mark() {
    case "$1" in
        blocking_file) echo "[×]" ;;
        importable) echo "[~]" ;;
        unavailable) echo "[—]" ;;
        not_installed) echo "[ ]" ;;
        installed) echo "[✓]" ;;
        wrong_target) echo "[!]" ;;
        *) echo "[?]" ;;
    esac
}

# Cabeçalho + uma linha por entrada (config/links.list) + legenda.
# Argumento: nome do array bash (nameref), ex.: dotfiles_menu_render entries
dotfiles_menu_render() {
    local -n _menu_entries=$1
    local line st c i=1
    echo ""
    echo "${B}Dotfiles — estado em ${HOME}${R}"
    echo "────────────────────────────────────────────────────────────────────────────────────"
    printf " %2s  %-4s  %-26s  %-12s  %-6s  %-30s\n" \
        "#" "[ ]" "ficheiro" "source" "Linked" "Action"
    echo "────────────────────────────────────────────────────────────────────────────────────"
    for line in "${_menu_entries[@]}"; do
        st="$(dotfiles_status_for_file "$line")"
        c="$(dotfiles_status_color "$st")"
        # Cor só no marcador e nas colunas à direita (ANSI quebra o alinhamento no nome).
        printf " %s%2d%s  %s%s%s  %-26s  %s%-12s  %-6s  %-30s%s\n" \
            "$B" "$i" "$R" \
            "$c" "$(dotfiles_status_mark "$st")" "$R" \
            "$line" \
            "$c" "$(dotfiles_status_source "$st")" \
            "$(dotfiles_status_linked_checkbox "$st")" \
            "$(dotfiles_status_action "$st")" "$R"
        i=$((i + 1))
    done
    echo "────────────────────────────────────────────────────────────────────────────────────"
    dotfiles_menu_print_legend
    echo ""
}

# Explica os símbolos; duas variantes conforme cores ativas ou não.
dotfiles_menu_print_legend() {
    if [[ -n "$C_INST" ]]; then
        echo "Legenda: ${C_INST}[✓]${R} ok  ${C_NONE}[ ]${R} falta  ${C_IMP}[~]${R} importar desde ~  ${C_MISS}[—]${R} sem fonte  ${C_WRONG}[!]${R} link errado  ${C_BLOCK}[×]${R} bloqueado"
    else
        echo "Legenda: [✓] ok  [ ] falta  [~] importar desde ~  [—] sem fonte  [!] link errado  [×] bloqueado"
    fi
}
