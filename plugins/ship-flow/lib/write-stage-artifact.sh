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
#   5 oversized content refused
#   6 hash mismatch (--if-hash CAS)
#   8 git commit failed
#   9 malformed stage wrapper refused
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

MAX_CONTENT_BYTES="${SHIP_FLOW_STAGE_ARTIFACT_MAX_BYTES:-52428800}"
case "$MAX_CONTENT_BYTES" in
  ''|*[!0-9]*)
    echo "Error: invalid max size SHIP_FLOW_STAGE_ARTIFACT_MAX_BYTES=${MAX_CONTENT_BYTES}" >&2
    exit 1
    ;;
esac
CONTENT_BYTES="$(wc -c < "$CONTENT" | tr -d '[:space:]')"
if [ "$CONTENT_BYTES" -gt "$MAX_CONTENT_BYTES" ]; then
  echo "Error: content exceeds max size (${CONTENT_BYTES} bytes > ${MAX_CONTENT_BYTES} bytes). Stage artifact write refused before touching output." >&2
  exit 5
fi

OPEN_TAG="<!-- section:${STAGE}-report -->"
CLOSE_TAG="<!-- /section:${STAGE}-report -->"
OPEN_COUNT="$(grep -Fxc -- "$OPEN_TAG" "$CONTENT" 2>/dev/null || true)"
CLOSE_COUNT="$(grep -Fxc -- "$CLOSE_TAG" "$CONTENT" 2>/dev/null || true)"
ANY_STAGE_MARKERS="$(grep -Ec '<!--[[:space:]]*/?[[:space:]]*section[[:space:]]*:[^>]*[[:space:]]*-report[[:space:]]*-->' "$CONTENT" 2>/dev/null || true)"
FIRST_LINE="$(sed -n '1p' "$CONTENT")"
LAST_NONEMPTY_LINE="$(awk 'NF { line = $0 } END { print line }' "$CONTENT")"
WRAP_MODE="wrap"

if [ "$OPEN_COUNT" -eq 0 ] && [ "$CLOSE_COUNT" -eq 0 ] && [ "$ANY_STAGE_MARKERS" -eq 0 ]; then
  WRAP_MODE="wrap"
elif [ "$OPEN_COUNT" -eq 1 ] && [ "$CLOSE_COUNT" -eq 1 ] && [ "$ANY_STAGE_MARKERS" -eq 2 ] && \
     [ "$FIRST_LINE" = "$OPEN_TAG" ] && [ "$LAST_NONEMPTY_LINE" = "$CLOSE_TAG" ]; then
  WRAP_MODE="pass-through"
else
  echo "Error: malformed stage wrapper in content for stage ${STAGE}. Expected bare content or exactly one ${OPEN_TAG} ... ${CLOSE_TAG} pair." >&2
  exit 9
fi

# Optional read-first CAS: if --if-hash provided and target file exists, verify hash
if [ -n "$IF_HASH" ] && [ -f "$OUT_FILE" ]; then
  CURRENT_HASH="$(sha256_of "$OUT_FILE")"
  if [ "$CURRENT_HASH" != "$IF_HASH" ]; then
    echo "Error: CAS hash mismatch — $OUT_FILE changed since extract (expected $IF_HASH, got $CURRENT_HASH). Review: git diff $OUT_FILE" >&2
    exit 6
  fi
fi

GIT_CONTEXT=""
if git -C "$WORKFLOW_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_CONTEXT="$WORKFLOW_DIR"
elif git rev-parse --git-dir >/dev/null 2>&1; then
  GIT_CONTEXT="$(pwd)"
fi

mkdir -p "$ENTITY_FOLDER"
OUT_FILE_ABS="$(cd "$(dirname "$OUT_FILE")" 2>/dev/null && pwd -P)/$(basename "$OUT_FILE")"

INDEX_PATCH=""
INDEX_PATCH_HAS_DIFF=0
GIT_OPERATION_CONTEXT="$GIT_CONTEXT"
OUT_FILE_GIT_PATH="$OUT_FILE_ABS"
if [ -n "$GIT_CONTEXT" ]; then
  GIT_ROOT="$(git -C "$GIT_CONTEXT" rev-parse --show-toplevel)"
  case "$OUT_FILE_ABS" in
    "$GIT_ROOT"/*)
      GIT_OPERATION_CONTEXT="$GIT_ROOT"
      OUT_FILE_GIT_PATH="${OUT_FILE_ABS#"$GIT_ROOT"/}"
      ;;
  esac
  INDEX_PATCH="$(mktemp "${ENTITY_FOLDER}/.${STAGE}.md.index.XXXXXX")"
  git -C "$GIT_OPERATION_CONTEXT" diff --cached --binary -- "$OUT_FILE_GIT_PATH" > "$INDEX_PATCH"
  if [ -s "$INDEX_PATCH" ]; then
    INDEX_PATCH_HAS_DIFF=1
  fi
fi

# Write wrapped content with section tags via temp-then-rename (atomic).
# Writing to a sibling tempfile + mv is immune to same-file aliasing AND gives
# atomic visibility (readers never see a half-written file). The cat-source and
# the redirect target are guaranteed to be distinct inodes here.
ISO_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUT_EXISTED=0
ORIGINAL_OUT=""
if [ -e "$OUT_FILE" ]; then
  OUT_EXISTED=1
  ORIGINAL_OUT="$(mktemp "${ENTITY_FOLDER}/.${STAGE}.md.original.XXXXXX")"
  cp -p "$OUT_FILE" "$ORIGINAL_OUT"
fi
TMP_OUT="$(mktemp "${ENTITY_FOLDER}/.${STAGE}.md.XXXXXX")"
cleanup_temps() {
  rm -f "$TMP_OUT"
  if [ -n "$ORIGINAL_OUT" ]; then
    rm -f "$ORIGINAL_OUT"
  fi
  if [ -n "$INDEX_PATCH" ]; then
    rm -f "$INDEX_PATCH"
  fi
}
rollback_written_artifact() {
  if [ "$OUT_EXISTED" = "1" ] && [ -n "$ORIGINAL_OUT" ] && [ -f "$ORIGINAL_OUT" ]; then
    cp -p "$ORIGINAL_OUT" "$OUT_FILE"
  else
    rm -f "$OUT_FILE"
  fi
}
restore_artifact_and_index() {
  local rc=0
  git -C "$GIT_OPERATION_CONTEXT" reset -q -- "$OUT_FILE_GIT_PATH" >/dev/null 2>&1 || rc=1
  rollback_written_artifact
  if [ "$INDEX_PATCH_HAS_DIFF" = "1" ]; then
    git -C "$GIT_OPERATION_CONTEXT" apply --cached --binary "$INDEX_PATCH" >/dev/null 2>&1 || rc=1
  fi
  return "$rc"
}
trap cleanup_temps EXIT
if [ "$WRAP_MODE" = "pass-through" ]; then
  cat "$CONTENT" > "$TMP_OUT"
else
  {
    printf '<!-- section:%s-report -->\n' "$STAGE"
    cat "$CONTENT"
    printf '\n<!-- /section:%s-report -->\n' "$STAGE"
  } > "$TMP_OUT"
fi
if [ "$OUT_EXISTED" = "1" ] && [ -n "$ORIGINAL_OUT" ] && cmp -s "$TMP_OUT" "$ORIGINAL_OUT"; then
  echo "Warning: no diff after write (idempotent - file unchanged)" >&2
  exit 0
fi
# mktemp defaults to 0600; normalize to repo convention 0644 (umask-respecting)
chmod 0644 "$TMP_OUT"
mv "$TMP_OUT" "$OUT_FILE"

# Atomic commit with explicit pathspec
if [ -z "$GIT_CONTEXT" ]; then
  echo "Warning: not a git repo, skipping commit" >&2
  exit 0
fi

COMMIT_MSG="${STAGE}(${ENTITY}): stage artifact landed (${ISO_TS})"

if ! git -C "$GIT_OPERATION_CONTEXT" add -- "$OUT_FILE_GIT_PATH"; then
  if ! restore_artifact_and_index; then
    echo "Error: git add failed; index restore failed" >&2
    exit 8
  fi
  echo "Error: git add failed" >&2
  exit 8
fi
if git -C "$GIT_OPERATION_CONTEXT" diff --cached --quiet -- "$OUT_FILE_GIT_PATH"; then
  if ! restore_artifact_and_index; then
    echo "Error: no diff after write; index restore failed" >&2
    exit 8
  fi
  echo "Warning: no diff after write (idempotent — file unchanged)" >&2
  exit 0
fi
if ! git -c user.email="${GIT_AUTHOR_EMAIL:-author@example.com}" \
          -c user.name="${GIT_AUTHOR_NAME:-Ship-flow}" \
          -C "$GIT_OPERATION_CONTEXT" commit -m "$COMMIT_MSG" -- "$OUT_FILE_GIT_PATH"; then
  if ! restore_artifact_and_index; then
    echo "Error: commit failed; index restore failed" >&2
    exit 8
  fi
  echo "Error: commit failed" >&2
  exit 8
fi

trap - EXIT
cleanup_temps

exit 0
