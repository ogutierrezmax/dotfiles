---
name: tasks
description: Decompõe uma User Story em tarefas técnicas executáveis, ordenadas e específicas (INVEST).
---

# Skill: tasks

## Purpose

Break a "ready to do" user story into **executable, ordered tasks** that a developer can pick up and complete independently. Makes the story Small and Estimable (INVEST).

## When to use

Apply **after** `user-story` and `acceptance-criteria` are complete. This skill is **optional** — apply it when:
- The story has non-trivial implementation steps that benefit from being made explicit.
- The story touches multiple layers (frontend, backend, database, infra).
- The team needs estimation anchors.

**Skip this skill when** the story is trivial (single-layer change, obvious implementation, < 1 day of work).

**NEVER invoke when** the User story or Acceptance criteria are missing — complete those first.

## How to apply

1. **Re-read the User story, Objective, and Acceptance criteria.** Identify all distinct work units.

2. **Identify the layers involved:** UI, API, business logic, data/DB, infra, tests, documentation, etc.

3. **Write tasks** following these rules:
   - Each task is a **single, independently completable unit of work** (one person, one session if possible).
   - Tasks must be **actionable** — start with a verb: "Implementar", "Criar", "Configurar", "Adicionar", "Escrever", "Revisar", etc.
   - Tasks must be **specific** — describe what to do, not just the layer (not "Backend" but "Criar endpoint POST /orders/confirm que...").
   - **Order matters** — list tasks in a logical execution order (dependencies first).
   - Include **test tasks** when relevant (unit tests, integration tests, e2e).

4. **Quality checklist** before returning:
   - [ ] Each task is actionable and specific.
   - [ ] Tasks are ordered by dependency.
   - [ ] At least one task covers testing (if non-trivial).
   - [ ] No task is so large it would take more than 1–2 days solo.
   - [ ] Tasks together cover all acceptance criteria.

## Format

```markdown
## Tasks

1. [Verb] [specific description of the task.]
2. [Verb] [specific description of the task.]
3. [Verb] [specific description of the task.]
```

## Example

**User story:** Como usuário logado, quero receber um e-mail de confirmação ao concluir uma compra para ter certeza de que meu pedido foi registrado.

**Tasks:**

1. Criar template de e-mail HTML com campos: número do pedido, itens, valor total e data estimada de entrega.
2. Implementar serviço de envio de e-mail (`OrderConfirmationMailer`) que recebe `orderId` e `userId` como entrada.
3. Integrar `OrderConfirmationMailer` ao evento `checkout.completed` no backend.
4. Implementar lógica de retry: até 3 tentativas com intervalo de 5 minutos em caso de falha no envio.
5. Adicionar log de falha definitiva quando todas as tentativas são esgotadas.
6. Escrever testes unitários para `OrderConfirmationMailer` cobrindo: envio bem-sucedido, falha com retry e falha definitiva.
7. Escrever teste de integração para o fluxo completo (checkout → e-mail enviado).

## NEVER invoke when

- User story or Acceptance criteria are missing.
- The feature is trivial and tasks would just restate the obvious.
- The user explicitly requested only user story + acceptance criteria (no tasks).
