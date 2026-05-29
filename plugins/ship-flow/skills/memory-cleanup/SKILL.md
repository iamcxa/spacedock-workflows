---
name: memory-cleanup
description: "Use when the project MEMORY.md grows past its budget (SessionStart size warning, or captain notices bloat) — measures against the budget, classifies entries against the 6-gate rubric, proposes a prune/consolidate matrix for captain review, and applies after approval."
user-invocable: true
argument-hint: "[--measure-only] [--snapshot-dir <path>]"
---

# Memory Cleanup

## Overview

`memory-cleanup` is the repeatable entry point for pruning + consolidating the project MEMORY.md when it bloats. It codifies the manual T1-2 (prune) + T2-5 (cluster consolidation) process that produced a 34KB → 11KB reduction, so future cleanups do not re-invent the flow.

Command:

```text
/ship-flow:memory-cleanup [--measure-only] [--snapshot-dir <path>]
```

This skill is the EXECUTION organ. Detection is already handled elsewhere (see Scope discipline). Invoke it when detection fires or when you want a measured status report.

## Scope discipline (read first)

This skill is deliberately minimal — **manual-invoke only, zero hooks, zero auto-trigger**. The rationale (do not rebuild this):

- **Detection already exists**: SessionStart loads MEMORY.md into context and the host surfaces a size warning when it is large. That warning is what triggers a cleanup; this skill does not duplicate detection.
- **Bloat root-cause already blocked**: the global MEMORY Quality Rubric (`~/.claude/CLAUDE.md` → "MEMORY Quality Rubric") Pre-write Protocol gates undisciplined append at write time. Future bloat accrues slowly, not silently.
- **No hard-block hook**: a write-blocking budget hook risks interrupting a debug peak (captain's standing concern). The budget is a forcing function via the SessionStart warning + this skill, not a write gate.

An auto-trigger (run at /ship end when size > warn) was considered and DEFERRED — see "Known future hardening". Building it now would be machinery for a problem (captain forgets to clean) that the SessionStart warning already mitigates.

## Budget source

Thresholds live in the project memory policy file (`<project-memory-dir>/_policy.md`), not hardcoded here, because they are project-specific (a micro project and a monorepo want different budgets). At authoring time the spacedock-ui policy is:

| Tier | Bytes | Meaning |
|---|---|---|
| Warn | > 24KB | cleanup recommended |
| Cleanup signal | > 28KB | next cleanup should consolidate, not just trim |
| Hard stop | > 30KB | grandfather clause: only prune / consolidate / policy-pointer edits until back under budget |

Always read the live `_policy.md` rather than trusting this table.

## Flow

### 1. Measure

```bash
MEM=<project-memory-dir>/MEMORY.md
wc -c "$MEM"
```

Report current size vs the `_policy.md` tiers. With `--measure-only`, stop here (status report, no changes).

### 2. Snapshot before any destructive op

MEMORY dir is NOT git-tracked — no rollback without a snapshot. Before pruning:

```bash
SNAP=${SNAPSHOT_DIR:-.context/memory-snapshots}
mkdir -p "$SNAP"
tar -cf "$SNAP/memory-snapshot-pre-cleanup-$(<timestamp>).tar" -C <project-memory-dir> .
# plus a plain MEMORY.md copy + a `wc -c` manifest of all topic files
```

(Pass timestamps in; do not rely on `date` inside scripted workflow runs.)

### 3. Classify (only if over warn, or captain forces)

Walk each MEMORY entry + topic file against the global rubric's 6 Entry Quality Gates (Generality, Broad Coverage, Actionable Specificity, Decontextualized, Self-contained, Mode Coverage). Per entry assign one verdict:

| Verdict | Action |
|---|---|
| PASS | keep verbatim |
| WARN-edit | strip incident noise (entity IDs / SHAs / dated counts), keep the claim |
| DELETE | apply Pruning Rule; **must name surviving authority** (archive tombstone / canon promotion / backref repair) OR explicitly assert "no surviving authority needed" — silent DELETE is rejected |
| CONSOLIDATE | fold into a cluster topic file per `_policy.md` taxonomy; each cluster file must satisfy Gate 6 ([do] + [avoid] complementary) |

Entry-by-entry (not gate-by-gate) — gates interact. Write the verdict matrix to `.context/` for captain review (this is the T1-2-classification.md / T2-5-cluster-matrix.md pattern).

### 4. Captain review (gate before destructive ops)

Present the matrix. Captain MUST review:
- every DELETE (irreversible; no git tracking) + its named surviving authority
- every CONSOLIDATE cluster boundary

PASS / WARN-edit are auto-accepted (recoverable). Do NOT apply any DELETE or file-move before captain sign-off.

### 5. Apply + integrity pass + dual-count

After sign-off:
1. Apply WARN-edits, DELETEs, consolidations with explicit-pathspec discipline (see the `parallel-session-git.md` topic file in the project memory dir).
2. **Integrity pass**: every MEMORY link resolves; no surviving entry depends on a deleted one; no active canon (SKILL.md / project CLAUDE.md) references a renamed/deleted topic file. Repair refs in the same change (atomic rename = required `rg` evidence first).
3. **Dual-count report**: bytes removed by low-value deletion vs bytes moved into topic files — track separately so consolidation does not hide bloat (getting under budget ≠ memory got better).

## Relationship to other skills

- **Detection**: SessionStart host warning (not this skill).
- **Prevention**: global rubric Pre-write Protocol (write-time gate, not this skill).
- **Promotion**: `harvest-decide` (success-mode candidates → canon; different input source).
- **Execution**: THIS skill (bloat → prune/consolidate).

## Known future hardening (do NOT build until evidence demands)

- **Auto-trigger at /ship end** (size > warn OR ≥N entities since last cleanup → emit a nudge). Trigger to build: captain repeatedly misses the SessionStart warning and MEMORY bloats past hard-stop unattended across multiple sessions. Until then, manual invoke + SessionStart warning suffice.
- **Cleanup cadence counter** (`entities since last cleanup` in `_policy.md`). Trigger to build: the same as above, if a count-based signal proves more reliable than the size-based warning.

Each note names its own build-trigger — the real evidence bar, not the idea.

## Exit contract

Success: pre/post size, deleted-bytes vs moved-bytes dual count, topic-file count delta, snapshot path, integrity-pass result.

Measure-only: current size vs budget tiers, recommendation (clean / no-action).

Blocked: snapshot write fails → do NOT prune. Captain rejects matrix → leave MEMORY unchanged, report.

## Common mistakes

| Mistake | Correction |
|---|---|
| Pruning without a snapshot | MEMORY dir is untracked; tar snapshot first or you cannot roll back |
| Silent DELETE on byte-delta alone | Every DELETE names a surviving authority or asserts none needed |
| Optimizing to get under budget | Track deleted vs moved separately; consolidation can hide bloat |
| Renaming a topic file without ref check | `rg` the old filename across active canon; repair refs atomically |
| Building the auto-trigger hook now | Deferred — SessionStart warning already covers detection |
