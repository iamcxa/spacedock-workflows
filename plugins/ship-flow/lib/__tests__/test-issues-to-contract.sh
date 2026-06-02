#!/usr/bin/env bash
# test-issues-to-contract.sh — Linear reference adapter transform (pitch 118.2).
#
# issues-to-contract.sh is the DETERMINISTIC, tracker-agnostic transform between a
# normalized issue set (the SKILL.md fetches + normalizes Linear MCP output into
# this shape — the only Linear-specific step, kept in the agent because MCP cannot
# run in a subagent) and 118.1's cut-project contract. It owns the OCD-2 filter +
# DAG-mapping vocabulary so that logic is tested, not buried in agent prose:
#   - state filter: drop completed / canceled (Done / Canceled / Duplicate)
#   - label:Bug → excluded from intake (debug fast-path), reported separately
#   - dedup: DROP issues whose external_id already exists (idempotent re-intake)
#   - DAG: blockedBy + blocks(inverse) → depends_on, FILTERED to surviving children
#          (closure-safe); parentId is NOT an edge in v1 (OCD-2 conservative call —
#          under-claim edges rather than risk wrong ordering)
#
# Exit: 0 all pass · 1 some failed.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
ADAPTER="${LIB_DIR}/issues-to-contract.sh"
VALIDATOR="${LIB_DIR}/validate-cut-project.sh"
INST="${LIB_DIR}/instantiate-cut-project.sh"
FAIL=0

ok()  { echo "OK $1"; }
bad() { echo "FAIL $1"; FAIL=1; }
assert_eq()    { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }
assert_grep()  { if grep -qE "$3" "$2" 2>/dev/null; then ok "$1"; else bad "$1 (pattern '$3' not in $2)"; fi; }
assert_nogrep(){ if grep -qE "$3" "$2" 2>/dev/null; then bad "$1 (unexpected '$3' in $2)"; else ok "$1"; fi; }

WORK="$(mktemp -d)"

# A fake workflow dir whose 116-bound entity already binds SC-813 (dedup target).
WF="$WORK/wf"
mkdir -p "$WF/116-bound"
printf -- '---\nid: "116"\nstatus: done\nexternal_id: "SC-813"\n---\n' > "$WF/116-bound/index.md"

write_issues() {
  cat > "$WORK/issues.json" <<'EOF'
{
  "external_project": "linear:duckbase/Carlove",
  "title": "Carlove backend",
  "issues": [
    {"external_id":"SC-800","title":"Old shipped thing","state_type":"completed","labels":[],"body":"already done","blocked_by":[]},
    {"external_id":"SC-810","title":"Schema core","state_type":"backlog","labels":["schema"],"body":"Schema + decider. Blocks everything.","blocked_by":["SC-800"],"domain":"schema"},
    {"external_id":"SC-811","title":"API layer","state_type":"unstarted","labels":[],"body":"Builds on the schema core.","blocked_by":["SC-810"],"affects_ui":true},
    {"external_id":"SC-812","title":"Login crash","state_type":"backlog","labels":["Bug"],"body":"crashes on login","blocked_by":[]},
    {"external_id":"SC-813","title":"Already intaken","state_type":"backlog","labels":[],"body":"dup","blocked_by":[]}
  ]
}
EOF
}

# ============================================================================
# Scenario A — full normalized issue set → contract (filter + dedup + DAG)
# ============================================================================
echo "--- Scenario A: normalized issues → contract ---"
write_issues
OUT="$WORK/contract.yaml"
bash "$ADAPTER" "$WORK/issues.json" --workflow-dir "$WF" --out "$OUT" 2>"$WORK/err-A.txt"
A_EXIT=$?
assert_eq   "DC-A1 valid JSON → exit 0" "$A_EXIT" "0"
assert_grep "DC-A1b external_project carried" "$OUT" '^external_project:[[:space:]]*"?linear:duckbase/Carlove'
assert_grep "DC-A1c title carried"            "$OUT" '^title:[[:space:]]*"?Carlove backend'

# DC-A2 completed issue dropped (not a child)
assert_nogrep "DC-A2 completed SC-800 not a child" "$OUT" 'external_id:[[:space:]]*"?SC-800'
# DC-A3 Bug-labeled dropped + reported as a bug (debug fast-path)
assert_nogrep "DC-A3a Bug SC-812 not a child"  "$OUT" 'external_id:[[:space:]]*"?SC-812'
assert_grep   "DC-A3b Bug SC-812 reported"     "$WORK/err-A.txt" 'SC-812'
# DC-A4 deduped issue dropped
assert_nogrep "DC-A4a deduped SC-813 not a child" "$OUT" 'external_id:[[:space:]]*"?SC-813'
assert_grep   "DC-A4b deduped SC-813 reported"    "$WORK/err-A.txt" 'SC-813'
# DC-A1d only the two intakeable issues survive (SC-810, SC-811)
NCHILD=$(grep -cE '^[[:space:]]*-[[:space:]]*external_id:' "$OUT")
assert_eq   "DC-A1d exactly 2 children survive" "$NCHILD" "2"
assert_grep "DC-A1e SC-810 is a child" "$OUT" 'external_id:[[:space:]]*"?SC-810'
assert_grep "DC-A1f SC-811 is a child" "$OUT" 'external_id:[[:space:]]*"?SC-811'

# DC-A5 dangling edge to a dropped issue is filtered (closure-safe) — SC-810 blocked_by
#       SC-800 (dropped) → SC-810 ends with NO deps; dropped edge reported.
SC810_DEPS=$(awk '/external_id:[[:space:]]*"?SC-810/{f=1} f&&/depends_on:/{print; exit}' "$OUT")
assert_eq   "DC-A5a SC-810 depends_on [] (edge to dropped SC-800 filtered)" "$(echo "$SC810_DEPS" | grep -oE '\[.*\]')" "[]"
assert_grep "DC-A5b dropped edge reported" "$WORK/err-A.txt" '(SC-800|drop.*edge|edge.*SC-810)'

# DC-A6 surviving structured dependency preserved (SC-811 depends_on SC-810)
SC811_DEPS=$(awk '/external_id:[[:space:]]*"?SC-811/{f=1} f&&/depends_on:/{print; exit}' "$OUT")
assert_eq   "DC-A6 SC-811 depends_on [\"SC-810\"]" "$(echo "$SC811_DEPS" | grep -oE 'SC-810')" "SC-810"

# DC-A7 emitted contract is structurally valid (round-trips through 118.1 validator)
if bash "$VALIDATOR" "$OUT" --workflow-dir "$WF" >/dev/null 2>&1; then ok "DC-A7 adapter output passes validate-cut-project"; else bad "DC-A7 adapter output FAILED validator"; fi

# ============================================================================
# Scenario B — end-to-end seam: adapter → instantiate produces epic + children
# ============================================================================
echo "--- Scenario B: adapter → instantiate (118.2 → 118.1 seam) ---"
REPO="$WORK/repo"; rm -rf "$REPO"; mkdir -p "$REPO/docs/ship-flow"
(
  cd "$REPO"; git init -q; git config user.email t@t; git config user.name t
  printf -- '---\nconcurrency: 2\n---\n# wf\n' > docs/ship-flow/README.md
  mkdir -p docs/ship-flow/117-x; printf -- '---\nid: "117"\nstatus: plan\n---\n' > docs/ship-flow/117-x/index.md
  git add -A; git commit -qm init
)
write_issues
bash "$ADAPTER" "$WORK/issues.json" --workflow-dir "$REPO/docs/ship-flow" --out "$WORK/c2.yaml" 2>/dev/null
( cd "$REPO" && bash "$INST" "$WORK/c2.yaml" --workflow-dir docs/ship-flow ) >"$WORK/out-B.txt" 2>"$WORK/err-B.txt"
B_EXIT=$?
assert_eq   "DC-A8a adapter→instantiate → exit 0" "$B_EXIT" "0"
assert_grep "DC-A8b epic 118 created"    "$REPO/docs/ship-flow/118-carlove-backend/index.md" '^status:[[:space:]]*epic'
assert_grep "DC-A8c child 118.1 schema (design — domain)"  "$REPO/docs/ship-flow/118.1-schema-core/index.md" '^status:[[:space:]]*design'
assert_grep "DC-A8d child 118.2 api (design — affects_ui)" "$REPO/docs/ship-flow/118.2-api-layer/index.md"   '^status:[[:space:]]*design'
assert_grep "DC-A8e child 118.2 depends-on dotted 118.1"   "$REPO/docs/ship-flow/118.2-api-layer/index.md"   '^depends-on:.*118\.1'
assert_grep "DC-A8f wave plan + ship-epic handoff"         "$WORK/out-B.txt" 'ship-epic 118'

# ============================================================================
# Scenario C — blocks (inverse) edge: A blocks B ⟹ B depends_on A
# ============================================================================
echo "--- Scenario C: blocks-inverse edge ---"
cat > "$WORK/inv.json" <<'EOF'
{
  "external_project": "linear:x/y",
  "title": "Inverse edges",
  "issues": [
    {"external_id":"A","title":"Foundation","state_type":"backlog","labels":[],"body":"base","blocks":["B"]},
    {"external_id":"B","title":"Consumer","state_type":"backlog","labels":[],"body":"uses A"}
  ]
}
EOF
bash "$ADAPTER" "$WORK/inv.json" --out "$WORK/inv.yaml" 2>/dev/null
B_DEPS=$(awk '/external_id:[[:space:]]*"?B"?[[:space:]]*$/{f=1} f&&/depends_on:/{print; exit}' "$WORK/inv.yaml")
assert_eq "DC-A10 blocks(A→B) yields B depends_on A" "$(echo "$B_DEPS" | grep -oE '"A"')" '"A"'

# ============================================================================
# Scenario D — nothing intakeable after filter → clear error, no empty contract
# ============================================================================
echo "--- Scenario D: empty after filter ---"
cat > "$WORK/empty.json" <<'EOF'
{
  "external_project": "linear:x/y",
  "title": "All done",
  "issues": [
    {"external_id":"Z1","title":"done","state_type":"completed","labels":[],"body":"x"},
    {"external_id":"Z2","title":"bug","state_type":"backlog","labels":["Bug"],"body":"y"}
  ]
}
EOF
bash "$ADAPTER" "$WORK/empty.json" --out "$WORK/empty.yaml" >/dev/null 2>&1
D_EXIT=$?
assert_eq "DC-A9 no intakeable issues → exit 1" "$D_EXIT" "1"

# ============================================================================
# Scenario E — malformed JSON → exit 3
# ============================================================================
echo "--- Scenario E: malformed JSON ---"
printf '{ this is not json' > "$WORK/bad.json"
bash "$ADAPTER" "$WORK/bad.json" --out "$WORK/bad.yaml" >/dev/null 2>&1
E_EXIT=$?
assert_eq "DC-A11 malformed JSON → exit 3" "$E_EXIT" "3"

rm -rf "$WORK"
echo
if [ "$FAIL" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; fi
exit "$FAIL"
