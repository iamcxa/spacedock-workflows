# Attempt Circuit Protocol and Clock Authority Implementation Plan

> **For executer:** REQUIRED SUB-SKILL: use `superpowers:executing-plans` task-by-task and preserve the Ship-Flow RED-before-GREEN evidence trail.

**Goal:** Implement only the exact plan/execute `stage-attempt-v1` protocol and FO-owned portable clock semantics defined by parent W1.
**Architecture:** Add one Bash 3.2-compatible helper at the fixed completion seam. The helper owns exact attempt identity, WAL/returned-bundle grammar, stage budgets, and same-boot clock continuity while treating `completion-v1.sh` as frozen bytes and leaving history, route, scheduler, skill/schema wiring, and #21 to later children.
**Tech stack:** Bash 3.2+, Git common-dir fixtures, Node 18+ monotonic clock source, ShellCheck, repository shell/Node CI gates.

## Research Summary

- This born-shaped child carries forward parent W1 without revising D1-D4. Durable inputs are design `31ec710f7afde772a7d88e90eac9c3fa4661502b`, approved topology `c7b6a9f264a74b8101525faf2036e12f414aff61`, reviewed RED `a575a1fb26f210c2f1a862af894e8d40305ad176`, child instantiation `e62bc651ae2f5728a4a13a75bcbb234e26617cb0`, and dispatch baseline `f05c79455e056522225c2a07e41d26e7c896e4a2`.
- `plugins/ship-flow/lib/fo-stage-attempt.sh` is **MISSING**: `test ! -e` succeeds, `find plugins/ship-flow/lib -maxdepth 1 -name '*attempt*'` finds no helper, and `rg` finds the protocol only in tests/design. Disproof hook: any production helper or callable equivalent outside fixtures changes this classification and requires plan review before execute.
- The committed contract and clock suites start byte-identical to `a575a1f` (`6be43aecbd54a7922bde036efeb226a24e017632e8962a907ac99050eb9e774b` and `bc2ed2ea35d2179b65e49ca852ce691f07b64cd77258c1f05172edf367019048`). Both currently exit 1 only on the named missing-helper behavior; T1 may append only the entity-required foreign-binding negatives to the existing contract suite before production edits.
- `plugins/ship-flow/lib/completion-v1.sh` is byte-identical to `e62bc65`, SHA-256 `a2d15b8281995e9bad82a472030b18ba0b427a29194d41f1729603ceb6f64f10`; it is a forbidden write path for T1-T2.
- Runtime is Tier-2 shell/Node from `.github/workflows/ship-flow-invariants.yml`: focused Bash suites, `bash -n`, ShellCheck, invariant/Node/version-triple/no-dangling gates; no build, typecheck, or dev command applies.
- Plan-time baselines: Node is 79/79 GREEN and version-triple/no-dangling pass. The full invariant composite reports eight inherited C14 transition violations across the 103-commit `origin/main..HEAD` range; plan-specific C4/C8/C15 pass. Execute must re-evaluate the real PR merge-base and return BLOCKED rather than repair unrelated history if C14 remains red.
- Parent T0 tests outside W1 remain read-only scope sentinels: `test-stage-attempt-history.sh`, `test-stage-attempt-route.sh`, and `test-attempt-scoped-stage-circuits-21.sh` may stay RED until 006.2-006.4. `test-stage-wiring.sh` is integration scope and must not be edited here.

## Size Re-evaluation

S implementation surface: one new production path, one bounded negative-case addition to the existing contract suite, and one committed read-only clock suite. Contract risk remains high, so work stays serial with two independently reviewable commits. Any need to edit a second production surface or satisfy history/route/wiring suites triggers **NARROW** to the owning child rather than a size upgrade.

## Plan Imported Design DCs

| Parent constraint | W1 carriage | Decision |
|---|---|---|
| Exact separate `stage-attempt-v1`; unchanged delimited completion receipt | T1 exact parser/serializer and frozen-byte gate | D1 |
| Plan/execute closed allowlist; unrelated stages unchanged | T1 allowlist and negative controls | D1 |
| FO alone issues run/attempt/ref-before/completion bindings and elapsed authority | T1 identity; T2 clocks/resume | D2 |
| Same-boot resume preserves identity/origin; clock loss or regression cannot regain budget | T2 fail-closed clock matrix | D2 |
| Plan=1200s, execute=1800s, strict `elapsed > budget` | T2 boundary matrix | D4 |

D3 history/CAS/replay and D4 exhaustion/#21 constraints remain fixed but are owned by 006.2-006.4, not this plan.

## Verification Spec

| DC | Verify Procedure | Expected |
|---|---|---|
| W1-DC1 protocol | `bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh` | Exact WAL/outer receipt grammar, fixed field order, plan/execute allowlist, ref/before/completion/worker/lease/attempt binding, flat/folder framing, and malformed/foreign bytes fail closed. |
| W1-DC2 clock | `bash plugins/ship-flow/lib/__tests__/test-stage-attempt-clock.sh` | Plan/execute budgets are 1200/1800, exact boundary is live, threshold+1 expires, fresh identity increments once, same-boot resume preserves authority, and clock loss/regression terminalizes interrupted. |
| W1-DC3 completion compatibility | `test "$(shasum -a 256 plugins/ship-flow/lib/completion-v1.sh | awk '{print $1}')" = a2d15b8281995e9bad82a472030b18ba0b427a29194d41f1729603ceb6f64f10 && bash plugins/ship-flow/lib/__tests__/test-completion-v1-review.sh && bash plugins/ship-flow/lib/__tests__/test-completion-v1-frontmatter.sh && bash plugins/ship-flow/lib/__tests__/test-advance-stage.sh` | Frozen implementation bytes and existing completion lifecycle matrices remain unchanged. |
| W1-DC4 repository gates | `CI=true bash plugins/ship-flow/bin/check-invariants.sh && node --test plugins/ship-flow/bin/*.test.mjs && bash scripts/check-version-triple.sh && bash scripts/check-no-dangling.sh` | All four assigned CI gates pass from repository root. |

## Canonical Doc Actions

| Doc | Action | Source | Rationale |
|---|---|---|---|
| `ROADMAP.md` | skip | plan | 006.1 is an internal child of the already-approved parent prerequisite; umbrella review owns roadmap placement. |
| `PRODUCT.md` | skip | design | Protocol/clock recovery correctness changes no user-facing capability or product promise. |
| `ARCHITECTURE.md` | update | design | Review must record the new FO-only attempt identity, frozen completion boundary, and boot-bound monotonic authority once implementation is verified. |

## Scope Anchoring

| Task | Entity outcome | Parent source |
|---|---|---|
| T1 | exact plan/execute grammar, FO-issued bindings, completion-v1 framing | W1; D1-D2; parent T1 contract half |
| T2 | 1200/1800 clocks, fresh versus same-boot resume, fail-closed clock identity | W1; D2/D4; parent T1 clock half |

## Plan

### T1 — Exact attempt protocol and frozen completion framing

task_id: T1
layer: L5
wave: W1
files: create `plugins/ship-flow/lib/fo-stage-attempt.sh`; modify `plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh` only for table-driven foreign-binding negatives; read-only regressions `test-completion-v1-review.sh`, `test-completion-v1-frontmatter.sh`, `test-advance-stage.sh`
read_first: child `index.md`; parent design commit `31ec710:101-255,371-388`; reviewed RED commit `a575a1f`; `completion-v1.sh:66-73,217-239`
classification: helper MISSING by the two-strategy search in Research Summary; contract suite EXISTS_BROKEN only for explicit foreign-binding coverage. Disproof hooks are a discovered production implementation or existing named mutation cases for every binding.
skills_needed: [test, best-practices, test-driven-development]
reviewer_questions: [{lens: contract, question: "Does the helper accept only plan/execute, derive FO-owned IDs from the fixed inputs, compare exact expected records, reject foreign bindings without state mutation, and preserve completion-v1 bytes?", affected_path_family: "plugins/ship-flow/lib/fo-stage-attempt.sh", evidence_required: "recorded contract RED before helper creation; focused GREEN; frozen SHA and completion matrices GREEN"}]
tdd_contract:
  red_command: "test ! -e plugins/ship-flow/lib/fo-stage-attempt.sh && bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh"
  expected_red_failure: "Exit 1 with only FAIL fo-stage-attempt.sh is missing: exact stage-attempt-v1 protocol, plan/execute allowlist, and completion-v1 framing are not implemented."
  green_command: "bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh && bash plugins/ship-flow/lib/__tests__/test-completion-v1-review.sh && bash plugins/ship-flow/lib/__tests__/test-completion-v1-frontmatter.sh && bash plugins/ship-flow/lib/__tests__/test-advance-stage.sh"
  refactor_check: "bash -n plugins/ship-flow/lib/fo-stage-attempt.sh && shellcheck plugins/ship-flow/lib/fo-stage-attempt.sh && git diff --exit-code e62bc651ae2f5728a4a13a75bcbb234e26617cb0 -- plugins/ship-flow/lib/completion-v1.sh"
parallel_group: serial
depends_on: []
owned_paths: [plugins/ship-flow/lib/fo-stage-attempt.sh, plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh]
integration_owner: executer@006.1-attempt-circuit-protocol-and-clock-authority
canonical_doc_actions: shared table
steps: 1. Verify the `a575a1f` suite hashes, append only mutations for foreign stage-run/ref/before/completion/worker/lease/attempt bindings, and record the exact RED before any production write. 2. Implement the smallest exact begin/validate-return/accept-return grammar and common-Git-dir WAL/returned-byte ownership needed by that suite. 3. Run GREEN and refactor checks. 4. Review the explicit two-path diff; commit only the helper and contract test.
review_gate: PROCEED only when each foreign-binding mutation independently fails closed, W1-DC1 and W1-DC3 pass, the clock suite remains the expected next RED, and no history/route/integration/#21 behavior or path was added; otherwise NARROW.

### T2 — FO clock authority and same-boot lifecycle

task_id: T2
layer: L5
wave: W2
files: modify `plugins/ship-flow/lib/fo-stage-attempt.sh`; read-only test `plugins/ship-flow/lib/__tests__/test-stage-attempt-clock.sh`
read_first: reviewed clock RED at `a575a1f`; T1 committed helper; parent design commit `31ec710:256-292`; Node 18+/Bash 3.2 constraints in `ARCHITECTURE.md`
classification: clock lifecycle EXISTS_BROKEN after T1 by the focused clock RED; disproof hook is an immediate GREEN, which means T1 accidentally absorbed T2 and requires review before continuing.
skills_needed: [test, best-practices, test-driven-development]
reviewer_questions: [{lens: clock-authority, question: "Are audit wall time and breaker authority separated, with Node monotonic nanoseconds plus hashed boot identity, strict greater-than expiry, exact same-boot resume, and no favorable wall-clock fallback?", affected_path_family: "plugins/ship-flow/lib/fo-stage-attempt.sh", evidence_required: "post-T1 clock RED; GREEN boundary/resume/fault matrix; protocol and completion regressions GREEN"}]
tdd_contract:
  red_command: "bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh && bash plugins/ship-flow/lib/__tests__/test-stage-attempt-clock.sh"
  expected_red_failure: "Protocol stays GREEN, then clock exits nonzero on missing elapsed, suspend/resume, interrupt, budget-boundary, or clock-loss behavior; a helper-missing or fixture failure is invalid RED evidence."
  green_command: "bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh && bash plugins/ship-flow/lib/__tests__/test-stage-attempt-clock.sh && bash plugins/ship-flow/lib/__tests__/test-completion-v1-review.sh && bash plugins/ship-flow/lib/__tests__/test-completion-v1-frontmatter.sh && bash plugins/ship-flow/lib/__tests__/test-advance-stage.sh"
  refactor_check: "bash -n plugins/ship-flow/lib/fo-stage-attempt.sh && shellcheck plugins/ship-flow/lib/fo-stage-attempt.sh && CI=true bash plugins/ship-flow/bin/check-invariants.sh && node --test plugins/ship-flow/bin/*.test.mjs && bash scripts/check-version-triple.sh && bash scripts/check-no-dangling.sh"
parallel_group: serial
depends_on: [T1]
owned_paths: [plugins/ship-flow/lib/fo-stage-attempt.sh]
integration_owner: executer@006.1-attempt-circuit-protocol-and-clock-authority
canonical_doc_actions: shared table
steps: 1. Record the post-T1 clock RED before clock edits. 2. Add minimal portable clock capture/query and open/suspended/resume/interrupted transitions without terminal history or route policy. 3. Run focused GREEN, compatibility, and repository gates. 4. Review the one-path diff and commit only the helper.
review_gate: PROCEED only when W1-DC1 through W1-DC4 pass and history/route/#21/wiring paths remain untouched; if the clock suite needs tracked history, route-out, scheduler, skill/schema wiring, or #21 seeding, stop **NARROW** for 006.2-006.4.

## Context Manifest

- **Skills loaded**: spacedock:ensign, ship-flow:ship-plan, superpowers:writing-plans, ship-flow:test-driven-development, ship-flow:ship-runtime-detect, reverse-recovery-audit.
- **INVARIANTS sections read**: Principle 6 context/layers/cross-review (`plugins/ship-flow/INVARIANTS.md:119-286`), Principle 8 plan budget (`:288-317`), Principle 15 owner transitions (`:561-593`), Principle 16 evidence validity (`:595-607`).
- **Architecture docs consulted**: `PRODUCT.md`, `ROADMAP.md`, `ARCHITECTURE.md`, parent `shape.md`, fixed `design.md`, approved parent `plan.md`, partial parent `execute.md`.
- **Domains touched**: workflow-local exact protocol and clock authority; no application/schema/event-saga domain implementation.
- **Lens dispatched**: none; fixed parent design at `31ec710` already passed schema/fmodel readiness and the child introduces no new decision.
- **Lens findings integrated**: 0 new findings, 0 deferred, 0 ignored; parent W1 constraints carried verbatim.
- **Folder guidance**: files=`plugins/ship-flow/lib/fo-stage-attempt.sh`, `plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh`, `docs/ship-flow/006.1-attempt-circuit-protocol-and-clock-authority/**` -> folder_guidance_files=[]; folder_guidance_skills=[]; codex_context_boundary=root AGENTS.md/CLAUDE.md intentionally excluded from folder_guidance_files.

## Plan Report

status: passed
stage_cost: inline bounded research, authoring, and adversarial self-review
iterations: 2 completed adversarial self-review loops
dimensions: requirement coverage, task completeness, dependency safety, placeholders, signatures, minimality, TDD, stale anchors, fixed-design compliance, scope boundary, context manifest, and skill coverage reviewed
reviewer_verdict: PROCEED — W1 is independently executable; execute must NARROW on W2-W4 dependency or BLOCKED on unresolved inherited C14 gate failure
scope_anchoring: 2/2 implementation tasks map only to 006.1 W1
skill-coverage: PASS

### Metrics

status: passed
duration_minutes: 15
iteration_count: 2
task_count: 2
verification_spec_count: 4
model_split: inline Codex plan worker

### Hand-off to Execute

<!-- section:hand-off-to-execute -->
- **tdd-ledger**: `docs/ship-flow/006.1-attempt-circuit-protocol-and-clock-authority/tdd-ledger.jsonl`; run the persisted-ledger validator command recorded below before dispatch.
- **wave_order**: W1 T1 -> review/explicit-path commit -> W2 T2 -> review/explicit-path commit.
- **critical_assumptions**: exact commits `e62bc651ae2f5728a4a13a75bcbb234e26617cb0`, `a575a1fb26f210c2f1a862af894e8d40305ad176`, and `31ec710f7afde772a7d88e90eac9c3fa4661502b` remain available; the two RED suites and frozen completion hash match Research Summary; Bash 3.2+/Node 18+ are available.
- **architecture_context**: execute touches no canonical doc; review updates `ARCHITECTURE.md`, skips `PRODUCT.md` and child-local `ROADMAP.md` changes.
- **stub_flags**: none.
- **skills_needed_summary**: T1 and T2 use test, best-practices, and test-driven-development for the same Bash path class; repetition is intentional because tasks mature one helper serially.

#### Plan Parallelization Manifest

| Task ID | Parallel Group | Depends On | Owned Paths | Integration Owner |
|---|---|---|---|---|
| T1 | serial | none | `plugins/ship-flow/lib/fo-stage-attempt.sh`, `plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh` | executer@006.1-attempt-circuit-protocol-and-clock-authority |
| T2 | serial | T1 | `plugins/ship-flow/lib/fo-stage-attempt.sh` | executer@006.1-attempt-circuit-protocol-and-clock-authority |

#### Domain Acceptance Checklist

| Task ID | Verify Lens | Reviewer Question | Affected Path Family | Required Skills | Evidence Required |
|---|---|---|---|---|---|
| T1 | exact contract | Are grammar/bindings/framing closed and completion-v1 bytes frozen? | `plugins/ship-flow/lib/*.sh` | test,best-practices,TDD | focused RED/GREEN, frozen SHA, completion matrices |
| T2 | clock authority | Can any missing/foreign/regressing clock regain budget or identity? | `plugins/ship-flow/lib/*.sh` | test,best-practices,TDD | post-T1 RED, boundary/resume/fault GREEN, four repo gates |

#### Canonical Doc Actions Summary

| Doc | Action | Rationale |
|---|---|---|
| `ROADMAP.md` | skip | Parent umbrella owns roadmap placement. |
| `PRODUCT.md` | skip | Internal-only correctness. |
| `ARCHITECTURE.md` | update | Record verified FO protocol/clock authority at review. |

- **narrow_boundary**: stop and return NARROW before any edit to history, route, scheduler, lifecycle wiring, plan/execute skills, schema, integration tests, or #21 evidence.
<!-- /section:hand-off-to-execute -->
