# Make debrief a native post-merge ship closeout — Design

```yaml
design-dispatch-manifest:
  lanes:
    - lane: domain
      role: domain-designer
      domain: schema
      panel_lane: domain-expert
      required_skills: []
      knowledge_module_path: plugins/ship-flow/references/domain-knowledge/schema.md
      designer_section_anchor: ship-design#schema-designer
      review_contract:
        worktree: /Users/kent/conductor/workspaces/spacedock-workflows/riga/.worktrees/spacedock-ensign-ship-stage-debrief-closeout
        base_head: main..spacedock-ensign/ship-stage-debrief-closeout
        mode: read-only findings-only
      outputs:
        - Schema Design Output
        - schema-domain design constraints
    - lane: contract-interface
      role: contract/interface-designer
      trigger: open_contract_decisions
      decisions:
        - landing-envelope proof grammar
        - closeout identity and ownership
        - resumable transaction boundary
        - recursion sentinel
        - merge-method ambiguity
      outputs:
        - captain_decisions
        - design_constraints
        - open_decisions
  integration:
    mode: parallel
    owner: ship-design
  visual_verification:
    fragment_level: []
    whole_page: []
```

## Design Output

### Captain Decisions

- **D1|Captain decision**: Treat the provider `mergedAt` and post-merge anchor as inputs to a versioned landing-envelope proof, never as sufficient evidence alone. Classify only when topology, PR commit count, ordered patch identities, aggregate patch equivalence, and the full 40-character anchor agree; persist `base_before` plus the ordered landing set and fail closed on any ambiguity. (ref: `shape.md:333-335`; the current reconciler fetches `mergedAt` but not an anchor at `plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh:159-175`.)
- **D2|Captain decision**: Key closeout by repository + workflow + one owning entity + implementation PR. A shared PR must declare exactly one owner and may list child participants; the owner emits one debrief/receipt for the unit. Session aggregation and indirect landing are not eligible identities. (ref: `shape.md:336-338`.)
- **D3|Captain decision**: Use a versioned repo-owned receipt at `docs/ship-flow/_closeouts/<closeout_id>.json` as the monotonic write-ahead identity/proof journal, and make the terminal projection set one atomic Git transition. Direct mode commits debrief, final `ship.md`, terminal entity/archive move, ROADMAP move, and applied receipt together; optional-PR mode persists `awaiting_closeout_pr`, creates/reuses one deterministic-head PR, and makes its terminal projection authoritative only on merge. (ref: `shape.md:339-341`; the current sequential set/archive/verify/remove flow is visible at `plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh:441-451`.)
- **D4|Captain decision**: Use that stable `_closeouts/<closeout_id>.json` receipt as the recursion sentinel rather than moving it with the entity. Bind path-derived identity, implementation PR, deterministic closeout head, artifact manifest, and canonical payload hash; a merged PR is closeout-only only when exactly one landed receipt validates all bindings from landed bytes. (ref: `shape.md:342-343` and the rejected prose classifier at `shape.md:269-270`.)
- **D5|Captain decision**: Infer the actual landing method from topology and ordered/aggregate patch proof, while persisting `merge_method_intent` before merge as a discriminator rather than provider fact. Intent may choose only a matching proof-valid candidate; absent intent with multiple candidates stops as `landing-method-ambiguous`, and conflicting intent stops as `landing-method-intent-mismatch`. (ref: `shape.md:344-346`.)

### Trade-off Record

| Decision | Options considered | Selected trade-off | Stable stop instead of silent choice |
| --- | --- | --- | --- |
| D1 landing proof | PR head/current main; time-window scan; anchor + exact proof grammar | Exact proof grammar costs more fixture data but survives rebases and concurrent main movement. | `landing-anchor-missing`, `landing-topology-unsupported`, `landing-pr-commit-count-mismatch`, `landing-patch-equivalence-failed` |
| D2 identity | Session debrief; one debrief per matching entity; one owner per PR closeout unit | Explicit owner keeps shared parent/child work auditable without duplicate debriefs. | `closeout-owner-not-unique`, `closeout-indirect-landing-unowned` |
| D3 transaction | Best-effort ordered writes; per-file checkpoints; atomic terminal bundle + proof-based external checkpoints | The bundle removes incoherent intermediate repository states; only PR creation needs an external idempotency proof. | `closeout-stage-artifact-incoherent`, `closeout-checkpoint-conflict`, `closeout-roadmap-conflict`, `archived-terminal-incoherent` |
| D4 sentinel | Title/body convention; entity-local marker; stable repo-owned receipt | The `_closeouts/` receipt survives archive moves, is discoverable in the landed diff, and binds every final artifact hash. | `closeout-sentinel-missing`, `closeout-sentinel-multiple`, `closeout-sentinel-invalid`, `closeout-sentinel-payload-mismatch` |
| D5 merge method | Trust UI choice; infer heuristically; proof-valid candidates plus persisted intent discriminator | Intent resolves only proof-valid ties and is never mislabeled as provider fact; absent/conflicting evidence is visible. | `landing-method-ambiguous`, `landing-method-intent-mismatch` |

### Artifact Bundle Manifest

| Path | Type | Purpose |
| --- | --- | --- |
| `docs/ship-flow/ship-stage-debrief-closeout/design.md` | Schema/domain design artifact | Decision anchors, typed closeout contract, readiness/review evidence, and plan handoff. |

### Canonical Context

| Doc | Sections Read | Update Intent | Skip Rationale |
| --- | --- | --- | --- |
| `PRODUCT.md` | `## Current Capabilities` / `capabilities` | Ship-review should add native post-merge debrief and terminal closeout as a pipeline capability. | n/a — shape already declares product impact. |
| `ARCHITECTURE.md` | `containers`, `components`, `constraints`, `decisions` | Ship-review should add the closeout boundary, landing proof, and atomic terminal bundle to components while preserving seven stage skills and hermetic mechanics. | n/a — shape already declares architecture impact. |

## Schema Design Output

### Layers touched

- L1 decider: the file-backed closeout command becomes authoritative for entity/PR ownership, landing proof, and the terminal Git bundle; no database table is added.
- L2 fstore: none. `ROADMAP.md` is a canonical map in the same terminal Git bundle, not a rebuildable projection.
- L3 view: additive CLI key/value output and additive `ship.md`, debrief, and `_closeouts/<closeout_id>.json` fields expose the receipt and stable reason code.

### Migration safety

- Additive / destructive: additive schema and receipt fields only; no destructive database or legacy debrief rewrite.
- Backfill required: no corpus backfill. Legacy `ship` entities without a closeout intent may use proof-derived defaults only when ownership and landing classification are unique; otherwise they stop.
- Event-saga implication: no fmodel event saga. The equivalent workflow saga is the closeout state machine below, with Git commit/merged-PR proofs as durable boundaries.

### RBAC and tenancy

- tenant_id / ownership columns: not applicable to repository files; ownership is repository/workflow/entity/PR identity.
- RBAC subject: the current repository actor remains the authorization boundary; the design adds no privilege or task-manager integration.

### Projection / fstore rebuild

- Rebuild strategy: none. Recovery re-derives candidates from provider facts and validates the persisted receipt/manifest; it never rebuilds terminal state from an unbounded history scan.
- Stale-read tolerance: zero for terminalization. Entity, archive, debrief, ship receipt, sentinel, and ROADMAP must agree at one authoritative commit.

### Hand-off constraints for Plan

- Required plan DCs: cover all three landing strategies with concurrent main movement, exact reason codes, one owner, atomic terminal bundle, sentinel validation, optional-PR awaiting semantics, and crash/no-op re-entry after every durable boundary.
- Verify-time intent checks: compare implemented envelope and receipt fields, state transitions, reason codes, artifact hashes, and terminal coherence against D1-D5; run the frozen PR #40/#41 value fixture twice.

## Contract Schemas

### Landing envelope

```yaml
landing_envelope:
  schema_version: 1
  repository: owner/name
  base_ref: main
  implementation_pr: 40
  provider_merged_at: RFC3339
  landing_anchor: 40-hex
  base_before: 40-hex
  strategy: rebase|squash|merge_commit
  strategy_evidence: topology+ordered-patch-ids+aggregate-patch-digest
  pr_commit_count: 29
  source_commit_patch_ids: [ordered]
  source_patch_digest: sha256
  landing_commits: [ordered-40-hex]
  landing_commit_patch_ids: [ordered]
  landing_patch_digest: sha256
  first_landing_commit: 40-hex
  last_landing_commit: 40-hex
```

Proof grammar is deterministic:

- Common: `mergedAt` is present; anchor/base/set are full SHAs; anchor is reachable from the named base; aggregate source and landing digests match; current main tip and original PR head are never substituted.
- Merge commit: anchor has exactly two parents; first parent is `base_before`; topic-only commits are the ordered second-parent range and the anchor is appended to `landing_commits`.
- Squash: anchor has one parent, `base_before=anchor^`, `landing_commits=[anchor]`, and the anchor patch matches the PR aggregate while the ordered source-commit candidate does not also validate.
- Rebase: anchor has one parent; walking exactly `pr_commit_count` first-parent commits yields the ordered set; ordered patch IDs match source commits and the aggregate range digest matches.
- Zero valid candidates fail closed. When multiple candidates validate, a persisted pre-merge `merge_method_intent` may select only its matching valid candidate; absent intent is ambiguous and conflicting intent is a mismatch. The receipt records `method_source: topology|intent-discriminator`, never falsely `provider`.

### Closeout identity, journal, and terminal bundle

```yaml
closeout_record:
  schema_version: 1
  kind: ship-flow.closeout
  closeout_id: sha256("v1\\0github\\0<repository>\\0<workflow>\\0<entity_slug>\\0<implementation_pr>")
  identity:
    provider: github
    repository: owner/name
    workflow: docs/ship-flow
    entity_slug: ship-stage-debrief-closeout
    implementation_pr: 40
  ownership_proof:
    unique_entity_matches: 1
    participant_entities: []
    source_hashes: {index: sha256, review: sha256, ship: sha256}
  mode: direct|pull_request
  merge_method_intent: rebase|squash|merge_commit|null
  deterministic_closeout_head: ship-closeout/<closeout_id>
  landing_proof: {}
  transaction:
    phase: prepared|awaiting_closeout_pr|applied|complete
    generation: 1
    closeout_pr: null|positive-integer
    main_commit: null|40-hex
  outputs:
    debrief: {path: string, sha256: sha256}
    ship: {path: string, sha256: sha256}
    archived_entity: {path: string, sha256: sha256}
    roadmap_row: {identity: string, sha256: sha256}
  proof_hash: sha256(canonical-json(identity+ownership+landing+outputs))
```

The receipt lives at `docs/ship-flow/_closeouts/<closeout_id>.json`; the ID excludes the currently empty entity `id`, mutable archive path, session, title, and body. Preparation validates the unique owner plus source hashes for `index.md`, `review.md`, and finalized `ship.md`, renders outside canonical paths, validates debrief schema/content, todo digest, C15 accounting, archive fields, and ROADMAP CAS, then hashes the exact terminal set. Direct mode applies receipt and projections in one Git commit. PR mode persists `awaiting_closeout_pr` before the external create/reuse step, uses the deterministic head, and remains non-terminal until that PR is MERGED; the merged sentinel bundle is terminal and requires no follow-up mutation.

The generated debrief remains schema-v1-compatible, uses provider merge date, derives abbreviated first/last fields from the envelope, preserves all required sections, and adds identity/receipt fields without replacing full reconciliation or todo digest. Full SHAs live in the `_closeouts/<closeout_id>.json` receipt and compact ship receipt. Existing balanced standalone `<details>` body-count semantics and the `ship.md` 60-line cap remain unchanged (`plugins/ship-flow/skills/ship/SKILL.md:262-274`; `docs/ship-flow/_debriefs/2026-07-15-01.md:26-44`).

### Recovery and stable reason vocabulary

| Observed state | Result |
| --- | --- |
| PR OPEN | no-op `pr-open`; preserve any pre-merge intent without creating a closeout receipt. |
| MERGED but missing provider time/anchor or invalid proof | stop with landing reason; write no terminal files. |
| Missing `review.md`, final `ship.md`, or registered stage link | `closeout-review-missing`, `closeout-ship-missing`, or `closeout-stage-artifacts-incoherent`; do not terminalize. |
| Existing debrief/ROADMAP/archive matches identity and receipt | treat that projection as already applied and continue/no-op. |
| Existing projection has same identity but different hash/source | `closeout-proof-hash-mismatch` or `closeout-projection-source-drift`; do not overwrite. |
| Direct terminal Git commit exists | `already-reconciled`; cleanup may retry independently. |
| Optional closeout PR is OPEN | `closeout-pr-awaiting-merge`; do not claim done/PASSED on authoritative main. |
| Optional closeout PR is MERGED and sentinel validates | Classify the sentinel before ordinary owner resolution, emit `closeout-pr-terminal-noop`, and never create another closeout. |
| Sentinel absent/invalid on a purported closeout PR | treat as ordinary implementation PR only if a unique owner exists; otherwise stop with sentinel/owner reason. |

Stable new reasons are: `landing-anchor-missing`, `landing-anchor-unreachable`, `landing-topology-unsupported`, `landing-pr-commit-count-mismatch`, `landing-patch-equivalence-failed`, `landing-patch-equivalence-ambiguous`, `landing-method-ambiguous`, `landing-method-intent-mismatch`, `closeout-owner-not-unique`, `closeout-indirect-landing-unowned`, `closeout-review-missing`, `closeout-ship-missing`, `closeout-stage-artifacts-incoherent`, `closeout-checkpoint-conflict`, `closeout-proof-hash-mismatch`, `closeout-projection-source-drift`, `closeout-roadmap-conflict`, `closeout-main-not-authoritative`, `closeout-sentinel-missing`, `closeout-sentinel-multiple`, `closeout-sentinel-invalid`, `closeout-sentinel-identity-mismatch`, `closeout-sentinel-payload-mismatch`, and `closeout-pr-awaiting-merge`. Existing reasons such as `missing-pr`, `pr-number-mismatch`, `merged-at-missing`, `archived-terminal-incoherent`, `dirty-worktree`, and `branch-mismatch` remain stable compatibility members (`plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh:370-455`).

## Domain Risk Questions for Plan and Verify

- Can any topology candidate accept a later unrelated main commit, original PR head, or reordered patch list?
- Can two entities sharing one PR both claim owner, or can an indirect landing terminalize without explicit policy?
- Can any crash expose done/PASSED without the matching debrief, ship receipt, archive, and ROADMAP row at the same authoritative commit?
- Can a closeout PR be classified from title/body or from an unbound sentinel whose artifact hashes do not match?
- Can reruns allocate a second debrief path, create another PR, or change receipt hash after a durable proof already exists?

## Design Readiness Review

```yaml
risk_triggers:
  - migration
  - fmodel
  - recent-debrief
reviewers: schema,fmodel
derived_from:
  - domain:schema
  - additive closeout receipt schema and terminal workflow saga
  - docs/ship-flow/_debriefs/2026-07-15-01.md:44-62
verdict: PASS
findings:
  - reviewer: schema
    severity: PASS
    route_to: plan
    evidence: "D1-D5 each define a typed identity/proof/state contract and at least one machine-checkable handoff constraint."
  - reviewer: fmodel
    severity: PASS
    route_to: plan
    evidence: "The workflow saga has explicit durable boundaries; terminal repository state is one atomic bundle and optional PR state is visibly awaiting-merge."
```

The recent debrief warning is absorbed: stage-artifact registration, entity terminal fields, archive location, and ROADMAP state are a single coherence predicate, so a `status: ship` entity without `review.md` cannot terminalize (`docs/ship-flow/_debriefs/2026-07-15-01.md:44-62`).

## Cross-Review Gate

| Factor | Result | Evidence |
| --- | --- | --- |
| Feasibility | PASS | D1-D5 resolve the five `shape.md:333-346` contract decisions with implementable proof, identity, transaction, sentinel, and method contracts. |
| Executable scope | PASS | The typed schemas, recovery matrix, risk questions, and 12 imported constraints bound plan/verify work without adding a stage or provider framework. |
| Quality | PASS | Stable reason names now match exactly across the trade-off table, recovery vocabulary, and handoff after one VETO correction. |
| DC adequacy | PASS | Every D1-D5 marker has at least one typed `design_constraints[]` backref; the importer preserves all 12 rows. |
| Canonical sync | PASS | `PRODUCT.md` capabilities and `ARCHITECTURE.md` components/constraints update intents are explicit in Canonical Context. |
| Reverse-audit previous stage | PASS | The reviewer mapped landing proof→D1, identity→D2, transaction→D3, sentinel→D4, and merge method→D5; `open_design_questions` was empty. |
| Constraint Coverage | PASS | Every decision has a constraint, `open_decisions: []`, and the handoff validator plus D-reference validator pass. |

Verdict: **PROCEED** after one VETO loop corrected `landing-count-mismatch` / `landing-patch-mismatch` to canonical `landing-pr-commit-count-mismatch` / `landing-patch-equivalence-failed`.

Coaching note: Principle 6 Rule C caught unstable reason-code names before plan could encode contradictory fixtures and runtime behavior.

## Design Report

- status: passed
- stage_cost: $0.00 (3 dispatches: schema designer, stalled fresh reviewer, circuit-breaker reviewer)
- iterations: 1 contradiction-resolution integration + 2 cross-review passes
- contradictions_resolved: 5
- captain_decisions: 5
- reviewer_verdict: PROCEED
- lane: non-UI schema + contract-interface; FO-gated PROCEED with no captain prompt
- design-flow: unavailable; `superpowers:brainstorming` fallback used for trade-off resolution
- readiness: PASS; `check-design-readiness-review.sh` derived schema+fmodel reviewers and returned `status=pass`
- verification: existing reconciler 82/82; readiness checker tests 10/10; contract-design gate 19/19; handoff schema valid; 5/5 D refs valid; 12/12 constraints imported; `git diff --check` clean

### Metrics

- status: passed
- duration_minutes: 45
- iteration_count: 3
- captain_decisions_count: 5
- reviewer_verdict: PROCEED

<!-- section:hand-off-to-plan -->
### Hand-off to Plan

```yaml
design-skipped: false
design_constraints:
  - type: schema-contract
    assertion: "landing envelope requires provider_merged_at, landing_anchor, base_before, strategy, pr_commit_count, ordered landing_commits, first/last landing commits, and source/landing patch proof"
    rationale_decision: D1
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
  - type: contract
    assertion: "rebase, squash, and merge_commit candidates pass only their exact topology/count/ordered-patch/aggregate-patch grammar; zero candidates or unresolved multi-candidate proof returns a stable landing reason"
    rationale_decision: D1
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
  - type: domain-contract
    assertion: "closeout_id equals sha256(v1 NUL github NUL repository NUL workflow NUL entity_slug NUL implementation_pr), and exactly one owner is required for shared PRs"
    rationale_decision: D2
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
  - type: filter-contract
    assertion: "indirect landing or shared PR ownership with zero/multiple owners cannot enter terminal closeout"
    rationale_decision: D2
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
  - type: data-contract
    assertion: "direct mode changes final ship.md, schema-valid debrief, terminal archived entity, _closeouts receipt, and exactly one ROADMAP Shipped row in one Git commit"
    rationale_decision: D3
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
  - type: contract
    assertion: "optional PR mode reports closeout-pr-awaiting-merge and withholds done/PASSED on authoritative main until the sentinel PR is MERGED"
    rationale_decision: D3
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
  - type: data-contract
    assertion: "every durable external or Git side effect has an identity+hash already-applied predicate, and two success reruns are no-ops with the same proof_hash"
    rationale_decision: D3
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
  - type: schema-contract
    assertion: "docs/ship-flow/_closeouts/<closeout_id>.json binds kind, schema_version, path-derived identity, ownership/source hashes, implementation PR, deterministic closeout head, transaction phase, landing proof, output hashes, and proof hash"
    rationale_decision: D4
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
  - type: contract
    assertion: "startup/idle classifies a merged PR before ordinary owner resolution and returns closeout-pr-terminal-noop only when exactly one landed _closeouts receipt validates head, path-derived identity, implementation PR, output manifest, and proof hash; title/body never classify it"
    rationale_decision: D4
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
  - type: contract
    assertion: "manual-UI method uses proof-valid topology/patch candidates plus pre-merge intent only as a discriminator; absent multi-match intent returns landing-method-ambiguous and conflicting intent returns landing-method-intent-mismatch"
    rationale_decision: D5
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
  - type: data-contract
    assertion: "generated debrief preserves schema-v1 required sections, full reconciliation/todo digest, and first/last commits derived only from the landing envelope"
    rationale_decision: D1
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
  - type: contract
    assertion: "ship.md remains within C15 60 body lines and balanced standalone details exclusion semantics are unchanged"
    rationale_decision: D3
    source_artifact: docs/ship-flow/ship-stage-debrief-closeout/design.md
render_fidelity_targets: []
open_decisions: []
artifact_paths:
  - path: docs/ship-flow/ship-stage-debrief-closeout/design.md
```
<!-- /section:hand-off-to-plan -->
