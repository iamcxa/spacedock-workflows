#!/usr/bin/env bash
# resolve-shape-artifact.sh - resolve canonical shape artifact with legacy fallback
set -u

if [ "$#" -ne 1 ]; then
  echo "Usage: resolve-shape-artifact.sh <entity-folder>" >&2
  exit 2
fi

ENTITY_FOLDER="$1"
SHAPE_PATH="${ENTITY_FOLDER}/shape.md"
legacy_spec_path="${ENTITY_FOLDER}/spec.md"

if [ -f "$SHAPE_PATH" ]; then
  printf '%s\n' "$SHAPE_PATH"
  exit 0
fi

if [ -f "$legacy_spec_path" ]; then
  printf '%s\n' "$legacy_spec_path"
  exit 0
fi

echo "Error: missing shape artifact in ${ENTITY_FOLDER} (expected shape.md, legacy fallback spec.md)" >&2
exit 4
