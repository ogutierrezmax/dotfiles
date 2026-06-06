---
name: "agents-md"
description: "Creates and manages AGENTS.md files for AI coding agents. Use when the user wants to create an AGENTS.md from scratch, improve an existing one, set up agent instructions for a project, or ask about best practices for configuring AI coding agents. Triggers on phrases like \"create AGENTS.md\", \"agent instructions\", \"configure AI agent\", \"setup agent rules\", \"agent context file\", \"project rules for AI\", \"improve AGENTS.md\", \"AGENTS.md template\", \"what should go in AGENTS.md\", or when onboarding a new project in an AI-powered editor."
---
# AGENTS.md Skill — Create & Manage Agent Instructions

Create, review, and maintain `AGENTS.md` — the cross-tool standard for giving AI coding
agents project-specific context. Supported by Codex CLI, Cursor, GitHub Copilot,
Windsurf, Devin, Amp, and 15+ other tools.

---

## What is AGENTS.md?

AGENTS.md is a Markdown file in your repository root that tells AI agents about your
project: tech stack, conventions, boundaries, and exact commands. Unlike README.md
(written for humans), AGENTS.md is written for AI coding agents.

- **Cross-tool standard** — originated by OpenAI, now stewarded by the Linux
  Foundation's Agentic AI Foundation. Works across 20+ AI coding tools.
- **Plain Markdown** — no special syntax, no YAML frontmatter, no schema.
- **Proven impact** — a Princeton study of 124 PRs found AGENTS.md reduced agent
  runtime by **28.6%** and token usage by **16.6%**.
- **Concise wins** — GitHub's analysis of 2,500+ repos found shorter, specific files
  outperform long, comprehensive ones. Start at 20–35 lines.

---

## When to Use This Skill

- The user asks "create an AGENTS.md for this project"
- The user says "set up agent instructions", "configure AI agent", or "project rules for AI"
- Onboarding a new project that will be edited with AI coding tools
- Reviewing or improving an existing AGENTS.md
- The user asks about AGENTS.md best practices, format, or what to include
- The user is unsure whether to use AGENTS.md, CLAUDE.md, or .cursor/rules

---

## Core Workflow

### Step 1 — Gather Context

Before writing, determine from the user or the codebase:

- **Tech stack**: language, framework, database, ORM, testing library (with versions)
- **Build system**: npm/pnpm/bun, uv/pip, make, cargo, etc.
- **Testing setup**: test runner, how to run a single test, mocking strategy
- **Linting/formatting**: ESLint, Prettier, Ruff, Black, etc.
- **Project structure**: key directories and their responsibilities
- **Boundaries**: files/directories the agent should never modify
- **Git workflow**: branching, commit conventions, PR requirements

Infer from the codebase when possible. Only ask for what isn't obvious.

### Step 2 — Write or Update AGENTS.md

Structure the file using these six categories (proven by GitHub's analysis of 2,500+ repos):

#### 1. Stack

State the stack upfront with versions. Agents waste tokens guessing frameworks.

```markdown
## Stack
- TypeScript 5.x (strict), Next.js 15 (App Router), Tailwind CSS v4
- Database: PostgreSQL 16 via Prisma ORM
- Auth: NextAuth.js v5
- Testing: Vitest with @testing-library/react
- Deploy: Docker → AWS ECS
```

#### 2. Commands

Exact, copy-pasteable commands. Include flags. Never say "run the tests" — say the
exact command.

```markdown
## Commands
- `bun run dev` — start dev server (port 3000)
- `bun run build` — production build
- `bun run test` — full test suite
- `bunx vitest run src/path/to/test.ts` — single test file
- `bun run lint` — ESLint with auto-fix
- `bun run typecheck` — TypeScript type checking
```

#### 3. Architecture

Map directories to their responsibilities. Name technologies with versions.

```markdown
## Architecture
- /src/app/          App Router pages and layouts (Server Components by default)
- /src/components/   Shared React components (named exports)
- /src/lib/          Utilities, DB client, helper functions
- /src/lib/db/       Prisma schema and migrations
- /src/actions/      Server actions (all mutations go here)
- /public/           Static assets
```

#### 4. Code Style

Only rules that differ from language defaults — things the agent would get wrong.

```markdown
## Code Style
- Named exports only. No default exports (except page.tsx / layout.tsx).
- Server Components by default. 'use client' only for interactivity.
- Tailwind for styling. No CSS modules or styled-components.
- Zod for all form validation. Never write raw type guards.
- Error boundaries at route segment level.
```

#### 5. Rules & Boundaries

What the agent must never do. Be explicit.

```markdown
## Rules
- Never modify prisma/schema.prisma without asking — migrations are tracked.
- Never commit .env files or hardcode secrets.
- All DB access through Prisma in server components/actions only.
- Mutations go through server actions, not API routes.
- /src/legacy/ contains frozen code — do not modify or refactor.
```

#### 6. Testing

Include how to run a single test, what to mock, what not to mock.

```markdown
## Testing
- Use `bunx vitest run src/test/path --reporter=verbose` for single file
- Factory functions for test data, no fixtures
- Mock external APIs with msw (mock service worker)
- Never mock the database — use test database
```

### Step 3 — Follow the "Start Small" Principle

Begin with 20–35 lines covering what the agent would most likely get wrong. Add
sections based on real agent mistakes, not hypothetical ones.

A good heuristic: every line should contain information the agent **cannot** get from
reading your package.json, tsconfig, or existing documentation. If it's already
obvious from the code, don't repeat it.

### Step 4 — Use Subdirectory AGENTS.md for Monorepos

For large projects, place AGENTS.md files in subdirectories. The agent reads the
nearest file to the code being edited. Root-level rules apply everywhere; subdirectory
rules override for that subtree.

```
project/
├── AGENTS.md                # Shared: git conventions, CI, global stack
├── frontend/
│   └── AGENTS.md            # Frontend-specific: React patterns, component rules
├── backend/
│   └── AGENTS.md            # API-specific: route patterns, DB access rules
└── infra/
    └── AGENTS.md            # Infra-specific: Terraform conventions
```

OpenAI's own Codex repository uses **88 AGENTS.md files** across its directory tree.

---

## Best Practices

### Do: Be Specific

```markdown
❌ "Run the tests before committing."
✅ "Run `bun run test && bun run lint` before committing."
```

```markdown
❌ "Follow our coding standards."
✅ "Use snake_case for database columns. PascalCase for model names."
```

### Do: Provide Examples

Show a real code snippet that demonstrates the expected pattern:

```markdown
## Conventions
API handlers follow this pattern:
```python
@router.get("/api/v1/users/{user_id}")
async def get_user(user_id: int, db: AsyncSession = Depends(get_db)):
    user = await user_service.get_by_id(db, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    return UserResponse.model_validate(user)
```
```

### Don't: Dump Your Entire Style Guide

A 50-page coding standards doc does not belong in AGENTS.md. Extract the 10 rules
that matter most and link to the full doc for reference.

### Don't: Be Vague

"Write clean code" tells the agent nothing. "Use parameterized queries for all SQL,
never string concatenation" tells it exactly what to do.

### Do: Keep It Under 500 Lines

Every line competes for the agent's attention budget. Shorter files perform better
in controlled studies. If you need more detail, use subdirectory AGENTS.md files.

### Don't: Duplicate README Content

The follow-up Princeton research found that auto-generated AGENTS.md files that
duplicated existing README content reduced task success by 2% and increased cost
by 23%. Every line must earn its place.

### Do: Treat It Like Code

Keep AGENTS.md in version control. Review and update it during PRs. If your stack
changes (e.g., Jest → Vitest), update the file immediately. Stale instructions are
worse than no instructions.

---

## AGENTS.md vs Other Formats

| Format | Tool | When to Use |
|--------|------|-------------|
| **AGENTS.md** | Cross-tool (20+) | Shared instructions, multi-tool teams |
| **CLAUDE.md** | Claude Code only | Claude-specific features (@imports, skills, hooks, permissions) |
| **.cursor/rules/** | Cursor only | Glob-scoped rules, YAML frontmatter, alwaysApply |
| **copilot-instructions.md** | GitHub Copilot | Copilot-specific path rules |
| **GEMINI.md** | Gemini CLI | Google Gemini-specific config |

**Best practice**: put shared instructions in AGENTS.md, tool-specific config in the
native file. The Bridge Pattern: have CLAUDE.md or GEMINI.md reference AGENTS.md
as the single source of truth.

---

## Verification Checklist

After creating or updating AGENTS.md, verify:

- [ ] Stack section lists exact versions (not just "Python" but "Python 3.12")
- [ ] Commands are copy-pasteable with all required flags
- [ ] Architecture maps directories to responsibilities
- [ ] Code style only includes rules that differ from language defaults
- [ ] Boundaries are explicit about what the agent should never do
- [ ] Testing includes single-file test command
- [ ] No content duplicates README.md or package.json
- [ ] File is under 500 lines (ideally 20–50 for most projects)
- [ ] Follows the "Stack → Commands → Architecture → Code Style → Rules → Testing" structure
- [ ] Committed to version control alongside the project code

---

## Templates

See `references/` directory for ready-to-use templates:

- `template-nextjs.md` — Next.js / React / TypeScript web app
- `template-python.md` — Python / FastAPI backend
- `template-monorepo.md` — Monorepo with root + per-package AGENTS.md
