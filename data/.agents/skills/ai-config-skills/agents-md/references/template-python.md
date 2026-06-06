# AGENTS.md — Python / FastAPI Template

Copy this template and adjust for your project. Delete sections that don't apply.
A shorter, accurate file outperforms a comprehensive, generic one.

```markdown
# Project Name

FastAPI 0.115, Python 3.12, PostgreSQL 16, SQLAlchemy 2.0 (async), Alembic,
Redis, Docker, uv.

## Commands

- `uv run dev` — Start dev server with hot reload (port 8000)
- `uv run pytest tests/ -v` — Full test suite
- `uv run pytest tests/unit/test_handlers.py::test_create -v` — Single test
- `uv run ruff check --fix .` — Lint and auto-fix
- `uv run ruff format .` — Format code
- `alembic upgrade head` — Run pending migrations
- `alembic revision --autogenerate -m "description"` — Create new migration
- `uv run mypy .` — Type checking

## Architecture

- /app/api/v1/           Route handlers (thin, delegate to services)
- /app/services/         Business logic layer
- /app/models/           SQLAlchemy ORM models
- /app/schemas/          Pydantic v2 request/response schemas
- /app/repositories/     Data access layer (repository pattern)
- /app/core/             Config, database session, dependency injection
- /alembic/              Database migrations (auto-generated)
- /tests/                Test suite mirroring /app/ structure

## Code Style

- Type hints on every function signature (including return types).
- Async handlers by default. Blocking operations go in background tasks.
- Pydantic v2 models for all request/response schemas — never use raw dicts.
- Repository pattern for data access: handlers call services, services call repos.
- No star imports (`from x import *`). Named imports only.
- Docstrings on all public functions (Google style).

## Rules

- Handlers must not contain business logic. Delegate to services.
- All endpoints return `{ "data": ..., "error": ..., "meta": ... }` shape.
- Dependency injection for database sessions — never create sessions in handlers.
- Redis is for caching only. Never use Redis as primary storage.
- Never modify /alembic/versions/ directly — always use `alembic revision`.
- All secrets from environment variables via pydantic-settings. Never hardcoded.
- /app/legacy/ uses sync code intentionally — do not convert to async.

## Testing

- pytest-asyncio for async tests.
- Factory Boy for test data. Never use raw fixtures or model instances.
- No mocking the database — use test database with migrations applied.
- Mock external HTTP calls with respx or responses library.
- Test file must mirror source path: `tests/api/v1/test_users.py` for
  `app/api/v1/users.py`.
```
