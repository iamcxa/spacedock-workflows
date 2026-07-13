---
commissioned-by: spacedock@0.24.0
workflow-version: ship-flow@0.8.2
entity-type: feature
entity-label: feature
entity-label-plural: features
id-style: slug
entry-point: ship-flow:ship-shape
auto_fix: execute
state: $inline
stages:
  defaults:
    worktree: true
    concurrency: 2
  states:
    - name: draft
      initial: true
      worktree: false
      manual: true
    - name: shape
      worktree: false
      gate: true
      manual: true
      parallelism: probes
      skill: ship-flow:ship-shape
      model: opus
    - name: design
      worktree: true
      gate: true
      manual: conditional
      parallelism: lanes
      skill: ship-flow:ship-design
      model: opus
    - name: plan
      parallelism: draft-lanes
      skill: ship-flow:ship-plan
      model: sonnet
    - name: execute
      parallelism: dag
      skill: ship-flow:ship-execute
      model: sonnet
    - name: verify
      gate: true
      worktree: false
      parallelism: checks
      skill: ship-flow:ship-verify
      model: sonnet
      dispatch: debate-driven
      feedback-to: execute
    - name: ship
      worktree: false
      skill: ship-flow:ship-review
      model: sonnet
    - name: done
      terminal: true
      worktree: false
---

# Ship-Flow — dogfood instance for the ship-flow plugin itself

Ship-focused pipeline: SHAPE once with the captain, then agents run design
for contract-bearing work before plan → execute → verify → ship. This is the
plugin's own development workflow — every feature here changes the ship-flow
plugin (stage skills, lib/bin helpers, references/schemas, templates, docs)
or this repo's canonical docs. The methodology source is
`plugins/ship-flow/`; this directory is the working instance that must obey
it.

## File Naming

Each feature lives as either:

- a flat markdown file `{slug}.md` (default — use this unless the feature
  produces many artifacts), or
- a folder `{slug}/` containing `index.md` as the canonical entity file,
  when the feature produces per-stage artifacts (shape.md, design.md,
  plan.md, execute.md, verify.md, review.md) that belong alongside the
  tracker.

Slugs are lowercase, hyphens, no spaces. The status scanner recognizes both
forms; `--set` and `--archive` resolve the slug either way, and folder
entities archive as a whole folder into `_archive/`.

## Schema

Every feature file has YAML frontmatter. Fields are documented below; see
**Feature Template** for a copy-paste starter.

### Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Optional under `id-style: slug` — the slug is the effective ID |
| `title` | string | Human-readable feature name |
| `status` | enum | One of: draft, shape, design, plan, execute, verify, ship, done |
| `source` | string | Where this feature came from (audit finding, todo, captain) |
| `started` | ISO 8601 | When active work began |
| `completed` | ISO 8601 | When the feature reached terminal status |
| `verdict` | enum | PASSED or REJECTED — set at final stage |
| `score` | number | Priority score, 0.0–1.0 (optional) |
| `worktree` | string | Worktree path while a dispatched agent is active, empty otherwise |
| `issue` | string | GitHub issue reference (optional cross-reference) |
| `pr` | string | GitHub PR reference — set when the entity's branch opens a PR |

### ID Style

`id-style: slug` — the entity slug (filename) is the durable identity;
`id` is optional. `status --next-id` is not applicable. Use
`status --validate` before trusting workflow state and
`status --resolve <ref>` to resolve slugs.

## Stages

### `draft`

Captain captures an idea. A feature sits in draft until the captain decides
it is worth shaping.

- **Inputs:** a friction signal — audit finding, harvest candidate, adopter
  bug report, or captain direction
- **Outputs:** an entity file with a problem statement (what breaks or costs
  today, with evidence) and provisional `## Acceptance criteria`
- **Good:** the problem names WHO pays the cost and cites the empirical
  record (entity stage-reports, audit, usage log)
- **Bad:** a solution masquerading as a problem; no evidence beyond "seems
  wrong"

### `shape`

Captain-facing. FO invokes `ship-flow:ship-shape` directly (not via ensign)
for the interactive Musk audit. Reads PRODUCT.md + ROADMAP.md +
ARCHITECTURE.md, size triage (S/M/L), scoring gate, and canonical update
intent. Only human gate in the pipeline.

- **Inputs:** entity problem statement, root canonical docs, the plugin's
  INVARIANTS.md, prior art in `_plans/` and `references/`
- **Outputs:** shape.md with problem/done-criteria/size; typed DCs;
  ROADMAP `now` row intent; canonical-doc impact blocks when the work
  changes durable architecture or product surface
- **Good:** scope cut to the cheapest slice that delivers the end value;
  every mechanism AC paired with a value-measuring AC
- **Bad:** multi-week absolutist plans without a loss-function audit;
  greenfield tasks without proof the abstraction is missing

### `design`

Design always runs. Contract-bearing work (skill contracts, schema changes
in `references/*.yaml`, helper CLI surfaces, template changes) dispatches a
designer; pure mechanical work walks the Phase 0 trivial-pass fast-path
emitting minimal design.md + verdict PROCEED.

- **Inputs:** shape.md, the affected SKILL/reference/helper sources, the
  shell-test suite that pins current contracts
- **Outputs:** design.md naming the contract deltas (which SKILL sections,
  which schema fields, which helper flags) and the test surfaces that must
  move with them
- **Good:** names every string-assertion test that pins the text being
  changed; prefers a code gate over a prose-only rule
- **Bad:** redesigning prose without checking which of the 110+ shell tests
  assert it

### `plan`

Agent-autonomous. Size-adaptive research + plan writing + self-review loop.
Max 3 iterations.

- **Inputs:** shape.md + design.md, `lib/__tests__/` test conventions,
  CI gates (invariants, node suite, version-triple, no-dangling)
- **Outputs:** plan.md with TDD contracts per code-bearing task
  (RED-before-GREEN), explicit test files, and a Canonical Doc Actions
  section (update/skip + rationale per root canonical doc)
- **Good:** every new helper or rule lands with a failing test first;
  tasks small enough to verify independently
- **Bad:** plans that touch `plugins/ship-flow/bin|lib` without naming
  which existing tests could break

### `execute`

Agent-autonomous. Wave-parallel dispatch with per-task model hints,
implementer→reviewer loop, BLOCKED escalation ladder.

- **Inputs:** plan.md tasks, the entity worktree
- **Outputs:** implementation commits with RED→GREEN evidence in
  execute.md; full local gate run (shell suite, node tests,
  check-invariants, check-no-dangling, check-version-triple) before
  handoff
- **Good:** pre-handoff self-check clean (`git diff --check` + suite);
  deviations from plan recorded with one-line rationale
- **Bad:** "tests pass" claims without naming which suites ran; silent
  scope growth into unrelated skills

### `verify`

Agent gate. FO dispatches review agents, integrates findings, runs the
quality gate + UAT. Stage feedback returns to execute; multi-destination
routing by finding class is handled inside verify.md via `route_to:`. FO
does not inline-fix BLOCKING/WARNING findings.

- **Inputs:** execute.md, the diff, the live gate results
- **Outputs:** verify.md with per-AC evidence citations, `runtime_uat`
  claim (or explicit `not-applicable|deferred — <reason>`), and verdict
- **Good:** every AC has an evidence citation; degraded checks are declared,
  never silent
- **Bad:** PASS verdicts diluted from INCONCLUSIVE runtime claims without a
  structured `PROMPT_CAPTAIN:` line

### `ship`

Agent-autonomous. PR creation, ROADMAP.md + PRODUCT.md + ARCHITECTURE.md
updates, token cost summary. Advances to done.

- **Inputs:** verify.md PASS, review.md canonical-doc outcomes
- **Outputs:** PR with the entity's branch; canonical docs patched per the
  plan's Canonical Doc Actions (update or explicit skip rationale);
  release consideration recorded (does this slice warrant a version bump?)
- **Good:** `pnpm`-free zero-dep checks pass in CI; canonical-doc sync is a
  pipeline output, not a manual afterthought
- **Bad:** merging with an unconsumed Canonical Doc Actions row

### `done`

Terminal stage. Merge hook fires here. Entity archived after merge.

## Workflow State

Workflow state is read by the first officer at boot. To view current state,
dispatch the first officer or run it directly:

```
spacedock claude
```

### Instance discovery guard

This repository contains workflow-shaped test fixtures. For every `spacedock
status` call here, bypass auto-discovery and select the real instance explicitly:

```sh
spacedock status --workflow-dir docs/ship-flow <status arguments>
```

Track removal of this workaround in [#24](https://github.com/iamcxa/spacedock-workflows/issues/24).
Until that issue is resolved, do not use `spacedock status --discover` to select
this instance.

## Feature Template

```yaml
---
title: Feature name here
status: draft
source:
started:
completed:
verdict:
score:
worktree:
issue:
pr:
---

Brief description of this feature and what it aims to achieve.

## Acceptance criteria

Each AC names a property of the finished entity (not a stage action) and
how it is verified.

**AC-1 — {End-state property.}**
Verified by: {grep / test name / file path / command a future reader can reproduce.}
```

## Commit Discipline

- Commit status changes at dispatch and merge boundaries
- Commit feature body updates when substantive
- Workflow-state commits ride the entity's PR branch; scaffolding changes
  land via PR like any other change in this repo
