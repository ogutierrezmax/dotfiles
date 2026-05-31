---
name: "@git-commit-v2"
description: 'Executa git commit com análise de mensagem convencional, staging inteligente, commits atômicos e geração de mensagem. Use quando o usuário pedir para commitar mudanças, criar um git commit ou mencionar "/commit". Suporta: (1) Detecção automática de tipo e escopo das mudanças, (2) Geração de mensagens de commit convencionais a partir do diff, (3) Commit interativo com substituições opcionais de tipo/escopo/descrição, (4) Staging inteligente com agrupamento lógico e commits atômicos.'
license: MIT
allowed-tools: Bash
---

# Git Commit with Conventional Commits

## Overview

Create standardized, semantic git commits using the Conventional Commits specification. Analyze the actual diff to determine appropriate type, scope, and message.

## Conventional Commit Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Commit Types

| Type       | Purpose                        |
| ---------- | ------------------------------ |
| `feat`     | New feature                    |
| `fix`      | Bug fix                        |
| `docs`     | Documentation only             |
| `style`    | Formatting/style (no logic)    |
| `refactor` | Code refactor (no feature/fix) |
| `perf`     | Performance improvement        |
| `test`     | Add/update tests               |
| `build`    | Build system/dependencies      |
| `ci`       | CI/config changes              |
| `chore`    | Maintenance/misc               |
| `revert`   | Revert commit                  |

## Breaking Changes

```
# Exclamation mark after type/scope
feat!: remove deprecated endpoint

# BREAKING CHANGE footer
feat: allow config to extend other configs

BREAKING CHANGE: `extends` key behavior changed
```

## Workflow

### 1. Analyze Diff

```bash
# If files are staged, use staged diff
git diff --staged

# If nothing staged, use working tree diff
git diff

# Also check status
git status --porcelain
```

### 2. Stage Files (if needed)

If nothing is staged or you want to group changes differently:

```bash
# Stage specific files
git add path/to/file1 path/to/file2

# Stage by pattern
git add *.test.*
git add src/components/*

# Interactive staging
git add -p
```

**Never commit secrets** (.env, credentials.json, private keys).

**Atomic staging**: analyze the diff and stage only files belonging to a single logical change. If multiple unrelated changes exist, perform multiple `git add` + `git commit` cycles — one per logical change.

### 3. Generate Commit Message

Analyze the diff to determine:

- **Type**: What kind of change is this?
- **Scope**: What area/module is affected?
- **Description**: One-line summary of what changed (present tense, imperative mood, <72 chars)

### 4. Execute Commit

```bash
# Single line
git commit -m "<type>[scope]: <description>"

# Multi-line with body/footer
git commit -m "$(cat <<'EOF'
<type>[scope]: <description>

<optional body>

<optional footer>
EOF
)"
```

## Best Practices & Atomic Commits

### One Logical Change Per Commit

Every commit MUST represent a single logical change. In this repository, "atomic" means one logical change per commit — ensuring a clean and revertible history.

### 🚫 Grouping Rules

- **Never** group changes to different programs/tools in the same commit (e.g., don't mix `.tmux.conf` with `.zshrc`)
- **Never** mix documentation changes with code/config changes unless they are strictly part of the same feature
- **Never** group unrelated documentation updates (e.g., don't mix "security guidelines" with "project structure")
- **Never** mix refactoring with new features or bug fixes

### ✅ Preferred Patterns

- **Configuration**: Separate commits per tool
  - `feat(kwin): update window rules`
  - `feat(tmux): improve status bar`
- **Shell**: Separate plugins from core settings if they aren't part of the same logical task
  - `refactor(zsh): cleanup plugins`
  - `fix(zsh): fix alias for grep`
- **Documentation**: One topic per commit
  - `docs(security): add encryption guidelines`
  - `docs(structure): update directory map`

### General Guidelines

- Present tense: "add" not "added"
- Imperative mood: "fix bug" not "fixes bug"
- Reference issues: `Closes #123`, `Refs #456`
- Keep description under 72 characters

## Git Safety Protocol

- NEVER update git config
- NEVER run destructive commands (--force, hard reset) without explicit request
- NEVER skip hooks (--no-verify) unless user asks
- NEVER force push to main/master
- If commit fails due to hooks, fix and create NEW commit (don't amend)
