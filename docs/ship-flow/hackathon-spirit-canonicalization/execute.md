# hackathon-spirit-canonicalization — Execute

## RED → GREEN Evidence

### Task 1 — INVARIANTS.md Time-Box Discipline subsection

**Edit**: Inserted `### Time-Box Discipline` subsection under `## FO Discipline`
immediately before the closing `---` that leads to `### Principle 9`.

**AC verification**:
```
$ grep -n "time_budget\|75%\|brake" plugins/ship-flow/INVARIANTS.md
413:**Rule**: Every entity MUST carry a `time_budget` field ...
416:- **75% consumed** — warn in-channel ...
418:- **100% consumed (brake fires)** — park the entity ...
422:**Verification is never optional**: the 100% brake scope-cuts tasks ...
426:**Precedent (hackathon-2, 2026-07-20)**: two time-box brakes fired ...
430:2026-07-20-01 "2 time-box brakes").
432:**Format constraint**: `time_budget` must use the scheduler-parseable ...
437:**Tier**: judgment (Tier-B). The 75%/100% enforcement seam is prose ...
438:enforcement (scheduler warning hook, check-invariants `time_budget` presence check) ...
```
All three terms (`time_budget`, `75%`, `brake`) hit with exact semantics and
park-not-compress wording.

### Task 2 — docs/ship-flow/README.md Feature Template + Field Reference

**Edit 2A**: Added `time_budget:` line after `score:` in Feature Template frontmatter.

**Edit 2B**: Added `time_budget` row after `score` row and before `worktree` row in
Field Reference table.

**AC verification**:
```
$ grep -n "time_budget" docs/ship-flow/README.md
104:| `time_budget` | string | Budget in `<N>h<N>m` format (e.g. `2h30m`). ...
261:time_budget:
```
Both the Field Reference row (line 104) and the Feature Template field (line 261) are
present.

## Gate Suite Results

| Gate | Result |
|------|--------|
| `check-invariants.sh` | PASS — all C1–C17 checks OK |
| Node test suite (`node --test bin/*.test.mjs`) | PASS — 79/79 |
| `test-check-version-triple.sh` | PASS — 5/5 |
| `test-check-no-dangling.sh` | PASS — 12/12 |
| `test-scheduler-runner-adapter.sh` (time_budget cases) | PASS — all 14 time_budget-specific cases pass |

**Pre-existing failures**: `test-scheduler-runner-adapter.sh` reports 33 passed / 13 failed.
The 13 failures (exit_class, sentinel, TICK_ID tests) are pre-existing on `main` — confirmed
by running the same test against the unmodified main branch (same 13 failures, zero new
regressions introduced by this change).

## Deviations

None. All edits match plan.md specs verbatim. No test additions required (docs-only).

## Commit

`d41f1ed` — execute(hackathon-spirit-canonicalization): add time-box discipline to
INVARIANTS.md + README.md
