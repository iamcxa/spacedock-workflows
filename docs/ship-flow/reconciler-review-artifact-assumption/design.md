# Design: Fix reconciler review-artifact validation

Design-stage output only. No implementation. All file paths are plugin-tree
relative (`plugins/ship-flow/...`) on this worktree, base `origin/main`.

## 0. Reconciler version confirmation (checklist item 3)

The bug reconciler present on this worktree base is the **0.9.0** version:
`plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh` is **2171 lines**
(`wc -l`), matching the shape's 0.9.0 reference — NOT muscat-v1's pre-0.9.0
458-line reconciler (which has no artifact check). The design and all line
citations below are against this 2171-line file.

`ship.md` stays **required**: it feeds `## Todo Closeout Digest` extraction
(`merged-pr-closeout-reconciler.sh:1151-1152`, `raise SystemExit("ship.md is
missing Todo Closeout Digest")`) and the `ship_rel` archived-ship output path
(`:1148`, `:1317` receipt `outputs.ship`). The fix narrows the required set to
`{ship.md}`, not `{}`. Only the `review.md` requirement is loosened.

## 1. Receipt-schema contract choice — PINNED (checklist item 1)

**Decision: OMIT the `review` key from `source_hashes` when `review.md` is
absent** (presence-driven). Rejected alternative: substitute `verify.md` under
an explicit key.

Rationale:
- **Workflow-agnostic.** `merged-pr-closeout-reconciler.sh` is a generic tool
  shared across workflows; it has **zero** references to `verify.md` (grep:
  all `verify` hits are `git rev-parse --verify`). Substituting `verify.md`
  would bake this workflow's 8-stage taxonomy ("review folded into verify")
  into a generic reconciler — exactly the dynamic-taxonomy coupling the shape
  ruled out of scope ("Reading stage taxonomy from README … out-of-appetite").
- **Deterministic.** `proof_hash` is `sha256(json.dumps(payload,
  sort_keys=True, …))` (`:1319`; validator recomputes identically). For a
  given artifact set the `source_hashes` object is byte-identical regardless of
  dict insertion order, so omission keeps `proof_hash` deterministic and
  reviewable. Review-present set → `{"index","review","ship"}`; review-absent
  set → `{"index","ship"}`.
- **Honest provenance, drift preserved.** The receipt records exactly the
  artifacts present. `ship.md`'s hash still anchors the review-bearing content
  (this workflow's `## Canonical Docs Update` lives in `ship.md`). Validators
  verify `review` **when the receipt carries the key**, so every existing
  tamper/removal test stays valid (see §3).

**Bidirectional presence constraint (rev 2 — closes a tamper window).**
"Omit when absent" alone is one-directional: a self-rehashed receipt could
omit the `review` key while an active regular `review.md` EXISTS. Enforcement
that merely iterates keys-present-in-the-receipt would skip hashing
`review.md` at `apply-closeout-bundle.sh:229-242`, yet
`copy_tracked_entity_tree` (`:100-119`, invoked at `:339`) archives every
git-tracked file under the active entity — the file would land in `_archive/`
with **no hash binding it to `proof_hash`**. The contract is therefore an iff:
**the `review` key MUST be present iff an active regular `review.md` exists**,
enforced in BOTH directions wherever repo state is visible:

- *file exists → key required*: the applier (critical path) computes the
  expected key set as `{index,ship} ∪ ({review} if review.md exists)` and
  requires the receipt's `source_hashes` keys to EQUAL it before hashing;
  `verify_source_bytes` (`--verify-sources`) applies the same rule. Structural
  `validate()` (`:597`) cannot see the repo, so it enforces only the key
  envelope: `{index,ship} ⊆ keys ⊆ {index,review,ship}`.
- *key present → file must exist and match*: unchanged hash-verify semantics
  (missing file → `closeout-stage-artifacts-incoherent`, tampered →
  drift/mismatch).

**Fixtures pinning each direction:**
- *file-exists-but-key-omitted rejects* (NEW, both surfaces): a
  `test-closeout-receipt.sh` assertion — seed `review.md`, hand-craft a
  self-rehashed receipt with `source_hashes={index,ship}` →
  `validate --verify-sources` REJECTS; and a
  `test-merged-pr-closeout-reconciler.sh` applier-path assertion — same
  crafted receipt driven through `apply-closeout-bundle.sh` stops before
  archive.
- *key-present-but-file-missing rejects* (EXISTING, must stay green):
  `test-closeout-receipt.sh:535` (`rm review.md` →
  `closeout-stage-artifacts-incoherent`) pins this direction unchanged.

**`require_exact_keys` forces a validator change under BOTH options** — it
fails on missing AND extra keys (`validate-closeout-receipt.py:56-58`).
Omitting `review` → `missing=["review"]` → `closeout-sentinel-invalid`; adding
a `verify` key → `extra=["verify"]`. So neither option is "reconciler-only";
the receipt schema is a contract jointly enforced by the writer, the validator,
and the applier (§2). "Omit" is the minimal coherent change.

**Named fixture assertion that pins the review-absent receipt shape:**
a NEW assertion in `test-merged-pr-closeout-reconciler.sh`, modeled on the
existing golden-receipt assertion at **`:4917`** (`"source_hashes":{"index":…,
"review":…,"ship":…}`), built from a review-absent fixture and asserting the
emitted receipt's `ownership_proof.source_hashes == {"index":<sha>,"ship":<sha>}`
with NO `review` key, and `proof_hash == sha256` over the recomputed payload
(same expected-receipt Python pattern as `:4902-4924`). Complemented by a
`test-closeout-receipt.sh` round-trip in BOTH validator modes: a review-absent
receipt (`source_hashes` = `{index,ship}`, no active `review.md`) passes
`validate --verify-outputs` AND passes `validate --verify-sources`. The
`--verify-sources` leg is mandatory (rev 2): `verify_source_bytes` runs ONLY
under `--verify-sources` (`validate-closeout-receipt.py:745-748`), so an
`--verify-outputs`-only round-trip would never execute the changed
source-verify path.

## 2. Change-site → test map (checklist item 2)

The two predicate sites named in the shape are the entry points; the `review.md`
requirement is enforced at **6 mandatory sites across 3 files** plus 1 coherence
site. All apply the SAME conceptual change: make `review` presence-driven.

### Mandatory (on the reconcile critical path)

| # | Site | Current behavior | Change |
|---|------|------------------|--------|
| 1 | `merged-pr-closeout-reconciler.sh:1327` (`reconcile_direct_bundle`, shape :1326-1328) | `[ -f review.md ] \|\| reject_input closeout-review-missing` | drop the review reject; keep ship reject (`:1328`) |
| 2 | `merged-pr-closeout-reconciler.sh:1880` (`reconcile_pull_request_bundle`, shape :1877-1881) | same reject (`:1880`) | drop the review reject; keep ship reject (`:1881`) |
| 3 | `merged-pr-closeout-reconciler.sh:1314` (receipt writer in `prepare_direct_bundle`, shared by both modes) | `source_hashes` unconditionally `"review":h(review.md)`; `h()` = `read_bytes()` (`:1136`) → **crashes** on absent file → `render_rc!=0` → `reject_input closeout-stage-artifacts-incoherent` (`:1344`) | emit `review` key only when `review.md` exists |
| 4 | `validate-closeout-receipt.py:597` (`validate()`, runs on every call — `:732`, before `--verify-outputs`) | `require_exact_keys(hashes, {"index","review","ship"})` | require `{index,ship}`; allow optional `review` |
| 5 | `apply-closeout-bundle.sh:229-231` (active-source check, reached via reconciler `:1364` direct / `:1807` PR) | `for source in index.md review.md ship.md: [ -f ] \|\| stop closeout-stage-artifacts-incoherent` | require index+ship always; enforce the §1 iff — receipt `source_hashes` keys must EQUAL `{index,ship} ∪ ({review} if review.md exists)` |
| 6 | `apply-closeout-bundle.sh:240-242` (inline byte-verify) | hardcoded 3-tuple hashes `review.md` | hash-verify the bidirectionally-validated key set from site 5 — NOT merely keys-present-in-receipt, which would let an omitted-key receipt archive an unhashed `review.md` via `copy_tracked_entity_tree` (`:100-119`, called at `:339`) |

Sites 1-2 (direct) block first; site 3 crashes render if the predicate is
removed alone; sites 5-6 block at apply even after 1-3 are fixed. Site 4 blocks
the PR-mode re-validation path (`validate_receipt_normal --verify-outputs`,
`:1059`) and any receipt re-scan. **A predicate-only fix is a silent failure:**
the reject moves from `closeout-review-missing` to
`closeout-stage-artifacts-incoherent` at render/apply, still blocking closeout.

### Coherence (off the reconciler hot path, exercised by tests)

| # | Site | Note |
|---|------|------|
| 7 | `validate-closeout-receipt.py:530` (`verify_source_bytes`, `--verify-sources` only; reconciler never calls it) | enforce the §1 iff per key: review file exists XOR `review` key present → fail; both present → hash-verify; both absent → skip. Preserves `test-closeout-receipt.sh` `--verify-sources` semantics (`:533` tamper, `:535` removal) while rejecting file-exists-but-key-omitted receipts |

Verified non-site (rev 2): `preflight_lexical_paths` (`apply-closeout-bundle.sh:38-64`)
receives `$ACTIVE_ENTITY_RELATIVE/review.md` explicitly (`:207`) but is
lexical/symlink-safety only — `os.path.lexists` gates the symlink check, so a
missing `review.md` passes. No change needed.

### Tests that pin the predicate + receipt today (impact across the 198-test suite)

- **The reject path is currently UNTESTED.** `closeout-review-missing` and
  `closeout-ship-missing` appear **zero** times in
  `test-merged-pr-closeout-reconciler.sh`. There is no test asserting either
  reject; the predicate has only implicit positive coverage.
- **Every fixture seeds `review.md`.** Full-closeout tests build the entity
  with `review.md` present (e.g. fixture setups at `:381`, `:419`, `:1004`,
  `:4062`, `:4469`, `:4980`; each `printf … > review.md`). They pin the
  review-**present** PROCEED path and the golden receipt shape (`:4917`).
- **Impact = no regression.** Because all 198 tests seed `review.md`, sites
  1-6 are behavior-preserving for the existing suite (review present → reject
  never fires, `review` hash still emitted, `require_exact_keys` still sees the
  key, apply still finds the file). Expected result: **198/198 stay green**;
  risk is confined to the NEW review-absent tests.
- **`test-closeout-receipt.sh` receipt fixtures** (`:41`, `:84-85`, `:131`,
  `:190`, `:263`) embed all three `source_hashes` keys and stay green (review
  present). Its drift tests — tampered review `:533` → `closeout-projection-
  source-drift`; removed review `:535`/`:561` → `closeout-stage-artifacts-
  incoherent` — stay valid **only because** the fix keeps verifying review
  when the key is present (site 7's iff: both-present → hash-verify). This is
  a binding constraint on the validator change: do NOT stop verifying review
  outright, and do NOT reduce it to keys-present-only (§1 tamper window).

### Runtime constraint (>=300s standalone)

`test-merged-pr-closeout-reconciler.sh` is **5328 lines / 198 tests** and
exceeds the harness's 90s-per-file bound (`exit 124` false-TIMEOUT recorded in
verify.md 2026-07-19; re-run alone at 300s → 198/198 PASS). The ~7 new
tests (§3) marginally increase runtime; the plan MUST schedule this
file standalone at **≥300s** and confirm **AC-4 dual-env** (local 129-file loop
AND `CI=true`). Do not rely on the 90s batch bound for this file.

## 3. Test plan (RED-then-GREEN, per AC)

- **AC-1 predicate (RED→GREEN), BOTH modes independently (rev 2).** TWO new
  reconciler tests, one per predicate: (a) **direct mode** — review-absent
  fixture (`verify.md`+`ship.md`, no `review.md`) through
  `reconcile_direct_bundle` → today `closeout-review-missing` (`:1327`), after
  fix PROCEED; (b) **pull-request mode** — review-absent fixture through
  `reconcile_pull_request_bundle` → today `closeout-review-missing` (`:1880`),
  after fix proceeds past the predicate. The two sites are independent code
  paths: a fix touching only the direct predicate MUST leave test (b) RED.
  Plus existing-fixture no-regression (review present still PROCEED — already
  covered).
- **AC-2 receipt shape (new assertions).** The `:4917`-modeled review-absent
  assertion from §1 (source_hashes `{index,ship}`, no review key, deterministic
  `proof_hash`) + the dual-mode `test-closeout-receipt.sh` round-trip from §1
  (review-absent receipt passes `validate --verify-outputs` AND
  `validate --verify-sources` — the latter is the only mode that executes the
  changed `verify_source_bytes`) + the two direction-A tamper fixtures from §1
  (file-exists-but-key-omitted rejects at validator and at applier). Existing
  `test-closeout-receipt.sh` fixtures + drift tests stay green (§2).
- **AC-3 fail-closed (RED).** New reconciler test: NO `ship.md` → still
  `closeout-ship-missing` (no existing test pins this). `canonical-doc-sync-
  checker.sh` unchanged (out of scope; already accepts review OR ship).
- **AC-4 dual-env.** Standalone ≥300s local loop AND `CI=true`; capture both
  outputs.

## 4. Scope reconciliation / FO flag

The shape scoped "`merged-pr-closeout-reconciler.sh` predicate + receipt schema
only" and reproduced the bug at the two predicates. Layer-tracing the closeout
path shows the `review.md` requirement is **not** contained there: it is a
receipt-schema contract co-enforced by the writer (`reconciler:1314`), the
validator (`validate-closeout-receipt.py:597`, `:530`), and the applier
(`apply-closeout-bundle.sh:229-231`, `:240-242`) that the reconciler invokes at
`:1364`/`:1807`. This is not scope creep — it is the honest extent of "the
receipt schema": omitting the downstream sites ships a fix that passes a
predicate unit test yet **still blocks closeout at apply time**
(`closeout-stage-artifacts-incoherent`).

Recommendation: the coherent fix is **one conceptual change** (the §1 iff:
`review` key present iff active `review.md` exists) replicated across
**3 files / 6 mandatory sites** (+1 coherence site) with **~7 new tests**
(§3). Surface area is larger than a single
predicate edit (nearer M than the shaped S), but the change is mechanical and
bounded. FO/captain should confirm this expanded-but-bounded scope before
plan/execute. **Execution prerequisite (unchanged from shape):** land on the
main/scheduler-controller lineage that actually runs during ticks — NOT
muscat-v1 (its 458-line reconciler has none of these sites).

Out of scope (unchanged): C14 completion contract, RoboRev/semantic-review
gate, `canonical-doc-sync-checker.sh`, workflow-template.yaml taxonomy drift,
dynamic taxonomy-reading, and backfill re-tick of stalled entities (FO-owned).
