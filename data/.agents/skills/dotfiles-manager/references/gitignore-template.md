# Template .gitignore para Dotfiles

Copie este conteúdo para `~/.dotfiles/.gitignore`.
Revise e adapte às suas ferramentas específicas.

---

```gitignore
# =============================================================================
# DOTFILES .GITIGNORE — SEGURANÇA PRIMEIRO
# Gerado pela skill dotfiles-manager
# =============================================================================

# =============================================================================
# SECRETS E CREDENCIAIS — NUNCA COMMITAR
# =============================================================================

# Variáveis de ambiente
.env
.env.*
*.env
.envrc
.direnv/

# Secrets genéricos
secrets/
private/
.secrets
.private
*.secret
*_secret

# Chaves e certificados
*.pem
*.key
*.p12
*.pfx
*.crt
*.cert
*_rsa
*_rsa.pub
*_ed25519
*_ed25519.pub
*_dsa
*_ecdsa
id_*
!id_*.template    # Templates sem valor real são OK

# Tokens e auth
token.json
tokens.json
credentials.json
auth.json
*.token

# =============================================================================
# DIRETÓRIOS SENSÍVEIS DO SISTEMA
# =============================================================================

# SSH — NUNCA versionar a pasta inteira
.ssh/
# (versionar apenas .ssh/config se necessário, via symlink explícito)

# GPG
.gnupg/
.gpg/

# Cloud providers
.aws/
.azure/
.gcloud/
.config/gcloud/
.config/gh/hosts.yml    # Token do GitHub CLI

# Kubernetes
.kube/
.minikube/

# Docker
.docker/config.json

# =============================================================================
# FERRAMENTAS DE DESENVOLVIMENTO
# =============================================================================

# npm/Node
.npmrc                  # Pode conter authToken — adicionar manualmente se seguro
.yarnrc
.yarn/
node_modules/

# Python
.pypirc
.pip/
__pycache__/
*.pyc
.python-version
.venv/
venv/

# Ruby
.bundle/config          # Pode conter tokens de gems
.gem/credentials

# Rust
.cargo/credentials
.cargo/credentials.toml

# Go
.config/go/env          # Pode ter GONOSUMCHECK com tokens

# Terraform
*.tfstate
*.tfstate.*
.terraform/
*.tfvars                # Pode conter secrets
!*.tfvars.example

# =============================================================================
# EDITORES E IDEs
# =============================================================================

.idea/
.vscode/settings.json  # settings.json pode ter tokens
!.vscode/extensions.json
!.vscode/launch.json
*.sublime-workspace
.vim/undo/
.vim/backup/
*.swp
*.swo
*~

# =============================================================================
# SISTEMA OPERACIONAL
# =============================================================================

# macOS
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes

# Windows
Thumbs.db
ehthumbs.db
Desktop.ini
$RECYCLE.BIN/

# Linux
.Trash-*/

# =============================================================================
# LOGS E TEMPORÁRIOS
# =============================================================================

*.log
*.tmp
*.temp
*.cache
.cache/
/tmp/
*.bak
*.bak.*
*.orig
*.backup

# =============================================================================
# DADOS LOCAIS (NÃO COMPARTILHÁVEIS)
# =============================================================================

# Histórico de shells (sensível + específico de máquina)
.bash_history
.zsh_history
.fish_history
.python_history
.node_repl_history
.irb_history
.psql_history
.mysql_history
.sqlite_history

# Sessões
.local/share/recently-used.xbel
.recently-used

# Pastas de dados de aplicações (muito grandes/sensíveis)
.local/share/keyrings/
.local/share/gnome-keyring/
.password-store/
.config/chromium/
.config/google-chrome/
.config/BraveSoftware/
.mozilla/

# =============================================================================
# DOTFILES ESPECÍFICOS — MACHINE-LOCAL
# =============================================================================

# Arquivos locais que o usuário pode criar para customização
*.local
.local.sh
*_local
local/

# Hosts e IPs específicos (segurança operacional)
.ssh/known_hosts

# =============================================================================
# BACKUP AUTOMÁTICO DO BOOTSTRAP
# =============================================================================

*.bak.[0-9]*
```
