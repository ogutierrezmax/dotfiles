#!/usr/bin/env bash
# Menu interativo principal (Menu Pai) com os filhos `dotfiles` e `packages`,
# além dos comandos globais do repositório.
#
# Uso:
#   ./dotfiles-menu.sh             # Abre no Menu Pai
#   ./dotfiles-menu.sh dotfiles    # Abre direto na view de Dotfiles
#   ./dotfiles-menu.sh packages    # Abre direto na view de Packages
set -euo pipefail

# Bootstrap mínimo: descobre o repo root via dotfiles_repo_root() após carregar a lib.
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/scripts/dotfiles-lib.sh"
# shellcheck disable=SC1091
source "$(dotfiles_repo_root)/scripts/dotfiles-menu-ui.sh"
# shellcheck disable=SC1091
source "$(dotfiles_repo_root)/scripts/dotfiles-menu-commands.sh"
# shellcheck disable=SC1091
source "$(dotfiles_repo_root)/scripts/dotfiles-menu-git.sh"
# shellcheck disable=SC1091
source "$(dotfiles_repo_root)/scripts/install-packages.sh"
# shellcheck disable=SC1091
source "$(dotfiles_repo_root)/scripts/dotfiles-menu-packages.sh"

# Controla alternância direta entre views irmãs (dotfiles <-> packages) sem empilhar loops.
DOTFILES_MENU_NEXT_VIEW=""

# View filha: Dotfiles (config/dotfile-names.list).
dotfiles_menu_dotfiles_view() {
    local -a entries=()
    local raw_choice trimmed choice file

    mapfile -t entries < <(dotfiles_dotfile_names_entries)

    if ((${#entries[@]} == 0)); then
        DOTFILES_MENU_ALERT="Nenhuma entrada em $(dotfiles_dotfile_names_path)."
        return 0
    fi

    while true; do
        dotfiles_menu_render entries

        read -r -p "dotfiles> " raw_choice || true
        trimmed="$(dotfiles_menu_trim "$raw_choice")"

        # Voltar ao Menu Pai: Enter vazio, 0, v, voltar, back, q
        case "${trimmed,,}" in
            "" | 0 | v | voltar | back | q | quit | exit)
                return 0
                ;;
            pkgs | packages)
                DOTFILES_MENU_NEXT_VIEW="packages"
                return 0
                ;;
        esac

        if dotfiles_menu_try_install_all "$trimmed"; then
            continue
        fi

        if dotfiles_menu_try_global_commands "$trimmed"; then
            continue
        fi

        if dotfiles_menu_try_add "$trimmed" entries; then
            continue
        fi

        # rm2, rm 3, etc.: sem espaços no meio do padrão.
        choice="${raw_choice//[[:space:]]/}"

        if dotfiles_menu_try_rm "$choice" entries; then
            continue
        fi

        # Resto deve ser índice numérico (linha da tabela).
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            DOTFILES_MENU_ALERT="Opção não reconhecida. Use número, rmN, add ou 0 para voltar."
            continue
        fi
        if ((choice < 1 || choice > ${#entries[@]})); then
            DOTFILES_MENU_ALERT="Número inválido (use 1–${#entries[@]} ou 0 para voltar)."
            continue
        fi

        file="${entries[$((choice - 1))]}"

        # act_on_entry: return 0 = nada mais a fazer nesta escolha; 1 = falta dotfiles_link_one.
        if dotfiles_menu_act_on_entry "$file"; then
            continue
        fi

        echo ""
        dotfiles_link_one "$file"
        DOTFILES_MENU_ALERT="Feito."
    done
}

main() {
    local raw_choice trimmed initial_arg=${1:-}

    # config/dotfile-names.list obrigatório.
    if [[ ! -f "$(dotfiles_dotfile_names_path)" ]]; then
        echo "Erro: config/dotfile-names.list não encontrado: $(dotfiles_dotfile_names_path)" >&2
        exit 1
    fi

    dotfiles_term_colors_init
    dotfiles_repo_initial_fetch

    case "${initial_arg,,}" in
        dotfiles | df | 1)
            DOTFILES_MENU_NEXT_VIEW="dotfiles"
            ;;
        packages | pkgs | 2)
            DOTFILES_MENU_NEXT_VIEW="packages"
            ;;
        "")
            ;;
        *)
            DOTFILES_MENU_ALERT="Argumento '${initial_arg}' não reconhecido. Use 'dotfiles' ou 'packages'."
            ;;
    esac

    while true; do
        if [[ "$DOTFILES_MENU_NEXT_VIEW" == "dotfiles" ]]; then
            DOTFILES_MENU_NEXT_VIEW=""
            dotfiles_menu_dotfiles_view
            continue
        elif [[ "$DOTFILES_MENU_NEXT_VIEW" == "packages" ]]; then
            DOTFILES_MENU_NEXT_VIEW=""
            dotfiles_menu_packages_view
            continue
        fi

        dotfiles_menu_root_render

        read -r -p "Opção: " raw_choice || true
        trimmed="$(dotfiles_menu_trim "$raw_choice")"

        case "${trimmed,,}" in
            "" | 0 | q | quit | exit | sair)
                echo "Até logo."
                dotfiles_menu_ui_sep_line
                exit 0
                ;;
            1 | dotfiles | df)
                dotfiles_menu_dotfiles_view
                continue
                ;;
            2 | packages | pkgs)
                dotfiles_menu_packages_view
                continue
                ;;
        esac

        if dotfiles_menu_try_global_commands "$trimmed"; then
            continue
        fi

        DOTFILES_MENU_ALERT="Opção não reconhecida. Use 1 (dotfiles), 2 (packages) ou um comando da lista acima."
    done
}

main "$@"
