# Attempt Circuit Protocol and Clock Authority Implementation Plan

> **For executer:** REQUIRED SUB-SKILL: use `superpowers:executing-plans` task-by-task and preserve the Ship-Flow RED-before-GREEN evidence trail.

**Goal:** Implement only the exact plan/execute `stage-attempt-v1` protocol and FO-owned nonterminal portable-clock authority defined by parent W1.
**Architecture:** Add one Bash 3.2-compatible helper at the fixed completion seam. The helper owns exact attempt identity, WAL/returned-bundle grammar, stage budgets, same-boot nonterminal continuity, and fail-closed clock-fault detection while treating `completion-v1.sh` as frozen bytes and leaving durable interruption/history, continuation policy, route, scheduler, skill/schema wiring, and #21 to later children.
**Tech stack:** Bash 3.2+, Git common-dir fixtures, Node 18+ monotonic clock source, ShellCheck, repository shell/Node CI gates.

## Research Summary

- This born-shaped child carries forward parent W1 without revising D1-D4. Durable inputs are design `31ec710f7afde772a7d88e90eac9c3fa4661502b`, approved topology `c7b6a9f264a74b8101525faf2036e12f414aff61`, reviewed RED `a575a1fb26f210c2f1a862af894e8d40305ad176`, child instantiation `e62bc651ae2f5728a4a13a75bcbb234e26617cb0`, and dispatch baseline `f05c79455e056522225c2a07e41d26e7c896e4a2`.
- `plugins/ship-flow/lib/fo-stage-attempt.sh` is **MISSING**: `test ! -e` succeeds, `find plugins/ship-flow/lib -maxdepth 1 -name '*attempt*'` finds no helper, and `rg` finds the protocol only in tests/design. Disproof hook: any production helper or callable equivalent outside fixtures changes this classification and requires plan review before execute.
- The committed contract and clock suites start byte-identical to `a575a1f` (`6be43aecbd54a7922bde036efeb226a24e017632e8962a907ac99050eb9e774b` and `bc2ed2ea35d2179b65e49ca852ce691f07b64cd77258c1f05172edf367019048`). Both currently exit 1 only at the missing-helper guard. That RED proves only the pre-existing baseline; it cannot prove any newly added foreign-binding negative. T1 therefore requires a runnable baseline GREEN before seven separately selectable binding cases may count as RED.
- `plugins/ship-flow/lib/completion-v1.sh` is byte-identical to `e62bc65`, SHA-256 `a2d15b8281995e9bad82a472030b18ba0b427a29194d41f1729603ceb6f64f10`; it is a forbidden write path for T1-T2.
- Runtime is Tier-2 shell/Node from `.github/workflows/ship-flow-invariants.yml`: focused Bash suites, `bash -n`, ShellCheck, invariant/Node/version-triple/no-dangling gates; no build, typecheck, or dev command applies.
- Plan-time lineage was repaired non-destructively at `8142856`; from feedback HEAD `a3085a1`, the full invariant composite is GREEN including C14, while C4/C8/C15 pass independently. Execute must preserve that clean lineage and return BLOCKED rather than repair unrelated history if C14 regresses.
- Parent T0 tests outside W1 remain read-only scope sentinels: `test-stage-attempt-history.sh`, `test-stage-attempt-route.sh`, and `test-attempt-scoped-stage-circuits-21.sh` may stay RED until 006.2-006.4. `test-stage-wiring.sh` is integration scope and must not be edited here.

## Size Re-evaluation

S implementation surface: one new production path, one bounded negative-case addition to the existing contract suite, and one committed read-only clock suite. Contract risk remains high, so work stays serial with two independently reviewable commits. Any need to edit a second production surface or satisfy history/route/wiring suites triggers **NARROW** to the owning child rather than a size upgrade.

## Plan Imported Design DCs

| Parent constraint | W1 carriage | Decision |
|---|---|---|
| Exact separate `stage-attempt-v1`; unchanged delimited completion receipt | T1 exact parser/serializer and frozen-byte gate | D1 |
| Plan/execute closed allowlist; unrelated stages unchanged | T1 allowlist and negative controls | D1 |
| FO alone issues run/attempt/ref-before/completion bindings and elapsed authority | T1 identity; T2 nonterminal clocks/resume | D2 |
| Same-boot resume preserves nonterminal identity/origin; clock loss or regression cannot regain budget | T2 fail-closed detection; durable interruption deferred to 006.2 | D2 |
| Plan=1200s, execute=1800s, strict `elapsed > budget` | T2 boundary matrix | D4 |

D3 history/CAS/replay and D4 exhaustion/#21 constraints remain fixed but are owned by 006.2-006.4, not this plan.

## Verification Spec

| DC | Verify Procedure | Expected |
|---|---|---|
| W1-DC1 protocol | `STAGE_ATTEMPT_CONTRACT_CASE=baseline bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh && for CASE in foreign-stage-run foreign-ref foreign-before foreign-worker-completion foreign-worker foreign-lease foreign-attempt; do STAGE_ATTEMPT_CONTRACT_CASE="$CASE" bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh || exit 1; done` | Baseline first runs GREEN with an executable helper; then seven independently selected stage-run/ref/before/worker-completion/worker/lease/attempt mutations each fail closed with unchanged WAL/returned state. A missing-helper or fixture guard is invalid foreign-binding evidence. |
| W1-DC2 clock | `STAGE_ATTEMPT_CLOCK_CASE=nonterminal bash plugins/ship-flow/lib/__tests__/test-stage-attempt-clock.sh` | Plan/execute budgets are 1200/1800, exact boundary is live, threshold+1 expires, same-boot suspend/resume preserves authority, and clock loss/regression refuses resume without changing the suspended WAL, terminal history, continuation count, or route state. |
| W1-DC3 completion compatibility | `test "$(shasum -a 256 plugins/ship-flow/lib/completion-v1.sh | awk '{print $1}')" = a2d15b8281995e9bad82a472030b18ba0b427a29194d41f1729603ceb6f64f10 && bash plugins/ship-flow/lib/__tests__/test-completion-v1-review.sh && bash plugins/ship-flow/lib/__tests__/test-completion-v1-frontmatter.sh && bash plugins/ship-flow/lib/__tests__/test-advance-stage.sh` | Frozen implementation bytes and existing completion lifecycle matrices remain unchanged. |
| W1-DC4 repository gates | `CI=true bash plugins/ship-flow/bin/check-invariants.sh && node --test plugins/ship-flow/bin/*.test.mjs && bash scripts/check-version-triple.sh && bash scripts/check-no-dangling.sh` | All four assigned CI gates pass from repository root. |

### Canonical Doc Actions

| Doc | Action | Source | Rationale |
|---|---|---|---|
| `ROADMAP.md` | skip | plan | 006.1 is an internal child of the already-approved parent prerequisite; umbrella review owns roadmap placement. |
| `PRODUCT.md` | skip | design | Protocol/clock recovery correctness changes no user-facing capability or product promise. |
| `ARCHITECTURE.md` | update | design | Review must record the new FO-only attempt identity, frozen completion boundary, and boot-bound monotonic authority once implementation is verified. |

## Scope Anchoring

| Task | Entity outcome | Parent source |
|---|---|---|
| T1 | exact plan/execute grammar, FO-issued bindings, completion-v1 framing | W1; D1-D2; parent T1 contract half |
| T2 | 1200/1800 clocks, same-boot nonterminal resume, fail-closed clock-fault detection | W1; D2/D4; parent T1 clock half |

## Plan

### T1 — Exact attempt protocol and frozen completion framing

task_id: T1
layer: L5
wave: W1
files: create `plugins/ship-flow/lib/fo-stage-attempt.sh`; modify `plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh` only for table-driven foreign-binding negatives; read-only regressions `test-completion-v1-review.sh`, `test-completion-v1-frontmatter.sh`, `test-advance-stage.sh`
read_first: child `index.md`; parent design commit `31ec710:101-255,371-388`; reviewed RED commit `a575a1f`; `completion-v1.sh:66-73,217-239`
classification: helper MISSING by the two-strategy search in Research Summary; the pre-existing contract baseline EXISTS_BROKEN on that absence, while the seven foreign-binding cases are separately MISSING. Disproof hooks are a discovered production implementation or existing independently selectable mutation cases for every binding.
skills_needed: [test, best-practices, test-driven-development]
reviewer_questions: [{lens: contract, question: "Does the helper accept only plan/execute, derive FO-owned IDs from the fixed inputs, compare exact expected records, reject each foreign binding without state mutation, and preserve completion-v1 bytes?", affected_path_family: "plugins/ship-flow/lib/fo-stage-attempt.sh", evidence_required: "missing-helper RED used only for the baseline; baseline GREEN before seven separately selected REDs; focused GREEN; frozen SHA and completion matrices GREEN"}]
baseline_tdd_checkpoint:
  baseline_red_probe: "test ! -e plugins/ship-flow/lib/fo-stage-attempt.sh && bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh"
  baseline_red_meaning: "Exit 1 only at the pre-existing missing-helper guard; this proves no foreign-binding case."
  baseline_green_gate: "STAGE_ATTEMPT_CONTRACT_CASE=baseline bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh"
tdd_contract:
  red_command: "test -x plugins/ship-flow/lib/fo-stage-attempt.sh && STAGE_ATTEMPT_CONTRACT_CASE=baseline bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh && for CASE in foreign-stage-run foreign-ref foreign-before foreign-worker-completion foreign-worker foreign-lease foreign-attempt; do STAGE_ATTEMPT_CONTRACT_CASE=$CASE bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh; done"
  expected_red_failure: "Baseline is GREEN, then exit 1 with seven separately labeled FAIL results for foreign stage_run_id, ref_hex, attempt_before_oid, worker_completion_oid, worker_id_hex, lease_sha256, and attempt_id; helper/fixture guards or one aggregate unlabeled failure are invalid RED evidence."
  green_command: "bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh && bash plugins/ship-flow/lib/__tests__/test-completion-v1-review.sh && bash plugins/ship-flow/lib/__tests__/test-completion-v1-frontmatter.sh && bash plugins/ship-flow/lib/__tests__/test-advance-stage.sh"
  refactor_check: "bash -n plugins/ship-flow/lib/fo-stage-attempt.sh && shellcheck plugins/ship-flow/lib/fo-stage-attempt.sh && git diff --exit-code e62bc651ae2f5728a4a13a75bcbb234e26617cb0 -- plugins/ship-flow/lib/completion-v1.sh"
parallel_group: serial
depends_on: []
owned_paths: [plugins/ship-flow/lib/fo-stage-attempt.sh, plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh]
integration_owner: executer@006.1-attempt-circuit-protocol-and-clock-authority
canonical_doc_actions: shared table
steps: 1. Verify the `a575a1f` hashes; record the missing-helper baseline RED; implement only enough exact grammar to make the unmodified baseline GREEN; freeze that checkpoint. 2. Add a selector whose default still runs every original assertion, prove `baseline` remains GREEN, then add stage-run/ref/before/worker-completion/worker/lease/attempt mutations. Before hardening production, run each selector separately and record its named exit-1 assertion plus unchanged state; the authoritative RED loop must reach all seven labels. 3. Implement the smallest binding hardening, run GREEN/refactor, and review the explicit two-path diff. 4. Commit only the helper and contract test.
review_gate: PROCEED only when the pre-existing baseline runs GREEN before every newly planned foreign-binding case has its own observable RED, W1-DC1/W1-DC3 pass, the W1 clock mode remains the expected next RED, and no history/route/integration/#21 behavior or path was added; otherwise NARROW.

### T2 — FO nonterminal clock authority and same-boot lifecycle

task_id: T2
layer: L5
wave: W2
files: modify `plugins/ship-flow/lib/fo-stage-attempt.sh`, `plugins/ship-flow/lib/__tests__/test-stage-attempt-clock.sh` only to add a W1 selector while preserving default/full cases
read_first: reviewed clock RED at `a575a1f`; T1 committed helper; parent design commit `31ec710:256-292`; Node 18+/Bash 3.2 constraints in `ARCHITECTURE.md`
classification: nonterminal clock authority EXISTS_BROKEN after T1 by the W1-focused RED. Durable interrupted terminalization/history/replay EXISTS_BROKEN but belongs to 006.2; fresh-continuation accounting/route-out belongs to 006.3. An immediate W1 GREEN means T1 accidentally absorbed T2 and requires review.
skills_needed: [test, best-practices, test-driven-development]
reviewer_questions: [{lens: clock-authority, question: "Are audit wall time and breaker authority separated, with Node monotonic nanoseconds plus hashed boot identity, strict greater-than expiry, exact same-boot nonterminal resume, and clock faults refusing resume without terminal/history/continuation/route mutation?", affected_path_family: "plugins/ship-flow/lib/fo-stage-attempt.sh", evidence_required: "post-T1 W1 clock RED; focused boundary/resume/fault-detection GREEN; suspended WAL unchanged on faults; protocol/completion regressions GREEN"}]
tdd_contract:
  red_command: "STAGE_ATTEMPT_CONTRACT_CASE=baseline bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh && STAGE_ATTEMPT_CLOCK_CASE=nonterminal bash plugins/ship-flow/lib/__tests__/test-stage-attempt-clock.sh"
  expected_red_failure: "Protocol baseline stays GREEN, then W1 mode exits nonzero only on missing budget/boundary/suspend-resume/clock-fault refusal behavior; helper/fixture failure, `interrupt`, terminal history, continuation accounting, or route behavior is invalid T2 RED evidence."
  green_command: "bash plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh && STAGE_ATTEMPT_CLOCK_CASE=nonterminal bash plugins/ship-flow/lib/__tests__/test-stage-attempt-clock.sh && bash plugins/ship-flow/lib/__tests__/test-completion-v1-review.sh && bash plugins/ship-flow/lib/__tests__/test-completion-v1-frontmatter.sh && bash plugins/ship-flow/lib/__tests__/test-advance-stage.sh"
  refactor_check: "bash -n plugins/ship-flow/lib/fo-stage-attempt.sh && shellcheck plugins/ship-flow/lib/fo-stage-attempt.sh && CI=true bash plugins/ship-flow/bin/check-invariants.sh && node --test plugins/ship-flow/bin/*.test.mjs && bash scripts/check-version-triple.sh && bash scripts/check-no-dangling.sh"
parallel_group: serial
depends_on: [T1]
owned_paths: [plugins/ship-flow/lib/fo-stage-attempt.sh, plugins/ship-flow/lib/__tests__/test-stage-attempt-clock.sh]
integration_owner: executer@006.1-attempt-circuit-protocol-and-clock-authority
canonical_doc_actions: shared table
steps: 1. Add a `nonterminal` selector whose default still runs the original full suite; use isolated plan/execute fixtures so W1 setup never calls `interrupt` for cleanup. Record the post-T1 W1 RED before clock production edits. 2. Add minimal portable clock capture/query, open/suspended/resume, and typed clock-fault refusal that preserves the suspended WAL byte-for-byte; do not durably terminalize, increment continuations, append history, or route. 3. Run focused GREEN, compatibility, and repository gates; record the default/full suite's remaining terminalization/policy RED as an explicit 006.2/006.3 handoff, not a T2 failure. 4. Review the explicit two-path diff and commit only the helper and clock test.
review_gate: PROCEED only when W1-DC1 through W1-DC4 pass, clock faults cannot regain budget or mutate nonterminal authority, and durable interruption/history/continuation/route/#21/wiring paths remain untouched; if T2 requires any such behavior or claims the full clock suite GREEN, stop **NARROW** for 006.2-006.4.

## Context Manifest

- **Skills loaded**: spacedock:ensign, ship-flow:ship-plan, superpowers:writing-plans, ship-flow:test-driven-development, ship-flow:ship-runtime-detect, reverse-recovery-audit.
- **INVARIANTS sections read**: Principle 6 context/layers/cross-review (`plugins/ship-flow/INVARIANTS.md:119-286`), Principle 8 plan budget (`:288-317`), Principle 15 owner transitions (`:561-593`), Principle 16 evidence validity (`:595-607`).
- **Architecture docs consulted**: `PRODUCT.md`, `ROADMAP.md`, `ARCHITECTURE.md`, parent `shape.md`, fixed `design.md`, approved parent `plan.md`, partial parent `execute.md`.
- **Domains touched**: workflow-local exact protocol and clock authority; no application/schema/event-saga domain implementation.
- **Lens dispatched**: none; fixed parent design at `31ec710` already passed schema/fmodel readiness and the child introduces no new decision.
- **Lens findings integrated**: 0 new findings, 0 deferred, 0 ignored; parent W1 constraints carried verbatim.
- **Folder guidance**: files=`plugins/ship-flow/lib/fo-stage-attempt.sh`, `plugins/ship-flow/lib/__tests__/test-stage-attempt-v1-contract.sh`, `plugins/ship-flow/lib/__tests__/test-stage-attempt-clock.sh`, `docs/ship-flow/006.1-attempt-circuit-protocol-and-clock-authority/**` -> folder_guidance_files=[]; folder_guidance_skills=[]; codex_context_boundary=root AGENTS.md/CLAUDE.md intentionally excluded from folder_guidance_files.

## Plan Report

status: passed
stage_cost: inline bounded research, authoring, and adversarial self-review
iterations: 3 completed adversarial self-review loops, including feedback cycle 1
dimensions: requirement coverage, task completeness, dependency safety, placeholders, signatures, minimality, TDD, stale anchors, fixed-design compliance, scope boundary, context manifest, and skill coverage reviewed
reviewer_verdict: PENDING independent SO/EM re-review — feedback-cycle plan-worker judgment is PROCEED for W1 on clean lineage `8142856`; execute must NARROW on durable interruption/history/continuation/route or BLOCKED if C14 regresses
scope_anchoring: 2/2 implementation tasks map only to 006.1 W1
skill-coverage: PASS

### Metrics

status: passed
duration_minutes: 35
iteration_count: 3
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
| T2 | serial | T1 | `plugins/ship-flow/lib/fo-stage-attempt.sh`, `plugins/ship-flow/lib/__tests__/test-stage-attempt-clock.sh` | executer@006.1-attempt-circuit-protocol-and-clock-authority |

#### Domain Acceptance Checklist

| Task ID | Verify Lens | Reviewer Question | Affected Path Family | Required Skills | Evidence Required |
|---|---|---|---|---|---|
| T1 | exact contract | Are grammar/bindings/framing closed and completion-v1 bytes frozen? | `plugins/ship-flow/lib/*.sh` | test,best-practices,TDD | focused RED/GREEN, frozen SHA, completion matrices |
| T2 | nonterminal clock authority | Can any missing/foreign/regressing clock regain budget or mutate the suspended WAL without 006.2 terminal authority? | `plugins/ship-flow/lib/*.sh`, clock test | test,best-practices,TDD | post-T1 W1 RED, boundary/resume/fault-refusal GREEN, unchanged WAL, four repo gates |

#### Canonical Doc Actions Summary

| Doc | Action | Rationale |
|---|---|---|
| `ROADMAP.md` | skip | Parent umbrella owns roadmap placement. |
| `PRODUCT.md` | skip | Internal-only correctness. |
| `ARCHITECTURE.md` | update | Record verified FO protocol/clock authority at review. |

- **deferred_clock_modes**: default/full clock cases requiring durable `interrupted` terminalization/history/replay route to 006.2; continuation-count and route-out cases route to 006.3. They remain expected RED after T2 and cannot be cited as W1 GREEN.
- **narrow_boundary**: stop and return NARROW before durable interruption, continuation accounting, history/replay, route, scheduler, lifecycle wiring, plan/execute skills, schema, integration tests, or #21 evidence.
<!-- /section:hand-off-to-execute -->
