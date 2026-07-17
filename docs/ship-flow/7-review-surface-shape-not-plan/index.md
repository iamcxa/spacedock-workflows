---
id: "7"
title: "Ship-flow core: the human review surface is the shape/spec, not plan.md"
pattern: pitch
appetite: "small-batch"
layout: folder
harvest_required: true
answers_density: "high"
affects_ui: false
design_required: false
contract_decision_required: false
pre_mortem:
  category: wrong-dcs
  one_liner: 'The C16 string-test pins that the rule text exists but not that the FO obeys it, so verify passes while FO behavior stays unchanged (accepted: the value is discoverability + regression-proofing, not behavioral enforcement).'
status: shape
stage_outputs:
  shape: shape.md
captain_bet: "以後 FO 不會再叫我看 plan，反而會用白話方式多跟我確認 spec (shape) 的內容"
issue: "#60"
tracker: gh
worktree: /Users/kent/conductor/workspaces/spacedock-workflows/muscat/.claude/worktrees/issue-60
---

## Captain Bet (gate approval 2026-07-18)

> 以後 FO 不會再叫我看 plan，反而會用白話方式多跟我確認 spec (shape) 的內容

Captain-authored at the shape gate. Retro at ship + 2 weeks: did the Bet match outcome? YES / NO / PARTIAL. If NO: which Will-get line was wrong?

## Domain Registry Validation
- classify: bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/registry-resolve.sh" --classify docs/ship-flow/7-review-surface-shape-not-plan/shape.md
- validate: bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/registry-resolve.sh" --validate --domain=schema
- domain: none
- result: proceed

**False-positive determination (FO override, evidence-backed — not a silent skip):**
`--classify` returned `matched=schema` from a single lexical token — one mention of "the existing workflow **schema** (`manual:` field)" in assumption A1 (shape.md:38), which is methodology prose about a workflow-config field, NOT a data/DB schema change. `required_skills` and `skill_hints` came back empty. `--validate --domain=schema` returns `status=ok` only because a schema specialist exists in the plugin-default registry — it does not imply this pitch needs one. #60's entire scope is `INVARIANTS.md` prose + a `check-invariants.sh` string-assertion (C16) + its test + doc-sync — **zero** schema / migration / storage / data-model surfaces. `domain:` is deliberately left unset; routing a prose + shell-check change to the design stage on a keyword hit would be disproportionate ceremony with no contract to decide. The enforcement style (string-assertion check) is fixed by the issue AC and mirrors the existing C1–C15 pattern, so no contract ambiguity is buried by skipping design.

### Hand-off to Plan
- design-skipped: true
- open_design_questions: []
- open_contract_decisions: []
