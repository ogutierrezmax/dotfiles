---
name: "dotfiles-secure-commit"
description: "Realiza commits seguros no repositório de dotfiles: executa auditoria de segurança no diff (segredos, permissões, paths privados), valida guardrails, e gera mensagem de commit convencional. Use quando o usuário quiser commitar mudanças em dotfiles, mencionar 'commit', 'salvar', '/commit', ou ao finalizar um onboarding de programa no repositório de dotfiles."
---

# Dotfiles Secure Commit

Commits em dotfiles têm riscos únicos: tokens, senhas, chaves privadas e paths pessoais que não devem ser públicos. Esta skill combina auditoria de segurança com geração de mensagem convencional.

## Fluxo de execução

```
git diff/status → Auditoria de Segurança → [BLOQUEIO se houver risco]
                                         ↓ (se seguro)
                                   Staging inteligente
                                         ↓
                                   Mensagem convencional + Assinatura
                                         ↓
                                      git commit
                                         ↓
                              hook commit-msg valida assinatura ✅
```

> [!IMPORTANT]
> **Assinatura obrigatória**: Todo commit gerado por esta skill DEVE incluir
> `Verified-By: dotfiles-secure-commit` no rodapé. O hook `commit-msg` do repositório
> bloqueia qualquer commit que não contenha essa linha, garantindo que todo commit
> passou pela auditoria de segurança.

---

## Etapa 1 — Analisar o estado atual

```bash
git status --porcelain
git diff --staged
git diff  # se nada staged
```

Se **nada foi modificado**, informar o usuário e parar.

---

## Etapa 2 — Auditoria de Segurança (OBRIGATÓRIA)

Analise o diff com foco em 5 categorias de risco. **Qualquer achado de severidade 🔴 bloqueia o commit.**

### Categorias de risco

| Nível | Categoria | Exemplos a detectar |
|-------|-----------|---------------------|
| 🔴 **Bloqueante** | Segredos e credenciais | `api_key`, `token`, `password`, `secret`, `-----BEGIN`, `GITHUB_TOKEN`, `AWS_SECRET` |
| 🔴 **Bloqueante** | Chaves privadas | Qualquer arquivo `.pem`, `.key`, padrão `-----BEGIN PRIVATE KEY-----` |
| 🟡 **Atenção** | Paths absolutos hardcoded | `/home/username/`, `/Users/alfo/`, caminhos com nome de usuário explícito |
| 🟡 **Atenção** | Permissões excessivas | `chmod 777`, `chmod 666`, `chmod o+w` |
| 🟢 **Informativo** | Arquivos de backup staged | `*.bak*`, `*.bkp`, `*~` acidentalmente staged |

### Como auditar

**Verifique o diff completo** — não apenas os nomes de arquivos, mas os **valores adicionados** (`+` no diff):

```bash
# Buscar padrões de segredo no que será commitado
git diff --staged | grep "^+" | grep -iE "(api[_-]?key|token|secret|password|-----BEGIN|AWS_SECRET|GITHUB_TOKEN|PRIVATE_KEY)"

# Verificar permissões de arquivos novos
git diff --staged --name-only | xargs stat -c "%a %n" 2>/dev/null

# Verificar backups acidentalmente staged
git diff --staged --name-only | grep -E "\.(bak|bkp|backup)[0-9_]*$|~$"
```

> [!IMPORTANT]
> A auditoria vai além da Regex do hook de pré-commit. Use inteligência contextual: `auth_header = "Bearer eyJ..."` é um token mesmo sem a palavra "token" na chave.

### Resultado da auditoria

**Se 🔴 encontrado:** PARE. Apresente o risco e as opções:
```
🔴 BLOQUEADO: encontrei possível segredo em 'data/.config/app/config.toml' (linha 12: api_key = "...")

Opções:
1. Remover o valor e mover para ~/.app_local (não versionado)
2. Usar uma variável de ambiente: api_key = $APP_API_KEY
3. Cancelar o commit para revisão manual
```

**Se 🟡 encontrado:** Alertar sem bloquear. Pedir confirmação antes de prosseguir.

**Se tudo 🟢:** Prosseguir para staging.

---

## Etapa 3 — Staging inteligente

Se nada está staged ou se há arquivos não relacionados no working tree, agrupe logicamente:

```bash
# Verificar o que está unstaged
git status --porcelain

# Staging por programa/contexto
git add data/.config/autostart/          # tudo do autostart
git add config/dotfile-names.list        # lista atualizada
git add docs/autostart.md README.md      # documentação
```

**Regras de staging:**
- Nunca `git add .` sem antes ter passado pela auditoria de segurança.
- Arquivos de backup (`*.bak.*`) nunca devem ser staged.
- Agrupe em commits atômicos: um programa = um commit.

---

## Etapa 4 — Gerar mensagem de commit (Conventional Commits)

### Formato

```
<tipo>(<escopo>): <descrição>

[corpo opcional]

[rodapé opcional]
```

### Tipos

| Tipo | Quando usar em dotfiles |
|------|------------------------|
| `feat` | Adicionar novo programa ao repo |
| `fix` | Corrigir symlink quebrado, path errado |
| `docs` | Atualizar `docs/*.md`, `README.md`, `llms.txt` |
| `chore` | Atualizar `.gitignore`, `dotfile-names.list` |
| `security` | Aplicar guardrails, corrigir exposição de segredo |
| `refactor` | Reorganizar estrutura de `data/` sem mudança funcional |

### Escopo (em dotfiles)

Use o nome do programa ou área afetada: `(autostart)`, `(zsh)`, `(git)`, `(kde-plasma)`.

### Exemplos

```
feat(autostart): add autostart programs with security guardrails

Moves 4 .desktop files to data/.config/autostart/ and creates symlinks.
Adds SECURITY NOTE and DANGER ZONE comments to prevent secret injection.

Closes: pre-commit hook installation
```

```
chore(gitignore): exclude backup files from autostart directory
```

```
security(zsh): remove API token from .zshrc history
```

---

## Etapa 5 — Executar o commit (com assinatura obrigatória)

Todo commit DEVE incluir `Verified-By: dotfiles-secure-commit` no rodapé.
Sem essa linha, o hook `commit-msg` do repositório bloqueará o commit.

```bash
# Commit simples com assinatura
git commit -m "<tipo>(<escopo>): <descrição>

Verified-By: dotfiles-secure-commit"

# Commit com corpo
git commit -m "$(cat <<'EOF'
<tipo>(<escopo>): <descrição>

<corpo opcional explicando o que mudou>

Verified-By: dotfiles-secure-commit
EOF
)"
```

> [!CAUTION]
> **NUNCA use `--no-verify`** — isso desabilita AMBOS os hooks (`pre-commit` e `commit-msg`),
> contornando toda a camada de segurança do repositório.

---

## Protocolo de segurança (herdado da @git-commit)

- **NUNCA** atualize git config sem solicitação explícita
- **NUNCA** execute `--force` ou hard reset sem pedido explícito
- **NUNCA** use `--no-verify` para pular hooks
- **NUNCA** force-push para `main`
- Se o commit falhar por hook, **corrija o problema e crie um novo commit** (não use `amend`)

---

## Checklist final (auto-verificação)

Antes de confirmar o commit, verifique:

- [ ] Auditoria de segurança passou (nenhum 🔴)?
- [ ] Arquivos de backup não foram staged?
- [ ] A mensagem segue Conventional Commits?
- [ ] O escopo representa corretamente o programa afetado?
- [ ] O commit é atômico (um programa/mudança por commit)?
- [ ] A assinatura `Verified-By: dotfiles-secure-commit` está no rodapé?
- [ ] O hook `pre-commit` está em `.git/hooks/pre-commit`?
- [ ] O hook `commit-msg` está em `.git/hooks/commit-msg`?
