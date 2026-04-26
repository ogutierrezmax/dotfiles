---
name: eslint-fix-all
description: Orquestra a correção paralela do ESLint usando subagentes. Executa o
  ESLint, constrói uma fila de todos os problemas (erros E avisos), despacha um subagente
  por problema (até 10 simultâneos), preenche os slots conforme terminam, então reexecuta
  o ESLint e repete até que restem zero problemas. Use quando o usuário quiser corrigir
  todos os erros/avisos do ESLint, limpar problemas de lint em toda a base de código
  ou pedir para 'corrigir eslint', 'fix lint', 'limpar erros de lint', 'resolver warnings'
  ou qualquer variação de correção em massa do lint.
---

# ESLint Fix-All Orchestrator

## Your Role: Pure Dispatcher

You are a **mail carrier**. You pick up the ESLint report, turn each problem (error or warning) into a Task, deliver them to subagents, and come back for the next report.

**You use exactly TWO tools during this entire process:**

- **Shell** — to run the ESLint command
- **Task** — to dispatch subagents

**You DO NOT use any other tool.** No `Read`. No `Write`. No `StrReplace`. No `Glob`. No `Grep`. No `SemanticSearch`. No `ReadLints`. Nothing else. You never open, read, inspect, view, peek at, or look at any source file. You never need to understand the code — that's what the subagents are for.

If you feel the urge to "check" a file, "understand" the context, "verify" what a subagent did, or "look at" source code — **don't**. Re-run ESLint instead. The ESLint output is your only source of truth.

## The Loop

```
1. Shell: run ESLint → build PROBLEM QUEUE (one entry per error/warning)
2. Zero problems? → DONE
3. Dispatch first 10 problems from queue (10 parallel Tasks)
4. As each Task completes:
   - Queue still has problems? → dispatch next problem immediately
   - Queue empty? → wait for remaining active Tasks
5. All Tasks done → Shell: re-run ESLint
6. New problems? → rebuild queue, go to 3
7. Zero problems? → DONE
Max 5 ESLint runs. If problem count doesn't decrease, stop.
```

**One subagent per problem (error or warning), keep 10 workers busy at all times.** Every time a subagent completes, immediately dispatch the next problem from the queue in that same response.

### Step 1: Run ESLint and build the queue

Run ESLint with JSON output via Shell:

```bash
npx eslint . --ext ts,tsx -f json --no-error-on-unmatched-pattern 2>/dev/null || true
```

Run from the directory that contains `eslint.config.js` (in monorepos, usually the workspace dir like `client/`).

If JSON output fails, fall back to the project's own lint command and parse the human-readable output from the Shell result.

From the output, build a **problem queue** — one entry per individual error or warning:

```
Error 1: /path/Foo.tsx line 12:5 — error — 'x' is defined but never used (@typescript-eslint/no-unused-vars)
Error 2: /path/Foo.tsx line 45:10 — warning — Unexpected any (@typescript-eslint/no-explicit-any)
Error 3: /path/Bar.ts line 8:1 — error — 'util' is defined but never used (@typescript-eslint/no-unused-vars)
...
```

Tell the user: "ESLint encontrou **N problemas** (X errors, Y warnings). Despachando subagents (10 paralelos)..."

### Step 2: Dispatch the initial wave

Take the first 10 problems from the queue and dispatch them **all in a single message** (10 parallel Task calls). Each Task fixes **one single problem**. Use `subagent_type: "generalPurpose"` and `model: "fast"`. Use this prompt — fill in the placeholders:

---

> Fix this single ESLint problem.
>
> **File:** `{filePath}`
> **Error:** Line {line}:{col} — {message} (`{ruleId}`)
>
> **How to approach:**
>
> 1. Read the file and understand the surrounding code — what does this function/component do, what types flow through it, what patterns does the file use.
> 2. Fix the error in a way that is **idiomatic and consistent** with the existing code. The fix should look like a senior developer wrote it, not like an automated tool patched it.
> 3. Prefer the **correct specific type** over `unknown` or `as any`. If a variable is a `string[]`, type it as `string[]`, not `unknown`. Infer from usage.
> 4. Do NOT introduce workarounds, suppress comments, or type casts that just silence the linter. Fix the actual problem.
> 5. Change ONLY what is needed to resolve this error — do not refactor, rename, or restructure unrelated code.
>
> Respond with one line: what you changed.

---

### Step 3: Keep the pool full

When Task results come back, you get them in groups (Cursor returns completed Tasks together). For **each response you receive**:

1. Note how many Tasks just completed
2. Check how many problems remain in the queue
3. In your **same reply**, dispatch that many new Tasks (up to the number of problems remaining) to refill the pool back to 10

Every message you send should include new Task dispatches for the next problems, until the queue is empty. Once the queue is empty, just wait for the remaining active Tasks to finish.

**Example flow with 25 problems:**

```
You:        dispatch errors 1-10   (10 Tasks)
Response:   errors 1,3,5,7 done   (4 slots open)
You:        dispatch errors 11-14  (4 Tasks, pool back to 10)
Response:   errors 2,4,11 done    (3 slots open)
You:        dispatch errors 15-17  (3 Tasks, pool back to 10)
Response:   errors 6,8,9,12,15 done (5 slots open)
You:        dispatch errors 18-22  (5 Tasks, pool back to 10)
Response:   errors 10,13,14,16 done (4 slots open)
You:        dispatch errors 23-25  (3 Tasks, queue empty, pool at 9)
Response:   remaining tasks done
→ all 25 problems processed
```

### Step 4: Re-run ESLint

Once all Tasks have completed, re-run ESLint via Shell (same command as Step 1). Compare the new problem count to the previous one:

- **Count decreased and problems remain → rebuild queue**, go to Step 2
- **Count unchanged → stuck**, report remaining problems and stop
- **Count is zero → done**

This is how you verify the subagents' work — by re-running ESLint, not by reading files.

### Step 5: Finish

Tell the user the final result:

```
Pronto! Corrigidos {total} problemas ESLint ({errors} errors, {warnings} warnings) em {files} arquivos.
```

If there are leftover errors after 5 ESLint runs, list them (from the ESLint output) for manual attention.

## Allowed Tools — Complete List

| Tool           | Allowed? | Purpose                  |
| -------------- | -------- | ------------------------ |
| Shell          | YES      | Run ESLint commands only |
| Task           | YES      | Dispatch subagents only  |
| Read           | **NO**   | Never                    |
| Write          | **NO**   | Never                    |
| StrReplace     | **NO**   | Never                    |
| Glob           | **NO**   | Never                    |
| Grep           | **NO**   | Never                    |
| SemanticSearch | **NO**   | Never                    |
| ReadLints      | **NO**   | Never                    |

## Safety Limits

- **Max 10 concurrent subagents** — always refill to 10 when slots open
- **Max 5 ESLint runs** — if after 5 re-checks there are still errors, stop
- **Stuck detection:** if an ESLint re-run shows the same or higher problem count, stop immediately
- **One problem per subagent** — each Task fixes exactly one ESLint problem (error or warning), never more
