#!/usr/bin/env bash
# write-stage-artifact.sh — unified per-stage .md writer (Layer C primitive)
# Analogous to shape-confirm.sh (entity creation) + patch-map.sh (flow-map writes).
#
# Usage:
#   bash write-stage-artifact.sh \
#     --stage=<plan|execute|verify|review|ship> \
#     --entity=<id>-<slug> \
#     --content=<path-to-draft-md> \
#     --workflow-dir=<dir> \
#     [--if-hash=<sha256>]
#
# Exit codes:
#   0 success
#   1 usage / invalid args
#   3 content file not found
#   6 hash mismatch (--if-hash CAS)
#   8 git commit failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./map-helpers.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/map-helpers.sh"

STAGE=""
ENTITY=""
CONTENT=""
WORKFLOW_DIR=""
IF_HASH=""

for arg in "$@"; do
  case "$arg" in
    --stage=*)        STAGE="${arg#--stage=}" ;;
    --entity=*)       ENTITY="${arg#--entity=}" ;;
    --content=*)      CONTENT="${arg#--content=}" ;;
    --workflow-dir=*) WORKFLOW_DIR="${arg#--workflow-dir=}" ;;
    --if-hash=*)      IF_HASH="${arg#--if-hash=}" ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

USAGE="Usage: write-stage-artifact.sh --stage=<plan|execute|verify|review|ship> --entity=<id>-<slug> --content=<path> --workflow-dir=<dir> [--if-hash=<sha256>]"

[ -n "$STAGE" ]        || { echo "Error: --stage required. $USAGE" >&2; exit 1; }
[ -n "$ENTITY" ]       || { echo "Error: --entity required. $USAGE" >&2; exit 1; }
[ -n "$CONTENT" ]      || { echo "Error: --content required. $USAGE" >&2; exit 1; }
[ -n "$WORKFLOW_DIR" ] || { echo "Error: --workflow-dir required. $USAGE" >&2; exit 1; }

# Validate stage value
case "$STAGE" in
  plan|execute|verify|review|ship) ;;
  *) echo "Error: --stage must be one of: plan execute verify review ship (got: $STAGE)" >&2; exit 1 ;;
esac

[ -f "$CONTENT" ] || { echo "Error: content file not found: $CONTENT" >&2; exit 3; }

# Resolve entity folder under workflow-dir
ENTITY_FOLDER="${WORKFLOW_DIR}/${ENTITY}"
OUT_FILE="${ENTITY_FOLDER}/${STAGE}.md"

# Optional read-first CAS: if --if-hash provided and target file exists, verify hash
if [ -n "$IF_HASH" ] && [ -f "$OUT_FILE" ]; then
  CURRENT_HASH="$(sha256_of "$OUT_FILE")"
  if [ "$CURRENT_HASH" != "$IF_HASH" ]; then
    echo "Error: CAS hash mismatch — $OUT_FILE changed since extract (expected $IF_HASH, got $CURRENT_HASH). Review: git diff $OUT_FILE" >&2
    exit 6
  fi
fi

mkdir -p "$ENTITY_FOLDER"

# Write wrapped content with section tags
ISO_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  printf '<!-- section:%s-report -->\n' "$STAGE"
  cat "$CONTENT"
  printf '\n<!-- /section:%s-report -->\n' "$STAGE"
} > "$OUT_FILE"

# Atomic commit with explicit pathspec
if ! git -C "$WORKFLOW_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  # Not inside a git repo: try from pwd
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Warning: not a git repo, skipping commit" >&2
    exit 0
  fi
fi

COMMIT_MSG="${STAGE}(${ENTITY}): stage artifact landed (${ISO_TS})"

git add -- "$OUT_FILE"
if git diff --cached --quiet -- "$OUT_FILE"; then
  echo "Warning: no diff after write (idempotent — file unchanged)" >&2
  exit 0
fi
if ! git commit -m "$COMMIT_MSG" -- "$OUT_FILE"; then
  echo "Error: file written but commit failed. Resolve or commit manually." >&2
  exit 8
fi

exit 0
