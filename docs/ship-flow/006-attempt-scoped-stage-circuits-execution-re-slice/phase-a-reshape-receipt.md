# Epic 006 Phase A Reshape Receipt

## Transaction Boundary

- Source HEAD: `548b3388400dd70651351b24f4e0ef537f2f4c38`.
- Direction: delegated autonomous reshape from the captain's recorded goal and
  failure lessons; no new captain questions were required.
- Phase: materialization and reversible readiness freeze only. No design,
  plan, implementation, runtime, test, CI, PR, branch, status, or verdict work.

## Trigger Evidence

PR #93 is `OPEN`, merge state `BLOCKED`, and explicitly **do not merge** at the
source HEAD. Its `ship-flow invariants` check failed five suites:
`test-attempt-scoped-stage-circuits-21.sh`,
`test-merged-pr-closeout-provider-pagination.sh`,
`test-stage-attempt-clock.sh`, `test-stage-attempt-history.sh`, and
`test-stage-attempt-route.sh`. This receipt records the failure; Phase A does
not repair or classify those suites as owned work.

The old decomposition also hid the end value behind helper-first scope. The
captain's unchanged bet is that the next post-ship dogfood must immediately
show more agent-native behavior. The replacement therefore proves one real
plan consumer, then its recovery, then execute adoption and one #21 UAT.

## Frozen Lane Snapshot

| Child | Live status | Original dependencies | Phase A dependencies |
|---|---|---|---|
| `006.1` | `ship` | `[]` | `[006-execute-attempt-generalization]` |
| `006.2` | `plan` | `[006.1]` | `[006.1, 006-execute-attempt-generalization]` |
| `006.3` | `plan` | `[006.2]` | `[006.2, 006-execute-attempt-generalization]` |
| `006.4` | `plan` | `[006.3]` | `[006.3, 006-execute-attempt-generalization]` |

Only these four dependency lines freeze the old lane. Their status, verdict,
PR, worktree, stage outputs, reports, implementation commits, and other
artifacts remain unchanged.

## Replacement DAG and Traceability

1. `006-plan-attempt-vertical` adopts the proven protocol/clock authority and
   the plan-integration value from old 006.1/006.4, but discards helper-first
   completion as sufficient proof: a real plan caller must consume it.
2. `006-plan-attempt-recovery` adopts old 006.2's crash-safe history/replay
   value, narrowed to one plan terminal contribution and zero duplicate
   dispatch.
3. `006-execute-attempt-generalization` adopts old 006.3's bounded route-out
   and the execute-consumer value from old 006.4. It keeps #21 as one-off UAT
   only and discards broad full-regression ownership, XFAIL/future-RED
   registries, and any dispatcher or shape-confirm fix from Epic 006.

No old product diff or evidence is deleted. "Discard" means the old
decomposition is not continuation authority; the preserved artifacts remain
available for evidence and selective adoption by the new children.

## Phase Boundary and Rollback

Phase B may start only after `006-plan-attempt-vertical` lands. Until then the
old 006.1-006.4 lane remains non-ready behind the final new child.

Rollback is one reversible Phase A transaction: revert the single commit that
adds this receipt; equivalently, delete the three new child folders, remove
their epic children/graph entries, restore the four dependency lines to the
original-dependencies column above, and delete this receipt. Do not rewrite
old statuses, verdicts, PR fields, or implementation artifacts during rollback.
