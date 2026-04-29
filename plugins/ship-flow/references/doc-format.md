# Doc Format Reference

Shared format for ARCHITECTURE.md, PRODUCT.md, and ROADMAP.md updates. Read by ship-shape (impact blocks / ROADMAP active rows), ship-review (canonical doc sync), and `docs/ship-flow/_mods/canonical-doc-sync.md` (umbrella closeout timing).

## Tone

All entries: **third-person, present tense, factual.** No marketing language, no hedge words. State what it does, not what it "aims to" or "helps with."

```
❌ "Helps improve the session management experience"
❌ "Aims to provide better visibility into connections"  
✅ "Shows connected sessions regardless of entity count"
✅ "Prunes zombie session records on daemon startup"
```

One sentence max per entry. If it needs two sentences, the scope is too broad — split or compress.

## PRODUCT.md Formats

### Capability Bullet

```
- {What it does} — {why it matters in ≤10 words} (#{entity-id})
```

Examples:
```
- CC connection indicator — shows daemon liveness at a glance (#004)
- Zombie session prune — prevents stale records after restart (#005)
- Entity scanner multi-dir — finds entities in any workflow directory (#005)
```

**Derivation rules:**
- If shape ran → extract from User Story US-1's "I want {action}" clause
- If shape didn't run → extract from `## Problem`'s first sentence, rewrite as capability
- Always end with `(#{entity-id})`
- For umbrella pitches, write one parent-level capability when the aggregate shipped result changes the product surface; do not write one bullet per shaped child unless the child was independently product-visible.

## ARCHITECTURE.md Formats

### Architecture Patch

`ARCHITECTURE.md` is updated only from `architecture-impact` or an equivalent durable architecture change discovered at review.

Update when the shipped work changes:
- system structure, container/component boundaries, data-flow contracts, storage/API contracts, or ADR-worthy constraints
- cross-child aggregate architecture in an umbrella pitch

Skip when the shipped work changes only:
- prompt text, tests, stage reports, ROADMAP/PRODUCT prose, or local workflow documentation with no durable architecture effect

Every skip must be explicit in `## Canonical Docs Update`.

### User Story (JTBD format)

```
As {persona from PRODUCT.md Who It Serves}, I want {action}, so that {outcome}
```

**Derivation rules:**
- If shape ran → copy accepted stories verbatim from `## Shape Output`
- If shape didn't run → generate ONE story from `## Problem` + `## Done Criteria`:
  - Persona: match from PRODUCT.md's "Who It Serves" table (default: Captain)
  - Action: from Done Criteria's primary observable change
  - Outcome: from `## Problem`'s "why it matters"

Example (S-size, no shape):
```
## Problem: entity-scan.ts hardcodes docs/build-pipeline/, dashboard shows 0 entities for ship-flow

→ As Captain, I want the dashboard to find entities in any workflow directory, so that ship-flow entities appear without reconfiguring the scanner
```

## ROADMAP.md Formats

### Now Row (written by ship-shape)

```
| {slug} | {S/M/L} | {one sentence from ## Problem — what's broken, not what to build} | {today YYYY-MM-DD} |
```

Examples:
```
| entity-scanner-multi-dir | S | Dashboard shows 0 entities because scanner only looks in docs/build-pipeline/ | 2026-04-18 |
```

**Rule:** "Why now" describes the PAIN, not the SOLUTION.

### Shipped Row (written by ship-review)

```
| {id} | {title} | {one sentence — what it does now, present tense} | {date} | {outcome emoji} |
```

Outcome emojis:
- ✅ confirmed working (manual or automated verification)
- ⏳ shipped but not yet verified in production
- ❌ shipped but known regression (link to follow-up entity)

Examples:
```
| 005 | Entity scanner multi-dir | Finds entities in any commissioned workflow directory | 2026-04-18 | ⏳ |
```

**Rule:** "Why it existed" uses present tense (it still exists). Describe the capability, not the bug.

### Umbrella Shipped Row

For `pattern: pitch`, `entity_type: epic`, or parent entities with `children[]`, write the `Shipped` row once when the final child ships or during the first follow-up PR after discovering the omission.

```
| {parent-id} | {parent title} | {one sentence — aggregate capability now shipped} | {date} | {outcome emoji or PR ref} |
```

Do not add separate shaped-child rows unless those children had independent ROADMAP rows.

### Not Doing Row

```
| {idea} | {one sentence — why rejected, present tense reasoning} |
```

**Rule:** Reason must be refutable. "Not needed" is too vague. "3 人團隊不需要 multi-tenant auth" is specific — someone could argue "we grew to 10 people" and revisit.

## Cross-Document Consistency

| Field | ROADMAP.md | PRODUCT.md |
|-------|-----------|------------|
| Feature name | Shipped table "Feature" column | Capability bullet first clause |
| Why | Shipped "Why it existed" | Capability bullet "why it matters" clause |
| Entity ref | Shipped "#" column | Capability bullet `(#id)` suffix |

These three fields describe the same thing in different formats. If they diverge → the writer made an error. ship-review should cross-check after writing both.

## North Star Consistency

PRODUCT.md `## Vision` and ROADMAP.md `> North Star:` must be identical text. If either is updated, both must update. ship-review checks this at Step 4 and warns if they diverge.
