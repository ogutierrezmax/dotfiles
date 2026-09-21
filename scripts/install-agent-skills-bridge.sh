#!/usr/bin/env bash
# === install-agent-skills-bridge.sh ===
# Cria symlinks por-skill nos diretórios de skills de cada ferramenta de IA,
# apontando para o acervo central versíonado: ~/.agents/skills
# (que é o próprio dotfiles/data/.agents/skills via symlink ~/.agents).
#
# Configuração: config/agent-skills-bridge.list
#   formato: <ferramenta>|<skill>   ("*" = todas as leaf skills de topo)
#
# SECURITY NOTE (guardrails para humanos e agentes de IA):
#  - Idempotente: reexecutar não duplica nem quebra nada.
#  - Só REMOVE um destino nas seguintes condições:
#      * é SYMLINK gerenciado (aponta para ~/.agents/skills) cujo alvo deixou de existir
#        (link órfão / quebrado) — removido para não confundir a ferramenta;
#      * é diretório REAL byte-a-byte idêntico ao acervo — movido para .bkp antes
#        do symlink (nada é apagado sem backup).
#  - Diretório REAL diferente do acervo → alerta e PULA (nunca destrói trabalho).
#  - Nunca usa rm -rf; nunca toca em skills fora da configuração (ex.: pinokio).
#  - Links são ABSOLUTOS via $HOME/.agents/... → funcionam em qualquer máquina.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dotfiles-lib.sh
source "${SCRIPT_DIR}/dotfiles-lib.sh"

# Mapa ferramenta → diretório(s) de skills em $HOME (separados por ":").
# Ferramentas que leem ~/.agents/skills nativamente (VS Code, Copilot CLI,
# OpenCode, Codex, Cursor, Gemini CLI) não precisam de bridge — ficam de fora por padrão.
declare -A TOOL_DIRS=(
    [claude]="$HOME/.claude/skills"
    [devin]="$HOME/.config/devin/skills"
    [antigravity]="$HOME/.agent/skills:$HOME/.gemini/antigravity/skills:$HOME/.gemini/config/skills"
    [cursor]="$HOME/.cursor/skills"
    [gemini]="$HOME/.gemini/skills"
)

CONFIG_FILE="$(dotfiles_repo_root)/config/agent-skills-bridge.list"
CENTER="$HOME/.agents/skills"

# Contadores do relatório final
BRIDGE_N_OK=0
BRIDGE_N_RELINK=0
BRIDGE_N_CONVERT=0
BRIDGE_N_SKIP_DIFF=0
BRIDGE_N_ORPHAN=0
BRIDGE_N_CREATED=0

# Todas as "leaf skills" de topo: dirs em $CENTER com SKILL.md direto.
bridge_leaves() {
    local d
    for d in "$CENTER"/*/; do
        [[ -d "$d" && -f "$d/SKILL.md" ]] && basename "$d"
    done
}

# Resolve uma especificação de skill do config para o caminho real no acervo.
# Retorna 0 e imprime o caminho se existir; 1 se não existir.
bridge_resolve_src() {
    local spec=$1
    local src="$CENTER/$spec"
    if [[ -d "$src" && -f "$src/SKILL.md" ]]; then
        echo "$src"
        return 0
    fi
    return 1
}

# Backup de um destino real (não-symlink) em <repo>/.bkp com slug datado.
# Retorna 0 em sucesso; 1 se o destino não existe ou já é symlink.
bridge_backup_dest() {
    local dest=$1
    local bkp_dir slug n base
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

# Garante que <dest> seja um symlink válido para <src>.
# - dest já RESOLVE para src (symlink correto OU o próprio acervo via aliás)
#   → ok (nada feito; protege contra dirs que são o próprio acervo central)
# - symlink errado/quebrado → refaz
# - diretório real idêntico → backup + symlink (conversão)
# - diretório real diferente → alerta + skip (retorna 1)
bridge_ensure_link() {
    local dest=$1 src=$2
    local canonical_src canonical_dest
    canonical_src="$(realpath "$src")"
    canonical_dest="$(realpath "$dest" 2>/dev/null || true)"

    # Já está correto (aponta para a fonte ou É a fonte — ex.: dir de tools
    # que é aliás do acervo central). NUNCA fazer backup/remover aqui.
    if [[ -n "$canonical_dest" && "$canonical_dest" == "$canonical_src" ]]; then
        BRIDGE_N_OK=$((BRIDGE_N_OK + 1))
        return 0
    fi

    if [[ -L "$dest" ]]; then
        echo "  Relink: ${dest} (apontava para outro lugar)"
        ln -sfn "$src" "$dest"
        BRIDGE_N_RELINK=$((BRIDGE_N_RELINK + 1))
        return 0
    fi

    if [[ -e "$dest" ]]; then
        if diff -rq "$src" "$dest" >/dev/null 2>&1; then
            bridge_backup_dest "$dest" || return 1
            ln -s "$src" "$dest"
            BRIDGE_N_CONVERT=$((BRIDGE_N_CONVERT + 1))
            return 0
        fi
        echo "  SKIP: ${dest} difere do acervo — não foi tocado (confira manualmente)" >&2
        BRIDGE_N_SKIP_DIFF=$((BRIDGE_N_SKIP_DIFF + 1))
        return 1
    fi

    ln -s "$src" "$dest"
    BRIDGE_N_CREATED=$((BRIDGE_N_CREATED + 1))
    return 0
}

# Remove symlinks órfãos dentro de <dir>: apontam para ~/.agents/skills mas o
# alvo não existe mais (skill removida do acervo).
bridge_cleanup_orphans() {
    local dir=$1 entry target
    [[ -d "$dir" ]] || return 0
    for entry in "$dir"/*; do
        [[ -L "$entry" ]] || continue
        target="$(readlink "$entry")"
        # Só gerencia links que apontam (literalmente) para o acervo central.
        case "$target" in
            "$CENTER"/* | "$HOME/.agents/skills"/*)
                if [[ ! -e "$entry" ]]; then
                    echo "  Removido órfão: ${entry} (alvo ${target} não existe mais)"
                    rm -- "$entry"
                    BRIDGE_N_ORPHAN=$((BRIDGE_N_ORPHAN + 1))
                fi
                ;;
        esac
    done
}

# Bridge de uma ferramenta inteira (todos os dirs mapeados).
bridge_tool() {
    local tool=$1 spec=$2 dirs dir skill src
    local center_real dir_real
    center_real="$(realpath "$CENTER")"
    IFS=':' read -r -a dirs <<<"${TOOL_DIRS[$tool]}"
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        # Salvaguarda: se o dir da ferramenta JÁ É o acervo central (aliás/symlink),
        # não há o que bridar — mexer aqui seria operar sobre a fonte da verdade.
        dir_real="$(realpath "$dir" 2>/dev/null || true)"
        if [[ -n "$dir_real" && "$dir_real" == "$center_real" ]]; then
            echo "→ ${tool} [$(basename "$dir")] já é o acervo central — pulando (sem bridge necessária)"
            continue
        fi
        # Gera a lista de skills: '*' expande para as leaf skills; senão usa a spec.
        if [[ "$spec" == "*" ]]; then
            while IFS= read -r skill; do
                [[ -z "$skill" ]] && continue
                # Leaf de topo (garantido por bridge_leaves): dir com SKILL.md direto
                echo "→ ${tool} [$(basename "$dir")] ${skill}"
                bridge_ensure_link "$dir/$skill" "$CENTER/$skill" || true
            done < <(bridge_leaves)
        else
            # Spec explícita: resolve dentro do acervo (pode ser bundle/sub-skill).
            if src="$(bridge_resolve_src "$spec")"; then
                skill="$(basename "$src")"
                echo "→ ${tool} [$(basename "$dir")] ${spec} (src=${src})"
                bridge_ensure_link "$dir/$skill" "$src" || true
            else
                echo "  AVISO: skill não encontrada no acervo: ${spec}" >&2
            fi
        fi
        bridge_cleanup_orphans "$dir"
    done
}

bridge_report() {
    cat <<EOF

── Bridge de skills concluído ─────────────────────────────
  criados:            ${BRIDGE_N_CREATED}
  já ok:              ${BRIDGE_N_OK}
  relinkados:         ${BRIDGE_N_RELINK}
  convertidos (backup): ${BRIDGE_N_CONVERT}
  órfãos removidos:   ${BRIDGE_N_ORPHAN}
  pulados (divergem): ${BRIDGE_N_SKIP_DIFF}
───────────────────────────────────────────────────────────
EOF
}

bridge_main() {
    local line tool spec
    if [[ ! -d "$CENTER" ]]; then
        echo "Erro: acervo central não encontrado: ${CENTER}" >&2
        echo "      Execute scripts/install-dotfiles.sh antes (cria o symlink ~/.agents)." >&2
        exit 1
    fi
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Erro: configuração não encontrada: ${CONFIG_FILE}" >&2
        exit 1
    fi

    echo "Bridge de skills → acervo central ${CENTER}"
    echo "Config: ${CONFIG_FILE}"
    echo ""

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// }" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        tool="${line%%|*}"
        spec="${line#*|}"
        if [[ -z "$spec" || "$tool" == "$line" ]]; then
            echo "  AVISO: linha inválida ignorada: ${line}" >&2
            continue
        fi
        if [[ -z "${TOOL_DIRS[$tool]:-}" ]]; then
            echo "  AVISO: ferramenta desconhecida: ${tool}" >&2
            continue
        fi
        bridge_tool "$tool" "$spec"
        echo ""
    done <"$CONFIG_FILE"

    bridge_report
}

bridge_main "$@"