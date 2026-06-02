#!/usr/bin/env bash
# issues-to-contract.sh — Linear reference adapter transform (pitch 118.2).
#
# Deterministic, tracker-agnostic transform: a NORMALIZED issue set → 118.1's
# cut-project contract YAML. The only Linear-specific step (MCP fetch) lives in
# ship-project/SKILL.md and runs in the captain main session (MCP cannot run in a
# subagent); that step normalizes the MCP response into the JSON shape this script
# consumes. Keeping the filter/dedup/DAG vocabulary HERE (not in agent prose) makes
# the OCD-2 rules testable and immune to prose drift — the discipline every other
# ship-flow lib follows (validate-cut-project, dag-waves, instantiate-cut-project).
#
# Normalized input JSON (tracker-agnostic):
#   {
#     "external_project": "linear:team/Project",
#     "title": "...",
#     "issues": [
#       { "external_id": "SC-810", "title": "...",
#         "state_type": "backlog|unstarted|started|completed|canceled",
#         "state": "Backlog",                 # human state name (fallback filter)
#         "labels": ["schema"], "body": "...",
#         "blocked_by": ["SC-809"],           # structured dependency edges
#         "blocks": ["SC-820"],               # inverse structured edges
#         "parent": "SC-800",                 # sub-issue parent (OCD-2: informational only in v1)
#         "affects_ui": false, "domain": "schema",
#         "contract_decision_required": false }
#     ]
#   }
#
# OCD-2 mapping vocabulary (v1):
#   - state filter   — drop state_type completed|canceled OR state name Done/Canceled/Cancelled/Duplicate
#   - label:Bug      — excluded from intake (debug fast-path), reported to stderr
#   - dedup          — DROP issues whose external_id already exists under --workflow-dir
#                      (idempotent re-intake; the 118.1 validator is the fail-closed safety net)
#   - DAG edges      — blocked_by + blocks(inverse) → depends_on, FILTERED to surviving
#                      children only (closure-safe; dangling edges dropped + reported)
#   - parent (sub-issue) — NOT a depends_on edge in v1. Hierarchy ≠ execution order;
#                      mapping it risks wrong ordering. Recorded as a future axis;
#                      blocked_by/blocks is the canonical dependency signal. (Flagged
#                      OCD-2 captain decision — see ship-project/SKILL.md.)
#
# Usage: issues-to-contract.sh <issues.json> [--workflow-dir <dir>] [--out <contract.yaml>]
# Exit:  0 success · 1 usage / no intakeable issues after filter · 2 file not found
#        · 3 malformed JSON
set -uo pipefail

ISSUES="" ; WF="" ; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --workflow-dir) WF="${2:-}"; shift ;;
    --out)          OUT="${2:-}"; shift ;;
    -*)             echo "issues-to-contract: unknown flag: $1" >&2; exit 1 ;;
    *) if [ -z "$ISSUES" ]; then ISSUES="$1"; else echo "issues-to-contract: unexpected arg: $1" >&2; exit 1; fi ;;
  esac
  shift
done

[ -n "$ISSUES" ] || { echo "usage: issues-to-contract.sh <issues.json> [--workflow-dir <dir>] [--out <contract.yaml>]" >&2; exit 1; }
[ -f "$ISSUES" ] || { echo "issues-to-contract: issues file not found: $ISSUES" >&2; exit 2; }

CONTRACT="$(python3 - "$ISSUES" "$WF" <<'PY'
import sys, os, glob, json

path = sys.argv[1]
wf   = sys.argv[2] if len(sys.argv) > 2 else ""

try:
    data = json.load(open(path, encoding="utf-8"))
except json.JSONDecodeError as e:
    sys.stderr.write("issues-to-contract: malformed JSON: %s\n" % e); sys.exit(3)
except OSError as e:
    sys.stderr.write("issues-to-contract: cannot read %s: %s\n" % (path, e)); sys.exit(2)

external_project = data.get("external_project")
title = data.get("title") or external_project
issues = data.get("issues") or []
if not external_project:
    sys.stderr.write("issues-to-contract: missing external_project in input\n"); sys.exit(1)

# Existing external_ids bound by entities under the workflow dir (dedup source).
existing = set()
if wf and os.path.isdir(wf):
    for f in glob.glob(os.path.join(wf, "*", "index.md")) + glob.glob(os.path.join(wf, "*.md")):
        try:
            lines = open(f, encoding="utf-8").read().splitlines()
        except OSError:
            continue
        if not lines or lines[0].strip() != "---":
            continue
        for ln in lines[1:]:
            if ln.strip() == "---":
                break
            if ln.startswith("external_id:"):
                v = ln.split(":", 1)[1].strip().strip('"').strip("'")
                if v:
                    existing.add(v)

DROP_STATE_TYPES = {"completed", "canceled", "cancelled"}
DROP_STATE_NAMES = {"done", "canceled", "cancelled", "duplicate"}

bugs, dups, dropped, kept = [], [], [], []
for it in issues:
    eid = it.get("external_id")
    if not eid:
        continue
    st_type = (it.get("state_type") or "").lower()
    st_name = (it.get("state") or "").lower()
    labels  = [str(l).lower() for l in (it.get("labels") or [])]
    if st_type in DROP_STATE_TYPES or st_name in DROP_STATE_NAMES:
        dropped.append(eid); continue
    if "bug" in labels:
        bugs.append(eid); continue
    if eid in existing:
        dups.append(eid); continue
    kept.append(it)

kept_ids = {it["external_id"] for it in kept}

# blocks-inverse: A blocks B  ⟹  B depends_on A. Build over ALL issues so an edge
# survives even when only one side is populated.
blocks_inverse = {}
for it in issues:
    a = it.get("external_id")
    for b in (it.get("blocks") or []):
        blocks_inverse.setdefault(b, set()).add(a)

dropped_edges = []
def deps_for(it):
    eid = it["external_id"]
    raw = set(it.get("blocked_by") or []) | blocks_inverse.get(eid, set())
    raw.discard(eid)
    out = []
    for d in sorted(raw):
        if d in kept_ids:
            out.append(d)
        else:
            dropped_edges.append((eid, d))
    return out

if not kept:
    sys.stderr.write("issues-to-contract: no intakeable issues after filter "
                     "(dropped %d done/canceled, %d bug, %d dup)\n"
                     % (len(dropped), len(bugs), len(dups)))
    sys.exit(1)

def q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'

out = []
out.append("external_project: %s" % q(external_project))
out.append("title: %s" % q(title))
out.append("children:")
for it in kept:
    eid = it["external_id"]
    out.append("  - external_id: %s" % q(eid))
    out.append("    title: %s" % q(it.get("title") or eid))
    deps = deps_for(it)
    if deps:
        out.append("    depends_on: [%s]" % ", ".join(q(d) for d in deps))
    else:
        out.append("    depends_on: []")
    if it.get("affects_ui") is True:
        out.append("    affects_ui: true")
    dom = it.get("domain")
    if dom:
        out.append("    domain: %s" % str(dom))
    if it.get("contract_decision_required") is True:
        out.append("    contract_decision_required: true")
    out.append("    body_source: |")
    body = it.get("body") or ""
    if body.strip():
        for bl in body.splitlines():
            out.append("      " + bl)
    else:
        out.append("      (no tracker description)")

# Reports (stderr — never pollutes the contract on stdout).
if bugs:
    sys.stderr.write("issues-to-contract: %d bug-labeled issue(s) excluded from intake "
                     "(route via /fix-bug): %s\n" % (len(bugs), ", ".join(bugs)))
if dups:
    sys.stderr.write("issues-to-contract: %d already-intaken issue(s) deduped: %s\n"
                     % (len(dups), ", ".join(dups)))
if dropped:
    sys.stderr.write("issues-to-contract: %d non-intakeable (done/canceled): %s\n"
                     % (len(dropped), ", ".join(dropped)))
if dropped_edges:
    sys.stderr.write("issues-to-contract: %d depends_on edge(s) dropped "
                     "(ref outside intake set): %s\n"
                     % (len(dropped_edges), ", ".join("%s->%s" % (a, b) for a, b in dropped_edges)))

sys.stdout.write("\n".join(out) + "\n")
sys.exit(0)
PY
)"
PYEXIT=$?
[ "$PYEXIT" -ne 0 ] && exit "$PYEXIT"

if [ -n "$OUT" ]; then
  printf '%s\n' "$CONTRACT" > "$OUT"
else
  printf '%s\n' "$CONTRACT"
fi
exit 0
