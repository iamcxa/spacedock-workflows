# Design — Issue-anchor scope-drift guard (route-back re-anchor)

affects_ui: false
domain: methodology (ship-flow shape stage + wired mod)

## Executive Summary

The captain's bet: when a captain re-shapes an entity carrying `design.md`/`plan.md`, ship-shape must first re-read the immutable original tracker issue and emit a machine-checkable source-diff before the model gets a chance to re-summarize its own drifted artifacts. The pre-mortem risk is well-known — a pinned SKILL section that only asks for prose lets the model rubber-stamp "on-goal" without a real diff. To defeat that risk, four contract decisions must all resolve toward the same design invariant: the done-check must be a text artifact a shell test can grep, not a self-report. This document proposes: **CD1** map the guard onto the existing SO/EM `proceed` / `narrow` / `return` route triad (no new vocabulary); **CD2** ship the guard as a **wired mod with `## Hook: pre-shape` plus a shell test in the `test-contribution-contract.sh` style** — not an inline SKILL section; **CD3** trigger the guard **automatically** by grepping the entity folder for later-stage artifacts (no captain flag to forget); **CD4** require the source-diff to emit a five-field YAML block quoting the issue AC list verbatim, so both the model and the test can point to the same evidence. Verdict: PROCEED to plan.

## Reconciliation (SO/EM review + captain adjudication, 2026-07-17)

Cross-reviewed by the Science Officer/EM (fable), adjudicated by the opus First
Officer against primary-source code, confirmed by the captain. The four trade-off
tables below stand; these deltas are AUTHORITATIVE where they differ:

- **CD1 — captain call: `return` (narrowed).** Reuse `{proceed, narrow, return}`;
  the guard's `return` is narrowly defined in the mod prose as "the original goal
  is already met by existing capability — close or defer this entity". (EM argued
  `costly_no`; captain chose `return`-narrowed for enum-reuse simplicity.)
- **CD2 — confirmed as designed** (wired mod + extractable resolver + end-to-end
  fixture). `## Hook: pre-shape` is a convention label invoked by the ship-shape
  SKILL (same pattern as contribution-contract's `pre-review-spend`), NOT an
  FO-auto-run lifecycle hook. Optional plan hardening: a shape-confirm-side check
  that refuses to confirm a re-shape whose source-diff artifact is absent —
  belt-and-braces only, gated on the shape-confirm instance-awareness gap
  (ROADMAP Later: `shape-confirm-instance-awareness`); do NOT block on it.
- **CD3 — confirmed as designed** (auto-detect via folder artifacts OR `status:`
  frontmatter). Make `status ∉ {draft, sharp}` the PRIMARY signal (covers
  flat-file-layout entities with no `design.md` to grep); folder artifacts
  secondary.
- **CD4 — per-AC refinement.** `original_issue_acs[]` becomes per-AC rows, each
  carrying `met_by_existing_capability: <true|false>` (not just a global
  `goal_still_unmet` boolean), so the case-study blind spot (AC-1/AC-4 already
  achievable by the existing fixed-staging lane) cannot hide inside one aggregate
  answer; `verdict` derives from the rows. **Honest residual (shell test cannot
  close it):** a model can still fill every field with a false ⊆-judgment; per-AC
  rows + captain-gate presentation of the immutable AC text raise the cost of
  hollow rubber-stamping but do not eliminate it. Named, not hidden.
- **CD5 — anchor availability.** In addition to the no-issue fallback +
  fail-visible gh-failure + gh-only-this-round already designed: (a) treat an
  empty-string `issue:` as absent (archived entity 1 carries a literal empty
  `issue:`) — **IMPLEMENTED** in T2's resolver (`test-issue-anchor-guard.sh`
  DC-8a); (b) bounded intake-stamping — when a shape directive references a
  tracker issue (URL / `#N`), carry `issue:`/`tracker:` into the entity
  frontmatter at shape-confirm so future entities are born anchored (the
  dry-fuel-line fix; entity 5 was hand-stamped this session). Keep minimal: carry
  the reference only, NOT a full tracker integration. — **IMPLEMENTED** in
  plan.md T5 (`shape-confirm.sh` `.pitch.issue`/`.pitch.tracker` → entity
  frontmatter, pitch-only scope, mirrors `instantiate-cut-project.sh`'s
  `external_id`/`external_project` stamping); pinned by
  `test-shape-confirm.sh` DC-5.1-1..3 (RED-before-GREEN) and documented for
  the composer in `ship-shape/SKILL.md`'s Intake section. This closes the
  silent-drop doctrine gap: CD5(b) was previously a named decision with no
  task, no DC, and no test.

## Trade-off Table

### CD1 — Route-vocabulary reconciliation

| Option | Description | Pros | Cons |
|---|---|---|---|
| **A. Reuse existing enum (`proceed`/`narrow`/`return`)** | Map issue #49's `re-anchor` → `return`; drop `split` (rabbit hole). Guard emits one of `proceed`/`narrow`/`return`, referencing `plugins/ship-flow/_mods/science-officer-em.md:110`. | (1) Zero change to `science-officer-em.md` contract or its five existing test files. (2) Downstream FO route-back logic already knows these three values. (3) Preserves the "SO/EM owns the route call" boundary from science-officer-em.md:114-119. | (1) `re-anchor` and `return` are semantically close but not identical — issue #49 wants "goal already met, close/defer entity" which is a stronger claim than the generic "return work". Rationale needs to land in the mod prose so the model does not conflate. |
| B. Add `re-anchor` + `split` to the enum | Perfect fidelity to issue #49 wording. | (1) Changes contract at `science-officer-em.md:110`. (2) Breaks `test-science-officer-em-upward-report-contract.sh` and `-surfaces.sh`. (3) Widens scope beyond small-batch appetite (2-3 days). Explicitly deleted in shape (`deleted_from_shape[1]`). |

**Recommendation: A.** Reuse `proceed`/`narrow`/`return`. The mod prose defines the guard's use of `return` narrowly: "the original goal is already met by existing capability — close or defer this entity". `split` (new goal → separate issue) stays a rabbit hole (`issue-anchor-guard-remaining-triggers`) because it also requires child-creation instrumentation the small-batch cannot afford. This decision is already load-bearing in shape (`deleted_from_shape[1]`) — design ratifies it.

### CD2 — Enforcement style (the pre-mortem crux)

| Option | Description | Pros | Cons | Test surface |
|---|---|---|---|---|
| **A. Wired mod `plugins/ship-flow/_mods/issue-anchor-guard.md` with `## Hook: pre-shape` + shell test** | Same pattern as `contribution-contract.md`: an inline extractable resolver block that shape-stage FO invokes before entering shape flow. Ship-shape SKILL.md gets a short section that resolves + invokes the mod. New test `test-issue-anchor-guard.sh` in the contribution-contract style: pins the mod file, its Hook heading, its resolver block, its five-field output contract, and runs it end-to-end against a synthetic entity fixture with + without a re-shape signal. | (1) Testable — hook heading, resolver block, and end-to-end fixture all greppable. (2) Matches existing plugin pattern; adopters know how to override. (3) Wired = present in the FO invocation path, not just cited. (4) Same `## Hook:` grammar as five sibling mods. | (1) More scaffolding surface than option B (~200 LoC across mod + test + SKILL section). Not a real cost — the shape budget explicitly funds it. |
| B. Inline SKILL section in `ship-shape/SKILL.md` + string-assertion test | Add a `### Issue-Anchor Guard` subsection near Intake; assert the section exists and mentions the five contract fields via grep. | (1) Smaller diff. | (1) The pre-mortem says the risk is hollow prose passing verify — a string assertion for a section title is exactly the hollow test. (2) The reverse-recovery-audit.md analog is the cautionary tale: prose reference, no `## Hook:`, no test, and its path is dangling (rabbit hole `reverse-recovery-audit-dangling-path`). (3) No end-to-end fixture — the model can add the section without the guard actually running at re-shape time. |

**Recommendation: A.** Ship a wired mod. The pre-mortem category is `wrong-dcs` — the guard passes verify but catches no drift. Only an end-to-end fixture that (i) creates a synthetic entity with `design.md` present, (ii) invokes the resolver, (iii) asserts the output YAML has the five required fields with non-empty values, and (iv) asserts a second entity without later-stage artifacts is a no-op, can pin non-hollow behavior. Test lives at `plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` and follows the extractable-resolver + adopter/source split from `test-contribution-contract.sh`.

**Test implications (load-bearing)** — `test-issue-anchor-guard.sh` MUST cover:

1. Mod file exists at `plugins/ship-flow/_mods/issue-anchor-guard.md`; has `## Hook: pre-shape` heading (grep).
2. Mod contains an extractable `# issue-anchor-guard-resolver:start` / `:end` block that is valid shell (`bash -n`).
3. Resolver invoked on a fixture entity with `design.md` + `plan.md` present AND a valid `issue: "#N"` frontmatter field: writes source-diff YAML to `.context/ship-flow/source-diff-<id>.yaml` containing all five CD4 fields.
4. Resolver invoked on a fresh-shape entity (no `design.md`): exits 0 with `guard_required=false` recorded (no drift check needed).
5. Resolver invoked on a re-shape entity **without** `issue:` field: exits 0 but writes `no_issue_anchor: true` and a captain-prompt marker instead of a fake diff (honors the "never faked" AC).
6. Ship-shape SKILL.md contains the resolver invocation line before Intake, tagged with an explicit `<!-- section:issue-anchor-guard --> ... <!-- /section:issue-anchor-guard -->` block so future refactors cannot silently drop it.
7. `verdict` field value is one of `proceed`/`narrow`/`return` (CD1 vocabulary lock).

### CD3 — Re-entry detection

| Option | Description | Pros | Cons |
|---|---|---|---|
| **A. Automatic — grep entity folder for later-stage artifacts** | On every `/shape <entity-id>`, the resolver checks whether `docs/<wf>/<id>-<slug>/` (or the flat-file equivalent) already contains `design.md`, `plan.md`, `execute.md`, `verify.md`, `review.md`, or a `status:` value beyond `sharp`. If yes → guard required. | (1) Honest to the shape statement: "the drift is silent" — an automatic detector cannot be forgotten. (2) Uses only local filesystem state; no external signal needed. (3) Aligns with A1 (only real route-back is captain re-invoking `/shape <entity-id>` on an artifact-carrying entity). | (1) A fresh `/shape "<free text>"` never triggers the guard (correct — no drift possible). (2) Requires care: a `--discuss` re-entry on a Mode B entity is the same trigger; must not accidentally skip on Mode B. |
| B. Explicit — captain flag `--re-anchor` or FO-set signal | Captain (or FO) declares re-shape intent. | (1) Zero risk of false positive. | (1) Forgotten exactly when it matters most (the 2+ week drift chain in issue #49 shows humans do not remember to invoke drift guards mid-fire). (2) Contradicts the shape's core claim: the drift lives precisely where nobody thought to look. |

**Recommendation: A.** Automatic detection. Trigger condition: entity folder (or flat file's `status:` frontmatter) shows any of `design.md`, `plan.md`, `execute.md`, `verify.md`, `review.md`, OR `status:` in `{design, plan, execute, verify, ship, done}`. Escape hatch: if the captain explicitly wants to skip the guard on a known false positive, they must pass `--skip-issue-anchor-guard` (not the inverse) — the default is on, so a forgotten flag fails safe.

### CD4 — Source-diff output contract (the pre-mortem mitigation)

| Option | Description | Pros | Cons |
|---|---|---|---|
| **A. Five-field YAML block written to `.context/ship-flow/source-diff-<id>.yaml`** | Fields: `original_issue_acs[]` (verbatim `gh issue view` lines quoted with source line numbers), `current_scope_delta` (what the current entity shape.md/plan.md is doing that the issue did not ask for, as a bullet list), `scope_subset_of_issue` (bool: is current scope subset of original asks?), `goal_still_unmet` (bool: is the original AC actually still unmet, or achievable by existing capability?), `verdict` (enum: proceed/narrow/return). | (1) All five fields are shell-testable: `yq eval` or `grep -q "original_issue_acs:"` etc. (2) Every field maps to a concrete question issue #49 poses (Q1 goal-unmet, Q2 scope-subset, Q3 verdict). (3) YAML in `.context/` is a durable artifact plan/verify stages can reference. (4) Test can assert non-empty AC quotes (rules out "I re-read the issue" hollow claim). | (1) YAML schema is another surface to maintain. Mitigated: schema declared inline in the mod, no separate `.yaml` schema file. |
| B. Prose narrative in shape.md | The model writes a "Source Diff" H2 section into shape.md. | (1) Zero new artifact. | (1) The pre-mortem itself: prose the model performs hollowly. (2) Hard to shell-test beyond "H2 exists". (3) Buries the anchor artifact inside the drifted artifact — same failure mode as the original bug. |

**Recommendation: A.** Emit the five-field YAML. Required schema (locked in the mod):

```yaml
# .context/ship-flow/source-diff-<id>.yaml
schema_version: "1.0"
entity_id: "<id>"
issue_ref: "<gh|linear>#<number>"
issue_fetched_at: "<ISO8601>"
original_issue_acs:                # verbatim quotes from `gh issue view` body
  - "AC-1: <quoted line>"
  - "AC-2: <quoted line>"
current_scope_delta:               # what current shape/plan is doing beyond the issue
  - "<bullet>"
scope_subset_of_issue: <true|false>
goal_still_unmet: <true|false>
verdict: <proceed|narrow|return>   # CD1 vocabulary
rationale: "<one paragraph, cites at least one AC by number>"
```

Non-hollow rule (test-enforced): if `verdict: proceed` then BOTH `scope_subset_of_issue: true` AND `goal_still_unmet: true` MUST hold; otherwise the guard MUST emit `narrow` or `return`. This is the mechanical bridge from "I re-read the issue" (hollow) to "here's the diff, and here's why the verdict follows" (testable). `original_issue_acs[]` MUST be non-empty when `issue:` is present; empty list with `issue:` set fails the shell test.

**No-issue fallback (honors AC's "never given a fake anchor")**: if entity has no `issue:` field, resolver writes instead:

```yaml
schema_version: "1.0"
entity_id: "<id>"
no_issue_anchor: true
captain_prompt: "Entity has no tracker issue: field. Confirm current scope manually or attach an issue: <ref> to the entity frontmatter and re-run."
```

Ship-shape halts and SendMessage(captain) with the prompt; captain resolves by editing the entity OR by explicit `--skip-issue-anchor-guard`.

## Implementation Sketch (one page)

### New file: `plugins/ship-flow/_mods/issue-anchor-guard.md` (~100 lines)

Structure mirrors `contribution-contract.md`:

- YAML frontmatter: `name`, `description`, `version: 0.1.0`.
- `## Hook: pre-shape` heading (grep target).
- `## Invocation` prose: ship-shape FO invokes this before Intake; skip only if entity has no later-stage artifacts (fresh shape) OR captain passed `--skip-issue-anchor-guard`.
- Extractable resolver block bounded by `# issue-anchor-guard-resolver:start` / `# issue-anchor-guard-resolver:end`. The resolver:
  1. Reads `ENTITY_ID` from arg, resolves entity dir under `WORKFLOW_DIR`.
  2. Detects re-shape: any of `design.md|plan.md|execute.md|verify.md|review.md` present, OR frontmatter `status:` in `{design,plan,execute,verify,ship,done}`.
  3. If not re-shape → write `guard_required: false` marker, exit 0.
  4. Reads `issue:` + `tracker:` from entity frontmatter via `extract-frontmatter.sh`.
  5. If no `issue:` → write `no_issue_anchor: true` + captain prompt YAML, exit 0.
  6. If `tracker: gh` → `gh issue view <n> --json title,body,labels`, parse `## Acceptance` / `AC-N` lines from body.
  7. If `tracker: linear` → shell out to `resolve-issue-anchor-linear.sh` (helper stub in this round; v1 supports gh, Linear supported in same pattern but tested via a fixture stub).
  8. Emit `.context/ship-flow/source-diff-<id>.yaml` with the CD4 five-field schema.
- `## Schema (locked)` block: literal YAML skeleton for the source-diff artifact.
- `## Rationale + References` — route enum authority at `science-officer-em.md:110`, verdict semantics.

### Changed file: `plugins/ship-flow/skills/ship-shape/SKILL.md` (~15 lines)

Add a `### Pre-Intake: Issue-Anchor Guard` subsection immediately before the existing `### Intake` header (currently around line 49). Contents:

```markdown
### Pre-Intake: Issue-Anchor Guard

<!-- section:issue-anchor-guard -->
Before Intake, resolve `plugins/ship-flow/_mods/issue-anchor-guard.md` for the target entity. If guard emits `verdict: narrow` or `verdict: return`, SendMessage(captain) with the source-diff summary before continuing to Intake. If `no_issue_anchor: true`, halt for captain confirmation. See mod for full contract; skip only via explicit `--skip-issue-anchor-guard`.
<!-- /section:issue-anchor-guard -->
```

Also update the References block at line ~585 to add: `- Issue-anchor guard mod: plugins/ship-flow/_mods/issue-anchor-guard.md.`

### New file: `plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` (~200 lines)

Pattern-copy from `test-contribution-contract.sh`:

- `extract_resolver` awk block that pulls the shell between `# issue-anchor-guard-resolver:start|end` markers.
- Three fixtures under `$TMP_DIR`:
  - **fx-reshape-with-issue**: entity dir with `index.md` (issue: "#49"), `shape.md`, `design.md`. Assert resolver writes source-diff YAML with 5 non-empty fields, verdict in {proceed,narrow,return}, `original_issue_acs[]` non-empty, non-hollow rule (if verdict=proceed then both bools true).
  - **fx-fresh-shape**: entity dir with only `index.md` + `shape.md`. Assert `guard_required: false` marker.
  - **fx-reshape-no-issue**: entity with `design.md` but no `issue:` field. Assert `no_issue_anchor: true` + captain prompt string in YAML.
- Cross-check that ship-shape SKILL.md contains the `<!-- section:issue-anchor-guard -->` block and cites the mod path (guards against silent drop).
- gh CLI is stubbed via a `PATH`-shadowed `gh` fixture returning canned issue JSON (same pattern as test-contribution-contract uses git init).

### Doc-coupling row (contribution-contract compliance)

Add row to `plugins/ship-flow/references/doc-coupling-map.yaml`:

```yaml
- name: issue-anchor-guard
  srcGlobs: ["plugins/ship-flow/_mods/issue-anchor-guard.md"]
  docPaths: ["plugins/ship-flow/skills/ship-shape/SKILL.md"]
  directions: ["source-to-doc", "doc-to-source"]
```

Ensures future edits to either side surface at PR-review time via the existing doc-impact gate.

## Artifacts Changed (scope boundary for plan stage)

| File | Change type | Scope |
|---|---|---|
| `plugins/ship-flow/_mods/issue-anchor-guard.md` | NEW | ~100 lines: mod prose + `## Hook: pre-shape` + resolver block + YAML schema |
| `plugins/ship-flow/skills/ship-shape/SKILL.md` | EDIT | +~15 lines: `### Pre-Intake: Issue-Anchor Guard` subsection before line ~49 Intake; +1 line References at ~585 |
| `plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | NEW | ~200 lines: shell test with 3 fixtures + resolver extraction + 7 assertions per CD2 test-implications |
| `plugins/ship-flow/references/doc-coupling-map.yaml` | EDIT | +1 row: `issue-anchor-guard` bidirectional coupling |
| `docs/ship-flow/README.md` | EDIT (optional) | +1 line under mods index if that index exists; skip if none |

Est. total: ~320 net LoC, all in `plugins/ship-flow/`. No changes to `science-officer-em.md`, `entity-body-schema.yaml`, `advance-stage.sh`, or any downstream consumer.

## Open Questions / Risks (for plan)

1. **Q: `gh issue view` for Linear entities?** `tracker: linear` uses `linear-mcp` (main FO context only, per A2). Plan must specify the branch: `if tracker=gh use gh issue view; if tracker=linear use linear-mcp get_issue`. Resolver becomes a two-arm shell block or delegates to a small helper `resolve-issue-anchor.sh`. Risk: low — the resolver can shell out either way; the test only needs to cover `gh` in v1 with a Linear rabbit-hole note. Verify stage should smoke-test one Linear entity manually.
2. **Q: Flat-file entities (`docs/<wf>/<id>-<slug>.md`) vs folder entities?** Detection must work on both layouts. Solution: for flat file, "later stage" = `status:` frontmatter in `{design,plan,execute,verify,ship,done}` (no `design.md` to grep). Test must cover both fixtures.
3. **Q: What if `gh issue view` fails (rate-limit / offline)?** Resolver exits non-zero with a captain-visible error, NOT with a fake-empty AC list. Test asserts non-zero exit and error string on a stubbed-failing gh.
4. **Q: Should the guard also run on `/shape --discuss`?** Yes — re-entry via `--discuss` on an entity carrying later-stage artifacts is exactly the drift path. The trigger is folder state, not the flag. Plan explicitly covers this in the SKILL edit.
5. **Non-risk: multi-round drift accumulation.** The guard fires every re-shape, not just the first — so round-5 diffs the current (round-4-drifted) shape against the same immutable issue text. This is the intended behavior; each round gets a fresh anchor check.

No blocking unknowns. All CDs have a chosen option with a testable enforcement path.

## Verdict

**PROCEED to plan** with the four decisions locked in:

- **CD1** = A (reuse `proceed`/`narrow`/`return`; `re-anchor`→`return`; `split` rabbit hole)
- **CD2** = A (wired mod with `## Hook: pre-shape` + full shell test)
- **CD3** = A (automatic detection via entity folder / status frontmatter)
- **CD4** = A (five-field YAML source-diff artifact, non-hollow rule test-enforced)

The pre-mortem risk (hollow prose passing verify) is mitigated by CD2 and CD4 in combination: an end-to-end fixture invokes the resolver and asserts the concrete YAML fields, so a model that only writes prose cannot pass the test. The appetite (small-batch, 2-3 days) holds — all changes are in a single plugin subdirectory with an existing test harness pattern to copy.

## Design Report

status: passed
stage_cost: captain-directed reconciliation session (SO/EM fable cross-review + opus FO adjudication against primary-source code, captain confirmation); no per-dispatch agent cost tracked
iterations: 1 reconciliation pass (SO/EM cross-review -> FO adjudication -> captain confirmation)
contradictions_resolved: 5
captain_decisions: 5
reviewer_verdict: PROCEED

Design Readiness Review: skipped - no risk trigger (`affects_ui: false`, no data-schema change, no cross-service-contract change, no event-sourcing-domain change, and no whole-page visual target in this entity; internal ship-flow methodology plus one wired mod only).

This backfills the schema-required `## Design Report` / `### Captain Decisions` / `### Hand-off to Plan` envelope onto the CD1-CD5 Reconciliation above (the substantive decision content), so `check-invariants.sh` C4 and ship-plan Step 1.6 can import it mechanically. No new decisions are introduced here — each Dn below cites the corresponding CDn already adjudicated in Reconciliation.

### Metrics

status: passed
duration_minutes: 0
iteration_count: 1
captain_decisions_count: 5
open_decisions_count: 0
reviewer_verdict: PROCEED

### Captain Decisions

- **D1|Captain decision**: CD1 route-vocabulary reconciliation — reuse the existing `proceed`/`narrow`/`return` triad; the guard's `return` is narrowly defined as "the original goal is already met by existing capability — close or defer this entity"; `re-anchor` maps to `return`, `split` is a deferred rabbit hole (ref: design.md Reconciliation CD1, Trade-off Table CD1).
- **D2|Captain decision**: CD2 enforcement style confirmed as designed — wired mod `plugins/ship-flow/_mods/issue-anchor-guard.md` with `## Hook: pre-shape` + extractable resolver block + end-to-end shell fixture; the Hook is a convention label invoked by the ship-shape SKILL (same pattern as contribution-contract's `pre-review-spend`), NOT an FO-auto-run lifecycle hook; an optional shape-confirm-side belt-and-braces check is deferred (gated on the `shape-confirm-instance-awareness` ROADMAP Later item), not blocking this round (ref: design.md Reconciliation CD2, Trade-off Table CD2).
- **D3|Captain decision**: CD3 re-entry detection confirmed as designed — automatic detection via entity folder artifacts (`design.md`/`plan.md`/`execute.md`/`verify.md`/`review.md`) OR `status:` frontmatter; `status ∉ {draft, sharp}` is the PRIMARY signal (covers flat-file-layout entities with no folder to grep), folder artifacts are secondary; default-on with an explicit `--skip-issue-anchor-guard` escape hatch (ref: design.md Reconciliation CD3, Trade-off Table CD3).
- **D4|Captain decision**: CD4 per-AC refinement — `original_issue_acs[]` becomes per-AC rows, each carrying its own `met_by_existing_capability: <true|false>` (not a single aggregate `goal_still_unmet` boolean), so the case-study blind spot (one AC already achievable by existing capability hiding inside an aggregate answer) cannot hide; `verdict` derives from the rows; the non-hollow rule (verdict:proceed requires scope_subset_of_issue:true AND goal_still_unmet:true) still holds, with `goal_still_unmet` now derived as true when ANY AC row has `met_by_existing_capability: false`. Honest residual (shell test cannot close it): a model can still fill every field with a false ⊆-judgment (ref: design.md Reconciliation CD4, Trade-off Table CD4).
- **D5|Captain decision**: CD5 anchor availability — an empty-string `issue:` is treated as absent (archived entity 1 carries a literal empty `issue:`), **IMPLEMENTED** (T2/DC-8a); bounded intake-stamping carries `issue:`/`tracker:` into entity frontmatter at shape-confirm when a shape directive references a tracker issue, so future entities are born anchored (reference only, no full tracker integration), **IMPLEMENTED** (T5/DC-5.1-1..3, ref: design.md Reconciliation CD5).

### Hand-off to Plan

<!-- section:hand-off-to-plan -->
```yaml
design-skipped: false
design_constraints:
  - type: contract
    assertion: "Guard emits verdict as exactly one of proceed/narrow/return (CD1 vocabulary lock, no new SO/EM route values); re-anchor maps to return, narrowly defined as 'the original goal is already met by existing capability — close or defer this entity'; split stays out of scope this round."
    rationale_decision: D1
    source_artifact: docs/ship-flow/5-issue-anchor-scope-drift-guard/design.md
  - type: contract
    assertion: "Ship plugins/ship-flow/_mods/issue-anchor-guard.md as a wired mod: '## Hook: pre-shape' heading + an extractable resolver block bounded by '# issue-anchor-guard-resolver:start'/':end' (valid shell, bash -n), invoked from a pinned <!-- section:issue-anchor-guard --> block in plugins/ship-flow/skills/ship-shape/SKILL.md before Intake — not an inline prose-only SKILL section with a string-assertion test."
    rationale_decision: D2
    source_artifact: docs/ship-flow/5-issue-anchor-scope-drift-guard/design.md
  - type: contract
    assertion: "Resolver auto-detects re-shape: any of design.md/plan.md/execute.md/verify.md/review.md present in the entity folder, OR entity `status:` in {design,plan,execute,verify,ship,done} (status is the PRIMARY signal so flat-file-layout entities with no folder are covered; folder artifacts are secondary). Default-on; escape hatch is an explicit --skip-issue-anchor-guard flag, never the inverse."
    rationale_decision: D3
    source_artifact: docs/ship-flow/5-issue-anchor-scope-drift-guard/design.md
  - type: schema-contract
    assertion: "Source-diff YAML at .context/ship-flow/source-diff-<id>.yaml carries schema_version, entity_id, issue_ref, issue_fetched_at, original_issue_acs[] (verbatim gh-quoted rows, each an object with the quoted AC text plus its own met_by_existing_capability:<bool>; non-empty when issue: is present), current_scope_delta[], scope_subset_of_issue:<bool>, goal_still_unmet:<bool> (derived: true when ANY AC row has met_by_existing_capability:false), verdict, and rationale (cites >=1 AC by number). Non-hollow rule: if verdict:proceed then BOTH scope_subset_of_issue:true AND goal_still_unmet:true MUST hold; otherwise verdict MUST be narrow or return."
    rationale_decision: D4
    source_artifact: docs/ship-flow/5-issue-anchor-scope-drift-guard/design.md
  - type: contract
    assertion: "Resolver treats an empty-string issue: as absent — writes no_issue_anchor:true + a captain_prompt marker (never a fake diff) and halts for captain resolution (edit the entity or pass --skip-issue-anchor-guard); a gh issue view failure (rate-limit/offline) exits non-zero with a captain-visible error string, never a fake-empty AC list; shape-confirm carries a shape directive's tracker reference (URL / #N) into the entity's issue:/tracker: frontmatter, reference only, no full tracker integration."
    rationale_decision: D5
    source_artifact: docs/ship-flow/5-issue-anchor-scope-drift-guard/design.md
open_decisions: []
artifact_paths:
  - path: docs/ship-flow/5-issue-anchor-scope-drift-guard/design.md
```
<!-- /section:hand-off-to-plan -->
