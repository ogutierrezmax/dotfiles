#!/usr/bin/env bash
# View interativa de Packages (config/install-packages.list) para o dotfiles-menu.sh.
# Requer scripts/dotfiles-lib.sh, scripts/dotfiles-menu-ui.sh, scripts/dotfiles-menu-commands.sh
# e scripts/install-packages.sh carregados previamente.
# shellcheck disable=SC2034,SC2154  # R, B, C_MARK_*, C_SOURCE_*, C_LINK_STATUS_*, C_FILE_PATH, DOTFILES_MENU_ALERT, DOTFILES_MENU_NEXT_VIEW são globais compartilhadas

declare -gA _DOTFILES_PKG_DPKG_CACHE=()

# Carrega em lote o estado de todos os pacotes dpkg instalados (~60ms no total),
# evitando dezenas de chamadas individuais a dpkg-query durante a renderização.
dotfiles_pkg_preload_status_cache() {
    local pkg
    _DOTFILES_PKG_DPKG_CACHE=()
    if command -v dpkg-query >/dev/null 2>&1; then
        while IFS= read -r pkg; do
            [[ -n "$pkg" ]] && _DOTFILES_PKG_DPKG_CACHE["$pkg"]=1
        done < <(dpkg-query -W -f='${Package}\t${Status}\n' 2>/dev/null | awk -F'\t' '$2 == "install ok installed" {print $1}')
    fi
}

# Retorna o estado de uma entrada:
#   installed | not_installed | no_manager | script | manual
dotfiles_pkg_fast_status() {
    local manager=$1 value=$2 bin
    case "$manager" in
        manual)
            echo "manual"
            return
            ;;
        script)
            echo "script"
            return
            ;;
        apt)
            if [[ -n "${_DOTFILES_PKG_DPKG_CACHE[$value]:-}" ]]; then
                echo "installed"
            else
                echo "not_installed"
            fi
            return
            ;;
        deb)
            bin="${value%%|*}"
            if [[ -n "${_DOTFILES_PKG_DPKG_CACHE[$bin]:-}" ]]; then
                echo "installed"
            else
                echo "not_installed"
            fi
            return
            ;;
        *)
            if ! dotfiles_pkg_manager_available "$manager"; then
                echo "no_manager"
            elif dotfiles_pkg_is_installed "$manager" "$value"; then
                echo "installed"
            else
                echo "not_installed"
            fi
            return
            ;;
    esac
}

# Calcula contadores de resumo de config/install-packages.list:
# Imprime: "<instalados> <total_instalavel> <faltando> <sem_gerenciador> <manuais_e_scripts>"
dotfiles_pkg_summary_counts() {
    local manager value st
    local installed=0 total=0 missing=0 no_mgr=0 extra=0
    dotfiles_pkg_preload_status_cache
    while IFS=$'\t' read -r manager value; do
        st="$(dotfiles_pkg_fast_status "$manager" "$value")"
        case "$st" in
            installed)
                installed=$((installed + 1))
                total=$((total + 1))
                ;;
            not_installed)
                missing=$((missing + 1))
                total=$((total + 1))
                ;;
            no_manager)
                no_mgr=$((no_mgr + 1))
                total=$((total + 1))
                ;;
            script | manual)
                extra=$((extra + 1))
                ;;
        esac
    done < <(dotfiles_pkg_entries 2>/dev/null || true)
    printf '%d %d %d %d %d\n' "$installed" "$total" "$missing" "$no_mgr" "$extra"
}

# Nome curto amigável para exibir na coluna Name da tabela.
dotfiles_pkg_display_name() {
    local manager=$1 value=$2 title
    case "$manager" in
        deb)
            echo "${value%%|*}"
            ;;
        manual)
            title="${value%%:*}"
            title="${title#[Ii]nstalar }"
            # Se tiver observação longa entre parênteses no título, encurta para a coluna Name
            if ((${#title} > 20)) && [[ "$title" == *" ("* ]]; then
                title="${title%% (*}"
            fi
            echo "$title"
            ;;
        script)
            # Extrai repo/arquivo ou basename da URL para leitura rápida
            local clean="${value#https://}"
            clean="${clean#http://}"
            clean="${clean#raw.githubusercontent.com/}"
            echo "$clean"
            ;;
        *)
            echo "$value"
            ;;
    esac
}

# Marcador curto ASCII ([+], [ ], [~], [i], [-]).
dotfiles_pkg_status_mark() {
    case "$1" in
        installed)     echo "[+]" ;;
        not_installed) echo "[ ]" ;;
        script)        echo "[~]" ;;
        manual)        echo "[i]" ;;
        no_manager)    echo "[-]" ;;
        *)             echo "[?]" ;;
    esac
}

# Texto da coluna status (alinhado ao estilo de dotfiles).
dotfiles_pkg_status_text() {
    case "$1" in
        installed)     echo "Installed" ;;
        not_installed) echo "Missing" ;;
        script)        echo "Script" ;;
        manual)        echo "Manual" ;;
        no_manager)    echo "No manager" ;;
        *)             echo "?" ;;
    esac
}

# Texto da coluna Action.
dotfiles_pkg_status_action() {
    local st=$1 manager=$2 value=$3
    case "$st" in
        installed)
            echo "-"
            ;;
        not_installed)
            if [[ "$manager" == "deb" ]]; then
                echo "download & install (.deb)"
            else
                echo "install (${manager})"
            fi
            ;;
        no_manager)
            dotfiles_pkg_manager_hint "$manager"
            ;;
        script)
            echo "run installer (confirm)"
            ;;
        manual)
            if [[ "$value" == *:* ]]; then
                local instr="${value#*:}"
                instr="${instr#"${instr%%[![:space:]]*}"}"
                echo "$instr"
            else
                echo "$value"
            fi
            ;;
        *)
            echo "?"
            ;;
    esac
}

# Cores ANSI por estado de pacote.
dotfiles_pkg_color_mark() {
    case "$1" in
        installed)     echo "$C_MARK_INST" ;;
        not_installed) echo "$C_MARK_NONE" ;;
        script|manual) echo "$C_MARK_IMP" ;;
        no_manager)    echo "$C_MARK_MISS" ;;
        *)             echo "" ;;
    esac
}

dotfiles_pkg_color_status() {
    case "$1" in
        installed)     echo "$C_LINK_STATUS_LINKED" ;;
        not_installed) echo "$C_LINK_STATUS_UNLINKED" ;;
        script|manual) echo "$C_MARK_IMP" ;;
        no_manager)    echo "$C_MARK_MISS" ;;
        *)             echo "" ;;
    esac
}

# Legenda da view de packages.
dotfiles_menu_packages_print_legend() {
    if [[ -n "${C_MARK_INST:-}" ]]; then
        echo "Legenda: ${C_MARK_INST}[+]${R} instalado  ${C_MARK_NONE}[ ]${R} faltando  ${C_MARK_IMP}[~]${R} script  ${C_MARK_IMP}[i]${R} manual  ${C_MARK_MISS}[-]${R} sem gerenciador"
    else
        echo "Legenda: [+] instalado  [ ] faltando  [~] script  [i] manual  [-] sem gerenciador"
    fi
}

# Bloco de ajuda de comandos exclusivo da view de packages (+ linha de atalhos globais).
dotfiles_menu_packages_print_command_help() {
    local _w _pad
    dotfiles_menu_ui_load_config
    _w="$(dotfiles_menu_ui_table_width)"
    printf -v _pad '%*s' "$_w" ''
    _pad="${_pad// /─}"

    echo "$_pad"
    echo "${B}Comandos (Packages)${R}"
    printf '  %-26s  %s\n' "- <Número da linha>" "Instalar pacote / rodar script / ver instrução manual"
    printf '  %-26s  %s\n' "- install-all" "Instalar todos os pacotes faltantes (com confirmação)"
    printf '  %-26s  %s\n' "- <gerenciador> | missing" "Filtrar lista (apt, deb, flatpak, snap, brew, npm, pipx, script, manual, missing, all)"
    printf '  %-26s  %s\n' "- add <mgr>:<valor>" "Adicionar pacote a config/install-packages.list (ex.: add apt:htop)"
    printf '  %-26s  %s\n' "- rm <Número da linha>" "Remover pacote da lista"
    printf '  %-26s  %s\n' "- 0 / v / Enter (vazio)" "Voltar ao Menu Principal"
    echo "${C_FILE_PATH:-}  Atalhos globais: dotfiles (df) │ commit │ pull │ push │ git │ term │ skills │ profiles${R:-}"
    echo "$_pad"
}

# Renderiza a tabela de pacotes (filtrada por $2 se definido) e preenche o array
# nameref $1 com as linhas visíveis no formato "manager<TAB>value<TAB>status".
dotfiles_menu_packages_render() {
    local -n _vis_entries=$1
    local active_filter=${2:-}
    local manager value st display action_txt
    local c_mark c_mgr c_status i=1 gap prefix_w
    local -a _wrap_name _wrap_action
    local _k _nf _na _n=0 fline aline
    local inst_cnt=0 tot_cnt=0 miss_cnt=0 nomgr_cnt=0 extra_cnt=0

    dotfiles_menu_ui_load_config
    dotfiles_pkg_preload_status_cache
    printf -v gap '%*s' "$MENU_UI_COL_GAP" ''
    prefix_w="$(dotfiles_menu_ui_prefix_before_file)"

    _vis_entries=()
    while IFS=$'\t' read -r manager value; do
        st="$(dotfiles_pkg_fast_status "$manager" "$value")"
        case "$st" in
            installed)     inst_cnt=$((inst_cnt + 1)); tot_cnt=$((tot_cnt + 1)) ;;
            not_installed) miss_cnt=$((miss_cnt + 1)); tot_cnt=$((tot_cnt + 1)) ;;
            no_manager)    nomgr_cnt=$((nomgr_cnt + 1)); tot_cnt=$((tot_cnt + 1)) ;;
            script|manual) extra_cnt=$((extra_cnt + 1)) ;;
        esac

        if [[ -n "$active_filter" ]]; then
            if [[ "$active_filter" == "missing" ]]; then
                [[ "$st" != "not_installed" && "$st" != "no_manager" ]] && continue
            elif [[ "$active_filter" == "installed" ]]; then
                [[ "$st" != "installed" ]] && continue
            elif [[ "$manager" != "$active_filter" ]]; then
                continue
            fi
        fi
        _vis_entries+=("${manager}"$'\t'"${value}"$'\t'"${st}")
    done < <(dotfiles_pkg_entries)

    printf '\n\n\n\n\n\n\n\n\n\n'
    dotfiles_menu_ui_sep_line
    local filter_badge=""
    if [[ -n "$active_filter" ]]; then
        filter_badge="  ${C_MARK_IMP:-}[filtro: ${active_filter}]${R:-}"
    fi
    echo "${B}Packages — config/install-packages.list${R}${filter_badge}"
    echo "${C_FILE_PATH:-}Resumo: ${C_MARK_INST:-}${inst_cnt}/${tot_cnt} instalados${R:-}${C_FILE_PATH:-} │ ${C_MARK_NONE:-}${miss_cnt} faltando${R:-}${C_FILE_PATH:-} │ ${extra_cnt} manuais/scripts${R:-}"
    dotfiles_menu_ui_sep_line
    # shellcheck disable=SC2059
    printf " %${MENU_UI_WIDTH_NUM}s${gap}%-${MENU_UI_WIDTH_MARK}s${gap}%-${MENU_UI_WIDTH_FILE}s${gap}%-${MENU_UI_WIDTH_SOURCE}s${gap}%-${MENU_UI_WIDTH_LINK_STATUS}s${gap}%-${MENU_UI_WIDTH_ACTION}s\n" \
        "$MENU_UI_HDR_NUM" "$MENU_UI_HDR_MARK" "Package" "manager" "status" "$MENU_UI_HDR_ACTION"
    dotfiles_menu_ui_sep_line

    if ((${#_vis_entries[@]} == 0)); then
        echo "  (Nenhum pacote corresponde ao filtro '${active_filter}'. Digite 'all' para mostrar todos.)"
    fi

    local row
    for row in "${_vis_entries[@]}"; do
        IFS=$'\t' read -r manager value st <<< "$row"
        display="$(dotfiles_pkg_display_name "$manager" "$value")"
        action_txt="$(dotfiles_pkg_status_action "$st" "$manager" "$value")"
        c_mark="$(dotfiles_pkg_color_mark "$st")"
        c_mgr="$c_mark"
        c_status="$(dotfiles_pkg_color_status "$st")"

        mapfile -t _wrap_name < <(dotfiles_menu_wrap_to_lines "$display" "$MENU_UI_WIDTH_FILE")
        mapfile -t _wrap_action < <(dotfiles_menu_wrap_to_lines "$action_txt" "$MENU_UI_WIDTH_ACTION")
        _nf=${#_wrap_name[@]}
        _na=${#_wrap_action[@]}
        ((_nf < 1)) && _nf=1
        ((_na < 1)) && _na=1
        ((_nf > _na)) && _n=$_nf || _n=$_na

        for ((_k = 0; _k < _n; _k++)); do
            fline="${_wrap_name[_k]:-}"
            aline="${_wrap_action[_k]:-}"
            local pad_len=$((MENU_UI_WIDTH_FILE - ${#fline}))
            ((pad_len < 0)) && pad_len=0
            local fline_padded
            printf -v fline_padded "%s%*s" "$fline" "$pad_len" ""

            if ((_k == 0)); then
                # shellcheck disable=SC2059
                printf " %s%${MENU_UI_WIDTH_NUM}d%s${gap}%s%-${MENU_UI_WIDTH_MARK}s%s${gap}%s${gap}%s%-${MENU_UI_WIDTH_SOURCE}s%s${gap}%s%-${MENU_UI_WIDTH_LINK_STATUS}s%s${gap}%-${MENU_UI_WIDTH_ACTION}s\n" \
                    "$B" "$i" "$R" \
                    "$c_mark" "$(dotfiles_pkg_status_mark "$st")" "$R" \
                    "$fline_padded" \
                    "$c_mgr" "$manager" "$R" \
                    "$c_status" "$(dotfiles_pkg_status_text "$st")" "$R" \
                    "$aline"
            else
                # shellcheck disable=SC2059
                printf "%*s%s${gap}%-${MENU_UI_WIDTH_SOURCE}s${gap}%-${MENU_UI_WIDTH_LINK_STATUS}s${gap}%-${MENU_UI_WIDTH_ACTION}s\n" \
                    "$prefix_w" '' "$fline_padded" '' '' "$aline"
            fi
        done
        i=$((i + 1))
    done

    dotfiles_menu_ui_sep_line
    dotfiles_menu_packages_print_legend
    echo ""
    dotfiles_menu_packages_print_command_help
    dotfiles_menu_render_alert
    dotfiles_menu_print_git_sync_warnings
    dotfiles_git_print_setup_banner
    DOTFILES_MENU_ALERT=""
    echo ""
}

# Executa a ação correspondente à linha selecionada na tabela de packages.
dotfiles_pkg_act_on_entry() {
    local manager=$1 value=$2 st=$3
    local display ans
    display="$(dotfiles_pkg_display_name "$manager" "$value")"

    case "$st" in
        not_installed)
            echo ""
            read -r -p "Instalar '${display}' via ${manager}? (sim/não): " ans || true
            if ! dotfiles_menu_is_yes "$ans"; then
                DOTFILES_MENU_ALERT="Instalação cancelada."
                return 0
            fi
            echo ""
            if dotfiles_pkg_install_one "$manager" "$value"; then
                DOTFILES_MENU_ALERT="Pacote '${display}' instalado com sucesso."
            else
                DOTFILES_MENU_ALERT="Falha ao instalar '${display}'."
            fi
            ;;
        installed)
            echo ""
            echo -e "${C_MARK_INST:-}✓ '${display}' (${manager}) já está instalado.${R:-}"
            read -r -p "Deseja reinstalar/atualizar '${display}' via ${manager}? (sim/não): " ans || true
            if dotfiles_menu_is_yes "$ans"; then
                echo ""
                if dotfiles_pkg_install_one "$manager" "$value"; then
                    DOTFILES_MENU_ALERT="Pacote '${display}' atualizado/reinstalado."
                else
                    DOTFILES_MENU_ALERT="Falha ao reinstalar '${display}'."
                fi
            fi
            ;;
        script)
            echo ""
            dotfiles_pkg_install_script "$value"
            DOTFILES_MENU_ALERT="Execução do script finalizada."
            ;;
        manual)
            echo ""
            dotfiles_menu_ui_sep_line
            echo -e "${B:-}📝 Instrução Manual — ${display}${R:-}"
            dotfiles_menu_ui_sep_line
            echo "  ${value}"
            dotfiles_menu_ui_sep_line
            read -r -p "Pressione Enter para continuar..." _ || true
            ;;
        no_manager)
            DOTFILES_MENU_ALERT="Gerenciador '${manager}' ausente: $(dotfiles_pkg_manager_hint "$manager")"
            ;;
    esac
}

# Trata comando "add" na view de packages: add <gerenciador>:<valor>
dotfiles_pkg_try_add() {
    local trimmed=$1
    local rest spec mgr val ans

    if [[ "$trimmed" =~ ^[Aa][Dd][Dd]$ ]]; then
        echo ""
        echo "${B}Uso de add (Packages)${R}"
        echo "  add apt:nome-do-pacote"
        echo "  add flatpak:org.app.Id"
        echo "  add npm:pacote-global"
        echo "  add deb:binario|https://url/pacote.deb"
        echo "  add manual:Instalar X: instruções..."
        echo "  Gerenciadores suportados: ${MANAGERS[*]}"
        echo ""
        read -r -p "Pressione Enter para continuar..." _ || true
        return 0
    fi

    if [[ "$trimmed" =~ ^[Aa][Dd][Dd][[:space:]]+(.+)$ ]]; then
        rest="$(dotfiles_menu_trim "${BASH_REMATCH[1]}")"
        spec="$(dotfiles_menu_parse_add_name "$rest")"
        if [[ "$spec" != *:* ]]; then
            DOTFILES_MENU_ALERT="Formato inválido. Use: add <gerenciador>:<valor> (ex.: add apt:htop)."
            return 0
        fi
        mgr="${spec%%:*}"
        val="${spec#*:}"
        mgr="$(dotfiles_menu_trim "$mgr")"
        val="$(dotfiles_menu_trim "$val")"

        if ! dotfiles_pkg_valid_manager "$mgr"; then
            DOTFILES_MENU_ALERT="Gerenciador inválido '${mgr}'. Use: ${MANAGERS[*]}"
            return 0
        fi
        if [[ -z "$val" ]]; then
            DOTFILES_MENU_ALERT="Erro: valor do pacote vazio."
            return 0
        fi
        read -r -p "Adicionar \"${mgr}:${val}\" a $(dotfiles_pkg_list_path)? (sim/não): " ans || true
        if ! dotfiles_menu_is_yes "$ans"; then
            return 0
        fi
        if dotfiles_pkg_add_entry "$mgr" "$val"; then
            DOTFILES_MENU_ALERT="Adicionado a config/install-packages.list: ${mgr}:${val}"
        fi
        return 0
    fi
    return 1
}

# Trata comando "rmN" / "rm N" na view de packages.
dotfiles_pkg_try_rm() {
    local choice="${1//[[:space:]]/}"
    local -n _rm_vis_entries=$2
    local rm_num row mgr val ans

    if [[ "${choice,,}" =~ ^rm([0-9]+)$ ]]; then
        rm_num="${BASH_REMATCH[1]}"
        if ((rm_num < 1 || rm_num > ${#_rm_vis_entries[@]})); then
            DOTFILES_MENU_ALERT="Número inválido para rm: use 1–${#_rm_vis_entries[@]}."
            return 0
        fi
        row="${_rm_vis_entries[$((rm_num - 1))]}"
        IFS=$'\t' read -r mgr val _ <<< "$row"
        read -r -p "Remover \"${mgr}:${val}\" de $(dotfiles_pkg_list_path)? (sim/não): " ans || true
        if ! dotfiles_menu_is_yes "$ans"; then
            return 0
        fi
        if dotfiles_pkg_remove_entry "$mgr" "$val"; then
            DOTFILES_MENU_ALERT="Removido de config/install-packages.list: ${mgr}:${val}"
        fi
        return 0
    fi
    return 1
}

# Verifica se o comando digitado é um filtro de gerenciador/status.
dotfiles_pkg_try_filter() {
    local trimmed=${1,,}
    local -n _filter_ref=$2
    local target=""

    if [[ "$trimmed" =~ ^filter[[:space:]]+(.+)$ ]]; then
        target="$(dotfiles_menu_trim "${BASH_REMATCH[1]}")"
    else
        target="$trimmed"
    fi

    case "$target" in
        all | todos | limpar | clear)
            _filter_ref=""
            DOTFILES_MENU_ALERT="Filtro removido (exibindo todos os pacotes)."
            return 0
            ;;
        missing | faltando | pendentes)
            _filter_ref="missing"
            DOTFILES_MENU_ALERT="Exibindo apenas pacotes não instalados (digite 'all' para todos)."
            return 0
            ;;
        installed | instalados)
            _filter_ref="installed"
            DOTFILES_MENU_ALERT="Exibindo apenas pacotes instalados (digite 'all' para todos)."
            return 0
            ;;
    esac

    if dotfiles_pkg_valid_manager "$target"; then
        _filter_ref="$target"
        DOTFILES_MENU_ALERT="Filtrando por gerenciador '${target}' (digite 'all' para todos)."
        return 0
    fi
    return 1
}

# Loop interativo da view de Packages.
dotfiles_menu_packages_view() {
    local -a vis_entries=()
    local raw_choice trimmed choice active_filter=""
    local row mgr val st

    if [[ ! -f "$(dotfiles_pkg_list_path)" ]]; then
        DOTFILES_MENU_ALERT="Erro: $(dotfiles_pkg_list_path) não encontrado."
        return 0
    fi

    while true; do
        dotfiles_menu_packages_render vis_entries "$active_filter"

        read -r -p "packages> " raw_choice || true
        trimmed="$(dotfiles_menu_trim "$raw_choice")"

        # Voltar ao Menu Pai: Enter vazio, 0, v, voltar, back, q
        case "${trimmed,,}" in
            "" | 0 | v | voltar | back | q | quit | exit)
                return 0
                ;;
            dotfiles | df)
                DOTFILES_MENU_NEXT_VIEW="dotfiles"
                return 0
                ;;
            install-all)
                echo ""
                FILTER="${active_filter}"
                if [[ "$FILTER" == "missing" || "$FILTER" == "installed" ]]; then
                    FILTER=""
                fi
                dotfiles_pkg_cmd_install
                FILTER=""
                DOTFILES_MENU_ALERT="Execução de install-all concluída."
                continue
                ;;
        esac

        if dotfiles_pkg_try_filter "$trimmed" active_filter; then
            continue
        fi

        if dotfiles_pkg_try_add "$trimmed"; then
            continue
        fi

        if dotfiles_menu_try_global_commands "$trimmed"; then
            continue
        fi

        choice="${raw_choice//[[:space:]]/}"
        if dotfiles_pkg_try_rm "$choice" vis_entries; then
            continue
        fi

        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            DOTFILES_MENU_ALERT="Opção não reconhecida. Use número da linha, install-all, gerenciador, add, rmN ou 0 para voltar."
            continue
        fi
        if ((choice < 1 || choice > ${#vis_entries[@]})); then
            DOTFILES_MENU_ALERT="Número inválido (use 1–${#vis_entries[@]} ou 0 para voltar)."
            continue
        fi

        row="${vis_entries[$((choice - 1))]}"
        IFS=$'\t' read -r mgr val st <<< "$row"
        dotfiles_pkg_act_on_entry "$mgr" "$val" "$st"
    done
}
