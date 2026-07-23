#!/usr/bin/env bash
# test-stage-wiring.sh — DC-2/DC-3/DC-4/DC-5 integration test for stage wiring
# Drives the real folder-layout shape producer, separate FO stage entries, and
# status-idempotent completion registration while preserving both registries.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
BIN_DIR="$(cd "${LIB_DIR}/../bin" && pwd)"
REPO_ROOT="$(cd "${LIB_DIR}/../../.." && pwd)"
FAIL=0

assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  (eval "$cmd") >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'
  fi
}

cd "$REPO_ROOT" || exit 1

LIFECYCLE_HELPER="$LIB_DIR/fo-completion-lifecycle.sh"
if [ ! -f "$LIFECYCLE_HELPER" ]; then
  echo "FAIL production completion lifecycle seam missing"
  exit 1
fi
# shellcheck disable=SC1090 # production helper is resolved from this test's lib directory
source "$LIFECYCLE_HELPER"
if ! type fo_completion_begin >/dev/null 2>&1 || ! type fo_completion_checkpoint >/dev/null 2>&1; then
  echo "FAIL production completion lifecycle functions unavailable"
  exit 1
fi
COMPLETION_LIFECYCLE_ONLY=0
case "${1:-}" in --completion-lifecycle|--completion-lifecycle-faults|--plan-attempt) COMPLETION_LIFECYCLE_ONLY=1 ;; esac

assert_ship_completion_wiring() {
  if type fo_completion_begin >/dev/null 2>&1 && type fo_completion_checkpoint >/dev/null 2>&1; then
    echo "OK ship completion-v1 FO production seam"
  else
    echo "FAIL ship completion-v1 FO production seam"; FAIL=1
  fi
}

if [ "$COMPLETION_LIFECYCLE_ONLY" = 0 ]; then
echo "=== Ship production completion-v1 FO wiring ==="
assert_ship_completion_wiring
[ "${1:-}" != --check-ship-completion-wiring ] || exit "$FAIL"

echo "=== DC-1 verify: completion publication and FO reconcile remain separate ==="
SKILL_REFS="$(grep -rE "advance-stage\.sh" "$REPO_ROOT/plugins/ship-flow/skills/" | grep -c "advance-stage" || true)"
CAS_REFS="$(grep -Fc "git update-ref \"\$ref\" \"\$completion\" \"\$before\"" "$REPO_ROOT/plugins/ship-flow/lib/advance-stage.sh" || true)"
RECONCILE_REFS="$(grep -Fc "git restore --source=\"\$COMPLETION\" --staged --worktree -- \"\$ENTITY\"" "$REPO_ROOT/plugins/ship-flow/lib/fo-reconcile-completion.sh" || true)"
FORBIDDEN_REFS="$(grep -Ec 'update-entity-status|register-stage-output|render-stage-links|git (add|commit|reset)' "$REPO_ROOT/plugins/ship-flow/lib/advance-stage.sh" || true)"
if [ "$SKILL_REFS" -ge 5 ] && [ "$CAS_REFS" = 1 ] && [ "$RECONCILE_REFS" = 1 ] && [ "$FORBIDDEN_REFS" = 0 ]; then
  echo "OK DC-1 SKILL refs=$SKILL_REFS CAS=$CAS_REFS reconcile=$RECONCILE_REFS"
else echo "FAIL DC-1 SKILL refs=$SKILL_REFS CAS=$CAS_REFS reconcile=$RECONCILE_REFS forbidden=$FORBIDDEN_REFS"; FAIL=1; fi

echo
echo "=== C14 Contract 2: exact completion triples and ownership wording ==="
assert_skill_contract() {
  local skill="$1" new_status="$2" stage_name="$3" stage_file="$4" ownership="$5"
  local path="$REPO_ROOT/plugins/ship-flow/skills/$skill/SKILL.md"
  local completion_block
  if grep -Fq -- "--new-status=$new_status" "$path" && \
     grep -Fq -- "--stage-name=$stage_name" "$path" && \
     grep -Fq -- "--stage-file=$stage_file" "$path"; then
    echo "OK $skill exact triple $new_status/$stage_name/$stage_file"
  else
    echo "FAIL $skill missing exact triple $new_status/$stage_name/$stage_file"; FAIL=1
  fi
  if grep -Fq -- "$ownership" "$path"; then
    echo "OK $skill completion/FO boundary"
  else
    echo "FAIL $skill missing completion/FO boundary: $ownership"; FAIL=1
  fi
  completion_block="$(awk -v new_status="$new_status" -v stage_name="$stage_name" -v stage_file="$stage_file" '
    /^[[:space:]]+INDEX_MD=/ { capture=1; block=$0 ORS; next }
    capture { block=block $0 ORS }
    capture && /--commit-as=/ {
      if (index(block, "--new-status=" new_status) &&
          index(block, "--stage-name=" stage_name) &&
          index(block, "--stage-file=" stage_file)) {
        print block
        found=1
      }
      capture=0
      block=""
    }
    END { if (!found) exit 1 }
  ' "$path" || true)"
  if printf '%s\n' "$completion_block" | grep -Fq 'command -v sha256sum' && \
     printf '%s\n' "$completion_block" | grep -Fq 'shasum -a 256'; then
    echo "OK $skill completion triple has cross-platform hash fallback"
  else
    echo "FAIL $skill completion triple lacks cross-platform hash fallback"; FAIL=1
  fi
}

assert_skill_contract ship-design design design design.md \
  "This registers design completion; it does not enter plan. Return to the First Officer for a separate plan stage-entry transition."
assert_skill_contract ship-plan plan plan plan.md \
  "This registers plan completion; it does not enter execute. Return to the First Officer for a separate execute stage-entry transition."
assert_skill_contract ship-execute execute execute execute.md \
  "This registers execute completion; it does not enter verify. Return to the First Officer for a separate verify stage-entry transition."
assert_skill_contract ship-verify verify verify verify.md \
  "This registers verify completion; it does not dispatch review. Return to the First Officer for the separate review-stage dispatch."
assert_skill_contract ship-review ship review review.md \
  "This registers review completion as the reviewed terminal status ship; it is not a First Officer stage-entry receipt."
assert_skill_contract ship ship ship ship.md \
  "This registers the ship artifact idempotently and independently from PR metadata; it does not perform ship-to-done."

FLAT_FALLBACK='Legacy flat entities without canonical stage_outputs authority MUST NOT invoke advance-stage.sh; historical body tables are non-authoritative and remain opaque.'
if grep -Fq -- "$FLAT_FALLBACK" "$REPO_ROOT/plugins/ship-flow/skills/ship-design/SKILL.md"; then
  echo "OK ship-design literal legacy-flat fallback"
else
  echo "FAIL ship-design missing literal legacy-flat fallback"; FAIL=1
fi
fi

setup_fo_completion_fixture() {
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
    - name: shape
    - name: design
    - name: plan
    - name: execute
    - name: verify
      feedback-to: execute
    - name: ship
---
EOF
    cat > ROADMAP.md <<'EOF'
# Roadmap

<!-- section:next -->
## Next

| Entity | Size | Why it matters | Depends on |
|--------|------|----------------|------------|
<!-- /section:next -->

<!-- section:later -->
## Later

| Entity | Size | Why it matters | Triggered by |
|--------|------|----------------|--------------|
<!-- /section:later -->

<!-- section:not-doing -->
## Not Doing

| Entity | Reason |
|--------|--------|
<!-- /section:not-doing -->
EOF
    cat > proposal.json <<'EOF'
{
  "pitch": {
    "id": "example",
    "slug": "stage-wiring",
    "title": "Stage wiring",
    "appetite": "small batch",
    "problem": "Prove the real folder-layout producer can enter the FO lifecycle.",
    "acceptance_outcome": "Captain receives a machine-verified lifecycle from the real shape producer through every separate First Officer entry and completion.",
    "shape_mode": "mode-b"
  },
  "children": [],
  "rabbit_holes": [],
  "deleted_from_shape": []
}
EOF
    git add -- docs/test-wf/README.md ROADMAP.md
    git commit -qm "baseline: canonical workflow graph"
    if ! bash "${LIB_DIR}/shape-confirm.sh" \
      --proposal=proposal.json \
      --layout=folder \
      --workflow-dir=docs/test-wf >/dev/null 2>&1; then
      echo "fixture setup failed: real shape-confirm producer" >&2
      exit 1
    fi
    rm -f proposal.json
    cat >> docs/test-wf/example-stage-wiring/index.md <<'EOF'

<!-- section:stage-artifact-links -->
| Stage | File |
| --- | --- |
| legacy | [wrong.md](wrong.md) |
<!-- /section:stage-artifact-links -->
EOF
    for stage in design plan execute verify review ship; do
      printf '# %s\n' "$stage" > "docs/test-wf/example-stage-wiring/${stage}.md"
    done
    git add -- docs/test-wf/example-stage-wiring/design.md \
      docs/test-wf/example-stage-wiring/index.md \
      docs/test-wf/example-stage-wiring/plan.md \
      docs/test-wf/example-stage-wiring/execute.md \
      docs/test-wf/example-stage-wiring/verify.md \
      docs/test-wf/example-stage-wiring/review.md \
      docs/test-wf/example-stage-wiring/ship.md
    git commit -qm "fixture: add stage artifacts"
    git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
    git checkout -q -b feature
  )
  echo "$dir"
}

if [ "${1:-}" = --plan-attempt ]; then
  echo "=== Production plan attempt lifecycle seam ==="
  if ! type fo_plan_attempt_begin >/dev/null 2>&1 || ! type fo_plan_attempt_checkpoint >/dev/null 2>&1; then
    echo "FAIL production plan-attempt lifecycle functions unavailable"
    exit 1
  fi

  SHIP_SKILL="$REPO_ROOT/plugins/ship-flow/skills/ship/SKILL.md"
  FO_DISPATCH_SECTION="$(awk '
    /^### Completion-v1 FO dispatch seam \(mandatory\)$/ { capture=1 }
    capture && /^### / && !/^### Completion-v1 FO dispatch seam \(mandatory\)$/ { exit }
    capture { print }
  ' "$SHIP_SKILL")"
  FO_DISPATCH_BLOCK="$(printf '%s\n' "$FO_DISPATCH_SECTION" | awk '
    /^```bash$/ { in_code=1; next }
    in_code && /^```$/ { exit }
    in_code { print }
  ')"
  PLAN_CALLER_BRANCH="$(printf '%s\n' "$FO_DISPATCH_BLOCK" | awk '
    /^[[:space:]]*plan\)$/ { capture=1 }
    capture { print }
    capture && /^[[:space:]]*;;[[:space:]]*$/ { exit }
  ')"
  COMPLETION_CALLER_BRANCH="$(printf '%s\n' "$FO_DISPATCH_BLOCK" | awk '
    /^[[:space:]]*design\|execute\|verify\|review\|ship\)$/ { capture=1 }
    capture { print }
    capture && /^[[:space:]]*;;[[:space:]]*$/ { exit }
  ')"
  PLAN_ENV_TOKEN="\$FO_PLAN_ATTEMPT_ENV_BLOCK"
  COMPLETION_ENV_TOKEN="\$FO_COMPLETION_ENV_BLOCK"
  PLAN_LABELS="$(printf '%s\n' "$FO_DISPATCH_BLOCK" | grep -Ec '^[[:space:]]*plan\)[[:space:]]*$' || true)"
  COMPLETION_LABELS="$(printf '%s\n' "$FO_DISPATCH_BLOCK" | grep -Ec '^[[:space:]]*design\|execute\|verify\|review\|ship\)[[:space:]]*$' || true)"
  if [ "$PLAN_LABELS" = 1 ] && \
     [ "$(printf '%s\n' "$PLAN_CALLER_BRANCH" | grep -Ec '^[[:space:]]*fo_plan_attempt_begin[[:space:]]' || true)" = 1 ] && \
     [ "$(printf '%s\n' "$PLAN_CALLER_BRANCH" | grep -Fc "$PLAN_ENV_TOKEN" || true)" = 1 ] && \
     [ "$(printf '%s\n' "$PLAN_CALLER_BRANCH" | grep -Ec '^[[:space:]]*fo_plan_attempt_checkpoint[[:space:]]' || true)" = 1 ] && \
     ! printf '%s\n' "$PLAN_CALLER_BRANCH" | grep -Eq 'fo_completion_(begin|checkpoint)' && \
     ! printf '%s\n' "$PLAN_CALLER_BRANCH" | grep -Fq "$COMPLETION_ENV_TOKEN"; then
    echo "OK ship plan caller uses only the bounded plan-attempt lifecycle"
  else
    echo "FAIL ship plan caller routing is not the exact bounded plan-attempt lifecycle"; FAIL=1
  fi
  if [ "$COMPLETION_LABELS" = 1 ] && \
     [ "$(printf '%s\n' "$COMPLETION_CALLER_BRANCH" | grep -Ec '^[[:space:]]*fo_completion_begin[[:space:]]' || true)" = 1 ] && \
     [ "$(printf '%s\n' "$COMPLETION_CALLER_BRANCH" | grep -Fc "$COMPLETION_ENV_TOKEN" || true)" = 1 ] && \
     [ "$(printf '%s\n' "$COMPLETION_CALLER_BRANCH" | grep -Ec '^[[:space:]]*fo_completion_checkpoint[[:space:]]' || true)" = 1 ] && \
     ! printf '%s\n' "$COMPLETION_CALLER_BRANCH" | grep -Eq 'fo_plan_attempt_(begin|checkpoint)' && \
     ! printf '%s\n' "$COMPLETION_CALLER_BRANCH" | grep -Fq "$PLAN_ENV_TOKEN"; then
    echo "OK ship non-plan callers retain only the bounded completion lifecycle"
  else
    echo "FAIL ship non-plan caller routing is not the exact bounded completion lifecycle"; FAIL=1
  fi
  if printf '%s\n' "$FO_DISPATCH_SECTION" | grep -Fq 'Sequence: begin; prepend env; dispatch; checkpoint the verbatim worker return; then separate Contract 1.'; then
    echo "OK ship caller keeps Contract 1 separate after lifecycle checkpoint"
  else
    echo "FAIL ship caller sequence does not keep Contract 1 separate after lifecycle checkpoint"; FAIL=1
  fi

  BEGIN_FAULT_TMP="$(setup_fo_completion_fixture)"
  BEGIN_FAULT_ENTITY=docs/test-wf/example-stage-wiring/index.md
  sed -i.bak 's/^status: shape$/status: plan/' "$BEGIN_FAULT_TMP/$BEGIN_FAULT_ENTITY"
  rm -f "$BEGIN_FAULT_TMP/$BEGIN_FAULT_ENTITY.bak"
  (cd "$BEGIN_FAULT_TMP" && git add -- "$BEGIN_FAULT_ENTITY" && git commit -qm "advance: begin-fault entering plan")
  if (
    cd "$BEGIN_FAULT_TMP" || exit 1
    printf '%s\n' '11111111-2222-3333-4444-555555555555' > .git/plan-attempt.boot-id
    # shellcheck disable=SC2030,SC2031 # each disposable-repo case owns its clock environment
    export STAGE_ATTEMPT_BOOT_ID_SOURCE="$BEGIN_FAULT_TMP/.git/plan-attempt.boot-id"
    # shellcheck disable=SC2030,SC2031 # each disposable-repo case owns its clock environment
    export STAGE_ATTEMPT_MONOTONIC_NS=1000000000
    fo_plan_attempt_begin "$BEGIN_FAULT_ENTITY" ensign-plan-fixture invalid-start >/dev/null 2>&1
    rc=$?
    gitdir="$(git rev-parse --absolute-git-dir)"
    private_count="$(find "$gitdir/spacedock-stage-attempt-v1" -type f \( -name '*.wal' -o -name '*.returned' \) 2>/dev/null | wc -l | tr -d ' ')"
    [ "$rc" = 2 ] && [ ! -e "$gitdir/completion-v1.lease" ] && [ "$private_count" = 0 ]
  ); then
    echo "OK rejected plan-attempt begin preserves rc and releases only its exact delegated lease"
  else
    echo "FAIL rejected plan-attempt begin leaked or masked its exact delegated lease"; FAIL=1
  fi
  rm -rf "$BEGIN_FAULT_TMP"

  TERMINAL_FAULT_TMP="$(setup_fo_completion_fixture)"
  TERMINAL_FAULT_ENTITY=docs/test-wf/example-stage-wiring/index.md
  sed -i.bak 's/^status: shape$/status: plan/' "$TERMINAL_FAULT_TMP/$TERMINAL_FAULT_ENTITY"
  rm -f "$TERMINAL_FAULT_TMP/$TERMINAL_FAULT_ENTITY.bak"
  (cd "$TERMINAL_FAULT_TMP" && git add -- "$TERMINAL_FAULT_ENTITY" && git commit -qm "advance: terminal-fault entering plan")
  if (
    cd "$TERMINAL_FAULT_TMP" || exit 1
    printf '%s\n' '11111111-2222-3333-4444-555555555555' > .git/plan-attempt.boot-id
    # shellcheck disable=SC2030,SC2031 # each disposable-repo case owns its clock environment
    export STAGE_ATTEMPT_BOOT_ID_SOURCE="$TERMINAL_FAULT_TMP/.git/plan-attempt.boot-id"
    # shellcheck disable=SC2030,SC2031 # each disposable-repo case owns its clock environment
    export STAGE_ATTEMPT_MONOTONIC_NS=1000000000
    fo_plan_attempt_begin "$TERMINAL_FAULT_ENTITY" ensign-plan-fixture 2026-07-23T01:00:00Z >/dev/null || exit
    receipt="$(bash "$LIB_DIR/advance-stage.sh" \
      --entity="$TERMINAL_FAULT_ENTITY" --new-status=plan --stage-name=plan --stage-file=plan.md \
      --if-hash="$(sha256_of "$TERMINAL_FAULT_ENTITY")" \
      --commit-as='plan(terminal-fault): register completion' \
      --lease-file="$SHIP_FLOW_COMPLETION_LEASE_FILE" --lease-token="$SHIP_FLOW_COMPLETION_LEASE_TOKEN" \
      --worker-id="$SHIP_FLOW_COMPLETION_WORKER_ID")" || exit
    export STAGE_ATTEMPT_MONOTONIC_NS=8000000000
    fo_plan_attempt_checkpoint "$receipt" invalid-finish >/dev/null 2>&1
    rc=$?
    gitdir="$(git rev-parse --absolute-git-dir)"
    wal_count="$(find "$gitdir/spacedock-stage-attempt-v1" -type f -name '*.wal' 2>/dev/null | wc -l | tr -d ' ')"
    returned_count="$(find "$gitdir/spacedock-stage-attempt-v1" -type f -name '*.returned' 2>/dev/null | wc -l | tr -d ' ')"
    tracked_count="$(find docs/test-wf/example-stage-wiring -maxdepth 1 -type f -name 'attempt-return-v1.*.receipt' | wc -l | tr -d ' ')"
    [ "$rc" = 2 ] && [ "$wal_count" = 1 ] && [ "$returned_count" = 1 ] &&
      [ "$tracked_count" = 0 ] && [ ! -e docs/test-wf/example-stage-wiring/attempt-history-v1.log ]
  ); then
    echo "OK terminal helper failure preserves exact rc and authoritative return evidence"
  else
    echo "FAIL terminal helper failure rc/evidence was masked or discarded"; FAIL=1
  fi
  rm -rf "$TERMINAL_FAULT_TMP"

  TMP="$(setup_fo_completion_fixture)"
  ENTITY_REL=docs/test-wf/example-stage-wiring/index.md
  ENTITY="$TMP/$ENTITY_REL"
  DISPATCH_COUNT="$TMP/.git/plan-attempt.dispatch-count"
  : > "$DISPATCH_COUNT"
  BOOT_ID="$TMP/.git/plan-attempt.boot-id"
  printf '%s\n' '11111111-2222-3333-4444-555555555555' > "$BOOT_ID"
  sed -i.bak 's/^status: shape$/status: plan/' "$ENTITY"
  rm -f "$ENTITY.bak"
  (cd "$TMP" && git add -- "$ENTITY_REL" && git commit -qm "advance: example-stage-wiring entering plan")

  PLAN_OUTPUT="$({
    cd "$TMP" || exit 1
    # shellcheck disable=SC2030,SC2031 # success case owns its disposable-repo clock environment
    export STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT_ID"
    # shellcheck disable=SC2030,SC2031 # success case owns its disposable-repo clock environment
    export STAGE_ATTEMPT_MONOTONIC_NS=1000000000
    fo_plan_attempt_begin "$ENTITY_REL" ensign-plan-fixture 2026-07-23T01:00:00Z || exit
    printf 'dispatch\n' >> "$DISPATCH_COUNT"
    receipt="$(bash "$LIB_DIR/advance-stage.sh" \
      --entity="$ENTITY_REL" \
      --new-status=plan \
      --stage-name=plan \
      --stage-file=plan.md \
      --if-hash="$(sha256_of "$ENTITY_REL")" \
      --commit-as='plan(example-stage-wiring): register completion' \
      --lease-file="$SHIP_FLOW_COMPLETION_LEASE_FILE" \
      --lease-token="$SHIP_FLOW_COMPLETION_LEASE_TOKEN" \
      --worker-id="$SHIP_FLOW_COMPLETION_WORKER_ID")" || exit
    export STAGE_ATTEMPT_MONOTONIC_NS=8000000000
    fo_plan_attempt_checkpoint "$receipt" 2026-07-23T01:00:07Z
  } 2>&1)" || {
    echo "FAIL production plan-attempt lifecycle: $PLAN_OUTPUT"
    rm -rf "$TMP"
    exit 1
  }

  DISPATCHES="$(wc -l < "$DISPATCH_COUNT" | tr -d ' ')"
  ACCEPTED="$(printf '%s\n' "$PLAN_OUTPUT" | grep -c '^stage-attempt-v1 disposition=returned ' || true)"
  TERMINAL="$(printf '%s\n' "$PLAN_OUTPUT" | grep -c '^stage-attempt-v1 disposition=terminal ' || true)"
  if [ "$DISPATCHES" = 1 ] && [ "$ACCEPTED" = 1 ] && [ "$TERMINAL" = 1 ]; then
    echo "OK plan attempt has exactly 1 dispatch, 1 authoritative return, and 1 terminal contribution"
  else
    echo "FAIL plan attempt counts dispatch=$DISPATCHES accepted=$ACCEPTED terminal=$TERMINAL output=$PLAN_OUTPUT"
    FAIL=1
  fi

  HISTORY="$TMP/docs/test-wf/example-stage-wiring/attempt-history-v1.log"
  TRACKED_COUNT="$(find "$TMP/docs/test-wf/example-stage-wiring" -maxdepth 1 -type f -name 'attempt-return-v1.sev1-*.receipt' | wc -l | tr -d ' ')"
  TRACKED="$(find "$TMP/docs/test-wf/example-stage-wiring" -maxdepth 1 -type f -name 'attempt-return-v1.sev1-*.receipt' -print -quit)"
  RETURNED_SHA="$(printf '%s\n' "$PLAN_OUTPUT" | sed -n 's/^stage-attempt-v1 disposition=returned returned_bundle_sha256=\([0-9a-f][0-9a-f]*\)$/\1/p')"
  if [ -f "$HISTORY" ] && [ "$(wc -l < "$HISTORY" | tr -d ' ')" = 1 ] && \
     [ "$(grep -c ' elapsed_seconds=7 cumulative_elapsed_seconds=7 ' "$HISTORY" || true)" = 1 ]; then
    echo "OK plan attempt records one terminal-history line and one duration"
  else
    echo "FAIL plan attempt terminal history/duration"; FAIL=1
  fi
  if [ "$TRACKED_COUNT" = 1 ] && [ -n "$TRACKED" ] && [ "$(sha256_of "$TRACKED")" = "$RETURNED_SHA" ]; then
    echo "OK plan attempt tracks one exact returned-bundle sidecar"
  else
    echo "FAIL plan attempt tracked sidecar count=$TRACKED_COUNT expected_sha=$RETURNED_SHA"; FAIL=1
  fi

  GIT_COMMON="$(cd "$TMP" && git rev-parse --git-common-dir)"
  case "$GIT_COMMON" in /*) ;; *) GIT_COMMON="$TMP/$GIT_COMMON" ;; esac
  PRIVATE_COUNT="$(find "$GIT_COMMON/spacedock-stage-attempt-v1" -type f \( -name '*.wal' -o -name '*.returned' \) 2>/dev/null | wc -l | tr -d ' ')"
  PLAN_OUTPUT_COUNT="$(grep -cE '^[[:space:]]+plan:[[:space:]]*plan\.md$' "$ENTITY" || true)"
  if [ "$PRIVATE_COUNT" = 0 ] && grep -q '^status: plan$' "$ENTITY" && [ "$PLAN_OUTPUT_COUNT" = 1 ]; then
    echo "OK plan attempt cleans private authority and preserves one plan stage output at plan status"
  else
    echo "FAIL plan attempt cleanup/status private=$PRIVATE_COUNT plan_outputs=$PLAN_OUTPUT_COUNT"; FAIL=1
  fi
  rm -rf "$TMP"
  exit "$FAIL"
fi

# shellcheck disable=SC2329 # invoked indirectly through assert_exit/eval below
run_c14() {
  local repo_dir="$1"
  (cd "$repo_dir" && bash "$BIN_DIR/check-invariants.sh" --check entity-status-via-advance-stage-only)
}

# shellcheck disable=SC2329 # invoked indirectly by assert_exit/eval lifecycle cases
run_completion_reconcile() {
  local repo="$1" entity="$2" status="$3" stage="$4" file="$5" message="$6"
  local hash receipt worker="ensign-fixture"
  (
    cd "$repo" || exit 1
    fo_completion_begin "$entity" "$status" "$stage" "$file" "$worker" || exit
    hash="$(sha256_of "$entity")" || exit
    receipt="$(bash "$LIB_DIR/advance-stage.sh" --entity="$entity" --new-status="$status" --stage-name="$stage" --stage-file="$file" --if-hash="$hash" --commit-as="$message" --lease-file="$SHIP_FLOW_COMPLETION_LEASE_FILE" --lease-token="$SHIP_FLOW_COMPLETION_LEASE_TOKEN" --worker-id="$SHIP_FLOW_COMPLETION_WORKER_ID")" || exit
    fo_completion_checkpoint "$receipt"
  )
}

if [ "${1:-}" = --completion-lifecycle ]; then
  echo "=== Production completion lifecycle seam ==="
  TMP="$(setup_fo_completion_fixture)"
  ENTITY="$TMP/docs/test-wf/example-stage-wiring/index.md"
  sed -i.bak 's/^status: shape$/status: design/' "$ENTITY"
  rm -f "$ENTITY.bak"
  (cd "$TMP" && git add -- docs/test-wf/example-stage-wiring/index.md && git commit -qm "dispatch: example-stage-wiring entering design")
  PUBLISHED="$(run_completion_reconcile "$TMP" docs/test-wf/example-stage-wiring/index.md design design design.md 'design(example-stage-wiring): register completion')" || FAIL=1
  case "$PUBLISHED" in completion-v1-reconcile\ disposition=reconciled\ *) echo "OK published completion uses production lifecycle seam" ;; *) echo "FAIL published completion lifecycle: $PUBLISHED"; FAIL=1 ;; esac
  ALREADY="$(run_completion_reconcile "$TMP" docs/test-wf/example-stage-wiring/index.md design design design.md 'design(example-stage-wiring): register completion')" || FAIL=1
  case "$ALREADY" in completion-v1-reconcile\ disposition=ready\ *) echo "OK already-registered completion uses production lifecycle seam" ;; *) echo "FAIL already-registered completion lifecycle: $ALREADY"; FAIL=1 ;; esac
  rm -rf "$TMP"
  exit "$FAIL"
fi

run_completion_fault_case() {
  local fault="$1" tmp entity result
  tmp="$(setup_fo_completion_fixture)"; entity="$tmp/docs/test-wf/example-stage-wiring/index.md"
  sed -i.bak 's/^status: shape$/status: design/' "$entity"; rm -f "$entity.bak"
  (cd "$tmp" && git add -- docs/test-wf/example-stage-wiring/index.md && git commit -qm "dispatch: example-stage-wiring entering design")
  (
    local receipt output rc=0 evidence
    cd "$tmp" || exit 1
    fo_completion_begin docs/test-wf/example-stage-wiring/index.md design design design.md ensign-fixture || exit
    receipt="$(bash "$LIB_DIR/advance-stage.sh" --entity=docs/test-wf/example-stage-wiring/index.md --new-status=design --stage-name=design --stage-file=design.md --if-hash="$(sha256_of docs/test-wf/example-stage-wiring/index.md)" --commit-as='design(example-stage-wiring): register completion' --lease-file="$SHIP_FLOW_COMPLETION_LEASE_FILE" --lease-token="$SHIP_FLOW_COMPLETION_LEASE_TOKEN" --worker-id="$SHIP_FLOW_COMPLETION_WORKER_ID")" || exit
    case "$fault" in
      malformed) receipt='completion-v1 malformed receipt' ;;
      foreign) sed -i.bak 's/^token=.*/token=tampered/' "$SHIP_FLOW_COMPLETION_LEASE_FILE"; rm -f "$SHIP_FLOW_COMPLETION_LEASE_FILE.bak" ;;
      dirty) : > completion-fault-dirty.txt ;;
      observe) git update-ref -d "$FO_COMPLETION_REF" ;;
      reconcile) : > "$FO_COMPLETION_GITDIR/index.lock" ;;
    esac
    output="$(fo_completion_checkpoint "$receipt" 2>&1)" || rc=$?
    [ "$rc" -ne 0 ] || { echo "FAIL $fault unexpectedly succeeded"; exit 1; }
    case "$output" in *'completion-v1-reconcile disposition=ready'*|*'completion-v1-reconcile disposition=reconciled'*) echo "FAIL $fault emitted success: $output"; exit 1 ;; esac
    case "$fault" in
      malformed|foreign|observe) evidence="$FO_COMPLETION_GITDIR/completion-v1.lease/record" ;;
      dirty) evidence=completion-fault-dirty.txt ;;
      reconcile) evidence="$FO_COMPLETION_GITDIR/completion-v1.lease/returned" ;;
    esac
    [ -e "$evidence" ] || { echo "FAIL $fault discarded diagnostic evidence"; exit 1; }
    [ "$fault" != dirty ] || [ -e "$FO_COMPLETION_GITDIR/completion-v1.lease/returned" ] || { echo "FAIL dirty discarded returned lease"; exit 1; }
    [ "$fault" != reconcile ] || [ -e "$FO_COMPLETION_GITDIR/index.lock" ] || { echo "FAIL reconcile discarded index lock"; exit 1; }
  ); result=$?
  rm -rf "$tmp"
  [ "$result" = 0 ] && echo "OK $fault fails closed through production lifecycle seam"
  return "$result"
}

if [ "${1:-}" = --completion-lifecycle-faults ]; then
  echo "=== Production completion lifecycle fault matrix ==="
  for fault in malformed foreign dirty observe reconcile; do run_completion_fault_case "$fault" || FAIL=1; done
  exit "$FAIL"
fi

echo
echo "=== DC-2/DC-3: real shape producer -> FO entry -> completion -> separate FO entry ==="
TMP="$(setup_fo_completion_fixture)"
ENTITY="$TMP/docs/test-wf/example-stage-wiring/index.md"
if grep -q '^status: shape$' "$ENTITY" && \
   grep -qE '^[[:space:]]+shape:[[:space:]]*shape\.md$' "$ENTITY" && \
   bash "$LIB_DIR/render-stage-links.sh" --entity="$ENTITY" | grep -qF '| shape | [shape.md](shape.md) |' && grep -Fq "| \`lib/advance-stage.sh\` | atomically registers current-stage completion while leaving current status unchanged; does not enter the next stage or render |" "$REPO_ROOT/plugins/ship-flow/README.md"; then
  echo "OK real shape-confirm producer emitted frontmatter authority, derived shape link, and completion status semantics"
else
  echo "FAIL real shape-confirm producer did not emit frontmatter authority and derived view"; FAIL=1
fi

sed -i.bak 's/^status: shape$/status: design/' "$ENTITY"
rm -f "$ENTITY.bak"
(cd "$TMP" && git add -- docs/test-wf/example-stage-wiring/index.md && git commit -qm "dispatch: example-stage-wiring entering design")
assert_exit 0 "run_c14 '$TMP'" "FO dispatch into design passes targeted C14"

H="$(sha256_of "$ENTITY")"
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
assert_exit 0 \
  "run_completion_reconcile '$TMP' docs/test-wf/example-stage-wiring/index.md design design design.md 'design(example-stage-wiring): register completion'" \
  "compatible folder design completion exits 0"
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ $(( COMMITS_AFTER - COMMITS_BEFORE )) = "1" ] && \
   grep -q '^status: design$' "$ENTITY" && \
   grep -qE '^[[:space:]]+design:[[:space:]]*design\.md' "$ENTITY"; then
  echo "OK design/design/design.md completion is idempotent and recorded"
else
  echo "FAIL design completion did not preserve status and record artifact"; FAIL=1
fi
assert_exit 0 "run_c14 '$TMP'" "completion commit remains distinct and passes targeted C14"

sed -i.bak 's/^status: design$/status: plan/' "$ENTITY"
rm -f "$ENTITY.bak"
(cd "$TMP" && git add -- docs/test-wf/example-stage-wiring/index.md && git commit -qm "advance: example-stage-wiring entering plan")
assert_exit 0 "run_c14 '$TMP'" "separate FO advance into plan passes targeted C14"

H="$(sha256_of "$ENTITY")"
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
assert_exit 0 \
  "run_completion_reconcile '$TMP' docs/test-wf/example-stage-wiring/index.md plan plan plan.md 'plan(example-stage-wiring): register completion'" \
  "compatible folder plan completion exits 0"
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ $(( COMMITS_AFTER - COMMITS_BEFORE )) = "1" ] && grep -q '^status: plan$' "$ENTITY"; then
  echo "OK plan/plan/plan.md completion is idempotent"
else
  echo "FAIL plan completion did not preserve plan status"; FAIL=1
fi
assert_exit 0 "run_c14 '$TMP'" "plan completion commit passes targeted C14"

sed -i.bak 's/^status: plan$/status: execute/' "$ENTITY"
rm -f "$ENTITY.bak"
(cd "$TMP" && git add -- docs/test-wf/example-stage-wiring/index.md && git commit -qm "dispatch: example-stage-wiring entering execute")
assert_exit 0 "run_c14 '$TMP'" "separate FO dispatch into execute passes targeted C14"

H="$(sha256_of "$ENTITY")"
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
assert_exit 0 \
  "run_completion_reconcile '$TMP' docs/test-wf/example-stage-wiring/index.md execute execute execute.md 'execute(example-stage-wiring): register completion'" \
  "compatible folder execute completion exits 0"
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ $(( COMMITS_AFTER - COMMITS_BEFORE )) = "1" ] && grep -q '^status: execute$' "$ENTITY"; then
  echo "OK execute/execute/execute.md completion is idempotent"
else
  echo "FAIL execute completion did not preserve execute status"; FAIL=1
fi
assert_exit 0 "run_c14 '$TMP'" "execute completion commit passes targeted C14"

sed -i.bak 's/^status: execute$/status: verify/' "$ENTITY"
rm -f "$ENTITY.bak"
(cd "$TMP" && git add -- docs/test-wf/example-stage-wiring/index.md && git commit -qm "advance: example-stage-wiring entering verify")
assert_exit 0 "run_c14 '$TMP'" "separate FO advance into verify passes targeted C14"

H="$(sha256_of "$ENTITY")"
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
assert_exit 0 \
  "run_completion_reconcile '$TMP' docs/test-wf/example-stage-wiring/index.md verify verify verify.md 'verify(example-stage-wiring): register completion'" \
  "compatible folder verify completion exits 0"
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ $(( COMMITS_AFTER - COMMITS_BEFORE )) = "1" ] && grep -q '^status: verify$' "$ENTITY"; then
  echo "OK verify/verify/verify.md completion is idempotent"
else
  echo "FAIL verify completion did not preserve verify status"; FAIL=1
fi
assert_exit 0 "run_c14 '$TMP'" "verify completion commit passes targeted C14"

sed -i.bak 's/^status: verify$/status: ship/' "$ENTITY"
rm -f "$ENTITY.bak"
(cd "$TMP" && git add -- docs/test-wf/example-stage-wiring/index.md && git commit -qm "dispatch: example-stage-wiring entering ship")
assert_exit 0 "run_c14 '$TMP'" "separate FO dispatch into ship passes targeted C14"

H="$(sha256_of "$ENTITY")"
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
assert_exit 0 \
  "run_completion_reconcile '$TMP' docs/test-wf/example-stage-wiring/index.md ship review review.md 'review(example-stage-wiring): register completion'" \
  "compatible folder review completion at ship exits 0"
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ $(( COMMITS_AFTER - COMMITS_BEFORE )) = "1" ] && grep -q '^status: ship$' "$ENTITY"; then
  echo "OK ship/review/review.md completion is idempotent"
else
  echo "FAIL review completion did not preserve ship status"; FAIL=1
fi
assert_exit 0 "run_c14 '$TMP'" "review completion commit passes targeted C14"

H="$(sha256_of "$ENTITY")"
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
assert_exit 0 \
  "run_completion_reconcile '$TMP' docs/test-wf/example-stage-wiring/index.md ship ship ship.md 'ship(example-stage-wiring): register completion'" \
  "compatible folder ship completion exits 0"
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ $(( COMMITS_AFTER - COMMITS_BEFORE )) = "1" ] && grep -q '^status: ship$' "$ENTITY"; then
  echo "OK ship/ship/ship.md completion is idempotent"
else
  echo "FAIL ship completion did not preserve ship status"; FAIL=1
fi
assert_exit 0 "run_c14 '$TMP'" "ship completion commit passes targeted C14"

for stage in shape design plan execute verify review ship; do
  if grep -qE "^[[:space:]]+${stage}:[[:space:]]*${stage}\\.md$" "$ENTITY" && \
     bash "$LIB_DIR/render-stage-links.sh" --entity="$ENTITY" | grep -qF "| ${stage} | [${stage}.md](${stage}.md) |"; then
    echo "OK ${stage} survives in frontmatter authority and derived view"
  else
    echo "FAIL ${stage} missing from frontmatter authority or derived view"; FAIL=1
  fi
done
# shellcheck disable=SC2015 # compact test assertion updates FAIL on mismatch
grep -qF '| legacy | [wrong.md](wrong.md) |' "$ENTITY" && echo "OK historical body table stayed opaque" || { echo "FAIL historical body table changed"; FAIL=1; }

COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
H="$(sha256_of "$ENTITY")"
assert_exit 0 \
  "run_completion_reconcile '$TMP' docs/test-wf/example-stage-wiring/index.md ship ship ship.md 'ship(example-stage-wiring): register completion'" \
  "DC-5a repeated completion is a successful no-op"
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ "$COMMITS_BEFORE" = "$COMMITS_AFTER" ] && [ -z "$(cd "$TMP" && git status --porcelain)" ]; then
  echo "OK DC-5b repeated completion creates no commit and leaves the repo clean"
else
  echo "FAIL DC-5b repeated completion changed history or left residue"; FAIL=1
fi
rm -rf "$TMP"

echo
echo "=== DC-4: stale-hash completion rejects before mutation ==="
TMP="$(setup_fo_completion_fixture)"
ENTITY="$TMP/docs/test-wf/example-stage-wiring/index.md"
sed -i.bak 's/^status: shape$/status: design/' "$ENTITY"
rm -f "$ENTITY.bak"
(cd "$TMP" && git add -- docs/test-wf/example-stage-wiring/index.md && git commit -qm "dispatch: example-stage-wiring entering design")
H="$(sha256_of "$ENTITY")"
BEFORE="$(cd "$TMP" && git rev-parse HEAD)"; TOKEN="fixture-dirty-${BEFORE}"; WORKER=ensign-fixture
(cd "$TMP" && bash "$LIB_DIR/fo-completion-lease.sh" acquire --entity=docs/test-wf/example-stage-wiring/index.md --stage=design --worker="$WORKER" --token="$TOKEN" --ref=refs/heads/feature --before="$BEFORE") >/dev/null
LEASE="$(cd "$TMP" && git rev-parse --absolute-git-dir)/completion-v1.lease/record"
printf '\n<!-- concurrent edit -->\n' >> "$ENTITY"
RC=0
(cd "$TMP" && bash "${LIB_DIR}/advance-stage.sh" \
  --entity=docs/test-wf/example-stage-wiring/index.md \
  --new-status=design \
  --stage-name=design \
  --stage-file=design.md \
  --if-hash="$H" \
  --commit-as="design(example-stage-wiring): register completion" \
  --lease-file="$LEASE" --lease-token="$TOKEN" --worker-id="$WORKER") >/dev/null 2>&1 || RC=$?
if [ "$RC" = "5" ]; then
  echo "OK DC-4 changed worktree snapshot fails before hash/CAS"
else
  echo "FAIL DC-4 expected exit 5, got $RC"; FAIL=1
fi
rm -rf "$TMP"

echo
echo "=== C14 immediate activation negatives ==="
TMP="$(setup_fo_completion_fixture)"
sed -i.bak 's/^status: shape$/status: design/' "$TMP/docs/test-wf/example-stage-wiring/index.md"
rm -f "$TMP/docs/test-wf/example-stage-wiring/index.md.bak"
(cd "$TMP" && git add -- docs/test-wf/example-stage-wiring/index.md && git commit -qm "manual: enter design")
assert_exit 1 "run_c14 '$TMP'" "arbitrary manual entry fails targeted C14"
rm -rf "$TMP"

TMP="$(setup_fo_completion_fixture)"
sed -i.bak 's/^status: shape$/status: plan/' "$TMP/docs/test-wf/example-stage-wiring/index.md"
rm -f "$TMP/docs/test-wf/example-stage-wiring/index.md.bak"
(cd "$TMP" && git add -- docs/test-wf/example-stage-wiring/index.md && git commit -qm "plan(example-stage-wiring): advance status to plan")
assert_exit 1 "run_c14 '$TMP'" "completion signature cannot bless skipped edge"
rm -rf "$TMP"

echo
echo "=== Cooperative completion lease surface ==="
TMP="$(setup_fo_completion_fixture)"; ENTITY_REL=docs/test-wf/example-stage-wiring/index.md; BEFORE="$(cd "$TMP" && git rev-parse HEAD)"
# Non-matching fixture lease value routed through a variable so the disposable
# test token is not a literal --token=<value> CLI option (GitGuardian false positive).
FOREIGN_LEASE_FIXTURE_TOKEN=foreign
assert_exit 0 "cd '$TMP' && bash '$LIB_DIR/fo-completion-lease.sh' acquire --entity='$ENTITY_REL' --stage=design --worker=ensign-test --token=lease-test --ref=refs/heads/feature --before='$BEFORE'" "FO atomically acquires one bound cooperative lease"
assert_exit 9 "cd '$TMP' && bash '$LIB_DIR/fo-completion-lease.sh' acquire --entity='$ENTITY_REL' --stage=design --worker=other --token='$FOREIGN_LEASE_FIXTURE_TOKEN' --ref=refs/heads/feature --before='$BEFORE'" "already-held lease cannot be replaced"
assert_exit 5 "cd '$TMP' && bash '$LIB_DIR/fo-completion-lease.sh' reclaim --entity='$ENTITY_REL' --stage=design --worker=other --token='$FOREIGN_LEASE_FIXTURE_TOKEN' --ref=refs/heads/feature --before='$BEFORE'" "foreign lease cannot be reclaimed"
rm -rf "$TMP"

exit $FAIL
