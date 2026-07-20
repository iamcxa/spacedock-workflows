# Execute — Fix reconciler review-artifact validation

Cycle 2 authored T1-T5, landed all 4 commits, then froze mid-way through
writing this file (session limit) before recording its own evidence. This
recovery leg (cycle 3, docs-only — no implementation code touched) re-ran the
four decisive DC commands fresh against the final committed tree (`383a14d`),
found the counts unchanged from cycle 2's own account, corrected one
inaccurate claim in Issues Found (below), and completed this file plus the
verify-stage gate-brief.

A prior execute worker died mid-T1 to a session limit; its partial
work is preserved at `wip(execute,cycle1)` (39 lines, one fixture helper).
This cycle reviewed the WIP, reused the one helper that was correct
(`prepare_full_d1_repo_review_absent`), and completed T1-T5 per plan.md
without any controller/wave machinery — tasks ran sequentially, single
implementer, no parallel dispatch (plan.md scoped this as one implementer,
no wave split).

## Execution Log

| Task | Status | RED evidence | GREEN / verification | Files | Commit |
| --- | --- | --- | --- | --- | --- |
| T1 | done | Direct-mode + PR-mode review-absent both `reason=closeout-review-missing`; receipt-shape assertion "no receipt found"; both `test-closeout-receipt.sh` round-trip legs `closeout-sentinel-invalid` (missing=['review']); applier tamper test `closeout-sentinel-invalid` (see Issues Found — differs from plan's predicted raw KeyError) | N/A (test-only commit) | `test-merged-pr-closeout-reconciler.sh`, `test-closeout-receipt.sh` | `865900f` |
| T2 | done | (carried from T1: sites 1/2/4 direct predicate/receipt-shape RED; item 5 `--verify-outputs` leg RED) | `test-merged-pr-closeout-reconciler.sh` unscoped 204/204; `test-closeout-receipt.sh` 97/99 (2 remaining RED are T3-scoped, expected); `test-apply-closeout-bundle.sh` 78/78 (no regression) | `merged-pr-closeout-reconciler.sh`, `apply-closeout-bundle.sh`, `validate-closeout-receipt.py` | `6a4ced5` |
| T3 | done | (carried: item 5 `--verify-sources` leg + item 6 validator-CLI direction-A tamper, both RED after T2 alone per plan's own per-item contract) | `test-closeout-receipt.sh` 99/99; `test-merged-pr-closeout-reconciler.sh` unscoped 204/204; `test-apply-closeout-bundle.sh` 78/78 | `validate-closeout-receipt.py` | `4bb3776` |
| T4 | done | N/A — docs-only, zero parse/behavior risk (verified: only a comment pointer in `persist-closeout-intent.sh:85`) | `grep -n review closeout-receipt-schema.yaml` shows both lines updated | `references/closeout-receipt-schema.yaml` | `383a14d` |
| T5 | done | N/A — verification stage | `test-merged-pr-closeout-reconciler.sh` standalone plain env 204/204; same file `CI=true` 204/204; `test-closeout-receipt.sh` 99/99; `test-apply-closeout-bundle.sh` 78/78; informational 90s-bound full loop captured (see Issues Found). **Cycle-3 re-verification:** all four commands re-run fresh, foreground, against `383a14d` — identical counts, exit 0 on all four. | — | — |

## Issues Found

- **T1 deviation from plan.md's predicted RED failure mode (non-blocking).** Plan.md's T1 item 7 (applier direction-A tamper) predicted an uncontrolled `KeyError` as the RED signature. Empirically, `apply-closeout-bundle.sh` calls the structural `validate()` (line ~179, `--allow-any-path`) *before* reaching the active-source-check sites 5/6, so the actual pre-fix RED is a clean `closeout-sentinel-invalid` reject (from the still-unfixed site 4), not a raw crash. Functionally equivalent RED (assertion correctly failed against unmodified code); the difference is only which layer produces the failure. Recorded for the record per plan's per-task DC framing; does not change scope, risk, or the fix itself.
- **Plan.md's own T2-section summary vs. T1's per-item contract disagree on one point (resolved in favor of the per-item contract).** The T2 TDD-contract paragraph says "items 6/7 GREEN" after T2 alone, but T1's own per-item spec for item 6 (validator-CLI direction-A tamper, `--verify-sources`) explicitly states `green_command: after T3`. Empirically item 6 stayed RED after T2 and went GREEN only after T3 (site 7) — matching the per-item contract, not the summary paragraph. Followed the more specific, itemized spec.
- **Corrected characterization of the informational full-loop failure (cycle-3 correction, Material).** Cycle 2's account described `test-archived-corpus-invariants.sh`'s FAILED result under the informational full loop as "a pre-existing harness-bound characteristic... unrelated to this change," by analogy to the reconciler file's known 90s-timeout false-negative. A fresh standalone re-run (this cycle, exit 1, no timeout involved — the file finishes in well under 90s) shows a different and more specific cause: `check_artifact_verbosity` (C15, `check-invariants.sh:2295`) FAILS because **this entity's own `plan.md` is 471 raw lines against a 400-line raw cap** (2x the 200-line body cap; body content itself is under cap — a single large `<details>` block defeats the raw budget). `plan.md` is new relative to `origin/main` in this branch's diff, so C15's branch-scope grandfather does not exempt it — this is a real branch-diff finding, not a harness artifact. It predates and is independent of the T1-T5 code fix (plan.md's size was fixed at the plan stage, commit `82935bf`, already through 2 design-stage REVISE cycles), but it **will surface as a red check in this PR's CI** once opened: `.github/workflows/ship-flow-invariants.yml` runs the full `test-*.sh` loop whenever `plugins/ship-flow/**` changes (`full_suite=true`), which this PR's code fix triggers. Not fixed in this stage — `plan.md` is outside execute's authorized touch-set (execute.md/index.md only) and this recovery leg does not have license to edit a plan-stage artifact. Flagged as a Material item in the gate-brief below for the verify stage / captain to decide (trim plan.md's `<details>` block, or explicitly accept/waive the resulting CI-red check).
- **No stalled-entity backfill performed.** Per shape's explicit scope carve-out, re-ticking already-blocked entities (e.g. `missing-canonical-mods`) is an FO-owned ops step, not part of this code change. Not attempted.

## Execute UAT

| DC | Verify Procedure | Result | Evidence |
| --- | --- | --- | --- |
| DC-1 (AC-1) | `timeout 300 bash plugins/ship-flow/lib/__tests__/test-merged-pr-closeout-reconciler.sh` (unscoped) | PASS | 204/204 — both direct-mode and PR-mode review-absent fixtures independently reach PROCEED; existing 198 fixtures unaffected |
| DC-2 (AC-2) | `bash plugins/ship-flow/lib/__tests__/test-closeout-receipt.sh` | PASS | 99/99 — review-absent receipt round-trips in both `--verify-outputs` and `--verify-sources`; both tamper directions (validator CLI, applier) reject before archive |
| DC-3 (AC-3) | same reconciler run, ship-missing characterization case | PASS | `ship.md` absent still exits `closeout-ship-missing` unchanged, regardless of `review.md` presence |
| DC-4 (AC-4, dual-env) | `test-merged-pr-closeout-reconciler.sh` standalone ≥300s plain env AND `CI=true`; `test-closeout-receipt.sh`; `test-apply-closeout-bundle.sh` | PASS | plain 204/204; `CI=true` 204/204; receipt 99/99; applier 78/78 — zero regressions across all three suites. Re-run fresh by cycle-3 (foreground, uncompressed, no truncation) against `383a14d`; counts identical to cycle-2's account. |

## Self-Check

- syntax: PASS — `bash -n` on all 3 modified shell files; `python3 -m ast` parse on `validate-closeout-receipt.py` and both embedded heredoc blocks
- unit tests: PASS — see Execute UAT
- lint: N/A — no linter configured for this plugin tree beyond the shell suites above
- critical-pass lite: PASS — no SQL/data-safety, race/concurrency, or shell-injection surface touched; the one security-relevant property (tamper-window closure, both directions of the iff) is covered by dedicated tests in both T1 and T3

## Execute Report

status: passed
stage_cost: single implementer, sequential T1→T5, no wave/controller dispatch (plan scoped this as one implementer)
task_count: 5
tasks_done: 5
tasks_blocked: 0
commit_count: 4 (T1 test-only; T2 6-site coherent fix; T3 site-7 independent fix; T4 docs-only) — cycle-1 WIP commit `9eb7e5c` preserved as-is, reused not amended

### Hand-off to Verify

- commits: `git log 82935bf..HEAD` — `9eb7e5c` (cycle-1 WIP, reused), `865900f` (T1), `6a4ced5` (T2), `4bb3776` (T3), `383a14d` (T4)
- dc_status: DC-1 PASS; DC-2 PASS; DC-3 PASS; DC-4 PASS
- deviations: T1's applier-tamper RED mode differs from plan.md's prediction (KeyError vs. clean reject — see Issues Found, non-blocking); T2-section's "items 6/7 GREEN" summary was superseded by T1's own per-item contract for item 6 (green after T3, not T2) — followed the more specific spec; cycle-3 corrected cycle-2's mischaracterization of the `test-archived-corpus-invariants.sh` full-loop failure (see Issues Found, Material)
- gate_brief: a worker-drafted verify-stage gate-brief per plan.md deliverable 5 is appended below in this file (`## Gate Brief`); the first officer forwards it as-is and does not author its substance
- residual_known_gap: (1) the CI workflow's 90s-per-file loop bound is expected to also flag `test-merged-pr-closeout-reconciler.sh` as a known non-regression false-negative (design.md-documented); (2) **new, Material** — this entity's own `plan.md` (471 raw lines, cap 400) trips C15 artifact-verbosity in `test-archived-corpus-invariants.sh`, which WILL run red in this PR's actual CI (full test suite triggers on any `plugins/ship-flow/**` change); not fixed here (out of execute's touch-set), flagged for verify-stage decision

## Gate Brief (verify-stage gate review) — drafted by execute-stage worker; FO forwards, does not author

Gate review: Fix reconciler review-artifact validation — execute
Chosen direction: 7-site coherent presence-driven fix (review key present iff review.md exists) landed as 4 commits (T1-T4) on this main-lineage branch per plan.md; T5 dual-env verification re-confirmed fresh by this recovery leg.
Recommend approve, with one Material flag below for a verify-stage decision — it does not affect the fix's correctness.

Checklist (from ## Execution Log and ## Execute UAT above):
- DONE: T1 RED tests authored against unmodified 0.9.0 code — `865900f`
- DONE: T2 6-site coherent hot-path fix (predicates x2, writer, validator structural, applier x2) — `6a4ced5`
- DONE: T3 independent `--verify-sources` coherence site — `4bb3776`
- DONE: T4 schema doc coherence — `383a14d`
- DONE: T5 dual-env verification, re-confirmed fresh this cycle: reconciler 204/204 plain + 204/204 `CI=true`; receipt 99/99; applier 78/78 — zero regressions

Reviewer findings:
Material: this entity's own `plan.md` is 471 raw lines (cap 400 for plan.md) and will trip C15 artifact-verbosity in this PR's CI (`test-archived-corpus-invariants.sh`; the full `test-*.sh` suite runs because `plugins/ship-flow/**` changed). Pre-existing from the plan stage (commit `82935bf`, already through 2 design-stage REVISE cycles), unrelated to the code fix's correctness, not fixed in this stage (outside execute's authorized touch-set). Verify stage should decide: trim plan.md's `<details>` block (link out instead of inlining, per the check's own remedy text), or explicitly accept/waive the resulting CI-red check before merge.
Polish: T1's applier-tamper RED mode differs from plan.md's predicted raw `KeyError` (actual: a clean `closeout-sentinel-invalid` reject from a different, still-unfixed layer) — functionally equivalent RED, non-blocking, recorded for the record.

Assessment: 5 done, 0 skipped, 0 failed (T1-T5); 1 Material finding requiring a verify-stage decision before merge.

Decision: approve to enter verify stage; verify must resolve the plan.md C15 finding (trim or explicit waive) before this PR can show all-green CI.
