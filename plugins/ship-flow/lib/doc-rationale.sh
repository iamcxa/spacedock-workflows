#!/usr/bin/env bash
# doc-rationale.sh — shared skip-rationale quality bar.
# Source this file; do not execute directly.
# Functions: is_weak_skip_rationale
#
# Extracted from bin/canonical-doc-sync-checker.sh (2026-07-12, entity
# 1-self-adoption-dogfood-bootstrap T2.1) so bin/doc-impact-gate.sh can reuse
# the same >=12-char rationale-quality bar as a second consumer instead of
# re-implementing it. Behavior unchanged from the original inline copy.
set -u

# is_weak_skip_rationale <line> — 0 (true/weak) if the "skipped"/"none"
# rationale on <line> is a boilerplate placeholder or shorter than 12 chars
# after the leading skip/none marker is stripped; 1 (false/ok) otherwise.
is_weak_skip_rationale() {
  local line="$1"
  local rationale
  rationale="$(printf '%s\n' "$line" | sed -E 's/.*[Ss][Kk][Ii][Pp][Pp]?[Ee]?[Dd]?[*`[:space:]]*[-—:|]?[[:space:]]*//')"
  rationale="$(printf '%s\n' "$rationale" | sed -E 's/[|[:space:]]*$//; s/^[`*[:space:]]+//; s/[`*[:space:]]+$//')"
  local lowered
  lowered="$(printf '%s\n' "$rationale" | tr '[:upper:]' '[:lower:]')"

  case "$lowered" in
    ""|"-"|"--"|"n/a"|"na"|"none"|"no"|"no rationale"|"not applicable"|"skip"|"skipped"|"tbd"|"todo")
      return 0
      ;;
  esac

  if [ "${#rationale}" -lt 12 ]; then
    return 0
  fi

  return 1
}
