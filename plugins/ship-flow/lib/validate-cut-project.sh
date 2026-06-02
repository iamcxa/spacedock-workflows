#!/usr/bin/env bash
# validate-cut-project.sh — structural validation of a cut-project contract
# (pitch 118.1). Mirrors lib/validate-handoff-schema.sh conventions.
#
# The cut-project contract (design-owned OCD-1) is the deterministic input CORE
# accepts: an epic-binding project ref + a list of children, each binding a
# tracker issue (external_id) with declared depends_on edges. Canonical form:
#
#   external_project: "linear:team/Project"
#   title: "..."
#   appetite: medium-batch            # optional
#   children:
#     - external_id: "SC-810"
#       depends_on: []                # inline list of other children's external_ids
#       affects_ui: false             # optional
#       domain: schema                # optional
#       body_source: |                # block scalar — becomes the shaped-child body
#         <issue body, indented; never parsed as structure>
#     - external_id: "SC-811"
#       depends_on: ["SC-810"]
#
# Validates (structural only — no inference):
#   - external_project present
#   - children non-empty; every child has external_id
#   - depends_on closure (every ref is a child in the set) + acyclic — reuses dag-waves
#   - dedup safety: no external_id already bound by an existing entity (needs --workflow-dir)
#
# Usage:   bash validate-cut-project.sh <contract.yaml> [--workflow-dir <dir>]
# Exit:    0 valid · 1 invalid (structural) · 2 usage error
set -u

CONTRACT="" ; WF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --workflow-dir) WF="${2:-}"; shift ;;
    -*) echo "validate-cut-project: unknown flag: $1" >&2; exit 2 ;;
    *) [ -z "$CONTRACT" ] && CONTRACT="$1" || { echo "validate-cut-project: unexpected arg: $1" >&2; exit 2; } ;;
  esac
  shift
done
[ -n "$CONTRACT" ] || { echo "usage: validate-cut-project.sh <contract.yaml> [--workflow-dir <dir>]" >&2; exit 2; }
[ -f "$CONTRACT" ] || { echo "validate-cut-project: contract not found: $CONTRACT" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAG_WAVES="${SCRIPT_DIR}/dag-waves.sh"

# --- Parse + structural checks (Python 3 stdlib; no PyYAML) ---
# On success: prints TSV graph lines "<external_id>\tplan\t<deps_csv>" to stdout, exit 0.
# On structural error: prints "validate-cut-project: <reason>" to stderr, exit 1.
GRAPH="$(python3 - "$CONTRACT" <<'PY'
import sys
path = sys.argv[1]
lines = open(path, encoding="utf-8").read().splitlines()

def indent_of(s): return len(s) - len(s.lstrip(' '))
def unquote(s): return s.strip().strip('"').strip("'").strip()

external_project = None
children = []           # [{eid, deps[]}]
in_children = False
item_indent = None
field_indent = None
cur = None

for raw in lines:
    line = raw.rstrip("\n")
    if not in_children:
        if line.startswith("external_project:"):
            external_project = unquote(line.split(":", 1)[1])
        elif indent_of(line) == 0 and line.lstrip().startswith("children:"):
            rest = line.split(":", 1)[1].strip()
            in_children = True            # `children: []` → in_children, zero items
        continue
    stripped = line.strip()
    if stripped == "":
        continue
    ind = indent_of(line)
    # new child item: `- ...` at the (first-seen) item indent
    if stripped.startswith("- "):
        if item_indent is None:
            item_indent = ind
        if ind == item_indent:
            cur = {"eid": None, "deps": []}
            children.append(cur)
            field_indent = ind + 2
            after = stripped[2:].strip()
            if after.startswith("external_id:"):
                cur["eid"] = unquote(after.split(":", 1)[1])
            continue
        # dash deeper than item indent → block-scalar body content → ignore
        continue
    # sibling fields only at the child-field indent (block-scalar body sits deeper → ignored)
    if cur is not None and field_indent is not None and ind == field_indent:
        key = line.lstrip()
        if key.startswith("external_id:"):
            cur["eid"] = unquote(key.split(":", 1)[1])
        elif key.startswith("depends_on:") or key.startswith("depends-on:"):
            v = key.split(":", 1)[1].strip()
            if v.startswith("["):
                inner = v[1:v.rfind("]")] if "]" in v else v[1:]
                cur["deps"] = [unquote(x) for x in inner.split(",") if x.strip()]
            # scalar/none/empty → no deps (block-list deps unsupported in contract: use inline)
    # deeper indent (body content) or other keys → ignored

errs = []
if not external_project:
    errs.append("missing external_project")
if not children:
    errs.append("children is empty")
for idx, c in enumerate(children):
    if not c["eid"]:
        errs.append("child #%d missing external_id" % (idx + 1))
if errs:
    sys.stderr.write("validate-cut-project: " + "; ".join(errs) + "\n")
    sys.exit(1)

for c in children:
    print("%s\tplan\t%s" % (c["eid"], ",".join(c["deps"])))
PY
)"
PYEXIT=$?
[ "$PYEXIT" -ne 0 ] && exit 1

# --- Dedup: no external_id may already be bound by an existing entity ---
if [ -n "$WF" ] && [ -d "$WF" ]; then
  EXISTING="$(for f in "$WF"/*/index.md "$WF"/*.md; do
    [ -f "$f" ] || continue
    awk '/^---[[:space:]]*$/{fm++; if(fm==2)exit; next} fm==1 && /^external_id:/{v=$0; sub(/^external_id:[[:space:]]*/,"",v); gsub(/["'\'' ]/,"",v); print v}' "$f"
  done)"
  while IFS=$'\t' read -r eid _ _; do
    [ -z "$eid" ] && continue
    if printf '%s\n' "$EXISTING" | grep -qxF "$eid"; then
      echo "validate-cut-project: external_id '$eid' already bound by an existing entity (dedup)" >&2
      exit 1
    fi
  done <<< "$GRAPH"
fi

# --- Cycle + closure: reuse dag-waves (single source of truth for the DAG algorithm) ---
if ! printf '%s' "$GRAPH" | bash "$DAG_WAVES" --layers --stdin >/dev/null 2>/tmp/.vcp-dagerr.$$; then
  echo "validate-cut-project: invalid DAG — $(cat /tmp/.vcp-dagerr.$$ 2>/dev/null)" >&2
  rm -f /tmp/.vcp-dagerr.$$
  exit 1
fi
rm -f /tmp/.vcp-dagerr.$$
exit 0
