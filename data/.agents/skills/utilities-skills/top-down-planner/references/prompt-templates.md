# Prompt Templates — Top-Down Planner

Copy-paste these templates as your internal reasoning scaffolding at each level.
Adapt variable fields marked with [BRACKETS].

---

## Level 1 — The Map

```
Act as a Software Architect and experienced self-teaching mentor.
The user wants to: [GOAL]
Current level: [beginner / some experience / intermediate]
Stack preference: [stack or "recommend the best option"]

Task:
1. List 5–8 indispensable macro stages in strict logical order.
2. For each stage: one-line summary, reason for its position, prerequisites needed.
3. Flag any stages where a missing prerequisite is a common learner trap.
4. After listing, critique: what is this plan missing? What assumption might be wrong?

Format as a Markdown table.
```

---

## Level 2 — The Compass

```
For Stage [N] — [Stage Name] of the plan to [GOAL]:

List 3–6 sub-steps in order. For each:
- Action title (verb + noun)
- One-sentence description of what the learner does
- The concept or tool that connects this step to the next
- Estimated effort: < 1h / 1–4h / 4h+

Then: what is one thing a beginner commonly skips in this stage that causes problems later?
```

---

## Level 3 — The Manual

```
Transform sub-step [N.M] — [Sub-step Title] — into a hands-on tutorial.

Structure:
1. Why this matters (1 paragraph, no fluff)
2. Core concept explained without jargon (use an analogy if possible)
3. Step-by-step instructions with runnable code in [LANGUAGE]
4. Top 2 mistakes beginners make here and how to avoid them
5. Definition of Done: 3 concrete, observable checks the learner can perform
   to confirm they truly understand this before moving on.

Keep code examples minimal and real. No "foo/bar" placeholders — use realistic context.
```

---

## Devil's Advocate

```
Review this plan: [PASTE PLAN]

Act as a senior engineer who is skeptical of this plan.
Identify:
1. Any missing prerequisite that would block the learner mid-way
2. Any step that is ordered incorrectly
3. Any tool or technology in this plan that has a simpler modern replacement
4. Any assumption the plan makes about the learner that might be wrong

Be concise: max 3 points. No praise, only critique.
```

---

## Definition of Done Generator

```
For the skill/concept: [TOPIC]
Learner level: [beginner / intermediate]

Generate a Definition of Done with exactly 3 checks:
- One that tests understanding (can explain without notes)
- One that tests ability (can do without tutorial)
- One that tests output (running X produces Y)

Make the checks specific and unambiguous. Avoid vague language like "understands" or "is comfortable with".
```
