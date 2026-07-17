# Ship-flow core: the human review surface is the shape/spec, not plan.md — Implementation Plan

**Goal:** Codify one methodology rule (Principle 17) into `INVARIANTS.md` — the captain's review surface is shape.md (+ design.md when its conditional gate fires), never `plan.md`/`execute.md` — cross-referencing (not re-deriving) the existing `## FO Discipline` captain-in-loop list, extend that list with a `direction-confirm` captain-stop + a new Violation pattern, pin the rule's presence with a new `C16` string-assertion check (RED-first), and lean-doc-sync the two ship-flow docs that describe the shape gate.
**Architecture:** Prose-discipline rule, honestly framed: C16 proves the rule TEXT survives (discoverability + regression-proofing), not that a live FO obeys it — Principle 16's Tier-A/Tier-B honesty framing (`INVARIANTS.md:595`) applies directly; the existing `manual:`-only-on-shape schema already failed to prevent the incident twice (issue #60's own plan.md-offer, entity #078's over-pausing), so no new machinery is proposed.
**Tech stack:** Markdown (`INVARIANTS.md`), bash 3.2+ (`check-invariants.sh`, portable BSD/macOS grep, no `grep -P`), shell test convention (`lib/__tests__/test-*.sh`).

## Plan Output

### Research Summary

No dispatched research team — S-size scope, and the FO's own dispatch prompt pre-supplied near-final content requirements (a/b/c/d) plus exact file coordinates. Direct codebase reads this session: `INVARIANTS.md` highest is `### Principle 16` (:595-603), `## Revision History` (:7-10), `## FO Discipline` (:356) → `### Autonomous continuation between stages` (:360-386, "Captain is in the loop at" list :364-368, "Violation patterns" :378-382). `check-invariants.sh` highest single-check is `# C15` (:2092); simplest close template is `check_principle_numbering` (C9, :1066-1086) — a `FIXTURE_INVARIANTS`-overridable function, exactly the shape C16 needs (string/presence assertion, not C15's git-range/multi-file machinery). Dispatcher single-check cases :2359-2400; full-run registration :2420-2465. Sibling precedent `docs/ship-flow/5-issue-anchor-scope-drift-guard/plan.md` (merged PR #59) is the closest real template for this plan's own shape (RED-first test → parallel prose+check landing → doc-sync → canonical-doc-actions task) and is followed directly.
Gap found: `shape.md` has no `### Done Criteria` table (only prose Problem/Acceptance Outcome + a `pm_skill_receipts` block) — DC-1..DC-8 below are authored directly from the FO's dispatch scope, not cited from a shape DC-N list. Flagged to FO as a shape-artifact completeness gap, not blocking (Acceptance Outcome prose is unambiguous).

### Assumption Re-validation (Step 1.5)

Skipped — shape.md's `## Assumptions` is the literal placeholder `(fill in at shape stage)`; no `file:line` citations exist to re-validate (per the "skip if no file:line citations" rule). The FO dispatch's own verified-coordinates block substitutes and was re-confirmed fresh this session (line numbers above match current HEAD).

### Size Re-evaluation

No Sharp size stated (only `appetite: small-batch`). Actual affected files: 7 — `test-check-invariants-c16.sh` (new), `INVARIANTS.md`, `check-invariants.sh`, `docs/ship-flow/README.md`, `skills/ship-shape/SKILL.md`, `ROADMAP.md`, `ARCHITECTURE.md`. Raw count nudges toward the S→M boundary (4-10 bracket), but 4 of the 7 files receive a single-line/single-row edit (Revision History bump, one doc-sync sentence each, one ROADMAP row move, one ARCHITECTURE row) — load-bearing work is concentrated in 3 files (test file, Principle 17 prose, C16 check). No size upgrade; stays small-batch.

### Verification Spec

| DC | Verify Procedure | Expected |
|---|---|---|
| DC-1 | `bash plugins/ship-flow/bin/check-invariants.sh --check review-surface-shape-not-plan` | Exit 0, stdout `OK C16 review-surface-shape-not-plan` (post T2+T3). |
| DC-2 | `bash plugins/ship-flow/lib/__tests__/test-check-invariants-c16.sh` | Exit 0, every case OK (post T2+T3); documented RED (nonzero) pre-T2/T3, failing because the dispatcher has no `review-surface-shape-not-plan` branch yet — not a shell/fixture bug. |
| DC-3 | `grep -qF "The human review surface is the shape/spec (and design.md when its conditional gate fires) -- never plan.md or execute.md." plugins/ship-flow/INVARIANTS.md && grep -qF "The FO MUST NOT offer plan.md or execute.md as a human-review artifact." plugins/ship-flow/INVARIANTS.md` | Both greps exit 0 — the two pinned Principle 17 sentences are present verbatim (no markdown backticks inside them, so C16 stays a plain `grep -F` fixed-string match). |
| DC-4 | `awk '/^### Autonomous continuation between stages/,/^---$/' plugins/ship-flow/INVARIANTS.md \| grep -q "direction-confirm"` and same range `\| grep -qiE "offer.*plan\.md.*human.review"` | Both match — new captain-stop bullet + new Violation pattern present in the existing list (not re-derived elsewhere). Second grep uses the `offer` root (not a tensed form) so it matches whichever tense ("offering"/"offered") the executed prose actually uses. |
| DC-5 | `grep -qE '^- \*\*2026-07-18\*\* — \*\*v1\.5\.0\*\*.*Principle 17' plugins/ship-flow/INVARIANTS.md` | Revision History has a dated, versioned entry naming Principle 17 + C16. |
| DC-6 | `grep -q "Principle 17" docs/ship-flow/README.md && grep -q "Principle 17" plugins/ship-flow/skills/ship-shape/SKILL.md` | Both ship-flow docs cross-reference Principle 17 near their existing shape-gate / rubber-stamp prose. |
| DC-7 | `CI=true bash plugins/ship-flow/bin/check-invariants.sh` (full suite) and `git diff --check` | Exit 0 both; no new CI regression, no trailing-whitespace/conflict-marker noise. |
| DC-8 | `grep -q "7-review-surface-shape-not-plan" ROADMAP.md` (inside `<!-- section:now -->`) and `grep -q "7-review-surface-shape-not-plan" ARCHITECTURE.md` (inside `<!-- section:decisions -->`) | Entity moved Next→Now; ARCHITECTURE.md decisions table carries a summary row, matching this repo's "kept current at every entity touching `plugins/ship-flow/` structure" convention. |

### Canonical Doc Actions

| Doc | Action | Source | Rationale |
|---|---|---|---|
| ROADMAP.md | update | plan | Entity already listed under `## Next` (:20); move to `## Now` via `lib/patch-map.sh` — plan stage is active-work start (c14/5-issue-anchor precedent). |
| PRODUCT.md | skip | plan | Internal ship-flow methodology/quality-gate addition (review-surface discipline), not a new user-facing capability — same rationale class as 5-issue-anchor's PRODUCT.md skip. |
| ARCHITECTURE.md | update | plan | New Principle + C16 check touches `plugins/ship-flow/` structure; this repo's ARCHITECTURE.md header states it is "kept current by ... every subsequent entity that touches `plugins/ship-flow/` structure" (precedent rows: `1-self-adoption-dogfood-bootstrap`, `c14-fo-dispatch-contract`, `5-issue-anchor-scope-drift-guard`). |

<details>
<summary>Task-to-scope anchoring</summary>

### Scope Anchoring

| Task | Acceptance Outcome / DC mapping |
|---|---|
| T1 | Acceptance Outcome ("a shell check fails if rule text regresses"); DC-2 |
| T2 | Acceptance Outcome (durable, discoverable rule + FO Discipline cross-ref); DC-3, DC-4, DC-5 |
| T3 | Acceptance Outcome ("shell check (C16) fails"); DC-1, DC-2 |
| T4 | doc-sync (FO scope item, lean); DC-6 |
| T5 | Canonical Doc Actions (meta); DC-7, DC-8 |

</details>

### Plan

#### T1 — Author test-check-invariants-c16.sh (RED authoring)
task_id: T1
layer: L5
wave: W1
files: `plugins/ship-flow/lib/__tests__/test-check-invariants-c16.sh` (new)
read_first: `plugins/ship-flow/bin/check-invariants.sh:1066-1086` (C9 `check_principle_numbering`, the `FIXTURE_INVARIANTS` override template); `plugins/ship-flow/lib/__tests__/test-check-invariants.sh:942-974` (C9's own fixture-mode test, the mechanism template); `plugins/ship-flow/lib/__tests__/test-check-invariants-c15.sh:1-30` (standalone-file boilerplate template — SCRIPT_DIR/PLUGIN_DIR/CHECK_SCRIPT/`assert_exit`/`assert_stderr_contains` helpers)
skills_needed: [test, best-practices, test-driven-development]
reviewer_questions: [{lens: contract, question: "Does the test pin BOTH directions (rule text present -> PASS; rule text removed/mutated -> FAIL) via FIXTURE_INVARIANTS, plus a live-INVARIANTS.md case, without asserting on check-invariants.sh internals?", affected_path_family: "plugins/ship-flow/lib/__tests__/test-check-invariants-c16.sh", evidence_required: "RED run showing every case fails because the dispatcher has no matching --check branch (exit 2, 'unknown check'), not a bash syntax error"}]
tdd_contract:
  red_command: "bash plugins/ship-flow/lib/__tests__/test-check-invariants-c16.sh"
  expected_red_failure: "Every case fails: check-invariants.sh's dispatcher has no 'review-surface-shape-not-plan' branch yet, so `--check review-surface-shape-not-plan` exits 2 ('unknown check') for every fixture — the PASS-fixture case (expects 0) and both FAIL-fixture cases (expect 1) all mismatch against 2. Confirm this by running the test file, as authored, against the CURRENT unmodified check-invariants.sh and INVARIANTS.md BEFORE starting T2/T3 — this is the explicit RED-before-GREEN gate for this entity."
  green_command: "bash plugins/ship-flow/lib/__tests__/test-check-invariants-c16.sh (green only after T2 AND T3 both land)"
  refactor_check: "bash -n plugins/ship-flow/lib/__tests__/test-check-invariants-c16.sh"
parallel_group: serial; depends_on: []; owned_paths: [plugins/ship-flow/lib/__tests__/test-check-invariants-c16.sh]; integration_owner: executer@7-review-surface-shape-not-plan
steps: 1. Copy the `assert_exit`/`assert_stderr_contains` helpers + SCRIPT_DIR/PLUGIN_DIR/CHECK_SCRIPT boilerplate from `test-check-invariants-c15.sh:1-30`. 2. Case A (live): `bash "$CHECK_SCRIPT" --check review-surface-shape-not-plan` expect exit 0 (post-T2/T3; RED for now). 3. Case B: `FIXTURE_INVARIANTS=<tmp file containing both pinned sentences verbatim>` expect exit 0. 4. Case C: `FIXTURE_INVARIANTS=<tmp file with neither sentence>` expect exit 1 + stderr names "Principle 17". 5. Case D (mutation): `FIXTURE_INVARIANTS=<tmp file with the Principle 17 HEADING present but both pinned sentences reworded away>` expect exit 1 — proves the check greps the load-bearing sentences, not just the heading. 6. Run RED, capture output, commit only this file.
done: script exits nonzero at RED with every assertion failing for the "unknown check" reason (visible in captured output), not a bash parse error; `bash -n` clean.
model: sonnet; canonical_doc_actions: shared table.

#### T2 — INVARIANTS.md: Principle 17 + FO Discipline extension + Revision History bump
task_id: T2
layer: meta
wave: W2
files: `plugins/ship-flow/INVARIANTS.md`
read_first: T1 DC-3/DC-4/DC-5 assertions; `INVARIANTS.md:595-605` (Principle 16, insertion anchor — new content lands between its Source line :603 and the pre-existing `---` at :605); `INVARIANTS.md:356-386` (`## FO Discipline` full section, extension anchor); `INVARIANTS.md:7-10` (Revision History, latest is v1.4.0/2026-05-30)
skills_needed: [write-docs]
TDD: skip -- docs-only prose; pinned by T1's test + T3's C16 check (DC-2/DC-3) plus DC-4/DC-5 grep evidence in Verification Spec — no separate code-level RED/GREEN cycle for prose content itself.
parallel_group: w2-invariants; depends_on: [T1]; owned_paths: [plugins/ship-flow/INVARIANTS.md]; integration_owner: executer@7-review-surface-shape-not-plan
steps: 1. Insert a new `---` + `### Principle 17: The human review surface is the shape/spec, never plan.md` immediately before the existing `---` at :605 (so it still separates Principle 17 from `## Success-mode Harvest Lifecycle`). Body MUST contain, verbatim, both pinned sentences from DC-3 (no backticks around plan.md/execute.md inside those two sentences — keeps C16 a plain fixed-string grep); plus one sentence naming the positive substitute (FO confirms shape/spec content in plain language instead of showing plan.md) and one sentence naming the autonomous-continuation boundary (stops only for direction-confirm or UAT); plus ONE sentence on verify-gate posture: "Verify-gate posture is unchanged: the existing science-officer-em engineering-judgment dispatch and ship-verify's already-autonomous Codex adversarial pass (Phase C, Tier A) remain the plan/execute-stage substitute for a captain plan.md skim -- this principle adds no new verify-gate machinery." Cross-reference (do not re-derive) `## FO Discipline -> Autonomous continuation between stages` (:360) for the full captain-in-loop enumeration. Failure mode + honest Grep-check framing per Principle 16's Tier-A/B pattern (C16 pins text presence, not FO runtime behavior) + Source line (`entity #60 / issue #60, 2026-07-18`). 2. In `### Autonomous continuation between stages`, add a `direction-confirm` bullet to the "Captain is in the loop at" list (:364-368) alongside the existing verify/BLOCKING bullet, and add one new "Violation patterns" bullet (:378-382): an FO offering plan.md/execute.md as a human-review artifact. 3. Bump `## Revision History` (:7): add `- **2026-07-18** — **v1.5.0** Principle 17 (review surface is shape/spec, never plan.md) added from entity #60/issue #60. FO Discipline's Autonomous continuation section extended with a direction-confirm captain-stop + a new Violation pattern. C16 pins the rule text -- see Principle 17's own honesty framing: discoverability + regression-proofing, not behavioral FO enforcement.` 4. Run T1's test; confirm DC-3/DC-4/DC-5-shaped assertions move toward green (full green needs T3 too).
done: DC-3/DC-4/DC-5 grep assertions all pass against the edited file; C9 (`--check principle-numbering`) still passes (no duplicate Principle N).
model: sonnet; canonical_doc_actions: shared table.

#### T3 — check-invariants.sh: C16 check function + dispatcher wiring
task_id: T3
layer: L5
wave: W2
files: `plugins/ship-flow/bin/check-invariants.sh`
read_first: T1 assertions; `check_principle_numbering` (:1066-1086, exact function template); dispatcher single-check cases (:2359-2400) and full-run registration (:2420-2465, C15 is the last entry)
skills_needed: [test, best-practices]
reviewer_questions: [{lens: contract, question: "Does check_review_surface_shape_not_plan mirror C9's FIXTURE_INVARIANTS-override + graceful-absent pattern exactly, assert BOTH pinned sentences (not just the Principle 17 heading), and get wired into both the single-check dispatcher AND the full-run registration list?", affected_path_family: "plugins/ship-flow/bin/check-invariants.sh", evidence_required: "T1's DC-2 fixture cases GREEN; full-run `check-invariants.sh` (no --check flag) also exercises C16"}]
tdd_contract:
  red_command: "bash plugins/ship-flow/lib/__tests__/test-check-invariants-c16.sh"
  expected_red_failure: "Same RED as T1 until T2 also lands: the dispatcher recognizes 'review-surface-shape-not-plan' after this task, but the live-INVARIANTS.md case (Case A) and the mutation case still need T2's actual prose to resolve correctly."
  green_command: "bash plugins/ship-flow/lib/__tests__/test-check-invariants-c16.sh (requires T2 landed too)"
  refactor_check: "bash -n plugins/ship-flow/bin/check-invariants.sh"
parallel_group: w2-check; depends_on: [T1]; owned_paths: [plugins/ship-flow/bin/check-invariants.sh]; integration_owner: executer@7-review-surface-shape-not-plan
steps: 1. Add `check_review_surface_shape_not_plan()` directly after `check_artifact_verbosity()` (before `# ---- Dispatcher ----`, ~:2354): `local invariants_file="${FIXTURE_INVARIANTS:-${ROOT}/plugins/ship-flow/INVARIANTS.md}"`; graceful-absent path `[ -f "$invariants_file" ] || { echo "OK C16 review-surface-shape-not-plan (no INVARIANTS.md; skipping)"; return 0; }` (C9 itself silently `return 0`s with no echo on absent-file — this function echoes for full-run-output visibility, a superset, not a literal mirror of that one line); `grep -qF` the two exact pinned sentences from T1/DC-3 (both required); FAIL + named stderr citing `INVARIANTS.md#principle-17` if either is missing; `OK C16 review-surface-shape-not-plan` on success. 2. Add single-check dispatcher case: `review-surface-shape-not-plan) check_review_surface_shape_not_plan; exit $? ;;` (after the `artifact-verbosity)` line, :2398). 3. Add full-run registration: `# C16: entity 7/issue #60 -- Principle 17 review-surface rule-text presence` + `check_review_surface_shape_not_plan || FAIL=1` (after `check_artifact_verbosity`, :2465). 4. Run T1; confirm all cases green once T2 has also landed.
done: T1's DC-2 fixture cases GREEN; full `bash check-invariants.sh` (no flags) still exits 0 on current HEAD-plus-T2.
model: sonnet; canonical_doc_actions: shared table.

#### T4 — Lean doc-sync: docs/ship-flow/README.md + ship-shape/SKILL.md
task_id: T4
layer: meta
wave: W3
files: `docs/ship-flow/README.md`, `plugins/ship-flow/skills/ship-shape/SKILL.md`
read_first: `docs/ship-flow/README.md:128-133` (`shape` stage section, "Only human gate in the pipeline"); `plugins/ship-flow/skills/ship-shape/SKILL.md:73` (existing rubber-stamp-risk paragraph)
skills_needed: [write-docs]
TDD: skip -- docs-only prose addition (user-facing methodology docs); pinned by DC-6 grep evidence, not a code-level RED/GREEN cycle.
parallel_group: serial; depends_on: [T2]; owned_paths: [docs/ship-flow/README.md, plugins/ship-flow/skills/ship-shape/SKILL.md]; integration_owner: executer@7-review-surface-shape-not-plan
steps: 1. In `docs/ship-flow/README.md`, append one sentence after ":133" ("Only human gate in the pipeline."): this is also the only stage whose artifact the captain reviews -- plan.md/execute.md are agent-facing and never re-offered for review (Principle 17, `plugins/ship-flow/INVARIANTS.md`). 2. In `ship-shape/SKILL.md`, append one cross-reference sentence to the existing :73 paragraph: codified as Principle 17 (`plugins/ship-flow/INVARIANTS.md`) so the rule survives outside this one paragraph. 3. Confirm DC-6 greps pass in both files. Explicitly OUT of scope: the deferred "before Intake" doc NIT (not touched).
done: DC-6 passes; no other prose in either file changed.
model: sonnet; canonical_doc_actions: shared table.

#### T5 — Canonical Doc Actions: ROADMAP move + ARCHITECTURE decision row
task_id: T5
layer: meta
wave: W4
files: `ROADMAP.md`, `ARCHITECTURE.md`
read_first: T2/T3/T4 diffs; Canonical Doc Actions table above; `ROADMAP.md:9-21` (`## Now`/`## Next` tables); `ARCHITECTURE.md:121-127` (`<!-- section:decisions -->` table + precedent rows)
skills_needed: [write-docs]
TDD: skip -- docs-only canonical synchronization; existing check-invariants.sh + patch-map.sh CAS gates are the alternate validation (mirrors 5-issue-anchor T4 precedent).
parallel_group: serial; depends_on: [T2, T3, T4]; owned_paths: [ROADMAP.md, ARCHITECTURE.md]; integration_owner: executer@7-review-surface-shape-not-plan
steps: 1. Via `lib/patch-map.sh`, move `7-review-surface-shape-not-plan` from ROADMAP.md `## Next` to `## Now` (Stage column: `plan`). 2. Add an ARCHITECTURE.md `<!-- section:decisions -->` row summarizing Principle 17 + C16 (review-surface rule, FO Discipline extension, string-assertion pin, honest non-enforcement framing). 3. Run `CI=true bash plugins/ship-flow/bin/check-invariants.sh` full suite + `git diff --check`.
done: DC-7 and DC-8 both pass.
model: sonnet; canonical_doc_actions: shared table.

<details>
<summary>Context routing manifest and receipt</summary>

<!-- section:context-routing-manifest -->
```yaml
context-routing-manifest:
  domain_matches: []
  knowledge_modules: []
  required_skills: []
  stage_hints: {plan: []}
  consumer_obligations: [preserve science-officer-em.md route enum unchanged, treat FO Discipline ":360-386" as authoritative captain-in-loop enumeration -- Principle 17 cross-references it rather than re-deriving it]
  future_provider_boundary: "No domain registry match; local INVARIANTS.md/check-invariants.sh convention is the routing source of truth for this entity."
```
<!-- /section:context-routing-manifest -->

## Context Routing Receipt

| Manifest row | Plan task skill mapping | Reviewer questions | domain_acceptance_checklist row |
|---|---|---|---|
| none (no domain match) | T1/T3 use test+best-practices; T2/T4/T5 use write-docs only | T1-T3 contract questions above | T1-T3 rows below |

</details>

## Context Manifest

- **Skills loaded**: ship-plan (self); `superpowers:writing-plans`/`ship-flow:test-driven-development` not invoked as separate `Skill()` calls this pass -- task shape follows the 5-issue-anchor precedent (merged PR #59) directly, same documented exception that precedent used.
- **INVARIANTS sections read**: Principle 5 (`INVARIANTS.md:96`, section-tag/script-mediated canonical docs), Principle 6 (`:119`, cross-review gate), Principle 8 (`:288`, artifact verbosity C15), Principle 16 (`:595`, Tier-A/B honesty framing Principle 17 borrows), FO Discipline (`:356-386`).
- **Architecture docs consulted**: PRODUCT.md, ROADMAP.md (`:9-21`), ARCHITECTURE.md (`:121-127`).
- **Domains touched**: none.
- **Lens dispatched**: none (no tag/customer/event-saga trigger match; ship-flow-internal methodology change).
- **Lens findings integrated**: 0 integrated, 0 deferred, 0 ignored.
- **Folder guidance**: files=`plugins/ship-flow/{INVARIANTS.md,bin,lib/__tests__,skills/ship-shape}/**`, `docs/ship-flow/README.md`, `ROADMAP.md`, `ARCHITECTURE.md` → folder_guidance_files=[]; folder_guidance_skills=[]; codex_context_boundary=root AGENTS.md/CLAUDE.md intentionally excluded from folder_guidance_files.

## Plan Report

status: passed
stage_cost: local planning only, no dispatched research team (S-size scope; FO dispatch pre-supplied near-final content spec); 1 dispatched fresh-sonnet cross-reviewer
iterations: 1 self-review, 0 BLOCKERs; 1 cross-review round
dimensions: requirement/completeness/dependencies/placeholders/signatures/minimality/TDD/line-anchors/context all pass; design-reference dimension N/A (no design.md, design-skipped per Hand-off)
reviewer_verdict: PROCEED (fresh-sonnet cross-review, 7-factor rubric + reverse-audit). 5/7 factors PASS, 2 WARN (both fixed before commit): DC-4's grep required "offered" but planned prose said "offering" — loosened to the `offer` root; T2/T4/T5 lacked an explicit `skills_needed:` line (only inferred via roll-up) — added `skills_needed: [write-docs]` to each. Reverse-audit confirmed shape.md's design-skipped bypass is legitimate (no render_fidelity_targets/design_constraints/open_decisions). Stale-line-anchor spot-check: ~14 citations, all exact.
scope_anchoring: 5/5 tasks mapped; no unmapped task
task_count: 5
model_split: 5 sonnet implementation tasks

### Metrics

status: passed
duration_minutes: 45
iteration_count: 1
task_count: 5
verification_spec_count: 8
model_split: 5 sonnet

### Hand-off to Execute

<!-- section:hand-off-to-execute -->
- **wave_order**: W1 T1 -> W2 (T2 ∥ T3) -> W3 T4 -> W4 T5.
- **critical_assumptions**: shape.md has no file:line assumptions (Step 1.5 skipped, see Research Summary gap note); verified-coordinates block re-confirmed fresh this session.
- **architecture_context**: update ROADMAP.md (Next→Now) and ARCHITECTURE.md (decisions row); PRODUCT.md skip — see Canonical Doc Actions.
- **canonical_doc_actions_summary**: ROADMAP update / PRODUCT skip / ARCHITECTURE update — full table above.
- **stub_flags**: none — no `stub|fake|placeholder|v1.*only|wired only for` language in any task.
- **skills_needed_summary**: T1/T3 test+best-practices(+TDD for T1); T2/T4/T5 write-docs(-only, TDD-skip). Two distinct lists across heterogeneous tasks.
- **domain_acceptance_checklist**:

  | Task ID | Verify Lens | Reviewer Question | Affected Path Family | Required Skills | Evidence Required |
  |---|---|---|---|---|---|
  | T1 | contract | Does the test pin both PASS and FAIL/mutation directions via FIXTURE_INVARIANTS? | lib/__tests__ | test, best-practices, TDD | RED run, right-reason failures |
  | T2 | contract | Does Principle 17 cross-reference (not re-derive) FO Discipline, and use backtick-free pinned sentences? | INVARIANTS.md | write-docs | DC-3/DC-4/DC-5 grep evidence |
  | T3 | contract | Does check_review_surface_shape_not_plan mirror C9's FIXTURE_INVARIANTS pattern and get wired into both dispatcher paths? | bin/check-invariants.sh | test, best-practices | DC-1/DC-2 GREEN |

- **context-routing-manifest**: see standalone block above; no domain match, local convention is authoritative.
<!-- /section:hand_off_to_execute -->

| Task ID | Parallel Group | Depends On | Owned Paths | Integration Owner |
|---|---|---|---|---|
| T1 | serial | — | `plugins/ship-flow/lib/__tests__/test-check-invariants-c16.sh` | executer@7-review-surface-shape-not-plan |
| T2 | w2-invariants | T1 | `plugins/ship-flow/INVARIANTS.md` | executer@7-review-surface-shape-not-plan |
| T3 | w2-check | T1 | `plugins/ship-flow/bin/check-invariants.sh` | executer@7-review-surface-shape-not-plan |
| T4 | serial | T2 | `docs/ship-flow/README.md`; `plugins/ship-flow/skills/ship-shape/SKILL.md` | executer@7-review-surface-shape-not-plan |
| T5 | serial | T2,T3,T4 | `ROADMAP.md`; `ARCHITECTURE.md` | executer@7-review-surface-shape-not-plan |
