---
name: test-driven-development
description: Use when ship-flow plan, execute, or verify needs TDD, test-first discipline, or RED-before-GREEN evidence for code-bearing tasks.
---

# Ship-Flow Test-Driven Development

## Overview

This is ship-flow's built-in TDD fallback contract. `superpowers:test-driven-development` is an optional enhancer, not a dependency: adopter projects are not required to install superpowers for ship-flow to require test-first work.

Core rule: every non-exempt code task carries a RED/GREEN/REFACTOR artifact trail from plan through execute and verify.

## When to Use

Use this skill when:
- Writing `plan.md` tasks for implementation work.
- Executing a task that changes production code.
- Verifying whether execution actually followed test-first order.
- The local runtime lacks `superpowers:test-driven-development`.

Do not use it for docs-only/stage-artifact tasks, pure configuration, migrations validated by existing migration tooling, or pure refactors with existing coverage. Those tasks still need an explicit `TDD: skip -- <reason>`.

## Required Artifact

Each code-bearing task must include a `tdd_contract` block:

```yaml
tdd_contract:
  red_command: "<command that runs the new/changed failing test only>"
  expected_red_failure: "<the missing behavior or failing assertion expected before implementation>"
  green_command: "<command proving the new/changed test passes after implementation>"
  refactor_check: "<command to re-run after cleanup; may equal green_command>"
```

The command can be a repo test runner, a focused shell test, or a small executable repro. It must be runnable by execute and auditable by verify.

## Stage Responsibilities

| Stage | Responsibility |
|---|---|
| plan | Write the `tdd_contract` before implementation tasks are dispatched. |
| execute | Run `red_command` before production edits and record the expected RED failure; then implement minimally, run `green_command`, refactor only while green, and record evidence. |
| verify | Audit execute evidence. Missing RED-before-GREEN evidence is a finding with `route_to: execute` unless the task has a valid `TDD: skip` reason. |

## RED-Before-GREEN Evidence

Execute evidence must show:

1. `RED command`: command text and exit/failure snippet.
2. `Expected RED failure`: why the failure proves the behavior was missing.
3. `GREEN command`: command text and pass snippet after implementation.
4. `REFACTOR`: either "not needed" or the command re-run after cleanup.

If a test passes immediately during RED, stop and revise the test or the task. A passing RED command means it did not prove missing behavior.

## Optional Superpower Bridge

If `superpowers:test-driven-development` is available, load it and follow its stricter discipline for the implementation cycle. If it is unavailable, do not block solely on that absence; this ship-flow artifact contract remains authoritative.

## Common Mistakes

| Mistake | Correction |
|---|---|
| Listing `test` in `skills_needed` but no `tdd_contract` | Add the concrete RED/GREEN commands to the task. |
| Writing one broad "run all tests" command for RED | Use the smallest command that proves the intended behavior is missing. |
| Marking migration/docs/config as skip without reason | Add `TDD: skip -- <specific reason and alternate validation>`. |
| Verifier accepts green tests only | Verify RED-before-GREEN evidence, not just final pass state. |
