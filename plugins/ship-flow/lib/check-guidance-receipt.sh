#!/usr/bin/env bash
# check-guidance-receipt.sh — enforce folder guidance read receipts in stage artifacts

set -euo pipefail

CONFIG=".claude/ship-flow/skill-routing.yaml"
FILES=""
ARTIFACT=""
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

usage() {
  cat <<'EOF'
check-guidance-receipt — verify execute/PR-feedback artifacts cite folder guidance

Usage:
  check-guidance-receipt.sh --files=<comma-separated-paths> --artifact=<path> [--config=<path>]

Checks:
  - non-root folder AGENTS.md/CLAUDE.md files resolved from touched files
  - file-signal skills from skill-routing.yaml
  - skills parsed from folder guidance docs

Exit codes:
  0  receipt complete
  2  usage error
  11 resolver/config error
  12 artifact missing required guidance or skill receipt
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --config=*)
      CONFIG="${1#--config=}"
      ;;
    --files=*)
      FILES="${1#--files=}"
      ;;
    --artifact=*)
      ARTIFACT="${1#--artifact=}"
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

[ -n "$FILES" ] || {
  echo "ERROR: --files is required" >&2
  usage >&2
  exit 2
}

[ -n "$ARTIFACT" ] || {
  echo "ERROR: --artifact is required" >&2
  usage >&2
  exit 2
}

[ -f "$ARTIFACT" ] || {
  echo "ERROR: artifact missing: $ARTIFACT" >&2
  exit 2
}

RESOLVE_OUT="$("${SCRIPT_DIR}/resolve-skill-routing.sh" --config="$CONFIG" --files="$FILES")" || {
  rc=$?
  echo "$RESOLVE_OUT" >&2
  exit "$rc"
}

value_for() {
  local key="$1"
  printf '%s\n' "$RESOLVE_OUT" | awk -F= -v k="$key" '$1 == k {print substr($0, length(k) + 2); exit}'
}

MISSING=0
GUIDANCE_FILES="$(value_for folder_guidance_files)"
ROUTE_SKILLS="$(value_for skills_needed)"
GUIDANCE_SKILLS="$(value_for folder_guidance_skills)"

require_artifact_text() {
  local kind="$1"
  local value="$2"
  [ -n "$value" ] || return 0
  if ! grep -Fq -- "$value" "$ARTIFACT"; then
    echo "missing_${kind}=$value"
    MISSING=1
  fi
}

for item in $(printf '%s' "$GUIDANCE_FILES" | tr ',' ' '); do
  require_artifact_text "guidance_file" "$item"
done

for item in $(printf '%s,%s' "$ROUTE_SKILLS" "$GUIDANCE_SKILLS" | tr ',' ' '); do
  require_artifact_text "skill" "$item"
done

if [ "$MISSING" -ne 0 ]; then
  exit 12
fi

echo "status=ok"
echo "artifact=$ARTIFACT"
echo "guidance_files=$GUIDANCE_FILES"
echo "skills=$ROUTE_SKILLS,$GUIDANCE_SKILLS" | sed 's/,$//'
exit 0
