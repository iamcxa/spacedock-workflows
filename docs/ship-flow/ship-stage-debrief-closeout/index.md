---
id: ""
title: "Make debrief a native post-merge ship closeout"
status: shape
pattern: pitch
appetite: medium-batch
affects_ui: false
design_required: true
contract_decision_required: true
source: "Captain directive 2026-07-15; PR #40/#41 dogfood closeout"
started: 2026-07-15T03:30:16Z
---

Productize the manual PR #40/#41 closeout as `ship-stage-debrief-closeout`.

After an implementation PR is merged, one bounded FO post-merge cycle must use GitHub's real `mergedAt` and landing facts to produce the final debrief and compact ship receipt, advance `ship -> done` with `PASSED`, archive the entity, move the ROADMAP row to Shipped, and optionally create one closeout PR. A closeout PR must be mechanically classified so its own merge cannot recurse into another closeout.

## Captain Bet

When this ships, the captain expects a merged implementation PR to reach a debriefed, archived done state with its real landing SHA within one FO post-merge closeout cycle. If not, this pitch was wrong about the Layer 1 claim that debrief belongs to the ship lifecycle rather than an ad-hoc session ritual.

## Required design questions

1. Pre-merge may prepare only a skeleton or intent; final debrief evidence must use post-merge `mergedAt` and the true landing SHA, never a rebase-rewritten PR-head SHA.
2. Runtime fixtures must cover rebase merge, squash merge, and merge commit, with reliable first/last landing commits even when main moves concurrently.
3. Final `ship.md` keeps the C15 cap and existing `pr:` number/body confirmation invariants. Terminal state, archive, and ROADMAP writes must be atomic or have an explicit crash-resume checkpoint.
4. Closeout classification must be a mechanical sentinel, not title guessing; startup, idle, and merge reruns must be idempotent.
5. Missing PR mirrors, missing ship.md, partial archive, or an already-updated ROADMAP must safely resume or fail closed with stable reasons; incoherent archives must never silently pass.
6. Preserve full debrief reconciliation/todo digest and the existing rule that todo body counts exclude balanced `<details>` content. Do not change C15 caps without separate captain evidence and approval.

## Acceptance criteria

- **AC-1 Landing evidence:** Rebase, squash, and merge-commit runtime fixtures produce the correct `mergedAt` plus first/last landing commit and never retain an invalid PR-head SHA.
- **AC-2 One-cycle closeout:** One startup/idle cycle after the implementation PR reaches MERGED produces the final debrief, final ship receipt, done/PASSED, archive, and ROADMAP Shipped outcome.
- **AC-3 Idempotency and recovery:** Repeating closeout at least twice creates no duplicate debrief, ROADMAP row, archive, or PR; every partial-state fixture safely resumes or fails closed with a stable reason.
- **AC-4 Recursion guard:** Merging the optional closeout PR does not create another closeout, proven mechanically rather than by prose.
- **AC-5 Compatibility:** Existing ship-final PR-body binding, persist-pr-metadata, C14, C15, todo accounting, and canonical-doc invariants remain green.
- **AC-6 Dogfood:** A PR #40/#41 regression fixture reproduces the final manually reconciled state without hand-editing index.md, ship.md, or ROADMAP.md.

## Scope boundaries

- Do not redo completed #20/#22/#28.
- Do not include #21 shape-confirm-instance-awareness.
- Do not touch C14 or RoboRev orphan worktrees.
- Do not post or modify upstream issues #24-#27.
- Do not hardcode Slack, Linear, or any specific task manager into core.

## Shape instructions

- Run the riskiest landing-SHA/range probe before composing the proposal.
- Default to `medium-batch`, `design_required: true`, and `contract_decision_required: true` unless evidence disproves them.
- Produce the shape artifact, sharpened ACs, explicit assumptions, one pre-mortem, and the ROADMAP row.
- Use runtime fixture evidence ahead of prose. Implementation workers later must follow TDD with observable RED before GREEN.
- Stop at the shape captain gate. Never self-approve.
