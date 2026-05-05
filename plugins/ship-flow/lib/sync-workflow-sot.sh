#!/usr/bin/env bash
# sync-workflow-sot.sh — keep ship-flow derived docs in sync with dogfood SOT.
#
# The dogfood workflow README is the source of truth. This helper updates the
# shipped adopter template and plugin README managed summary from that SOT.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: sync-workflow-sot.sh --check|--write [--sot PATH] [--template PATH] [--plugin-readme PATH]

Defaults:
  --sot            docs/ship-flow/README.md
  --template       plugins/ship-flow/workflow-template.yaml
  --plugin-readme  plugins/ship-flow/README.md
USAGE
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." &> /dev/null && pwd)"

MODE=""
SOT="${REPO_ROOT}/docs/ship-flow/README.md"
TEMPLATE="${REPO_ROOT}/plugins/ship-flow/workflow-template.yaml"
PLUGIN_README="${REPO_ROOT}/plugins/ship-flow/README.md"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check|--write)
      MODE="${1#--}"
      shift
      ;;
    --sot)
      SOT="$2"
      shift 2
      ;;
    --template)
      TEMPLATE="$2"
      shift 2
      ;;
    --plugin-readme)
      PLUGIN_README="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [ -z "$MODE" ]; then
  usage
  exit 2
fi

for file in "$SOT" "$TEMPLATE" "$PLUGIN_README"; do
  if [ ! -f "$file" ]; then
    echo "ERROR missing file: ${file}" >&2
    exit 2
  fi
done

read_stage_property() {
  local file="$1"
  local stage="$2"
  local property="$3"
  awk -v stage="$stage" -v property="$property" '
    /^---[[:space:]]*$/ {
      fence++
      if (fence == 2) exit
      next
    }
    fence != 1 { next }
    $0 ~ "^[[:space:]]*-[[:space:]]*name:[[:space:]]*" stage "[[:space:]]*$" {
      in_stage = 1
      next
    }
    in_stage && /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ { exit }
    in_stage && $0 ~ "^[[:space:]]*" property ":[[:space:]]*" {
      value = $0
      sub("^[[:space:]]*" property ":[[:space:]]*", "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "$file"
}

read_template_stage_property() {
  local file="$1"
  local stage="$2"
  local property="$3"
  awk -v stage="$stage" -v property="$property" '
    $0 ~ "^[[:space:]]*-[[:space:]]*name:[[:space:]]*" stage "[[:space:]]*$" {
      in_stage = 1
      next
    }
    in_stage && /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ { exit }
    in_stage && $0 ~ "^[[:space:]]*" property ":[[:space:]]*" {
      value = $0
      sub("^[[:space:]]*" property ":[[:space:]]*", "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "$file"
}

# DESIGN_SKIP_WHEN no longer derived — pitch 116 W3 removed skip-when entirely (INVARIANTS Principle 11 "Design Stage Required")
VERIFY_FEEDBACK_TO="$(read_stage_property "$SOT" verify feedback-to)"
SHAPE_PARALLELISM="$(read_stage_property "$SOT" shape parallelism)"
DESIGN_PARALLELISM="$(read_stage_property "$SOT" design parallelism)"
PLAN_PARALLELISM="$(read_stage_property "$SOT" plan parallelism)"
EXECUTE_PARALLELISM="$(read_stage_property "$SOT" execute parallelism)"
VERIFY_PARALLELISM="$(read_stage_property "$SOT" verify parallelism)"

if [ -z "$VERIFY_FEEDBACK_TO" ] ||
  [ -z "$SHAPE_PARALLELISM" ] || [ -z "$DESIGN_PARALLELISM" ] ||
  [ -z "$PLAN_PARALLELISM" ] || [ -z "$EXECUTE_PARALLELISM" ] ||
  [ -z "$VERIFY_PARALLELISM" ]; then
  echo "ERROR SOT missing required derived fields: verify.feedback-to, and shape/design/plan/execute/verify.parallelism are required" >&2
  exit 2
fi

EXPECTED_TEMPLATE_DESCRIPTION="Design always runs (W3 — pitch 116). UI work, matched-domain work, schema/API/domain/architecture contract impact, and unresolved contract/interface decision work all dispatch designer. Pure mechanical work walks Phase 0 trivial-pass fast-path emitting minimal design.md + verdict PROCEED."
EXPECTED_VERIFY_DESCRIPTION="Agent gate. FO dispatches review agents, integrates findings, runs quality gate + UAT. Stage feedback returns to execute; any multi-destination routing by finding class is handled inside verify.md via route_to:. FO does not inline-fix BLOCKING/WARNING findings."
EXPECTED_PLUGIN_DESIGN_LINE="- New stage \`design\` inserted between \`shape\` and \`plan\`. Always runs (no \`skip-when:\` clause); trivial-pass fast-path in Phase 0 short-circuits pure mechanical work (no \`affects_ui\`, no matched domain, no \`design_required\`, no \`contract_decision_required\`, no \`open_contract_decisions\`). Dispatched by \`/ship\` to \`designer\` teammate (opus). Output: \`design.md\` + narrow artifact bundle required by the selected \`design-dispatch-manifest\`. Per pitch 116 W3 (design always runs); INVARIANTS Principle 11 \"Design Stage Required\"."

DRIFT=0

record_drift() {
  echo "DRIFT $1 expected=\"$2\" actual=\"$3\""
  DRIFT=$((DRIFT + 1))
}

check_state() {
  local template_verify_feedback
  local template_design_description
  local template_verify_description
  local template_shape_parallelism
  local template_design_parallelism
  local template_plan_parallelism
  local template_execute_parallelism
  local template_verify_parallelism

  template_verify_feedback="$(read_template_stage_property "$TEMPLATE" verify feedback-to)"
  template_design_description="$(read_template_stage_property "$TEMPLATE" design description)"
  template_verify_description="$(read_template_stage_property "$TEMPLATE" verify description)"
  template_shape_parallelism="$(read_template_stage_property "$TEMPLATE" shape parallelism)"
  template_design_parallelism="$(read_template_stage_property "$TEMPLATE" design parallelism)"
  template_plan_parallelism="$(read_template_stage_property "$TEMPLATE" plan parallelism)"
  template_execute_parallelism="$(read_template_stage_property "$TEMPLATE" execute parallelism)"
  template_verify_parallelism="$(read_template_stage_property "$TEMPLATE" verify parallelism)"

  # template.design.skip-when drift check removed (pitch 116 W3 — no skip-when in template)
  [ "$template_verify_feedback" = "$VERIFY_FEEDBACK_TO" ] || record_drift "template.verify.feedback-to" "$VERIFY_FEEDBACK_TO" "$template_verify_feedback"
  [ "$template_design_description" = "$EXPECTED_TEMPLATE_DESCRIPTION" ] || record_drift "template.design.description" "$EXPECTED_TEMPLATE_DESCRIPTION" "$template_design_description"
  [ "$template_verify_description" = "$EXPECTED_VERIFY_DESCRIPTION" ] || record_drift "template.verify.description" "$EXPECTED_VERIFY_DESCRIPTION" "$template_verify_description"
  [ "$template_shape_parallelism" = "$SHAPE_PARALLELISM" ] || record_drift "template.shape.parallelism" "$SHAPE_PARALLELISM" "$template_shape_parallelism"
  [ "$template_design_parallelism" = "$DESIGN_PARALLELISM" ] || record_drift "template.design.parallelism" "$DESIGN_PARALLELISM" "$template_design_parallelism"
  [ "$template_plan_parallelism" = "$PLAN_PARALLELISM" ] || record_drift "template.plan.parallelism" "$PLAN_PARALLELISM" "$template_plan_parallelism"
  [ "$template_execute_parallelism" = "$EXECUTE_PARALLELISM" ] || record_drift "template.execute.parallelism" "$EXECUTE_PARALLELISM" "$template_execute_parallelism"
  [ "$template_verify_parallelism" = "$VERIFY_PARALLELISM" ] || record_drift "template.verify.parallelism" "$VERIFY_PARALLELISM" "$template_verify_parallelism"

  if ! grep -Fqx -- "$EXPECTED_PLUGIN_DESIGN_LINE" "$PLUGIN_README"; then
    record_drift "plugin-readme.design-stage-summary" "$EXPECTED_PLUGIN_DESIGN_LINE" "missing-or-stale"
  fi
}

write_template() {
  local tmp
  local tmp_inserted
  tmp="$(mktemp)"
  tmp_inserted="$(mktemp)"
  awk \
    -v verify_feedback="$VERIFY_FEEDBACK_TO" \
    -v shape_parallelism="$SHAPE_PARALLELISM" \
    -v design_parallelism="$DESIGN_PARALLELISM" \
    -v plan_parallelism="$PLAN_PARALLELISM" \
    -v execute_parallelism="$EXECUTE_PARALLELISM" \
    -v verify_parallelism="$VERIFY_PARALLELISM" \
    -v design_description="$EXPECTED_TEMPLATE_DESCRIPTION" \
    -v verify_description="$EXPECTED_VERIFY_DESCRIPTION" '
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*shape[[:space:]]*$/ {
      stage = "shape"
      print
      next
    }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*design[[:space:]]*$/ {
      stage = "design"
      print
      next
    }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*plan[[:space:]]*$/ {
      stage = "plan"
      print
      next
    }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*execute[[:space:]]*$/ {
      stage = "execute"
      print
      next
    }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*verify[[:space:]]*$/ {
      stage = "verify"
      print
      next
    }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
      stage = ""
      print
      next
    }
    stage == "design" && /^[[:space:]]*skip-when:[[:space:]]*/ {
      # skip-when removed (pitch 116 W3); silently drop any stale skip-when line
      next
    }
    stage == "shape" && /^[[:space:]]*parallelism:[[:space:]]*/ {
      print "    parallelism: " shape_parallelism
      next
    }
    stage == "design" && /^[[:space:]]*parallelism:[[:space:]]*/ {
      print "    parallelism: " design_parallelism
      next
    }
    stage == "plan" && /^[[:space:]]*parallelism:[[:space:]]*/ {
      print "    parallelism: " plan_parallelism
      next
    }
    stage == "execute" && /^[[:space:]]*parallelism:[[:space:]]*/ {
      print "    parallelism: " execute_parallelism
      next
    }
    stage == "verify" && /^[[:space:]]*parallelism:[[:space:]]*/ {
      print "    parallelism: " verify_parallelism
      next
    }
    stage == "design" && /^[[:space:]]*description:[[:space:]]*/ {
      print "    description: \"" design_description "\""
      next
    }
    stage == "verify" && /^[[:space:]]*feedback-to:[[:space:]]*/ {
      print "    feedback-to: \"" verify_feedback "\""
      next
    }
    stage == "verify" && /^[[:space:]]*description:[[:space:]]*/ {
      print "    description: \"" verify_description "\""
      next
    }
    { print }
  ' "$TEMPLATE" > "$tmp"
  awk \
    -v shape_parallelism="$SHAPE_PARALLELISM" \
    -v design_parallelism="$DESIGN_PARALLELISM" \
    -v plan_parallelism="$PLAN_PARALLELISM" \
    -v execute_parallelism="$EXECUTE_PARALLELISM" \
    -v verify_parallelism="$VERIFY_PARALLELISM" '
    function expected_for(stage_name) {
      if (stage_name == "shape") return shape_parallelism
      if (stage_name == "design") return design_parallelism
      if (stage_name == "plan") return plan_parallelism
      if (stage_name == "execute") return execute_parallelism
      if (stage_name == "verify") return verify_parallelism
      return ""
    }
    function flush_stage() {
      if (stage == "") return
      print stage_header
      if (!saw_parallelism) print "    parallelism: " expected_for(stage)
      for (i = 1; i <= block_count; i++) print block[i]
      stage = ""
      block_count = 0
      delete block
      saw_parallelism = 0
    }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*(shape|design|plan|execute|verify)[[:space:]]*$/ {
      flush_stage()
      stage_header = $0
      stage = $0
      sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", stage)
      sub(/[[:space:]]*$/, "", stage)
      next
    }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
      flush_stage()
      print
      next
    }
    stage != "" {
      if ($0 ~ /^[[:space:]]*parallelism:[[:space:]]*/) saw_parallelism = 1
      block[++block_count] = $0
      next
    }
    { print }
    END { flush_stage() }
  ' "$tmp" > "$tmp_inserted"
  mv "$tmp_inserted" "$TEMPLATE"
  rm -f "$tmp"
}

write_plugin_readme() {
  local tmp
  tmp="$(mktemp)"
  awk -v expected="$EXPECTED_PLUGIN_DESIGN_LINE" '
    /^- New stage `design` inserted between `shape` and `plan`\./ {
      print expected
      next
    }
    { print }
  ' "$PLUGIN_README" > "$tmp"
  mv "$tmp" "$PLUGIN_README"
}

case "$MODE" in
  check)
    check_state
    if [ "$DRIFT" -gt 0 ]; then
      exit 1
    fi
    echo "OK workflow SOT derived files are in sync"
    ;;
  write)
    write_template
    write_plugin_readme
    check_state
    if [ "$DRIFT" -gt 0 ]; then
      exit 1
    fi
    echo "UPDATED workflow SOT derived files are in sync"
    ;;
esac
