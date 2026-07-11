---
id: "1"
title: "Self-adoption dogfood bootstrap — canonical docs + doc-impact gate"
status: design
pattern: pitch
appetite: "small-batch"
layout: folder
harvest_required: true
answers_density: "low"
source: 2026-07-11 captain decision (dogfood bundle) + 2026-07-08 joint audit
started: 2026-07-11T05:59:50Z
completed:
verdict:
score: 0.9
worktree: .worktrees/spacedock-ensign-1-self-adoption-dogfood-bootstrap
issue:
pr:
domain: schema
affects_ui: false
contract_decision_required: true
pre_mortem:
    category: wrong-dcs
    one_liner: Declaration escape-hatch becomes rubber-stamp default; PRs carry boilerplate none-reasons and prose drift continues despite a green gate — coupling-map tuning was the real value, unmeasured.
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
| design | [design.md](design.md) |
<!-- /section:stage-artifact-links -->

## Problem

The plugin repo does not obey its own methodology: the repo root had no
PRODUCT.md / ROADMAP.md / ARCHITECTURE.md (check-invariants Principle 5b
WARNs and skips), plugin development bypasses ship-flow entirely, and the
only doc-currency protection for prose is manual audits (PR #6 found stale
version claims exactly this way; the root README still claimed 0.7.0 /
spacedock 0.22.0 at shape time). Adopters (carlove) are gated by the very
machinery this repo skips. Full framing: [shape.md](shape.md).

## Acceptance criteria

**AC-1 — Principle 5b enforces instead of skipping.**
Root ARCHITECTURE.md exists with the flow-map-schema six section markers
(mermaid for context/containers/components); PRODUCT.md and ROADMAP.md exist
with patchable section markers. Verified by: `CI=true bash
plugins/ship-flow/bin/check-invariants.sh` output contains no
`WARN [Principle 5b]` skip line.

**AC-2 — Routing policy is a code gate, not prose.**
A plugin-shipped `doc-impact-gate` checker (config-driven couplings +
declaration syntax) runs in this repo's CI and fails a plugin-touching PR
above the configured threshold that neither touches the coupled docs nor
carries a `doc-impact: none — <reason>` declaration. Verified by: the
checker's own test suite (RED-first) + one live CI run showing the gate
evaluated on a real PR.

**AC-3 — The canonical-doc sync loop runs end-to-end on a real entity.**
This entity itself travels shape → design → plan → execute → verify → ship
in this workflow, and ship-review's canonical-doc sync writes the resulting
PRODUCT/ROADMAP/ARCHITECTURE updates (or explicit skip rationales) as
pipeline output. Verified by: this entity's review.md `## Canonical Docs
Update` section citing real commits, and
`bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/bin/canonical-doc-sync-checker.sh"
docs/ship-flow/1-self-adoption-dogfood-bootstrap` exiting 0.
(Path updated from the pre-confirm flat slug at shape-confirm, 2026-07-11.)

**AC-4 — T3 rideshare: harvest vocabulary decision record.**
A short reference (pr-merge-paths pattern) pins the correspondence between
debrief-guardrail-harvest's six buckets, harvest-decide's four outcomes, and
kc-forge's D1/D2 layers. Verified by: file exists under
`plugins/ship-flow/references/` and is linked from the plugin README's
further-reading list.

## Captain Bet (gate approval 2026-07-11)

> 「這組跑完後 ship flow 就正式使用自身規則開發自己，且可搭配 claude or codex
> 的 goal 指令drive」 — captain, verbatim

Organized into template form (captain's words, agent-formatted):
Bet: when this ships, captain expects ship-flow to officially develop itself
under its own rules — this entity completes shape→design→plan→execute→verify→ship
with `canonical-doc-sync-checker.sh` exiting 0 — and the pipeline to be
drivable via a `/goal` command, within this pitch's small-batch window. If
not, this pitch was wrong about W3 (sync loop proven end-to-end) or the
goal-driveability claim.

Boundary note (flagged at gate, 2026-07-11): Codex-side `/goal` drive is
outside W1–W4 scope (root README: full pipeline under Codex is unverified
this release). At retro, an unmet Codex-drive expectation scores the Bet
PARTIAL, not a pitch failure.

Retro prompt (re-read at ship + 2 weeks): Did the Bet match outcome?
YES / NO / PARTIAL. If NO: which Layer 1 line was wrong?

## Captain Articulation Trail

**Q1 (Problem)**: What gets worse without this?
> 「用 ship-flow 開發 ship 時為何 plugin 內沒有 product.md ARCHITECTURE.md
> CONTRACT.md 一類的檔案？那如何確保 ship-flow 的所有文件本身都自包含且一定
> 最新？如何把 ship 規範用在迭代 flow 自身上？」 (2026-07-11 verbatim;
> confirmed at gate)

**Q2 (Appetite)**: How long?
> small-batch (2-3d) — agent-recommended, captain ratified via gate confirm.

**Q3 (Wedge)**: If you could only do ONE part, which?
> 「我要確保 ship 開發時應該要確保遵守自身的規範」→ the doc-impact-gate code
> gate (AC-2); confirmed at gate.

**Q4 (Out-of-scope)**: What do you happily NOT include?
> Captain-ratified ruling: LLM semantic verification never enters required CI
> (carlove R3 scar); helm wiring and carlove pilot stay tracked in their own
> repos; confirmed at gate.

**Q5 (Assumption/Bet)**: What are you betting on that could be wrong?
> Captured verbatim as the Captain Bet above (2026-07-11).

## Domain Registry Validation
- classify: bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/registry-resolve.sh" --classify docs/ship-flow/self-adoption-dogfood-bootstrap.md
- validate: bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/registry-resolve.sh" --validate --domain=schema
- domain: schema
- result: proceed

### Hand-off to Design

- `affects_ui: false` — `ui_surfaces` / `framework_detected` omitted.
- `open_design_questions`: []
- `open_contract_decisions[]`:
  1. Coupling-config format and location — plugin-shipped default vs adopter
     override path; YAML schema for `couplings[] = {srcGlobs → docPaths}`.
  2. Declaration grammar and placement — `doc-impact: none — <reason>` in PR
     body vs repo file; reason quality bar (cf. canonical-doc-sync-checker's
     ≥12-char rationale precedent).
  3. Size-threshold semantics — diff LOC vs file count vs path-class; which
     paths count as "plugin-touching".
  4. Checker family — shell (`bin/*.sh` + `lib/__tests__/test-*.sh`) vs node
     (`bin/*.mjs` + sibling `*.test.mjs`); determines test location and which
     CI step auto-collects it.
- `pm_framing_output`: shape.md `pm-skill-receipts` section (all four
  delegates ran as inline fallbacks — none installed in this environment).

## Stage Report

### shape — 2026-07-11

Checklist accounting: 3 done, 0 skipped, 0 failed.

1. DONE — shape.md with problem / acceptance outcome / appetite / typed
   children + DAG; written by `shape-confirm.sh --layout=folder`
   (commit `41f291b`, 9 files: pitch folder, 3 children, 3 todos, ROADMAP
   rows in next/later/not-doing).
2. DONE — ROADMAP `next` row intent landed via patch-map append; canonical-doc
   impact intent recorded as explicit bootstrap-case rationale: ARCHITECTURE.md
   does not exist yet — its creation IS child 1.1's deliverable, so no
   architecture-impact `before:` block is extractable at shape; ship-review's
   canonical sync patches sections at ship (AC-3 proves the loop).
3. DONE — captain gate resolved: confirm + captain-authored Bet (verbatim
   above); fork decision (i) native numeric-prefix confirm path; cross-review
   verdict PROMPT_CAPTAIN presented with both concerns and dispositions.

Notes for downstream stages:
- Children files carry `pattern: shaped-child` and stay undispatched as
  spacedock entities; the PITCH travels the pipeline (AC-3), children are its
  plan/execute work-breakdown per the shape.md DAG (1.1 → 1.2; 1.3 parallel).
- Confirm-path frictions banked as todos (fixture-pollution-discovery-helpers,
  shape-confirm-instance-awareness incl. legacy `status: sharp` literals,
  root-readme-stale-claims); ROADMAP `later` carries the same three rows.
- Worktree-first note: ceremony ran in the Conductor workspace — an isolated
  linked git worktree on branch `iamcxa/ship-flow-self-hosting`, not the base
  checkout; pathspec-locked commits throughout.
- Adopter skill-routing (.claude/ship-flow/skill-routing.yaml) is absent and
  the discovery draft is fixture-polluted — plan stage must hand-author the
  routing map or accept generic defaults deliberately.

### Metrics
- status: passed
- duration_minutes: 135
- iteration_count: 2
- path: shape+sharp
- open_contract_decisions_count: 4
- domain_matches_count: 1

## Stage Report: design

- DONE: design.md resolves all four open_contract_decisions from the entity's Hand-off to Design (coupling-config format+location, declaration grammar+placement, size-threshold semantics, checker family) with explicit trade-offs — no silent picks
  D1→new tight YAML `references/doc-coupling-map.yaml` (+ `.claude/ship-flow/` adopter override); D2→PR-body declaration passed to checker as input, reuse `is_weak_skip_rationale` ≥12-char bar; D3→path-class (no size var, A/C rejected vs pre-mortem); D4→shell family. Trade-off tables in design.md §Design Output → Contract Decisions.
- DONE: Contract deltas are named together with the test surfaces that pin them: which SKILL sections / references/*.yaml fields / helper flags move, and which existing shell string-assertion tests must move with them
  design.md §Contract Deltas & Test Surfaces — per-child tables (1.1/1.2/1.3): NEW `bin/doc-impact-gate.sh`+`references/doc-coupling-map.yaml` pinned by NEW `test-doc-impact-gate.sh`; CI step pinned by `test-ship-flow-ci-scope.sh` (add assertion); 1.1 docs consumed by existing `check_flow_map_coverage` (Principle 5b, check-invariants.sh:197-240), no checker delta.
- DONE: Every enforcement decision prefers a code gate over a prose rule and honors the R3 constraint recorded in the entity: mechanical declaration-presence only in required CI; LLM semantics stay in pipeline route-back or advisory surfaces
  The checker IS the code gate replacing the prose "remember to update docs" rule; R3 boundary recorded as a load-bearing plan constraint (required CI = presence+grammar+≥12-char length ONLY; reason-legitimacy routes to ship-review canonical-doc route-back + PR review, advisory). Declaration-text-as-input seam keeps the checker offline-testable.

### Summary

Contract Interface Designer lane resolved all four contract decisions with trade-off tables and pre-mortem-guarded rejections (no silent picks). Reverse-recovery finding drove D1: a coupling map already EXISTS_BROKEN in `references/doc-sync-context.md` (LLM-consumed, prose-keyed, coarse) — re-shaped as a tight machine-readable subset rather than greenfielded, reusing two existing zero-dep shell primitives (`glob_to_regex`, `is_weak_skip_rationale`). Verdict PROCEED (non-UI-lane, FO-gated); one non-blocking sub-decision (D4 primitive-reuse: extract-vs-copy) carried to plan. design.md at docs/ship-flow/1-self-adoption-dogfood-bootstrap/design.md.
