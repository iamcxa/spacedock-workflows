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

## fo-20260713T110924Z-verify-proceed-final-coherence

```yaml receipt
receipt_id: fo-20260713T110924Z-verify-proceed-final-coherence
created_at: "2026-07-13T11:09:24Z"
actor: "first-officer"
transition:
  from: verify
  to: ship
  trigger: verify-proceed-final-coherence
decision: self-approved
verdict: PROCEED
rule_source: plugins/ship-flow/skills/ship-verify/SKILL.md
evidence:
  verify_artifact: verify.md
  claim_records: "required VERIFIED=11 NOT VERIFIED=0 INCONCLUSIVE=0"
  final_coherence: "945bff9 aligns Quality Gate and Knowledge Capture with approved DC-10 isolation exception"
  clean_scope: "six frozen paths byte-identical; shared check-invariants blob 5d21b50 with only three #20 hunks beyond origin/main"
  cross_review_verdict: PROCEED
  science_officer_em: "final review gate conditions resolved; bounded static confirmation PASS"
  acceptance_receipt: "original frozen commit 1b3871f8; sole launch rc0 stdout193 stderr0 routes0; replay forbidden"
preconditions:
  - name: verify.md remains passed with eleven required claims
    status: pass
  - name: Quality Gate and DC-10 use one coherent isolation model
    status: pass
  - name: independent review and EM conditions are resolved
    status: pass
  - name: immutable sole-run receipt remains intact
    status: pass
blocker_scan:
  stale_seven_path_claim: none
  failed_static_recheck: none
  unresolved_review_veto: none
  receipt_integrity_issue: none
  prompt_captain_required: false
open_decisions: []
next_action: "compose and gate the single PR body"

```

## fo-20260713T122105Z-ship-hold-post-acceptance-correction

The receipts above remain historical evidence at their recorded heads. This
receipt supersedes only their current-head six-path identity predicate.

```yaml receipt
receipt_id: fo-20260713T122105Z-ship-hold-post-acceptance-correction
created_at: "2026-07-13T12:21:05Z"
actor: "first-officer"
transition:
  from: ship
  to: ship
  trigger: post-acceptance-agy-correction
decision: em-adjudicated
verdict: HOLD
rule_source: plugins/ship-flow/skills/ship/SKILL.md
evidence:
  prior_head: "904599d; agy BLOCK on density S2 healthy no-match and missing coverage"
  correction_head: "fc6ef1e4f4509f9a1cc080b861cd9f7a8d35f514"
  acceptance_closure: "discovery-exclusions ce0447c9792b31038b912daa21deaf97bb5a8748 + discover-adopter 2c183a1cd5c178f3f8f2c5fe7432acfacd96becc; identical at 1b3871f8 and fc6ef1e"
  invariant_isolation: "check-invariants 5d21b50ad24faa6b052a43e0964a333627a3df61 remains applicable"
  density_blobs: "implementation e5c9e12f3c205b1c7364bdadfff69946361fb882 -> 7098af017e1632d2c54b6a3be9a9911464cc11c3; test fe67604f6f705f43287d4a140b0331cd07bf041d -> f6de6e98bf712231f11d2a7185f2f21a256e4178"
  focused_red: "suite rc1; primary rc2 expected0/no vacuum/129-byte stderr; --is-high rc2 expected1/129-byte stderr; operational grep-error guard passed"
  focused_green: "Bash syntax rc0; density 51 OK / 0 FAIL with healthy no-match and real grep-error contracts separated"
  science_officer_em: "code/test repair fc6 closes agy findings 1-2; density suite is now 51/51; signal trap remains accepted nonblocking."
  acceptance_receipt: "sole discover-adopter --root=. launch at 09:39:05Z; rc0 stdout193 stderr0 routes0; density excluded"
  coherence_amendment: "DC-10 static closure audit targets final HEAD after evidence correction; no acceptance replay"
preconditions:
  - name: helper and discover-adopter acceptance closure unchanged
    status: pass
  - name: post-acceptance density repair is bounded and focused GREEN
    status: pass
  - name: repository-root acceptance replay count remains zero
    status: pass
  - name: final agy review at correction/evidence head
    status: pending
  - name: current-head CI
    status: pending
blocker_scan:
  unresolved_local_code_finding: none
  accepted_signal_warning: "combined EXIT/INT/TERM trap; nonblocking"
  final_agy: pending
  current_head_ci: pending
  prompt_captain_required: false
open_decisions: []
next_action: "FO reruns final agy and current-head CI; merge only if both pass"
no_replay_boundary: "never run, emulate, reconstruct, or indirectly invoke repository-root discovery"

```
