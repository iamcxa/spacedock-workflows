# Fix reconciler review-artifact validation — Plan

### Summary

`review.md` is required at **6 mandatory sites across 3 files** (plus 1 off-hot-path
coherence site in a 4th location, plus 1 documentation-only reference) — not just the
two predicates the shape named. All 8 sites implement ONE conceptual change (per
design.md §1/§4, gate-approved through 2 REVISE cycles): **the `review` key in a D1
receipt's `source_hashes` is present iff an active, regular `review.md` exists** —
`ship.md` and `index.md` stay unconditionally required everywhere. This plan authors
all new tests first (T1, RED against unmodified code), lands the 6 mandatory sites as
ONE coherent commit (T2 — splitting them further leaves the system in a still-blocked
intermediate state, explained below), lands the 1 independent coherence site
separately (T3), updates the stale schema reference doc found during planning (T4,
new — not named in design.md), then runs the dual-env verification design.md's own
runtime-constraint section requires (T5).

### Execution prerequisite — branch/lineage, verified live

This worktree's base (`origin/main`) already carries the correct 0.9.0 reconciler:
`plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh` is **2171 lines** (`wc -l`,
matches design.md §0), and `git diff --stat origin/main ship-flow-scheduler-controller
-- plugins/ship-flow/` is **empty** — this worktree's `plugins/ship-flow` tree is
byte-identical to the `ship-flow-scheduler-controller` worktree the shape named as the
scheduler's actual code lineage. All line citations below were re-verified against
this worktree's checked-out files (not assumed from design.md), and match exactly:
`:1314` (writer), `:1327`/`:1880` (predicates), `validate-closeout-receipt.py:597`
(structural), `:530` (verify_source_bytes), `apply-closeout-bundle.sh:229-231`/
`:240-242` (applier). **Execute must open the PR against `main`**, not
`iamcxa/muscat-v1` — the muscat-v1 tree's reconciler is the pre-0.9.0 458-line version
with no artifact check at all; a fix landed there ships nowhere the scheduler reads.

### Deliverables

1. Code fix — the coherent 6-site mandatory change (T2) + 1 independent coherence site
   (T3), across `merged-pr-closeout-reconciler.sh`, `validate-closeout-receipt.py`,
   `apply-closeout-bundle.sh`.
2. Test suite additions — ~9 new tests across `test-merged-pr-closeout-reconciler.sh`
   and `test-closeout-receipt.sh` (T1); zero regressions across all 200 existing
   fixtures in those two files plus the 3rd, previously-unenumerated regression
   surface this plan found (`test-apply-closeout-bundle.sh` — see Plan finding).
3. `closeout-receipt-schema.yaml` doc-coherence update (T4, new finding, non-code).
4. Dual-env verification run output (T5): standalone ≥300s, plain env AND `CI=true`.
5. **A gate-brief for the verify-stage gate review, drafted by the execute/verify-stage
   worker as part of that stage's own output.** The first officer's role at that gate
   is to forward this brief to the captain — not to author or edit its substance.

### Plan finding — a 3rd untested regression surface, verified live (not in design.md)

design.md §2 enumerates test impact across `test-merged-pr-closeout-reconciler.sh` and
`test-closeout-receipt.sh` only. `grep -rl "source_hashes"
plugins/ship-flow/lib/__tests__/*.sh` shows a **3rd file**:
`test-apply-closeout-bundle.sh` — it drives `apply-closeout-bundle.sh` (where sites 5
and 6 live) directly, with its own hardcoded 3-key receipt fixture (`:139`,
`"review":h(repo/…/review.md)`) and its own assertion (`:228`, `'review evidence is
archived byte-for-byte'`), plus a `review.md` seed at `:50` and a late-mutation case at
`:372-373`. This file's fixtures always seed `review.md` (verified: `grep -c
review.md` → 6 hits, all present-path), so the same "every fixture seeds review.md →
no regression" argument design.md made for the other two files applies here too — but
it was never named, so T5's regression check explicitly re-runs this file and confirms
its review-present assertions (including `:228`) still pass unchanged. Not a blocking
finding — direction stands — but the coverage claim in design.md §2 was incomplete by
one file; this plan closes that gap.

### Why sites 1-6 land in ONE commit, not six (design.md §2, re-confirmed live)

The two predicate sites are the user-visible entry points, but `reconcile_direct_bundle`
calls `prepare_direct_bundle` (the writer, site 3) unconditionally right after the
predicate (`merged-pr-closeout-reconciler.sh:1341`), and `validate_receipt_normal`
(which calls the python validator, site 4) runs inside the same flow before apply
(confirmed live: `grep -n "validate_receipt_normal\|RECEIPT_VALIDATOR"
merged-pr-closeout-reconciler.sh` shows 8+ call sites threaded through both
`reconcile_direct_bundle`'s and `reconcile_pull_request_bundle`'s critical path, not
just an opt-in CLI flag). Concretely:

- Predicate-only (sites 1-2, no site 3): the writer still unconditionally computes
  `h(entity.parent/"review.md")` at `:1314`, which crashes on missing file
  → `render_rc!=0` → `reject_input closeout-stage-artifacts-incoherent` at `:1344`.
  Net effect: closeout still fails, just with a different `reason=`.
- Sites 1-3 without site 4: the just-rendered review-absent receipt has
  `source_hashes={index,ship}`; `validate_receipt_normal` calls the structural
  `validate()`, whose `require_exact_keys(hashes, {"index","review","ship"}, …)` at
  `:597` rejects it as `missing=["review"]` → `closeout-sentinel-invalid`. Closeout
  still fails.
- Sites 1-4 without sites 5/6: `apply-closeout-bundle.sh:229-231`'s loop
  (`for source in index.md review.md ship.md`) still hard-requires `review.md` on
  disk → `closeout-stage-artifacts-incoherent` at apply time even though the receipt
  and predicate both already accepted the review-absent case.

There is no intermediate state among sites 1-6 where a review-absent direct or
pull-request closeout actually reaches `verdict=PROCEED`. Splitting them into 6 commits
would produce 5 commits that are each individually a no-op fix (still-blocked, just
with a different `reason=`) — worse for bisectability, not better. This plan lands
them as one commit (T2), each site individually named and DC'd within it, and reserves
real commit-splitting for the one site (7) that is genuinely independent of the
reconciler's hot path.

### Runtime commands (dual-env, AC-4)

- **New/updated file, standalone, plain env:**
  `timeout 300 bash plugins/ship-flow/lib/__tests__/test-merged-pr-closeout-reconciler.sh`
- **Same file, standalone, CI env** (per debrief 2026-07-19: this file exceeds the CI
  workflow's 90s-per-file loop bound — `CI=true` here is the env-var toggle some
  scripts branch on, not the workflow's timeout wrapper):
  `CI=true timeout 300 bash plugins/ship-flow/lib/__tests__/test-merged-pr-closeout-reconciler.sh`
- **Receipt round-trip file:**
  `bash plugins/ship-flow/lib/__tests__/test-closeout-receipt.sh` (fast, no 90s risk)
- **Applier regression file (Plan finding):**
  `bash plugins/ship-flow/lib/__tests__/test-apply-closeout-bundle.sh`
- **Full local loop** (matches `.github/workflows/ship-flow-invariants.yml:110`,
  repo-root-relative): `for t in plugins/ship-flow/lib/__tests__/test-*.sh; do CI=true
  timeout 90 bash "$t" || echo FAILED:$t; done` — expect the reconciler file's own line
  to report FAILED here (known 90s-bound false-negative, unrelated to this fix); T5
  cross-checks it separately at 300s per the line above.

### Time budget (1h45m total) — verification is never compressed

| Task | Budget | Note |
|---|---|---|
| T1 — author tests (RED) | 30m | test-only, 2 files |
| T2 — sites 1-6, one commit | 30m | 3 files, mechanical per §-mapped diffs below |
| T3 — site 7, one commit | 15m | 1 file, independent of hot path |
| T4 — schema doc coherence | 5m | 1 file, 2 lines |
| T5 — dual-env verification | 20m | standalone ≥300s x2 + 2 regression files |
| Commit hygiene / DC review | 5m | |

If T1-T4 run over budget, T5 is **not** shortened, skipped, or run only once — AC-4
explicitly requires both envs, and the whole point of this fix is a closeout gate that
was silently broken; a plan that reduces its own verification to fit a clock defeats
the entity.

---

<details>
<summary>Task detail — T1-T5 implementation spec, TDD contracts, per-site DC</summary>

### T1 — Author all new tests (RED / characterization), test-file-only commit

No production code changes; confirms baseline behavior against the unmodified
0.9.0 reconciler before T2/T3 touch anything.

**In `test-merged-pr-closeout-reconciler.sh`:**

1. **Direct-mode review-absent RED** (AC-1, independent test). New helper
   `prepare_full_d1_repo_review_absent` — `prepare_full_d1_repo` (`:365`) minus
   the `review.md` add/commit block. Asserts `rc=0` (`native_repo` pattern,
   `:619-623`). `red_command`: unmodified code → `rc=2`,
   `reason=closeout-review-missing` (`:1327`). `green_command`: after T2 →
   `rc=0`.

2. **PR-mode review-absent RED** (AC-1, independent — a direct-only fix must
   leave this RED). Same fixture-omission pattern, PR-mode path (mirrors
   `run_pull_request_roadmap_validation_case`'s `--closeout-mode
   pull-request` shape, `:4051-4088`). Asserts `rc=0` where today
   `reason=closeout-review-missing` fires at `:1880`. Own PR-mode fixture
   path, not item 1's helper — independence by construction.

3. **Ship-missing characterization test** (AC-3 — NOT RED-then-GREEN; must
   stay unchanged). New direct-mode fixture: `review.md` present, `ship.md`
   absent → `rc=2` + `reason=closeout-ship-missing`. Baseline: already PASSES
   today (locks current behavior; zero existing test pinned this reason
   string per design.md §2). Unchanged after T2/T3 — confirms the fix
   narrowed the required set to `{ship.md}`, not `{}`.

4. **Receipt-shape assertion, `:4917`-modeled** (AC-2, determinism). After
   test 1's run reaches `rc=0`, locate the applied receipt and assert
   `sorted(source_hashes.keys()) == ["index","ship"]` and recompute
   `sha256(json.dumps({...sort_keys=True...}))` equals `proof_hash` (matches
   the existing `:4902-4924` golden-receipt pattern). `red_command`: today
   this never executes (predicate rejects first) — "no receipt file found" is
   RED. `green_command`: after T2, passes.

**In `test-closeout-receipt.sh`:**

5. **Review-absent dual-mode round-trip** (AC-2 — both `--verify-outputs` AND
   `--verify-sources`; the latter is the only mode executing the changed
   `verify_source_bytes`). `make_receipt`/`bind_repo_bytes` (`:29`/`:66`)
   hardcode the 3-key tuple — needs a review-absent variant omitting the
   `"review"` key and the fixture-tree `review.md`. `red_command`:
   `require_exact_keys` (`:597`) rejects structurally first
   (`missing=["review"]` → `closeout-sentinel-invalid`) — both
   `--verify-outputs`/`--verify-sources` FAIL. `green_command`: after T2
   (site 4) + T3 (site 7), both PASS.

6. **Direction-A tamper, validator** (AC-2, tamper-window closure). `review.md`
   EXISTS; hand-craft a self-rehashed receipt with `source_hashes = {index,
   ship}` (key omitted despite the file existing), `proof_hash` recomputed
   self-consistent. Asserts `closeout-stage-artifacts-incoherent` via
   `--verify-sources`. `red_command`: today's `verify_source_bytes` (`:530`)
   does `expected[key]` on the fixed 3-tuple → uncontrolled `KeyError`, not a
   clean reject — counts as RED. `green_command`: after T3, clean reject.

7. **Direction-A tamper, applier** (AC-2, same tamper window at apply). Same
   crafted receipt as item 6, driven through `apply-closeout-bundle.sh`
   directly — asserts non-zero exit + `closeout-stage-artifacts-incoherent`,
   archive step never ran. `red_command`: today's bash loop at `:229-231`
   only checks `review.md` existence on disk (true here) — proceeds past
   this check, then `KeyError`s on `expected["review"]` at `:240-242`
   (uncontrolled crash) — RED. `green_command`: after T2 (site 5 compares
   receipt-declared keys against disk-derived expected keys), clean reject
   before any archive I/O.

**Existing-fixture no-regression baseline (DC only, no new test):**
`test-closeout-receipt.sh:533` (tampered review → drift) and `:535` (removed
review, key present → incoherent) both still PASS unmodified after T2/T3 —
pin the direction this plan does not change.

**DC (T1):** both test files run against unmodified code; the 7 new
assertions show FAIL/RED (or documented crash/KeyError equivalent) except
item 3 (ship-missing baseline), PASS. Commit: `test(closeout): add
review-absent RED fixtures + receipt round-trip + tamper-window assertions
(AC-1, AC-2, AC-3 baseline)` — pathspec both test files.

---

### T2 — Sites 1-6, coherent hot-path fix, ONE commit (AC-1, AC-2 structural, AC-3)

**Site 1** `merged-pr-closeout-reconciler.sh:1327` (`reconcile_direct_bundle`):
delete the `review.md`-required `reject_input` line. Keep `:1328` (ship)
unchanged. `$review_file`'s `local` declaration stays (harmless, minimal
diff) since `ship_file` on the same line stays load-bearing.

**Site 2** `merged-pr-closeout-reconciler.sh:1880` (`reconcile_pull_request_bundle`):
identical deletion, PR-mode predicate. Keep `:1881` (ship) unchanged.

**Site 3** `merged-pr-closeout-reconciler.sh:1314` (writer,
`prepare_direct_bundle`, shared by both modes): `source_hashes` now includes
`"review"` only conditionally —
```python
_source_hashes = {"index":h(entity), "ship":h(entity.parent/"ship.md")}
if (entity.parent/"review.md").exists(): _source_hashes["review"] = h(entity.parent/"review.md")
```
referenced in the `ownership_proof` literal in place of the old inline 3-key
block. (`h()` is the existing hasher at `:1136`, unchanged.)

**Site 4** `validate-closeout-receipt.py:597` (`validate()`): replaced
`require_exact_keys(hashes, {"index","review","ship"}, "source_hashes")`
with a range check making `review` optional (`missing = {"index","ship"} -
keys`, `extra = keys - {"index","review","ship"}`; either non-empty →
`closeout-sentinel-invalid`).

**Sites 5+6** `apply-closeout-bundle.sh` (active-source check + byte-verify,
same conceptual iff, same function flow):
- `:229-231`: bash loop `for source in index.md review.md ship.md` →
  `for source in index.md ship.md` (unconditional; AC-3's "ship.md
  required").
- `:234-246` (python block parsing the receipt): inserts the bidirectional
  iff check before the hash-verify loop —
  `expected_keys = {"index","ship"} | ({"review"} if review_path.is_file()
  else set())`; `actual_keys != expected_keys` → `closeout-stage-artifacts-incoherent`
  before any hashing. One equality check covers both iff directions:
  file-exists-but-key-omitted and key-present-but-file-missing — same
  mismatch, same reject. (`review_path.is_file()`, not `.exists()` — matches
  T3's validator semantics exactly, closing a directory-vs-file edge the
  codex cross-review pass flagged; see verify.md.)

**TDD contract (T2, one shared red/green pair across all 6 sites — see
rationale above for why this can't be split further):** `red_command`: T1
items 1, 2, 4, 6, 7. `green_command`: items 1/2/4 GREEN; item 5's
`--verify-outputs` leg GREEN, `--verify-sources` leg still RED (needs T3);
items 6/7 GREEN. `refactor_check`: T1 item 3 + `:533`/`:535` + all 198
pre-existing reconciler fixtures + all applier fixtures stay GREEN.

**DC:** all 3 test files green except item 5's `--verify-sources` leg
(expected, closed by T3). Commit: `fix(closeout): make review.md
presence-driven across predicate/writer/validator/applier (AC-1, AC-2,
AC-3)` — pathspec all 3 files.

---

### T3 — Site 7, independent coherence fix, ONE commit (AC-2 `--verify-sources` leg)

`validate-closeout-receipt.py:522-533` (`verify_source_bytes`,
`--verify-sources` only — the reconciler's own hot path never calls this
function, 0 hits). Fixed 3-tuple loop replaced with a per-key iff matching
site 5/6's semantics: `index`/`ship` hashed unconditionally
(`hash_file` already fails `closeout-stage-artifacts-incoherent` on missing);
`review_exists = review_path.is_file()` must equal `"review" in expected` or
fail `closeout-stage-artifacts-incoherent`; when both true, hash-compare or
fail `closeout-projection-source-drift`. Preserves `:533`/`:535` exactly,
adding the review-absent skip path and the file-exists-but-key-omitted
reject.

**TDD contract:** `red_command`: T1 item 5's `--verify-sources` leg (RED
after T2 alone) + item 6. `green_command`: both GREEN after this commit.
`refactor_check`: `:533`/`:535` still PASS.

**DC:** `test-closeout-receipt.sh` full green. Commit:
`fix(closeout-receipt): enforce review.md presence iff in --verify-sources
(AC-2)` — pathspec `validate-closeout-receipt.py`.

---

### T4 — `closeout-receipt-schema.yaml` doc coherence (new finding, non-code)

Not named in design.md. Referenced only as a comment pointer
(`persist-closeout-intent.sh:85`), never parsed/loaded — docs-only, zero
test/behavior risk. After T2/T3 it would misdescribe the contract: `:33`
`review: { type: sha256 }` reads as unconditionally required → noted
conditional (`optional: true`, presence-iff note); `:148`
`verify_sources` prose updated to reflect review's conditional
participation.

**DC:** `grep -n review closeout-receipt-schema.yaml` shows both lines
updated; no test parses this file, so no red/green pair. Commit:
`docs(closeout-receipt-schema): reflect review.md as presence-driven, not
required (AC-2)` — pathspec the yaml file.

---

### T5 — Dual-env verification (AC-4)

Run, in order, and capture output:
1. `timeout 300 bash .../test-merged-pr-closeout-reconciler.sh`
2. `CI=true timeout 300 bash .../test-merged-pr-closeout-reconciler.sh`
3. `bash .../test-closeout-receipt.sh`
4. `bash .../test-apply-closeout-bundle.sh`
5. Full local loop (90s bound, informational — the reconciler file is
   expected to report FAILED here per its known pre-existing harness-bound
   false-negative, documented in verify.md 2026-07-19 and design.md §2):
   `for t in .../test-*.sh; do CI=true timeout 90 bash "$t" || echo
   FAILED:$t; done`

**DC:** commands 1-4 all exit 0, 100% PASS in both env variants of 1/2;
command 5's reconciler-file FAILED (if any) is the pre-existing, documented
90s-bound cause, not a regression — flagged in the gate-brief so the
reviewer doesn't mistake it for new.

</details>

---

### Canonical Doc Actions

| Doc | Action | Rationale |
| --- | --- | --- |
| PRODUCT.md | **skip** | Fixes a broken internal gate (Phase-A auto-closeout), does not add or change a user-facing capability. |
| ARCHITECTURE.md | **skip** | No new component/contract/decision — a presence-driven key in an existing receipt schema, applied consistently at its existing enforcement points. Nothing rises to `<!-- section:decisions -->` weight. |
| ROADMAP.md | **skip at plan; ship adds a Shipped row directly** | Hackathon-2-sourced (issue #83), not roadmap-groomed — no existing Now/Next/Later row to move (`grep -n 'reconciler-review-artifact\|review-artifact-assumption' ROADMAP.md` → no hits). Matches the same-session hackathon cadence precedent (`missing-canonical-mods`, `c14-fo-dispatch-contract`). |

Root canonical docs only, per this stage's checklist scope: PRODUCT.md, ARCHITECTURE.md,
ROADMAP.md. `closeout-receipt-schema.yaml` (T4) is a plugin reference doc, not a root
canonical doc.

### Plan Report

- status: passed
- task_count: 5 (T1 RED/characterization tests, T2 6-site coherent commit, T3
  independent coherence site, T4 schema-doc coherence, T5 dual-env verification)
- verification_spec_count: 7 new assertions/tests (2 independent predicate RED tests +
  1 ship-missing characterization + 1 receipt-shape determinism assertion + 1 dual-mode
  round-trip + 2 direction-A tamper fixtures) + 3 regression files re-confirmed green
  (test-merged-pr-closeout-reconciler.sh 198 pre-existing, test-closeout-receipt.sh
  existing fixtures + `:533`/`:535`, test-apply-closeout-bundle.sh — Plan finding)
- new_constraint_found_at_plan: 2 — (1) `test-apply-closeout-bundle.sh` is a 3rd
  regression surface touching `source_hashes` that design.md's test-impact table
  didn't name (verified live via `grep -rl "source_hashes"
  plugins/ship-flow/lib/__tests__/*.sh`); (2) `closeout-receipt-schema.yaml` is a stale
  canonical-schema-reference doc surface design.md didn't name (verified live: only a
  comment pointer, zero parse/behavior risk, but would misdescribe the post-fix
  contract if left unchanged) — folded in as T4
- open_contract_decisions: 0 — design.md's rev-2 iff pinning left no open choice; T2's
  `actual_keys != expected_keys` equality check is the concrete mechanism for the
  abstract iff design.md specified
- canonical_doc_actions: PRODUCT skip, ARCHITECTURE skip, ROADMAP skip-at-plan (no
  existing row; ship appends Shipped directly)
- execution_prerequisite_reverified: this worktree (`origin/main` base) is
  byte-identical to `ship-flow-scheduler-controller` at `plugins/ship-flow/`
  (`git diff --stat` empty) — confirmed live, not assumed from shape
- deliverable_gate_brief: plan names a worker-drafted verify-stage gate-brief as
  deliverable 5; FO forwards, does not author (per checklist requirement)
- residual_known_gap: the CI workflow's 90s-per-file loop bound will still report
  `test-merged-pr-closeout-reconciler.sh` as FAILED (exit 124) regardless of this fix —
  pre-existing harness-bound issue, out of this entity's scope, called out in T5's DC
  and to be surfaced in the gate-brief so it isn't mistaken for a fix regression
