#!/usr/bin/env bash
# check-no-dangling.sh — dangling-reference grep gate for the yangon ship-flow repo.
#
# PASS (exit 0): no true-dangling references found in plugins/ship-flow/.
# FAIL (exit 1): one or more violations printed as  file:line:content.
#
# EXCLUDED directories (historical / adopter-only, do-not-touch):
#   - plugins/ship-flow/_archive/
#   - plugins/ship-flow/_debriefs-evidence/
#   - plugins/ship-flow/_plans/
#   - plugins/ship-flow/lib/__tests__/integration/
#
# EXCLUDED line patterns (legitimate grep-assertion tests that contain the string
# as a pattern, not as an actual path/reference):
#   - Lines whose only /Users/kent occurrence is inside a `grep ...` invocation
#     (i.e. the line contains "grep" and does not assign or expand the path).
#
# Usage:
#   bash scripts/check-no-dangling.sh            # normal run
#   bash scripts/check-no-dangling.sh --self-test # inject a violation into a
#                                                  # scratch temp file, assert
#                                                  # exit 1, then clean up.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
SCAN_ROOT="${REPO_ROOT}/plugins/ship-flow"

# ---------------------------------------------------------------------------
# Exclusion helper: build a grep --exclude-dir list
# We pass exclusions as --exclude-dir arguments to grep.
# ---------------------------------------------------------------------------
EXCLUDE_DIRS=(
  "_archive"
  "_debriefs-evidence"
  "_plans"
  "integration"
)

build_exclude_args() {
  local args=()
  for d in "${EXCLUDE_DIRS[@]}"; do
    args+=(--exclude-dir="$d")
  done
  echo "${args[@]}"
}

EXCLUDE_ARGS_STR="$(build_exclude_args)"
# Split into array (safe for paths without spaces)
read -ra EXCLUDE_ARGS <<< "$EXCLUDE_ARGS_STR"

# ---------------------------------------------------------------------------
# Gate patterns
# Each entry: LABEL|GREP_PATTERN
# grep is invoked with -P (Perl-compatible regex) for negative lookahead support.
# ---------------------------------------------------------------------------
declare -A PATTERNS
declare -a PATTERN_ORDER

add_pattern() {
  local label="$1"
  local pattern="$2"
  PATTERNS["$label"]="$pattern"
  PATTERN_ORDER+=("$label")
}

# 1. Dead skill: spacedock:overhaul (any extension / variant)
add_pattern "spacedock:overhaul" 'spacedock:overhaul'

# 2. Dead skill namespace: spacedock:workflow-adopt / spacedock:workflow-sync
#    (spacebridge: variants are LEGITIMATE — only spacedock: is dead)
add_pattern "spacedock:workflow-adopt" 'spacedock:workflow-adopt'
add_pattern "spacedock:workflow-sync"  'spacedock:workflow-sync'

# 3. Stale GitHub org reference
add_pattern "spacedock-dev" 'spacedock-dev'

# 4. Source monorepo name (the monorepo this was extracted from)
add_pattern "spacedock-ui" 'spacedock-ui'

# 5. Absolute author paths — flag /Users/kent when it is NOT inside a grep
#    pattern assertion (i.e. the line does not also contain "grep").
#    We achieve this via a two-step approach: grep finds candidates, then
#    we filter out lines that are grep-assertion lines.
add_pattern "/Users/kent" '/Users/kent'

# 6. Dogfood-SOT claim phrasing — specific removed assertions:
#    "docs/ship-flow/README.md is the dogfood … SOT" and
#    "THIS project" capitalized dogfood-SOT marker.
add_pattern "dogfood-SOT-THIS-project"    'THIS project'
add_pattern "dogfood-SOT-readme-claim"    'docs/ship-flow/README\.md is the dogfood'

# ---------------------------------------------------------------------------
# Run gate
# ---------------------------------------------------------------------------
violations=0
violation_lines=()

run_pattern_check() {
  local label="$1"
  local pattern="$2"

  # Run grep; capture output (may be empty)
  local hits
  hits=$(grep -rn --include="*.sh" --include="*.md" --include="*.yaml" \
    --include="*.json" --include="*.ts" --include="*.rb" \
    "${EXCLUDE_ARGS[@]}" \
    -E "$pattern" \
    "$SCAN_ROOT" 2>/dev/null || true)

  if [[ -z "$hits" ]]; then
    return 0
  fi

  # Special post-filter: for /Users/kent — exclude lines that are grep assertions
  # (a line containing "grep" with /Users/kent as a pattern-string is legitimate)
  if [[ "$label" == "/Users/kent" ]]; then
    local filtered
    filtered=$(echo "$hits" | grep -v $'grep' || true)
    hits="$filtered"
  fi

  if [[ -z "$hits" ]]; then
    return 0
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "  VIOLATION [$label]: $line"
    violation_lines+=("$line")
    violations=$((violations + 1))
  done <<< "$hits"
}

# ---------------------------------------------------------------------------
# Mislocated-canonical-mod resolver (AC-2): flags a backtick-fenced
# `docs/ship-flow/_mods/<name>.md` reference when the adopter-local file is
# absent, the plugin-canonical twin `plugins/ship-flow/_mods/<name>.md`
# exists, and the reference's full logical unit (paragraph/list-item, not
# just the matched physical line) carries no adopter-optional qualifier.
# Both candidate paths are resolved against the given root, not SCAN_ROOT —
# the two trees straddle docs/ and plugins/. Takes an explicit root argument
# (not the global REPO_ROOT) so tests can drive it against a scratch tree.
# ---------------------------------------------------------------------------
_mislocated_mod_logical_unit() {
  local file="$1"
  local start="$2"

  awk -v start="$start" '
    {
      line = $0
      sub(/^> /, "", line)
      lines[NR] = line
    }
    END {
      s = start
      while (s > 1) {
        prev = lines[s - 1]
        if (prev ~ /^[[:space:]]*$/) break
        if (prev ~ /^[[:space:]]*[-*][[:space:]]/) break
        if (prev ~ /^[[:space:]]*[0-9]+\.[[:space:]]/) break
        if (prev ~ /^#/) break
        s--
      }
      e = start
      while (e < NR) {
        nxt = lines[e + 1]
        if (nxt ~ /^[[:space:]]*$/) break
        if (nxt ~ /^[[:space:]]*[-*][[:space:]]/) break
        if (nxt ~ /^[[:space:]]*[0-9]+\.[[:space:]]/) break
        if (nxt ~ /^#/) break
        e++
      }
      out = ""
      for (i = s; i <= e; i++) {
        out = out lines[i] " "
      }
      print out
    }
  ' "$file"
}

run_mislocated_canonical_mods() {
  local root="$1"
  local violation_count=0

  # NOTE: -E (POSIX ERE), not -P — BSD/macOS grep has no -P, and this
  # pattern needs no lookaround, so -E is the portable equivalent (the
  # backtick delimiters in the pattern itself are what give constraint (a):
  # a double-quoted JSON path never matches).
  local hits
  # shellcheck disable=SC2016  # intentional literal backtick-fenced regex, not a var/command substitution
  hits=$(grep -rnoE '`docs/ship-flow/_mods/[A-Za-z0-9_-]+\.md`' \
    --include="*.sh" --include="*.md" --include="*.yaml" \
    --include="*.json" --include="*.ts" --include="*.rb" \
    "${EXCLUDE_ARGS[@]}" --exclude-dir="__tests__" \
    "${root}/plugins/ship-flow" 2>/dev/null || true)

  if [[ -z "$hits" ]]; then
    return 0
  fi

  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    local file="${hit%%:*}"
    local rest="${hit#*:}"
    local lineno="${rest%%:*}"
    local match="${rest#*:}"

    local name="${match#*_mods/}"
    name="${name%\`}"
    name="${name%.md}"

    local relfile="${file#"${root}"/}"

    # Constraint (d): a mod file describing its own adoption path is never
    # dangling — the twin IS the file being scanned.
    if [[ "$relfile" == "plugins/ship-flow/_mods/${name}.md" ]]; then
      continue
    fi

    local adopter_path="${root}/docs/ship-flow/_mods/${name}.md"
    local plugin_path="${root}/plugins/ship-flow/_mods/${name}.md"

    # Cond 1: adopter file absent.
    [[ -f "$adopter_path" ]] && continue

    # Classify by twin presence (both paths resolved against root, not
    # SCAN_ROOT — the two trees straddle docs/ and plugins/).
    local label
    if [[ -f "$plugin_path" ]]; then
      label="mislocated-canonical-mod"        # unchanged class: adopter absent, twin present.
    else
      # Missing-everywhere: adopter absent AND twin absent. Guard (F3): only
      # fire when the adopter tree exists — a plugins-only extraction ships
      # neither file and must stay green (preserves #71 clone-safety).
      [[ ! -d "${root}/docs/ship-flow/_mods" ]] && continue
      label="missing-everywhere-canonical-mod"
    fi

    # Cond 3: the full logical unit (not just the matched physical line)
    # carries no adopter-optional qualifier.
    local unit
    unit="$(_mislocated_mod_logical_unit "$file" "$lineno")"
    if printf '%s' "$unit" | grep -qE \
      'when present|if a workflow override exists|if the repo has|otherwise the plugin copy|adopter override|override'; then
      continue
    fi

    local content
    content="$(sed -n "${lineno}p" "$file")"
    echo "  VIOLATION [${label}]: ${file}:${lineno}:${content}"
    violation_count=$((violation_count + 1))
  done <<< "$hits"

  if [[ $violation_count -gt 0 ]]; then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Self-test mode: inject a violation, assert gate exits 1, clean up.
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--self-test" ]]; then
  echo "=== check-no-dangling.sh self-test mode ==="
  # Use a unique temp directory (not /tmp directly, to avoid scanning other tmp files)
  tmpdir="$(mktemp -d /tmp/check-no-dangling-selftest-XXXXXX)"
  trap 'rm -rf "$tmpdir"' EXIT
  tmpfile="${tmpdir}/injected-violation.md"
  echo "This line references spacedock:overhaul which is dead." > "$tmpfile"

  # Scan only the isolated temp dir
  hits=$(grep -rn --include="*.md" -E 'spacedock:overhaul' "$tmpdir" 2>/dev/null || true)
  if [[ -n "$hits" ]]; then
    echo "  Self-test CAUGHT violation (expected):"
    echo "    $hits"
    echo "SELF-TEST PASS: gate correctly detects injected violation (would exit 1 in normal run)."
    exit 0
  else
    echo "SELF-TEST FAIL: gate did not detect injected violation."
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Normal run
#
# Guarded so the script is safely source-able (defines functions only, does
# not auto-run or exit the sourcing shell) — needed so
# lib/__tests__/test-check-no-dangling.sh can source this file and call
# run_mislocated_canonical_mods() directly against scratch fixture trees.
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "=== check-no-dangling.sh — scanning plugins/ship-flow/ ==="
  echo "Excluded dirs: ${EXCLUDE_DIRS[*]}"
  echo ""

  for label in "${PATTERN_ORDER[@]}"; do
    run_pattern_check "$label" "${PATTERNS[$label]}"
  done

  mislocated_output=""
  mislocated_status=0
  mislocated_output="$(run_mislocated_canonical_mods "$REPO_ROOT")" || mislocated_status=$?
  if [[ -n "$mislocated_output" ]]; then
    echo "$mislocated_output"
  fi
  if [[ $mislocated_status -ne 0 ]]; then
    mislocated_count=$(printf '%s\n' "$mislocated_output" | grep -cE '^  VIOLATION \[(mislocated|missing-everywhere)-canonical-mod\]')
    violations=$((violations + mislocated_count))
  fi

  echo ""
  if [[ $violations -eq 0 ]]; then
    echo "PASS: no dangling references found (${#PATTERN_ORDER[@]} patterns checked)."
    exit 0
  else
    echo "FAIL: $violations dangling reference(s) found — see violations above."
    exit 1
  fi
fi
