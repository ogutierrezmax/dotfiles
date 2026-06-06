#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Dotfiles Bootstrap Script
# Cross-platform: Linux, macOS, WSL
# Idempotente: seguro de re-executar múltiplas vezes
# Gerado pela skill dotfiles-manager
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURAÇÃO
# =============================================================================

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false
VERBOSE=false
SKIP_SECRETS_CHECK=false

# =============================================================================
# CORES E OUTPUT
# =============================================================================

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_dry()     { echo -e "${CYAN}[DRY]${RESET}   $*"; }
log_section() { echo -e "\n${BOLD}══════════════════════════════════════${RESET}"; \
                echo -e "${BOLD}  $*${RESET}"; \
                echo -e "${BOLD}══════════════════════════════════════${RESET}"; }

# =============================================================================
# PARSING DE ARGUMENTOS
# =============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)           DRY_RUN=true; shift ;;
    --verbose|-v)        VERBOSE=true; shift ;;
    --skip-secrets)      SKIP_SECRETS_CHECK=true; shift ;;
    --dotfiles-dir=*)    DOTFILES_DIR="${1#*=}"; shift ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--verbose] [--skip-secrets] [--dotfiles-dir=PATH]"
      echo "  --dry-run       Mostra o que seria feito sem executar"
      echo "  --verbose       Output detalhado"
      echo "  --skip-secrets  Pular verificação de secrets (não recomendado)"
      echo "  --dotfiles-dir  Caminho do repositório (padrão: ~/.dotfiles)"
      exit 0 ;;
    *)
      log_error "Argumento desconhecido: $1"
      exit 1 ;;
  esac
done

# =============================================================================
# DETECÇÃO DE SISTEMA OPERACIONAL
# =============================================================================

detect_os() {
  local os
  case "$(uname -s)" in
    Linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        os="wsl"
      elif grep -qi "arch linux" /etc/os-release 2>/dev/null; then
        os="arch"
      elif grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
        os="debian"
      elif grep -qi "fedora\|rhel\|centos" /etc/os-release 2>/dev/null; then
        os="fedora"
      else
        os="linux"
      fi
      ;;
    Darwin*)
      os="macos"
      ;;
    CYGWIN*|MINGW*|MSYS*)
      os="windows"
      ;;
    *)
      os="unknown"
      ;;
  esac
  echo "$os"
}

OS=$(detect_os)
ARCH=$(uname -m)

# =============================================================================
# VERIFICAÇÃO DE PRÉ-REQUISITOS
# =============================================================================

check_prerequisites() {
  log_section "Verificando pré-requisitos"

  local missing=()

  command -v git >/dev/null 2>&1 || missing+=("git")
  command -v ln  >/dev/null 2>&1 || missing+=("ln")

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Ferramentas ausentes: ${missing[*]}"
    log_error "Instale antes de continuar."
    exit 1
  fi

  # Verificar versão do Git (mínimo 2.0)
  local git_version
  git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
  local git_major git_minor
  git_major=$(echo "$git_version" | cut -d. -f1)
  git_minor=$(echo "$git_version" | cut -d. -f2)
  if [[ $git_major -lt 2 ]]; then
    log_warn "Git $git_version detectado. Recomendado Git 2.0+."
  fi

  log_ok "Sistema: $OS ($ARCH)"
  log_ok "Git: $(git --version)"
}

# =============================================================================
# DETECÇÃO DE SECRETS
# =============================================================================

check_secrets() {
  [[ "$SKIP_SECRETS_CHECK" == "true" ]] && \
    log_warn "Verificação de secrets IGNORADA (--skip-secrets)" && return 0

  log_section "Verificação de segurança"

  local found_secrets=false

  # Scan dos arquivos que seriam linkados
  while IFS= read -r -d '' file; do
    # Pular arquivos binários e .git
    [[ "$file" == *"/.git/"* ]] && continue
    file --mime "$file" 2>/dev/null | grep -q "charset=binary" && continue

    if grep -qEi \
      '(api[_-]?key\s*[=:]\s*['"'"'"]?[A-Za-z0-9_\-]{16,}|secret\s*[=:]\s*['"'"'"]?[A-Za-z0-9_\-]{16,}|password\s*[=:]\s*['"'"'"]?.{8,}|-----BEGIN [A-Z]+ PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{20,})' \
      "$file" 2>/dev/null; then
      log_warn "Possível secret em: $file"
      found_secrets=true
    fi
  done < <(find "$DOTFILES_DIR" -not -path '*/.git/*' -type f -print0 2>/dev/null)

  if [[ "$found_secrets" == "true" ]]; then
    log_error "Secrets potenciais detectados. Revise antes de continuar."
    log_error "Use --skip-secrets para ignorar (não recomendado)."
    exit 1
  fi

  log_ok "Nenhum secret óbvio detectado."
}

# =============================================================================
# CRIAÇÃO DE SYMLINKS (IDEMPOTENTE)
# =============================================================================

make_symlink() {
  local src="$1"
  local dst="$2"

  # Validar que src existe
  if [[ ! -e "$src" ]]; then
    log_error "Fonte não existe: $src"
    return 1
  fi

  # Symlink já correto — nada a fazer
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    [[ "$VERBOSE" == "true" ]] && log_ok "Symlink já existe: $dst"
    return 0
  fi

  # Dry run
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "ln -s $src $dst"
    return 0
  fi

  # Backup de arquivo real existente (não symlink)
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR"
    local backup_path="$BACKUP_DIR/$(basename "$dst")"
    cp -r "$dst" "$backup_path"
    log_warn "Backup criado: $dst → $backup_path"
    rm -rf "$dst"
  fi

  # Remover symlink antigo/quebrado
  [[ -L "$dst" ]] && rm "$dst"

  # Criar diretório pai
  mkdir -p "$(dirname "$dst")"

  # Criar symlink
  ln -s "$src" "$dst"
  log_ok "Symlink: $dst → $src"
}

# =============================================================================
# INSTALAÇÃO DOS SYMLINKS
# =============================================================================

install_symlinks() {
  log_section "Instalando symlinks"

  local home_dir="$DOTFILES_DIR/home"
  [[ ! -d "$home_dir" ]] && log_warn "Diretório $home_dir não encontrado. Pulando." && return 0

  # Processar todos os arquivos em home/
  while IFS= read -r -d '' src; do
    # Calcular destino relativo
    local relative="${src#$home_dir/}"
    local dst="$HOME/$relative"

    make_symlink "$src" "$dst"
  done < <(find "$home_dir" -not -path '*/.git/*' -type f -print0 2>/dev/null)

  # Symlinks específicos por OS
  local os_dir="$DOTFILES_DIR/os/$OS"
  if [[ -d "$os_dir" ]]; then
    log_info "Aplicando configs específicas de $OS..."
    while IFS= read -r -d '' src; do
      local relative="${src#$os_dir/}"
      local dst="$HOME/$relative"
      make_symlink "$src" "$dst"
    done < <(find "$os_dir" -not -path '*/.git/*' -type f -print0 2>/dev/null)
  fi
}

# =============================================================================
# VALIDAÇÃO PÓS-INSTALAÇÃO
# =============================================================================

validate_symlinks() {
  log_section "Validando symlinks"

  local broken=0
  local total=0

  while IFS= read -r link; do
    total=$((total + 1))
    if [[ ! -e "$link" ]]; then
      log_error "Symlink quebrado: $link → $(readlink "$link")"
      broken=$((broken + 1))
    fi
  done < <(find "$HOME" -maxdepth 5 -type l \
    -exec sh -c 'readlink "$1" | grep -q "\.dotfiles"' _ {} \; -print 2>/dev/null)

  if [[ $broken -eq 0 ]]; then
    log_ok "Todos os $total symlinks de dotfiles estão válidos."
  else
    log_error "$broken/$total symlinks estão quebrados."
    return 1
  fi
}

# =============================================================================
# HOOKS GIT
# =============================================================================

install_git_hooks() {
  log_section "Instalando Git hooks"

  local hooks_dir="$DOTFILES_DIR/.git/hooks"
  mkdir -p "$hooks_dir"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "Instalaria hooks versionados de data/git-hooks/"
    return 0
  fi

  # Remove hooks antigos em .git/hooks/ se existirem
  rm -f "$hooks_dir/pre-commit" "$hooks_dir/commit-msg"

  # Configura core.hooksPath para usar os hooks versionados
  git -C "$DOTFILES_DIR" config core.hooksPath data/git-hooks

  log_ok "hooksPath configurado: data/git-hooks"
  log_ok "Hooks ativos: $(ls -1 "$DOTFILES_DIR/data/git-hooks/" | tr '\n' ' ')"
}

# =============================================================================
# CONFIGURAÇÕES ESPECÍFICAS POR OS
# =============================================================================

apply_os_specific() {
  log_section "Configurações específicas: $OS"

  case "$OS" in
    macos)
      # Verificar se Homebrew está instalado
      if ! command -v brew >/dev/null 2>&1; then
        log_warn "Homebrew não encontrado. Instale em: https://brew.sh"
      fi
      # macOS: readlink não suporta -f por padrão
      if ! command -v greadlink >/dev/null 2>&1; then
        log_warn "greadlink não disponível. Instale: brew install coreutils"
      fi
      ;;
    wsl)
      # WSL: avisar sobre symlinks para paths Windows
      log_warn "WSL detectado. Symlinks para /mnt/c/ têm limitações com tools Windows."
      log_info "Dica: coloque configs compartilhadas em $WINHOME (via /mnt/c/Users/...)"
      ;;
    linux|arch|debian|fedora)
      log_ok "Linux nativo — sem configurações especiais necessárias."
      ;;
  esac
}

# =============================================================================
# MAIN
# =============================================================================

main() {
  echo -e "${BOLD}"
  echo "  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗"
  echo "  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝"
  echo "  ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗"
  echo "  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║"
  echo "  ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║"
  echo "  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝"
  echo -e "${RESET}"

  [[ "$DRY_RUN" == "true" ]] && log_warn "MODO DRY-RUN: nenhuma alteração será feita.\n"

  check_prerequisites
  check_secrets
  apply_os_specific
  install_symlinks
  install_git_hooks
  validate_symlinks

  log_section "Bootstrap concluído"

  if [[ -d "$BACKUP_DIR" ]]; then
    log_info "Backups salvos em: $BACKUP_DIR"
  fi

  echo ""
  log_ok "Dotfiles instalados com sucesso!"
  log_info "Para reverter: bash $DOTFILES_DIR/scripts/rollback.sh"
  echo ""
}

main "$@"
