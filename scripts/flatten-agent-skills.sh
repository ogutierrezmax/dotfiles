#!/usr/bin/env bash
# === flatten-agent-skills.sh ===
# Migra o acervo ~/.agents/skills de "bundles" (agrupamento por diretório) para
# uma estrutura FLAT, movendo a organização para o catálogo de metadados do app
# skills-gui (apps/skills-gui/catalog/skills-catalog.json).
#
# O que faz:
#   1. move <bundle>/<skill>/ para <skill>/ (git mv quando rastreado);
#   2. normaliza nomes com prefixo "@" (dir + campo name: do frontmatter);
#   3. remove os diretórios de bundle que ficarem vazios;
#   4. semeia/atualiza o catálogo (categoria derivada do bundle; leaves e skills
#      novas entram como "uncategorized");
#   5. remove o prefixo de bundle das specs em config/agent-skills-bridge.list;
#   6. corrige os skillPath de data/.agents/.skill-lock.json.
#
# Modos:
#   --dry-run   mostra o plano (moves, renomes, categorias) sem escrever nada
#   --apply     aplica (padrão)
#   --check     diagnóstico read-only: estrutura flat + cobertura do catálogo
#   --help      esta ajuda
#
# SECURITY NOTE (guardrails para humanos e agentes de IA):
#  - Idempotente: rodar de novo não move nada (não há mais bundles) e só
#    acrescenta ao catálogo entradas que faltam — metadados existentes NUNCA
#    são sobrescritos.
#  - Catálogo existente é copiado para .bkp/ antes de qualquer merge.
#  - Aborta se houver colisão de nome final (nunca escolhe por conta própria).
#  - Nada é apagado: diretórios de bundle só saem com `rmdir` (vazio).
#  - Nunca usa `rm -rf`, nunca toca em arquivos fora de data/.agents/skills,
#    config/agent-skills-bridge.list e data/.agents/.skill-lock.json.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dotfiles-lib.sh
source "${SCRIPT_DIR}/dotfiles-lib.sh"

REPO="$(dotfiles_repo_root)"
CENTER="${REPO}/data/.agents/skills"
CATALOG="${REPO}/apps/skills-gui/catalog/skills-catalog.json"
BRIDGE_CONFIG="${REPO}/config/agent-skills-bridge.list"
SKILL_LOCK="${REPO}/data/.agents/.skill-lock.json"

MODE=apply

usage() {
    cat <<'EOF'
Uso: flatten-agent-skills.sh [--dry-run | --apply | --check | --help]

  --dry-run  Mostra o plano (moves, renomes, categorias) sem escrever nada.
  --apply    Aplica a migração (padrão). Idempotente.
  --check    Diagnóstico read-only: skills aninhadas, nomes com "@" e
             cobertura do catálogo. Exit 1 se houver problema.
  --help     Esta ajuda.
EOF
}

case "${1:-}" in
    --dry-run) MODE=dry-run ;;
    --apply | "") MODE=apply ;;
    --check) MODE=check ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "Argumento inválido: $1" >&2
        usage >&2
        exit 2
        ;;
esac

command -v jq >/dev/null 2>&1 || {
    echo "ERRO: jq é obrigatório (usado para o catálogo e o skill-lock)." >&2
    exit 1
}

[[ -d "$CENTER" ]] || {
    echo "ERRO: acervo não encontrado: $CENTER" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# "@git-commit" → "git-commit"
normalize_skill_name() {
    local n=$1
    printf '%s' "${n#@}"
}

# "tech-domain-skills" → "tech-domain"; "K-flow" → "k-flow"
normalize_category() {
    local c=$1
    c="${c%-skills}"
    printf '%s' "${c,,}"
}

# Rótulo humano: "k1-refinement" → "K1 Refinement"
category_label() {
    local c=$1
    printf '%s' "$c" | awk -F- '{
        for (i = 1; i <= NF; i++) {
            printf "%s%s", (i > 1 ? " " : ""), toupper(substr($i, 1, 1)) substr($i, 2)
        }
        print ""
    }'
}

# Atualiza o campo name: (primeira ocorrência) preservando o resto do arquivo.
set_frontmatter_name() {
    local file=$1 name=$2
    sed -i "0,/^name:/{s|^name:.*|name: \"${name}\"|}" "$file"
}

# ---------------------------------------------------------------------------
# Descoberta
# ---------------------------------------------------------------------------

# Arrays paralelos: SRC_DIRS[i] → FINAL_NAMES[i] → SKILL_CATS[i]
SRC_DIRS=()
FINAL_NAMES=()
SKILL_CATS=()
BUNDLES=()

discover() {
    local f dir rel base final cat

    while IFS= read -r f; do
        dir="$(dirname "$f")"
        rel="${dir#"$CENTER"/}"
        base="$(basename "$dir")"
        final="$(normalize_skill_name "$base")"

        if [[ "$rel" == */* ]]; then
            cat="$(normalize_category "${rel%%/*}")"
        else
            cat="uncategorized"
        fi

        SRC_DIRS+=("$dir")
        FINAL_NAMES+=("$final")
        SKILL_CATS+=("$cat")
    done < <(find "$CENTER" -mindepth 2 -maxdepth 3 -name SKILL.md -type f 2>/dev/null | sort)

    local bundle
    while IFS= read -r bundle; do
        BUNDLES+=("$bundle")
    done < <(
        find "$CENTER" -mindepth 3 -maxdepth 3 -name SKILL.md -type f 2>/dev/null \
            | while IFS= read -r f; do
                dir="$(dirname "$f")"
                printf '%s\n' "${dir#"$CENTER"/}" | cut -d/ -f1
            done | sort -u
    )
}

# Aborta se dois skills distintos disputarem o mesmo nome final.
check_collisions() {
    local dup
    dup="$(printf '%s\n' "${FINAL_NAMES[@]}" | sort | uniq -d)"
    if [[ -n "$dup" ]]; then
        echo "ERRO: colisão de nome final — a migração foi abortada:" >&2
        printf '%s\n' "$dup" | sed 's/^/  - /' >&2
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Plano (dry-run e apply)
# ---------------------------------------------------------------------------

print_plan() {
    local i src final cat rel moves=0 renames=0

    echo "Acervo: ${CENTER}"
    echo "Skills: ${#SRC_DIRS[@]} (${#BUNDLES[@]} bundles)"
    echo

    for i in "${!SRC_DIRS[@]}"; do
        src="${SRC_DIRS[$i]}"
        final="${FINAL_NAMES[$i]}"
        cat="${SKILL_CATS[$i]}"
        rel="${src#"$CENTER"/}"

        if [[ "$rel" == */* ]]; then
            moves=$((moves + 1))
            printf '  [move]   %-48s → %s  (categoria: %s)\n' "$rel" "$final" "$cat"
        fi

        if [[ "$(basename "$src")" != "$final" ]]; then
            renames=$((renames + 1))
            printf '  [rename] %-48s → %s  (name: %s → %s)\n' \
                "$rel" "$final" "$(basename "$src")" "$final"
        fi
    done

    echo
    echo "Resumo: ${moves} move(s), ${renames} renome(s), ${#BUNDLES[@]} bundle(s) a remover."
    echo "Catálogo: ${CATALOG}"
}

# ---------------------------------------------------------------------------
# Catálogo
# ---------------------------------------------------------------------------

seed_catalog() {
    local now tsv new_json old_json merged
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    tsv="$(mktemp)"
    new_json="$(mktemp)"
    old_json="$(mktemp)"
    merged="$(mktemp)"

    local i name
    for i in "${!FINAL_NAMES[@]}"; do
        name="${FINAL_NAMES[$i]}"
        printf '%s\t%s\n' "$name" "${SKILL_CATS[$i]}" >>"$tsv"
    done

    jq -Rn --arg now "$now" '
        def cat_label:
            { "ai-config": "AI Config", "ai-ecosystem": "AI Ecosystem",
              "cursor-ide": "Cursor IDE", "devops": "DevOps", "k-flow": "K-Flow" }[.] //
            (. | gsub("-"; " ") | split(" ")
               | map((.[0:1] | ascii_upcase) + .[1:]) | join(" "));
        [inputs | split("\t") | {name: .[0], category: .[1]}]
        | {
            version: 1,
            updatedAt: $now,
            categories: (
                ([.[].category] | unique | sort | to_entries
                 | map({
                     id: .value,
                     label: (.value | cat_label),
                     order: ((.key + 1) * 10)
                   }))
            ),
            skills: (
                map({
                    key: .name,
                    value: {category: .category, tags: [], tools: null, favorite: false, notes: ""}
                }) | from_entries
            )
          }
    ' <"$tsv" >"$new_json"

    mkdir -p "$(dirname "$CATALOG")"

    if [[ -f "$CATALOG" ]]; then
        local bkp_dir slug
        bkp_dir="$(dotfiles_backup_dir)"
        mkdir -p "$bkp_dir"
        slug="$(date +%d-%m-%Y_%H:%M)_skills-catalog.json"
        cp -p -- "$CATALOG" "${bkp_dir}/${slug}"
        echo "  Backup do catálogo: ${bkp_dir}/${slug}"
        cp -- "$CATALOG" "$old_json"
    else
        printf '{"version":1,"categories":[],"skills":{}}\n' >"$old_json"
    fi

    # Merge: entradas existentes SEMPRE vencem (metadados do usuário).
    jq -s --arg now "$now" '
        .[0] as $old
        | .[1] as $new
        | $old
        | .version = 1
        | .updatedAt = $now
        | .skills = ($new.skills + ($old.skills // {}))
        | .categories = (
            (($old.categories // []) + ($new.categories // []))
            | unique_by(.id)
            | sort_by((.order // 999), .id)
          )
    ' "$old_json" "$new_json" >"$merged"

    mv -- "$merged" "$CATALOG"
    rm -f -- "$tsv" "$new_json" "$old_json"

    echo "  Catálogo: $(jq -r '"\(.skills | length) skills, \(.categories | length) categorias"' "$CATALOG")"
}

# ---------------------------------------------------------------------------
# Config do bridge e skill-lock
# ---------------------------------------------------------------------------

update_bridge_config() {
    [[ -f "$BRIDGE_CONFIG" ]] || return 0
    # "cursor|tech-domain-skills/tauri-gmail-oauth" → "cursor|tauri-gmail-oauth"
    if grep -qE '^[a-z]+\|[a-z0-9-]+/' "$BRIDGE_CONFIG"; then
        sed -i -E 's#^([a-z]+)\|([a-z0-9-]+)/#\1|#' "$BRIDGE_CONFIG"
        echo "  Bridge: prefixos de bundle removidos de ${BRIDGE_CONFIG#"$REPO"/}"
    fi
}

update_skill_lock() {
    [[ -f "$SKILL_LOCK" ]] || return 0
    local tmp
    tmp="$(mktemp)"
    jq '
        .skills |= with_entries(
            .value.skillPath |= (
                sub("^\\.agents/"; "") as $p
                | ($p | split("/")) as $s
                | (if ($s | length) == 4 then "skills/" + ($s[2:] | join("/")) else $p end)
                | gsub("/@"; "/")
            )
        )
    ' "$SKILL_LOCK" >"$tmp" && mv -- "$tmp" "$SKILL_LOCK"
    echo "  skill-lock: skillPath normalizados"
}

# ---------------------------------------------------------------------------
# Aplicação
# ---------------------------------------------------------------------------

apply_migration() {
    local i src final dest base tracked=0 moved=0

    for i in "${!SRC_DIRS[@]}"; do
        src="${SRC_DIRS[$i]}"
        final="${FINAL_NAMES[$i]}"
        dest="${CENTER}/${final}"
        base="$(basename "$src")"

        [[ "$src" == "$dest" ]] && continue

        if [[ -e "$dest" ]]; then
            echo "ERRO: destino já existe: $dest" >&2
            exit 1
        fi

        if git -C "$REPO" ls-files --error-unmatch "$src" >/dev/null 2>&1; then
            tracked=$((tracked + 1))
            git -C "$REPO" mv -- "$src" "$dest"
        else
            mv -- "$src" "$dest"
        fi
        moved=$((moved + 1))

        if [[ "$base" != "$final" ]]; then
            set_frontmatter_name "$dest/SKILL.md" "$final"
        fi
    done

    echo "  Movidos: ${moved} (${tracked} via git mv)"

    local b
    for b in "${BUNDLES[@]}"; do
        local bdir="${CENTER}/${b}"
        [[ -d "$bdir" ]] || continue
        if rmdir -- "$bdir" 2>/dev/null; then
            echo "  Bundle vazio removido: ${b}/"
        else
            echo "  AVISO: bundle não vazio (revisar manualmente): ${b}/" >&2
            find "$bdir" -mindepth 1 -maxdepth 1 -printf '    %f\n' >&2
        fi
    done
}

# ---------------------------------------------------------------------------
# Check (read-only)
# ---------------------------------------------------------------------------

check_state() {
    local fail=0 nested=0 at_names=0 missing=0 orphan=0
    local f rel depth

    echo "== Estrutura =="
    while IFS= read -r f; do
        rel="${f#"$CENTER"/}"
        depth="$(awk -F/ '{print NF}' <<<"$rel")"
        if ((depth > 2)); then
            echo "  ERRO aninhada: ${rel}"
            nested=$((nested + 1))
            fail=1
        fi
    done < <(find "$CENTER" -name SKILL.md -type f 2>/dev/null | sort)

    while IFS= read -r f; do
        echo "  ERRO nome com @: ${f#"$CENTER"/}"
        at_names=$((at_names + 1))
        fail=1
    done < <(find "$CENTER" -maxdepth 2 -type d -name '@*' 2>/dev/null | sort)

    local total
    total="$(find "$CENTER" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l)"
    echo "  Skills flat: ${total} | aninhadas: ${nested} | nomes com @: ${at_names}"

    echo
    echo "== Catálogo =="
    if [[ ! -f "$CATALOG" ]]; then
        echo "  ERRO: catálogo ausente: ${CATALOG}"
        return 1
    fi
    if ! jq empty "$CATALOG" 2>/dev/null; then
        echo "  ERRO: catálogo não é JSON válido"
        return 1
    fi

    local dirs_file keys_file
    dirs_file="$(mktemp)"
    keys_file="$(mktemp)"
    find "$CENTER" -mindepth 2 -maxdepth 2 -name SKILL.md -type f \
        -printf '%h\n' | xargs -n1 basename | sort >"$dirs_file"
    jq -r '.skills | keys[]' "$CATALOG" | sort >"$keys_file"

    while IFS= read -r f; do
        echo "  FALTA no catálogo: ${f}"
        missing=$((missing + 1))
        fail=1
    done < <(comm -23 "$dirs_file" "$keys_file")

    while IFS= read -r f; do
        echo "  ÓRFÃ no catálogo (sem diretório): ${f}"
        orphan=$((orphan + 1))
        fail=1
    done < <(comm -13 "$dirs_file" "$keys_file")

    echo "  Entradas: ${total} skills | $(jq -r '.skills | length' "$CATALOG") no catálogo | faltando: ${missing} | órfãs: ${orphan}"

    # Aviso (não falha): dir ≠ name do frontmatter.
    local name
    while IFS= read -r f; do
        name="$(awk 'NR > 1 && /^name:/ {gsub(/^name:[[:space:]]*["'\'']?|["'\'']?[[:space:]]*$/, ""); print; exit}' "$f")"
        rel="$(basename "$(dirname "$f")")"
        if [[ -n "$name" && "$name" != "$rel" ]]; then
            echo "  AVISO: dir '${rel}' ≠ name '${name}'"
        fi
    done < <(find "$CENTER" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | sort)

    rm -f -- "$dirs_file" "$keys_file"

    echo
    if ((fail == 0)); then
        echo "OK: estrutura flat e catálogo em dia."
        return 0
    fi
    echo "FALHOU: corrija os itens acima." >&2
    return 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [[ "$MODE" == check ]]; then
    check_state
    exit $?
fi

discover
check_collisions

if [[ ${#SRC_DIRS[@]} -eq 0 ]]; then
    echo "Nenhuma skill encontrada em ${CENTER}" >&2
    exit 1
fi

print_plan

if [[ "$MODE" == dry-run ]]; then
    echo
    echo "DRY-RUN: nada foi alterado. Rode com --apply para migrar."
    exit 0
fi

echo
echo "Aplicando migração..."
apply_migration
seed_catalog
update_bridge_config
update_skill_lock

echo
echo "Migração concluída. Valide com:"
echo "  scripts/flatten-agent-skills.sh --check"
echo "  scripts/install-agent-skills-bridge.sh --doctor"
