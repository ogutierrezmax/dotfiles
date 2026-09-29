#!/usr/bin/env bash
# === install-agent-skills-bridge.sh ===
# Converge os diretórios de skills de cada ferramenta de IA para o acervo central
# versionado ~/.agents/skills (que é o próprio dotfiles/data/.agents/skills via
# symlink ~/.agents, criado por install-dotfiles.sh).
#
# Configuração: config/agent-skills-bridge.list
#   formato: <ferramenta>|<spec>  onde spec é:
#     "*"           → todas as "leaf skills" de topo (dir com SKILL.md direto)
#     "**"          → TODAS as skills em qualquer profundidade, achatadas por
#                     basename (o dir da skill vira o nome da skill)
#     "@manifest"   → gera/atualiza o manifest <TOOL_MANIFEST[tool]> (Antigravity)
#     "<nome>"      → skill leaf, ex.: context7-mcp
#     "<bundle>/<nome>" → sub-skill dentro de um bundle
#
# Modos de execução:
#   (padrão)    aplica as mudanças (bootstrap e re-convergência)
#   --dry-run   imprime o que faria, sem escrever nada em $HOME
#   --doctor    diagnóstico read-only: o que cada tool enxerga + drift
#               (exit 1 se houver drift — X/X visíveis, sem órfão, manifest em dia)
#
# SECURITY NOTE (guardrails para humanos e agentes de IA):
#  - Declarativo + idempotente: o estado desejado vem do acervo + deste config;
#    rodar N vezes leva ao mesmo estado (nada duplica, nada quebra).
#  - Só REMOVE/REESCREVE um destino nas seguintes condições:
#      * symlink GERENCIADO (aponta para ~/.agents/skills) cujo alvo deixou de
#        existir (órfão) — removido para não confundir a ferramenta;
#      * diretório REAL byte-a-byte idêntico ao acervo — movido para .bkp antes
#        do symlink (nada é apagado sem backup);
#      * symlink que É o próprio acervo (alias) — normalizado em links por-skill
#        (remove-se só o link; a fonte, nunca).
#  - Diretório REAL diferente do acervo → alerta e PULA (nunca destrói trabalho).
#  - Manifest (skills.json) só é sobrescrito com backup datado em .bkp/.
#  - Nunca usa rm -rf; nunca toca em skills fora do escopo configurado (ex.:
#    pinokio no Claude, skills da Google Cloud em ~/.gemini/config/skills).
#  - Links são ABSOLUTOS via $HOME/.agents/... → funcionam em qualquer máquina.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dotfiles-lib.sh
source "${SCRIPT_DIR}/dotfiles-lib.sh"

# Mapa ferramenta → diretório(s) de skills em $HOME (separados por ":").
# Ferramentas que leem ~/.agents/skills nativamente (VS Code/Copilot, Copilot CLI,
# OpenCode, Codex, Cursor, Gemini CLI) entram aqui como espelho explícito: elas
# escaneiam UM NÍVEL, então precisam de um acervo "flat" com todas as skills.
declare -A TOOL_DIRS=(
    [claude]="$HOME/.claude/skills"
    [devin]="$HOME/.config/devin/skills"
    [antigravity]="$HOME/.agent/skills:$HOME/.gemini/antigravity/skills:$HOME/.gemini/config/skills"
    [copilot]="$HOME/.copilot/skills"
    [cursor]="$HOME/.cursor/skills"
    [gemini]="$HOME/.gemini/skills"
)

# Ferramentas com suporte a manifest de customização (JSON) na raiz global.
# Cada "entry" do manifest é escaneada UM NÍVEL pelo agente.
declare -A TOOL_MANIFEST=(
    [antigravity]="$HOME/.gemini/config/skills.json"
)

SPEC_LEAVES="*"
SPEC_ALL="**"
SPEC_MANIFEST="@manifest"

CONFIG_FILE="$(dotfiles_repo_root)/config/agent-skills-bridge.list"
CENTER="$HOME/.agents/skills"

# Profundidade máxima (a partir de $CENTER) em que um SKILL.md conta como skill:
# CENTER/<leaf>/SKILL.md = 1 e CENTER/<bundle>/<skill>/SKILL.md = 2.
BRIDGE_MAX_DEPTH=3

# apply | dry-run | doctor
MODE=apply

# Contadores do relatório final
BRIDGE_N_OK=0
BRIDGE_N_RELINK=0
BRIDGE_N_CONVERT=0
BRIDGE_N_SKIP_DIFF=0
BRIDGE_N_ORPHAN=0
BRIDGE_N_CREATED=0
BRIDGE_N_ALIAS=0
BRIDGE_N_MANIFEST=0
BRIDGE_N_COLLISION=0
BRIDGE_N_NAMEWARN=0
BRIDGE_N_ERROR=0
BRIDGE_DRIFT=0

# Linhas do resumo por tool/root: tool|root|esperado|visiveis|status
BRIDGE_ROWS=()
# Avisos não fatais (higiene de nome, colisão de basename, manifest ausente...).
BRIDGE_WARNINGS=()
# Resultado da descoberta (preenchido por bridge_discover):
#   BRIDGE_SKILLS    = ("<nome>\t<caminho relativo ao acervo>") ordenado por nome
#   BRIDGE_COLLISIONS= ("<nome>\t<rel1>\t<rel2>") nomes ambíguos (ignorados)
BRIDGE_SKILLS=()
BRIDGE_COLLISIONS=()

# ---------------------------------------------------------------------------
# Infra
# ---------------------------------------------------------------------------

bridge_warn() {
    BRIDGE_WARNINGS+=("$1")
    if [[ "$MODE" != "doctor" ]]; then
        echo "  AVISO: $1" >&2
    fi
}

bridge_drift() {
    BRIDGE_DRIFT=$((BRIDGE_DRIFT + 1))
}

bridge_is_apply() {
    [[ "$MODE" == "apply" ]]
}

# Rótulo honesto por modo: o texto diz o que JÁ aconteceu (apply) ou o que
# aconteceria (dry-run/doctor). Nenhum modo mente sobre ter escrito algo.
bridge_label() {
    case "$MODE" in
        apply) printf '%s' "$1" ;;
        dry-run) printf '[dry-run] %s' "$1" ;;
        doctor) printf '[doctor] %s pendente' "$1" ;;
    esac
}

# Nome de skill aceito sem risco pelas ferramentas: começa por [a-z0-9], corpo
# [-._]. Prefixos "@" e "_" existem no acervo e podem não virar slash command:
# avisamos, mas nunca renomeamos (SKILL.md é fonte versionada).
bridge_name_ok() {
    [[ $1 =~ ^[a-z0-9][a-z0-9._-]*$ ]]
}

# Quantos links válidos (que resolvem para dentro do acervo) existem em <dir>.
# Aceita alvo absoluto OU relativo (links antigos vêm em "../.agents/skills/x")
# e também o path real do repo (o alias do acervo).
bridge_count_visible() {
    local dir=$1 entry n=0 center_real
    center_real="$(realpath "$CENTER")"
    [[ -d "$dir" ]] || {
        echo 0
        return 0
    }
    for entry in "$dir"/*; do
        [[ -L "$entry" && -e "$entry" ]] || continue
        case "$(realpath "$entry" 2>/dev/null || true)" in
            "$center_real"/*) n=$((n + 1)) ;;
        esac
    done
    echo "$n"
}

# ---------------------------------------------------------------------------
# Descoberta do acervo
# ---------------------------------------------------------------------------

# Todas as "leaf skills" de topo: dirs em $CENTER com SKILL.md direto.
bridge_leaves() {
    local d
    for d in "$CENTER"/*/; do
        if [[ -d "$d" && -f "$d/SKILL.md" ]]; then
            basename "$d"
        fi
    done
    return 0
}

# Todos os "bundles": dirs de $CENTER sem SKILL.md próprio mas com sub-skills.
# Um bundle não é uma skill (não tem SKILL.md) — é um agrupamento que as
# ferramentas de 1 nível não enxergam; é por isso que existe o flatten.
bridge_bundles() {
    local d n
    for d in "$CENTER"/*/; do
        [[ -d "$d" && -f "$d/SKILL.md" ]] && continue
        n="$(find "$d" -maxdepth 2 -name SKILL.md -type f 2>/dev/null | wc -l)"
        if ((n > 0)); then
            basename "$d"
        fi
    done
    return 0
}

# Descoberta única do acervo → BRIDGE_SKILLS ("<name>\t<relpath>", ordenado por
# nome: determinístico → idempotente e diffável). Roda UMA vez, sem pipeline,
# para que contadores e avisos não se percam em subshell.
# Colisão de basename → as AMBAS ficam de fora (nunca escolhe por conta).
bridge_discover() {
    local f dir rel name seen_name collided=""
    local -A seen=()
    local -a names=() sorted=()
    BRIDGE_SKILLS=()
    BRIDGE_COLLISIONS=()
    while IFS= read -r f; do
        dir="$(dirname "$f")"
        rel="${dir#"$CENTER"/}"
        name="$(basename "$dir")"
        if [[ -n "${seen[$name]:-}" ]]; then
            BRIDGE_COLLISIONS+=("${name}"$'\t'"${seen[$name]}"$'\t'"${rel}")
            collided+=" ${name}"
            continue
        fi
        seen[$name]=$rel
    done < <(find "$CENTER" -maxdepth "$BRIDGE_MAX_DEPTH" -name SKILL.md -type f 2>/dev/null | sort)
    for seen_name in "${!seen[@]}"; do
        names+=("$seen_name")
    done
    if ((${#names[@]} > 0)); then
        mapfile -t sorted < <(printf '%s\n' "${names[@]}" | sort)
    fi
    for seen_name in "${sorted[@]}"; do
        case "$collided" in
            *" ${seen_name} "*) continue ;;
        esac
        BRIDGE_SKILLS+=("${seen_name}"$'\t'"${seen[$seen_name]}")
    done
    BRIDGE_N_COLLISION=${#BRIDGE_COLLISIONS[@]}
    return 0
}

# Emite as skills descobertas por bridge_discover (uma por linha: nome<TAB>rel).
bridge_all() {
    if ((${#BRIDGE_SKILLS[@]} > 0)); then
        printf '%s\n' "${BRIDGE_SKILLS[@]}"
    fi
    return 0
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

# ---------------------------------------------------------------------------
# Escrita (aplicação) — só muta $HOME no modo apply
# ---------------------------------------------------------------------------

# Move um destino real (não-symlink) para <repo>/.bkp com slug datado.
# Retorna 0 em sucesso; 1 se o destino não existe ou já é symlink.
bridge_backup_dest() {
    local dest=$1
    local bkp_dir slug base n=0
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
    while [[ -e "$bkp_dir/$slug" ]]; do
        n=$((n + 1))
        slug="$(date +%d-%m-%Y_%H:%M)_${base}_${n}"
    done
    echo "  Backup: ${dest} → ${bkp_dir}/${slug}"
    mv -- "$dest" "$bkp_dir/$slug"
}

# Garante que <dest> seja um symlink válido para <src>.
# - dest já RESOLVE para src (symlink correto OU o próprio acervo via alias)
#   → ok (nada feito; protege contra dirs que são o próprio acervo central)
# - symlink errado/quebrado → refaz
# - diretório real idêntico → backup + symlink (conversão)
# - diretório real diferente → alerta + skip (retorna 1)
bridge_ensure_link() {
    local dest=$1 src=$2
    local canonical_src canonical_dest
    canonical_src="$(realpath "$src")"
    canonical_dest="$(realpath "$dest" 2>/dev/null || true)"

    # Já está correto (aponta para a fonte ou É a fonte). NUNCA backup/remover.
    if [[ -n "$canonical_dest" && "$canonical_dest" == "$canonical_src" ]]; then
        BRIDGE_N_OK=$((BRIDGE_N_OK + 1))
        return 0
    fi

    if [[ -L "$dest" ]]; then
        echo "  $(bridge_label 'Relink'): ${dest} (apontava para outro lugar)"
        bridge_drift
        if bridge_is_apply; then
            ln -sfn "$src" "$dest"
        fi
        BRIDGE_N_RELINK=$((BRIDGE_N_RELINK + 1))
        return 0
    fi

    if [[ -e "$dest" ]]; then
        if diff -rq "$src" "$dest" >/dev/null 2>&1; then
            if bridge_is_apply; then
                bridge_backup_dest "$dest" || return 1
                ln -s "$src" "$dest"
            else
                echo "  $(bridge_label 'Convert (backup+symlink)'): ${dest}"
                bridge_drift
            fi
            BRIDGE_N_CONVERT=$((BRIDGE_N_CONVERT + 1))
            return 0
        fi
        bridge_warn "SKIP: ${dest} difere do acervo — não foi tocado (confira manualmente)"
        BRIDGE_N_SKIP_DIFF=$((BRIDGE_N_SKIP_DIFF + 1))
        # É uma divergência real do estado desejado: o --doctor precisa acusar.
        bridge_drift
        return 1
    fi

    if bridge_is_apply; then
        if ! ln -s "$src" "$dest"; then
            echo "  ERRO: não foi possível criar ${dest}" >&2
            BRIDGE_N_ERROR=$((BRIDGE_N_ERROR + 1))
            return 1
        fi
    fi
    bridge_drift
    BRIDGE_N_CREATED=$((BRIDGE_N_CREATED + 1))
    return 0
}

# Remove symlinks órfãos dentro de <dir>: apontam para dentro do acervo, mas o
# alvo não existe mais (skill removida do acervo). Aceita alvo absoluto,
# relativo ou o path real do repo.
bridge_cleanup_orphans() {
    local dir=$1 entry target abs center_real
    [[ -d "$dir" ]] || return 0
    center_real="$(realpath "$CENTER")"
    for entry in "$dir"/*; do
        [[ -L "$entry" ]] || continue
        target="$(readlink "$entry")"
        if [[ "$target" == /* ]]; then
            abs="$target"
        else
            abs="$(dirname "$entry")/$target"
        fi
        abs="$(realpath -m "$abs" 2>/dev/null || true)"
        # Só gerencia links que apontam para o acervo (nunca outros conteúdos).
        case "$abs" in
            "$CENTER"/* | "$center_real"/*) ;;
            *) continue ;;
        esac
        if [[ ! -e "$entry" ]]; then
            echo "  $(bridge_label 'Removido órfão'): ${entry} (alvo ${target} não existe mais)"
            bridge_drift
            if bridge_is_apply; then
                rm -- "$entry"
            fi
            BRIDGE_N_ORPHAN=$((BRIDGE_N_ORPHAN + 1))
        fi
    done
    return 0
}

# Normaliza um dir de tool que É o acervo central (alias) em links por-skill.
# Remove só o symlink (a fonte, o repo, nunca é tocada).
bridge_normalize_alias() {
    local dir=$1 center_real dir_real
    center_real="$(realpath "$CENTER")"
    [[ -L "$dir" ]] || return 0
    dir_real="$(realpath "$dir" 2>/dev/null || true)"
    if [[ -n "$dir_real" && "$dir_real" == "$center_real" ]]; then
        echo "  $(bridge_label 'Normalizado alias→per-skill'): ${dir} (link removido; acervo intacto)"
        bridge_drift
        if bridge_is_apply; then
            rm -- "$dir"
        fi
        BRIDGE_N_ALIAS=$((BRIDGE_N_ALIAS + 1))
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Manifest de customização (Antigravity: ~/.gemini/config/skills.json)
# ---------------------------------------------------------------------------

# Conteúdo desejado: 1 entry para a raiz (leaves) + 1 por bundle (sub-skills).
# Caminhos usam "~/.agents/..." (alias do acervo, portátil entre máquinas) —
# resolvidos pelo próprio Antigravity (path home-relative).
bridge_manifest_content() {
    local out=$1 bundle
    {
        printf '{\n'
        printf '  "entries": [\n'
        printf '    { "path": "~/.agents/skills" }'
        while IFS= read -r bundle; do
            [[ -z "$bundle" ]] && continue
            printf ',\n'
            printf '    { "path": "~/.agents/skills/%s" }' "$bundle"
        done < <(bridge_bundles | sort)
        printf '\n  ]\n'
        printf '}\n'
    } >"$out"
}

bridge_write_manifest() {
    local tool=$1 file n_entries
    file="${TOOL_MANIFEST[$tool]:-}"
    [[ -n "$file" ]] || return 0
    local tmp
    tmp="$(mktemp)"
    bridge_manifest_content "$tmp"
    n_entries="$(grep -c '"path"' "$tmp")"

    if [[ -f "$file" ]] && diff -q "$tmp" "$file" >/dev/null 2>&1; then
        echo "  Manifest em dia: ${file} (${n_entries} entries)"
        rm -f "$tmp"
        return 0
    fi

    if [[ -e "$file" ]]; then
        # Só sobrescreve com backup datado: nunca perde um manifest editado à mão.
        local bkp_dir slug
        bkp_dir="$(dotfiles_backup_dir)"
        mkdir -p "$bkp_dir"
        slug="$(date +%d-%m-%Y_%H:%M)_$(basename "$file")"
        if bridge_is_apply; then
            echo "  Backup: ${file} → ${bkp_dir}/${slug}"
            cp -p -- "$file" "$bkp_dir/$slug"
        fi
        bridge_drift
    fi
    if bridge_is_apply; then
        mkdir -p "$(dirname "$file")"
        cp -- "$tmp" "$file"
    fi
    echo "  Manifest [${MODE}]: ${file} (${n_entries} entries)"
    BRIDGE_N_MANIFEST=$((BRIDGE_N_MANIFEST + 1))
    rm -f "$tmp"
    return 0
}

# ---------------------------------------------------------------------------
# Bridge por tool
# ---------------------------------------------------------------------------

bridge_tool() {
    local tool=$1 spec=$2
    local dirs dir skill rel src line
    local -a pairs=()

    if [[ "$spec" == "$SPEC_MANIFEST" ]]; then
        bridge_write_manifest "$tool"
        return 0
    fi

    IFS=':' read -r -a dirs <<<"${TOOL_DIRS[$tool]}"
    for dir in "${dirs[@]}"; do
        # Alias do acervo central → normaliza em links por-skill (o acervo tem
        # bundles no topo, que não são skills e poluem a lista da tool).
        # Precisa vir ANTES do mkdir: o alias É o dir, e removê-lo o apaga.
        bridge_normalize_alias "$dir"
        if bridge_is_apply; then
            mkdir -p "$dir"
        fi

        local expected=0 visible status
        pairs=()
        if [[ "$spec" == "$SPEC_LEAVES" ]]; then
            while IFS= read -r skill; do
                [[ -z "$skill" ]] && continue
                expected=$((expected + 1))
                echo "→ ${tool} [$(basename "$dir")] ${skill}"
                bridge_ensure_link "$dir/$skill" "$CENTER/$skill" || true
            done < <(bridge_leaves)
        elif [[ "$spec" == "$SPEC_ALL" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                pairs+=("$line")
            done < <(bridge_all)
            for line in "${pairs[@]}"; do
                skill="${line%%$'\t'*}"
                rel="${line#*$'\t'}"
                expected=$((expected + 1))
                echo "→ ${tool} [$(basename "$dir")] ${skill} ← ${rel}"
                bridge_ensure_link "$dir/$skill" "$CENTER/$rel" || true
            done
        else
            # Spec explícita: resolve dentro do acervo (pode ser bundle/sub-skill).
            if src="$(bridge_resolve_src "$spec")"; then
                skill="$(basename "$src")"
                expected=1
                echo "→ ${tool} [$(basename "$dir")] ${spec} (src=${src})"
                bridge_ensure_link "$dir/$skill" "$src" || true
            else
                echo "  AVISO: skill não encontrada no acervo: ${spec}" >&2
            fi
        fi
        bridge_cleanup_orphans "$dir"

        visible="$(bridge_count_visible "$dir")"
        if [[ "$MODE" == "doctor" ]]; then
            if ((visible == expected)); then status="ok"; else status="DRIFT"; fi
        else
            status="${visible}/${expected}"
        fi
        BRIDGE_ROWS+=("${tool}|${dir}|${expected}|${visible}|${status}")
    done
    return 0
}

bridge_summary() {
    local row tool dir expected visible status
    printf '\n%-12s %-40s %9s %9s  %s\n' TOOL ROOT ESPERADO VISÍVEIS ESTADO
    printf '%s\n' "────────────────────────────────────────────────────────────────────────"
    for row in "${BRIDGE_ROWS[@]}"; do
        IFS='|' read -r tool dir expected visible status <<<"$row"
        printf '%-12s %-40s %9s %9s  %s\n' "$tool" "$dir" "$expected" "$visible" "$status"
    done
}

bridge_report() {
    cat <<EOF

── Bridge de skills ───────────────────────────────────────────
  criados:            ${BRIDGE_N_CREATED}
  já ok:              ${BRIDGE_N_OK}
  relinkados:         ${BRIDGE_N_RELINK}
  convertidos (bkp):  ${BRIDGE_N_CONVERT}
  alias normalizados: ${BRIDGE_N_ALIAS}
  órfãos removidos:   ${BRIDGE_N_ORPHAN}
  manifest gerado:    ${BRIDGE_N_MANIFEST}
  colisões basename:  ${BRIDGE_N_COLLISION}
  nomes fora padrão:  ${BRIDGE_N_NAMEWARN}
  pulados (divergem): ${BRIDGE_N_SKIP_DIFF}
  erros de escrita:   ${BRIDGE_N_ERROR}
  drift detectado:    ${BRIDGE_DRIFT}
───────────────────────────────────────────────────────────────
EOF
    # Em doctor os avisos são impressos só aqui (nos outros já saem ao vivo).
    if [[ "$MODE" == "doctor" ]] && ((${#BRIDGE_WARNINGS[@]} > 0)); then
        echo ""
        echo "  Avisos (${#BRIDGE_WARNINGS[@]}):"
        printf '   - %s\n' "${BRIDGE_WARNINGS[@]}"
    fi
}

# ---------------------------------------------------------------------------
# Validação de configuração (executada nos 3 modos)
# ---------------------------------------------------------------------------

# Nomes fora do padrão + colisões de basename: avisados 1x por execução, antes
# de aplicar (nunca corrigidos automaticamente: SKILL.md é fonte versionada).
bridge_hygiene() {
    local line name rel1 rel2
    for line in "${BRIDGE_COLLISIONS[@]}"; do
        IFS=$'\t' read -r name rel1 rel2 <<<"$line"
        bridge_warn "colisão de basename: '${name}' existe em '${rel1}' e em '${rel2}' — ambas ignoradas (renomeie no acervo)"
    done
    for line in "${BRIDGE_SKILLS[@]}"; do
        name="${line%%$'\t'*}"
        if ! bridge_name_ok "$name"; then
            BRIDGE_N_NAMEWARN=$((BRIDGE_N_NAMEWARN + 1))
            bridge_warn "nome fora do padrão (pode não virar slash command): '${name}'"
        fi
    done
}

bridge_usage() {
    cat <<EOF
Uso: $(basename "$0") [--doctor | --dry-run | --help]

  (padrão)    aplica as mudanças declaradas em config/agent-skills-bridge.list
  --dry-run   mostra o que faria, sem escrever nada em \$HOME
  --doctor    diagnóstico read-only (o que cada tool enxerga + drift); exit 1 se houver drift
EOF
}

bridge_main() {
    local line tool spec mode_flag=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --doctor | -D)
                MODE=doctor
                mode_flag="--doctor (read-only)"
                ;;
            --dry-run | -n)
                MODE=dry-run
                mode_flag="--dry-run (nada é escrito)"
                ;;
            -h | --help)
                bridge_usage
                return 0
                ;;
            *)
                echo "Opção desconhecida: $1" >&2
                bridge_usage >&2
                return 2
                ;;
        esac
        shift
    done

    if [[ ! -d "$CENTER" ]]; then
        echo "Erro: acervo central não encontrado: ${CENTER}" >&2
        echo "      Execute scripts/install-dotfiles.sh antes (cria o symlink ~/.agents)." >&2
        return 1
    fi
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Erro: configuração não encontrada: ${CONFIG_FILE}" >&2
        return 1
    fi

    # Descoberta única do acervo (lê o disco 1x; usada por todas as tools).
    bridge_discover

    if [[ -n "$mode_flag" ]]; then
        echo "MODO: ${mode_flag}"
    else
        echo "Bridge de skills → acervo central ${CENTER}"
    fi
    echo "Config: ${CONFIG_FILE}"
    echo "Acervo: ${#BRIDGE_SKILLS[@]} skills em $(bridge_leaves | wc -l) leaves + $(bridge_bundles | wc -l) bundles"
    echo ""

    bridge_hygiene

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

    bridge_summary
    bridge_report

    if [[ "$MODE" == "doctor" ]]; then
        if ((BRIDGE_DRIFT > 0)); then
            echo ""
            echo "→ ${BRIDGE_DRIFT} divergência(s). Para convergir: scripts/install-agent-skills-bridge.sh"
            return 1
        fi
        echo ""
        echo "→ Tudo convergido com o acervo central."
        return 0
    fi
    return 0
}

bridge_main "$@"
