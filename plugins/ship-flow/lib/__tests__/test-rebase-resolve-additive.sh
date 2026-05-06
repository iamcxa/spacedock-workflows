#!/usr/bin/env bash
# test-rebase-resolve-additive.sh — TDD contract for safe ROADMAP additive conflict resolution
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
REPO_ROOT="$(cd "${LIB_DIR}/../../.." && pwd)"
HELPER="${LIB_DIR}/rebase-resolve-additive.sh"
FAIL=0

pass() { echo "OK $1"; }
fail() { echo "FAIL $1"; FAIL=1; }

write_roadmap() {
  local path="$1"
  local now_rows="$2"
  local later_rows="$3"
  cat > "$path" <<EOF
# Roadmap

<!-- section:now -->
| ID | Item |
|----|------|
${now_rows}
<!-- /section:now -->

<!-- section:later -->
| ID | Item |
|----|------|
${later_rows}
<!-- /section:later -->

<!-- section:not-doing -->
| ID | Item |
|----|------|
<!-- /section:not-doing -->

<!-- section:shipped -->
| ID | Item |
|----|------|
<!-- /section:shipped -->
EOF
}

setup_repo() {
  local mode="$1"
  local repo
  repo="$(mktemp -d)"
  git -C "$repo" init -q
  git -C "$repo" checkout -q -b main
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name "Ship Flow Test"

  write_roadmap "$repo/ROADMAP.md" "| base | Keep baseline |" "| base | Keep baseline |"
  cat > "$repo/ARCHITECTURE.md" <<'EOF'
# Architecture

baseline
EOF
  git -C "$repo" add ROADMAP.md ARCHITECTURE.md
  git -C "$repo" commit -qm "base"

  git -C "$repo" checkout -q -b feature
  case "$mode" in
    additive|multi)
      write_roadmap "$repo/ROADMAP.md" "| base | Keep baseline |" $'| base | Keep baseline |\n| feature | Feature row |'
      ;;
    structural)
      write_roadmap "$repo/ROADMAP.md" "| base | Keep baseline |" "| base | Feature edited existing row |"
      ;;
    unsupported)
      write_roadmap "$repo/ROADMAP.md" $'| base | Keep baseline |\n| feature | Feature now row |' "| base | Keep baseline |"
      ;;
  esac
  if [ "$mode" = "multi" ]; then
    cat > "$repo/ARCHITECTURE.md" <<'EOF'
# Architecture

feature edit
EOF
  fi
  git -C "$repo" add ROADMAP.md ARCHITECTURE.md
  git -C "$repo" commit -qm "feature edit"

  git -C "$repo" checkout -q main
  case "$mode" in
    additive|multi)
      write_roadmap "$repo/ROADMAP.md" "| base | Keep baseline |" $'| base | Keep baseline |\n| main | Main row |'
      ;;
    structural)
      write_roadmap "$repo/ROADMAP.md" "| base | Keep baseline |" "| base | Main edited existing row |"
      ;;
    unsupported)
      write_roadmap "$repo/ROADMAP.md" $'| base | Keep baseline |\n| main | Main now row |' "| base | Keep baseline |"
      ;;
  esac
  if [ "$mode" = "multi" ]; then
    cat > "$repo/ARCHITECTURE.md" <<'EOF'
# Architecture

main edit
EOF
  fi
  git -C "$repo" add ROADMAP.md ARCHITECTURE.md
  git -C "$repo" commit -qm "main edit"

  git -C "$repo" checkout -q feature
  if git -C "$repo" rebase main >/dev/null 2>&1; then
    fail "setup $mode produced a rebase conflict"
  fi
  echo "$repo"
}

assert_exit() {
  local expected="$1"
  local name="$2"
  shift 2
  "$@" >/tmp/rebase-resolve-additive.out 2>&1
  local got=$?
  if [ "$got" = "$expected" ]; then pass "$name"
  else
    fail "$name (expected exit $expected, got $got)"
    sed 's/^/  | /' /tmp/rebase-resolve-additive.out
  fi
}

echo "--- Case 1: resolves pure additive ROADMAP later conflict and stages union ---"
REPO="$(setup_repo additive)"
assert_exit 0 "Case-1a additive helper exits 0" bash -c "cd '$REPO' && bash '$HELPER'"
if git -C "$REPO" diff --name-only --diff-filter=U | grep -q .; then
  fail "Case-1b no unmerged paths remain"
else
  pass "Case-1b no unmerged paths remain"
fi
if git -C "$REPO" diff --cached --name-only | grep -qx "ROADMAP.md"; then
  pass "Case-1c ROADMAP.md staged"
else
  fail "Case-1c ROADMAP.md not staged"
fi
if grep -q "| main | Main row |" "$REPO/ROADMAP.md" && grep -q "| feature | Feature row |" "$REPO/ROADMAP.md"; then
  pass "Case-1d keeps both additive rows"
else
  fail "Case-1d missing additive rows"
fi
if grep -qE '^(<<<<<<<|=======|>>>>>>>)' "$REPO/ROADMAP.md"; then
  fail "Case-1e conflict markers removed"
else
  pass "Case-1e conflict markers removed"
fi
if GIT_EDITOR=true git -C "$REPO" rebase --continue >/dev/null 2>&1; then
  pass "Case-1f staged union lets rebase continue"
else
  fail "Case-1f rebase continue failed"
fi
rm -rf "$REPO"

echo
echo "--- Case 2: refuses when another file is also unmerged ---"
REPO="$(setup_repo multi)"
assert_exit 2 "Case-2 helper exits 2 for multiple unmerged files" bash -c "cd '$REPO' && bash '$HELPER'"
if git -C "$REPO" diff --name-only --diff-filter=U | grep -qx "ARCHITECTURE.md"; then
  pass "Case-2b leaves non-roadmap conflict for captain"
else
  fail "Case-2b missing ARCHITECTURE.md unmerged conflict"
fi
git -C "$REPO" rebase --abort >/dev/null 2>&1 || true
rm -rf "$REPO"

echo
echo "--- Case 3: refuses structural edits to existing rows ---"
REPO="$(setup_repo structural)"
assert_exit 3 "Case-3 helper exits 3 for structural section edit" bash -c "cd '$REPO' && bash '$HELPER'"
if git -C "$REPO" diff --name-only --diff-filter=U | grep -qx "ROADMAP.md"; then
  pass "Case-3b ROADMAP.md remains unmerged"
else
  fail "Case-3b ROADMAP.md should remain unmerged"
fi
git -C "$REPO" rebase --abort >/dev/null 2>&1 || true
rm -rf "$REPO"

echo
echo "--- Case 4: refuses conflicts outside the allowed append-only sections ---"
REPO="$(setup_repo unsupported)"
assert_exit 3 "Case-4 helper exits 3 for unsupported section conflict" bash -c "cd '$REPO' && bash '$HELPER'"
git -C "$REPO" rebase --abort >/dev/null 2>&1 || true
rm -rf "$REPO"

echo
echo "--- Case 5: ship-final docs mention poll + helper contract ---"
if grep -q "mergeStateStatus" "${REPO_ROOT}/plugins/ship-flow/skills/ship/SKILL.md" &&
   grep -q "rebase-resolve-additive.sh" "${REPO_ROOT}/plugins/ship-flow/skills/ship/SKILL.md" &&
   grep -q "rebase-resolve-additive.sh" "${REPO_ROOT}/docs/ship-flow/_mods/pr-merge.md"; then
  pass "Case-5 docs wire merge-state polling to additive resolver"
else
  fail "Case-5 docs missing merge-state polling/additive resolver contract"
fi

exit "$FAIL"
