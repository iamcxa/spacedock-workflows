#!/usr/bin/env bash
# doc-impact-gate.sh — mechanical coupling gate (AC-2): fails a plugin-touching
# PR that changes one side of a declared contribution edge without touching
# its required counterpart. Legacy rows enforce source-to-doc only; rows may
# explicitly add doc-to-source without changing legacy behavior.
#
# R3 boundary (load-bearing, design.md): this checker does mechanical
# presence + grammar + >=12-char reason-length checking ONLY. It never
# fetches the declaration itself — the caller (CI) passes it in via
# --declaration, keeping this script offline-testable and free of any LLM
# semantic judgment in the required path.
#
# Usage:
#   doc-impact-gate.sh --changed=<file-of-paths> [--changed-status=<name-status-file>] --declaration=<text> [--coupling-map=<path>] [--base-coupling-map=<path>]
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
#   2  usage error / rejected write-mode flag / invalid coupling map

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/.."

# The canonical plugin layout shares these helpers. An adopter may instead
# copy this exact checker to .claude/ship-flow/doc-impact-gate.sh; in that
# layout the checker must remain self-contained and uses the mirrored fallback
# definitions below rather than requiring a vendored plugins/ship-flow tree.
if [ -f "${PLUGIN_DIR}/lib/glob-match.sh" ] && [ -f "${PLUGIN_DIR}/lib/doc-rationale.sh" ]; then
  # shellcheck source=../lib/glob-match.sh
  # Runtime path is canonical or adopter-local.
  # shellcheck disable=SC1091
  source "${PLUGIN_DIR}/lib/glob-match.sh"
  # shellcheck source=../lib/doc-rationale.sh
  # Runtime path is canonical or adopter-local.
  # shellcheck disable=SC1091
  source "${PLUGIN_DIR}/lib/doc-rationale.sh"
else
  glob_to_regex() {
    local glob="$1" token="__DOUBLE_STAR__" brace_token="__BRACE_GROUP__" brace_group=""
    glob="${glob//\*\*/$token}"
    if printf '%s' "$glob" | grep -qE '\{[^}]+\}'; then
      brace_group=$(printf '%s' "$glob" | sed -n 's/.*{\([^}]*\)}.*/\1/p' | sed 's/[;,]/|/g')
      glob=$(printf '%s' "$glob" | sed 's/{[^}]*}/__BRACE_GROUP__/')
    fi
    # '$' is a literal regex character here.
    # shellcheck disable=SC2016
    glob=$(printf '%s' "$glob" | sed 's/[.[\^$()+?|]/\\&/g')
    glob="${glob//\*/[^\/]*}"
    glob="${glob//$token/.*}"
    if [ -n "$brace_group" ]; then glob="${glob//$brace_token/($brace_group)}"; fi
    printf '^%s$' "$glob"
  }

  is_weak_skip_rationale() {
    local line="$1" rationale lowered
    rationale="$(printf '%s\n' "$line" | sed -E 's/.*[Ss][Kk][Ii][Pp][Pp]?[Ee]?[Dd]?[*`[:space:]]*[-—:|]?[[:space:]]*//')"
    # Backticks are literal Markdown delimiters.
    # shellcheck disable=SC2016
    rationale="$(printf '%s\n' "$rationale" | sed -E 's/[|[:space:]]*$//; s/^[`*[:space:]]+//; s/[`*[:space:]]+$//')"
    lowered="$(printf '%s\n' "$rationale" | tr '[:upper:]' '[:lower:]')"
    case "$lowered" in
      ""|"-"|"--"|"n/a"|"na"|"none"|"no"|"no rationale"|"not applicable"|"skip"|"skipped"|"tbd"|"todo") return 0 ;;
    esac
    [ "${#rationale}" -lt 12 ] && return 0
    return 1
  }
fi

usage() {
  echo "Usage: doc-impact-gate.sh --changed=<file-of-paths> [--changed-status=<name-status-file>] --declaration=<text> [--coupling-map=<path>] [--base-coupling-map=<path>]" >&2
  echo "Read-only mechanical coupling gate. No write mode is available." >&2
}

CHANGED_FILE=""
CHANGED_STATUS_FILE=""
DECLARATION=""
COUPLING_MAP_OVERRIDE=""
BASE_COUPLING_MAP=""
HEAD_MAP_ABSENT=0
SYNTHETIC_HEAD_MAP=""

# Invoked by the EXIT trap below.
# shellcheck disable=SC2329
cleanup() {
  [ -z "$SYNTHETIC_HEAD_MAP" ] || rm -f "$SYNTHETIC_HEAD_MAP"
}
trap cleanup EXIT

for arg in "$@"; do
  case "$arg" in
    --fix|--write|--apply|--sync|--repair)
      usage
      exit 2
      ;;
    --changed=*) CHANGED_FILE="${arg#--changed=}" ;;
    --changed-status=*) CHANGED_STATUS_FILE="${arg#--changed-status=}" ;;
    --declaration=*) DECLARATION="${arg#--declaration=}" ;;
    --coupling-map=*) COUPLING_MAP_OVERRIDE="${arg#--coupling-map=}" ;;
    --base-coupling-map=*) BASE_COUPLING_MAP="${arg#--base-coupling-map=}" ;;
    --head-map-absent) HEAD_MAP_ABSENT=1 ;;
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
if [ -n "$CHANGED_STATUS_FILE" ] && [ ! -f "$CHANGED_STATUS_FILE" ]; then
  echo "ERROR: --changed-status file not found: $CHANGED_STATUS_FILE" >&2
  exit 2
fi

if [ "$HEAD_MAP_ABSENT" -eq 1 ]; then
  if [ -z "$BASE_COUPLING_MAP" ] || [ ! -f "$BASE_COUPLING_MAP" ]; then
    echo "ERROR: --head-map-absent requires an existing --base-coupling-map" >&2
    exit 2
  fi
  SYNTHETIC_HEAD_MAP="$(mktemp)"
  printf '%s\n' \
    'schema_version: "1.1"' \
    'couplings:' \
    '  - name: __removed_contract_sentinel__' \
    '    srcGlobs: ["__ship_flow_never__"]' \
    '    docPaths: ["__ship_flow_never__.md"]' > "$SYNTHETIC_HEAD_MAP"
  COUPLING_MAP_OVERRIDE="$SYNTHETIC_HEAD_MAP"
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
if [ -n "$BASE_COUPLING_MAP" ] && [ ! -f "$BASE_COUPLING_MAP" ]; then
  echo "ERROR: base coupling map not found: $BASE_COUPLING_MAP" >&2
  exit 2
fi

# schema_version is a frozen parser boundary, not advisory metadata. Parse it
# before any row can emit PASS/BLOCKER output so unknown or ambiguous maps
# never receive partial enforcement.
SCHEMA_VERSION=""
SCHEMA_VERSION_COUNT=0
SCHEMA_VERSION_MALFORMED=0
while IFS= read -r schema_line || [ -n "$schema_line" ]; do
  if [[ "$schema_line" =~ ^[[:space:]]*schema_version: ]]; then
    SCHEMA_VERSION_COUNT=$((SCHEMA_VERSION_COUNT + 1))
    if ! [[ "$schema_line" =~ ^schema_version: ]]; then
      SCHEMA_VERSION_MALFORMED=1
      continue
    fi
    parsed_version="$(printf '%s\n' "$schema_line" | sed -nE "s/^schema_version:[[:space:]]*['\"]([^'\"]+)['\"][[:space:]]*$/\\1/p")"
    if [ -z "$parsed_version" ]; then
      SCHEMA_VERSION_MALFORMED=1
    else
      SCHEMA_VERSION="$parsed_version"
    fi
  fi
done < "$COUPLING_MAP"

if [ "$SCHEMA_VERSION_COUNT" -ne 1 ]; then
  echo "ERROR: coupling map ${COUPLING_MAP} must declare exactly one top-level schema_version; found ${SCHEMA_VERSION_COUNT}." >&2
  exit 2
fi
if [ "$SCHEMA_VERSION_MALFORMED" -ne 0 ]; then
  echo "ERROR: coupling map ${COUPLING_MAP} has a malformed schema_version; use the quoted top-level form schema_version: \"1.0\" or \"1.1\"." >&2
  exit 2
fi
case "$SCHEMA_VERSION" in
  1.0|1.1) ;;
  *)
    echo "ERROR: coupling map ${COUPLING_MAP} declares unsupported schema_version '${SCHEMA_VERSION}'. Supported versions: 1.0, 1.1." >&2
    exit 2
    ;;
esac

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
#
# codex-gate round-2 P1-2 residual: the marker must also be line-anchored
# (only leading whitespace allowed before "doc-impact:"). Without this, any
# text preceding the marker on the same line — a PR-template example line
# ("Example only: doc-impact: none — ..."), a quoted/attributed aside
# ('"doc-impact: none — ..." they said'), etc. — counted as a real waiver.
# A genuine declaration is always its own standalone line; anything else is
# indistinguishable from quoted/prefixed prose and must fall through to the
# caller's empty-REASON BLOCKER path exactly like no declaration at all.
extract_doc_impact_reason() {
  local declaration="$1"
  local marker_line
  marker_line="$(printf '%s\n' "$declaration" | grep -im1 '^[[:space:]]*[Dd][Oo][Cc]-[Ii][Mm][Pp][Aa][Cc][Tt]:[[:space:]]*[Nn][Oo][Nn][Ee][[:space:]]*[-—:|]')" || true
  [ -n "$marker_line" ] || { printf ''; return 0; }
  printf '%s' "$marker_line" | sed -E 's/^[[:space:]]*[Dd][Oo][Cc]-[Ii][Mm][Pp][Aa][Cc][Tt]:[[:space:]]*[Nn][Oo][Nn][Ee][[:space:]]*[-—:|]*[[:space:]]*//'
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

# filter_exempt_paths <files_csv> <exempt_globs_csv> — remove only paths that
# match a row-local exemption. Exemptions never leak across coupling rows.
filter_exempt_paths() {
  local files_csv="$1" exempt_globs_csv="$2"
  local file result=""

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if [ -n "$exempt_globs_csv" ] && any_glob_in_csv_matches_files "$exempt_globs_csv" "$file" > /dev/null; then
      continue
    fi
    if [ -n "$result" ]; then result="${result},${file}"; else result="$file"; fi
  done <<< "$(printf '%s' "$files_csv" | tr ',' '\n')"
  printf '%s' "$result"
}

directions_include() {
  local directions_csv="$1" wanted="$2" direction
  while IFS= read -r direction; do
    direction="$(printf '%s' "$direction" | sed 's/^ *//; s/ *$//')"
    [ "$direction" = "$wanted" ] && return 0
  done <<< "$(printf '%s' "$directions_csv" | tr ',' '\n')"
  return 1
}

extract_scoped_contribution_reason() {
  local name="$1" direction="$2" line prefix remainder
  prefix="contribution-impact: none [${name}:${direction}]"
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
    case "$line" in
      "$prefix — "*) remainder="${line#"$prefix — "}" ;;
      "$prefix -"*) remainder="${line#"$prefix -"}" ;;
      "$prefix :"*) remainder="${line#"$prefix :"}" ;;
      "$prefix |"*) remainder="${line#"$prefix |"}" ;;
      *) continue ;;
    esac
    printf '%s' "$(printf '%s' "$remainder" | sed 's/^[[:space:]]*//')"
    return 0
  done <<< "$DECLARATION"
  printf ''
}

emit_missing_path_blockers() {
  local name="$1" src_csv="$2" docs_csv="$3" files_csv="$4"
  local file missing=0

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if any_glob_in_csv_matches_files "$src_csv" "$file" > /dev/null || any_doc_in_csv_touched "$docs_csv" "$file"; then
      local deleted=false status_path="" status_code=""
      if [ -n "$CHANGED_STATUS_FILE" ]; then
        while IFS=$'\t' read -r status_code status_path _; do
          if [ "$status_code" = "D" ] && [ "$status_path" = "$file" ]; then
            deleted=true
            break
          fi
        done < "$CHANGED_STATUS_FILE"
      elif [ ! -e "$file" ]; then
        deleted=true
      fi
      if [ "$deleted" = "true" ]; then
        emit_blocker "contribution-impact: ${name} [protected-path] — ${file} is missing; update the coupling row for a rename or add a narrow exemptGlobs entry for an intentional deletion"
        missing=1
      fi
    fi
  done <<< "$(printf '%s' "$files_csv" | tr ',' '\n')"

  [ "$missing" -eq 0 ]
}

process_row() {
  local name="$1" src_csv="$2" docs_csv="$3" directions_csv="$4" exempt_globs_csv="$5"
  [ -n "$name" ] || return 0

  local row_changed_files_csv non_doc_files_csv
  row_changed_files_csv="$(filter_exempt_paths "$CHANGED_FILES_CSV" "$exempt_globs_csv")"
  non_doc_files_csv="$(exclude_doc_paths "$row_changed_files_csv" "$docs_csv")"

  if [ "$directions_csv" != "source-to-doc" ] || [ -n "$CHANGED_STATUS_FILE" ]; then
    emit_missing_path_blockers "$name" "$src_csv" "$docs_csv" "$row_changed_files_csv" || true
  fi

  if directions_include "$directions_csv" "source-to-doc"; then
    local matched_glob=""
    if matched_glob="$(any_glob_in_csv_matches_files "$src_csv" "$non_doc_files_csv")"; then
      if any_doc_in_csv_touched "$docs_csv" "$row_changed_files_csv"; then
        emit_pass "${name}: coupled doc touched"
      elif [ -z "$REASON" ] || is_weak_skip_rationale "skipped — ${REASON}"; then
        emit_blocker "doc-impact: ${name} — changed ${matched_glob} but coupled doc ${docs_csv//,/, } not touched and no 'doc-impact: none — <reason>' declaration found"
      else
        emit_pass "${name}: doc-impact declaration accepted (${REASON})"
      fi
    fi
  fi

  if directions_include "$directions_csv" "doc-to-source" && any_doc_in_csv_touched "$docs_csv" "$row_changed_files_csv"; then
    local matched_source="" scoped_reason=""
    if matched_source="$(any_glob_in_csv_matches_files "$src_csv" "$non_doc_files_csv")"; then
      emit_pass "contribution-impact: ${name} [doc-to-source] counterpart touched (${matched_source})"
    else
      scoped_reason="$(extract_scoped_contribution_reason "$name" "doc-to-source")"
      if [ -n "$scoped_reason" ] && ! is_weak_skip_rationale "skipped — ${scoped_reason}"; then
        emit_pass "contribution-impact: ${name} [doc-to-source] scoped exemption accepted (${scoped_reason})"
      else
        emit_blocker "contribution-impact: ${name} [doc-to-source] — contract doc changed but coupled source/code/schema ${src_csv//,/, } not touched; use a paired change or 'contribution-impact: none [${name}:doc-to-source] — <reason>'"
      fi
    fi
  fi
}

# --- Parse coupling map (line-based; mirrors lib/resolve-skill-routing.sh's
# `- name:` / `srcGlobs: [...]` / `docPaths: [...]` reader) ---
#
# codex-gate P1-3: the D1 schema (design.md) is declared flat/inline —
# `srcGlobs: ["a", "b"]` — but the original matcher only recognized one
# exact 4-space, double-quote layout, so any other reasonable rendering of
# that same flat schema (single quotes, different indentation) silently
# parsed to an empty list and the row was skipped unprotected (fail-open).
# Two-part fix: (1) tolerate whitespace/quote-style variance within the
# declared flat schema via regex matching instead of literal-prefix `case`;
# (2) validate_row fails CLOSED (hard error, exit 2) for any named row that
# still ends up with an empty srcGlobs or docPaths — covering layouts
# genuinely outside the flat schema (e.g. YAML block sequences) that this
# zero-dep line-based parser does not attempt to support.
#
# codex-gate round-2 P1-3 residual: per-row fail-closed above is not enough
# when the WHOLE map parses to zero rows — a `couplings:` key rendered in an
# unsupported layout the row matcher never triggers on at all (e.g. flow-style
# `couplings: [{...}]`, or a syntactically-empty `couplings: []`) hits
# `validate_and_process_row` exactly once at EOF with an empty name, which is
# a silent no-op, not a hard error — so the whole gate goes dark with zero
# enforcement and zero output. Default-deny fix, two parts: (a) count parsed
# rows; if the map declares a `couplings:` key but zero rows parsed, hard
# error naming the map (below, after the loop). (b) once inside the
# `couplings:` block, any non-blank, non-comment line that is not a
# recognized row/key line is itself a parse failure — hard error naming the
# offending line — instead of being silently skipped by the loop's `elif`
# chain (this is what let a stray/garbled line pass through undetected).
NAME_RE='^[[:space:]]*-[[:space:]]+name:[[:space:]]*(.+)$'
SRC_RE='^[[:space:]]*srcGlobs:[[:space:]]*\[(.*)\][[:space:]]*$'
DOCS_RE='^[[:space:]]*docPaths:[[:space:]]*\[(.*)\][[:space:]]*$'
DIRECTIONS_RE='^[[:space:]]*directions:[[:space:]]*\[(.*)\][[:space:]]*$'
EXEMPT_RE='^[[:space:]]*exemptGlobs:[[:space:]]*\[(.*)\][[:space:]]*$'
# Loose "is this line attempting one of the recognized keys" patterns — used
# only by the unrecognized-line guard below. Distinct from SRC_RE/DOCS_RE
# (strict value-extraction, unchanged): a `srcGlobs:` line with no inline
# bracket (e.g. a YAML block-sequence continuation) is still a *recognized*
# key line — it just fails validate_and_process_row's existing empty-value
# check per-row, which already names the row. Only a line that isn't even an
# attempt at one of the recognized row keys is "unrecognized" here.
SRC_KEY_RE='^[[:space:]]*srcGlobs:'
DOCS_KEY_RE='^[[:space:]]*docPaths:'
DIRECTIONS_KEY_RE='^[[:space:]]*directions:'
EXEMPT_KEY_RE='^[[:space:]]*exemptGlobs:'
RATIONALE_KEY_RE='^[[:space:]]*rationale:'
COMMENT_OR_BLANK_RE='^[[:space:]]*(#.*)?$'
COUPLINGS_KEY_RE='^couplings:'

# strip_bracket_list <bracket-contents> — strips both quote styles the
# declared flat schema allows ("a" or 'a'), leaving the comma-separated list.
strip_bracket_list() {
  printf '%s' "$1" | tr -d "\"'"
}

# validate_and_process_row <name> <src_csv> <docs_csv> — fail-closed gate in
# front of process_row: a named row with an empty srcGlobs or docPaths is a
# coupling-map parse failure, not "no coupling here" — hard-error rather
# than silently disable the row's protection.
validate_and_process_row() {
  local name="$1" src_csv="$2" docs_csv="$3" directions_csv="$4" exempt_globs_csv="$5" directions_declared="$6" exempt_declared="$7"
  if [ -n "$name" ]; then
    if ! [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
      echo "ERROR: coupling map row name '${name}' in ${COUPLING_MAP} is not a safe slug." >&2
      echo "Row names may contain only letters, numbers, dot, underscore, and hyphen because they are used in scoped declaration matching." >&2
      exit 2
    fi
    if [ -z "$src_csv" ] || [ -z "$docs_csv" ]; then
      echo "ERROR: coupling map row '${name}' in ${COUPLING_MAP} has an empty or unparseable srcGlobs/docPaths." >&2
      echo "Only the inline array form is supported: srcGlobs: [\"a\", \"b\"] / docPaths: [\"a\", \"b\"] (single or double quotes, any indentation)." >&2
      echo "Block-sequence or bareword lists are not supported — fix the row rather than relying on silent skip." >&2
      exit 2
    fi
    if [[ "$src_csv" == *"{"* || "$src_csv" == *"}"* || "$docs_csv" == *"{"* || "$docs_csv" == *"}"* || "$exempt_globs_csv" == *"{"* || "$exempt_globs_csv" == *"}"* ]]; then
      echo "ERROR: coupling map row '${name}' in ${COUPLING_MAP} uses brace glob syntax; brace globs with comma expansion are unsupported." >&2
      echo "List each glob as a separate inline-array entry instead." >&2
      exit 2
    fi
    if [ "$directions_declared" -eq 1 ] && [ -z "$directions_csv" ]; then
      echo "ERROR: coupling map row '${name}' in ${COUPLING_MAP} has an empty or unparseable directions list." >&2
      exit 2
    fi
    if [ "$exempt_declared" -eq 1 ] && [ -z "$exempt_globs_csv" ]; then
      echo "ERROR: coupling map row '${name}' in ${COUPLING_MAP} has an empty or unparseable exemptGlobs list." >&2
      exit 2
    fi
    if [ "$SCHEMA_VERSION" = "1.0" ] && { [ "$directions_declared" -eq 1 ] || [ "$exempt_declared" -eq 1 ]; }; then
      echo "ERROR: schema_version 1.0 cannot use directions/exemptGlobs (row '${name}'); it supports only legacy source-to-doc rows." >&2
      echo "Set schema_version to \"1.1\" before using directions or exemptGlobs." >&2
      exit 2
    fi
    directions_csv="${directions_csv:-source-to-doc}"
    local direction
    while IFS= read -r direction; do
      direction="$(printf '%s' "$direction" | sed 's/^ *//; s/ *$//')"
      case "$direction" in
        source-to-doc|doc-to-source) ;;
        *)
          echo "ERROR: coupling map row '${name}' in ${COUPLING_MAP} declares unsupported direction '${direction}'." >&2
          echo "Supported directions: source-to-doc, doc-to-source." >&2
          exit 2
          ;;
      esac
    done <<< "$(printf '%s' "$directions_csv" | tr ',' '\n')"
  fi
  process_row "$name" "$src_csv" "$docs_csv" "${directions_csv:-source-to-doc}" "$exempt_globs_csv"
}

current_name=""
current_src=""
current_docs=""
current_directions=""
current_exempt_globs=""
current_directions_declared=0
current_exempt_declared=0
current_src_declared=0
current_docs_declared=0
current_rationale_declared=0
seen_row_names="|"
in_couplings_block=0
couplings_key_seen=0
parsed_row_count=0

while IFS= read -r line || [ -n "$line" ]; do
  if [ "$in_couplings_block" -eq 0 ]; then
    if [[ "$line" =~ $COUPLINGS_KEY_RE ]]; then
      couplings_key_seen=1
      in_couplings_block=1
    fi
    continue
  fi

  if [[ "$line" =~ $NAME_RE ]]; then
    next_name="${BASH_REMATCH[1]}"
    validate_and_process_row "$current_name" "$current_src" "$current_docs" "$current_directions" "$current_exempt_globs" "$current_directions_declared" "$current_exempt_declared"
    current_name="$(printf '%s' "$next_name" | sed -E 's/[[:space:]]+$//')"
    case "$seen_row_names" in
      *"|${current_name}|"*)
        echo "ERROR: coupling map ${COUPLING_MAP} declares duplicate row name '${current_name}'." >&2
        exit 2
        ;;
    esac
    seen_row_names="${seen_row_names}${current_name}|"
    current_src=""
    current_docs=""
    current_directions=""
    current_exempt_globs=""
    current_directions_declared=0
    current_exempt_declared=0
    current_src_declared=0
    current_docs_declared=0
    current_rationale_declared=0
    parsed_row_count=$((parsed_row_count + 1))
  elif [[ "$line" =~ $SRC_RE ]]; then
    if [ "$current_src_declared" -eq 1 ]; then
      echo "ERROR: coupling map row '${current_name:-<none>}' in ${COUPLING_MAP} declares duplicate srcGlobs key." >&2
      exit 2
    fi
    current_src="$(strip_bracket_list "${BASH_REMATCH[1]}")"
    current_src_declared=1
  elif [[ "$line" =~ $DOCS_RE ]]; then
    if [ "$current_docs_declared" -eq 1 ]; then
      echo "ERROR: coupling map row '${current_name:-<none>}' in ${COUPLING_MAP} declares duplicate docPaths key." >&2
      exit 2
    fi
    current_docs="$(strip_bracket_list "${BASH_REMATCH[1]}")"
    current_docs_declared=1
  elif [[ "$line" =~ $DIRECTIONS_RE ]]; then
    if [ "$current_directions_declared" -eq 1 ]; then
      echo "ERROR: coupling map row '${current_name:-<none>}' in ${COUPLING_MAP} declares duplicate directions key." >&2
      exit 2
    fi
    current_directions="$(strip_bracket_list "${BASH_REMATCH[1]}")"
    current_directions_declared=1
  elif [[ "$line" =~ $EXEMPT_RE ]]; then
    if [ "$current_exempt_declared" -eq 1 ]; then
      echo "ERROR: coupling map row '${current_name:-<none>}' in ${COUPLING_MAP} declares duplicate exemptGlobs key." >&2
      exit 2
    fi
    current_exempt_globs="$(strip_bracket_list "${BASH_REMATCH[1]}")"
    current_exempt_declared=1
  elif [[ "$line" =~ $DIRECTIONS_KEY_RE ]]; then
    if [ "$current_directions_declared" -eq 1 ]; then
      echo "ERROR: coupling map row '${current_name:-<none>}' in ${COUPLING_MAP} declares duplicate directions key." >&2
      exit 2
    fi
    current_directions_declared=1
  elif [[ "$line" =~ $EXEMPT_KEY_RE ]]; then
    if [ "$current_exempt_declared" -eq 1 ]; then
      echo "ERROR: coupling map row '${current_name:-<none>}' in ${COUPLING_MAP} declares duplicate exemptGlobs key." >&2
      exit 2
    fi
    current_exempt_declared=1
  elif [[ "$line" =~ $RATIONALE_KEY_RE ]]; then
    if [ "$current_rationale_declared" -eq 1 ]; then
      echo "ERROR: coupling map row '${current_name:-<none>}' in ${COUPLING_MAP} declares duplicate rationale key." >&2
      exit 2
    fi
    current_rationale_declared=1
  elif [[ "$line" =~ $SRC_KEY_RE ]]; then
    if [ "$current_src_declared" -eq 1 ]; then
      echo "ERROR: coupling map row '${current_name:-<none>}' in ${COUPLING_MAP} declares duplicate srcGlobs key." >&2
      exit 2
    fi
    current_src_declared=1
  elif [[ "$line" =~ $DOCS_KEY_RE ]]; then
    if [ "$current_docs_declared" -eq 1 ]; then
      echo "ERROR: coupling map row '${current_name:-<none>}' in ${COUPLING_MAP} declares duplicate docPaths key." >&2
      exit 2
    fi
    current_docs_declared=1
    : # recognized key line whose value isn't the strict inline-array form
      # (e.g. block-sequence) — validate_and_process_row's per-row empty
      # check (P1-3, cycle 2) catches it below, naming the row.
  elif [[ "$line" =~ $COMMENT_OR_BLANK_RE ]]; then
    : # comment or blank line inside the block — allowed
  else
    echo "ERROR: coupling map ${COUPLING_MAP} has an unrecognized line inside the 'couplings:' block (current row: '${current_name:-<none>}'): ${line}" >&2
    echo "Recognized line types inside 'couplings:' are '- name:', 'srcGlobs:', 'docPaths:', 'directions:', 'exemptGlobs:', 'rationale:', comments, and blank lines." >&2
    exit 2
  fi
done < "$COUPLING_MAP"
validate_and_process_row "$current_name" "$current_src" "$current_docs" "$current_directions" "$current_exempt_globs" "$current_directions_declared" "$current_exempt_declared"

# codex-gate round-3 P1: the zero-rows guard below only fires once a
# recognized 'couplings:' key was already seen — a map whose key is missing
# entirely or misspelled (e.g. 'coupling:' singular) never enters the block
# at all, so couplings_key_seen stays 0 and the whole gate goes dark with
# zero enforcement. Require exactly one recognized 'couplings:' key first.
if [ "$couplings_key_seen" -ne 1 ]; then
  echo "ERROR: coupling map ${COUPLING_MAP} does not declare a recognized top-level 'couplings:' key." >&2
  echo "Expected exactly one line matching '^couplings:' (no leading whitespace) to introduce the coupling rows — check for a missing or misspelled key (e.g. 'coupling:' instead of 'couplings:')." >&2
  exit 2
fi

if [ "$parsed_row_count" -eq 0 ]; then
  echo "ERROR: coupling map ${COUPLING_MAP} declares a 'couplings:' key but zero rows parsed." >&2
  echo "Only the block-sequence form is supported: 'couplings:' followed by '- name: <slug>' rows. Flow-style ('couplings: [...]') and empty ('couplings: []') are not supported — fix the map rather than relying on silent skip." >&2
  exit 2
fi

emit_map_records() {
  local map="$1"
  awk '
    function clean(value) {
      sub(/^[^[]*\[/, "", value)
      sub(/\][[:space:]]*$/, "", value)
      gsub(/["\047]/, "", value)
      return value
    }
    function flush() {
      if (name != "") {
        if (directions == "") directions = "source-to-doc"
        print name "\034" src "\034" docs "\034" directions "\034" exemptions
      }
    }
    /^couplings:/ { in_rows=1; next }
    in_rows && /^[[:space:]]*-[[:space:]]+name:/ {
      flush()
      line=$0
      sub(/^[[:space:]]*-[[:space:]]+name:[[:space:]]*/, "", line)
      sub(/[[:space:]]+$/, "", line)
      name=line; src=""; docs=""; directions=""; exemptions=""
      next
    }
    in_rows && /^[[:space:]]*srcGlobs:/ { src=clean($0); next }
    in_rows && /^[[:space:]]*docPaths:/ { docs=clean($0); next }
    in_rows && /^[[:space:]]*directions:/ { directions=clean($0); next }
    in_rows && /^[[:space:]]*exemptGlobs:/ { exemptions=clean($0); next }
    END { flush() }
  ' "$map"
}

csv_contains_exact() {
  local csv="$1" wanted="$2" item
  while IFS= read -r item; do
    item="$(printf '%s' "$item" | sed 's/^ *//; s/ *$//')"
    [ "$item" = "$wanted" ] && return 0
  done <<< "$(printf '%s' "$csv" | tr ',' '\n')"
  return 1
}

removed_csv_items() {
  local base_csv="$1" head_csv="$2" item removed=""
  while IFS= read -r item; do
    item="$(printf '%s' "$item" | sed 's/^ *//; s/ *$//')"
    [ -n "$item" ] || continue
    if ! csv_contains_exact "$head_csv" "$item"; then
      if [ -n "$removed" ]; then removed="${removed},${item}"; else removed="$item"; fi
    fi
  done <<< "$(printf '%s' "$base_csv" | tr ',' '\n')"
  printf '%s' "$removed"
}

extract_contract_migration_reason() {
  local row="$1" line prefix remainder
  prefix="contract-migration: ${row}"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "$prefix — "*) remainder="${line#"$prefix — "}" ;;
      *) continue ;;
    esac
    remainder="$(printf '%s' "$remainder" | sed 's/^[[:space:]]*//')"
    printf '%s' "$remainder"
    return 0
  done <<< "$DECLARATION"
  printf ''
}

compare_base_contract() {
  local base_map="$1" base_records head_records validation_changed validation_output validation_rc=0
  local base_name base_src base_docs base_directions base_exemptions
  local head_record head_src head_docs head_directions head_exemptions
  local removed_src removed_docs removed_directions added_exemptions details reason
  validation_changed="$(mktemp)"
  validation_output="$(mktemp)"
  : > "$validation_changed"
  bash "${BASH_SOURCE[0]}" \
    "--changed=$validation_changed" \
    "--declaration=" \
    "--coupling-map=$base_map" > "$validation_output" 2>&1 || validation_rc=$?
  if [ "$validation_rc" -ne 0 ]; then
    echo "ERROR: base coupling map is invalid: $base_map" >&2
    cat "$validation_output" >&2
    rm -f "$validation_changed" "$validation_output"
    exit 2
  fi
  rm -f "$validation_changed" "$validation_output"

  base_records="$(mktemp)"
  head_records="$(mktemp)"
  emit_map_records "$base_map" > "$base_records"
  emit_map_records "$COUPLING_MAP" > "$head_records"

  while IFS=$'\034' read -r base_name base_src base_docs base_directions base_exemptions; do
    [ -n "$base_name" ] || continue
    head_record="$(awk -F '\034' -v wanted="$base_name" '$1 == wanted { print; exit }' "$head_records")"
    details=""
    if [ -z "$head_record" ]; then
      details="row removed"
    else
      IFS=$'\034' read -r _ head_src head_docs head_directions head_exemptions <<< "$head_record"
      removed_src="$(removed_csv_items "$base_src" "$head_src")"
      removed_docs="$(removed_csv_items "$base_docs" "$head_docs")"
      removed_directions="$(removed_csv_items "$base_directions" "$head_directions")"
      added_exemptions="$(removed_csv_items "$head_exemptions" "$base_exemptions")"
      [ -z "$removed_src" ] || details="${details} srcGlobs removed: ${removed_src};"
      [ -z "$removed_docs" ] || details="${details} docPaths removed: ${removed_docs};"
      [ -z "$removed_directions" ] || details="${details} directions removed: ${removed_directions};"
      [ -z "$added_exemptions" ] || details="${details} exemptGlobs added: ${added_exemptions};"
    fi

    if [ -n "$details" ]; then
      reason="$(extract_contract_migration_reason "$base_name")"
      if [ -n "$reason" ] && ! is_weak_skip_rationale "skipped — ${reason}"; then
        emit_pass "contract-migration: ${base_name} accepted (${reason})"
      else
        emit_blocker "contract-migration: ${base_name} — coupling contract weakened (${details}); add 'contract-migration: ${base_name} — <reason>' with at least 12 characters"
      fi
    fi
  done < "$base_records"
  rm -f "$base_records" "$head_records"
}

if [ -n "$BASE_COUPLING_MAP" ]; then
  compare_base_contract "$BASE_COUPLING_MAP"
fi

if [ "$BLOCKERS" -gt 0 ]; then
  exit 1
fi

exit 0
