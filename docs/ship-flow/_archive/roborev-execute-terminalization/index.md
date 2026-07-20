---
title: Terminalize the stuck roborev entity (#80 fix-first)
status: done
source: captain batch approval 2026-07-20 (ticket 3 of 5; fix-first decision for PR #80)
started: 2026-07-20T05:33:47Z
completed: 2026-07-20T06:43:31Z
verdict: passed
score:
worktree:
issue: "#88"
pr: pr-merge:89
archived: 2026-07-20T06:43:31Z
---

The historical entity roborev-migration-receipt-merge-semantics (flat file on origin/main) has been stuck in status: execute since 2026-07-13 with a vanished worktree (dir and branch both gone), no issue anchor, and no pre_mortem — its corpus state is what main's check-invariants CI rejects, keeping PR #80 red. Captain decision (fix-first): repair the historical entity honestly — shape judges whether to backfill required fields and complete it, or archive it as parked with correct terminal state — so #80's invariants check turns green and auto-merge arms. Never an allowlist/checker exclusion (captain rejected fake-allowlist).

## Acceptance criteria

**AC-1 — Main's corpus passes check-invariants with roborev terminalized.**
Verified by: PR #80's invariants check green on a fresh run after the terminalization lands on main (or on #80's merged tree).

**AC-2 — The terminalization is corpus-honest.**
Verified by: the entity's final state is either a properly archived parked entity (in _archive with terminal frontmatter) or a completed entity with all checker-required fields backfilled from real history; diff shows zero checker/allowlist modifications.

## Stage Report: execute+verify+ship (FO state-op)

- DONE: archive-as-parked landed on main via PR #89 (merged 2026-07-20T06:20:02Z, merge f4de438); zero checker edits (AC-2 diff evidence: one file move + frontmatter + postscript + CI paths fix under captain exact-target grant 「準」)
- DONE: AC-1 verified — PR #80 invariants went green on the post-merge re-run and #80 auto-merged 2026-07-20T06:23:54Z (captain decision #4 flow)
- DONE: muscat-v1 corpus mirrored (archive parity with main)

### Summary
FO state-op per shape.md: no worker, no product code. Bonus findings shipped en route: invariants workflow now triggers on docs/ship-flow/** (corpus-checker bypass hole closed, captain-granted); doc_impact event-payload-freeze rerun trap documented (empty-commit retrigger). Verdict PASSED.
