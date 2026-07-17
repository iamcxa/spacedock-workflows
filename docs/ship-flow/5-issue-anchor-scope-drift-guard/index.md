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
