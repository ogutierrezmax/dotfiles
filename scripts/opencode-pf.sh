#!/usr/bin/env bash
# === opencode-pf.sh ===
# CLI de perfis isolados do OpenCode — substituto do `opencode-multi` com
# isolamento REAL (o original tem 3 bugs: XDG_DATA_HOME no pai, --init copiando
# para lugar errado e nenhum tratamento do background service do opencode v2).
#
#   create <nome> [--init] [--with-auth]
#                            Cria perfil. --init espelha ~/.config/opencode sem
#                            runtime (node_modules, package*.json) e sem segredos
#                            de config (cli.json, service.json). --init e
#                            --with-auth também copiam as CREDENCIAIS do perfil
#                            padrão (tabela 'credential' do SQLite do opencode v2
#                            + auth.json legado) — opt-in explícito.
#   list                     Lista perfis e status (config/auth)
#   show <nome>              Detalhes de um perfil
#   run <nome> [-- args]     Roda opencode ISOLADO por perfil:
#                              - OPENCODE_CONFIG_DIR → config do perfil
#                              - XDG_DATA_HOME      → data DO PERFIL (não o pai)
#                              - --standalone       → servidor privado, fora do
#                                background service compartilhado do opencode v2
#   clone <src> <dst>        Copia um perfil (sem auth.json/banco de sessões)
#   remove <nome> [--yes]    Remove perfil e seus dados (com confirmação)
#   doctor                   Diagnóstico de perfis e do ambiente
#
# SECURITY NOTE (guardrails para humanos e agentes de IA):
#   - Credenciais só são copiadas com --init/--with-auth (opt-in explícito do
#     usuário). Sem esses flags, este script NUNCA lê/escreve/versiona segredos
#     (auth.json, cli.json, service.json) nem runtime (node_modules, package*.json).
#   - `remove` apaga diretórios de perfil → valida o nome (regex) e exige
#     confirmação (ou --yes explícito).
#   - `clone` não propaga credenciais nem o banco de sessões (login novo via
#     /connect no perfil clonado).
#   - `run` executa com --standalone; use `run <nome> --no-jail` para abrir o
#     binário direto, sem o sandbox ai-jail.
set -euo pipefail

CONFIG_ROOT="$HOME/.config/opencode-multi/profiles"
DATA_ROOT="$HOME/.local/share/opencode-multi/profiles"
DEFAULT_CONFIG="$HOME/.config/opencode"
DEFAULT_DATA="$HOME/.local/share/opencode"
OPENCODE_BIN="$HOME/.opencode/bin/opencode"

# Comando usado pelo `run` (override via OPENCODE_PF_OPENCODE_CMD).
# Padrão: `opencode` do PATH (wrapper ~/bin/opencode aplica o ai-jail).
OPENCODE_CMD="${OPENCODE_PF_OPENCODE_CMD:-opencode}"

# ── utilitários ──────────────────────────────────────────────────────────────

pf_validate_name() {
    local name=$1
    if [[ -z "$name" ]] || [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]]; then
        echo "Erro: nome de perfil inválido: '${name}' (use [A-Za-z0-9_-], máx. 64, sem começar com - ou _)." >&2
        return 1
    fi
}

# Escreve o opencode.json scaffold (somente $schema) se ainda não existir.
pf_scaffold_config() {
    local dir=$1
    local file="$dir/opencode.json"
    if [[ ! -f "$file" ]]; then
        cat > "$file" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF
    fi
}

# Copia entradas de topo de $src para $dst, excluindo segredos/runtime.
pf_copy_config() {
    local src=$1 dst=$2 entry base
    mkdir -p "$dst"
    while IFS= read -r -d '' entry; do
        base="$(basename "$entry")"
        case "$base" in
            node_modules|.git|.gitignore|package.json|package-lock.json|cli.json|service.json)
                continue ;;
        esac
        cp -a "$entry" "$dst/"
    done < <(find "$src" -mindepth 1 -maxdepth 1 -print0 2>/dev/null || true)
}

# Copia SOMENTE as credenciais do perfil padrão (~/.local/share/opencode) para
# o data dir do perfil. No opencode v2, auth vive na tabela `credential` do
# SQLite (opencode.db) — não existe export/import no CLI — então o perfil
# inicializa o próprio DB com o schema real (migrações do opencode, via um
# `auth list --standalone` rápido e sem rede) e recebe só as linhas da tabela
# `credential` (SEM sessões/storage de mensagens). auth.json legado (V1) também
# é copiado, se presente. Não é fatal se falhar (apenas avisa).
# Opt-in: chamada apenas por `create --init` / `create --with-auth`.
pf_copy_credentials() {
    local dst_data=$1 cfg=$2 name=$3
    local dst_oc="$1/opencode"
    local src_db="$DEFAULT_DATA/opencode.db" src_auth="$DEFAULT_DATA/auth.json"
    local init_cmd="$OPENCODE_CMD" out copied=0

    if [[ -x "$OPENCODE_BIN" ]]; then
        init_cmd="$OPENCODE_BIN"
    fi

    if [[ -f "$src_db" ]] && command -v python3 >/dev/null 2>&1; then
        mkdir -p "$dst_oc"
        # inicializa o DB do perfil com o schema real (migrações do opencode),
        # só se ainda não existir; servidor standalone privado, sem rede.
        if ! [[ -f "$dst_oc/opencode.db" ]] && command -v "$init_cmd" >/dev/null 2>&1; then
            (export OPENCODE_CONFIG_DIR="$cfg" XDG_DATA_HOME="$dst_data" OPENCODE_PROFILE="$name"
             "$init_cmd" auth list --standalone --format json >/dev/null 2>&1) || true
        fi
        if [[ -f "$dst_oc/opencode.db" ]]; then
            out=$(python3 - "$src_db" "$dst_oc/opencode.db" 2>&1 <<'PY' || true
import sqlite3, sys
try:
    src, dst = sys.argv[1], sys.argv[2]
    s = sqlite3.connect(f"file:{src}?mode=ro", uri=True)
    try:
        n = s.execute("SELECT COUNT(*) FROM credential").fetchone()[0]
        if n == 0:
            print("EMPTY")
            sys.exit(0)
        d = sqlite3.connect(dst)
        try:
            cols = [r[1] for r in s.execute("PRAGMA table_info(credential)")]
            rows = s.execute("SELECT * FROM credential").fetchall()
            q = ", ".join("?" * len(cols))
            d.executemany(
                f"INSERT OR REPLACE INTO credential ({', '.join(cols)}) VALUES ({q})",
                rows,
            )
            d.commit()
            print(f"OK {len(rows)}")
        finally:
            d.close()
    finally:
        s.close()
except Exception as e:
    print(f"ERROR {e}")
PY
            )
        fi
        case "$out" in
            OK*)
                chmod 600 "$dst_oc/opencode.db" 2>/dev/null || true
                copied=1
                echo "✓ Credenciais copiadas do perfil padrão (${out#OK } no SQLite) → $dst_oc/opencode.db"
                ;;
            EMPTY)
                echo "  Aviso: perfil padrão sem credenciais (tabela 'credential' vazia) — nada copiado." >&2
                ;;
            ERROR*)
                echo "  Aviso: falha ao copiar credenciais do SQLite padrão (${out#ERROR })." >&2
                ;;
            *)
                echo "  Aviso: não foi possível inicializar o DB do perfil para copiar credenciais." >&2
                ;;
        esac
    fi

    if [[ -f "$src_auth" ]]; then
        mkdir -p "$dst_oc"
        cp "$src_auth" "$dst_oc/auth.json"
        chmod 600 "$dst_oc/auth.json"
        copied=1
        echo "✓ auth.json (legado V1) copiado do perfil padrão."
    fi

    if ((!copied)); then
        echo "  Aviso: nenhuma credencial encontrada no perfil padrão (sem opencode.db nem auth.json)." >&2
    fi
}

# Verifica se um perfil tem credenciais: auth.json legado OU tabela `credential`
# preenchida no opencode.db (v2). $1 = dir data/opencode do perfil.
pf_has_credentials() {
    local oc_dir=$1
    [[ -f "$oc_dir/auth.json" ]] && return 0
    [[ -f "$oc_dir/opencode.db" ]] || return 1
    command -v python3 >/dev/null 2>&1 || return 1
    python3 - "$oc_dir/opencode.db" <<'PY' >/dev/null 2>&1
import sqlite3, sys
try:
    c = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
    n = c.execute("SELECT COUNT(*) FROM credential").fetchone()[0]
    sys.exit(0 if n > 0 else 1)
finally:
    c.close()
PY
}

# ── comandos ─────────────────────────────────────────────────────────────────

pf_create() {
    local name=$1 init=${2:-0} with_auth=${3:-0}
    local cfg data
    pf_validate_name "$name" || return 1
    cfg="$CONFIG_ROOT/$name"
    data="$DATA_ROOT/$name"
    if [[ -e "$cfg" || -e "$data" ]]; then
        echo "Erro: perfil '$name' já existe." >&2
        return 1
    fi
    mkdir -p "$cfg/plugins" "$cfg/commands" "$cfg/agents" "$cfg/modes" "$data"
    pf_scaffold_config "$cfg"
    echo "✓ Perfil '$name' criado."
    echo "  config: $cfg"
    echo "  data:   $data"
    if ((init)); then
        if [[ ! -d "$DEFAULT_CONFIG" ]]; then
            echo "  Aviso: não existe config padrão em $DEFAULT_CONFIG — perfil criado em branco." >&2
        else
            pf_copy_config "$DEFAULT_CONFIG" "$cfg"
            echo "✓ Config espelhada de $DEFAULT_CONFIG (sem segredos de config/runtime)."
        fi
    fi
    if ((init || with_auth)); then
        pf_copy_credentials "$data" "$cfg" "$name"
    fi
    echo ""
    echo "Para usar:            opencode-pf run $name"
    if ((init || with_auth)); then
        echo "Credenciais:          copiadas do perfil padrão (veja mensagens acima)."
    else
        echo "Para autenticar:      dentro do opencode, use /connect (login a partir do zero)."
    fi
}

pf_list() {
    local -a names=()
    local d name config auth status
    for d in "$CONFIG_ROOT"/*/; do
        [[ -d "$d" ]] && names+=("$(basename "$d")")
    done
    if ((${#names[@]} == 0)); then
        echo "Nenhum perfil em $CONFIG_ROOT"
        return 0
    fi
    printf '%-16s %-7s %-5s %s\n' NAME CONFIG AUTH STATUS
    for name in "${names[@]}"; do
        config="no"
        if [[ -f "$CONFIG_ROOT/$name/opencode.json" || -f "$CONFIG_ROOT/$name/opencode.jsonc" ]]; then
            config="yes"
        fi
        auth="no"
        if pf_has_credentials "$DATA_ROOT/$name/opencode"; then
            auth="yes"
        fi
        if [[ "$auth" == "yes" ]]; then
            status="healthy"
        elif [[ "$config" == "yes" ]]; then
            status="needs-auth"
        else
            status="missing"
        fi
        printf '%-16s %-7s %-5s %s\n' "$name" "$config" "$auth" "$status"
    done
}

pf_show() {
    local name=$1 cfg data
    pf_validate_name "$name" || return 1
    cfg="$CONFIG_ROOT/$name"
    data="$DATA_ROOT/$name"
    echo "Perfil: $name"
    echo "  config: $cfg  ($([[ -d "$cfg" ]] && echo "existe" || echo "NÃO existe"))"
    echo "  data:   $data ($([[ -d "$data" ]] && echo "existe" || echo "NÃO existe"))"
    if pf_has_credentials "$data/opencode"; then
        echo "  auth:   configurado (SQLite 'credential' e/ou auth.json legado em $data/opencode)"
    else
        echo "  auth:   não configurado (rode 'opencode-pf run $name' e use /connect, ou crie com --init/--with-auth)"
    fi
    if [[ -d "$cfg" ]]; then
        echo "  conteúdo de config/:"
        # shellcheck disable=SC2012 # ls -1A: listagem legível para o usuário, inclui ocultos
        ls -1A "$cfg" | sed 's/^/    /'
    fi
    if [[ -e "$data" ]]; then
        echo "  tamanho data: $(du -sh "$data" 2>/dev/null | cut -f1)"
    fi
}

pf_run() {
    local name=$1 cfg data no_jail=0 bin
    shift
    pf_validate_name "$name" || return 1
    if [[ "${1:-}" == "--no-jail" ]]; then
        no_jail=1
        shift
    fi
    if [[ "${1:-}" == "--" ]]; then
        shift
    fi
    cfg="$CONFIG_ROOT/$name"
    data="$DATA_ROOT/$name"
    if [[ ! -d "$cfg" ]]; then
        echo "Erro: perfil '$name' não existe. Crie com: opencode-pf create $name" >&2
        return 1
    fi
    mkdir -p "$data"
    export OPENCODE_CONFIG_DIR="$cfg"
    export XDG_DATA_HOME="$data"
    export OPENCODE_PROFILE="$name"
    bin="$OPENCODE_CMD"
    if ((no_jail)); then
        if [[ -x "$OPENCODE_BIN" ]]; then
            bin="$OPENCODE_BIN"
        else
            echo "Erro: binário direto não encontrado em $OPENCODE_BIN (--no-jail)." >&2
            return 1
        fi
    fi
    echo "opencode-pf: perfil '$name' — servidor privado (--standalone)"
    echo "  config: $cfg"
    echo "  data:   $data/opencode (auth.json/sessões deste perfil)"
    exec "$bin" "$@" --standalone
}

pf_clone() {
    local src=$1 dst=$2 entry
    pf_validate_name "$src" || return 1
    pf_validate_name "$dst" || return 1
    if [[ ! -d "$CONFIG_ROOT/$src" ]]; then
        echo "Erro: perfil de origem '$src' não existe." >&2
        return 1
    fi
    if [[ -e "$CONFIG_ROOT/$dst" || -e "$DATA_ROOT/$dst" ]]; then
        echo "Erro: perfil de destino '$dst' já existe." >&2
        return 1
    fi
    mkdir -p "$CONFIG_ROOT/$dst" "$DATA_ROOT/$dst"
    pf_copy_config "$CONFIG_ROOT/$src" "$CONFIG_ROOT/$dst"
    # copia dados de estado, SEM auth.json e SEM banco de sessões
    # (login novo via /connect no perfil clonado).
    mkdir -p "$DATA_ROOT/$dst/opencode"
    while IFS= read -r -d '' entry; do
        case "$(basename "$entry")" in
            auth.json|*.db|*.db-wal|*.db-shm|log) continue ;;
        esac
        cp -a "$entry" "$DATA_ROOT/$dst/opencode/"
    done < <(find "$DATA_ROOT/$src/opencode" -mindepth 1 -maxdepth 1 -print0 2>/dev/null || true)
    echo "✓ Perfil '$dst' clonado de '$src' (config sem segredos; auth novo via /connect)."
}

pf_remove() {
    local name=$1 yes=${2:-0} ans
    pf_validate_name "$name" || return 1
    if [[ ! -e "$CONFIG_ROOT/$name" && ! -e "$DATA_ROOT/$name" ]]; then
        echo "Erro: perfil '$name' não existe." >&2
        return 1
    fi
    if ((!yes)); then
        read -r -p "Remover perfil '$name' e TODOS os seus dados? (config: $CONFIG_ROOT/$name, data: $DATA_ROOT/$name) [y/N] " ans || true
        case "${ans,,}" in
            y|yes|s|sim) ;;
            *) echo "Remoção cancelada."; return 0 ;;
        esac
    fi
    rm -rf -- "${CONFIG_ROOT:?}/$name" "${DATA_ROOT:?}/$name"
    echo "✓ Perfil '$name' removido."
}

pf_doctor() {
    echo "opencode-pf doctor"
    echo ""
    if command -v "$OPENCODE_CMD" >/dev/null 2>&1 || [[ -x "$OPENCODE_CMD" ]]; then
        echo "✓ opencode: $OPENCODE_CMD"
    else
        echo "✗ comando opencode não encontrado: $OPENCODE_CMD (configure OPENCODE_PF_OPENCODE_CMD)"
    fi
    if [[ -d "$CONFIG_ROOT" ]]; then
        echo "✓ config root: $CONFIG_ROOT"
    else
        echo "✗ config root ausente: $CONFIG_ROOT (crie perfis com 'opencode-pf create <nome>')"
    fi
    if [[ -d "$DATA_ROOT" ]]; then
        echo "✓ data root:  $DATA_ROOT"
    else
        echo "✗ data root ausente: $DATA_ROOT"
    fi
    if pgrep -f "opencode serve --service" >/dev/null 2>&1; then
        echo "⚠ background service compartilhado ATIVO — use 'opencode-pf run <nome>' (--standalone) para isolar de verdade."
    fi
    if [[ -d "$DATA_ROOT/opencode" ]]; then
        echo "⚠ resíduo de execução antiga (env quebrado do opencode-multi): $DATA_ROOT/opencode — não é usado por perfis; pode remover."
    fi
    echo ""
    echo "Perfis:"
    pf_list
}

pf_usage() {
    cat <<'EOF'
Uso: opencode-pf <comando> [args...]

Comandos:
  create <nome> [--init] [--with-auth]
                      Cria perfil (--init: espelha ~/.config/opencode sem segredos
                      de config/runtime; --init/--with-auth: copiam também as
                      credenciais do perfil padrão — SQLite 'credential' + auth.json legado)
  list                      Lista perfis e status (config/auth)
  show <nome>               Detalhes de um perfil
  run <nome> [-- args]      Roda opencode isolado (config+auth+dados+servidor privado)
                            run <nome> --no-jail  usa o binário direto (sem ai-jail)
  clone <src> <dst>         Copia um perfil (sem auth.json/sessões)
  remove <nome> [--yes]     Remove perfil e seus dados
  doctor                    Diagnóstico de perfis/ambiente

Variáveis de ambiente:
  OPENCODE_PF_OPENCODE_CMD  comando opencode usado pelo run (padrão: opencode do PATH)
EOF
}

main() {
    local cmd=${1:-}
    if [[ -z "$cmd" ]]; then
        pf_usage
        return 0
    fi
    shift
    case "$cmd" in
        create)
            local init=0 with_auth=0
            local -a rest=()
            local a
            for a in "$@"; do
                case "$a" in
                    --init) init=1 ;;
                    --with-auth) with_auth=1 ;;
                    *) rest+=("$a") ;;
                esac
            done
            if ((${#rest[@]} != 1)); then
                echo "uso: opencode-pf create <nome> [--init] [--with-auth]" >&2
                return 1
            fi
            pf_create "${rest[0]}" "$init" "$with_auth"
            ;;
        list)
            pf_list
            ;;
        show)
            if (($# != 1)); then
                echo "uso: opencode-pf show <nome>" >&2
                return 1
            fi
            pf_show "$1"
            ;;
        run)
            if (($# < 1)); then
                echo "uso: opencode-pf run <nome> [-- args]" >&2
                return 1
            fi
            pf_run "$@"
            ;;
        clone)
            if (($# != 2)); then
                echo "uso: opencode-pf clone <src> <dst>" >&2
                return 1
            fi
            pf_clone "$1" "$2"
            ;;
        remove)
            local yes=0
            local -a rest=()
            local a
            for a in "$@"; do
                if [[ "$a" == "--yes" ]]; then
                    yes=1
                else
                    rest+=("$a")
                fi
            done
            if ((${#rest[@]} != 1)); then
                echo "uso: opencode-pf remove <nome> [--yes]" >&2
                return 1
            fi
            pf_remove "${rest[0]}" "$yes"
            ;;
        doctor)
            pf_doctor
            ;;
        -h|--help|help)
            pf_usage
            ;;
        *)
            echo "Erro: comando desconhecido: $cmd" >&2
            pf_usage >&2
            return 1
            ;;
    esac
}

main "$@"