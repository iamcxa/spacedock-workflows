#!/usr/bin/env bash
# Build a direct FO-to-stage-worker dispatch prompt with mandatory EM charter.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

workflow_dir="docs/ship-flow"
plugin_root="${ROOT}/plugins/ship-flow"
profile_path=""
stage=""
teammate=""
entity_folder=""
prior_artifact=""
output_artifact=""
skill=""

usage() {
  cat >&2 <<'USAGE'
usage: build-stage-dispatch-prompt.sh --stage <stage> --teammate <name> \
  --entity-folder <path> --prior-artifact <file> --output-artifact <file> \
  --skill <skill> [--workflow-dir <path>] [--plugin-root <path>] \
  [--profile-path <path>]
USAGE
}

abs_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$ROOT" "$1" ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workflow-dir) workflow_dir="${2:?missing --workflow-dir value}"; shift 2 ;;
    --plugin-root) plugin_root="${2:?missing --plugin-root value}"; shift 2 ;;
    --profile-path) profile_path="${2:?missing --profile-path value}"; shift 2 ;;
    --stage) stage="${2:?missing --stage value}"; shift 2 ;;
    --teammate) teammate="${2:?missing --teammate value}"; shift 2 ;;
    --entity-folder) entity_folder="${2:?missing --entity-folder value}"; shift 2 ;;
    --prior-artifact) prior_artifact="${2:?missing --prior-artifact value}"; shift 2 ;;
    --output-artifact) output_artifact="${2:?missing --output-artifact value}"; shift 2 ;;
    --skill) skill="${2:?missing --skill value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

for required in stage teammate entity_folder prior_artifact output_artifact skill; do
  if [ -z "${!required}" ]; then
    echo "missing required argument: --${required//_/-}" >&2
    usage
    exit 2
  fi
done

resolve_profile() {
  if [ -n "$profile_path" ]; then
    abs_path "$profile_path"
    return
  fi

  local workflow_abs plugin_abs
  workflow_abs="$(abs_path "$workflow_dir")"
  plugin_abs="$(abs_path "$plugin_root")"

  if [ -f "${workflow_abs}/_mods/science-officer-em.md" ]; then
    printf '%s\n' "${workflow_abs}/_mods/science-officer-em.md"
    return
  fi

  printf '%s\n' "${plugin_abs}/_mods/science-officer-em.md"
}

profile="$(resolve_profile)"
if [ ! -f "$profile" ]; then
  echo "science-officer-em-profile-not-loaded: ${profile}" >&2
  exit 10
fi

if ! grep -q '^name: science-officer-em$' "$profile" || \
   ! grep -q '^standing: true$' "$profile" || \
   ! grep -qi 'anti-relay' "$profile" || \
   ! grep -qi 'costly no' "$profile" || \
   ! grep -qi 'independent synthesis' "$profile" || \
   ! grep -qi 'FO owns' "$profile" || \
   ! grep -qi 'EM owns' "$profile"; then
  echo "science-officer-em-profile-not-loaded: ${profile} missing required charter markers" >&2
  exit 10
fi

extract_profile_charter() {
  awk '
    /^### Judgment Criteria$/ {printing=1}
    /^### Downstream Boundaries$/ {printing=0}
    /^### Portable Contract Surfaces$/ {printing=0}
    printing {print}
  ' "$profile" | sed '/^$/N;/^\n$/D'
}

charter="$(extract_profile_charter)"
if [ -z "$charter" ]; then
  charter="$(grep -vE '^(---|name:|description:|version:|standing:)' "$profile" | sed '/^[[:space:]]*$/d' | head -20)"
fi

cat <<PROMPT
Run /${stage} for the active ship-flow entity.

Entity folder: ${entity_folder}
Read ${prior_artifact}; output ${output_artifact} via Skill: ${skill}.
Dispatch cross-review counterpart before returning verdict.

### Science Officer (EM) Charter

Mandatory load source: ${profile#"${ROOT}"/}

${charter}

This charter applies only to direct FO-to-stage-worker dispatch in 130.1. Nested
worker prompts, stage-internal worker assignments, stewardship mechanics, and
upward-report schema are 130.2/130.3 scope.

### Codex dispatch evidence guard

Codex/FO-dispatched shape, design, and verify workers MUST NOT report completion
until the expected 113 evidence is produced or explicitly cited in the stage
artifact. Missing required evidence is a completion blocker; return BLOCKED or
NEEDS_CONTEXT instead of DONE/PROCEED.

- shape: include Domain Registry Validation when domain classification or
  validation is relevant.
- design: include ## Schema Design Output for domain: schema or the
  schema-domain route.
- verify: include ## Intent Match Findings when schema design output exists
  or schema domain triggers.

Codex dispatch evidence guard: missing shape/design/verify 113 evidence is a
completion blocker; do not report completion without the required Domain
Registry Validation, ## Schema Design Output, or ## Intent Match Findings block
for the triggered stage.

### Verbatim constraint carriage

Constraints quoted in this prompt are carried verbatim from the entity's
plan/spec. Treat exact flags, paths, thresholds, and never/always qualifiers
as load-bearing. When you re-state a constraint (in sub-dispatches, todos, or
reports), quote it verbatim — never paraphrase or summarize it.

Send this assignment to ${teammate} only after the charter block above is
present in the dispatch body.
PROMPT
