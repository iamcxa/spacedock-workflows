#!/usr/bin/env bash
# test-validate-cut-project.sh — structural validation of the cut-project contract
# (pitch 118.1). Exit: 0 valid · 1 invalid · 2 usage.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
VAL="${LIB_DIR}/validate-cut-project.sh"
FAIL=0

assert_exit() {
  # assert_exit <name> <expected-exit> <args...>
  local name="$1" expected="$2"; shift 2
  local got
  bash "$VAL" "$@" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}

WORK="$(mktemp -d)"   # scratch dir for contract files + a fake workflow dir
mkdir -p "$WORK/wf/existing-entity"
# An existing entity that already binds external_id SC-999 (for the dedup test)
printf -- '---\nid: "099"\nstatus: plan\nexternal_id: "SC-999"\n---\n' > "$WORK/wf/existing-entity/index.md"
# An ARCHIVED (shipped) entity binding SC-ARCH — dedup must scan _archive too, else
# re-intaking a shipped tracker issue silently creates a duplicate binding (P2-1).
mkdir -p "$WORK/wf/_archive/old-shipped"
printf -- '---\nid: "050"\nstatus: done\nexternal_id: "SC-ARCH"\n---\n' > "$WORK/wf/_archive/old-shipped/index.md"

write_valid() {
  cat > "$WORK/valid.yaml" <<'EOF'
external_project: "linear:duckbase/Project X"
title: "Project X intake"
appetite: medium-batch
children:
  - external_id: "SC-810"
    depends_on: []
    affects_ui: false
    domain: schema
    body_source: |
      Schema + decider + saga. All features block on this.
      - external_id: "FAKE-1"
      depends_on: ["NOPE"]
  - external_id: "SC-811"
    depends_on: ["SC-810"]
    body_source: |
      Builds on SC-810.
  - external_id: "SC-812"
    depends_on: ["SC-810", "SC-811"]
    body_source: |
      Final release-verification slice.
EOF
}

echo "--- DC-1: valid contract (incl. block-scalar body with decoy structure) → exit 0 ---"
write_valid
assert_exit "valid" 0 "$WORK/valid.yaml"

echo "--- DC-2: decoy body lines must NOT be parsed as children/deps (no phantom FAKE-1 / NOPE) ---"
# Same valid file — if the parser were fooled, FAKE-1 would be a 4th child and NOPE an
# unknown ref → closure fail (exit 1). Passing DC-1 already proves it; assert layers too.
assert_exit "decoy-ignored" 0 "$WORK/valid.yaml"

echo "--- DC-3: missing external_project → exit 1 ---"
cat > "$WORK/no-proj.yaml" <<'EOF'
title: "no project ref"
children:
  - external_id: "SC-1"
    depends_on: []
EOF
assert_exit "missing-external_project" 1 "$WORK/no-proj.yaml"

echo "--- DC-4: a child missing external_id → exit 1 ---"
cat > "$WORK/no-eid.yaml" <<'EOF'
external_project: "linear:x/y"
children:
  - external_id: "SC-1"
    depends_on: []
  - depends_on: ["SC-1"]
    body_source: |
      missing external_id
EOF
assert_exit "child-missing-external_id" 1 "$WORK/no-eid.yaml"

echo "--- DC-5: depends_on cycle → exit 1 ---"
cat > "$WORK/cycle.yaml" <<'EOF'
external_project: "linear:x/y"
children:
  - external_id: "A"
    depends_on: ["B"]
  - external_id: "B"
    depends_on: ["A"]
EOF
assert_exit "cycle" 1 "$WORK/cycle.yaml"

echo "--- DC-6: depends_on references unknown external_id → exit 1 (closure) ---"
cat > "$WORK/unknown.yaml" <<'EOF'
external_project: "linear:x/y"
children:
  - external_id: "A"
    depends_on: ["GHOST"]
EOF
assert_exit "unknown-ref" 1 "$WORK/unknown.yaml"

echo "--- DC-7: dedup — external_id already bound by an existing entity → exit 1 ---"
cat > "$WORK/dup.yaml" <<'EOF'
external_project: "linear:x/y"
children:
  - external_id: "SC-999"
    depends_on: []
EOF
assert_exit "dedup-collision" 1 "$WORK/dup.yaml" --workflow-dir "$WORK/wf"

echo "--- DC-8: same contract, no --workflow-dir → dedup skipped → exit 0 ---"
assert_exit "no-dedup-without-wf" 0 "$WORK/dup.yaml"

echo "--- DC-9: empty children list → exit 1 ---"
cat > "$WORK/empty.yaml" <<'EOF'
external_project: "linear:x/y"
children: []
EOF
assert_exit "empty-children" 1 "$WORK/empty.yaml"

echo "--- DC-10: missing file → usage exit 2 ---"
assert_exit "missing-file" 2 "$WORK/nope.yaml"

echo "--- DC-11: underscore depends_on key accepted (corpus mixes keys) ---"
cat > "$WORK/under.yaml" <<'EOF'
external_project: "linear:x/y"
children:
  - external_id: "A"
    depends_on: []
  - external_id: "B"
    depends_on: ["A"]
EOF
assert_exit "underscore-ok" 0 "$WORK/under.yaml"

echo "--- DC-16: dedup against ARCHIVED entity external_id → exit 1 (P2-1 archive-aware) ---"
cat > "$WORK/arch-dup.yaml" <<'EOF'
external_project: "linear:x/y"
children:
  - external_id: "SC-ARCH"
    depends_on: []
EOF
assert_exit "dedup-archived" 1 "$WORK/arch-dup.yaml" --workflow-dir "$WORK/wf"

echo "--- DC-12: BLOCK-style depends_on cycle → exit 1 (parser must not silently drop block lists) ---"
cat > "$WORK/blk-cycle.yaml" <<'EOF'
external_project: "linear:x/y"
children:
  - external_id: "A"
    depends_on:
      - "B"
  - external_id: "B"
    depends_on:
      - "A"
EOF
assert_exit "block-cycle" 1 "$WORK/blk-cycle.yaml"

echo "--- DC-13: BLOCK-style depends_on unknown ref → exit 1 (closure) ---"
cat > "$WORK/blk-unknown.yaml" <<'EOF'
external_project: "linear:x/y"
children:
  - external_id: "A"
    depends_on:
      - "GHOST"
EOF
assert_exit "block-unknown-ref" 1 "$WORK/blk-unknown.yaml"

echo "--- DC-14: valid BLOCK-style depends_on (closure holds, acyclic) → exit 0 ---"
cat > "$WORK/blk-valid.yaml" <<'EOF'
external_project: "linear:x/y"
children:
  - external_id: "A"
    depends_on: []
  - external_id: "B"
    depends_on:
      - "A"
    body_source: |
      Body content with a decoy list that must NOT be read as deps:
      - "NOPE"
EOF
assert_exit "block-valid" 0 "$WORK/blk-valid.yaml"

echo "--- DC-15: block-list deps then body_source decoy dash must not leak into deps (closure stays valid) ---"
# Same as DC-14 but assert the decoy '- \"NOPE\"' under body_source does not create
# an unknown-ref closure failure (would exit 1 if the parser leaked body dashes).
assert_exit "block-then-body-decoy" 0 "$WORK/blk-valid.yaml"

rm -rf "$WORK"
echo
if [ "$FAIL" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; fi
exit "$FAIL"
