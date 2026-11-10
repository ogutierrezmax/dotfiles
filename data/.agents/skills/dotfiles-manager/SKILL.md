---
name: "dotfiles-manager"
description: "Gerencia dotfiles com foco em segurança, portabilidade e versionamento Git. Use esta skill SEMPRE que o usuário mencionar: dotfiles, arquivos de configuração (~/.bashrc, ~/.zshrc, ~/.gitconfig, ~/.config/*, etc.), versionar configurações, sincronizar ambiente entre máquinas, bootstrap de novo sistema, symlinks para home directory, gerenciar segredos em configurações, .gitignore para dotfiles, GNU Stow, chezmoi, yadm, ou qualquer variação de \"quero versionar meu ambiente\". Também aciona quando o usuário quer configurar um novo computador rapidamente, fazer rollback de configuração, ou detectar credenciais em arquivos de config. Esta skill prioriza: 1) Segurança 2) Reprodutibilidade 3) Automação 4) Clareza 5) Manutenibilidade."
---

# Dotfiles Manager Skill

Gerencia dotfiles com segurança, portabilidade cross-platform e versionamento Git.
Antes de qualquer ação, leia as seções relevantes abaixo e os arquivos de referência indicados.

---

## PASSO 0 — Pesquisa Web (OBRIGATÓRIO, executar antes de tudo)

Antes de qualquer ação, execute as buscas abaixo para obter informações atualizadas
e específicas ao contexto do usuário. Adapte as queries ao que foi mencionado.

As buscas são divididas em **fixas** (sempre executar) e **condicionais** (executar
quando o contexto se encaixar). Teto recomendado: **até 8 buscas** para casos
complexos; nunca menos que 5.

---

### Buscas Fixas (sempre executar — mínimo de 5)

**Busca F1 — Melhores práticas para o alvo específico**
Pesquise práticas de versionamento para *exatamente* o que o usuário mencionou.
```
# Exemplos de query por contexto:
"neovim dotfiles best practices versioning 2025"          # se Neovim
"zsh oh-my-zsh dotfiles git symlinks best practices"      # se Zsh/OMZ
"tmux config dotfiles versioning"                         # se tmux
"gitconfig dotfiles versioning credential helper"         # se .gitconfig
"dotfiles management best practices git symlinks 2025"    # setup geral
```

**Busca F2 — Segurança e secrets específicos das ferramentas mencionadas**
```
"<ferramenta> dotfiles secrets sensitive files gitignore"
# Exemplos:
"neovim lua plugin api keys secrets gitignore"
"zshrc environment variables secrets leak git"
"gitconfig credential token security versioning"
"ssh config dotfiles security best practices"
```

**Busca F3 — Compatibilidade com o ambiente/OS do usuário**
```
# Adaptar ao OS mencionado:
"dotfiles WSL2 symlinks windows interop 2025"             # WSL
"dotfiles macos symlinks homebrew bootstrap"              # macOS
"dotfiles linux ubuntu symlinks bootstrap idempotent"     # Linux
"dotfiles cross-platform linux macos windows bootstrap"   # múltiplos OS
```

**Busca F4 — Estrutura de repositório e organização**
Pesquise exemplos de repositórios dotfiles populares e bem estruturados para
extrair padrões de organização relevantes ao stack do usuário.
```
"dotfiles repository structure organization <ferramenta> github"
"dotfiles stow structure home directory layout 2025"
"popular dotfiles repos neovim zsh tmux structure"        # adaptar ao stack
```

**Busca F5 — Ferramentas de gerenciamento (GNU Stow vs alternativas)**
Pesquise a ferramenta mais adequada ao contexto do usuário.
```
"GNU stow dotfiles symlinks tutorial 2025"
"dotfiles manager stow vs chezmoi vs yadm comparison 2025"
"dotbot dotfiles cross-platform yaml symlinks"            # se cross-platform
```

---

### Buscas Condicionais (executar quando o contexto se encaixar)

**Busca C1 — Ferramenta de nicho ou pouco documentada**
*Quando*: usuário menciona ferramenta incomum (Wezterm, Aerospace, Karabiner,
Helix, Yabai, Sketchybar, Ghostty, etc.)
```
"<ferramenta> dotfiles config versioning best practices"
"<ferramenta> config files location linux macos"
```

**Busca C2 — Stack com múltiplas ferramentas inter-dependentes**
*Quando*: usuário menciona 3+ ferramentas que se integram (ex: Neovim + LSP +
Mason, Zsh + Starship + fzf, tmux + tmuxinator).
```
"<stack> dotfiles integration versioning example"
"<tool-a> <tool-b> shared config dotfiles"
```

**Busca C3 — Auditoria de repositório existente**
*Quando*: repositório já existe e usuário quer auditar ou migrar.
```
"git history secrets audit remove credential dotfiles"
"gitleaks trufflehog scan dotfiles repository"
"git filter-repo remove sensitive file history"
```

**Busca C4 — Bootstrap em ambiente restrito**
*Quando*: usuário menciona servidor remoto, container, CI/CD, máquina sem sudo
ou ambiente corporativo.
```
"dotfiles bootstrap no sudo minimal dependencies"
"dotfiles ci environment headless bootstrap script"
"dotfiles server setup without package manager"
```

**Busca C5 — Criptografia de configs sensíveis necessária**
*Quando*: usuário precisa versionar algo que contém dados sensíveis (ex: `.ssh/config`
com hosts internos, configs com tokens que não podem ficar em arquivo local).
```
"dotfiles encrypt secrets git gpg age sops"
"chezmoi encrypt sensitive dotfiles gpg"
"git-crypt dotfiles sensitive files encryption"
```

**Busca C6 — Sincronização entre múltiplas máquinas**
*Quando*: usuário menciona mais de uma máquina, perfis por host, ou branches por ambiente.
```
"dotfiles multiple machines host-specific config git branches"
"dotfiles per-machine overrides symlinks profiles"
"yadm dotfiles multiple hosts alternates"
```

---

### O que fazer com os resultados

Após executar as buscas:

1. **Mapear arquivos relevantes** encontrados nos resultados que o usuário não mencionou
   (ex: pesquisa revelou que Neovim com Mason guarda tokens em `~/.local/share/nvim/`)
2. **Identificar riscos específicos** do stack (paths onde secrets costumam aparecer)
3. **Extrair padrões de .gitignore** recomendados para as ferramentas listadas
4. **Escolher ferramenta de gerenciamento** mais adequada ao contexto
5. **Incorporar tudo** na estrutura de repositório, .gitignore e script de bootstrap

Apresente ao usuário um breve resumo do que as pesquisas revelaram de relevante
**antes** de propor qualquer estrutura ou código.

---

## Fluxo de Decisão Principal

```
Usuário quer gerenciar dotfiles?
├── Repositório já existe?  →  [SEÇÃO: Auditoria de Repositório Existente]
└── Não existe ainda?       →  [SEÇÃO: Inicialização do Repositório]

Ação específica?
├── Adicionar arquivo       →  [SEÇÃO: Adicionando Arquivos com Segurança]
├── Bootstrap nova máquina  →  [SEÇÃO: Script de Bootstrap]
├── Detectar secrets        →  [SEÇÃO: Detecção de Segredos]
├── Validar symlinks        →  [SEÇÃO: Validação e Saúde]
├── Rollback                →  [SEÇÃO: Rollback Seguro]
└── Cross-platform          →  [SEÇÃO: Compatibilidade entre Ambientes]
```

---

## Estrutura de Repositório Recomendada

Se o repositório não existir, proponha esta estrutura. Se já existir, adapte sem destruir o existente.

```
~/.dotfiles/                        ← raiz do repositório Git
├── .gitignore                      ← CRÍTICO: gerado com segurança (ver referências)
├── .gitmodules                     ← submódulos se necessário
├── README.md                       ← instruções de bootstrap
├── bootstrap.sh                    ← script de instalação idempotente
├── scripts/
│   ├── install.sh                  ← cria symlinks
│   ├── detect-secrets.sh           ← scan pré-commit
│   ├── validate.sh                 ← verifica saúde dos symlinks
│   └── rollback.sh                 ← desfaz symlinks e restaura backups
├── home/                           ← espelha estrutura do $HOME
│   ├── .bashrc
│   ├── .zshrc
│   ├── .gitconfig
│   └── .config/
│       ├── nvim/
│       └── tmux/
├── os/
│   ├── linux/                      ← configs exclusivas de Linux
│   ├── macos/                      ← configs exclusivas de macOS
│   └── wsl/                        ← ajustes para WSL
└── private/                        ← NUNCA commitado (.gitignore)
    ├── .env.local
    └── secrets/
```

**Regra fundamental**: tudo em `home/` é espelhado via symlink para `$HOME/`. Nunca copiar, sempre symlinkear.

---

## Inicialização do Repositório

```bash
# 1. Criar repositório
mkdir -p ~/.dotfiles/{home,os/{linux,macos,wsl},scripts,private}
cd ~/.dotfiles
git init

# 2. Gerar .gitignore seguro ANTES de qualquer git add
# (ver references/gitignore-template.md para template completo)

# 3. Configurar hooks Git
mkdir -p .git/hooks
# Instalar hook pre-commit de detecção de secrets (ver scripts/detect-secrets.sh)

# 4. Primeiro commit seguro
git add .gitignore README.md bootstrap.sh
git commit -m "chore: initialize dotfiles repository"
```

⚠️ **NUNCA execute `git add .` sem antes validar o .gitignore.**

---

## Adicionando Arquivos com Segurança

Sempre seguir este fluxo ao adicionar um arquivo:

### Checklist pré-adição
1. **Verificar se contém secrets** → rodar `scripts/detect-secrets.sh <arquivo>`
2. **Verificar permissões** → arquivos com 600/700 podem conter credenciais
3. **Verificar se já existe symlink** → evitar conflito
4. **Fazer backup do original** → antes de criar symlink

```bash
# Fluxo seguro para adicionar ~/.zshrc
DOTFILES=~/.dotfiles
FILE=~/.zshrc
DEST="$DOTFILES/home/.zshrc"

# 1. Checar secrets (nunca pular este passo)
grep -Ei '(api[_-]?key|secret|password|token|private[_-]?key|aws_|GITHUB_TOKEN)' "$FILE" \
  && echo "⚠️  POSSÍVEL SECRET DETECTADO — revisar antes de continuar" && exit 1

# 2. Checar permissões inseguras
PERMS=$(stat -c %a "$FILE" 2>/dev/null || stat -f %p "$FILE" | tail -c 4)
[[ "$PERMS" =~ ^[67][0-9][0-9]$ ]] && echo "⚠️  Permissão $PERMS pode indicar arquivo sensível"

# 3. Mover para repositório (nunca copiar)
mv "$FILE" "$DEST"

# 4. Criar symlink (idempotente)
[[ -L "$FILE" ]] && rm "$FILE"
ln -s "$DEST" "$FILE"

echo "✓ Symlink criado: $FILE → $DEST"
```

---

## Detecção de Segredos

Ler `references/security.md` para detalhes completos. Resumo:

### Padrões a detectar (regex)
```
API_KEY, api_key, apikey
SECRET, secret_key, client_secret
PASSWORD, passwd, pwd
TOKEN, access_token, bearer
PRIVATE KEY (PEM blocks)
AWS_ACCESS_KEY, AWS_SECRET
GITHUB_TOKEN, GH_TOKEN
-----BEGIN (qualquer bloco PEM/RSA/EC)
[0-9a-f]{32,} (hashes longos — possível chave)
```

### Ferramentas por disponibilidade
```bash
# Opção 1: gitleaks (mais rápido, recomendado para CI)
gitleaks detect --source . --no-git

# Opção 2: trufflehog (mais detalhado, valida contra APIs)
trufflehog filesystem . --only-verified

# Opção 3: fallback puro bash (quando nenhuma ferramenta disponível)
grep -rEi \
  '(api[_-]?key|secret|password|token|private.?key|-----BEGIN|aws_access|GITHUB_TOKEN)' \
  --include="*.sh" --include="*.zsh" --include="*.bash" \
  --include="*.conf" --include="*.cfg" --include="*.env" \
  --exclude-dir=".git" .
```

### Hook pre-commit
```bash
# .git/hooks/pre-commit (chmod +x)
#!/usr/bin/env bash
set -euo pipefail

STAGED=$(git diff --cached --name-only)
FOUND=0

for file in $STAGED; do
  [[ -f "$file" ]] || continue
  if grep -qEi '(api[_-]?key\s*=|secret\s*=|password\s*=|-----BEGIN|AWS_SECRET|GITHUB_TOKEN)' "$file"; then
    echo "🔴 BLOQUEADO: possível secret em '$file'"
    FOUND=1
  fi
done

[[ $FOUND -eq 1 ]] && echo "Remova secrets antes de commitar." && exit 1
exit 0
```

---

## Geração do .gitignore Seguro

Ver `references/gitignore-template.md` para template completo. Seções obrigatórias:

```gitignore
# === SECRETS E CREDENCIAIS (NUNCA commitar) ===
.env
.env.*
*.env
.secrets
secrets/
private/
*_rsa
*_rsa.pub
*_ed25519
*_ed25519.pub
*.pem
*.key
*.p12
*.pfx
id_*
*.gpg
*.asc
auth.json
credentials.json
token.json
netrc
.netrc
.authinfo

# === ARQUIVOS SENSÍVEIS DO SISTEMA ===
.ssh/
.gnupg/
.aws/credentials
.azure/
.kube/config
.docker/config.json

# === CACHE E DADOS LOCAIS ===
.cache/
*.log
*.tmp
__pycache__/
node_modules/
.DS_Store
Thumbs.db
```

---

## Script de Bootstrap

Gerar script idempotente que funcione em todas as plataformas suportadas.
Ver `scripts/bootstrap-template.sh` para o template completo.

### Princípios de idempotência
- Toda operação deve ser segura de re-executar
- Checar se symlink já existe antes de criar
- Fazer backup datado antes de sobrescrever qualquer arquivo
- Detectar OS e aplicar configurações específicas
- Retornar código de saída correto (0 = sucesso)

```bash
# Estrutura mínima do bootstrap.sh
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

make_symlink() {
  local src="$1" dst="$2"
  
  # Backup se arquivo real existir (não symlink)
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
    mv "$dst" "$backup"
    echo "  ↳ backup: $backup"
  fi
  
  # Remover symlink antigo quebrado
  [[ -L "$dst" ]] && rm "$dst"
  
  # Criar diretório pai se necessário
  mkdir -p "$(dirname "$dst")"
  
  ln -s "$src" "$dst"
  echo "  ✓ $dst → $src"
}
```

---

## Rollback Seguro

```bash
# Reverter último commit de symlinks
rollback_symlinks() {
  local DOTFILES="${1:-$HOME/.dotfiles}"
  local BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
  
  mkdir -p "$BACKUP_DIR"
  
  # Listar todos os symlinks apontando para o repositório
  find "$HOME" -maxdepth 3 -type l 2>/dev/null | while read -r link; do
    local target
    target=$(readlink "$link")
    if [[ "$target" == "$DOTFILES"* ]]; then
      echo "Removendo symlink: $link → $target"
      rm "$link"
      # Restaurar backup se existir
      local backup
      backup=$(ls "${link}.bak."* 2>/dev/null | sort | tail -1)
      if [[ -n "$backup" ]]; then
        mv "$backup" "$link"
        echo "  ↳ restaurado de $backup"
      fi
    fi
  done
}

# Rollback via Git (reverter para commit específico)
git_rollback() {
  local commit="${1:-HEAD~1}"
  git stash
  git checkout "$commit"
  bash bootstrap.sh  # re-aplicar symlinks do estado anterior
}
```

---

## Validação e Saúde

```bash
# Verificar symlinks quebrados
check_symlinks() {
  echo "=== Symlinks quebrados ==="
  find "$HOME" -maxdepth 4 -type l ! -exec test -e {} \; -print 2>/dev/null

  echo "=== Symlinks apontando para dotfiles ==="
  find "$HOME" -maxdepth 4 -type l -exec readlink {} \; 2>/dev/null \
    | grep -c "\.dotfiles" || echo "0 symlinks de dotfiles encontrados"

  echo "=== Permissões potencialmente inseguras ==="
  find "$HOME/.dotfiles" -not -path '*/.git/*' \
    \( -perm -o+w -o -perm -g+w \) -print 2>/dev/null \
    | grep -v "^$" || echo "Nenhuma permissão insegura encontrada."
}
```

---

## Compatibilidade entre Ambientes

Ao gerar configs, checar compatibilidade com:

| Recurso              | Linux | macOS | WSL |
|----------------------|-------|-------|-----|
| `ln -s`              | ✓     | ✓     | ✓*  |
| `readlink -f`        | ✓     | ✗**   | ✓   |
| `/proc/version`      | ✓     | ✗     | ✓   |
| `stat -c %a`         | ✓     | ✗***  | ✓   |
| `sed -i ''`          | ✗     | ✓     | ✗   |

\* WSL: symlinks para paths Windows (`/mnt/c/`) funcionam mas têm limitações  
\** macOS: usar `greadlink` (coreutils) ou `realpath`  
\*** macOS: usar `stat -f %p`

### Detecção de OS em shell scripts
```bash
OS=$(uname -s)
case "$OS" in
  Linux)
    [[ -f /proc/version ]] && grep -qi microsoft /proc/version && OS="WSL"
    ;;
  Darwin)
    OS="macOS"
    ;;
esac
```

---

## Auditoria de Repositório Existente

Quando o usuário já tem dotfiles versionados, executar antes de qualquer mudança:

1. **Verificar secrets já commitados**: `git log --all -p | grep -Ei 'api_key|secret|password|token'`
2. **Listar symlinks ativos**: `find $HOME -maxdepth 3 -type l 2>/dev/null`
3. **Checar symlinks quebrados**: `find $HOME -maxdepth 3 -type l ! -exec test -e {} \; -print`
4. **Verificar .gitignore** cobre todos os padrões sensíveis
5. **Verificar permissões de arquivos** no repositório

---

## Referências de Arquivos

| Arquivo | Conteúdo | Quando ler |
|---------|----------|------------|
| `references/gitignore-template.md` | Template .gitignore completo e comentado | Ao criar/auditar .gitignore |
| `references/security.md` | Padrões de secrets, ferramentas, boas práticas | Ao lidar com segurança/credenciais |
| `scripts/bootstrap-template.sh` | Script bootstrap completo cross-platform | Ao gerar bootstrap para novo sistema |

---

## Regras Absolutas (Nunca Violar)

1. **NUNCA** commitar arquivos de `~/.ssh/`, `~/.gnupg/`, `~/.aws/credentials`
2. **NUNCA** usar `git add .` sem validar .gitignore antes
3. **NUNCA** sobrescrever arquivo existente sem fazer backup datado
4. **NUNCA** criar symlink se o destino já é um symlink válido (idempotência)
5. **SEMPRE** rodar detecção de secrets antes de qualquer `git commit`
6. **SEMPRE** informar o usuário sobre arquivos ignorados e o porquê
7. **SEMPRE** testar scripts com `--dry-run` ou equivalente antes de executar
