#!/usr/bin/env bash
# validate-pm-skill-receipts.sh — validate ship-shape PM delegate receipt block
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: validate-pm-skill-receipts.sh <shape.md>" >&2
  exit 1
fi

SHAPE_FILE="$1"
[ -f "$SHAPE_FILE" ] || { echo "ERROR: shape file not found: $SHAPE_FILE" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "ERROR: yq required for PM-skill receipt validation" >&2; exit 1; }

START_COUNT=$(grep -c '^<!-- section:pm-skill-receipts -->$' "$SHAPE_FILE" 2>/dev/null || true)
END_COUNT=$(grep -c '^<!-- /section:pm-skill-receipts -->$' "$SHAPE_FILE" 2>/dev/null || true)

if [ "$START_COUNT" -eq 0 ]; then
  echo "ERROR: missing section:pm-skill-receipts" >&2
  exit 1
fi
if [ "$START_COUNT" -gt 1 ]; then
  echo "ERROR: duplicate section:pm-skill-receipts" >&2
  exit 1
fi
if [ "$END_COUNT" -ne 1 ]; then
  echo "ERROR: malformed section:pm-skill-receipts markers" >&2
  exit 1
fi

TMP_YAML="$(mktemp)"
trap 'rm -f "$TMP_YAML"' EXIT

# shellcheck disable=SC2016 # Literal markdown fences, not shell expressions.
awk '
  /^<!-- section:pm-skill-receipts -->$/ { inside = 1; next }
  /^<!-- \/section:pm-skill-receipts -->$/ { inside = 0; next }
  inside { print }
' "$SHAPE_FILE" | sed '/^```yaml[[:space:]]*$/d; /^```[[:space:]]*$/d' > "$TMP_YAML"

if ! yq -e '.pm_skill_receipts.receipts | type == "!!seq"' "$TMP_YAML" >/dev/null 2>&1; then
  echo "ERROR: pm_skill_receipts.receipts must be a YAML sequence" >&2
  exit 1
fi

required_delegates=(
  "problem-framing-canvas"
  "opportunity-solution-tree"
  "pol-probe-advisor"
  "press-release"
)

FAIL=0

err() {
  echo "ERROR: $*" >&2
  FAIL=1
}

field_at() {
  local idx="$1" field="$2"
  yq -r ".pm_skill_receipts.receipts[${idx}].${field} // \"\"" "$TMP_YAML"
}

is_blank() {
  local value="$1"
  [ -z "$(printf '%s' "$value" | tr -d '[:space:]')" ] || [ "$value" = "null" ]
}

STAGE=$(yq -r '.pm_skill_receipts.stage // ""' "$TMP_YAML")
MODE=$(yq -r '.pm_skill_receipts.mode // ""' "$TMP_YAML")
APPETITE=$(yq -r '.pm_skill_receipts.appetite // ""' "$TMP_YAML")
COMPOSE_GUARD=$(yq -r '.pm_skill_receipts.compose_guard // ""' "$TMP_YAML")

if [ "$STAGE" != "ship-shape" ]; then
  err "pm_skill_receipts.stage must be ship-shape"
fi
if [ "$MODE" != "mode-a" ]; then
  err "pm_skill_receipts.mode must be mode-a"
fi
case "$APPETITE" in
  small-batch|medium-batch|big-batch) ;;
  *) err "pm_skill_receipts.appetite must be one of: small-batch, medium-batch, big-batch" ;;
esac
if [ "$COMPOSE_GUARD" != "passed" ]; then
  err "pm_skill_receipts.compose_guard must be passed"
fi

receipt_count=$(yq -r '.pm_skill_receipts.receipts | length' "$TMP_YAML")
for i in $(seq 0 $((receipt_count - 1))); do
  phase="$(field_at "$i" phase)"
  delegate="$(field_at "$i" delegate)"
  required="$(field_at "$i" required)"
  status="$(field_at "$i" status)"
  evidence="$(field_at "$i" evidence)"
  fallback="$(field_at "$i" fallback)"
  rationale="$(field_at "$i" rationale)"

  if is_blank "$delegate"; then
    err "receipt row $i missing delegate"
    continue
  fi

  expected_phase=""
  case "$delegate" in
    problem-framing-canvas) expected_phase="intake-problem" ;;
    opportunity-solution-tree) expected_phase="scope-decompose" ;;
    pol-probe-advisor) expected_phase="assumption-extract" ;;
    press-release) expected_phase="acceptance-outcome" ;;
  esac
  if [ -n "$expected_phase" ]; then
    if [ "$phase" != "$expected_phase" ]; then
      err "required delegate ${delegate} must have phase ${expected_phase}"
    fi
    if [ "$required" != "true" ]; then
      err "required delegate ${delegate} must set required: true"
    fi
  fi

  case "$status" in
    invoked)
      if is_blank "$evidence"; then
        err "invoked delegate ${delegate} missing evidence"
      fi
      ;;
    unavailable)
      if is_blank "$fallback"; then
        err "unavailable delegate ${delegate} missing fallback"
      fi
      if is_blank "$rationale"; then
        err "unavailable delegate ${delegate} missing rationale"
      fi
      ;;
    skipped)
      if is_blank "$rationale"; then
        err "skipped delegate ${delegate} missing rationale"
      fi
      if [ "$delegate" = "pol-probe-advisor" ] && { [ "$APPETITE" = "medium-batch" ] || [ "$APPETITE" = "big-batch" ]; }; then
        err "pol-probe-advisor cannot be skipped for ${APPETITE}"
      fi
      ;;
    *)
      err "invalid status for delegate ${delegate}: ${status:-<empty>}"
      ;;
  esac
done

for delegate in "${required_delegates[@]}"; do
  count=$(yq -r ".pm_skill_receipts.receipts | map(select(.delegate == \"${delegate}\")) | length" "$TMP_YAML")
  if [ "$count" -eq 0 ]; then
    err "missing required delegate: ${delegate}"
    continue
  fi
  if [ "$count" -gt 1 ]; then
    err "duplicate receipt row for delegate: ${delegate}"
    continue
  fi
done

exit "$FAIL"
