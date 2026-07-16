<!-- section:verify-report -->
# Make debrief a native post-merge ship closeout — Verify

<details>
<summary>Round 10 provenance</summary>

Captain feedback receipt `85d8a50`; implementation/tests/schema `90bd6dd`; execute report `e033f14`; canonical Verify entry `fac70c2`. Verification froze `fac70c290d73c09909f504480bd91796d8b2f3e3` on branch `spacedock-ensign/ship-stage-debrief-closeout`; the worktree began clean.
</details>

<!-- section:verify-check-manifest -->
### Verify Check Manifest

<details>
<summary>Current-byte lanes</summary>

| Lane | Evidence | Verdict |
|---|---|---|
| Endpoint syntax/transport | HTTPS, scp-like, SSH normalization; literal local `send-pack` lease probes | PASS for exercised forms |
| Endpoint/provider binding | ambient-config and persisted-endpoint local bare-repo probes | FAIL R10-B1 |
| Endpoint immutability/reuse | awaiting and terminal standalone/replay probes | FAIL R10-B2 |
| Recovery envelope | R9-R2/default, receipt, static/TDD/C1-C15 on current bytes | PASS |
| Read-only panels | general, silent/recovery, testing | VETO |
| External actions | network, repository remote, PR, merge, archive, RoboRev | NOT RUN by scope |
</details>
<!-- /section:verify-check-manifest -->

<!-- section:quality-gate -->
### Quality Gate

| Gate | Fresh result | Verdict |
|---|---|---|
| Cycle 9 + receipt | R9 59/59 and receipt 92/92 on Bash 3.2 and 5.3 | PASS modeled cases |
| Recovery/compatibility | R8 50; R7 19; R5/R6 289; R4 29; R3 107; R2 13+23; default 198, both shells | PASS |
| Static/process | Bash syntax, Python AST, diff check, TDD ledger 5, full C1-C15 | PASS |
| Provider-bound publication | global-marker and altered-receipt actual endpoint refs | FAIL |

<details>
<summary>Required Verification Claim records</summary>

| claim_source | condition | observable/threshold | smallest disproving surface | baseline/treatment/comparison | verdict | route_to |
|---|---|---|---|---|---|---|
| `other:snapshot` | current bytes are authoritative | exact HEAD/range and clean tree | `git status`, `rev-parse` | `fac70c2`, seven-file range, clean | VERIFIED | proceed |
| `DC-1/DC-3/DC-5/DC-6/DC-7` | prior behavior remains compatible | every named dual-shell suite has zero failures | focused/default suites + C1-C15 | all fresh counts equal GREEN envelope | VERIFIED | proceed |
| `DC-2/DC-4` | endpoint is provider-bound before publication | unrelated endpoint ref remains absent | global matching marker + unmarked local bare repo | B absent→seed; one publication and two provider calls | NOT VERIFIED | execute |
| `DC-2/DC-4/DC-6` | bound endpoint cannot change across recovery/reuse | exact endpoint/provider/checkpoint agreement before push/no-op | altered awaiting/terminal receipts | wrong leaf terminalized before provider mismatch; standalone terminal validates | NOT VERIFIED | execute |
</details>
<!-- /section:quality-gate -->

<!-- section:review-findings -->
### Review Findings

| ID | Severity | File:Line | Finding | Route/status |
|---|---|---|---|---|
| R10-B1 | BLOCKING | reconciler `:1195-1203,1219-1229,1276-1279` | Local fixture binding reads merged Git config; an ambient matching marker authorizes an unrelated unmarked bare endpoint and permits seed publication. | execute; VETO |
| R10-B2 | BLOCKING | reconciler `:729-736,1367-1415,1507-1517`; validator `:729-774` | Provider equivalence and endpoint immutability are transition-local. Recovery/reuse accepts a changed awaiting/terminal endpoint without a prior-checkpoint comparison; publication or terminal no-op can occur before mismatch detection. | execute; VETO |
| R10-W1 | WARNING | tests `:1235-1255,1592-1617,2274-2495` | Positive transport publication, terminal receive-pack race, valid legacy prepared hydration, and provider-refresh failure are not all causal integration cases. | fix with blockers |
| W2/W3/W4 | WARNING | prior receipts | Same-user path-swap TOCTOU, O(R+E) receipt scan, and review-scope tooling remain deferred. | deferred |

<details>
<summary>Current-byte reproduction and panel synthesis</summary>

- Ambient marker: with `GIT_CONFIG_GLOBAL` containing `ship-flow.closeoutFixtureRepository=example/repo`, the unmarked endpoint B changed `absent→55f0a20...`; R9 recorded one publication and two provider calls (`55/59`, four expected fail-closed assertions disproved).
- Altered awaiting receipt: provider A stayed at seed `859d05...`, syntactically valid endpoint B advanced to terminal `f7ca34...`, and provider refresh then stopped ready with `PROMPT_CAPTAIN`. The late failure cannot undo B.
- Altered terminal receipt: standalone validation succeeds because `publication_endpoint` is compared only when `--previous` is supplied; terminal reuse/receipt-only paths do not supply the durable awaiting receipt.
- Literal Git semantics remain sound: expected-absence seed publication succeeds once; stale terminal OID lease returns 1 and preserves the competing ref.
- General review found R10-B1; silent/recovery review found R10-B2; testing review found the missing causal regression surfaces. Every cited current-byte location was spot-checked.

#### TDD Evidence Audit

The five-record persisted ledger validates. Cycle 9 has causal RED-before-GREEN evidence and fresh dual-shell GREEN, but current tests do not disprove the ambient-marker or changed-terminal-receipt cases; this is implementation-owned missing recovery evidence, not a plan gap.

#### Reviewer Lens Matrix

| Lens/owner | Scope | Verdict |
|---|---|---|
| general/type-design + maintainability | endpoint binding against D3/T4 | BLOCKING R10-B1 |
| silent/recovery | awaiting, terminal reuse, receipt-only classification | BLOCKING R10-B2 |
| testing | receive-pack, hydration, refresh and transport causality | BLOCKING/WARNING R10-W1 |
| workflow/runtime verifier | dual-shell envelope, local refs, provider order | BLOCKING |
</details>
<!-- /section:review-findings -->

<!-- section:uat -->
### UAT
mode: full-rerun — non-UI CLI/Git with temporary local repositories and fake provider only.
| DC | Verify Procedure | Execute 1st | Verify | Evidence |
|---|---|---|---|---|
| DC-1 | exact landing/source-object resolver suites | PASS | re-run (fallback) | R3 landing/source-object and prior resolver evidence remains green |
| DC-2/DC-4/DC-6 | focused reconciler suites plus actual endpoint-ref recovery probes | PASS | re-run (fallback): FAIL | R10-B1/B2 actual endpoint refs and recovery ordering |
| DC-3 | receipt suite plus schema/static/C15 checks | PASS | re-run (fallback) | receipt 92/92 both shells; schema/static/C15 pass |
| DC-5 | default recursion/sentinel suite | PASS | re-run (fallback) | default recursion/sentinel cases 198/198 both shells |
| DC-7 | compatibility chain plus full C1-C15 | PASS | re-run (fallback) | full compatibility and C1-C15 pass |
| DC-8 | default frozen-dogfood/two-run no-op suite | PASS | re-run (fallback) | frozen dogfood and second-run no-op remain in default 198/198 |
<!-- /section:uat -->

<!-- section:verify-knowledge-captures -->
### Knowledge Captures

- `[D2-candidate]` Fixture identity must come from endpoint-local Git config, and transaction-field immutability must be predecessor-checked or bound into immutable proof; ambient/standalone values are not repository facts.
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
  em_judgment: "Cycle 9 closes modeled rewrite/config drift, but provider binding and endpoint immutability still depend on ambient config and callers supplying a predecessor receipt."
  evidence_synthesis: ["full dual-Bash recovery envelope green", "two independent temporary-local-repository failures plus three read-only panel judgments"]
  risk_tradeoff_call: "Provider refresh prevents one false-ready path only after an unintended endpoint ref write; terminal reuse can bypass even that comparison."
  recommendation: "Return R10-B1/B2 and the causal regression envelope to execute; preserve all closed R2-R9 controls."
  route: return
  confidence: high
  fo_boundary: "FO owns workflow mechanics; EM owns judgment and recommendation."
```
<!-- /section:science-officer-em-upward-report -->

<!-- section:verify-verdict -->
### Verdict

status: failed
stage_cost: full dual-Bash recovery envelope, receipt/TDD/static/C1-C15, temporary-local endpoint probes, three read-only panels
quality: modeled Cycle 9 cases pass; provider-bound immutable endpoint recovery fails
review: general, silent/recovery, and testing panels VETO
uat: DC-2/DC-4/DC-6 failed on actual endpoint refs and recovery ordering
stage_verdict: VETO — two required claims are NOT VERIFIED
cross_review_verdict: PROCEED — R10-B1/B2 remain unsoftened and consistently drive FAILED/VETO/PROMPT_CAPTAIN across findings, claims, index, verdict, and hand-off
captain_gate: PROMPT_CAPTAIN
blocking_issues: R10-B1, R10-B2
knowledge_capture: D1: 0, D2: 1
claim_records: required VERIFIED=2 NOT VERIFIED=2 INCONCLUSIVE=0; advisory VERIFIED=0 NOT VERIFIED=0 INCONCLUSIVE=0
auto_fixes: none — implementation and regressions are execute-owned
started_at: 2026-07-16T05:49:00Z
completed_at: 2026-07-16T06:40:28Z
duration_minutes: 52
<!-- /section:verify-verdict -->

<!-- section:verify-verdict-metrics -->
### Metrics

status: failed
duration_minutes: 52
iteration_count: 10
claim_records_required_not_verified: 2
blocking_findings_count: 2
warning_findings_count: 4
runtime_checks_count: 31
<!-- /section:verify-verdict-metrics -->

<!-- section:panel-coverage -->
## Panel Coverage

- Tier B read-only local panel; external/network/RoboRev review excluded by Captain scope, `cross_model: false`. General/type-design+maintainability: BLOCKING 1; silent/recovery: BLOCKING 1; testing: BLOCKING 2 plus warnings.
- Pass ownership: worker ownership PASS; workflow_ci/type_design/silent_failure/test_adequacy/runtime_uat BLOCKING; cross_model_challenge DEGRADED by scope. PR Quality Score: 6/10; code panel VETO; artifact cross-review PROCEED.
<!-- /section:panel-coverage -->

<!-- section:runtime-verification -->
### Runtime Verification

| Type | Command/result | Verdict |
|---|---|---|
| Cycle 9 | `feedback-r9-b1-b2`: 59/59 both shells | PASS modeled cases |
| ambient config | global matching marker + unmarked B: B absent→seed, publication/provider effects occurred | FAIL R10-B1 |
| endpoint recovery | altered awaiting endpoint: B terminal, provider A seed; refresh stops ready only afterward | FAIL R10-B2 |
| terminal reuse | changed endpoint standalone-valid; predecessor comparison rejects | FAIL R10-B2 |
| literal leases | expected-absence create; stale terminal OID returns 1 and preserves competitor | PASS |
| history | R8 50; R7 19; R5/R6 289; R4 29; R3 107; R2 13+23; default 198, both shells | PASS |
| static/contracts | receipt 92 both; syntax/AST/diff/TDD ledger/C1-C15 | PASS |
<!-- /section:runtime-verification -->

<!-- section:stage-checklist -->
## Stage Report: verify

- DONE: Verify current endpoint normalization, rewrite rejection, literal leased send-pack behavior, persisted config drift, and post-terminal provider refresh with temporary local repositories/fake provider; re-run the complete dual-Bash recovery/compatibility envelope, receipt/TDD/static checks, C1-C15, and three fresh read-only panels.
- FAILED: Ambient Git config can authorize an unrelated fixture endpoint, and changed awaiting/terminal endpoint bytes are not provider-bound or predecessor-checked on every recovery/reuse path.
- GATE: Round 10 is FAILED/PROMPT_CAPTAIN. No implementation/test bytes, Review advance, network, repository remote, PR, merge, archive, todo, or RoboRev state changed.
<!-- /section:stage-checklist -->

<!-- section:hand-off-to-review -->
### Hand-off to Review

- `verify_verdict`: failed; Review must not proceed.
- `blocking_issues`: [R10-B1 ambient fixture identity leakage, R10-B2 recovery/reuse endpoint immutability gap].
- `canonical_docs_touched`: none by Verify; `render_fidelity_status`: not-applicable.
<!-- /section:hand-off-to-review -->

<!-- section:deferred-to-todo -->
## Deferred to TODO

Deferred to TODO: 0 emitted. R10-B1/B2 are Captain-gated; W2-W4 remain deferred. No todo or external state was mutated.
<!-- /section:deferred-to-todo -->

<!-- /section:verify-report -->
