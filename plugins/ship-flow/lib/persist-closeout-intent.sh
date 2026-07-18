#!/usr/bin/env bash
# persist-closeout-intent.sh — sole CAS producer for pre-merge owner/method intent
set -euo pipefail

ENTITY=""
IF_HASH=""
MIRROR_ENTITY=""
MIRROR_IF_HASH=""
CLOSEOUT_OWNER=""
SHIP_FILE=""
SHIP_IF_HASH=""
MERGE_METHOD_INTENT=""
PARTICIPANTS=()
PARTICIPANT_HASHES=()

usage() {
  echo "Usage: persist-closeout-intent.sh --entity PATH --if-hash SHA256 [--mirror-entity PATH --mirror-if-hash SHA256] [--closeout-owner true|false] [--participant-entity PATH --participant-if-hash SHA256 ...] [--ship PATH --ship-if-hash SHA256 --merge-method-intent rebase|squash|merge_commit]" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --entity) ENTITY="${2:-}"; shift 2 ;;
    --if-hash) IF_HASH="${2:-}"; shift 2 ;;
    --mirror-entity) MIRROR_ENTITY="${2:-}"; shift 2 ;;
    --mirror-if-hash) MIRROR_IF_HASH="${2:-}"; shift 2 ;;
    --closeout-owner) CLOSEOUT_OWNER="${2:-}"; shift 2 ;;
    --participant-entity)
      [ "${3:-}" = "--participant-if-hash" ] && [ -n "${4:-}" ] || usage
      PARTICIPANTS+=("${2:-}")
      PARTICIPANT_HASHES+=("${4:-}")
      shift 4
      ;;
    --ship) SHIP_FILE="${2:-}"; shift 2 ;;
    --ship-if-hash) SHIP_IF_HASH="${2:-}"; shift 2 ;;
    --merge-method-intent) MERGE_METHOD_INTENT="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done

report_stop() { echo "verdict=STOP"; echo "reason=$1"; echo "detail=$2"; exit "${3:-1}"; }
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'
  fi
}
frontmatter_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    NR == 1 {
      if ($0 !~ /^---[[:space:]]*$/) exit 3
      opened=1
      next
    }
    opened && /^---[[:space:]]*$/ {
      closed=1
      if (found) print value
      exit 0
    }
    opened && index($0, field ":") == 1 && !found {
      value=substr($0,length(field)+2); sub(/^[[:space:]]*/,"",value); sub(/[[:space:]]*$/, "", value)
      gsub(/^"|"$/, "", value); found=1
    }
    END { if (!closed) exit 3 }
  ' "$file"
}
slug_for_file() {
  local file="$1" slug
  slug="$(frontmatter_field "$file" slug)"
  if [ -n "$slug" ]; then
    printf '%s\n' "$slug"
    return
  fi
  basename "$(dirname "$file")"
}
validate_frontmatter() {
  frontmatter_field "$1" __ship_flow_frontmatter_validation__ >/dev/null
}
normalize_pr() {
  local value="$1" number
  number="${value#\#}"
  case "$number" in ""|*[!0-9]*) return 1 ;; esac
  number="$(printf '%s' "$number" | sed 's/^0*//')"
  [ -n "$number" ] || return 1
  printf '%s\n' "$number"
}

[ -n "$ENTITY" ] && [ -n "$IF_HASH" ] || usage
[ "${#PARTICIPANTS[@]}" -eq "${#PARTICIPANT_HASHES[@]}" ] || usage
[ -f "$ENTITY" ] || report_stop missing-entity "$ENTITY"
[ "$(sha256_of "$ENTITY")" = "$IF_HASH" ] || report_stop stale-entity-hash "$ENTITY" 6
validate_frontmatter "$ENTITY" || report_stop malformed-frontmatter "$ENTITY"
case "$CLOSEOUT_OWNER" in ""|true|false) ;; *) usage ;; esac
case "$MERGE_METHOD_INTENT" in ""|rebase|squash|merge_commit) ;; *) usage ;; esac
if [ -n "$MIRROR_ENTITY" ]; then
  [ -n "$MIRROR_IF_HASH" ] || usage
  [ -f "$MIRROR_ENTITY" ] || report_stop missing-entity "$MIRROR_ENTITY"
  [ "$(sha256_of "$MIRROR_ENTITY")" = "$MIRROR_IF_HASH" ] || report_stop stale-entity-hash "$MIRROR_ENTITY" 6
  validate_frontmatter "$MIRROR_ENTITY" || report_stop malformed-frontmatter "$MIRROR_ENTITY"
fi
if [ -n "$MERGE_METHOD_INTENT" ]; then
  [ -n "$SHIP_FILE" ] && [ -n "$SHIP_IF_HASH" ] || usage
fi
if [ -n "$SHIP_FILE" ]; then
  [ -f "$SHIP_FILE" ] || report_stop closeout-ship-missing "$SHIP_FILE"
  [ "$(sha256_of "$SHIP_FILE")" = "$SHIP_IF_HASH" ] || report_stop stale-ship-hash "$SHIP_FILE" 6
fi

PRIMARY_PR="$(frontmatter_field "$ENTITY" pr)"
[ -n "$PRIMARY_PR" ] || report_stop missing-pr "entity has no implementation PR"
PRIMARY_PR_NORMALIZED="$(normalize_pr "$PRIMARY_PR")" || report_stop malformed-frontmatter "entity PR is not normalized numeric identity"
PRIMARY_SLUG="$(slug_for_file "$ENTITY")"
PRIMARY_TITLE="$(frontmatter_field "$ENTITY" title)"
[ -n "$PRIMARY_TITLE" ] || report_stop malformed-frontmatter "entity has no title"
if [ -n "$MIRROR_ENTITY" ]; then
  MIRROR_SLUG="$(slug_for_file "$MIRROR_ENTITY")"
  MIRROR_TITLE="$(frontmatter_field "$MIRROR_ENTITY" title)"
  MIRROR_PR="$(frontmatter_field "$MIRROR_ENTITY" pr)"
  MIRROR_PR_NORMALIZED="$(normalize_pr "$MIRROR_PR")" || report_stop closeout-checkpoint-conflict "mirror PR is not numeric identity"
  if [ "$MIRROR_SLUG" != "$PRIMARY_SLUG" ] || [ "$MIRROR_TITLE" != "$PRIMARY_TITLE" ] || [ "$MIRROR_PR_NORMALIZED" != "$PRIMARY_PR_NORMALIZED" ]; then
    report_stop closeout-checkpoint-conflict "active and mirror entity identity differ"
  fi
fi
MATCH_COUNT=$((1 + ${#PARTICIPANTS[@]}))
if [ -z "$CLOSEOUT_OWNER" ]; then
  if [ "$MATCH_COUNT" -eq 1 ]; then CLOSEOUT_OWNER=true
  else CLOSEOUT_OWNER="$(frontmatter_field "$ENTITY" closeout_owner)"; fi
fi

OWNER_COUNT=0
[ "$CLOSEOUT_OWNER" = true ] && OWNER_COUNT=1
SEEN_PATHS="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$ENTITY")"
SEEN_SLUGS="$PRIMARY_SLUG"
for index in "${!PARTICIPANTS[@]}"; do
  participant="${PARTICIPANTS[$index]}"
  participant_hash="${PARTICIPANT_HASHES[$index]}"
  [ -f "$participant" ] || report_stop missing-entity "$participant"
  [ "$(sha256_of "$participant")" = "$participant_hash" ] || report_stop stale-entity-hash "$participant" 6
  validate_frontmatter "$participant" || report_stop malformed-frontmatter "$participant"
  participant_canonical="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$participant")"
  if printf '%s\n' "$SEEN_PATHS" | grep -Fxq "$participant_canonical"; then
    report_stop closeout-owner-not-unique "duplicate participant path"
  fi
  participant_pr="$(frontmatter_field "$participant" pr)"
  participant_pr_normalized="$(normalize_pr "$participant_pr")" || report_stop closeout-owner-not-unique "participant PR is not numeric identity"
  [ "$participant_pr_normalized" = "$PRIMARY_PR_NORMALIZED" ] || report_stop closeout-owner-not-unique "participants do not share one PR"
  participant_slug="$(slug_for_file "$participant")"
  if printf '%s\n' "$SEEN_SLUGS" | grep -Fxq "$participant_slug"; then
    report_stop closeout-owner-not-unique "duplicate participant slug"
  fi
  SEEN_PATHS="${SEEN_PATHS}
${participant_canonical}"
  SEEN_SLUGS="${SEEN_SLUGS}
${participant_slug}"
  [ "$(frontmatter_field "$participant" closeout_owner)" = true ] && OWNER_COUNT=$((OWNER_COUNT + 1))
done
[ "$OWNER_COUNT" -eq 1 ] || report_stop closeout-owner-not-unique "shared PR must declare exactly one closeout owner"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

set_frontmatter_bool() {
  local source="$1" target="$2" value="$3"
  python3 - "$source" "$target" "$value" <<'PY'
from pathlib import Path
import sys
source, target, value = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
text=source.read_text()
lines=text.splitlines(keepends=True)
fences=[i for i,line in enumerate(lines) if line.strip()=="---"]
if len(fences)<2 or fences[0]!=0: raise SystemExit("malformed-frontmatter")
start,end=fences[:2]; found=False
for i in range(start+1,end):
    if lines[i].startswith("closeout_owner:"):
        newline="\n" if lines[i].endswith("\n") else ""
        lines[i]=f"closeout_owner: {value}{newline}"; found=True; break
if not found: lines.insert(end,f"closeout_owner: {value}\n")
Path(target).write_text("".join(lines))
PY
}

set_ship_intent() {
  local source="$1" target="$2" intent="$3"
  python3 - "$source" "$target" "$intent" <<'PY'
from pathlib import Path
import sys
source,target,intent=Path(sys.argv[1]),Path(sys.argv[2]),sys.argv[3]
lines=source.read_text().splitlines(keepends=True)
try: verdict=next(i for i,line in enumerate(lines) if line.strip()=="### Verdict")
except StopIteration: raise SystemExit("missing-verdict")
end=next((i for i in range(verdict+1,len(lines)) if lines[i].startswith("#")),len(lines))
found=False
for i in range(verdict+1,end):
    if lines[i].startswith("merge_method_intent:"):
        newline="\n" if lines[i].endswith("\n") else ""
        lines[i]=f"merge_method_intent: {intent}{newline}"; found=True; break
if not found: lines.insert(verdict+1,f"merge_method_intent: {intent}\n")
Path(target).write_text("".join(lines))
PY
}

set_frontmatter_bool "$ENTITY" "$TMP_DIR/entity" "$CLOSEOUT_OWNER" || report_stop malformed-frontmatter "$ENTITY"
if [ -n "$MIRROR_ENTITY" ]; then
  set_frontmatter_bool "$MIRROR_ENTITY" "$TMP_DIR/mirror" "$CLOSEOUT_OWNER" || report_stop malformed-frontmatter "$MIRROR_ENTITY"
fi
if [ -n "$MERGE_METHOD_INTENT" ]; then
  set_ship_intent "$SHIP_FILE" "$TMP_DIR/ship" "$MERGE_METHOD_INTENT" || report_stop closeout-ship-missing "ship.md lacks ### Verdict"
fi

cmp -s "$TMP_DIR/entity" "$ENTITY" || mv "$TMP_DIR/entity" "$ENTITY"
if [ -n "$MIRROR_ENTITY" ]; then cmp -s "$TMP_DIR/mirror" "$MIRROR_ENTITY" || mv "$TMP_DIR/mirror" "$MIRROR_ENTITY"; fi
if [ -n "$MERGE_METHOD_INTENT" ]; then cmp -s "$TMP_DIR/ship" "$SHIP_FILE" || mv "$TMP_DIR/ship" "$SHIP_FILE"; fi

echo "verdict=OK"
echo "pr=$PRIMARY_PR"
echo "closeout_owner=$CLOSEOUT_OWNER"
if [ -n "$MERGE_METHOD_INTENT" ]; then echo "merge_method_intent=$MERGE_METHOD_INTENT"; else echo "merge_method_intent=absent"; fi
