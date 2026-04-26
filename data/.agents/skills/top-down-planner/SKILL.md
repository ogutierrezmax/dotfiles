---
name: top-down-planner
description: 'Use esta skill sempre que o usuário quiser planejar, aprender ou construir
  algo que ainda não sabe como fazer. Dispara em: "me ajude a planejar", "quero aprender
  X do zero", "não sei por onde começar", "me dê um roteiro para", "como eu faria
  X". Também dispara proativamente quando o usuário declara um objetivo vago ou ambicioso
  sem um caminho de execução claro. Esta skill implementa um método estruturado de
  Decomposição Top-Down com salvaguardas integradas contra procrastinação de planejamento,
  pré-requisitos ausentes e entendimento superficial.'
---

# Top-Down Planner Skill

A recursive planning method that uses the LLM as an "Architecture Guide" to decompose
any complex goal — layer by layer — until tasks are small enough to execute immediately.

Designed especially for self-learners and solo builders who face the "I don't know what
I don't know" problem.

---

## Core Philosophy

The method has three rules:
1. **Breadth before depth** — always finish a full level before decomposing the next
2. **Prerequisites first** — every node must list what the user needs to know BEFORE tackling it
3. **Done means done** — every node must have a concrete "Definition of Done" so the user knows when to move on

---

## The Three-Level Structure

```
Level 1 — The Map       (Macro steps, the full picture)
Level 2 — The Compass   (Sub-steps + connections between stages)
Level 3 — The Manual    (Actionable tasks + code examples)
```

Only decompose to Level 3 **right before executing that specific task**. Premature
Level-3 decomposition leads to planning rot (the plan becomes obsolete before it's used).

---

## Workflow

### Step 0 — Understand the Goal

Before generating anything, ask (or infer from context):

- What is the end goal? (e.g., "build a web app", "learn Python", "deploy an API")
- What is the user's current level? (beginner / some experience / intermediate)
- What is the time horizon? (a weekend project vs. 6-month learning path)
- Is there a preferred language, framework, or stack? (if not, recommend one and justify)

If the user has already provided enough context, skip the interview and proceed.

---

### Step 1 — Generate the Map (Level 1)

Use web search to ground the plan in current, real-world best practices.

**Search before planning** when:
- The domain changes fast (e.g., frontend frameworks, AI tooling, cloud infra)
- The user mentions a specific technology you're not certain about
- You need to validate whether a tool/library is still maintained or recommended

**Prompt template you should follow internally:**

> "Act as a Software Architect. The user wants to [GOAL] at [LEVEL] level.
> List the 5–8 indispensable macro steps in strict logical order.
> For each step, write: (1) a one-line summary, (2) why this step comes here and not elsewhere,
> (3) what the user must already know before starting it."

**Output format for Level 1:**

```
## 🗺️ Map — [Goal Title]

| # | Stage | Why here | Prerequisites |
|---|-------|----------|---------------|
| 1 | ...   | ...      | ...           |
| 2 | ...   | ...      | ...           |
```

After presenting the map, **always run the Devil's Advocate check** (see below).

---

### Step 2 — Generate the Compass (Level 2)

For each Level-1 stage, generate sub-steps. Do ALL stages before going deeper.

**For each sub-step, include:**
- A short action title (verb + noun, e.g., "Configure environment variables")
- A one-sentence description of what the user will do
- The concept or technology that bridges this step to the next one
- Estimated effort (🟢 < 1h / 🟡 1–4h / 🔴 4h+)

**Output format for Level 2:**

```
### Stage [N]: [Stage Name]

- **[N.1]** Action title — description *(bridges to: [concept])* 🟢
- **[N.2]** Action title — description *(bridges to: [concept])* 🟡
- **[N.3]** Action title — description *(bridges to: [concept])* 🔴
```

---

### Step 3 — Generate the Manual (Level 3)

**Only for the task the user is about to start right now.**

Transform the specific sub-step into a step-by-step tutorial:

1. Context: why this matters
2. Concept explained simply (no jargon without definition)
3. Step-by-step instructions with real, runnable code examples
4. Common mistakes and how to avoid them
5. **Definition of Done** — a concrete, objective test the user can perform to confirm they've truly mastered this step before moving on

**Definition of Done format:**

```
✅ Definition of Done for [Sub-step title]:
- [ ] You can [observable action] without looking at a tutorial
- [ ] You can explain [core concept] in your own words
- [ ] Running [specific command or test] produces [expected output]
```

---

### Devil's Advocate Check (run after every Level 1 and Level 2 generation)

Always critique your own plan before presenting it:

> Internally ask: "What are 2–3 logical flaws in this plan? Is there a missing prerequisite?
> Is there a simpler modern tool that replaces one of these steps? Is the order truly optimal?"

Present the critique briefly to the user:

```
⚠️ Devil's Advocate:
- [Potential flaw or gap 1]
- [Potential flaw or gap 2]
- [Optional: simpler alternative if one exists]
```

---

## Anti-Procrastination Guard

If the user has been in planning mode for more than 2 levels without writing any actual
code or taking action, **pause and prompt**:

> "Temos um plano sólido. Antes de decompor mais, que tal escrever as primeiras 10 linhas
> de código? Planejamento sem execução é ficção."
> 
> ("We have a solid plan. Before decomposing further, how about writing the first 10 lines
> of code? Planning without execution is fiction.")

---

## Output Language Rule

Always respond in the same language the user used. If the user writes in Portuguese,
respond in Portuguese. If in English, respond in English. Mix only technical terms
(function names, CLI commands) that have no natural translation.

---

## Quick Reference — When to Use Each Level

| Situation | Action |
|-----------|--------|
| User has a vague goal | Go to Step 0 → Step 1 |
| User has a goal, needs structure | Go to Step 1 |
| User has macro steps, needs detail | Go to Step 2 |
| User is about to start a specific task | Go to Step 3 |
| User seems stuck in planning | Trigger Anti-Procrastination Guard |
| User asks "how do I know I'm done?" | Generate Definition of Done |

---

## Reference Files

- `references/prompt-templates.md` — Copy-paste prompt templates for each level
- `references/definition-of-done-examples.md` — Examples of good vs. bad Definitions of Done
