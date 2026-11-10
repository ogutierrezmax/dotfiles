# AGENTS.md — Next.js / React / TypeScript Template

Copy this template and adjust for your project. Delete sections that don't apply.
A shorter, accurate file outperforms a comprehensive, generic one.

```markdown
# Project Name

Next.js 15 (App Router), React 19, TypeScript 5.x (strict), Tailwind CSS v4,
Drizzle ORM, PostgreSQL 16, Bun.

## Commands

- `bun run dev` — Dev server (port 3000)
- `bun run build` — Production build with type checking
- `bun run test` — Full Vitest suite
- `bunx vitest run src/path/to/file.test.ts` — Single test file
- `bun run lint` — ESLint with auto-fix
- `bun run typecheck` — TypeScript type checking (tsc --noEmit)
- `bun run db:push` — Push Drizzle schema changes to database
- `bun run db:generate` — Generate Drizzle migrations

## Architecture

- /src/app/            App Router pages and layouts (Server Components by default)
- /src/components/     Shared React components (named exports, PascalCase files)
- /src/lib/            Utilities, DB client, helper functions
- /src/lib/db/         Drizzle schema definitions and migrations
- /src/actions/        Server actions (all mutations go through here)
- /src/store/          Zustand stores (client-side state only)
- /public/             Static assets (images, fonts, etc.)

## Code Style

- Named exports only. No default exports except page.tsx and layout.tsx.
- Server Components by default. Add 'use client' only for interactivity.
- Tailwind CSS for all styling. No CSS modules, no styled-components.
- Zod schemas for all form validation and API input validation.
- Route Segment Config for revalidation, dynamic behavior.
- Error boundaries at each route segment level (error.tsx).

## Rules

- All database access through Drizzle ORM in server components or server actions.
- Never fetch data in client components — pass props from server components.
- Mutations go through server actions in /src/actions/, never API routes.
- Environment variables via NEXT_PUBLIC_ prefix only for client-safe values.
- Never commit .env.local or .env.production files.
- Do not modify drizzle.config.ts without asking — it affects all environments.
- /src/legacy/ contains deprecated code — do not modify or refactor.

## Testing

- Vitest with @testing-library/react for component tests.
- msw (mock service worker) for API mocking — never mock fetch directly.
- Playwright for E2E tests (separate from unit tests).
- Test files co-located with source: `component.test.tsx` next to `component.tsx`.
- Run `bun run test --coverage` before marking a feature complete.
```
