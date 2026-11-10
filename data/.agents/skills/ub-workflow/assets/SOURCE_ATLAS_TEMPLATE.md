# Source Atlas

This file routes source-code work before agents read implementation files. It is seeded once by `ub-workflow` bootstrap from visible project roots and then maintained when source boundaries change.

## First-Read Order

For non-trivial source work:

1. Root `AGENTS.md`.
2. `.ub-workflows/status.md`.
3. `SOURCE_ATLAS.md`.
4. Nearest relevant folder `AGENTS.md` when one exists.
5. Selected source files and tests.
6. `.ub-workflows/vision.md` only when product direction matters.

Do not read unrelated folder guidance unless the task crosses that boundary.

## Map Use Rule

Module maps are routing aids, not source truth. Use them to choose files to open first, then inspect source and tests with fast local search before changing behavior. If source ownership changes, update this atlas in the same change.

## Detected Source Routes

- `tests/`: start at `tests/`.
- `docs/`: start at `docs/AGENTS.md`.
- `scripts/`: start at `scripts/`.

## Workflow Route

- Workflow state, waves, discoveries, initiatives, sprints, and source packs: start at `.ub-workflows/WORKFLOW_ATLAS.md`, then `.ub-workflows/AGENTS.md`.

## Local Guidance Policy

Local `AGENTS.md` files should answer only what the folder owns, when work starts there, local boundaries, what to inspect before editing, likely tests, and what to avoid. Add local guidance only when a folder has a meaningful responsibility boundary, rule set, or repeated navigation cost.

## Source Route Note

Before editing, identify the owning folder, local guidance read, expected source files, expected tests, and boundaries intentionally avoided.

## Maintenance

Update this file and the nearest relevant folder `AGENTS.md` when a change adds, removes, renames, or moves a source boundary, plugin lane, public API area, runtime/protocol/host responsibility, major package, or test topology.
