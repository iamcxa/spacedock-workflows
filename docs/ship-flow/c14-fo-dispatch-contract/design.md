# Design — Align C14 with First Officer stage-entry transitions

affects_ui: false
domain: schema

## Design Dispatch Manifest

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
        worktree: /Users/kent/conductor/workspaces/spacedock-workflows/yangon/.claude/worktrees/c14-fo-dispatch-contract
        base_head: origin/main..HEAD
        mode: read-only findings-only
      outputs:
        - workflow-schema boundary
        - explicit database-layer non-applicability
    - lane: contract-interface
      role: contract/interface-designer
      trigger: captain-approved separation of First Officer stage entry from stage-worker completion
      decisions: [D1, D2]
      examples: [commit subject grammar, helper protocol, workflow status schema]
      outputs:
        - two independently recognizable Git receipt contracts
        - skill and helper wiring deltas
        - shell, string-assertion, and integration acceptance surfaces
  integration:
    mode: parallel
    owner: ship-design
registry:
  matched: schema
  validate_status: ok
ui_surfaces: []
```

## Design Output

### Captain Decisions

- **D1|Captain decision**: Stage-entry dispatch and completion advancement are two independent legal contracts. The First Officer owns entry into the next workflow stage; the stage worker owns registering the completed artifact through the completion helper. C14 must recognize each contract by its own receipt and must not let either receipt impersonate the other.
- **D2|Captain decision**: The aligned contracts take effect without a data-migration gate: the current entity's real `shape -> design` FO entry is valid immediately, and the next `/ship` run is protected by the same checked-in skill, helper, and test contracts once the FO prepares a ship range containing Safe NARROW Cases 14–31 only.

These decisions preserve the captain's approved bet verbatim in the entity body: separate, machine-verifiable legal contracts that support FO-led dogfood safely, effective on the next ship and, where the repaired C14 code is already present, on this entity.

### Contract 1 — First Officer stage-entry dispatch

| Dimension | Contract |
| --- | --- |
| Owner | First Officer orchestration, before the stage worker begins |
| State effect | Mutate each dispatched entity from its current state to the next declared stage or the current state's declared `feedback-to` stage |
| Durable receipt | Commit **subject** exactly `dispatch: <non-empty bounded summary> entering <stage>` for fresh dispatch or `advance: <non-empty bounded summary> entering <stage>` for same-worker reuse |
| Mechanical binding | The final subject token equals every mutated entity's resulting `status:`; C14 validates the workflow edge before accepting the receipt |
| Forbidden lookalikes | Receipt in body only; empty summary; wrong after-stage; undeclared skip/back-edge; alternate verb; forged completion substring |
| Enforcer | `_commit_has_fo_stage_entry_receipt` plus graph-first `check_entity_status_via_advance_stage_only` in `plugins/ship-flow/bin/check-invariants.sh` |

The contract already exists in `plugins/ship-flow/skills/ship/SKILL.md:39-56`, `plugins/ship-flow/INVARIANTS.md:561-590`, and C14. Plan must preserve those semantics and add tests before changing production code.

### Contract 2 — Stage-worker completion advancement

| Dimension | Contract |
| --- | --- |
| Owner | The active stage worker, after its stage artifact lands |
| State effect | On a helper-compatible folder entity, invoke `advance-stage.sh` with `--new-status=<current-stage>` and `--stage-name=<current-artifact-stage>` so FO-entered runs register the artifact idempotently; the helper's sanctioned status-mutation path remains legal for compatible callers |
| Durable receipt | If the helper actually mutates `status:`, its commit message contains the distinct completion signature `: advance status to `; if status is already set, the artifact/link commit remains helper-owned without pretending to be a stage-entry receipt |
| Mechanical binding | CAS hash, `register-stage-output.sh`, optional `update-entity-status.sh`, `render-stage-links.sh`, and a path-scoped commit form one atomic helper chain |
| Forbidden lookalikes | Worker directly entering the next stage; using `dispatch:`/`advance: ... entering ...` as a completion receipt; omitting the helper; hand-editing status or stage output links |
| Enforcer | `advance-stage.sh`, its unit/integration tests, and C14's unchanged completion-signature branch |

This is deliberately not “completion moves to the next stage.” The worker registers completion against the stage the FO already entered, then returns control; the FO performs the next stage-entry transition under Contract 1.

### Required contract deltas

| Surface | Required plan delta | Why it is load-bearing |
| --- | --- | --- |
| `plugins/ship-flow/skills/ship/SKILL.md:39-56` | Preserve the fresh/reuse subject grammar, subject-only and after-stage binding, graph legality, and the sentence that entry does not replace completion. Add an exact string assertion rather than relying on prose review. | This is the future `/ship` dispatch contract and therefore the next-ship activation point. |
| `plugins/ship-flow/skills/ship-design/SKILL.md:340-365,706-709` | Replace both direct `design -> plan` instructions with a layout-safe completion branch: for a helper-compatible folder entity, call `advance-stage.sh --new-status=design --stage-name=design --stage-file=design.md`; for a legacy flat ledger without the stage-link schema, do not invoke the destructive helper or synthesize a migration. In both branches, return to the FO for a separate plan-entry commit. | Design is the only core stage skill without explicit completion ownership, and the guard preserves the helper's existing legacy warning instead of widening this slice into entity migration. |
| `plugins/ship-flow/skills/ship-plan/SKILL.md:410-426` | Preserve `--new-status=plan --stage-name=plan --stage-file=plan.md`; clarify that this registers plan completion and FO owns entry into execute. | Prevents “advance to execute” prose from being mistaken for direct worker mutation while keeping the existing machine path. |
| `plugins/ship-flow/skills/ship-execute/SKILL.md:333-349` | Preserve `execute/execute/execute.md`; clarify completion-versus-next-entry ownership. | Same owner boundary for execute. |
| `plugins/ship-flow/skills/ship-verify/SKILL.md:1181-1195` | Preserve `verify/verify/verify.md`; clarify completion-versus-next-entry ownership. | Same owner boundary for verify. |
| `plugins/ship-flow/skills/ship-review/SKILL.md:383-403` | Preserve the intentional `--new-status=ship --stage-name=review --stage-file=review.md` exception and explicitly state that it is the completion contract's reviewed terminal state, not a generic FO receipt. | Review has no `status: review`; an exact exception prevents a false all-stages-are-identical rule. |
| `plugins/ship-flow/skills/ship/SKILL.md:279-291` | Preserve `ship/ship/ship.md` idempotent completion registration independently from PR metadata; keep `ship -> done` outside this slice. | Closes the stage-output chain without widening into terminal merge policy. |
| `plugins/ship-flow/lib/advance-stage.sh:4-14,16-33,79-94,120-160,203-205` | Add `design` to the documented `--new-status` and `--stage-name` usage. Preserve the legacy-body warning, current runtime behavior, CAS, helper order, conditional completion signature, rollback, and path-scoped commit. Do not add a second receipt grammar or auto-migrate flat entities. | The implementation already accepts design and supports status-idempotent artifact registration on compatible entities; the public helper contract and tests lag the behavior. |
| `plugins/ship-flow/bin/check-invariants.sh` C14 helpers | Preserve Safe NARROW Cases 14–31: subject-only FO matching, non-empty summary, all-after-stage binding, graph-first validation, root/bounds/indentation/normalization parsing, and flat/folder path scope. No migration, rename, merge, or provenance expansion. | This is the enforceable gate for Contract 1 and the manual-bypass gate shared by both contracts. |
| `plugins/ship-flow/INVARIANTS.md:561-590` | Keep Principle 15 as the normative two-owner contract. Correct the stale claim that `advance-stage.sh` injects the completion signature at a named line: callers provide the message and the helper validates it before a status mutation. | Durable contract documentation must match the executable checks, but docs alone do not satisfy the design. |
| `ARCHITECTURE.md` decisions | Add one decision recording the two-owner split, graph-first validation, completion-helper chain, and provenance deferral to #38. | Prevents later refactors from collapsing the two legal transitions into one ambiguous “advance” operation. |
| Git ship range | Before review/ship, FO prepares a clean range containing `f8fc638`, `347cfe2`, `2f4afbe`, `be5d071`, `4b1b35b`, and only the parser-indentation hunks from `cd957c3`, plus the new contract-alignment work. Exclude the current branch's Cases 32–45 commits and unrelated harvest entities. | `origin/main...HEAD` currently contains deferred migration/rename and merge behavior; passing local tests is not proof that the eventual merge remains Safe NARROW. Branch/worktree surgery is FO-owned, not worker scope. |

### Schema boundary and deliberate no-deltas

| Schema surface | Decision |
| --- | --- |
| `docs/ship-flow/README.md` workflow `stages.states` | Remains the owning transition graph. No new state or edge is introduced; C14 reads the graph at the commit parent. |
| Entity frontmatter `status:` | Remains the state value that both contracts ultimately bind. No frontmatter receipt field is added. |
| `plugins/ship-flow/references/entity-body-schema.yaml` | No receipt-schema change. Receipts are Git commit metadata, while this schema continues to type design handoff constraints and artifacts. The current flat ledger is not converted to a folder index merely to exercise the helper. |
| Database L1/L2/L3, migration, RBAC, fstore | Not applicable. This is a repository workflow-contract schema; no application data model, storage table, tenant boundary, projection, or rebuild changes. |
| Provenance/authentication | Explicitly deferred to #38. V1 validates structure and transition semantics, not author identity. No self-attested tool field is added. |

### Test and activation inventory

| Layer | Surface | Assertions planning must pin |
| --- | --- | --- |
| Shell contract | `plugins/ship-flow/lib/__tests__/test-enforce-advance-stage.sh` Cases 14–18 | Accept fresh/reuse FO subjects; reject body-only, empty-summary, lookalike, and wrong-stage receipts. |
| Shell contract | Same file Cases 19–25 | Require declared direct or feedback edges before every receipt/exemption path; normalize graph values. |
| Shell parser/path | Same file Cases 26–31 | Stop at root/sibling bounds; ignore decoy lists; enforce canonical `stages.states` indentation and correct entity path scope. |
| Manual-bypass baseline | Same file Cases 1–13 | Preserve arbitrary status-edit rejection, completion-signature acceptance, body-table exemption behavior, and existing safe additions. |
| Helper unit | `plugins/ship-flow/lib/__tests__/test-advance-stage.sh` | Add design as an accepted documented stage; preserve CAS, atomic helper chain, rollback, idempotent artifact registration, path-only commits, and Case 11's refusal of invalid completion messages before mutation. |
| Stage integration | `plugins/ship-flow/lib/__tests__/test-stage-wiring.sh` | Add `design.md`; on a compatible folder fixture, exercise FO-entered `status: design` followed by idempotent design completion registration; then prove a separate legal FO plan-entry receipt before plan completion. Keep exact review-to-ship exception and all output/link synchronization checks. Add a flat-ledger assertion that design completion does not invoke the destructive helper or mutate status. |
| String assertions | `plugins/ship-flow/lib/__tests__/test-ship-unified-entry-routing.sh` plus `test-stage-wiring.sh` | Extend the existing `/ship` entry-routing test beyond FO bootstrap to assert the exact fresh/reuse grammars and “does not replace completion” boundary. In stage wiring, assert explicit helper wiring and exact stage/status/file triples in design, plan, execute, verify, review, and ship skills. Replace weak count-only coverage where exact wiring matters. |
| Current-entity integration | Real commit `8b9488c5fe2f7aeb0b9c38ef0fff2b069d2acee2` | `advance: c14-fo-dispatch-contract entering design` is a same-worker receipt, changes this entity `shape -> design`, and passes targeted C14 now. Because this entity remains a legacy flat ledger without the helper's stage-link schema, design completion appends its report without a status mutation; it must not force Contract 2 or a layout migration. |
| Next-ship integration | A disposable workflow fixture driven through the checked-in `/ship` contract | FO entry commit passes targeted C14, stage helper registers the matching artifact, arbitrary/manual and cross-contract lookalikes fail, and the subsequent FO entry remains a separate commit. |
| Repository gates | Targeted C14, `CI=true` invariant gate, canonical shell suite, Node tests, shellcheck, `git diff --check`, and a final merge-range audit | All pass with no commit allowlist, forged completion signature, or imported Cases 32–45 behavior. The range audit is performed after FO narrowing, not inferred from this broad historical branch. |

Cases 32–35, 37–43, and 45 remain #36; Cases 36 and 44 remain #37; authenticated provenance remains #38. The completion-message body-forgery limitation already documented in Principle 15 also remains outside this Safe NARROW slice.

### Same-feature and next-ship activation

1. **Same feature, already active for stage entry:** commit `8b9488c5fe2f7aeb0b9c38ef0fff2b069d2acee2` uses the canonical same-worker subject and the targeted C14 checker returns `OK C14 entity-status-via-advance-stage-only` for the real `shape -> design` edge.
2. **Same feature, safe completion:** this legacy flat ledger records the design artifact and Stage Report without changing `status:`. It does not invoke `advance-stage.sh`, because there is no compatible stage-link table to render and layout/status migration is deferred. The FO later enters plan in its own `advance: ... entering plan` commit, which Contract 1 verifies.
3. **Next ship, automatic activation after range narrowing:** `/ship` emits Contract 1 and compatible folder entities run Contract 2. A folder-fixture integration test proves design completion is status-idempotent before the later, separate FO plan-entry commit. No release-time data migration or manual backfill is required; once the FO excludes deferred Cases 32–45 and merges the skill/helper/test deltas, the next invocation uses the aligned contracts.

## Schema Design Output

- **L1 decider:** N/A — no application decision model changes.
- **L2 persistence/fstore:** N/A — Git history remains the receipt store; no database or projection changes.
- **L3 view:** N/A — no read-model or UI changes.
- **Migration safety:** N/A — no data migration; existing workflow entities retain their current status and layout, including this flat ledger.
- **RBAC/tenancy:** N/A — no tenant-scoped data surface.
- **Rebuild strategy:** N/A — no fstore or projection rebuild.
- **Workflow schema decision:** the root `stages.states` graph and entity `status:` remain canonical. Receipt type is inferred from Git commit metadata and checked against that schema; it is not copied into entity YAML.

## Design Readiness Review

reviewers: schema
verdict: PASS

The schema/contract review found no database-layer change and confirmed that the workflow graph, entity status, and Git receipt remain separate canonical concerns. It also found that the live branch contains deferred Cases 32–45, so FO-owned range narrowing is a pre-ship constraint. A proposed bare `design.md` helper call on this flat ledger was rejected: `register-stage-output.sh` stores the path verbatim and `render-stage-links.sh` returns exit 10 because the ledger has no section markers. The plan therefore adds helper wiring only for compatible folder entities and pins the flat fallback. Safe NARROW and #36–#38 deferrals remain intact.

Independent cross-review first returned BLOCK on the machine handoff, manifest shape, and reviewer-verdict vocabulary. After adding the folder/flat split to the typed constraints, normalizing lane roles and integration ownership, and setting the cross-review verdict to `PROCEED`, the same reviewer returned **PROCEED** with all fresh checks passing.

## Design Report

status: passed
stage_cost: local analysis and independent schema/contract review

### Metrics

status: passed
duration_minutes: 32
iteration_count: 0
captain_decisions_count: 2
reviewer_verdict: PROCEED

### Hand-off to Plan

<!-- section:hand-off-to-plan -->
```yaml
design-skipped: false
design_constraints:
  - type: contract
    assertion: "FO stage entry is a subject-only dispatch/advance receipt bound to every entity after-stage and a declared direct or feedback workflow edge."
    rationale_decision: D1
    source_artifact: docs/ship-flow/c14-fo-dispatch-contract/design.md
  - type: contract
    assertion: "On helper-compatible folder entities, stage workers register completion through advance-stage.sh against the completed stage and return next-stage entry to the FO; design receives the missing helper wiring."
    rationale_decision: D1
    source_artifact: docs/ship-flow/c14-fo-dispatch-contract/design.md
  - type: contract
    assertion: "Legacy flat ledgers without the stage-artifact-links schema append stage reports without invoking advance-stage.sh and without mutating status or layout; the FO still owns the next entry."
    rationale_decision: D1
    source_artifact: docs/ship-flow/c14-fo-dispatch-contract/design.md
  - type: schema-contract
    assertion: "The workflow README stages.states graph plus entity status remain canonical; no receipt field, database schema, migration, or authenticated provenance is added."
    rationale_decision: D1
    source_artifact: docs/ship-flow/c14-fo-dispatch-contract/design.md
  - type: contract
    assertion: "Acceptance proves the real same-feature entry and a disposable next-ship sequence, while retaining manual-bypass detection and only Cases 14-31."
    rationale_decision: D2
    source_artifact: docs/ship-flow/c14-fo-dispatch-contract/design.md
  - type: contract
    assertion: "Before review and ship, the FO prepares a clean merge range containing Cases 14-31 only; current-branch Cases 32-45 and unrelated harvest entities are excluded."
    rationale_decision: D2
    source_artifact: docs/ship-flow/c14-fo-dispatch-contract/design.md
render_fidelity_targets: []
storyboard_frames: []
open_decisions: []
artifact_paths:
  - path: docs/ship-flow/c14-fo-dispatch-contract/design.md
```
<!-- /section:hand-off-to-plan -->
