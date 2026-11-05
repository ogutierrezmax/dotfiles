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
    : "${MENU_UI_HDR_FILE:=arquivo}"
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
        C_LINK_STATUS_MODIFIED="$(dotfiles_menu_ansi_fg_hex '#f59e0b')"  # symlink ok, mas arquivo modificado
        C_GIT_SYNC_WARN="$(dotfiles_menu_ansi_fg_hex '#f59e0b')"         # aviso git vs remoto
        C_FILE_PATH="$(dotfiles_menu_ansi_fg_hex '#6b7280')"             # caminho acinzentado
    else
        R="" B=""
        C_MARK_INST="" C_MARK_NONE="" C_MARK_IMP="" C_MARK_MISS="" C_MARK_WRONG="" C_MARK_BLOCK=""
        C_SOURCE_INST="" C_SOURCE_NONE="" C_SOURCE_IMP="" C_SOURCE_MISS="" C_SOURCE_WRONG="" C_SOURCE_BLOCK=""
        C_LINK_STATUS_LINKED="" C_LINK_STATUS_UNLINKED="" C_LINK_STATUS_WRONG="" C_LINK_STATUS_MODIFIED=""
        C_GIT_SYNC_WARN="" C_FILE_PATH=""
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
        not_installed) echo "link" ;;
        installed_modified) echo "commit" ;;
        installed) echo "-" ;;
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
# Largura é em unidades de fold (tipicamente bytes; nomes de arquivo ASCII alinham bem ao terminal).
dotfiles_menu_wrap_to_lines() {
    local text=${1:-} width=$2
    if [[ -z "$text" ]]; then
        printf '%s\n' ''
        return 0
    fi
    fold -s -w "$width" <<< "$text"
}

# Largura visual do bloco antes da coluna "arquivo" (espaço + # + gap + marcador + gap).
dotfiles_menu_ui_prefix_before_file() {
    echo $((1 + MENU_UI_WIDTH_NUM + MENU_UI_COL_GAP + MENU_UI_WIDTH_MARK + MENU_UI_COL_GAP))
}

# Formata o caminho do arquivo: path em cinza, nome em destaque (base_color ou default).
# offset é a posição inicial desta fatia (folded) na string original.
dotfiles_menu_ui_format_file_path() {
    local original=$1
    local folded=$2
    local base_color=$3
    local offset=$4
    local r=${R:-}

    local prefix="${original%/*}"
    if [[ "$prefix" == "$original" ]]; then
        echo "${base_color}${folded}${r}"
        return
    fi

    local last_slash_pos=${#prefix} # Index da barra
    local folded_len=${#folded}
    local end_pos=$((offset + folded_len - 1))

    # Se todo o folded está antes ou na barra
    if ((end_pos <= last_slash_pos)); then
        echo "${C_FILE_PATH}${folded}${r}"
        return
    fi

    # Se todo o folded está depois da barra
    if ((offset > last_slash_pos)); then
        echo "${base_color}${folded}${r}"
        return
    fi

    # O folded contém a transição
    local split_at=$((last_slash_pos - offset + 1))
    local part_path="${folded:0:split_at}"
    local part_file="${folded:split_at}"
    echo "${C_FILE_PATH}${part_path}${r}${base_color}${part_file}${r}"
}

# Mensagem de alerta exibida na parte inferior do menu (abaixo de tudo).
DOTFILES_MENU_ALERT=""

dotfiles_menu_render_alert() {
    local _w _pad
    _w="$(dotfiles_menu_ui_table_width)"
    printf -v _pad '%*s' "$_w" ''
    _pad="${_pad// /─}"
    echo "$_pad"
    if [[ -n "$DOTFILES_MENU_ALERT" ]]; then
        echo "${B}⚠ ${DOTFILES_MENU_ALERT}${R}"
    fi
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

        local offset=0
        for ((_k = 0; _k < _n; _k++)); do
            fline="${_wrap_file[_k]:-}"
            aline="${_wrap_action[_k]:-}"
            c_file=""
            [[ "$st" == "installed_modified" ]] && c_file="$C_LINK_STATUS_MODIFIED"

            # Formata o arquivo com path cinza e calcula padding manual (ANSI quebra printf %-Ns)
            formatted_fline="$(dotfiles_menu_ui_format_file_path "$line" "$fline" "$c_file" "$offset")"
            pad_len=$((MENU_UI_WIDTH_FILE - ${#fline}))
            ((pad_len < 0)) && pad_len=0
            printf -v fline_padded "%s%*s" "$formatted_fline" "$pad_len" ""
            offset=$((offset + ${#fline}))

            if ((_k == 0)); then
                # ANSI fora dos %-Ns (marcador, source, link status); nome do arquivo formatado acima.
                # shellcheck disable=SC2059
                printf " %s%${MENU_UI_WIDTH_NUM}d%s${gap}%s%-${MENU_UI_WIDTH_MARK}s%s${gap}%s${gap}%s%-${MENU_UI_WIDTH_SOURCE}s${gap}%s%-${MENU_UI_WIDTH_LINK_STATUS}s%s${gap}%-${MENU_UI_WIDTH_ACTION}s%s\n" \
                    "$B" "$i" "$R" \
                    "$c_mark" "$(dotfiles_status_mark "$st")" "$R" \
                    "$fline_padded" \
                    "$c_source" "$(dotfiles_status_source "$st")" \
                    "$c_link_status" "$(dotfiles_status_link_status_text "$st")" "$R" \
                    "$aline" "$R"
            else
                # Continuação: colunas # e marcador vazias; source e link status vazios; file e action com linhas extra.
                # shellcheck disable=SC2059
                printf "%*s%s${gap}%-${MENU_UI_WIDTH_SOURCE}s${gap}%-${MENU_UI_WIDTH_LINK_STATUS}s${gap}%-${MENU_UI_WIDTH_ACTION}s\n" \
                    "$prefix_w" '' "$fline_padded" '' '' "$aline"
            fi
        done
        i=$((i + 1))
    done
    dotfiles_menu_ui_sep_line
    dotfiles_menu_print_legend
    echo ""
    dotfiles_menu_print_command_help
    dotfiles_menu_render_alert
    dotfiles_menu_print_chunk_injector_warnings
    dotfiles_menu_print_git_sync_warnings
    dotfiles_git_print_setup_banner
    DOTFILES_MENU_ALERT=""
    echo ""
}

# Explica os símbolos; duas variantes conforme cores ativas ou não (cores da coluna marcador).
dotfiles_menu_print_legend() {
    if [[ -n "$C_MARK_INST" ]]; then
        echo "Legenda: ${C_MARK_INST}[+]${R} ok  ${C_MARK_NONE}[ ]${R} falta  ${C_MARK_IMP}[~]${R} importar desde ~  ${C_MARK_MISS}[-]${R} sem fonte  ${C_MARK_WRONG}[!]${R} link errado  ${C_MARK_BLOCK}[#]${R} bloqueado"
        echo "         ${C_LINK_STATUS_MODIFIED}(!)${R} arquivo com alterações não commitadas"
    else
        echo "Legenda: [+] ok  [ ] falta  [~] importar desde ~  [-] sem fonte  [!] link errado  [#] bloqueado"
        echo "         (!) arquivo com alterações não commitadas"
    fi
}

# Instruções de add / rm / escolha de linha na view Dotfiles.
dotfiles_menu_print_command_help() {
    local _w _pad
    dotfiles_menu_ui_load_config
    _w="$(dotfiles_menu_ui_table_width)"
    printf -v _pad '%*s' "$_w" ''
    _pad="${_pad// /─}"

    echo "$_pad"
    echo "${B}Comandos (Dotfiles)${R}"
    printf '  %-26s  %s\n' "- <Número da linha>" "Ação da coluna Action"
    printf '  %-26s  %s\n' "- install-all" "Instalar todos os dotfiles da lista"
    printf '  %-26s  %s\n' "- add <nome>" "Adicionar um novo dotfile a config/dotfile-names.list"
    printf '  %-26s  %s\n' "- rm <Número da linha>" "Remover um dotfile da lista"
    printf '  %-26s  %s\n' "- skills / skills doctor" "Reconstruir / diagnosticar bridge de skills (~/.agents/skills)"
    printf '  %-26s  %s\n' "- profiles" "Reconstruir symlinks dos perfis OpenCode"
    printf '  %-26s  %s\n' "- chunks / doctor / gui" "Injetar / diagnosticar / abrir GUI (config/chunks/*.json)"
    printf '  %-26s  %s\n' "- 0 / v / Enter (vazio)" "Voltar ao Menu Principal"
    echo "${C_FILE_PATH:-}  Atalhos globais: packages (pkgs) │ install │ commit │ pull │ push │ git │ term${R:-}"
    echo "$_pad"
}

# Calcula contadores de resumo de config/dotfile-names.list:
# Imprime: "<linkados> <total> <modificados> <pendentes>"
dotfiles_dotfiles_summary_counts() {
    local entry st
    local linked=0 total=0 modified=0 pending=0
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        total=$((total + 1))
        st="$(dotfiles_status_for_file "$entry")"
        if [[ "$st" == "installed" ]]; then
            linked=$((linked + 1))
            if dotfiles_file_has_changes "$entry"; then
                modified=$((modified + 1))
            fi
        else
            pending=$((pending + 1))
        fi
    done < <(dotfiles_dotfile_names_entries 2>/dev/null || true)
    printf '%d %d %d %d\n' "$linked" "$total" "$modified" "$pending"
}

# Renderiza o Menu Pai (Root Menu) com os filhos `dotfiles` e `packages` + comandos globais.
dotfiles_menu_root_render() {
    local df_linked=0 df_total=0 df_mod=0 df_pend=0
    local pkg_inst=0 pkg_tot=0 pkg_miss=0 pkg_nomgr=0 pkg_extra=0
    local df_badge pkg_badge

    dotfiles_menu_ui_load_config
    read -r df_linked df_total df_mod df_pend < <(dotfiles_dotfiles_summary_counts)
    if declare -F dotfiles_pkg_summary_counts >/dev/null 2>&1; then
        read -r pkg_inst pkg_tot pkg_miss pkg_nomgr pkg_extra < <(dotfiles_pkg_summary_counts)
    fi

    df_badge="${C_MARK_INST:-}${df_linked}/${df_total} linkados${R:-}"
    if ((df_pend > 0)); then
        df_badge+="  ${C_MARK_NONE:-}(${df_pend} pendente(s))${R:-}"
    fi
    if ((df_mod > 0)); then
        df_badge+="  ${C_LINK_STATUS_MODIFIED:-}(${df_mod} modificado(s))${R:-}"
    fi

    pkg_badge="${C_MARK_INST:-}${pkg_inst}/${pkg_tot} instalados${R:-}"
    if ((pkg_miss > 0)); then
        pkg_badge+="  ${C_MARK_NONE:-}(${pkg_miss} faltando)${R:-}"
    fi
    if ((pkg_extra > 0)); then
        pkg_badge+="  ${C_FILE_PATH:-}[+${pkg_extra} manuais/scripts]${R:-}"
    fi

    printf '\n\n\n\n\n\n\n\n\n\n'
    dotfiles_menu_ui_sep_line
    echo "${B}Dotfiles & Packages — Menu Principal (${HOME})${R}"
    dotfiles_menu_ui_sep_line
    echo "${B}Views (Submenus)${R}"
    printf "  %s1)%s %-22s  %s  %s\n" "$B" "$R" "dotfiles (df)" "$df_badge" "${C_FILE_PATH:-}— Symlinks em config/dotfile-names.list${R:-}"
    printf "  %s2)%s %-22s  %s  %s\n" "$B" "$R" "packages (pkgs)" "$pkg_badge" "${C_FILE_PATH:-}— Pacotes em config/install-packages.list${R:-}"
    dotfiles_menu_ui_sep_line
    echo "${B}Comandos do Repositório${R}"
    printf '  %-26s  %s\n' "- 1 / dotfiles (df)" "Abrir view de Dotfiles (symlinks, add, rm, install-all)"
    printf '  %-26s  %s\n' "- 2 / packages (pkgs)" "Abrir view de Packages (status de instalados, instalar, filtrar)"
    printf '  %-26s  %s\n' "- install" "Instalação completa (dotfiles + skills + perfis OpenCode)"
    printf '  %-26s  %s\n' "- skills / skills doctor" "Reconstruir / diagnosticar symlinks de skills (~/.agents/skills)"
    printf '  %-26s  %s\n' "- profiles" "Reconstruir symlinks dos perfis OpenCode"
    printf '  %-26s  %s\n' "- chunks / doctor / gui" "Injetar / diagnosticar / abrir GUI (config/chunks/*.json)"
    printf '  %-26s  %s\n' "- commit" "Smart commit (AI audita e agrupa alterações)"
    printf '  %-26s  %s\n' "- pull / push" "Sincronizar commits com o repositório remoto"
    printf '  %-26s  %s\n' "- git" "Submenu Git / SSH / GitHub"
    printf '  %-26s  %s\n' "- term / terminal" "Abrir terminal neste repositório"
    printf '  %-26s  %s\n' "- Enter (vazio) / q" "Sair do menu"
    dotfiles_menu_render_alert
    dotfiles_menu_print_chunk_injector_warnings
    dotfiles_menu_print_git_sync_warnings
    dotfiles_git_print_setup_banner
    DOTFILES_MENU_ALERT=""
    echo ""
}

# Exibe alerta no Menu Principal caso o cache do chunk-injector indique trechos ausentes.
dotfiles_menu_print_chunk_injector_warnings() {
    local alert_file="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/chunk-injector-alert.txt"
    [[ -s "$alert_file" ]] || return 0

    local line id status target selector desc count=0
    echo ""
    echo "${C_MARK_WRONG:-}⚠️  Chunk Injector: trecho(s) ausente(s) ou alterado(s):${R:-}"
    while IFS='|' read -r id status target selector desc; do
        [[ -z "$id" || "$id" == \#* ]] && continue
        count=$((count + 1))
        echo "   ${C_MARK_NONE:-}• ${id}${R:-} (${status}): ${target} [${selector}] — ${desc}"
    done <"$alert_file"
    if ((count > 0)); then
        echo "   ${C_FILE_PATH:-}→ Digite 'chunks' para restaurar, 'chunks doctor' para diagnosticar ou 'chunks gui' para abrir no desktop.${R:-}"
    fi
}
