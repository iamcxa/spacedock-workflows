---
title: Missing canonical mods — author or de-reference (both tiers)
status: shape
source: hackathon-2 Wave 2c (todo missing-canonical-mods-both-tiers; rra shape discovery)
started: 2026-07-19T16:04:46Z
completed:
verdict:
score:
worktree:
issue: "#77"
pr:
---

Time budget: 1h00m. architecture-canon.md and some canonical-doc-sync.md references resolve in
NEITHER plugin nor adopter tier. Decide per reference: author the missing mod (only if its content
is genuinely load-bearing and recoverable from context) or reconcile/remove the dangling reference.
Extend the resolver/denylist so this class is mechanically guarded.

## Acceptance criteria

**AC-1 — Every named reference resolves or is removed.** No reference to architecture-canon.md /
canonical-doc-sync.md points at a nonexistent file in either tier; decisions recorded per reference.
Verified by: the discovery grep from rra shape returns only resolving references.

**AC-2 — Class guarded.** check-no-dangling (or equivalent) catches this missing-everywhere class.
Verified by: synthetic fixture red, repo green.

**AC-3 — Suite green both envs.**
Verified by: dual-env run output.
