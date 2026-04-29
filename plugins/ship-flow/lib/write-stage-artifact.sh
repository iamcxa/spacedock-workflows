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
#   4 same-file aliasing (--content path resolves to the writer's --stage output path)
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

USAGE="Usage: write-stage-artifact.sh --stage=<plan|design|execute|verify|review|ship> --entity=<id>-<slug> --content=<path> --workflow-dir=<dir> [--if-hash=<sha256>]"

[ -n "$STAGE" ]        || { echo "Error: --stage required. $USAGE" >&2; exit 1; }
[ -n "$ENTITY" ]       || { echo "Error: --entity required. $USAGE" >&2; exit 1; }
[ -n "$CONTENT" ]      || { echo "Error: --content required. $USAGE" >&2; exit 1; }
[ -n "$WORKFLOW_DIR" ] || { echo "Error: --workflow-dir required. $USAGE" >&2; exit 1; }

# Validate stage value
case "$STAGE" in
  plan|design|execute|verify|review|ship) ;;
  *) echo "Error: --stage must be one of: plan design execute verify review ship (got: $STAGE)" >&2; exit 1 ;;
esac

[ -f "$CONTENT" ] || { echo "Error: content file not found: $CONTENT" >&2; exit 3; }

# Resolve entity folder under workflow-dir
ENTITY_FOLDER="${WORKFLOW_DIR}/${ENTITY}"
OUT_FILE="${ENTITY_FOLDER}/${STAGE}.md"

# Same-file aliasing guard — refuse if --content resolves to the writer's
# output path. Without this, the brace-group `{ printf; cat $CONTENT; printf } > $OUT_FILE`
# becomes a self-feeding loop (truncate target → printf header → cat re-reads
# its own redirect output → unbounded growth until disk-full / OOM). Hit once on
# pitch-113.2 (1.44 GB blob). Comparison uses inode (-ef) for symlink resilience,
# with realpath fallback when -ef unavailable.
if [ -e "$OUT_FILE" ] && [ "$CONTENT" -ef "$OUT_FILE" ] 2>/dev/null; then
  echo "Error: --content path is the same file as the writer's output ($OUT_FILE). Self-feed loop refused. Pass a separate draft path." >&2
  exit 4
elif [ -e "$OUT_FILE" ]; then
  # -ef unavailable on this shell; fall back to realpath comparison
  CONTENT_RP="$(cd "$(dirname "$CONTENT")" 2>/dev/null && pwd)/$(basename "$CONTENT")"
  OUT_RP="$(cd "$(dirname "$OUT_FILE")" 2>/dev/null && pwd)/$(basename "$OUT_FILE")"
  if [ "$CONTENT_RP" = "$OUT_RP" ]; then
    echo "Error: --content path is the same file as the writer's output ($OUT_FILE). Self-feed loop refused. Pass a separate draft path." >&2
    exit 4
  fi
fi

# Optional read-first CAS: if --if-hash provided and target file exists, verify hash
if [ -n "$IF_HASH" ] && [ -f "$OUT_FILE" ]; then
  CURRENT_HASH="$(sha256_of "$OUT_FILE")"
  if [ "$CURRENT_HASH" != "$IF_HASH" ]; then
    echo "Error: CAS hash mismatch — $OUT_FILE changed since extract (expected $IF_HASH, got $CURRENT_HASH). Review: git diff $OUT_FILE" >&2
    exit 6
  fi
fi

mkdir -p "$ENTITY_FOLDER"

# Write wrapped content with section tags via temp-then-rename (atomic).
# Writing to a sibling tempfile + mv is immune to same-file aliasing AND gives
# atomic visibility (readers never see a half-written file). The cat-source and
# the redirect target are guaranteed to be distinct inodes here.
ISO_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TMP_OUT="$(mktemp "${ENTITY_FOLDER}/.${STAGE}.md.XXXXXX")"
trap 'rm -f "$TMP_OUT"' EXIT
{
  printf '<!-- section:%s-report -->\n' "$STAGE"
  cat "$CONTENT"
  printf '\n<!-- /section:%s-report -->\n' "$STAGE"
} > "$TMP_OUT"
# mktemp defaults to 0600; normalize to repo convention 0644 (umask-respecting)
chmod 0644 "$TMP_OUT"
mv "$TMP_OUT" "$OUT_FILE"
trap - EXIT

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
