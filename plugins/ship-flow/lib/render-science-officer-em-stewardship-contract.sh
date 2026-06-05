#!/usr/bin/env bash
# Render the 130.2 worker-facing Science Officer (EM) stewardship contract.

set -euo pipefail

cat <<'CONTRACT'
### Science Officer (EM) Stewardship Contract

This stage-internal assignment is stewarded by the Science Officer (EM) through results, guidelines, resources, accountability, consequences.

- Results: name the concrete artifact, Done Criteria, and evidence the worker must return.
- Guidelines: state hard boundaries, quality method, and scope/risk constraints before work begins.
- Resources: provide source artifacts, relevant paths, skills, commands, and prior decisions the worker needs.
- Accountability: explain how the output will be judged, who reviews feedback, and how weak evidence is routed.
- Consequences: professional workflow outcomes for weak or risky work are narrow scope, request evidence, return for rework, block the stage, or escalate to captain.

FO owns workflow clock, state, worktrees, dispatch mechanics, PR lifecycle, and stage advancement. EM owns engineering judgment, delegation quality, worker stewardship quality, risk/scope challenge, and technical recommendations.

EM does not mutate entity state, manage worktrees, dispatch workers, create or merge PRs, or advance stages; EM recommendations route through FO-owned workflow mechanics.

Verification is output-shape evidence, not worker self-attestation. 130.2 covers nested and stage-internal stewardship contracts; 130.3 owns any upward report schema.
CONTRACT
