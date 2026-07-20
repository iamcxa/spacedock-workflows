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

No production code changes. Confirms baseline behavior with the unmodified 0.9.0
reconciler before T2/T3 touch anything.

**In `test-merged-pr-closeout-reconciler.sh`:**

1. **Direct-mode review-absent RED** (AC-1, own independent test — rev-2 requirement).
   New helper `prepare_full_d1_repo_review_absent` — a copy of the existing
   `prepare_full_d1_repo` (`:365`) with the `review.md` `printf`/`git add`/`git commit`
   block removed (`index.md` alone is added+committed in its place). Then, modeled on
   the existing `native_repo` pattern (`:619-623`):
   ```
   prepare_full_d1_repo_review_absent "$repo" "$fixture"
   rc="$(run_helper "$repo" "$output" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
   assert_exit 'direct closeout proceeds without review.md (AC-1)' 0 "$rc"
   ```
   `red_command`: run this against unmodified code → `rc=2`,
   `reason=closeout-review-missing` (`:1327`) → `assert_exit` expects 0, gets 2 → FAIL
   (RED). `green_command`: same, after T2 → `rc=0` → PASS.

2. **Pull-request-mode review-absent RED** (AC-1, independently — direct-only fix must
   leave this RED). Same fixture-omission pattern, PR-mode path (mirrors
   `run_pull_request_roadmap_validation_case`'s `--closeout-mode pull-request` fixture
   shape, `:4051-4088`, but with `review.md` omitted from the reviewed-entity commit).
   Asserts `rc=0`/PROCEED where today `reason=closeout-review-missing` fires at `:1880`.
   **Independence check (part of this task's DC, not a separate task):** this test uses
   its own fixture-building path (PR-mode `--pr-fixture` + `--closeout-mode
   pull-request`), not the direct-mode helper from item 1 — confirmed by construction,
   not by shared setup, so a fix touching only `:1327` cannot accidentally flip this one
   green too.

3. **Ship-missing characterization test** (AC-3 — NOT a RED-then-GREEN pair; this
   behavior is unchanged by the fix and must stay identical before and after). New
   direct-mode fixture: `review.md` present, `ship.md` absent →
   `assert_exit … 2 "$rc"` + `assert_contains … '^reason=closeout-ship-missing$'
   "$output"`. `red_command`/baseline run: already PASSES today (locks current
   behavior — zero existing test currently pins this reason string, per design.md §2's
   "zero hits" grep). `green_command`: same assertion, unchanged, after T2/T3 land —
   confirms the fix narrowed the required set to `{ship.md}`, not `{}`.

4. **Receipt-shape assertion, `:4917`-modeled** (AC-2, receipt determinism). Extend
   test 1's fixture: after the direct-mode review-absent run reaches `rc=0`, locate the
   applied receipt (`find "$repo/docs/ship-flow/_closeouts" -name '*.json'`) and, in a
   Python assertion block matching the existing `:4902-4924` golden-receipt pattern,
   assert `sorted(receipt["ownership_proof"]["source_hashes"].keys()) ==
   ["index","ship"]` (no `"review"` key) and recompute
   `sha256(json.dumps({k:receipt[k] for k in ("identity","ownership_proof",
   "landing_proof","outputs")}, sort_keys=True, separators=(",",":"),
   ensure_ascii=False))` equals `receipt["proof_hash"]` — pins determinism, not just
   presence/absence. `red_command`: today this never executes (predicate rejects
   first, no receipt is produced) — treat "no receipt file found" as the RED failure.
   `green_command`: after T2, assertion passes on the produced receipt.

**In `test-closeout-receipt.sh`:**

5. **Review-absent dual-mode round-trip** (AC-2 — both `--verify-outputs` AND
   `--verify-sources` per rev-2; the latter is the only mode that executes the changed
   `verify_source_bytes`). `make_receipt` (`:29`) and `bind_repo_bytes` (`:66`)
   currently hardcode the 3-key `("index","review","ship")` tuple — **note for T1's
   implementer**: this needs either a new `make_receipt_review_absent` /
   `bind_repo_bytes_review_absent` helper pair, or a parameter added to the existing
   ones, that omits the `"review"` key from `source_hashes` and skips creating
   `docs/ship-flow/widget-closeout/review.md` in the fixture tree. Build such a
   receipt/repo pair, then:
   ```
   expect_ok "review-absent receipt validates via --verify-outputs" python3 "$VALIDATOR" --receipt "$RECEIPT" --repo-root "$TMP" --allow-any-path --verify-outputs
   expect_ok "review-absent receipt validates via --verify-sources" python3 "$VALIDATOR" --receipt "$RECEIPT" --repo-root "$TMP" --allow-any-path --verify-sources
   ```
   `red_command`: today `validate()`'s `require_exact_keys` at `:597` rejects this
   receipt structurally before either mode's extra checks run (`missing=["review"]` →
   `closeout-sentinel-invalid`) — both `expect_ok` calls FAIL. `green_command`: after
   T2 (validator structural, site 4) + T3 (site 7) both land, both PASS.

6. **Direction-A tamper, validator** (AC-2, rev-2 tamper-window closure). `review.md`
   EXISTS in the fixture tree; hand-craft a self-rehashed receipt whose
   `source_hashes = {index, ship}` (key omitted despite the file being present) —
   recompute `proof_hash` over that payload so it's internally self-consistent, then:
   ```
   expect_reason "file-exists-but-key-omitted rejects (--verify-sources)" closeout-stage-artifacts-incoherent python3 "$VALIDATOR" --receipt "$RECEIPT" --repo-root "$TMP" --allow-any-path --verify-sources
   ```
   `red_command`: today's `verify_source_bytes` (`:530`) iterates the fixed 3-tuple and
   does `expected[key]` — a `KeyError` on the missing `"review"` entry (Python
   exception, not a clean `reason=` reject) — counts as RED (wrong failure mode, not
   the expected `reason=` line). `green_command`: after T3, clean
   `closeout-stage-artifacts-incoherent` reject.

7. **Direction-A tamper, applier** (AC-2, same tamper window at the apply critical
   path). Same crafted receipt as item 6, driven through
   `apply-closeout-bundle.sh` directly (this test file's own harness pattern, matching
   `test-apply-closeout-bundle.sh`'s `run_bundle`/`make_bundle` shape, or reuse via a
   `--bundle-root` pointed at a bundle built from this crafted receipt) — asserts a
   non-zero exit and `closeout-stage-artifacts-incoherent`, and that the archive step
   never ran (active entity's `review.md` still present, un-archived).
   `red_command`: today's bash loop at `:229-231` only checks `review.md`
   *existence on disk* (true here) — it has no way to see the receipt omits the key —
   so the current code would proceed past this check and hash-verify against
   `expected[key]` which again `KeyError`s on `"review"` at `:240-242` (uncontrolled
   crash, not a clean reject) → RED. `green_command`: after T2 (site 5 rewritten to
   compare receipt-declared keys against disk-derived expected keys), clean reject
   before any archive I/O.

**Existing-fixture no-regression baseline (DC only, no new test needed):** confirm
`test-closeout-receipt.sh:533` (tampered review → `closeout-projection-source-drift`)
and `:535` (removed review, key present → `closeout-stage-artifacts-incoherent`) both
still PASS unmodified after T2/T3 — these pin "key present → file must exist and
match," the direction this plan does not change.

**DC (T1):** `bash plugins/ship-flow/lib/__tests__/test-merged-pr-closeout-reconciler.sh`
and `bash plugins/ship-flow/lib/__tests__/test-closeout-receipt.sh` both run against
unmodified code; the 7 new assertions above show FAIL/RED (or the documented
crash/KeyError equivalent) except item 3 (ship-missing characterization), which shows
PASS as a locked baseline. Commit: `test(closeout): add review-absent RED fixtures +
receipt round-trip + tamper-window assertions (AC-1, AC-2, AC-3 baseline)` — pathspec
both test files.

---

### T2 — Sites 1-6, coherent hot-path fix, ONE commit (AC-1, AC-2 structural, AC-3)

**Site 1** `merged-pr-closeout-reconciler.sh:1327` (`reconcile_direct_bundle`): delete
the line `[ -f "$review_file" ] || reject_input closeout-review-missing "review.md is
required for terminal closeout"`. Keep `:1328` (ship) unchanged. Verified live
(`grep -n '\$review_file'`) — `$review_file` has exactly 2 references repo-wide, both
the two reject lines being deleted (sites 1 and 2); it is used nowhere else, so its
`local review_file="$workflow_dir/$entity_slug/review.md" …` declaration becomes an
unused assignment after this deletion — leave the declaration in place (harmless,
`ship_file` on the same `local` line stays load-bearing) rather than restructuring the
line, to keep this a minimal diff.

**Site 2** `merged-pr-closeout-reconciler.sh:1880` (`reconcile_pull_request_bundle`):
identical deletion, PR-mode predicate. Keep `:1881` (ship) unchanged. Same unused-var
note applies (independent `local` declaration in this function).

**Site 3** `merged-pr-closeout-reconciler.sh:1314` (writer, `prepare_direct_bundle`,
shared by both modes): change
`"source_hashes":{"index":h(entity),"review":h(entity.parent/"review.md"),"ship":h(entity.parent/"ship.md")}`
to conditionally include `"review"` only when the file exists:
```python
_review_path = entity.parent/"review.md"
_source_hashes = {"index":h(entity), "ship":h(entity.parent/"ship.md")}
if _review_path.exists(): _source_hashes["review"] = h(_review_path)
```
and reference `_source_hashes` in the `ownership_proof` dict literal in place of the
inline 3-key block. (`h()` is the existing `read_bytes()`-based hasher at `:1136`,
unchanged — just called conditionally now.)

**Site 4** `validate-closeout-receipt.py:597` (`validate()`): replace
`require_exact_keys(hashes, {"index", "review", "ship"}, "source_hashes")` with a
range check (mirrors `require_exact_keys`'s error shape but with `review` optional):
```python
_missing = {"index", "ship"} - hashes.keys()
_extra = hashes.keys() - {"index", "review", "ship"}
if _missing or _extra:
    fail("closeout-sentinel-invalid", f"source_hashes keys mismatch; missing={sorted(_missing)}, extra={sorted(_extra)}")
```

**Sites 5+6** `apply-closeout-bundle.sh` (active-source check + byte-verify — combined
because they're the same conceptual iff enforcement in the same function flow):
- `:229-231`: change the bash loop from `for source in index.md review.md ship.md`
  to `for source in index.md ship.md` (unconditional, matches AC-3's "ship.md stays
  required").
- `:234-246` (the existing python block that already parses the receipt): insert the
  bidirectional iff check before the hash-verify loop, then generalize the loop from
  the hardcoded 3-tuple to the now-validated key set:
  ```python
  review_path = base/"review.md"
  review_exists = review_path.exists()
  expected_keys = {"index","ship"} | ({"review"} if review_exists else set())
  actual_keys = set(r["ownership_proof"]["source_hashes"].keys())
  if actual_keys != expected_keys:
      print("verdict=STOP\nreason=closeout-stage-artifacts-incoherent\ndetail=source_hashes keys do not match active source presence"); raise SystemExit(1)
  _names = {"index":"index.md","review":"review.md","ship":"ship.md"}
  for key in expected_keys:
      if h(base/_names[key]) != r["ownership_proof"]["source_hashes"][key]:
          print("verdict=STOP\nreason=closeout-projection-source-drift\ndetail=source bytes changed for "+key); raise SystemExit(1)
  ```
  This single equality check (`actual_keys != expected_keys`) covers BOTH iff
  directions in one assertion: file-exists-but-key-omitted (actual lacks `review`,
  expected has it) and key-present-but-file-missing (expected lacks `review` since the
  file check already ran at `:229-231`'s sibling for ship/index, but for review
  specifically — if the receipt claims a `review` key while `review.md` is genuinely
  absent, `expected_keys` won't contain `review` while `actual_keys` will — same
  mismatch, same reject).

**TDD contract (T2, one shared red/green pair across all 6 sites — see rationale
above for why this can't be split further):**
- `red_command`: all of T1's items 1, 2, 4, 6, 7 (as run against unmodified code).
- `expected_red_failure`: items 1/2 → `reason=closeout-review-missing`; item 4 → no
  receipt produced; items 6/7 → uncontrolled `KeyError` (not a clean reject).
- `green_command`: same tests, after this commit → items 1/2/4 GREEN; item 5 (dual-mode
  round-trip) — `--verify-outputs` leg GREEN, `--verify-sources` leg still RED (needs
  T3); items 6/7 GREEN (sites 5/6 close the applier-direction tamper window
  independently of T3, which only closes the validator-CLI-direction tamper window).
- `refactor_check`: T1's items 3 (ship-missing) and the existing-fixture no-regression
  baseline (`:533`/`:535` in `test-closeout-receipt.sh`, all 198 pre-existing
  `test-merged-pr-closeout-reconciler.sh` fixtures, all `test-apply-closeout-bundle.sh`
  fixtures per the Plan finding) all stay GREEN, unchanged.

**DC:** `bash plugins/ship-flow/lib/__tests__/test-merged-pr-closeout-reconciler.sh`
and `test-closeout-receipt.sh` and `test-apply-closeout-bundle.sh` all green except
item 5's `--verify-sources` leg (expected, closed by T3). Commit:
`fix(closeout): make review.md presence-driven across predicate/writer/validator/
applier (AC-1, AC-2, AC-3)` — pathspec all 3 files.

---

### T3 — Site 7, independent coherence fix, ONE commit (AC-2 `--verify-sources` leg)

`validate-closeout-receipt.py:522-533` (`verify_source_bytes`, `--verify-sources`
only — the reconciler's own hot path never calls this function, confirmed by design.md
§2 and re-confirmed live: `grep -n "verify_source_bytes"
merged-pr-closeout-reconciler.sh` → 0 hits). Replace the fixed 3-tuple loop with a
per-key iff, matching site 5/6's semantics:
```python
for key, filename in (("index", "index.md"), ("ship", "ship.md")):
    actual = hash_file(base / filename, f"source {key}")
    if actual != expected[key]:
        fail("closeout-projection-source-drift", f"source bytes differ for {key}")
review_path = base / "review.md"
review_exists = review_path.is_file()
review_keyed = "review" in expected
if review_exists != review_keyed:
    fail("closeout-stage-artifacts-incoherent", "review.md presence does not match receipt source_hashes")
if review_exists:
    actual = hash_file(review_path, "source review")
    if actual != expected["review"]:
        fail("closeout-projection-source-drift", "source bytes differ for review")
```
`hash_file` (`:470-476`) already fails `closeout-stage-artifacts-incoherent` on a
missing mandatory file — unchanged for `index`/`ship`. This preserves `:533` (tampered
review, both present → drift) and `:535` (removed review, key present → incoherent)
exactly, while adding the review-absent skip path and the new
file-exists-but-key-omitted reject.

**TDD contract:**
- `red_command`: T1 item 5's `--verify-sources` leg (RED after T2 alone) + T1 item 6.
- `green_command`: both GREEN after this commit.
- `refactor_check`: `test-closeout-receipt.sh:533`/`:535` still PASS.

**DC:** `bash plugins/ship-flow/lib/__tests__/test-closeout-receipt.sh` full green (all
items from T1 plus pre-existing). Commit: `fix(closeout-receipt): enforce review.md
presence iff in --verify-sources (AC-2)` — pathspec `validate-closeout-receipt.py`.

---

### T4 — `closeout-receipt-schema.yaml` doc coherence (new finding, non-code)

Not named in design.md. Verified live: this file is referenced only as a comment
pointer (`persist-closeout-intent.sh:85`), never parsed/loaded by any script — a
docs-only surface, zero test/behavior risk. But `references/closeout-receipt-schema.yaml`
is the repo's canonical schema reference, and after T2/T3 it would misdescribe the
contract:
- `:33` `review: { type: sha256 }` inside `source_hashes` — reads as unconditionally
  required. Change to note conditionality, e.g. `review: { type: sha256, optional:
  true, note: "present iff an active review.md exists at receipt-prepare time" }`.
- `:148` `verify_sources: "hash <repo-root>/<workflow>/<entity_slug>/{index,review,
  ship}.md against ownership_proof.source_hashes before merge"` — update to reflect
  review's conditional participation, e.g. append "; review.md is hashed only when
  both the file and the source_hashes.review key are present (both absent is not a
  drift)."

**DC:** `grep -n 'review' plugins/ship-flow/references/closeout-receipt-schema.yaml`
shows both lines updated; no test parses this file (confirmed above), so no
red/green pair — pure prose coherence. Commit: `docs(closeout-receipt-schema): reflect
review.md as presence-driven, not required (AC-2)` — pathspec the yaml file.

---

### T5 — Dual-env verification (AC-4)

Run, in order, and capture output:
1. `timeout 300 bash plugins/ship-flow/lib/__tests__/test-merged-pr-closeout-reconciler.sh`
2. `CI=true timeout 300 bash plugins/ship-flow/lib/__tests__/test-merged-pr-closeout-reconciler.sh`
3. `bash plugins/ship-flow/lib/__tests__/test-closeout-receipt.sh`
4. `bash plugins/ship-flow/lib/__tests__/test-apply-closeout-bundle.sh`
5. Full local loop (90s bound, informational — the reconciler file is expected to
   report FAILED here per its known pre-existing harness-bound false-negative,
   documented in verify.md 2026-07-19 and design.md §2's "Runtime constraint"; this
   loop is not this entity's AC-4 proof, commands 1-2 are):
   `for t in plugins/ship-flow/lib/__tests__/test-*.sh; do CI=true timeout 90 bash "$t" || echo FAILED:$t; done`

**DC:** commands 1-4 all exit 0 with 100% PASS lines in both env variants of command
1/2; command 5's output is captured but its reconciler-file FAILED (if any) is not
treated as a regression given the pre-existing, documented 90s-bound cause — flag
explicitly in the gate-brief (deliverable 5) so the reviewer doesn't mistake it for a
new failure.

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
