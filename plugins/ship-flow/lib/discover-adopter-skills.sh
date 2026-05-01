#!/usr/bin/env bash
# discover-adopter-skills.sh — derive adopter-level file-signal skill routing
#
# This helper does not write files. Consumers may redirect stdout to
# .claude/ship-flow/skill-routing.yaml after captain review.

set -euo pipefail

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

has_path() {
  local pattern="$1"
  find_pruned -path "$ROOT/$pattern" -print -quit | grep -q .
}

has_file_name() {
  local name="$1"
  find_pruned -name "$name" -print -quit | grep -q .
}

has_dependency() {
  local pattern="$1"
  find_pruned -name package.json -type f -exec sh -c 'grep -qE "$1" "$2"' sh "$pattern" {} \; -print -quit | grep -q .
}

find_pruned() {
  find "$ROOT" \
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
    \) -prune -o "$@" 2>/dev/null
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

emit_header

if has_path "apps/refine-app/*" || has_dependency '"@refinedev/'; then
  emit_route \
    "refine-web" \
    "apps/refine-app/src/**" \
    "refine-expert, refine-gotchas, antd-expert, react-patterns, tailwind-expert" \
    "Refine/Ant Design office web surface."
fi

if has_path "apps/expo-app/*" || has_file_name "app.json" || has_dependency '"expo"'; then
  emit_route \
    "expo-mobile" \
    "apps/expo-app/**" \
    "expo-rnr-nativewind, expo-accessibility, react-patterns" \
    "Expo mobile surface."
fi

if has_path "apps/supabase/migrations/*" || has_path "domains/*/src/schema/*" || has_path "apps/supabase/types/*"; then
  emit_route \
    "supabase-schema" \
    "domains/**/src/schema/**, apps/supabase/migrations/**, apps/supabase/types/**" \
    "project-db, migration-helper" \
    "Supabase/Drizzle schema and migration work."
fi

if has_path "domains/*/src/domain/*/types.ts" || has_path "domains/*/src/domain/*/decider.ts" || has_path "domains/*/src/domain/*/view.ts" || has_path "domains/*/src/domain/*/saga.ts" || has_path "apps/deno-api/src/middlewares/fmodel-middleware.ts"; then
  emit_route \
    "fmodel-domain" \
    "domains/**/src/domain/**/{types,decider,view,saga}.ts, apps/deno-api/src/middlewares/fmodel-middleware.ts" \
    "fmodel" \
    "fmodel aggregate, decider, view, saga, and projection contracts."
fi

if has_path "packages/api-contract/src/*.schemas.ts" || has_path "packages/api-contract/src/*/*.schemas.ts" || has_path "apps/deno-api/src/routers/*" || has_dependency '"@ts-rest/'; then
  emit_route \
    "api-contract" \
    "packages/api-contract/src/**/*.schemas.ts, apps/deno-api/src/routers/**" \
    "ts-rest, api-guide" \
    "API contract schemas and router surface."
fi

if has_path "apps/supabase/functions/*"; then
  emit_route \
    "supabase-edge-functions" \
    "apps/supabase/functions/**" \
    "project-supabase-edge-functions, deno-test" \
    "Supabase Edge Functions. Keep separate from plain migrations."
fi
