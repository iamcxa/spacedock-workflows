<!-- section:verify-report -->
# Make debrief a native post-merge ship closeout — Verify

<details>
<summary>Round 7 snapshot provenance</summary>

Implementation range: `e624554..2554a25`; production repair: `0a47e50`; metadata-only Verify entry:
`8163bd9`. Verification and panels used this immutable snapshot.
</details>

<!-- section:verify-check-manifest -->
### Verify Check Manifest

| Lane | Fresh evidence | Verdict |
|---|---|---|
| R6 seed and cleanup | command counts, remote states, bundle cleanup, signals, temp ownership | PASS except R7-B1 |
| R5/R4/R3/R2 history | exact routing, binding, bounded acquisition, native/squash proof | retained PASS |
| Panels | general BLOCKING; fresh recovery re-review PASS but missed R7-B1 | BLOCKING |
| External/RoboRev | excluded by Captain instruction | NOT RUN |
<!-- /section:verify-check-manifest -->
<!-- section:quality-gate -->
### Quality Gate

| Gate | Fresh result | Verdict |
|---|---|---|
| R6 focused | 279/279 on Bash 5.3 and 3.2 | PASS assertions; race gap below |
| Static | both Bash syntax, ShellCheck, and diff hygiene | PASS |
| Atomic seed probe | missing inspection, intervening ancestor ref, ordinary push | FAIL: remote mutated |
| Historical/contracts | accepted from cycle-6 plus unchanged implementation bytes | retained PASS |
<!-- /section:quality-gate -->
<!-- section:review-findings -->
### Review Findings

| ID | Severity | File:Line | Finding | Route/status |
|---|---|---|---|---|
| R7-B1 | BLOCKING | reconciler `:1157-1174`; test `:1805-1829` | Seed publication is not atomic. | execute; gate FAIL |
| W2 | WARNING | `apply-closeout-bundle.sh:232` | Same-user path-swap TOCTOU remains possible. | deferred |
| W3 | WARNING | reconciler `:648` | Receipt/entity discovery remains additive `O(R+E)`. | deferred |
| W4 | WARNING | `review-scope.sh:21` | Positional fallback can select `HEAD~1`. | deferred |

<details>
<summary>R6 closure and TDD audit</summary>

After an authoritative missing result, another actor can create the deterministic remote ref at an ancestor OID.
The ordinary seed push then fast-forwards that unexpected ref instead of failing closed. Independent reproduction showed
`ls_remote_rc=2`, `unexpected_before=base`, `after_unguarded_push=seed`, and `mutated=yes`.

R6-B1's duplicate-push defect is closed: actual seed and terminal invocations are counted. R6-W1 is closed: one composed
EXIT/signal owner removes internally owned bundle roots while preserving caller TMP sentinels and durable checkpoints.
Exact pre-existing OIDs skip; pre-existing divergent, malformed, and failed inspections fail closed; terminal publication
still uses the original force-with-lease. The missing inspection-to-push interleaving is the new blocker.

#### TDD Evidence Audit

The 279/279 suite observes real push commands and all planned provider seams, but never inserts a competing remote ref
after a missing `ls-remote` and before seed publication. Green tests therefore do not prove atomic expected-absence.
</details>

<details>
<summary>Required claim records</summary>

| Source / condition | Smallest disproof | Verdict / route |
|---|---|---|
| scoped gates exit zero | any named command fails | VERIFIED / proceed |
| actual seed and terminal commands are counted | no-op or failed push is invisible | VERIFIED / proceed |
| exact OID skips and true missing permits one seed push | wrong count or state | VERIFIED / proceed |
| divergent or uninspectable state fails closed | push or checkpoint mutation | VERIFIED / proceed |
| missing-ref publication is atomic | intervening ref is mutated | NOT VERIFIED / execute |
| terminal force-with-lease is unchanged | terminal push loses lease | VERIFIED / proceed |
| owned bundle cleanup preserves caller state | residue or caller deletion | VERIFIED / proceed |
| R2-R5 closures remain intact | changed bytes or regression evidence | VERIFIED / proceed |
</details>
<!-- /section:review-findings -->
<!-- section:uat -->
### UAT

mode: focused CLI recovery and local bare-remote race reproduction; non-UI.

| DC | Verify | Evidence |
|---|---|---|
| DC-1/DC-5 PASS | historical identity and acquisition closures retained | unchanged implementation bytes |
| DC-2/DC-4/DC-6 FAIL | seed publication can mutate an intervening remote ref | independent race reproduction |
| DC-3/DC-7 PASS | syntax, ShellCheck, compatibility evidence retained | zero exits; cycle-6 evidence |
| DC-8 PASS | frozen historical dogfood path unchanged | unaffected source path |
<!-- /section:uat -->
<!-- section:verify-knowledge-captures -->
### Knowledge Captures

- `[D2-candidate]` A preflight ref read plus an ordinary push is not atomic expected-absence publication.
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
  em_judgment: "R6 command counts and cleanup are repaired, but missing-ref seed publication is not atomic."
  evidence_synthesis: ["R6 279/279 both shells", "bare-remote inspection-to-push race mutates an unexpected ref"]
  risk_tradeoff_call: "The race violates exact-OID fail-closed semantics and can mutate remote state."
  recommendation: "Return only R7-B1 and its interleaving regression to execute; preserve closed R2-R6 claims."
  route: return
  confidence: high
  fo_boundary: "FO owns workflow mechanics; EM owns judgment and recommendation."
```
<!-- /section:science-officer-em-upward-report -->
<!-- section:verify-verdict -->
### Verdict

status: failed
stage_cost: dual-shell R6, static checks, two panels, and independent atomicity probe
quality: R6-B1 and R6-W1 close; missing-ref publication race remains
review: general panel BLOCKING; recovery panel PASS missed R7-B1 and does not soften the verdict
cross_review_verdict: VETO — one required claim is NOT VERIFIED
cross_review_coaching: Test the interleaving between authoritative inspection and external mutation.
captain_gate: PROMPT_CAPTAIN
blocking_issues: R7-B1
claim_records: required VERIFIED=7 NOT VERIFIED=1 INCONCLUSIVE=0; advisory VERIFIED=0 NOT VERIFIED=0 INCONCLUSIVE=0
auto_fixes: none — provider/recovery logic and tests are execute-owned
started_at: 2026-07-15T17:35:00Z
completed_at: 2026-07-15T17:43:35Z
duration_minutes: 9
<!-- /section:verify-verdict -->
<!-- section:verify-verdict-metrics -->
### Metrics

status: failed
duration_minutes: 9
iteration_count: 7
claim_records_required_not_verified: 1
blocking_findings_count: 1
warning_findings_count: 3
runtime_checks_count: 5
<!-- /section:verify-verdict-metrics -->
<!-- section:panel-coverage -->
## Panel Coverage

- Tier B by Captain instruction; no RoboRev/external review.
- Fresh general panel: BLOCKING R7-B1 with source audit, test audit, and local reproduction.
- Reused addressable recovery reviewer performed a fresh Round-7 audit and returned PASS; it verified R6 closures but
  missed the inspection-to-push race. Its PASS is recorded without verdict softening.
- Pass ownership: type_design BLOCKING; test_adequacy BLOCKING; cleanup/security NO_FINDINGS;
  recovery/silent-failure DEGRADED by the missed race; cross-model challenge excluded by instruction.
<!-- /section:panel-coverage -->
<!-- section:runtime-verification -->
### Runtime Verification

| Type | Command/result | Verdict |
|---|---|---|
| R6 recovery | focused matrix: 279/279 on Bash 5.3 and 3.2 | PASS assertions |
| atomicity probe | missing read, concurrent ancestor ref, ordinary seed push | FAIL: ref changed to seed |
| static | both Bash syntax, ShellCheck, `git diff --check` | PASS |
| historical | R2-R5 implementation bytes unchanged from accepted cycle-6 snapshot | retained PASS |
<!-- /section:runtime-verification -->
<!-- section:stage-checklist -->
## Stage Report: verify

- DONE: Verify R6 command-level push counts, exact pre-existing remote handling, terminal lease, cleanup ownership,
  signal behavior, caller TMP sentinel preservation, and durable checkpoints on both Bash versions.
- DONE: Preserve R2-R5 closures and independently reproduce the missing-inspection publication interleaving.
- FAILED: An intervening ancestor-valued remote ref is fast-forwarded by the unguarded seed push.
- GATE: Round 7 FAILED/PROMPT_CAPTAIN. No implementation, FO receipt/status, Review dispatch, push, PR, merge,
  archive, todo, or external remote mutation occurred.
<!-- /section:stage-checklist -->
<!-- section:hand-off-to-review -->
### Hand-off to Review

- `verify_verdict`: failed; review must not proceed.
- `blocking_issues`: [R7-B1 non-atomic missing-ref seed publication].
- `canonical_docs_touched`: none in Verify; `render_fidelity_status`: not-applicable.
<!-- /section:hand-off-to-review -->
<!-- section:deferred-to-todo -->
## Deferred to TODO

Deferred to TODO: 0 emitted. R7-B1 is Captain-gated; W2-W4 remain visible. No todo or remote state was mutated.
<!-- /section:deferred-to-todo -->

<!-- /section:verify-report -->
