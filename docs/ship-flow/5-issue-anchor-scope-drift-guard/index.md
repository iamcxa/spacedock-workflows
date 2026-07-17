---
id: "5"
title: "Issue-anchor scope-drift guard (route-back re-anchor)"
pattern: pitch
appetite: "small-batch (2-3 days)"
layout: folder
harvest_required: true
pre_mortem:
    category: wrong-dcs
    one_liner: Guard ships as a pinned SKILL section but the re-anchor is prose the model performs hollowly, rubber-stamping on-goal without a real diff, passing verify yet catching no drift.
status: execute
stage_outputs:
    shape: shape.md
captain_bet: 當一個帶 design/plan 的 entity 被 re-shape 時,ship-shape 先攤出原始 GitHub 票的 source-diff、擋下一次真實 scope-drift;若擋不下,'route-back 多讀一次源頭票' 這個 wedge 就是錯的。
contract_decision_required: true
design_required: true
issue: "#49"
tracker: gh
worktree: /Users/kent/conductor/workspaces/spacedock-workflows/muscat
---

## Shape Report

### Hand-off to Design

- affects_ui: false
- framework_detected: n/a (methodology + shell helper; no UI surface)
- open_design_questions: []
- open_contract_decisions:
  - id: CD1 — Route-vocabulary reconciliation. Map the guard verdict onto the
    EXISTING SO/EM route enum (`proceed`/`narrow`/`return`/`block`/`costly_no`,
    defined at `plugins/ship-flow/_mods/science-officer-em.md:110`). Issue #49's
    `re-anchor`/`split` do NOT exist today; do not add new values (that changes
    the science-officer-em contract + its tests). Confirm the subset:
    `proceed`=on-goal, `narrow`=cut back to original scope, `return`=original
    goal already met by existing capability. `split` (new goal → separate issue)
    is out of scope this round.
  - id: CD2 — Enforcement style. Wired mod with a `## Hook:` heading +
    contribution-contract-style shell test, VS an inline ship-shape SKILL
    section pinned by a lighter string-assertion test. The reverse-recovery
    analog is unenforced prose (dangling path, no test); this guard MUST be
    tested. Pick the cheapest form a shell test can pin.
  - id: CD3 — Re-entry detection. Automatic (ship-shape greps the entity folder
    for design.md/plan.md to detect a re-shape) VS explicit (a CLI flag / captain
    signal). Automatic is honest to "the drift is silent"; a flag risks being
    forgotten exactly when it matters.
  - id: CD4 — Source-diff output contract (the pre-mortem mitigation). The exact
    fields the produced source-diff MUST carry so the done-check is non-hollow:
    original-issue AC list (quoted from `gh issue view`), current-scope delta,
    explicit scope-⊆-issue answer, explicit goal-still-unmet answer, verdict. A
    bare "I re-read the issue" is NOT sufficient.
- pm_framing_output: .context/shape-proposal-5.json (full stated_assumptions +
  deleted_from_shape record; shape.md rendered placeholders for those sections)

## Stage Report: plan

- DONE: plan.md carries a TDD contract (RED-before-GREEN, explicit failing test named) for each code-bearing task: the issue-anchor-guard mod + its extractable resolver block, the ship-shape SKILL invocation section, and the shell test.
  T1 (test-issue-anchor-guard.sh) / T2 (mod+resolver) / T3 (SKILL wiring) each carry `tdd_contract: {red_command, expected_red_failure, green_command, refactor_check}` in plan.md; `validate-tdd-ledger.py --plan` passes 4/4 records, `--emit-jsonl`/`--require-ledger-jsonl` round-trip clean (tdd-ledger.txt/.jsonl committed alongside plan.md).
- DONE: The named shell test file (test-issue-anchor-guard.sh) enumerates the CD2 executable-resolver assertions + CD4 per-AC source-diff fields + CD5 anchor-availability cases (empty-string=absent, gh-failure fail-visible, no-issue fallback).
  plan.md's Verification Spec (DC-1..DC-8b) and T1's steps enumerate all 9 assertions the test must pin, including DC-8a (empty-string `issue:` treated as absent) and DC-8b (PATH-stubbed failing `gh` → non-zero exit + visible error, never a fake-empty AC list).
- DONE: A Canonical Doc Actions section decides per root canonical doc (PRODUCT capabilities row; ARCHITECTURE/README) update-or-skip with rationale, honoring the design.md Reconciliation deltas as authoritative.
  plan.md Canonical Doc Actions: ROADMAP.md update (Next→Now), PRODUCT.md skip (internal quality mechanism, c14 precedent), ARCHITECTURE.md update (new `_mods` component + CD1-CD5 decision row), root README.md skip (no new contributor-facing doc).

### Summary

Plan-stage boot self-check found design.md missing the schema-required `## Design Report`/`### Captain Decisions`/`### Hand-off to Plan` envelope (confirmed empirically: `check-invariants.sh` C4 fails the moment plan.md exists without it). Backfilled it as a translation-only addition — D1-D5 map 1:1 onto the already-adjudicated CD1-CD5 Reconciliation, no new decisions introduced — then verified clean against `validate-handoff-schema.sh`, `validate-d-references.sh`, `check-design-readiness-review.sh`, and `import-design-dcs.sh`. Wrote plan.md with 4 TDD-contracted tasks (T1 write-test-first, T2 mod/resolver, T3 SKILL wiring, T4 canonical-doc sync), a 9-row Verification Spec, and the Canonical Doc Actions table. Full `check-invariants.sh` suite is clean except one pre-existing, out-of-scope finding (C14 entity-status-via-advance-stage-only on commit `cef479ff`, predating this plan and unrelated to this entity's code).

## Stage Report: execute (cycle 2)

- DONE: RED-first: add a failing assertion (shape-confirm test) proving a proposal JSON with pitch.issue and pitch.tracker causes the written entity frontmatter to carry issue: and tracker:; confirm it is RED before implementing (shape-confirm.sh currently has zero issue handling).
  `test-shape-confirm.sh` DC-5.1-1..3 added and confirmed RED (commit `b9598da`) — DC-5.1-1a/1b (folder) and DC-5.1-2 (flat) failed on real absence, not a shell error, before `shape-confirm.sh` had any issue/tracker handling.
- DONE: GREEN: shape-confirm.sh stamps issue:/tracker: into the entity frontmatter from proposal .pitch.issue/.pitch.tracker (mirror the existing cut-project pattern in instantiate-cut-project.sh which stamps external_id/external_project); absent pitch.issue -> no stamping (unchanged behavior). ship-shape SKILL prose instructs the composer to populate pitch.issue/pitch.tracker when the /shape directive references a tracker issue (#N or URL).
  `shape-confirm.sh` extracts `PITCH_ISSUE`/`PITCH_TRACKER` via the same `// ""` pattern as `PITCH_ANSWERS_DENSITY` and conditionally emits `issue:`/`tracker:` into the pitch-only frontmatter (folder `index.md` + flat `.md`), mirroring `instantiate-cut-project.sh`'s `external_id`/`external_project` stamping; DC-5.1-1..3 GREEN (commit `b46dc35`). `ship-shape/SKILL.md`'s Intake section gained a "Tracker-issue anchoring (CD5(b) bounded intake-stamping)" paragraph (same commit).
- DONE: Resolve the D5(b) silent-drop doctrine violation: mark CD5(b) IMPLEMENTED in design.md + plan.md (it now has a task+DC+test). Run gate green: new assertion + test-issue-anchor-guard.sh + shape-confirm's own tests + check-invariants. BOUNDED SCOPE: intake issue/tracker stamping ONLY — do NOT touch the guard mod, do NOT add AC-N parsing, do NOT change Linear/external_id handling.
  design.md Reconciliation CD5(b) + D5 Captain Decision marked IMPLEMENTED; plan.md gained a T5 task block (TDD contract, DC-9, Scope Anchoring row) and an Addendum explaining the post-T4 route-back (commit `d0668c6`). Gate green: `test-shape-confirm.sh` full suite (incl. DC-5.1), `test-issue-anchor-guard.sh` 32/32, `test-doc-impact-gate.sh` 112/112, `test-contribution-contract.sh` 24/24, `CI=true check-invariants.sh` clean, `check-no-dangling.sh` PASS, `check-version-triple.sh` PASS, `git diff --check` clean. `git diff --stat` confirms no touch to `issue-anchor-guard.md`, no AC-N parsing, no Linear/`external_id` change. Bulk `lib/__tests__/test-*.sh` sweep (110 files) surfaced 2 pre-existing failures (`test-advance-stage.sh` timeout, `test-stage-wiring.sh` "C14 activation boundary" FAIL) — confirmed via `git stash` baseline to pre-date this task's changes and unrelated to `shape-confirm.sh`/`ship-shape/SKILL.md`.

### Summary

Route-back from verify surfaced that CD5(b) (design.md's "future entities are born anchored" bounded intake-stamping) was adjudicated in design but never implemented in the T1-T4 execute pass — a silent-drop doctrine violation. This cycle added T5: a RED-first `test-shape-confirm.sh` assertion (DC-5.1), a two-line conditional stamp in `shape-confirm.sh` mirroring the existing `instantiate-cut-project.sh` external_id pattern, and a composer-facing instruction in `ship-shape/SKILL.md`. design.md and plan.md now mark CD5(b) IMPLEMENTED with task/DC/test references. Scope stayed bounded to intake stamping only; the guard mod, AC-N parsing, and Linear/external_id handling were untouched, confirmed via `git diff --stat` on the full commit range.

## Stage Report: execute (cycle 3)

- DONE: P1-1 + P1-4 (core-promise fixes, each RED-first): (P1-1) validate MUST require non-empty original_issue_acs AND derive goal_still_unmet + the verdict from the per-AC met_by_existing_capability rows, not trust the independently-editable scalar fields — a proceed with zero/removed AC rows or scalars inconsistent with the rows must BLOCK. (P1-4) the source-diff artifact must be run-scoped / tombstoned so a prior run's stale proceed can never be validated after a later gh-failure or an overlapping re-shape.
  RED: DC-10/DC-13 confirmed failing against the unmodified mod (commit `8028dcd`). GREEN: `iag_ac_met_values()` + derivation-based BLOCK checks in `validate`, and `rm -f "$IAG_OUT_FILE"` at the top of `emit` (commit `23d7e7e`); `test-issue-anchor-guard.sh` 53/53.
- DONE: P1-2 + P1-3 (fail-closed edge guards, each RED-first): (P1-2) the AC parser must capture each AC's multiline continuation block OR fail-closed when a matched AC heading has no substantive criterion text. (P1-3) issue-ref resolution must preserve canonical URL / owner-repo identity and fail-VISIBLE BLOCK on a cross-repo or ambiguous reference instead of silently reducing a foreign URL to a local #N.
  RED: DC-11/DC-12 confirmed failing against the unmodified mod (commit `8028dcd`) — DC-12's fixtures were rewritten to pair each reference with a would-succeed `gh` stub so the signal isn't a coincidental real-`gh` 404. GREEN: `iag_parse_ac_blocks()` awk state machine + `IAG_EMPTY_AC` fail-closed check, and an owner/repo-qualified-reference BLOCK before any `gh` call (commit `23d7e7e`).
- DONE: BOUNDED + GREEN: all edits confined to `plugins/ship-flow/_mods/issue-anchor-guard.md` (resolver) + new assertions in `test-issue-anchor-guard.sh` — `shape-confirm.sh`, `ship-shape/SKILL.md`, and re-entry detection untouched. RED->GREEN evidence recorded per fix in execute.md; full local gate green.
  `git diff --stat` across both commits touches only the two named files. `test-issue-anchor-guard.sh` 53/53; `node --test plugins/ship-flow/bin/*.test.mjs` 79/79; `test-doc-impact-gate.sh` 112/112; `test-contribution-contract.sh` 24/24; `test-shape-confirm.sh` full suite; `CI=true check-invariants.sh` clean (C14 both variants OK); `check-no-dangling.sh` PASS; `check-version-triple.sh` PASS; `git diff --check` clean.

### Summary

Route-back from verify surfaced four resolver-level gaps in `issue-anchor-guard.md` that T1-T5 never touched: `validate` trusted independently-editable scalars instead of deriving them from the per-AC rows (P1-1), the AC parser silently accepted an empty-text heading and dropped multiline continuation (P1-2), `issue:` resolution didn't distinguish same-repo `#N` from a cross-repo/ambiguous reference (P1-3), and a later failed `emit` left a prior run's stale `verdict: proceed` file on disk for `validate` to find (P1-4). Each fix followed RED-first TDD: DC-10..DC-13 added to `test-issue-anchor-guard.sh`, confirmed failing against the unmodified mod (36/53, commit `8028dcd`), then all four fixed together in the resolver (53/53, commit `23d7e7e`). Scope stayed bounded to the mod + its test file, confirmed via `git diff --stat`.

## Stage Report: execute (cycle 4)

- DONE: P1-A (non-hollow crux, RED-first): validate must STRUCTURALLY enforce original_issue_acs is a non-empty array where EVERY row has non-empty criterion text AND a real boolean met_by_existing_capability (use yq structural parse — yq is available and shape-confirm.sh already uses it — not a fragile text scan); goal_still_unmet + verdict derive from those rows; a verdict=proceed with any missing/empty/malformed/duplicate-count row must BLOCK. This closes the STRUCTURAL hole (the irreducible SEMANTIC residual — a model filling fields with a false judgment — stays named+accepted, do not chase it).
  RED: DC-14 (3 assertions: empty text, non-boolean `met_by_existing_capability`, text-embedded substring miscounted as a phantom row) confirmed failing against the unmodified mod (commit `fd0781f`). GREEN: `iag_ac_rows_count()` + `iag_ac_row_met_value()` replace the line-oriented `iag_ac_met_values()` with a yq structural parse — each row is indexed and type-checked (`!!seq`/`!!map`/`!!bool`) rather than text-scanned (commit `3e6eeda`); `test-issue-anchor-guard.sh` 66/66.
- DONE: P1-B + P1-C (contract reconcile, each RED-first): (P1-B) the resolver must canonicalize a verified SAME-REPO GitHub issue URL to #N and ACCEPT it (so ship-shape/SKILL.md's advertised full-URL intake actually works end-to-end), while still fail-VISIBLE BLOCK on cross-repo / Linear / ambiguous refs; SKILL intake wording and resolver accepted-forms must agree. (P1-C) shape-confirm.sh must validate issue+tracker as an all-or-nothing typed pair (tracker in {gh, linear}; both present or neither; YAML-safe values) — reject half-anchored or malformed pairs instead of committing them while reporting success.
  RED: DC-15 (2 assertions: verified same-repo URL wrongly BLOCKed) and DC-5.1-4/5/7 (6 assertions: half-anchored pair, bad tracker enum, newline-in-issue all silently accepted) confirmed failing against the unmodified files (commit `fd0781f`). GREEN: (P1-B) `iag_local_owner_repo()` reads the local `git remote get-url origin`, and a full-URL reference whose owner/repo matches is canonicalized to `IAG_ISSUE_BARE` and accepted, else the existing cross-repo BLOCK fires unchanged; `ship-shape/SKILL.md`'s Tracker-issue anchoring paragraph now states the pairing + verification rule explicitly. (P1-C) `shape-confirm.sh` gates right after `PITCH_ISSUE`/`PITCH_TRACKER` extraction: presence-parity check, `tracker` enum {gh,linear}, and an embedded-newline check on `issue`, each exiting 10 before any write (commit `3e6eeda`); `test-issue-anchor-guard.sh` 66/66, `test-shape-confirm.sh` full suite green.
- DONE: P2-D + BOUNDED + GREEN: (P2-D) the AC-block parser must accept ONLY properly-indented continuation lines and flush/BLOCK when unindented content begins (no silent absorption of a following section). Edits confined to issue-anchor-guard.md (resolver) + shape-confirm.sh (P1-C) + ship-shape/SKILL.md (P1-B intake wording only) + test assertions in test-issue-anchor-guard.sh / test-shape-confirm.sh — NO new features, NO change to re-entry detection or the guard's core flow. RED->GREEN evidence per fix in execute.md; full local gate green (both test files, check-invariants clean incl C14+C15, no-dangling, version-triple).
  RED: DC-16 (4 assertions: an unindented section silently absorbed into AC-1's text; a no-inline-text AC heading followed by an unindented section wrongly accepted with fabricated criterion text) confirmed failing against the unmodified mod (commit `fd0781f`). GREEN: a new `have && /^[^[:space:]]/ { flush(); have = 0; buf = ""; next }` rule in `iag_parse_ac_blocks()`'s awk state machine ends continuation capture the moment an unindented, non-blank, non-AC-heading line appears (commit `3e6eeda`). `git diff --stat` across both commits confirms edits confined to `issue-anchor-guard.md`, `shape-confirm.sh`, `ship-shape/SKILL.md` (intake paragraph only), and the two test files. Full gate: `test-issue-anchor-guard.sh` 66/66; `test-shape-confirm.sh` full suite; `node --test plugins/ship-flow/bin/*.test.mjs` 79/79; `test-doc-impact-gate.sh` 112/112; `test-contribution-contract.sh` 24/24; `CI=true check-invariants.sh` clean (C14 both variants + C15 OK); `check-no-dangling.sh` PASS; `check-version-triple.sh` PASS; `git diff --check` clean.

### Summary

Route-back from verify surfaced four further gaps in `issue-anchor-guard.md`/`shape-confirm.sh` that cycles 1-3 never touched: `validate`'s non-hollow check was still a fragile line-oriented text scan vulnerable to a phantom-row miscount (P1-A), a full GitHub issue URL always cross-repo-BLOCKed even when it verifiably referenced the local repo (P1-B), `shape-confirm.sh` stamped `pitch.issue`/`pitch.tracker` independently with no pairing or enum validation (P1-C), and the AC-block parser absorbed any non-blank line regardless of indentation, letting a following section's prose masquerade as AC criteria (P2-D). Each fix followed RED-first TDD: DC-14/DC-15/DC-16 added to `test-issue-anchor-guard.sh` and DC-5.1-4/5/7 added to `test-shape-confirm.sh`, confirmed failing against the unmodified files (commit `fd0781f`), then all four fixed together (commit `3e6eeda`) — `test-issue-anchor-guard.sh` 66/66, `test-shape-confirm.sh` full suite green. Scope stayed bounded to the resolver + shape-confirm.sh + SKILL.md's intake paragraph + the two test files, confirmed via `git diff --stat`.

## Stage Report: execute (cycle 5)

- DONE: P1-r3-1 (real flow bug, RED-first): the ship-shape guard invocation must be GATED so it fires ONLY when Intake matches an EXISTING entity (a re-shape of /shape <entity-id>); a brand-new free-text or todo-based /shape must NOT hit the resolver's "entity path not found" BLOCK. Move/gate the guard section in ship-shape/SKILL.md to run after Intake determines new-vs-existing, and add an end-to-end test proving a new-shape form does not invoke the guard or is a clean no-op.
  RED: DC-6 flipped (guard section still before `### Intake`) + new DC-17 (4 text assertions: Entity id / Free text / Todo tid / "entity path not found" gating language absent) confirmed failing against the unmodified SKILL.md (commit `74c498d`, 67/72). GREEN: moved `<!-- section:issue-anchor-guard -->` to after `### Intake`, retitled "Post-Intake: Issue-Anchor Guard (existing-entity re-shape only)", with explicit gating prose; `issue-anchor-guard.md`'s `## Hook: pre-shape` + Invocation prose updated to match (commit `b943212`); `test-issue-anchor-guard.sh` 72/72.
- DONE: Name the deferred residuals (NO code fix this round): file ONE rabbit-hole todo "issue-anchor-guard-resolver-shell-parser-robustness" capturing P1-r3-2 (tombstone removal must check success + abort before fetch when it fails), P1-r3-3 (scalar validation via structural yq), P1-r3-4 (Markdown-aware AC extraction). Also name these three as accepted shell-parser-robustness residuals in the mod's Boundary section.
  `docs/ship-flow/todos/issue-anchor-guard-resolver-shell-parser-robustness.md` filed + ROADMAP.md `later` row appended via `patch-map.sh` (commit `6906f29`); the same three residuals documented in `issue-anchor-guard.md`'s Boundary section (commit `b943212`).
- DONE: BOUNDED + GREEN: edits confined to ship-shape/SKILL.md (guard gating), the resolver mod (Hook/Invocation prose + residual note, no logic change), test assertions, and the one rabbit-hole todo — NO code fix for P1-r3-2/3/4, NO other features. RED->GREEN evidence in execute.md; full local gate green.
  `git diff --stat f3474d0..HEAD` (excluding this Stage Report + execute.md doc-only commits) touches exactly `plugins/ship-flow/skills/ship-shape/SKILL.md`, `plugins/ship-flow/_mods/issue-anchor-guard.md`, `plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh`, `docs/ship-flow/todos/issue-anchor-guard-resolver-shell-parser-robustness.md`, `ROADMAP.md`. Full gate: `test-issue-anchor-guard.sh` 72/72; `test-shape-confirm.sh` full suite unaffected; `node --test` 79/79; `test-doc-impact-gate.sh` 112/112; `test-contribution-contract.sh` 24/24; `CI=true check-invariants.sh` clean (C14 both variants + C15 OK); `check-no-dangling.sh`/`check-version-triple.sh` PASS; `git diff --check` clean.

### Summary

Route-back from verify surfaced a genuine flow bug: ship-shape/SKILL.md invoked the Issue-Anchor Guard unconditionally before Intake, so a brand-new free-text or todo-based `/shape` (no existing entity yet) could hit the resolver's "entity path not found" BLOCK — contradicting design premise A1. Fixed by moving the guard section to after Intake and gating it explicitly on the "Entity id" (existing-entity) form, with the mod's own Hook/Invocation prose updated to match (both were previously out of sync — the mod's Hook heading already said "for every `/shape <entity-id>` ... re-entry" but the SKILL.md wiring never enforced that gate). RED-first: flipped DC-6's ordering assertion and added DC-17's gating-language assertions, confirmed failing (commit `74c498d`), then GREEN (commit `b943212`). Filed the one required rabbit-hole todo for the three named shell-parser-robustness residuals (P1-r3-2/3/4), documented identically in the mod's Boundary section — no code fix, honest deferral per the guard's own philosophy. execute.md's still-open cycle 2/3 addenda were collapsed into trimmed `<details>` blocks (matching the cycle 1/4 precedent) to stay under the C15 raw-line cap before appending this cycle's evidence. Scope stayed bounded to exactly the five files named above, confirmed via `git diff --stat`; design.md/plan.md's "before Intake" wording is now stale relative to the corrected wiring but is out of this cycle's allowed edit list (noted for verify/doc-sync).
