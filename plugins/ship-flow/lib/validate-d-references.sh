#!/usr/bin/env bash
# validate-d-references.sh — validate D{N} cross-references across design/plan/verify artifacts.
#
# Background: PR #44 introduced rationale_decision: D{N} backref in design hand-off
# fields. plan Step 1.6 imports them with backref. Without this validator, design can
# emit constraints citing D{N} that has no matching `**D{N}|Captain decision**` marker
# in Phase 8 — silent broken-reference shipping.
#
# Usage:
#   bash validate-d-references.sh <entity-folder>
#   bash validate-d-references.sh <design.md>  (single-file mode)
#
# Exit codes:
#   0 — all D{N} references resolve to a Captain Decision marker
#   1 — at least one dangling reference (printed to stderr)
#   2 — usage error
#
# What's checked:
#   1. Collect all `**D{N}|Captain decision**` markers in design.md (defining set)
#   2. Collect all `D{N}` references in design.md hand-off + plan.md ## Plan Imported Design DCs + verify.md
#   3. Every reference must be in the defining set; warn on unreferenced markers (dead decisions)
#
# Scope: works on both structured (PR #44 schema) and prose (legacy bullet) hand-off formats —
# uses regex on D{N} pattern, format-agnostic.

set -euo pipefail

TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "ERROR: usage: $0 <entity-folder|design.md>" >&2; exit 2; }

# Locate design.md
if [ -d "$TARGET" ]; then
  DESIGN="${TARGET%/}/design.md"
  PLAN="${TARGET%/}/plan.md"
  VERIFY="${TARGET%/}/verify.md"
elif [ -f "$TARGET" ]; then
  DESIGN="$TARGET"
  PLAN=""
  VERIFY=""
else
  echo "ERROR: target not found: $TARGET" >&2; exit 2
fi

[ -f "$DESIGN" ] || { echo "ERROR: design.md not found: $DESIGN" >&2; exit 2; }

# 1. Collect markers — '**D1|Captain decision**', '**D2|Captain decision**', ...
MARKERS=$(grep -oE '\*\*D[0-9]+\|Captain decision\*\*' "$DESIGN" 2>/dev/null \
  | grep -oE 'D[0-9]+' | sort -u || true)

if [ -z "$MARKERS" ]; then
  echo "WARN: no '**D{N}|Captain decision**' markers found in $DESIGN — design may be incomplete" >&2
fi

# 2. Collect references from design.md (hand-off block), plan.md (imported DCs section), verify.md
collect_refs() {
  local file="$1" section_pattern="$2"
  [ -f "$file" ] || return 0
  awk -v pat="$section_pattern" '$0 ~ pat { in_section=1 } in_section { print } /^---$|^## / && !($0 ~ pat) && in_section { in_section=0 }' "$file" \
    | grep -oE 'D[0-9]+' | sort -u || true
}

REFS_DESIGN=$(grep -oE 'rationale_decision:\s*D[0-9]+|\bD[0-9]+\b' "$DESIGN" 2>/dev/null \
  | grep -oE 'D[0-9]+' | sort -u || true)

REFS_PLAN=""
[ -n "$PLAN" ] && [ -f "$PLAN" ] && REFS_PLAN=$(collect_refs "$PLAN" '## Plan Imported Design DCs')

REFS_VERIFY=""
[ -n "$VERIFY" ] && [ -f "$VERIFY" ] && REFS_VERIFY=$(grep -oE 'rationale_decision:\s*D[0-9]+|\bD[0-9]+\b' "$VERIFY" 2>/dev/null \
  | grep -oE 'D[0-9]+' | sort -u || true)

ALL_REFS=$(printf '%s\n%s\n%s\n' "$REFS_DESIGN" "$REFS_PLAN" "$REFS_VERIFY" | sort -u | grep -v '^$' || true)

# 3. Validate every reference has a matching marker
FAIL=0
DANGLING=""
for ref in $ALL_REFS; do
  if ! echo "$MARKERS" | grep -qx "$ref"; then
    DANGLING="${DANGLING}${ref} "
    FAIL=1
  fi
done

# 4. Find unreferenced markers (warn, not fail)
UNUSED=""
for marker in $MARKERS; do
  if ! echo "$ALL_REFS" | grep -qx "$marker"; then
    UNUSED="${UNUSED}${marker} "
  fi
done

# Output
if [ "$FAIL" = "1" ]; then
  echo "FAIL D-reference validation: dangling references not in design Captain Decisions:" >&2
  echo "  Dangling: $DANGLING" >&2
  echo "  Markers found in $DESIGN: ${MARKERS:-(none)}" >&2
  echo "  Fix: ensure each rationale_decision: D{N} backref has a matching '**D{N}|Captain decision**' in design.md Phase 8 Captain Decisions." >&2
fi

if [ -n "$UNUSED" ]; then
  echo "WARN: design Captain Decisions exist but are unreferenced (dead decisions): $UNUSED" >&2
  echo "  These decisions are documented but no constraint/target/DC cites them — possibly redundant or missing import." >&2
fi

if [ "$FAIL" = "0" ]; then
  marker_count=$(echo "$MARKERS" | wc -w | tr -d ' ')
  ref_count=$(echo "$ALL_REFS" | wc -w | tr -d ' ')
  echo "OK D-reference validation: $marker_count markers, $ref_count references, all resolved"
fi

exit $FAIL
