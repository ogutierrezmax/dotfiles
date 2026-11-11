# Padrões de Erro Comuns — reference.md

Referência rápida para o error-log-analyzer. Classificar o erro e sugerir ação.

---

## Prisma / Database

### P3009 — Migration falhou
```
Error: P3009
migrate found failed migrations in the target database
```
- **Complexidade**: Simples
- **Causa**: Migration anterior falhou e bloqueia novas migrations
- **Correção**: `npx prisma migrate resolve --rolled-back "NOME_DA_MIGRATION"`

### P3010 — Novas migrations não aplicadas
```
Error: P3010
new migrations will not be applied
```
- **Complexidade**: Simples
- **Causa**: Migrations pendentes que precisam ser rodadas
- **Correção**: `npx prisma migrate dev` (dev) ou verificar migrações pendentes

### P1001 — Não consegue conectar ao DB
```
Error: P1001
Can't reach database server
```
- **Complexidade**: Simples
- **Causa**: DB offline, `DATABASE_URL` errada, firewall
- **Correção**: Verificar `DATABASE_URL` no `.env`, checar se o Supabase está ativo

### P2025 — Record não encontrado
```
Error: P2025
Record to update not found
```
- **Complexidade**: Simples
- **Causa**: Tentativa de atualizar/deletar registro que não existe
- **Correção**: Verificar IDs, checar se dados foram populados

---

## Turbo / Build

### ELIFECYCLE — Comando falhou com exit code
```
ELIFECYCLE  Command failed with exit code 1
<package>#<task>: command exited (1)
```
- **Complexidade**: Média (depende do task)
- **Causa**: O comando do package falhou — precisa ver qual package/tarefa
- **Correção**: Rodar o comando isolado: `pnpm --filter <package> run <task>` para ver erro completo

### Package não encontrado
```
Could not resolve "<package>"
```
- **Complexidade**: Simples
- **Causa**: Package não existe, typo, ou não está no workspace
- **Correção**: Verificar `pnpm-workspace.yaml` e nome do package

---

## Portas

### Porta já em uso
```
Error: listen EADDRINUSE :::<porta>
```
- **Complexidade**: Simples
- **Causa**: Outro processo usando a mesma porta
- **Correção**: `lsof -i :<porta>` → `kill <PID>` ou usar `scripts/port-manager.mjs`

---

## TypeScript

### TS2307 — Módulo não encontrado
```
error TS2307: Cannot find module '<module>'
```
- **Complexidade**: Simples
- **Causa**: Import errado, package não instalado, falta de build
- **Correção**: Verificar import, rodar `pnpm install`, ou `pnpm run build` do package dependente

### TS2345 — Tipos incompatíveis
```
error TS2345: Argument of type 'X' is not assignable to parameter of type 'Y'
```
- **Complexidade**: Média
- **Causa**: Tipo errado, API mudou, falta de cast
- **Correção**: Verificar tipos em `packages/types`, alinhar com a interface esperada

---

## Node / Runtime

### MODULE_NOT_FOUND
```
Error: Cannot find module '<path>'
```
- **Complexidade**: Simples
- **Causa**: Arquivo não existe, path errado, ou não foi buildado
- **Correção**: Verificar path, rodar build do package

### ENOENT — Arquivo/diretório não encontrado
```
Error: ENOENT: no such file or directory
```
- **Complexidade**: Simples
- **Causa**: Path incorreto, arquivo não criado, ou diretório não existe
- **Correção**: Verificar se o arquivo/diretório foi criado, checar paths no script

---

## Docker / Infra

### Container não rodando
```
Error: connect ECONNREFUSED 127.0.0.1:<porta>
```
- **Complexidade**: Simples
- **Causa**: Serviço (DB, cache) não está rodando
- **Correção**: Verificar containers: `docker ps`, iniciar serviço necessário

---

## Classificação de Prioridade

| Prioridade | Quando |
|-----------|--------|
| `high` | Bloqueia `pnpm run dev`, build quebrado, DB inacessível |
| `medium` | Warn em CI, erro em task secundária, types não críticos |
| `low` | Lint warning, formatação, warnings de deprecação |

---

## Labels padrão

| Contexto | Label |
|----------|-------|
| Prisma/migrations | `["bug", "database"]` |
| Turbo/build | `["bug", "build"]` |
| Portas | `["bug", "infra"]` |
| TypeScript | `["bug", "types"]` |
| Scripts | `["bug", "scripts"]` |
| Docker | `["bug", "docker"]` |

---

## Exemplos de Causa Raiz

Formato: `CAUSA RAIZ: <ação> → <consequência> → <erro>`

### Prisma

| Erro | Causa Raiz |
|------|-----------|
| P3009 | `CAUSA RAIZ: Migration X foi aplicada mas falhou no DB → Prisma bloqueia novas migrations → ELIFECYCLE no migrate:deploy` |
| P3010 | `CAUSA RAIZ: Migration Y existe no disco mas não foi aplicada ao DB → Prisma detecta pendência → erro ao rodar migrate:dev` |
| P1001 | `CAUSA RAIZ: DATABASE_URL aponta para host inacessível / Supabase off → Prisma não conecta → P1001` |
| P2025 | `CAUSA RAIZ: Record deletado externamente ou ID errado → Prisma não encontra → P2025 ao atualizar/deletar` |

### Turbo / Build

| Erro | Causa Raiz |
|------|-----------|
| ELIFECYCLE | `CAUSA RAIZ: Comando dentro do package falhou (verificar qual) → turbo repassa exit code 1 → ELIFECYCLE` |
| Package não encontrado | `CAUSA RAIZ: Typo no nome do package ou não adicionado ao pnpm-workspace.yaml → turbo não resolve → erro de build` |

### Portas

| Erro | Causa Raiz |
|------|-----------|
| EADDRINUSE | `CAUSA RAIZ: Processo anterior não foi killado corretamente → porta ainda ocupada → novo dev não sobe` |

### TypeScript

| Erro | Causa Raiz |
|------|-----------|
| TS2307 | `CAUSA RAIZ: Import de package que não foi buildado / path errado → TS não resolve o módulo → erro de compilação` |
| TS2345 | `CAUSA RAIZ: API do package dependente mudou / tipo desatualizado → incompatibilidade de tipos → erro de compilação` |

### Node / Runtime

| Erro | Causa Raiz |
|------|-----------|
| MODULE_NOT_FOUND | `CAUSA RAIZ: Arquivo não existe ou não foi buildado → Node não resolve → MODULE_NOT_FOUND` |
| ENOENT | `CAUSA RAIZ: Path incorreto no script / arquivo não criado → filesystem não encontra → ENOENT` |

---

## Comandos de Investigação

Comandos concretos para verificar o estado antes de aplicar correções.

### Prisma / Database

#### O que a migration faz
```bash
# Ler o SQL da migration
cat prisma/migrations/<nome_da_migration>/migration.sql

# Ver o diff do schema que a migration representa
git diff prisma/schema.prisma
```

#### Se a migration foi aplicada
```bash
# Verificar se a migration foi completada
npx prisma migrate status --schema=packages/database/prisma/schema.prisma

# Query direta no DB (se acessível)
SELECT migration_name, started_at, finished_at, logs
FROM _prisma_migrations
WHERE migration_name = '<nome_da_migration>';
# finished_at = NULL → nunca completou
# finished_at tem valor → foi aplicada
# logs contém erro → falhou parcialmente
```

#### Se objetos existem no DB
```bash
# Verificar se tabela existe
SELECT table_name FROM information_schema.tables
WHERE table_name = '<nome_tabela>';

# Verificar colunas de uma tabela
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = '<nome_tabela>';

# Verificar se outros packages usam a tabela
grep -r "<nome_tabela>" packages/*/src/
```

#### Resolver P3009 (migration falhou)
```bash
# Se migration NÃO completou (finished_at = NULL):
npx prisma migrate resolve --rolled-back "<nome_da_migration>"

# Se migration COMPLETOU mas está marcada como falha:
npx prisma migrate resolve --applied "<nome_da_migration>"

# Verificar depois:
npx prisma migrate status
```

### Portas

```bash
# Ver quem está usando a porta
lsof -i :<porta>

# Matar processo específico
kill <PID>

# Matar todos os processos na porta
kill $(lsof -t -i :<porta>)

# Verificar se porta ficou livre
lsof -i :<porta>
```

### Package / Build

```bash
# Verificar se package foi buildado
ls packages/<pkg>/dist/index.js

# Buildar package específico
pnpm run build --filter=<pkg>

# Verificar se package existe no workspace
cat pnpm-workspace.yaml | grep <pkg>

# Rodar build de todos os packages dependentes
pnpm run build --filter=<pkg>...
```

### TypeScript

```bash
# Verificar se package dependente mudou
git diff packages/<pkg>/src/

# Rodar typecheck só no package afetado
pnpm run typecheck --filter=<pkg>

# Verificar import errado
grep -rn "from '<modulo>'" packages/<pkg>/src/
```

### Porta já em uso (EADDRINUSE)

```bash
# Identificar o processo
lsof -i :<porta>

# Se for nosso dev anterior:
kill $(lsof -t -i :<porta>)

# Se for outro processo:
# → Perguntar ao usuário se pode matar
```
