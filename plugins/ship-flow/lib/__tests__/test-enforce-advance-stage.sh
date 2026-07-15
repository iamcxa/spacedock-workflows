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
      bodytable)
        # Folder entity with a stage-artifact-links BODY TABLE but NO
        # stage_outputs frontmatter (the shape-confirm.sh format). advance-stage.sh
        # / render-stage-links rebuild that table FROM stage_outputs, so on such
        # an entity advance-stage.sh is DESTRUCTIVE — a manual status edit is the
        # SAFE path and must be EXEMPT from the signature requirement (#117).
        mkdir -p docs/test-wf/bodytable-entity
        cat > docs/test-wf/bodytable-entity/index.md <<'EOF'
---
id: "bodytable-entity"
title: "Body Table"
status: sharp
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
        git add docs/test-wf/bodytable-entity/index.md
        git commit -qm "baseline: add body-table entity"
        sed -i.bak 's/^status: sharp$/status: plan/' docs/test-wf/bodytable-entity/index.md
        rm -f docs/test-wf/bodytable-entity/index.md.bak
        git add docs/test-wf/bodytable-entity/index.md
        git commit -qm "$mutation_msg"
        ;;
      stageoutputs)
        # Folder entity WITH stage_outputs frontmatter — advance-stage.sh is safe
        # here, so a manual status edit MUST still be flagged (narrow exemption).
        mkdir -p docs/test-wf/stageoutputs-entity
        cat > docs/test-wf/stageoutputs-entity/index.md <<'EOF'
---
id: "stageoutputs-entity"
title: "Stage Outputs"
status: sharp
stage_outputs:
  shape: shape.md
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
        git add docs/test-wf/stageoutputs-entity/index.md
        git commit -qm "baseline: add stage_outputs entity"
        sed -i.bak 's/^status: sharp$/status: plan/' docs/test-wf/stageoutputs-entity/index.md
        rm -f docs/test-wf/stageoutputs-entity/index.md.bak
        git add docs/test-wf/stageoutputs-entity/index.md
        git commit -qm "$mutation_msg"
        ;;
      bodytable-large)
        # Same shape as "bodytable" but the parent-rev (pre-mutation) index.md
        # is padded past ~100KB with the marker still near the top. This
        # exceeds the kernel pipe-buffer size (~64KB), which is what lets the
        # unfixed printf|grep -q marker-detection pipe SIGPIPE: grep matches
        # the marker on its first read and exits before printf finishes
        # writing the padded remainder, and that non-zero writer exit was
        # misread (under pipefail) as "marker not found" — losing a
        # legitimate exemption. Regression coverage for the CI-only repro
        # (PR #14, commits 90f47062/f9a7e4ab) that 4 local macOS pre-flights
        # never reproduced at small fixture sizes.
        mkdir -p docs/test-wf/large-bodytable-entity
        {
          cat <<'EOF'
---
id: "large-bodytable-entity"
title: "Large Body Table"
status: sharp
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->

EOF
          i=0
          while [ "$i" -lt 1700 ]; do
            printf 'padding padding padding padding padding padding padding padding\n'
            i=$((i + 1))
          done
        } > docs/test-wf/large-bodytable-entity/index.md
        git add docs/test-wf/large-bodytable-entity/index.md
        git commit -qm "baseline: add large body-table entity"
        sed -i.bak 's/^status: sharp$/status: plan/' docs/test-wf/large-bodytable-entity/index.md
        rm -f docs/test-wf/large-bodytable-entity/index.md.bak
        git add docs/test-wf/large-bodytable-entity/index.md
        git commit -qm "$mutation_msg"
        ;;
      stageoutputs-large)
        # Same shape as "stageoutputs" but padded to ~380KB — exercises the
        # sibling SIGPIPE direction: the unfixed `awk | grep -q y`
        # stage_outputs-detection pipe can have grep match "y" and exit
        # before awk (itself blocked writing into a full pipe from an
        # upstream printf) is done, SIGPIPEing the chain; the resulting
        # non-zero pipeline exit made the `if pipeline; then return 1; fi`
        # guard silently skip, wrongly granting the exemption to an entity
        # that DOES carry stage_outputs.
        #
        # Padding sits BETWEEN the frontmatter (stage_outputs near the top,
        # so the awk|grep-q-y check races early) and the stage-artifact-links
        # marker (pushed near the END). That keeps the marker-presence check
        # (`printf | grep -q marker`, the OTHER unfixed pipe, already
        # regressed by the "bodytable-large" case above) reading almost the
        # whole buffer before it can match — steady-state drain, not a
        # blocked-writer race — so this fixture isolates the second,
        # sibling SIGPIPE direction instead of conflating both.
        mkdir -p docs/test-wf/large-stageoutputs-entity
        {
          cat <<'EOF'
---
id: "large-stageoutputs-entity"
title: "Large Stage Outputs"
status: sharp
stage_outputs:
  shape: shape.md
---

EOF
          i=0
          while [ "$i" -lt 6000 ]; do
            printf 'padding padding padding padding padding padding padding padding\n'
            i=$((i + 1))
          done
          cat <<'EOF'
<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
        } > docs/test-wf/large-stageoutputs-entity/index.md
        git add docs/test-wf/large-stageoutputs-entity/index.md
        git commit -qm "baseline: add large stage_outputs entity"
        sed -i.bak 's/^status: sharp$/status: plan/' docs/test-wf/large-stageoutputs-entity/index.md
        rm -f docs/test-wf/large-stageoutputs-entity/index.md.bak
        git add docs/test-wf/large-stageoutputs-entity/index.md
        git commit -qm "$mutation_msg"
        ;;
    esac
  )
  echo "$dir"
}

# Build the exact First Officer stage-entry history: an existing flat entity is
# moved from draft to shape on a feature branch, and the supplied commit subject
# is the only receipt C14 can inspect.
setup_fo_dispatch_fixture() {
  local mutation_msg="$1"
  local dir
  dir="$(mktemp -d)"
  (
    cd "$dir" || exit 1
    git init -q -b main
    git config user.email test@test
    git config user.name test

    mkdir -p docs/test-wf
    cat > docs/test-wf/example-feature.md <<'EOF'
---
title: "Example Feature"
status: draft
started:
---
EOF
    git add docs/test-wf/example-feature.md
    git commit -qm "draft: add example feature"

    git checkout -q -b feature
    sed -i.bak 's/^status: draft$/status: shape/' docs/test-wf/example-feature.md
    rm -f docs/test-wf/example-feature.md.bak
    sed -i.bak 's/^started:$/started: 2026-07-12T13:48:06Z/' docs/test-wf/example-feature.md
    rm -f docs/test-wf/example-feature.md.bak
    git add docs/test-wf/example-feature.md
    git commit -qm "$mutation_msg"
  )
  echo "$dir"
}

# Build a feedback-stage transition with independently configurable subject,
# resulting status, and body receipt. The entity carries stage_outputs so C14's
# legacy body-table exemption cannot mask an invalid feedback receipt.
setup_fo_feedback_fixture() {
  local subject="$1" after_status="$2" receipt_cycle="$3" receipt_rejected="$4"
  local receipt_target="$5" captain_decision="$6" routed_at="$7" verify_artifact="$8"
  local commit_body="${9:-}" dir
  dir="$(mktemp -d)"
  (
    cd "$dir" || exit 1
    git init -q -b main
    git config user.email test@test
    git config user.name test

    mkdir -p docs/test-wf/feedback-entity
    cat > docs/test-wf/feedback-entity/index.md <<'EOF'
---
id: "feedback-entity"
title: "Feedback Entity"
status: verify
stage_outputs:
  verify: verify.md
---
EOF
    git add docs/test-wf/feedback-entity/index.md
    git commit -qm "baseline: add verify entity"

    git checkout -q -b feature
    sed -i.bak "s/^status: verify$/status: ${after_status}/" docs/test-wf/feedback-entity/index.md
    rm -f docs/test-wf/feedback-entity/index.md.bak
    cat >> docs/test-wf/feedback-entity/index.md <<EOF

### Feedback Cycles

- cycle: ${receipt_cycle}
  rejected_stage: ${receipt_rejected}
  feedback_to: ${receipt_target}
  captain_decision: ${captain_decision}
  routed_at: ${routed_at}
  verify_artifact: ${verify_artifact}
EOF
    git add docs/test-wf/feedback-entity/index.md
    if [ -n "$commit_body" ]; then
      git commit -q -m "$subject" -m "$commit_body"
    else
      git commit -qm "$subject"
    fi
  )
  echo "$dir"
}

setup_fo_feedback_multi_fixture() {
  local subject="$1" second_target="$2" dir
  dir="$(mktemp -d)"
  (
    cd "$dir" || exit 1
    git init -q -b main
    git config user.email test@test
    git config user.name test
    local entity target
    for entity in feedback-one feedback-two; do
      mkdir -p "docs/test-wf/$entity"
      cat >"docs/test-wf/$entity/index.md" <<EOF
---
id: "$entity"
title: "$entity"
status: verify
stage_outputs:
  verify: verify.md
---
EOF
    done
    git add docs/test-wf/feedback-one/index.md docs/test-wf/feedback-two/index.md
    git commit -qm "baseline: add two verify entities"

    git checkout -q -b feature
    for entity in feedback-one feedback-two; do
      target=execute
      [ "$entity" = feedback-one ] || target="$second_target"
      sed -i.bak 's/^status: verify$/status: execute/' "docs/test-wf/$entity/index.md"
      rm -f "docs/test-wf/$entity/index.md.bak"
      cat >>"docs/test-wf/$entity/index.md" <<EOF

### Feedback Cycles

- cycle: 1
  rejected_stage: verify
  feedback_to: ${target}
  captain_decision: fix
  routed_at: 2026-07-15T11:03:07Z
  verify_artifact: verify.md@ae56c20
EOF
    done
    git add docs/test-wf/feedback-one/index.md docs/test-wf/feedback-two/index.md
    git commit -qm "$subject"
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
echo "--- Case 8: BODY-TABLE entity (stage-artifact-links table, no stage_outputs) manual status edit → PASS (exempt; advance-stage destructive here) [#117] ---"
TMP="$(setup_fixture "execute(bodytable-entity): correct status to plan" "bodytable" "edit")"
assert_exit 0 "run_check_only '$TMP'" "Case-8 body-table manual edit exempt (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 9: STAGE_OUTPUTS entity manual status edit (no signature) → FAIL (advance-stage safe; exemption is narrow) [#117] ---"
TMP="$(setup_fixture "manual hand-edit status to plan" "stageoutputs" "edit")"
assert_exit 1 "run_check_only '$TMP'" "Case-9 stage_outputs manual edit still flagged (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 10 (BLOCKING repro): ONE commit mutating status: on TWO entities — one exempt bodytable (sorts first), one non-exempt stageoutputs — NO signature → FAIL ---"
# Build a fixture where a SINGLE commit mutates both:
#   aaa-bodytable: has body table, NO stage_outputs  (exempt)
#   zzz-stageoutputs: has body table AND stage_outputs  (NOT exempt)
# The commit carries NO advance-stage signature.
# On current code (break after first match → aaa-bodytable, applies single exemption, continues)
# the check silently PASSES. Correct behaviour: check ALL paths → zzz-stageoutputs is not exempt → FAIL.
TMP="$(mktemp -d)"
(
  cd "$TMP" || exit 1
  git init -q -b main
  git config user.email test@test
  git config user.name test

  # Create both entities on main so parent commit exists for ${sha}^
  mkdir -p docs/test-wf/aaa-bodytable
  cat > docs/test-wf/aaa-bodytable/index.md <<'EOF'
---
id: "aaa-bodytable"
title: "Body Table Only"
status: sharp
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
  mkdir -p docs/test-wf/zzz-stageoutputs
  cat > docs/test-wf/zzz-stageoutputs/index.md <<'EOF'
---
id: "zzz-stageoutputs"
title: "Has Stage Outputs"
status: sharp
stage_outputs:
  shape: shape.md
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
  git add docs/test-wf/aaa-bodytable/index.md docs/test-wf/zzz-stageoutputs/index.md
  git commit -qm "baseline: two entities"

  git checkout -q -b feature

  # Mutate BOTH statuses in a single commit, NO signature
  sed -i.bak 's/^status: sharp$/status: plan/' docs/test-wf/aaa-bodytable/index.md
  rm -f docs/test-wf/aaa-bodytable/index.md.bak
  sed -i.bak 's/^status: sharp$/status: plan/' docs/test-wf/zzz-stageoutputs/index.md
  rm -f docs/test-wf/zzz-stageoutputs/index.md.bak
  git add docs/test-wf/aaa-bodytable/index.md docs/test-wf/zzz-stageoutputs/index.md
  git commit -qm "manual: edit two entity statuses (no signature)"
  git update-ref refs/remotes/origin/main "$(git rev-parse main)"
)
assert_exit 1 "run_check_only '$TMP'" "Case-10 two-entity commit: non-exempt path leaks through (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 11 (after-state repro): commit strips stage_outputs AND bumps status, NO signature → FAIL ---"
# Build a fixture where the test commit BOTH removes the stage_outputs: block
# AND mutates status: — without a signature.
# On current code _entity_bodytable_no_stage_outputs reads after-state ($sha)
# and sees no stage_outputs → treats as exempt → PASSES. Correct behaviour:
# read parent ($sha^) which HAS stage_outputs → not exempt → FAIL.
TMP="$(mktemp -d)"
(
  cd "$TMP" || exit 1
  git init -q -b main
  git config user.email test@test
  git config user.name test

  # Baseline entity WITH stage_outputs (advance-stage safe → signature required)
  mkdir -p docs/test-wf/strip-entity
  cat > docs/test-wf/strip-entity/index.md <<'EOF'
---
id: "strip-entity"
title: "Strip Stage Outputs"
status: sharp
stage_outputs:
  shape: shape.md
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
  git add docs/test-wf/strip-entity/index.md
  git commit -qm "baseline: entity with stage_outputs"

  git checkout -q -b feature

  # Single commit: strip stage_outputs block AND advance status — no signature
  cat > docs/test-wf/strip-entity/index.md <<'EOF'
---
id: "strip-entity"
title: "Strip Stage Outputs"
status: plan
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
  git add docs/test-wf/strip-entity/index.md
  git commit -qm "manual: strip stage_outputs and bump status (no signature)"
  git update-ref refs/remotes/origin/main "$(git rev-parse main)"
)
assert_exit 1 "run_check_only '$TMP'" "Case-11 strip-stage_outputs after-state bypass: correctly flagged (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 12 (SIGPIPE repro): LARGE (>100KB) body-table entity, marker near top, manual status edit → PASS (exempt; #C14-pipefail) ---"
# Regresses PR #14 CI-red root cause: _entity_bodytable_no_stage_outputs's
# marker check used `printf | grep -q`. On an entity whose parent-rev
# index.md exceeds the kernel pipe-buffer size, grep -q can match and exit
# before printf finishes writing, SIGPIPEing printf; under `set -o
# pipefail` that non-zero exit was misread as "no marker" and this
# legitimate body-table entity LOST its exemption. Deterministic on this
# fixture size (verified via direct repro before wiring this case in).
TMP="$(setup_fixture "execute(large-bodytable-entity): correct status to plan" "bodytable-large" "edit")"
assert_exit 0 "run_check_only '$TMP'" "Case-12 large body-table manual edit exempt (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 13 (SIGPIPE repro, reverse direction): LARGE (~380KB) stage_outputs entity, marker near the end, manual status edit → FAIL (advance-stage safe; exemption is narrow) ---"
# Sibling of Case 12: the stage_outputs check used
# `printf | awk ... | grep -q y` inside `if PIPELINE; then return 1; fi`.
# grep -q y matching and exiting early can SIGPIPE the still-writing
# upstream, making the pipeline's pipefail-propagated exit non-zero even
# though stage_outputs IS present — the `if` then silently falls through
# and wrongly grants the exemption. This entity DOES carry stage_outputs
# and must still be flagged. See the "stageoutputs-large" fixture comment
# for why the marker sits near the end here (isolates this pipe's race
# from the marker-check pipe's own race, regressed separately by Case 12).
TMP="$(setup_fixture "manual hand-edit status to plan" "stageoutputs-large" "edit")"
assert_exit 1 "run_check_only '$TMP'" "Case-13 large stage_outputs manual edit still flagged (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 14: FO STAGE-ENTRY receipt (draft→shape, canonical subject + resulting stage) → PASS ---"
TMP="$(setup_fo_dispatch_fixture "dispatch: example-feature entering shape")"
assert_exit 0 "run_check_only '$TMP'" "Case-14 canonical FO draft-to-shape dispatch passes (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 15: FO LOOKALIKE receipt (non-canonical verb) → FAIL ---"
TMP="$(setup_fo_dispatch_fixture "dispatch: example-feature enters shape")"
assert_exit 1 "run_check_only '$TMP'" "Case-15 FO dispatch receipt requires canonical entering grammar (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 16: FO LOOKALIKE receipt (wrong resulting stage) → FAIL ---"
TMP="$(setup_fo_dispatch_fixture "dispatch: example-feature entering plan")"
assert_exit 1 "run_check_only '$TMP'" "Case-16 FO dispatch receipt must name the resulting stage (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 17: FO REUSE STAGE-ENTRY receipt (advance subject, exact resulting stage) → PASS ---"
TMP="$(setup_fo_dispatch_fixture "advance: example-feature entering shape")"
assert_exit 0 "run_check_only '$TMP'" "Case-17 canonical FO reuse-stage entry passes (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 18: FO LOOKALIKE receipt (whitespace-only summary) → FAIL ---"
TMP="$(setup_fo_dispatch_fixture "dispatch:   entering shape")"
assert_exit 1 "run_check_only '$TMP'" "Case-18 FO dispatch receipt requires a non-whitespace summary (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 19: FO FEEDBACK receipt (verify cycle 1 → execute, canonical subject/body/status) → PASS ---"
TMP="$(setup_fo_feedback_fixture "feedback: feedback-entity verify cycle 1 to execute" execute 1 verify execute fix 2026-07-15T11:03:07Z verify.md@ae56c20)"
assert_exit 0 "run_check_only '$TMP'" "Case-19 canonical FO feedback receipt passes (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 20: FO FEEDBACK wrong resulting status → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: feedback-entity verify cycle 1 to execute" plan 1 verify execute fix 2026-07-15T11:03:07Z verify.md@ae56c20)"
assert_exit 1 "run_check_only '$TMP'" "Case-20 feedback target must equal resulting status (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 21: FO FEEDBACK rejected-stage mismatch between subject and body → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: feedback-entity review cycle 1 to execute" execute 1 verify execute fix 2026-07-15T11:03:07Z verify.md@ae56c20)"
assert_exit 1 "run_check_only '$TMP'" "Case-21 feedback rejected stage must match body (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 22: FO FEEDBACK cycle mismatch between subject and body → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: feedback-entity verify cycle 2 to execute" execute 1 verify execute fix 2026-07-15T11:03:07Z verify.md@ae56c20)"
assert_exit 1 "run_check_only '$TMP'" "Case-22 feedback cycle must match body (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 23: FO FEEDBACK target mismatch between subject and body → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: feedback-entity verify cycle 1 to execute" execute 1 verify plan fix 2026-07-15T11:03:07Z verify.md@ae56c20)"
assert_exit 1 "run_check_only '$TMP'" "Case-23 feedback target must match body (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 24: FO FEEDBACK non-canonical subject grammar → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: feedback-entity verify cycle 1 into execute" execute 1 verify execute fix 2026-07-15T11:03:07Z verify.md@ae56c20)"
assert_exit 1 "run_check_only '$TMP'" "Case-24 feedback subject requires canonical grammar (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 25: FO FEEDBACK canonical text in commit body only → FAIL ---"
TMP="$(setup_fo_feedback_fixture "manual: route feedback" execute 1 verify execute fix 2026-07-15T11:03:07Z verify.md@ae56c20 "feedback: feedback-entity verify cycle 1 to execute")"
assert_exit 1 "run_check_only '$TMP'" "Case-25 feedback receipt is subject-only (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 26: FO FEEDBACK non-fix captain decision → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: feedback-entity verify cycle 1 to execute" execute 1 verify execute defer 2026-07-15T11:03:07Z verify.md@ae56c20)"
assert_exit 1 "run_check_only '$TMP'" "Case-26 feedback body requires captain fix decision (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 27: FO FEEDBACK malformed routed timestamp → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: feedback-entity verify cycle 1 to execute" execute 1 verify execute fix not-a-time verify.md@ae56c20)"
assert_exit 1 "run_check_only '$TMP'" "Case-27 feedback body requires canonical routed time (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 28: FO FEEDBACK mismatched verify artifact provenance → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: feedback-entity verify cycle 1 to execute" execute 1 verify execute fix 2026-07-15T11:03:07Z review.md@deadbee)"
assert_exit 1 "run_check_only '$TMP'" "Case-28 feedback artifact must match rejected stage (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 29: FO FEEDBACK multi-entity commit requires matching receipt on every path → FAIL ---"
TMP="$(setup_fo_feedback_multi_fixture "feedback: feedback entities verify cycle 1 to execute" plan)"
assert_exit 1 "run_check_only '$TMP'" "Case-29 feedback receipt binds every mutated entity path (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 30: FO FEEDBACK rejected stage must equal parent status → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: feedback-entity review cycle 1 to execute" execute 1 review execute fix 2026-07-15T11:03:07Z review.md@deadbee)"
assert_exit 1 "run_check_only '$TMP'" "Case-30 feedback rejected stage binds parent status (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 31: FO FEEDBACK impossible routed calendar timestamp → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: feedback-entity verify cycle 1 to execute" execute 1 verify execute fix 2026-99-99T99:99:99Z verify.md@ae56c20)"
assert_exit 1 "run_check_only '$TMP'" "Case-31 feedback routed time must be a real UTC instant (exit 1)"
rm -rf "$TMP"

echo
if [ "$FAIL" = "0" ]; then
  echo "All test-enforce-advance-stage cases passed."
  exit 0
else
  echo "FAIL: test-enforce-advance-stage has failures."
  exit 1
fi
