#!/usr/bin/env bash
# === install-opencode-profiles.sh ===
# Cria/atualiza os symlinks dos perfis do OpenCode em
#   ~/.config/opencode-multi/profiles/<perfil>/
# apontando para a fonte única no repositório (config/opencode-profiles.list).
#
# Configuração: config/opencode-profiles.list
#   formato: <perfil>|<dest relativo ao perfil>|<fonte relativa no repo>
#   (uma linha por arquivo)
#
# SECURITY NOTE (guardrails para humanos e agentes de IA):
#   - Idempotente: link correto → nada a fazer; reexecutar não duplica nada.
#   - Arquivo real byte-a-byte idêntico à fonte → backup em .bkp/ e vira
#     symlink (conversão); nada é apagado sem backup.
#   - Arquivo real DIFERENTE da fonte → alerta e PULA (nunca destrói trabalho).
#   - NUNCA toca em cli.json, service.json, node_modules, package*.json —
#     permanecem locais (e sensíveis) em cada perfil.
#   - Links ABSOLUTOS → funcionam em qualquer máquina após o clone do repo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dotfiles-lib.sh
source "${SCRIPT_DIR}/dotfiles-lib.sh"

CONFIG_FILE="$(dotfiles_repo_root)/config/opencode-profiles.list"
PROFILE_ROOT="$HOME/.config/opencode-multi/profiles"

PF_N_OK=0
PF_N_CREATED=0
PF_N_CONVERT=0
PF_N_RELINK=0
PF_N_SKIP=0

# Backup de um destino real (não-symlink) em <repo>/.bkp com slug datado.
pf_backup_dest() {
    local dest=$1 bkp_dir slug n base
    if [[ ! -e "$dest" ]]; then
        echo "Erro: não existe ${dest}" >&2
        return 1
    fi
    if [[ -L "$dest" ]]; then
        echo "Erro: ${dest} já é link (não precisa de backup)." >&2
        return 1
    fi
    bkp_dir="$(dotfiles_backup_dir)"
    base="$(basename "$dest")"
    mkdir -p "$bkp_dir"
    slug="$(date +%d-%m-%Y_%H:%M)_${base}"
    n=0
    while [[ -e "$bkp_dir/$slug" ]]; do
        n=$((n + 1))
        slug="$(date +%d-%m-%Y_%H:%M)_${base}_${n}"
    done
    echo "  Backup: ${dest} → ${bkp_dir}/${slug}"
    mv -- "$dest" "$bkp_dir/$slug"
}

# Garante que <dest> seja um symlink para <src> (mesmo critério do bridge de skills).
pf_ensure_link() {
    local dest=$1 src=$2
    local canonical_src canonical_dest
    mkdir -p "$(dirname "$dest")"
    canonical_src="$(realpath "$src")"
    canonical_dest="$(realpath "$dest" 2>/dev/null || true)"

    if [[ -n "$canonical_dest" && "$canonical_dest" == "$canonical_src" ]]; then
        PF_N_OK=$((PF_N_OK + 1))
        return 0
    fi
    if [[ -L "$dest" ]]; then
        echo "  Relink: ${dest} (apontava para outro lugar)"
        ln -sfn "$src" "$dest"
        PF_N_RELINK=$((PF_N_RELINK + 1))
        return 0
    fi
    if [[ -e "$dest" ]]; then
        if diff -q "$src" "$dest" >/dev/null 2>&1; then
            pf_backup_dest "$dest" || return 1
            ln -s "$src" "$dest"
            PF_N_CONVERT=$((PF_N_CONVERT + 1))
            return 0
        fi
        echo "  SKIP: ${dest} difere de ${src} — não foi tocado (confira manualmente)" >&2
        PF_N_SKIP=$((PF_N_SKIP + 1))
        return 1
    fi
    ln -s "$src" "$dest"
    PF_N_CREATED=$((PF_N_CREATED + 1))
    return 0
}

pf_main() {
    local line profile rel_dest src_rel src dest
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Erro: configuração não encontrada: ${CONFIG_FILE}" >&2
        exit 1
    fi

    echo "Perfis OpenCode → fonte única (${CONFIG_FILE})"
    echo "Root dos perfis: ${PROFILE_ROOT}"
    echo ""

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// }" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Formato: <perfil>|<dest relativo ao perfil>|<fonte relativa no repo>
        profile="${line%%|*}"
        rest="${line#*|}"
        rel_dest="${rest%%|*}"
        src_rel="${rest#*|}"

        if [[ -z "$profile" || -z "$rel_dest" || -z "$src_rel" || "$rel_dest" == "$rest" ]]; then
            echo "  AVISO: linha inválida ignorada: ${line}" >&2
            continue
        fi
        if [[ ! "$profile" =~ ^[A-Za-z0-9_-]+$ ]]; then
            echo "  AVISO: nome de perfil inválido: ${profile}" >&2
            continue
        fi
        src="$(dotfiles_repo_root)/${src_rel}"
        if [[ ! -e "$src" ]]; then
            echo "  AVISO: fonte não existe no repo: ${src_rel}" >&2
            continue
        fi
        dest="$PROFILE_ROOT/$profile/$rel_dest"
        echo "→ ${profile}/${rel_dest} ← ${src_rel}"
        pf_ensure_link "$dest" "$src" || true
    done <"$CONFIG_FILE"

    echo ""
    echo "── Perfis OpenCode ──────────────────────────────"
    echo "  criados: ${PF_N_CREATED}   já ok: ${PF_N_OK}   convertidos: ${PF_N_CONVERT}"
    echo "  relink:  ${PF_N_RELINK}   pulados (divergem): ${PF_N_SKIP}"
    echo "─────────────────────────────────────────────────"
}

pf_main "$@"