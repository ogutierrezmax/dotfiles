#!/usr/bin/env bash
# Funções compartilhadas pelos scripts de instalação.
# Uso: source a partir da raiz do repositório (ex.: install.sh).

set -euo pipefail

dotfiles_repo_root() {
    (
        cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
    )
}

dotfiles_data_dir() {
    echo "$(dotfiles_repo_root)/data"
}

# Diretório de backups (raiz do repo): <repo>/.bkp
dotfiles_backup_dir() {
    echo "$(dotfiles_repo_root)/.bkp"
}

# Move o destino em ~ (ficheiro/pasta real, não symlink) para .bkp com slug
# DD-MM-AAAA_HH:MM_<basename> (basename = nome em ~, ex.: .zshrc).
# Retorna 0 se ok; 1 em erro.
dotfiles_move_blocking_dest_to_bkp() {
    local file=$1
    local dest bkp_dir base slug n
    dest="$(dotfiles_dest_for_file "$file")"
    bkp_dir="$(dotfiles_backup_dir)"

    if [[ ! -e "$dest" ]]; then
        echo "Erro: não existe ${dest}" >&2
        return 1
    fi
    if [[ -L "$dest" ]]; then
        echo "Erro: ${dest} é link simbólico (estado não é bloqueio)." >&2
        return 1
    fi

    base="$(basename "$dest")"
    mkdir -p "$bkp_dir"
    slug="$(date +%d-%m-%Y_%H:%M)_${base}"
    n=0
    while [[ -e "$bkp_dir/$slug" ]]; do
        n=$((n + 1))
        slug="$(date +%d-%m-%Y_%H:%M)_${base}_${n}"
    done

    echo "Backup: ${dest} → ${bkp_dir}/${slug}"
    mv -- "$dest" "$bkp_dir/$slug"
}

dotfiles_dotfile_names_path() {
    echo "$(dotfiles_repo_root)/config/dotfile-names.list"
}

# Caminho de destino em ~ para um nome relativo em data/ (ex.: gitconfig → ~/.gitconfig).
dotfiles_dest_for_file() {
    local file=$1
    if [[ "$file" == .* ]]; then
        echo "${HOME}/${file}"
    else
        echo "${HOME}/.${file}"
    fi
}

# Lista os nomes em config/dotfile-names.list (uma linha por nome relativo a data/).
dotfiles_dotfile_names_entries() {
    local names_file line file
    names_file="$(dotfiles_dotfile_names_path)"
    if [[ ! -f "$names_file" ]]; then
        echo "Erro: config/dotfile-names.list não encontrado: $names_file" >&2
        return 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// }" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        line="${line%%#*}"
        file="${line#"${line%%[![:space:]]*}"}"
        file="${file%"${file##*[![:space:]]}"}"
        [[ -z "$file" ]] && continue
        printf '%s\n' "$file"
    done <"$names_file"
}

# Remove a primeira linha cujo nome (após o mesmo parsing da lista) é $1.
dotfiles_dotfile_names_remove_entry() {
    local names_file entry line file tmp removed=0
    names_file="$(dotfiles_dotfile_names_path)"
    entry="$1"
    if [[ ! -f "$names_file" ]]; then
        echo "Erro: config/dotfile-names.list não encontrado: $names_file" >&2
        return 1
    fi
    tmp="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        file=""
        if [[ -n "${line// }" ]] && [[ ! "$line" =~ ^[[:space:]]*# ]]; then
            local l="${line%%#*}"
            file="${l#"${l%%[![:space:]]*}"}"
            file="${file%"${file##*[![:space:]]}"}"
        fi
        if [[ -n "$file" && "$file" == "$entry" && "$removed" -eq 0 ]]; then
            removed=1
            continue
        fi
        printf '%s\n' "$line" >> "$tmp"
    done <"$names_file"
    if [[ "$removed" -eq 0 ]]; then
        rm -f "$tmp"
        echo "Erro: nome não encontrado em config/dotfile-names.list: $entry" >&2
        return 1
    fi
    mv -- "$tmp" "$names_file"
}

# Acrescenta um nome ao fim de config/dotfile-names.list (sem duplicar).
dotfiles_dotfile_names_add_entry() {
    local names_file entry e last
    names_file="$(dotfiles_dotfile_names_path)"
    entry="$1"
    if [[ ! -f "$names_file" ]]; then
        echo "Erro: config/dotfile-names.list não encontrado: $names_file" >&2
        return 1
    fi
    if [[ -z "${entry// }" ]]; then
        echo "Erro: o nome não pode ser vazio." >&2
        return 1
    fi
    if [[ "$entry" =~ ^[[:space:]]*# ]]; then
        echo "Erro: o nome não pode começar com # (seria comentário)." >&2
        return 1
    fi
    if [[ "$entry" == *$'\n'* ]]; then
        echo "Erro: o nome não pode conter quebras de linha." >&2
        return 1
    fi
    while IFS= read -r e; do
        if [[ "$e" == "$entry" ]]; then
            echo "Erro: o nome já existe em config/dotfile-names.list: $entry" >&2
            return 1
        fi
    done < <(dotfiles_dotfile_names_entries)

    if [[ -s "$names_file" ]]; then
        last=$(tail -c1 "$names_file" 2>/dev/null || true)
        if [[ -n "$last" && "$last" != $'\n' ]]; then
            echo "" >>"$names_file"
        fi
    fi
    printf '%s\n' "$entry" >>"$names_file"
}

# Estados: importable | unavailable | not_installed | installed | wrong_target | blocking_file
# importable = sem cópia em data/, mas existe ficheiro/pasta real em ~ (pode mover para o repo).
dotfiles_status_for_file() {
    local file=$1
    local src dest canonical_src
    local data_dir
    data_dir="$(dotfiles_data_dir)"
    src="${data_dir}/${file}"
    dest="$(dotfiles_dest_for_file "$file")"

    if [[ ! -e "$src" ]]; then
        if [[ -e "$dest" ]] && [[ ! -L "$dest" ]]; then
            echo "importable"
        else
            echo "unavailable"
        fi
        return
    fi
    canonical_src="$(realpath "$src")"

    if [[ ! -e "$dest" ]] && [[ ! -L "$dest" ]]; then
        echo "not_installed"
        return
    fi
    if [[ -L "$dest" ]]; then
        local target
        target="$(realpath "$dest" 2>/dev/null || true)"
        if [[ -n "$target" && "$target" == "$canonical_src" ]]; then
            echo "installed"
        else
            echo "wrong_target"
        fi
        return
    fi
    echo "blocking_file"
}

# Cria um único symlink; falha se a fonte não existir em data/.
dotfiles_link_one() {
    local file=$1
    local src dest
    local data_dir
    data_dir="$(dotfiles_data_dir)"
    src="${data_dir}/${file}"
    dest="$(dotfiles_dest_for_file "$file")"

    if [[ ! -e "$src" ]]; then
        echo "Erro: arquivo não existe em data/: $file" >&2
        return 1
    fi
    echo "Criando link simbólico para $file → $dest"
    ln -sf "$src" "$dest"
}

# Cria symlinks em $HOME para cada nome em config/dotfile-names.list (relativos a data/).
dotfiles_link_from_dotfile_names() {
    local file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ ! -e "$(dotfiles_data_dir)/${file}" ]]; then
            echo "Aviso: arquivo não existe em data/, pulando: $file" >&2
            continue
        fi
        dotfiles_link_one "$file"
    done < <(dotfiles_dotfile_names_entries)
}
