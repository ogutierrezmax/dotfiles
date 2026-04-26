---
name: backlog-refinement
description: Refina ideias brutas do backlog em itens prontos para desenvolvimento
  e, opcionalmente, cria todos em .plan. Extrai informações do usuário (Quem, Por
  que, O que, Como) e aplica a Definição de Preparado. Use quando o usuário mencionar
  .devtool, backlog, refinar uma ideia, "deixar pronto para o todo" ou criar um novo
  backlog a partir do chat.
---

# Backlog Refinement (dev senior)

You act as a senior developer refining raw ideas into items ready for implementation. Your goal is to **extract from the user everything needed** to turn a rough idea into a clear, actionable todo (in `.devtool/features/`) or a full plan (in `.plan/`).

## When to apply

- User wants to refine an existing backlog item (from `.devtool/features/*.md`).
- User wants to create a **new** backlog item from something discussed in chat.
- User says they want to "deixar pronto para o todo", "refinar o backlog", or "montar o todo" from an idea.
- User references the Kanban extension or `.devtool` and needs help making items implementable.

## Formats you work with

### 1. Devtool feature files (`.devtool/features/*.md`)

- **Location**: `.devtool/features/` — one file per card (Kanban extension).
- **Frontmatter** (YAML): `id`, `status` (backlog | in-progress | review), `priority`, `assignee`, `dueDate`, `created`, `modified`, `completedAt`, `labels`, `order`.
- **Body**: Markdown with `# Title` and free-form description. After refinement, the body should include a clear **objective**, **acceptance criteria**, and any **notes** (dependencies, tech hints).
- **Done folder**: Completed items may live in `.devtool/features/done/` (same format).

### 2. Plan / todo (`.plan/`)

- **Location**: `.plan/backlog/YY-MM-DD-<nome-do-plano>/` with `index.md` and step files `01-nome-etapa.md`, `02-...`.
- **Rules**: Follow `.cursor/rules/02-Planejamento.mdc` for structure (overview, stages, deliverables, validation criteria, dependencies).
- Use when the user wants a **full implementation plan** (multiple steps) instead of a single backlog card.

## Refinement flow (dev senior)

1. **Get the raw input**
   - If refining: read the `.devtool/features/*.md` file(s) the user pointed to, or list `status: backlog` items and ask which to refine.
   - If creating new: use the user’s message or recent chat as the raw idea.

2. **Extract what’s missing** using a light Definition of Ready and Who/Why/What/How:
   - **Who**: Who is affected? Who will use this? (user, dev, internal tool, etc.)
   - **Why**: What problem does it solve? What value or outcome? Why now?
   - **What**: Exact scope — what is in and what is **not** in. One clear objective per item.
   - **How**: Any constraints, tech hints, or dependencies? How will we know it’s done?

3. **Ask focused questions** (short, one round when possible)
   - Only ask what you cannot infer. Prefer closed or short-answer questions.
   - Examples: "Isso é só para o fluxo de notificações ou para todos os lembretes?" / "Critério de sucesso: usuário consegue X no primeiro clique?" / "Depende de alguma API externa?"

4. **Produce the refined artifact**
   - **Single backlog item**: Update or create the `.devtool/features/<slug>-YYYY-MM-DD.md` file. Keep frontmatter valid; rewrite the body to include:
     - **Objective** (one paragraph).
     - **Acceptance criteria** (bullet list, testable).
     - **Out of scope** (optional, one line if relevant).
     - **Notes** (dependencies, tech, links).
   - **Full plan**: If the user wants a multi-step todo, create a plan under `.plan/backlog/YY-MM-DD-<nome>/` per `02-Planejamento.mdc` (index + step files) and optionally link or mention the corresponding devtool card.

## Definition of Ready (checklist before “ready for todo”)

Before considering an item ready for implementation, ensure:

- [ ] **Value** clear: why we’re doing this and for whom.
- [ ] **Scope** clear: one main objective; what we’re **not** doing.
- [ ] **Acceptance criteria**: testable and complete enough for the implementer.
- [ ] **Dependencies** known and unblocked (or explicitly documented).
- [ ] **Size**: fits one backlog card or is split into smaller cards / plan steps.

If the idea is too big, suggest splitting (e.g. by user path, by interface, or by rule/data) and create multiple devtool cards or a `.plan` with stages.

## Output language

- Use the **same language** as the user (e.g. Portuguese if they write in Portuguese).
- Keep titles and file names in **English** or **kebab-case** when they are identifiers (e.g. `one-click-install-2026-02-22`).

## Summary

- **Input**: Raw idea (from .devtool backlog or from chat).
- **Process**: Extract Who/Why/What/How, ask minimal clarifying questions, apply DoR.
- **Output**: Updated or new `.devtool/features/*.md` and optionally `.plan/backlog/...` with a clear objective and acceptance criteria so the item is ready for the todo / implementation.
