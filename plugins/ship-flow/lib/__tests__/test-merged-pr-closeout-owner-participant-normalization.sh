#!/usr/bin/env bash
# Keep owner/participant path normalization on the top-level CI discovery surface.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SHIP_FLOW_CLOSEOUT_CASE=owner-participant-normalization \
  bash "${SCRIPT_DIR}/test-merged-pr-closeout-reconciler.sh"
