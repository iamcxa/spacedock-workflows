---
tid: shaped-child-created-off-graph-sharp
captured_at: 2026-07-17T10:25:15Z
status: pending
domain: dx
guess_files: [plugins/ship-flow/lib/shape-confirm.sh, plugins/ship-flow/bin/check-invariants.sh, docs/ship-flow/README.md]
suggest_done_type: code
entity: null
start_after: "issue #46 merges"
---

**Follow-up to start AFTER issue #46 merges.**

**Related:** existing entity `shape-confirm-instance-awareness` (ROADMAP later) already flags "write legacy status `sharp` (3 sites)" as one symptom of a broader instance-awareness refit. This todo is the specific, #46-evidenced consequence — the C14-blocking of child advancement — and may fold into that entity rather than ship standalone.

`shape-confirm.sh` creates shaped-children with `status: sharp`, but this workflow's README stage graph declares `shape` (there is NO `sharp` state). So any CHILD entity's first status advance is an off-graph, undeclared transition that the C14 invariant (`entity-status-via-advance-stage-only`) blocks — a shaped-child cannot legally advance through the pipeline. It only surfaces for children (not top-level pitches, which are created at `shape` and are on-graph).

Discovered during #46: child `6.1` `sharp -> plan` was flagged by C14; the branch history had to be rebuilt with the child created at `shape` and traversing `shape -> design -> plan -> execute` with canonical FO stage-entry receipts.

Fix direction: align shape-confirm's child template `status:` to the declared graph (`shape`, matching the parent pitch), OR declare a `sharp` state / `sharp -> shape` edge in the workflow. Prefer aligning child creation to the declared graph. Confirm existing `sharp` children (e.g. `2.1`) migrate cleanly.

Likely files: `plugins/ship-flow/lib/shape-confirm.sh` (child template ~line 337), `plugins/ship-flow/bin/check-invariants.sh` (C14 transition graph / `_workflow_transition_allowed_at_rev`), `docs/ship-flow/README.md` (stages).
