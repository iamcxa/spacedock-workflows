---
name: harvest-decide
description: "Use when adjudicating pending success-mode / failure-mode harvest candidates emitted by ship-review Step 4.5 — decide promote/merge/draft/discard per candidate and stamp the ledger. Closes the T1-3 success-mode lifecycle invariant."
user-invocable: true
argument-hint: "[--entity <id>] [--backlog]"
---

# Harvest Decide

## Overview

`harvest-decide` is the consumer of ship-review's success-mode harvest (`## What Worked` + `## What Almost Failed` blocks in `review.md`). It reads pending candidates, decides one outcome each, and records the decision in an append-only ledger. Canon files NEVER mutate before captain approval.

This is the skill named by `plugins/ship-flow/INVARIANTS.md` → "Success-mode Harvest Lifecycle" as the lifecycle closer. Without it, harvested candidates become "retrospective sediment".

Command:

```text
/ship-flow:harvest-decide [--entity <id>] [--backlog]
```

- `--entity <id>`: adjudicate only the named entity's review.md candidates (per-ship mode).
- `--backlog`: adjudicate all pending candidates across shipped entities (drift-control mode).
- no args: same as `--backlog` but report-only count first, then ask captain whether to proceed.

## Scope discipline (read first)

This skill is deliberately minimal. The success-mode harvest went live forward-only; at authoring time the pending queue is empty. Do NOT build machinery for scale that has not yet arrived. The two load-bearing guarantees are:

1. **Append-only ledger** — never silently re-process or overwrite a prior decision.
2. **Captain approval before canon mutation** — promote/merge proposals are presented, never auto-committed.

Everything else (conflict-grouping, fingerprint dedup, supersede chains, coverage thresholds) is deferred to "Known future hardening" at the bottom. Promote those notes to implementation only when real evidence (≥10 entities, an actual conflict, an actual bad-merge rollback) demands it.

## Flow

### 1. Scan

Find candidates with `Status: captured` in shipped entities' review.md:

```bash
grep -rl '^Status: captured' docs/ship-flow/*/review.md docs/ship-flow/_archive/*/review.md 2>/dev/null
```

Read each `## What Worked` and `## What Almost Failed` block. Each captured candidate has Pattern / Trigger / Action / Evidence / Destination.

`--entity <id>` narrows to one entity's review.md. `--backlog` / no-arg reads all.

### 2. Skip already-decided

Read `docs/ship-flow/success-mode-ledger.yaml`. Skip any candidate whose `(entity, section, candidate_index)` triple already has a ledger entry. The `section` component is load-bearing: a single entity can have `what-worked` candidate 1 AND `what-almost-failed` candidate 1 — without `section` in the key the second would be silently mis-skipped. (Minimal dedup — triple-key. Fingerprint drift handling is future hardening.)

**Drift guard**: do NOT renumber or reorder captured candidates in a shipped `review.md` after ledger entries exist for that entity. If a candidate's pattern text no longer matches what the ledger recorded at that `(entity, section, candidate_index)`, STOP and audit manually — do not auto-skip and do not auto-re-process. (Fingerprint-based automatic drift detection is deferred — see Known future hardening.)

### 3. Decide one outcome per candidate

For each undecided candidate, judge using the global MEMORY rubric (6 gates in `~/.claude/CLAUDE.md` → MEMORY Quality Rubric):

| Outcome | When | Requires |
|---|---|---|
| `promoted` | Pattern is a canonical rule that belongs in a SKILL.md / topic file and is NOT already there | destination canon path |
| `merged-into-canon` | Canon already materially covers this pattern | `merged_into:` canon path + one-line coverage note |
| `kept-as-draft-memory` | Reusable but not yet canon-ready | `topic_file:` (existing or `new:<slug>`) + rationale |
| `discarded` | Fails a rubric gate (incident-specific, not actionable, too narrow, already covered everywhere) | rationale naming the failed gate |

The candidate's own `Destination` field (draft-memory / promote-to-<skill> / one-off) is the author's suggestion — treat it as a prior, not a binding. Override with rationale when the rubric disagrees.

### 4. Captain checkpoint (only for canon-mutating outcomes)

- `discarded` and `kept-as-draft-memory`: low-stakes, append to ledger directly, but keep the rationale visible in the run summary (a bad discard loses institutional memory — captain should see it).
- `promoted` and `merged-into-canon`: write a proposal to `.context/harvest-proposals/<yyyy-mm-dd>.md` showing the exact canon edit. Present to captain. Apply the canon mutation ONLY after explicit approval. Use explicit-pathspec commits (see `parallel-session-git` discipline).

### 5. Stamp ledger

Append one entry per decided candidate to `docs/ship-flow/success-mode-ledger.yaml`:

```yaml
- entity: "#101"
  candidate_index: 1
  section: what-worked          # or what-almost-failed
  pattern: early-fixture-parity-check
  decision: promoted            # promoted | merged-into-canon | kept-as-draft-memory | discarded
  destination: plugins/ship-flow/skills/ship-execute/SKILL.md   # for promoted
  decided_at: "2026-05-29"
  rationale: "Canonical DC discipline, low blast radius."
```

Use `git add docs/ship-flow/success-mode-ledger.yaml` with explicit pathspec. Append under `entries:` only — never rewrite prior entries, never regenerate or sort the file (sorting would reorder history and break the append-only audit trail).

## Verification-dispatch trigger

Per INVARIANTS "Success-mode Harvest Lifecycle": when this run batches **≥5 candidates** OR any proposed outcome **reorganizes MEMORY topic taxonomy**, dispatch a fresh-context verifier (`Agent(subagent_type: spacedock:ensign)`) to check low-confidence promote/merge claims BEFORE the captain proposal. Verifier output is **findings-only** — it surfaces "claim X low-confidence because Y" / "canon location Z already covers this"; it does NOT counter-propose decisions. Author (this skill's run) retains correction judgment.

## Exit contract

Success:
- Candidates scanned / decided counts by outcome.
- Ledger entries appended.
- Canon mutations applied (count, only after captain approval) OR "none proposed".

Skip:
- No `Status: captured` candidates pending → report "nothing to adjudicate" to session, append NOTHING to ledger (the ledger records candidate outcomes, not scheduler noise).

Blocked:
- Ledger file unwritable.
- Captain rejects a proposal → leave candidate undecided (no ledger entry), report for next run.

## Known future hardening (do NOT build until evidence demands)

These were designed during T2-4 pre-discuss (codex + FO) but deliberately deferred — building them now is premature optimization for a queue that is currently empty. Promote to implementation only on real evidence:

- **Fingerprint dedup** (codex BS1): add `source_fingerprint: sha256:...` to ledger key when review.md formatting drift causes false re-processing. Trigger to build: an actual observed re-process of an already-decided candidate.
- **Conflict-grouping** (FO BS4): pre-classify step grouping candidates by proposed canon destination; surface 2-entities-disagree as a single captain decision. Trigger to build: first time two entities propose conflicting rules for the same canon scope.
- **Supersede chain** (FO BS5): `superseded_by: <ledger_id>` field so a later cycle can revise a bad promotion without silent overwrite. Trigger to build: first bad-merge rollback.
- **Strict merged-into-canon** (codex BS2): `material_coverage_threshold: verbatim|paraphrase|partial` + `gap_acknowledged:`. Trigger to build: `merged-into-canon` count exceeds promoted+discarded combined (dumping-ground signal).
- **Strict draft-memory expiry** (codex BS3): `revisit_after: <N entities>|<date>|never`. Trigger to build: draft-memory topic files accumulate without ever maturing to canon.
- **Auto-trigger counter-file hook** (FO mod 2): post-ship hook writes pending count to `.ship-flow/pending-harvest.txt`; debt tracker WARN reads it. Trigger to build: captain forgets to invoke harvest-decide and the queue grows past the INVARIANTS >10 WARN threshold.

Each hardening note names its own build-trigger so a future session knows the evidence bar, not just the idea.

## Common mistakes

| Mistake | Correction |
|---|---|
| Mutating canon before captain approval | Write proposal to `.context/harvest-proposals/`, apply only after explicit OK |
| Appending "ran, nothing pending" to ledger | Ledger records candidate outcomes only; skip silently |
| Building conflict-grouping / fingerprints now | Deferred — see Known future hardening; build on evidence not anticipation |
| Treating candidate's `Destination` field as binding | It's the author's prior; rubric judgment overrides with rationale |
| Rewriting a prior ledger entry | Ledger is append-only; future revision uses supersede chain (when that hardening lands) |
