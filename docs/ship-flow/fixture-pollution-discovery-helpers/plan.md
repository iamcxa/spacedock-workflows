# Fixture-tree exclusion for discovery helpers — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: use `superpowers:executing-plans` task-by-task; every code task also uses both TDD skills named below.

**Goal:** Make the two audited discovery consumers ignore descendant `__tests__` and `test-fixtures` trees through one Bash 3.2 sourceable helper, then prove the repo-root result once.

**Architecture:** `plugins/ship-flow/lib/discovery-exclusions.sh` owns only marker pruning and delegates each consumer's remaining `find` expression unchanged. The consumers keep their distinct outputs and existing non-fixture pruning; the existing invariant surface pins exactly two consumers and one production marker-definition site.

**Tech stack:** Bash 3.2, `find`, shell regression tests, mechanical invariants, Markdown.

<!-- section:plan-output -->
## Plan Output

### Research Summary

Design readiness, hand-off schema, and D-reference checks pass. Current recursive reach confirms only `discover-adopter-skills.sh:46-74` and the four `density-classify.sh:137-184` traversals qualify; the debrief warning at `docs/ship-flow/_debriefs/2026-07-12-01.md:38-49` matches this bounded fix. Runtime detection is shell-only (Bash 3.2 per `ARCHITECTURE.md:96-109`); no package-manager command override or architecture-lens trigger applies.

Fresh seven-factor cross-review verdict: PROCEED; all factors and `skill-coverage` passed.

### Size Re-evaluation

Small-batch confirmed: nine bounded implementation/test/doc paths across four serial tasks. No schema, API, UI, executable-helper, config-loader, non-shell consumer, or permanent walker-inventory work is planned.

<details>
<summary>Mechanical import of all seven design constraints</summary>

## Plan Imported Design DCs

<!-- section:plan-imported-design-dcs -->
| DC | Type | Source | Decision |
|---|---|---|---|
| DC-1 | contract | Exactly one Bash 3.2 namespaced sourceable helper; no executable, declarative-loader, or non-shell mode. | D1 |
| DC-2 | filter-contract | Prune requested-root-relative descendant `__tests__` and `test-fixtures` only; never reject root/ancestor or generic `fixtures`, `test`, `tests`. | D2 |
| DC-3 | contract | Both consumers source/use the helper; all four density traversals retain consumer-specific behavior. | D3 |
| DC-4 | contract | Direct source assertions plus one marker-single-definition invariant; no permanent detector/inventory. | D3 |
| DC-5 | filter-contract | Twin-root RED/GREEN decoys, positive fixture-root behavior, intended stdout, exit 0, empty stderr for both consumers. | D2 |
| DC-6 | contract | Workflow README records `--workflow-dir docs/ship-flow` and local tracker `#24`. | D3 |
| DC-7 | contract | Repo-root discovery runs once only after focused GREEN; any route, stderr, or nonzero exit returns to design. | D3 |
<!-- /section:plan-imported-design-dcs -->
</details>

<!-- section:verification-spec -->
### Verification Spec

| DC | Verify Procedure | Expected |
|---|---|---|
| DC-1 | `bash -n plugins/ship-flow/lib/discovery-exclusions.sh && grep -q '^ship_flow_discovery_find()' plugins/ship-flow/lib/discovery-exclusions.sh` | Sourceable namespaced Bash function parses. |
| DC-2 | `bash plugins/ship-flow/lib/__tests__/test-adopter-skill-discovery.sh && bash plugins/ship-flow/lib/__tests__/test-density-classify.sh` | Nested markers are pruned while marker-named roots remain valid. |
| DC-3 | `test "$(grep -c 'ship_flow_discovery_find' plugins/ship-flow/lib/density-classify.sh)" -eq 4 && grep -q 'discovery-exclusions.sh' plugins/ship-flow/lib/discover-adopter-skills.sh` | Exactly four density calls and adopter consumer wiring. |
| DC-4 | `bash plugins/ship-flow/lib/__tests__/test-check-invariants.sh && bash plugins/ship-flow/bin/check-invariants.sh --check discovery-exclusions` | Positive and adversarial invariant fixtures pass. |
| DC-5 | `bash plugins/ship-flow/lib/__tests__/test-adopter-skill-discovery.sh && bash plugins/ship-flow/lib/__tests__/test-density-classify.sh` | Both focused suites assert exact stdout, exit 0, and empty stderr. |
| DC-6 | `grep -q -- '--workflow-dir docs/ship-flow' docs/ship-flow/README.md && grep -q 'iamcxa/spacedock-workflows/issues/24' docs/ship-flow/README.md` | Guard and tracker link are present. |
| DC-7 | `tmp=$(mktemp -d); plugins/ship-flow/lib/discover-adopter-skills.sh --root=. >"$tmp/out" 2>"$tmp/err"; rc=$?; bad=0; test "$rc" -eq 0 || bad=1; test ! -s "$tmp/err" || bad=1; test "$(grep -c '^  - name:' "$tmp/out" || true)" -eq 0 || bad=1; rm -rf "$tmp"; test "$bad" -eq 0` | Execute once after DC-1–DC-6 GREEN; failure stops and routes to design. |
<!-- /section:verification-spec -->

<!-- section:canonical-doc-actions -->
### Canonical Doc Actions

| Doc | Action | Source | Rationale |
|---|---|---|---|
| `ROADMAP.md` | update | spec | Ship-review moves the active Now row to Shipped at terminal closeout; execute does not edit it. |
| `PRODUCT.md` | skip | design | Internal correctness repair adds no durable product capability. |
| `ARCHITECTURE.md` | skip | design | A sourceable helper stays inside the documented `lib/` component and Bash 3.2 constraint. |
<!-- /section:canonical-doc-actions -->

<!-- section:plan -->
### Plan

#### Task 1: Adopter discovery RED/GREEN and shared helper

```yaml
task_id: T1
wave: W1
layer: L4
parallel_group: serial
depends_on: []
owned_paths: [plugins/ship-flow/lib/discovery-exclusions.sh, plugins/ship-flow/lib/discover-adopter-skills.sh, plugins/ship-flow/lib/__tests__/test-adopter-skill-discovery.sh]
integration_owner: executer
skills_needed: [superpowers:test-driven-development, ship-flow:test-driven-development, test, best-practices]
reviewer_questions: [{lens: bash-portability, question: "Does the helper stay source-only, Bash 3.2-compatible, root-relative, and safely quoted while preserving the consumer expression?", affected_path_family: "plugins/ship-flow/lib/*.sh", evidence_required: "bash -n plus focused twin-root output, exit, and stderr assertions"}]
tdd_contract:
  red_command: "bash plugins/ship-flow/lib/__tests__/test-adopter-skill-discovery.sh"
  expected_red_failure: "the nested __tests__/test-fixtures decoy adds a route or diverges from its clean twin before shared pruning exists"
  green_command: "bash plugins/ship-flow/lib/__tests__/test-adopter-skill-discovery.sh"
  refactor_check: "bash -n plugins/ship-flow/lib/discovery-exclusions.sh plugins/ship-flow/lib/discover-adopter-skills.sh && bash plugins/ship-flow/lib/__tests__/test-adopter-skill-discovery.sh"
```

Confirmed `MISSING`: two searches (`rg --files plugins/ship-flow/lib` and `rg -n 'ship_flow_discovery_find|discovery-exclusions' plugins/ship-flow`) find no existing shared helper. Add twin clean/decoy roots, explicit status/stderr capture, and positive use of the existing marker-ancestor fixture; observe RED, then create only `ship_flow_discovery_find` and wire `find_pruned` before GREEN.

#### Task 2: Density RED/GREEN across all four traversals

```yaml
task_id: T2
wave: W2
layer: L4
parallel_group: serial
depends_on: [T1]
owned_paths: [plugins/ship-flow/lib/density-classify.sh, plugins/ship-flow/lib/__tests__/test-density-classify.sh]
integration_owner: executer
skills_needed: [superpowers:test-driven-development, ship-flow:test-driven-development, test, best-practices]
reviewer_questions: [{lens: density-contract, question: "Do nested decoys cease affecting S1-S3 while roots beneath marker-named ancestors retain intended classification and all runs keep exit 0/empty stderr?", affected_path_family: "plugins/ship-flow/lib/density-classify.sh", evidence_required: "focused RED then GREEN output for all four helper calls"}]
tdd_contract:
  red_command: "bash plugins/ship-flow/lib/__tests__/test-density-classify.sh"
  expected_red_failure: "a nested fixture decoy changes the clean twin classification before density traversals use the helper"
  green_command: "bash plugins/ship-flow/lib/__tests__/test-density-classify.sh"
  refactor_check: "bash -n plugins/ship-flow/lib/density-classify.sh && bash plugins/ship-flow/lib/__tests__/test-density-classify.sh"
```

Add clean/decoy and marker-ancestor positive cases with explicit status/stderr assertions; observe RED, source the T1 helper, replace exactly the four `find` traversals, and preserve S1-S4 semantics through GREEN.

#### Task 3: Direct-consumer and single-definition invariant

```yaml
task_id: T3
wave: W3
layer: L4
parallel_group: serial
depends_on: [T1, T2]
owned_paths: [plugins/ship-flow/bin/check-invariants.sh, plugins/ship-flow/lib/__tests__/test-check-invariants.sh]
integration_owner: executer
skills_needed: [superpowers:test-driven-development, ship-flow:test-driven-development, test, best-practices]
reviewer_questions: [{lens: invariant-scope, question: "Does the named check directly pin the two consumers and production marker definitions without classifying recursive walkers or fixtures?", affected_path_family: "plugins/ship-flow/{bin,lib/__tests__}", evidence_required: "one good fixture plus missing-source and duplicate-definition failures"}]
tdd_contract:
  red_command: "bash plugins/ship-flow/lib/__tests__/test-check-invariants.sh"
  expected_red_failure: "new positive/adversarial discovery-exclusions cases fail because the named invariant and dispatcher entry do not exist"
  green_command: "bash plugins/ship-flow/lib/__tests__/test-check-invariants.sh && bash plugins/ship-flow/bin/check-invariants.sh --check discovery-exclusions"
  refactor_check: "bash -n plugins/ship-flow/bin/check-invariants.sh plugins/ship-flow/lib/__tests__/test-check-invariants.sh && bash plugins/ship-flow/lib/__tests__/test-check-invariants.sh"
```

Test first, then add one narrow named/full-run check: both consumers source the helper and `-name __tests__`/`-name test-fixtures` production definitions occur only there. Do not add a walker detector, inventory file, or new checker.

#### Task 4: Operator guard and one-shot acceptance

```yaml
task_id: T4
wave: W4
layer: meta
parallel_group: serial
depends_on: [T1, T2, T3]
owned_paths: [docs/ship-flow/README.md]
integration_owner: executer
skills_needed: [write-docs, superpowers:verification-before-completion]
reviewer_questions: [{lens: acceptance-stop, question: "Is the #24 guard actionable, and is repo-root discovery executed exactly once only after focused GREEN with every failure routed to design?", affected_path_family: "docs/ship-flow/README.md and repo-root CLI", evidence_required: "README grep plus captured exit/stdout/stderr from the single run"}]
TDD: skip -- documentation plus acceptance orchestration; alternate validation is the DC-6 grep followed by the DC-7 single execution after every focused check is GREEN.
```

Document the explicit guard/tracker, run T1–T3 GREEN commands and the named invariant, then execute DC-7 exactly once. Any emitted route, non-empty stderr, or nonzero exit ends execute with return-to-design evidence; do not patch again.

| Task | Scope anchor | Wave safety |
|---|---|---|
| T1 | AC-1/AC-2; DC-1/DC-2/DC-3/DC-5 | Owns helper/adopter files exclusively. |
| T2 | W2; DC-2/DC-3/DC-5 | Depends on helper; owns density files. |
| T3 | AC-2; DC-4 | Depends on both consumers; owns invariant files. |
| T4 | AC-3; DC-6/DC-7 | Last serial wave; owns README only. |
<!-- /section:plan -->

## Context Manifest

- **Skills loaded**: `superpowers:writing-plans`, `superpowers:test-driven-development`, `ship-flow:test-driven-development`, `ship-flow:ship-runtime-detect`, `ship-flow:ship-plan`, `ship-flow:science-officer-em`, `spacedock:ensign`.
- **INVARIANTS sections read**: Principle 6 (`plugins/ship-flow/INVARIANTS.md:119`), Principle 8 (`:288`), Principle 12 (`:481`).
- **Architecture docs consulted**: `PRODUCT.md` capabilities; `ROADMAP.md` Now; `ARCHITECTURE.md` components, constraints, dependencies.
- **Domains touched**: registry label `schema` is context-only; zero L1/L2/L3 schema surfaces and no architecture-lens trigger matched.
- **Lens dispatched**: none (no trigger match).
- **Lens findings integrated**: 0 integrated, 0 deferred, 0 ignored.
- **Folder guidance**: files=all T1-T4 paths → `folder_guidance_files=`, `folder_guidance_skills=`; `.claude/ship-flow/skill-routing.yaml` absent and discovery is reserved by DC-7; `codex_context_boundary=root AGENTS.md/CLAUDE.md intentionally excluded from folder_guidance_files`.

<!-- section:context-routing-manifest -->
```yaml
context-routing-manifest:
  schema_version: 1
  domain_matches: [{domain: schema, match_type: local-registry, required: true}]
  knowledge_modules: [{domain: schema, path: plugins/ship-flow/references/domain-knowledge/schema.md, load_required: false, missing_behavior: warn}]
  required_skills: []
  stage_hints: {plan: [], execute: [], verify: []}
  consumer_obligations: {plan: [map manifest rows to task skills, reviewer questions, and domain acceptance], verify: [extract this section before accepting routed obligations]}
  future_provider_boundary: {status: optional_append_only, provider_hints: [], context_sources: [{source_type: local-registry, source_ref: plugins/ship-flow/registry/defaults.yaml, authoritative_for_routing: true}]}
```
<!-- /section:context-routing-manifest -->

<details>
<summary>Context routing receipt</summary>

## Context Routing Receipt

| Manifest row | Task mapping | Reviewer questions | Checklist row |
|---|---|---|---|
| `schema_version`, `domain_matches: schema` | T1-T4 preserve registry context but add no schema skill/surface. | Each question stays Bash/invariant/docs-specific. | DAC-1 to DAC-4 |
| `knowledge_modules: schema` | Explicit N/A: no L1/L2/L3 files or migration semantics. | No schema lens invented from historical label. | DAC-1 |
| `required_skills: []`, empty `stage_hints` | No task skill mapping required. | Explicit skip because registry emitted empty lists. | DAC-1 |
| `consumer_obligations.plan` | Every task has `skills_needed` and `reviewer_questions`. | Evidence is carried below. | DAC-1 to DAC-4 |
| `future_provider_boundary` | Local registry remains authoritative; no provider hints. | No task obligation. | Explicit N/A |

</details>

<!-- section:plan-report -->
## Plan Report

status: passed
stage_cost: $0.00 (one planner; one stalled reviewer replaced by one read-only PROCEED reviewer)
iterations: 1 self-review + 1 completed cross-review
dimensions: requirement coverage PASS; task completeness PASS; dependency safety PASS; placeholder scan PASS; TDD PASS; stale anchors PASS; design constraints PASS; context routing PASS
reviewer_verdict: APPROVED
cross_review_verdict: PROCEED
cross_review_coaching: Enforce Ship-Flow Principle 16—evidence over attestation—to prevent fixture-derived false routing from contaminating repository-root acceptance.
scope_anchoring: 4/4 tasks mapped; 7/7 imported constraints covered
skill-coverage: PASS

### Metrics

- status: passed
- duration_minutes: 30
- iteration_count: 2
- task_count: 4
- verification_spec_count: 7
- model_split: 3 sonnet implementation tasks, 1 haiku docs/acceptance task
<!-- /section:plan-report -->

<!-- section:hand-off-to-execute -->
### Hand-off to Execute

- `tdd-ledger`: `tdd-ledger.jsonl`; validate with `python3 plugins/ship-flow/lib/validate-tdd-ledger.py --plan docs/ship-flow/fixture-pollution-discovery-helpers/plan.md --require-ledger-jsonl docs/ship-flow/fixture-pollution-discovery-helpers/tdd-ledger.jsonl`.
- `wave_order`: W1 T1 → W2 T2 → W3 T3 → W4 T4.
- `critical_assumptions`: helper preserves arbitrary consumer expressions and marker-named requested roots; exactly two current consumers remain; DC-7 is never used before focused GREEN.
- `architecture_context`: update only workflow README during execute; PRODUCT/ARCHITECTURE skip; ROADMAP closeout is ship-review-owned.
- `stub_flags`: none.
- `skills_needed_summary`: T1-T3 use both TDD skills plus shell test/best-practices; T4 uses write-docs and verification-before-completion; heterogeneous lists are distinct.

| Task ID | Parallel Group | Depends On | Owned Paths | Integration Owner |
|---|---|---|---|---|
| T1 | serial | none | helper, adopter consumer/test | executer |
| T2 | serial | T1 | density consumer/test | executer |
| T3 | serial | T1,T2 | invariant/test | executer |
| T4 | serial | T1,T2,T3 | workflow README | executer |

| Task ID | Verify Lens | Reviewer Question | Affected Path Family | Required Skills | Evidence Required |
|---|---|---|---|---|---|
| T1 | bash-portability | Source-only root-relative helper preserves caller expression? | `plugins/ship-flow/lib/*.sh` | TDD,test,best-practices | RED/GREEN, `bash -n`, exact stdout/status/stderr |
| T2 | density-contract | All four traversals prune decoys without root rejection? | density script/test | TDD,test,best-practices | RED/GREEN classification/status/stderr |
| T3 | invariant-scope | Two sources and one marker-definition site only? | invariant script/test | TDD,test,best-practices | positive and adversarial fixture results |
| T4 | acceptance-stop | Guard actionable and single run stops on any failure? | README and repo-root CLI | write-docs,verification | grep plus one captured run |

Canonical doc actions summary: `ROADMAP.md` update at ship-review; `PRODUCT.md` skip; `ARCHITECTURE.md` skip.
<!-- /section:hand-off-to-execute -->
<!-- /section:plan-output -->
