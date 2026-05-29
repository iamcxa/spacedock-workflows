#!/usr/bin/env bash
# check-cross-review-threshold.sh — Tier-A gate on cross-review verdict↔factor CONSISTENCY.
#
# WHY: the rubric-ification audit (systemic finding #2) found that the 7-factor cross-review
# verdict — the most consequential gate, repeated across ship-{shape,design,plan,execute,verify,
# review} — had NO mechanical threshold. A reviewer could record "7-factor mostly PASS, one WARN"
# and still emit verdict=PROCEED, and nothing caught it. That is the rubber-stamp / 0%-reject drift
# (the #109 failure mode). This check makes the threshold mechanical.
#
# CONTRACT: the cross-review (a SEPARATELY-DISPATCHED reviewer per INVARIANTS Principle 6 Rule C —
# executer teammate / fresh sonnet / fresh opus, never the stage author) MUST emit exactly one
# canonical summary line in the stage artifact:
#
#   cross-review: factors=<N> pass=<p> warn=<w> fail=<f> verdict=<PROCEED|PROMPT_CAPTAIN|VETO>
#
# (a leading "- " list bullet is allowed). The prose 7-factor breakdown + coaching note stay as-is;
# this line is the machine-checkable summary of them.
#
# RULE:
#   - missing line            -> FAIL  (un-gated / silent skip; fail-closed)
#   - malformed line          -> FAIL  (M2: never fail-open on a partial parse)
#   - pass+warn+fail != factors -> FAIL (catches pass-inflation used to bury WARNs)
#   - verdict in {PROMPT_CAPTAIN, VETO} -> PASS (escalation is always valid, counts not gating)
#   - verdict=PROCEED with fail>=1      -> FAIL (a FAIL factor cannot PROCEED)
#   - verdict=PROCEED with warn>=3      -> FAIL (3+ WARN factors require escalation)
#   - verdict=PROCEED, fail=0, warn<=2  -> PASS
#
# M1 LIMIT (deliberate, documented): this enforces verdict↔factor consistency mechanically. It
# CANNOT verify the summary line was authored by a separate reviewer (content provenance) — that
# remains Principle 6 Rule C dispatch discipline (Tier B). Mechanical consistency is necessary,
# not sufficient. Do NOT mistake a green check here for "a real independent review happened".
#
# Usage: check-cross-review-threshold.sh <stage-artifact.md>
# Exit:  0 = PASS, 1 = FAIL (reason printed to stdout).
# Portable: BSD/macOS bash + grep + POSIX arithmetic only (no grep -P, no GNU-isms).
set -u

ARTIFACT="${1:-}"
if [ -z "$ARTIFACT" ]; then echo "FAIL: usage: $0 <stage-artifact.md>"; exit 1; fi
if [ ! -f "$ARTIFACT" ]; then echo "FAIL: artifact not found: $ARTIFACT"; exit 1; fi

# First canonical summary line (optionally bullet-prefixed). fail-closed if absent.
LINE="$(grep -E '^[[:space:]]*-?[[:space:]]*cross-review:[[:space:]]*factors=' "$ARTIFACT" | head -1)"
if [ -z "$LINE" ]; then
  echo "FAIL: no 'cross-review: factors=… verdict=…' summary line in $ARTIFACT (un-gated / silent skip)"
  exit 1
fi

# Portable field extraction. Missing field -> empty -> caught by the numeric/verdict guards below.
field() { printf '%s\n' "$LINE" | grep -oE "$1=[0-9A-Za-z_]+" | head -1 | cut -d= -f2; }
FACTORS="$(field factors)"
PASS_N="$(field pass)"
WARN_N="$(field warn)"
FAIL_N="$(field fail)"
VERDICT="$(field verdict)"

# M2 fail-safe: every count must be present AND numeric.
for v in "$FACTORS" "$PASS_N" "$WARN_N" "$FAIL_N"; do
  if ! printf '%s' "$v" | grep -qE '^[0-9]+$'; then
    echo "FAIL: malformed summary line (count missing or non-numeric): $LINE"
    exit 1
  fi
done

# Verdict must be one of the three legal tokens.
case "$VERDICT" in
  PROCEED|PROMPT_CAPTAIN|VETO) : ;;
  *) echo "FAIL: malformed/absent verdict token (got '${VERDICT:-<none>}'): $LINE"; exit 1 ;;
esac

# Integrity: declared counts must sum to declared factor total.
SUM=$((PASS_N + WARN_N + FAIL_N))
if [ "$SUM" -ne "$FACTORS" ]; then
  echo "FAIL: counts inconsistent — pass($PASS_N)+warn($WARN_N)+fail($FAIL_N)=$SUM != factors=$FACTORS: $LINE"
  exit 1
fi

# Escalation verdicts are always valid; factor counts do not gate them.
if [ "$VERDICT" = "PROMPT_CAPTAIN" ] || [ "$VERDICT" = "VETO" ]; then
  echo "PASS: verdict=$VERDICT (escalated; factor counts not gating)"
  exit 0
fi

# verdict == PROCEED: must be clean enough to skip escalation.
if [ "$FAIL_N" -ge 1 ]; then
  echo "FAIL: verdict=PROCEED with fail=$FAIL_N — a FAIL factor cannot PROCEED (escalate to PROMPT_CAPTAIN/VETO): $LINE"
  exit 1
fi
if [ "$WARN_N" -ge 3 ]; then
  echo "FAIL: verdict=PROCEED with warn=$WARN_N (>=3) — 3+ WARN factors require escalation, not PROCEED: $LINE"
  exit 1
fi

echo "PASS: verdict=PROCEED consistent (fail=$FAIL_N, warn=$WARN_N < 3, sum=$SUM=factors)"
exit 0
