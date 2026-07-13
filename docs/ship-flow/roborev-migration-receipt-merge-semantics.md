---
title: Deterministic migration receipts and merge-parent semantics
status: shape
source: "RoboRev job 40 exact-head review of C14"
started: 2026-07-13T09:46:16Z
completed:
verdict:
score:
worktree:
issue:
pr:
pattern: pitch
appetite: medium-batch
answers_density: high
affects_ui: false
design_required: true
contract_decision_required: true
domain: schema
---

Replace heuristic entity-migration correlation with a deterministic sanctioned
contract, and define merge-parent semantics that validate resolution-only status
changes without re-requiring receipts for transitions inherited unchanged from
another parent.

## Acceptance criteria

**AC-1 — Entity migration identity is deterministic rather than content-similarity based.**
Verified by: a mechanically validated migration receipt or stable identity contract accepts intentional path/ID migrations and rejects ambiguous retirement-plus-addition histories without relying on Git rename percentage.

**AC-2 — Merge status validation distinguishes inherited state from resolution-only mutation across all parents.**
Verified by: regression fixtures cover ordinary inherited merges, an entity absent from the first parent but present in another parent, and a resolution status that differs from every parent.

**AC-3 — The C14 branch can produce a fresh exact-head RoboRev receipt with no medium-or-higher code finding.**
Verified by: targeted C14 tests, full invariant/shell/Node gates, and a `code_completion` panel whose reviewed head equals the branch head.

<!-- section:pm-skill-receipts -->
```yaml
pm_skill_receipts:
  stage: ship-shape
  mode: mode-a
  appetite: medium-batch
  compose_guard: passed
  receipts:
    - phase: intake-problem
      delegate: problem-framing-canvas
      required: true
      status: unavailable
      evidence:
      fallback: inline
      rationale: RoboRev job 40 and the dispatch end value provide a concrete falsifier-grounded problem.
    - phase: scope-decompose
      delegate: opportunity-solution-tree
      required: true
      status: unavailable
      evidence:
      fallback: inline
      rationale: The dispatch completion checklist fixes the two independently valuable seams and their boundary.
    - phase: assumption-extract
      delegate: pol-probe-advisor
      required: true
      status: unavailable
      evidence:
      fallback: inline
      rationale: The critical receipt-identity assumption is isolated and handed to design for falsification.
    - phase: acceptance-outcome
      delegate: press-release
      required: true
      status: unavailable
      evidence:
      fallback: inline
      rationale: The dispatch end value supplies the observable C14 outcome without expanding product scope.
```
<!-- /section:pm-skill-receipts -->

## Dispatch Articulation Trail

This shape organizes the First Officer dispatch rather than inventing a wider
brief:

- **Problem:** RoboRev job 40 showed that Git similarity can invent or miss
  migration identity, and that first-parent-only classification misses an
  entity present only in another merge parent.
- **Wedge:** “Cut the contract to the smallest deterministic migration identity
  that replaces Git similarity without confusing retirement plus addition.”
- **Outcome:** “C14 can distinguish sanctioned entity migration and genuine
  merge-resolution status changes without heuristic identity or duplicate
  receipt failures.”
- **Boundary:** shape/design only; no C14 implementation, old-entity lifecycle
  mutation, hook installation, or required RoboRev gate.

## Acceptance Outcome

When C14 inspects entity history, a maintainer can explain every cross-path
migration from one exact sanctioned receipt and every merge status decision
from the complete parent set. Ordinary inherited merges remain receipt-free,
while a novel merge-resolution status cannot hide behind parent ordering or a
Git similarity score.

## Appetite

`medium-batch` — up to 1 week inside the 1-2 week band. The initial two-slice
cut omitted the sanctioned emitter, activation compatibility, and the
normalization/validation seam identified by independent review and RoboRev job
41. Receipt authentication, a general event ledger, and RoboRev gate promotion
remain explicitly outside the budget.

## Children and Appetite Fit

- **C1 — Ratified receipt envelope and sanctioned emitter** (`~1.5 days`, deps:
  none): one bounded operation envelope can be emitted and parsed.
- **C2 — Deterministic migration correlation and activation compatibility**
  (`~1.5 days`, deps: C1): migration is distinguished from independent
  retirement/creation without inference or retroactive main-history failure.
- **C3 — All-parent normalization and resolution validation** (`~2 days`, deps:
  C2): inherited, collision, pure-addition, and resolution-only states are
  deterministic before graph enforcement.

The five-day sum is below 80% of a ten-workday medium-batch cap (eight days),
leaving three days for review/falsifier iteration. The exact-head RoboRev run
is acceptance evidence, not a fourth child. Planning and implementation are
blocked until design ratifies the decisions named in the hand-off.

### Will get

- **W1:** When an entity changes path, layout, or frontmatter ID, maintainers
  can bind exactly one before path to exactly one after path without content
  similarity. (Check: W1 in `Will-get dogfood checks`.)
- **W2:** When a merge result inherits an entity state from any parent,
  maintainers can merge it without manufacturing a duplicate transition
  receipt. (Check: W2 in `Will-get dogfood checks`.)
- **W3:** When a merge creates a status different from every parent that
  contains the entity, C14 can validate the new transition independent of
  parent order. (Check: W3 in `Will-get dogfood checks`.)
- **W4:** When the repaired C14 head is reviewed, the captain can inspect a
  fresh exact-head RoboRev panel with no medium-or-higher finding after the FO
  lifecycle prerequisite is reconciled. (Check: W4 in `Will-get dogfood
  checks`.)

### Won't get

- No cryptographic proof that a receipt was emitted by Spacedock; current
  commit-message provenance remains structurally validated, not authenticated.
- No permanent acceptance of frontmatter ID, normalized layout, or Git rename
  percentage as sufficient cross-path identity.
- No pre-commit/pre-push hook and no required RoboRev CI gate.
- No lifecycle repair for `c14-fo-dispatch-contract`; FO owns that separate
  sanctioned transition.

### Why this scope

An exact operation receipt plus all-parent state comparison closes both job-40
findings. A durable global UUID system or general workflow event ledger would
expand migration, creation, and provenance policy beyond this C14 repair.

## Contract Alternatives

| Approach | Benefit | Loss function | Shape decision |
| --- | --- | --- | --- |
| Immutable frontmatter ID | Small comparison surface for already-ID-bearing entities | Legacy entities and intentional ID changes still need an escape hatch; ID reuse can confuse retirement plus addition | Reject as the sole contract |
| Exact commit-bound `before path -> after path` receipt | Handles path, layout, ID, and content changes without inference; naturally one-to-one | Requires sanctioned emitter/grammar and a rule for mixed add/delete commits | **Recommend** |
| Blob-OID lineage receipt | Strongly binds exact content snapshots | Duplicates identity already supplied by commit plus path, complicates rewrites, and adds no status-transition authority | Reject as overbuilt |

## Shaped Contract

Shape fixes the semantic boundary below. Carrier syntax and the divergent-parent
legality algorithm are explicit design decisions; normative implementation must
not begin until design ratifies them.

### M1 — Deterministic migration identity

1. A cross-path entity migration exists only when the inspected commit carries
   one mechanically valid receipt binding workflow identity, source parent,
   exact before path, and exact after path. A single-parent commit has one
   implicit source parent; a merge names it explicitly.
2. Each before and after path may occur in at most one pair. One-to-many,
   many-to-one, duplicate, cross-workflow, nonexistent-source, and
   nonexistent-destination claims fail closed.
3. The before path is resolved in the named source-parent tree and the after
   path in the commit tree. The inspected commit plus parent identity supplies
   the revision boundary, so blob hashes are not part of the minimal identity.
4. A commit containing both unpaired entity deletions and additions in the same
   workflow is ambiguous. It must account for every path with either a
   migration pair or explicit independent `retire`/`create` disposition, or
   split genuine retirement and creation into separate commits. Pure
   addition-only and deletion-only commits retain their existing exemption.
5. Layout identity, equal frontmatter ID, and Git rename similarity may produce
   diagnostics, but none may establish migration identity or authorize a
   transition.
6. A migration receipt only correlates paths. If status changes across the
   pair, the normal workflow-graph and stage-entry/completion receipt checks
   still apply.

#### Provisional semantic envelope for design ratification

The carrier may be a commit trailer or another commit-bound surface, but after
parsing it must yield these fields. Design may change spelling, not meaning:

| Field | `migrate` | `retire` | `create` |
| --- | --- | --- | --- |
| `version` | required, exactly `1` | required | required |
| `operation` | `migrate` | `retire` | `create` |
| `workflow` | required workflow slug | required | required |
| `source_parent` | required for merge, implicit sole parent otherwise | required for merge, implicit otherwise | forbidden |
| `before_path` | required | required | forbidden |
| `after_path` | required | forbidden | required |

All paths are normalized repository-relative paths under the declared
`docs/<workflow>/` root: no absolute path, `..`, empty segment, workflow escape,
or README target. A path may be classified exactly once per commit. The number
of operation rows cannot exceed the changed entity-path count. Unknown version,
unknown field, malformed row, duplicate classification, source-parent not in
the commit's parent set, missing before blob, missing after blob, or wrong
workflow fails before status validation. Design owns the exact line-length and
message-size limits.

#### Activation and legacy compatibility

The new contract is scan-bound, not retroactive. C14 continues to inspect only
`merge-base(origin/main, HEAD)..HEAD`; main-history migrations before the new
checker lands are never revisited. Any in-range mixed delete/add commit is
subject to v1 and must be amended with operation rows or split. A branch forked
before activation must rebase onto the new main and repair its still-unmerged
in-range commits; Git similarity is not retained as a grandfather path. After
the review range is selected, a missing required parent/tree object fails loud
rather than being treated as absence. The existing no-`origin/main` fixture
skip remains a separate C14 boundary.

Diagnostics use stable categories so fixtures assert causes rather than prose:
`receipt-missing`, `receipt-malformed`, `receipt-conflict`,
`receipt-semantic-invalid`, `parent-unavailable`, `parent-path-collision`, and
`transition-illegal`. Design supplies exact messages and carrier bounds.

This is the smallest contract that both recognizes a simultaneous path/ID
change and refuses to guess whether an unrelated deletion plus addition is a
migration.

### M2 — Recommended multi-parent merge semantics (design ratification required)

For merge commit `M`, define each entity path state in every parent as
`absent` or `present(status)`. Apply a valid M1 path mapping from its named
source parent before comparing states when the merge itself migrates the
entity. Other parents participate at that source path or the result path;
convergence from multiple unrelated old paths must be normalized before merge
and is outside this medium-batch contract.

Per parent, normalization is order-independent:

1. Inspect the receipt's normalized source path and result path in that parent.
2. Neither exists → logical state `absent`.
3. Exactly one exists → logical state `present(status)` from that path.
4. Both exist → fail `parent-path-collision`; C14 does not infer that two blobs
   are one entity, even if IDs, status, or content match.
5. Deduplicate identical normalized states only after every parent is
   classified; retain the contributing parent set for diagnostics.

Different parents may recognize different members of the source/result pair;
the fixed mapping still normalizes them to one logical comparison set. A
second unrelated old path is not part of that mapping and must be normalized
on its branch before merge.

1. **Inherited:** if `M`'s result state equals the state in any parent, the
   result is inherited. C14 does not require a second transition receipt on the
   merge commit, even when the matching parent is not the first parent.
2. **Pure addition:** a result is a pure addition only when the logical entity
   is absent from every parent at the result/source path and no migration
   receipt names a source in any parent.
3. **Resolution-only:** when the result differs from every normalized parent and the
   logical entity exists in at least one parent, the merge introduced a new
   state. Absence contributes no graph edge.
4. **Recommended legality rule:** the result must be a declared direct next or
   feedback transition from every distinct present-parent status, and the merge
   commit carries one transition receipt bound to the resulting stage. This is
   fail-closed and parent-order-independent, but remains unratified because job
   40 proves first-parent-only wrong without proving direct-edge-from-every-parent
   is the only valid reconciliation policy.
5. Design must ratify the recommendation or replace it with one fully specified
   alternative: graph reachability, or a receipt-selected provenance parent
   plus explicit reconciliation checks for every other present parent. Plan
   must not choose. Any ratified option must have identical verdicts under
   parent permutation and cannot let one convenient parent silently mask
   another.

The job-40 absent-first-parent case therefore reduces deterministically:
`P1=absent`, `P2=present(shape)`, `M=present(shape)` is inherited; the same
parents with `M=present(plan)` are resolution-only and must prove the
`shape -> plan` edge plus one merge transition receipt.

## Will-get dogfood checks

- **W1:** RED/GREEN fixtures cover a low-similarity path+ID migration with one
  exact receipt, the same migration without a receipt, duplicate/one-to-many
  receipts, an unrelated retirement plus addition with explicit independent
  dispositions, and the ambiguous equivalent with neither dispositions nor a
  split commit.
- **W1 compatibility:** a pre-contract migration reachable only in main history
  is not scanned; an unmerged in-range legacy migration fails with an actionable
  amend/split diagnostic rather than falling back to similarity.
- **W2:** A no-conflict merge and an absent-first-parent merge whose result
  equals the second parent pass without a merge transition receipt; the same
  inherited transition is not reported twice.
- **W3:** Fixtures permute parent order and cover a result different from every
  parent. They also cover source-only, result-only, neither-path, and both-path
  collision normalization in non-source parents. The design-ratified legality
  policy supplies the final pass/fail matrix; planning is blocked until then.
- **W4:** Run targeted C14 fixtures, full invariant/shell/Node gates, then a
  `code_completion` panel whose reviewed head equals branch HEAD and whose
  synthesis contains zero medium-or-higher finding. Before that final panel,
  FO must reconcile the stale `c14-fo-dispatch-contract` lifecycle through its
  sanctioned transition path; this pitch neither edits nor bypasses it.

## Mechanism-to-Value Evidence Matrix

| Mechanism criterion | Reproducible value evidence |
| --- | --- |
| Exact one-to-one path receipt is the only cross-path identity | A low-similarity intentional migration is correlated; unrelated delete/add content is never similarity-paired |
| Mixed operations require pair or independent dispositions | Legitimate retirement plus creation remains possible, while a status-jump evasion cannot silently relabel itself |
| Receipt correlation does not authorize status | A receipt-bearing skipped stage still fails the workflow graph |
| Scan-bound activation | Existing main history is not retroactively rejected, while every still-unmerged ambiguous commit is repaired explicitly |
| Result equal to any parent is inherited | Ordinary merge and absent-first-parent inheritance pass without duplicate receipt |
| Pure addition checks every parent | Job 40's absent-first-parent status mutation enters graph and receipt validation |
| Every parent normalizes before legality | Source/result collisions fail deterministically and parent permutations produce the same state set |
| Design-ratified novel-result rule | Parent permutations have identical verdicts and one legal parent cannot silently mask another |

## Scope

### In

- Exact operation-receipt identity and validation invariants.
- Same-workflow migration/retire/create accounting for mixed commits.
- Scan-bound activation behavior for unmerged legacy commits.
- All-parent inherited, pure-addition, and resolution-only state semantics.
- RED/GREEN fixtures for job 40 and receipt ambiguity.
- Fresh exact-head advisory RoboRev proof after normal deterministic gates.

### Out

- Receipt signature/authentication or cross-repository Spacedock provenance.
- General creation, deletion, or event-ledger redesign.
- Multiple unrelated old paths converging into one merge result.
- Required RoboRev policy, hooks, or auto-fix/refine.
- Direct status mutation of any workflow entity.

## Stated Assumptions

- **A1 (critical, 80%)**: Exact commit-bound path pairs plus an ambiguity rule
  are sufficient to represent sanctioned entity migrations without a global
  immutable identifier. `verified_by: codebase-grep`; job-40 and Cases 43-45
  show the current inference boundary, while design must falsify legacy and
  merge-path edge cases.
- **A2 (important, 90%)**: Comparing `(existence, status)` across every parent
  is enough for C14 because C14 protects lifecycle state, not full body-content
  provenance. `verified_by: codebase-grep`.
- **A3 (critical, 70%)**: Requiring a resolution-only result to be legal from
  every present-parent status is an acceptable fail-closed policy; rare
  divergent states can be aligned before merge. `verified_by: design-contract`;
  design must compare direct-edge, graph-reachability, and declared-provenance
  alternatives before ratification.
- **A4 (important, 100%)**: A structural commit receipt cannot authenticate its
  emitter under the current Spacedock contract. `verified_by: codebase-grep`.
- **A5 (critical, 75%)**: Binding a merge migration to one named source parent
  plus a normalized source/result path is sufficient; multi-old-path
  convergence can be rejected and normalized before merge. `verified_by:
  design-contract`.
- **A6 (important, 90%)**: Scan-bound activation avoids breaking accepted main
  history while it is acceptable to require still-unmerged branches to amend
  ambiguous commits. `verified_by: codebase-grep`.

## Rejected Alternatives

- Lower or tune Git rename similarity — retains both false-pair and missed-pair
  failure modes exposed by job 40.
- Treat equal normalized layout as identity — deterministically confuses a
  same-slug retirement plus folder addition.
- Treat frontmatter ID as always immutable — conflicts with legacy/no-ID and
  intentional ID-repair histories already covered by C14 fixtures.
- Require every legitimate retirement plus creation to use separate commits —
  deterministic but needlessly breaks atomic maintenance; explicit independent
  dispositions preserve intent without guessing.
- Validate a novel merge result against only the first or any one parent —
  makes correctness depend on parent order or permits one legal edge to mask an
  illegal rollback from another parent.
- Add cryptographic receipt provenance now — requires a coordinated Spacedock
  contract and exceeds the bounded C14 repair.

## Pre-mortem

`wrong-dcs`: fail-closed parent provenance or mixed-operation rules reject
legitimate merges and retirement-plus-creation histories because compatibility
cases were under-specified.

## DAG

```mermaid
graph LR
  A[Receipt envelope and emitter] --> B[Deterministic correlation and activation]
  B --> C[All-parent normalization and resolution validation]
```

## Dependencies

- **Pre-final-panel FO dependency:** advance
  `c14-fo-dispatch-contract` through the sanctioned lifecycle mechanism so job
  40's third, non-code stale-state finding cannot contaminate AC-3. This shape
  does not perform or simulate that transition.
- **Implementation base:** C14 branch through RoboRev job 40 / HEAD
  `d658eb5c`; design and plan must re-resolve the live head before editing.

## Canonical Intent

- `ROADMAP.md`: ship-review should add/move this entity through the canonical
  Now/Shipped rows; shape does not patch FO-owned stage state.
- `ARCHITECTURE.md#decisions`: **impact required**. Ship-review should append
  the design-ratified receipt carrier and merge-parent reduction semantics.
  The stable intent is explicit commit-bound identity and no content
  similarity; unresolved parent-policy wording must not be canonized early.
- `PRODUCT.md`: skip — this hardens an existing mechanical quality capability;
  it adds no new user-facing capability, persona, or constraint.
- Root `README.md` and workflow README prose: skip at shape — no install,
  command, quick-start, or declared stage-graph change is proposed.

## Domain Registry Validation

- classify: `bash plugins/ship-flow/lib/registry-resolve.sh --classify docs/ship-flow/roborev-migration-receipt-merge-semantics.md`
- validate: `bash plugins/ship-flow/lib/registry-resolve.sh --validate --domain=schema`
- domain: schema
- result: proceed

## Project Skills

- `.claude/ship-flow/domains.yaml`: absent.
- `.claude/ship-flow/skill-routing.yaml`: absent.
- Plugin-default `schema` validation returns `status=ok`; generating adopter
  routing is deliberately deferred while the sibling fixture-pollution entity
  repairs that discovery surface.

### Hand-off to Design

- `affects_ui: false`; `ui_surfaces` and `framework_detected` omitted.
- `open_design_questions`: []
- `open_contract_decisions[]`:
  1. Receipt carrier and canonical grammar, including the sanctioned emitter
     and how C14 distinguishes missing, duplicate, and malformed receipts while
     preserving the explicit non-authentication boundary and bounding parser
     input. Ratify or amend the provisional semantic envelope.
  2. Ratify the operation envelope for mixed additions/deletions: migration
     pairs plus independent retire/create dispositions, covering legacy flat,
     folder, no-ID, and ID-changing histories without implicit identity, plus
     the scan-bound activation policy.
  3. Ratify per-parent normalization, especially both-source-and-result path
     collision, different paths across parents, deduplication, and missing
     parent/tree failure behavior.
  4. Ratify parent provenance and legality: compare direct legality from every
     present parent against graph reachability and a receipt-selected source
     with reconciliation checks; preserve parent-order independence and the
     absent-first-parent outcome in every option.
- `pm_framing_output`: this file's `pm-skill-receipts` section.
- route: `design` (`domain: schema`, `design_required: true`,
  `contract_decision_required: true`).

## Shape Report

- DONE: Cut migration identity to one exact, commit-bound, workflow-local
  before/after path pair; content similarity, layout, and ID inference are not
  authority.
- DONE: Defined the ambiguity rule: mixed unpaired retirement/addition in one
  workflow must be paired, explicitly disposed as independent operations, or
  split, preventing delete/add status evasion without breaking legitimate
  atomic maintenance.
- DONE: Defined all-parent semantics for inherited, pure-addition, and
  resolution-only results, including RoboRev job 40's absent-first-parent case,
  per-parent source/result collision handling, and parent-order independence;
  the novel-result legality algorithm is explicitly recommended but blocked on
  design ratification.
- DONE: Paired every mechanism with reproducible value evidence and named the
  required `ARCHITECTURE.md#decisions` impact plus deliberate PRODUCT/README
  skips.
- DONE: Preserved the parent FO write boundary; no C14 implementation, tests,
  lifecycle status, hooks, or RoboRev required-gate policy changed.
- REVIEW: Independent seven-factor cross-review returned `PROMPT_CAPTAIN` and
  its actionable findings are absorbed: explicit slice estimates, the FO
  lifecycle dependency, legitimate retire/create compatibility, source-parent
  binding, two new critical assumptions, and a compatibility-focused
  pre-mortem. The four remaining semantic choices are explicitly routed to
  design rather than silently selected by plan.
- REVIEW: Exact-commit RoboRev design job 41 reviewed `75a5d4d` and returned
  FAIL. The valid contradictions/gaps are absorbed here: normative-vs-open
  parent policy is separated, non-source-parent normalization is deterministic,
  a provisional semantic envelope and error classes are present, activation is
  scan-bound, the appetite is widened, and implementation is blocked until
  four design decisions are ratified.
- status: passed
- stage_cost: solo shape artifact; no implementation work

### Summary

Shaped a medium-batch C14 repair around a bounded operation envelope,
scan-bound deterministic migration identity, and all-parent normalization,
with job-40/job-41 falsifiers and four implementation-blocking contract
decisions routed to design.

### Metrics

- status: passed
- duration_minutes: 42
- iteration_count: 0
- path: sharp-only
- open_contract_decisions_count: 4
- domain_matches_count: 1
