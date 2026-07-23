# Epic 006 Phase B Supersession Disposition

## Transaction Boundary

- Source: `origin/main`; transaction base:
  `7740836760f280a2b19fb181e3c5275edd36b524`.
- The Phase A receipt remains unchanged as the historical source-HEAD snapshot.
- Phase B supersedes continuation authority only. It starts no replacement
  implementation and dispatches no recovery, generalization, or legacy 006.2
  work.

## Active Replacement DAG

| Child | Disposition | Dependency and retained evidence |
|---|---|---|
| `006-plan-attempt-vertical` | Remains active: `status=done`, `verdict=PASSED`, `completed=2026-07-23T05:07:22Z` | No dependencies; PR #94 and all artifacts retained. It is not archived because recovery depends on it and active DAG closure must stay valid. |
| `006-plan-attempt-recovery` | Held at schema-valid `status=sharp` | Depends only on `006-plan-attempt-vertical`; worktree and PR remain empty. |
| `006-execute-attempt-generalization` | Held at schema-valid `status=sharp` | Depends only on `006-plan-attempt-recovery`; worktree and PR remain empty. |

The shipped `ship-epic` classifier treats only `design` or `plan` with empty
worktree and PR as fresh. `sharp` is undispatchable/in-flight, so recovery
remains held until the separate wave-control feature lands. No cross-epic
dependency is created.

## Superseded Children

| Child | Final disposition | Replacement and archive disposition |
|---|---|---|
| `006.1` | `status=done`, `verdict=PASSED`, `completed=2026-07-23T05:07:23Z`; only live worktree ownership is cleared. PR #93 and all stage outputs and artifacts are retained. | Product contribution entered main through PR #94 lineage; only continuation authority is superseded. The whole folder is archived. |
| `006.2` | At `2026-07-23T05:19:50Z`: `status=done`, `verdict=REJECTED`, empty stage outputs, and no invented started, PR, or implementation record. | Superseded before implementation by `006-plan-attempt-recovery`. The whole folder is archived. |
| `006.3` | At `2026-07-23T05:19:50Z`: `status=done`, `verdict=REJECTED`, empty stage outputs, and no invented started, PR, or implementation record. | Superseded before implementation by `006-execute-attempt-generalization`. The whole folder is archived. |
| `006.4` | At `2026-07-23T05:19:50Z`: `status=done`, `verdict=REJECTED`, empty stage outputs, and no invented started, PR, or implementation record. | Its plan value was absorbed by the passed vertical, its execute value moved to generalization, and broad regression/XFAIL ownership was discarded. The whole folder is archived. |

GitHub recorded PR #93 as merged by ancestry after PR #94 landed; head 548b338 is contained in PR #94 head 6a5eb78 and therefore in main via merge commit 7740836. PR #93 has no independent merge commit.
