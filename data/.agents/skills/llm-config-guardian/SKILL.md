---
name: llm-config-guardian
description: "Audita e anota arquivos de configuração para prevenir falhas de segurança introduzidas por LLMs. Aplica guardrails inline (comentários SECURITY NOTE, DANGER ZONE, NEVER) que guiam tanto humanos quanto agentes de IA. Use sempre que o usuário pedir para revisar segurança de configs, adicionar proteções contra LLMs, auditar dotfiles, proteger scripts, blindar configurações, 'tornar seguro pra IA editar', 'adicionar guardrails', 'security review', ou ao criar/modificar qualquer arquivo de configuração que uma LLM possa editar no futuro (shell configs, Dockerfiles, CI/CD, nginx, .env, scripts de deploy, infra-as-code)."
---

# LLM Config Guardian

Arquivos de configuração editados por LLMs são vetores silenciosos de falhas de segurança. Uma LLM não tem contexto sobre o que é sensível no seu ambiente — ela sugere `chmod 777`, exporta tokens em arquivos rastreados pelo Git, ou cria aliases que mascaram comandos destrutivos. Esta skill existe para antecipar esses erros antes que aconteçam.

## O problema

LLMs geram código funcional, mas sem consciência de segurança contextual. Os erros mais comuns:

- **Exposição de segredos**: colocar API keys, tokens e senhas em arquivos versionados
- **Permissões excessivas**: `chmod 777`, `sudo` desnecessário, arquivos world-writable
- **Mascaramento de comandos**: aliases que escondem o comportamento real de comandos destrutivos (ex: `alias rm='rm -rf'`)
- **Execução cega de código remoto**: `curl | bash`, `eval "$(comando)"` sem validação
- **Injeção via variáveis**: expansão de variáveis não sanitizadas em contextos de shell
- **Configurações permissivas**: `bind 0.0.0.0`, `allowAll: true`, autenticação desabilitada

## Processo

### 1. Identificar o tipo de arquivo e seu perfil de risco

Cada tipo de configuração tem riscos diferentes. Classifique o arquivo antes de anotar:

| Tipo de Arquivo | Riscos Primários |
|---|---|
| Shell configs (`.zshrc`, `.bashrc`, `.profile`) | Exposição de segredos, aliases perigosos, `eval` de código remoto |
| Scripts de instalação/deploy | Execução como root, download não verificado, permissões excessivas |
| Dockerfiles | Execução como root, segredos em layers, imagens não-pinadas |
| CI/CD (`.github/workflows`, `.gitlab-ci.yml`) | Segredos em logs, permissões de token excessivas, cache poisoning |
| Configs de servidor (nginx, Apache) | Bind em `0.0.0.0`, TLS desabilitado, headers de segurança ausentes |
| `.env` e variáveis de ambiente | Arquivo versionado por acidente, segredos em plaintext |
| Infra-as-code (Terraform, Ansible) | Security groups abertos, credenciais hardcoded, state não-encriptado |

### 2. Aplicar guardrails inline

O mecanismo principal são **comentários de segurança diretamente no arquivo**, posicionados exatamente onde o risco existe. Uma LLM que lê o arquivo encontra o aviso no contexto certo e é muito menos propensa a violar a regra.

**Formato dos comentários por nível de severidade:**

```
# SECURITY NOTE: [explicação do risco e a regra a seguir]
# DANGER ZONE: [operação perigosa — exige revisão humana antes de modificar]
# NEVER: [ação explicitamente proibida — LLMs não devem gerar código que faça isso]
```

**Regras de posicionamento:**

- Coloque o comentário **imediatamente acima** da linha ou bloco que ele protege
- Se o risco é sobre o que **não deve ser adicionado** ao arquivo (ex: segredos), coloque no topo do arquivo
- Se o risco é sobre uma **operação específica**, coloque junto da operação
- Em arquivos longos, repita avisos críticos se a distância do topo for maior que ~50 linhas

### 3. Categorias de anotação

Aplique as categorias relevantes ao tipo de arquivo. Nem todo arquivo precisa de todas:

#### Segredos e credenciais
```bash
# SECURITY NOTE: DO NOT place API keys, passwords, or tokens in this file.
# This file is tracked by Git. Use ~/.env_private or a secrets manager instead.
```

#### Permissões de arquivo
```bash
# SECURITY NOTE: This file must be owned by your user (chmod 600 or 644).
# World-writable config files can be exploited for privilege escalation.
```

#### Aliases e mascaramento de comandos
```bash
# SECURITY NOTE: Avoid aliasing destructive commands (rm, mv, cp, chmod).
# LLMs may suggest commands assuming standard behavior. Masked commands
# cause silent, unexpected data loss.
```

#### Execução de código remoto
```bash
# DANGER ZONE: eval executes arbitrary code. Ensure the source is trusted
# and the output is predictable. Prefer explicit sourcing over eval when possible.
eval "$(tool init zsh)"
```

#### Execução com privilégios elevados
```bash
# DANGER ZONE: This script runs with elevated privileges.
# Every command here executes as root. Minimize scope and validate inputs.
```

#### Download e execução
```bash
# NEVER: Do not add 'curl | bash' or 'wget | sh' patterns to this file.
# Always download first, inspect, then execute. Pin versions when possible.
```

#### Bind de rede
```yaml
# SECURITY NOTE: Binding to 0.0.0.0 exposes this service to all network interfaces.
# Use 127.0.0.1 for local-only access unless external access is explicitly required.
```

### 4. Criar arquivo de segredos local (quando aplicável)

Se o arquivo auditado contém ou poderia conter segredos, crie (ou sugira) um arquivo local não rastreado:

```bash
# Exemplo para shell configs:
# Arquivo: ~/.zsh_local (ou ~/.env_private)
# Este arquivo NÃO deve ser versionado. Adicione ao .gitignore.

# SECURITY NOTE: Place all secrets, API keys, and sensitive environment
# variables in this file. Source it from your shell config.
export MY_API_KEY="..."
export DATABASE_URL="..."
```

E adicione a referência no arquivo principal:
```bash
# Load local secrets (not tracked by Git)
[ -f ~/.zsh_local ] && source ~/.zsh_local
```

### 5. Verificar .gitignore

Confirme que arquivos sensíveis estão excluídos do versionamento:
- `~/.env_private`, `~/.zsh_local`, `*.pem`, `*.key`
- Diretórios de state (`terraform.tfstate`, `.env.local`)

### 6. Auto-verificação

Após anotar, verifique:

- [ ] Todo segredo potencial tem um aviso de redirecionamento para arquivo local?
- [ ] Toda operação `eval` ou `source` de código dinâmico tem um DANGER ZONE?
- [ ] Todo alias de comando destrutivo tem um aviso?
- [ ] O `.gitignore` protege arquivos sensíveis?
- [ ] Os comentários explicam o **porquê** (não apenas o **quê**)?
- [ ] Uma LLM lendo apenas este arquivo teria contexto suficiente para não introduzir falhas?

## Exemplo completo: Shell config

```bash
# Environment variables
# SECURITY NOTE: DO NOT place API keys, passwords, or tokens in this file.
# This file is tracked by Git. Use ~/.zsh_local for secrets.
export PATH=$HOME/bin:$HOME/.local/bin:$PATH

# DANGER ZONE: eval executes arbitrary code from an external tool.
# Ensure zoxide is installed from a trusted source before enabling.
eval "$(zoxide init zsh)"

# Aliases
# SECURITY NOTE: Avoid aliasing destructive commands (rm, mv, cp).
# LLMs assume standard command behavior when suggesting shell commands.
alias ls='eza --icons'
alias ll='eza -lah --icons'

# NEVER: Do not add 'curl URL | bash' patterns here.

# Load local secrets (not tracked by Git)
[ -f ~/.zsh_local ] && source ~/.zsh_local
```

## Quando NÃO aplicar

- Arquivos temporários ou descartáveis que não serão reutilizados
- Configs em ambientes isolados e efêmeros (containers de CI descartáveis)
- Quando o usuário explicitamente pede para pular a revisão de segurança
