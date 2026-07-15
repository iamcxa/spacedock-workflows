<!-- section:verify-report -->
# Make debrief a native post-merge ship closeout — Verify

<details>
<summary>Round 5 snapshot provenance</summary>

Implementation snapshot: `63a47a3..f5e9dbc`; production repair: `eba76c1`; metadata-only Verify entry: `0ef493b`. Verification and panels were pinned to that immutable bundle.
</details>

<!-- section:verify-check-manifest -->
### Verify Check Manifest

| Lane | Fresh evidence | Verdict |
|---|---|---|
| R4 repository binding | five call-site audit; foreign-CWD optional + OPEN/MERGED replay; negative repo/PR/OID/count | PASS; R4-B1/R4-W1 CLOSED |
| Historical recovery | R3 107/107 both shells; R2 13/13 + 23/23; landing 94/94; receipt 85/85; bundle 78/78 | PASS |
| Provider failure recovery | injected `gh pr list/create/ready` exit 71 after durable boundaries | FAIL |
| Panels | general/testing/schema PASS; recovery BLOCKING | FAIL |
| External/RoboRev | excluded by Captain instruction; not invoked | NOT RUN |
<!-- /section:verify-check-manifest -->

<!-- section:quality-gate -->
### Quality Gate

| Gate | Fresh result | Verdict |
|---|---|---|
| R4 focused | 29/29 on Bash 5.3 and 3.2 | PASS |
| Proportional regression | R3 107/107 both; R2 13/13 + 23/23; landing 94/94; receipt 85/85; bundle 78/78 | PASS |
| Static/contracts | both Bash syntax; ShellCheck; diff hygiene; C1–C15 | PASS |
| Pinned launcher | `0.25.0-pre1`, contract 3; status with explicit workflow dir remains `verify` | PASS |
<!-- /section:quality-gate -->

<!-- section:review-findings -->
### Review Findings

| ID | Severity | File:Line | Finding | Route/status |
|---|---|---|---|---|
| R5-B1 | BLOCKING | `merged-pr-closeout-reconciler.sh:1190,1202,1271`; test `:783-797` | `gh pr list/create/ready` failures raw-exit without stable report; list leaves 1 local commit, create 1 + remote write, ready 2 + remote write. | execute; Captain gate FAIL |
| W2 | WARNING | `apply-closeout-bundle.sh:232` | Same-user path-swap TOCTOU remains possible after static checks. | deferred hardening |
| W3 | WARNING | `merged-pr-closeout-reconciler.sh:648` | Receipt/entity discovery remains additive `O(R+E)` scanning. | performance follow-up |
| W4 | WARNING | `review-scope.sh:21` | Positional-range fallback can select `HEAD~1`; verifier used the immutable manifest. | tooling follow-up |

R4-B1/R4-W1 are closed: repository discovery is repo-root-bound; implementation/closeout view, list, create, and ready bind authoritative `--repo`; receipt repository comparison and the strict fake reject drift. R5-B1 is separate and does not reopen R2/R3.

#### TDD Evidence Audit

T1–T4 retain observable RED/GREEN history and fresh GREEN commands; T5 retains its documentation exemption. R4 success behavior is GREEN, but provider-failure recovery has no regression and violates T4's unchanged-tree/stable-stop contract.

<details>
<summary>Required claim records</summary>

| Source / condition | Smallest disproof | Verdict / route |
|---|---|---|
| scoped gates exit zero | any named gate fails | VERIFIED / proceed |
| active legacy terminal requires native proof | mutation or bypass | VERIFIED / proceed |
| squash proof is Git-rederived/caller-propagated | forged IDs pass | VERIFIED / proceed |
| main-only/post-GC acquisition is bounded and residue-free | exact objects unavailable/residue | VERIFIED / proceed |
| all five PR calls bind authoritative repository | missing/wrong `--repo` accepted | VERIFIED / proceed |
| provider failures stop stably without unsafe residue | exit 71 yields no report and durable partial state | NOT VERIFIED / execute |
| ROADMAP cell-zero and young-root rules hold | later-cell/crash accepted | VERIFIED / proceed |
| one owner/full archive/postcommit/W1/no duplicates | lost byte/duplicate | VERIFIED / proceed |
</details>
<!-- /section:review-findings -->

<!-- section:uat -->
### UAT

| DC | Verify procedure | Verdict | Evidence |
|---|---|---|---|
| DC-1/DC-5 | landing, identity, acquisition, forged/tampered negatives | PASS | 94/94; R3 107/107 both shells |
| DC-2/DC-4/DC-6 | foreign-CWD optional + receipt replay and provider interruptions | FAIL | success 29/29 both; injected list/create/ready raw-exit with residue |
| DC-3/DC-7 | schema/static/compatibility/C1–C15 | PASS | all selected gates zero |
| DC-8 | frozen PR40/41 historical closure | PASS | retained execute proof and unaffected code paths |
<!-- /section:uat -->

<!-- section:verify-knowledge-captures -->
### Knowledge Captures

- `[D2-candidate]` Binding provider identity is necessary but insufficient: every provider failure after a durable checkpoint needs a stable routed result and resumable predicate.
<!-- /section:verify-knowledge-captures -->

<!-- section:render-fidelity -->
### Render Fidelity

render_fidelity_status: not-applicable — `affects_ui: false`.
<!-- /section:render-fidelity -->

### Science Officer (EM) Upward Report

```yaml
science_officer_em_upward_report:
  subject: {entity: ship-stage-debrief-closeout, stage: verify, report_kind: verify-synthesis}
  em_judgment: "Repository binding is repaired, but provider failure recovery still violates the durable-boundary contract."
  evidence_synthesis: ["R4 29/29 both shells", "injected list/create/ready exit 71 leaves no report and 1/1/2 local commits; create/ready change remote refs"]
  risk_tradeoff_call: "Proceeding would accept externally visible partial state without a stable recovery reason."
  recommendation: "Return only R5-B1 to execute; preserve every closed R2-R4 claim."
  route: return
  confidence: high
  fo_boundary: "FO owns workflow mechanics; EM owns judgment and recommendation."
```

<!-- section:verify-verdict -->
### Verdict

status: failed
quality: repository binding, acquisition, schema, static, and proportional gates pass; provider failure recovery fails
review: general panel PASS/NO_FINDINGS; recovery panel BLOCKING on R5-B1
cross_review_verdict: VETO — required provider-failure claim is NOT VERIFIED
captain_gate: PROMPT_CAPTAIN
blocking_issues: R5-B1
claim_records: required VERIFIED=7 NOT VERIFIED=1 INCONCLUSIVE=0
auto_fixes: none — provider/recovery logic and tests are execute-owned
completed_at: 2026-07-15T15:40:00Z
<!-- /section:verify-verdict -->

<!-- section:verify-verdict-metrics -->
### Metrics

iteration_count: 5
blocking_findings_count: 1
warning_findings_count: 3
runtime_checks_count: 15
<!-- /section:verify-verdict-metrics -->

<!-- section:panel-coverage -->
## Panel Coverage

- Tier B by Captain instruction; no RoboRev/external review. General/testing/schema: PASS/NO_FINDINGS. Recovery: BLOCKING.
- Pass ownership: worker ownership PASS; workflow/static PASS; type/design PASS; test adequacy BLOCKING; silent failure BLOCKING; recovery/runtime BLOCKING; domain intent BLOCKING.
<!-- /section:panel-coverage -->

<!-- section:runtime-verification -->
### Runtime Verification

| Type | Result | Verdict |
|---|---|---|
| foreign-CWD success | R4 29/29 both Bash versions | PASS |
| acquisition/history | R3 107/107 both; R2 13/13 + 23/23 | PASS |
| injected provider failures | list `rc=71/local=1/remote=no`; create `71/1/yes`; ready `71/2/yes`; all `report=NONE` | FAIL |
<!-- /section:runtime-verification -->

<!-- section:stage-checklist -->
## Stage Report: verify

- DONE: Close R4-B1/R4-W1 with authoritative five-call binding and strict foreign-CWD coverage on both shells.
- DONE: Reconfirm R2/R3 acquisition, signals, collision, mixed-case, no-residue, native/squash, identity, archive, and recovery closures.
- FAILED: Provider list/create/ready interruptions lack stable routing and leave durable partial state.
- GATE: Captain Verify gate FAIL/PROMPT_CAPTAIN. No implementation, FO receipt/status, review, push, PR, merge, archive, todo, or remote mutation occurred.
<!-- /section:stage-checklist -->

<!-- section:hand-off-to-review -->
### Hand-off to Review

- `verify_verdict`: failed; review must not proceed.
- `blocking_issues`: [R5-B1 provider list/create/ready failure routing and partial durable state].
- `canonical_docs_touched`: none in Verify; `render_fidelity_status`: not-applicable.
<!-- /section:hand-off-to-review -->

<!-- section:deferred-to-todo -->
## Deferred to TODO

Deferred to TODO: 0 emitted. R5-B1 is Captain-gated; W2–W4 remain visible. No todo or remote state was mutated.
<!-- /section:deferred-to-todo -->

<!-- /section:verify-report -->
