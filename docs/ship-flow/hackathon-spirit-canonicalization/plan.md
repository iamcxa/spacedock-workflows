# hackathon-spirit-canonicalization — Plan

## Overview

Docs-only ticket. Two edit targets, no code changes, no test changes. The design
confirmed trivial-pass; this plan translates the design hand-off directly into
concrete inline edit specs.

---

## Task 1 — Add time-box discipline prose to `plugins/ship-flow/INVARIANTS.md`

**What**: Insert a new `### Time-Box Discipline` subsection inside `## FO Discipline`
(after the existing "Evidence discipline under an active `/goal`" subsection, which
ends at the `---` separator before line 409's `### Principle 9` heading). The
subsection is behavioral FO discipline (not a Principle-numbered architecture rule),
so `## FO Discipline` is the correct home.

**Placement anchor**: Insert immediately before the closing `---` that separates the
last FO Discipline subsection from `### Principle 9` (the `---` at approximately
line 409). The new block is self-contained and follows the existing subsection style.

**Exact prose to add** (between the separator that closes "Evidence discipline" and
the `### Principle 9` block):

```markdown
---

### Time-Box Discipline

**Rule**: Every entity MUST carry a `time_budget` field in its frontmatter (format:
`<N>h<N>m`, e.g. `2h30m`). The FO enforces two checkpoints against elapsed wall-clock:

- **75% consumed** — warn in-channel: surface elapsed vs budget, remaining scope,
  any at-risk deliverables. Do not pause or wait for captain; continue autonomously.
- **100% consumed (brake fires)** — park the entity: open findings surface (in-channel
  summary of done/remaining/blocker), cut remaining scope to a follow-up, and
  surface to the captain. NEVER compress or skip verification to fit a budget.

**Verification is never optional**: the 100% brake scope-cuts tasks, not quality gates.
If the remaining un-cut scope would require verification to be shortened, cut the scope
further until verification can run in full.

**Precedent (hackathon-2, 2026-07-20)**: two time-box brakes fired correctly across two
nights — scope was cut at 100% twice; verification was never compressed. The finale entity
was parked with findings instead of compressing verification. Debrief citation:
`docs/ship-flow/_archive/debriefs/debrief-2026-07-18-02.md` (and session debrief
2026-07-20-01 "2 time-box brakes").

**Format constraint**: `time_budget` must use the scheduler-parseable `<N>h<N>m` string
(e.g. `2h30m`, not `2.5h` or `150m`). The scheduler's `derive_timeout_sec` in
`plugins/ship-flow/lib/scheduler-runner-adapter.sh` reads this field directly; a
non-parseable value silently falls back to the 5400s default.

**Tier**: judgment (Tier-B). The 75%/100% enforcement seam is prose discipline; code-gate
enforcement (scheduler warning hook, check-invariants `time_budget` presence check) is the
`time-budget-code-gate` rabbit hole (out of scope for this ticket).
```

**AC verification (at verify stage)**:
```sh
grep -n "time_budget\|75%\|brake" plugins/ship-flow/INVARIANTS.md
```
Must hit all three terms with exact brake semantics and the park-not-compress wording.

**TDD contract**: No test addition needed. No shell test pins INVARIANTS.md prose;
`check-invariants.sh` enforces numbered-Principle DCs and section-tagging, neither of
which constrains new FO Discipline subsection text. Proof: `grep -rn "time.box\|75%"
lib/__tests__/` → zero hits.

---

## Task 2 — Add `time_budget` to `docs/ship-flow/README.md` Feature Template + Field Reference

**What**: Two coordinated edits to docs/ship-flow/README.md:

### Edit 2A — Feature Template block (around line 251)

Current template frontmatter:
```yaml
---
title: Feature name here
status: draft
source:
started:
completed:
verdict:
score:
worktree:
issue:
pr:
---
```

Add `time_budget:` after `score:`:
```yaml
---
title: Feature name here
status: draft
source:
started:
completed:
verdict:
score:
time_budget:
worktree:
issue:
pr:
---
```

**Format note**: leave the value blank in the template (the captain fills it in at
shape/dispatch time). The field must use `<N>h<N>m` syntax (e.g. `2h30m`) so the
scheduler's `derive_timeout_sec` can parse it.

### Edit 2B — Field Reference table (around line 94)

Current table ends with:
```
| `pr` | string | GitHub PR reference — set when the entity's branch opens a PR |
```

Add a new row for `time_budget` after `score` and before `worktree`:

| Field | Type | Description |
|-------|------|-------------|
| ... existing rows ... |
| `score` | number | Priority score, 0.0–1.0 (optional) |
| `time_budget` | string | Budget for this entity in `<N>h<N>m` format (e.g. `2h30m`). At 75% consumed the FO warns in-channel; at 100% the brake fires (park + surface + cut scope). Verification is NEVER compressed to fit a budget. |
| `worktree` | string | Worktree path while a dispatched agent is active, empty otherwise |
| ... |

**Exact row to insert** (after the `score` row, before the `worktree` row):
```
| `time_budget` | string | Budget in `<N>h<N>m` format (e.g. `2h30m`). At 75% consumed the FO warns in-channel; at 100% the brake fires: park + surface + cut scope. Verification is NEVER compressed to fit a budget. Parsed by `scheduler-runner-adapter.sh` `derive_timeout_sec`. |
```

**AC verification (at verify stage)**:
Template section diff shows `time_budget:` field; field reference table has matching
row with one-line semantics pointer.

**TDD contract**: No test addition needed. The field's runtime behavior (`time_budget`
→ timeout derivation) is already covered by `lib/__tests__/test-scheduler-runner-adapter.sh`
(pins `2h30m`→9000s + edge cases). This edit adds the documentation column only; no new
code path is introduced. Proof: `grep -rn "time_budget" lib/__tests__/` → existing
scheduler test already pins format + derivation.

---

## Canonical Doc Actions

### Files Updated (this ticket)

| File | Action | Rationale |
|------|--------|-----------|
| `plugins/ship-flow/INVARIANTS.md` | UPDATE — add `### Time-Box Discipline` subsection under `## FO Discipline` | AC-1: time-box rules must be repo-canonical in the FO-contract surface |
| `docs/ship-flow/README.md` | UPDATE — add `time_budget:` to Feature Template + Field Reference table | AC-2: new entities must be born with budget slots in the authoritative task template |

### Files Skipped (explicit rationale)

| File | Rationale |
|------|-----------|
| `plugins/ship-flow/README.md` (plugin README) | Not the task template surface; doc-coupling-map couples this file to `references/*.yaml` and `skills/ship-*/SKILL.md` changes — neither applies here. No coupling row moves with this change. |
| `doc-sync` / any SKILL.md | No skill contract changes; doc-sync is only needed when a SKILL.md or schema/reference file changes (per doc-coupling-map srcGlob). |
| Any new standalone learnings file | Explicitly rejected: AC-3 pins distill-into-existing-canon; creating a new file would be canon fragmentation. |
| `references/*.yaml` schemas | No schema change; `time_budget` is an already-live frontmatter field. |
| `bin/check-invariants.sh` | Code-gate for `time_budget` presence enforcement is the `time-budget-code-gate` rabbit hole — explicitly out of scope. |

---

## Test Addition Rationale

**No test additions or moves needed.** This is a docs-only change:

1. No shell test pins INVARIANTS.md prose — `check-invariants.sh` enforces numbered
   Principle DCs and section counts; new `## FO Discipline` prose is unconstrained.
2. No shell test pins the docs/ship-flow/README.md template or field table prose.
3. The `time_budget` runtime contract (format parsing, timeout derivation) is already
   pinned by `lib/__tests__/test-scheduler-runner-adapter.sh` — that test does not need
   to move or change.
4. `doc-impact-gate.sh` will not fire: neither `INVARIANTS.md` nor `docs/ship-flow/README.md`
   is a coupling srcGlob in `references/doc-coupling-map.yaml`.

The plan confirms: **zero new test vectors, zero test moves.**

---

## Execution Order

1. Edit `plugins/ship-flow/INVARIANTS.md` — insert Time-Box Discipline subsection
   under `## FO Discipline`, after the "Evidence discipline under an active `/goal`"
   subsection's closing `---`.
2. Edit `docs/ship-flow/README.md` — two coordinated edits: Feature Template + Field
   Reference table row.
3. Run AC-verification greps (from shape) to confirm both edits land cleanly.
4. Commit.
