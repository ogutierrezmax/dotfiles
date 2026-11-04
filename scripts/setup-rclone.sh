#!/usr/bin/env bash
# =============================================================================
# setup-rclone.sh — Bootstrap idempotente do Google Drive (rclone + systemd)
# -----------------------------------------------------------------------------
# Fluxo em máquina nova:
#   1. Garante que o rclone upstream (>= 1.70) está instalado
#   2. Cria os symlinks dos 3 units (mount, backup e timer) com backup em .bkp/
#   3. Materializa ~/.config/rclone/rclone.conf (chmod 600) a partir de config/rclone.conf.example
#   4. Solicita client_secret (se vazio) e dispara OAuth (`rclone config reconnect gdrive:`)
#   5. Valida com `rclone about gdrive:` e habilita o mount + o timer no systemd --user
#
# SECURITY NOTE: This script handles sensitive user input (client_secret) and
# writes to ~/.config/rclone/rclone.conf with 600 permissions. NEVER echo secrets
# to stdout or pass them as CLI arguments visible in `ps`.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dotfiles-lib.sh
source "${SCRIPT_DIR}/dotfiles-lib.sh"

REPO_ROOT="$(dotfiles_repo_root)"
TEMPLATE_CONF="${REPO_ROOT}/config/rclone.conf.example"
TARGET_CONF="${HOME}/.config/rclone/rclone.conf"
UNIT_RELS=(
    ".config/systemd/user/rclone-gdrive.service"
    ".config/systemd/user/rclone-backup.service"
    ".config/systemd/user/rclone-backup.timer"
)
SERVICE_NAME="rclone-gdrive.service"
TIMER_NAME="rclone-backup.timer"

DRY_RUN=0
STATUS_ONLY=0
RECONNECT=0

usage() {
    cat <<'EOF'
Uso: ./scripts/setup-rclone.sh [opções]

Opções:
  --status      Exibe diagnóstico completo (rclone, symlink, config 600 e systemd unit)
  --reconnect   Força renovação do token OAuth (`rclone config reconnect gdrive:`)
  --dry-run     Mostra o que seria feito sem modificar arquivos nem serviços
  -h, --help    Mostra esta ajuda
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --status)
            STATUS_ONLY=1
            shift
            ;;
        --reconnect)
            RECONNECT=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Erro: opção desconhecida: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

detect_os() {
    case "$(uname -s)" in
        Linux*)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*) echo "macos" ;;
        *)       echo "unknown" ;;
    esac
}

get_file_perms() {
    local f=$1
    if [[ "$(detect_os)" == "macos" ]]; then
        stat -f %Lp "$f" 2>/dev/null || echo "unknown"
    else
        stat -c %a "$f" 2>/dev/null || echo "unknown"
    fi
}

conf_has_value() {
    local key=$1 value
    [[ -f "$TARGET_CONF" ]] || return 1
    value="$(sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$TARGET_CONF" | head -n1)"
    [[ -n "${value//[[:space:]]/}" ]] || return 1
    # Placeholder do template não conta como preenchido.
    [[ "$value" != COLE_SEU_* ]] || return 1
}

show_status() {
    echo "== Diagnóstico rclone Google Drive =="
    echo "OS detectado       : $(detect_os)"
    if "${SCRIPT_DIR}/install-rclone.sh" --check >/dev/null 2>&1; then
        echo "Binário rclone     : ✅ $(rclone version | head -n 1)"
    else
        echo "Binário rclone     : ❌ ausente ou desatualizado (< 1.70)"
    fi
    echo "Symlink unit mount : $(dotfiles_status_for_file "${UNIT_RELS[0]}")"
    echo "Symlink backup     : $(dotfiles_status_for_file "${UNIT_RELS[1]}")"
    echo "Symlink timer      : $(dotfiles_status_for_file "${UNIT_RELS[2]}")"
    if [[ -f "$TARGET_CONF" ]]; then
        local perms
        perms="$(get_file_perms "$TARGET_CONF")"
        echo "Arquivo rclone.conf: ✅ presente (permissão: ${perms})"
        if conf_has_value "client_secret"; then
            echo "  client_secret   : ✅ preenchido"
        else
            echo "  client_secret   : ⚠️  vazio"
        fi
        if conf_has_value "token"; then
            echo "  token OAuth      : ✅ preenchido"
        else
            echo "  token OAuth      : ⚠️  vazio"
        fi
    else
        echo "Arquivo rclone.conf: ❌ ausente (${TARGET_CONF})"
    fi
    if command -v systemctl >/dev/null 2>&1; then
        local active enabled
        active="$(systemctl --user is-active "$SERVICE_NAME" 2>/dev/null || true)"
        enabled="$(systemctl --user is-enabled "$SERVICE_NAME" 2>/dev/null || true)"
        echo "Serviço mount      : ${active:-unknown} (${enabled:-unknown})"
        active="$(systemctl --user is-active "$TIMER_NAME" 2>/dev/null || true)"
        enabled="$(systemctl --user is-enabled "$TIMER_NAME" 2>/dev/null || true)"
        echo "Timer backup       : ${active:-unknown} (${enabled:-unknown})"
    fi
}

if (( STATUS_ONLY == 1 )); then
    show_status
    exit 0
fi

# 1. Verificar binário rclone >= 1.70
if ! "${SCRIPT_DIR}/install-rclone.sh" --check; then
    echo ">> Instalando/atualizando rclone upstream..."
    if (( DRY_RUN == 1 )); then
        "${SCRIPT_DIR}/install-rclone.sh" --dry-run
    else
        "${SCRIPT_DIR}/install-rclone.sh"
    fi
fi

# 2. Garantir symlinks dos units systemd usando dotfiles-lib.sh
for unit_rel in "${UNIT_RELS[@]}"; do
    UNIT_STATE="$(dotfiles_status_for_file "$unit_rel")"
    case "$UNIT_STATE" in
        installed)
            echo "✅ Symlink do unit já instalado: ~/${unit_rel}"
            ;;
        blocking_file|wrong_target|not_installed)
            if (( DRY_RUN == 1 )); then
                echo "[dry-run] Criaria backup (se necessário) e linkaria ~/${unit_rel}"
            else
                if [[ "$UNIT_STATE" == "blocking_file" ]]; then
                    dotfiles_move_blocking_dest_to_bkp "$unit_rel"
                elif [[ "$UNIT_STATE" == "wrong_target" ]]; then
                    rm -f "$(dotfiles_dest_for_file "$unit_rel")"
                fi
                dotfiles_link_one "$unit_rel"
            fi
            ;;
        *)
            echo "Erro: estado inesperado para ${unit_rel}: ${UNIT_STATE}" >&2
            exit 1
            ;;
    esac
done

# 3. Materializar ~/.config/rclone/rclone.conf (chmod 600) se não existir
if [[ ! -f "$TARGET_CONF" ]]; then
    if (( DRY_RUN == 1 )); then
        echo "[dry-run] Copiaria ${TEMPLATE_CONF} → ${TARGET_CONF} (chmod 600)"
    else
        mkdir -p "$(dirname "$TARGET_CONF")"
        umask 077
        grep -v '^#' "$TEMPLATE_CONF" | sed '/^[[:space:]]*$/N;/^\n$/D' > "$TARGET_CONF"
        chmod 600 "$TARGET_CONF"
        echo "✅ Criado ${TARGET_CONF} (permissão 600) a partir do template."
    fi
else
    if (( DRY_RUN == 0 )); then
        chmod 600 "$TARGET_CONF"
    fi
    echo "✅ ${TARGET_CONF} já existe (permissão 600 garantida)."
fi

if (( DRY_RUN == 1 )); then
    echo "[dry-run] Verificaria client_secret/token e habilitaria ${SERVICE_NAME} + ${TIMER_NAME}."
    exit 0
fi

# 4. Preencher client_secret se estiver vazio
if ! conf_has_value "client_secret"; then
    echo ""
    echo "🔑 O campo 'client_secret' está vazio em ${TARGET_CONF}."
    read -r -s -p "Cole o Client Secret OAuth do Google Cloud (entrada oculta): " input_secret
    echo ""
    if [[ -z "$input_secret" ]]; then
        echo "Erro: client_secret não pode ser vazio." >&2
        exit 1
    fi
    python3 - "$TARGET_CONF" "$input_secret" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
secret = sys.argv[2]
lines = p.read_text(encoding="utf-8").splitlines()
out = [f"client_secret = {secret}" if l.strip().startswith("client_secret") else l for l in lines]
p.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
    chmod 600 "$TARGET_CONF"
    echo "✅ client_secret salvo com segurança em ${TARGET_CONF}."
fi

# 5. Autenticar OAuth se token estiver vazio ou --reconnect solicitado
if (( RECONNECT == 1 )) || ! conf_has_value "token"; then
    echo ">> Iniciando autorização OAuth no navegador (rclone config reconnect gdrive:)..."
    rclone config reconnect gdrive: --config "$TARGET_CONF"
    chmod 600 "$TARGET_CONF"
fi

# 6. Validar acesso ao remote e habilitar serviço systemd
echo ">> Validando conexão com Google Drive (rclone about gdrive:)..."
rclone about gdrive: --config "$TARGET_CONF"

echo ">> Recarregando systemd --user e habilitando ${SERVICE_NAME} + ${TIMER_NAME}..."
systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE_NAME"
systemctl --user enable --now "$TIMER_NAME"
systemctl --user status "$SERVICE_NAME" --no-pager | head -n 12
echo ""
echo "Timer do backup:"
systemctl --user list-timers "$TIMER_NAME" --no-pager | head -n 3
