---
title: Guard qualifier precision — W1-W5 robustness follow-ups
status: shape
source: hackathon-2 Wave 2a (todo no-dangling-guard-qualifier-precision; #71 verify Deferred to TODO)
started: 2026-07-19T16:04:46Z
completed:
verdict:
score:
worktree:
issue: "#75"
pr:
---

Time budget: 1h15m. Harden the mislocated-canonical-mod resolver shipped in #71 against future
content: W1 bare `override` qualifier over-broad; W2 logical-unit scan stops at self-contained
list-item starts; W3 broaden qualifier allowlist (if present / falls back to / defaults to the
plugin copy); W4 `|| true` on grep -c at check-no-dangling.sh:300; W5 fixture cases 6/7 named
for what they exercise. THIS ENTITY IS TICK-DISPATCHED (hackathon-2 live proof of the hardened tick).

## Acceptance criteria

**AC-1 — Precision.** W1+W2+W3 fixed: the qualifier match is scoped/proximity-bound, the unit scan
respects list-item boundaries, the allowlist covers the three named phrasings; each with a RED
fixture that previously mis-fired.
Verified by: extended test-check-no-dangling.sh red-then-green per case.

**AC-2 — Robustness.** W4+W5 fixed (pipefail-safe grep -c; fixtures renamed to match behavior).
Verified by: suite run + fixture names greppable.

**AC-3 — No regressions.** Full local gate green (both envs).
Verified by: dual-env run output.
