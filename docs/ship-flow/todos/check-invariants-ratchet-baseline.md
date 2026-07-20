---
tid: check-invariants-ratchet-baseline
captured_at: 2026-07-20T00:00:00Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/bin/check-invariants.sh]
suggest_done_type: code
entity: null
---

Ratchet/baseline mechanism for checker-strengthening PRs — resolves the structural hostage
problem PR #80 exposed (a checker improvement blocked by OTHER entities' pre-existing revealed
debt). NOT the rejected grandfather pattern: a dated, itemized known-violations baseline with
(1) monotonic-decrease enforcement (gate fails if baseline GROWS or a new violation appears),
(2) every baseline entry MUST cite a filed todo/entity (burn-down has an owner),
(3) burn-down visible in rollup/debrief. Captain-approved direction 2026-07-20. Priority: after
R1/R2 (they block the live finale; this blocks future corpus-honesty work).
