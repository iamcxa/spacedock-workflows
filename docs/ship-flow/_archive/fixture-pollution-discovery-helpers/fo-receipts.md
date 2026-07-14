# FO Receipts

## fo-20260713T101049Z-verify-proceed-auto-advance

```yaml receipt
receipt_id: fo-20260713T101049Z-verify-proceed-auto-advance
created_at: "2026-07-13T10:10:49Z"
actor: "first-officer"
transition:
  from: verify
  to: verify
  trigger: verify-proceed-auto-advance
decision: self-approved
verdict: PROCEED
rule_source: plugins/ship-flow/skills/ship-verify/SKILL.md
evidence:
  verify_artifact: verify.md
  claim_records: "required VERIFIED=11 NOT VERIFIED=0 INCONCLUSIVE=0"
  cross_review_verdict: PROCEED
  science_officer_em: "final_verify PROCEED high confidence; blocker none"
  acceptance_receipt: "sole invocation rc0 stdout193 stderr0 routes0; replay forbidden"
preconditions:
  - name: verify.md exists and has status passed
    status: pass
  - name: required claims verified
    status: pass
  - name: cross-review verdict permits advance
    status: pass
  - name: Science Officer EM final verify gate permits advance
    status: pass
  - name: immutable sole-run receipt audit is intact
    status: pass
blocker_scan:
  missing_verify_md: none
  missing_hand_off_to_review: none
  required_not_verified: none
  invalid_required_inconclusive: none
  veto: none
  prompt_captain_required: false
open_decisions: []
next_action: "record verify stage status"

```
