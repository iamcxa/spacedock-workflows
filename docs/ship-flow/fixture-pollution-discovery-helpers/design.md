# Fixture-tree exclusion for discovery helpers — Design

This is a non-UI contract/interface design revision. The Captain explicitly
delegated C1-C3 engineering judgment to the Science Officer (EM); the EM routed
the work `narrow` with high confidence. D1-D3 below record those delegated
decisions, so no Captain product or risk decision remains and plan may proceed.

```yaml
design-dispatch-manifest:
  lanes:
    - lane: contract-interface
      role: contract/interface-designer
      trigger: delegated_open_contract_decisions
      decisions: [D1, D2, D3]
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
    applied_route: contract-interface-only
    rationale: No data-model surface changes; this is a Bash discovery contract.
  visual_verification:
    status: not-applicable-non-ui
```

## Canonical Context

| Doc | Sections Read | Update Intent | Skip Rationale |
| --- | --- | --- | --- |
| `PRODUCT.md` | `Current Capabilities` | skip | This repairs an existing internal capability; it adds no durable product promise (`PRODUCT.md:7-18`). |
| `ARCHITECTURE.md` | `containers`, `components`, `constraints`, `dependencies` | skip | A sourceable Bash primitive remains in the existing `lib/` boundary and preserves Bash 3.2 portability (`ARCHITECTURE.md:30-50`, `ARCHITECTURE.md:54-109`). |

The implementation-stage documentation delta is intentionally limited to
`docs/ship-flow/README.md`: add the explicit `--workflow-dir docs/ship-flow`
guard and link local tracker `#24`. No canonical product or component boundary
changes.

## Canonical Problem and Delegation

The acceptance outcome remains the first real repository-root run with zero
fixture-derived routing and no helper error (`shape.md:48-53`). The Captain's
Bet is preserved verbatim:

> ship-flow helpers 不再有不正確的運作問題，如果處理完仍有問題則表示用 helper 這條路可能策略不對
>
> 修完後第一次真實執行且零錯誤 routing

The Science Officer reviewed the prior C1-C3 trade-offs under the Captain's
explicit delegation and selected the narrow route: sourceable Bash only,
requested-root-relative marker pruning, and a one-time complete audit plus
small invariants. Executable/non-shell modes and a permanent recursive-walker
classification framework are deferred until an actual consumer makes either
necessary.

## Current Repository-wide Candidate Audit

Audit baseline: branch head `f55b154` before this design-only revision. The
one-time audit searched production `plugins/ship-flow/lib/` and
`plugins/ship-flow/bin/` sources (excluding tests and methodology prose) for
shell `find`/recursive grep/`rg --files`/`git ls-files`, JavaScript directory
reads and recursive walkers, and Python `glob`/`walk` forms. Every hit was read
to classify its actual normal-operation reach; this record is the deliverable,
not a checked-in detector or classification framework.

| Surface | Actual reach | Decision |
| --- | --- | --- |
| `lib/discover-adopter-skills.sh:46-74` | Recursively inspects the requested repository root and lets nested content emit routing. | Qualifying consumer; source the shared helper. |
| `lib/density-classify.sh:125-165` | Recursively inspects workflow guidance, repo-local plugin skills, and precedent trees; nested decoys can alter S1-S3. | Qualifying consumer; all four `find` traversals source/use the shared helper. |
| `lib/issues-to-contract.sh:79-96` | Python globbing is fixed to active entities and `_archive` at depth zero/one beneath the requested workflow directory. | Bounded dedup scan; does not consume the helper. |
| `bin/sync-drift-check.mjs:25-44,346,389` | `readdir` lists immediate files only in exact plugin/adopter `_mods` and script directories; it never descends. | Shallow manifest comparison; does not consume the helper. |
| `bin/ship-flow-lint.mjs:67-83` | Recurses only inside the explicitly selected workflow directory to lint Markdown. | Bounded validator; does not consume the helper. |
| `bin/stale-worktree-cleanup-planner.sh:303-314` | Finds `index.md` at exact depth two inside the selected workflow directory. | Bounded entity scan; does not consume the helper. |
| `bin/debrief-boundary-resolver.sh:88-103` | Finds `index.md` at exact depth two inside the selected workflow directory. | Bounded entity matcher; does not consume the helper. |
| `lib/query-entity-history.sh:230-233` | Finds archived `index.md` at exact depth two in the selected archive directory. | Bounded history query; does not consume the helper. |
| `bin/check-invariants.sh:108-129,290-304,1703-1716` | Recursively validates the plugin's skill sources; fixture mode deliberately scans the supplied fixture workflow root. | Invariant/explicit-fixture behavior; pruning would change its contract. |
| `bin/ship-capture.sh:9-11` | `grep -r` receives shell-expanded `docs/*/README.md` file arguments, not a repository directory. | Syntactic false positive; no recursive repository reach. |
| `lib/rebase-resolve-additive.sh:48` | `git ls-files -u` reads unmerged index entries only. | Syntactic false positive; no filesystem discovery. |

Conclusion: the complete current qualifying set is exactly
`discover-adopter-skills.sh` and `density-classify.sh`. The two candidates the
prior cycle omitted, `issues-to-contract.sh` and `sync-drift-check.mjs`, are now
explicitly classified with source evidence.

## Design Output

### Captain Decisions

**D1|Captain decision**: Under the Captain's explicit delegation to the Science
Officer, choose C1-A: add one namespaced, sourceable Bash-only helper at
`plugins/ship-flow/lib/discovery-exclusions.sh`. It exposes a
`ship_flow_discovery_find <requested-root> <find-expression...>` contract; both
known Bash consumers source it. Do not add executable, config-loader, or
non-shell consumption modes until a real consumer exists.

**D2|Captain decision**: Under the same delegation, choose C2-A: prune only
descendant directory segments named `__tests__` or `test-fixtures`, evaluated
relative to the requested root. The requested root is never rejected because
its own name or any ancestor contains a marker. Do not generically exclude
`fixtures`, `test`, or `tests`, and do not derive policy from `.gitignore`.

**D3|Captain decision**: Under the same delegation, choose constrained C3-A:
record this complete current audit, directly assert that both known consumers
source the helper, and add one simple invariant that exclusion-marker
definitions (`-name __tests__` / `-name test-fixtures`, or their constant
equivalent) occur only in the helper. Do not build a permanent multi-language
recursive-primitive detector or checked-in classification inventory.

### Helper Boundary

The helper owns only the shared fixture-tree semantics. Each consumer retains
its distinct search target, output, and existing non-fixture pruning. The
function must be Bash 3.2-compatible, quote paths safely, preserve normal
`find` predicate arguments, and use a root-relative traversal boundary such as
`-mindepth 1` so a legitimate root located beneath
`lib/__tests__/fixtures/**` remains discoverable.

### Verification Strategy

Implementation begins with focused RED/GREEN regressions, not the real
repository-root run:

1. Extend `test-adopter-skill-discovery.sh` with twin clean/decoy roots. A
   nested `__tests__` or `test-fixtures` subtree contains route-shaped files;
   before the fix the full YAML differs (RED), after the fix stdout is
   byte-identical to the clean twin (GREEN). Both runs must exit 0 with empty
   stderr.
2. Extend `test-density-classify.sh` with a nested fixture decoy that changes a
   density signal before the fix (RED) but leaves the clean twin's intended
   classification unchanged after the fix (GREEN). Both runs must exit 0 with
   empty stderr.
3. Preserve positive fixture-root behavior. Run discovery from the existing
   `lib/__tests__/fixtures/adopter-skill-discovery/carlove-like` root and add an
   equivalent density fixture whose requested root or ancestor contains a
   marker; legitimate signals below that root still produce the existing
   output.
4. Add direct source assertions for both consumers and the single-definition
   invariant. These are intentionally simple grep/source checks, not an
   extensible walker detector.
5. Verify `docs/ship-flow/README.md` contains the explicit
   `--workflow-dir docs/ship-flow` guard and local tracker `#24`.

Only after all focused checks are GREEN, execute
`plugins/ship-flow/lib/discover-adopter-skills.sh --root=.` exactly once as the
post-fix acceptance run. Capture exit status, stdout, and stderr; require exit
0, empty stderr, and zero fixture-derived routes. Any unexpected route,
non-empty stderr, or nonzero exit stops implementation and returns the helper
strategy to design review; it is not permission for another patch iteration.

### Artifact Bundle Manifest

| Path | Type | Purpose |
| --- | --- | --- |
| `docs/ship-flow/fixture-pollution-discovery-helpers/design.md` | non-UI contract design | Delegated D1-D3 decisions, complete audit, verification contract, and structured plan hand-off. |

## Reverse Audit of Shape Hand-off

- `open_design_questions`: empty (`shape.md:244-245`).
- C1 is resolved by D1 as sourceable Bash-only, explicitly deferring speculative
  executable/non-shell modes.
- C2 is resolved by D2 with exact root-relative descendant markers and explicit
  non-markers.
- C3 is resolved by D3 with one complete audit and two small invariants, without
  a permanent classification framework.
- No UI lane or token-indirection evidence exists; UI fidelity checks are not
  applicable.

## Design Readiness Review

```yaml
risk_triggers: []
reviewers: []
derived_from:
  - affects_ui:false
  - single-contract-interface-lane
  - internal-bash-discovery-contract
verdict: PASS
findings:
  - reviewer: routing-preflight
    severity: PASS
    route_to: plan
    evidence: D1-D3 narrow the internal contract without data-model, external interface, or multi-domain work.
```

Design Readiness Review: skipped - no risk trigger. The separate fresh
seven-factor non-UI cross-review remains mandatory.

## Adversarial Cross-Review

The first fresh reviewer stalled without evidence and was interrupted. A
replacement reviewer received only `design.md` and `shape.md`, performed a
context-free read-only review, edited no files, and returned:

| Non-UI factor | Result | Evidence |
| --- | --- | --- |
| Feasibility | PASS | The Bash 3.2 helper boundary, quoting, and root-relative `-mindepth 1` semantics are implementable (`design.md:114-121`). |
| Executable scope | PASS | Consumers, focused tests, documentation delta, and one-shot acceptance command are explicit (`design.md:128-153`). |
| Quality | PASS | RED/GREEN behavior covers stdout, stderr, exit status, positive fixture-root behavior, and the stop rule (`design.md:128-153`). |
| DC adequacy | PASS | Seven typed constraints carry decision and source back-references; `open_decisions` is empty (Hand-off to Plan). |
| Canonical sync | PASS | Shape and design consistently skip PRODUCT/ARCHITECTURE changes and require only the workflow README guard (`shape.md:191-199`; `design.md:32-42`). |
| Reverse-audit previous stage | PASS | D1-D3 directly resolve shape C1-C3, including explicit deferrals (`shape.md:246-255`; `design.md:94-112,161-169`). |
| Constraint Coverage | PASS | The complete audit classifies `issues-to-contract.sh` and `sync-drift-check.mjs`; every D marker is referenced and no decision remains open (`design.md:71-88`; Hand-off to Plan). |

Verdict: **PROCEED**.

Coaching note: keep plan mechanically faithful to the seven typed constraints,
especially the root-relative positive-fixture case and one-shot repository-root
acceptance gate.

## Design Report

- status: passed
- stage_cost: $0.00 (single Codex design worker + fresh read-only reviewer)
- iterations: 2 (initial prompt cycle + delegated narrow revision)
- contradictions_resolved: 3
- captain_decisions: 3 delegated through the Science Officer
- reviewer_verdict: PROCEED
- Design Readiness Review: skipped - no risk trigger

The installed `design-flow` delegate was unavailable, so the design used the
documented `superpowers:brainstorming` fallback. The EM decision changed the
prior recommendations materially: D1 rejects speculative executable support,
and D3 replaces a permanent inventory framework with one complete audit plus
small source invariants.

### Metrics

- status: passed
- duration_minutes: 25
- iteration_count: 2
- captain_decisions_count: 3
- reviewer_verdict: PROCEED

<!-- section:hand-off-to-plan -->
### Hand-off to Plan

```yaml
design-skipped: false
design_constraints:
  - type: contract
    assertion: Create exactly one Bash 3.2-compatible namespaced sourceable helper at plugins/ship-flow/lib/discovery-exclusions.sh; do not add executable, declarative-loader, or non-shell modes.
    rationale_decision: D1
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: filter-contract
    assertion: Prune only descendant directory segments named __tests__ or test-fixtures relative to the requested root; never reject the root because of its own name or ancestors, and do not exclude fixtures, test, or tests generically.
    rationale_decision: D2
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: contract
    assertion: Both discover-adopter-skills.sh and all four density-classify.sh find traversals source and use the shared helper while retaining their consumer-specific non-fixture behavior.
    rationale_decision: D3
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: contract
    assertion: Add simple source invariants that both known consumers source the helper and exclusion-marker definitions exist only in that helper; do not add a permanent recursive-walker detector or classification inventory.
    rationale_decision: D3
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: filter-contract
    assertion: Focused RED/GREEN twin-root tests cover nested fixture decoys for both consumers, preserve positive fixture-root discovery, keep intended stdout unchanged, and assert exit 0 plus empty stderr.
    rationale_decision: D2
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: contract
    assertion: Update docs/ship-flow/README.md with the explicit --workflow-dir docs/ship-flow guard and local tracker #24.
    rationale_decision: D3
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: contract
    assertion: Reserve discover-adopter-skills.sh --root=. for one post-fix acceptance execution after focused tests; unexpected routing, stderr, or nonzero exit stops work and returns to strategy review rather than triggering another patch.
    rationale_decision: D3
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
open_decisions: []
artifact_paths:
  - path: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
```
<!-- /section:hand-off-to-plan -->

## Stage Report: design (cycle 2)

- DONE: Record the Science Officer route=narrow decisions as D1-D3 under the Captain's explicit delegation: sourceable Bash-only shared helper; requested-root-relative descendant __tests__/test-fixtures pruning; one-time complete walker audit plus simple single-definition/consumer invariant, without a permanent cross-language inventory framework.
  D1-D3 and the complete audit above provide the decision and source evidence.
- DONE: Replace PROMPT_CAPTAIN with a complete non-UI Hand-off to Plan: typed design_constraints for every D marker, open_decisions: [], focused RED/GREEN and first-real-run verification constraints, updated Design Report and Stage Report. Re-audit current recursive candidates including issues-to-contract.sh and sync-drift-check.mjs before any completeness claim.
  The structured hand-off has seven typed constraints; the audit classifies both required candidates.
- DONE: Run applicable design validators and a fresh context-free read-only seven-factor review. Commit only design-stage artifacts; do not implement code, mutate entity status, advance stages, file upstream issues, or manage worktrees.
  Readiness skipped correctly; hand-off and D-reference validation passed; the fresh reviewer returned seven-factor PROCEED.

### Summary

Converted the blocked design into an FO-gated narrow contract under explicit
delegation, completed the missing candidate audit, and supplied focused
RED/GREEN plus one-shot acceptance constraints. No Captain input remains.
