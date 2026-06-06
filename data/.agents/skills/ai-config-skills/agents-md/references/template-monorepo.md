# AGENTS.md — Monorepo Template

Monorepos benefit from multiple AGENTS.md files — one at root for shared rules,
then per-package files for package-specific context. This template shows both.

---

## Root AGENTS.md

Place at `project-root/AGENTS.md`:

```markdown
# Project Name — Monorepo

Turborepo, pnpm workspaces, TypeScript 5.x (strict).
Apps: Next.js 15 (frontend), Express (API). Packages: shared UI, DB, types.

## Root Commands

- `pnpm dev` — Start all services in parallel
- `pnpm build` — Build all packages
- `pnpm test` — Run all test suites
- `turbo run test --filter=@app/api` — Test single package
- `pnpm lint` — Lint all packages
- `pnpm typecheck` — TypeScript type checking across all packages

## Repository Structure

- /apps/web/         Next.js frontend — see `apps/web/AGENTS.md`
- /apps/api/         Express API — see `apps/api/AGENTS.md`
- /packages/ui/      Shared React component library
- /packages/db/      Drizzle schema, migrations, shared DB client
- /packages/types/   Shared TypeScript types and interfaces
- /packages/config/  Shared ESLint, TypeScript, Tailwind configs
- /tooling/          Turborepo pipeline configurations

## Root Rules

- Shared types in @app/types. Never duplicate type definitions across packages.
- Import shared packages by name: `import { Button } from "@app/ui"`.
- Never use relative paths to import across package boundaries.
- DB schema changes require migrations in both dev and test databases.
- Run `pnpm typecheck` before pushing — type errors block CI.
- Each package has its own AGENTS.md for package-specific rules.
```

---

## Per-Package AGENTS.md — Frontend

Place at `apps/web/AGENTS.md`:

```markdown
# Frontend — Web App

Next.js 15 (App Router), React 19, Tailwind CSS v4, TypeScript 5.x.

## Package Commands

- `pnpm dev --filter=@app/web` — Dev server (port 3000)
- `pnpm test --filter=@app/web` — Vitest suite
- `pnpm lint --filter=@app/web` — ESLint

## Conventions

- Server Components by default. 'use client' only for interactivity.
- Page components are async — fetch data directly, no getServerSideProps.
- Shared UI components from @app/ui — never duplicate in this package.
- All API calls go through @app/api-client, never raw fetch.
- Named exports only. Default exports only for page.tsx and layout.tsx.

## Boundaries

- Do not access the database from this package. Use server actions or API routes.
- This package owns nothing in /packages/. Import only.
```

---

## Per-Package AGENTS.md — API

Place at `apps/api/AGENTS.md`:

```markdown
# API — Express Backend

Express 5, TypeScript 5.x, Drizzle ORM, PostgreSQL 16.

## Package Commands

- `pnpm dev --filter=@app/api` — Dev server (port 4000)
- `pnpm test --filter=@app/api` — Vitest suite
- `pnpm lint --filter=@app/api` — ESLint

## Conventions

- Controllers are thin — delegate to service layer.
- All DB access through @app/db package. No direct queries in controllers.
- Request validation with Zod schemas defined in each route file.
- Error handling through express-async-errors + centralized error middleware.

## Boundaries

- Do not import from @app/ui or @app/web. This is a backend package.
- All mutations require request validation + authorization checks.
- Never expose raw database errors to clients — wrap in ApiError.
```
