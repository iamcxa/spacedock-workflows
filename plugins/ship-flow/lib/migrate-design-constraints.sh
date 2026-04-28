#!/usr/bin/env bash
# migrate-design-constraints.sh — assist migrating legacy design.md from G8 dual-write format
# to PR #44 single-source-of-truth format.
#
# Background: PR #44 G8 dedup retired '### Constraints for Plan Stage' subsection in
# Phase 8 design.md output; '### Hand-off to Plan' became single-source-of-truth.
# Existing entities written before PR #44 may have both blocks — this script flags
# and assists migration.
#
# Usage:
#   bash migrate-design-constraints.sh <design.md>
#
# Exit codes:
#   0 — already migrated (no '### Constraints for Plan Stage' subsection)
#   1 — migration needed (legacy block found; suggested action printed)
#   2 — usage error
#
# Strategy: NOT auto-rewriting. Prints the legacy block content + suggested
# integration into '### Hand-off to Plan'. Captain reviews + edits manually.
# Auto-rewrite risks losing nuance in prose-format constraints.

set -euo pipefail

DESIGN="${1:-}"
[ -z "$DESIGN" ] && { echo "ERROR: usage: $0 <design.md>" >&2; exit 2; }
[ -f "$DESIGN" ] || { echo "ERROR: file not found: $DESIGN" >&2; exit 2; }

if ! grep -qE '^### Constraints for Plan Stage' "$DESIGN"; then
  echo "OK migrate-design-constraints: $DESIGN already migrated (no legacy '### Constraints for Plan Stage' subsection)"
  exit 0
fi

echo "=== MIGRATION NEEDED: $DESIGN ===" >&2
echo "" >&2
echo "Legacy '### Constraints for Plan Stage' subsection found. PR #44 G8 dedup retired this." >&2
echo "" >&2
echo "Legacy content:" >&2
echo "---" >&2
awk '/^### Constraints for Plan Stage/,/^### |^---|^## /' "$DESIGN" \
  | sed '$d' | head -100 >&2
echo "---" >&2
echo "" >&2

if grep -qE '^### Hand-off to Plan' "$DESIGN"; then
  echo "ACTION: '### Hand-off to Plan' block ALSO present — dual-write conflict." >&2
  echo "  1. Read the legacy content above carefully." >&2
  echo "  2. Verify each item is reflected in '### Hand-off to Plan' design_constraints[]." >&2
  echo "  3. If any legacy item is missing, add it to design_constraints[] in structured format:" >&2
  echo '       - type: token-binding | layout | interaction' >&2
  echo '         assertion: <machine-checkable text>' >&2
  echo '         rationale_decision: D{N}' >&2
  echo '         source_artifact: <path>' >&2
  echo "  4. Delete the '### Constraints for Plan Stage' subsection." >&2
  echo "  5. Re-run check-invariants.sh --check no-design-constraints-dual-write to verify." >&2
else
  echo "ACTION: '### Hand-off to Plan' block MISSING — legacy-only entity." >&2
  echo "  1. Create '### Hand-off to Plan' block per ship-design/SKILL.md Phase 9 format." >&2
  echo "  2. Translate each prose constraint above into structured design_constraints[] item." >&2
  echo "  3. Delete the '### Constraints for Plan Stage' subsection." >&2
  echo "  4. Re-run check-invariants.sh --check no-design-constraints-dual-write to verify." >&2
fi

echo "" >&2
echo "Why manual: prose constraints often encode nuance (BLOCKING vs WARN, conditional rules)" >&2
echo "that auto-rewriting would silently lose. Captain edits, then validate-handoff-schema.sh" >&2
echo "+ validate-d-references.sh confirm the migration is structurally sound." >&2

exit 1
