---
title: Make shape-confirm/allocate-id instance-aware
status: shape
source: todo shape-confirm-instance-awareness (pitch 1 harvest)
started: 2026-07-12T13:48:06Z
completed:
verdict:
score:
worktree:
issue:
pr:
---

`plugins/ship-flow/lib/shape-confirm.sh` and `lib/allocate-id.sh` ignore the workflow README's `id-style` declaration (this instance declares `id-style: slug`; allocate-id insists on numeric ids — exit 10 hit live in pitch 1), write the legacy vocabulary `status: sharp` at 3 sites (pitch 1 needed a sharp→shape reconciliation commit, 695adde, x4 occurrences), and never absorb an existing flat entity into folder layout (pitch 1 migrated four captain-written ACs by hand, then retired the flat file manually). WHO pays: every adopter whose instance README deviates from the tooling's baked-in assumptions — the confirm ceremony either hard-fails or silently writes vocabulary the status scanner rejects.

## Acceptance criteria

**AC-1 — id-style is read from the instance README, not assumed.**
Verified by: shape-confirm/allocate-id on an `id-style: slug` fixture instance completes without exit 10; regression test per id-style.

**AC-2 — zero legacy `sharp` writes.**
Verified by: `grep -rn "sharp" plugins/ship-flow/lib/shape-confirm.sh plugins/ship-flow/lib/allocate-id.sh` returns no status-writing site; scanner accepts confirm output with no reconciliation.

**AC-3 — confirm absorbs an existing flat entity.**
Verified by: fixture with a pre-existing flat `{slug}.md` (captain-authored ACs in body) — confirm migrates body content into the folder entity and retires the flat file in the same ceremony; test asserts no content loss.
