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
status: plan
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
