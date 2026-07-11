---
id: "1"
title: "Self-adoption dogfood bootstrap — canonical docs + doc-impact gate"
status: verify
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

## Stage Report: plan

- DONE: plan.md carries a TDD contract per code-bearing task (RED-before-GREEN) with explicit test files — including NEW test-doc-impact-gate.sh observed RED before bin/doc-impact-gate.sh goes GREEN
  T2.2 `tdd_contract` (red/green/refactor_check all `test-doc-impact-gate.sh`) and T2.3 `tdd_contract` (`test-ship-flow-ci-scope.sh`) re-verified this session against the live tree: `bin/doc-impact-gate.sh`, `lib/__tests__/test-doc-impact-gate.sh`, `references/doc-coupling-map.yaml`, `lib/glob-match.sh`, `lib/doc-rationale.sh` all confirmed absent (RED-first premise holds); `test-ship-flow-ci-scope.sh` exists today with exactly the 6 assertions T2.3's `regression_risk` claims (`bash .../test-ship-flow-ci-scope.sh` → 6 passed).
- DONE: A Canonical Doc Actions section covers ARCHITECTURE.md, PRODUCT.md and ROADMAP.md (update/skip + rationale each)
  plan.md `### Canonical Doc Actions` table (ARCHITECTURE.md: update / PRODUCT.md: skip / ROADMAP.md: update, each with rationale) — unchanged from the resumed draft, re-verified consistent with the live tree (PRODUCT.md/ROADMAP.md already flow-map-schema-tagged per commit `11350a0`; ARCHITECTURE.md confirmed still absent at repo root).
- DONE: Every task touching plugins/ship-flow/bin or lib names which existing tests could break, and the D4 primitive-reuse sub-decision (extract vs copy-with-pointer) is decided explicitly and recorded
  T2.1 `regression_risk` names `test-adopter-skill-discovery.sh` + `test-canonical-doc-sync-checker.sh`; both re-run green this session (18/18, 62/62) with no line-number-anchored assertions found — safe under extraction. `### D4 Decision` section records **Extract** (not copy-with-pointer) with rationale, satisfying design.md's Constraints-for-Plan-Stage requirement that plan decide this explicitly.

### Resume-and-validate work this session

- FAILED→FIXED: `check-invariants.sh --check plan-imported-design-dcs-emitted` (C4) failed on the resumed plan.md — entity is design-bearing (`contract_decision_required: true`, `domain: schema`) with a non-skipped `### Hand-off to Plan`, but plan.md had no `## Plan Imported Design DCs` section. Fixed by running `lib/import-design-dcs.sh` and appending its output (empty tables, correctly — design.md's Hand-off to Plan is prose-referenced, not the UI-typed `design_constraints[]` schema this importer parses; a note inside the block records why and points to where the real constraints live). Wrapped in a `<details>` block so the addition costs 0 body lines against the C15 200-line cap (plan.md's body was already sitting exactly at the 200-line cap from the predecessor's trim — confirming the dispatch note that the trim was complete). Re-ran: C4 OK, C15 OK (`OK C15 artifact-verbosity`), full `check-invariants.sh` re-run clean apart from the one pre-existing out-of-scope item below.
- SKIPPED: C14 (`entity-status-via-advance-stage-only`) fires on commits `695addea` and `0d0ca53e` — both from the earlier **shape** stage (entity status mutated without the `advance-stage.sh` signature), not on anything plan.md or tdd-ledger.jsonl own. Out of scope for a plan-stage fix (rewriting shape-stage commit history is a different, riskier class of change); flagging for FO/captain visibility rather than silently ignoring.
- DONE: tdd-ledger.jsonl re-validated against the (now-edited) plan.md: `validate-tdd-ledger.py --plan plan.md --require-ledger-jsonl tdd-ledger.jsonl` → `status=pass records=7`, unchanged from the predecessor's ledger — no task_id/tdd_contract surface changed by the C4 fix.
- DONE: 12-dimension self-review re-run against the resumed+fixed plan.md (1 iteration, converged — no second pass needed): zero-placeholder scan clean; all `file:line` citations re-read and current (`check-invariants.sh:197`, `resolve-skill-routing.sh:64-82`, `canonical-doc-sync-checker.sh:114-133`/`:19-24`, README further-reading `~:528-533`); no stub/fake/placeholder task markers; wave graph (W1 parallel → W2 chain) has no cycle/overlap; `skills_needed` non-boilerplate (2 distinct lists: `[write-docs]` vs `[test, best-practices]`); Context Manifest's 7 fields present (C8 OK).
- SKIPPED: `check-design-readiness-review.sh` / `validate-d-references.sh` (SKILL.md Step 1.6 pre-import helper scripts, not CI-enforced) flag design.md for a missing `## Design Readiness Review` header and `**D{N}|Captain decision**` markers — both are keyword-triggered on design.md's own negated prose ("no DB migration... or public-API/ts-rest contract"), and design.md is a prior, already-`PROCEED`-verdicted stage artifact outside this plan-stage RESUME's scope (plan.md + tdd-ledger.jsonl only, per dispatch). Not fixed; not blocking (not a `check-invariants.sh` CI gate for this entity).

### Summary

Resumed the killed predecessor's already-structurally-complete plan.md (7 tasks, TDD contracts, Canonical Doc Actions, D4=extract) and validated it against the live tree rather than rewriting it. One real gap found and fixed: `check-invariants.sh` C4 (`plan-imported-design-dcs-emitted`) failed because plan.md lacked a `## Plan Imported Design DCs` section; fixed by appending the mechanical importer's output inside a `<details>` block (0 net body-line cost, keeping the C15 200-line cap — which was already sitting at exactly the cap — intact). Full self-review (12 dimensions) converged in one pass with no other findings; one pre-existing, out-of-scope issue (C14, from shape-stage commits) is flagged for FO visibility, not fixed here. Plan is not gated; ready for execute.

### Metrics
- status: passed
- duration_minutes: 40
- iteration_count: 1
- reviewer_verdict: N/A (ungated stage per dispatch — FO advances straight to execute)

## Stage Report: execute

- DONE: Every code-bearing task lands with RED evidence before GREEN (tdd-ledger contracts T2.1-T2.3): test-doc-impact-gate.sh observed failing before bin/doc-impact-gate.sh exists, and the new CI-scope assertion observed failing before the workflow step is added
  T2.2: `test-doc-impact-gate.sh` exit 127 / 15 of 20 fixture assertions FAIL before `bin/doc-impact-gate.sh` existed → 20/20 PASS after (commit `1b5dba0`). T2.3: `test-ship-flow-ci-scope.sh` 6/7 (new assertion FAIL) before the workflow step was added → 7/7 after (commit `22c3c87`). T2.1 is a pure refactor (`TDD: skip` per tdd-ledger.jsonl, `applicable: false`) — regression-gated instead: `test-adopter-skill-discovery.sh` (18/18) and `test-canonical-doc-sync-checker.sh` (62/62) unchanged pre/post extraction.
- DONE: Full local gate run is clean before handoff and the report names each suite: shell test-*.sh loop, node --test bin/*.test.mjs, CI=true check-invariants.sh (Principle 5b now enforcing, zero WARN lines), check-no-dangling.sh, check-version-triple.sh, git diff --check
  shell `test-*.sh` loop: 103 files, 101 pass, 2 pre-existing/out-of-scope fails (see deviations in execute.md Hand-off to Verify). `node --test plugins/ship-flow/bin/*.test.mjs`: 79/79 pass. `CI=true bash plugins/ship-flow/bin/check-invariants.sh`: zero `WARN [Principle 5b]` lines (ARCHITECTURE.md now real-checked); only failure is the pre-existing, explicitly out-of-scope C14 (commits `695addea`/`0d0ca53e`, shape-stage, "handled at FO level" per dispatch). `check-no-dangling.sh`: PASS (8 patterns, 0 violations). `check-version-triple.sh`: PASS (0.8.2 triple-matched). `git diff --check` (against dispatch-base `7780b2a`): clean, no whitespace errors.
- DONE: Deviations from plan.md recorded with one-line rationale in execute.md; no scope growth beyond the 7 planned tasks (T1.1-T2.4)
  Full detail in execute.md § Hand-off to Verify → deviations (ROADMAP Stage-column value execute vs. plan.md's literal "plan"; the 2 pre-existing shell-suite fails verified via a scratch `git worktree add --detach 7780b2a` check). Exactly 7 tasks landed (T1.1-T2.4), one commit each, no additional files touched beyond each task's `owned_paths`.

### Summary

All 7 planned tasks (T1.1-T2.4) landed, one commit per task, in wave order (W1 parallel-safe → W2 chain). AC-1 (Principle 5b enforcing) and AC-4 (harvest vocabulary) are fully satisfied; AC-2's mechanical gate is built and RED→GREEN-proven for both TDD-contracted tasks (T2.2, T2.3); AC-3 stays correctly deferred to ship-review per plan.md. Full local gate run is clean apart from two pre-existing, out-of-scope shell-test failures independently verified present at the dispatch-base commit before this entity's work began — flagged for FO/captain visibility, not fixed, matching the dispatch's explicit "handled at FO level" instruction and the no-scope-growth constraint.

## Stage Report: verify

- DONE: verify.md carries a per-AC evidence citation (or explicit unmet-with-owning-stage) for each of AC-1 through AC-4, cross-checked against the live worktree, not just execute.md claims
  Each of AC-1/AC-2/AC-3/AC-4 got an independent live re-run this session (not trusted from execute.md): AC-1 zero `WARN [Principle 5b]` confirmed via fresh `check-invariants.sh` run + section-marker/mermaid grep on ARCHITECTURE.md; AC-2 both the fail-path and declaration-path of `bin/doc-impact-gate.sh` exercised live with a synthetic changed-file list, plus the CI workflow step read directly; AC-3 confirmed correctly deferred (checker live-run returns `BLOCKER review-artifact` — gate is real, not silently skipped); AC-4 file-existence + README grep re-run. See verify.md for full Verification Claim records.
- DONE: runtime_uat claim is explicit: a live invocation of bin/doc-impact-gate.sh from a worker-perspective (both the fail path and the declaration path) and CI=true check-invariants.sh on the worktree, or a structured not-applicable/deferred reason
  Both `doc-impact-gate.sh` paths run live this session (fail path → exit 1 `BLOCKER doc-impact: stage-skill-readme`; declaration path → exit 0 `PASS stage-skill-readme: doc-impact declaration accepted`). `CI=true bash plugins/ship-flow/bin/check-invariants.sh` re-run live on HEAD: 0 `WARN [Principle 5b]` lines, only FAIL is the 2 named historical C14 commits. AC-2's live-CI-run leg (a real PR's CI run) is structurally impossible pre-PR — declared explicitly deferred-to-ship in verify.md, not silently marked N/A.
- DONE: Verdict declares every degraded/known-dirty check by name with route_to per finding class — no silent absorption, no PASS diluted from INCONCLUSIVE without a PROMPT_CAPTAIN line
  verify.md § Known-Dirty table names all 4 items with route_to: (1) the 2 pre-existing shell-suite failures (`test-archived-corpus-invariants.sh`, `test-merged-pr-closeout-reconciler.sh`) — independently re-verified present-and-identical at base `7780b2a` (via scratch `git worktree add --detach`) and at HEAD, route_to: ship; (2) C14 on the 2 historical shape-stage commits (`695addea`, `0d0ca53e`) — confirmed no new C14 on any of the 7 execute commits via `git log --oneline 7780b2a..HEAD` cross-check, route_to: ship; (3) AC-2 live-CI-run leg, route_to: review; (4) AC-3 whole, route_to: review. No item is INCONCLUSIVE (each has a reproducible command and known root cause), so no PROMPT_CAPTAIN line was needed — verdict is a clean PASS, not a diluted one.

### Summary

Re-ran every check independently against the live worktree HEAD (`f5a8fd2`) rather than trusting execute.md's word: shell suite 101/103 (2 pre-existing fails, both re-verified present-and-unchanged at base `7780b2a` via scratch worktree), node 79/79, zero Principle-5b WARN lines, no-dangling PASS, version-triple PASS, `git diff --check` clean. Exercised `bin/doc-impact-gate.sh` live from both the fail path and the declaration-accepted path with a synthetic changed-file list. Confirmed no NEW C14 violations beyond the 2 historical shape-stage commits. AC-1/AC-2(local)/AC-4 VERIFIED; AC-2's live-CI-run leg and AC-3 whole are explicitly deferred-to-ship/review per plan.md's own scoping, not silently absorbed. Verdict: PASS, proceed to review/ship; no BLOCKING/WARNING routes back to execute this cycle.

### Metrics
- status: passed
- duration_minutes: (see FO dispatch timing)
- iteration_count: 1
- degraded_checks_declared: 4
- new_findings: 0

### Feedback Cycles

| cycle | date | reviewer verdict | routed to | findings | resolution |
|---|---|---|---|---|---|
| 1 | 2026-07-11 | verify.md PASS (local scope) overridden by codex-gate FAIL ([P1]:3, all FO-confirmed) | execute (cycle-2 dispatch) | P1-1 CI step runs on push where PR body is absent; P1-2 unanchored `none` match accepts non-waiver prose; P1-3 coupling YAML parser fails open on layout variants — full text + repro evidence in verify.md `codex-gate-findings` section | **RESOLVED** — fixed cycle-2: P1-1 `004456c`, P1-2 `961223a`, P1-3 `f030145` (RED-first evidence in execute.md § Cycle-2 Fixes); re-verified live against HEAD in verify.md § Verdict (cycle 2) — all 3 P1s confirmed closed, regression suites 32/32 + 8/8 green |

## Stage Report: execute (cycle 2)

- DONE: Each of the three codex-gate P1s is fixed with a RED-first regression test: (1) CI step no longer evaluates the declaration on push events where PR body is structurally absent, (2) the declaration matcher requires an anchored standalone `doc-impact: none — <reason>` form and the FO repro string now exits 1, (3) the coupling-map parser fails CLOSED on unparsed/empty srcGlobs or docPaths, proven with block-array and quote-variant fixtures
  All 3 fixed one-commit-each with RED (observed failing) → GREEN (observed passing) evidence: P1-1 `004456c` (test-ship-flow-ci-scope.sh 7/8→8/8), P1-2 `961223a` (test-doc-impact-gate.sh 23/26→26/26, FO repro string now exits 1), P1-3 `f030145` (test-doc-impact-gate.sh 26/32→32/32, new fixtures coupling-map-single-quote.yaml/coupling-map-indent-variant.yaml parse correctly, coupling-map-block-array.yaml hard-errors exit 2). Full per-P1 evidence in execute.md § Cycle-2 Fixes.
- DONE: Full local gate re-run is clean and named: test-doc-impact-gate.sh (all new cases green), test-ship-flow-ci-scope.sh, full shell loop (baseline 101/103 with only the 2 known pre-existing failures), node --test 79/79, CI=true check-invariants.sh (zero 5b WARNs, only the 2 known historical C14 lines), check-no-dangling.sh, git diff --check
  test-doc-impact-gate.sh 32/32, test-ship-flow-ci-scope.sh 8/8, full shell suite 101/103 (2 pre-existing fails, identical to base `fb59795`), node --test 79/79, check-no-dangling.sh PASS, check-version-triple.sh PASS, `git diff --check fb59795 HEAD` clean. Deviation: `CI=true check-invariants.sh` shows 5 FAIL lines, not 2 — the 2 known C14 lines PLUS C11/C12 (missing `## Panel Coverage`/`## Deferred to TODO` on verify.md) and C15 (verify.md 173 lines > 120 cap). Independently confirmed via a scratch `git worktree add --detach` that all 3 extra FAILs already fire at dispatch base `fb59795`, and even at the original verify-stage commit `553a471` (156 lines, pre-codex-gate-append) — pre-existing on verify.md, not introduced by this cycle's 7 files (`git diff --stat fb59795 HEAD` confirms verify.md untouched). Out of scope per this dispatch's explicit "verify.md NOT touched (re-verify owns it)" instruction; flagged for FO/re-verify visibility, not fixed here.
- DONE: execute.md appended with a cycle-2 fix section (per-P1 evidence: RED output before fix, GREEN after) and `## Stage Report: execute` updated; verify.md NOT touched (re-verify owns it)
  See execute.md § Cycle-2 Fixes (this section) and this `Stage Report: execute (cycle 2)` section; `git diff --stat fb59795 HEAD` confirms verify.md is not among the 7 changed files.

### Summary

All 3 codex-gate P1 findings (CI push-event scoping, unanchored `none` declaration matcher, coupling-map parser fail-open) fixed one-commit-each with independently re-run RED→GREEN evidence, no scope growth beyond the named files. Full local gate re-run is clean apart from the already-known 2 shell-suite failures and 2 C14 historical commits, plus 3 newly-surfaced check-invariants.sh findings (C11/C12/C15) on verify.md that were independently proven pre-existing (present at dispatch base and even at the original verify-stage commit, before any codex-gate work) and out of scope for this execute-cycle dispatch. Ready for re-verify.

### Metrics

- status: passed
- duration_minutes: (see FO dispatch timing)
- iteration_count: 1 (cycle-2 fix pass, no further rejection within this cycle)
- commit_count: 3
- new_findings: 0 (all 3 are the codex-gate-routed P1s; the 3 pre-existing check-invariants.sh FAILs are not new)

## Stage Report: verify (cycle 2)

- DONE: Each routed P1 fix is re-verified against the live tree (not execute.md claims): the FO bypass repro string exits 1, a legit anchored declaration exits 0, a block-array coupling map hard-errors exit 2, and the CI step carries the pull_request event guard — plus the fix regression tests re-run green
  P1-1: `.github/workflows/ship-flow-invariants.yml` step condition confirmed live to read `... && github.event_name == 'pull_request'`. P1-2: FO repro string `doc-impact: none of these docs are affected by my change I promise` → exit 1 (live); anchored control → exit 0 (live). P1-3: `coupling-map-block-array.yaml` fixture → exit 2, `ERROR: coupling map row 'skill-readme' ... has an empty or unparseable srcGlobs/docPaths` (live). `test-doc-impact-gate.sh` 32/32, `test-ship-flow-ci-scope.sh` 8/8, both re-run this session. Full table in verify.md § Cycle-2 P1 Fix Re-verification.
- DONE: verify.md is brought to invariant compliance as verify-stage-owned work: C11 Panel Coverage section, C12 Deferred-to-TODO section, C15 body-line cap (bulk evidence wrapped in details blocks); CI=true check-invariants.sh afterward shows ONLY the 2 known historical C14 lines
  `## Panel Coverage` and `## Deferred to TODO` added (grep count 1 each); the 4 original per-AC + 3 runtime-UAT full evidence tables moved into two `<details>` blocks, body measured 119 lines (cap 120), raw 230 lines (cap 240). `CI=true bash plugins/ship-flow/bin/check-invariants.sh` re-run live after the commit: `OK C11`, `OK C12`, `OK C15`; only `FAIL C14` on `695addea`/`0d0ca53e` remains.
- DONE: verify.md gains a cycle-2 verdict section superseding (not deleting) the cycle-1 verdict, with per-P1 evidence citations and the updated Feedback Cycles row marked resolved; index.md Stage Report: verify updated with cycle-2 accounting
  cycle-1 `## Verdict` retitled `(cycle 1 — superseded by cycle 2 below)`, content unchanged; new `## Verdict (cycle 2 — current, supersedes cycle 1)` added with per-P1 evidence citations and final PASS. Feedback Cycles table row 1 resolution column now reads `**RESOLVED** — ...`. This section is the cycle-2 accounting.

### Summary

Re-verified all 3 codex-gate P1 fixes live against HEAD (not execute.md's word): CI push-event guard, anchored declaration matcher, and coupling-map fail-closed parsing all confirmed working exactly as fixed, with both regression suites (`test-doc-impact-gate.sh` 32/32, `test-ship-flow-ci-scope.sh` 8/8) re-run green. Separately brought verify.md itself to C11/C12/C15 compliance — the schema debt inherited from the cycle-1 verify worker dying at session limit — by adding the mandatory Panel Coverage / Deferred to TODO sections and collapsing bulk per-AC/runtime-UAT evidence into `<details>` blocks to fit the 120-line body cap. `CI=true check-invariants.sh` now shows only the 2 known historical C14 lines (out of scope, FO-acknowledged). Verdict: PASS, proceed to review/ship; feedback loop to execute is closed this cycle.

### Metrics
- status: passed
- duration_minutes: (see FO dispatch timing)
- iteration_count: 2 (cycle-2 re-verify)
- p1_fixes_reverified: 3
- invariant_fails_closed: 3 (C11, C12, C15)
- new_findings: 0
