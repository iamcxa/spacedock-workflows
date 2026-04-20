#!/usr/bin/env bash
# write-section.sh <entity-file> <section-tag> [<content>]
# Appends a named section to an entity markdown file.
# Content may be supplied as a third argument or via stdin.
# Exit codes:
#   0  success
#   1  usage/args error
#   2  tag not in schema (schema validation failure)
#   3  entity file missing
#   4  tag already exists in entity (duplicate — no --replace in V1)
#   5  invalid TAG format (not kebab-case)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="${SCRIPT_DIR}/../references/entity-body-schema.yaml"

ENTITY_FILE="${1:-}"
TAG="${2:-}"
CONTENT_ARG="${3:-}"

# --- Arg validation (exit 1) ---
if [ -z "$ENTITY_FILE" ] || [ -z "$TAG" ]; then
  echo "Usage: write-section.sh <entity-file> <section-tag> [<content>]" >&2
  exit 1
fi

# --- TAG format validation (exit 5) ---
if [[ ! "$TAG" =~ ^[a-z]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "ERROR: TAG must be kebab-case [a-z][a-z0-9-]*: '${TAG}'" >&2
  exit 5
fi

# --- Schema validation (exit 2) ---
if ! grep -qE "section_tag: \"?${TAG}\"?" "$SCHEMA_FILE"; then
  echo "Error: section tag '${TAG}' not found in schema (${SCHEMA_FILE})" >&2
  exit 2
fi

# --- Entity file existence (exit 3) ---
if [ ! -f "$ENTITY_FILE" ]; then
  echo "Error: entity file not found: ${ENTITY_FILE}" >&2
  exit 3
fi

# --- Duplicate check (exit 4) ---
if grep -q "<!-- section:${TAG} -->" "$ENTITY_FILE"; then
  echo "Error: section '${TAG}' already exists in ${ENTITY_FILE} (use --replace in V2)" >&2
  exit 4
fi

# --- Read content from arg or stdin ---
if [ -n "$CONTENT_ARG" ]; then
  CONTENT="$CONTENT_ARG"
else
  CONTENT="$(cat)"
fi

# --- Append section ---
printf '\n<!-- section:%s -->\n%s\n<!-- /section:%s -->\n' \
  "$TAG" "$CONTENT" "$TAG" >> "$ENTITY_FILE"

exit 0
