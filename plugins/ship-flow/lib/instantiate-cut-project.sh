#!/usr/bin/env bash
# instantiate-cut-project.sh — atomic instantiate of a validated cut-project
# contract into an epic + dotted shaped-children + a printed wave/parallel plan
# (pitch 118.1, Option B). The deterministic, zero-LLM core of /ship-project.
#
# Pipeline:
#   1. validate    reuse validate-cut-project.sh — closure / cycle / dup-external_id
#                  all BLOCK here (exit 3). Nothing is written when validation fails.
#   2. parse       yq full extraction (validator already guaranteed structure).
#   3. allocate    _archive-aware epic id = max top-level id across ACTIVE ∪ _archive,
#                  +1. A naive active-only scan would re-use an archived id.
#   4. map         external_id → dotted <epic>.N id; translate each child's
#                  depends_on (external_ids) into dotted depends-on edges.
#   5. stamp       Gap-1: child status = a LIVE entry stage — `design` when a
#                  design-trigger flag is set (affects_ui / domain / contract_decision_required),
#                  else `plan`. NEVER the dead `sharp` status (the FO `--next`
#                  dispatch skips `sharp`, so a sharp child is undispatchable).
#                  Gap-2: the parent is stamped `status: epic` (dispatch skips it)
#                  with `pattern: epic` / `entity_type: epic`. It is written WITHOUT
#                  an `appetite` frontmatter key — a project-intake epic is a
#                  tracker-intaken container, not a Shape Up pitch. `pattern: pitch`
#                  would trip check-invariants.sh C1 (pre_mortem) and a frontmatter
#                  `appetite:` would trip C2 (pol-probe). New-file creation is exempt
#                  from C14 (advance-stage-only) because pure additions have no
#                  parent frontmatter status.
#   6. commit      ONE atomic explicit-pathspec commit (never `git add -A`).
#   7. plan        print the wave/parallel plan (dag-waves --layers; per-wave
#                  max-parallel = min(wave size, workflow concurrency cap)).
#
# Usage: instantiate-cut-project.sh <contract.yaml> --workflow-dir <dir>
#                                   [--dry-run] [--epic-id <NNN>]
# Exit:  0 success · 1 usage · 2 contract not found · 3 validation failed (BLOCK)
#        · 4 target epic id already in use (refuse overwrite) · 7 helper missing
#        · 8 commit failed
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="${SCRIPT_DIR}/validate-cut-project.sh"
DAG_WAVES="${SCRIPT_DIR}/dag-waves.sh"

CONTRACT="" ; WF="" ; DRY_RUN=0 ; EPIC_ID_OVERRIDE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --workflow-dir) WF="${2:-}"; shift ;;
    --dry-run)      DRY_RUN=1 ;;
    --epic-id)      EPIC_ID_OVERRIDE="${2:-}"; shift ;;
    -*)             echo "instantiate-cut-project: unknown flag: $1" >&2; exit 1 ;;
    *) if [ -z "$CONTRACT" ]; then CONTRACT="$1"; else echo "instantiate-cut-project: unexpected arg: $1" >&2; exit 1; fi ;;
  esac
  shift
done

[ -n "$CONTRACT" ] || { echo "usage: instantiate-cut-project.sh <contract.yaml> --workflow-dir <dir> [--dry-run] [--epic-id <NNN>]" >&2; exit 1; }
[ -n "$WF" ]       || { echo "instantiate-cut-project: --workflow-dir is required" >&2; exit 1; }
[ -f "$CONTRACT" ] || { echo "instantiate-cut-project: contract not found: $CONTRACT" >&2; exit 2; }
[ -d "$WF" ]       || { echo "instantiate-cut-project: workflow dir not found: $WF" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || { echo "instantiate-cut-project: yq required" >&2; exit 7; }
[ -f "$VALIDATOR" ] || { echo "instantiate-cut-project: validate-cut-project.sh missing at $VALIDATOR" >&2; exit 7; }
[ -f "$DAG_WAVES" ] || { echo "instantiate-cut-project: dag-waves.sh missing at $DAG_WAVES" >&2; exit 7; }

# ---- 1. Validate (the gatekeeper). Its stdout is empty on success; route any
#         output to stderr so it never pollutes our wave-plan stdout. ----
if ! bash "$VALIDATOR" "$CONTRACT" --workflow-dir "$WF" 1>&2; then
  echo "instantiate-cut-project: contract failed validation — refusing to instantiate" >&2
  exit 3
fi

# ---- 2. Parse ----
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-60
}

# Escape a value for a YAML double-quoted scalar: `\` and `"` escaped, and control
# whitespace collapsed to spaces so a quote/newline in a tracker title (e.g. a Linear
# project name) cannot produce malformed frontmatter or inject extra lines.
yaml_dq() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"; s="${s//$'\r'/ }"; s="${s//$'\t'/ }"
  printf '%s' "$s"
}

# Sanitize a value for a mermaid `["..."]` node label (lossy, display-only): a raw
# double-quote or square bracket breaks the node-label syntax.
mermaid_label() {
  local s="$1"
  s="${s//\"/\'}"; s="${s//\[/(}"; s="${s//\]/)}"
  s="${s//$'\n'/ }"; s="${s//$'\r'/ }"; s="${s//$'\t'/ }"
  printf '%s' "$s"
}

EXTERNAL_PROJECT="$(yq '.external_project' "$CONTRACT" | head -1)"
PROJECT_TITLE="$(yq '.title // ""' "$CONTRACT" | head -1)"
{ [ -n "$PROJECT_TITLE" ] && [ "$PROJECT_TITLE" != "null" ]; } || PROJECT_TITLE="$EXTERNAL_PROJECT"
CHILD_N="$(yq '.children | length' "$CONTRACT" | head -1 | tr -dc '0-9')"
[ -n "$CHILD_N" ] || CHILD_N=0

# ---- 3. Allocate epic id (_archive-aware) ----
# v1 assumes a single intake session: max(active ∪ _archive)+1 with a pre-write collision
# refuse (id_in_use), but no lock — concurrent intake could race the same id. Intake is a
# deliberate captain action; the spacedock-next-id-archive-awareness rabbit-hole tracks
# switching to spacedock's atomic --next-id if concurrent intake becomes real (codex PR #190 P1-5).
allocate_epic_id() {
  local maxid=0 p name n
  for p in "$WF"/* "$WF"/_archive/*; do
    [ -e "$p" ] || continue
    name="$(basename "$p")"
    n="$(printf '%s' "$name" | grep -oE '^[0-9]+' || true)"
    [ -n "$n" ] || continue
    n=$((10#$n))                          # base-10 — zero-padded ids (086, 094) are NOT octal
    [ "$n" -gt "$maxid" ] && maxid="$n"
  done
  printf '%03d' "$((maxid + 1))"
}

# id-collision check: is <id> (top-level or dotted) already claimed by an
# ACTIVE or ARCHIVED entity? Guards against --epic-id clobbering an existing id.
id_in_use() {
  local target="$1" p name idpart
  for p in "$WF"/* "$WF"/_archive/*; do
    [ -e "$p" ] || continue
    name="$(basename "$p")"
    idpart="${name%%-*}"   # leading token before first '-' (118-foo→118, 121.1-x→121.1)
    idpart="${idpart%.md}" # flat-file suffix
    [ "$idpart" = "$target" ] && return 0
  done
  return 1
}

if [ -n "$EPIC_ID_OVERRIDE" ]; then
  EPIC_ID="$EPIC_ID_OVERRIDE"
else
  EPIC_ID="$(allocate_epic_id)"
fi
EPIC_SLUG="$(slugify "$PROJECT_TITLE")"
[ -n "$EPIC_SLUG" ] || EPIC_SLUG="epic-${EPIC_ID}"
EPIC_DIR="${WF}/${EPIC_ID}-${EPIC_SLUG}"

# ---- 4 + 5. Build per-child fields (dotted ids, slugs, status stamping) ----
EIDS=() ; DOTTED=() ; CSLUGS=() ; CTITLES=() ; CSTATUS=() ; CAFFECTS=() ; CDOMAIN=() ; CCDR=()
i=0
while [ "$i" -lt "$CHILD_N" ]; do
  eid="$(yq ".children[$i].external_id" "$CONTRACT" | head -1)"
  ctitle="$(yq ".children[$i].title // \"\"" "$CONTRACT" | head -1)"
  { [ -n "$ctitle" ] && [ "$ctitle" != "null" ]; } || ctitle="$eid"
  domain="$(yq ".children[$i].domain // \"\"" "$CONTRACT" | head -1)"
  [ "$domain" = "null" ] && domain=""
  affects="$(yq ".children[$i].affects_ui // false" "$CONTRACT" | head -1)"
  cdr="$(yq ".children[$i].contract_decision_required // false" "$CONTRACT" | head -1)"
  dotted="${EPIC_ID}.$((i + 1))"
  cslug="$(slugify "$ctitle")"; [ -n "$cslug" ] || cslug="$(slugify "$eid")"
  # Gap-1: LIVE entry stage. design-trigger → design, else plan. NEVER sharp.
  status="plan"
  if [ "$affects" = "true" ] || [ "$cdr" = "true" ] || { [ -n "$domain" ] && [ "$domain" != "false" ]; }; then
    status="design"
  fi
  EIDS+=("$eid"); DOTTED+=("$dotted"); CSLUGS+=("$cslug"); CTITLES+=("$ctitle")
  CSTATUS+=("$status"); CAFFECTS+=("$affects"); CDOMAIN+=("$domain"); CCDR+=("$cdr")
  i=$((i + 1))
done

# external_id → dotted lookup (linear scan; child counts are small — no assoc array
# so the helper stays portable to pre-4.0 bash, mirroring dag-waves discipline).
dotted_for_eid() {
  local t="$1" j
  for j in "${!EIDS[@]}"; do
    [ "${EIDS[$j]}" = "$t" ] && { printf '%s' "${DOTTED[$j]}"; return 0; }
  done
  return 1
}

# echoes a child's dotted deps, space-joined (empty when none)
child_dotted_deps() {
  local idx="$1" d dot out=""
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    dot="$(dotted_for_eid "$d")" || { echo "instantiate-cut-project: internal — dep '$d' has no child mapping (validator should have caught closure)" >&2; return 1; }
    out="${out:+$out }$dot"
  done < <(yq "(.children[$idx].depends_on // .children[$idx].\"depends-on\" // []) | .[]" "$CONTRACT" 2>/dev/null)
  printf '%s' "$out"
}

# inline YAML list form from space-separated ids: [] | ["a"] | ["a", "b"]
fmt_depends_inline() {
  local first=1 out="[" d
  for d in "$@"; do
    if [ "$first" = 1 ]; then first=0; else out="$out, "; fi
    out="$out\"$d\""
  done
  printf '%s]' "$out"
}

# ---- Wave/parallel plan (reuse dag-waves --layers; status irrelevant to layering) ----
build_tsv() {
  local idx deps
  idx=0
  while [ "$idx" -lt "$CHILD_N" ]; do
    deps="$(child_dotted_deps "$idx" | tr ' ' ',')" || return 1
    printf '%s\t%s\t%s\n' "${DOTTED[$idx]}" "${CSTATUS[$idx]}" "$deps"
    idx=$((idx + 1))
  done
}
TSV="$(build_tsv)" || { echo "instantiate-cut-project: failed to build dependency graph" >&2; exit 3; }

CONCURRENCY="$(grep -m1 -E '^[[:space:]]*concurrency:' "${WF}/README.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
[ -n "$CONCURRENCY" ] || CONCURRENCY=2

render_wave_plan() {
  local wnum=0 line wsize maxp
  echo "Wave plan (concurrency cap ${CONCURRENCY}):"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    wnum=$((wnum + 1))
    wsize=$(printf '%s\n' "$line" | wc -w | tr -d ' ')
    maxp="$wsize"; [ "$maxp" -gt "$CONCURRENCY" ] && maxp="$CONCURRENCY"
    printf '  wave %d: %s   (max-parallel %d)\n' "$wnum" "$line" "$maxp"
  done < <(printf '%s' "$TSV" | bash "$DAG_WAVES" --layers --stdin)
}

render_mermaid() {
  echo '```mermaid'
  echo 'graph LR'
  local idx dep deps
  idx=0
  while [ "$idx" -lt "$CHILD_N" ]; do
    printf '  n%s["%s"]\n' "${DOTTED[$idx]//./_}" "$(mermaid_label "${DOTTED[$idx]} ${CTITLES[$idx]}")"
    idx=$((idx + 1))
  done
  idx=0
  while [ "$idx" -lt "$CHILD_N" ]; do
    deps="$(child_dotted_deps "$idx")" || return 1
    for dep in $deps; do
      printf '  n%s --> n%s\n' "${dep//./_}" "${DOTTED[$idx]//./_}"
    done
    idx=$((idx + 1))
  done
  echo '```'
}

print_children_lines() {
  local idx
  idx=0
  while [ "$idx" -lt "$CHILD_N" ]; do
    printf '  %s %-22s status:%-7s external_id:%s\n' \
      "${DOTTED[$idx]}" "${CSLUGS[$idx]}" "${CSTATUS[$idx]}" "${EIDS[$idx]}"
    idx=$((idx + 1))
  done
}

print_plan() {
  echo
  render_wave_plan
  echo
  echo "Next: run \`/ship-flow:ship-epic ${EPIC_ID}\` in a clean session to dispatch the children wave-by-wave."
}

# ---- Refuse to clobber an existing entity id (before any write) ----
if id_in_use "$EPIC_ID"; then
  echo "instantiate-cut-project: epic id '$EPIC_ID' already in use by an existing entity — refusing to overwrite" >&2
  exit 4
fi

# ---- Dry-run: print the full plan, write nothing ----
if [ "$DRY_RUN" = "1" ]; then
  echo "[dry-run] would instantiate epic ${EPIC_ID} (${CHILD_N} children) from ${EXTERNAL_PROJECT}; no files written."
  print_children_lines
  print_plan
  exit 0
fi

# ---- 6. Write the entity set, then commit in ONE explicit-pathspec commit ----
# The commit is the atomic unit. Track every dir we create so a failed `git add`/commit
# (missing identity, pre-commit hook, index lock, concurrent op) rolls the partial writes
# back, leaving the worktree clean — never a half-written epic/children set.
CREATED_DIRS=()
rollback_writes() {
  git reset -q -- "${WRITTEN_FILES[@]}" >/dev/null 2>&1 || true
  local d
  for d in "${CREATED_DIRS[@]}"; do rm -rf "$d"; done
}
mkdir -p "$EPIC_DIR"; CREATED_DIRS+=("$EPIC_DIR")
{
  echo "---"
  echo "id: \"${EPIC_ID}\""
  echo "title: \"$(yaml_dq "${PROJECT_TITLE}")\""
  echo "entity_type: epic"
  echo "pattern: epic"
  echo "external_project: \"$(yaml_dq "${EXTERNAL_PROJECT}")\""
  echo "layout: folder"
  echo "children:"
  for j in "${!DOTTED[@]}"; do
    echo "  - ${DOTTED[$j]}-${CSLUGS[$j]}"
  done
  echo "status: epic"
  echo "stage_outputs: {}"
  echo "---"
  echo
  echo "<!-- section:dependency-graph -->"
  echo "## Dependency Graph"
  echo
  render_mermaid
  echo "<!-- /section:dependency-graph -->"
} > "${EPIC_DIR}/index.md"
WRITTEN_FILES=("${EPIC_DIR}/index.md")

i=0
while [ "$i" -lt "$CHILD_N" ]; do
  cdir="${WF}/${DOTTED[$i]}-${CSLUGS[$i]}"
  mkdir -p "$cdir"; CREATED_DIRS+=("$cdir")
  # Resolve deps with an explicit rc check — `$(child_dotted_deps ...)` as a bare
  # argument would swallow a failed lookup and emit partial/empty deps (silent
  # mis-ordering). Fail closed instead. (Belt-and-suspenders: build_tsv already
  # fail-hards earlier, and the validator now catches block-list closure.)
  _cdeps="$(child_dotted_deps "$i")" || { echo "instantiate-cut-project: dependency resolution failed for ${DOTTED[$i]} (validator should have caught this)" >&2; exit 3; }
  # shellcheck disable=SC2086  # intentional word-split of space-joined dotted deps
  deps_inline="$(fmt_depends_inline $_cdeps)"
  {
    echo "---"
    echo "id: \"${DOTTED[$i]}\""
    echo "title: \"$(yaml_dq "${CTITLES[$i]}")\""
    echo "pattern: shaped-child"
    echo "parent_pitch: \"${EPIC_ID}\""
    echo "external_id: \"$(yaml_dq "${EIDS[$i]}")\""
    echo "depends-on: ${deps_inline}"
    echo "affects_ui: ${CAFFECTS[$i]}"
    [ -n "${CDOMAIN[$i]}" ] && echo "domain: ${CDOMAIN[$i]}"
    [ "${CCDR[$i]}" = "true" ] && echo "contract_decision_required: true"
    echo "layout: folder"
    echo "status: ${CSTATUS[$i]}"
    echo "stage_outputs: {}"
    echo "---"
    echo
    # Issue body as plain intro-zone content (no ship-flow section tags → the
    # check_section_tag_coverage grandfather rule skips it; later design/plan
    # stages append their own tagged sections after this intro).
    # Defang any section-marker line a tracker body might carry (e.g. a Linear
    # description containing `<!-- section:x -->`) — left live it would make the
    # entity "tagged" and trip the 5a walker (orphan / unclosed). Escaping the
    # opener keeps it human-readable while removing the false section boundary.
    yq ".children[$i].body_source // \"\"" "$CONTRACT" | sed -E 's/^<!-- (\/?section:)/\&lt;!-- \1/'
  } > "${cdir}/index.md"
  WRITTEN_FILES+=("${cdir}/index.md")
  i=$((i + 1))
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "instantiate-cut-project: warning — not a git repo; files written but not committed" >&2
  print_plan
  exit 0
fi

# ONE commit, explicit pathspec (never `git add -A` — a parallel session's staged
# changes must not be captured). See MEMORY parallel-session-git. Roll back partial
# writes on any add/commit failure so the commit stays the atomic unit.
if ! git add -- "${WRITTEN_FILES[@]}"; then
  rollback_writes
  echo "instantiate-cut-project: git add failed — rolled back partial entity writes" >&2
  exit 8
fi
COMMIT_MSG="instantiate(${EPIC_ID}): ${CHILD_N} children from cut-project ${EXTERNAL_PROJECT}"
if ! git commit -q -m "$COMMIT_MSG" -- "${WRITTEN_FILES[@]}"; then
  rollback_writes
  echo "instantiate-cut-project: git commit failed — rolled back partial entity writes" >&2
  exit 8
fi

echo "Instantiated epic ${EPIC_ID} (${CHILD_N} children) from ${EXTERNAL_PROJECT}."
print_children_lines
print_plan
exit 0
