<!-- section:review-report -->
## What Worked

Status: captured

1. Pattern: fail-loud producer status makes an empty discovery receipt trustworthy
   Trigger: A healthy empty result can otherwise be indistinguishable from a suppressed traversal failure.
   Action: Preserve producer status as 0/1/2, buffer output until every producer succeeds, and inject focused failures for every traversal branch before accepting an empty result.
   Evidence: DC-5 records adopter 38/38; post-repair DC-6 records density 51/51. DC-10 binds the immutable cycle-3 receipt only to the sole discover-adopter launch at original frozen commit `1b3871f8cfb1f811813605e48f7c22922d686162`, process rc 0, stdout 193 bytes, stderr 0 bytes, and routes 0.
   Destination: promote-to-ship-verify.md

## What Almost Failed

Status: captured

1. Pattern: one-shot acceptance clock started before capture setup was proven
   Trigger: An acceptance command is authorized for exactly one real launch and shell redirection can fail before process execution.
   Action: Create and validate the parent capture directory, open dedicated stdout/stderr descriptors, and prove both descriptors writable before starting the process clock.
   Evidence: `execute.md` records the `2026-07-13T09:35:46Z` parent/redirection failure as pre-launch invocation count 0; corrected descriptor validation preceded the sole DC-10 launch at `09:39:05Z` and its immutable receipt.
   Destination: promote-to-ship-execute.md

## PR Draft

Title: Fixture-tree exclusion for discovery helpers

PR body was composed by ship-final (`/ship` Step 6.3) from `shape.md` (canonical Problem / User Journey / Done Criteria) + verify UAT table + Quality Gate + execute Execution Log, materialized for PR #32 and retained in ignored `.context/issue20-pr-body.md`. The local body is corrected for the post-acceptance density lane; publishing remains FO-owned. It closes #20; #21 and #24 remain related evidence only.

## Per-Feature Retrospective

**Shipped this entity**: [fixture-pollution-discovery-helpers](index.md)

**Deferred via `ship-flow:add-todos`** (`/ship-flow:add-todos list`): 0 informational + 0 critical-confidence<8 findings.

Risks accepted: none — no CRITICAL finding was accepted as-is.

**Verify Panel Coverage**: Historical Tier B panel passed; agy pre-merge review BLOCKED `904599d` on two density no-match/coverage findings. `fc6ef1e` repairs both; final agy and current-head CI remain pending.

**Accepted release note**: Combined `EXIT INT TERM` cleanup traps do not explicitly terminate after a caught signal on Bash 3.2; agy finding 3 remains accepted nonblocking.

**What Worked**: Fail-loud 0/1/2 producer status plus focused injected failures made the immutable discover-adopter DC-10 receipt trustworthy; the later density no-match correction remains a separate evidence lane → `promote-to-ship-verify.md`.

## Post-Acceptance Review Correction

| Head / signal | Evidence | Disposition |
|---|---|---|
| `904599d` agy | BLOCK: S2 `-exec grep -l "$WF_NAME" {} +` converted a healthy grep no-match rc 1 into find rc 1 and classifier rc 2; the focused suite lacked an unpruned nonmatching `SKILL.md` case. | Findings 1-2 required code/test repair. |
| Focused RED | Density suite rc1; primary observed rc2 instead of 0 with no `vacuum` and 129-byte stderr; `--is-high` observed rc2 instead of 1 with 129-byte stderr. The operational grep-error guard already passed. | Confirms both findings without repository-root discovery. |
| `fc6ef1e` correction | Density implementation blob `e5c9e12…f882` → `7098af01…11c3`; test blob `fe67604…041d` → `f6de6e9…4178`; syntax passes and density is 51 OK / 0 FAIL. | Findings 1-2 locally closed by worker and EM. |
| Acceptance closure | Helper blob `ce0447…a8748` and discover-adopter blob `2c183a…becc` are identical at `1b3871f8` and `fc6ef1e`; only these two files are in the in-repo closure of the sole accepted command. | DC-10 remains applicable only to that discover-adopter command; density does not inherit the receipt. |
| Signal trap | agy finding 3. | Accepted nonblocking. |
| Final agy / CI | Not yet recorded. | PENDING; merge remains held. |

**What Almost Failed**: One-shot setup must validate parent paths and capture descriptors before starting the process clock → `promote-to-ship-execute.md`.

## Canonical Docs Update

- `ARCHITECTURE.md`: skipped — internal caller-owned capture and pruning mechanics do not change durable component, data-flow, storage, or API boundaries.
- `PRODUCT.md`: skipped — this repairs correctness of an existing discovery capability and adds no durable user-facing capability.
- `README.md`: skipped at review — no root install, usage, command, compatibility, or quick-start contract changes.
- `docs/ship-flow/README.md`: preserved — the explicit `--workflow-dir docs/ship-flow` guard and related #24 link already landed and remain intact.
- `ROADMAP.md`: `3c9f83e` — moved `fixture-pollution-discovery-helpers` from Later to Shipped with the verified fixture-pruning and fail-loud outcome.
- Umbrella closeout: no — standalone pitch with no parent or child entities; only its independently listed ROADMAP row closes.

<details>
<summary>Canonical doc actions consumed</summary>

| Doc | Action Source | Plan Action | Review Outcome | Commit Or Skip Rationale |
| --- | --- | --- | --- | --- |
| `ROADMAP.md` | spec | update | updated | `3c9f83e`; Later → Shipped with verified outcome |
| `PRODUCT.md` | design | skip | skipped | Existing internal correctness repair; no new capability |
| `ARCHITECTURE.md` | design | skip | skipped | Existing `lib/` Bash boundary remains unchanged |
| `README.md` | review audit | skip | skipped | No root install, usage, command, compatibility, or quick-start change |
| `docs/ship-flow/README.md` | existing W3 evidence | preserve | preserved | Explicit workflow-dir guard and #24 link already landed and remain intact |

</details>

## Token Summary

Budget: not recorded; shape appetite is small-batch (1-2 days)
Actual: not recorded in entity frontmatter
Ratio: not available

## Review Report

status: passed — historical review; current-head merge readiness pending final agy/CI
stage_cost: historical review panel plus agy block, worker correction, and EM adjudication

<details>
<summary>Review evidence and Science Officer/EM judgment</summary>

verify_results: historical required claims 11/11; post-repair density syntax + 51/51 PASS; final agy/CI PENDING
verify_uat_contract: `faaad26` + `4e0c53d` + `d7be3a4`, corrected at `fc6ef1e`; DC-10 is a read-only helper/discover-adopter closure plus receipt audit; never executed during review
canonical_sync_status: PASS — seven canonical-doc-sync checker outcomes passed with no blockers
harvest_gate: required; two bounded reusable candidates captured
review_scope: isolated branch `iamcxa/issue-20-fixture-discovery` from origin/main `38c588d`; issue #20 allowlist plus review metadata only
acceptance_receipt: immutable cycle-3 receipt bound to the sole `discover-adopter-skills.sh --root=.` launch at original frozen commit `1b3871f8cfb1f811813605e48f7c22922d686162`; count 1, process rc 0, stdout 193 bytes, stderr 0 bytes, routes 0; pre-launch setup failure count 0
acceptance_closure: helper `ce0447c9792b31038b912daa21deaf97bb5a8748` plus discover-adopter `2c183a1cd5c178f3f8f2c5fe7432acfacd96becc`, identical at frozen and `fc6ef1e`; applicable `check-invariants.sh` isolation blob `5d21b50ad24faa6b052a43e0964a333627a3df61`
density_repair: separate post-acceptance lane at `fc6ef1e`; implementation blob `7098af017e1632d2c54b6a3be9a9911464cc11c3`, test blob `f6de6e98bf712231f11d2a7185f2f21a256e4178`, focused suite 51/51
no_replay_boundary: repository-root discovery, emulation, reconstruction, indirect invocation, receipt edits, and capture edits are permanently forbidden
signal_warning: accepted nonblocking `EXIT INT TERM` cleanup semantics note carried to release
cross_review: agy BLOCK at `904599d`; `fc6ef1e` closes findings 1-2 locally; final agy PENDING
static_recheck: PASS — HEAD absence is limited to `_commit_has_fo_stage_entry_receipt`; only newly added diff lines reject that symbol or C14 beyond origin/main
started_at: 2026-07-13T10:45:14Z
completed_at: 2026-07-13T10:59:05Z

```yaml
science_officer_em_upward_report:
  subject: {entity: fixture-pollution-discovery-helpers, stage: review, report_kind: review-closeout}
  em_judgment: "code/test repair fc6 closes agy findings 1-2; density suite is now 51/51; signal trap remains accepted nonblocking."
  evidence_synthesis: ["904599d agy BLOCK plus focused RED", "fc6ef1e density 51/51 and exact zero-match/error observables", "unchanged helper/discover-adopter acceptance closure"]
  risk_tradeoff_call: "Keep DC-10 bound only to the sole discover-adopter command; density is a separate post-acceptance repair lane."
  recommendation: "Hold merge until final agy and current-head CI pass; never replay or reconstruct acceptance."
  route: hold
  confidence: high
  fo_boundary: "FO owns workflow mechanics; EM owns judgment and recommendation."
```

</details>

### Captain-Ack Audit

stub_flags: none — plan hand-off records no stubs; no Captain acknowledgment is required.

### Metrics

status: passed
duration_minutes: 14
iteration_count: 2
canonical_docs_updated_count: 1
canonical_docs_skipped_count: 3
pr_number: 32

### Hand-off to Ship

- `pr_url`: https://github.com/iamcxa/spacedock-workflows/pull/32 — live updates remain FO-owned.
- `review_verdict`: HOLD — `fc6ef1e` locally closes agy findings 1-2, but final agy and current-head CI are pending.
- `captain_ack_stubs`: true — no stub flags exist.
- `roadmap_row_ready`: true — commit `3c9f83e` moved the entity from Later to Shipped.
- `umbrella_closeout`: no — standalone pitch with no parent or children.
- Preserve the no-replay boundary, keep density outside the acceptance receipt, and carry the accepted signal-cleanup warning into release notes.

<!-- /section:review-report -->
