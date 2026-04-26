---
name: user-story
description: Cria uma User Story (Como/Quero/Para) e um Objetivo de negócio a partir de um resumo clarificado (INVEST).
---

# Skill: user-story

## Purpose

Produce a high-quality **user story** and **Objective** from a clarified feature summary. Ensures the story is Valuable, Negotiable, and aligned to INVEST criteria.

## When to use

Apply after the `clarification` skill has produced a `Clarified summary`. The input to this skill must be the clarified summary — never the raw, unprocessed idea.

**NEVER invoke when** there is no clarified summary available (return to the clarification skill first).

## How to apply

1. **Read the Clarified summary** carefully. Identify:
   - **Actor**: Who benefits? (end user, admin, system, anonymous user, etc.)
   - **Goal**: What action or capability do they need?
   - **Benefit**: Why? What value does it deliver?

2. **Write the Objective** (1–2 sentences):
   - State the business/product value in plain language.
   - Avoid technical jargon. Answer: "What problem does this solve and for whom?"

3. **Write the User story** in the standard format:

   ```
   Como [ator], quero [o quê] para [benefício].
   ```

   Rules:
   - **One need per story** — do not combine multiple unrelated goals.
   - **Actor** must be specific (e.g., "usuário logado", "administrador", not "o sistema").
   - **Goal** describes the desired action or capability, not the implementation.
   - **Benefit** explains the value or outcome, not a feature description.

4. **Quality checklist** before returning:
   - [ ] The story has exactly one actor, one goal, one benefit.
   - [ ] The benefit explains *why*, not *what*.
   - [ ] The story does not prescribe implementation details.
   - [ ] The story is Testable (i.e., it is possible to write acceptance criteria for it).
   - [ ] The story fits in one sprint or work block (Small + Estimable from INVEST).

## Examples

**Input (Clarified summary):**
> Feature de notificação por e-mail para usuários logados ao completar uma compra no checkout.

**Output:**

**Objective:** Permitir que usuários logados sejam notificados por e-mail ao finalizar uma compra, confirmando o pedido e reduzindo dúvidas pós-checkout.

**User story:** Como usuário logado, quero receber um e-mail de confirmação ao concluir uma compra para ter certeza de que meu pedido foi registrado.

---

**Input (Clarified summary):**
> Dashboard de métricas de uso para o time de produto visualizar retenção semanal de usuários ativos.

**Output:**

**Objective:** Oferecer ao time de produto uma visão consolidada da retenção semanal de usuários ativos, facilitando decisões baseadas em dados.

**User story:** Como membro do time de produto, quero visualizar a retenção semanal de usuários ativos em um dashboard para identificar tendências e tomar decisões informadas sobre o produto.

## Output format

```markdown
## Objective

[1–2 sentences.]

## User story

Como [ator], quero [o quê] para [benefício].
```

## NEVER invoke when

- The clarified summary is missing or the input is still ambiguous.
- The request is only to update or rewrite acceptance criteria without changing the story.
