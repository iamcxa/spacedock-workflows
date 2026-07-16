<!-- section:verify-report -->
# Make debrief a native post-merge ship closeout — Verify

<details>
<summary>Round 9 snapshot provenance</summary>

Cycle-8 feedback `fe3f0bf`; implementation/test `9e8cc8c`; execute artifacts `1149376`, `0781a83`;
metadata-only Verify entry `3543ded`. Current source/test blobs exactly equal `9e8cc8c` and the worktree began clean.
</details>

<!-- section:verify-check-manifest -->
### Verify Check Manifest

<details>
<summary>Fresh lane manifest</summary>

| Lane | Fresh evidence | Verdict |
|---|---|---|
| R8 direct destination binding | causal baseline, dual-Bash focused GREEN, direct multi-pushurl/invalid matrices | PASS for modeled cases |
| Git endpoint identity | nested remote, chained `pushInsteadOf`, provider-drift local probes | FAIL R9-B1/B2 |
| Recovery/compatibility | R7-R2, default, static/contracts, C1-C15, pinned status | PASS |
| Panels | general, silent/recovery, testing; corrected artifact cross-review | code BLOCKING; artifact PROCEED |
| External/RoboRev | excluded by Captain instruction | NOT RUN |
</details>
<!-- /section:verify-check-manifest -->

<!-- section:quality-gate -->
### Quality Gate

<details>
<summary>Scoped gate results</summary>

| Gate | Fresh result | Verdict |
|---|---|---|
| R8 focused | 50/50 on Bash 3.2 and 5.3 | PASS direct cases |
| Historical recovery | R7 19, R6 289, R4 29, R3 107, R2 13+23, default 198; all both shells | PASS |
| Contracts/static | TDD ledger 5, schema registry, syntax, ShellCheck, diff check, full C1-C15 | PASS |
| Endpoint semantics | three temporary-local Git probes disprove terminal/provider binding | FAIL |
</details>
<!-- /section:quality-gate -->

<!-- section:review-findings -->
### Review Findings

| ID | Severity | File:Line | Finding | Route/status |
|---|---|---|---|---|
| R9-B1 | BLOCKING | reconciler `:1132,1148,1208,1335` | A one-line token can name another remote or be rewritten again, so inspection and publication may fan out or hit different endpoints. | execute; VETO |
| R9-B2 | BLOCKING | reconciler `:1255,1335-1347,1358` | Destination is not persisted/provider-bound; terminal push self-assigns success and may ready the provider PR without re-querying its head. | execute; VETO |
| R9-W1 | WARNING | test `:1679,1766-1776,2066-2181` | Fixtures cover direct origin values, not nested aliases, rewrite chains, provider drift, or terminal fan-out. | with blockers |
| W2/W3/W4 | WARNING | prior citations retained | Path-swap TOCTOU, receipt scan, and review-scope fallback remain deferred hardening. | deferred |

<details>
<summary>Probe and panel evidence</summary>

- Baseline direct multi-pushurl: `rc=1`, A absent→seed, B competitor→competitor, `partial_mutation=yes`.
- Nested remote: origin resolves to one token `fanout`; `ls-remote` sees A absent; push returns 1 after A→seed while B stays competitor. Retry sees A exact and can continue provider lookup while B remains divergent.
- Rewrite chain: origin semantics target A, but passing the already-expanded A literal through Git again rewrites publication to B; inspection returned absent at A while B received the ref.
- Provider drift: provider A and rebound B started at the leased OID; terminal push advanced only B. Source then assigns the terminal OID in memory and can call `gh pr ready` without re-querying A.
- Three fresh reviewers independently returned BLOCKING with current-byte citations; all citations were spot-checked.

#### TDD Evidence Audit

Cycle 8 RED/GREEN is causal for direct multiple `remote.origin.pushurl` entries: frozen production failed 12 of 50 and current production passes 50/50 on both shells. It is insufficient for the broader endpoint contract because the nested/rewrite/provider-drift cases are absent. The five-record persisted ledger validates.

#### Reviewer Lens Matrix

| Source/lens | Owner | Scope/evidence | Verdict |
|---|---|---|---|
| DAC T1 landing-proof | verifier | exact resolver 94/94 | PASS |
| DAC T2 schema | verifier + execute evidence | schema registry/debrief and unchanged T2 suites | PASS |
| DAC T3 recovery | silent/recovery panel | fault/retry paths and three probes | BLOCKING |
| DAC T4 recursion/value | testing/recovery panel | optional PR discovery/publication/default dogfood | BLOCKING |
| DAC T5 compatibility | verifier | exact compatibility chain plus C1-C15 | PASS |
| general/type-design + maintainability | general reviewer | immutable two-source-file Cycle 8 diff | BLOCKING R9-B1; otherwise NO_FINDINGS |
| silent-failure | silent/recovery reviewer | seed/terminal/retry/provider convergence | BLOCKING R9-B1/B2 |
| testing | testing specialist | causal direct RED/GREEN and missing endpoint cases | BLOCKING R9-W1 |
| security | security specialist | option/ref/credential/eval boundary | NO_FINDINGS |
</details>

<details>
<summary>Nine complete required Verification Claim records</summary>

| claim_source | condition | metric_or_observable | threshold | smallest_disproving_surface | baseline | treatment | comparison | verdict | route_to |
|---|---|---|---|---|---|---|---|---|---|
| `other:snapshot` | current bytes judged | source/test blob OIDs | equal `9e8cc8c` | `git rev-parse HEAD:path` | implementation OIDs | current OIDs | exact equality | VERIFIED | proceed |
| `DC-2/DC-4/DC-6` | direct invalid origin configuration | local/endpoint/provider/bundle state | no effect, stable prompt | R8 focused case | pre-fix partial write | current 50/50 | direct cases closed | VERIFIED | proceed |
| `DC-2` | literal leaf seed missing/exact/race | seed push counts and remote OID | create once/skip/reject | R7/R8 seed matrix | unsafe ordinary push | leased leaf push | expected-absence CAS holds | VERIFIED | proceed |
| `DC-4` | literal leaf terminal publication | terminal push count/lease/ref | exact OID lease/full ref | R6/R8 terminal matrix | unbound ordinary push | leased leaf push | exact leaf semantics hold | VERIFIED | proceed |
| `DC-4/DC-6` | prior recovery paths | dual-shell assertion counts | every named matrix zero failures | R7-R2 suites | prior cycle failures | current suites | all named gates green | VERIFIED | proceed |
| `DC-3/DC-7` | schema/static/compatibility | exact commands and exit codes | all zero | TDD/schema/static/C1-C15 | execute evidence | fresh full chain | all gates green | VERIFIED | proceed |
| `DC-5/DC-8` | recursion/dogfood default | default suite assertions | 198/198 both shells | default reconciler suite | execute 198 | fresh 198 | exact equality | VERIFIED | proceed |
| `review:general/silent` | resolved token reused by Git | every actual endpoint ref | one non-reinterpretable endpoint | nested/rewrite probe | direct origin fix | token reused | fan-out/retarget remains | NOT VERIFIED | execute |
| `review:silent-failure` | retry/terminal provider convergence | provider head after leased push | persisted provider match and re-query=terminal | provider-drift probe | provider A old | rebound B terminal | provider A unchanged | NOT VERIFIED | execute |
</details>
<!-- /section:review-findings -->

<!-- section:uat -->
### UAT

mode: full-rerun; non-UI local CLI/Git correctness probes.

| DC | Verify Procedure | Execute 1st | Verify | Evidence |
|---|---|---|---|---|
| DC-1 | exact landing resolver suite | PASS 94 | PASS | fresh 94/94 |
| DC-2/DC-4/DC-5/DC-6 | reconciler full + focused recovery/probes | PASS 198 plus focused | FAIL R9-B1/B2 | default 198 both; direct R8 50 both; three disproving probes |
| DC-3 | debrief schema + C15 | PASS | PASS | fresh schema PASS and C15 through 23b |
| DC-7 | exact seven-command compatibility chain | PASS | PASS | todo 5, metadata 45, mergeable 115, map and C1-C15 PASS |
| DC-8 | default includes frozen dogfood/two-run no-op | PASS 198 | PASS | fresh default 198/198 both shells |
<!-- /section:uat -->

<!-- section:verify-knowledge-captures -->
### Knowledge Captures

- `[D2-candidate]` `git remote get-url` output is not necessarily a terminal endpoint: passing it back to Git can apply remote-name or URL-rewrite semantics again.
- `[D2-candidate]` A successful leased push is not provider convergence until the provider head is re-queried and matches the terminal OID.
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
  em_judgment: "Cycle 8 closes direct pushurl cardinality but not a non-reinterpretable, provider-bound publication endpoint."
  evidence_synthesis: ["dual-Bash direct 50/50 plus historical green", "nested/rewrite/provider-drift local probes and three blocking panels"]
  risk_tradeoff_call: "Retry can continue or ready a provider PR while another endpoint is divergent or the provider head never advanced."
  recommendation: "Return R9-B1/B2 plus coupled regressions to execute; preserve closed direct and R2-R7 claims."
  route: return
  confidence: high
  fo_boundary: "FO owns workflow mechanics; EM owns judgment and recommendation."
```
<!-- /section:science-officer-em-upward-report -->

<!-- section:verify-verdict -->
### Verdict

status: failed
stage_cost: dual-Bash focused/history matrices, static/contracts, three Git probes, three panels, artifact cross-review
quality: direct destination rejection passes; endpoint/provider identity fails
review: general, silent/recovery, and testing panels independently BLOCKING
stage_verdict: VETO — two required claims are NOT VERIFIED
cross_review_verdict: PROCEED — corrected artifact honestly records the code VETO
cross_review_coaching: Treat a Git repository argument as unresolved until its receive-pack endpoint and provider identity are proven.
captain_gate: PROMPT_CAPTAIN
blocking_issues: R9-B1, R9-B2
claim_records: required VERIFIED=7 NOT VERIFIED=2 INCONCLUSIVE=0; advisory VERIFIED=0 NOT VERIFIED=0 INCONCLUSIVE=0
auto_fixes: none — publication identity and regressions are execute-owned
started_at: 2026-07-16T01:51:25Z
completed_at: 2026-07-16T02:17:51Z
duration_minutes: 27
<!-- /section:verify-verdict -->

<!-- section:verify-verdict-metrics -->
### Metrics

status: failed
duration_minutes: 27
iteration_count: 9
claim_records_required_not_verified: 2
blocking_findings_count: 2
warning_findings_count: 4
runtime_checks_count: 27
<!-- /section:verify-verdict-metrics -->

<!-- section:panel-coverage -->
## Panel Coverage

- Tier B single-host panel; Captain excluded RoboRev/network/external review, so `cross_model: false`.
- General/type-design: BLOCKING 1; silent/recovery: BLOCKING 2; testing: BLOCKING 1; security: NO_FINDINGS.
- All outputs matched repo/branch/current source bytes and all cited lines were spot-checked.
- Pass ownership: worker ownership PASS; workflow_ci BLOCKING; type_design BLOCKING; silent_failure BLOCKING; test_adequacy BLOCKING; security NO_FINDINGS; cross_model_challenge DEGRADED by instruction; runtime_uat BLOCKING.
- PR Quality Score: 6/10. Code panel verdict: VETO; corrected artifact cross-review: PROCEED.
<!-- /section:panel-coverage -->

<!-- section:runtime-verification -->
### Runtime Verification

| Type | Command/result | Verdict |
|---|---|---|
| R8 direct | `feedback-r8-b1`: 50/50 both shells | PASS modeled cases |
| nested remote | one token, `ls-remote` A absent, push rc=1, A→seed/B unchanged | FAIL partial mutation |
| rewrite chain | expanded A inspected; passing A again publishes to B | FAIL endpoint mismatch |
| provider drift | leased push advances rebound B; provider A stays old | FAIL provider binding |
| history | R7 19; R6 289; R4 29; R3 107; R2 13+23; default 198, both shells | PASS |
| static/contracts | TDD/schema/syntax/ShellCheck/diff/C1-C15/pinned status | PASS |
<!-- /section:runtime-verification -->

<!-- section:stage-checklist -->
## Stage Report: verify

- DONE: Reproduce the original two-pushurl baseline and verify current direct multi/missing/malformed/unresolvable rejection before modeled effects.
- DONE: Re-run dual-Bash R8/R7-R2/default matrices, TDD/schema/static contracts, full C1-C15, pinned status, and three fresh panels.
- FAILED: A one-line destination remains reinterpretable and is not persisted/provider-bound; retries can partially publish or ready without provider convergence.
- GATE: Round 9 FAILED/PROMPT_CAPTAIN. No implementation, Review advance, external push, PR, merge, archive, todo, network, or RoboRev mutation occurred.
<!-- /section:stage-checklist -->

<!-- section:hand-off-to-review -->
### Hand-off to Review

- `verify_verdict`: failed; Review must not proceed.
- `blocking_issues`: [R9-B1 reinterpretable Git destination, R9-B2 unbound/unqueried provider destination].
- `canonical_docs_touched`: Execute touched `plugins/ship-flow/README.md`, `references/doc-sync-context.md`, `INVARIANTS.md`, and closeout/entity schemas; PRODUCT/ARCHITECTURE/ROADMAP remain intentionally Review-owned. Verify touched none; `render_fidelity_status`: not-applicable.
<!-- /section:hand-off-to-review -->

<!-- section:deferred-to-todo -->
## Deferred to TODO

Deferred to TODO: 0 emitted. R9-B1/B2 are Captain-gated; W2-W4 remain visible. No todo or external state was mutated.
<!-- /section:deferred-to-todo -->

<!-- /section:verify-report -->
