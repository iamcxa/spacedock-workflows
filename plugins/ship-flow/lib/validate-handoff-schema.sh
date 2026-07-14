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

AFFECTS_UI_TRUE=0
if [ -f "$(dirname "$DESIGN")/index.md" ]; then
  if awk '/^---$/{fm++; next} fm==1 && /^affects_ui:[[:space:]]*true[[:space:]]*$/{found=1} fm==2{exit} END{exit !found}' "$(dirname "$DESIGN")/index.md"; then
    AFFECTS_UI_TRUE=1
  fi
fi

# Format detection: structured (YAML-ish keys at column 0/2) vs prose (markdown bullets)
# Heuristic: structured has lines like '    type: token-binding'; prose has '  1. some prose'
STRUCTURED_HINTS=$(echo "$HANDOFF" | grep -cE '^[[:space:]]+(type|assertion|rationale_decision|selector|css_property|expected_value|route|reference_artifact|capture|threshold):' || true)
PROSE_HINTS=$(echo "$HANDOFF" | grep -cE '^[[:space:]]*[0-9]+\.[[:space:]]' || true)

FAIL=0

if [ "$STRUCTURED_HINTS" -lt 2 ] && [ "$PROSE_HINTS" -gt 0 ]; then
  echo "WARN handoff-schema: prose format detected — schema validation skipped." >&2
  echo "  Migration: bash plugins/ship-flow/lib/migrate-design-constraints.sh $DESIGN" >&2
  echo "  Until migrated, structured field validation cannot run; D{N} reference check (validate-d-references.sh) still works." >&2
  exit 0
fi

# Non-UI hand-offs may intentionally carry no design DCs. Accept the compact
# C4 shape only when every declared importable collection is explicitly `[]`;
# do not infer emptiness from missing fields, null-style keys, or parse failure.
IMPORTABLE_DECL_COUNT=$(echo "$HANDOFF" | grep -cE '^[[:space:]]*(design_constraints|visible_surface_map|render_fidelity_targets|whole_page_visual_targets):' || true)
EXPLICIT_EMPTY_IMPORTABLE_COUNT=$(echo "$HANDOFF" | grep -cE '^[[:space:]]*(design_constraints|visible_surface_map|render_fidelity_targets|whole_page_visual_targets):[[:space:]]*\[[[:space:]]*\][[:space:]]*$' || true)
if [ "$AFFECTS_UI_TRUE" = "0" ] \
  && [ "$IMPORTABLE_DECL_COUNT" -gt 0 ] \
  && [ "$IMPORTABLE_DECL_COUNT" -eq "$EXPLICIT_EMPTY_IMPORTABLE_COUNT" ]; then
  echo "OK handoff-schema: explicitly empty structured design collections"
  exit 0
fi

VSM_PRESENT=0
if echo "$HANDOFF" | grep -qE '^[[:space:]]*visible_surface_map:'; then
  VSM_PRESENT=1
fi

UI_TARGET_COUNT=$(echo "$HANDOFF" | awk '
  /render_fidelity_targets:/ { in_rft=1; next }
  /whole_page_visual_targets:|storyboard_frames:|open_decisions:|artifact_paths:|^### |^---/ { in_rft=0 }
  in_rft && /^[[:space:]]*-[[:space:]]*selector:/ { n++ }
  /whole_page_visual_targets:/ { in_wp=1; next }
  /storyboard_frames:|open_decisions:|artifact_paths:|^### |^---/ { in_wp=0 }
  in_wp && /^[[:space:]]*-[[:space:]]*route:/ { n++ }
  END { print n+0 }
')

if [ "$VSM_PRESENT" = "0" ] && { [ "$AFFECTS_UI_TRUE" = "1" ] || [ "$UI_TARGET_COUNT" -gt 0 ]; }; then
  echo "FAIL handoff-schema: visible_surface_map[] required when affects_ui:true or UI render/whole-page targets are present" >&2
  FAIL=1
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

# Validate visible_surface_map[] structured fields when present. This field is
# optional for non-UI/non-design-bearing handoffs, but strict once emitted.
if echo "$HANDOFF" | grep -qE '^[[:space:]]*visible_surface_map:'; then
  if ! echo "$HANDOFF" | awk '
    function clean(value, q) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      q=sprintf("%c", 39)
      if ((substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") ||
          (substr(value, 1, 1) == q && substr(value, length(value), 1) == q)) {
        value=substr(value, 2, length(value) - 2)
      }
      return value
    }
    function set_field(key, value) {
      value=clean(value)
      if (key == "id") id=value
      else if (key == "surface_type") surface_type=value
      else if (key == "route") route=value
      else if (key == "selector_hint") selector_hint=value
      else if (key == "visible_when") visible_when=value
      else if (key == "intent_summary") intent_summary=value
      else if (key == "coverage") coverage=value
      else if (key == "mapped_by") mapped_by=value
      else if (key == "rationale_decision") rationale_decision=value
      else if (key == "na_rationale") na_rationale=value
    }
    function parse_field(line) {
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      sub(/^[[:space:]]+/, "", line)
      key=line
      sub(/:.*/, "", key)
      value=line
      sub(/^[^:]+:[[:space:]]*/, "", value)
      set_field(key, value)
    }
    function fail(msg) {
      print "FAIL handoff-schema: visible_surface_map[] " msg > "/dev/stderr"
      bad=1
    }
    function emit() {
      if (!started) return
      if (id == "") fail("item missing id")
      if (id != "" && id !~ /^[a-z0-9][a-z0-9-]*$/) fail("item " id " has invalid id; expected ^[a-z0-9][a-z0-9-]*$")
      if (surface_type !~ /^(region|control|state_indicator|semantic_badge)$/) fail("item " id " has invalid or missing surface_type")
      if (route == "") fail("item " id " missing route")
      if (selector_hint == "") fail("item " id " missing selector_hint")
      if (visible_when == "") fail("item " id " missing visible_when")
      if (intent_summary == "") fail("item " id " missing intent_summary")
      if (coverage !~ /^(mapped|explicit_na|deferred_blocker)$/) fail("item " id " has invalid or missing coverage")
      if (rationale_decision !~ /^D[0-9]+$/) fail("item " id " missing rationale_decision D{N}")
      if (coverage == "mapped" && mapped_by == "") fail("item " id " has coverage:mapped but missing mapped_by")
      if (coverage == "explicit_na" && na_rationale == "") fail("item " id " has coverage:explicit_na but missing na_rationale")
    }
    /^[[:space:]]*visible_surface_map:/ { in_vsm=1; next }
    in_vsm && /^[[:space:]]*(render_fidelity_targets:|whole_page_visual_targets:|storyboard_frames:|open_decisions:|artifact_paths:|---|### )/ { in_vsm=0 }
    in_vsm && /^[[:space:]]*-[[:space:]]*[A-Za-z_]+:/ {
      emit()
      started=1
      id=surface_type=route=selector_hint=visible_when=intent_summary=coverage=mapped_by=rationale_decision=na_rationale=""
      parse_field($0)
      next
    }
    in_vsm && started && /^[[:space:]]+[A-Za-z_]+:/ { parse_field($0) }
    END {
      emit()
      exit bad
    }
  '; then
    FAIL=1
  fi
fi

if [ "$FAIL" = "0" ]; then
  echo "OK handoff-schema: $DESIGN structured fields valid"
fi

exit $FAIL
