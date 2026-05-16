#!/usr/bin/env bash
# test-enforce-advance-stage.sh — tests for check_entity_status_via_advance_stage_only
# in plugins/ship-flow/bin/check-invariants.sh
#
# TDD: written before implementation. Runs the function against synthetic
# git histories to validate detection/bypass discipline.
#
# Source pitch: enforce-advance-stage-primitive-only (sharp 2026-05-15).
# Source evidence: pitch-106 commit 898d006c — direct YAML edit bypassed
# advance-stage.sh, would have nuked entity body table per MEMORY
# "advance-stage destructive on legacy body tables".

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
BIN_DIR="$(cd "${LIB_DIR}/../bin" && pwd)"
FAIL=0

assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}

# Build a tiny git repo with two commits: a sharp-claim baseline (so we have
# something to advance) + the test commit we want to scrutinize. We make
# `main` the merge-base; the scrutinized commit lives on a branch ahead.
#
# Args: $1 = commit_message for the mutation commit
#       $2 = "mutate" (change status:) | "noop" (touch file body, leave status:)
#            | "nonentity" (modify a non-entity file)
#            | "stageartifact" (modify a folder entity stage artifact, not index.md)
#            | "flatbody" (modify a flat entity body status: line, not frontmatter)
#       $3 = "new" (NEW entity index.md — only +status:) | "edit" (mutate existing — both +status: and -status:)
#
# Returns: prints the path of the repo dir.
setup_fixture() {
  local mutation_msg="$1" kind="$2" entity_age="$3"
  local dir
  dir="$(mktemp -d)"
  (
    cd "$dir" || exit 1
    git init -q -b main
    git config user.email test@test
    git config user.name test

    # Always: create baseline entity on `main`
    mkdir -p docs/test-wf/baseline-entity
    cat > docs/test-wf/baseline-entity/index.md <<'EOF'
---
id: "baseline-entity"
title: "Baseline"
status: sharp
---
EOF
    git add docs/test-wf/baseline-entity/index.md
    git commit -qm "baseline: pre-existing entity"

    # Flat entity baseline for body-only status: false-positive coverage.
    cat > docs/test-wf/flat-entity.md <<'EOF'
---
id: "flat-entity"
title: "Flat"
status: sharp
---

Example body metadata:
status: pending
EOF
    git add docs/test-wf/flat-entity.md
    git commit -qm "baseline: pre-existing flat entity"

    # Branch off main; the scrutinized commit lives here
    git checkout -q -b feature

    case "$kind" in
      mutate)
        if [ "$entity_age" = "edit" ]; then
          # Mutation: edit existing entity's status: line
          sed -i.bak 's/^status: sharp$/status: plan/' docs/test-wf/baseline-entity/index.md
          rm -f docs/test-wf/baseline-entity/index.md.bak
          git add docs/test-wf/baseline-entity/index.md
          git commit -qm "$mutation_msg"
        else
          # NEW entity: create a different entity folder; only +status:
          mkdir -p docs/test-wf/new-entity
          cat > docs/test-wf/new-entity/index.md <<'EOF'
---
id: "new-entity"
title: "New"
status: sharp
---
EOF
          git add docs/test-wf/new-entity/index.md
          git commit -qm "$mutation_msg"
        fi
        ;;
      noop)
        # Touch entity body but leave status: alone
        printf "\n## New section\nText\n" >> docs/test-wf/baseline-entity/index.md
        git add docs/test-wf/baseline-entity/index.md
        git commit -qm "$mutation_msg"
        ;;
      nonentity)
        # Modify a non-entity file
        echo "data" > somefile.txt
        git add somefile.txt
        git commit -qm "$mutation_msg"
        ;;
      stageartifact)
        # Modify a folder entity stage artifact with a top-level status: line.
        # This is not entity frontmatter and must not trip C14.
        cat > docs/test-wf/baseline-entity/plan.md <<'EOF'
# Plan

status: draft
EOF
        git add docs/test-wf/baseline-entity/plan.md
        git commit -qm "baseline: add plan artifact"
        git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"

        sed -i.bak 's/^status: draft$/status: reviewed/' docs/test-wf/baseline-entity/plan.md
        rm -f docs/test-wf/baseline-entity/plan.md.bak
        git add docs/test-wf/baseline-entity/plan.md
        git commit -qm "$mutation_msg"
        ;;
      flatbody)
        # Modify a body-level status: line in a flat entity. Frontmatter status
        # is unchanged, so this must not count as an entity status mutation.
        sed -i.bak 's/^status: pending$/status: resolved/' docs/test-wf/flat-entity.md
        rm -f docs/test-wf/flat-entity.md.bak
        git add docs/test-wf/flat-entity.md
        git commit -qm "$mutation_msg"
        ;;
    esac
  )
  echo "$dir"
}

# Run only the new check against the fixture repo via --check mode.
# Uses check-invariants.sh's existing single-check dispatch path.
# shellcheck disable=SC2329 # invoked indirectly through assert_exit/eval cases below
run_check_only() {
  local repo_dir="$1"
  (
    cd "$repo_dir" || exit 1
    # Pretend `main` is `origin/main` for the function's merge-base call.
    git update-ref refs/remotes/origin/main "$(git rev-parse main)"
    bash "${BIN_DIR}/check-invariants.sh" --check entity-status-via-advance-stage-only
  )
}

echo "--- Case 1: BYPASS commit (mutate status:, no advance-stage signature) → FAIL ---"
TMP="$(setup_fixture "manual hand-edit status to plan" "mutate" "edit")"
assert_exit 1 "run_check_only '$TMP'" "Case-1 bypass detected (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 2: LEGITIMATE commit (mutate status:, msg contains signature) → PASS ---"
TMP="$(setup_fixture "plan(baseline-entity): advance status to plan" "mutate" "edit")"
assert_exit 0 "run_check_only '$TMP'" "Case-2 legitimate advance-stage passes (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 3: UNRELATED commit (entity touched, status: unchanged) → PASS (no false positive) ---"
TMP="$(setup_fixture "docs(baseline-entity): add notes" "noop" "edit")"
assert_exit 0 "run_check_only '$TMP'" "Case-3 status-unchanged no false positive (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 4: NON-ENTITY commit (no entity file modified) → PASS ---"
TMP="$(setup_fixture "chore: update unrelated file" "nonentity" "edit")"
assert_exit 0 "run_check_only '$TMP'" "Case-4 non-entity commit no false positive (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 5: NEW entity sharp-claim (only +status:, no -status:) → PASS (not a mutation) ---"
TMP="$(setup_fixture "sharp(new-entity): claim entity" "mutate" "new")"
assert_exit 0 "run_check_only '$TMP'" "Case-5 new entity sharp-claim no false positive (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 6: STAGE ARTIFACT status line changes → PASS (not entity frontmatter) ---"
TMP="$(setup_fixture "docs(baseline-entity): update plan artifact status" "stageartifact" "edit")"
assert_exit 0 "run_check_only '$TMP'" "Case-6 stage artifact status no false positive (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 7: BODY status line changes → PASS (not entity frontmatter) ---"
TMP="$(setup_fixture "docs(flat-entity): update body status example" "flatbody" "edit")"
assert_exit 0 "run_check_only '$TMP'" "Case-7 body status no false positive (exit 0)"
rm -rf "$TMP"

echo
if [ "$FAIL" = "0" ]; then
  echo "All test-enforce-advance-stage cases passed."
  exit 0
else
  echo "FAIL: test-enforce-advance-stage has failures."
  exit 1
fi
