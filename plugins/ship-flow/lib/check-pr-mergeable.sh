#!/usr/bin/env bash
# check-pr-mergeable.sh - classify GitHub PR mergeability after PR creation

set -u

PR=""
MAX_ATTEMPTS=6
INTERVAL_SECONDS=5
GH_VIEW_JSON_FIXTURE=""
STATE_SEQUENCE_FIXTURE=""
PARSE_ERROR=0

usage() {
  cat >&2 <<'EOF'
usage: check-pr-mergeable.sh --pr <number|#number|url> [--max-attempts N] [--interval-seconds N] [--gh-view-json-fixture PATH] [--state-sequence-fixture PATH]
EOF
}

normalize_pr() {
  local raw="$1" number
  case "$raw" in
    \#*) number="${raw#\#}" ;;
    *"/pull/"*) number="${raw##*/pull/}"; number="${number%%[/?#]*}" ;;
    *) number="$raw" ;;
  esac
  case "$number" in
    ''|*[!0-9]*) return 1 ;;
    *) printf '#%s\n' "$number" ;;
  esac
}

conflict_files() {
  git diff --name-only --diff-filter=U 2>/dev/null | paste -sd, - 2>/dev/null || true
}

sanitize_diagnostic() {
  printf '%s' "$1" | tr '\n\r\t' '   ' | tr -d '[:cntrl:]' | awk '{$1=$1; print}' | cut -c1-240
}

server_conflict_files() {
  local gh_pr="$1" stderr_file files rc context
  [ -z "$GH_VIEW_JSON_FIXTURE" ] || return 0
  [ -z "$STATE_SEQUENCE_FIXTURE" ] || return 0

  stderr_file="$(mktemp)"
  files="$(gh pr diff "$gh_pr" --name-only 2>"$stderr_file")"
  rc=$?
  context="$(sanitize_diagnostic "$(cat "$stderr_file" 2>/dev/null || true)")"
  rm -f "$stderr_file"

  if [ "$rc" -ne 0 ]; then
    [ -n "$context" ] || context="no stderr captured"
    printf "check-pr-mergeable: warning: unable to enumerate server conflict files via 'gh pr diff %s --name-only': %s\n" "$gh_pr" "$context" >&2
    return 0
  fi

  if [ -z "$files" ]; then
    printf "check-pr-mergeable: warning: unable to enumerate server conflict files via 'gh pr diff %s --name-only': no files returned\n" "$gh_pr" >&2
    return 0
  fi

  printf '%s\n' "$files" | awk 'NF { print }'
}

combine_conflict_files() {
  local local_files="$1" server_files="$2"
  {
    printf '%s\n' "$local_files" | tr ',' '\n'
    printf '%s\n' "$server_files"
  } | awk 'NF && !seen[$0]++ { out = out ? out "," $0 : $0 } END { print out }'
}

emit_report() {
  local verdict="$1" state_class="$2" pr="$3" status="$4" attempts="$5" started="$6" files="$7" action="$8" reason="$9"
  local now elapsed
  now="$(date +%s)"
  elapsed=$((now - started))
  printf 'helper=check-pr-mergeable\n'
  printf 'verdict=%s\n' "$verdict"
  printf 'state_class=%s\n' "$state_class"
  printf 'pr=%s\n' "$pr"
  printf 'merge_state_status=%s\n' "$status"
  printf 'attempts=%s\n' "$attempts"
  printf 'elapsed_seconds=%s\n' "$elapsed"
  printf 'conflict_files=%s\n' "$files"
  printf 'action=%s\n' "$action"
  printf 'reason=%s\n' "$reason"
}

read_json_fixture_status() {
  local fixture="$1"
  [ -r "$fixture" ] || return 1
  awk '
    match($0, /"mergeStateStatus"[[:space:]]*:[[:space:]]*"[^"]*"/) {
      value = substr($0, RSTART, RLENGTH)
      sub(/^.*:[[:space:]]*"/, "", value)
      sub(/"$/, "", value)
      print value
      found = 1
    }
    END { if (!found) exit 1 }
  ' "$fixture"
}

read_sequence_status() {
  local fixture="$1" attempt="$2"
  [ -r "$fixture" ] || return 1
  awk -v attempt="$attempt" '
    NR == attempt { print; found = 1; exit }
    { last = $0; seen = 1 }
    END {
      if (!found) {
        if (seen) print last
        else print ""
      }
    }
  ' "$fixture"
}

read_merge_state() {
  local attempt="$1" gh_pr="$2"
  if [ -n "$STATE_SEQUENCE_FIXTURE" ]; then
    read_sequence_status "$STATE_SEQUENCE_FIXTURE" "$attempt"
    return $?
  fi
  if [ -n "$GH_VIEW_JSON_FIXTURE" ]; then
    read_json_fixture_status "$GH_VIEW_JSON_FIXTURE"
    return $?
  fi
  gh pr view "$gh_pr" --json mergeStateStatus --jq '.mergeStateStatus'
}

has_option_value() {
  [ "$#" -ge 2 ] && [ "${2#--}" = "$2" ]
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pr)
      has_option_value "$@" || { usage; PARSE_ERROR=1; break; }
      PR="$2"
      shift 2
      ;;
    --max-attempts)
      has_option_value "$@" || { usage; PARSE_ERROR=1; break; }
      MAX_ATTEMPTS="$2"
      shift 2
      ;;
    --interval-seconds)
      has_option_value "$@" || { usage; PARSE_ERROR=1; break; }
      INTERVAL_SECONDS="$2"
      shift 2
      ;;
    --gh-view-json-fixture)
      has_option_value "$@" || { usage; PARSE_ERROR=1; break; }
      GH_VIEW_JSON_FIXTURE="$2"
      shift 2
      ;;
    --state-sequence-fixture)
      has_option_value "$@" || { usage; PARSE_ERROR=1; break; }
      STATE_SEQUENCE_FIXTURE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      PARSE_ERROR=1
      break
      ;;
  esac
done

STARTED="$(date +%s)"
NORMALIZED_PR="$(normalize_pr "$PR" 2>/dev/null || true)"

case "$MAX_ATTEMPTS" in ''|*[!0-9]*) MAX_ATTEMPTS=0 ;; esac
case "$INTERVAL_SECONDS" in ''|*[!0-9]*) INTERVAL_SECONDS=0 ;; esac

if [ "$PARSE_ERROR" -ne 0 ] || [ -z "$NORMALIZED_PR" ] || [ "$MAX_ATTEMPTS" -le 0 ]; then
  emit_report "PROMPT_CAPTAIN" "usage-error" "${NORMALIZED_PR:-}" "" 0 "$STARTED" "" "surface-to-captain" "usage-error"
  exit 2
fi

GH_PR_NUMBER="${NORMALIZED_PR#\#}"
attempt=1
last_status=""
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  merge_stderr_file="$(mktemp)"
  status="$(read_merge_state "$attempt" "$GH_PR_NUMBER" 2>"$merge_stderr_file")"
  rc=$?
  merge_error="$(sanitize_diagnostic "$(cat "$merge_stderr_file" 2>/dev/null || true)")"
  rm -f "$merge_stderr_file"
  if [ "$rc" -ne 0 ]; then
    if [ -z "$STATE_SEQUENCE_FIXTURE" ] && [ -z "$GH_VIEW_JSON_FIXTURE" ]; then
      [ -n "$merge_error" ] || merge_error="no stderr captured"
      printf "check-pr-mergeable: error: gh pr view failed for %s via 'gh pr view %s --json mergeStateStatus --jq .mergeStateStatus' (exit %s): %s\n" "$NORMALIZED_PR" "$GH_PR_NUMBER" "$rc" "$merge_error" >&2
    fi
    emit_report "PROMPT_CAPTAIN" "gh-failure" "$NORMALIZED_PR" "$last_status" "$attempt" "$STARTED" "" "surface-to-captain" "gh-pr-view-failed"
    exit 30
  fi
  last_status="$status"

  case "$status" in
    CLEAN)
      emit_report "OK" "clean" "$NORMALIZED_PR" "$status" "$attempt" "$STARTED" "" "continue" "merge-state-clean"
      exit 0
      ;;
    CONFLICTING)
      local_files="$(conflict_files)"
      server_files="$(server_conflict_files "$GH_PR_NUMBER")"
      emit_report "BLOCK" "conflicting" "$NORMALIZED_PR" "$status" "$attempt" "$STARTED" "$(combine_conflict_files "$local_files" "$server_files")" "branch-update-required" "merge-state-conflicting"
      exit 10
      ;;
    DIRTY)
      emit_report "BLOCK" "dirty" "$NORMALIZED_PR" "$status" "$attempt" "$STARTED" "$(conflict_files)" "branch-update-required" "merge-state-dirty"
      exit 11
      ;;
    UNSTABLE|BLOCKED)
      emit_report "PROMPT_CAPTAIN" "unknown" "$NORMALIZED_PR" "$status" "$attempt" "$STARTED" "" "surface-to-captain" "merge-state-unknown"
      exit 12
      ;;
    UNKNOWN|"")
      ;;
    *)
      emit_report "PROMPT_CAPTAIN" "unknown" "$NORMALIZED_PR" "$status" "$attempt" "$STARTED" "" "surface-to-captain" "merge-state-unknown"
      exit 12
      ;;
  esac

  if [ "$attempt" -lt "$MAX_ATTEMPTS" ] && [ "$INTERVAL_SECONDS" -gt 0 ]; then
    sleep "$INTERVAL_SECONDS"
  fi
  attempt=$((attempt + 1))
done

emit_report "PROMPT_CAPTAIN" "timeout" "$NORMALIZED_PR" "$last_status" "$MAX_ATTEMPTS" "$STARTED" "" "surface-to-captain" "merge-state-timeout"
exit 20
