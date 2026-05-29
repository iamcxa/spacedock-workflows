#!/usr/bin/env bash
# check-harvest-exempt.sh — ship-review harvest gate exemption check (Step 8).
#
# Usage:
#   bash check-harvest-exempt.sh <path-to-entity-index.md>
#
# Exit codes:
#   0  — entity is EXEMPT (gate skips BLOCKER); prints "exempt"
#   1  — entity is NOT exempt (gate applies BLOCKER); prints "not-exempt"
#
# Semantics:
#   - Missing file / unreadable  → "not-exempt" + exit 1  (fail-safe)
#   - Frontmatter LACKS harvest_required: true → "exempt" + exit 0
#     (forward-only: old entities predate the flag)
#   - Frontmatter HAS  harvest_required: true → "not-exempt" + exit 1
#
# Only the YAML frontmatter block (between first and second "---" delimiters)
# is inspected. Occurrences of harvest_required in the document body are
# intentionally ignored.

set -euo pipefail

ENTITY_PATH="${1:-}"

# --- fail-safe: missing argument or unreadable file ---
if [ -z "$ENTITY_PATH" ] || [ ! -r "$ENTITY_PATH" ]; then
  echo "not-exempt"
  exit 1
fi

# --- extract frontmatter block (first --- to second ---) ---
# We read line by line, capturing only the lines between the two delimiters.
# This avoids pipelines that differ between bash 3.2 (macOS) and newer versions.
in_frontmatter=0
frontmatter_done=0
found_harvest_required_true=0

while IFS= read -r line; do
  if [ "$frontmatter_done" -eq 1 ]; then
    break
  fi

  if [ "$in_frontmatter" -eq 0 ]; then
    # Expect the very first line to be the opening "---"
    if [ "$line" = "---" ]; then
      in_frontmatter=1
    else
      # No frontmatter block — treat as exempt (old entity without frontmatter)
      break
    fi
  else
    # Inside the frontmatter block
    if [ "$line" = "---" ]; then
      # Closing delimiter — stop scanning
      frontmatter_done=1
    else
      # Check for harvest_required: true (allow optional trailing spaces)
      if printf '%s' "$line" | grep -qE '^harvest_required:[[:space:]]*true[[:space:]]*$'; then
        found_harvest_required_true=1
      fi
    fi
  fi
done < "$ENTITY_PATH"

if [ "$found_harvest_required_true" -eq 1 ]; then
  echo "not-exempt"
  exit 1
fi

echo "exempt"
exit 0
