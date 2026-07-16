<!-- section:verify-report -->
# Make debrief a native post-merge ship closeout — Verify

<details>
<summary>Round 11 frozen-head provenance</summary>

Captain feedback `d7be3e2`; Cycle 10 implementation `e094f4e`; execute report `9f9398d`; verify entry `81c1e14`. Verification froze `81c1e1473d80134fd0c4afb96db626ddd5bcf002` on `spacedock-ensign/ship-stage-debrief-closeout`; worktree began clean. Baseline evidence is the committed Cycle 10 causal record (`d7be3e2` 7/9); treatment is fresh current-byte execution below.
</details>

<!-- section:verify-check-manifest -->
### Verify Check Manifest

| Lane | Owner/input | Verdict |
|---|---|---|
| Current CLI/runtime | verifier; R10, R9-R2, default, receipt, landing, optional, dogfood | PASS exercised cases |
| Recovery/type design | general + silent/recovery reviewers; `d7be3e2..e094f4e` | BLOCKING 3 |
| Test adequacy/data integrity | testing reviewer + TDD/DC reverse audit | BLOCKING gaps align with defects |
| Static/canonical | verifier; syntax, ShellCheck, Python, diff, registry, C1-C15/C14 | PASS |
| UI/browser/external | `affects_ui: false`; network/remotes/RoboRev excluded | N/A by scope |
<!-- /section:verify-check-manifest -->

<!-- section:quality-gate -->
### Quality Gate

| Gate | Fresh result | Verdict |
|---|---|---|
| Cycle 10 treatment | R10 120/120 on Bash 3.2 and 5.3 | PASS modeled cases |
| Signal/provider recovery | R5/R6 289/289 serial foreground on both shells | PASS modeled cases |
| Neighbor envelope | R9 59, receipt 92, R8 50, R7 19, R3 107, R2 13+23, default 198, landing 94, optional 179, dogfood 141; both shells | PASS |
| Static/process | dual syntax, ShellCheck, Python compile, diff check, TDD ledger 5, registry, C1-C15 and focused C14 | PASS |
| Authoritative terminal recovery | mature-main, provider-OID, and signal-temp proofs below | FAIL |

<details>
<summary>Required Verification Claim records</summary>

| claim_source | condition | observable / threshold | smallest disproving surface | baseline | treatment / comparison | verdict | route_to |
|---|---|---|---|---|---|---|---|
| `other:snapshot` | frozen bytes are authoritative | exact HEAD/status/clean start | `rev-parse`, pinned status, `git status` | `81c1e14`, verify | unchanged during evidence collection | VERIFIED | proceed |
| `DC-2/DC-4/DC-6` | Cycle 10 endpoint/predecessor regressions fail closed | zero unintended effects; all assertions pass | R10 dual-shell suite | `d7be3e2`: 7/9 | current: 120/120 twice | VERIFIED | proceed |
| `DC-4/DC-5/DC-6` | bounded recovery accepts a unique nearby awaiting predecessor on mature main | recovery rc=0 when candidate is `HEAD^1` | exact-function 41-commit repro; `plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh:1517-1551` | expected D3/D4 recovery | rc=2 with `candidate-1.json` already found | NOT VERIFIED | execute |
| `DC-5/DC-6` | landed terminal bytes bind the provider merged head | validated terminal SHA equals `headRefOid` | `plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh:761-797` control flow | provider OID is authority | predecessor path prefers unchecked local ref | NOT VERIFIED | execute |
| `DC-4/DC-6` | every validator temp is signal-owned | no scoped TMPDIR residue after HUP/INT/QUIT/TERM | TERM injection at `:1324`; scan sites `:697,:724` | R6 later seam cleans | exit 143 leaves `file.FCYFIT` | NOT VERIFIED | execute |
</details>
<!-- /section:quality-gate -->

<!-- section:review-findings -->
### Review Findings

| ID | Severity | File:Line | Finding | Route/status |
|---|---|---|---|---|
| R11-B1 | BLOCKING | `plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh:1517-1551`; `plugins/ship-flow/lib/__tests__/test-merged-pr-closeout-reconciler.sh:2653,2773-2776` | The 34th history sentinel increments `scanned` to 33 and returns 2 even after a unique valid predecessor was found within the first 32; mature main therefore cannot terminal-noop. | execute; VETO |
| R11-B2 | BLOCKING | `plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh:761-797,1494-1506` | With a predecessor, landed recovery validates the local deterministic ref but never requires its SHA to equal provider `headRefOid`; exact provider-bound terminal proof is absent. | execute; VETO |
| R11-B3 | BLOCKING | `plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh:25-64,697,724,1324-1327` | New receipt/preflight validator files use bare `mktemp` outside all EXIT/signal-owned roots; injected TERM exits 143 and leaves residue. | execute; VETO |

<details>
<summary>TDD evidence audit and independent panel synthesis</summary>

`validate-tdd-ledger.py` returns `status=pass records=5`; plan T1-T4 RED-before-GREEN and T5 skip rationale are recorded. R10 repairs have causal RED/GREEN, but the mature-main acceptance case, provider-OID divergence, and signal-at-validator cases are absent, so execute evidence does not disprove R11-B1..B3. Three fresh read-only lanes independently cited and spot-checked current bytes: general/type-design/maintainability found B1-B3; silent/recovery reproduced all three; testing/data-integrity confirmed B3 and the missing history branches. Every cited location was read at ±2 lines. No UI/domain-registry drift or canonical-doc contradiction was found; schema registry validates and routed skills are empty.
</details>
<!-- /section:review-findings -->

<!-- section:uat -->
### UAT

mode: full-rerun — non-UI CLI/Git with temporary local repositories and fake provider/transport only.

| DC | Verify procedure | Verify | Evidence |
|---|---|---|---|
| DC-1/DC-3/DC-7/DC-8 | landing, receipt/schema, compatibility/invariants, dogfood | PASS | 94/92/C1-C15/141, both shells where applicable |
| DC-2/DC-4/DC-5/DC-6 | R10 + recovery review/repros | FAIL | 120/120 modeled; R11-B1..B3 disprove required recovery claims |
<!-- /section:uat -->

<!-- section:verify-knowledge-captures -->
### Knowledge Captures

- `[D2-candidate]` A bounded history sentinel must distinguish “window truncated with no proof” from “proof already found”; provider terminal identity and every preflight temp must remain bound through the same recovery boundary.
<!-- /section:verify-knowledge-captures -->

<!-- section:render-fidelity -->
### Render Fidelity

render_fidelity_status: not-applicable — `affects_ui: false`; no UI DC, route, browser, or screenshot obligation exists.
<!-- /section:render-fidelity -->

<!-- section:science-officer-em-upward-report -->
### Science Officer (EM) Upward Report

```yaml
science_officer_em_upward_report:
  subject: {entity: ship-stage-debrief-closeout, stage: verify, report_kind: verify-synthesis}
  em_judgment: "Cycle 10 closes the reported endpoint cases, but terminal recovery still rejects valid mature histories, can trust a non-provider local terminal ref, and leaks validator temp files under signals."
  evidence_synthesis: ["fresh dual-shell runtime envelope", "three independent read-only reviews plus exact-function mature-main and TERM repros"]
  risk_tradeoff_call: "These are acceptance-path recovery defects, not optional hardening; modeled green suites currently encode one false rejection as PASS."
  recommendation: "Return R11-B1..B3 to execute with mature-main acceptance, provider-OID divergence, and validator-signal regressions."
  route: return
  confidence: high
  fo_boundary: "FO owns workflow mechanics; EM owns judgment and recommendation."
```
<!-- /section:science-officer-em-upward-report -->

<!-- section:verify-verdict -->
### Verdict

status: failed
stage_cost: dual-shell CLI/recovery envelope, static/TDD/C1-C15, three read-only panels, two exact-function repros
claim_records: required VERIFIED=2 NOT VERIFIED=3 INCONCLUSIVE=0; advisory VERIFIED=0 NOT VERIFIED=0 INCONCLUSIVE=0
stage_verdict: VETO — R11-B1..B3 are execute-owned blockers; captain_gate: PROMPT_CAPTAIN
cross_review_verdict: PROCEED — artifact faithfully preserves R11-B1..B3 as required NOT VERIFIED claims and FAILED/VETO/PROMPT_CAPTAIN
blocking_issues: R11-B1, R11-B2, R11-B3
auto_fixes: none — implementation/tests are execute-owned
started_at: 2026-07-16T11:24:00Z
completed_at: 2026-07-16T11:51:58Z
duration_minutes: 28
<!-- /section:verify-verdict -->

<!-- section:verify-verdict-metrics -->
### Metrics

status: failed
duration_minutes: 28
iteration_count: 11
claim_records_required_not_verified: 3
blocking_findings_count: 3
warning_findings_count: 0
runtime_checks_count: 13
<!-- /section:verify-verdict-metrics -->

<!-- section:panel-coverage -->
## Panel Coverage

- Tier B single-model read-only panel; cross-model/network/RoboRev excluded by Captain scope. General/type-design/maintainability: BLOCKING 3; silent/recovery: BLOCKING 3; testing/data-integrity: BLOCKING 2; separate security owner DEGRADED by ordinary-correctness scope and capacity.
- Pass ownership: worker ownership PASS; workflow_ci PASS; type_design BLOCKING; silent_failure BLOCKING; test_adequacy BLOCKING; runtime_uat BLOCKING; cross_model_challenge DEGRADED. PR Quality Score: 4/10.
<!-- /section:panel-coverage -->

<!-- section:runtime-verification -->
### Runtime Verification

| Type | Command/result | Verdict |
|---|---|---|
| R10 treatment | `feedback-r10-b1-b2`: 120/120 Bash 3.2 + 120/120 Bash 5.3 | PASS modeled cases |
| signals/provider | `feedback-r5-b1`: 289/289 each, serial foreground | PASS modeled cases |
| neighbors | R9 59; receipt 92; R8 50; R7 19; R3 107; R2 13+23; default 198; landing 94; optional 179; dogfood 141, both shells | PASS |
| mature main | 41 commits, valid awaiting at `HEAD^1`: `recovery_rc=2`, recovered candidate already present | FAIL R11-B1 |
| provider terminal | predecessor path has no local-ref SHA = provider-OID predicate | FAIL R11-B2 |
| signal temp | TERM during persisted-endpoint validator: exit 143, one scoped temp remains | FAIL R11-B3 |
| static/contracts | syntax/ShellCheck/Python/diff/TDD/registry/C1-C15/C14 exit 0; full invariant uses Bash 5.x | PASS |
<!-- /section:runtime-verification -->

<!-- section:stage-checklist -->
## Stage Report: verify

- DONE: Fresh dual-shell R10, signal/provider, neighboring recovery, receipt, default, landing, optional, and dogfood suites; static/TDD/registry/C1-C15/C14 gates.
- FAILED: Mature-main predecessor recovery, provider-head binding for landed terminal validation, and signal ownership of new validator temps.
- GATE: Round 11 is FAILED/PROMPT_CAPTAIN. No implementation/test bytes, status advance, network, remote, PR, merge, archive, todo, or RoboRev state changed.
<!-- /section:stage-checklist -->

<!-- section:hand-off-to-review -->
### Hand-off to Review

- `verify_verdict`: failed; Review must not proceed.
- `blocking_issues`: [R11-B1 bounded mature-main false rejection, R11-B2 provider-OID gap, R11-B3 signal temp leak].
- `canonical_docs_touched`: none by Verify; `render_fidelity_status`: not-applicable.
<!-- /section:hand-off-to-review -->

<!-- section:deferred-to-todo -->
## Deferred to TODO

Deferred to TODO: 0 findings this round. R11-B1..B3 are Captain-gated blockers; W2-W4 remain previously deferred. No todo or external state was mutated.
<!-- /section:deferred-to-todo -->

<!-- /section:verify-report -->
