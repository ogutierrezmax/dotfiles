#!/usr/bin/env bash
# Cores e rótulos do menu interativo (dotfiles-menu.sh).
# Estados vêm de dotfiles_status_for_file (dotfiles-lib.sh).
# Layout (espaços entre colunas, larguras, cabeçalhos): config/menu-ui.conf
# shellcheck disable=SC2034  # R, B, C_MARK_*, C_SOURCE_*, C_LINK_STATUS_{LINKED,UNLINKED,WRONG} são globais para printf

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
    : "${MENU_UI_WIDTH_LINK_STATUS:=6}"
    : "${MENU_UI_WIDTH_ACTION:=30}"
    : "${MENU_UI_HDR_NUM:=#}"
    MENU_UI_HDR_MARK="${MENU_UI_HDR_MARK:-$_hdr_mark_def}"
    : "${MENU_UI_HDR_FILE:=ficheiro}"
    : "${MENU_UI_HDR_SOURCE:=source}"
    : "${MENU_UI_HDR_LINK_STATUS:=link status}"
    : "${MENU_UI_HDR_ACTION:=Action}"
}

# Largura aproximada da linha da tabela (para o separador ───).
dotfiles_menu_ui_table_width() {
    local g=$((MENU_UI_COL_GAP))
    echo $((1 + MENU_UI_WIDTH_NUM + g + MENU_UI_WIDTH_MARK + g + MENU_UI_WIDTH_FILE + g + MENU_UI_WIDTH_SOURCE + g + MENU_UI_WIDTH_LINK_STATUS + g + MENU_UI_WIDTH_ACTION))
}

dotfiles_menu_ui_sep_line() {
    local w
    w="$(dotfiles_menu_ui_table_width)"
    printf '%*s' "$w" '' | sed 's/ /─/g'
    echo
}

# Primeiro plano ANSI truecolor: \033[38;2;R;G;Bm (requer terminal com suporte a 24-bit).
# Comentários #RRGGBB ao lado: o Cursor/VS Code (Color Highlight, etc.) mostram o quadradinho de cor.
dotfiles_menu_ansi_fg_rgb() {
    printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"
}

# Mesma sequência a partir de uma string "R G B", "R;G;B" ou "R,G,B" (0–255).
dotfiles_menu_ansi_fg_rgb_str() {
    local _r _g _b
    IFS=' ;,' read -r _r _g _b <<< "$1"
    dotfiles_menu_ansi_fg_rgb "$_r" "$_g" "$_b"
}

# A partir de #RRGGBB (ideal para preview de cor no IDE).
dotfiles_menu_ansi_fg_hex() {
    local h=${1#"#"}
    [[ "${#h}" -eq 6 ]] || return 1
    dotfiles_menu_ansi_fg_rgb $((16#${h:0:2})) $((16#${h:2:2})) $((16#${h:4:2}))
}

# --- Cores ANSI por coluna (só se stdout for TTY e NO_COLOR não estiver definido) ---
dotfiles_term_colors_init() {
    if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
        R=$'\033[0m'
        B=$'\033[1m'
        # Coluna marcador ([+], [ ], …) — #RRGGBB para preview no editor
        C_MARK_INST="$(dotfiles_menu_ansi_fg_hex '#22c55e')"   # installed
        C_MARK_NONE="$(dotfiles_menu_ansi_fg_hex '#eab308')"    # falta instalar
        C_MARK_IMP="$(dotfiles_menu_ansi_fg_hex '#06b6d4')"    # importável
        C_MARK_MISS="$(dotfiles_menu_ansi_fg_hex '#6b7280')"   # sem fonte
        C_MARK_WRONG="$(dotfiles_menu_ansi_fg_hex '#a855f7')"  # link errado
        C_MARK_BLOCK="$(dotfiles_menu_ansi_fg_hex '#ef4444')"   # bloqueado
        # Coluna source (data, ~, none, …)
        C_SOURCE_INST="$(dotfiles_menu_ansi_fg_hex '#22c55e')"
        C_SOURCE_NONE="$(dotfiles_menu_ansi_fg_hex '#eab308')"
        C_SOURCE_IMP="$(dotfiles_menu_ansi_fg_hex '#06b6d4')"
        C_SOURCE_MISS="$(dotfiles_menu_ansi_fg_hex '#6b7280')"
        C_SOURCE_WRONG="$(dotfiles_menu_ansi_fg_hex '#a855f7')"
        C_SOURCE_BLOCK="$(dotfiles_menu_ansi_fg_hex '#ef4444')"
        # Coluna link status: só 3 tipos (Linked / Unlinked / wrong target) → 3 cores
        C_LINK_STATUS_LINKED="$(dotfiles_menu_ansi_fg_hex '#22c55e')"    # symlink ok
        C_LINK_STATUS_UNLINKED="$(dotfiles_menu_ansi_fg_hex '#eab308')" # sem link ou não aplicável
        C_LINK_STATUS_WRONG="$(dotfiles_menu_ansi_fg_hex '#a855f7')"     # aponta para sítio errado
        C_LINK_STATUS_MODIFIED="$(dotfiles_menu_ansi_fg_hex '#f59e0b')"  # symlink ok, mas ficheiro modificado
        C_GIT_SYNC_WARN="$(dotfiles_menu_ansi_fg_hex '#f59e0b')"         # aviso git vs remoto
    else
        R= B=
        C_MARK_INST= C_MARK_NONE= C_MARK_IMP= C_MARK_MISS= C_MARK_WRONG= C_MARK_BLOCK=
        C_SOURCE_INST= C_SOURCE_NONE= C_SOURCE_IMP= C_SOURCE_MISS= C_SOURCE_WRONG= C_SOURCE_BLOCK=
        C_LINK_STATUS_LINKED= C_LINK_STATUS_UNLINKED= C_LINK_STATUS_WRONG= C_LINK_STATUS_MODIFIED=
        C_GIT_SYNC_WARN=
    fi
}

# Avisos de git (alterações locais / ahead / behind do remoto).
dotfiles_menu_print_git_sync_warnings() {
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        if [[ -n "${C_GIT_SYNC_WARN:-}" ]]; then
            echo "${C_GIT_SYNC_WARN}🔴 ${line}${R}"
        else
            echo "🔴 ${line}"
        fi
    done < <(dotfiles_repo_git_sync_warnings)
}

# --- Cor ANSI por coluna (estado = saída de dotfiles_status_for_file) ---

dotfiles_menu_column_color_mark() {
    case "$1" in
        installed|installed_modified) echo "$C_MARK_INST" ;;
        not_installed) echo "$C_MARK_NONE" ;;
        importable) echo "$C_MARK_IMP" ;;
        unavailable) echo "$C_MARK_MISS" ;;
        wrong_target) echo "$C_MARK_WRONG" ;;
        blocking_file) echo "$C_MARK_BLOCK" ;;
        *) echo "" ;;
    esac
}

dotfiles_menu_column_color_source() {
    case "$1" in
        installed|installed_modified) echo "$C_SOURCE_INST" ;;
        not_installed) echo "$C_SOURCE_NONE" ;;
        importable) echo "$C_SOURCE_IMP" ;;
        unavailable) echo "$C_SOURCE_MISS" ;;
        wrong_target) echo "$C_SOURCE_WRONG" ;;
        blocking_file) echo "$C_SOURCE_BLOCK" ;;
        *) echo "" ;;
    esac
}

# Só três tipos na coluna: Linked, Unlinked, wrong target (cores alinhadas a estes rótulos).
dotfiles_menu_column_color_link_status() {
    case "$1" in
        installed) echo "$C_LINK_STATUS_LINKED" ;;
        installed_modified) echo "$C_LINK_STATUS_MODIFIED" ;;
        wrong_target) echo "$C_LINK_STATUS_WRONG" ;;
        not_installed|importable|unavailable|blocking_file) echo "$C_LINK_STATUS_UNLINKED" ;;
        *) echo "" ;;
    esac
}

# Colunas à direita: origem, link status, ação sugerida.
dotfiles_status_source() {
    case "$1" in
        installed|installed_modified|not_installed|wrong_target) echo "data" ;;
        importable) echo "~" ;;
        unavailable) echo "none" ;;
        blocking_file) echo "~ & data" ;;
        *) echo "?" ;;
    esac
}

# Coluna link status: exatamente três rótulos — Linked, Unlinked, wrong target (só ASCII no texto).
dotfiles_status_link_status_text() {
    case "$1" in
        installed) echo "Linked" ;;
        installed_modified) echo "Linked (!)" ;;
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
        installed|installed_modified|not_installed) echo "-" ;;
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
        installed|installed_modified) echo "[+]" ;;
        wrong_target) echo "[!]" ;;
        *) echo "[?]" ;;
    esac
}

# Quebra texto em linhas até largura máxima (preferência por espaços: fold -s).
# Largura é em unidades de fold (tipicamente bytes; nomes de ficheiro ASCII alinham bem ao terminal).
dotfiles_menu_wrap_to_lines() {
    local text=${1:-} width=$2
    if [[ -z "$text" ]]; then
        printf '%s\n' ''
        return 0
    fi
    fold -s -w "$width" <<< "$text"
}

# Largura visual do bloco antes da coluna "ficheiro" (espaço + # + gap + marcador + gap).
dotfiles_menu_ui_prefix_before_file() {
    echo $((1 + MENU_UI_WIDTH_NUM + MENU_UI_COL_GAP + MENU_UI_WIDTH_MARK + MENU_UI_COL_GAP))
}

# Cabeçalho + uma linha por entrada (config/links.list) + legenda.
# Argumento: nome do array bash (nameref), ex.: dotfiles_menu_render entries
dotfiles_menu_render() {
    local -n _menu_entries=$1
    local line st c_mark c_source c_link_status i=1 gap prefix_w
    local -a _wrap_file _wrap_action
    local _k _nf _na _n=0 fline aline
    dotfiles_menu_ui_load_config
    printf -v gap '%*s' "$MENU_UI_COL_GAP" ''
    prefix_w="$(dotfiles_menu_ui_prefix_before_file)"

    printf '\n\n\n\n\n\n\n\n\n\n'
    dotfiles_menu_ui_sep_line
    echo "${B}Dotfiles — estado em ${HOME}${R}"
    dotfiles_menu_print_git_sync_warnings
    dotfiles_menu_ui_sep_line
    # shellcheck disable=SC2059
    printf " %${MENU_UI_WIDTH_NUM}s${gap}%-${MENU_UI_WIDTH_MARK}s${gap}%-${MENU_UI_WIDTH_FILE}s${gap}%-${MENU_UI_WIDTH_SOURCE}s${gap}%-${MENU_UI_WIDTH_LINK_STATUS}s${gap}%-${MENU_UI_WIDTH_ACTION}s\n" \
        "$MENU_UI_HDR_NUM" "$MENU_UI_HDR_MARK" "$MENU_UI_HDR_FILE" "$MENU_UI_HDR_SOURCE" "$MENU_UI_HDR_LINK_STATUS" "$MENU_UI_HDR_ACTION"
    dotfiles_menu_ui_sep_line
    for line in "${_menu_entries[@]}"; do
        st="$(dotfiles_status_for_file "$line")"
        if [[ "$st" == "installed" ]] && dotfiles_file_has_changes "$line"; then
            st="installed_modified"
        fi
        c_mark="$(dotfiles_menu_column_color_mark "$st")"
        c_source="$(dotfiles_menu_column_color_source "$st")"
        c_link_status="$(dotfiles_menu_column_color_link_status "$st")"
        mapfile -t _wrap_file < <(dotfiles_menu_wrap_to_lines "$line" "$MENU_UI_WIDTH_FILE")
        mapfile -t _wrap_action < <(dotfiles_menu_wrap_to_lines "$(dotfiles_status_action "$st")" "$MENU_UI_WIDTH_ACTION")
        _nf=${#_wrap_file[@]}
        _na=${#_wrap_action[@]}
        ((_nf < 1)) && _nf=1
        ((_na < 1)) && _na=1
        ((_nf > _na)) && _n=$_nf || _n=$_na
        for ((_k = 0; _k < _n; _k++)); do
            fline="${_wrap_file[_k]:-}"
            aline="${_wrap_action[_k]:-}"
            if ((_k == 0)); then
                # ANSI fora dos %-Ns (marcador, source, link status); nome do ficheiro sem cor.
                # shellcheck disable=SC2059
                printf " %s%${MENU_UI_WIDTH_NUM}d%s${gap}%s%-${MENU_UI_WIDTH_MARK}s%s${gap}%-${MENU_UI_WIDTH_FILE}s${gap}%s%-${MENU_UI_WIDTH_SOURCE}s${gap}%s%-${MENU_UI_WIDTH_LINK_STATUS}s%s${gap}%-${MENU_UI_WIDTH_ACTION}s%s\n" \
                    "$B" "$i" "$R" \
                    "$c_mark" "$(dotfiles_status_mark "$st")" "$R" \
                    "$fline" \
                    "$c_source" "$(dotfiles_status_source "$st")" \
                    "$c_link_status" "$(dotfiles_status_link_status_text "$st")" "$R" \
                    "$aline" "$R"
            else
                # Continuação: colunas # e marcador vazias; source e link status vazios; file e action com linhas extra.
                # shellcheck disable=SC2059
                printf "%*s%-${MENU_UI_WIDTH_FILE}s${gap}%-${MENU_UI_WIDTH_SOURCE}s${gap}%-${MENU_UI_WIDTH_LINK_STATUS}s${gap}%-${MENU_UI_WIDTH_ACTION}s\n" \
                    "$prefix_w" '' "$fline" '' '' "$aline"
            fi
        done
        i=$((i + 1))
    done
    dotfiles_menu_ui_sep_line
    dotfiles_menu_print_legend
    echo ""
    dotfiles_menu_print_command_help
    echo ""
}

# Explica os símbolos; duas variantes conforme cores ativas ou não (cores da coluna marcador).
dotfiles_menu_print_legend() {
    if [[ -n "$C_MARK_INST" ]]; then
        echo "Legenda: ${C_MARK_INST}[+]${R} ok  ${C_MARK_NONE}[ ]${R} falta  ${C_MARK_IMP}[~]${R} importar desde ~  ${C_MARK_MISS}[-]${R} sem fonte  ${C_MARK_WRONG}[!]${R} link errado  ${C_MARK_BLOCK}[#]${R} bloqueado"
        echo "         ${C_LINK_STATUS_MODIFIED}(!)${R} ficheiro com alterações não commitadas"
    else
        echo "Legenda: [+] ok  [ ] falta  [~] importar desde ~  [-] sem fonte  [!] link errado  [#] bloqueado"
        echo "         (!) ficheiro com alterações não commitadas"
    fi
}

# Instruções de add / rm / escolha de linha (alinhado ao prompt em dotfiles-menu.sh).
dotfiles_menu_print_command_help() {
    local _w _pad
    dotfiles_menu_ui_load_config
    _w="$(dotfiles_menu_ui_table_width)"
    printf -v _pad '%*s' "$_w" ''
    _pad="${_pad// /─}"

    echo "$_pad"
    echo "${B}Comandos${R}"
    printf '  %-18s  %s\n' "- add <nome>"
    printf '  %-18s  %s\n' "- rm <numero da linha>"
    printf '  %-18s  %s\n' "- <N> + enter               ação da coluna action"
    printf '  %-18s  %s\n' "- Enter (vazio)             Sai do menu."
    echo "$_pad"
}
