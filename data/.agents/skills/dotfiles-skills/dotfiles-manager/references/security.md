# Segurança em Dotfiles

## Por que dotfiles são vetores de risco

Dotfiles acumulam credenciais fora do Git sem que o desenvolvedor perceba:
shell profiles (`.bashrc`, `.zshrc`), configurações de ferramentas (`.aws/`, `.kube/`),
histórico de terminal, scripts locais e configs de IDE podem conter tokens, senhas
e chaves em texto puro. Mesmo arquivos nunca commitados podem ser expostos via
backup, sincronização de nuvem ou acesso a disco.

---

## Classificação de Arquivos por Risco

### 🔴 NUNCA versionar (bloquear no .gitignore)
```
~/.ssh/                    # Chaves SSH privadas
~/.gnupg/                  # Chaves GPG
~/.aws/credentials         # Credenciais AWS
~/.azure/                  # Credenciais Azure
~/.kube/config             # Tokens Kubernetes
~/.docker/config.json      # Auth de registries Docker
~/.netrc / .authinfo       # Credenciais FTP/SMTP/etc
~/.config/gh/hosts.yml     # Token GitHub CLI
~/.config/gcloud/          # Credenciais GCloud
~/.bundle/config           # Tokens RubyGems
~/.npmrc                   # Auth npm (pode ter tokens)
~/.pypirc                  # Credenciais PyPI
*.pem / *.key / *.p12      # Certificados/chaves
.env / .env.*              # Variáveis de ambiente com secrets
```

### 🟡 Versionar com cuidado (revisar antes)
```
~/.gitconfig               # Pode ter tokens em [credential]
~/.ssh/config              # OK se não tiver IdentityFile com paths privados
~/.npmrc                   # OK apenas com registry (sem authToken)
~/.config/nvim/            # OK; checar se tem API keys em plugins
~/.tmux.conf               # Geralmente seguro
~/.zshrc / ~/.bashrc       # Checar exports de tokens/keys
```

### 🟢 Seguro para versionar
```
~/.zshrc (sem exports sensíveis)
~/.bashrc (sem exports sensíveis)
~/.vimrc / ~/.config/nvim/
~/.tmux.conf
~/.gitconfig (sem credential.helper com tokens)
~/.config/starship.toml
~/.config/alacritty/
~/.config/kitty/
~/.wezterm.lua
~/.config/fish/
```

---

## Padrões Regex para Detecção de Secrets

### Alta confiança (bloquear sempre)
```regex
-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY
(api[_-]?key|apikey)\s*[=:]\s*['"]?[A-Za-z0-9_\-]{16,}
(secret|client_secret)\s*[=:]\s*['"]?[A-Za-z0-9_\-]{16,}
(password|passwd|pwd)\s*[=:]\s*['"]?.{8,}
(access_token|bearer)\s*[=:]\s*['"]?[A-Za-z0-9_\-\.]{20,}
AKIA[0-9A-Z]{16}                          # AWS Access Key ID
[0-9a-zA-Z/+]{40}                         # AWS Secret (40 chars)
ghp_[A-Za-z0-9]{36}                       # GitHub Personal Token
ghs_[A-Za-z0-9]{36}                       # GitHub App Token
sk-[A-Za-z0-9]{48}                        # OpenAI API Key
xox[baprs]-[0-9A-Za-z\-]+                 # Slack Token
AIza[0-9A-Za-z\-_]{35}                    # Google API Key
```

### Média confiança (alertar, pedir revisão)
```regex
[0-9a-f]{32,64}                           # Hash longo (pode ser chave)
export\s+[A-Z_]+=.{12,}                   # Export de variável longa
```

---

## Ferramentas de Detecção

### Gitleaks (recomendado para velocidade)
```bash
# Instalação
brew install gitleaks                      # macOS
curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/main/scripts/install.sh | sh

# Uso
gitleaks detect --source . --no-git       # Scan de arquivos
gitleaks protect --staged                 # Hook pre-commit
```

### TruffleHog (recomendado para validação)
```bash
# Instalação
brew install trufflehog                   # macOS
pip install trufflehog --break-system-packages

# Uso
trufflehog filesystem . --only-verified  # Só secrets confirmados como válidos
trufflehog git file://. --since-commit HEAD~5  # Últimos 5 commits
```

### Fallback: grep puro (sem dependências)
```bash
grep -rEin \
  '(api[_-]?key|secret|password|token|private.?key|-----BEGIN|aws_access_key|GITHUB_TOKEN|ghp_|sk-)' \
  --include="*.sh" --include="*.bash" --include="*.zsh" \
  --include="*.conf" --include="*.cfg" --include="*.toml" \
  --include="*.yaml" --include="*.yml" --include="*.json" \
  --exclude-dir=".git" \
  . 2>/dev/null
```

---

## Gestão de Permissões

```bash
# Verificar arquivos com permissões muito abertas no repositório
find ~/.dotfiles -not -path '*/.git/*' -type f \
  \( -perm -o+r -o -perm -g+w \) \
  -print 2>/dev/null

# Corrigir permissões de scripts
chmod 755 ~/.dotfiles/scripts/*.sh
chmod 755 ~/.dotfiles/bootstrap.sh

# Permissões corretas para configs sensíveis (SE versionar)
chmod 600 ~/.gitconfig
chmod 600 ~/.ssh/config   # NÃO versionar a pasta, mas o config pode ser versionado

# Detectar arquivos com SUID/SGID (não deveriam estar em dotfiles)
find ~/.dotfiles -perm /6000 -print 2>/dev/null
```

---

## Estratégias para Secrets Necessários

### Opção 1: Arquivo local não versionado com source
```bash
# ~/.dotfiles/home/.zshrc
[[ -f "$HOME/.env.local" ]] && source "$HOME/.env.local"
```

```gitignore
# .gitignore
.env.local
*.local
```

### Opção 2: Template com placeholders
```bash
# ~/.dotfiles/home/.env.template  (este é versionado)
GITHUB_TOKEN=PLACEHOLDER_REPLACE_ME
AWS_ACCESS_KEY=PLACEHOLDER_REPLACE_ME
```
O bootstrap copia para `.env.local` e o usuário preenche.

### Opção 3: Referência a gerenciador de secrets
```bash
# Nunca o valor, sempre a referência
export GITHUB_TOKEN=$(gh auth token 2>/dev/null)
export AWS_ACCESS_KEY=$(aws configure get aws_access_key_id 2>/dev/null)
```

---

## Auditoria de Histórico Git

Se suspeitar que secrets já foram commitados:

```bash
# Buscar em TODO o histórico
git log --all -p | grep -Ei '(api_key|secret|password|token|AKIA)'

# Usar git-filter-repo para remover (DESTRUTIVO — comunicar ao time antes)
pip install git-filter-repo --break-system-packages
git filter-repo --path-glob '*.env' --invert-paths

# Após remover: forçar push e considerar o secret comprometido
# SEMPRE rotacionar o secret mesmo após remoção do histórico
```
