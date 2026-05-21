#!/usr/bin/env bash
# check-visible-surface-coverage.sh — compare live visible surfaces to design intent.
#
# Usage:
#   bash check-visible-surface-coverage.sh \
#     --design <design.md> \
#     --live-surfaces <surfaces.tsv> \
#     --render-report <report.md>
#
# live-surfaces TSV columns:
#   id route surface_type selector_hint visible_when evidence_class

set -euo pipefail

DESIGN=""
LIVE_SURFACES=""
RENDER_REPORT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --design)
      DESIGN="${2:-}"; shift 2 ;;
    --live-surfaces)
      LIVE_SURFACES="${2:-}"; shift 2 ;;
    --render-report)
      RENDER_REPORT="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '1,18p' "$0"; exit 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$DESIGN" ] || { echo "ERROR: --design required" >&2; exit 2; }
[ -n "$LIVE_SURFACES" ] || { echo "ERROR: --live-surfaces required" >&2; exit 2; }
[ -n "$RENDER_REPORT" ] || { echo "ERROR: --render-report required" >&2; exit 2; }
[ -f "$DESIGN" ] || { echo "ERROR: design file not found: $DESIGN" >&2; exit 2; }
[ -f "$LIVE_SURFACES" ] || { echo "ERROR: live surfaces TSV not found: $LIVE_SURFACES" >&2; exit 2; }
[ -f "$RENDER_REPORT" ] || { echo "ERROR: render report not found: $RENDER_REPORT" >&2; exit 2; }

TMP_MAP="$(mktemp)"
TMP_LIVE_IDS="$(mktemp)"
cleanup() {
  rm -f "$TMP_MAP" "$TMP_LIVE_IDS"
}
trap cleanup EXIT
trap 'cleanup; exit 130' HUP INT TERM

awk '
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
    else if (key == "coverage") coverage=value
    else if (key == "route") route=value
    else if (key == "surface_type") surface_type=value
    else if (key == "selector_hint") selector_hint=value
    else if (key == "visible_when") visible_when=value
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
  function emit() {
    if (!started) return
    if (id != "") print id "\t" coverage "\t" route "\t" surface_type "\t" selector_hint "\t" visible_when
  }
  /^[[:space:]]*visible_surface_map:/ { in_vsm=1; next }
  in_vsm && /^[[:space:]]*(render_fidelity_targets:|whole_page_visual_targets:|storyboard_frames:|open_decisions:|artifact_paths:|---|### )/ { in_vsm=0 }
  in_vsm && /^[[:space:]]*-[[:space:]]*[A-Za-z_]+:/ {
    emit()
    started=1
    id=coverage=route=surface_type=selector_hint=visible_when=""
    parse_field($0)
    next
  }
  in_vsm && started && /^[[:space:]]+[A-Za-z_]+:/ {
    parse_field($0)
  }
  END {
    emit()
  }
' "$DESIGN" > "$TMP_MAP"

render_passed=false
if grep -qE '^[[:space:]]*render_fidelity_targets_passed=true[[:space:]]*$' "$RENDER_REPORT" || awk '
  /^#### Mechanical UI Parity/ { in_mechanical=1; next }
  /^#### / && in_mechanical { in_mechanical=0 }
  in_mechanical {
    line=$0
    sub(/^[[:space:]]+/, "", line)
    sub(/[[:space:]]+$/, "", line)
    if (line ~ /^[0-9]+\/[0-9]+[[:space:]]+PASS$/) {
      split(line, parts, /[\/ \t]+/)
      if (parts[1] + 0 > 0 && parts[1] + 0 == parts[2] + 0) found=1
    }
  }
  END { exit !found }
' "$RENDER_REPORT"; then
  render_passed=true
fi

echo "#### Visible Surface Coverage"
echo
echo "render_fidelity_targets_passed=${render_passed}"
echo
echo "| Severity | Finding | Evidence | route_to | route_reason |"
echo "|---|---|---|---|---|"

missing_count=0

while IFS=$'\t' read -r id route surface_type selector_hint visible_when evidence_class; do
  [ -n "${id:-}" ] || continue
  printf '%s\n' "$id" >> "$TMP_LIVE_IDS"
  if awk -F '\t' -v id="$id" '$1 == id && ($2 == "mapped" || $2 == "explicit_na") { found=1 } END { exit !found }' "$TMP_MAP"; then
    continue
  fi

  case "$evidence_class" in
    design-intent)
      route_to="design"
      reason="unmapped design intent; design handoff is incomplete"
      ;;
    implementation-extra)
      route_to="execute"
      reason="implementation-only extra UI is not authorized by design intent"
      ;;
    ambiguous)
      route_to="design"
      reason="ambiguous ownership; route to design first before judging execute"
      ;;
    *)
      route_to="design"
      reason="unknown evidence_class; route to design first"
      ;;
  esac

  echo "| BLOCKING | unmapped visible surface \`${id}\` | route=${route}; selector=${selector_hint}; type=${surface_type}; visible_when=${visible_when}; evidence_class=${evidence_class} | route_to: ${route_to} | ${reason} |"
  missing_count=$((missing_count + 1))
done < <(tail -n +2 "$LIVE_SURFACES")

while IFS=$'\t' read -r id coverage route surface_type selector_hint visible_when; do
  [ -n "${id:-}" ] || continue
  [ "$coverage" = "mapped" ] || continue
  if grep -Fxq "$id" "$TMP_LIVE_IDS"; then
    continue
  fi
  echo "| BLOCKING | mapped design surface absent from live inventory \`${id}\` | route=${route}; selector=${selector_hint}; type=${surface_type}; visible_when=${visible_when}; coverage=${coverage} | route_to: execute | implementation is missing a surface mapped by design intent |"
  missing_count=$((missing_count + 1))
done < "$TMP_MAP"

echo
if [ "$missing_count" -gt 0 ]; then
  echo "status=blocked missing_visible_surfaces=${missing_count}"
  exit 1
fi

echo "status=pass missing_visible_surfaces=0"
exit 0
