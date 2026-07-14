---
title: Refresh root README stale compatibility claims
status: shape
source: todo root-readme-stale-claims (pitch 1 harvest)
started: 2026-07-12T13:48:06Z
completed:
verdict:
score:
worktree:
issue: "#22"
pr:
---

Root `README.md` still claims a 0.7.0 adoption gap and spacedock 0.22.0 compatibility; reality as of 2026-07-12 is ship-flow 0.9.0 and spacedock 0.25.x, and PRODUCT.md (created in pitch 1) now carries the canonical positioning the README duplicates ad hoc. WHO pays: adopters and onboarding readers who trust the front-door doc — root README is the first file a new adopter reads, and both of its load-bearing claims are two-plus versions stale. Note the version claims in root README are NOT covered by `scripts/check-version-triple.sh` (that gates plugin.json / marketplace.json / plugin README H1 only), so nothing mechanically prevents recurrence.

## Acceptance criteria

**AC-1 — no stale version claims in root README.**
Verified by: grep for `0.7.0` / `0.22.0` (and any hardcoded version prose) returns nothing, or every remaining version string matches the current release.

**AC-2 — positioning prose defers to PRODUCT.md instead of duplicating it.**
Verified by: README positioning section links PRODUCT.md; no paragraph-level duplication (reviewer check against PRODUCT.md sections).

**AC-3 — recurrence is gated, not hoped away.**
Verified by: root README version claims covered by an existing mechanical gate (version-triple extension, doc-coupling row, or an explicit rejected-with-reason record in shape.md if gating is judged not worth it).
