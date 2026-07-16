<!-- section:verify-report -->
# Make debrief a native post-merge ship closeout — Verify

<details>
<summary>Round 12 frozen-head provenance</summary>

Captain feedback `6befef8`; Cycle 11 implementation `2c02bae`; execute report `5c43341`; verify entry `c607c28`. Verification froze `c607c28b129be8ab9527b20c8f4692e86b10906e` on `spacedock-ensign/ship-stage-debrief-closeout`; pinned status was `verify` and the worktree began clean. One testing reviewer violated the immutable-path boundary by patching a temporary copied suite; its output was discarded, its process stopped, and a fresh read-only replacement supplied testing ownership.
</details>

<!-- section:verify-check-manifest -->
### Verify Check Manifest

| Lane | Owner/input | Verdict |
|---|---|---|
| Current CLI/runtime | verifier; R11/R10/signal/default/receipt/landing/optional/dogfood | PASS modeled cases |
| Type/schema/recovery | general, silent, maintainability, schema-intent reviewers | BLOCKING 2 |
| Test adequacy | replacement testing reviewer + TDD/DC reverse audit | BLOCKING gaps |
| Static/process | verifier; syntax, ShellCheck, Python AST, diff, registry, C1-C15/C14 | PASS |
| UI/browser/external | `affects_ui: false`; network/remotes/RoboRev excluded | N/A / DEGRADED cross-model |
<!-- /section:verify-check-manifest -->

<!-- section:quality-gate -->
### Quality Gate

| Gate | Fresh current-head result | Verdict |
|---|---|---|
| Cycle 11 causal treatment | R11 91/91 on Bash 3.2 and 5.3 | PASS covered cases |
| Recovery neighbors | R10 120/120, signal/provider 289/289, default 198/198; both shells | PASS |
| Contract/value neighbors | landing 94/94 and receipt 92/92 both shells; optional 179/179 and dogfood 141/141 on Bash 5.3 | PASS |
| Static/process | dual syntax, ShellCheck, Python AST, diff, TDD ledger 5, schema registry, C15, C14, C1-C15 | PASS |
| Exact deterministic refs + concurrent-main recovery | causal probes and panels below | FAIL |

<details>
<summary>Required Verification Claim records</summary>

| claim_source | condition | observable / threshold | smallest disproving surface | baseline | treatment / comparison | verdict | route_to |
|---|---|---|---|---|---|---|---|
| `other:snapshot` | frozen bytes are authoritative | exact HEAD/status/clean start | `rev-parse`, pinned status, `git status` | `c607c28`, verify | unchanged during evidence collection | VERIFIED | proceed |
| `DC-2/DC-4/DC-5/DC-6` | reported R11 seams converge or fail closed | 91 assertions on both shells | focused R11 suite | Round 11 three blockers | current: 91/91 twice | VERIFIED | proceed |
| `DC-4/DC-5/DC-6` | every deterministic local head read is exact under same-name tag | branch OID/tree selected, never tag | isolated tag/branch probe; reconciler `:768-770,1402-1403,1474,1533-1544,1599-1601` | exact-ref contract | bare ref selected tag OID/content instead of branch | NOT VERIFIED | execute |
| `DC-4/DC-5/DC-6` | valid awaiting ancestor survives later main movement | some identical bounded candidate is ancestor of provider terminal | local A/B/T/M topology; reconciler `:1577-1585,818-823` | A is ancestor of T | scan selects newer B; B is not ancestor of T | NOT VERIFIED | execute |
</details>
<!-- /section:quality-gate -->

<!-- section:review-findings -->
### Review Findings

| ID | Severity | File:Line | Finding | Route/status |
|---|---|---|---|---|
| R12-B1 | BLOCKING | `merged-pr-closeout-reconciler.sh:768-770,1402-1403,1474,1533-1544,1599-1601`; test `:3113-3116` | Landed comparison is exact, but awaiting/OPEN/build paths still DWIM the bare deterministic head; Git chooses a same-name tag over the branch. | execute; VETO |
| R12-B2 | BLOCKING | `merged-pr-closeout-reconciler.sh:1577-1585,818-823`; test `:3085-3114,3123-3126` | Scan binds ancestry to the newest commit carrying identical awaiting bytes. A later main-only commit B is not ancestor of terminal T branched from the real checkpoint A, so legal recovery false-rejects. | execute; VETO |
| R12-W1 | WARNING | `merged-pr-closeout-reconciler.sh:54-61,464-466,497,718-719,746-748` | `ensure_owned_validator_root` failure is not explicitly propagated; an empty root can feed `/validator.XXXXXX` when errexit is suppressed by caller `||` chains. | execute hardening; non-dominant |

#### TDD Evidence Audit

`validate-tdd-ledger.py` returns `status=pass records=5`; T1-T4 retain recorded RED-before-GREEN and T5 has a valid docs skip. Cycle 11's frozen causal records cover its three named defects, but the new test puts fillers before awaiting, creates the tag only after terminal construction, and asserts awaiting at `HEAD^1`; it has no RED/GREEN for R12-B1 or R12-B2. The first testing reviewer was discarded as INVALID_CONTEXT; the replacement read current committed bytes only.

Every retained citation was spot-checked against `c607c28`. General/schema, silent/maintainability, and ordinary-correctness lanes independently confirmed both blockers; security returned NO_FINDINGS for injection/path/ref-mutation concerns. Cross-model challenge is DEGRADED because dispatch forbids network/external review; the internal same-model ordinary-correctness lane found R12-B2.
<!-- /section:review-findings -->

<!-- section:uat -->
### UAT

mode: full focused non-UI CLI/Git rerun with hermetic local repositories and fake provider/transport.

| DC | Verify procedure | Verify | Evidence |
|---|---|---|---|
| DC-1/DC-3/DC-7/DC-8 | landing, receipt/schema, invariants, dogfood | PASS | 94/92/C1-C15/141; dual shell where required |
| DC-2/DC-4/DC-5/DC-6 | R11 + recovery review/probes | FAIL | 91/91 modeled; R12-B1/B2 disprove exact-ref and moving-main recovery |
<!-- /section:uat -->

<!-- section:verify-knowledge-captures -->
### Knowledge Captures

- `[D2-candidate]` Exact-ref tests must collide before every consumer, not only after terminal construction; an identical checkpoint blob can have multiple carrier commits with different ancestry.
<!-- /section:verify-knowledge-captures -->

<!-- section:render-fidelity -->
### Render Fidelity

render_fidelity_status: not-applicable — `affects_ui: false`; no UI DC, route, browser, screenshot, or visible-surface obligation exists.
<!-- /section:render-fidelity -->

<!-- section:science-officer-em-upward-report -->
### Science Officer (EM) Upward Report

<details>
<summary>Structured EM judgment</summary>

```yaml
science_officer_em_upward_report:
  subject: {entity: ship-stage-debrief-closeout, stage: verify, report_kind: verify-synthesis}
  em_judgment: "Cycle 11 repairs its named defects, but deterministic-head identity and concurrent-main ancestry remain incomplete on ordinary recovery paths."
  evidence_synthesis: ["fresh dual-Bash causal and neighbor suites", "two local Git topology probes plus three independent confirming reviewer lanes"]
  risk_tradeoff_call: "Passing modeled cases cannot outweigh two acceptance-path false identity/recovery decisions."
  recommendation: "return R12-B1/B2 to execute; carry R12-W1 as coupled hardening"
  route: return
  confidence: high
  fo_boundary: "FO owns workflow mechanics; EM owns judgment and recommendation."
```

</details>
<!-- /section:science-officer-em-upward-report -->

<!-- section:verdict -->
### Verdict

status: failed
Verdict: VETO — route R12-B1/B2 to execute and stop at the Captain gate.
stage_cost: dual-shell CLI/recovery envelope, static/TDD/C1-C15, four valid read-only owner lanes plus one discarded lane, two causal Git probes
claim_records: required VERIFIED=2 NOT VERIFIED=2 INCONCLUSIVE=0; advisory VERIFIED=0 NOT VERIFIED=1 INCONCLUSIVE=0
cross_review_verdict: PROCEED — Rule C confirms FAILED/VETO/PROMPT_CAPTAIN matches the evidence; coaching: distinguish product canonical docs from the verifier-owned entity index.
auto_fixes: none
started_at: 2026-07-16T16:03:00Z
completed_at: 2026-07-16T16:38:00Z
duration_minutes: 35
<!-- /section:verdict -->

<!-- section:panel-coverage -->
## Panel Coverage

- Tier: B (single-model; external cross-model prohibited by no-network dispatch boundary)
- Specialists run: general FAIL=2; silent FAIL=2; testing FAIL=2; maintainability FAIL=2/WARN=1; security NO_FINDINGS; schema-intent FAIL=1
- Adversarial: internal ordinary-correctness PASS coverage with one BLOCKING finding; external cross-model DEGRADED
- Structured Codex review: not separate from Codex verifier; same-model panel used
- Pass ownership: verify_agent_worker_ownership PASS after invalid testing lane replacement; workflow_ci PASS; type_design BLOCKING; silent_failure BLOCKING; test_adequacy BLOCKING; security NO_FINDINGS; cross_model_challenge DEGRADED; runtime_uat BLOCKING; domain_intent BLOCKING
- PR Quality Score: 6/10; Cross-model: NO — explicit scope boundary, not an implicit skip
<!-- /section:panel-coverage -->

<!-- section:runtime-verification -->
### Runtime Verification

Preflight: non-UI local CLI/Git fixtures only; no dev server/API/browser applies. Signal-heavy suites ran serially in the foreground.

| DC | Type | Command | Result | Verdict |
|---|---|---|---|---|
| DC-2/4/5/6 | cli | `SHIP_FLOW_CLOSEOUT_CASE=feedback-r11-b1-b2-b3 <bash> test-merged-pr-closeout-reconciler.sh` | 91/91 on Bash 3.2 + 5.3 | PASS modeled |
| DC-2/4/5/6 | cli | local same-name tag/branch probe | short ref selected tag, exact ref selected branch | FAIL |
| DC-4/5/6 | cli | local A/B/T/M ancestry probe | A→T true; B→T false; A/B receipt bytes identical | FAIL |

Preflight or probe failures: two assertion-level acceptance defects R12-B1/B2; no infrastructure failure.
<!-- /section:runtime-verification -->

<!-- section:metrics -->
### Metrics

status: failed
duration_minutes: 35
iteration_count: 12
claim_records_required_not_verified: 2
blocking_findings_count: 2
warning_findings_count: 1
runtime_checks_count: 15 suite/shell/gate groups plus 2 causal probes
<!-- /section:metrics -->

<!-- section:stage-checklist -->
### Stage Checklist

- DONE: Independently rerun Cycle 11, adjacent recovery, landing/receipt, optional/dogfood, static, TDD, schema-registry, C14, C15, and full invariants.
- DONE: Run mandatory general, silent-failure, testing replacement, maintainability, security/ordinary-correctness, and schema-intent ownership; spot-check every retained citation.
- FAILED: Exact deterministic refs remain ambiguous outside landed recovery, and identical awaiting bytes after concurrent main movement bind the wrong ancestry commit.
- GATE: Round 12 is FAILED/PROMPT_CAPTAIN. No implementation/test behavior, status advance, network, remote, PR, merge, archive, todo, or RoboRev state changed.
<!-- /section:stage-checklist -->

<!-- section:hand-off-to-review -->
### Hand-off to Review

- `verify_verdict`: failed; Review must not proceed.
- `blocking_issues`: [R12-B1 exact deterministic-ref gap, R12-B2 identical-carrier ancestry gap].
- `canonical_docs_touched`: no product canonical docs; Verify updated only its entity index report; `render_fidelity_status`: not-applicable.
<!-- /section:hand-off-to-review -->

<!-- section:deferred-to-todo -->
## Deferred to TODO

Deferred to TODO: 0 findings this round. R12-B1/B2 are Captain-gated blockers; R12-W1 should travel with their execute repair. No todo or external state was mutated.
<!-- /section:deferred-to-todo -->

<!-- /section:verify-report -->
