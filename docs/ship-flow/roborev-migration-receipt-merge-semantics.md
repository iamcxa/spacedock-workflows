---
title: Deterministic migration receipts and merge-parent semantics
status: shape
source: "RoboRev job 40 exact-head review of C14"
started: 2026-07-13T09:46:16Z
completed:
verdict:
score:
worktree:
issue:
pr:
---

Replace heuristic entity-migration correlation with a deterministic sanctioned
contract, and define merge-parent semantics that validate resolution-only status
changes without re-requiring receipts for transitions inherited unchanged from
another parent.

## Acceptance criteria

**AC-1 — Entity migration identity is deterministic rather than content-similarity based.**
Verified by: a mechanically validated migration receipt or stable identity contract accepts intentional path/ID migrations and rejects ambiguous retirement-plus-addition histories without relying on Git rename percentage.

**AC-2 — Merge status validation distinguishes inherited state from resolution-only mutation across all parents.**
Verified by: regression fixtures cover ordinary inherited merges, an entity absent from the first parent but present in another parent, and a resolution status that differs from every parent.

**AC-3 — The C14 branch can produce a fresh exact-head RoboRev receipt with no medium-or-higher code finding.**
Verified by: targeted C14 tests, full invariant/shell/Node gates, and a `code_completion` panel whose reviewed head equals the branch head.
