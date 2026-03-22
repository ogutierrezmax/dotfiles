#!/usr/bin/env bash
# Cores e rótulos do menu interativo (dotfiles-menu.sh).
# Estados vêm de dotfiles_status_for_file (install/lib.sh).
# Layout (espaços entre colunas, larguras, cabeçalhos): config/menu-ui.conf
# shellcheck disable=SC2034  # R, B, C_* são globais intencionais para printf

# Carrega config/menu-ui.conf (opcional) e aplica padrões.
dotfiles_menu_ui_load_config() {
    local conf _hdr_mark_def='[ ]'
    conf="$(dotfiles_repo_root)/config/menu-ui.conf"
    if [[ -f "$conf" ]]; then
        # shellcheck source=/dev/null
        source "$conf"
    fi
    : "${MENU_UI_COL_GAP:=2}"
    : "${MENU_UI_WIDTH_NUM:=2}"
    : "${MENU_UI_WIDTH_MARK:=4}"
    : "${MENU_UI_WIDTH_FILE:=26}"
    : "${MENU_UI_WIDTH_SOURCE:=12}"
    : "${MENU_UI_WIDTH_LINKED:=6}"
    : "${MENU_UI_WIDTH_ACTION:=30}"
    : "${MENU_UI_HDR_NUM:=#}"
    MENU_UI_HDR_MARK="${MENU_UI_HDR_MARK:-$_hdr_mark_def}"
    : "${MENU_UI_HDR_FILE:=ficheiro}"
    : "${MENU_UI_HDR_SOURCE:=source}"
    : "${MENU_UI_HDR_LINKED:=Linked}"
    : "${MENU_UI_HDR_ACTION:=Action}"
}

# Largura aproximada da linha da tabela (para o separador ───).
dotfiles_menu_ui_table_width() {
    local g=$((MENU_UI_COL_GAP))
    echo $((1 + MENU_UI_WIDTH_NUM + g + MENU_UI_WIDTH_MARK + g + MENU_UI_WIDTH_FILE + g + MENU_UI_WIDTH_SOURCE + g + MENU_UI_WIDTH_LINKED + g + MENU_UI_WIDTH_ACTION))
}

dotfiles_menu_ui_sep_line() {
    local w
    w="$(dotfiles_menu_ui_table_width)"
    printf '%*s' "$w" '' | sed 's/ /─/g'
    echo
}

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

# Coluna Linked: só ASCII (como nos marcadores): Unicode tipo ☐ desloca o printf vs. o terminal.
dotfiles_status_linked_checkbox() {
    case "$1" in
        installed) echo "Linked" ;;
        wrong_target) echo "wrong target" ;;
        not_installed|importable|unavailable|blocking_file) echo "Unlinked" ;;
        *) echo "?" ;;
    esac
}

# Traço "sem ação": só ASCII (-); o traço longo Unicode (—) faz o mesmo desalinhamento que nos marcadores.
dotfiles_status_action() {
    case "$1" in
        importable) echo "move and link" ;;
        unavailable) echo "create file" ;;
        blocking_file) echo "local backup and replace" ;;
        wrong_target) echo "fix link" ;;
        installed|not_installed) echo "-" ;;
        *) echo "?" ;;
    esac
}

# Símbolo curto ([+], [ ], …) à esquerda do nome.
# Só caracteres ASCII nos marcadores: printf %-Ns conta largura de Unicode de forma
# diferente do terminal (ex.: [×] e [✓] viram 4 “unidades” no printf e 3 colunas na tela),
# o que desloca as colunas à direita.
dotfiles_status_mark() {
    case "$1" in
        blocking_file) echo "[#]" ;;
        importable) echo "[~]" ;;
        unavailable) echo "[-]" ;;
        not_installed) echo "[ ]" ;;
        installed) echo "[+]" ;;
        wrong_target) echo "[!]" ;;
        *) echo "[?]" ;;
    esac
}

# Cabeçalho + uma linha por entrada (config/links.list) + legenda.
# Argumento: nome do array bash (nameref), ex.: dotfiles_menu_render entries
dotfiles_menu_render() {
    local -n _menu_entries=$1
    local line st c i=1 gap
    dotfiles_menu_ui_load_config
    printf -v gap '%*s' "$MENU_UI_COL_GAP" ''

    echo ""
    echo "${B}Dotfiles — estado em ${HOME}${R}"
    dotfiles_menu_ui_sep_line
    # shellcheck disable=SC2059
    printf " %${MENU_UI_WIDTH_NUM}s${gap}%-${MENU_UI_WIDTH_MARK}s${gap}%-${MENU_UI_WIDTH_FILE}s${gap}%-${MENU_UI_WIDTH_SOURCE}s${gap}%-${MENU_UI_WIDTH_LINKED}s${gap}%-${MENU_UI_WIDTH_ACTION}s\n" \
        "$MENU_UI_HDR_NUM" "$MENU_UI_HDR_MARK" "$MENU_UI_HDR_FILE" "$MENU_UI_HDR_SOURCE" "$MENU_UI_HDR_LINKED" "$MENU_UI_HDR_ACTION"
    dotfiles_menu_ui_sep_line
    for line in "${_menu_entries[@]}"; do
        st="$(dotfiles_status_for_file "$line")"
        c="$(dotfiles_status_color "$st")"
        # Cor só no marcador e nas colunas à direita (ANSI quebra o alinhamento no nome).
        # shellcheck disable=SC2059
        printf " %s%${MENU_UI_WIDTH_NUM}d%s${gap}%s%-${MENU_UI_WIDTH_MARK}s%s${gap}%-${MENU_UI_WIDTH_FILE}s${gap}%s%-${MENU_UI_WIDTH_SOURCE}s${gap}%-${MENU_UI_WIDTH_LINKED}s${gap}%-${MENU_UI_WIDTH_ACTION}s%s\n" \
            "$B" "$i" "$R" \
            "$c" "$(dotfiles_status_mark "$st")" "$R" \
            "$line" \
            "$c" "$(dotfiles_status_source "$st")" \
            "$(dotfiles_status_linked_checkbox "$st")" \
            "$(dotfiles_status_action "$st")" "$R"
        i=$((i + 1))
    done
    dotfiles_menu_ui_sep_line
    dotfiles_menu_print_legend
    echo ""
}

# Explica os símbolos; duas variantes conforme cores ativas ou não.
dotfiles_menu_print_legend() {
    if [[ -n "$C_INST" ]]; then
        echo "Legenda: ${C_INST}[+]${R} ok  ${C_NONE}[ ]${R} falta  ${C_IMP}[~]${R} importar desde ~  ${C_MISS}[-]${R} sem fonte  ${C_WRONG}[!]${R} link errado  ${C_BLOCK}[#]${R} bloqueado"
    else
        echo "Legenda: [+] ok  [ ] falta  [~] importar desde ~  [-] sem fonte  [!] link errado  [#] bloqueado"
    fi
}
