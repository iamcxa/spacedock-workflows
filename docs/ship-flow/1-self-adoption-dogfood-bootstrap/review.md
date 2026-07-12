# Self-adoption dogfood bootstrap — canonical docs + doc-impact gate — Review

## Canonical Docs Update

| Doc | Outcome |
| --- | --- |
| ARCHITECTURE.md | Updated — commit `e51ed05` (T1.1, execute cycle 1) bootstrapped all 6 flow-map-schema sections (mermaid in context/containers/components), synthesized directly from plan.md's already-speced T2.x design (including the doc-impact-gate mechanism, present in the components/decisions sections). Verified current by direct read this stage against the shipped `bin/doc-impact-gate.sh` + `references/doc-coupling-map.yaml` — no further edit needed. |
| PRODUCT.md | Skipped — capabilities skeleton already flow-map-schema compliant since commit `11350a0` (pre-entity), verified by direct read this stage. The 3-row `<!-- section:capabilities -->` table's existing "Mechanical CI gates" row already covers the new checker at the capability-class level; no per-checker row precedent exists elsewhere in the table. |
| ROADMAP.md | Updated — commit `1f08020` (T1.2, execute cycle 1) moved the entity's row Next→Now. The Shipped-section flip is a merge-time action (pr-merge mod), correctly deferred past this ship stage per plan.md's Verification Spec (AC-3 row: "out of plan scope"). |

- Umbrella closeout: no — pitch id `1` has no parent umbrella above it. Shaped-child stubs `1.1`/`1.2`/`1.3` (status: shape) never independently advanced; their full T1.1/T1.2/T1.3/T2.1-T2.4 scope was executed flat under this entity's own plan/execute stage (`e51ed05`, `1f08020`, `82a6495`, `c32fa52`, `1b5dba0`, `22c3c87`, `885ea61`). No separate child ROADMAP.md rows exist to remove.

### Canonical Doc Actions Consumed

| Doc | Source | Action | Outcome | Evidence |
| --- | --- | --- | --- | --- |
| ARCHITECTURE.md | design | update | updated | `e51ed05` |
| PRODUCT.md | spec | skip | skipped | `11350a0` (pre-entity) |
| ROADMAP.md | spec | update | updated | `1f08020` |

## AC-3 Closure Evidence

This entity is the AC-3 proof: shape (2026-07-11) → design → plan → execute
(4 cycles, `e51ed05`..`d963f3c`) → verify (4 codex-gate rounds, round-4
clean, no novel findings) → this ship stage — all inside
`docs/ship-flow/1-self-adoption-dogfood-bootstrap/`.
`canonical-doc-sync-checker.sh` run against this entity dir exits 0 (Stage
Report below cites the live run).

## Release Consideration

`bin/doc-impact-gate.sh` + `references/doc-coupling-map.yaml` + the CI step
wiring (`.github/workflows/ship-flow-invariants.yml`) is new user-facing
capability (AC-2), not a patch/fix — a **minor** version bump (0.8.2 →
0.9.x) is the release candidate for the NEXT plugin release. Recorded only;
not bumped this stage — the FO/captain owns the release cut per plan.md's
scope (release mechanics were not a plan task).

## PR Readiness

Branch `spacedock-ensign/1-self-adoption-dogfood-bootstrap`, 4 execute
cycles + 4 verify cycles, 7 execute commits + 3 codex-gate-driven fix
commits. `pr-body.md` (this folder) carries the drafted PR title/body with
AC-1..AC-4 evidence citations, the 4-round codex-gate history, and the
self-application note (doc-impact-gate run against this branch's own
changed-file list). PR is prepared, not created — no push, no PR API call
this stage (HARD BOUNDARY per dispatch).
