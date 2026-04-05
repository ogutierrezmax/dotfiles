# Skill: clarification

## Purpose

Execute a **clarification loop** on a vague feature idea to reach a documented, shared understanding before writing user stories and acceptance criteria. This skill is a thin wrapper: it delegates to the `request-clarifier` agent and returns its output unchanged, ensuring a single source of truth for the CLARIFY/PROCEED format.

## When to use

Apply this skill as the **first step** of the k1-refinement flow. The calling agent (k1-refinement) **always** delegates to the request-clarifier; the decision to return PROCEED or CLARIFY is the request-clarifier's. Do not skip this step based on the caller's judgment — when the input already contains a clarified summary or markers, the request-clarifier will recognize them and return PROCEED quickly.

## How to apply

1. **Assemble the input** for `request-clarifier`:

   ```
   Feature idea: [the original idea or file content]
   User answers so far: [none | 1-A, 2-B, ...]
   Round: N of 5
   Task: Clarify this feature idea so it can be turned into a ready-to-do specification.
   ```

2. **Delegate to `request-clarifier`** (via `mcp_task` with `subagent_type: request-clarifier` or equivalent).

3. **Return the result unchanged** to the calling agent:
   - If `STATUS: CLARIFY` → the calling agent must surface the questions to the user, collect answers, and re-invoke with `Round: N+1`.
   - If `STATUS: PROCEED` → extract the `Clarified summary` and pass it as the sole input to the `user-story` skill.

## Loop rules

| Aspect | Rule |
|---|---|
| **Max rounds** | 5. After round 5, the request-clarifier returns PROCEED with best interpretation. |
| **Question format** | Multiple choice (≤ 3 options + escape) when options are known; open-ended for discovery. |
| **Stop condition** | (1) Intent resolved; (2) User explicitly confirms; (3) Round 5 reached. |
| **Output on exit** | A `Clarified summary` — the single input for subsequent skills. |

## Output

Returns exactly what `request-clarifier` returns — either:

```markdown
## STATUS: CLARIFY
[questions for the user]

## Instructions for the parent
[re-invocation instructions]
```

or:

```markdown
## STATUS: PROCEED

## Clarified summary
[2–4 sentences: actor, goal, scope, success condition]

## Suggested next step
Apply skill user-story with this summary as input.
```

Em fluxos de refinement (k1), o request-clarifier **deve** sugerir apenas esse tipo de próximo passo ("Apply skill user-story with this summary as input" ou equivalente). **Não** deve sugerir "Implementar as alterações", "Implement Y" nem qualquer passo que implique editar código, scripts ou agentes — isso evita que o pai ou o clarifier deleguem por engano a um agente de implementação.

## NEVER invoke when

- The calling agent is performing a partial action (e.g., "only write acceptance criteria for this story") — in that case, skip directly to the relevant skill.

When the input already has `Clarified summary:`, `STATUS: PROCEED`, or `Entrada já clarificada: sim`, the **caller must still delegate** to the request-clarifier; the clarifier will recognize these markers and return PROCEED (no need for the caller to skip the skill).
