# Execute — C14 First Officer dispatch contract

## Execute Dispatch Manifest

| Task | Wave | Depends On | Owned Paths | Integration Owner | Dispatch Mode |
| --- | --- | --- | --- | --- | --- |
| T1 | W1 | — | C14 checker/test, `/ship` skill/routing test | executer | serial |
| T2 | W2 | T1 | C14 checker/test | executer | serial |
| T4 | W2 | T1 | completion helper/tests and six stage skills | executer | serial |
| T3 | W3 | T2 | C14 checker/test | executer | serial |
| T5 | W4 | T3, T4 | INVARIANTS, ARCHITECTURE, ROADMAP | executer | serial |

T2 and T4 had disjoint ownership and were eligible for W2 parallelism. The controller nevertheless serialized their full implementer→spec-review→quality-review loops to preserve the selected subagent-driven task discipline; later waves retained the planned dependency order.

## Execution Log

| Task | Status | RED evidence | GREEN / verification | Files | Commit |
| --- | --- | --- | --- | --- | --- |
| T1 | done | Cases 14/17 and two exact routing assertions failed before production | Cases 1–18; routing 16/16; bash-n; shellcheck | 4 planned paths | `817b115` |
| T2 | done | Cases 19/20/22/23/25 expected 1, got 0 | Cases 1–25; graph-first direct/feedback checks; bash-n; shellcheck | 2 planned paths | `0a17981` |
| T4 | done | helper design usage, design triple, ownership strings, and flat fallback failed | helper Cases 1–24; exact six triples; immediate-activation fixture; flat rollback | 9 planned paths | `b29ba95` |
| T3 | done | Cases 26/28–31 expected 1, got 0; Case 27 stayed green | Cases 1–31; parser/path scope; no Cases 32–45 | 2 planned paths | `fc48bc8` |
| T5 | done | TDD: skip — docs-only canonical sync | CAS patch-map, range audit, C14 and repository gates | 3 planned paths | `359ce25` |

Review fixes were test/lint-first: T4 added six portable hash assertions before normalizing completion snippets; T3 added a failing subdirectory Case 28 before top-rooting pathspecs; plain shellcheck reproduced SC1091 on both this branch and `origin/main` before the narrow suppression in `89914e3`.

## Issues Found

- `.claude/ship-flow/skill-routing.yaml` is absent. The approved plan already recorded no non-root folder guidance and a root context boundary, so execution used the plan-declared skills and logged this resolver warning.
- W2's T2 and T4 were disjoint but executed serially. This was a controller scheduling deviation from the plan's allowed parallelism, not a file-ownership conflict.
- T4 quality review found Linux-only `sha256sum` in completion snippets. Six snippets now use the repository's macOS fallback pattern; the unrelated ship PR-metadata hash remains unchanged.
- T3 quality review found cwd-relative Git pathspecs. Existing Case 28 now proves root and subdirectory invocation; all C14 pathspecs are top-rooted.
- Canonical review found the graph-gated body-table/no-`stage_outputs` compatibility path is ownerless. Canon now names it as a manual compatibility exception outside automated eligibility; Cases 8/22/23 and routing/stage-wiring tests pin the boundary. Retirement remains triggered by the second hit or next shape-confirm change.
- Execution exceeded the 30-minute reporting circuit breaker because mandatory per-task reviews and the 103-file shell suite remained active. No task or gate was dropped; duration is reported honestly below.

## Critical-Pass Self-Check Findings

No SQL/data-safety, race/concurrency, LLM trust-boundary, shell-injection, or enum/value-completeness finding remained after task review.

## Knowledge Captures

- **D1-confirmed:** FO entry and worker completion can activate in the same entity lifecycle when the entry subject is graph-bound and compatible-folder completion is status-idempotent.
- **D1-confirmed:** Git pathspecs in repository-wide invariants must use `top`; root-only fixtures can hide subdirectory bypasses.
- **D2-candidate:** retire the ownerless body-table compatibility exception when shape-confirm seeds `stage_outputs:`; keep #36–#38 as the separate migration, merge, and provenance boundaries.

## Execute UAT

| DC | Verify Procedure | Result | Evidence |
| --- | --- | --- | --- |
| DC-1 | `bash plugins/ship-flow/lib/__tests__/test-enforce-advance-stage.sh` | PASS | Cases 1–31, including canonical direct/feedback entries and negative lookalikes |
| DC-2 | `bash test-ship-unified-entry-routing.sh && bash test-stage-wiring.sh` | PASS | routing 16/16; exact entry/completion boundary, six triples, immediate next-ship sequence |
| DC-3 | targeted C14 plus forbidden Case/symbol grep | PASS | coverage stops at Case 31; no migration/layout/merge/provenance implementation |
| DC-4 | invariant + all shell tests + Node + shellcheck + diff checks | PASS | invariants; 103 shell files; Node 79/79; exact shellcheck; no-dangling; version triple 0.9.0 |

## Self-Check

- typecheck: N/A — shell/Markdown slice
- lint: PASS — bash-n, exact plain shellcheck, git diff check
- unit tests: PASS — C14 31/31, routing 16/16, helper 24/24, 103 shell files, Node 79/79
- qa-only: N/A — no UI files
- critical-pass lite: PASS

## Execute Report

status: passed
stage_cost: 5 task implementers, per-task spec/quality review, review-fix loops, independent cross-review round 1 VETO then round 2 PROCEED
started: 2026-07-14T10:07:59Z
completed: 2026-07-14T11:32:45Z
duration_minutes: 85
iteration_count: 4
task_count: 5
tasks_done: 5
tasks_blocked: 0
commit_count: 8
knowledge_captures: 3
reviewer_verdict: PROCEED round 2; round 1 truthfulness findings fixed in `42af061` and this artifact

### Metrics

status: passed
duration_minutes: 85
iteration_count: 4
task_count: 5
tasks_done: 5
tasks_blocked: 0
commit_count: 8

### Hand-off to Verify

- commits: `git log 4314d71..HEAD`; DC evidence cites `817b115`, `0a17981`, `b29ba95`, `fc48bc8`, `89914e3`, `359ce25`, and cross-review wording fix `42af061`.
- dc_status: DC-1 PASS; DC-2 PASS; DC-3 PASS; DC-4 PASS.
- deviations: disjoint W2 tasks were serialized by controller choice; T4 has a second review/gate-fix commit; cross-review wording required `42af061`; the stage exceeded 30 minutes; the final artifact-aware range audit permits this `execute.md` in addition to T5's pre-artifact allowlist.
- render_fidelity_evidence: N/A — non-UI entity.
- skills_needed_used: T1–T3 test/best-practices/TDD; T4 test/TDD/write-docs; T5 write-docs.
- context_read_receipts: none — plan resolver reported no non-root folder guidance; root AGENTS instructions and plan context were applied.
- stub_ack_log: none — `stub_flags: none`.
