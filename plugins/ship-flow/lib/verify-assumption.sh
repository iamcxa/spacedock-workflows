#!/usr/bin/env bash
# verify-assumption.sh — run a stated_assumption's verification command,
# emit a single JSON line summarising result, and exit with a coded exit code.
#
# Usage:
#   bash verify-assumption.sh --entity=<path> --assumption=<id> [--timeout=<secs>]
#
# Exit codes:
#   0  pass
#   1  fail — criticality: critical
#   2  fail — criticality: important
#   3  fail — criticality: nice-to-know
#  10  error (missing file, missing assumption, missing yq, malformed)
#  11  timeout
#
# Stdout (single line JSON):
#   {"id":"A1","result":"pass|fail","criticality":"critical","verification_output":"...","duration_ms":142}
#
# Phase 1 Task 1.2. Consumed by Phase 4 (stage-entry verify wrapper).

set -uo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() {
  echo "ERROR: $*" >&2
  exit 10
}

now_ms() {
  # macOS BSD date +%s%3N outputs trailing literal 'N' (e.g. 17768620463N).
  # Detect any non-digit character in output and fall back to python3.
  local t
  t=$(date +%s%3N 2>/dev/null)
  # shellcheck disable=SC2086
  if [ -z "$t" ] || printf '%s' "$t" | grep -qE '[^0-9]'; then
    t=$(python3 -c 'import time; print(int(time.time()*1000))')
  fi
  printf '%s' "$t"
}

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------

ENTITY=""
ASSUMPTION_ID=""
TIMEOUT_SECS=30

for arg in "$@"; do
  case "$arg" in
    --entity=*)   ENTITY="${arg#--entity=}" ;;
    --assumption=*) ASSUMPTION_ID="${arg#--assumption=}" ;;
    --timeout=*)  TIMEOUT_SECS="${arg#--timeout=}" ;;
    *) die "Unknown argument: $arg" ;;
  esac
done

[ -n "$ENTITY" ]        || die "--entity is required"
[ -n "$ASSUMPTION_ID" ] || die "--assumption is required"

# ---------------------------------------------------------------------------
# Validate preconditions
# ---------------------------------------------------------------------------

[ -f "$ENTITY" ] || die "Entity file not found: $ENTITY"
command -v yq >/dev/null 2>&1 || die "yq is required but not found in PATH"

# ---------------------------------------------------------------------------
# Extract frontmatter YAML
# ---------------------------------------------------------------------------

FM_FILE="$(mktemp)"
trap 'rm -f "$FM_FILE"' EXIT INT TERM

awk '/^---$/{c++; if(c==2){exit}; next} c==1{print}' "$ENTITY" > "$FM_FILE"

# ---------------------------------------------------------------------------
# Extract the requested assumption block
# ---------------------------------------------------------------------------

ASSUMPTION_YAML="$(yq ".stated_assumptions[] | select(.id == \"${ASSUMPTION_ID}\")" "$FM_FILE" 2>/dev/null || true)"

if [ -z "$ASSUMPTION_YAML" ]; then
  die "Assumption '${ASSUMPTION_ID}' not found in ${ENTITY}"
fi

# Write the assumption fragment to its own temp file for field extraction
ASSUMP_FILE="$(mktemp)"
trap 'rm -f "$FM_FILE" "$ASSUMP_FILE"' EXIT INT TERM
printf '%s\n' "$ASSUMPTION_YAML" > "$ASSUMP_FILE"

VERIFICATION="$(yq '.verification' "$ASSUMP_FILE" 2>/dev/null || true)"
CRITICALITY="$(yq '.criticality' "$ASSUMP_FILE" 2>/dev/null || true)"

[ -z "$VERIFICATION" ] || [ "$VERIFICATION" = "null" ] && die "Assumption '${ASSUMPTION_ID}' has no 'verification' field"
[ -z "$CRITICALITY" ]  || [ "$CRITICALITY" = "null" ] && die "Assumption '${ASSUMPTION_ID}' has no 'criticality' field"

# ---------------------------------------------------------------------------
# Find timeout binary (prefer gtimeout on macOS)
# ---------------------------------------------------------------------------

TIMEOUT_BIN="$(command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null || true)"
[ -n "$TIMEOUT_BIN" ] || die "Neither gtimeout nor timeout found in PATH"

# ---------------------------------------------------------------------------
# Run verification command
# ---------------------------------------------------------------------------

OUT_FILE="$(mktemp)"
trap 'rm -f "$FM_FILE" "$ASSUMP_FILE" "$OUT_FILE"' EXIT INT TERM

START_MS="$(now_ms)"

"$TIMEOUT_BIN" "$TIMEOUT_SECS" bash -c "$VERIFICATION" > "$OUT_FILE" 2>&1
RC=$?

END_MS="$(now_ms)"
DURATION_MS=$((END_MS - START_MS))

# ---------------------------------------------------------------------------
# Build verification_output excerpt (safe for JSON)
# ---------------------------------------------------------------------------

VERIFY_OUT="$(tr '\n' ' ' < "$OUT_FILE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | head -c 500)"

# ---------------------------------------------------------------------------
# Emit JSON + exit
# ---------------------------------------------------------------------------

if [ "$RC" -eq 124 ]; then
  # Timeout
  printf '{"id":"%s","result":"fail","criticality":"%s","verification_output":"TIMEOUT after %ss","duration_ms":%s}\n' \
    "$ASSUMPTION_ID" "$CRITICALITY" "$TIMEOUT_SECS" "$DURATION_MS"
  exit 11
fi

if [ "$RC" -eq 0 ]; then
  RESULT="pass"
else
  RESULT="fail"
fi

printf '{"id":"%s","result":"%s","criticality":"%s","verification_output":"%s","duration_ms":%s}\n' \
  "$ASSUMPTION_ID" "$RESULT" "$CRITICALITY" "$VERIFY_OUT" "$DURATION_MS"

if [ "$RESULT" = "pass" ]; then
  exit 0
fi

# Fail exit codes by criticality
case "$CRITICALITY" in
  critical)     exit 1 ;;
  important)    exit 2 ;;
  nice-to-know) exit 3 ;;
  *)            exit 10 ;;
esac
