#!/usr/bin/env bash
# glob-match.sh — shared glob -> anchored-regex conversion.
# Source this file; do not execute directly.
# Functions: glob_to_regex
#
# Extracted from lib/resolve-skill-routing.sh (2026-07-12, entity
# 1-self-adoption-dogfood-bootstrap T2.1) so bin/doc-impact-gate.sh can reuse
# it as a second consumer instead of re-implementing glob matching. Behavior
# unchanged from the original inline copy.
set -u

# glob_to_regex <glob> — glob (`**`, `*`, `{a,b}`) -> anchored ERE string.
glob_to_regex() {
  local glob="$1"
  local token="__DOUBLE_STAR__"
  local brace_token="__BRACE_GROUP__"
  local brace_group=""

  glob="${glob//\*\*/$token}"
  if printf '%s' "$glob" | grep -qE '\{[^}]+\}'; then
    brace_group=$(printf '%s' "$glob" | sed -n 's/.*{\([^}]*\)}.*/\1/p' | sed 's/[;,]/|/g')
    glob=$(printf '%s' "$glob" | sed 's/{[^}]*}/__BRACE_GROUP__/')
  fi
  glob=$(printf '%s' "$glob" | sed 's/[.[\^$()+?|]/\\&/g')
  glob="${glob//\*/[^\/]*}"
  glob="${glob//$token/.*}"
  if [ -n "$brace_group" ]; then
    glob="${glob//$brace_token/($brace_group)}"
  fi
  printf '^%s$' "$glob"
}
