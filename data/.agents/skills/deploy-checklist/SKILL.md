---
name: deploy-checklist
description: Checklist de deploy antes de publicar — testes, variáveis de ambiente, backup do DB e só então publicar. Use ao fazer deploy (staging ou produção) ou quando o usuário pedir checklist de deploy.
---

# Skill: deploy-checklist

## Objetivo

Garantir que todo deploy siga a **ordem obrigatória**: rodar testes → checar variáveis de ambiente → fazer backup do DB → publicar. Evita publicar com testes falhando, env incompleto ou sem backup.

## Quando usar

- O usuário pede checklist de deploy, pré-deploy ou "o que fazer antes de publicar".
- O usuário vai fazer deploy (staging ou produção) e quer seguir um fluxo padronizado.
- Revisão de pipeline de CI/CD ou script de deploy.

## Como aplicar

1. **Consultar o checklist** em `docs/deploy-checklist.md`.
2. **Executar na ordem:**
   - **1. Testes** — Rodar suite de testes do projeto (unitários, integração, E2E). Não prosseguir se falhar.
   - **2. Variáveis de ambiente** — Verificar presença (e, se possível, validar) de: `DATABASE_URL`, secrets (`SECRET_KEY`, API keys), `DEBUG=false` em prod, hosts e serviços (cache, e-mail, storage).
   - **3. Backup do DB** — Executar backup imediatamente antes do deploy (ex.: `pg_dump`, `mysqldump` ou snapshot do provedor). Guardar em local seguro com nome/data.
   - **4. Publicar** — Staging primeiro; depois produção. Executar comando de deploy (ex.: `vercel deploy`, `git push`, script do projeto).
3. **Automatizar quando possível:** usar o script `scripts/deploy-staging.sh` com as variáveis descritas em `scripts/README-deploy.md` (configurar `RUN_TESTS_CMD`, `REQUIRED_ENV_VARS`, `DATABASE_URL`/`STAGING_DATABASE_URL`, `PUBLISH_CMD`).

## Regras

- Nunca publicar com testes falhando.
- Nunca pular a checagem de variáveis críticas do ambiente.
- Backup do DB deve ser feito **antes** de publicar, não depois.
- Em produção, preferir aprovação manual após validar staging.

## Referência

- Checklist completo: `docs/deploy-checklist.md`
- Script e variáveis: `scripts/README-deploy.md`, `scripts/deploy-staging.sh`
