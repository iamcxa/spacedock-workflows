<!-- section:verify-report -->
# Make debrief a native post-merge ship closeout — Verify

<details>
<summary>Round 8 snapshot provenance</summary>

Cycle-7 feedback: `b716f71`; implementation/test: `e3adebe`; execute artifacts: `f655167`, `c95b0c6`;
metadata-only Verify entry: `15ec239`. Current source/test blobs equal `e3adebe`.
</details>

<!-- section:verify-check-manifest -->
### Verify Check Manifest

| Lane | Fresh evidence | Verdict |
|---|---|---|
| R7 atomic seed CAS | causal RED, dual-Bash GREEN, single- and multi-destination probes | FAIL R8-B1 |
| R6-R2 history | recovery, binding, acquisition, native/squash, default matrix | PASS |
| Panels | general plus silent/testing/recovery, immutable two-file range | BLOCKING |
| External/RoboRev | excluded by Captain instruction | NOT RUN |
<!-- /section:verify-check-manifest -->
<!-- section:quality-gate -->
### Quality Gate

| Gate | Fresh result | Verdict |
|---|---|---|
| Causal RED | current tests + pre-fix production: 14/19 on both Bash versions | PASS evidence |
| R7 focused | 19/19 on Bash 5.3 and 3.2 | PASS single destination |
| Adjacent runtime | R6 279/279 both; R4 29/29 both; R3 107; R2 13+23; default 198 | PASS |
| Contracts/static | TDD 5; registry/schema; syntax; ShellCheck; diff; C1-C15; pinned launcher | PASS |
<!-- /section:quality-gate -->
<!-- section:review-findings -->
### Review Findings

| ID | Severity | File:Line | Finding | Route/status |
|---|---|---|---|---|
| R8-B1 | BLOCKING | reconciler `:1158,1174-1178` | Named remote can fan out and partially mutate destinations. | execute; gate FAIL |
| R8-W1 | WARNING | test `:824,1939-1964,1988` | Single-origin fixture cannot observe partial multi-pushurl success. | with R8-B1 |
| W2 | WARNING | `apply-closeout-bundle.sh:232` | Same-user path-swap TOCTOU remains possible. | deferred |
| W3 | WARNING | reconciler `:648` | Receipt/entity discovery remains additive `O(R+E)`. | deferred |
| W4 | WARNING | `review-scope.sh:21` | Positional fallback can select `HEAD~1`. | deferred |

<details>
<summary>Atomicity probe and TDD audit</summary>

The create-only lease is correct for one push endpoint. With two local `origin` pushurls, endpoint A lacked the ref and
endpoint B held the competitor. The same command returned `1`, but A became the seed while B retained the competitor:
`partial_mutation=yes`. Aggregate failure therefore does not prove exact remote preservation.

#### TDD Evidence Audit

Frozen-production RED was exactly 14 pass / 5 fail on both shells: competitor preservation, no later provider action,
expected-absence lease, full-ref destination, and no provider create. Current GREEN is 19/19 on both shells. The ledger
validates five records and RED precedes GREEN, but the test's one-origin model omits multi-destination fan-out.
</details>

<details>
<summary>Required claim records</summary>

| Source / condition | Smallest disproof | Verdict / route |
|---|---|---|
| Cycle-7 test is causal | pre-fix production does not fail as declared | VERIFIED / proceed |
| one-endpoint expected-absence CAS rejects a competitor | competitor ref changes | VERIFIED / proceed |
| failed publication preserves every configured destination | any endpoint changes after nonzero push | NOT VERIFIED / execute |
| true missing ref creates the exact seed once | absent case fails or wrong OID lands | VERIFIED / proceed |
| exact pre-existing seed skips publication | retry invokes seed push | VERIFIED / proceed |
| single-endpoint race preserves checkpoint/provider state | bytes or provider action changes | VERIFIED / proceed |
| terminal publication retains its OID lease | terminal lease changes | VERIFIED / proceed |
| R2-R6 and scoped contracts remain green | named matrix or gate fails | VERIFIED / proceed |
</details>
<!-- /section:review-findings -->
<!-- section:uat -->
### UAT

mode: local CLI/Git correctness probes and proportional historical regression; non-UI.

| DC | Verify | Evidence |
|---|---|---|
| DC-1/DC-5 PASS | landing/acquisition closures retained | R3 107; R2 13+23; unchanged paths |
| DC-2/DC-4/DC-6 FAIL | failed seed push can partially mutate configured destinations | two-pushurl probe |
| DC-3/DC-7 PASS | schema/static/compatibility | registry, debrief schema, C1-C15 zero |
| DC-8 PASS | frozen dogfood and recursion/value evidence retained | panel fresh default 198; unchanged paths |
<!-- /section:uat -->
<!-- section:verify-knowledge-captures -->
### Knowledge Captures

- `[D2-candidate]` A lease is atomic per receive-pack destination, not across every pushurl behind a remote name.
<!-- /section:verify-knowledge-captures -->
<!-- section:render-fidelity -->
### Render Fidelity

render_fidelity_status: not-applicable — `affects_ui: false`.
<!-- /section:render-fidelity -->
<!-- section:science-officer-em-upward-report -->
### Science Officer (EM) Upward Report

```yaml
science_officer_em_upward_report:
  subject: {entity: ship-stage-debrief-closeout, stage: verify, report_kind: verify-synthesis}
  em_judgment: "Cycle 7 fixes one-endpoint CAS, but a named remote can still fail after partial publication."
  evidence_synthesis: ["dual-Bash RED 14/5 to GREEN 19/19", "two local pushurls: rc=1, A=seed, B=competitor"]
  risk_tradeoff_call: "Aggregate push failure cannot satisfy the explicit zero-remote-mutation recovery contract."
  recommendation: "Return only R8-B1 plus a multi-pushurl causal regression; preserve closed R2-R7 claims."
  route: return
  confidence: high
  fo_boundary: "FO owns workflow mechanics; EM owns judgment and recommendation."
```
<!-- /section:science-officer-em-upward-report -->
<!-- section:verify-verdict -->
### Verdict

status: failed
stage_cost: causal dual-shell RED/GREEN, adjacent runtime, static/contracts, two panels, two Git probes
quality: single-destination repair passes; multi-destination failure preservation fails
review: general and silent/testing panels independently BLOCKING on R8-B1
cross_review_verdict: VETO — one required claim is NOT VERIFIED
cross_review_coaching: Model every destination addressed by a named remote when failure must preserve remote state.
captain_gate: PROMPT_CAPTAIN
blocking_issues: R8-B1
claim_records: required VERIFIED=7 NOT VERIFIED=1 INCONCLUSIVE=0; advisory VERIFIED=0 NOT VERIFIED=0 INCONCLUSIVE=0
auto_fixes: none — Git publication logic and its regression are execute-owned
started_at: 2026-07-15T18:23:39Z
completed_at: 2026-07-15T18:38:22Z
duration_minutes: 15
<!-- /section:verify-verdict -->
<!-- section:verify-verdict-metrics -->
### Metrics

status: failed
duration_minutes: 15
iteration_count: 8
claim_records_required_not_verified: 1
blocking_findings_count: 1
warning_findings_count: 4
runtime_checks_count: 16
<!-- /section:verify-verdict-metrics -->
<!-- section:panel-coverage -->
## Panel Coverage

- Tier B by Captain instruction; no RoboRev, network, or external reviewer.
- General/maintainability and silent/testing/recovery panels: BLOCKING R8-B1; remaining scope NO_FINDINGS.
- All cited lines were spot-checked. The recovery panel explicitly corrected its initial single-endpoint blind spot.
- Pass ownership: worker ownership PASS; workflow_ci BLOCKING; type_design BLOCKING; silent_failure BLOCKING;
  test_adequacy BLOCKING; security NO_FINDINGS; cross_model_challenge DEGRADED by instruction; runtime_uat BLOCKING.
<!-- /section:panel-coverage -->
<!-- section:runtime-verification -->
### Runtime Verification

| Type | Command/result | Verdict |
|---|---|---|
| causal TDD | pre-fix production with current R7 test: 14/19 both shells | expected RED |
| R7 single endpoint | focused matrix: 19/19 both shells; CAS reject/create probe | PASS |
| multi-pushurl | A absent, B competitor; push rc=1; A=seed, B=competitor | FAIL partial mutation |
| adjacent/history | R6 279 both; R4 29 both; R3 107; R2 13+23; default 198 | PASS |
| static/contracts | syntax, ShellCheck, diff, TDD, registry/schema, C1-C15, pinned status | PASS |
<!-- /section:runtime-verification -->
<!-- section:stage-checklist -->
## Stage Report: verify

- DONE: Verify causal RED, single-endpoint CAS, exact checkpoint/provider behavior, terminal lease, and adjacent R2-R6.
- DONE: Run both reviewer panels, all citation checks, scoped static/contracts, schema routing, and pinned launcher status.
- FAILED: A multi-pushurl remote can accept the seed at one endpoint before another rejects, then return nonzero.
- GATE: Round 8 FAILED/PROMPT_CAPTAIN. No implementation, receipt/status, Review dispatch, external push, PR, merge,
  archive, todo, or network mutation occurred.
<!-- /section:stage-checklist -->
<!-- section:hand-off-to-review -->
### Hand-off to Review

- `verify_verdict`: failed; review must not proceed.
- `blocking_issues`: [R8-B1 multi-pushurl partial seed publication].
- `canonical_docs_touched`: none in Verify; `render_fidelity_status`: not-applicable.
<!-- /section:hand-off-to-review -->
<!-- section:deferred-to-todo -->
## Deferred to TODO

Deferred to TODO: 0 emitted. R8-B1 is Captain-gated; W2-W4 remain visible. No todo or external state was mutated.
<!-- /section:deferred-to-todo -->

<!-- /section:verify-report -->
