#!/usr/bin/env bash
# extract-map.sh <map-file> <section-tag> [--emit-hash-only]
# Prints the content of a named section from a flow-level map doc.
# Schema-validates <section-tag> against flow-map-schema.yaml.
# --emit-hash-only: print sha256 of the whole file (for read-first pairing with patch-map).
#
# Exit codes:
#   0 success
#   1 usage/args error
#   2 tag not in flow-map-schema
#   3 map file missing
#   5 bad-TAG format (not kebab-case)
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="${SCRIPT_DIR}/../references/flow-map-schema.yaml"
# shellcheck source=./map-helpers.sh
source "${SCRIPT_DIR}/map-helpers.sh"

EMIT_HASH_ONLY=0
POS=()
for arg in "$@"; do
  case "$arg" in
    --emit-hash-only) EMIT_HASH_ONLY=1 ;;
    --*) echo "Unknown option: $arg" >&2; exit 1 ;;
    *) POS+=("$arg") ;;
  esac
done

MAP_FILE="${POS[0]:-}"
TAG="${POS[1]:-}"
{ [ -n "$MAP_FILE" ] && [ -n "$TAG" ]; } || {
  echo "Usage: extract-map.sh <map-file> <section-tag> [--emit-hash-only]" >&2
  exit 1
}

[ -f "$MAP_FILE" ] || { echo "Error: file not found: $MAP_FILE" >&2; exit 3; }

validate_kebab_tag "$TAG" || exit 5
validate_schema_tag "$TAG" "$SCHEMA_FILE" || exit 2

if [ "$EMIT_HASH_ONLY" = "1" ]; then
  sha256_of "$MAP_FILE"
  exit 0
fi

# Extract content between <!-- section:TAG --> and <!-- /section:TAG -->
# (reuse extract-section.sh:29 sed idiom — primary path; no H2 fallback for maps)
sed -n "/<!-- section:${TAG} -->/,/<!-- \/section:${TAG} -->/p" "$MAP_FILE"
