<!-- section:verify-report -->
# Make debrief a native post-merge ship closeout — Verify
<details>
<summary>Snapshot provenance</summary>

Implementation snapshot: `d45d176..c08c391`; execute report: `e0033eb`; verify entry: `7086f2d`. The later execute narrative is not implementation-object evidence.
</details>
<!-- section:verify-check-manifest -->
### Verify Check Manifest

| Lane | Primary owner | Fresh evidence | Verdict |
|---|---|---|---|
| workflow CI / CLI DCs | verifier | 951 counted focused assertions; exact compatibility chain; static gates | PASS |
| general + type/design | external panel A | 22-file pinned diff and artifacts | BLOCKING |
| silent failure + recovery | external panel B | control flow, fault boundaries, startup integration | BLOCKING |
| testing + maintainability | panel A | focused suites plus uncovered branches | BLOCKING / WARNING |
| security | panel B | receipt/path/sentinel boundary | BLOCKING + WARNING |
| schema/domain intent | panels A/B + verifier | registry, design D1-D5, receipt contract | BLOCKING |
| cross-model challenge | verifier | no external Claude transport after decisive VETO | DEGRADED, no effect on failed verdict |
<!-- /section:verify-check-manifest -->

<!-- section:quality-gate -->
### Quality Gate

| Gate | Fresh result | Verdict |
|---|---|---|
| TDD ledger | `status=pass records=5` | PASS |
| Landing proof | 89/89 on Bash 3.2 and 89/89 on Bash 5.3 | PASS |
| Receipt / intent / schema | 43/43 + 21/21 + 34/34 + 7/7 | PASS |
| Bundle / reconciler | 51/51 on each Bash; direct 162/162; full 160/160; optional 141/141; PR40/41 103/103 | PASS |
| Compatibility / static | exact seven-command chain rc 0; syntax, Python compile, ShellCheck, `git diff --check` clean | PASS |

`/bin/bash` 3.2 reaches the untouched `check-invariants.sh` `declare -A` baseline; the plan's exact PATH command uses Bash 5.3 and passes, while all changed shell entry points pass Bash 3.2 checks.
<!-- /section:quality-gate -->

<!-- section:review-findings -->
### Review Findings

| ID | Severity | File:Line | Finding | Disposition |
|---|---|---|---|---|
| B1 | BLOCKING | `merged-pr-closeout-reconciler.sh:1314` | Missing landing fields silently select legacy sequential done/archive and return `PROCEED`. | bounce execute; add missing-field no-mutation tests |
| B2 | BLOCKING | `docs/ship-flow/_mods/pr-merge.md:17` | Startup delegates to the reconciler, then still commands a second legacy terminalize/archive path. | bounce execute/docs; one reconciler owner only |
| B3 | BLOCKING | `apply-closeout-bundle.sh:245` | Bundle archives only index/ship, then deletes shape/design/plan/execute/verify/review and ledgers. | bounce execute; preserve the complete folder tree |
| B4 | BLOCKING | `validate-closeout-receipt.py:242` | Self-rehashed minimal landing proof and arbitrary/duplicate safe output paths can validate as terminal sentinel state. | bounce execute; validate D1 fields and canonical unique roles |
| B5 | BLOCKING | `apply-closeout-bundle.sh:253` | Signal after durable commit but before `APPLIED=no` runs rollback against new HEAD and deletes committed outputs. | bounce execute; add post-commit interruption recovery proof |
| W1 | WARNING | `merged-pr-closeout-reconciler.sh:1043` | Pull-request mode omits direct mode's ROADMAP title/table validation. | include in execute repair |
| W2 | WARNING | `apply-closeout-bundle.sh:126` | Static symlink preflight leaves a same-user path-swap TOCTOU window. | retain as explicit hardening follow-up |

#### TDD Evidence Audit

| Task | RED / GREEN / REFACTOR audit | Severity | route_to |
|---|---|---|---|
| T1 | persisted contract and 89/89 fresh GREEN on both shells | NIT (none) | none |
| T2 | persisted contract; 43/43, 21/21, 34/34, 7/7 fresh GREEN | NIT (none) | none |
| T3 | persisted contract; bundle/direct fault suites fresh GREEN, but B3/B5 branches absent | BLOCKING | execute |
| T4 | persisted contract; optional/dogfood GREEN, but B1/B2 integration paths absent | BLOCKING | execute |
| T5 | valid `TDD: skip` docs exemption; exact chain GREEN; W1 remains | WARNING | execute |

<details>
<summary>Required verification claim records</summary>

Pre-scan: plan/diff paths match; context-routing manifest extracted; schema registry validates; no non-root guidance applies. Citation spot-check confirmed 100% of 7 unique findings. Strict dominance deduplicates the general/testing reports of B1; green suites do not override uncovered integration branches.

```yaml
science_officer_em_upward_report:
  subject: {entity: ship-stage-debrief-closeout, stage: verify, report_kind: verify-synthesis}
  em_judgment: "Verify evidence VETOs the implementation despite green focused suites."
  evidence_synthesis: ["five cited integration defects", "951 counted assertions plus exact compatibility/static gates"]
  risk_tradeoff_call: "Return now; accepting helper-level green would permit destructive or duplicated terminal closeout."
  recommendation: "Route B1-B5 and W1 to execute; retain W2 as explicit hardening risk."
  route: return
  confidence: high
  fo_boundary: "FO owns workflow mechanics; EM owns judgment and recommendation."
```

#### Verification Claim: scoped mechanical gate is reproducible
| Field | Value |
|---|---|
| claim_source | `quality-gate:scoped-cli` |
| condition / threshold | all declared focused and compatibility commands exit zero |
| metric_or_observable | 951 counted assertions plus exact chain/static exits |
| smallest_disproving_surface | any named failed assertion or nonzero exit |
| baseline / treatment / comparison | execute report; fresh verifier runs; counts reproduced |
| verdict / route_to | `VERIFIED`; `proceed` |

#### Verification Claim: incomplete provider proof fails closed
| Field | Value |
|---|---|
| claim_source | `review:general+silent`; DC-1/DC-2/DC-6 |
| condition / threshold | merged input missing any landing field must reject without mutation |
| metric_or_observable | control flow and existing legacy fixture |
| smallest_disproving_surface | `:1314-1337` reaches sequential terminalization |
| baseline / treatment / comparison | design fail-closed; implementation fallback; contradiction |
| verdict / route_to | `NOT VERIFIED`; `execute` |

#### Verification Claim: startup has exactly one terminal projection owner
| Field | Value |
|---|---|
| claim_source | `review:silent`; DC-2/DC-4 |
| condition / threshold | mod only schedules reconciler and reports its result |
| metric_or_observable | startup instructions |
| smallest_disproving_surface | `pr-merge.md:17-21` commands a second mutation |
| baseline / treatment / comparison | reconciler-owner intent; contradictory mod; mismatch |
| verdict / route_to | `NOT VERIFIED`; `execute` |

#### Verification Claim: terminal archive preserves entity evidence
| Field | Value |
|---|---|
| claim_source | `review:silent`; DC-2/DC-4 |
| condition / threshold | complete folder entity is archived byte-for-byte except terminal index/ship updates |
| metric_or_observable | rendered outputs and recursive deletion |
| smallest_disproving_surface | `apply-closeout-bundle.sh:245` after only index/ship copies |
| baseline / treatment / comparison | workflow whole-folder archive contract; evidence loss; mismatch |
| verdict / route_to | `NOT VERIFIED`; `execute` |

#### Verification Claim: landed sentinel proves canonical terminal semantics
| Field | Value |
|---|---|
| claim_source | `review:security+schema`; DC-5/DC-6 |
| condition / threshold | D1 landing schema and unique canonical output roles are validated |
| metric_or_observable | validator key/path checks |
| smallest_disproving_surface | arbitrary nonempty object at `:242-244` and generic paths at `:283-295` |
| baseline / treatment / comparison | D1/D4 contract; underconstrained validator; mismatch |
| verdict / route_to | `NOT VERIFIED`; `execute` |

#### Verification Claim: durable commit survives interruption coherently
| Field | Value |
|---|---|
| claim_source | `review:adversarial`; DC-4/DC-6 |
| condition / threshold | post-commit signal leaves new HEAD and worktree coherent and rerunnable |
| metric_or_observable | trap lifetime around commit |
| smallest_disproving_surface | `APPLIED=yes` through `git commit`, rollback deletes new-HEAD outputs |
| baseline / treatment / comparison | pre-commit test only; post-commit gap; not proven |
| verdict / route_to | `NOT VERIFIED`; `execute` |

</details>
<!-- /section:review-findings -->

<!-- section:uat -->
### UAT

mode: full-rerun plus control-flow review; no UI/API server applies to this CLI-only entity.

| DC | Verify Procedure | Execute 1st | Verify | Evidence |
|---|---|---|---|---|
| DC-1 | landing resolver suite | PASS | PASS helper / FAIL integration | 89/89; B1 bypass |
| DC-2/4/5/6 | reconciler suites + fault review | PASS | FAIL | 162/160/141 green but B1-B5 disprove integrated behavior |
| DC-3 | debrief schema + C15 | PASS | PASS | exact compatibility chain rc 0 |
| DC-7 | compatibility chain | PASS | PASS | exact seven commands rc 0 |
| DC-8 | PR40/41 case twice | PASS | PASS | 103/103; byte/hash no-op assertions |
<!-- /section:uat -->

<!-- section:verify-knowledge-captures -->
### Knowledge Captures

skipped: true — failed-round lessons remain attached to the blocking findings.
<!-- /section:verify-knowledge-captures -->

<!-- section:render-fidelity -->
### Render Fidelity

render_fidelity_status: not-applicable — `affects_ui: false`.
<!-- /section:render-fidelity -->

<!-- section:verify-verdict -->
### Verdict

status: failed
stage_cost: two parallel read-only panels plus six parallel mechanical lanes
quality: mechanical gates pass
review: VETO
cross_review_verdict: PROCEED on failed artifact `18bfdea`; route execute
uat: DC-2/DC-4/DC-5/DC-6 failed integrated verification
blocking_issues: B1-B5
claim_records: required VERIFIED=1 NOT VERIFIED=5 INCONCLUSIVE=0; advisory VERIFIED=0 NOT VERIFIED=0 INCONCLUSIVE=0
auto_fixes: none — logic findings must route to execute
started_at: 2026-07-15T09:49:00Z
completed_at: 2026-07-15T10:06:17Z
duration_minutes: 17

<!-- section:verify-verdict-metrics -->
### Metrics

status: failed
duration_minutes: 17
iteration_count: 1
claim_records_required_not_verified: 5
blocking_findings_count: 5
warning_findings_count: 2
runtime_checks_count: 951
<!-- /section:verify-verdict-metrics -->
<!-- /section:verify-verdict -->

<!-- section:panel-coverage -->
## Panel Coverage

- Tier: B (single-model; external Claude transport not invoked after decisive VETO).
- Specialists: general BLOCKING; silent-failure BLOCKING; testing BLOCKING; maintainability WARNING; security BLOCKING; schema/domain BLOCKING; adversarial BLOCKING.
- Pass ownership: verify_agent_worker_ownership PASS; workflow_ci PASS; type_design BLOCKING; silent_failure BLOCKING; test_adequacy BLOCKING; security BLOCKING; cross_model_challenge DEGRADED; runtime_uat BLOCKING; domain_intent BLOCKING.
- PR Quality Score: 0/10. Cross-model: NO; this cannot soften the failed verdict.
<!-- /section:panel-coverage -->

<!-- section:stage-checklist -->
## Stage Report: verify

- DONE: independently booted the exact execute snapshot, derived manifests, validated ledger, and reran scoped CLI/schema evidence.
- DONE: completed mandatory general, silent-failure, testing, maintainability, security, schema/domain, and adversarial coverage with 100% citation checks.
- FAILED: five unique blockers require execute repair; no FO proceed receipt, state advance, push, PR, merge, or archive was performed.
<!-- /section:stage-checklist -->

<!-- section:hand-off-to-review -->
### Hand-off to Review

- `verify_verdict`: failed; review must not proceed.
- `blocking_issues`: [B1, B2, B3, B4, B5].
- `canonical_docs_touched`: plugin README and pr-merge mod were reviewed; PRODUCT/ARCHITECTURE/ROADMAP terminal edits remain ship-review-owned.
- `render_fidelity_status`: not-applicable.
<!-- /section:hand-off-to-review -->
<details>
<summary>Verify Round 2 — FAILED / VETO, route R2-B1–R2-B4 to execute</summary>
<!-- section:verify-round-2 -->
## Verify Round 2
snapshot: `d45d176..c0494e5`; execute `c0494e5`; valid verify entry `5523916`; quality: 1,286 focused assertions plus full C1-C15 PASS.
resolved_from_round_1: B2, B3, B5, W1; round-1 body above remains the historical record.
- R2-B1 BLOCKING — active legacy done/PASSED archives before native proof (`merged-pr-closeout-reconciler.sh:1265-1279`); route execute.
- R2-B2 BLOCKING — squash source patch IDs are not Git-rederived, so self-rehashed forgery passes (`validate-closeout-receipt.py:162-199,327-337`); route execute.
- R2-B3 BLOCKING — ROADMAP identity matches any cell, not `cells[0]` (`validate-closeout-receipt.py:444-458`); route execute.
- R2-B4 BLOCKING — young-repo squash can crash on speculative root-parent dereference (`resolve-landing-envelope.sh:281-305`); route execute.
warnings: same-user path-swap TOCTOU; O(E×R) receipt scanning (effectively O(R²) when both grow); both non-blocking.
status: failed; review: VETO; claim_records: required VERIFIED=1 NOT VERIFIED=4 INCONCLUSIVE=0; blocking_issues: R2-B1–R2-B4.
hand_off: review must not proceed; no proceed receipt, status advance, push, PR, merge, archive, todo, or remote mutation.
<!-- /section:verify-round-2 -->
</details>
<!-- section:deferred-to-todo -->
## Deferred to TODO

Deferred to TODO: 0 findings this round. W1 should be repaired in the execute bounce; W2 remains explicitly visible as a non-acceptance hardening warning. No issue/todo/remote state was mutated.
<!-- /section:deferred-to-todo -->

<!-- /section:verify-report -->
