---
title: Terminalize the stuck roborev entity (#80 fix-first)
status: draft
source: captain batch approval 2026-07-20 (ticket 3 of 5; fix-first decision for PR #80)
started:
completed:
verdict:
score:
worktree:
issue: "#88"
pr:
---

The historical entity roborev-migration-receipt-merge-semantics (flat file on origin/main) has been stuck in status: execute since 2026-07-13 with a vanished worktree (dir and branch both gone), no issue anchor, and no pre_mortem — its corpus state is what main's check-invariants CI rejects, keeping PR #80 red. Captain decision (fix-first): repair the historical entity honestly — shape judges whether to backfill required fields and complete it, or archive it as parked with correct terminal state — so #80's invariants check turns green and auto-merge arms. Never an allowlist/checker exclusion (captain rejected fake-allowlist).

## Acceptance criteria

**AC-1 — Main's corpus passes check-invariants with roborev terminalized.**
Verified by: PR #80's invariants check green on a fresh run after the terminalization lands on main (or on #80's merged tree).

**AC-2 — The terminalization is corpus-honest.**
Verified by: the entity's final state is either a properly archived parked entity (in _archive with terminal frontmatter) or a completed entity with all checker-required fields backfilled from real history; diff shows zero checker/allowlist modifications.
