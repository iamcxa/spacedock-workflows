#!/usr/bin/env bash
# patch-map.sh <map-file> <section-tag> [--if-hash=<sha>] [--commit-as=<msg>] [--no-commit]
# Replaces content between <!-- section:TAG --> markers. Content from stdin.
#
# Exit codes:
#   0 success
#   1 usage/args error
#   2 tag not in flow-map-schema
#   3 map file missing
#   4 tag schema-valid but not present in file
#   5 bad-TAG format
#   6 sha256 mismatch (file changed after --if-hash)
#   7 --if-hash required but missing (read-first enforcement)
#   8 git commit failed (hook blocked, not a repo, etc.)
#   9 mermaid diagram missing for requires_diagram: true section
#  10 markers missing or unbalanced
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="${SCRIPT_DIR}/../references/flow-map-schema.yaml"
# shellcheck source=./map-helpers.sh
source "${SCRIPT_DIR}/map-helpers.sh"

IF_HASH=""
COMMIT_MSG=""
NO_COMMIT=0
POS=()
for arg in "$@"; do
  case "$arg" in
    --if-hash=*) IF_HASH="${arg#--if-hash=}" ;;
    --commit-as=*) COMMIT_MSG="${arg#--commit-as=}" ;;
    --no-commit) NO_COMMIT=1 ;;
    --*) echo "Unknown option: $arg" >&2; exit 1 ;;
    *) POS+=("$arg") ;;
  esac
done

MAP_FILE="${POS[0]:-}"
TAG="${POS[1]:-}"
{ [ -n "$MAP_FILE" ] && [ -n "$TAG" ]; } || {
  echo "Usage: patch-map.sh <map-file> <section-tag> [--if-hash=<sha>] [--commit-as=<msg>] [--no-commit]" >&2
  exit 1
}
[ -f "$MAP_FILE" ] || { echo "Error: file not found: $MAP_FILE" >&2; exit 3; }

validate_kebab_tag "$TAG" || exit 5
validate_schema_tag "$TAG" "$SCHEMA_FILE" || exit 2

# Read-first enforcement (exit 7 if --if-hash missing)
if [ -z "$IF_HASH" ]; then
  echo "Error: patch requires --if-hash=<sha256>. Run: extract-map.sh $MAP_FILE $TAG --emit-hash-only" >&2
  exit 7
fi
CURRENT_HASH="$(sha256_of "$MAP_FILE")"
if [ "$CURRENT_HASH" != "$IF_HASH" ]; then
  echo "Error: patch failed — $MAP_FILE changed after your extract (expected sha256=$IF_HASH, got $CURRENT_HASH). Review: git diff $MAP_FILE" >&2
  exit 6
fi

# Tag must exist in file body (not just schema — exit 4)
if ! grep -q "<!-- section:${TAG} -->" "$MAP_FILE"; then
  echo "Error: section '${TAG}' schema-valid but missing in ${MAP_FILE} (run backfill first)" >&2
  exit 4
fi

# Read new content from stdin → temp file
BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT INT TERM
cat > "$BODY_FILE"

# Diagram validation — only if schema declares requires_diagram: true for this section
REQ="$(awk -v tag="$TAG" '
  /^[[:space:]]+- section_tag: / && $3 == tag { found=1; next }
  found && /^[[:space:]]+requires_diagram: / { print $2; exit }
  found && /^[[:space:]]+- section_tag/ { exit }
' "$SCHEMA_FILE")"
KIND="$(awk -v tag="$TAG" '
  /^[[:space:]]+- section_tag: / && $3 == tag { found=1; next }
  found && /^[[:space:]]+diagram_kind: / { sub(/^[^"]*"/, ""); sub(/".*/, ""); print; exit }
  found && /^[[:space:]]+- section_tag/ { exit }
' "$SCHEMA_FILE")"
if [ "$REQ" = "true" ]; then
  validate_mermaid "$BODY_FILE" "${KIND:-unknown}" || exit 9
fi

# Atomic section replace (exit 10 on marker mismatch)
if ! atomic_replace "$MAP_FILE" "$TAG" "$BODY_FILE"; then
  echo "Error: markers missing or unbalanced for '${TAG}' in ${MAP_FILE}" >&2
  exit 10
fi
rm -f "$BODY_FILE"
trap - EXIT INT TERM

# Atomic commit (only if --commit-as given AND not --no-commit)
if [ "$NO_COMMIT" = "0" ] && [ -n "$COMMIT_MSG" ]; then
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Warning: not a git repo; skipping commit" >&2
    exit 0
  fi
  # Explicit-path staging (internalizes 5069b8ba incident lesson — never -a/-A)
  git add -- "$MAP_FILE"
  if git diff --cached --quiet -- "$MAP_FILE"; then
    # No-op patch (content already matched) — idempotent
    exit 0
  fi
  if ! git commit -m "$COMMIT_MSG" -- "$MAP_FILE"; then
    echo "Error: file patched OK but commit blocked by pre-commit hook or similar. File state saved. Resolve or retry with --no-commit." >&2
    exit 8
  fi
fi

exit 0
