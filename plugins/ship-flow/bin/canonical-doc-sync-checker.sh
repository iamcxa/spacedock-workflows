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
PLAN_FILE="${ENTITY_DIR}/plan.md"
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

review_line_for_doc() {
  local doc="$1"
  local section="$2"
  grep -Ei '^[[:space:]]*\|[[:space:]]*`?'"${doc}"'`?[[:space:]]*\|' "$section" | head -n 1 || true
}

table_field() {
  local row="$1"
  local index="$2"
  trim_field "$(printf '%s\n' "$row" | awk -F'|' -v field_no="$index" '{print $field_no}')"
}

is_skipped_outcome() {
  local line="$1"
  printf '%s\n' "$line" | grep -Eiq '(^|[[:space:]:|—])skipped([[:space:]:|—.]|$)'
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

trim_field() {
  printf '%s\n' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^`//; s/`$//'
}

is_root_canonical_doc() {
  case "$1" in
    ARCHITECTURE.md|PRODUCT.md|ROADMAP.md) return 0 ;;
    *) return 1 ;;
  esac
}

is_repo_relative_markdown_doc() {
  case "$1" in
    ""|/*|../*|*/../*|*/..) return 1 ;;
    *.md) return 0 ;;
    *) return 1 ;;
  esac
}

is_valid_plan_action_doc() {
  local doc="$1"
  local source="$2"

  if is_root_canonical_doc "$doc"; then
    return 0
  fi

  if [ "$source" = "touched-files" ] && is_repo_relative_markdown_doc "$doc"; then
    return 0
  fi

  return 1
}

check_plan_canonical_doc_actions() {
  if [ ! -f "$PLAN_FILE" ]; then
    return
  fi

  local section="${TMP_DIR}/plan-canonical-doc-actions.md"
  local consumed_section="${TMP_DIR}/review-canonical-doc-actions-consumed.md"
  awk '
    /^###[[:space:]]+Canonical Doc Actions[[:space:]]*$/ {
      in_section = 1
      next
    }
    in_section && /^##(#)?[[:space:]]+/ {
      in_section = 0
    }
    in_section {
      print
    }
  ' "$PLAN_FILE" > "$section"

  if [ ! -s "$section" ]; then
    emit_blocker "canonical_doc_actions: missing ### Canonical Doc Actions in ${PLAN_FILE}"
    return
  fi

  awk '
    /^###[[:space:]]+Canonical Doc Actions Consumed[[:space:]]*$/ {
      in_section = 1
      next
    }
    in_section && /^##(#)?[[:space:]]+/ {
      in_section = 0
    }
    in_section {
      print
    }
  ' "$ARTIFACT_FILE" > "$consumed_section"

  if [ ! -s "$consumed_section" ]; then
    emit_blocker "canonical_doc_actions: missing ### Canonical Doc Actions Consumed in ${ARTIFACT_FILE}"
  fi

  for required_doc in ARCHITECTURE.md PRODUCT.md ROADMAP.md; do
    local count
    count="$(awk -F'|' -v doc="$required_doc" '
      function trim(s) {
        gsub(/^[[:space:]`]+|[[:space:]`]+$/, "", s)
        return s
      }
      /^\|/ {
        value = trim($2)
        if (value == doc) count++
      }
      END { print count + 0 }
    ' "$section")"

    if [ "$count" -eq 0 ]; then
      emit_blocker "canonical_doc_actions: ${required_doc} missing plan action row"
    elif [ "$count" -gt 1 ]; then
      emit_blocker "canonical_doc_actions: ${required_doc} duplicate plan action rows"
    fi
  done

  while IFS= read -r row; do
    case "$row" in
      "|"*) ;;
      *) continue ;;
    esac

    local doc action source rationale line
    doc="$(table_field "$row" 2)"
    action="$(table_field "$row" 3 | tr '[:upper:]' '[:lower:]')"
    source="$(table_field "$row" 4)"
    rationale="$(table_field "$row" 5)"

    case "$doc" in
      Doc|---|"") continue ;;
    esac

    case "$source" in
      spec|design|plan|touched-files) ;;
      *) emit_blocker "canonical_doc_actions: ${doc} invalid source ${source}" ;;
    esac

    if ! is_valid_plan_action_doc "$doc" "$source"; then
      emit_blocker "canonical_doc_actions: invalid doc ${doc}"
      continue
    fi

    local consumed_line
    consumed_line="$(review_line_for_doc "$doc" "$consumed_section")"
    if [ -z "$consumed_line" ]; then
      emit_blocker "canonical_doc_actions: ${doc} missing review consumption row"
    else
      local consumed_source consumed_action consumed_outcome
      consumed_source="$(table_field "$consumed_line" 3)"
      consumed_action="$(table_field "$consumed_line" 4 | tr '[:upper:]' '[:lower:]')"
      consumed_outcome="$(table_field "$consumed_line" 5 | tr '[:upper:]' '[:lower:]')"

      if [ "$consumed_source" != "$source" ]; then
        emit_blocker "canonical_doc_actions: ${doc} review consumption source ${consumed_source} does not match plan source ${source}"
      fi
      if [ "$consumed_action" != "$action" ]; then
        emit_blocker "canonical_doc_actions: ${doc} review consumption plan action ${consumed_action} does not match ${action}"
      fi
    fi

    case "$action" in
      update)
        if is_root_canonical_doc "$doc"; then
          line="$(line_for_doc "$doc")"
          if [ -z "$line" ] || is_skipped_outcome "$line"; then
            emit_blocker "canonical_doc_actions: ${doc} update from ${source} missing review outcome"
          elif [ -n "$consumed_line" ] && [ "$consumed_outcome" != "updated" ]; then
            emit_blocker "canonical_doc_actions: ${doc} update from ${source} not marked updated in review consumption"
          else
            emit_pass "canonical_doc_actions: ${doc} update from ${source} consumed"
          fi
        elif [ -z "$consumed_line" ]; then
          :
        elif [ "$consumed_outcome" != "updated" ]; then
          emit_blocker "canonical_doc_actions: ${doc} update from ${source} not marked updated in review consumption"
        else
          emit_pass "canonical_doc_actions: ${doc} update from ${source} consumed"
        fi
        ;;
      skip)
        if is_weak_skip_rationale "$rationale"; then
          emit_blocker "canonical_doc_actions: ${doc} skip from ${source} missing concrete rationale"
        elif [ -n "$consumed_line" ] && [ "$consumed_outcome" != "skipped" ]; then
          emit_blocker "canonical_doc_actions: ${doc} skip from ${source} not carried into review outcome"
        else
          emit_pass "canonical_doc_actions: ${doc} skip from ${source} consumed"
        fi
        ;;
      *)
        emit_blocker "canonical_doc_actions: ${doc} invalid action ${action}"
        ;;
    esac
  done < "$section"
}

check_doc "ARCHITECTURE.md"
check_doc "PRODUCT.md"
check_doc "ROADMAP.md"
check_umbrella_closeout
check_plan_canonical_doc_actions

if [ "$BLOCKERS" -gt 0 ]; then
  exit 1
fi

exit 0
