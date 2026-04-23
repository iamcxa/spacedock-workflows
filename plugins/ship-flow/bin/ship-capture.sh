#!/usr/bin/env bash
# ship-capture.sh — zero-friction ship-flow entity creation
# Usage: ship-capture.sh "Title text" ["source context"]
set -euo pipefail

TITLE="${1:?Usage: ship-capture.sh \"Title\" [\"source\"]}"
SOURCE="${2:-captain capture session $(date +%Y-%m-%d)}"

# Detect workflow dir
WORKFLOW_DIR=$(grep -rl "^commissioned-by:" "$(git rev-parse --show-toplevel 2>/dev/null || echo .)/docs"/*/README.md 2>/dev/null | head -1 | xargs -I{} dirname {} 2>/dev/null || true)
[ -z "$WORKFLOW_DIR" ] && WORKFLOW_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo .)/docs/ship-flow"

# Generate slug
STOP_WORDS="a an the of for to in on at with this that is are be into from and or but"
slug=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]')
for w in $STOP_WORDS; do slug=$(echo "$slug" | sed -E "s/\\b${w}\\b//g"); done
slug=$(echo "$slug" | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
slug=$(echo "$slug" | tr '-' '\n' | grep -v '^$' | head -6 | tr '\n' '-' | sed 's/-$//')

# Collision check
TARGET="$WORKFLOW_DIR/${slug}.md"
if [ -f "$TARGET" ]; then
  for i in 2 3 4 5; do
    candidate="$WORKFLOW_DIR/${slug}-${i}.md"
    if [ ! -f "$candidate" ]; then TARGET="$candidate"; slug="${slug}-${i}"; break; fi
    [ "$i" -eq 5 ] && { echo "Error: slug collision after 5 attempts. Rename manually."; exit 1; }
  done
fi

# Sentence-case title (capitalize first letter only)
TITLE_CASED="$(echo "${TITLE:0:1}" | tr '[:lower:]' '[:upper:]')${TITLE:1}"
# Truncate to 80 chars
[ ${#TITLE_CASED} -gt 80 ] && TITLE_CASED="${TITLE_CASED:0:79}…"

# Write entity file
cat > "$TARGET" <<EOF
---
id:
title: ${TITLE_CASED}
status: draft
source: "${SOURCE}"
started:
completed:
verdict:
priority: P3
score:
worktree:
pr:
token_budget:
token_actual:
---

${TITLE_CASED}

> Next: when ready to define problem framing + done criteria, run \`/ship-flow:ship-shape ${slug}\`. Captain gates the sharp stage; agents handle plan/execute/verify/ship autonomously after.
EOF

echo "Captured: ${slug}"
echo "Path:     ${TARGET}"
echo "Title:    ${TITLE_CASED}"
echo "Run:      git add ${TARGET}"
