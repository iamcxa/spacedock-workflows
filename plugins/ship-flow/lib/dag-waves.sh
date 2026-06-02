#!/usr/bin/env bash
# dag-waves.sh — wave-layering + ready-set computation over a child DAG for the
# ship-flow wave orchestrator (pitch 118 / Option B).
#
# Two pure modes over a set of children, each carrying a status and a list of
# `depends-on` child ids:
#   --layers   topological wave layers (the static parallel plan). Validates the
#              DAG is acyclic and depends-on closure holds.
#   --ready    children that are dispatchable NOW: status != done AND every
#              depends-on child has status == done.
#
# Input:
#   --stdin                 read TSV lines: <id>\t<status>\t<comma-sep-deps>
#   --from-workflow <dir> --epic <id>
#                           build the TSV by scanning <dir> for entities whose
#                           parent_pitch == <epic>, reading id/status/depends-on
#                           from each entity's frontmatter (folder index.md or
#                           flat <slug>.md).
#
# Output: ids only (a child references the orchestrator dispatches by id).
#   --layers : one line per wave, space-joined ids, sorted within the wave.
#   --ready  : one line, space-joined sorted ready ids (empty line if none).
#
# Exit: 0 ok · 2 cycle · 3 depends-on closure violation (unknown ref) · 4 duplicate
#       id (corpus id collision) · 1 usage. Codes 2/3/4 fail CLOSED — a structurally
#       broken epic is refused, never silently mis-ordered. Accepts both `depends-on`
#       (hyphen) and `depends_on` (underscore) keys; canonical write form is a list.
# Portable: POSIX awk only (no gawk asort / no bash assoc arrays). "done" is the
# terminal status per docs/ship-flow/README.md.
set -u

MODE="" ; SRC="" ; WF="" ; EPIC=""
while [ $# -gt 0 ]; do
  case "$1" in
    --layers) MODE="layers" ;;
    --ready)  MODE="ready" ;;
    --stdin)  SRC="stdin" ;;
    --from-workflow) SRC="workflow"; WF="${2:-}"; shift ;;
    --epic)   EPIC="${2:-}"; shift ;;
    *) echo "dag-waves: unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done
[ -n "$MODE" ] || { echo "dag-waves: need --layers or --ready" >&2; exit 1; }
[ -n "$SRC" ]  || { echo "dag-waves: need --stdin or --from-workflow" >&2; exit 1; }

# ---- Source the TSV (id \t status \t comma-deps) ----
emit_from_workflow() {
  local dir="$1" epic="$2" f
  [ -d "$dir" ] || { echo "dag-waves: no such workflow dir: $dir" >&2; exit 1; }
  for f in "$dir"/*/index.md "$dir"/*.md; do
    [ -f "$f" ] || continue
    awk -v epic="$epic" '
      BEGIN { infm=0; id=""; st=""; deps=""; parent=""; indep=0 }
      /^---[[:space:]]*$/ { infm++; if (infm==2) exit; next }
      infm!=1 { next }
      /^id:/                { v=$0; sub(/^id:[[:space:]]*/,"",v); gsub(/["'\'' ]/,"",v); id=v; next }
      /^status:/            { v=$0; sub(/^status:[[:space:]]*/,"",v); gsub(/["'\'' ]/,"",v); st=v; next }
      /^(parent_pitch|parent):/ { v=$0; sub(/^[a-z_]+:[[:space:]]*/,"",v); gsub(/["'\'' ]/,"",v); parent=v; next }
      # depends key: accept BOTH depends-on (hyphen) AND depends_on (underscore) —
      # the real entity corpus mixes them (e.g. 117.x underscore, 118.2 hyphen).
      # inline-flow: depends[-_]on: ["a","b"]
      /^depends[-_]on:[[:space:]]*\[/ { v=$0; sub(/^depends[-_]on:[[:space:]]*\[/,"",v); sub(/\].*$/,"",v); gsub(/["'\'' ]/,"",v); deps=v; next }
      # block: depends[-_]on: \n  - a \n  - b
      /^depends[-_]on:[[:space:]]*$/  { indep=1; next }
      # scalar value (not list): `none`/`[]`/`null`/`~` → no deps. Any other scalar
      # (e.g. legacy prose `depends_on: 117.1 (note)`) is unparseable — capture it raw
      # so the closure check fails CLOSED (exit 3) instead of silently treating it as
      # dependency-free. Canonical form is a list: depends-on: ["id", ...].
      /^depends[-_]on:[[:space:]]*[^[:space:]]/ {
        v=$0; sub(/^depends[-_]on:[[:space:]]*/,"",v); sub(/[[:space:]]*$/,"",v)
        if (v=="none" || v=="[]" || v=="null" || v=="~") { deps=""; next }
        gsub(/["'\'' ]/,"",v); deps=v; next
      }
      indep==1 && /^[[:space:]]*-[[:space:]]*/ { v=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",v); gsub(/["'\'' ]/,"",v); deps=(deps=="")?v:(deps","v); next }
      indep==1 { indep=0 }
      END {
        if (parent==epic && id!="") printf "%s\t%s\t%s\n", id, st, deps
      }
    ' "$f"
  done
}

if [ "$SRC" = "workflow" ]; then
  [ -n "$WF" ] && [ -n "$EPIC" ] || { echo "dag-waves: --from-workflow needs <dir> and --epic <id>" >&2; exit 1; }
  TSV="$(emit_from_workflow "$WF" "$EPIC")"
else
  TSV="$(cat)"
fi

# ---- Compute (POSIX awk) ----
printf '%s' "$TSV" | awk -v mode="$MODE" '
  function isort(arr, n,   i,j,key) {           # ascending insertion sort, 1..n
    for (i=2;i<=n;i++){ key=arr[i]; j=i-1
      while (j>=1 && arr[j]>key){ arr[j+1]=arr[j]; j-- } arr[j+1]=key }
  }
  {
    if ($1=="") next
    id=$1
    # fail closed on id collision (e.g. a corpus where a folder entity and a flat
    # entity both claim the same id) rather than silently emitting duplicates /
    # mis-ordering. Instantiate allocates unique dotted ids, so this never fires
    # on intake output — it guards running on a pre-existing messy corpus.
    if (id in EXISTS){ printf "dag-waves: duplicate id %s (id collision in the child set)\n", id > "/dev/stderr"; DUP=1; exit }
    ids[++N]=id; EXISTS[id]=1; ST[id]=$2; DEPS[id]=$3
  }
  END {
    if (DUP) exit 4
    # closure: every referenced dep must be a known child
    for (i=1;i<=N;i++){ id=ids[i]
      m=split(DEPS[id], d, ","); for (k=1;k<=m;k++){ if(d[k]=="") continue
        if (!(d[k] in EXISTS)){ printf "dag-waves: depends-on closure: %s -> unknown %s\n", id, d[k] > "/dev/stderr"; exit 3 } } }

    if (mode=="ready") {
      r=0
      for (i=1;i<=N;i++){ id=ids[i]
        if (ST[id]=="done") continue
        ok=1; m=split(DEPS[id], d, ","); for (k=1;k<=m;k++){ if(d[k]=="") continue
          if (ST[d[k]]!="done"){ ok=0; break } }
        if (ok) ready[++r]=id }
      isort(ready, r)
      line=""; for (i=1;i<=r;i++) line=(line=="")?ready[i]:(line" "ready[i])
      print line
      exit 0
    }

    # mode==layers : Kahn by layers over edge dep->id
    for (i=1;i<=N;i++) placed[ids[i]]=0
    remaining=N
    while (remaining>0) {
      lc=0
      for (i=1;i<=N;i++){ id=ids[i]; if (placed[id]) continue
        ok=1; m=split(DEPS[id], d, ","); for (k=1;k<=m;k++){ if(d[k]=="") continue
          if (!placed[d[k]]){ ok=0; break } }
        if (ok) layer[++lc]=id }
      if (lc==0){ printf "dag-waves: cycle detected among %d remaining children\n", remaining > "/dev/stderr"; exit 2 }
      isort(layer, lc)
      line=""; for (i=1;i<=lc;i++) line=(line=="")?layer[i]:(line" "layer[i])
      print line
      for (i=1;i<=lc;i++){ placed[layer[i]]=1; remaining-- }
    }
    exit 0
  }
'
