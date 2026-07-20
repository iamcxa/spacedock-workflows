---
title: Fix reconciler review-artifact validation
status: design
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

## Stage Report: design

- DONE: Receipt-schema contract choice decided and pinned in design.md (omit vs substitute); proof_hash deterministic; named the fixture assertion pinning the review-absent shape
  design.md §1 pins OMIT `review` when `review.md` absent (workflow-agnostic — reconciler has zero `verify.md` refs; deterministic via `sort_keys=True`). Named assertion: new `:4917`-modeled `source_hashes:{index,ship}` assertion in test-merged-pr-closeout-reconciler.sh + a test-closeout-receipt.sh validate round-trip.
- DONE: design.md maps both predicate change sites (:1326-1328 direct, :1877-1881 PR) to exact tests, including 198-test-suite impact and the >=300s standalone runtime constraint
  design.md §2: predicate reject path is currently UNTESTED (0 hits for closeout-review-missing); all 198 fixtures seed review.md so sites are no-regression (198/198 stay green); risk confined to new review-absent tests; test-merged-pr-closeout-reconciler.sh (5328 lines/198 tests) must run standalone >=300s + CI=true (AC-4).
- DONE: Confirmed design references the 0.9.0 reconciler (2171 lines) on this worktree base, not muscat-v1's pre-0.9.0 version; ship.md stays required
  design.md §0: `wc -l` = 2171; ship.md required (feeds `## Todo Closeout Digest` :1151-1152 + `ship_rel` :1148/:1317); only review.md loosened.

### Summary
Pinned the receipt-schema choice as OMIT-review-when-absent (rejected verify.md-substitute: the generic reconciler must not bake this workflow's taxonomy, and it has no verify.md references). Layer-tracing the closeout path surfaced a finding beyond the shaped scope: the `review.md` requirement is a receipt-schema contract co-enforced at 6 mandatory sites across 3 files (reconciler predicate x2 + writer :1314, validate-closeout-receipt.py:597, apply-closeout-bundle.sh:229-231/:240-242) plus 1 coherence site (validator :530) — a predicate-only fix is a silent failure that still blocks at apply time (`closeout-stage-artifacts-incoherent`). design.md §4 flags the expanded-but-bounded scope (one conceptual change, ~M not S) for FO/captain confirmation before plan/execute. No code changed; design-stage output only.

## Stage Report: design (cycle 2)

- DONE: Fold gate REVISE feedback (3 codex gaps) into design.md; chosen direction unchanged
  Gap 1: design.md §1 now pins the bidirectional iff — `review` key present iff an active regular review.md exists — closing the tamper window where a self-rehashed key-omitted receipt would archive an unhashed review.md via copy_tracked_entity_tree (apply-closeout-bundle.sh:100-119, called at :339; verified first-hand). Fixtures named per direction: NEW validator (--verify-sources) + applier direction-A assertions; EXISTING test-closeout-receipt.sh:535 pins direction B. Sites 5/6/7 reformulated to enforce both directions.
  Gap 2: design.md §3 AC-1 now has TWO independent RED-then-GREEN tests, one per predicate (direct :1327, PR :1880) — a direct-only fix must leave the PR-mode test RED.
  Gap 3: design.md §1/§3 round-trip is now dual-mode — the review-absent receipt must pass --verify-outputs AND --verify-sources, since verify_source_bytes runs only under --verify-sources (validate-closeout-receipt.py:745-748).
  Also verified codex's no-action call on apply-closeout-bundle.sh:207 first-hand: preflight_lexical_paths (:38-64) is lexical/symlink-safety only (os.path.lexists gates the symlink check), so missing review.md passes — documented in §2 as a verified non-site. New-test count updated ~3 to ~7.

### Summary
Bounded revision per gate: direction stands (OMIT review key, 6-site coherent fix, ship.md required); design.md now carries the bidirectional presence constraint with per-direction fixture names, independent AC-1 coverage for both predicates, and a --verify-sources leg on the review-absent round-trip. All three gaps were verified against source before folding in.

## Stage Report: plan

- DONE: Tasks map 1:1 to the coherent 7-site fix (reconciler :1327/:1880 predicates, :1314 writer, validator require_exact_keys + coherence, applier both directions) with the bidirectional iff presence constraint; each predicate carries its OWN RED test; review-absent round-trip includes BOTH --verify-outputs AND --verify-sources; receipt determinism assertion named
  plan.md task detail: T1 authors 2 independent predicate RED tests (direct :1327 via a new `prepare_full_d1_repo_review_absent` fixture, PR :1880 via a separate PR-mode fixture path — independence verified by construction, not shared setup) + a `:4917`-modeled receipt-shape determinism assertion + a dual-mode (`--verify-outputs`+`--verify-sources`) round-trip + 2 direction-A tamper fixtures (validator + applier); T2 implements sites 1-6 as one coherent commit (rationale: no intermediate state between them reaches PROCEED — verified live via the writer/validator/applier call chain, not assumed); T3 implements the 7th, independent coherence site.
- DONE: Test plan runs test-merged-pr-closeout-reconciler.sh standalone at >=300s AND under CI=true (dual-env); total time budget 1h45m; verification tasks are never compressed to fit budget
  plan.md "Runtime commands" names both `timeout 300` and `CI=true timeout 300` invocations (T5); "Time budget" table allocates 105m across T1-T5 + hygiene and states explicitly that T5 is not shortened if earlier tasks overrun.
- DONE: Deliverable lands on this main-lineage branch (the running scheduler must read the fix); plan lists a worker-drafted gate-brief for the verify gate as an explicit deliverable (FO forwards, does not author)
  plan.md "Execution prerequisite" re-verifies live (not assumed from shape) that this worktree's `plugins/ship-flow` tree is byte-identical to the `ship-flow-scheduler-controller` worktree (`git diff --stat` empty) and states execute must PR into `main`. "Deliverables" item 5 names the gate-brief, worker-drafted, FO-forwards-only.

### Summary
Plan re-verified every design.md line citation live against this worktree's checked-out 2171-line reconciler (all matched exactly) and found 2 additional plan-stage constraints design.md didn't name: (1) `test-apply-closeout-bundle.sh` is a 3rd test file touching `source_hashes` (confirmed via `grep -rl "source_hashes"`), added to the regression-safety scope; (2) `references/closeout-receipt-schema.yaml` is a stale canonical-schema doc that would misdescribe the post-fix contract, folded in as new task T4. Landed the task breakdown as T1 (author all new tests, RED against unmodified code) → T2 (sites 1-6, one coherent commit — split further would leave 5 commits that are each individually still-blocked, just with a different `reason=`) → T3 (site 7, independent) → T4 (schema doc) → T5 (dual-env verification, protected from time-budget compression). No implementation code touched — plan-stage output only.

## Stage Report: execute

- DONE: RED-before-GREEN observed per site
  T1 (`865900f`) authored all 7 new assertions against unmodified 0.9.0 code and captured each site's RED signature (2 independent predicate RED, 1 characterization-baseline PASS, 1 receipt-shape RED, 1 dual-mode round-trip RED, 2 tamper RED); T2 (`6a4ced5`) and T3 (`4bb3776`) each flip their scoped items GREEN per plan.md's per-site TDD contract. Two documented deviations in execute.md's Issues Found (applier-tamper RED mode was a clean reject, not the predicted `KeyError`; item 6 followed the per-item contract over a stale T2-summary line) — both non-blocking, functionally equivalent RED either way.
- DONE: full local gate green in both envs, verification uncompressed
  AC-4's 4 named dual-env/regression commands were re-run fresh, foreground, uncompressed (no truncation) by this recovery leg against `383a14d`: `test-merged-pr-closeout-reconciler.sh` standalone plain-env 204/204 and `CI=true` 204/204 (both the ≥300s standalone invocation, not the 90s harness bound); `test-closeout-receipt.sh` 99/99; `test-apply-closeout-bundle.sh` 78/78 — zero regressions, counts identical to cycle-2's own account. Caveat (Material, does not block this DC): the entity's own `plan.md` trips an unrelated corpus-wide C15 artifact-verbosity check (471 raw lines vs. 400 cap) that will show red in this PR's actual CI once opened — disclosed in execute.md's Gate Brief for a verify-stage decision; it is outside AC-4's own scope (plan.md's T5 explicitly excludes the full 131-file loop from this entity's AC-4 proof).
- DONE: 7-site coherent fix landed on this main-lineage branch + gate-brief produced
  All 4 commits (`865900f` T1, `6a4ced5` T2 sites 1-6, `4bb3776` T3 site 7, `383a14d` T4 doc) sit on `spacedock-ensign/reconciler-review-artifact-assumption`, based on `origin/main` (verified per plan.md's execution prerequisite: this worktree's `plugins/ship-flow` tree matches the `ship-flow-scheduler-controller` lineage) — the PR opens against `main`, not `muscat-v1`. The worker-drafted gate-brief (plan.md deliverable 5) is appended to execute.md's `## Gate Brief` section; the FO forwards it verbatim per plan.md's explicit FO-forwards-only instruction.

### Summary
Cycle 2 completed all T1-T5 implementation and committed the 7-site coherent fix but froze mid-write of execute.md before recording its own evidence. This recovery leg (cycle 3, docs-only, no implementation code touched) re-ran the four decisive dual-env/regression checks fresh — identical to cycle 2's claimed counts — completed execute.md and its verify-stage gate-brief, and corrected one inaccurate claim cycle 2 left behind: `test-archived-corpus-invariants.sh`'s failure in the informational full loop is not the reconciler file's known harness-bound false-negative but a genuine, pre-existing C15 artifact-verbosity violation on this entity's own oversized `plan.md`, flagged Material in the gate-brief for the verify stage to resolve before merge.

