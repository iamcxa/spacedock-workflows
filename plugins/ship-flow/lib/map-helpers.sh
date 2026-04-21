#!/usr/bin/env bash
# map-helpers.sh — shared functions for extract-map.sh + patch-map.sh
# Source this file; do not execute directly.
# Functions: sha256_of, atomic_replace, validate_mermaid, validate_schema_tag, validate_kebab_tag, resolve_map_path
#
# Mermaid directive whitelist derivation (#059 Task 3):
# - ARCHITECTURE.md actual scan: `graph` (LR/TB variants)
# - Schema diagram_kind values: "C4 System Context", "C4 Container", "C4 Component or layering"
# - C4 Mermaid dialect: C4Context, C4Container, C4Component, C4Dynamic, C4Deployment
# - Future-proof standard mermaid diagrams
set -u
# shellcheck disable=SC2034  # version marker for future compat detection
MAP_HELPERS_VERSION=1
export MAP_HELPERS_VERSION

MAP_HELPERS_MERMAID_DIRECTIVES='^(graph|flowchart|sequenceDiagram|stateDiagram(-v2)?|classDiagram|erDiagram|C4Context|C4Container|C4Component|C4Dynamic|C4Deployment|gantt|pie|gitGraph|mindmap|timeline|journey|quadrantChart|xychart)'

# sha256_of <file> — prints 64-char hex, cross-platform (macOS shasum / Linux sha256sum)
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# validate_kebab_tag <tag> — exit 0 OK, exit 5 bad format
validate_kebab_tag() {
  local tag="$1"
  if [[ ! "$tag" =~ ^[a-z]([a-z0-9-]*[a-z0-9])?$ ]]; then
    echo "Error: TAG must be kebab-case [a-z][a-z0-9-]*: '${tag}'" >&2
    return 5
  fi
  return 0
}

# validate_schema_tag <tag> <schema-file> — exit 0 OK, exit 2 not-in-schema
validate_schema_tag() {
  local tag="$1" schema="$2"
  if ! grep -qE "^[[:space:]]+- section_tag: ${tag}[[:space:]]*\$" "$schema"; then
    echo "Error: section tag '${tag}' not in $(basename "$schema")" >&2
    echo "Valid tags:" >&2
    grep -oE "section_tag: [a-z][a-z0-9-]*" "$schema" | awk '{print "  " $2}' | sort -u >&2
    return 2
  fi
  return 0
}

# atomic_replace <file> <tag> <body-file> — replace content between
# <!-- section:TAG --> and <!-- /section:TAG --> atomically (mktemp + mv on same fs)
# Reads body from FILE (not -v) to avoid awk backslash interpretation.
# Exit 10 if markers missing or unbalanced.
atomic_replace() {
  local file="$1" tag="$2" bodyfile="$3"
  local tmp
  tmp="$(mktemp "${file}.XXXXXX")" || return 1
  trap 'rm -f "$tmp"' EXIT INT TERM

  awk -v tag="$tag" -v bodyfile="$bodyfile" '
    BEGIN {
      body = ""
      while ((getline line < bodyfile) > 0) body = body line ORS
      sub(ORS "$", "", body)
      seen_open = 0; seen_close = 0; in_sec = 0
    }
    $0 ~ "<!-- section:" tag " -->"  { print; print body; in_sec = 1; seen_open = 1; next }
    $0 ~ "<!-- /section:" tag " -->" { in_sec = 0; seen_close = 1 }
    !in_sec { print }
    END { if (!seen_open || !seen_close) exit 10 }
  ' "$file" > "$tmp"
  local awk_rc=$?
  if [ "$awk_rc" -ne 0 ]; then
    rm -f "$tmp"
    trap - EXIT INT TERM
    return 10
  fi

  mv "$tmp" "$file"
  trap - EXIT INT TERM
  return 0
}

# resolve_map_path <plugin_slug> <map_name> — returns plugin-scoped or repo-root path
# Usage: resolve_map_path "ship-flow" "ARCHITECTURE.md" → "plugins/ship-flow/ARCHITECTURE.md"
#        resolve_map_path "" "ARCHITECTURE.md"          → "ARCHITECTURE.md"
# Backward-compat: empty plugin_slug → repo-root relative (no plugins/ prefix)
resolve_map_path() {
  local plugin_slug="${1:-}" map_name="${2}"
  if [ -n "$plugin_slug" ]; then
    echo "plugins/${plugin_slug}/${map_name}"
  else
    echo "${map_name}"
  fi
}

# validate_mermaid <body-file> <diagram-kind> — exit 0 OK, exit 9 missing/invalid
# Only call when schema declares requires_diagram: true for the target section.
validate_mermaid() {
  local bodyfile="$1" kind="$2"
  if ! grep -qE '^```mermaid$' "$bodyfile"; then
    echo "Error: patched content requires mermaid diagram (kind: '${kind}') but no \`\`\`mermaid fence found" >&2
    return 9
  fi
  if ! awk '/^```mermaid$/{flag=1; next} /^```$/{flag=0} flag' "$bodyfile" | \
       grep -qE "$MAP_HELPERS_MERMAID_DIRECTIVES"; then
    echo "Error: mermaid fence found but missing valid directive (expected one of: graph, flowchart, C4Container, C4Component, ...)" >&2
    return 9
  fi
  local opens closes
  opens=$(grep -cE '^```mermaid$' "$bodyfile" || true)
  closes=$(awk '/^```mermaid$/{f=1;next} /^```$/&&f{c++;f=0} END{print c+0}' "$bodyfile")
  if [ "$opens" != "$closes" ]; then
    echo "Error: unbalanced mermaid fences (open=$opens, close=$closes)" >&2
    return 9
  fi
  return 0
}
