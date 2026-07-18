#!/usr/bin/env bash
# Keep the 101-commit GitHub pagination matrix under the per-test CI timeout.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SHIP_FLOW_CLOSEOUT_CASE=provider-pagination \
  bash "${SCRIPT_DIR}/test-merged-pr-closeout-reconciler.sh"
