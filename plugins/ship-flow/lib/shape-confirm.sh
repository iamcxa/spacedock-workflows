#!/usr/bin/env bash
# shape-confirm.sh — atomic write orchestrator for confirmed pitch proposal
#
# Reads a JSON proposal, writes: pitch entity + children + rabbit-hole todos
# + ROADMAP updates (next/later/not-doing sections) in ONE atomic commit.
#
# Usage: bash shape-confirm.sh --proposal=<json-file> [--dry-run] [--layout=folder|flat]
#
# --layout=folder  writes docs/<wf>/<id>-<slug>/index.md + shape.md (folder layout)
#                  Note: index.md (not README.md) per spacedock status --next-id
#                  discovery convention; see pitch 089.
# --layout=flat    writes docs/<wf>/<id>-<slug>.md (default, backward compat)
#
# Exit codes: 0 success, 1 usage/malformed JSON, 3 missing file,
#             6 hash mismatch during patch, 7 required helpers missing,
#             8 commit failed, 10 invalid proposal content or repo-state refusal
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./map-helpers.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/map-helpers.sh"

PROPOSAL=""
DRY_RUN=0
LAYOUT="flat"

for arg in "$@"; do
  case "$arg" in
    --proposal=*)    PROPOSAL="${arg#--proposal=}" ;;
    --dry-run)       DRY_RUN=1 ;;
    --layout=folder) LAYOUT="folder" ;;
    --layout=flat)   LAYOUT="flat" ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

[ -n "$PROPOSAL" ] || { echo "Usage: shape-confirm.sh --proposal=<json> [--dry-run]" >&2; exit 1; }
[ -f "$PROPOSAL" ] || { echo "Error: proposal file not found: $PROPOSAL" >&2; exit 3; }

# Validate required helpers
PATCH_MAP="${SCRIPT_DIR}/patch-map.sh"
[ -x "$PATCH_MAP" ] || { echo "Error: patch-map.sh not found/executable" >&2; exit 7; }

# Validate yq for JSON parsing
command -v yq >/dev/null 2>&1 || { echo "Error: yq required for JSON parse" >&2; exit 1; }

# Validate JSON parses
if ! yq --input-format=json '.' "$PROPOSAL" >/dev/null 2>&1; then
  echo "Error: malformed JSON in $PROPOSAL" >&2
  exit 1
fi

# Extract top-level fields
PITCH_ID=$(yq --input-format=json '.pitch.id' "$PROPOSAL" | tr -d '"')
PITCH_SLUG=$(yq --input-format=json '.pitch.slug' "$PROPOSAL" | tr -d '"')
PITCH_TITLE=$(yq --input-format=json '.pitch.title' "$PROPOSAL" | tr -d '"')
PITCH_APPETITE=$(yq --input-format=json '.pitch.appetite' "$PROPOSAL" | tr -d '"')
PITCH_PROBLEM=$(yq --input-format=json '.pitch.problem' "$PROPOSAL" | tr -d '"')
PITCH_ACCEPTANCE_OUTCOME=$(yq --input-format=json '.pitch.acceptance_outcome' "$PROPOSAL" | tr -d '"')
PITCH_ANSWERS_DENSITY=$(yq --input-format=json '.pitch.answers_density // ""' "$PROPOSAL" | tr -d '"')

[ -n "$PITCH_ID" ] && [ -n "$PITCH_SLUG" ] && [ -n "$PITCH_TITLE" ] || {
  echo "Error: proposal missing pitch.id / pitch.slug / pitch.title" >&2
  exit 10
}

# Acceptance Outcome required for pitches (Phase 100)
if [ -z "$PITCH_ACCEPTANCE_OUTCOME" ] || [ "$PITCH_ACCEPTANCE_OUTCOME" = "null" ]; then
  echo "Error: pitch.acceptance_outcome is required (user-observable answer to 'what does captain GET?'). See docs/ship-flow/100-shape-acceptance-outcome-gate/shape.md" >&2
  exit 10
fi
if [ "${#PITCH_ACCEPTANCE_OUTCOME}" -lt 50 ]; then
  echo "Error: pitch.acceptance_outcome too short (${#PITCH_ACCEPTANCE_OUTCOME} chars, min 50). Describe an observable outcome, not an artifact list." >&2
  exit 10
fi

ENTITY_DIR="docs/ship-flow"
TODO_DIR="${ENTITY_DIR}/todos"

# Layout-aware path computation
if [ "$LAYOUT" = "folder" ]; then
  PITCH_FOLDER="${ENTITY_DIR}/${PITCH_ID}-${PITCH_SLUG}"
  # index.md (not README.md) — spacedock status --next-id discovery convention
  PITCH_INDEX="${PITCH_FOLDER}/index.md"
  PITCH_SHAPE="${PITCH_FOLDER}/shape.md"
  PITCH_PATH="$PITCH_INDEX"
else
  PITCH_PATH="${ENTITY_DIR}/${PITCH_ID}-${PITCH_SLUG}.md"
fi

CHILD_COUNT=$(yq --input-format=json '.children | length' "$PROPOSAL")
CHILDREN_PATHS=()
for i in $(seq 0 $((CHILD_COUNT - 1))); do
  c_id=$(yq --input-format=json ".children[$i].id" "$PROPOSAL" | tr -d '"')
  c_slug=$(yq --input-format=json ".children[$i].slug" "$PROPOSAL" | tr -d '"')
  if [ "$LAYOUT" = "folder" ]; then
    CHILDREN_PATHS+=("${ENTITY_DIR}/${c_id}-${c_slug}/index.md")
  else
    CHILDREN_PATHS+=("${ENTITY_DIR}/${c_id}-${c_slug}.md")
  fi
done

RH_COUNT=$(yq --input-format=json '.rabbit_holes | length' "$PROPOSAL")
RH_PATHS=()
for i in $(seq 0 $((RH_COUNT - 1))); do
  rh_slug=$(yq --input-format=json ".rabbit_holes[$i].slug" "$PROPOSAL" | tr -d '"')
  RH_PATHS+=("${TODO_DIR}/${rh_slug}.md")
done

DEL_COUNT=$(yq --input-format=json '.deleted_from_shape | length' "$PROPOSAL")

if [ "$DRY_RUN" = "1" ]; then
  echo "# shape-confirm --dry-run (layout=$LAYOUT)"
  echo "Would write:"
  if [ "$LAYOUT" = "folder" ]; then
    echo "  pitch index:  ${PITCH_INDEX}"
    echo "  pitch shape:  ${PITCH_SHAPE}"
  else
    echo "  pitch: $PITCH_PATH"
  fi
  for c in "${CHILDREN_PATHS[@]}"; do echo "  child: $c"; done
  for r in "${RH_PATHS[@]}"; do echo "  rabbit: $r"; done
  echo "Would patch: ROADMAP.md sections next, later, not-doing"
  exit 0
fi

# Duplicate todo refusal shares exit 10 with proposal validation failures: both
# reject unsafe write input before the write phase mutates directories or files.
for rh_path in "${RH_PATHS[@]}"; do
  if [ -e "$rh_path" ]; then
    echo "Error: rabbit-hole todo already exists, refusing to overwrite: $rh_path" >&2
    exit 10
  fi
done

# === Real write phase ===
mkdir -p "$ENTITY_DIR" "$TODO_DIR"

# 1. Write pitch entity (layout-aware)
if [ "$LAYOUT" = "folder" ]; then
  mkdir -p "$PITCH_FOLDER"
  # index.md — frontmatter + stage-artifact-links section
  cat > "$PITCH_INDEX" <<EOF
---
id: "${PITCH_ID}"
title: "${PITCH_TITLE}"
status: sharp
pattern: pitch
appetite: "${PITCH_APPETITE}"
layout: folder
$([ -n "${PITCH_ANSWERS_DENSITY}" ] && [ "${PITCH_ANSWERS_DENSITY}" != "null" ] && echo "answers_density: \"${PITCH_ANSWERS_DENSITY}\"" || true)
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
  # shape.md — problem / appetite / children / assumptions / rabbit-holes
  cat > "$PITCH_SHAPE" <<EOF
# ${PITCH_TITLE} — Shape

## Problem

${PITCH_PROBLEM}

## Acceptance Outcome

${PITCH_ACCEPTANCE_OUTCOME}

## Appetite

${PITCH_APPETITE}

## Children

$(for i in $(seq 0 $((CHILD_COUNT - 1))); do
  c_id=$(yq --input-format=json ".children[$i].id" "$PROPOSAL" | tr -d '"')
  c_slug=$(yq --input-format=json ".children[$i].slug" "$PROPOSAL" | tr -d '"')
  echo "- ${c_id}-${c_slug}"
done)

## Assumptions

(fill in at shape stage)

## Rabbit Holes

$(for i in $(seq 0 $((RH_COUNT - 1))); do
  rh_slug=$(yq --input-format=json ".rabbit_holes[$i].slug" "$PROPOSAL" | tr -d '"')
  echo "- ${rh_slug}"
done)

## Deletes

(fill in from deleted_from_shape)
EOF
  WRITTEN_FILES=("$PITCH_INDEX" "$PITCH_SHAPE")
else
  cat > "$PITCH_PATH" <<EOF
---
id: "${PITCH_ID}"
title: "${PITCH_TITLE}"
status: sharp
pattern: pitch
appetite: "${PITCH_APPETITE}"
$([ -n "${PITCH_ANSWERS_DENSITY}" ] && [ "${PITCH_ANSWERS_DENSITY}" != "null" ] && echo "answers_density: \"${PITCH_ANSWERS_DENSITY}\"" || true)
---

### Problem

${PITCH_PROBLEM}

### Acceptance Outcome

${PITCH_ACCEPTANCE_OUTCOME}
EOF
  WRITTEN_FILES=("$PITCH_PATH")
fi

# 2. Write children entity files
for i in $(seq 0 $((CHILD_COUNT - 1))); do
  c_id=$(yq --input-format=json ".children[$i].id" "$PROPOSAL" | tr -d '"')
  c_slug=$(yq --input-format=json ".children[$i].slug" "$PROPOSAL" | tr -d '"')
  c_title=$(yq --input-format=json ".children[$i].title" "$PROPOSAL" | tr -d '"')
  if [ "$LAYOUT" = "folder" ]; then
    c_folder="${ENTITY_DIR}/${c_id}-${c_slug}"
    mkdir -p "$c_folder"
    c_path="${c_folder}/index.md"
  else
    c_path="${ENTITY_DIR}/${c_id}-${c_slug}.md"
  fi
  cat > "$c_path" <<EOF
---
id: "${c_id}"
title: "${c_title}"
status: sharp
pattern: shaped-child
parent_pitch: "${PITCH_ID}"
$([ "$LAYOUT" = "folder" ] && echo "layout: folder" || true)
---

### Problem

(child scope of pitch ${PITCH_ID})
EOF
  WRITTEN_FILES+=("$c_path")
done

# 3. Write rabbit-hole todos
for i in $(seq 0 $((RH_COUNT - 1))); do
  rh_slug=$(yq --input-format=json ".rabbit_holes[$i].slug" "$PROPOSAL" | tr -d '"')
  rh_claim=$(yq --input-format=json ".rabbit_holes[$i].claim" "$PROPOSAL" | tr -d '"')
  rh_path="${TODO_DIR}/${rh_slug}.md"
  cat > "$rh_path" <<EOF
---
tid: ${rh_slug}
captured_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
status: pending
source_pitch: "${PITCH_ID}"
---

${rh_claim}
EOF
  WRITTEN_FILES+=("$rh_path")
done

# 4. Patch ROADMAP.md sections
ROW_NEXT="| ${PITCH_ID}-${PITCH_SLUG} | ${PITCH_TITLE} | (pitch) | ${PITCH_APPETITE} |"

# Patch 'next' section
HASH=$(sha256_of ROADMAP.md)
echo "$ROW_NEXT" | bash "$PATCH_MAP" \
  --if-hash="$HASH" --mode=append --section=next --no-commit ROADMAP.md || exit 6

# Patch 'later' section (each rabbit hole)
for i in $(seq 0 $((RH_COUNT - 1))); do
  rh_slug=$(yq --input-format=json ".rabbit_holes[$i].slug" "$PROPOSAL" | tr -d '"')
  rh_claim=$(yq --input-format=json ".rabbit_holes[$i].claim" "$PROPOSAL" | tr -d '"')
  row="| ${rh_slug} | S | ${rh_claim} | pitch ${PITCH_ID} |"
  HASH=$(sha256_of ROADMAP.md)
  echo "$row" | bash "$PATCH_MAP" \
    --if-hash="$HASH" --mode=append --section=later --no-commit ROADMAP.md || exit 6
done

# Patch 'not-doing' section
for i in $(seq 0 $((DEL_COUNT - 1))); do
  d_claim=$(yq --input-format=json ".deleted_from_shape[$i].claim" "$PROPOSAL" | tr -d '"')
  d_reason=$(yq --input-format=json ".deleted_from_shape[$i].reason" "$PROPOSAL" | tr -d '"')
  row="| ${d_claim} | ${d_reason} |"
  HASH=$(sha256_of ROADMAP.md)
  echo "$row" | bash "$PATCH_MAP" \
    --if-hash="$HASH" --mode=append --section=not-doing --no-commit ROADMAP.md || exit 6
done

WRITTEN_FILES+=("ROADMAP.md")

# 5. Single atomic commit with explicit pathspec
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Warning: not a git repo, skipping commit" >&2
  exit 0
fi

git add -- "${WRITTEN_FILES[@]}"
git -c user.email=shape@confirm -c user.name=shape-confirm \
  commit -m "shape: ${PITCH_ID} ${PITCH_SLUG} — ${CHILD_COUNT} children + ${RH_COUNT} rabbit holes + ${DEL_COUNT} deletes" \
  -- "${WRITTEN_FILES[@]}" || exit 8

exit 0
