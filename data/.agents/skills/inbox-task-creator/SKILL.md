---
name: inbox-task-creator
description: Decompose user input (errors, refactorings, implementations, etc.) into structured tasks and creates each one via inbox-task.mjs. Use when the user provides a list of bugs, errors, refactoring needs, feature requests, or any work description that should be split into multiple tracked tasks in .devtool/features/Inbox/.
---

# Inbox Task Creator

Creates structured inbox tasks from user input using `.devtool/scripts/inbox-task.mjs`.

## Fluxo de execução

### 1. Classificar tipo de entrada

| Tipo | Gatilhos |
|------|----------|
| **error_log** | Stack trace, `Error:`, `ERROR:`, `FAIL:`, `FATAL:`, `exit code`, `Uncaught Exception` |
| **task_list** | `- [ ]` ou `- [x]` (≥2), enumeração numerada (1.\n2.\n3.), verbos imperativos, "TODO", "checklist" |
| **complex_input** | Fallback. Múltiplos parágrafos, seções, termos de arquitetura |

### 2. Segmentar em tasks

**error_log:** 1 task (o log documenta 1 problema)

**task_list:** Identificar items individuais. Items relacionados (mesma implementação) → 1 task agrupada. Items independentes → 1 task cada.

**complex_input:** Se descreve 1 feature → 1 task. Se múltiplas features distintas → 1 task cada.

### 3. Inferir labels por task

Varrer o conteúdo e coletar labels:

| Palavra-chave | Label |
|---------------|-------|
| `bug`, `error`, `crash`, `exception`, `fail`, `não funciona`, `quebrado` | `bug` |
| `implementar`, `criar`, `adicionar`, `new feature`, `feat` | `feat` |
| `refactor`, `refatorar`, `melhorar`, `reestruturar` | `refactor` |
| `performance`, `lento`, `otimizar`, `cache`, `lazy` | `perf` |
| `configurar`, `setup`, `migration`, `update`, `deploy` | `chore` |
| `test`, `spec`, `vitest`, `cobertura` | `test` |
| `docs`, `readme`, `documentar`, `doc` | `docs` |
| `?`, `dúvida`, `investigar`, `entender` | `duvida` |
| `database`, `prisma`, `schema`, `orm`, `migration` | `database` |
| `ui`, `component`, `frontend`, `layout`, `css` | `ui` |
| `api`, `route`, `endpoint`, `graphql` | `api` |
| `voice`, `audio`, `voz` | `voice-control` |
| `gemini`, `genai`, `llm`, `ai` | `gemini` |

Fallback: `["chore"]`. Ordenar labels alfabeticamente.

### 4. Apresentar lote ao usuário

Mostrar as tasks propostas numeradas:

```
Tasks propostas (N):

1. [bug] Título da task 1
2. [feat] Título da task 2
3. [refactor] Título da task 3

Crio todas? [y/N]
```

Se o usuário disser não, perguntar quais manter ou deixar refinar.

### 5. Criar cada task

Para cada task confirmada, pipe o markdown para o script:

```bash
echo '# Title\n\nBody content' | node .devtool/scripts/inbox-task.mjs --labels '["tag1","tag2"]'
```

Regras:
- Conteúdo DEVE começar com `# Title` (exigido pelo script)
- Incluir contexto relevante após o título
- `--labels` deve ser JSON array não vazio
- Usar `\n` para quebras de linha no echo

### 6. Reportar

```
✅ N task(s) criadas em .devtool/features/Inbox/:
  filename1.md  ← Title 1
  filename2.md  ← Title 2
```

## Auto-verificação

Após criar cada task:
- [ ] Script exitou com código 0
- [ ] Output é um path válido em `.devtool/features/Inbox/`
- [ ] Arquivo existe com frontmatter válido

## Exemplos

### Input: Log de erro

```
ERROR in src/auth/login.ts:42
TypeError: Cannot read property 'token' of undefined
    at loginHandler (src/auth/login.ts:42)
```

**Proposta:**
1. [bug] Fix TypeError in login handler

**Comando:**
```bash
echo '# Fix TypeError in login handler\n\n## Context\nLogin endpoint crashes when token is undefined in src/auth/login.ts:42\n\n## Error\nTypeError: Cannot read property token of undefined' | node .devtool/scripts/inbox-task.mjs --labels '["bug"]'
```

### Input: Lista de tarefas

```
- Corrigir layout quebrado no mobile
- Adicionar paginação na listagem de heróis
- Refatorar HeroCard para usar HeroAvatar
```

**Proposta:**
1. [ui] Corrigir layout quebrado no mobile
2. [feat] Adicionar paginação na listagem de heróis
3. [refactor] Refatorar HeroCard para usar HeroAvatar

### Input: Plano complexo

```
Preciso implementar cache nas imagens usando SWR no cliente.
Também quero refatorar o serviço de heróis que está muito acoplado.
```

**Proposta:**
1. [perf] Implement image cache with SWR
2. [refactor] Decouple hero service
