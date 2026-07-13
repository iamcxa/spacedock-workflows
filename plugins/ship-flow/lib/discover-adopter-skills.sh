#!/usr/bin/env bash
# discover-adopter-skills.sh — derive adopter-level file-signal skill routing
#
# This helper does not write files. Consumers may redirect stdout to
# .claude/ship-flow/skill-routing.yaml after captain review.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "${SCRIPT_DIR}/discovery-exclusions.sh"

ROOT="."

usage() {
  cat <<'EOF'
discover-adopter-skills — derive adopter-level file-signal skill routing

Usage:
  discover-adopter-skills.sh [--root=<repo-root>]

Output:
  YAML suitable for .claude/ship-flow/skill-routing.yaml
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --root=*)
      ROOT="${1#--root=}"
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

[ -d "$ROOT" ] || {
  echo "ERROR: root not found: $ROOT" >&2
  exit 2
}

SCRATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ship-flow-adopter-discovery.XXXXXX")" || {
  echo "ERROR: adopter discovery could not create bounded capture directory" >&2
  exit 2
}
trap 'rm -rf "${SCRATCH_DIR}"' EXIT INT TERM

PROBE_STDOUT="${SCRATCH_DIR}/probe.stdout"
PROBE_STDERR="${SCRATCH_DIR}/probe.stderr"
ROUTING_OUTPUT="${SCRATCH_DIR}/routing.yaml"

capture_probe() {
  local family="$1"
  local context="$2"
  local producer_status
  shift 2

  : >"${PROBE_STDOUT}"
  : >"${PROBE_STDERR}"

  if find_pruned "$@" >"${PROBE_STDOUT}" 2>"${PROBE_STDERR}"; then
    producer_status=0
  else
    producer_status=$?
  fi

  if [ "${producer_status}" -ne 0 ]; then
    if [ -s "${PROBE_STDERR}" ]; then
      cat "${PROBE_STDERR}" >&2
    fi
    printf 'ERROR: adopter discovery %s traversal failed (rc %s): %s\n' \
      "${family}" "${producer_status}" "${context}" >&2
    return 2
  fi

  if [ -s "${PROBE_STDOUT}" ]; then
    return 0
  fi
  return 1
}

has_path() {
  local pattern="$1"
  capture_probe "has_path" "$pattern" -path "$ROOT/$pattern" -print -quit
}

has_file_name() {
  local name="$1"
  capture_probe "has_file_name" "$name" -name "$name" -print -quit
}

has_dependency() {
  local pattern="$1"
  capture_probe "has_dependency" "$pattern" \
    -name package.json -type f \
    -exec sh -c 'grep -qE "$1" "$2"' sh "$pattern" {} \; \
    -print -quit
}

probe_any() {
  local family
  local argument
  local probe_status

  while [ "$#" -gt 0 ]; do
    family="$1"
    argument="$2"
    shift 2

    if "$family" "$argument"; then
      return 0
    else
      probe_status=$?
    fi

    case "$probe_status" in
      1)
        ;;
      2)
        return 2
        ;;
      *)
        printf 'ERROR: adopter discovery %s returned unexpected probe status %s\n' \
          "$family" "$probe_status" >&2
        return 2
        ;;
    esac
  done

  return 1
}

find_pruned() {
  ship_flow_discovery_find "$ROOT" \
    \( \
      -path "$ROOT/.git" -o \
      -path "$ROOT/node_modules" -o \
      -path "$ROOT/.claude/worktrees" -o \
      -path "$ROOT/.worktrees" -o \
      -path "$ROOT/worktrees" -o \
      -path "$ROOT/docs/ship-flow/_archive" -o \
      -path "$ROOT/dist" -o \
      -path "$ROOT/build" -o \
      -path "$ROOT/.next" -o \
      -path "$ROOT/.turbo" \
    \) -prune -o "$@"
}

emit_header() {
  cat <<'EOF'
schema_version: "1.0"
target_path: .claude/ship-flow/skill-routing.yaml
source: discovered
boundary: domain registry required_skills stay in domains.yaml; file-signal skills live here
routing:
EOF
}

emit_route() {
  local name="$1"
  local signals="$2"
  local skills="$3"
  local notes="$4"

  cat <<EOF
  - name: $name
    signals: [$signals]
    skills: [$skills]
    notes: "$notes"
EOF
}

{
  emit_header

  if probe_any has_path "apps/refine-app/*" has_dependency '"@refinedev/'; then
    emit_route \
      "refine-web" \
      "apps/refine-app/src/**" \
      "refine-expert, refine-gotchas, antd-expert, react-patterns, tailwind-expert" \
      "Refine/Ant Design office web surface."
  else
    probe_status=$?
    [ "$probe_status" -eq 1 ] || exit 2
  fi

  if probe_any has_path "apps/expo-app/*" has_file_name "app.json" has_dependency '"expo"'; then
    emit_route \
      "expo-mobile" \
      "apps/expo-app/**" \
      "expo-rnr-nativewind, expo-accessibility, react-patterns" \
      "Expo mobile surface."
  else
    probe_status=$?
    [ "$probe_status" -eq 1 ] || exit 2
  fi

  if probe_any \
    has_path "apps/supabase/migrations/*" \
    has_path "domains/*/src/schema/*" \
    has_path "apps/supabase/types/*"; then
    emit_route \
      "supabase-schema" \
      "domains/**/src/schema/**, apps/supabase/migrations/**, apps/supabase/types/**" \
      "project-db, migration-helper" \
      "Supabase/Drizzle schema and migration work."
  else
    probe_status=$?
    [ "$probe_status" -eq 1 ] || exit 2
  fi

  if probe_any \
    has_path "domains/*/src/domain/*/types.ts" \
    has_path "domains/*/src/domain/*/decider.ts" \
    has_path "domains/*/src/domain/*/view.ts" \
    has_path "domains/*/src/domain/*/saga.ts" \
    has_path "apps/deno-api/src/middlewares/fmodel-middleware.ts"; then
    emit_route \
      "fmodel-domain" \
      "domains/**/src/domain/**/{types,decider,view,saga}.ts, apps/deno-api/src/middlewares/fmodel-middleware.ts" \
      "fmodel" \
      "fmodel aggregate, decider, view, saga, and projection contracts."
  else
    probe_status=$?
    [ "$probe_status" -eq 1 ] || exit 2
  fi

  if probe_any \
    has_path "packages/api-contract/src/*.schemas.ts" \
    has_path "packages/api-contract/src/*/*.schemas.ts" \
    has_path "apps/deno-api/src/routers/*" \
    has_dependency '"@ts-rest/'; then
    emit_route \
      "api-contract" \
      "packages/api-contract/src/**/*.schemas.ts, apps/deno-api/src/routers/**" \
      "ts-rest, api-guide" \
      "API contract schemas and router surface."
  else
    probe_status=$?
    [ "$probe_status" -eq 1 ] || exit 2
  fi

  if probe_any has_path "apps/supabase/functions/*"; then
    emit_route \
      "supabase-edge-functions" \
      "apps/supabase/functions/**" \
      "project-supabase-edge-functions, deno-test" \
      "Supabase Edge Functions. Keep separate from plain migrations."
  else
    probe_status=$?
    [ "$probe_status" -eq 1 ] || exit 2
  fi
} >"${ROUTING_OUTPUT}"

cat "${ROUTING_OUTPUT}"
