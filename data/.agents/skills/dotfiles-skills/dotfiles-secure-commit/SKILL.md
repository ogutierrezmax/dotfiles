---
name: "dotfiles-secure-commit"
description: "Realiza commits seguros no repositório de dotfiles: executa auditoria de segurança no diff (segredos, permissões, paths privados), valida guardrails, e gera mensagem de commit convencional. Use quando o usuário quiser commitar mudanças em dotfiles, mencionar 'commit', 'salvar', '/commit', ou ao finalizar um onboarding de programa no repositório de dotfiles."
---

# Dotfiles Secure Commit

Commits em dotfiles têm riscos únicos: tokens, senhas, chaves privadas e paths pessoais que não devem ser públicos.

Esta skill é uma **camada de segurança** para dotfiles que DEVE ser usada em conjunto com **[@git-commit-v2]** — ela executa a auditoria e, se aprovada, delega staging, mensagem e execução para a v2.

## Fluxo de execução

```
git diff/status → Auditoria de Segurança → [BLOQUEIO se houver risco]
                                         ↓ (se seguro)
                              @git-commit-v2 (staging + mensagem + commit)
                                         ↓
                              hook commit-msg valida assinatura ✅
```

> [!IMPORTANT]
> **Assinatura obrigatória**: Todo commit DEVE incluir
> `Verified-By: dotfiles-secure-commit` no rodapé. O hook `commit-msg` do repositório
> bloqueia qualquer commit que não contenha essa linha, garantindo que todo commit
> passou pela auditoria de segurança.

---

## Etapa 1 — Auditoria de Segurança (OBRIGATÓRIA)

Analise o diff com foco em 5 categorias de risco. **Qualquer achado de severidade 🔴 bloqueia o commit.**

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
git diff --staged | grep "^+" | grep -iE "(api[_-]?key|token|secret|password|-----BEGIN|AWS_SECRET|GITHUB_TOKEN|PRIVATE_KEY)"
git diff --staged --name-only | xargs stat -c "%a %n" 2>/dev/null
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
2. Usar variável de ambiente: api_key = $APP_API_KEY
3. Cancelar o commit para revisão manual
```

**Se 🟡 encontrado:** Alertar sem bloquear. Pedir confirmação antes de prosseguir.

**Se tudo 🟢:** Prosseguir para Etapa 2.

---

## Etapa 2 — Delegar à @git-commit-v2

Se a auditoria passou, use a **[@git-commit-v2]** para:

1. **Staging inteligente**: agrupar arquivos por programa (commits atômicos)
2. **Gerar mensagem**: Conventional Commits com tipo/escopo/descrição
3. **Executar commit**: com `git commit` e a assinatura obrigatória

### Regras de staging

- Nunca `git add .` sem auditoria
- Arquivos de backup (`*.bak.*`) nunca devem ser staged
- Um programa = um commit

### Tipos específicos de dotfiles

| Tipo | Uso |
|------|-----|
| `feat` | Novo programa no repo |
| `fix` | Symlink quebrado, path errado |
| `docs` | `docs/*.md`, `README.md`, `llms.txt` |
| `chore` | `.gitignore`, `dotfile-names.list` |
| `security` | Guardrails, corrigir exposição de segredo |
| `refactor` | Reorganizar `data/` sem mudança funcional |

### Escopo

Use o nome do programa: `(zsh)`, `(git)`, `(kde-plasma)`, `(tmux)`, etc.

### Assinatura obrigatória

A mensagem gerada pela `@git-commit-v2` DEVE ter `Verified-By: dotfiles-secure-commit` no rodapé:

```bash
git commit -m "<tipo>(<escopo>): <descrição>

Verified-By: dotfiles-secure-commit"
```

> [!CAUTION]
> **NUNCA use `--no-verify`** — desabilita os hooks de segurança do repositório.

---

## Protocolo de segurança (herdado da @git-commit-v2)

- NUNCA atualize git config sem solicitação explícita
- NUNCA execute `--force` ou hard reset sem pedido explícito
- NUNCA use `--no-verify` para pular hooks
- NUNCA force-push para `main`
- Se o commit falhar por hook, corrija e crie novo commit (não use `amend`)

---

## Checklist final

- [ ] Auditoria de segurança passou (nenhum 🔴)?
- [ ] Arquivos de backup não foram staged?
- [ ] A mensagem segue Conventional Commits?
- [ ] A assinatura `Verified-By: dotfiles-secure-commit` está no rodapé?
- [ ] A `@git-commit-v2` foi usada para staging + mensagem + execução?
