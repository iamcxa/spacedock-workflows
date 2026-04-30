#!/usr/bin/env bash
# workflow-doctor.sh — read-only ship-flow workflow adoption/sync dry-run
#
# Usage:
#   bash plugins/ship-flow/bin/workflow-doctor.sh <workflow-dir>
#
# Output classifications are intentionally grep-friendly:
#   BLOCKER       exits non-zero; captain should fix before dogfood
#   RECOMMENDED   safe sync/adoption recommendation
#   PROJECT_LOCAL project-owned README content to preserve

set -euo pipefail

usage() {
  echo "Usage: workflow-doctor.sh <workflow-dir>" >&2
  echo "Read-only dry-run only. No auto-fix or write mode is available." >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

case "$1" in
  --fix|--write|--apply|--sync|--repair)
    usage
    exit 2
    ;;
esac

WORKFLOW_DIR="$1"
README_FILE="${WORKFLOW_DIR}/README.md"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd)"
TEMPLATE_FILE="${PLUGIN_ROOT}/workflow-template.yaml"

if [ ! -d "$WORKFLOW_DIR" ]; then
  echo "BLOCKER workflow-dir: directory not found: ${WORKFLOW_DIR}"
  exit 1
fi

if [ ! -f "$README_FILE" ]; then
  echo "BLOCKER README: missing ${README_FILE}"
  exit 1
fi

BLOCKERS=0

emit_blocker() {
  echo "BLOCKER $1"
  BLOCKERS=$((BLOCKERS + 1))
}

emit_recommended() {
  echo "RECOMMENDED $1"
}

emit_project_local() {
  echo "PROJECT_LOCAL $1"
}

read_id_style() {
  awk '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 && /^[[:space:]]*id-style:[[:space:]]*/ {
      value = $0
      sub(/^[[:space:]]*id-style:[[:space:]]*/, "", value)
      gsub(/["'\'']/, "", value)
      print value
      exit
    }
  ' "$README_FILE"
}

read_design_skip_when() {
  awk '
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*design[[:space:]]*$/ { in_design = 1; next }
    in_design && /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ { exit }
    in_design && /^[[:space:]]*skip-when:[[:space:]]*/ {
      value = $0
      sub(/^[[:space:]]*skip-when:[[:space:]]*/, "", value)
      gsub(/["'\'']/, "", value)
      print value
      exit
    }
  ' "$README_FILE"
}

ID_STYLE="$(read_id_style)"
if [ "$ID_STYLE" != "slug" ]; then
  emit_blocker "id-style: expected slug, found ${ID_STYLE:-missing}"
fi

DESIGN_SKIP_WHEN="$(read_design_skip_when)"
if [ -z "$DESIGN_SKIP_WHEN" ]; then
  emit_blocker "design.skip-when: missing design stage skip-when; expected domain-aware expression such as !affects_ui && !domain"
elif ! printf '%s\n' "$DESIGN_SKIP_WHEN" | grep -q '!domain'; then
  emit_blocker "design.skip-when: expected domain-aware routing such as !affects_ui && !domain, found ${DESIGN_SKIP_WHEN}"
fi

if [ -f "$TEMPLATE_FILE" ]; then
  if ! grep -qE '^[[:space:]]*-[[:space:]]*name:[[:space:]]*design[[:space:]]*$' "$TEMPLATE_FILE"; then
    emit_recommended "workflow-template.yaml: installed template lacks the design stage; safe template sync recommended for future adopters"
  elif ! awk '
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*design[[:space:]]*$/ { in_design = 1; next }
    in_design && /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ { exit }
    in_design && /^[[:space:]]*skip-when:[[:space:]]*/ { print; found = 1; exit }
    END { exit !found }
  ' "$TEMPLATE_FILE" | grep -q '!domain'; then
    emit_recommended "workflow-template.yaml: design.skip-when is not domain-aware; safe template sync recommended for future adopters"
  fi
else
  emit_recommended "workflow-template.yaml: not found; cannot compare installed template drift"
fi

if grep -qE '^## Local Operating Notes$|project-specific|repository-specific' "$README_FILE"; then
  emit_project_local "README: project-local body content detected; preserve during sync"
fi

if [ "$BLOCKERS" -gt 0 ]; then
  exit 1
fi

exit 0
