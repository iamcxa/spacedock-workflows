#!/usr/bin/env bash
# review-merge.sh — merge specialist findings with fingerprint dedup,
# multi-specialist confirmation boost, confidence gates, and PR Quality Score.
#
# Input: stdin — newline-delimited JSON findings from specialist subagents.
# Each line is one finding (object) with required fields:
#   severity, confidence, path, category, summary, specialist
# Optional fields: line, fix, fingerprint, evidence, test_stub
#
# Output: stdout — merged findings as JSONL + final summary JSON line.
# Last stdout line is always a SUMMARY object:
#   {"_summary": true, "quality_score": N, "critical": N, "informational": N,
#    "confirmed_multi": N, "suppressed": N}
#
# Snapshot 2026-05-12. Extracted into ship-flow plugin as lib/review-merge.sh

set -eu

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required for review-merge.sh; install jq" >&2
  exit 2
fi

# Read all input lines into a JSON array of objects.
# Drop blank lines and "NO FINDINGS" sentinel from specialists with nothing to say.
INPUT=$(grep -vE '^\s*$|^NO FINDINGS$' || true)

if [ -z "$INPUT" ]; then
  # No findings at all — emit empty summary
  echo '{"_summary":true,"quality_score":10,"critical":0,"informational":0,"confirmed_multi":0,"suppressed":0}'
  exit 0
fi

# Parse JSONL into array. Compute fingerprint where missing.
ALL=$(echo "$INPUT" | jq -c -s '
  map(
    . + {
      fingerprint: (
        if .fingerprint then .fingerprint
        elif .line then "\(.path):\(.line):\(.category)"
        else "\(.path):\(.category)"
        end
      )
    }
  )
')

# Group by fingerprint. For each group:
#   - keep finding with highest confidence
#   - if multiple distinct specialists, set MULTI-SPECIALIST CONFIRMED + boost +1 (cap 10)
MERGED=$(echo "$ALL" | jq -c '
  group_by(.fingerprint)
  | map(
      (max_by(.confidence)) as $top
      | ([.[] | .specialist] | unique) as $specs
      | $top + (
          if ($specs | length) > 1 then
            {
              confidence: ([.confidence + 1, 10] | min),
              multi_specialist_confirmed: true,
              confirming_specialists: $specs
            }
          else {} end
        )
    )
')

# Apply confidence gates
#   7+ : kept in main output
#   5-6 : kept but flagged with caveat
#   3-4 : moved to appendix (suppress from main; emit with appendix: true)
#   1-2 : fully suppressed (drop)
GATED=$(echo "$MERGED" | jq -c '
  map(
    if .confidence >= 7 then .
    elif .confidence >= 5 then . + {caveat: "Medium confidence — verify this is actually an issue"}
    elif .confidence >= 3 then . + {appendix: true}
    else empty
    end
  )
')

# Count stats
CRITICAL_N=$(echo "$GATED" | jq '[.[] | select(.severity == "CRITICAL" and (.appendix // false | not))] | length')
INFO_N=$(echo "$GATED" | jq '[.[] | select(.severity != "CRITICAL" and (.appendix // false | not))] | length')
CONFIRMED_N=$(echo "$GATED" | jq '[.[] | select(.multi_specialist_confirmed // false)] | length')

# Compute suppressed count (1-2 confidence dropped + 3-4 appendix-moved)
SUPPRESSED_N=$(echo "$MERGED" | jq "[.[] | select(.confidence < 7)] | length")

# PR Quality Score = max(0, 10 - critical*2 - informational*0.5), cap 10
QS_RAW=$(echo "10 - $CRITICAL_N * 2 - $INFO_N * 0.5" | bc -l)
QUALITY_SCORE=$(echo "$QS_RAW" | awk '{ if ($1 < 0) print 0; else if ($1 > 10) print 10; else printf "%.1f", $1 }')

# Output merged findings, sorted: CRITICAL first, then by descending confidence
echo "$GATED" | jq -c '
  sort_by(
    (if .severity == "CRITICAL" then 0 else 1 end),
    (- .confidence)
  )
  | .[]
'

# Emit final summary line
jq -nc --argjson qs "$QUALITY_SCORE" \
       --argjson c "$CRITICAL_N" \
       --argjson i "$INFO_N" \
       --argjson cm "$CONFIRMED_N" \
       --argjson s "$SUPPRESSED_N" \
       '{_summary:true, quality_score:$qs, critical:$c, informational:$i, confirmed_multi:$cm, suppressed:$s}'
