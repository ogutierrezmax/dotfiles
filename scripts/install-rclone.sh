#!/usr/bin/env bash
# =============================================================================
# install-rclone.sh — Instalador seguro do rclone upstream (.deb oficial)
# -----------------------------------------------------------------------------
# Por que não usar `apt install rclone` no Debian 13 (trixie)?
#   O pacote `rclone` do Debian trixie é a v1.60.1 (de 2022), com bugs no
#   backend do Google Drive e bisync experimental. Este script baixa o .deb
#   oficial upstream (https://downloads.rclone.org), valida o checksum SHA-256
#   contra o arquivo SHA256SUMS oficial e garante versão >= 1.70.
#
# SECURITY NOTE: This script is tracked by Git. DO NOT place credentials,
# OAuth secrets, or tokens here.
# NEVER: Do not replace the verified .deb download flow with `curl | sudo bash`.
# =============================================================================

set -euo pipefail

MIN_MAJOR=1
MIN_MINOR=70
DRY_RUN=0
CHECK_ONLY=0
FORCE=0

usage() {
    cat <<'EOF'
Uso: ./scripts/install-rclone.sh [opções]

Opções:
  --check      Apenas verifica se o rclone está instalado e se a versão é >= 1.70
  --dry-run    Simula o download e exibe o que seria executado sem alterar o sistema
  --force      Reinstala/atualiza mesmo que uma versão >= 1.70 já esteja presente
  -h, --help   Mostra esta ajuda
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            CHECK_ONLY=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --force)
            FORCE=1
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

get_installed_version() {
    if ! command -v rclone >/dev/null 2>&1; then
        return 1
    fi
    rclone version 2>/dev/null | head -n 1 | awk '{print $2}' | sed 's/^v//'
}

version_ge_min() {
    local ver=$1
    local major minor
    major="${ver%%.*}"
    minor="${ver#*.}"
    minor="${minor%%.*}"
    if [[ ! "$major" =~ ^[0-9]+$ || ! "$minor" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    if (( major > MIN_MAJOR )) || (( major == MIN_MAJOR && minor >= MIN_MINOR )); then
        return 0
    fi
    return 1
}

detect_deb_arch() {
    if command -v dpkg >/dev/null 2>&1; then
        dpkg --print-architecture
        return 0
    fi
    case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "armhf" ;;
        *)
            echo "Erro: arquitetura não suportada: $(uname -m)" >&2
            return 1
            ;;
    esac
}

CURRENT_VER=""
if CURRENT_VER="$(get_installed_version)"; then
    if version_ge_min "$CURRENT_VER"; then
        echo "✅ rclone v${CURRENT_VER} já instalado (>= ${MIN_MAJOR}.${MIN_MINOR})."
        if (( CHECK_ONLY == 1 || FORCE == 0 )); then
            exit 0
        fi
        echo ">> --force especificado: prosseguindo com atualização/reinstalação."
    else
        echo "⚠️  rclone v${CURRENT_VER} instalado (provavelmente do apt), mas é inferior a ${MIN_MAJOR}.${MIN_MINOR}."
        if (( CHECK_ONLY == 1 )); then
            exit 1
        fi
    fi
else
    echo "ℹ️  rclone não encontrado no sistema."
    if (( CHECK_ONLY == 1 )); then
        exit 1
    fi
fi

ARCH="$(detect_deb_arch)"
echo ">> Consultando versão estável mais recente em downloads.rclone.org..."
LATEST_TAG="$(curl -fsSL --retry 3 https://downloads.rclone.org/version.txt | awk '{print $2}' | tr -d '\r\n')"

if [[ ! "$LATEST_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Erro: tag de versão inválida retornada pelo servidor: '${LATEST_TAG}'" >&2
    exit 1
fi

DEB_FILENAME="rclone-${LATEST_TAG}-linux-${ARCH}.deb"
BASE_URL="https://downloads.rclone.org/${LATEST_TAG}"
DEB_URL="${BASE_URL}/${DEB_FILENAME}"
SUMS_URL="${BASE_URL}/SHA256SUMS"

if (( DRY_RUN == 1 )); then
    echo "[dry-run] Baixaria: ${DEB_URL}"
    echo "[dry-run] Baixaria: ${SUMS_URL}"
    echo "[dry-run] Validaria SHA-256 de ${DEB_FILENAME}"
    echo "[dry-run] Executaria: sudo DEBIAN_FRONTEND=noninteractive apt install -y <tmp>/${DEB_FILENAME}"
    exit 0
fi

TMP_DIR="$(mktemp -d -t rclone-setup.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo ">> Baixando ${DEB_FILENAME}..."
curl -fL --retry 3 "$DEB_URL" -o "${TMP_DIR}/${DEB_FILENAME}"

echo ">> Baixando SHA256SUMS..."
curl -fsSL --retry 3 "$SUMS_URL" -o "${TMP_DIR}/SHA256SUMS"

echo ">> Verificando integridade SHA-256..."
(
    cd "$TMP_DIR"
    grep -E "  ${DEB_FILENAME}$" SHA256SUMS > SHA256SUMS.target
    if [[ ! -s SHA256SUMS.target ]]; then
        echo "Erro: entrada para ${DEB_FILENAME} não encontrada no SHA256SUMS." >&2
        exit 1
    fi
    sha256sum --check --strict SHA256SUMS.target
)

# DANGER ZONE: Elevates privileges via sudo apt to install the verified upstream .deb package.
echo ">> Instalando pacote verificado via apt..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y "${TMP_DIR}/${DEB_FILENAME}"

NEW_VER="$(get_installed_version || true)"
if [[ -z "$NEW_VER" ]] || ! version_ge_min "$NEW_VER"; then
    echo "Erro: pós-instalação falhou na validação de versão (atual: '${NEW_VER:-nenhuma}')." >&2
    exit 1
fi

echo "✅ rclone v${NEW_VER} instalado e validado com sucesso!"
