<!-- section:verify-report -->
# Make debrief a native post-merge ship closeout — Verify

<details>
<summary>Round 4 snapshot provenance</summary>

Implementation snapshot: `9b3be77..60f59d9`; production repairs: `54a4a9a`, `8d1ac64`; valid metadata-only Verify entry: `a535179`. Verification and panels were pinned to that immutable bundle.
</details>

<!-- section:verify-check-manifest -->
### Verify Check Manifest

| Lane | Fresh evidence | Verdict |
|---|---|---|
| R3 source acquisition | true main-only/post-GC direct, optional, OPEN/MERGED receipt replay; foreign-CWD dry-run; collision/signals/remotes | PASS for acquisition; FAIL for full foreign-CWD optional/replay |
| Mechanical/contracts | focused + aggregate, Bash 3.2/5.3, schema/domain, static, pinned launcher, C1–C15 | PASS |
| General/testing/schema panel | immutable 9b3be77..60f59d9 source/test/handoff review | BLOCKING |
| Recovery panel | interrupted after timeout; no result used | DEGRADED |
| External/RoboRev | excluded by Captain instruction; not invoked | NOT RUN |
<!-- /section:verify-check-manifest -->

<!-- section:quality-gate -->
### Quality Gate

| Gate | Fresh result | Verdict |
|---|---|---|
| TDD + schema domain | ledger `status=pass records=5`; registry validate/resolve `status=ok`; intent 21/21, entity 34/34, ship 7/7 | PASS |
| Landing / receipt / bundle | 94/94 both shells; 85/85; 78/78 both shells | PASS |
| Reconciler | R3 107/107 both shells; R2 13/13 + 23/23; default 198/198 both shells; direct 200/200; optional 179/179; PR40/41 141/141; recursion 124/124 | PASS |
| Compatibility / static | exact compatibility chain; Bash syntax; ShellCheck; Python compile; diff hygiene; C1–C15 | PASS |
| Pinned launcher | `~/.local/share/spacedock/0.25.0-pre1/spacedock` contract 3; status read with `--workflow-dir docs/ship-flow` | PASS |
<!-- /section:quality-gate -->

<!-- section:review-findings -->
### Review Findings

| ID | Severity | File:Line | Finding | Route/status |
|---|---|---|---|---|
| R4-B1 | BLOCKING | `merged-pr-closeout-reconciler.sh:624,1170,1182,1250`; test `:1016-1041,1105-1108` | Receipt-first `gh pr view` and optional `gh pr list/create/ready` lack `--repo`/repo-root binding. Foreign-CWD coverage exits at dry-run before these calls; the real unbound command fails outside Git. | execute; Captain gate FAIL |
| R4-W1 | WARNING | test `:742-764` | Fake `gh` accepts PR queries without asserting `--repo`, so it does not regression-lock provider repository binding. | test hardening with R4-B1 |
| W2 | WARNING | `apply-closeout-bundle.sh:232` | Same-user path-swap TOCTOU remains possible after static path checks. | deferred hardening |
| W3 | WARNING | `merged-pr-closeout-reconciler.sh:629` | Receipt/entity discovery remains additive `O(R+E)` scanning. | performance follow-up |
| W4 | WARNING | `review-scope.sh:21` | Positional-range helper can fall back to `HEAD~1`; verifier used the explicit immutable manifest. | verifier tooling follow-up |

#### TDD Evidence Audit

T1–T4 retain observable RED/GREEN history and fresh GREEN commands; T5 retains its valid documentation exemption. R3 acquisition fixes are GREEN, but the new foreign-CWD optional/replay cross-product is absent and R4-B1 routes to execute.

<details>
<summary>Required claim records</summary>

| Source | Condition / observable | Smallest disproof | Baseline → treatment | Verdict / route |
|---|---|---|---|---|
| scoped gates | every named command exits zero | any nonzero/failure | execute report → fresh round 4 | VERIFIED / proceed |
| DC-1/DC-6 legacy | active done/PASSED without native proof rejects unchanged | HEAD/archive/receipt mutation | round-2 bypass → 13/13 | VERIFIED / proceed |
| DC-1/DC-5 proof | squash IDs are Git-rederived and caller-propagated | forged IDs pass/argument absent | forgery → 85/85 + 23/23 | VERIFIED / proceed |
| DC-1/2/4/6 acquisition | main-only and post-GC direct/optional/replay reacquire exact provider objects | provider OID unavailable | round-3 blocker → 107/107 both shells | VERIFIED / proceed |
| provider location | every GitHub PR operation is bound from foreign CWD | unbound `gh` requires cwd repo | dry-run PASS → real command rc 1 | NOT VERIFIED / execute |
| ROADMAP identity | only cell zero identifies the entity | later-cell identity accepted | any-cell bug → negative suites | VERIFIED / proceed |
| young root | squash root succeeds; speculative rebase rejects stably | exit 128/lost base | crash → 94/94 both shells | VERIFIED / proceed |
| terminal projection | one owner/full archive/postcommit/W1/no duplicates | lost byte/duplicate/rollback | prior blockers → bundle/direct/optional/dogfood | VERIFIED / proceed |
</details>
<!-- /section:review-findings -->

<!-- section:uat -->
### UAT

mode: full CLI rerun plus main-only/GC/signal/location challenge; no UI/API server applies.

| DC | Verify Procedure | Execute 1st | Verify | Evidence |
|---|---|---|---|---|
| DC-1 | landing proof and source acquisition | PASS | PASS | 94/94 and R3 107/107 both shells |
| DC-2/DC-4/DC-6 | direct/optional/recovery from supported caller locations | PASS | FAIL | optional/replay GitHub operations are unbound outside Git cwd |
| DC-3 | debrief schema + C15 | PASS | PASS | compatibility and C1–C15 green |
| DC-5 | sentinel/identity validation | PASS | PASS | forged/tampered/multiple cases reject |
| DC-7 | exact compatibility chain | PASS | PASS | chain exits zero |
| DC-8 | frozen PR40/41 twice | PASS | PASS | 141/141, byte/hash no-op |
<!-- /section:uat -->

<!-- section:verify-knowledge-captures -->
### Knowledge Captures

- `[D2-candidate]` Repository binding must cover every provider call, not only discovery; a foreign-CWD dry-run does not prove post-checkpoint optional/replay operations.
<!-- /section:verify-knowledge-captures -->

<!-- section:render-fidelity -->
### Render Fidelity

render_fidelity_status: not-applicable — `affects_ui: false`.
<!-- /section:render-fidelity -->

<!-- section:verify-verdict -->
### Verdict

status: failed
stage_cost: parallel mechanical lanes plus one completed and one timed-out read-only panel
quality: deterministic acquisition, recovery, schema, static, and compatibility gates pass
review: VETO on R4-B1; recovery panel degraded without softening the blocker
cross_review_verdict: VETO — executable evidence, quality, DC adequacy, reverse-audit, and D3/D4 coverage fail
cross_review_coaching: Exercise location independence through real optional and receipt-first paths, not only the pre-side-effect dry-run.
captain_gate: PROMPT_CAPTAIN
uat: DC-2/DC-4/DC-6 fail the foreign-CWD optional/replay boundary
blocking_issues: R4-B1
claim_records: required VERIFIED=7 NOT VERIFIED=1 INCONCLUSIVE=0; advisory VERIFIED=0 NOT VERIFIED=0 INCONCLUSIVE=0
auto_fixes: none — provider/recovery logic is execute-owned
started_at: 2026-07-15T14:52:00Z
completed_at: 2026-07-15T15:04:06Z
duration_minutes: 12
<!-- /section:verify-verdict -->

<!-- section:verify-verdict-metrics -->
### Metrics

status: failed
duration_minutes: 12
iteration_count: 4
claim_records_required_not_verified: 1
blocking_findings_count: 1
warning_findings_count: 4
runtime_checks_count: 32
<!-- /section:verify-verdict-metrics -->

<!-- section:panel-coverage -->
## Panel Coverage

- Tier: B by Captain instruction; RoboRev/external review not invoked. General/testing/schema panel: 0 PASS / 1 WARN / 1 BLOCKING. Recovery panel: timed out and was interrupted.
- Pass ownership: verify_agent_worker_ownership PASS; workflow_ci PASS; type_design BLOCKING; silent_failure BLOCKING; test_adequacy BLOCKING; security WARNING; cross_model_challenge DEGRADED; runtime_uat BLOCKING; domain_intent BLOCKING.
- PR Quality Score: non-PASS. Cross-model: NO; degradation cannot soften the required NOT VERIFIED claim.
<!-- /section:panel-coverage -->

<!-- section:runtime-verification -->
### Runtime Verification

CLI preflight: Bash 3.2/5.3, Python, Git, ShellCheck, pinned Spacedock available. No UI/API dev server applies.

| DC | Type | Command | Result | Verdict |
|---|---|---|---|---|
| DC-1/2/4/6 | cli/git | `SHIP_FLOW_CLOSEOUT_CASE=feedback-r3-b1` under both shells | `107 passed, 0 failed` each | PASS acquisition |
| DC-2/4/6 | cli/provider | exact unbound `gh pr view 141 --json ...` from fresh non-Git cwd | rc 1, `fatal: not a git repository` | FAIL location |
<!-- /section:runtime-verification -->

<!-- section:stage-checklist -->
## Stage Report: verify

- DONE: Pin round 4 to `9b3be77..60f59d9` at metadata-only `a535179`; rerun full mechanical, contract, static, pinned-launcher, and C1–C15 evidence.
- DONE: Verify cycle-3 source acquisition itself end to end: true main-only and post-GC direct/optional/OPEN/MERGED replay, provider OIDs, collision, real HUP/INT/QUIT/TERM, mixed-case remotes, and mutation residue all pass on both shells.
- DONE: Reconfirm R2 and historical closures: native-proof gate, Git-derived squash proof, ROADMAP cell zero, young root, one owner, full archive, postcommit recovery, and W1 remain closed.
- FAILED: Optional and receipt-first GitHub operations remain caller-CWD-dependent; the focused foreign-CWD test stops before them.
- GATE: Captain Verify gate FAIL/PROMPT_CAPTAIN. No FO receipt/status/review/push/PR/merge/archive/todo/remote mutation occurred.
<!-- /section:stage-checklist -->

<!-- section:hand-off-to-review -->
### Hand-off to Review

- `verify_verdict`: failed; review must not proceed.
- `blocking_issues`: [R4-B1 unbound foreign-CWD optional/receipt GitHub operations].
- `canonical_docs_touched`: none in Verify; execute-owned docs/schema were checked.
- `render_fidelity_status`: not-applicable.
<!-- /section:hand-off-to-review -->

<!-- section:deferred-to-todo -->
## Deferred to TODO

Deferred to TODO: 0 findings emitted. R4-B1 is a Captain-gated blocker; R4-W1 and W2–W4 remain visible follow-ups. No todo or remote state was mutated.
<!-- /section:deferred-to-todo -->

<!-- /section:verify-report -->
