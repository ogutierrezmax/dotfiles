#!/usr/bin/env bash
# === chunk-injector.sh ===
# Gerenciador declarativo de "chunks" (trechos de configuração/código) em
# arquivos que não podem ser integralmente substituídos por symlinks.
#
# Operações:
#   chunk-injector [inject] [--dry-run]  Injeta chunks ausentes/divergentes + ativa timer
#   chunk-injector doctor | check        Diagnóstico read-only (exit 1 se houver drift)
#   chunk-injector monitor               Verificação periódica silenciosa (alerta via
#                                        notify-send e ~/.cache/dotfiles/chunk-injector-alert.txt)
#
# Configuração padrão: config/chunk-injector.list
# Formato: <id>|<tipo>|<arquivo-alvo>|<seletor>|<fonte>|<descrição>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dotfiles-lib.sh disable=SC1091
source "${SCRIPT_DIR}/dotfiles-lib.sh"

REPO_ROOT="$(dotfiles_repo_root)"
CHUNKS_DIR="${CHUNK_INJECTOR_DIR:-${REPO_ROOT}/config/chunks}"
ALERT_FILE="${CHUNK_INJECTOR_ALERT_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/chunk-injector-alert.txt}"
BACKUP_DIR="${CHUNK_INJECTOR_BACKUP_DIR:-$(dotfiles_backup_dir)}"
UNDO_DIR="${CHUNK_INJECTOR_UNDO_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/undo}"

CI_N_OK=0
CI_N_INJECTED=0
CI_N_UPDATED=0
CI_N_REVERTED=0
CI_N_MISSING=0
CI_N_DRIFT=0
CI_N_ERROR=0

ci_usage() {
    cat <<'EOF'
Uso: chunk-injector [comando] [opções]

Comandos:
  inject (padrão)   Injeta chunks ausentes ou divergentes (faz backup em .bkp/)
  revert, undo      Desfaz a injeção (restaura snapshot pré-injeção ou reverte trecho)
  doctor, check     Diagnóstico read-only de todos os chunks (exit 1 se faltar algo)
  monitor           Verifica sem alterar arquivos; grava alerta em cache e envia
                    notificação desktop (notify-send) se algum chunk tiver sumido
  help              Exibe esta ajuda

Opções:
  --only <id>       Executa a operação exclusivamente no chunk com o ID especificado
  --dry-run         Simula a injeção sem modificar arquivos
  --no-systemd      Não tenta habilitar/iniciar o timer systemd --user no inject
  --no-notify       Não dispara notify-send no modo monitor

Variáveis de ambiente opcionais:
  CHUNK_INJECTOR_DIR         Diretório de definições de chunks (padrão: config/chunks/)
  CHUNK_INJECTOR_ALERT_FILE  Caminho alternativo para o arquivo de alerta em cache
  CHUNK_INJECTOR_BACKUP_DIR  Diretório alternativo para backups (.bkp)
EOF
}

# Expande ~/ e $HOME/ literais no início de um caminho.
# shellcheck disable=SC2016,SC2088
ci_expand_path() {
    local p=$1
    if [[ "$p" == "~/"* ]]; then
        printf '%s/%s\n' "$HOME" "${p#\~/}"
    elif [[ "$p" == '$HOME/'* ]]; then
        printf '%s/%s\n' "$HOME" "${p#\$HOME/}"
    elif [[ "$p" == '${HOME}/'* ]]; then
        printf '%s/%s\n' "$HOME" "${p#\$\{HOME\}/}"
    else
        printf '%s\n' "$p"
    fi
}

# Abrevia $HOME para ~ para exibição em tabelas e alertas.
# shellcheck disable=SC2088
ci_short_path() {
    local p=$1
    if [[ -n "${HOME:-}" && "$p" == "$HOME/"* ]]; then
        printf '~/%s\n' "${p#"$HOME"/}"
    else
        printf '%s\n' "$p"
    fi
}

# Carrega o conteúdo esperado a partir da especificação <fonte>.
# Suporta:
#   - json:<literal>
#   - text:<literal>
#   - caminho relativo ao REPO_ROOT (ou absoluto)
ci_load_source_content() {
    local src_spec=$1
    local resolved
    if [[ "$src_spec" == "json:"* ]]; then
        printf '%s\n' "${src_spec#json:}"
        return 0
    fi
    if [[ "$src_spec" == "text:"* ]]; then
        printf '%s\n' "${src_spec#text:}"
        return 0
    fi
    if [[ "$src_spec" == /* ]]; then
        resolved="$src_spec"
    else
        resolved="${REPO_ROOT}/${src_spec}"
    fi
    if [[ ! -f "$resolved" ]]; then
        return 1
    fi
    cat "$resolved"
}

# Faz backup de um arquivo existente em $BACKUP_DIR antes de modificá-lo.
ci_backup_file() {
    local target=$1
    local base slug n
    [[ -f "$target" ]] || return 0
    mkdir -p "$BACKUP_DIR"
    base="$(basename "$target")"
    slug="$(date +%d-%m-%Y_%H-%M)_chunk_${base}"
    n=0
    while [[ -e "${BACKUP_DIR}/${slug}" ]]; do
        n=$((n + 1))
        slug="$(date +%d-%m-%Y_%H-%M)_chunk_${base}_${n}"
    done
    cp -p -- "$target" "${BACKUP_DIR}/${slug}"
}

# Substitui o arquivo-alvo preservando permissões originais se o alvo já existia.
ci_atomic_replace() {
    local tmp_file=$1 target=$2
    if [[ -f "$target" ]]; then
        chmod --reference="$target" "$tmp_file" 2>/dev/null || true
    fi
    mv -f -- "$tmp_file" "$target"
}

# ── Estratégia 1: json-key (via jq) ──────────────────────────────────────────

# Retorna: OK | TARGET_MISSING | INVALID_TARGET | MISSING | DRIFT
ci_check_json_key() {
    local target=$1 selector=$2 expected_raw=$3
    local expected_norm actual_type actual_norm

    if ! command -v jq >/dev/null 2>&1; then
        printf 'ERROR_NO_JQ\n'
        return 0
    fi

    expected_norm="$(printf '%s\n' "$expected_raw" | jq -S -c '.' 2>/dev/null)" || {
        printf 'INVALID_SOURCE\n'
        return 0
    }

    if [[ ! -f "$target" ]]; then
        printf 'TARGET_MISSING\n'
        return 0
    fi

    if ! jq -e '.' "$target" >/dev/null 2>&1; then
        printf 'INVALID_TARGET\n'
        return 0
    fi

    if [[ "$selector" == "." || "$selector" == "-" || -z "$selector" ]]; then
        local check_res
        check_res="$(jq -r --argjson exp "$expected_norm" '
            if type != "object" then
                "MISSING"
            else
                [($exp | keys[]) as $k | 
                    if has($k) | not then "MISSING"
                    elif .[$k] == $exp[$k] then "OK"
                    else "DRIFT"
                    end
                ] | 
                if any(. == "DRIFT") then "DRIFT"
                elif all(. == "OK") then "OK"
                else "MISSING"
                end
            end
        ' "$target" 2>/dev/null || printf 'INVALID_TARGET')"
        printf '%s\n' "$check_res"
        return 0
    fi

    actual_type="$(jq -r "${selector} | type" "$target" 2>/dev/null || printf 'null')"
    if [[ "$actual_type" == "null" ]]; then
        printf 'MISSING\n'
        return 0
    fi

    actual_norm="$(jq -S -c "${selector}" "$target" 2>/dev/null || printf '')"
    if [[ "$actual_norm" == "$expected_norm" ]]; then
        printf 'OK\n'
    else
        printf 'DRIFT\n'
    fi
}

ci_inject_json_key() {
    local target=$1 selector=$2 expected_raw=$3
    local expected_norm tmp_file target_dir

    expected_norm="$(printf '%s\n' "$expected_raw" | jq -S -c '.')"
    target_dir="$(dirname "$target")"
    mkdir -p "$target_dir"

    tmp_file="$(mktemp "${target_dir}/.chunk-injector.XXXXXX")"

    if [[ "$selector" == "." || "$selector" == "-" || -z "$selector" ]]; then
        if [[ -f "$target" ]]; then
            ci_backup_file "$target"
            if ! jq --argjson val "$expected_norm" '. * $val' "$target" >"$tmp_file"; then
                rm -f -- "$tmp_file"
                return 1
            fi
        else
            if ! jq -n --argjson val "$expected_norm" '$val' >"$tmp_file"; then
                rm -f -- "$tmp_file"
                return 1
            fi
        fi
        ci_atomic_replace "$tmp_file" "$target"
        return 0
    fi

    if [[ -f "$target" ]]; then
        ci_backup_file "$target"
        if ! jq --argjson val "$expected_norm" "${selector} = \$val" "$target" >"$tmp_file"; then
            rm -f -- "$tmp_file"
            return 1
        fi
    else
        if ! jq -n --argjson val "$expected_norm" "${selector} = \$val" >"$tmp_file"; then
            rm -f -- "$tmp_file"
            return 1
        fi
    fi

    ci_atomic_replace "$tmp_file" "$target"
}

# ── Estratégia 2: block (marcadores begin/end) ───────────────────────────────

ci_block_markers() {
    local id=$1 selector=$2
    local prefix="#"
    if [[ -n "$selector" && "$selector" != "-" ]]; then
        prefix="$selector"
    fi
    printf '%s >>> chunk-injector:%s >>>\n' "$prefix" "$id"
    printf '%s <<< chunk-injector:%s <<<\n' "$prefix" "$id"
}

ci_check_block() {
    local id=$1 target=$2 selector=$3 expected_raw=$4
    local begin_mark end_mark extracted

    if [[ ! -f "$target" ]]; then
        printf 'TARGET_MISSING\n'
        return 0
    fi

    {
        IFS= read -r begin_mark
        IFS= read -r end_mark
    } < <(ci_block_markers "$id" "$selector")

    if ! grep -Fxq -- "$begin_mark" "$target" || ! grep -Fxq -- "$end_mark" "$target"; then
        printf 'MISSING\n'
        return 0
    fi

    extracted="$(awk -v b="$begin_mark" -v e="$end_mark" '
        $0 == b { inside=1; next }
        $0 == e { inside=0; exit }
        inside { print }
    ' "$target")"

    if [[ "$extracted" == "$expected_raw" ]]; then
        printf 'OK\n'
    else
        printf 'DRIFT\n'
    fi
}

ci_inject_block() {
    local id=$1 target=$2 selector=$3 expected_raw=$4
    local begin_mark end_mark target_dir tmp_file body_file

    {
        IFS= read -r begin_mark
        IFS= read -r end_mark
    } < <(ci_block_markers "$id" "$selector")

    target_dir="$(dirname "$target")"
    mkdir -p "$target_dir"
    tmp_file="$(mktemp "${target_dir}/.chunk-injector.XXXXXX")"
    body_file="$(mktemp "${target_dir}/.chunk-body.XXXXXX")"
    printf '%s\n' "$expected_raw" >"$body_file"

    if [[ -f "$target" ]]; then
        ci_backup_file "$target"
        if grep -Fxq -- "$begin_mark" "$target" && grep -Fxq -- "$end_mark" "$target"; then
            awk -v b="$begin_mark" -v e="$end_mark" -v bf="$body_file" '
                $0 == b {
                    print b
                    while ((getline line < bf) > 0) print line
                    close(bf)
                    skip=1
                    next
                }
                $0 == e {
                    print e
                    skip=0
                    next
                }
                !skip { print }
            ' "$target" >"$tmp_file"
        else
            cat "$target" >"$tmp_file"
            # Garante quebra de linha antes do bloco se arquivo não estiver vazio
            if [[ -s "$tmp_file" ]] && [[ "$(tail -c 1 "$tmp_file" | wc -l)" -eq 0 ]]; then
                printf '\n' >>"$tmp_file"
            fi
            printf '%s\n%s\n%s\n' "$begin_mark" "$expected_raw" "$end_mark" >>"$tmp_file"
        fi
    else
        printf '%s\n%s\n%s\n' "$begin_mark" "$expected_raw" "$end_mark" >"$tmp_file"
    fi

    rm -f -- "$body_file"
    ci_atomic_replace "$tmp_file" "$target"
}

# ── Estratégia 3: line (linha exata) ─────────────────────────────────────────

ci_check_line() {
    local target=$1 expected_raw=$2
    local first_line
    first_line="${expected_raw%%$'\n'*}"

    if [[ ! -f "$target" ]]; then
        printf 'TARGET_MISSING\n'
        return 0
    fi

    if grep -Fxq -- "$first_line" "$target"; then
        printf 'OK\n'
    else
        printf 'MISSING\n'
    fi
}

ci_inject_line() {
    local target=$1 expected_raw=$2
    local first_line target_dir tmp_file
    first_line="${expected_raw%%$'\n'*}"
    target_dir="$(dirname "$target")"
    mkdir -p "$target_dir"
    tmp_file="$(mktemp "${target_dir}/.chunk-injector.XXXXXX")"

    if [[ -f "$target" ]]; then
        ci_backup_file "$target"
        cat "$target" >"$tmp_file"
        if [[ -s "$tmp_file" ]] && [[ "$(tail -c 1 "$tmp_file" | wc -l)" -eq 0 ]]; then
            printf '\n' >>"$tmp_file"
        fi
    fi
    printf '%s\n' "$first_line" >>"$tmp_file"
    ci_atomic_replace "$tmp_file" "$target"
}

# ── Despacho por linha de config ─────────────────────────────────────────────

ci_check_entry() {
    local id=$1 type=$2 target=$3 selector=$4 expected_raw=$5
    case "$type" in
        json-key)
            ci_check_json_key "$target" "$selector" "$expected_raw"
            ;;
        block)
            ci_check_block "$id" "$target" "$selector" "$expected_raw"
            ;;
        line)
            ci_check_line "$target" "$expected_raw"
            ;;
        *)
            printf 'UNKNOWN_TYPE\n'
            ;;
    esac
}

ci_save_undo_snapshot() {
    local id=$1 target=$2
    mkdir -p "$UNDO_DIR"
    if [[ -f "$target" ]]; then
        cp -p -- "$target" "${UNDO_DIR}/${id}.snapshot"
        rm -f -- "${UNDO_DIR}/${id}.was_created"
    else
        touch "${UNDO_DIR}/${id}.was_created"
        rm -f -- "${UNDO_DIR}/${id}.snapshot"
    fi
}

ci_inject_entry() {
    local id=$1 type=$2 target=$3 selector=$4 expected_raw=$5
    ci_save_undo_snapshot "$id" "$target"
    case "$type" in
        json-key)
            ci_inject_json_key "$target" "$selector" "$expected_raw"
            ;;
        block)
            ci_inject_block "$id" "$target" "$selector" "$expected_raw"
            ;;
        line)
            ci_inject_line "$target" "$expected_raw"
            ;;
        *)
            return 1
            ;;
    esac
}

ci_revert_json_key() {
    local target=$1 selector=$2 expected_raw=${3:-}
    [[ -f "$target" ]] || return 0
    ci_backup_file "$target"
    local target_dir tmp_file
    target_dir="$(dirname "$target")"
    tmp_file="$(mktemp "${target_dir}/.chunk-injector.XXXXXX")"

    if [[ "$selector" == "." || "$selector" == "-" || -z "$selector" ]]; then
        local expected_norm
        expected_norm="$(printf '%s\n' "$expected_raw" | jq -S -c '.' 2>/dev/null || printf '{}')"
        if jq --argjson val "$expected_norm" 'reduce ($val | keys[]) as $k (.; del(.[$k]))' "$target" >"$tmp_file"; then
            ci_atomic_replace "$tmp_file" "$target"
            return 0
        else
            rm -f -- "$tmp_file"
            return 1
        fi
    fi

    if jq "del(${selector})" "$target" >"$tmp_file"; then
        ci_atomic_replace "$tmp_file" "$target"
    else
        rm -f -- "$tmp_file"
        return 1
    fi
}

ci_revert_block() {
    local id=$1 target=$2 selector=$3
    [[ -f "$target" ]] || return 0
    ci_backup_file "$target"
    local begin_mark end_mark target_dir tmp_file
    {
        IFS= read -r begin_mark
        IFS= read -r end_mark
    } < <(ci_block_markers "$id" "$selector")

    target_dir="$(dirname "$target")"
    tmp_file="$(mktemp "${target_dir}/.chunk-injector.XXXXXX")"
    awk -v b="$begin_mark" -v e="$end_mark" '
        $0 == b { inside=1; next }
        $0 == e { inside=0; next }
        !inside { print }
    ' "$target" >"$tmp_file"
    ci_atomic_replace "$tmp_file" "$target"
}

ci_revert_line() {
    local target=$1 expected_raw=$2
    [[ -f "$target" ]] || return 0
    ci_backup_file "$target"
    local first_line target_dir tmp_file
    first_line="${expected_raw%%$'\n'*}"
    target_dir="$(dirname "$target")"
    tmp_file="$(mktemp "${target_dir}/.chunk-injector.XXXXXX")"
    grep -v -F -x "$first_line" "$target" >"$tmp_file" || true
    ci_atomic_replace "$tmp_file" "$target"
}

ci_revert_entry() {
    local id=$1 type=$2 target=$3 selector=$4 expected_raw=$5
    mkdir -p "$UNDO_DIR"
    if [[ -f "${UNDO_DIR}/${id}.was_created" ]]; then
        rm -f -- "$target"
        rm -f -- "${UNDO_DIR}/${id}.was_created"
        return 0
    fi

    if [[ -f "${UNDO_DIR}/${id}.snapshot" ]]; then
        ci_backup_file "$target"
        cp -p -- "${UNDO_DIR}/${id}.snapshot" "$target"
        rm -f -- "${UNDO_DIR}/${id}.snapshot"
        return 0
    fi

    case "$type" in
        json-key)
            ci_revert_json_key "$target" "$selector" "$expected_raw"
            ;;
        block)
            ci_revert_block "$id" "$target" "$selector"
            ;;
        line)
            ci_revert_line "$target" "$expected_raw"
            ;;
        *)
            return 1
            ;;
    esac
}

# Atualiza ou limpa o arquivo de alerta em cache usado pelo Zsh e pelo menu.
ci_update_alert_cache() {
    local -a issues=("$@")
    local alert_dir
    alert_dir="$(dirname "$ALERT_FILE")"

    if ((${#issues[@]} == 0)); then
        rm -f -- "$ALERT_FILE"
        return 0
    fi

    mkdir -p "$alert_dir"
    {
        printf '# Gerado automaticamente por chunk-injector em %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        local item
        for item in "${issues[@]}"; do
            printf '%s\n' "$item"
        done
    } >"$ALERT_FILE"
}

# Habilita o timer systemd --user se disponível.
ci_enable_systemd_timer() {
    local no_systemd=$1
    [[ "$no_systemd" == "1" || "${CHUNK_INJECTOR_NO_SYSTEMD:-0}" == "1" ]] && return 0
    command -v systemctl >/dev/null 2>&1 || return 0

    local unit_dir="$HOME/.config/systemd/user"
    if [[ -f "${unit_dir}/chunk-injector-monitor.timer" ]]; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        systemctl --user enable --now chunk-injector-monitor.timer >/dev/null 2>&1 || true
    fi
}

# Envia notificação desktop (notify-send) quando o monitor detecta problemas.
ci_send_desktop_notification() {
    local no_notify=$1 count=$2 details=$3
    [[ "$no_notify" == "1" || "${CHUNK_INJECTOR_NO_NOTIFY:-0}" == "1" ]] && return 0
    command -v notify-send >/dev/null 2>&1 || return 0

    notify-send \
        -u critical \
        -a "Dotfiles Chunk Injector" \
        -i dialog-warning \
        "⚠️ Chunk Injector: ${count} trecho(s) ausente(s)/divergente(s)" \
        "${details}
Execute 'chunk-injector inject' (ou 'chunks' no dotfiles-menu) para restaurar." >/dev/null 2>&1 || true
}

ci_run() {
    local mode="inject"
    local dry_run=0
    local no_systemd=0
    local no_notify=0
    local only_id=""

    while (($# > 0)); do
        case "$1" in
            inject | --apply)
                mode="inject"
                ;;
            revert | undo | --revert | --undo)
                mode="revert"
                ;;
            doctor | check | --doctor | --check)
                mode="doctor"
                ;;
            monitor | --monitor)
                mode="monitor"
                ;;
            --only)
                shift
                if (($# == 0)); then
                    echo "Erro: --only requer o identificador do chunk." >&2
                    return 2
                fi
                only_id="$1"
                ;;
            help | --help | -h)
                ci_usage
                return 0
                ;;
            --dry-run)
                dry_run=1
                ;;
            --no-systemd)
                no_systemd=1
                ;;
            --no-notify)
                no_notify=1
                ;;
            *)
                echo "Erro: argumento desconhecido '$1'. Use 'chunk-injector help'." >&2
                return 2
                ;;
        esac
        shift
    done

    mkdir -p "$CHUNKS_DIR"

    local -a alert_lines=()
    local notify_details=""

    if [[ "$mode" == "doctor" ]]; then
        printf '%-24s %-10s %-14s %-38s %s\n' "ID" "TIPO" "STATUS" "ALVO" "SELETOR"
        printf '%-24s %-10s %-14s %-38s %s\n' "────────────────────────" "──────────" "──────────────" "──────────────────────────────────────" "───────────────"
    elif [[ "$mode" == "inject" ]]; then
        echo "Chunk Injector → aplicando chunks de (${CHUNKS_DIR}/)"
        [[ "$dry_run" == "1" ]] && echo "  [MODO DRY-RUN: nenhum arquivo será modificado]"
        echo ""
    elif [[ "$mode" == "revert" ]]; then
        echo "Chunk Injector → revertendo chunks de (${CHUNKS_DIR}/)"
        [[ "$dry_run" == "1" ]] && echo "  [MODO DRY-RUN: nenhum arquivo será modificado]"
        echo ""
    fi

    local -a chunk_files=("$CHUNKS_DIR"/*.json)
    if [[ ! -e "${chunk_files[0]}" ]]; then
        [[ "$mode" != "monitor" ]] && echo "  Nenhum chunk (.json) encontrado em ${CHUNKS_DIR}/"
        return 0
    fi

    local chunk_file id type target_raw selector desc expected_raw
    local target short_target status

    for chunk_file in "${chunk_files[@]}"; do
        [[ -f "$chunk_file" ]] || continue

        id="$(jq -r '.id // empty' "$chunk_file" 2>/dev/null)" || {
            [[ "$mode" != "monitor" ]] && echo "  AVISO: JSON inválido em: ${chunk_file}" >&2
            CI_N_ERROR=$((CI_N_ERROR + 1))
            continue
        }
        [[ -z "$id" ]] && id="$(basename "$chunk_file" .json)"

        if [[ ! "$id" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
            [[ "$mode" != "monitor" ]] && echo "  AVISO: id inválido '${id}' em ${chunk_file}" >&2
            CI_N_ERROR=$((CI_N_ERROR + 1))
            continue
        fi

        if [[ -n "$only_id" && "$id" != "$only_id" ]]; then
            continue
        fi

        type="$(jq -r '.type // "block"' "$chunk_file" 2>/dev/null)"
        target_raw="$(jq -r '.target // empty' "$chunk_file" 2>/dev/null)"
        selector="$(jq -r 'if .selector != null and .selector != "" then .selector elif .type == "json-key" then "." else "#" end' "$chunk_file" 2>/dev/null)"
        desc="$(jq -r '.description // .id // ""' "$chunk_file" 2>/dev/null)"

        if [[ -z "$target_raw" ]]; then
            [[ "$mode" != "monitor" ]] && echo "  AVISO: campo 'target' ausente em: ${chunk_file}" >&2
            CI_N_ERROR=$((CI_N_ERROR + 1))
            continue
        fi

        if jq -e 'has("payload")' "$chunk_file" >/dev/null 2>&1; then
            if [[ "$type" == "json-key" ]]; then
                expected_raw="$(jq -c '.payload' "$chunk_file")"
            else
                expected_raw="$(jq -r 'if (.payload | type) == "string" then .payload else (.payload | tostring) end' "$chunk_file")"
            fi
        elif jq -e 'has("file")' "$chunk_file" >/dev/null 2>&1; then
            local file_spec
            file_spec="$(jq -r '.file' "$chunk_file")"
            if ! expected_raw="$(ci_load_source_content "$file_spec")"; then
                [[ "$mode" != "monitor" ]] && echo "  AVISO: arquivo não encontrado para '${id}': ${file_spec}" >&2
                CI_N_ERROR=$((CI_N_ERROR + 1))
                continue
            fi
        else
            [[ "$mode" != "monitor" ]] && echo "  AVISO: 'payload' ou 'file' ausente em: ${chunk_file}" >&2
            CI_N_ERROR=$((CI_N_ERROR + 1))
            continue
        fi

        target="$(ci_expand_path "$target_raw")"
        short_target="$(ci_short_path "$target")"

        if [[ "$mode" == "revert" ]]; then
            if [[ "$dry_run" == "1" ]]; then
                echo "  [DRY-RUN] Reverteria ${id} em ${short_target}"
            else
                if ci_revert_entry "$id" "$type" "$target" "$selector" "$expected_raw"; then
                    CI_N_REVERTED=$((CI_N_REVERTED + 1))
                    echo "  [DESFEITO] ${id} revertido em ${short_target}"
                else
                    CI_N_ERROR=$((CI_N_ERROR + 1))
                    echo "  [ERRO] Falha ao reverter ${id} em ${short_target}" >&2
                fi
            fi
            continue
        fi

        status="$(ci_check_entry "$id" "$type" "$target" "$selector" "$expected_raw")"

        if [[ "$mode" == "doctor" ]]; then
            printf '%-24s %-10s %-14s %-38s %s\n' "$id" "$type" "$status" "$short_target" "$selector"
        fi

        case "$status" in
            OK)
                CI_N_OK=$((CI_N_OK + 1))
                if [[ "$mode" == "inject" ]]; then
                    echo "  [OK] ${id} (${short_target} → ${selector})"
                fi
                ;;
            MISSING | TARGET_MISSING | DRIFT)
                if [[ "$status" == "DRIFT" ]]; then
                    CI_N_DRIFT=$((CI_N_DRIFT + 1))
                else
                    CI_N_MISSING=$((CI_N_MISSING + 1))
                fi

                if [[ "$mode" == "inject" ]]; then
                    if [[ "$dry_run" == "1" ]]; then
                        echo "  [DRY-RUN] Injetaria ${id} (${status}) em ${short_target} (${selector})"
                        alert_lines+=("${id}|${status}|${short_target}|${selector}|${desc:-$id}")
                    else
                        if ci_inject_entry "$id" "$type" "$target" "$selector" "$expected_raw"; then
                            if [[ "$status" == "DRIFT" ]]; then
                                CI_N_UPDATED=$((CI_N_UPDATED + 1))
                                echo "  [ATUALIZADO] ${id} restaurado em ${short_target} (${selector})"
                            else
                                CI_N_INJECTED=$((CI_N_INJECTED + 1))
                                echo "  [INJETADO] ${id} aplicado em ${short_target} (${selector})"
                            fi
                        else
                            CI_N_ERROR=$((CI_N_ERROR + 1))
                            echo "  [ERRO] Falha ao injetar ${id} em ${short_target}" >&2
                            alert_lines+=("${id}|${status}|${short_target}|${selector}|${desc:-$id}")
                        fi
                    fi
                else
                    alert_lines+=("${id}|${status}|${short_target}|${selector}|${desc:-$id}")
                    notify_details+="• ${id} (${status}): ${short_target} [${selector}]"$'\n'
                fi
                ;;
            *)
                CI_N_ERROR=$((CI_N_ERROR + 1))
                if [[ "$mode" != "monitor" ]]; then
                    echo "  [ERRO] ${id}: status=${status} (${short_target})" >&2
                fi
                alert_lines+=("${id}|${status}|${short_target}|${selector}|${desc:-$id}")
                notify_details+="• ${id} (${status}): ${short_target}"$'\n'
                ;;
        esac
    done

    if [[ "$mode" == "revert" ]]; then
        echo ""
        echo "── Chunk Injector ───────────────────────────────"
        echo "  revertidos: ${CI_N_REVERTED}   erros: ${CI_N_ERROR}"
        echo "─────────────────────────────────────────────────"
        ((CI_N_ERROR == 0))
        return $?
    fi

    # Sincroniza o cache de alerta de acordo com o resultado final
    if [[ "$mode" == "inject" && "$dry_run" == "0" ]]; then
        ci_update_alert_cache "${alert_lines[@]}"
        ci_enable_systemd_timer "$no_systemd"
        echo ""
        echo "── Chunk Injector ───────────────────────────────"
        echo "  injetados: ${CI_N_INJECTED}   atualizados: ${CI_N_UPDATED}   já ok: ${CI_N_OK}   erros: ${CI_N_ERROR}"
        echo "─────────────────────────────────────────────────"
        ((CI_N_ERROR == 0))
        return $?
    fi

    if [[ "$mode" == "doctor" ]]; then
        ci_update_alert_cache "${alert_lines[@]}"
        echo ""
        echo "Resumo: ok=${CI_N_OK}  ausentes=${CI_N_MISSING}  divergentes=${CI_N_DRIFT}  erros=${CI_N_ERROR}"
        ((CI_N_MISSING == 0 && CI_N_DRIFT == 0 && CI_N_ERROR == 0))
        return $?
    fi

    if [[ "$mode" == "monitor" ]]; then
        ci_update_alert_cache "${alert_lines[@]}"
        local total_issues=$((CI_N_MISSING + CI_N_DRIFT + CI_N_ERROR))
        if ((total_issues > 0)); then
            ci_send_desktop_notification "$no_notify" "$total_issues" "$notify_details"
        fi
        return 0
    fi
}

ci_run "$@"
