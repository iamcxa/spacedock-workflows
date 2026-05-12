#!/usr/bin/env bash
# review-scope.sh — portable diff scope detection for ship-verify
# Usage: source <(./review-scope.sh [base-branch])
# Outputs eval-able shell assignments to stdout.
# After source, these vars are set:
#   STACK            = ruby|node|python|go|rust|unknown (space-separated if multi)
#   TEST_FW          = jest|vitest|rspec|pytest|go-test|unknown
#   DIFF_INS         = lines inserted
#   DIFF_DEL         = lines deleted
#   DIFF_LINES       = DIFF_INS + DIFF_DEL
#   SCOPE_AUTH       = true|false
#   SCOPE_BACKEND    = true|false
#   SCOPE_FRONTEND   = true|false
#   SCOPE_API        = true|false
#   SCOPE_MIGRATIONS = true|false
#
# Snapshot 2026-05-12. After /spacedock:overhaul lives at
# plugins/ship-flow/lib/review-scope.sh

set -u

BASE="${1:-origin/main}"

# Guard: ensure we can resolve the base ref. If not, default to HEAD~1 (single
# commit) so script still works on a fresh branch with no remote.
if ! git rev-parse --verify -q "$BASE" >/dev/null 2>&1; then
  BASE="HEAD~1"
fi

# Stack detection — multi-stack repos can have several
STACK=""
[ -f Gemfile ] && STACK="${STACK}ruby "
[ -f package.json ] && STACK="${STACK}node "
{ [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; } && STACK="${STACK}python "
[ -f go.mod ] && STACK="${STACK}go "
[ -f Cargo.toml ] && STACK="${STACK}rust "
STACK="${STACK% }"
[ -z "$STACK" ] && STACK="unknown"

# Test framework detection — pick the most specific signal
TEST_FW="unknown"
if [ -f jest.config.js ] || [ -f jest.config.ts ] || [ -f jest.config.mjs ]; then
  TEST_FW="jest"
elif [ -f vitest.config.ts ] || [ -f vitest.config.js ] || [ -f vitest.config.mts ]; then
  TEST_FW="vitest"
elif [ -f .rspec ] || [ -f spec/spec_helper.rb ]; then
  TEST_FW="rspec"
elif [ -f pytest.ini ] || [ -f conftest.py ] || grep -q "pytest" pyproject.toml 2>/dev/null; then
  TEST_FW="pytest"
elif [ -f go.mod ]; then
  TEST_FW="go-test"
fi

# Diff line counts (from --stat summary line)
STAT_LINE=$(git diff "$BASE"...HEAD --stat 2>/dev/null | tail -1)
DIFF_INS=$(echo "$STAT_LINE" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
DIFF_DEL=$(echo "$STAT_LINE" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
DIFF_INS="${DIFF_INS:-0}"
DIFF_DEL="${DIFF_DEL:-0}"
DIFF_LINES=$((DIFF_INS + DIFF_DEL))

# Changed files list (used for all scope checks)
CHANGED_FILES=$(git diff "$BASE"...HEAD --name-only 2>/dev/null)

# Scope flags — pattern-matching against changed file paths
match_any() {
  # match_any "pattern1|pattern2|..." → echoes true/false
  local pat="$1"
  if echo "$CHANGED_FILES" | grep -qE "$pat"; then
    echo "true"
  else
    echo "false"
  fi
}

# AUTH: paths suggesting authentication / authorization / session handling
SCOPE_AUTH=$(match_any '(^|/)(auth|users|sessions?|login|password|tokens?|oauth|jwt|permissions?|roles?)(/|\.|$)')

# BACKEND: server-side languages + typical backend dirs
SCOPE_BACKEND=$(match_any '\.(rb|py|go|java|kt|rs|cs|php|ex|exs)$|(^|/)(api|service|services|controller|controllers|model|models|handler|handlers|backend|server)(/|$)|\.ts$.*(^|/)(api|service|server)(/|$)')

# FRONTEND: frontend file extensions + typical frontend dirs
SCOPE_FRONTEND=$(match_any '\.(tsx|jsx|vue|svelte|css|scss|sass|less|html|astro)$|(^|/)(components?|pages?|views?|frontend|client|web|app/(routes|components|ui))(/|$)')

# API: explicit API surface (route definitions, endpoint controllers)
SCOPE_API=$(match_any '(^|/)(routes?|endpoints?|api|controllers?)(/|$)|openapi\.(ya?ml|json)$|schema\.graphql$')

# MIGRATIONS: schema-mutating files
SCOPE_MIGRATIONS=$(match_any '(^|/)(migrations?|migrate|db/(migrate|migrations)|alembic|versions)(/|$)|\.sql$')

# Output as eval-able shell assignments
cat <<EOF
STACK="$STACK"
TEST_FW="$TEST_FW"
DIFF_INS=$DIFF_INS
DIFF_DEL=$DIFF_DEL
DIFF_LINES=$DIFF_LINES
SCOPE_AUTH=$SCOPE_AUTH
SCOPE_BACKEND=$SCOPE_BACKEND
SCOPE_FRONTEND=$SCOPE_FRONTEND
SCOPE_API=$SCOPE_API
SCOPE_MIGRATIONS=$SCOPE_MIGRATIONS
EOF
