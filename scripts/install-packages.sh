#!/usr/bin/env bash
set -euo pipefail

# SECURITY NOTE: Este script instala pacotes no sistema com privilégios elevados (sudo).
#   - A lista vem de config/install-packages.list — revise antes de rodar.
#   - Entradas "script:" executam código de terceiros (URL) — cada uma pede confirmação.
#   - Entradas "deb:" baixam e instalam .deb de URLs — verifique a procedência da fonte.
#   - Entradas "manual:" nunca executam nada; apenas imprimem instruções.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/dotfiles-lib.sh"

PACKAGES_FILE="$(dotfiles_repo_root)/config/install-packages.list"

MANAGERS=(apt deb flatpak snap brew npm pipx script manual)

MODE="dry-run"
FILTER=""

dotfiles_pkg_list_path() {
    echo "$(dotfiles_repo_root)/config/install-packages.list"
}

dotfiles_pkg_valid_manager() {
    local target=$1 m
    for m in "${MANAGERS[@]}"; do
        [[ "$m" == "$target" ]] && return 0
    done
    return 1
}

# Lista as entradas de config/install-packages.list como "gerenciador<TAB>valor".
# Ignora linhas vazias, comentários (#) e aparações.
dotfiles_pkg_entries() {
    local line manager value pkg_file
    pkg_file="$(dotfiles_pkg_list_path)"
    if [[ ! -f "$pkg_file" ]]; then
        echo "Erro: ${pkg_file} não encontrado." >&2
        return 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// }" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        [[ "$line" != *:* ]] && continue
        manager="${line%%:*}"
        value="${line#*:}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        [[ -z "$value" ]] && continue
        printf '%s\t%s\n' "$manager" "$value"
    done <"$pkg_file"
}

# Acrescenta "gerenciador:valor" ao fim de config/install-packages.list (sem duplicar).
dotfiles_pkg_add_entry() {
    local manager=$1 value=$2 pkg_file m v last
    pkg_file="$(dotfiles_pkg_list_path)"
    if [[ ! -f "$pkg_file" ]]; then
        echo "Erro: ${pkg_file} não encontrado." >&2
        return 1
    fi
    if ! dotfiles_pkg_valid_manager "$manager"; then
        echo "Erro: gerenciador inválido '${manager}'. Use um de: ${MANAGERS[*]}" >&2
        return 1
    fi
    if [[ -z "${value// }" ]]; then
        echo "Erro: o valor do pacote não pode ser vazio." >&2
        return 1
    fi
    if [[ "$value" == *$'\n'* ]]; then
        echo "Erro: o valor não pode conter quebras de linha." >&2
        return 1
    fi
    while IFS=$'\t' read -r m v; do
        if [[ "$m" == "$manager" && "$v" == "$value" ]]; then
            echo "Erro: entrada já existe em config/install-packages.list: ${manager}:${value}" >&2
            return 1
        fi
    done < <(dotfiles_pkg_entries)

    if [[ -s "$pkg_file" ]]; then
        last=$(tail -c1 "$pkg_file" 2>/dev/null || true)
        if [[ -n "$last" && "$last" != $'\n' ]]; then
            echo "" >>"$pkg_file"
        fi
    fi
    printf '%s:%s\n' "$manager" "$value" >>"$pkg_file"
}

# Remove a primeira linha cujo gerenciador é $1 e valor é $2 de config/install-packages.list.
dotfiles_pkg_remove_entry() {
    local target_mgr=$1 target_val=$2 pkg_file line parsed m v tmp removed=0
    pkg_file="$(dotfiles_pkg_list_path)"
    if [[ ! -f "$pkg_file" ]]; then
        echo "Erro: ${pkg_file} não encontrado." >&2
        return 1
    fi
    tmp="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        m=""
        v=""
        if [[ -n "${line// }" ]] && [[ ! "$line" =~ ^[[:space:]]*# ]]; then
            parsed="${line%%#*}"
            parsed="${parsed#"${parsed%%[![:space:]]*}"}"
            parsed="${parsed%"${parsed##*[![:space:]]}"}"
            if [[ "$parsed" == *:* ]]; then
                m="${parsed%%:*}"
                v="${parsed#*:}"
                v="${v#"${v%%[![:space:]]*}"}"
                v="${v%"${v##*[![:space:]]}"}"
            fi
        fi
        if [[ -n "$m" && "$m" == "$target_mgr" && "$v" == "$target_val" && "$removed" -eq 0 ]]; then
            removed=1
            continue
        fi
        printf '%s\n' "$line" >>"$tmp"
    done <"$pkg_file"
    if [[ "$removed" -eq 0 ]]; then
        rm -f "$tmp"
        echo "Erro: entrada não encontrada em config/install-packages.list: ${target_mgr}:${target_val}" >&2
        return 1
    fi
    mv -- "$tmp" "$pkg_file"
}

# Entradas de um gerenciador (valores apenas).
dotfiles_pkg_entries_for() {
    local manager=$1 line m v
    while IFS=$'\t' read -r m v; do
        [[ "$m" == "$manager" ]] && printf '%s\n' "$v"
    done < <(dotfiles_pkg_entries)
}

# 0 se o gerenciador (binário base) existe no sistema.
dotfiles_pkg_manager_available() {
    local manager=$1
    case "$manager" in
        apt | deb | manual | script) return 0 ;;
        flatpak) command -v flatpak >/dev/null 2>&1 ;;
        snap) command -v snap >/dev/null 2>&1 ;;
        brew) command -v brew >/dev/null 2>&1 ;;
        npm) command -v npm >/dev/null 2>&1 ;;
        pipx) command -v pipx >/dev/null 2>&1 ;;
    esac
}

# Dica do que instalar quando o gerenciador está ausente.
dotfiles_pkg_manager_hint() {
    case "$1" in
        flatpak) echo "apt:flatpak (já está na lista)" ;;
        snap) echo "apt:snapd (já está na lista)" ;;
        brew) echo "instale o Homebrew antes (ver entradas manual: no .list)" ;;
        npm) echo "instale o Node.js antes (script nvm na lista)" ;;
        pipx) echo "apt:pipx (já está na lista)" ;;
        *) echo "instale o gerenciador primeiro" ;;
    esac
}

# 0 se o pacote $2 já está instalado via gerenciador $1.
dotfiles_pkg_is_installed() {
    local manager=$1 value=$2
    case "$manager" in
        apt) dpkg-query -W -f='${Status}' "$value" 2>/dev/null | grep -q "install ok installed" ;;
        deb) dpkg-query -W -f='${Status}' "${value%%|*}" 2>/dev/null | grep -q "install ok installed" ;;
        flatpak) command -v flatpak >/dev/null 2>&1 && flatpak info "$value" >/dev/null 2>&1 ;;
        snap) command -v snap >/dev/null 2>&1 && snap list "$value" >/dev/null 2>&1 ;;
        brew) command -v brew >/dev/null 2>&1 && brew list "$value" >/dev/null 2>&1 ;;
        npm) command -v npm >/dev/null 2>&1 && npm ls -g --depth=0 "$value" >/dev/null 2>&1 ;;
        pipx) command -v pipx >/dev/null 2>&1 && pipx list --short 2>/dev/null | grep -qx "$value" ;;
        script) return 1 ;;
        manual) return 1 ;;
    esac
}

dotfiles_pkg_confirm() {
    local r
    read -r -p "$1 (s/n): " r || true
    [[ "$r" =~ ^[sS]$ ]]
}

dotfiles_pkg_install_apt() {
    echo ">> sudo DEBIAN_FRONTEND=noninteractive apt update"
    sudo DEBIAN_FRONTEND=noninteractive apt update
    echo ">> sudo DEBIAN_FRONTEND=noninteractive apt install -y $*"
    sudo DEBIAN_FRONTEND=noninteractive apt install -y "$@"
}

dotfiles_pkg_install_deb() {
    local entry bin url tmp
    for entry in "$@"; do
        bin="${entry%%|*}"
        url="${entry#*|}"
        echo ">> Baixando ${url}"
        tmp="$(mktemp --suffix="-${bin}.deb")"
        curl -fL --retry 3 "$url" -o "$tmp"
        echo ">> sudo DEBIAN_FRONTEND=noninteractive apt install -y ${tmp}  (binário: ${bin})"
        sudo DEBIAN_FRONTEND=noninteractive apt install -y "$tmp"
        rm -f "$tmp"
    done
}

dotfiles_pkg_install_flatpak() {
    if ! flatpak remotes 2>/dev/null | grep -q flathub; then
        echo ">> sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    echo ">> flatpak install -y flathub $*"
    flatpak install -y flathub "$@"
}

dotfiles_pkg_install_snap() {
    echo ">> sudo snap install $*"
    sudo snap install "$@"
}

dotfiles_pkg_install_brew() {
    echo ">> brew install $*"
    brew install "$@"
}

dotfiles_pkg_install_npm() {
    echo ">> npm install -g $*"
    npm install -g "$@"
}

dotfiles_pkg_install_pipx() {
    echo ">> pipx install $*"
    pipx install "$@"
}

# Instaladores oficiais: executa código de terceiros — confirmação por URL.
dotfiles_pkg_install_script() {
    local url
    for url in "$@"; do
        echo ""
        echo "AVISO: executar este instalador roda código de terceiros não auditado:"
        echo "  ${url}"
        if ! dotfiles_pkg_confirm "Baixar e executar agora?"; then
            echo "  Pulado."
            continue
        fi
        echo ">> bash <(curl -fsSL ${url})"
        bash <(curl -fsSL "$url")
    done
}

dotfiles_pkg_install_one() {
    local manager=$1
    shift
    local entries=("$@")
    case "$manager" in
        apt) dotfiles_pkg_install_apt "${entries[@]}" ;;
        deb) dotfiles_pkg_install_deb "${entries[@]}" ;;
        flatpak) dotfiles_pkg_install_flatpak "${entries[@]}" ;;
        snap) dotfiles_pkg_install_snap "${entries[@]}" ;;
        brew) dotfiles_pkg_install_brew "${entries[@]}" ;;
        npm) dotfiles_pkg_install_npm "${entries[@]}" ;;
        pipx) dotfiles_pkg_install_pipx "${entries[@]}" ;;
        script) dotfiles_pkg_install_script "${entries[@]}" ;;
    esac
}

dotfiles_pkg_cmd_list() {
    local manager value
    echo "== Entradas cruas de ${PACKAGES_FILE} =="
    while IFS=$'\t' read -r manager value; do
        printf '%s:%s\n' "$manager" "$value"
    done < <(dotfiles_pkg_entries)
}

dotfiles_pkg_cmd_dry_run() {
    local manager count total=0
    local -a entries=()
    echo "== Plano de instalação =="
    echo "Arquivo: ${PACKAGES_FILE}"
    echo ""
    for manager in "${MANAGERS[@]}"; do
        [[ -n "$FILTER" && "$manager" != "$FILTER" ]] && continue
        mapfile -t entries < <(dotfiles_pkg_entries_for "$manager")
        ((${#entries[@]} == 0)) && continue
        echo "── ${manager} ──────────────────────────────"
        count=0
        for value in "${entries[@]}"; do
            if [[ "$manager" == "manual" ]]; then
                printf '  %s\n' "📝 ${value}"
            elif dotfiles_pkg_is_installed "$manager" "$value"; then
                printf '  %s\n' "✅ [instalado]      ${value}"
            elif dotfiles_pkg_manager_available "$manager"; then
                printf '  %s\n' "⬜ [faltando]       ${value}"
                count=$((count + 1))
            else
                printf '  %s\n' "🚫 [sem gerenciador] ${value}  →  $(dotfiles_pkg_manager_hint "$manager")"
            fi
        done
        echo ""
        if [[ "$manager" == "manual" ]]; then
            echo "  → ${#entries[@]} instrução(ões) a ler"
        elif [[ "$manager" == "script" ]]; then
            echo "  → ${count} instalador(es) externo(s) a avaliar"
        else
            echo "  → ${count} pendente(s)"
        fi
        total=$((total + count))
        echo ""
    done
    echo "=============================================="
    echo "Total a instalar: ${total} (mais manual/script a avaliar)"
}

dotfiles_pkg_cmd_install() {
    local manager count
    local -a entries=()
    local -a missing=()
    for manager in "${MANAGERS[@]}"; do
        [[ -n "$FILTER" && "$manager" != "$FILTER" ]] && continue
        mapfile -t entries < <(dotfiles_pkg_entries_for "$manager")
        ((${#entries[@]} == 0)) && continue
        if [[ "$manager" == "manual" ]]; then
            echo "── ${manager} (apenas instruções) ──────────"
            for value in "${entries[@]}"; do
                echo "  * ${value}"
            done
            echo ""
            continue
        fi
        missing=()
        for value in "${entries[@]}"; do
            if dotfiles_pkg_is_installed "$manager" "$value"; then
                echo "✅ já instalado: ${value}"
            elif ! dotfiles_pkg_manager_available "$manager"; then
                echo "🚫 gerenciador ausente (${manager}) — ${value}  →  $(dotfiles_pkg_manager_hint "$manager")"
            else
                missing+=("$value")
            fi
        done
        ((${#missing[@]} == 0)) && continue
        echo ""
        echo "── ${manager} ──────────────────────────────"
        printf '  Falta instalar (%d):\n' "${#missing[@]}"
        for value in "${missing[@]}"; do
            printf '    - %s\n' "$value"
        done
        echo ""
        if ! dotfiles_pkg_confirm "Instalar ${#missing[@]} via ${manager}?"; then
            echo "  Pulado."
            echo ""
            continue
        fi
        echo ""
        dotfiles_pkg_install_one "$manager" "${missing[@]}"
        echo ""
    done
    echo "Concluído."
}

dotfiles_pkg_usage() {
    cat <<'EOF'
Uso: scripts/install-packages.sh [--dry-run|--install|--list] [gerenciador]

  --dry-run    (padrão) Mostra o plano: o que já está instalado e o que falta.
  --install    Instala os programas da lista curada (config/install-packages.list).
  --list       Mostra as entradas cruas da lista.
  gerenciador  Filtra por gerenciador: apt, deb, flatpak, snap, brew, npm, pipx, script, manual.

Exemplos:
  scripts/install-packages.sh                 # plano (dry-run)
  scripts/install-packages.sh --install      # instala tudo (com confirmações)
  scripts/install-packages.sh --install apt  # só apt
EOF
}

dotfiles_pkg_cli_main() {
    local arg m ok=0
    while (($#)); do
        arg="$1"
        shift
        case "$arg" in
            --install) MODE="install" ;;
            --dry-run) MODE="dry-run" ;;
            --list) MODE="list" ;;
            --help | -h) dotfiles_pkg_usage && return 0 ;;
            --*) FILTER="${arg#--}" ;;
            *) FILTER="$arg" ;;
        esac
    done
    if [[ -n "$FILTER" ]]; then
        for m in "${MANAGERS[@]}"; do
            [[ "$m" == "$FILTER" ]] && ok=1
        done
        if ((ok != 1)); then
            echo "Erro: gerenciador desconhecido: ${FILTER}" >&2
            dotfiles_pkg_usage >&2
            return 1
        fi
    fi
    case "$MODE" in
        list) dotfiles_pkg_cmd_list ;;
        dry-run) dotfiles_pkg_cmd_dry_run ;;
        install) dotfiles_pkg_cmd_install ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    dotfiles_pkg_cli_main "$@"
fi
