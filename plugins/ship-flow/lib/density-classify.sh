#!/usr/bin/env bash
# density-classify.sh — 4-signal density classifier for ship-flow entities (pitch-101)
#
# Usage:
#   bash density-classify.sh --entity=<path-to-entity-index.md>
#   bash density-classify.sh --directive=<text>
#   bash density-classify.sh --is-high --entity=<path>  # boolean exit: 0=high, 1=not-high
#   bash density-classify.sh --help
#
# Stdout (primary mode): one of: high | medium | low | vacuum
# Exit codes: 0=success, 1=not-high (--is-high mode), 2=usage/traversal error
#
# 4-signal decision tree (all signals are boolean):
#   S1: CLAUDE.md hits ≥1 in entity's workflow area
#   S2: skill preset coverage ≥1 matching plugin
#   S3: precedent count ≥2 in archive/done
#   S4: canonical doc section match (ARCHITECTURE.md or PRODUCT.md)
#
# Classification:
#   all 4 signals → high
#   3 signals     → high
#   2 signals     → medium
#   1 signal      → low
#   0 signals     → vacuum
#
# External boolean surface (Principle 4 boolean-gate):
#   --is-high: exits 0 if classification=high, exits 1 otherwise
#   The 4-tier enum is internal display only — not exposed at gate logic.
set -uo pipefail

DENSITY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=discovery-exclusions.sh
. "$DENSITY_LIB_DIR/discovery-exclusions.sh"

ENTITY=""
DIRECTIVE=""
IS_HIGH_MODE=0

usage() {
  echo "Usage: density-classify.sh --entity=<path> | --directive=<text> [--is-high]" >&2
  echo "       density-classify.sh --help" >&2
  exit 2
}

for arg in "$@"; do
  case "$arg" in
    --entity=*)    ENTITY="${arg#--entity=}" ;;
    --directive=*) DIRECTIVE="${arg#--directive=}" ;;
    --is-high)     IS_HIGH_MODE=1 ;;
    --help)
      grep '^#' "$0" | head -20 | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; usage ;;
  esac
done

# Validate: exactly one of --entity or --directive must be provided
if [ -n "$ENTITY" ] && [ -n "$DIRECTIVE" ]; then
  echo "Error: --entity and --directive are mutually exclusive" >&2
  usage
fi
if [ -z "$ENTITY" ] && [ -z "$DIRECTIVE" ]; then
  echo "Error: one of --entity or --directive is required" >&2
  usage
fi

# ── Extract context from entity or directive ───────────────────────────────────

ENTITY_DIR=""
WORKFLOW_DIR=""

if [ -n "$ENTITY" ]; then
  [ -f "$ENTITY" ] || { echo "Error: entity file not found: $ENTITY" >&2; exit 2; }
  ENTITY_DIR="$(dirname "$ENTITY")"
  # Extract workflow_dir from frontmatter (e.g., docs/ship-flow)
  WORKFLOW_DIR="$(grep -E '^workflow_dir:' "$ENTITY" 2>/dev/null | head -1 | sed 's/workflow_dir:[[:space:]]*//' | tr -d '"' || echo '')"
  # Fall back: infer from path (entity is at docs/ship-flow/<slug>/index.md)
  if [ -z "$WORKFLOW_DIR" ]; then
    # e.g., /path/to/docs/ship-flow/101-slug/index.md → docs/ship-flow
    WORKFLOW_DIR="$(echo "$ENTITY" | grep -oE 'docs/[^/]+' | head -1 || echo 'docs/ship-flow')"
  fi
else
  WORKFLOW_DIR="docs/ship-flow"
fi

# ── Find repo root (walk up from entity or cwd) ────────────────────────────────

REPO_ROOT=""
if [ -n "$ENTITY_DIR" ]; then
  CHECK_DIR="$(cd "$ENTITY_DIR" && pwd)"
  # Use git to find the repo root containing the entity (stays within the entity's git tree)
  GIT_ROOT="$(git -C "$CHECK_DIR" rev-parse --show-toplevel 2>/dev/null || echo '')"
  if [ -n "$GIT_ROOT" ]; then
    REPO_ROOT="$GIT_ROOT"
  else
    # Walk up to find CLAUDE.md within the entity's directory tree
    WALK_DIR="$CHECK_DIR"
    for _ in 1 2 3 4 5 6 7 8; do
      if [ -f "$WALK_DIR/CLAUDE.md" ]; then
        REPO_ROOT="$WALK_DIR"
        break
      fi
      WALK_DIR="$(dirname "$WALK_DIR")"
      [ "$WALK_DIR" = "/" ] && break
    done
  fi
else
  # --directive mode: use cwd's git root
  GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"
  [ -n "$GIT_ROOT" ] && REPO_ROOT="$GIT_ROOT"
fi
# Fallback: use cwd
[ -z "$REPO_ROOT" ] && REPO_ROOT="$(pwd)"

DENSITY_CAPTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ship-flow-density.XXXXXX")" || {
  echo "ERROR: density classifier could not create bounded capture directory" >&2
  exit 2
}
trap 'rm -rf "${DENSITY_CAPTURE_DIR}"' EXIT INT TERM

TRAVERSAL_STDERR="${DENSITY_CAPTURE_DIR}/traversal.stderr"

capture_traversal() {
  local label="$1"
  local requested_root="$2"
  local capture_file="$3"
  local producer_status
  shift 3

  : >"${capture_file}"
  : >"${TRAVERSAL_STDERR}"

  if ship_flow_discovery_find "${requested_root}" "$@" \
    >"${capture_file}" 2>"${TRAVERSAL_STDERR}"; then
    producer_status=0
  else
    producer_status=$?
  fi

  if [ "${producer_status}" -ne 0 ]; then
    if [ -s "${TRAVERSAL_STDERR}" ]; then
      cat "${TRAVERSAL_STDERR}" >&2
    fi
    printf 'ERROR: density traversal %s failed (rc %s): %s\n' \
      "${label}" "${producer_status}" "${requested_root}" >&2
    return 2
  fi

  return 0
}

# ── Signal evaluation ──────────────────────────────────────────────────────────

S1=0  # CLAUDE.md hits ≥1
S2=0  # skill preset coverage ≥1
S3=0  # precedent count ≥2
S4=0  # canonical doc section match

# S1: CLAUDE.md has positive workflow guidance (entry-point or pipeline section)
# Requires a meaningful positive reference, not just a mention.
# Patterns that qualify: entry-point line, "## {WF_NAME}" heading, "workflow_dir.*{WF_NAME}",
# or "Ship-Flow Pipeline" style section headers (case-insensitive).
WF_NAME="$(basename "$WORKFLOW_DIR")"  # e.g., "ship-flow"
CLAUDE_HITS=0
check_claude_positive() {
  local f="$1"
  [ -f "$f" ] || return 0
  # Positive patterns: heading, entry-point, or workflow_dir reference
  if grep -qiE "(^##.*$WF_NAME|entry-point:.*$WF_NAME|workflow_dir:.*$WF_NAME|commissioned-by:|Ship-Flow Pipeline)" "$f" 2>/dev/null; then
    echo 1
  else
    echo 0
  fi
}
HIT1="$(check_claude_positive "$REPO_ROOT/CLAUDE.md")"
CLAUDE_HITS=$((CLAUDE_HITS + HIT1))
if [ -d "$REPO_ROOT/$WORKFLOW_DIR" ]; then
  S1_CAPTURE="${DENSITY_CAPTURE_DIR}/s1-claude-files"
  capture_traversal \
    "S1 workflow CLAUDE.md" \
    "$REPO_ROOT/$WORKFLOW_DIR" \
    "$S1_CAPTURE" \
    -name "CLAUDE.md" -print0
  CAPTURE_STATUS=$?
  [ "$CAPTURE_STATUS" -eq 0 ] || exit "$CAPTURE_STATUS"

  while IFS= read -r -d '' claude_file; do
    H="$(check_claude_positive "$claude_file")"
    CLAUDE_HITS=$((CLAUDE_HITS + H))
  done <"$S1_CAPTURE"
fi
[ "$CLAUDE_HITS" -ge 1 ] && S1=1

# S2: skill preset coverage ≥1 matching plugin for workflow
# Only check the REPO_ROOT local plugins (not $HOME/.claude/plugins — that's system-wide
# and does not indicate this specific repo has the workflow skill installed).
PLUGIN_HITS=0
if [ -d "$REPO_ROOT/plugins" ]; then
  S2_CAPTURE="${DENSITY_CAPTURE_DIR}/s2-plugin-skills"
  capture_traversal \
    "S2 plugin skills" \
    "$REPO_ROOT/plugins" \
    "$S2_CAPTURE" \
    -name "SKILL.md" -exec sh -c '
      pattern=$1
      shift
      grep -l "$pattern" "$@"
      grep_status=$?
      case "$grep_status" in
        0|1) exit 0 ;;
        *) exit "$grep_status" ;;
      esac
    ' sh "$WF_NAME" {} +
  CAPTURE_STATUS=$?
  [ "$CAPTURE_STATUS" -eq 0 ] || exit "$CAPTURE_STATUS"

  while IFS= read -r _; do
    PLUGIN_HITS=$((PLUGIN_HITS + 1))
  done <"$S2_CAPTURE"
fi
[ "$PLUGIN_HITS" -ge 1 ] && S2=1

# S3: precedent count ≥2 in archive/done
ARCHIVE_HITS=0
ARCHIVE_DIR="$REPO_ROOT/$WORKFLOW_DIR/_archive"
DONE_DIR="$REPO_ROOT/$WORKFLOW_DIR/done"
if [ -d "$ARCHIVE_DIR" ]; then
  ARCHIVE_CAPTURE="${DENSITY_CAPTURE_DIR}/s3-archive-precedents"
  capture_traversal \
    "S3 archive precedents" \
    "$ARCHIVE_DIR" \
    "$ARCHIVE_CAPTURE" \
    -name "*.md" -print
  CAPTURE_STATUS=$?
  [ "$CAPTURE_STATUS" -eq 0 ] || exit "$CAPTURE_STATUS"

  while IFS= read -r _; do
    ARCHIVE_HITS=$((ARCHIVE_HITS + 1))
  done <"$ARCHIVE_CAPTURE"
fi
if [ -d "$DONE_DIR" ]; then
  DONE_CAPTURE="${DENSITY_CAPTURE_DIR}/s3-done-precedents"
  capture_traversal \
    "S3 done precedents" \
    "$DONE_DIR" \
    "$DONE_CAPTURE" \
    -name "*.md" -print
  CAPTURE_STATUS=$?
  [ "$CAPTURE_STATUS" -eq 0 ] || exit "$CAPTURE_STATUS"

  while IFS= read -r _; do
    ARCHIVE_HITS=$((ARCHIVE_HITS + 1))
  done <"$DONE_CAPTURE"
fi
[ "$ARCHIVE_HITS" -ge 2 ] && S3=1

# S4: canonical doc section match
# Check if ARCHITECTURE.md or PRODUCT.md has a section matching the workflow area
S4_FOUND=0
for canon_file in "$REPO_ROOT/ARCHITECTURE.md" "$REPO_ROOT/PRODUCT.md"; do
  if [ -f "$canon_file" ]; then
    # Check for section tags referencing the workflow
    if grep -qE "section:.*$WF_NAME|## .*$WF_NAME|$WF_NAME" "$canon_file" 2>/dev/null; then
      S4_FOUND=1
      break
    fi
  fi
done
# Also accept: extract-map.sh can resolve a section for the workflow
if [ "$S4_FOUND" = "0" ] && [ -f "$REPO_ROOT/plugins/ship-flow/lib/extract-map.sh" ]; then
  if bash "$REPO_ROOT/plugins/ship-flow/lib/extract-map.sh" "$REPO_ROOT/ARCHITECTURE.md" constraints 2>/dev/null | grep -q .; then
    # Canonical doc has at least the constraints section populated
    S4_FOUND=1
  fi
fi
[ "$S4_FOUND" = "1" ] && S4=1

# ── Classification ─────────────────────────────────────────────────────────────

SIGNAL_COUNT=$((S1 + S2 + S3 + S4))

if [ "$SIGNAL_COUNT" -ge 3 ]; then
  CLASSIFICATION="high"
elif [ "$SIGNAL_COUNT" -eq 2 ]; then
  CLASSIFICATION="medium"
elif [ "$SIGNAL_COUNT" -eq 1 ]; then
  CLASSIFICATION="low"
else
  CLASSIFICATION="vacuum"
fi

# ── Output ─────────────────────────────────────────────────────────────────────

if [ "$IS_HIGH_MODE" = "1" ]; then
  # Boolean external surface (Principle 4): single boolean, no enum exposed
  [ "$CLASSIFICATION" = "high" ] && exit 0 || exit 1
fi

# Primary stdout: enum value (single line, deterministic)
echo "$CLASSIFICATION"
