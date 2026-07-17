---
title: C14 accepts the FO feedback-stage receipt
kind: traceability-note
parent-issue: "#30"
---

New traceability doc, not a workflow entity — no `status:` field, never run through
workflow stages, C14-exempt by construction (new file, no parent status).

## Problem

`check_entity_status_via_advance_stage_only()` (`plugins/ship-flow/bin/check-invariants.sh`)
recognized only two First Officer transition receipts: `dispatch:`/`advance: … entering
<stage>`. It did not recognize the FO feedback-routing receipt
(`feedback: <summary> <rejected-stage> cycle <N> to <target-stage>`), even though the
feedback-to edge itself is graph-legal. Every real feedback-routing commit — a legitimate
FO operation — was rejected as an unsanctioned status mutation.

## Why

Sibling branch `spacedock-ensign/ship-stage-debrief-closeout` produced 12 real
`feedback: ship-stage-debrief-closeout … cycle N to execute` commits that main's
un-extended C14 FAILs. Feedback routing is not a bypass; it is the same FO authority
that owns stage entry (Principle 15 Contract 1), applied to the declared `feedback-to`
edge. The gap blocked that branch's C14 and would block all future FO feedback routing.

## What

Ported the two proven helpers from the sibling branch (`_commit_has_fo_feedback_stage_receipt`,
`_entity_has_fo_feedback_cycle_record`) plus their dependency `_valid_utc_rfc3339_timestamp`
(absent from main) onto main's checker structure, reusing main's existing
`_frontmatter_status_at_rev_path`. Added a `feedback:*` arm to the `case "$subject" in`
block, evaluated only after main's graph-gate validation (unchanged ordering). The receipt
binds every field: `target_stage == after_status`, `rejected_stage == before_status`, cycle
match, `captain_decision == fix`, a valid UTC RFC3339 `routed_at`, and
`verify_artifact == <rejected-stage>.md@<7-40 lowercase hex>` — dropping any one bind turns a
forged `feedback: … to <anystage>` subject into an authority leak. Documented as a Contract 1
variant in `plugins/ship-flow/INVARIANTS.md` Principle 15. Added positive, forged, and
graph-illegal-edge test cases to `plugins/ship-flow/lib/__tests__/test-enforce-advance-stage.sh`.

## Evidence

- Before (main's un-extended checker, `0b21e95`): all 12 real
  `feedback: ship-stage-debrief-closeout … cycle N to execute` commits on
  `spacedock-ensign/ship-stage-debrief-closeout` FAIL C14 (exit 1).
- After (extended checker): the same 12 commits, in their real branch history, PASS
  (`OK C14 entity-status-via-advance-stage-only`, exit 0) — reproduced under both bash 3.2
  and bash 5.3.
- `plugins/ship-flow/lib/__tests__/test-enforce-advance-stage.sh`: 42/42 cases pass,
  including 11 new feedback-stage cases (1 positive, 6 forged-record negatives, 1
  non-feedback-edge negative, 3 malformed-grammar negatives).
- Parent contract: C14 FO dispatch contract issue #30 (Principle 15).
