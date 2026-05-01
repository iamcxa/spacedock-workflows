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

DESIGN_SKIP_WHEN="$(read_stage_property "$SOT" design skip-when)"
VERIFY_FEEDBACK_TO="$(read_stage_property "$SOT" verify feedback-to)"

if [ -z "$DESIGN_SKIP_WHEN" ] || [ -z "$VERIFY_FEEDBACK_TO" ]; then
  echo "ERROR SOT missing design.skip-when or verify.feedback-to" >&2
  exit 2
fi

EXPECTED_TEMPLATE_DESCRIPTION="Design is mandatory for UI, matched-domain, or contract-bearing work. Skips only for trivial mechanical work with no affects_ui, no matched domain, and no design_required signal."
EXPECTED_VERIFY_DESCRIPTION="Agent gate. FO dispatches review agents, integrates findings, runs quality gate + UAT. Verify-stage captain UAT feedback routes to execute/design/plan/follow-up by finding class; FO does not inline-fix BLOCKING/WARNING findings."
EXPECTED_PLUGIN_DESIGN_LINE="- New stage \`design\` inserted between \`shape\` and \`plan\`. Conditional but mandatory for design-bearing work (\`manual: conditional\`, \`skip-when: ${DESIGN_SKIP_WHEN}\`). It runs for UI work, matched-domain work, and schema/API/domain/architecture contract impact; it skips only for trivial mechanical work with no design-bearing decision. Dispatched by \`/ship\` to \`designer\` teammate (opus). Output: \`design.md\` + narrow artifact bundle required by the selected \`design-dispatch-manifest\`."

DRIFT=0

record_drift() {
  echo "DRIFT $1 expected=\"$2\" actual=\"$3\""
  DRIFT=$((DRIFT + 1))
}

check_state() {
  local template_design_skip
  local template_verify_feedback
  local template_design_description
  local template_verify_description

  template_design_skip="$(read_template_stage_property "$TEMPLATE" design skip-when)"
  template_verify_feedback="$(read_template_stage_property "$TEMPLATE" verify feedback-to)"
  template_design_description="$(read_template_stage_property "$TEMPLATE" design description)"
  template_verify_description="$(read_template_stage_property "$TEMPLATE" verify description)"

  [ "$template_design_skip" = "$DESIGN_SKIP_WHEN" ] || record_drift "template.design.skip-when" "$DESIGN_SKIP_WHEN" "$template_design_skip"
  [ "$template_verify_feedback" = "$VERIFY_FEEDBACK_TO" ] || record_drift "template.verify.feedback-to" "$VERIFY_FEEDBACK_TO" "$template_verify_feedback"
  [ "$template_design_description" = "$EXPECTED_TEMPLATE_DESCRIPTION" ] || record_drift "template.design.description" "$EXPECTED_TEMPLATE_DESCRIPTION" "$template_design_description"
  [ "$template_verify_description" = "$EXPECTED_VERIFY_DESCRIPTION" ] || record_drift "template.verify.description" "$EXPECTED_VERIFY_DESCRIPTION" "$template_verify_description"

  if ! grep -Fqx -- "$EXPECTED_PLUGIN_DESIGN_LINE" "$PLUGIN_README"; then
    record_drift "plugin-readme.design-stage-summary" "$EXPECTED_PLUGIN_DESIGN_LINE" "missing-or-stale"
  fi
}

write_template() {
  local tmp
  tmp="$(mktemp)"
  awk \
    -v design_skip="$DESIGN_SKIP_WHEN" \
    -v verify_feedback="$VERIFY_FEEDBACK_TO" \
    -v design_description="$EXPECTED_TEMPLATE_DESCRIPTION" \
    -v verify_description="$EXPECTED_VERIFY_DESCRIPTION" '
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*design[[:space:]]*$/ {
      stage = "design"
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
      print "    skip-when: \"" design_skip "\""
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
  mv "$tmp" "$TEMPLATE"
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
