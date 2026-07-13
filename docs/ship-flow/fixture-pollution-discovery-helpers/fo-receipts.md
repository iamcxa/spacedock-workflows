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

## fo-20260713T110244Z-verify-proceed-post-isolation-audit

```yaml receipt
receipt_id: fo-20260713T110244Z-verify-proceed-post-isolation-audit
created_at: "2026-07-13T11:02:44Z"
actor: "first-officer"
transition:
  from: verify
  to: ship
  trigger: verify-proceed-post-isolation-audit
decision: self-approved
verdict: PROCEED
rule_source: plugins/ship-flow/skills/ship-verify/SKILL.md
evidence:
  verify_artifact: verify.md
  claim_records: "required VERIFIED=11 NOT VERIFIED=0 INCONCLUSIVE=0"
  clean_uat_contract: "faaad26 + 4e0c53d + d7be3a4; DC-1..DC-9 reproducible, DC-10 static/no-replay"
  clean_scope: "six frozen paths byte-identical; shared check-invariants blob 5d21b50 with only three #20 hunks beyond origin/main"
  cross_review_verdict: PROCEED
  science_officer_em: "review closeout REVISE condition resolved; bounded static confirm PASS"
  acceptance_receipt: "original frozen commit 1b3871f8; sole launch rc0 stdout193 stderr0 routes0; replay forbidden"
preconditions:
  - name: verify.md remains passed with eleven required claims
    status: pass
  - name: clean DC-10 new-line-only audit is truthful
    status: pass
  - name: independent seven-factor review permits ship
    status: pass
  - name: isolated branch excludes unrelated C14 and entity scope
    status: pass
  - name: immutable sole-run receipt remains intact
    status: pass
blocker_scan:
  missing_verify_evidence: none
  failed_static_recheck: none
  unresolved_review_veto: none
  receipt_integrity_issue: none
  prompt_captain_required: false
open_decisions: []
next_action: "ship-final preflight after review artifact satisfies C15"

```
