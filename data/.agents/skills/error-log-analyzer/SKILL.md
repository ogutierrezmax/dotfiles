---
name: error-log-analyzer
description: Analisa logs de erro na pasta error-logs/, identifica tipo e complexidade, sugere correção ou gera tasks no backlog. Use quando o usuário pedir para analisar um log, mencionar error-logs, ou quando um novo log de erro for detectado.
---

# Error Log Analyzer

## Quando usar

- Usuário pede para analisar um log de erro
- Usuário menciona `error-logs/` ou "analisa o log"
- Novo arquivo `.log` aparece em `error-logs/`
- Usuário pergunta "por que o dev falhou?"

## Ao carregar a skill

Ao receber esta skill execute imediatamente:

1. Rodar `ls -lt error-logs/*.log 2>/dev/null | head -5` para ver se existem logs
2. Se existir pelo menos um `.log` → **ler o mais recente e executar o fluxo completo** (passos 1-7) sem esperar o usuário pedir
3. Se não existir nenhum `.log` → informar "Nenhum log de erro encontrado em error-logs/" e ficar pronta

### Perguntas ao usuário

A skill **pode e deve** fazer perguntas quando faltar informação para uma análise precisa:

- **Logs anteriores**: "Quando foi a última vez que o dev rodou sem erros?" — ajuda a identificar o que mudou
- **Contexto da ação**: "O que você fez antes do erro rodar dev?" — confirma a causa raiz
- **Riscos aceitáveis**: "Posso rodar o comando X? Ele desfaz a migration no DB" — confirma antes de executar correções de risco alto
- **Prioridade**: "Isso está bloqueando você agora ou pode esperar?" — define se gera task no backlog ou resolve na hora
- **Ambiente**: "O erro aconteceu em dev, staging ou produção?" — muda a gravidade e os riscos

Não presumir intenção do usuário. Se o log não tem informação suficiente para identificar a causa raiz, perguntar antes de sugerir uma correção.

## Fluxo de análise

### 1. Encontrar o log

```bash
ls -lt error-logs/*.log | head -5
```

- Se houver vários, pegar o mais recente
- Se usuário especificar um arquivo, usar esse

### 2. Ler e extrair informações

Ler o log completo. Extrair:

| Campo | Como identificar |
|-------|-----------------|
| **Timestamp** | Nome do arquivo: `YYYY-MM-DD_HH-MM-SS__comando.log` |
| **Comando** | Linha `Cmd:` no header |
| **Package que falhou** | Linhas com `Failed:`, ` exited (1)`, `ELIFECYCLE` |
| **Mensagem de erro** | Linhas com `Error:`, `ERROR`, `FAILED`, `error` |
| **Stack trace** | Linhas subsequentes à mensagem de erro |

### 3. Classificar complexidade

**Simples** — correção direta em 1 passo:
- Variável de ambiente faltando
- Porta já em uso
- Syntax error / tipo TypeScript
- Arquivo não encontrado
- Comando não encontrado

**Complexa** — precisa de múltiplos passos:
- Migration do Prisma falhou (P3009, P3010)
- Dependência circular
- Erro intermitente / race condition
- Múltiplos packages afetados
- Erro em build/CI sem causa clara

### 4. Identificar a causa raiz

Antes de sugerir qualquer correção, **explicar qual mudança ou ação causou o problema**:

- **O que mudou desde a última vez que funcionou?** (git diff, migrations recentes, novos packages)
- **Qual ação do usuário precedeu o erro?** (rodou `pnpm run dev`, adicionou migration, mudou .env)
- **Qual é a cadeia causal?** — conectar a ação ao erro:
  - "Você adicionou a migration `20260613000000_add_hero_tags` mas ela falhou no Supabase porque..."
  - "O `pnpm install` adicionou um package que depende de Node 20, mas você está no 18..."
  - "A porta 3000 já estava ocupada porque o processo anterior não foi killado..."

Formato da explicação:
```
CAUSA RAIZ: <ação/mudança> → <consequência técnica> → <erro visível>
```

Exemplo:
```
CAUSA RAIZ: Migration 20260613000000_add_hero_tags foi aplicada mas falhou no Supabase
→ Prisma bloqueia novas migrations (P3009) → dev não sobe
```

### 5. Investigar e classificar riscos

ANTES de listar riscos, a skill DEVE investigar o estado real do sistema. Riscos sem evidência são inúteis.

#### 5.1 Investigar

| Tipo de correção | O que investigar | Como |
|-----------------|-----------------|------|
| Migration Prisma | O que a migration cria/detela | `cat prisma/migrations/<nome>/migration.sql` |
| Migration Prisma | Se objetos já existem no DB | `SELECT table_name FROM information_schema.tables WHERE table_name = 'X'` |
| Migration Prisma | Se migration foi aplicada parcialmente | `SELECT finished_at, logs FROM _prisma_migrations WHERE migration_name = 'X'` |
| Migration Prisma | Se outros packages usam a tabela | `grep -r "nome_tabela" packages/*/src/` |
| Porta em uso | Se o processo é nosso | `lsof -i :PORTA` |
| Package não encontrado | Se foi buildado | `ls packages/<pkg>/dist/index.js` |
| Tipo TypeScript | Se o package dependente mudou | `git diff packages/<pkg>/src/` |

Se não conseguir rodar a query/comando (ex: sem acesso ao DB), **perguntar ao usuário** para rodar e colar o resultado. Não presumir o estado.

#### 5.2 Classificar com base na investigação

**Risco confirmado** (evidência prova que é real):
- Listar com a evidência concreta (output da query, diff, etc.)
- Dar comando de como evitar ANTES de aplicar a correção
- Dar comando de reversão SE algo der errado
- Dar checkpoint para verificar se deu certo

**Risco descartado** (evidência prova que NÃO é problema):
- Não listar na análise final
- Explicar brevemente por que não se aplica

**Risco não verificável** (sem acesso ao dado):
- Perguntar ao usuário para rodar a verificação
- Não assumir nem positivo nem negativo

#### 5.3 Formato da análise

```
INVESTIGAÇÃO:
- <o que foi verificado e o que foi encontrado>
- <output da query/comando>

RISCOS CONFIRMADOS:
- 🔴/🟡/🟢 <risco específico>
  Evidência: <output que prova o risco>
  Como evitar: <ação preventiva antes de aplicar>
  Como reverter: <comando exato para desfazer>
  Checkpoint: <onde parar e verificar se deu certo>

RISCOS DESCARTADOS:
- <risco> — descartado porque <evidência>
```

Exemplo com investigação:
```
INVESTIGAÇÃO:
- Li migration.sql: cria tabela "hero_tags" com colunas id, hero_id, tag
- Query: SELECT finished_at FROM _prisma_migrations
  WHERE migration_name = '20260613000000_add_hero_tags';
  → finished_at = NULL (migration nunca completou)
- Query: SELECT table_name FROM information_schema.tables
  WHERE table_name = 'hero_tags';
  → 0 rows (tabela não existe no DB)

RISCOS CONFIRMADOS:
- 🟡 Médio: Migration pode ter criado objetos parcialmente
  Evidência: finished_at = NULL mas migration.sql existe
  Como evitar: Verificar se há triggers/views dependentes antes
  Como reverter: Se rollback causar problema, re-aplicar com
    npx prisma migrate resolve --applied "20260613000000_add_hero_tags"
  Checkpoint: Rodar `npx prisma db pull` e comparar schema

RISCOS DESCARTADOS:
- Perda de dados na tabela hero_tags — descartado porque tabela não existe no DB
- Dependências de outros packages — descartado porque grep não encontrou referências
```

**Sempre** mostrar investigação + riscos antes do comando. Se risco alto, pedir confirmação.

### 6. Ação

**Se simples:**
- Primeiro mostrar a causa raiz (passo 4)
- Depois mostrar a investigação e riscos (passo 5)
- Se risco alto → pedir confirmação antes de executar
- Dar o comando de correção

**Se complexa:**
- Primeiro mostrar a causa raiz (passo 4)
- Depois mostrar a investigação e riscos (passo 5)
- Gerar task em `.devtool/features/backlog/` com causa raiz, investigação e riscos documentados
- Filename: `YYYY-MM-DD-HHMMSS-slug-do-erro.md`
- Usar formato padrão (ver abaixo)
- Informar ao usuário que a task foi criada

### 7. Pós-correção: Auditar e limpar

Depois de aplicar a correção (seja simples ou complexa), **sempre** executar a auditoria antes de apagar o log:

1. **Rodar o comando que falhou** para verificar se passou:
   - Se o erro era no `pnpm run dev` → rodar `pnpm run dev` (ou o subcomando específico)
   - Se o erro era de migration → rodar `pnpm run db:deploy`
   - Se era de build → rodar `pnpm run build`
   - Se era de types → rodar `pnpm run typecheck`
   - Se era de lint → rodar `pnpm run lint`

2. **Checar se não há erros novos**:
   ```bash
   ls -lt error-logs/*.log 2>/dev/null | head -3
   ```
   - Se um log **novo** apareceu após a correção → **não apagar** o log original, pois o problema persiste ou mudou
   - Se nenhum log novo → prosseguir

3. **Se tudo OK** (comando passou sem erro, nenhum log novo):
   ```bash
   rm error-logs/<nome-do-arquivo>.log
   ```
   - Informar ao usuário: `✅ Log <arquivo> removido — erro corrigido com sucesso`

4. **Se ainda falhar**:
   - **Nunca** apagar o log
   - Re-analisar o novo erro
   - Informar ao usuário que a correção não resolveu

## Formato da task (backlog)

```markdown
---
id:
name: "YYYY-MM-DD-HHMMSS-slug-do-erro"
status: "backlog"
priority: "high"
assignee: null
dueDate: null
created: "YYYY-MM-DDTHH:MM:SS.000Z"
modified: "YYYY-MM-DDTHH:MM:SS.000Z"
completedAt: null
labels: ["bug", "<contexto>"]
order: ""
---

# <Título claro do problema>

## Contexto

<O que estava fazendo quando ocorreu o erro>

## Problema

<Descrição técnica do erro com base no log>

## Causa Raiz

```
CAUSA RAIZ: <ação/mudança> → <consequência técnica> → <erro visível>
```

## Riscos da Correção

### Investigação
- <o que foi verificado e o que foi encontrado>

### Riscos confirmados
- 🔴/🟡/🟢 <risco>
  Evidência: <output da query/comando>
  Como evitar: <ação preventiva>
  Como reverter: <comando exato>
  Checkpoint: <onde verificar>

### Riscos descartados
- <risco> — descartado porque <evidência>

## Critérios de Aceite

- [ ] <Correção aplicada>
- [ ] <Teste verifying>
- [ ] <Docs/atualização se necessário>

## Passos

1. <Passo específico>
2. <Passo específico>

## Log de referência

`error-logs/<nome-do-arquivo>.log`
```

## Regras

- **Nunca** editar o log original
- **Nunca** apagar um log sem antes rodar a auditoria (passo 7)
- **Sempre** mostrar o trecho relevante do erro quando explicar
- Se o erro já existir em logs anteriores, mencionar que é recorrente
- Prioridade padrão: `high` para erros que bloqueiam dev, `medium` para warn
- Labels: usar `["bug", "<package>"]` — ex: `["bug", "database"]`, `["bug", "prisma"]`

## Referência

- Padrões de erro comuns: `reference.md`
- Logs: `error-logs/`
- Backlog: `.devtool/features/backlog/`
