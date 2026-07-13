<!-- section:review-report -->
## What Worked

Status: captured

1. Pattern: fail-loud producer status makes an empty discovery receipt trustworthy
   Trigger: A healthy empty result can otherwise be indistinguishable from a suppressed traversal failure.
   Action: Preserve producer status as 0/1/2, buffer output until every producer succeeds, and inject focused failures for every traversal branch before accepting an empty result.
   Evidence: DC-5 and DC-6 record adopter 38/38 and density 41/41 fail-loud behavior; DC-10 binds the immutable cycle-3 receipt to original frozen commit `1b3871f8cfb1f811813605e48f7c22922d686162`, process rc 0, stdout 193 bytes, stderr 0 bytes, and routes 0.
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

PR body composed by ship-final (`/ship` Step 6.3) from `shape.md` (canonical Problem / User Journey / Done Criteria) + verify UAT table + Quality Gate + execute Execution Log, materialized as the external GitHub PR body (NOT committed to ship.md). See `stages.ship.pr_payload` in entity-body-schema.yaml. Not restated here. The future PR body closes #20; #21 and #24 remain related evidence only.

## Per-Feature Retrospective

**Shipped this entity**: [fixture-pollution-discovery-helpers](index.md)

**Deferred via `ship-flow:add-todos`** (`/ship-flow:add-todos list`): 0 informational + 0 critical-confidence<8 findings.

Risks accepted: none — no CRITICAL finding was accepted as-is.

**Verify Panel Coverage**: Tier B · PR Quality Score 9.5/10 · Adversarial: independent collaboration reviewer passed; external Claude/Codex DEGRADED

**Accepted release note**: Combined `EXIT INT TERM` cleanup traps do not explicitly terminate after a caught signal on Bash 3.2; this remains nonblocking and does not reopen frozen source.

**What Worked**: Fail-loud 0/1/2 producer status plus focused injected failures made the immutable empty DC-10 receipt trustworthy → `promote-to-ship-verify.md`.

**What Almost Failed**: One-shot setup must validate parent paths and capture descriptors before starting the process clock → `promote-to-ship-execute.md`.

## Canonical Docs Update

- `ARCHITECTURE.md`: skipped — internal caller-owned capture and pruning mechanics do not change durable component, data-flow, storage, or API boundaries.
- `PRODUCT.md`: skipped — this repairs correctness of an existing discovery capability and adds no durable user-facing capability.
- `README.md`: skipped at review — no root install, usage, command, compatibility, or quick-start contract changes.
- `docs/ship-flow/README.md`: preserved — the explicit `--workflow-dir docs/ship-flow` guard and related #24 link already landed and remain intact.
- `ROADMAP.md`: `3c9f83e` — moved `fixture-pollution-discovery-helpers` from Later to Shipped with the verified fixture-pruning and fail-loud outcome.
- Umbrella closeout: no — standalone pitch with no parent or child entities; only its independently listed ROADMAP row closes.

### Canonical Doc Actions Consumed

| Doc | Action Source | Plan Action | Review Outcome | Commit Or Skip Rationale |
| --- | --- | --- | --- | --- |
| `ROADMAP.md` | spec | update | updated | `3c9f83e`; Later → Shipped with verified outcome |
| `PRODUCT.md` | design | skip | skipped | Existing internal correctness repair; no new capability |
| `ARCHITECTURE.md` | design | skip | skipped | Existing `lib/` Bash boundary remains unchanged |
| `README.md` | review audit | skip | skipped | No root install, usage, command, compatibility, or quick-start change |
| `docs/ship-flow/README.md` | existing W3 evidence | preserve | preserved | Explicit workflow-dir guard and #24 link already landed and remain intact |

## Token Summary

Budget: not recorded; shape appetite is small-batch (1-2 days)
Actual: not recorded in entity frontmatter
Ratio: not available

## Review Report

status: passed
stage_cost: one clean review worker, one fresh independent seven-factor reviewer, and final Science Officer/EM judgment
verify_results: PASS; required claims 11/11; Tier B accepted; independent collaboration fallback passed; external Claude/Codex transports DEGRADED
verify_uat_contract: `faaad26` + `4e0c53d` + `d7be3a4`; bounded copy-paste procedures for DC-1 through DC-9 and read-only clean-scope object/hash/receipt audit for DC-10; not executed during review
canonical_sync_status: pending post-write checker
harvest_gate: required; two bounded reusable candidates captured
review_scope: isolated branch `iamcxa/issue-20-fixture-discovery` from origin/main `38c588d`; issue #20 allowlist plus review metadata only
acceptance_receipt: immutable cycle-3 receipt bound to original frozen commit `1b3871f8cfb1f811813605e48f7c22922d686162`; sole launch count 1, process rc 0, stdout 193 bytes, stderr 0 bytes, routes 0; pre-launch setup failure count 0
mechanical_isolation_exception: six nonshared paths are byte-identical to `1b3871f8`; shared `check-invariants.sh` intentionally uses isolated blob `5d21b50ad24faa6b052a43e0964a333627a3df61`, whose origin/main diff contains only three #20 exclusion hunks, with no HEAD `_commit_has_fo_stage_entry_receipt` and no new `_commit_has_fo_stage_entry_receipt`/C14 surface beyond origin/main
no_replay_boundary: repository-root discovery, emulation, reconstruction, indirect invocation, receipt edits, and capture edits are permanently forbidden
signal_warning: accepted nonblocking `EXIT INT TERM` cleanup semantics note carried to release
cross_review: PROCEED — all seven factors pass; preserve DC-10 as immutable receipt-only evidence and retain the frozen-commit/blob binding through ship-final
static_recheck: PASS — HEAD absence is limited to `_commit_has_fo_stage_entry_receipt`; only newly added diff lines reject that symbol or C14 beyond origin/main
started_at: 2026-07-13T10:45:14Z
completed_at: 2026-07-13T10:58:10Z

```yaml
science_officer_em_upward_report:
  subject: {entity: fixture-pollution-discovery-helpers, stage: review, report_kind: review-closeout}
  em_judgment: "The isolated issue #20 branch, corrected bounded UAT contract, 11/11 verify claims, immutable receipt, and canonical-doc audit support PR readiness without reopening implementation."
  evidence_synthesis: ["verify.md PASS plus faaad26/4e0c53d/d7be3a4 safe DC-1 through DC-10 audit contract and corrected new-line-only isolation audit", "ROADMAP commit 3c9f83e plus explicit ARCHITECTURE/PRODUCT/root README skips and preserved workflow README guard"]
  risk_tradeoff_call: "Accept Tier B external Claude/Codex transport degradation and carry the isolated INT/TERM cleanup warning as nonblocking; never replay or reconstruct acceptance."
  recommendation: "Proceed to ship-final after the canonical-doc checker passes; the fresh seven-factor review and bounded static recheck both pass."
  route: proceed
  confidence: high
  fo_boundary: "FO owns workflow mechanics; EM owns judgment and recommendation."
```

### Captain-Ack Audit

stub_flags: none — plan hand-off records no stubs; no Captain acknowledgment is required.

### Metrics

status: passed
duration_minutes: 13
iteration_count: 2
canonical_docs_updated_count: 1
canonical_docs_skipped_count: 3
pr_number: not-created

### Hand-off to Ship

- `pr_url`: not-created — ship-final owns PR creation.
- `review_verdict`: PROCEED — fresh seven-factor review and bounded DC-10 static recheck passed.
- `captain_ack_stubs`: true — no stub flags exist.
- `roadmap_row_ready`: true — commit `3c9f83e` moved the entity from Later to Shipped.
- `umbrella_closeout`: no — standalone pitch with no parent or children.
- Preserve the no-replay boundary and carry the accepted signal-cleanup warning into release notes.

<!-- /section:review-report -->
