#!/usr/bin/env bash
# persist-pr-metadata.sh - persist created PR metadata onto a ship-flow entity

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
# shellcheck source=./map-helpers.sh
source "${SCRIPT_DIR}/map-helpers.sh"

ENTITY=""
PR_CREATE_OUTPUT=""
IF_HASH=""
MIRROR_ENTITY=""
GH_VIEW_JSON_FIXTURE=""
EXPECT_BODY_FILE=""

usage() {
  echo "Usage: persist-pr-metadata.sh --entity <index.md> --pr-create-output <file> --if-hash <sha256> [--expect-body-file <file>] [--mirror-entity <index.md>] [--gh-view-json-fixture <file>]" >&2
}

emit_report() {
  printf 'verdict=%s\n' "${verdict:-REJECT}"
  printf 'reason=%s\n' "${reason:-}"
  printf 'pr=%s\n' "${pr_display:-}"
  printf 'entity=%s\n' "${ENTITY:-}"
  printf 'mirror=%s\n' "${mirror_status:-not_applicable}"
  printf 'detail=%s\n' "${detail:-}"
}

reject() {
  verdict="REJECT"
  reason="$1"
  detail="${2:-}"
  emit_report
  exit 1
}

reject_usage() {
  verdict="REJECT"
  reason="usage"
  detail="$1"
  emit_report
  usage
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --entity=*) ENTITY="${1#--entity=}" ; shift ;;
    --entity) ENTITY="${2:-}" ; shift 2 ;;
    --pr-create-output=*) PR_CREATE_OUTPUT="${1#--pr-create-output=}" ; shift ;;
    --pr-create-output) PR_CREATE_OUTPUT="${2:-}" ; shift 2 ;;
    --if-hash=*) IF_HASH="${1#--if-hash=}" ; shift ;;
    --if-hash) IF_HASH="${2:-}" ; shift 2 ;;
    --mirror-entity=*) MIRROR_ENTITY="${1#--mirror-entity=}" ; shift ;;
    --mirror-entity) MIRROR_ENTITY="${2:-}" ; shift 2 ;;
    --gh-view-json-fixture=*) GH_VIEW_JSON_FIXTURE="${1#--gh-view-json-fixture=}" ; shift ;;
    --gh-view-json-fixture) GH_VIEW_JSON_FIXTURE="${2:-}" ; shift 2 ;;
    --expect-body-file=*) EXPECT_BODY_FILE="${1#--expect-body-file=}" ; shift ;;
    --expect-body-file) EXPECT_BODY_FILE="${2:-}" ; shift 2 ;;
    *) reject_usage "unknown argument: $1" ;;
  esac
done

[ -n "$ENTITY" ] || reject_usage "missing --entity"
[ -n "$PR_CREATE_OUTPUT" ] || reject_usage "missing --pr-create-output"
[ -n "$IF_HASH" ] || reject_usage "missing --if-hash"
[ -f "$ENTITY" ] || reject "missing-entity" "entity file not found"
[ -f "$PR_CREATE_OUTPUT" ] || reject "missing-pr-create-output" "PR create output file not found"

extract_pr_number() {
  local file="$1"
  awk '
    {
      for (i = 1; i <= NF; i++) {
        token = $i
        gsub(/[),.;]+$/, "", token)
        if (match(token, /\/pulls?\/[0-9]+$/)) {
          number = token
          sub(/^.*\/pulls?\//, "", number)
          print number
          exit
        }
      }
    }
  ' "$file"
}

json_number() {
  local file="$1"
  sed -nE 's/.*"number"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' "$file" | head -1
}

# Extract the JSON string value of "body" from a `gh pr view --json ... body`
# document into a raw (decoded) string. Prefer python3 (handles \n, \", unicode
# escapes); fall back to a best-effort sed decode of the common escapes when
# python3 is unavailable. Prints nothing when no body field is present.
json_body() {
  local file="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" <<'PY'
import json, sys
try:
    obj = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
b = obj.get("body")
if b is None:
    sys.exit(0)
sys.stdout.write(b)
PY
  else
    # Fallback: pull the "body":"..." value and decode the common JSON escapes.
    sed -nE 's/.*"body"[[:space:]]*:[[:space:]]*"(.*)"[^"]*}[[:space:]]*$/\1/p' "$file" \
      | head -1 \
      | sed -e 's/\\n/\n/g' -e 's/\\t/\t/g' -e 's/\\"/"/g' -e 's/\\\\/\\/g'
  fi
}

# Normalize a body for comparison: strip CR (CRLF→LF), then drop final blank
# lines. Per-line trailing spaces are meaningful Markdown and must be preserved.
normalize_body() {
  awk '{ sub(/\r$/, ""); print }' \
    | awk 'BEGIN{n=0} {lines[n++]=$0} END{ while(n>0 && lines[n-1]=="") n--; for(i=0;i<n;i++) print lines[i] }'
}

confirm_pr_number() {
  local number="$1"
  # One round-trip: fetch number + body together (real `gh` adds `body` to the
  # --json field list; fixture mode reads the fixture which may carry `body`).
  if [ -n "$GH_VIEW_JSON_FIXTURE" ]; then
    [ -f "$GH_VIEW_JSON_FIXTURE" ] || reject "pr-view-unconfirmed" "gh view fixture missing"
    confirmed_number="$(json_number "$GH_VIEW_JSON_FIXTURE")"
    confirmed_body="$(json_body "$GH_VIEW_JSON_FIXTURE")"
  else
    command -v gh >/dev/null 2>&1 || reject "pr-view-unconfirmed" "gh CLI not found"
    local tmp
    tmp="$(mktemp)"
    if ! gh pr view "$number" --json number,url,headRefName,headRefOid,state,body > "$tmp"; then
      rm -f "$tmp"
      reject "pr-view-unconfirmed" "gh pr view failed"
    fi
    confirmed_number="$(json_number "$tmp")"
    confirmed_body="$(json_body "$tmp")"
    rm -f "$tmp"
  fi
  [ "$confirmed_number" = "$number" ] || reject "pr-view-unconfirmed" "confirmed PR number mismatch"
}

# Confirm the CREATED PR body matches the gated body (the exact bytes uploaded
# via `gh pr create --body-file`). Skipped entirely when --expect-body-file is
# omitted (back-compat / backfill path). The created body comes from the same
# `gh pr view --json ... body` round-trip captured in confirm_pr_number.
confirm_pr_body() {
  [ -n "$EXPECT_BODY_FILE" ] || return 0  # arg absent → skip body check
  [ -f "$EXPECT_BODY_FILE" ] || reject "pr-body-mismatch" "expected body file not found"
  local expected actual
  expected="$(normalize_body < "$EXPECT_BODY_FILE")"
  actual="$(printf '%s' "${confirmed_body:-}" | normalize_body)"
  [ "$expected" = "$actual" ] || reject "pr-body-mismatch" "created PR body differs from gated body"
}

frontmatter_fence_count() {
  awk '/^---[[:space:]]*$/ { count++ } END { print count + 0 }' "$1"
}

read_frontmatter_field() {
  local file="$1"
  local key="$2"
  awk -v key="$key" '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 {
      prefix = key ":"
      if (index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        gsub(/^["'\''"]|["'\''"]$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

normalize_existing_pr() {
  local raw="$1"
  raw="${raw##*#}"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    printf '#%s\n' "$raw"
    return 0
  fi
  [ -z "$raw" ] && return 0
  return 1
}

write_pr_field() {
  local file="$1"
  local number="$2"
  local tmp
  tmp="$(mktemp "${file}.XXXXXX")" || return 1
  awk -v number="$number" '
    BEGIN { written = 0 }
    /^---[[:space:]]*$/ {
      fence++
      if (fence == 2 && !written) {
        print "pr: \"#" number "\""
        written = 1
      }
      print
      next
    }
    fence == 1 && /^pr:[[:space:]]*/ {
      print "pr: \"#" number "\""
      written = 1
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

slug_for_file() {
  local file="$1"
  local slug
  slug="$(read_frontmatter_field "$file" slug)"
  if [ -n "$slug" ]; then
    printf '%s\n' "$slug"
    return
  fi
  basename "$(dirname "$file")"
}

mirror_pr_field() {
  local mirror="$1"
  local number="$2"
  [ -n "$mirror" ] || { mirror_status="not_applicable"; return 0; }
  [ -f "$mirror" ] || { mirror_status="skipped"; return 0; }
  [ "$(frontmatter_fence_count "$mirror")" -ge 2 ] || { mirror_status="skipped"; return 0; }

  local active_slug mirror_slug mirror_existing mirror_normalized
  active_slug="$(slug_for_file "$ENTITY")"
  mirror_slug="$(slug_for_file "$mirror")"
  if [ -z "$active_slug" ] || [ "$active_slug" != "$mirror_slug" ]; then
    mirror_status="skipped"
    return 0
  fi

  mirror_existing="$(read_frontmatter_field "$mirror" pr)"
  mirror_normalized="$(normalize_existing_pr "$mirror_existing" || true)"
  if [ -n "$mirror_normalized" ] && [ "$mirror_normalized" != "$pr_display" ]; then
    mirror_status="conflict"
    reason="mirror-conflict"
    return 0
  fi
  if [ "$mirror_normalized" = "$pr_display" ]; then
    mirror_status="already-present"
    return 0
  fi

  write_pr_field "$mirror" "$number"
  mirror_status="written"
}

pr_number="$(extract_pr_number "$PR_CREATE_OUTPUT")"
[ -n "$pr_number" ] || reject "missing-pr-number" "no PR URL with /pull/<number> in create output"
pr_display="#${pr_number}"

confirm_pr_number "$pr_number"
confirm_pr_body

[ "$(frontmatter_fence_count "$ENTITY")" -ge 2 ] || reject "malformed-frontmatter" "entity frontmatter fences missing"

existing_pr="$(read_frontmatter_field "$ENTITY" pr)"
normalized_existing="$(normalize_existing_pr "$existing_pr" || true)"
if [ -n "$normalized_existing" ] && [ "$normalized_existing" != "$pr_display" ]; then
  reject "conflicting-pr" "entity already has different pr"
fi

current_hash="$(sha256_of "$ENTITY")"
if [ "$current_hash" != "$IF_HASH" ]; then
  if [ "$normalized_existing" = "$pr_display" ]; then
    verdict="OK"
    reason="already-present"
    mirror_status="not_applicable"
    emit_report
    exit 0
  fi
  reject "stale-entity-hash" "entity hash changed before pr metadata write"
fi

if [ "$normalized_existing" = "$pr_display" ]; then
  verdict="OK"
  reason="already-present"
  mirror_status="not_applicable"
  emit_report
  exit 0
fi

write_pr_field "$ENTITY" "$pr_number"
mirror_pr_field "$MIRROR_ENTITY" "$pr_number"
verdict="OK"
[ "${reason:-}" = "mirror-conflict" ] || reason="written"
emit_report
