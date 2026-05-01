#!/usr/bin/env bash
# validate-handoff-schema.sh — structural validation of `### Hand-off to Plan` block.
#
# Background: PR #44 G9/G12 introduced structured fields (design_constraints[],
# render_fidelity_targets[]) replacing prose bullets. Without machine validation,
# captain can emit hand-off with missing required fields and downstream stages
# (plan Step 1.6, verify Step 3.6) silently degrade.
#
# Usage:
#   bash validate-handoff-schema.sh <entity-folder>
#   bash validate-handoff-schema.sh <design.md>  (single-file mode)
#
# Exit codes:
#   0 — schema valid (structured) OR design-skipped:true OR prose-format with migration hint (warn only)
#   1 — schema invalid (missing required field; structured but malformed)
#   2 — usage error
#
# What's validated (when not design-skipped):
#   - design_constraints[] non-empty, each item has type + assertion + rationale_decision
#   - render_fidelity_targets[] non-empty when affects_ui=true and design has visual artifacts,
#     each item has selector + css_property + expected_value + rationale_decision
#
# Scope: detects structured-vs-prose format. Prose format → WARN with migration hint
# (lib/migrate-design-constraints.sh). Structured format → strict field validation.

set -euo pipefail

TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "ERROR: usage: $0 <entity-folder|design.md>" >&2; exit 2; }

if [ -d "$TARGET" ]; then
  DESIGN="${TARGET%/}/design.md"
elif [ -f "$TARGET" ]; then
  DESIGN="$TARGET"
else
  echo "ERROR: target not found: $TARGET" >&2; exit 2
fi

[ -f "$DESIGN" ] || { echo "ERROR: design.md not found: $DESIGN" >&2; exit 2; }

# Extract Hand-off to Plan block
HANDOFF=$(awk '/^### Hand-off to Plan/{flag=1} /^<!-- \/section:hand-off-to-plan -->/{flag=0} flag' "$DESIGN")

if [ -z "$HANDOFF" ]; then
  echo "FAIL handoff-schema: '### Hand-off to Plan' block not found in $DESIGN" >&2
  exit 1
fi

# Design-skipped short-circuit
if echo "$HANDOFF" | grep -qE '^[[:space:]]*-?[[:space:]]*design-skipped:[[:space:]]*true'; then
  echo "OK handoff-schema: design-skipped:true (validation skipped)"
  exit 0
fi

# Format detection: structured (YAML-ish keys at column 0/2) vs prose (markdown bullets)
# Heuristic: structured has lines like '    type: token-binding'; prose has '  1. some prose'
STRUCTURED_HINTS=$(echo "$HANDOFF" | grep -cE '^[[:space:]]+(type|assertion|rationale_decision|selector|css_property|expected_value|route|reference_artifact|capture|threshold):' || true)
PROSE_HINTS=$(echo "$HANDOFF" | grep -cE '^[[:space:]]*[0-9]+\.[[:space:]]' || true)

FAIL=0

if [ "$STRUCTURED_HINTS" -lt 2 ] && [ "$PROSE_HINTS" -gt 2 ]; then
  echo "WARN handoff-schema: prose format detected — schema validation skipped." >&2
  echo "  Migration: bash plugins/ship-flow/lib/migrate-design-constraints.sh $DESIGN" >&2
  echo "  Until migrated, structured field validation cannot run; D{N} reference check (validate-d-references.sh) still works." >&2
  exit 0
fi

# Validate design_constraints[] structured fields
DC_BLOCK=$(echo "$HANDOFF" | awk '/design_constraints:/,/render_fidelity_targets:|artifact_paths:|open_decisions:|^### |^---/' | head -80)
if [ -n "$DC_BLOCK" ]; then
  # Each item should have type + assertion + rationale_decision
  ITEM_COUNT=$(echo "$DC_BLOCK" | grep -cE '^[[:space:]]*-[[:space:]]*(type|assertion):' || true)
  TYPE_COUNT=$(echo "$DC_BLOCK" | grep -cE '^[[:space:]]*-?[[:space:]]*type:[[:space:]]*(token-binding|layout|interaction|contract|schema-contract|filter-contract|api-contract|data-contract|domain-contract)' || true)
  ASSERTION_COUNT=$(echo "$DC_BLOCK" | grep -cE '^[[:space:]]*-?[[:space:]]*assertion:' || true)
  RATIONALE_COUNT=$(echo "$DC_BLOCK" | grep -cE '^[[:space:]]+rationale_decision:[[:space:]]*D[0-9]+' || true)

  if [ "$TYPE_COUNT" = "0" ] && [ "$ASSERTION_COUNT" = "0" ]; then
    echo "FAIL handoff-schema: design_constraints[] structured fields missing — expected 'type:', 'assertion:', 'rationale_decision: D{N}' per item" >&2
    FAIL=1
  fi
  if [ "$ITEM_COUNT" -gt 0 ] && [ "$TYPE_COUNT" -lt "$ITEM_COUNT" ]; then
    echo "FAIL handoff-schema: design_constraints[] $ITEM_COUNT items but only $TYPE_COUNT valid type fields" >&2
    FAIL=1
  fi
  if [ "$ITEM_COUNT" -gt 0 ] && [ "$ASSERTION_COUNT" -lt "$ITEM_COUNT" ]; then
    echo "FAIL handoff-schema: design_constraints[] $ITEM_COUNT items but only $ASSERTION_COUNT assertion fields" >&2
    FAIL=1
  fi
  if [ "$ITEM_COUNT" -gt 0 ] && [ "$RATIONALE_COUNT" -lt "$ITEM_COUNT" ]; then
    echo "FAIL handoff-schema: design_constraints[] $ITEM_COUNT items but only $RATIONALE_COUNT rationale_decision backrefs (G12 violation)" >&2
    FAIL=1
  fi
fi

# Validate render_fidelity_targets[] structured fields
RFT_BLOCK=$(echo "$HANDOFF" | awk '/render_fidelity_targets:/,/whole_page_visual_targets:|storyboard_frames:|^### |^---/' | head -80)
if [ -n "$RFT_BLOCK" ]; then
  SELECTOR_COUNT=$(echo "$RFT_BLOCK" | grep -cE '^[[:space:]]*-?[[:space:]]*selector:' || true)
  PROPERTY_COUNT=$(echo "$RFT_BLOCK" | grep -cE '^[[:space:]]+css_property:' || true)
  EXPECTED_COUNT=$(echo "$RFT_BLOCK" | grep -cE '^[[:space:]]+expected_value:' || true)
  RFT_RATIONALE_COUNT=$(echo "$RFT_BLOCK" | grep -cE '^[[:space:]]+rationale_decision:[[:space:]]*D[0-9]+' || true)

  if [ "$SELECTOR_COUNT" -gt 0 ]; then
    if [ "$PROPERTY_COUNT" -lt "$SELECTOR_COUNT" ] || [ "$EXPECTED_COUNT" -lt "$SELECTOR_COUNT" ]; then
      echo "FAIL handoff-schema: render_fidelity_targets[] missing required field per item — selectors=$SELECTOR_COUNT, css_property=$PROPERTY_COUNT, expected_value=$EXPECTED_COUNT" >&2
      FAIL=1
    fi
    if [ "$RFT_RATIONALE_COUNT" -lt "$SELECTOR_COUNT" ]; then
      echo "FAIL handoff-schema: render_fidelity_targets[] $SELECTOR_COUNT items but only $RFT_RATIONALE_COUNT rationale_decision backrefs (G12 violation)" >&2
      FAIL=1
    fi
  fi
fi

# Validate whole_page_visual_targets[] structured fields when present.
WP_BLOCK=$(echo "$HANDOFF" | awk '/whole_page_visual_targets:/,/storyboard_frames:|^### |^---/' | head -80)
if [ -n "$WP_BLOCK" ]; then
  ROUTE_COUNT=$(echo "$WP_BLOCK" | grep -cE '^[[:space:]]*-?[[:space:]]*route:' || true)
  REF_COUNT=$(echo "$WP_BLOCK" | grep -cE '^[[:space:]]+reference_artifact:' || true)
  CAPTURE_COUNT=$(echo "$WP_BLOCK" | grep -cE '^[[:space:]]+capture:[[:space:]]*(full-page screenshot|viewport screenshot)' || true)
  WP_RATIONALE_COUNT=$(echo "$WP_BLOCK" | grep -cE '^[[:space:]]+rationale_decision:[[:space:]]*D[0-9]+' || true)

  if [ "$ROUTE_COUNT" -gt 0 ]; then
    if [ "$REF_COUNT" -lt "$ROUTE_COUNT" ] || [ "$CAPTURE_COUNT" -lt "$ROUTE_COUNT" ]; then
      echo "FAIL handoff-schema: whole_page_visual_targets[] missing required field per item — routes=$ROUTE_COUNT, reference_artifact=$REF_COUNT, capture=$CAPTURE_COUNT" >&2
      FAIL=1
    fi
    if [ "$WP_RATIONALE_COUNT" -lt "$ROUTE_COUNT" ]; then
      echo "FAIL handoff-schema: whole_page_visual_targets[] $ROUTE_COUNT items but only $WP_RATIONALE_COUNT rationale_decision backrefs (G12 violation)" >&2
      FAIL=1
    fi
  fi
fi

if [ "$FAIL" = "0" ]; then
  echo "OK handoff-schema: $DESIGN structured fields valid"
fi

exit $FAIL
