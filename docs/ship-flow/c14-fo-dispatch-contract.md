---
title: Align C14 with First Officer stage-entry transitions
status: design
source: blocker discovered while starting issue #20
started: 2026-07-14T08:07:52Z
completed:
verdict:
score:
worktree: .claude/worktrees/c14-fo-dispatch-contract
issue: "#30"
pr:
---

The First Officer owns stage entry and currently records it with `dispatch: <feature> entering <stage>`, while C14 recognizes only the completion-side `advance-stage.sh` commit signature. The mismatch makes a legitimate FO `draft -> shape` transition fail the invariant and shell-suite baseline before feature work starts.

## Acceptance criteria

**AC-1 — Legitimate FO stage entry is mechanically recognized.**
Verified by: a RED-first fixture covering `draft -> shape` through the canonical FO dispatch path passes after the fix.

**AC-2 — Manual status bypass remains blocked.**
Verified by: arbitrary or lookalike commit messages that hand-edit frontmatter status without a sanctioned transition receipt continue to fail C14.

**AC-3 — Entry and completion contracts are aligned.**
Verified by: the workflow/FO-facing process contract names the stage-entry receipt, C14 recognizes it narrowly, and completion-side `advance-stage.sh` enforcement remains intact.

**AC-4 — Dogfood baseline is restored without allowlists.**
Verified by: the current branch passes invariants, the shell suite, and Node tests without commit-hash grandfathering or a forged `advance-stage.sh` signature.

## Stage Report: execute

- DONE: RED-first regression covers a legitimate FO draft-to-shape dispatch and preserves a failing arbitrary manual mutation case
  Case 14 failed before implementation (expected 0, got 1); final targeted suite passes 18/18, including manual, malformed, wrong-stage, and whitespace-only-summary rejection cases.
- DONE: A narrow sanctioned stage-entry receipt is aligned across implementation, invariant documentation, and FO-facing workflow process without hash allowlists or forged advance-stage signatures
  Commit `f8fc638` accepts subject-only `dispatch|advance: <non-empty summary> entering <stage>` receipts only when every mutated entity after-status matches; completion-side `: advance status to ` remains unchanged.
- DONE: Targeted C14 tests plus the full invariant, shell, and Node suites are run and reported with exact results
  C14 targeted 18/18; `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103 exit 0; Node 79/79 exit 0; shellcheck and `git diff --check` clean.

### Summary

C14 now recognizes the First Officer's fresh-dispatch and same-worker-reuse stage-entry receipts while binding the named stage to the actual entity after-state. The repair keeps arbitrary status edits and receipt lookalikes blocked, preserves completion-side `advance-stage.sh` enforcement, and restores the dogfood invariant baseline without commit allowlists.
