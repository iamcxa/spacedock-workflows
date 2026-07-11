#!/usr/bin/env bash
# doc-impact-gate.sh — mechanical coupling gate (AC-2): fails a plugin-touching
# PR that changes a coupled source glob without touching the coupled doc and
# without a "doc-impact: none — <reason>" declaration.
#
# R3 boundary (load-bearing, design.md): this checker does mechanical
# presence + grammar + >=12-char reason-length checking ONLY. It never
# fetches the declaration itself — the caller (CI) passes it in via
# --declaration, keeping this script offline-testable and free of any LLM
# semantic judgment in the required path.
#
# Usage:
#   doc-impact-gate.sh --changed=<file-of-paths> --declaration=<text> [--coupling-map=<path>]
#
# Coupling map resolution order: --coupling-map override >
# .claude/ship-flow/doc-coupling.yaml (adopter override) >
# references/doc-coupling-map.yaml (plugin default).
#
# Read-only. No write mode is available.
#
# Exit codes:
#   0  no BLOCKER rows
#   1  one or more BLOCKER rows
#   2  usage error / rejected write-mode flag

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/.."
# shellcheck source=../lib/glob-match.sh
source "${PLUGIN_DIR}/lib/glob-match.sh"
# shellcheck source=../lib/doc-rationale.sh
source "${PLUGIN_DIR}/lib/doc-rationale.sh"

usage() {
  echo "Usage: doc-impact-gate.sh --changed=<file-of-paths> --declaration=<text> [--coupling-map=<path>]" >&2
  echo "Read-only mechanical coupling gate. No write mode is available." >&2
}

CHANGED_FILE=""
DECLARATION=""
COUPLING_MAP_OVERRIDE=""

for arg in "$@"; do
  case "$arg" in
    --fix|--write|--apply|--sync|--repair)
      usage
      exit 2
      ;;
    --changed=*) CHANGED_FILE="${arg#--changed=}" ;;
    --declaration=*) DECLARATION="${arg#--declaration=}" ;;
    --coupling-map=*) COUPLING_MAP_OVERRIDE="${arg#--coupling-map=}" ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $arg" >&2
      usage
      exit 2
      ;;
  esac
done

if [ -z "$CHANGED_FILE" ]; then
  echo "ERROR: --changed is required" >&2
  usage
  exit 2
fi

if [ ! -f "$CHANGED_FILE" ]; then
  echo "ERROR: --changed file not found: $CHANGED_FILE" >&2
  exit 2
fi

if [ -n "$COUPLING_MAP_OVERRIDE" ]; then
  COUPLING_MAP="$COUPLING_MAP_OVERRIDE"
elif [ -f ".claude/ship-flow/doc-coupling.yaml" ]; then
  COUPLING_MAP=".claude/ship-flow/doc-coupling.yaml"
else
  COUPLING_MAP="${PLUGIN_DIR}/references/doc-coupling-map.yaml"
fi

if [ ! -f "$COUPLING_MAP" ]; then
  echo "ERROR: coupling map not found: $COUPLING_MAP" >&2
  exit 2
fi

BLOCKERS=0

emit_pass() {
  echo "PASS $1"
}

emit_blocker() {
  echo "BLOCKER $1"
  BLOCKERS=$((BLOCKERS + 1))
}

# extract_doc_impact_reason <declaration> — prints the free-text reason after
# an anchored "doc-impact: none" marker (first matching line only), or empty
# if no anchored marker is present. Declaration is an explicit input, never
# fetched here.
#
# codex-gate P1-2: detection requires an explicit separator (one of
# doc-rationale.sh's -—:| chars, optionally repeated e.g. "--") right after
# "none" — prose like "none of these docs are affected" has no separator
# there and must NOT match; it is indistinguishable from no declaration at
# all (falls through to the caller's empty-REASON BLOCKER path). Extraction
# stays permissive (`[-—:|]*`) once a match is confirmed, so multi-char
# separators like "--" are stripped in full, matching prior behavior for
# already-anchored declarations.
extract_doc_impact_reason() {
  local declaration="$1"
  local marker_line
  marker_line="$(printf '%s\n' "$declaration" | grep -im1 '[Dd][Oo][Cc]-[Ii][Mm][Pp][Aa][Cc][Tt]:[[:space:]]*[Nn][Oo][Nn][Ee][[:space:]]*[-—:|]')" || true
  [ -n "$marker_line" ] || { printf ''; return 0; }
  printf '%s' "$marker_line" | sed -E 's/.*[Dd][Oo][Cc]-[Ii][Mm][Pp][Aa][Cc][Tt]:[[:space:]]*[Nn][Oo][Nn][Ee][[:space:]]*[-—:|]*[[:space:]]*//'
}

REASON="$(extract_doc_impact_reason "$DECLARATION")"
CHANGED_FILES_CSV="$(tr '\n' ',' < "$CHANGED_FILE")"

# any_glob_in_csv_matches_files <globs_csv> <files_csv> — prints the first
# matching glob and returns 0, or returns 1 if none of the files match any
# glob. NOTE: does not protect commas inside {a,b} brace groups when a globs
# list has multiple entries — the shipped coupling map does not use brace
# groups; if that changes, apply resolve-skill-routing.sh's route_matches
# comma-protection first.
any_glob_in_csv_matches_files() {
  local globs_csv="$1"
  local files_csv="$2"
  local glob regex file

  while IFS= read -r glob; do
    glob="$(printf '%s' "$glob" | sed 's/^ *//; s/ *$//')"
    [ -n "$glob" ] || continue
    regex="$(glob_to_regex "$glob")"
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      if printf '%s\n' "$file" | grep -Eq "$regex"; then
        printf '%s' "$glob"
        return 0
      fi
    done <<< "$(printf '%s' "$files_csv" | tr ',' '\n')"
  done <<< "$(printf '%s' "$globs_csv" | tr ',' '\n')"
  return 1
}

# any_doc_in_csv_touched <docs_csv> <files_csv> — 0 if some changed file is
# an exact match for one of the coupled docPaths.
any_doc_in_csv_touched() {
  local docs_csv="$1"
  local files_csv="$2"
  local doc file

  while IFS= read -r doc; do
    doc="$(printf '%s' "$doc" | sed 's/^ *//; s/ *$//')"
    [ -n "$doc" ] || continue
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      if [ "$file" = "$doc" ]; then
        return 0
      fi
    done <<< "$(printf '%s' "$files_csv" | tr ',' '\n')"
  done <<< "$(printf '%s' "$docs_csv" | tr ',' '\n')"
  return 1
}

# exclude_doc_paths <files_csv> <docs_csv> — <files_csv> minus any file that
# exactly matches one of <docs_csv> (so a docPath that happens to also match
# a srcGlob does not count toward "touched" on its own).
exclude_doc_paths() {
  local files_csv="$1"
  local docs_csv="$2"
  local file doc keep result=""

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    keep=1
    while IFS= read -r doc; do
      doc="$(printf '%s' "$doc" | sed 's/^ *//; s/ *$//')"
      [ -n "$doc" ] || continue
      if [ "$file" = "$doc" ]; then
        keep=0
        break
      fi
    done <<< "$(printf '%s' "$docs_csv" | tr ',' '\n')"
    if [ "$keep" -eq 1 ]; then
      if [ -n "$result" ]; then result="${result},${file}"; else result="$file"; fi
    fi
  done <<< "$(printf '%s' "$files_csv" | tr ',' '\n')"
  printf '%s' "$result"
}

process_row() {
  local name="$1" src_csv="$2" docs_csv="$3"
  [ -n "$name" ] || return 0

  local non_doc_files_csv
  non_doc_files_csv="$(exclude_doc_paths "$CHANGED_FILES_CSV" "$docs_csv")"

  local matched_glob=""
  if ! matched_glob="$(any_glob_in_csv_matches_files "$src_csv" "$non_doc_files_csv")"; then
    return 0
  fi

  if any_doc_in_csv_touched "$docs_csv" "$CHANGED_FILES_CSV"; then
    emit_pass "${name}: coupled doc touched"
    return 0
  fi

  if [ -z "$REASON" ] || is_weak_skip_rationale "skipped — ${REASON}"; then
    emit_blocker "doc-impact: ${name} — changed ${matched_glob} but coupled doc ${docs_csv//,/, } not touched and no 'doc-impact: none — <reason>' declaration found"
  else
    emit_pass "${name}: doc-impact declaration accepted (${REASON})"
  fi
}

# --- Parse coupling map (line-based; mirrors lib/resolve-skill-routing.sh's
# `- name:` / `srcGlobs: [...]` / `docPaths: [...]` reader) ---
current_name=""
current_src=""
current_docs=""

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    "  - name: "*)
      process_row "$current_name" "$current_src" "$current_docs"
      current_name="${line#  - name: }"
      current_src=""
      current_docs=""
      ;;
    "    srcGlobs: ["*"]")
      current_src="${line#    srcGlobs: [}"
      current_src="${current_src%]}"
      current_src="$(printf '%s' "$current_src" | tr -d '"')"
      ;;
    "    docPaths: ["*"]")
      current_docs="${line#    docPaths: [}"
      current_docs="${current_docs%]}"
      current_docs="$(printf '%s' "$current_docs" | tr -d '"')"
      ;;
  esac
done < "$COUPLING_MAP"
process_row "$current_name" "$current_src" "$current_docs"

if [ "$BLOCKERS" -gt 0 ]; then
  exit 1
fi

exit 0
