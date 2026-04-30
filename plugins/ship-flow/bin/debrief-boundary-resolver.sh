#!/usr/bin/env bash
# debrief-boundary-resolver.sh — read-only debrief boundary classifier
#
# Usage:
#   bash plugins/ship-flow/bin/debrief-boundary-resolver.sh <workflow-dir> <draft-file>

set -euo pipefail

usage() {
  echo "Usage: debrief-boundary-resolver.sh <workflow-dir> <draft-file>" >&2
  echo "Read-only dry-run only. No debrief, entity, or issue write mode is available." >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

case "$1" in
  --fix|--write|--apply|--create|--file-issue)
    usage
    exit 2
    ;;
esac

WORKFLOW_DIR="$1"
DRAFT_FILE="$2"

if [ ! -d "$WORKFLOW_DIR" ]; then
  echo "BLOCKER workflow-dir: directory not found: ${WORKFLOW_DIR}"
  exit 2
fi

if [ ! -f "$DRAFT_FILE" ]; then
  echo "BLOCKER draft-file: file not found: ${DRAFT_FILE}"
  exit 2
fi

clean_line() {
  sed -E 's/^[[:space:]]*[-*][[:space:]]+//; s/^[[:space:]]*[0-9]+[.)][[:space:]]+//; s/[[:space:]]+$//'
}

extract_title() {
  awk '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 && /^[[:space:]]*title:[[:space:]]*/ {
      value = $0
      sub(/^[[:space:]]*title:[[:space:]]*/, "", value)
      gsub(/^["'\'']|["'\'']$/, "", value)
      print value
      exit
    }
  ' "$1"
}

token_overlap_score() {
  local text="$1"
  local metadata="$2"
  awk -v text="$text" -v metadata="$metadata" '
    function collect(value, bucket, parts, i, token) {
      value = tolower(value)
      gsub(/[^a-z0-9.]+/, " ", value)
      split(value, parts, /[[:space:]]+/)
      for (i in parts) {
        token = parts[i]
        if (length(token) < 4) {
          continue
        }
        if (token ~ /^(this|that|with|from|into|should|already|covers|later|after|before|resolver|read|only|sync)$/) {
          continue
        }
        bucket[token] = 1
      }
    }
    BEGIN {
      collect(text, line_tokens)
      collect(metadata, meta_tokens)
      for (token in line_tokens) {
        if (token in meta_tokens) {
          score++
        }
      }
      print score + 0
    }
  '
}

match_existing_entity() {
  local text="$1"
  local best_slug=""
  local best_score=0
  local index_file slug title metadata score

  while IFS= read -r index_file; do
    slug="$(basename "$(dirname "$index_file")")"
    title="$(extract_title "$index_file")"
    metadata="${slug} ${title}"
    score="$(token_overlap_score "$text" "$metadata")"
    if [ "$score" -gt "$best_score" ]; then
      best_score="$score"
      best_slug="$slug"
    fi
  done < <(find "$WORKFLOW_DIR" -mindepth 2 -maxdepth 2 -name index.md -type f | sort)

  if [ "$best_score" -ge 2 ]; then
    printf '%s\n' "$best_slug"
  fi
}

is_follow_up_candidate() {
  printf '%s\n' "$1" | grep -qiE 'follow[ -]?up|todo|next session|later|create (an? )?entity|new entity|backlog|planner'
}

is_spacedock_issue_candidate() {
  printf '%s\n' "$1" | grep -qiE 'spacedock|first officer|ensign|ship-flow|workflow|plugin|runtime|skill lookup|packaged skill' &&
    printf '%s\n' "$1" | grep -qiE 'bug|broken|fix|fails?|error|loses?|missing|regression|crash|cannot'
}

is_local_note() {
  printf '%s\n' "$1" | grep -qiE 'remember|note|observation|decision|preference|evidence|capture|keep'
}

has_existing_coverage_signal() {
  printf '%s\n' "$1" | grep -qiE 'already covers|covered by|existing|duplicate|same as'
}

escape_text() {
  printf '%s\n' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

AMBIGUOUS=0
LINE_NO=0

while IFS= read -r raw_line || [ -n "$raw_line" ]; do
  LINE_NO=$((LINE_NO + 1))
  text="$(printf '%s\n' "$raw_line" | clean_line)"
  if [ -z "$text" ]; then
    continue
  fi

  if ! is_local_note "$text" || has_existing_coverage_signal "$text"; then
    existing_slug="$(match_existing_entity "$text")"
    if [ -n "$existing_slug" ]; then
      printf 'EXISTING_ENTITY line=%s reason=existing-entity-match slug=%s text="%s"\n' "$LINE_NO" "$existing_slug" "$(escape_text "$text")"
      continue
    fi
  fi

  follow_up=0
  spacedock_issue=0
  is_follow_up_candidate "$text" && follow_up=1
  is_spacedock_issue_candidate "$text" && spacedock_issue=1

  if [ "$follow_up" -eq 1 ] && [ "$spacedock_issue" -eq 1 ]; then
    printf 'AMBIGUOUS line=%s reason=captain-input-required candidates=FOLLOW_UP_ENTITY,SPACEDOCK_ISSUE text="%s"\n' "$LINE_NO" "$(escape_text "$text")"
    AMBIGUOUS=1
  elif [ "$spacedock_issue" -eq 1 ]; then
    printf 'SPACEDOCK_ISSUE line=%s reason=spacedock-framework-issue text="%s"\n' "$LINE_NO" "$(escape_text "$text")"
  elif [ "$follow_up" -eq 1 ]; then
    printf 'FOLLOW_UP_ENTITY line=%s reason=follow-up-keyword text="%s"\n' "$LINE_NO" "$(escape_text "$text")"
  elif is_local_note "$text"; then
    printf 'DEBRIEF_ONLY line=%s reason=local-note text="%s"\n' "$LINE_NO" "$(escape_text "$text")"
  else
    printf 'DEBRIEF_ONLY line=%s reason=no-routing-signal text="%s"\n' "$LINE_NO" "$(escape_text "$text")"
  fi
done < "$DRAFT_FILE"

exit "$AMBIGUOUS"
