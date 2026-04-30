#!/usr/bin/env bash
# canonical-doc-sync-checker.sh - read-only checker for review/ship canonical doc outcomes
#
# Usage:
#   bash plugins/ship-flow/bin/canonical-doc-sync-checker.sh <entity-dir>

set -euo pipefail

usage() {
  echo "Usage: canonical-doc-sync-checker.sh <entity-dir>" >&2
  echo "Read-only dry-run only. No write mode is available." >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

case "$1" in
  --fix|--write|--apply|--sync|--repair)
    usage
    exit 2
    ;;
esac

ENTITY_DIR="$1"
ENTITY_FILE="${ENTITY_DIR}/index.md"
REVIEW_FILE="${ENTITY_DIR}/review.md"
SHIP_FILE="${ENTITY_DIR}/ship.md"
BLOCKERS=0

emit_pass() {
  echo "PASS $1"
}

emit_blocker() {
  echo "BLOCKER $1"
  BLOCKERS=$((BLOCKERS + 1))
}

emit_recommended() {
  echo "RECOMMENDED $1"
}

if [ ! -d "$ENTITY_DIR" ]; then
  emit_blocker "entity-dir: directory not found: ${ENTITY_DIR}"
  exit 1
fi

if [ ! -f "$ENTITY_FILE" ]; then
  emit_blocker "entity-file: missing ${ENTITY_FILE}"
  exit 1
fi

ARTIFACT_FILE=""
if [ -f "$REVIEW_FILE" ]; then
  ARTIFACT_FILE="$REVIEW_FILE"
elif [ -f "$SHIP_FILE" ]; then
  ARTIFACT_FILE="$SHIP_FILE"
else
  emit_blocker "review-artifact: missing review.md or ship.md in ${ENTITY_DIR}"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
SECTION_FILE="${TMP_DIR}/canonical-docs-section.md"

awk '
  /^##[[:space:]]+Canonical Docs Update[[:space:]]*$/ {
    in_section = 1
    found = 1
    next
  }
  in_section && /^##[[:space:]]+/ {
    in_section = 0
  }
  in_section {
    print
  }
  END {
    if (!found) {
      exit 1
    }
  }
' "$ARTIFACT_FILE" > "$SECTION_FILE" || {
  emit_blocker "canonical-docs-section: missing ## Canonical Docs Update in ${ARTIFACT_FILE}"
  exit 1
}

line_for_doc() {
  local doc="$1"
  grep -Ei '(^[[:space:]]*[-*][[:space:]]*`?'"${doc}"'`?[[:space:]]*:)|(^[[:space:]]*\|[[:space:]]*`?'"${doc}"'`?[[:space:]]*\|)' "$SECTION_FILE" | head -n 1 || true
}

is_weak_skip_rationale() {
  local line="$1"
  local rationale
  rationale="$(printf '%s\n' "$line" | sed -E 's/.*[Ss][Kk][Ii][Pp][Pp]?[Ee]?[Dd]?[*`[:space:]]*[-—:|]?[[:space:]]*//')"
  rationale="$(printf '%s\n' "$rationale" | sed -E 's/[|[:space:]]*$//; s/^[`*[:space:]]+//; s/[`*[:space:]]+$//')"
  local lowered
  lowered="$(printf '%s\n' "$rationale" | tr '[:upper:]' '[:lower:]')"

  case "$lowered" in
    ""|"-"|"--"|"n/a"|"na"|"none"|"no"|"no rationale"|"not applicable"|"skip"|"skipped"|"tbd"|"todo")
      return 0
      ;;
  esac

  if [ "${#rationale}" -lt 12 ]; then
    return 0
  fi

  return 1
}

check_doc() {
  local doc="$1"
  local line
  line="$(line_for_doc "$doc")"

  if [ -z "$line" ]; then
    emit_blocker "${doc}: missing canonical docs outcome"
    return
  fi

  if printf '%s\n' "$line" | grep -qi 'skipped'; then
    if is_weak_skip_rationale "$line"; then
      emit_recommended "${doc}: weak skip rationale"
    else
      emit_pass "${doc}: explicit skip rationale"
    fi
    return
  fi

  emit_pass "${doc}: outcome present"
}

needs_umbrella_closeout() {
  awk '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 {
      if ($0 ~ /^[[:space:]]*pattern:[[:space:]]*"?shaped-child"?[[:space:]]*$/) found = 1
      if ($0 ~ /^[[:space:]]*parent_pitch:[[:space:]]*/) found = 1
      if ($0 ~ /^[[:space:]]*pattern:[[:space:]]*"?pitch"?[[:space:]]*$/) found = 1
      if ($0 ~ /^[[:space:]]*entity_type:[[:space:]]*"?epic"?[[:space:]]*$/) found = 1
      if ($0 ~ /^[[:space:]]*children:[[:space:]]*/) found = 1
    }
    END { exit !found }
  ' "$ENTITY_FILE"
}

check_umbrella_closeout() {
  if grep -Eiq '^[[:space:]]*[-*][[:space:]]*Umbrella closeout[[:space:]]*:|^[[:space:]]*\|[[:space:]]*Umbrella closeout[[:space:]]*\|' "$SECTION_FILE"; then
    emit_pass "umbrella-closeout: outcome present"
  elif needs_umbrella_closeout; then
    emit_blocker "umbrella-closeout: missing Umbrella closeout outcome"
  else
    emit_pass "umbrella-closeout: not required for standalone entity"
  fi
}

check_doc "ARCHITECTURE.md"
check_doc "PRODUCT.md"
check_doc "ROADMAP.md"
check_umbrella_closeout

if [ "$BLOCKERS" -gt 0 ]; then
  exit 1
fi

exit 0
