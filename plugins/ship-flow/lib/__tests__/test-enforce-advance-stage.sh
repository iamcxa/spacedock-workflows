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
#       $4 = target status for mutations (default: plan)
#
# Returns: prints the path of the repo dir.
setup_fixture() {
  local mutation_msg="$1" kind="$2" entity_age="$3" target_status="${4:-plan}"
  local dir
  dir="$(mktemp -d)"
  (
    cd "$dir" || exit 1
    git init -q -b main
    git config user.email test@test
    git config user.name test

    # Always: declare the workflow graph and create a baseline entity on `main`.
    mkdir -p docs/test-wf/baseline-entity
    cat > docs/test-wf/README.md <<'EOF'
---
stages:
  states:
    - name: sharp
    - name: plan
    - name: execute
    - name: verify
    - name: ship
    - name: done
---
EOF
    cat > docs/test-wf/baseline-entity/index.md <<'EOF'
---
id: "baseline-entity"
title: "Baseline"
status: sharp
---
EOF
    git add docs/test-wf/README.md docs/test-wf/baseline-entity/index.md
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
          sed -i.bak "s/^status: sharp$/status: ${target_status}/" docs/test-wf/baseline-entity/index.md
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
        sed -i.bak "s/^status: sharp$/status: ${target_status}/" docs/test-wf/bodytable-entity/index.md
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

# Build an exact First Officer stage-entry history for a workflow whose legal
# forward edges come from README stage order and whose verify stage may route
# feedback back to execute.
setup_fo_dispatch_fixture() {
  local mutation_msg="$1" before_status="${2:-draft}" after_status="${3:-shape}" readme_style="${4:-lf}" entity_slug="${5:-example-feature}"
  local dir
  dir="$(mktemp -d)"
  (
    cd "$dir" || exit 1
    git init -q -b main
    git config user.email test@test
    git config user.name test

    mkdir -p docs/test-wf
    cat > docs/test-wf/README.md <<'EOF'
---
stages:
  states:
    - name: draft
    - name: shape
    - name: design
    - name: plan
    - name: execute
    - name: verify
      feedback-to: execute
    - name: ship
    - name: done
---
EOF
    case "$readme_style" in
      crlf-trailing)
        awk '{
          if ($0 ~ /name:|feedback-to:/) printf "%s  \r\n", $0
          else printf "%s\r\n", $0
        }' docs/test-wf/README.md > docs/test-wf/README.md.tmp
        mv docs/test-wf/README.md.tmp docs/test-wf/README.md
        ;;
      unrelated-list)
        cat > docs/test-wf/README.md <<'EOF'
---
stages:
  states:
    - name: draft
    - name: shape
reviewers:
  - name: plan
---
EOF
        ;;
      nested-stages)
        cat > docs/test-wf/README.md <<'EOF'
---
metadata:
  stages:
    states:
      - name: draft
      - name: plan
---
EOF
        ;;
      nested-stage-name)
        cat > docs/test-wf/README.md <<'EOF'
---
stages:
  states:
    - name: draft
      reviewers:
        - name: plan
    - name: shape
---
EOF
        ;;
      nested-feedback)
        cat > docs/test-wf/README.md <<'EOF'
---
stages:
  states:
    - name: draft
    - name: shape
      metadata:
        feedback-to: draft
---
EOF
        ;;
    esac
    cat > "docs/test-wf/${entity_slug}.md" <<'EOF'
---
title: "Example Feature"
status: STATUS_PLACEHOLDER
started:
---
EOF
    sed -i.bak "s/^status: STATUS_PLACEHOLDER$/status: ${before_status}/" "docs/test-wf/${entity_slug}.md"
    rm -f "docs/test-wf/${entity_slug}.md.bak"
    git add docs/test-wf/README.md "docs/test-wf/${entity_slug}.md"
    git commit -qm "draft: add example feature"

    git checkout -q -b feature
    sed -i.bak "s/^status: ${before_status}$/status: ${after_status}/" "docs/test-wf/${entity_slug}.md"
    rm -f "docs/test-wf/${entity_slug}.md.bak"
    sed -i.bak 's/^started:$/started: 2026-07-12T13:48:06Z/' "docs/test-wf/${entity_slug}.md"
    rm -f "docs/test-wf/${entity_slug}.md.bak"
    git add "docs/test-wf/${entity_slug}.md"
    git commit -qm "$mutation_msg"
  )
  echo "$dir"
}

# Build an exact First Officer feedback-stage-receipt history on the same
# workflow graph as setup_fo_dispatch_fixture (verify's declared feedback-to
# is execute). $5 is raw body text appended verbatim to the entity file on
# the mutation (feature-branch) commit — a canonical ### Feedback Cycles
# record, an empty string (no record at all), or a forged/broken record, per
# case. $6 (optional) is raw body text appended on the BASELINE (main/parent)
# commit instead — used to construct a PARENT revision that already carries
# Feedback Cycles history, for freshness/monotonic-cycle cases.
# shellcheck disable=SC2329 # invoked indirectly through assert_exit/eval cases below
setup_fo_feedback_fixture() {
  local mutation_msg="$1" before_status="${2:-verify}" after_status="${3:-execute}" entity_slug="${4:-example-feature}" feedback_body="${5:-}" parent_feedback_body="${6:-}"
  local dir
  dir="$(mktemp -d)"
  (
    cd "$dir" || exit 1
    git init -q -b main
    git config user.email test@test
    git config user.name test

    mkdir -p docs/test-wf
    cat > docs/test-wf/README.md <<'EOF'
---
stages:
  states:
    - name: draft
    - name: shape
    - name: design
    - name: plan
    - name: execute
    - name: verify
      feedback-to: execute
    - name: ship
    - name: done
---
EOF
    cat > "docs/test-wf/${entity_slug}.md" <<EOF
---
title: "Example Feature"
status: ${before_status}
---
EOF
    if [ -n "$parent_feedback_body" ]; then
      printf '%s\n' "$parent_feedback_body" >> "docs/test-wf/${entity_slug}.md"
    fi
    git add docs/test-wf/README.md "docs/test-wf/${entity_slug}.md"
    git commit -qm "draft: add example feature"

    git checkout -q -b feature
    sed -i.bak "s/^status: ${before_status}$/status: ${after_status}/" "docs/test-wf/${entity_slug}.md"
    rm -f "docs/test-wf/${entity_slug}.md.bak"
    if [ -n "$feedback_body" ]; then
      printf '%s\n' "$feedback_body" >> "docs/test-wf/${entity_slug}.md"
    fi
    git add "docs/test-wf/${entity_slug}.md"
    git commit -qm "$mutation_msg"
  )
  echo "$dir"
}

# Build one commit with a skipped transition on an exempt body-table entity and
# a legal transition on a non-exempt entity. A completion-looking signature must
# not let the legal path hide the illegal one.
setup_mixed_transition_fixture() {
  local dir
  dir="$(mktemp -d)"
  (
    cd "$dir" || exit 1
    git init -q -b main
    git config user.email test@test
    git config user.name test

    mkdir -p docs/test-wf/aaa-bodytable docs/test-wf/zzz-stageoutputs
    cat > docs/test-wf/README.md <<'EOF'
---
stages:
  states:
    - name: sharp
    - name: plan
    - name: execute
---
EOF
    cat > docs/test-wf/aaa-bodytable/index.md <<'EOF'
---
id: "aaa-bodytable"
status: sharp
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
    cat > docs/test-wf/zzz-stageoutputs/index.md <<'EOF'
---
id: "zzz-stageoutputs"
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
    git add docs/test-wf
    git commit -qm "baseline: add mixed transition entities"

    git checkout -q -b feature
    sed -i.bak 's/^status: sharp$/status: execute/' docs/test-wf/aaa-bodytable/index.md
    rm -f docs/test-wf/aaa-bodytable/index.md.bak
    sed -i.bak 's/^status: sharp$/status: plan/' docs/test-wf/zzz-stageoutputs/index.md
    rm -f docs/test-wf/zzz-stageoutputs/index.md.bak
    git add docs/test-wf/aaa-bodytable/index.md docs/test-wf/zzz-stageoutputs/index.md
    git commit -qm "plan(mixed): advance status to plan"
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

# shellcheck disable=SC2329 # invoked indirectly through assert_exit/eval below
run_check_only_from_subdir() {
  local repo_dir="$1"
  (
    cd "$repo_dir/docs/test-wf" || exit 1
    # Exercise C14 from below the repository root. Its pathspecs must remain
    # rooted at the worktree rather than inheriting this command prefix.
    git update-ref refs/remotes/origin/main "$(git rev-parse main)"
    bash "${BIN_DIR}/check-invariants.sh" --check entity-status-via-advance-stage-only
  )
}

# Run C14 with a Git wrapper that fails one enumeration/receipt lookup. The
# fixture setup and origin/main update still use the real Git binary so each
# assertion isolates checker plumbing rather than fixture construction.
# shellcheck disable=SC2329 # invoked indirectly through assert_exit/eval below
run_check_only_with_git_fault() {
  local repo_dir="$1" wrapper_dir="$2" fault_mode="$3"
  (
    cd "$repo_dir" || exit 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)"
    PATH="${wrapper_dir}:${PATH}" GIT_FAULT_MODE="$fault_mode" \
      bash "${BIN_DIR}/check-invariants.sh" --check entity-status-via-advance-stage-only
  )
}

setup_git_fault_wrapper() {
  local wrapper_dir real_git
  wrapper_dir="$(mktemp -d)"
  real_git="$(command -v git)"
  cat > "${wrapper_dir}/git" <<EOF
#!/usr/bin/env bash
set -u
mode="\${GIT_FAULT_MODE:-}"
case "\$mode" in
  range-log)
    if [ "\${1:-}" = "log" ]; then
      for arg in "\$@"; do
        [ "\$arg" = "--format=%H" ] && exit 77
      done
    fi
    ;;
  diff-tree)
    [ "\${1:-}" = "diff-tree" ] && exit 77
    ;;
  subject-log)
    if [ "\${1:-}" = "log" ]; then
      for arg in "\$@"; do
        [ "\$arg" = "--format=%s" ] && exit 77
      done
    fi
    ;;
esac
exec "${real_git}" "\$@"
EOF
  chmod +x "${wrapper_dir}/git"
  echo "$wrapper_dir"
}

echo "--- Case 1: BYPASS commit (mutate status:, no advance-stage signature) → FAIL ---"
TMP="$(setup_fixture "manual hand-edit status to plan" "mutate" "edit")"
assert_exit 1 "run_check_only '$TMP'" "Case-1 bypass detected (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 2: COMPLETION receipt on a legal edge cannot impersonate FO stage entry → FAIL ---"
TMP="$(setup_fixture "plan(baseline-entity): advance status to plan" "mutate" "edit")"
assert_exit 1 "run_check_only '$TMP'" "Case-2 completion receipt cannot authorize next-stage entry (exit 1)"
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
echo "--- Case 8: BODY-TABLE-only entity manual status edit → FAIL (historical body is non-authoritative) ---"
TMP="$(setup_fixture "execute(bodytable-entity): correct status to plan" "bodytable" "edit")"
assert_exit 1 "run_check_only '$TMP'" "Case-8 body-table-only manual edit requires Contract 1 (exit 1)"
rm -rf "$TMP"

TMP="$(setup_fixture "dispatch: bodytable-entity enters plan" "bodytable" "edit")"
assert_exit 1 "run_check_only '$TMP'" "Case-8 malformed FO-shaped dispatch cannot use ownerless exemption (exit 1)"
rm -rf "$TMP"

TMP="$(setup_fixture "advance: bodytable-entity entering execute" "bodytable" "edit")"
assert_exit 1 "run_check_only '$TMP'" "Case-8 FO-shaped receipt must bind actual resulting stage before exemption (exit 1)"
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
echo "--- Case 12 (SIGPIPE repro): LARGE (>100KB) body-table-only manual status edit → FAIL Contract 1 ---"
# Regresses PR #14 CI-red root cause: _entity_bodytable_no_stage_outputs's
# marker check used `printf | grep -q`. On an entity whose parent-rev
# index.md exceeds the kernel pipe-buffer size, grep -q can match and exit
# before printf finishes writing, SIGPIPEing printf; under `set -o
# pipefail` that non-zero exit was misread as "no marker" and this
# obsolete exemption once depended on pipe timing. Deterministic on this
# fixture size (verified via direct repro before wiring this case in).
TMP="$(setup_fixture "execute(large-bodytable-entity): correct status to plan" "bodytable-large" "edit")"
assert_exit 1 "run_check_only '$TMP'" "Case-12 large body-table-only manual edit requires Contract 1 (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 13 (SIGPIPE repro, reverse direction): LARGE (~380KB) stage_outputs entity, manual status edit → FAIL Contract 1 ---"
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
echo "--- Case 19: FO SKIPPED transition (draft→plan, canonical-looking subject) → FAIL ---"
TMP="$(setup_fo_dispatch_fixture "dispatch: example-feature entering plan" draft plan)"
assert_exit 1 "run_check_only '$TMP'" "Case-19 FO receipt cannot skip declared workflow stages (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 20: FO BACKWARD transition without feedback edge (shape→draft) → FAIL ---"
TMP="$(setup_fo_dispatch_fixture "advance: example-feature entering draft" shape draft)"
assert_exit 1 "run_check_only '$TMP'" "Case-20 FO receipt cannot move backward without a declared feedback edge (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 21: FO DECLARED FEEDBACK transition (verify→execute) → PASS ---"
TMP="$(setup_fo_dispatch_fixture "dispatch: example-feature entering execute" verify execute)"
assert_exit 0 "run_check_only '$TMP'" "Case-21 FO receipt accepts a declared workflow feedback edge (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 22: BODY-TABLE exemption cannot skip workflow stages (sharp→execute) → FAIL ---"
TMP="$(setup_fixture "manual body-table correction to execute" bodytable edit execute)"
assert_exit 1 "run_check_only '$TMP'" "Case-22 body-table exemption preserves transition-graph enforcement (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 23: COMPLETION signature cannot authorize body-table skipped stage → FAIL ---"
TMP="$(setup_fixture "execute(bodytable): advance status to execute" bodytable edit execute)"
assert_exit 1 "run_check_only '$TMP'" "Case-23 completion signature cannot bypass body-table transition graph (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 24: CRLF + trailing-space workflow stages still match legal edge → PASS ---"
TMP="$(setup_fo_dispatch_fixture "dispatch: example-feature entering shape" draft shape crlf-trailing)"
assert_exit 0 "run_check_only '$TMP'" "Case-24 workflow graph parser normalizes CRLF and trailing whitespace (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 25: MIXED commit validates every transition before completion receipt → FAIL ---"
TMP="$(setup_mixed_transition_fixture)"
assert_exit 1 "run_check_only '$TMP'" "Case-25 legal non-exempt path cannot hide illegal exempt transition (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 26: ROOT sibling list names are not workflow stages → FAIL ---"
TMP="$(setup_fo_dispatch_fixture "advance: example-feature entering plan" shape plan unrelated-list)"
assert_exit 1 "run_check_only '$TMP'" "Case-26 parser stops at the next root-level frontmatter key (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 27: CRLF commit subject still matches canonical receipt → PASS ---"
TMP="$(setup_fo_dispatch_fixture $'dispatch: example-feature entering shape\r')"
assert_exit 0 "run_check_only '$TMP'" "Case-27 FO subject normalization accepts CRLF-formatted commit text (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 28: SINGLE-WORD flat slug remains inside C14 scope → FAIL ---"
TMP="$(setup_fo_dispatch_fixture "dispatch: task entering plan" draft plan lf task)"
assert_exit 1 "run_check_only '$TMP'" "Case-28 single-word flat entity cannot bypass transition validation (exit 1)"
assert_exit 1 "run_check_only_from_subdir '$TMP'" "Case-28 subdirectory invocation cannot bypass single-word flat entity validation (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 29: NESTED decoy stages list is not a workflow graph → FAIL ---"
TMP="$(setup_fo_dispatch_fixture "dispatch: example-feature entering plan" draft plan nested-stages)"
assert_exit 1 "run_check_only '$TMP'" "Case-29 parser ignores nested stages keys outside the root workflow graph (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 30: NESTED named list inside a state is not another stage → FAIL ---"
TMP="$(setup_fo_dispatch_fixture "dispatch: example-feature entering plan" draft plan nested-stage-name)"
assert_exit 1 "run_check_only '$TMP'" "Case-30 parser requires canonical stage-item indentation (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 31: NESTED feedback metadata is not a workflow feedback edge → FAIL ---"
TMP="$(setup_fo_dispatch_fixture "advance: example-feature entering draft" shape draft nested-feedback)"
assert_exit 1 "run_check_only '$TMP'" "Case-31 parser requires canonical feedback-to indentation (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 31: Git enumeration and receipt lookups fail closed ---"
GIT_FAULT_WRAPPER="$(setup_git_fault_wrapper)"

TMP="$(setup_fixture "manual hand-edit status to plan" "mutate" "edit")"
assert_exit 1 "run_check_only_with_git_fault '$TMP' '$GIT_FAULT_WRAPPER' range-log" "Case-31 range-log failure is not an empty successful scan (exit 1)"
assert_exit 1 "run_check_only_with_git_fault '$TMP' '$GIT_FAULT_WRAPPER' diff-tree" "Case-31 diff-tree failure is not an unchanged entity (exit 1)"
rm -rf "$TMP"

TMP="$(setup_fixture "manual body-table correction to plan" "bodytable" "edit")"
assert_exit 1 "run_check_only_with_git_fault '$TMP' '$GIT_FAULT_WRAPPER' subject-log" "Case-31 subject lookup failure cannot select ownerless compatibility (exit 1)"
rm -rf "$TMP" "$GIT_FAULT_WRAPPER"

# ---- FO feedback-stage receipt cases (Principle 15 third receipt kind) ----
# Canonical/forged ### Feedback Cycles body records shared by Cases 32-38.
FB_VALID=$'\n### Feedback Cycles\n\n- cycle: 1\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: verify.md@abc1234\n'
FB_MISMATCH_CYCLE=$'\n### Feedback Cycles\n\n- cycle: 2\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: verify.md@abc1234\n'
FB_WRONG_DECISION=$'\n### Feedback Cycles\n\n- cycle: 1\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: hold\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: verify.md@abc1234\n'
FB_BAD_TIMESTAMP=$'\n### Feedback Cycles\n\n- cycle: 1\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-12 13:48:06\n  verify_artifact: verify.md@abc1234\n'
FB_BAD_ARTIFACT=$'\n### Feedback Cycles\n\n- cycle: 1\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: execute.md@abc1234\n'
FB_DUPLICATE_SECTION=$'\n### Feedback Cycles\n\n- cycle: 1\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: verify.md@abc1234\n\n### Feedback Cycles\n\n- cycle: 1\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: verify.md@abc1234\n'

echo
echo "--- Case 32: FEEDBACK canonical receipt (verify->execute, matching body record) → PASS ---"
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "$FB_VALID")"
assert_exit 0 "run_check_only '$TMP'" "Case-32 canonical FO feedback-stage receipt passes (exit 0)"
rm -rf "$TMP"

echo
echo "--- Case 33: FEEDBACK FORGED — subject with no Feedback Cycles record at all → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "")"
assert_exit 1 "run_check_only '$TMP'" "Case-33 forged feedback subject without a body record is rejected (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 34: FEEDBACK FORGED — body record cycle mismatches subject cycle → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "$FB_MISMATCH_CYCLE")"
assert_exit 1 "run_check_only '$TMP'" "Case-34 mismatched cycle number cannot authorize the receipt (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 35: FEEDBACK FORGED — captain_decision is not fix → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "$FB_WRONG_DECISION")"
assert_exit 1 "run_check_only '$TMP'" "Case-35 non-fix captain_decision cannot authorize the receipt (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 36: FEEDBACK FORGED — routed_at is not valid UTC RFC3339 → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "$FB_BAD_TIMESTAMP")"
assert_exit 1 "run_check_only '$TMP'" "Case-36 malformed routed_at cannot authorize the receipt (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 37: FEEDBACK FORGED — verify_artifact names the wrong stage → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "$FB_BAD_ARTIFACT")"
assert_exit 1 "run_check_only '$TMP'" "Case-37 verify_artifact stage mismatch cannot authorize the receipt (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 38: FEEDBACK FORGED — duplicate Feedback Cycles sections → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "$FB_DUPLICATE_SECTION")"
assert_exit 1 "run_check_only '$TMP'" "Case-38 duplicate Feedback Cycles sections cannot authorize the receipt (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 39: FEEDBACK over a NON-feedback edge (graph gate blocks before receipt case) → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: example-feature shape cycle 1 to execute" shape execute example-feature "$FB_VALID")"
assert_exit 1 "run_check_only '$TMP'" "Case-39 feedback subject cannot bless an undeclared graph edge (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 40: FEEDBACK malformed subject grammar — missing 'cycle N' → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify to execute" verify execute example-feature "$FB_VALID")"
assert_exit 1 "run_check_only '$TMP'" "Case-40 feedback receipt requires the cycle keyword and number (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 41: FEEDBACK malformed subject grammar — missing 'to <target>' → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 execute" verify execute example-feature "$FB_VALID")"
assert_exit 1 "run_check_only '$TMP'" "Case-41 feedback receipt requires the 'to <target>' clause (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 42: FEEDBACK malformed subject grammar — uppercase target stage → FAIL ---"
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to EXECUTE" verify execute example-feature "$FB_VALID")"
assert_exit 1 "run_check_only '$TMP'" "Case-42 feedback receipt requires lowercase canonical stage grammar (exit 1)"
rm -rf "$TMP"

# ---- Codex-found authority-gap regressions (feedback-to-edge bind,
# stale-record replay + monotonic cycle, fence-safety, bounded cycle) ----

echo
echo "--- Case 43: FEEDBACK subject over a NEXT-STAGE edge that is NOT the rejected stage's declared feedback-to → FAIL (P1-#1) ---"
# execute->verify IS a legal graph edge (the declared NEXT stage per README
# order), but it is NOT execute's feedback-to (only verify declares
# feedback-to: execute). A forged feedback: receipt + matching body record
# over this forward edge must still be rejected — the shared graph gate
# alone (legal edge, forward or feedback) is not sufficient authority.
FB_EXECUTE_TO_VERIFY=$'\n### Feedback Cycles\n\n- cycle: 1\n  rejected_stage: execute\n  feedback_to: verify\n  captain_decision: fix\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: execute.md@abc1234\n'
TMP="$(setup_fo_feedback_fixture "feedback: example-feature execute cycle 1 to verify" execute verify example-feature "$FB_EXECUTE_TO_VERIFY")"
assert_exit 1 "run_check_only '$TMP'" "Case-43 feedback receipt cannot bless a merely-legal forward edge as if it were the feedback-to edge (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 44: FEEDBACK reusing an UNCHANGED parent cycle record (no newly-added record) → FAIL (P1-#2 freshness) ---"
# Parent already carries the exact cycle-1 record (FB_VALID). The mutation
# commit changes status: verify->execute but appends NOTHING new — the
# "evidence" is stale, byte-identical, pre-existing parent content, not
# fresh routing evidence produced by THIS commit.
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "" "$FB_VALID")"
assert_exit 1 "run_check_only '$TMP'" "Case-44 stale unchanged parent cycle record cannot authorize the receipt (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 45: FEEDBACK non-monotonic — new record's cycle is LOWER than an already-recorded parent cycle → FAIL (P1-#2 monotonic) ---"
# Parent already has cycle 2 on record. The mutation commit appends a
# genuinely NEW, distinct record (different routed_at/verify_artifact, so it
# passes the freshness check) but claims cycle 1 — lower than the entity's
# already-recorded maximum. Cycle numbering must be monotonic per entity.
FB_PARENT_CYCLE2=$'\n### Feedback Cycles\n\n- cycle: 2\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-10T10:00:00Z\n  verify_artifact: verify.md@aaaa111\n'
FB_CHILD_NEW_CYCLE1=$'- cycle: 1\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: verify.md@bbbb222\n'
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "$FB_CHILD_NEW_CYCLE1" "$FB_PARENT_CYCLE2")"
assert_exit 1 "run_check_only '$TMP'" "Case-45 non-monotonic (lower) cycle number cannot authorize the receipt (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 46: FEEDBACK record's ONLY appearance is inside a fenced code block → FAIL (P1-#3 fence-safety) ---"
# The entity carries no real top-level ### Feedback Cycles section — only a
# fenced ``` block containing what looks like a canonical record. Fenced
# example content must never manufacture authority.
FB_FENCED_ONLY=$'\n```\n### Feedback Cycles\n\n- cycle: 1\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: verify.md@abc1234\n```\n'
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "$FB_FENCED_ONLY")"
assert_exit 1 "run_check_only '$TMP'" "Case-46 fenced-code-block record cannot authorize the receipt (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 47: FEEDBACK over-long/huge cycle number in the subject → FAIL (P2 bounded cycle) ---"
# Cycle digit run exceeds the 9-digit canonical cap. Must be rejected as
# malformed grammar before any body-record comparison is attempted.
FB_HUGE_CYCLE=$'\n### Feedback Cycles\n\n- cycle: 123456789012\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: verify.md@abc1234\n'
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 123456789012 to execute" verify execute example-feature "$FB_HUGE_CYCLE")"
assert_exit 1 "run_check_only '$TMP'" "Case-47 over-long cycle number cannot authorize the receipt (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 48: FEEDBACK record inside a REAL \`\`\`-fence whose only 'closing' marker is TAB-indented → FAIL (codex round-2 P1 tab-fence bypass) ---"
# The outer fence opens unindented, so from CommonMark's view the WHOLE block
# up to the final unindented \`\`\` is one code fence — the tab-indented \`\`\`
# mid-block is not a valid ≤3-space-indented closer, so it never actually
# closes anything. A checker that treats [[:space:]] (which matches TAB) as
# equivalent to CommonMark's 0-3-SPACE indent would wrongly let that
# tab-indented line close the fence early, re-exposing the embedded
# "### Feedback Cycles" record as if it were live, unfenced content.
FB_TAB_FAKE_CLOSE_BACKTICK=$'\n```\n\t```\n### Feedback Cycles\n\n- cycle: 1\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: verify.md@abc1234\n```\n'
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "$FB_TAB_FAKE_CLOSE_BACKTICK")"
assert_exit 1 "run_check_only '$TMP'" "Case-48 tab-indented fake closing backtick-fence marker cannot authorize the receipt (exit 1)"
rm -rf "$TMP"

echo
echo "--- Case 49: FEEDBACK record inside a REAL ~~~-fence whose only 'closing' marker is TAB-indented → FAIL (codex round-2 P1 tab-fence bypass, tilde variant) ---"
FB_TAB_FAKE_CLOSE_TILDE=$'\n~~~\n\t~~~\n### Feedback Cycles\n\n- cycle: 1\n  rejected_stage: verify\n  feedback_to: execute\n  captain_decision: fix\n  routed_at: 2026-07-12T13:48:06Z\n  verify_artifact: verify.md@abc1234\n~~~\n'
TMP="$(setup_fo_feedback_fixture "feedback: example-feature verify cycle 1 to execute" verify execute example-feature "$FB_TAB_FAKE_CLOSE_TILDE")"
assert_exit 1 "run_check_only '$TMP'" "Case-49 tab-indented fake closing tilde-fence marker cannot authorize the receipt (exit 1)"
rm -rf "$TMP"

echo
if [ "$FAIL" = "0" ]; then
  echo "All test-enforce-advance-stage cases passed."
  exit 0
else
  echo "FAIL: test-enforce-advance-stage has failures."
  exit 1
fi
