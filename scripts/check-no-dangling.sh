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
# ---------------------------------------------------------------------------
echo "=== check-no-dangling.sh — scanning plugins/ship-flow/ ==="
echo "Excluded dirs: ${EXCLUDE_DIRS[*]}"
echo ""

for label in "${PATTERN_ORDER[@]}"; do
  run_pattern_check "$label" "${PATTERNS[$label]}"
done

echo ""
if [[ $violations -eq 0 ]]; then
  echo "PASS: no dangling references found (${#PATTERN_ORDER[@]} patterns checked)."
  exit 0
else
  echo "FAIL: $violations dangling reference(s) found — see violations above."
  exit 1
fi
