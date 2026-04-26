#!/usr/bin/env bash
# Menu interativo: lista o estado de cada entrada de config/dotfile-names.list e instala por número.
#
# Fluxo do loop: desenhar lista → ler comando → (commit | add | rm | número de linha).
# Para um número, dotfiles-lib decide o estado; menu-commands trata o caso ou deixa

# criar/atualizar o symlink em dotfiles_link_one (scripts/dotfiles-lib.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# O ShellCheck verifica scripts .sh e avisa sobre erros comuns, más práticas e problemas de portabilidade.

# shellcheck source=scripts/dotfiles-lib.sh
source "${SCRIPT_DIR}/scripts/dotfiles-lib.sh"
# shellcheck source=scripts/dotfiles-menu-ui.sh
source "${SCRIPT_DIR}/scripts/dotfiles-menu-ui.sh"
# shellcheck source=scripts/dotfiles-menu-commands.sh
source "${SCRIPT_DIR}/scripts/dotfiles-menu-commands.sh"

main() {
    local -a entries=()
    local raw_choice trimmed choice file

    # config/dotfile-names.list obrigatório.
    if [[ ! -f "$(dotfiles_dotfile_names_path)" ]]; then
        echo "Erro: config/dotfile-names.list não encontrado: $(dotfiles_dotfile_names_path)" >&2
        exit 1
    fi

    mapfile -t entries < <(dotfiles_dotfile_names_entries)

    if ((${#entries[@]} == 0)); then
        echo "Nenhuma entrada em $(dotfiles_dotfile_names_path)."
        exit 0
    fi

    dotfiles_term_colors_init

    while true; do
        dotfiles_menu_render entries

        read -r -p "Opção: " raw_choice || true
        # Só espaços ou Enter: sair sem erro.
        [[ -z "${raw_choice// }" ]] && echo "Até logo." && dotfiles_menu_ui_sep_line && exit 0

        # "add" usa o texto com espaços preservados; por isso trim à parte.
        trimmed="$(dotfiles_menu_trim "$raw_choice")"

        # try_add: return 0 = já tratámos (mensagem, confirmação ou escrita em config/dotfile-names.list).
        if dotfiles_menu_try_smart_commit "$trimmed"; then
            continue
        fi

        if dotfiles_menu_try_add "$trimmed" entries; then
            continue
        fi

        # rm2, rm 3, etc.: sem espaços no meio do padrão.
        choice="${raw_choice//[[:space:]]/}"

        # try_rm: return 0 = reconhecemos rmN (incl. erro de intervalo ou lista vazia).
        if dotfiles_menu_try_rm "$choice" entries; then
            continue
        fi

        # Resto deve ser índice numérico (linha da tabela).
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo "Opção não reconhecida. Use número, rmN ou add (ver o bloco de comandos acima)."
            continue
        fi
        if ((choice < 1 || choice > ${#entries[@]})); then
            echo "Número inválido (use 1–${#entries[@]})."
            continue
        fi

        file="${entries[$((choice - 1))]}"

        # act_on_entry: return 0 = nada mais a fazer nesta escolha; 1 = falta dotfiles_link_one.
        if dotfiles_menu_act_on_entry "$file"; then
            continue
        fi

        echo ""
        dotfiles_link_one "$file"
        echo "Feito."
    done
}

main "$@"
