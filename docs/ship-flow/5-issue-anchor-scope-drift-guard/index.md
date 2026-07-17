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
status: verify
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
