#!/usr/bin/env bash
# Tests for check-cross-review-threshold.sh
#
# These cases ARE the rubric's teeth. The NEGATIVE cases (must FAIL) come first and are the
# point of the gate: they enumerate the cross-review outputs that MUST be rejected — chiefly the
# rubber-stamp shape (verdict=PROCEED while >=3 WARN or >=1 FAIL factors stand) that the original
# prose cross-review could not catch (rubric-ification audit, systemic finding #2).
#
# Convention mirrors lib/__tests__/test-check-harvest-exempt.sh (check()/expect-exit style).
# Portable: BSD/macOS bash + grep only (no grep -P).
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../check-cross-review-threshold.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0
FAILED=0

# expect_exit <want 0|1> <label> <artifact-content>
expect_exit() {
  want="$1"; label="$2"; content="$3"
  f="$TMP/artifact.md"
  printf '%s\n' "$content" > "$f"
  if bash "$SCRIPT" "$f" >/dev/null 2>&1; then got=0; else got=1; fi
  if [ "$got" -eq "$want" ]; then
    printf 'ok   %s\n' "$label"; PASS=$((PASS + 1))
  else
    printf 'FAIL %s (want exit %s, got %s)\n' "$label" "$want" "$got"; FAILED=$((FAILED + 1))
  fi
}

# ── NEGATIVE eval cases — MUST FAIL (exit 1). The should-NOT-pass set. ──
expect_exit 1 "warn>=3 + PROCEED is the rubber-stamp"      'cross-review: factors=7 pass=4 warn=3 fail=0 verdict=PROCEED'
expect_exit 1 "fail>=1 + PROCEED forbidden"                'cross-review: factors=7 pass=6 warn=0 fail=1 verdict=PROCEED'
expect_exit 1 "no summary line = un-gated silent skip"     'reviewer cross-review looked fine, verdict PROCEED'
expect_exit 1 "pass-inflation breaks sum (7+3+0=10!=7)"    'cross-review: factors=7 pass=7 warn=3 fail=0 verdict=PROCEED'
expect_exit 1 "malformed: warn/fail missing (no fail-open)" 'cross-review: factors=7 pass=4 verdict=PROCEED'
expect_exit 1 "malformed: unknown verdict token"           'cross-review: factors=7 pass=7 warn=0 fail=0 verdict=LGTM'

# ── POSITIVE eval cases — MUST PASS (exit 0). The should-pass anchors. ──
expect_exit 0 "clean PROCEED (warn<=2, fail=0)"            'cross-review: factors=7 pass=5 warn=2 fail=0 verdict=PROCEED'
expect_exit 0 "escalated PROMPT_CAPTAIN despite warns"     'cross-review: factors=7 pass=2 warn=4 fail=1 verdict=PROMPT_CAPTAIN'
expect_exit 0 "escalated VETO (8-factor stage variant)"    'cross-review: factors=8 pass=5 warn=3 fail=0 verdict=VETO'
expect_exit 0 "list-bullet-prefixed summary is found"      '- cross-review: factors=7 pass=7 warn=0 fail=0 verdict=PROCEED'

echo "---"
echo "pass=$PASS fail=$FAILED"
[ "$FAILED" -eq 0 ]
