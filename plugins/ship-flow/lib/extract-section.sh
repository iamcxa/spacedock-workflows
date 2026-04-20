#!/usr/bin/env bash
# extract-section.sh <entity-file> <section-tag>
# Prints the content of a named section from an entity markdown file.
# Primary: HTML comment tags <!-- section:tag --> ... <!-- /section:tag -->
# Fallback: H2 boundary extraction (legacy entities without tags)
# Exit 0 on success with content on stdout; exit 1 on not found.
set -euo pipefail

ENTITY_FILE="${1:-}"
TAG="${2:-}"

if [ -z "$ENTITY_FILE" ] || [ -z "$TAG" ]; then
  echo "Usage: extract-section.sh <entity-file> <section-tag>" >&2
  exit 1
fi

if [ ! -f "$ENTITY_FILE" ]; then
  echo "Error: file not found: $ENTITY_FILE" >&2
  exit 1
fi

# Primary: HTML comment tag extraction
RESULT=$(sed -n "/<!-- section:${TAG} -->/,/<!-- \/section:${TAG} -->/p" "$ENTITY_FILE")
if [ -n "$RESULT" ]; then
  printf '%s\n' "$RESULT"
  exit 0
fi

# Fallback: H2 boundary extraction
# Convert kebab-case tag to Title Case header (sharp-output → Sharp Output)
HEADER=$(echo "$TAG" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')
RESULT=$(awk "
  found && /^## / { exit }
  found { print }
  /^## ${HEADER}[[:space:]]*\$/ { found=1; print }
" "$ENTITY_FILE")
if [ -n "$RESULT" ]; then
  printf '%s\n' "$RESULT"
  exit 0
fi

echo "Section '${TAG}' not found in ${ENTITY_FILE}" >&2
exit 1
