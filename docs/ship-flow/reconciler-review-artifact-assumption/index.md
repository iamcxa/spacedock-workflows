---
title: Fix reconciler review-artifact validation
status: verify
issue: "#83"
worktree: .worktrees/spacedock-ensign-reconciler-review-artifact-assumption
started: 2026-07-20T02:00:03Z
---

Tick reconcile of every merged entity blocks with closeout-review-missing: the reconciler demands review.md but this workflow's 8-stage taxonomy folds review into verify — the closeout validation must accept the workflow's actual artifact set (verify.md as review-bearing) or read the stage taxonomy. Evidence: l3/rra/missing-canonical-mods reconcile-blocked beats 2026-07-19 19:26-20:10 in controller events log. Blocks Phase-A auto-closeout for ALL merged entities.

Time budget: 1h15m. Fix reconciler artifact-required predicate so the workflow's actual per-stage artifacts (`verify.md` for review-bearing content, `ship.md` for canonical-doc closeout) satisfy the terminal-closeout precondition WITHOUT requiring `review.md`. Scope is `merged-pr-closeout-reconciler.sh` predicate + receipt schema only; NO changes to C14 completion contract or RoboRev semantic-review gate.

## Acceptance criteria

**AC-1 — Predicate accepts the workflow's actual artifact set.** `reconcile_direct_bundle` and `reconcile_pull_request_bundle` no longer hard-`reject_input closeout-review-missing` when `review.md` is absent; a merged entity with `verify.md` + `ship.md` (this workflow's produced set) passes the pre-closeout gate.
Verified by: RED fixture (entity with `verify.md`+`ship.md`, no `review.md`) exits `closeout-review-missing` today, exits PROCEED after the fix; existing fixtures with both `review.md`+`ship.md` still exit PROCEED (no regression).

**AC-2 — Receipt schema stays coherent.** The D1 receipt's `source_hashes` block no longer embeds a mandatory `review` hash; when `review.md` is absent, either the field is omitted OR the schema records the actual review-bearing artifact (`verify.md`) with an explicit key so `proof_hash` remains deterministic and reviewable.
Verified by: test-closeout-receipt.sh (or a targeted subset) still passes; a new assertion pins the review-absent receipt shape byte-for-byte.

**AC-3 — Failure surface stays fail-closed elsewhere.** `ship.md` remains required (it is the source of `## Todo Closeout Digest` and the ship_rel bundle output — see reconciler line 1148-1153); a merged entity missing `ship.md` still exits `closeout-ship-missing`. `## Canonical Docs Update` continues to gate via `canonical-doc-sync-checker.sh` (which already accepts `review.md` OR `ship.md`, line 60-66) — that checker is out of scope.
Verified by: RED fixture (no `ship.md`) still exits `closeout-ship-missing`; canonical-doc-sync-checker.sh unchanged.

**AC-4 — Suite green both envs.** Full local gate green under the 129-file standalone loop AND CI mode (`CI=true`).
Verified by: dual-env run output.

## Shape

**Size:** S. **Time budget:** 1h15m. **Captain articulation:** hackathon-2 GO + bulk attestation 「原則上是都核准」(2026-07-20) applied to this backlog batch; not re-asked.

### Source of truth: the reconciler with the check DOES NOT live on `iamcxa/muscat-v1`

The bug reconciler is `ship-flow@0.9.0` (2171 lines), installed at `/Users/kent/.claude/plugins/cache/spacedock-workflows/ship-flow/0.9.0/bin/merged-pr-closeout-reconciler.sh` and vendored on the `ship-flow-scheduler-controller` worktree at `plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh`. It is **NOT** on `iamcxa/muscat-v1` — the muscat-v1 tree's reconciler is the pre-0.9.0 458-line version with no artifact check at all (`git log -S closeout-review-missing`: adds on commits `bdbbf96` "feat(ship-flow): make optional closeout sentinel-first" and `2424b9d` "feat(ship-flow): reconcile direct closeout atomically", both on `main`, absent from muscat-v1). **Execution prerequisite:** the fix must land on the code branch that actually runs during ticks (main / scheduler-controller lineage), not on muscat-v1 — plan/execute MUST base the code worktree accordingly, else the fix ships to a file the running scheduler never invokes.

### AC verification (all four REAL — none already-satisfied)

**AC-1 — REAL, empirically reproduced.** `merged-pr-closeout-reconciler.sh:1326-1328` (direct mode) and `:1877-1881` (pull-request mode) both hard-reject when `review.md` is absent:

```
local review_file="$workflow_dir/$entity_slug/review.md" ship_file="$workflow_dir/$entity_slug/ship.md"
[ -f "$review_file" ] || reject_input closeout-review-missing "review.md is required for terminal closeout"
[ -f "$ship_file" ] || reject_input closeout-ship-missing "ship.md is required for terminal closeout"
```

Empirical confirmation: `origin/main:docs/ship-flow/missing-canonical-mods/` (the entity that reconcile-blocked 2026-07-19 19:26-20:10) has `verify.md` + `ship.md` but NO `review.md` (`git ls-tree -r --name-only origin/main | grep missing-canonical-mods`). The scheduler's `l3/rra/missing-canonical-mods` beat calls this reconciler which fires `closeout-review-missing` → `.ship-flow-scheduler-events.jsonl` emits `blocked reconciler-error` (`ship-flow-scheduler.sh:585-586`) → Phase-A auto-closeout stalled repo-wide.

**AC-2 — REAL, receipt schema currently references review.md hash.** `merged-pr-closeout-reconciler.sh:1314` embeds `"review":h(entity.parent/"review.md")` inside `source_hashes` (D1 receipt proof, line 1310 comment: "source_commits is provider/rendering input, not part of the canonical D1 receipt proof"). This is the ownership_proof block whose `proof_hash` is computed at :1315 — removing `review.md` alone would leave a phantom hash. Fix must adjust either the hash source (drop `review` when absent; substitute `verify.md`) OR the schema shape (make `review` optional). AC-2 pins the choice must be receipt-deterministic and captured by a test assertion, not left implicit.

**AC-3 — REAL, ship.md is genuinely load-bearing.** `merged-pr-closeout-reconciler.sh:1148-1153` reads `ship.md` to extract `## Todo Closeout Digest` for the debrief render (`raise SystemExit("ship.md is missing Todo Closeout Digest")`), and `:1317` writes `ship_rel` as the archived-ship output path. `ship.md` is the actual review-bearing artifact in this workflow: `origin/main:docs/ship-flow/missing-canonical-mods/ship.md` carries `## Canonical Docs Update` (the section `canonical-doc-sync-checker.sh` scans for at :74-92). So the fix narrows the required set to `{ship.md}`, not `{}`. The sibling checker (`canonical-doc-sync-checker.sh:60-66`) already accepts `review.md` OR `ship.md` — that behavior is what the reconciler must adopt; DO NOT modify the checker.

**AC-4 — REAL, dual-env required.** The reconciler runs under scheduler and under CI; `CI=true` toggles pipefail/shell behavior in adjacent scripts (`check-invariants.sh` precedent), and `test-merged-pr-closeout-reconciler.sh` is 198 tests (verify.md 2026-07-19 line: "test-merged-pr-closeout-reconciler.sh at the harness's 90s-per-file bound (exit 124) — re-run alone at 300s: 198/198 PASS"). Both envs are enumeratable.

### Out of scope

- **C14 completion contract** (`plugins/ship-flow/lib/completion-v1.sh:45` `completion_contract_ok`) — its `ship/review/review.md|ship/ship/ship.md` case reflects the plugin's internal stage-triple grammar for `--advance` guard, NOT the reconciler's closeout precondition; leave untouched.
- **RoboRev / semantic-review gate** (`bin/semantic-review-gate.mjs`, `bin/review-thread-gate.mjs`) — orthogonal PR-comment gate, not artifact-set validation.
- **`canonical-doc-sync-checker.sh`** — already correct (line 60-66 accepts `review.md` OR `ship.md`); no change.
- **Workflow README taxonomy edit** — this workflow's `docs/ship-flow/README.md` already declares 8 stages including a `ship` stage producing `ship.md`; the plugin's `workflow-template.yaml` incorrectly maps `ship` stage → `ship-flow:ship-review` skill (which writes `review.md`) but that mapping drift is a separate template-vs-runtime bug best addressed as its own entity. Do NOT fix here.
- **Reading stage taxonomy from README** to derive the artifact set dynamically — attractive but out-of-appetite for S; the narrow fix is: make `review.md` optional, keep `ship.md` required.
- **Backfill of stalled entities**: any entities already blocked by `closeout-review-missing` beats need a one-shot re-tick after the fix lands; that ops step is FO-owned, not part of the code change.

### Risk / FO flag

- **Split-branch code drift**: the fix lives on `main` (or a branch off main), while this workflow's entity state is on `muscat-v1`. The debrief calls this out as "dual-branch state topology" structural debt. Execute must pick the right code base (main-derived), and the PR path must merge into a branch the running scheduler picks up.
- **Receipt schema change is a soft breaking-change**: any prior `proof_hash` computed with the old schema (embedding `review.md` even if empty) will differ. Since Phase-A auto-closeout is currently 100% blocked, no live receipts exist to migrate — but AC-2 must document the schema-shape choice in the receipt fixture so future audits see the version transition.
- **Test file location**: `lib/__tests__/test-merged-pr-closeout-reconciler.sh` lives in the plugin tree; running under the 90s-per-file harness bound produced a false-positive TIMEOUT (verify.md 2026-07-19) — plan should schedule this test standalone at ≥300s or split its slow leaf.

## Stage Report: shape

- DONE: Reconciler validation must accept workflow's actual stage taxonomy (8-stage ship-flow folds review into verify)
  AC-1 pins predicate change in `reconcile_direct_bundle` (:1326-1328) + `reconcile_pull_request_bundle` (:1877-1881) so `review.md` is optional; `verify.md`+`ship.md` (this workflow's actual set on origin/main:docs/ship-flow/missing-canonical-mods/) passes.
- DONE: Defined acceptance criteria for artifact acceptance (verify.md as review-bearing stage artifact)
  4 ACs written: predicate (AC-1), receipt-schema coherence for the review hash slot (AC-2), fail-closed elsewhere with ship.md still required (AC-3), dual-env suite green (AC-4). Each pairs a mechanism claim with a verifier (RED-then-GREEN fixture / receipt assertion / dual-env run).
- DONE: Shaped the fix: reconciler.sh logic only; no C14 contract or RoboRev gate changes
  Out-of-scope block lists C14 (`completion-v1.sh:45`), RoboRev (`semantic-review-gate.mjs`, `review-thread-gate.mjs`), `canonical-doc-sync-checker.sh` (already correct), workflow-template.yaml drift, and dynamic taxonomy-reading. Narrow S fix: predicate + receipt schema in `merged-pr-closeout-reconciler.sh` only.

### Summary
The bug is real and reproduced: `merged-pr-closeout-reconciler.sh:1326-1328` and `:1877-1881` hard-reject when `review.md` is absent, but `origin/main:docs/ship-flow/missing-canonical-mods/` (the reconcile-blocked entity from 2026-07-19) has `verify.md` + `ship.md` only. Narrow S-sized fix: (a) make `review.md` optional in both `reconcile_*_bundle` predicates, (b) adjust the D1 receipt `source_hashes` block (:1314) so `proof_hash` stays deterministic when review.md is absent; keep `ship.md` required (it feeds `## Todo Closeout Digest` and `ship_rel`). Two FO flags: (1) the code lives on main-lineage (0.9.0 reconciler is 2171 lines; muscat-v1 has only the 458-line pre-0.9.0 version) — execute must base on the right branch, else the fix ships nowhere the scheduler reads; (2) the receipt schema change is a soft version bump requiring a fixture-pinned schema choice, but no live receipts exist to migrate because closeout is 100% blocked today.
