# Fix reconciler review-artifact validation — Verify

Baseline: this worktree's `spacedock-ensign/reconciler-review-artifact-assumption`
branch (based on `origin/main`, PR #92). Everything below is independently
re-run in this session against the final committed tree, not relayed from
execute.md.

## Independent Quality Gate Re-Run

Fresh, foreground, uncompressed: `test-merged-pr-closeout-reconciler.sh`
standalone plain env 204/204 (`timeout 300`); same file `CI=true` 204/204;
`test-closeout-receipt.sh` 99/99; `test-apply-closeout-bundle.sh` 78/78;
`check-invariants.sh` full run 0 FAIL (18 checks OK, including C15 after the
fix below). Zero regressions across all three test files.

<details>
<summary>Decisive per-assertion evidence (own re-run, not relayed)</summary>

- Dual-mode predicate pair (AC-1): `PASS: direct closeout proceeds without
  review.md (AC-1)`; `PASS: pull-request closeout proceeds without review.md
  (AC-1)` — independently fixtured, confirming a direct-only fix could not
  have passed both.
- Ship-missing characterization (AC-3): `PASS: ship.md absent still rejects
  regardless of review.md (AC-3)`.
- Receipt determinism (AC-2): `PASS: review-absent direct receipt
  source_hashes omits review key and stays proof-hash deterministic`.
- `--verify-sources` round-trip (AC-2): `PASS: review-absent receipt
  validates via --verify-outputs`; `PASS: review-absent receipt validates
  via --verify-sources`.
- Both tamper directions (AC-2): `PASS: file-exists-but-key-omitted rejects
  (--verify-sources)` (validator); `PASS: file-exists-but-key-omitted
  rejects at apply (active source check)` + `PASS: ...rejects before any
  archive I/O` (applier); pre-existing `:533`/`:535` (drift / removed-review-
  key-present) still pass unmodified.

</details>

## Per-AC Evidence

- **AC-1 — VERIFIED.** Both predicate sites independently fixtured and
  re-run: direct-mode and PR-mode review-absent closeouts each reach
  `verdict=PROCEED` on their own fixture path (not shared setup) — a
  direct-only fix could not pass both. 204/204 in both env variants.
- **AC-2 — VERIFIED.** Receipt schema omits `review` key when the file is
  absent; `proof_hash` recomputation matches. Dual-mode round-trip
  (`--verify-outputs` + `--verify-sources`) passes on a review-absent
  receipt. Both tamper directions closed at both the validator and applier
  layers (see above) — own re-run, not relayed.
- **AC-3 — VERIFIED.** `ship.md` absent still exits `closeout-ship-missing`
  regardless of `review.md` presence; `canonical-doc-sync-checker.sh`
  untouched (verified: `git diff --stat` shows no change to that file).
- **AC-4 — VERIFIED, dual-env.** `test-merged-pr-closeout-reconciler.sh`
  204/204 plain + 204/204 `CI=true` (own foreground re-run, ≥300s standalone,
  not the 90s harness bound); `test-closeout-receipt.sh` 99/99;
  `test-apply-closeout-bundle.sh` 78/78. Zero regressions.

## Review Findings

Proportionality: 7-site coherent fix across 3 files (predicate x2, writer,
validator x2, applier x2), zero UI/API/migration surface — scoped review
applied. Cross-model coverage (codex adversarial pass) is the FO's parallel
job, integrated here rather than re-invoked.

**Codex cross-model — PASS, zero P1, 4 P2 advisories triaged:**

| Finding | Disposition | Detail |
| --- | --- | --- |
| P2-1 symlink-following in `hash_file()`/`is_file()` (`validate-closeout-receipt.py:533-534`) | **todo** | Pre-existing pattern shared by index/ship/review alike, not introduced or worsened by this entity's fix; filed `symlink-validation-receipt-gap`. |
| P2-2 `apply-closeout-bundle.sh:241` `.exists()` vs validator's `.is_file()` — directory/symlink semantic mismatch | **NIT-fixed now** (`4b0a0f8`) | Both call sites are net-new from this entity's own T2/T3; changed to `.is_file()` for parity. Re-verified: applier 78/78, receipt 99/99, zero regressions. |
| P2-3 no applier-level Direction-B tamper test (key-present, file-absent) | **todo** | design.md's own 2-REVISE-cycle scoping relied on the existing validator-level `:535` test generalizing to the applier; the P2-2 fix restores that parity, so the existing coverage argument holds. Filed `applier-direction-b-tamper-test` as an optional hardening follow-up, not a functional gap. |
| P2-4 `pr-merge-paths.md:91` + `INVARIANTS.md:21` stale "review.md required" contract prose | **NIT-fixed now** (`0b853d6`) | Same class as T4's `closeout-receipt-schema.yaml` update — plugin reference-doc coherence, docs-only, no test parses this prose. |

Own read of the diff: no silent-failure pattern introduced; the
`actual_keys != expected_keys` iff check is the same equality-based
mechanism at all three enforcement layers (writer, validator, applier),
now semantically identical after the P2-2 fix.

**C15 artifact-verbosity (self-found, fixed):** `plan.md` was 471 raw lines
against the 400-line raw cap — the `<details>`-wrapped T1-T5 spec kept body
content under its 200-line cap but the raw backstop still fired. Applied
the standing NIT-fix precedent (`missing-canonical-mods/plan.md`): condensed
narrative scaffolding inside the `<details>` block, all file:line citations /
reason strings / DC criteria / commit messages preserved (`abafc27`). Raw
now 375. `check-invariants.sh --check artifact-verbosity` OK;
`test-archived-corpus-invariants.sh` now ALL TESTS PASSED (was FAIL).

**PR #92 CI:** `invariants` now PASS (was FAIL on C15); `GitGuardian` PASS.
`doc_impact` requires a `doc-impact: none — <reason>` PR-body declaration
(README.md/`doc-sync-context.md` have no content this fix drifts —
`closeout-receipt-schema.yaml`'s own coupled row already covers it); PR body
updated with that declaration, but the CI run triggered by this stage's code
push captured the PR body *before* the edit (webhook snapshot timing) — the
push accompanying this verify.md commit will re-trigger `synchronize` with
the now-current body. FO should confirm `doc_impact` shows PASS on the next
check run after this push before arming auto-merge.

## Runtime UAT

`runtime_uat: deferred — the live reconciler beat (scheduler-driven
`--closeout-mode direct` tick against a real blocked entity) is not
exercisable inside this worktree; the runtime proof for this class is a
post-merge one-shot re-tick of the stalled entities currently blocked on
`closeout-review-missing`, which is FO-owned (requires the merged fix
running against live scheduler state, outside this worktree's scope).` The
Independent Quality Gate Re-Run above (fixture-driven, both real predicate
paths + both tamper directions) is the pre-merge substitute proof for this
entity's own AC-1..AC-4.

## Verdict

**PASS (PROCEED).** All 4 ACs independently re-verified with own re-run
evidence (not relayed); zero regressions across 381 total assertions (204 +
204 + 99 + 78, counting both dual-env legs). Codex cross-model PASS, zero
P1; of 4 P2 advisories, 2 fixed now (both squarely in this entity's own
net-new code/docs), 2 deferred as todos (pre-existing or already covered by
a deliberate, gate-approved design scoping choice). Self-found C15 gap fixed
under the standing precedent. Runtime UAT explicitly deferred with a named
FO-owned proof, not silently diluted.

## Panel Coverage

`panel_coverage: scoped` (S-sized mechanical fix, zero UI/API/security/
migration scope flags) — `cross_model: true` (codex adversarial pass,
PASS/zero-P1, 4 P2 findings triaged above). Full 5-specialist panel not
dispatched; scoped review + own diff read + dual-env fixture re-run exceed
typical specialist depth for this change class. Declared visibly, not
silent.

## Deferred to TODO

This round emits 2 findings to `ship-flow:add-todos` (filed, both non-blocking P2 from the codex pass, neither part of this entity's AC-1..AC-4):
- `symlink-validation-receipt-gap` — pre-existing symlink-following in
  `hash_file()`/`is_file()`, shared across index/ship/review, not introduced
  by this entity.
- `applier-direction-b-tamper-test` — optional applier-level Direction-B
  fixture; the existing validator-level test already covers this direction
  and the P2-2 fix restores validator/applier parity.

Not filed as a todo (tracked instead as an explicit FO-owned post-merge
step, per shape's own scope carve-out): re-tick of entities currently
stalled on `closeout-review-missing` once this PR merges.

Findings escalated to captain (CRITICAL+confidence≥8): 0 entries.
