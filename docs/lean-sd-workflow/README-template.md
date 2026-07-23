---
commissioned-by: spacedock@<version>
entity-type: task
entity-label: task
entity-label-plural: tasks
id-style: sd-b32
state: .spacedock-state
trunk: main
stages:
  defaults:
    worktree: false
    concurrency: 2
  states:
    - name: backlog
      initial: true
      gate: true
    - name: ideation
      gate: true
    - name: implementation
      worktree: true
    - name: validation
      worktree: true
      fresh: true
      feedback-to: implementation
      gate: true
    - name: done
      terminal: true
---

<!--
  LEAN SD WORKFLOW — canonical template (draft for captain review)

  Provenance: distilled from ship-flow methodology (2026-07-23 scope-cut ruling:
  freeze Epic 006 remainder, extract essence) + spacedock docs/dev/README.md
  proof policy + subspace-v0 lean replication pattern.

  Per-repo setup: copy to <repo>/docs/dev/README.md, fill every <angle-bracket>
  placeholder, run `spacedock` commission/refit to scaffold state checkout.
  Runtime concerns (gates, worktrees, state, dispatch, exactly-once) belong to
  the spacedock binary — this README carries METHODOLOGY ONLY.

  Litmus test for what belongs here: if correctness must survive a process
  crash, concurrent worktrees, or duplicate delivery, it belongs in the binary.
  If it describes how an agent should reason or what evidence it must produce,
  it belongs here.
-->


# <Repo Name> — Development Workflow

<One-paragraph product statement: what this repo ships, for whom, and where
canonical strategy lives. Link PRODUCT.md / ARCHITECTURE.md if present.>

Tasks move `backlog → ideation → implementation → validation → done`. One
gated design stage (ideation), one worktree build stage (implementation), one
fresh-context verification stage (validation) with `feedback-to`
implementation, and a terminal merge. The spacedock binary owns all runtime
semantics: stage transitions, gate records, worktree lifecycle, state
durability, exactly-once approval. This README owns judgment discipline only.

## File Naming

Each task is `{slug}.md` (default) or a folder `{slug}/index.md` when
per-stage artifacts accumulate. Slugs: lowercase, hyphens, no spaces. Task
state lives in the split-root state checkout (`state:` above) so stage
transitions never churn the code branch.

## Schema

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | SD-B32 stored ID from `status --next-id --id-seed <slug>` |
| `title` | string | Human-readable task name |
| `status` | enum | backlog, ideation, implementation, validation, done |
| `source` | string | Where the task came from (captain note, defect, audit) |
| `started` / `completed` | ISO 8601 | Boundary timestamps |
| `verdict` | enum | PASSED or REJECTED — set at final stage |
| `worktree` | string | Set on first worktree dispatch, cleared at terminal merge |
| `issue` / `pr` | string | External references |
| `design` | enum | `required` or `trivial-pass` — set during ideation, never empty at the ideation gate |

## Proof Policy

Inherited from the spacedock proof discipline; the four rules below are
binding in every stage report and every gate review.

1. **No prose-grep, and provenance decides independence.** A string match
   over an instruction file the model reads never proves a behavioral claim.
   A grep may serve as one-off evidence for an existence fact in a validation
   report; the same grep committed as a test is banned — it cannot fail. And
   a check counts as independent evidence only when what it inspects was not
   authored by the agent under review — a script over a self-written artifact
   is a self-issued stamp, not a gate.
2. **Evidence must be able to fail.** Each AC's cited evidence names the
   concrete change that would flip it. If the author cannot name the
   falsifying edit, the criterion does not count.
3. **Prove behavior by exercising it.** Output bytes, exit codes, resulting
   on-disk state, a browser actually driving the flow. Unit tests prove logic;
   they do not prove wiring. Seam-level claims need runtime or E2E evidence.
4. **Trace every mechanism to value.** Any new mechanism names the value AC it
   serves, the simplest alternative considered, and why that alternative is
   insufficient. A test harness orchestrates and observes the supported
   runtime; it never becomes a second implementation of the system under test.
5. **Behavior checks live at stage boundaries, never in the worker's inner
   loop.** Hooks that fire on every commit/edit inside a work session are
   limited to fast mechanical checks (format, lint, typecheck). Behavioral or
   corpus/consistency checks belong to the validation gate and CI: a
   must-pass check inside the inner loop turns "implement the behavior" into
   "make the check shut up", and the worker will drift the implementation —
   or the check's inputs — to satisfy it.

## Stages

Every stage report opens with a one-paragraph TL;DR; raw command output,
full diffs, and re-derivations go in collapsed or linked sections. A report
that reads like a session transcript costs reading budget nobody spends.

### `backlog` — capture (this is the todo queue)

Any idea, rabbit hole, defect, or captain note enters as a seed task file:
title, `source`, one-paragraph description. Target cost: under two minutes.
Capturing a seed triggers NO design work — the gate is where the captain
curates what advances. A seed too vague for the captain to triage is the only
"bad" here.

### `ideation` — one gate for design, plan, and acceptance

The single judgment-heavy stage. Flesh out the problem, decide the approach,
define acceptance criteria and the test plan. The gate reviews all of it at
once. Discipline clauses:

- **The captain authors scope; the agent never infers it for a
  rubber-stamp.** For non-trivial tasks, open ideation by asking the captain
  a few short scope questions (what gets worse without this; the time
  budget; what to keep if forced to cut; what we are happily NOT doing;
  which assumption could be wrong) and compose Problem/Scope from the
  answers verbatim. Skip only with a stated small-scope reason.
- **Appetite is a forcing budget.** Record a time/scope budget in the task
  body. When work is about to exceed it: cut scope (defer a sub-part to
  backlog) or park cleanly with re-enterable state and explicit open
  findings — never extend the budget silently, and never compress
  validation to land inside it. Size or budget variance is a drift signal
  to investigate, never a number to hit by padding artifacts or stripping
  tests.
- **One-sentence pre-mortem.** Before the gate: "if this ships exactly per
  spec and still fails, the most likely cause is ___" — pick one of {wrong
  problem, criteria that pass without delivering value, wrong framing lens,
  hidden assumption, over-conviction}. This is an orthogonal
  future-failure check the AC rubric structurally cannot generate.
- **Design determination is mandatory, never skipped.** Every task records
  `design: required` (UI, contract, interface, schema, or visual surface
  affected — attach the concrete design decision: wireframe reference, API
  shape, before/after) or `design: trivial-pass` with a one-line reason. An
  ideation gate presented without a design determination is returned unread.
- **Reverse-recovery audit before any "build/add X"** (brownfield default):
  assume the abstraction may already exist. Layer-trace the path (UI →
  contract → handler → domain → persistence → readback) and classify each
  layer WORKING / EXISTS_BROKEN / STUB / MISSING with file:line. Greenfield
  is allowed only after proof of absence (multi-strategy, multi-language
  search). A single broken seam means repair scoped to that seam, not a
  rebuild. Full procedure: `_mods/reverse-recovery-audit.md`.
- **AC are end-state properties with falsifiable proof.** Each AC names a
  property of the finished task (not a stage action) plus a `Verified by:`
  clause citing proof outside the task's own prose. At least one AC measures
  the end value the task exists for, against a baseline that can move the
  wrong way.
- **E2E-first acceptance.** When the task changes full-stack or user-visible
  behavior, at least one AC is verified by exercising the real flow end to
  end (browser drive, CLI invocation, service round-trip). Unit-only proof is
  insufficient for wiring claims. Skip only for docs/config/CI-only tasks,
  and record the skip reason.
- **Doc diff proposed here.** When the task changes behavior that PRODUCT.md,
  ARCHITECTURE.md, or any published doc describes, ideation proposes the
  concrete doc diff (before/after wording) in the task body. The gate reviews
  it; implementation applies it; validation verifies behavior diff and doc
  diff landed together.
- **Spike the riskiest unverified mechanism first**, and record the result in
  the task body — or record "no spike needed: {proven mechanisms relied on}"
  so the determination is auditable.

### `implementation` — build in a worktree, test-first

- **RED before GREEN, with evidence.** For each behavior: write the failing
  test, run it, record the RED evidence in the stage report (test name +
  failure output digest), then write the minimum code to pass. GREEN without
  recorded RED is treated by validation as unproven — tests written after the
  fact to confirm existing code do not count.
- **RED and GREEN close in the same session, and commit together.** Never
  commit failing tests as a handoff contract for a later worker: an agent
  handed a red suite optimizes for "make it green", and will drift the
  implementation to fit a possibly-wrong test — or the test to fit the
  implementation — instead of delivering the behavior. The RED record is
  stage-report evidence; committed tests arrive with the code that passes
  them. If a session must stop mid-loop, the unfinished RED work stays
  uncommitted and the stage report says exactly where the loop stopped.
- **Scoped tests in the loop, full suite once at the exit.** During the
  build loop run only the tests scoped to the behavior under change (file,
  module, or tagged subset). Run the full suite exactly once, after scoped
  tests are green, as the stage-exit regression check — not on every
  iteration.
- Minimal diff that satisfies the AC. No unrelated refactoring. Apply the doc
  diff approved at ideation in the same branch.
- The deliverable must be self-contained for a fresh validator: stage report
  says what was produced, where, and how to run it.

### `validation` — fresh eyes, adversarial by default

A fresh-context agent verifies the deliverable against the ideation AC. The
validator checks what was produced; it never finishes the work.

- Reproduce each AC's `Verified by:` clause; report PASS/FAIL per criterion
  with actual evidence (command output, screenshots, on-disk state) — never
  the implementer's self-report. Same execution order as implementation:
  scoped checks per AC first, one full-suite run at the end — a full-suite
  failure outside the diff's blast radius is reported as context, not
  debugged by the validator.
- **Review through distinct lenses**, scaled to the diff: correctness always;
  add silent-failure, security, or type-design lenses when the diff touches
  error handling, auth/input boundaries, or new types. (Use the globally
  installed reviewer agents, e.g. `pr-review-toolkit:code-reviewer`.)
- **Verify reviewer citations before acting on findings.** Check every cited
  `file:line` against the actual file — LLM reviewers fabricate plausible
  citations. If more than roughly a third of one reviewer's citations are
  wrong, discard that reviewer's entire round rather than triaging it. And
  when writing off a failure as pre-existing, prove it per failing line
  (blame against the change's commit range), never per file or surface.
- **Converge by naming residuals.** When a review round's findings stop
  being fixable defects and become a named class the chosen approach
  genuinely cannot solve, stop iterating: record the residual and its
  acceptance reason instead of opening another round. Chasing irreducible
  residuals is gold-plating dressed as rigor.
- **Cross-model gate before merge approval**: run one independent cross-model
  review of the diff (e.g. `/codex review`). A P1 finding is fixed or
  explicitly waived with a recorded reason at the gate — never silently
  dropped.
- Exercise the E2E AC in the real runtime when one exists.
- **Coverage is a ratchet, not a target.** The mechanical floor is **diff
  coverage**: lines added or changed by the task meet the repo bar
  (<X>% — set per repo, suggested 85 for new code) via the CI diff-coverage
  check, and repo-wide coverage never decreases from its recorded baseline.
  A red coverage check is fixed or explicitly waived at the gate with a
  recorded reason. Coverage percent is never an AC by itself —
  RED-before-GREEN evidence proves behavior; the percentage only catches
  untested seams the TDD loop missed.
- **Adversarial spot-check.** For one or two core behaviors, make a
  claim-breaking edit (revert a guard, flip a boundary) in a scratch copy and
  confirm the suite goes red. A suite that stays green under a claim-breaking
  edit is a hole — route back with that evidence.
- Rejection routes back to implementation (`feedback-to`) with concrete,
  file-anchored fixes. Two consecutive rejections on the same finding →
  escalate to the captain instead of a third round.
- **Every correction round carries a budget record.** Each rework round
  appends one entry: the round's actual effort against the ideation-declared
  estimate, the deviation, and the findings disposition. Past the declared
  tolerance, record a design-reset decision (back to ideation to re-cut)
  before opening any further round — the counter-based escalation above and
  this budget-based brake are independent circuit breakers. A round whose
  findings are all declined records `0 fixed` with every decline named:
  "nothing was found" and "everything found was declined" must never read
  alike.
- **Rework re-anchors on the source requirement.** On any route-back, the
  rework agent re-reads the original requirement and diffs it against the
  current ACs before touching code — rework loops naturally optimize
  against intermediate artifacts and silently drop original constraints.
  Any dropped constraint is restored or explicitly justified first.

### `done` — terminal

Merge after a passed validation gate (repo's merge policy: <PR to main / local
`--no-ff`>), set `completed` and `verdict`, archive the task. Record the
measurement ledger row (below) in the same transition.

- **Merge only on observed green CI for the exact HEAD.** A passing local
  suite, a static PR approval, or "CI was green earlier" never substitutes
  for a live CI run observed green on the commit being merged. A red or
  running check at merge time blocks the merge — no exceptions by memory.

## Judgment Escalation

Irreversible calls — schema, architecture, scope-cut, costly_no, anything
merge-governing — are never self-adjudicated by the working agent. Route to a
fresh-context engineering-judgment agent (`ship-flow:science-officer-em`) for
independent synthesis, add one cross-vendor pass (codex/gemini) when the call
is contested, and bring the captain a CONVERGED recommendation. The captain
rules; disagreement between seats goes to the captain, not to a vote.

## Canonical Docs Ownership

| File | Owner | Updated |
|------|-------|---------|
| PRODUCT.md / ARCHITECTURE.md | Task lifecycle (ideation proposes, implementation applies, validation verifies) | In the PR that changes the behavior |
| ROADMAP.md / roadmap indexes | Captain (or sprint Commander) | Sprint boundaries, strategy shifts — never tracks task state (that's a `status --where` query) |
| This README | Captain-approved revision | When ledger data says a clause needs tuning |

## Measurement Ledger

Every task that reaches `done` (or is abandoned after implementation started)
appends one row to `docs/dev/ledger.csv`:

```
task_id, slug, dispatches, rework_rounds, wallclock_hours, tokens_if_known, diff_coverage, escaped_defects_7d
```

`escaped_defects_7d` is back-filled when a defect traced to the task surfaces
within seven days of merge. This ledger is the experiment: it is compared
against the ship-flow historical baseline (006-line dispatch/veto records).
Pre-registered bar — this lean flow wins if it holds ≤60% of baseline tokens
and ≤70% wall-clock with no added Severity-1/2 escaped defects; complexity
(extra stages, skills, mechanisms) earns its way back only through this
ledger, never through argument.

## Task Template

```yaml
---
id:
title:
status: backlog
source:
started:
completed:
verdict:
worktree:
issue:
pr:
design:
---

## Problem

## Proposed approach

## Design determination

`required` (attach decision) or `trivial-pass — <reason>`.

## Acceptance criteria

**AC-1 — <end-state property>.**
Verified by: <reproducible check outside this file>. Falsified by: <the edit that would flip it>.

## Test plan

## Doc diff

<before/after wording for PRODUCT.md / ARCHITECTURE.md, or "none — no described behavior changes">

## Out of scope
```

## Commit Discipline

- Status changes commit at dispatch and merge boundaries (binary-owned).
- State commits are path-scoped per entity in the state checkout — never bare `git add -A`.
- Implementation commits land on the worktree branch; merge only after the validation gate passes.
