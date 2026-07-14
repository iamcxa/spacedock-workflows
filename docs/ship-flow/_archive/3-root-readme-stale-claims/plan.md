<!-- section:plan-report -->
# Refresh root README stale compatibility claims — Implementation Plan

> **For executer:** use strict RED-before-GREEN; do not edit `README.md` or `scripts/check-version-triple.sh` until the focused test fails for the expected missing guard.

**Goal:** Make the repository front door version-independent and make the existing release gate reject future root-README version literals.

**Architecture:** Keep the three canonical release-version values and their equality check unchanged. Add one independent root-README negative grep to the same gate, pinned by a hermetic shell fixture that copies the production checker into a temporary repository.

**Runtime:** Tier-1 stack detection is empty. Tier-2 detects a shell-first repository (`*.sh`, GitHub Actions); the relevant commands are focused Bash fixture tests, `bash -n`, `shellcheck`, and the existing repository gate.

<!-- section:plan-output -->
## Plan Output

### Research Summary

`README.md` currently contains stale `0.7.0`, `0.7.x`, and `0.22.0` claims plus an `Apache-2.0` literal. `scripts/check-version-triple.sh` validates only plugin JSON, marketplace JSON, plugin README H1, and repository metadata; it never scans the root README. `PRODUCT.md` already owns canonical product positioning. No architecture-lens domain trigger matches this three-file shell/docs slice.

### Size Re-evaluation

Small-batch confirmed: exactly three implementation paths, one serial TDD task, no UI/domain/contract decision, and no runtime dependency addition.

### Assumption Re-validation

| Assumption | Live evidence | Result |
| --- | --- | --- |
| A1 — a version-shape grep can catch recurrence without the current release value | The current checker has no root README input; the planned fixtures vary bare, `v`-prefixed, and `x`-series spellings. | confirmed |
| A2 — `PRODUCT.md` is canonical positioning | `PRODUCT.md` already states capabilities and quality-gate positioning; root README duplicates release-era prose. | confirmed |

## Plan Imported Design DCs

<!-- section:plan-imported-design-dcs -->
<!-- Generated from the design-skipped hand-off; there are no design constraints to import. -->

**Status**: design-skipped (`design-skipped: true`).

No design DCs to import. Plan proceeds without UI or render-fidelity work.

<!-- /section:plan-imported-design-dcs -->

<!-- section:verification-spec -->
### Verification Spec

| AC | Verify Procedure | Expected |
| --- | --- | --- |
| AC-1 | Run the focused fixture test and `grep -nE` with the production version-literal pattern against `README.md`. | The clean repository README has zero version-shaped literals; bare semver, `v0.7`, and `0.7.x` fixture variants are rejected. |
| AC-2 | Compare root positioning/adoption prose with `PRODUCT.md`; verify `README.md` links it. | README describes compatibility/adoption without release-number duplication and points readers to the canonical product document. |
| AC-3 | Run `bash scripts/check-version-triple.sh` and inspect the focused test's failure fixtures. | The existing gate remains green on the repository and returns nonzero for every injected root-README version variant. |
<!-- /section:verification-spec -->

<!-- section:canonical-doc-actions -->
### Canonical Doc Actions

| Doc | Action | Source | Rationale |
| --- | --- | --- | --- |
| `README.md` | update | touched-files | This is the stale front-door surface and must link canonical positioning. |
| `PRODUCT.md` | skip | plan | It already carries the canonical positioning; no capability changes. |
| `ARCHITECTURE.md` | skip | plan | The change extends an existing mechanical gate without changing component boundaries or dependencies. |
| `ROADMAP.md` | update | plan | Shape moved the entity into the active queue; review must synchronize its current stage while merge closeout remains terminal. |
<!-- /section:canonical-doc-actions -->

<!-- section:plan -->
### Plan

#### T1 — Pin and implement version-independent root README

```yaml
task_id: T1
wave: W1
layer: L4
parallel_group: serial
depends_on: []
owned_paths:
  - plugins/ship-flow/lib/__tests__/test-check-version-triple.sh
  - scripts/check-version-triple.sh
  - README.md
integration_owner: executer
model_hint: sonnet
skills_needed:
  - superpowers:test-driven-development
  - ship-flow:test-driven-development
  - test
  - best-practices
  - write-docs
reviewer_questions:
  - "Does the fixture exercise the unmodified production checker and prove clean, bare-semver, v0.7, and x-series behavior?"
  - "Does the production regex reject version claims without depending on the current release number?"
  - "Does README retain truthful compatibility/adoption guidance while delegating canonical positioning to PRODUCT.md?"
tdd_contract:
  red_command: "bash plugins/ship-flow/lib/__tests__/test-check-version-triple.sh"
  expected_red_failure: "the new fixture expects v0.7-style root README drift to fail, but the current checker exits zero because it does not inspect the root README"
  green_command: "bash plugins/ship-flow/lib/__tests__/test-check-version-triple.sh && bash scripts/check-version-triple.sh"
  refactor_check: "bash -n scripts/check-version-triple.sh plugins/ship-flow/lib/__tests__/test-check-version-triple.sh && shellcheck scripts/check-version-triple.sh plugins/ship-flow/lib/__tests__/test-check-version-triple.sh && bash plugins/ship-flow/lib/__tests__/test-check-version-triple.sh && bash scripts/check-version-triple.sh"
```

1. Create the focused test first. Its temporary repo supplies matching triple-site versions and a clean root README, then injects `0.7.0`, `v0.7`, and `0.7.x` one at a time. Require clean rc 0 and drift rc nonzero with a root-README diagnostic.
2. Run the focused command and record the expected RED: at least the first drift fixture incorrectly exits 0 because the production checker has no root README scan. Stop if RED passes.
3. Extend `scripts/check-version-triple.sh` with a release-number-independent ERE for `v?major.minor`, optional patch, and `x` series variants. Keep the existing triple equality and repository checks unchanged.
4. Rewrite root compatibility/adoption prose without version literals, link `PRODUCT.md`, and keep the root license line version-independent by pointing readers to the machine-readable plugin metadata instead of inventing a nonexistent `LICENSE` link.
5. Run GREEN, then the full refactor check. Record exact RED/GREEN/REFACTOR evidence in `execute.md`.

| Task | AC anchor | Wave safety |
| --- | --- | --- |
| T1 | AC-1, AC-2, AC-3 | Single serial owner for all three tightly coupled paths. |
<!-- /section:plan -->

## Context Manifest

- **Skills loaded**: `superpowers:writing-plans`, `ship-flow:ship-plan`, `ship-flow:ship-runtime-detect`, `ship-flow:test-driven-development`.
- **INVARIANTS sections read**: Principle 5 canonical docs, Principle 6 plan review, Principle 8 artifact budget, Principle 12 hermetic dependencies in `plugins/ship-flow/INVARIANTS.md`.
- **Architecture docs consulted**: `PRODUCT.md`, `ARCHITECTURE.md` constraints/dependencies, `ROADMAP.md`, shape and trivial-pass design artifacts.
- **Domains touched**: none.
- **Lens dispatched**: none (no trigger match).
- **Lens findings integrated**: 0 integrated, 0 deferred, 0 ignored.
- **Folder guidance**: files=T1 owned paths -> `folder_guidance_files=`, `folder_guidance_skills=`; `codex_context_boundary=root AGENTS.md/CLAUDE.md intentionally excluded from folder_guidance_files`.

## Plan Report

status: passed
stage_cost: one Codex planner plus one bounded read-only cross-review
iterations: 1 self-review + 1 cross-review remediation
dimensions: feasibility PASS; executable scope PASS; quality PASS; DC adequacy PASS; canonical sync PASS; reverse-audit PASS; skill coverage PASS
reviewer_verdict: APPROVED
cross_review_verdict: PROCEED after BLOCK remediation
cross_review_coaching: Keep root licensing truthful without inventing a target, and make execute metadata independently consumable.
open_decisions: []
scope_anchoring: 1/1 task mapped; AC-1/2/3 covered
skill-coverage: PASS

### Metrics

status: passed
duration_minutes: 18
iteration_count: 2
task_count: 1
verification_spec_count: 3
model_split: one sonnet implementation dispatch; one read-only plan review
started: 2026-07-14T16:26:00Z
completed: 2026-07-14T16:44:29Z

### Hand-off to Execute

- `tdd-ledger`: `tdd-ledger.jsonl`; validate with `python3 plugins/ship-flow/lib/validate-tdd-ledger.py --plan docs/ship-flow/3-root-readme-stale-claims/plan.md --require-ledger-jsonl docs/ship-flow/3-root-readme-stale-claims/tdd-ledger.jsonl` (current result: PASS, one record).
- `wave_order`: W1 T1 only; create test → RED → production edits → GREEN/REFACTOR.
- `critical_assumptions`: A1 version-shape regex remains release-independent; A2 `PRODUCT.md` remains canonical positioning.
- `architecture_context`: update root README; skip PRODUCT/ARCHITECTURE; ROADMAP closeout remains review-owned.
- `stub_flags`: none.
- `skills_needed_summary`: T1 uses both TDD contracts plus test/best-practices/write-docs; single heterogeneous task intentionally carries one combined list.

<!-- section:hand-off-to-execute -->
```yaml
plan-parallelization-manifest:
  - task_id: T1
    parallel_group: serial
    depends_on: []
    owned_paths:
      - plugins/ship-flow/lib/__tests__/test-check-version-triple.sh
      - scripts/check-version-triple.sh
      - README.md
    integration_owner: executer
```
<!-- /section:hand-off-to-execute -->

| Task ID | Verify Lens | Reviewer Question | Affected Path Family | Required Skills | Evidence Required |
| --- | --- | --- | --- | --- | --- |
| T1 | shell-gate-contract | Does the unmodified production checker distinguish clean root prose from bare, `v`-prefixed, and `x`-series version drift while retaining triple-site checks? | root README, release checker, focused fixture | TDD, test, best-practices, write-docs | ordered RED/GREEN output, syntax/shellcheck results, live repository gate, README/PRODUCT comparison |

Execute T1 serially with its recorded RED before any production edit. No implementation task may touch #28, the changed-scope CI fix, or ROADMAP closeout rows.
<!-- /section:plan-output -->

<!-- /section:plan-report -->
