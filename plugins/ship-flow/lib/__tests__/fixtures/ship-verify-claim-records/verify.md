<!-- section:verify-output -->
# Verify Output Fixture

<!-- section:quality-gate -->
### Quality Gate

#### Verification Claim: focused claim-record test fails before guidance exists

| Field | Value |
|---|---|
| claim_source | `quality-gate:test-ship-verify-claim-records` |
| condition | verifier guidance is checked by the focused shell test |
| metric_or_observable | test process exits non-zero before the claim-record contract exists |
| threshold | exit code is non-zero for RED and zero for GREEN |
| smallest_disproving_surface | `bash plugins/ship-flow/lib/__tests__/test-ship-verify-claim-records.sh` |
| baseline | missing guidance in `plugins/ship-flow/skills/ship-verify/SKILL.md` |
| treatment | current verifier guidance after execute edits |
| comparison | field and mapping greps compare required terms against the guidance |
| verdict | `VERIFIED` |
| route_to | `proceed` |
<!-- /section:quality-gate -->

<!-- section:review-findings -->
### Review Findings

#### Verification Claim: blocking review finding routes to execute

| Field | Value |
|---|---|
| claim_source | `review:general-external-reviewer` |
| condition | reviewer cites an execute-introduced blocking defect |
| metric_or_observable | file:line citation and reproduced command output |
| threshold | defect must be absent or fixed before verify can pass |
| smallest_disproving_surface | reviewer citation plus local test transcript |
| baseline | parent commit without the execute diff |
| treatment | execute branch with the cited change |
| comparison | treatment introduces the failing behavior relative to baseline |
| verdict | `NOT VERIFIED` |
| route_to | `execute` |
<!-- /section:review-findings -->

<!-- section:uat -->
### UAT

#### Verification Claim: advisory measurement is inconclusive but non-blocking

| Field | Value |
|---|---|
| claim_source | `other:advisory-format-check` |
| condition | advisory artifact is unavailable but not required for acceptance |
| metric_or_observable | optional screenshot path is missing |
| threshold | not applicable: advisory-only evidence |
| smallest_disproving_surface | verify artifact inventory |
| baseline | not applicable: no prior artifact required |
| treatment | current verify artifact inventory |
| comparison | inconclusive because the optional artifact was not requested |
| verdict | `INCONCLUSIVE` |
| route_to | `follow-up` |
<!-- /section:uat -->

<!-- section:verdict -->
### Verdict

status: failed
claim_records: required VERIFIED=1 NOT_VERIFIED=1 INCONCLUSIVE=0; advisory VERIFIED=0 NOT_VERIFIED=0 INCONCLUSIVE=1
<!-- /section:verdict -->
<!-- /section:verify-output -->
