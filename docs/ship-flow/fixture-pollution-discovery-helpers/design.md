# Fixture-tree exclusion for discovery helpers — Design

This is a non-UI contract/interface design. It does not select an option for
the Captain: the approved Bet fixes the observable outcome, but it does not
choose the shared surface, exclusion vocabulary, or inventory boundary.

```yaml
design-dispatch-manifest:
  lanes:
    - lane: contract-interface
      role: contract/interface-designer
      trigger: open_contract_decisions
      decisions:
        - shared-surface-form-and-future-non-shell-consumption
        - root-relative-nested-fixture-semantics
        - mechanical-repository-tree-walker-inventory
      required_skills:
        - ship-flow:ship-design
        - superpowers:brainstorming
      outputs:
        - docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  integration:
    mode: single-designer
    owner: ship-design
  registry_context:
    classified_domain: schema
    validation: ok
    designer_section_anchor: ship-design#schema-designer
    applied_route: contract-interface-only
    rationale: The dispatch and shape scope define a portable Bash discovery contract, not a data-model surface.
  visual_verification:
    status: not-applicable-non-ui
```

## Canonical Context

| Doc | Sections Read | Update Intent | Skip Rationale |
| --- | --- | --- | --- |
| `PRODUCT.md` | `Current Capabilities` | skip | This corrects existing internal discovery behavior; it does not add a durable product capability (`PRODUCT.md:7-18`). |
| `ARCHITECTURE.md` | `containers`, `components`, `constraints`, `dependencies` | skip | A sourceable/executable lib primitive stays inside the existing `lib/` boundary, with mechanical tests and Bash 3.2 portability already required (`ARCHITECTURE.md:30-50`, `ARCHITECTURE.md:54-109`). |

Canonical preflight agrees with shape's update intent
(`shape.md:191-199`): implementation may update the workflow README for the
operator guard, but this design does not change canonical product or component
boundaries.

## Canonical Problem and Evidence

The acceptance outcome is the first real repository-root run with zero
fixture-derived routing and no helper error (`shape.md:48-53`). The Captain Bet
is preserved verbatim:

> ship-flow helpers 不再有不正確的運作問題，如果處理完仍有問題則表示用 helper 這條路可能策略不對
>
> 修完後第一次真實執行且零錯誤 routing

Current evidence supports the problem but not a technical choice:

- `discover-adopter-skills.sh` sends path, filename, and dependency probes
  through a local `find_pruned`, whose prune list does not exclude test trees
  (`plugins/ship-flow/lib/discover-adopter-skills.sh:46-74`). A live
  `--root=.` run emitted three bogus adopter routes from checked-in fixture
  content (Refine, Expo, and an API vocabulary route).
- `density-classify.sh` recursively scans workflow guidance, all repo-local
  plugin skills, and precedents (`plugins/ship-flow/lib/density-classify.sh:125-165`),
  so a nested decoy can change a boolean density signal even when the current
  fixture corpus does not yet contain that exact decoy.
- Existing discovery tests intentionally set their requested root inside an
  absolute `.../__tests__/fixtures/...` path
  (`plugins/ship-flow/lib/__tests__/test-adopter-skill-discovery.sh:6-9`).
  The contract therefore cannot reject a root because an ancestor outside the
  requested root has a test or fixture name.
- Shape requires one shared surface, names both definite consumers, and keeps
  bounded workflow/entity scanners outside the pollution boundary
  (`shape.md:94-112`, `shape.md:150-163`).

## Design Output

### Contract Decision C1 — shared surface and future non-shell consumption

| Option | Current Bash ergonomics | Future non-shell use | Cost and risk |
| --- | --- | --- | --- |
| **A. Sourceable shell functions only** | Smallest change; both definite consumers source one file. | A future non-shell walker must duplicate rules or add its own bridge. | Lowest initial cost, but does not close the cross-runtime duplication concern. |
| **B. Declarative rule file plus per-runtime loaders** | Bash must parse and translate data into BSD-compatible traversal predicates. | Native consumption from any runtime. | Most portable data shape, but creates loader and parser surface before a second runtime exists. |
| **C. One sourceable and executable shell contract** | Shell consumers source a canonical root-relative exclusion predicate/traversal function. | A non-shell walker invokes the same executable predicate or enumeration boundary rather than copying rules. | One implementation surface and one process boundary; executable modes and exit semantics must be tested. |

**Recommendation: C.** It is the smallest surface that serves today's Bash
consumers and gives a future runtime a no-duplication path. It supports the
Captain Bet better than A because the rule remains single-source when another
walker arrives, and better than B because the first real run does not depend on
new parsing machinery.

**Captain confirmation needed:** choose C1-A, C1-B, or C1-C (recommended).
No `D{N}|Captain decision` marker is emitted until the Captain selects one.

### Contract Decision C2 — root-relative nested test-tree semantics

Invariant shared by every option: normalize the requested root once; decide
exclusion only from descendant paths relative to that root; never inspect root
ancestors; never derive policy from `.gitignore`; preserve BSD/macOS `find`,
quoted paths, `-print -quit`, and existing exit behavior.

| Option | Nested markers pruned | False-negative / false-positive balance | Fixture-root behavior |
| --- | --- | --- | --- |
| **A. Current canonical markers** | Any descendant directory segment named `__tests__` or `test-fixtures`. This covers current `lib/__tests__/fixtures` and `bin/test-fixtures`. | Narrowest proven set; a future `tests/fixtures` convention would need an explicit contract update. It does not suppress ordinary adopter content named `fixtures`. | Safe: markers above the requested root are ignored. |
| **B. Fixture-pair convention family** | Descendant `__tests__/fixtures`, `tests/fixtures`, `test/fixtures`, and `test-fixtures`. | Covers more conventions while retaining a fixture relationship; leaves non-fixture files directly under test directories discoverable. | Safe when matching is root-relative. |
| **C. Generic test/fixture segments** | Any descendant `fixtures`, `__tests__`, `tests`, or `test` segment. | Broadest protection, but can hide legitimate adopter paths such as an app or package named `fixtures` or `test`. | Safe for the root itself, but highest descendant false-negative risk. |

**Recommendation: A.** It is the smallest rule that removes both checked-in
test-tree conventions and preserves ordinary adopter content. This makes the
Captain's first real zero-error run testable without silently changing wider
discovery semantics. Adding a convention later becomes an explicit contract
change with a decoy regression, rather than an accidental blanket exclusion.

**Captain confirmation needed:** choose C2-A (recommended), C2-B, or C2-C.
No `D{N}|Captain decision` marker is emitted until the Captain selects one.

### Contract Decision C3 — mechanical tree-walker inventory and proof

The qualifying boundary is behavioral: a production helper under
`plugins/ship-flow/lib/` or `plugins/ship-flow/bin/` qualifies when, during
normal operation, it recursively inspects repository content from the repo
root or a broad repo-root-derived subtree that can reach nested test-tree
decoys and lets matching content affect discovery/routing classification.
Explicit fixture modes and scanners confined to a workflow/entity root or a
fixed depth are audited but do not consume this discovery exclusion contract.

| Option | Proof | Future drift protection | Cost and risk |
| --- | --- | --- | --- |
| **A. Assert only the two known consumers** | Tests grep/source-check `discover-adopter-skills.sh` and `density-classify.sh`. | None: a new repository walker can land unnoticed. | Smallest test, but AC-2 can regress silently. |
| **B. Candidate scan plus checked-in classification inventory** | A mechanical scan finds recursive primitives in production lib/bin files; every candidate must be classified `repository-discovery` or `bounded/explicit`, with rationale. Every `repository-discovery` row must consume the shared contract; unclassified candidates fail. | Strong: a new primitive changes the candidate set and forces an explicit reviewed classification. | Requires maintaining the primitive detector and inventory, but keeps semantic judgment out of CI after classification is checked in. |
| **C. Require every recursive scanner to consume the exclusion** | A broad grep requires shared-helper use everywhere. | Strong syntactically. | Changes bounded validators and explicit fixture modes that cannot reach pollution during normal operation; violates the shaped scope. |

**Recommendation: B.** It turns W2 into a mechanical completeness gate while
preserving the scope cut. The initial inventory must classify the two definite
consumers as `repository-discovery` and explicitly record bounded scanners such
as workflow lint, fixed-depth entity scanners, and fixture-mode invariant
checks with source-line evidence. This best supports the Bet: the real run is
protected now and a future walker cannot quietly reintroduce the same class of
wrong routing.

**Captain confirmation needed:** choose C3-A, C3-B (recommended), or C3-C.
No `D{N}|Captain decision` marker is emitted until the Captain selects one.

### Mechanical Inventory Boundary (current evidence)

| Surface | Classification | Evidence / required plan treatment |
| --- | --- | --- |
| `plugins/ship-flow/lib/discover-adopter-skills.sh` | `repository-discovery` | Repo-root `find_pruned` drives emitted adopter routes (`:46-74`); must consume the accepted shared contract. |
| `plugins/ship-flow/lib/density-classify.sh` | `repository-discovery` | Repo-root-derived recursive signal scans can alter density (`:125-165`); all S1-S3 traversal paths should use the accepted semantics so the helper has one rule. |
| `plugins/ship-flow/bin/ship-flow-lint.mjs` | `bounded/explicit` | Recursive, but rooted at the selected workflow directory (`:60-83`); cannot reach plugin fixtures in normal operation. |
| `plugins/ship-flow/bin/stale-worktree-cleanup-planner.sh` | `bounded/explicit` | Fixed-depth `index.md` scan inside the passed workflow directory (`:305-314`). |
| `plugins/ship-flow/bin/debrief-boundary-resolver.sh` | `bounded/explicit` | Fixed-depth entity scan inside the workflow directory (`:92-103`). |
| `plugins/ship-flow/lib/query-entity-history.sh` | `bounded/explicit` | Fixed-depth archive entity scan (`:230-233`). |
| `plugins/ship-flow/bin/check-invariants.sh` fixture path | `bounded/explicit` | Explicit fixture mode deliberately scans the supplied fixture workflow root (`:1703-1716`); automatic pruning would break its contract. |

The inventory detector should cover at least shell `find`/recursive grep,
JavaScript recursive directory reads, and Python recursive glob/walk forms.
The checked-in classifications are the human-reviewed boundary; CI only checks
candidate-set completeness and contract consumption mechanically.

### Captain Decisions

No Captain decision markers are present. The two verbatim Bet lines choose the
observable outcome, not C1, C2, or C3. Emitting D-markers now would fabricate
Captain approval. After confirmation, design must add one marker per accepted
choice and at least one typed hand-off constraint with a
`rationale_decision` back-reference for each marker.

### Artifact Bundle Manifest

| Path | Type | Purpose |
| --- | --- | --- |
| `docs/ship-flow/fixture-pollution-discovery-helpers/design.md` | non-UI contract/interface design | Trade-offs, recommendations, readiness evidence, cross-review, and the sole structured hand-off to plan. |

## Reverse Audit of Shape Hand-off

- `open_design_questions`: empty (`shape.md:244-245`).
- `open_contract_decisions`: C1-C3 are each represented by a trade-off table,
  recommendation, and blocking Captain prompt (`shape.md:246-255`).
- Contradiction count is three unresolved contract choices; Captain decision
  count is zero. This intentionally requires `PROMPT_CAPTAIN` rather than a
  fabricated `PROCEED`.
- No UI lane or token-indirection evidence exists; UI fidelity checks are not
  applicable (`shape.md:244-245`).

## Design Readiness Review

```yaml
risk_triggers: []
reviewers: []
derived_from:
  - affects_ui:false
  - single-contract-interface-lane
  - internal-portable-discovery-contract
verdict: PASS
findings:
  - reviewer: routing-preflight
    severity: PASS
    route_to: design
    evidence: "registry validation succeeded; dispatch constrains the schema label to the contract/interface lane"
  - reviewer: scope-preflight
    severity: PASS
    route_to: plan
    evidence: "no data-model, public-interface, multi-domain, or high-risk UI signal"
```

This is a single internal contract lane with no risk-gated review trigger. The
separate Phase 9 adversarial non-UI cross-review remains mandatory.

## Adversarial Cross-Review

Fresh reviewer receipt: read-only review in
`/Users/kent/conductor/workspaces/spacedock-workflows/yangon/.claude/worktrees/fixture-pollution-discovery-helpers`;
only this `design.md` and `shape.md` were read. The first dispatched reviewer
stalled without evidence and was stopped; a new context-free reviewer completed
the gate. No reviewer edited files or mutated state.

| Non-UI factor | Result | Evidence |
| --- | --- | --- |
| Feasibility | PASS | C1-C3 each have options, trade-offs, recommendations, and explicit Captain prompts; no D-marker is fabricated. |
| Executable scope | PASS | All three choices remain blocking in the sole hand-off. |
| Quality | PASS | The single contract lane, canonical context, root-relative semantics, and portable surface are coherent. |
| DC adequacy | PASS | Zero D-markers and zero references is correct until Captain selection. |
| Canonical sync | PASS | Canonical sections and skip intent are cited and agree with shape. |
| Reverse-audit previous stage | PASS | Both Bet lines are verbatim; all three hand-off choices are represented. |
| Constraint Coverage | PASS | No decision is accepted, so accepted-decision coverage is vacuous; `open_decisions` carries C1-C3. |

Findings: no design blocker beyond the three unresolved Captain choices. The
D-reference warning is expected and consistent with the no-fabrication
contract.

Exact validator receipt:

```text
$ bash plugins/ship-flow/lib/check-design-readiness-review.sh docs/ship-flow/fixture-pollution-discovery-helpers/design.md
exit=0
status=skipped reason=no-risk-trigger
risk_triggers=
required_reviewers=

$ bash plugins/ship-flow/lib/validate-handoff-schema.sh docs/ship-flow/fixture-pollution-discovery-helpers/design.md
exit=0
OK handoff-schema: docs/ship-flow/fixture-pollution-discovery-helpers/design.md structured fields valid

$ bash plugins/ship-flow/lib/validate-d-references.sh docs/ship-flow/fixture-pollution-discovery-helpers/design.md
exit=0
WARN: no '**D{N}|Captain decision**' markers found in docs/ship-flow/fixture-pollution-discovery-helpers/design.md — design may be incomplete
OK D-reference validation: 0 markers, 0 references, all resolved
```

Verdict: **PROMPT_CAPTAIN**.

Coaching note: ask the Captain to select C1, C2, and C3 explicitly, then add
the corresponding D-markers and typed constraints before plan advancement.

## Design Report

- status: blocked
- stage_cost: $0.00 (single Codex design worker + one fresh read-only cross-review)
- iterations: 1 fallback brainstorming pass + 1 cross-review
- contradictions_resolved: 0
- captain_decisions: 0
- reviewer_verdict: PROMPT_CAPTAIN
- Design Readiness Review: skipped - no risk trigger

The installed `design-flow` delegate was unavailable, so the design used the
documented `superpowers:brainstorming` fallback. All three recommendations are
YAGNI-biased and tied to the Captain Bet, but none is accepted without Captain
confirmation.

### Metrics

- status: blocked
- duration_minutes: 35
- iteration_count: 2
- captain_decisions_count: 0
- reviewer_verdict: PROMPT_CAPTAIN

<!-- section:hand-off-to-plan -->
### Hand-off to Plan

```yaml
design-skipped: false
open_decisions:
  - id: C1
    question: Select the shared exclusion surface and future non-shell consumption boundary.
    options: [sourceable-shell-only, declarative-rules-with-loaders, sourceable-and-executable-shell-contract]
    recommendation: sourceable-and-executable-shell-contract
    blocker: Captain selection required before any rationale_decision back-reference can exist.
  - id: C2
    question: Select the root-relative nested test-tree marker vocabulary.
    options: [current-canonical-markers, fixture-pair-convention-family, generic-test-fixture-segments]
    recommendation: current-canonical-markers
    blocker: Captain selection required before exact excluded segments become plan constraints.
  - id: C3
    question: Select the mechanical repository-tree-walker inventory proof.
    options: [known-consumers-only, candidate-scan-with-classification-inventory, all-recursive-scanners]
    recommendation: candidate-scan-with-classification-inventory
    blocker: Captain selection required before the inventory gate becomes a plan constraint.
artifact_paths:
  - path: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
```
<!-- /section:hand-off-to-plan -->

## Stage Report: design

- DONE: Emitted one non-UI contract/interface dispatch manifest; the registry
  envelope is recorded as context without creating data-model work.
- DONE: Preserved both Captain Bet lines verbatim and tied one recommendation
  to each of the three shaped contract choices.
- DONE: Audited the two qualifying consumers and recorded the bounded-scanner
  exclusions needed by the recommended mechanical inventory.
- DONE: Emitted Canonical Context, Design Readiness Review evidence, reverse
  audit, artifact manifest, and the single structured Hand-off to Plan.
- BLOCKED: Captain has not selected C1, C2, or C3. No D-markers or typed
  constraints were fabricated; `open_decisions` remains non-empty.
- REVIEW: Fresh adversarial non-UI cross-review passed all seven factors and
  returned `PROMPT_CAPTAIN`; all three applicable validators exited 0, with the
  expected zero-marker warning from D-reference validation.
- status: blocked
- reviewer_verdict: PROMPT_CAPTAIN

### Summary

Designed the smallest enforceable fixture-tree exclusion contract, recommended
a dual-use shell surface, narrow root-relative current markers, and a
candidate-scan inventory gate, while correctly blocking plan until the Captain
confirms all three choices.
