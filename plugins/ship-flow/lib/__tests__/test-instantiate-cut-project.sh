#!/usr/bin/env bash
# test-instantiate-cut-project.sh — atomic instantiate of a cut-project contract
# into an epic + dotted shaped-children + a printed wave/parallel plan (pitch 118.1).
#
# The instantiate helper is the riskiest 118.1 piece: atomic multi-file write +
# _archive-aware id allocation + external_id->dotted depends-on mapping + Gap-1
# status stamping (LIVE entry stage, never the dead `sharp`) + Gap-2 epic-ification.
# These DCs lock each of those behaviours.
#
# Exit: 0 all pass · 1 some failed.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
INST="${LIB_DIR}/instantiate-cut-project.sh"
CHK="${LIB_DIR}/../bin/check-invariants.sh"
FAIL=0

ok()   { echo "OK $1"; }
bad()  { echo "FAIL $1"; FAIL=1; }

assert_eq()    { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }
assert_grep()  { if grep -qE "$3" "$2" 2>/dev/null; then ok "$1"; else bad "$1 (pattern '$3' not in $2)"; fi; }
assert_nogrep(){ if grep -qE "$3" "$2" 2>/dev/null; then bad "$1 (unexpected '$3' in $2)"; else ok "$1"; fi; }
assert_file()  { if [ -f "$2" ]; then ok "$1"; else bad "$1 (missing file $2)"; fi; }
assert_nofile(){ if [ -e "$2" ]; then bad "$1 (file should not exist: $2)"; else ok "$1"; fi; }

WORK="$(mktemp -d)"
REPO="$WORK/repo"
WF="docs/ship-flow"

setup_repo() {
  rm -rf "$REPO"; mkdir -p "$REPO"
  (
    cd "$REPO"
    git init -q
    git config user.email t@t; git config user.name t
    mkdir -p "$WF/_archive"
    # workflow README carrying the concurrency cap the parallel-planner reads
    printf -- '---\nconcurrency: 2\n---\n# wf\n' > "$WF/README.md"
    # active entities — max active top-level id = 118
    mkdir -p "$WF/117-existing";  printf -- '---\nid: "117"\nstatus: plan\n---\n' > "$WF/117-existing/index.md"
    mkdir -p "$WF/118-foo";       printf -- '---\nid: "118"\nstatus: done\n---\n' > "$WF/118-foo/index.md"
    # an entity that already binds SC-999 (dedup target)
    mkdir -p "$WF/116-bound";     printf -- '---\nid: "116"\nstatus: done\nexternal_id: "SC-999"\n---\n' > "$WF/116-bound/index.md"
    # ARCHIVED id 120 — HIGHER than active max. _archive-aware allocation must
    # consider it, so next epic id = 121 (a naive active-only scan picks 119).
    mkdir -p "$WF/_archive/120-archived"; printf -- '---\nid: "120"\nstatus: done\n---\n' > "$WF/_archive/120-archived/index.md"
    git add -A; git commit -qm init
  )
}

CONTRACT_PATH="$WORK/contract.yaml"   # kept OUTSIDE the repo so it never pollutes git status
write_valid_contract() {
  cat > "$CONTRACT_PATH" <<'EOF'
external_project: "linear:duckbase/Carlove"
title: "Carlove backend intake"
children:
  - external_id: "SC-810"
    title: "Schema core"
    depends_on: []
    domain: schema
    body_source: |
      Schema + decider. Blocks everything downstream.
  - external_id: "SC-811"
    title: "API layer"
    depends_on: ["SC-810"]
    affects_ui: true
    body_source: |
      Builds on the schema core.
  - external_id: "SC-812"
    title: "Release verify"
    depends_on: ["SC-810", "SC-811"]
    body_source: |
      Final release-verification slice.
  - external_id: "SC-813"
    title: "Docs polish"
    depends_on: []
    body_source: |
      Independent docs pass — parallel with the schema core.
EOF
}

# ============================================================================
# Scenario A — valid contract → atomic instantiate (the happy-path DCs)
# ============================================================================
echo "--- Scenario A: valid contract instantiate ---"
setup_repo
write_valid_contract
OUT="$WORK/out-A.txt"
( cd "$REPO" && bash "$INST" "$CONTRACT_PATH" --workflow-dir "$WF" ) >"$OUT" 2>"$WORK/err-A.txt"
A_EXIT=$?
EPIC="$REPO/$WF/121-carlove-backend-intake/index.md"
C1="$REPO/$WF/121.1-schema-core/index.md"
C2="$REPO/$WF/121.2-api-layer/index.md"
C3="$REPO/$WF/121.3-release-verify/index.md"
C4="$REPO/$WF/121.4-docs-polish/index.md"

assert_eq   "DC-1 valid contract → exit 0" "$A_EXIT" "0"

# DC-3 _archive-aware id allocation → 121 (NOT 119)
assert_file "DC-3 epic allocated id 121 (archive-aware)" "$EPIC"
assert_nofile "DC-3b naive id 119 NOT used" "$REPO/$WF/119-carlove-backend-intake"

# DC-2 epic frontmatter: epic-ified container + external_project + children + mermaid
assert_grep "DC-2a epic status: epic"          "$EPIC" '^status:[[:space:]]*epic'
assert_grep "DC-2b epic entity_type: epic"     "$EPIC" '^entity_type:[[:space:]]*epic'
assert_grep "DC-2c epic pattern: epic"         "$EPIC" '^pattern:[[:space:]]*epic'
assert_grep "DC-2d external_project carried"   "$EPIC" '^external_project:[[:space:]]*"?linear:duckbase/Carlove'
assert_grep "DC-2e children list has 121.1"    "$EPIC" '121\.1-schema-core'
assert_grep "DC-2f children list has 121.4"    "$EPIC" '121\.4-docs-polish'
assert_grep "DC-2g dag_mermaid rendered"       "$EPIC" '```mermaid'
# DC-2h epic must NOT carry appetite in frontmatter (would trip C2 pol-probe invariant)
assert_nogrep "DC-2h epic has no appetite frontmatter (C2-safe)" "$EPIC" '^appetite:'
# DC-2i epic must NOT be pattern: pitch (would trip C1 pre_mortem invariant)
assert_nogrep "DC-2i epic not pattern: pitch (C1-safe)" "$EPIC" '^pattern:[[:space:]]*pitch'

# DC-4 dotted children + shaped-child + parent_pitch + external_id
assert_file "DC-4a child 121.1 written" "$C1"
assert_file "DC-4b child 121.2 written" "$C2"
assert_file "DC-4c child 121.3 written" "$C3"
assert_file "DC-4d child 121.4 written" "$C4"
assert_grep "DC-4e child id dotted"            "$C1" '^id:[[:space:]]*"?121\.1"?'
assert_grep "DC-4f child pattern shaped-child" "$C1" '^pattern:[[:space:]]*shaped-child'
assert_grep "DC-4g child parent_pitch=121"     "$C1" '^parent_pitch:[[:space:]]*"?121"?'
assert_grep "DC-4h child external_id bound"    "$C1" '^external_id:[[:space:]]*"?SC-810'
assert_grep "DC-4i child2 external_id bound"   "$C2" '^external_id:[[:space:]]*"?SC-811'

# DC-5 Gap-1 status stamping: LIVE entry stage, NEVER the dead `sharp`
assert_grep   "DC-5a child1 design (domain set)"      "$C1" '^status:[[:space:]]*design'
assert_grep   "DC-5b child2 design (affects_ui true)" "$C2" '^status:[[:space:]]*design'
assert_grep   "DC-5c child3 plan (no trigger)"        "$C3" '^status:[[:space:]]*plan'
assert_grep   "DC-5d child4 plan (no trigger)"        "$C4" '^status:[[:space:]]*plan'
assert_nogrep "DC-5e child1 NOT sharp" "$C1" '^status:[[:space:]]*sharp'
assert_nogrep "DC-5f child3 NOT sharp" "$C3" '^status:[[:space:]]*sharp'

# DC-6 external_id → dotted-id depends-on mapping (NOT raw external_ids)
assert_grep   "DC-6a child2 depends-on dotted 121.1"  "$C2" '^depends-on:.*121\.1'
assert_grep   "DC-6b child3 depends-on dotted 121.1"  "$C3" '^depends-on:.*121\.1'
assert_grep   "DC-6c child3 depends-on dotted 121.2"  "$C3" '^depends-on:.*121\.2'
assert_nogrep "DC-6d child2 depends-on NOT external"  "$C2" '^depends-on:.*SC-'

# DC-7 atomicity — exactly ONE new commit, capturing exactly the 5 entity files
NCOMMITS=$( cd "$REPO" && git rev-list --count HEAD )
assert_eq "DC-7a exactly one new commit (init + instantiate = 2)" "$NCOMMITS" "2"
CHANGED=$( cd "$REPO" && git diff-tree --no-commit-id --name-only -r HEAD | sort | tr '\n' ' ' )
EXPECT="docs/ship-flow/121-carlove-backend-intake/index.md docs/ship-flow/121.1-schema-core/index.md docs/ship-flow/121.2-api-layer/index.md docs/ship-flow/121.3-release-verify/index.md docs/ship-flow/121.4-docs-polish/index.md "
assert_eq "DC-7b commit contains exactly the 5 entity files (explicit pathspec)" "$CHANGED" "$EXPECT"
DIRTY=$( cd "$REPO" && git status --porcelain | wc -l | tr -d ' ' )
assert_eq "DC-7c working tree clean after commit (no stray writes)" "$DIRTY" "0"

# DC-11 parallel-planner print: wave layers + per-wave max-parallel + epic handoff
assert_grep "DC-11a wave 1 printed"             "$OUT" 'wave 1:'
assert_grep "DC-11b wave1 max-parallel = 2"     "$OUT" 'wave 1:.*(max-parallel 2|max-parallel: 2)'
assert_grep "DC-11c wave 3 printed (3 layers)"  "$OUT" 'wave 3:'
assert_grep "DC-11d names ship-epic 121 next"   "$OUT" 'ship-epic 121'

# ============================================================================
# Scenario B — dedup collision BLOCKS at the validator (no write, no commit)
# ============================================================================
echo "--- Scenario B: dedup collision blocks ---"
setup_repo
cat > "$WORK/dup.yaml" <<'EOF'
external_project: "linear:x/y"
title: "Dup project"
children:
  - external_id: "SC-999"
    depends_on: []
    body_source: |
      collides with the existing 116-bound entity
EOF
( cd "$REPO" && bash "$INST" "$WORK/dup.yaml" --workflow-dir "$WF" ) >/dev/null 2>&1
B_EXIT=$?
B_NCOMMITS=$( cd "$REPO" && git rev-list --count HEAD )
assert_eq     "DC-8a dedup collision → exit 3 (validation block)" "$B_EXIT" "3"
assert_eq     "DC-8b no new commit on block" "$B_NCOMMITS" "1"
B_NEW=$( cd "$REPO" && ls "$WF" | grep -cE '^(119|120|121)' )
assert_eq     "DC-8c no new epic dir written on block" "$B_NEW" "0"

# ============================================================================
# Scenario C — depends_on cycle BLOCKS at the validator (no write)
# ============================================================================
echo "--- Scenario C: cycle blocks ---"
setup_repo
cat > "$WORK/cycle.yaml" <<'EOF'
external_project: "linear:x/y"
title: "Cyclic project"
children:
  - external_id: "A"
    depends_on: ["B"]
  - external_id: "B"
    depends_on: ["A"]
EOF
( cd "$REPO" && bash "$INST" "$WORK/cycle.yaml" --workflow-dir "$WF" ) >/dev/null 2>&1
C_EXIT=$?
C_NEW=$( cd "$REPO" && ls "$WF" | grep -cE '^(119|120|121)' )
assert_eq "DC-9a cycle → exit 3 (validation block)" "$C_EXIT" "3"
assert_eq "DC-9b no entity dir written on cycle block" "$C_NEW" "0"

# ============================================================================
# Scenario D — --dry-run prints the plan but writes nothing / commits nothing
# ============================================================================
echo "--- Scenario D: --dry-run ---"
setup_repo
write_valid_contract
OUTD="$WORK/out-D.txt"
( cd "$REPO" && bash "$INST" "$CONTRACT_PATH" --workflow-dir "$WF" --dry-run ) >"$OUTD" 2>&1
D_EXIT=$?
D_NCOMMITS=$( cd "$REPO" && git rev-list --count HEAD )
assert_eq   "DC-10a dry-run → exit 0" "$D_EXIT" "0"
assert_eq   "DC-10b dry-run makes no commit" "$D_NCOMMITS" "1"
assert_nofile "DC-10c dry-run writes no epic dir" "$REPO/$WF/121-carlove-backend-intake/index.md"
assert_grep "DC-10d dry-run still prints the wave plan" "$OUTD" 'wave 1:'

# ============================================================================
# Scenario E — refuse to overwrite an existing entity id (--epic-id override)
# ============================================================================
echo "--- Scenario E: refuse overwrite ---"
setup_repo
write_valid_contract
( cd "$REPO" && bash "$INST" "$CONTRACT_PATH" --workflow-dir "$WF" --epic-id 118 ) >/dev/null 2>&1
E_EXIT=$?
E_NCOMMITS=$( cd "$REPO" && git rev-list --count HEAD )
assert_eq "DC-12a --epic-id collides with existing 118 → exit 4 (refuse)" "$E_EXIT" "4"
assert_eq "DC-12b no commit on refuse" "$E_NCOMMITS" "1"

# ============================================================================
# Scenario F — quotes/colons/ampersands in titles → valid ESCAPED frontmatter
# (codex review P2-2: unescaped values produced malformed index.md)
# ============================================================================
echo "--- Scenario F: special chars in titles → yq round-trips generated frontmatter ---"
setup_repo
cat > "$WORK/q.yaml" <<'EOF'
external_project: 'linear:duckbase/Proj "X"'
title: 'Backend: intake "v1" & more'
children:
  - external_id: "SC-900"
    title: 'Schema "core": decider'
    depends_on: []
    body_source: |
      body
EOF
( cd "$REPO" && bash "$INST" "$WORK/q.yaml" --workflow-dir "$WF" ) >/dev/null 2>&1
assert_eq "DC-13a quote/colon title instantiate → exit 0" "$?" "0"
EPICF=$(ls "$REPO/$WF"/121-*/index.md 2>/dev/null | head -1)
CF=$(ls "$REPO/$WF"/121.1-*/index.md 2>/dev/null | head -1)
# Extract just the frontmatter then yq it (real consumers parse frontmatter, NOT the whole
# file — the epic body's mermaid block is intentionally not valid YAML). This proves the
# generated frontmatter is well-formed escaped YAML.
fm_yq() { awk '/^---[[:space:]]*$/{c++; if(c==2)exit; next} c==1{print}' "$1" | yq "$2" 2>/dev/null; }
assert_eq "DC-13b epic title round-trips via yq"          "$(fm_yq "$EPICF" '.title')"            'Backend: intake "v1" & more'
assert_eq "DC-13c epic external_project round-trips"      "$(fm_yq "$EPICF" '.external_project')" 'linear:duckbase/Proj "X"'
assert_eq "DC-13d epic status still parseable (valid YAML)" "$(fm_yq "$EPICF" '.status')"         'epic'
assert_eq "DC-13e child title round-trips via yq"        "$(fm_yq "$CF" '.title')"               'Schema "core": decider'
assert_eq "DC-13f child external_id intact"              "$(fm_yq "$CF" '.external_id')"         'SC-900'
# mermaid label must not contain a raw double-quote that breaks the node label
assert_nogrep "DC-13g mermaid node label has no raw double-quote in title" "$EPICF" '\["121\.1[^"]*"[^]]*"'

# ============================================================================
# Scenario G — tracker body_source can't inject ship-flow section markers (P2-3)
# ============================================================================
echo "--- Scenario G: body_source section-marker injection neutralized ---"
REPO2="$WORK/repo2"; rm -rf "$REPO2"; mkdir -p "$REPO2/docs/ship-flow"
(
  cd "$REPO2"; git init -q; git config user.email t@t; git config user.name t
  printf -- '---\nconcurrency: 2\n---\n# wf\n' > docs/ship-flow/README.md
  mkdir -p docs/ship-flow/117-x; printf -- '---\nid: "117"\nstatus: plan\n---\n' > docs/ship-flow/117-x/index.md
  git add -A; git commit -qm init
)
cat > "$WORK/inject.yaml" <<'EOF'
external_project: "linear:x/y"
title: "Injection test"
children:
  - external_id: "SC-INJ"
    title: "Injecty"
    depends_on: []
    body_source: |
      Normal issue description line.
      <!-- section:evil -->
      ## Sneaky injected header
EOF
( cd "$REPO2" && bash "$INST" "$WORK/inject.yaml" --workflow-dir docs/ship-flow ) >/dev/null 2>&1
INJF=$(ls "$REPO2/docs/ship-flow"/118.1-*/index.md 2>/dev/null | head -1)
assert_nogrep "DC-14a injected open marker not a live section tag"  "$INJF" '^<!-- section:evil'
assert_nogrep "DC-14b injected close marker not a live section tag" "$INJF" '^<!-- /section:evil'
assert_grep   "DC-14c marker preserved (defanged) as escaped literal" "$INJF" 'lt;!-- section:evil'
# end-to-end: the entity must pass the 5a section-tag-coverage invariant (no unclosed/orphan)
if bash "$CHK" --test-fixture "$REPO2" --check section-tag-coverage 2>&1 | grep -qE 'ERROR.*118\.1'; then
  bad "DC-14d injected child passes 5a section-tag-coverage"
else
  ok "DC-14d injected child passes 5a section-tag-coverage"
fi

# ============================================================================
# Scenario H — commit failure rolls back partial writes (P1-3 atomicity)
# ============================================================================
echo "--- Scenario H: commit failure → rollback leaves a clean worktree ---"
setup_repo
write_valid_contract
# A pre-commit hook that always fails forces the commit step to fail.
printf '#!/bin/sh\nexit 1\n' > "$REPO/.git/hooks/pre-commit"; chmod +x "$REPO/.git/hooks/pre-commit"
( cd "$REPO" && bash "$INST" "$CONTRACT_PATH" --workflow-dir "$WF" ) >/dev/null 2>&1
assert_eq "DC-15a commit failure → exit 8" "$?" "8"
H_DIRS=$( cd "$REPO" && ls "$WF" | grep -cE '^121' )
assert_eq "DC-15b rollback removed the partial epic + child dirs" "$H_DIRS" "0"
H_STAGED=$( cd "$REPO" && git status --porcelain | grep -cE '121' )
assert_eq "DC-15c nothing from the failed instantiate left staged/untracked" "$H_STAGED" "0"
rm -f "$REPO/.git/hooks/pre-commit"

rm -rf "$WORK"
echo
if [ "$FAIL" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; fi
exit "$FAIL"
