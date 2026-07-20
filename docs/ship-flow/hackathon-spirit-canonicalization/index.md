---
title: Document hackathon #2 process and learnings
status: design
appetite: small
issue: "#86"
started: 2026-07-20T02:56:25Z
worktree: .worktrees/mini-fo-hsc
---

Capture and archive hackathon-2 debrief findings, timeline, scope decisions, and EM-drive lessons into canonical process documentation (flow README updates, ticketing discipline, time-budget enforcement mechanics). Update ROADMAP milestone markers and close archival todos. Timing: post-Wave-4 closeout, prerequisite for next-cycle retrospective.

## Stage Report: design

- DONE: Read shape.md + design stage definition; confirmed trivial-pass criteria
  No contract grammar / schema / CLI / SKILL section changes — prose-only additions to existing docs.
- DONE: Check A1 — INVARIANTS.md current state for time-box rules
  `grep -n "time_budget\|75%\|brake\|time.box" plugins/ship-flow/INVARIANTS.md` → no matches; A1 confirmed (INVARIANTS is the FO-contract surface, carries numbered Principle process contracts through 17).
- DONE: Check A2 — docs/ship-flow/README.md task-template current state
  `grep -n "time_budget\|budget" docs/ship-flow/README.md` → no matches; Feature Template (line 249) + Field Reference (line 94) are the two coordinated edit points.
- DONE: Shell tests pinning relevant text
  `time_budget` is ALREADY a live field: scheduler-runner-adapter.sh derives dispatch timeout from it; test-scheduler-runner-adapter.sh pins `2h30m`→9000s + edge cases. No test pins the INVARIANTS/docs-README PROSE being added. doc-coupling-map does not couple either target file.
- DONE: Wrote design.md with verdict PROCEED, target files, contract delta, test surface, hand-off
  docs/ship-flow/hackathon-spirit-canonicalization/design.md.

### Summary

Trivial-pass PROCEED. Docs-only: AC-1 → INVARIANTS.md time-box prose, AC-2 → docs/ship-flow/README.md `time_budget` template slot + field row, AC-3 satisfied by landing in existing canon. Load-bearing finding: `time_budget` frontmatter already exists and is honored by the scheduler (`derive_timeout_sec`), so the AC-2 template slot must use the parseable `<N>h<N>m` format (e.g. `2h30m`) — flagged for plan. No test moves and no new test vectors needed; no test pins the added prose and neither target file is a doc-coupling srcGlob.
