#!/usr/bin/env bash
# === opencode-pf.sh ===
# CLI de perfis isolados do OpenCode — substituto do `opencode-multi` com
# isolamento REAL (o original tem 3 bugs: XDG_DATA_HOME no pai, --init copiando
# para lugar errado e nenhum tratamento do background service do opencode v2).
#
#   create <nome> [--init]   Cria perfil (--init espelha ~/.config/opencode SEM
#                            copiar segredos: cli.json, service.json, auth.json,
#                            node_modules, package*.json)
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
#   - Este script NUNCA lê/escreve/versiona segredos (auth.json, cli.json,
#     service.json) nem runtime (node_modules, package*.json).
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
            echo "✓ Config espelhada de $DEFAULT_CONFIG (sem segredos/runtime)."
        fi
    fi
    if ((with_auth)); then
        if [[ -f "$DEFAULT_DATA/auth.json" ]]; then
            mkdir -p "$data/opencode"
            cp "$DEFAULT_DATA/auth.json" "$data/opencode/auth.json"
            chmod 600 "$data/opencode/auth.json"
            echo "✓ auth.json copiado de $DEFAULT_DATA/auth.json (mesmas credenciais)."
        else
            echo "  Aviso: $DEFAULT_DATA/auth.json não existe — nada copiado." >&2
        fi
    fi
    echo ""
    echo "Para usar:            opencode-pf run $name"
    echo "Para autenticar:      dentro do opencode, use /connect (login a partir do zero)."
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
        [[ -f "$DATA_ROOT/$name/opencode/auth.json" ]] && auth="yes"
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
    if [[ -f "$data/opencode/auth.json" ]]; then
        echo "  auth:   configurado em $data/opencode/auth.json"
    else
        echo "  auth:   não configurado (rode 'opencode-pf run $name' e use /connect)"
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
    exec "$bin" --standalone "$@"
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
                      Cria perfil (--init: espelha ~/.config/opencode sem segredos;
                      --with-auth: copia também auth.json do perfil padrão)
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