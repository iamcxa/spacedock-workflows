#!/usr/bin/env bash
# Render the 130.3 upward-facing Science Officer (EM) report contract.

set -euo pipefail

cat <<'CONTRACT'
### Science Officer (EM) Upward Report Contract

Use this structured block whenever Science Officer (EM) judgment is reported upward to FO/captain-facing verify, review, ship, semantic-review, or cross-stage surfaces.

```yaml
science_officer_em_upward_report:
  subject:
    entity: "<id-slug or PR/ref>"
    stage: "<shape|design|plan|execute|verify|review|ship|cross-stage>"
    report_kind: "<stage-handoff|verify-synthesis|semantic-review|review-closeout|ship-summary|risk-escalation>"
  em_judgment: "<the EM's own engineering call, not FO or worker status>"
  evidence_synthesis:
    - "<source artifact, command output, reviewer finding, file/path ref, or durable evidence>"
    - "<second independent evidence item>"
  risk_tradeoff_call: "<risk, trade-off, assumption, professional concern, or accepted residual risk>"
  recommendation: "<concrete next action for FO/captain>"
  route: "<proceed|narrow|return|block|costly_no>"
  confidence: "<high|medium|low>"
  fo_boundary: "FO owns workflow mechanics; EM owns judgment and recommendation."
```

Invalid reports include status-only relay, worker transcript/checklist digest, green "no blockers" summary without judgment, missing route/confidence, and any report granting EM FO-owned workflow mechanics such as entity state, worktrees, dispatch, PR creation/merge, or stage advancement.

Verification must inspect output-shape evidence and artifact content, not worker self-attestation, skill-load receipts, or canary echoes.
CONTRACT
