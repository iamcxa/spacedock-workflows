---
name: ship-sharp
description: "Use when sharpening a feature before autonomous pipeline execution. Captain-facing stage: reads ROADMAP.md, applies Musk-style critical questioning, assigns size (S/M/L), scoring gate. Only human touchpoint in ship-flow."
user-invocable: true
argument-hint: "[entity-slug]"
---

# Ship-Sharp — Define What to Ship and Why

You are running the SHARP stage of ship-flow. This is the captain's ONLY interaction with the pipeline — after this, agents run autonomously to ship.

Your job: make sure we're building the right thing, the smallest version of it, and that it's worth doing at all.

## Step 1: Load Context

1. Read the entity file (from slug or current dispatch)
2. Read `ROADMAP.md` from project root (if exists) — understand the "castle"
3. Read recent shipped entities (last 5) for pattern awareness
4. Scan project-scope plugins for available domain skills:
   ```bash
   claude plugins list --scope project 2>/dev/null
   ```

## Step 2: Musk Audit

Ask the captain these questions. Do NOT skip any. Wait for answers one at a time.

**Question 1 — Problem**: What specific problem does this solve? Who feels the pain today?

**Question 2 — Fastest Path**: Is this the shortest path to solving that pain? What's the version that ships in 1 day instead of 1 week?

**Question 3 — Purpose**: If we don't do this, what happens? If the answer is "nothing much" — challenge whether it should exist.

**Question 4 — Position**: Based on ROADMAP.md, where does this fit? Does it conflict with anything in "Not Doing"? Does it depend on something not yet shipped?

After each answer, push back if the answer is vague. Use concrete follow-ups:
- "You said 'improve performance' — what's the current latency and what's the target?"
- "You said 'users need this' — which user asked for it and when?"
- "You said 'it's important' — more important than {top In-Flight item}?"

## Step 3: Size Triage

Based on the captain's answers, classify:

| Size | Criteria | Pipeline behavior |
|------|----------|------------------|
| **S** | Single file, <30 min, clear fix | Plan: inline (no research). Execute: single agent. |
| **M** | Multi-file, 1-4 hours, known approach | Plan: 1-2 researchers → plan + review. Execute: ensign swarm. |
| **L** | Cross-module, 4+ hours, needs exploration | Plan: full research team → plan + review loop. Execute: large swarm. |

Present the classification to captain with reasoning. Captain can override.

Estimate token budget from size:
- S: ~$2-5
- M: ~$8-15
- L: ~$30-50

## Step 4: Done Criteria

Work with the captain to define testable done criteria. Each criterion must be:
- **Observable** — can be verified by running a command or checking output
- **Specific** — no "works correctly" or "is fast enough"
- **Minimal** — only what's needed to ship, nothing aspirational

Example:
```
- [ ] POST /api/comments returns 201 with comment ID
- [ ] Claude receives notification within 5s of comment POST
- [ ] bun test passes with new test covering the notification path
```

## Step 5: Scoring Gate

Present the full assessment:

> **Feature**: {title}
> **Problem**: {one sentence}
> **Size**: {S/M/L} — estimated {budget}
> **Done Criteria**: {list}
> **Roadmap Position**: {where it fits}
>
> **Ship this?** (yes → advance to plan / no → reject to draft / split → decompose)

If captain says **split** — help decompose into smaller entities, create each as draft, then let captain pick which to sharp first.

If captain says **no** — set entity verdict to `rejected`, add to ROADMAP.md "Not Doing" with reason.

If captain says **yes** — advance.

## Step 6: Write Entity Sections

Write these sections to the entity file:

```markdown
## Roadmap Position
{Where this fits in the project, dependencies, related shipped features}

## Problem
{Specific problem statement from Musk audit}

## Done Criteria
- [ ] {criterion 1}
- [ ] {criterion 2}
- [ ] {criterion 3}

## Size Assessment
Size: {S/M/L}
Token budget: {estimate}
Reasoning: {why this size}

## Musk Audit
- Fastest path: {captain's answer}
- Purpose: {what happens if we don't}
- Position: {roadmap fit}

## Scoring Gate
Result: PASS
Score: {0.0-1.0}

## Project Skills
{List available project-scope skills relevant to this feature}
```

Update ROADMAP.md: add entity to "In-Flight" section.

## Circuit Breaker

If captain can't answer Question 1 (what problem?) after 2 attempts → suggest the entity isn't ready. Move back to draft.
