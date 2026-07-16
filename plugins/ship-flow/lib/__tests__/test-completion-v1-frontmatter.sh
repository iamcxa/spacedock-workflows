#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/.."
# shellcheck disable=SC1091 # production authority seam under test
source "$LIB/completion-v1.sh"
FAIL=0
ok() { echo "OK $1"; }
bad() { echo "FAIL $1"; FAIL=1; }

D="$(mktemp -d)"
MATRIX_PIDS=()
# shellcheck disable=SC2329 # invoked by EXIT/INT/TERM traps below
cleanup_test() { local pid; for pid in "${MATRIX_PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done; for pid in "${MATRIX_PIDS[@]}"; do wait "$pid" 2>/dev/null || true; done; MATRIX_PIDS=(); rm -rf "$D"; }
trap cleanup_test EXIT
trap 'cleanup_test; exit 143' INT TERM
SOURCE="$D/source.md"
EXPECTED="$D/expected.md"
ACTUAL="$D/actual.md"
cat > "$SOURCE" <<'EOF'
---
id: "x"
status: design
stage_outputs: {}
---
# Opaque body

```yaml
status: decoy
stage_outputs: {body: decoy}
```
<!-- section:stage-artifact-links -->
| historical | [old.md](old.md) |
<!-- /section:stage-artifact-links -->
EOF
cat > "$EXPECTED" <<'EOF'
---
id: "x"
status: design
stage_outputs:
  design: design.md
---
# Opaque body

```yaml
status: decoy
stage_outputs: {body: decoy}
```
<!-- section:stage-artifact-links -->
| historical | [old.md](old.md) |
<!-- /section:stage-artifact-links -->
EOF

if [ "$(completion_parse_entity "$SOURCE" design design design.md 2>/dev/null || true)" = ABSENT ]; then ok 'exact empty map parses ABSENT'; else bad 'exact empty map must parse ABSENT'; fi
if completion_render "$SOURCE" design design.md "$ACTUAL" 2>/dev/null && cmp -s "$EXPECTED" "$ACTUAL"; then
  ok 'exact empty map expands without body rewrite'
else bad 'exact empty map must expand without body rewrite'; diff -u "$EXPECTED" "$ACTUAL" 2>/dev/null || true
fi

cat > "$SOURCE" <<'EOF'
---
id: "x"
status: design
stage_outputs:
  shape: shape.md
  plan: plan.md
---
# Body bytes stay exact
stage_outputs: body decoy
EOF
cat > "$EXPECTED" <<'EOF'
---
id: "x"
status: design
stage_outputs:
  shape: shape.md
  design: design.md
  plan: plan.md
---
# Body bytes stay exact
stage_outputs: body decoy
EOF
if [ "$(completion_parse_entity "$SOURCE" design design design.md 2>/dev/null || true)" = ABSENT ] && \
   completion_render "$SOURCE" design design.md "$ACTUAL" 2>/dev/null && \
   cmp -s "$EXPECTED" "$ACTUAL"; then
  ok 'sparse shape/plan inserts design by rank and preserves body bytes'
else
  bad 'sparse shape/plan must insert design by rank and preserve body bytes'
  diff -u "$EXPECTED" "$ACTUAL" 2>/dev/null || true
fi

echo '--- exhaustive 128-subset/absent-target closure matrix ---'
STAGES=(shape design plan execute verify review ship)
FILES=(shape.md design.md plan.md execute.md verify.md review.md ship.md)
build_mask_doc() {
  local out="$1" mask="$2" i=0
  {
    printf '%s\n' '---' 'id: "matrix"' 'status: design'
    if [ "$mask" = 0 ]; then printf '%s\n' 'stage_outputs: {}'; else printf '%s\n' 'stage_outputs:'
      while [ "$i" -lt 7 ]; do
        [ $((mask & (1 << i))) -eq 0 ] || printf '  %s: %s\n' "${STAGES[$i]}" "${FILES[$i]}"
        i=$((i + 1))
      done
    fi
    printf '%s\n' '---' '# opaque matrix body' 'stage_outputs: decoy'
  } > "$out"
}
matrix_worker() {
  local mask="$2" end="$3" source="$D/matrix-$1-source.md" expected="$D/matrix-$1-expected.md" actual="$D/matrix-$1-actual.md"
  local coverage="$D/matrix-$1.coverage" i state failed=0 masks=0 decisions=0 closures=0
  while [ "$mask" -le "$end" ]; do
    build_mask_doc "$source" "$mask"; i=0
    while [ "$i" -lt 7 ]; do
      decisions=$((decisions + 1))
      state="$(completion_parse_entity "$source" design "${STAGES[$i]}" "${FILES[$i]}" 2>/dev/null || true)"
      if [ $((mask & (1 << i))) -ne 0 ]; then
        [ "$state" = PRESENT ] || { echo "FAIL matrix mask=$mask present ${STAGES[$i]}"; failed=1; }
      else
        closures=$((closures + 1))
        build_mask_doc "$expected" $((mask | (1 << i)))
        if [ "$state" != ABSENT ] || ! completion_render "$source" "${STAGES[$i]}" "${FILES[$i]}" "$actual" 2>/dev/null || \
           ! cmp -s "$expected" "$actual" || [ "$(completion_parse_entity "$actual" design "${STAGES[$i]}" "${FILES[$i]}" 2>/dev/null || true)" != PRESENT ]; then
          echo "FAIL matrix mask=$mask closes absent ${STAGES[$i]}"; failed=1
        fi
      fi
      i=$((i + 1))
    done
    masks=$((masks + 1)); mask=$((mask + 1))
  done
  printf '%s %s %s\n' "$masks" "$decisions" "$closures" > "$coverage"
  return "$failed"
}
MATRIX_FAIL=0; MATRIX_RC=(); SHARD_START=(0 32 64 96); SHARD_END=(31 63 95 127); WORKER=0
while [ "$WORKER" -lt 4 ]; do matrix_worker "$WORKER" "${SHARD_START[$WORKER]}" "${SHARD_END[$WORKER]}" > "$D/matrix-$WORKER.log" 2>&1 & MATRIX_PIDS[WORKER]=$!; WORKER=$((WORKER + 1)); done
WORKER=0; while [ "$WORKER" -lt 4 ]; do wait "${MATRIX_PIDS[$WORKER]}"; MATRIX_RC[WORKER]=$?; WORKER=$((WORKER + 1)); done; MATRIX_PIDS=()
MASKS=0; DECISIONS=0; CLOSURES=0; WORKER=0
while [ "$WORKER" -lt 4 ]; do
  cat "$D/matrix-$WORKER.log"; [ "${MATRIX_RC[$WORKER]}" = 0 ] || MATRIX_FAIL=1
  if read -r M T C < "$D/matrix-$WORKER.coverage"; then MASKS=$((MASKS + M)); DECISIONS=$((DECISIONS + T)); CLOSURES=$((CLOSURES + C)); else MATRIX_FAIL=1; fi
  WORKER=$((WORKER + 1))
done
if [ "$MATRIX_FAIL/$MASKS/$DECISIONS/$CLOSURES" = 0/128/896/448 ]; then ok 'all 128 ordered subsets, 896 target decisions, and 448 render closures pass'; else bad "matrix aggregate fail=$MATRIX_FAIL masks=$MASKS decisions=$DECISIONS closures=$CLOSURES"; fi

echo '--- malformed authority tail matrix ---'
BASE="$D/base.md"
cat > "$BASE" <<'EOF'
---
id: "x"
status: design
stage_outputs:
  shape: shape.md
  design: design.md
---
body
EOF
reject_file() {
  local label="$1" file="$2"
  if completion_parse_entity "$file" '' shape shape.md >/dev/null 2>&1; then bad "malformed tail accepted: $label"; else ok "malformed tail rejected: $label"; fi
}
mutate() {
  local label="$1" expression="$2" file="$D/bad-$1.md"
  perl -0pe "$expression" "$BASE" > "$file"; reject_file "$label" "$file"
}
mutate duplicate-status 's/status: design/status: design\nstatus: design/'; mutate missing-status 's/status: design\n//'
mutate reordered 's/status: design\nstage_outputs:/stage_outputs:\nstatus: design/'; mutate non-tail-key 's/  design: design.md/  design: design.md\nextra: value/'
mutate duplicate-map 's/stage_outputs:/stage_outputs: {}\nstage_outputs:/'; mutate indented-status 's/^status:/ status:/m'
mutate quoted-status 's/status: design/status: "design"/'; mutate status-comment 's/status: design/status: design # comment/'
mutate empty-map-spacing 's/stage_outputs:\n  shape: shape.md\n  design: design.md/stage_outputs: { }/'; mutate map-comment 's/stage_outputs:/stage_outputs: # comment/'
mutate one-space-row 's/^  shape:/ shape:/m'; mutate three-space-row 's/^  shape:/   shape:/m'; mutate tab-row 's/^  shape:/\tshape:/m'
mutate row-trailing-space 's/shape.md\n/shape.md \n/'; mutate inline-row-comment 's/shape.md\n/shape.md # comment\n/'
mutate quoted-row 's/  shape: shape.md/  "shape": "shape.md"/'; mutate anchor-row 's/shape: shape.md/shape: \&f shape.md/'; mutate alias-row 's/shape: shape.md/shape: *f/'
mutate tag-row 's/shape: shape.md/shape: !file shape.md/'; mutate flow-map 's/stage_outputs:\n  shape: shape.md\n  design: design.md/stage_outputs: {shape: shape.md}/'
mutate multiline-row 's/shape: shape.md/shape: |/'; mutate wrong-stage 's/shape: shape.md/draft: shape.md/'; mutate wrong-file 's/shape: shape.md/shape: spec.md/'
mutate duplicate-row 's/  shape: shape.md/  shape: shape.md\n  shape: shape.md/'; mutate rank-disorder 's/  shape: shape.md\n  design: design.md/  design: design.md\n  shape: shape.md/'
mutate carriage-return 's/status: design\n/status: design\r\n/'; mutate control-byte 's/id: "x"/id: "x"\x01/'
BAD_UTF8="$D/bad-invalid-utf8.md"; cp "$BASE" "$BAD_UTF8"; printf '\377' >> "$BAD_UTF8"
reject_file invalid-utf8 "$BAD_UTF8"

for OPAQUE in '<<: *defaults' 'status : shadow' '"entity_type": epic' '!!str pattern: epic'; do
  printf '%s\n' '---' 'id: "opaque"' "$OPAQUE" 'status: design' 'stage_outputs: {}' '---' body > "$SOURCE"
  printf '%s\n' '---' 'id: "opaque"' "$OPAQUE" 'status: design' 'stage_outputs:' '  design: design.md' '---' body > "$EXPECTED"
  if [ "$(completion_parse_entity "$SOURCE" design design design.md 2>/dev/null || true)" = ABSENT ] &&
     completion_render "$SOURCE" design design.md "$ACTUAL" 2>/dev/null && cmp -s "$EXPECTED" "$ACTUAL"; then
    ok "opaque prefix structurally parses and renders byte-exact: $OPAQUE"
  else bad "opaque prefix must remain structural data: $OPAQUE"; fi
done

echo '--- five compatibility classes and pre-lease eligibility ---'
R="$D/repo"
mkdir -p "$R/docs/wf/item" "$R/docs/wf/existing" "$R/docs/wf/noncompliant" \
  "$R/docs/wf/body-only" "$R/docs/wf/_archive/old" "$R/docs/wf/epic"
cat > "$R/docs/wf/README.md" <<'EOF'
---
stages:
  states:
    - name: shape
    - name: design
    - name: plan
---
EOF
cat > "$R/docs/wf/item/index.md" <<'EOF'
---
id: "item"
entity_type: entity
pattern: shaped-child
nested:
  entity_type: epic
  pattern: "epic"
status: design
stage_outputs: {}
---
new canonical body
EOF
cat > "$R/docs/wf/existing/index.md" <<'EOF'
---
id: "existing"
status: design
stage_outputs:
  shape: shape.md
---
<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
cat > "$R/docs/wf/noncompliant/index.md" <<'EOF'
---
id: "noncompliant"
status: design
priority: high
---
EOF
cat > "$R/docs/wf/body-only/index.md" <<'EOF'
---
id: "body-only"
status: design
---
<!-- section:stage-artifact-links -->
| Stage | File |
| design | [design.md](design.md) |
<!-- /section:stage-artifact-links -->
EOF
cat > "$R/docs/wf/_archive/old/index.md" <<'EOF'
---
id: "old"
status: design
stage_outputs: {}
---
EOF
cat > "$R/docs/wf/epic/index.md" <<'EOF'
---
id: "epic"
entity_type: epic
pattern: epic
status: design
stage_outputs: {}
---
EOF
printf '# Design\n' > "$R/docs/wf/epic/design.md"
(cd "$R" && git init -q -b main && git config user.email t@t && git config user.name t && git add docs && git commit -qm init)
B="$(cd "$R" && git rev-parse HEAD)"

if (cd "$R" && completion_eligible_at_rev "$B" docs/wf/item/index.md design design design.md) 2>/dev/null; then
  ok 'class 1 canonical non-container and indented epic decoys are eligible'
else
  bad 'class 1 canonical non-container and indented epic decoys must be eligible'
fi
if (cd "$R" && completion_eligible_at_rev "$B" docs/wf/existing/index.md design design design.md) 2>/dev/null; then
  ok 'class 2 compliant active with historical body table is eligible'
else
  bad 'class 2 compliant active with historical body table must be eligible'
fi
reject_file 'class 3 active noncompliant frontmatter' "$R/docs/wf/noncompliant/index.md"
reject_file 'class 4 body-table-only remains Contract-1-only' "$R/docs/wf/body-only/index.md"
if [ "$(completion_parse_entity "$R/docs/wf/_archive/old/index.md" '' design design.md 2>/dev/null || true)" = ABSENT ] && \
   ! (cd "$R" && completion_eligible_at_rev "$B" docs/wf/_archive/old/index.md design design design.md) 2>/dev/null; then
  ok 'class 5 archived entity parses but is ineligible'
else
  bad 'class 5 archived entity must parse structurally but remain ineligible'
fi
if [ "$(completion_parse_entity "$R/docs/wf/epic/index.md" '' design design.md 2>/dev/null || true)" = ABSENT ] && \
   ! (cd "$R" && completion_eligible_at_rev "$B" docs/wf/epic/index.md design design design.md) 2>/dev/null; then
  ok 'epic structural parse succeeds but eligibility rejects'
else
  bad 'epic must parse structurally but reject completion eligibility'
fi

CASE_N=0; CASE_EXPECT=(); CASE_LABEL=(); CASE_PATH=(); mkdir -p "$D/classification"
add_case() { local expect="$1" label="$2" path; shift 2; path="$D/classification/case-$CASE_N.md"
  printf '%s\n' '---' 'id: "case"' "$@" 'status: design' 'stage_outputs: {}' '---' > "$path"
  CASE_EXPECT[CASE_N]="$expect"; CASE_LABEL[CASE_N]="$label"; CASE_PATH[CASE_N]="$path"; CASE_N=$((CASE_N + 1)); }
ET=('' 'entity_type: entity' 'entity_type: epic'); PT=('' 'pattern: single' 'pattern: pitch' 'pattern: shaped-child' 'pattern: epic')
for E in "${ET[@]}"; do for P in "${PT[@]}"; do X=P; [ "$E" = 'entity_type: epic' ] && X=N; [ "$P" = 'pattern: epic' ] && X=N
  L=(); [ -z "$E" ] || L+=("$E"); [ -z "$P" ] || L+=("$P"); add_case "$X" "classification cross-product e=[$E] p=[$P]" "${L[@]}"; done; done
add_case N 'duplicate entity_type count=2' 'entity_type: entity' 'entity_type: entity'; add_case N 'duplicate pattern count=2' 'pattern: single' 'pattern: pitch'
BAD_VALUES=('' '  entity' ' entity # comment' ' "entity"' ' !kind entity' ' &kind entity' ' *kind' ' [entity]' ' |' ' Entity' ' task')
for K in entity_type pattern; do for V in "${BAD_VALUES[@]}"; do add_case N "$K rejects noncanonical suffix [$V]" "$K:$V"; done; done
CODE=32; while [ "$CODE" -le 126 ]; do printf -v OCT '%03o' "$CODE"; printf -v CH '%b' "\\$OCT"; X=N
  { [ "$CODE" -eq 32 ] || [ "$CODE" -eq 35 ] || { [ "$CODE" -ge 97 ] && [ "$CODE" -le 122 ]; }; } && X=P
  add_case "$X" "first-key-byte $CODE" "${CH}key: value"; X=N
  { [ "$CODE" -eq 45 ] || [ "$CODE" -eq 58 ] || [ "$CODE" -eq 95 ] || { [ "$CODE" -ge 48 ] && [ "$CODE" -le 57 ]; } || { [ "$CODE" -ge 97 ] && [ "$CODE" -le 122 ]; }; } && X=P
  add_case "$X" "subsequent-key-byte $CODE" "a${CH}b: value"; CODE=$((CODE + 1)); done
add_case P 'exact empty suffix' 'alpha:'; add_case P 'colon begins opaque suffix' 'alpha:: value'; add_case N 'space before delimiter' 'alpha : value'; add_case N 'missing delimiter' 'alpha value'
add_case N 'non-ASCII key start' 'ékey: value'; add_case N 'non-ASCII inside key' 'aéb: value'; add_case P 'non-ASCII opaque value' 'metadata: café'; add_case P 'non-ASCII indented continuation' '  ékey: value'
for LINE in '- item' 'scalar' '{x: y}' '[x]' '%YAML 1.2' '...' '? key' ': value' '&k metadata: value' '*alias' '!!str metadata: value' '"metadata": value' 'metadata : value' '<<: *defaults'; do add_case N "rejected root form [$LINE]" "$LINE"; done
add_case P 'blank token' ''; add_case P 'comment token' '# opaque'; add_case P 'space-indented token' ' continuation'; add_case P 'tab-indented token' $'\tcontinuation'
for VALUE in '' ' plain' " 'quoted'" ' "quoted"' ' !tag value' ' &anchor value' ' *alias' ' {x: y}' ' [x, y]'; do add_case P "opaque unrelated value [$VALUE]" "metadata:$VALUE"; done
add_case P 'opaque block indicator and continuation' 'metadata: |' '  block'
for I in "${!CASE_PATH[@]}"; do completion_classification_ok "${CASE_PATH[$I]}" && X=P || X=N
  [ "$X" = "${CASE_EXPECT[$I]}" ] || bad "classification ${CASE_LABEL[$I]} expected=${CASE_EXPECT[$I]} actual=$X"
done
if [ "$CASE_N" = 265 ]; then ok 'classification language matrix exercised exactly 265 direct-seam cases'; else bad "classification language matrix count=$CASE_N expected=265"; fi
INTEGRATION_N=0; INTEGRATION_EXPECT=(); INTEGRATION_LABEL=(); INTEGRATION_PATH=()
add_integration() { local expect="$1" label="$2" path; shift 2; path="docs/wf/integration-$INTEGRATION_N/index.md"; mkdir -p "$R/${path%/index.md}"
  printf '%s\n' '---' 'id: "integration"' "$@" 'status: design' 'stage_outputs: {}' '---' > "$R/$path"; printf '# Design\n' > "$R/${path%index.md}design.md"
  INTEGRATION_EXPECT[INTEGRATION_N]="$expect"; INTEGRATION_LABEL[INTEGRATION_N]="$label"; INTEGRATION_PATH[INTEGRATION_N]="$path"; INTEGRATION_N=$((INTEGRATION_N + 1)); }
add_integration P absent; add_integration P entity 'entity_type: entity'; add_integration P pattern-single 'pattern: single'; add_integration P pattern-pitch 'pattern: pitch'
add_integration P pattern-shaped-child 'pattern: shaped-child'; add_integration N entity-epic 'entity_type: epic'; add_integration N pattern-epic 'pattern: epic'
add_integration N duplicate-entity 'entity_type: entity' 'entity_type: entity'; add_integration N duplicate-pattern 'pattern: single' 'pattern: pitch'
add_integration N noncanonical-classification 'entity_type: entity # comment'; add_integration N invalid-root-key 'metadata : value'; add_integration P indented-decoy '  entity_type: epic' '  pattern: epic'
(cd "$R" && git add docs/wf/integration-* && git commit -qm 'twelve classification integration partitions'); B="$(cd "$R" && git rev-parse HEAD)"
for I in "${!INTEGRATION_PATH[@]}"; do PATH_I="${INTEGRATION_PATH[$I]}"; REF_BEFORE="$B"; INDEX_BEFORE="$(cd "$R" && git write-tree)"; WORK_BEFORE="$(cd "$R" && git status --porcelain=v1 --untracked-files=all)"
  OUT="$(cd "$R" && bash "$LIB/advance-stage.sh" --entity="$PATH_I" --new-status=design --stage-name=design --stage-file=design.md --if-hash="$(completion_sha256 "$R/$PATH_I")" --commit-as=x --lease-file=/missing --lease-token=x --worker-id=x 2>&1)"; RC=$?
  if [ "$RC" != 0 ] && ! printf '%s' "$OUT" | grep -q '^completion-v1 disposition=' && [ "$REF_BEFORE" = "$(cd "$R" && git rev-parse refs/heads/main)" ] && [ "$INDEX_BEFORE" = "$(cd "$R" && git write-tree)" ] && [ "$WORK_BEFORE" = "$(cd "$R" && git status --porcelain=v1 --untracked-files=all)" ] &&
     { { [ "${INTEGRATION_EXPECT[$I]}" = P ] && printf '%s' "$OUT" | grep -q 'missing or foreign cooperative lease' && ! printf '%s' "$OUT" | grep -q 'ineligible'; } || { [ "${INTEGRATION_EXPECT[$I]}" = N ] && printf '%s' "$OUT" | grep -q 'completion ineligible at parent revision' && ! printf '%s' "$OUT" | grep -q 'lease'; }; }; then :
  else bad "integration ${INTEGRATION_LABEL[$I]} expected=${INTEGRATION_EXPECT[$I]} rc=$RC out=$OUT"; fi
done
if [ "$INTEGRATION_N" = 12 ]; then ok 'exactly 12 advance-stage classification partitions preserve ref/index/worktree and emit no receipt'; else bad "integration partition count=$INTEGRATION_N expected=12"; fi

exit "$FAIL"
