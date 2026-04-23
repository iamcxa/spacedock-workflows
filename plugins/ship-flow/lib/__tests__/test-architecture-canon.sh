#!/usr/bin/env bash
# test-architecture-canon.sh — DC-1..DC-10 for #060 architecture-canon-mod
# Pattern: test-map-layer.sh + test-check-invariants.sh (same dir) — FAIL=0, exit $FAIL.
#
# Pre-impl expectation (T1 ships before T2-T6): all 10 DCs FAIL because
#   - docs/ship-flow/_mods/architecture-canon.md doesn't exist     (DC-1..5, 9, 10 part b)
#   - plugins/ship-flow/skills/ship-shape/SKILL.md has no arch refs (DC-6)
#   - plugins/ship-flow/skills/ship-execute/SKILL.md has no extract-map on ARCHITECTURE.md (DC-7)
#   - plugins/ship-flow/references/entity-body-schema.yaml has no section_tag: architecture-impact (DC-8)
# Post-impl (after T2-T6): all 10 DCs PASS.
#
# Fixture strategy: inline heredoc + mktemp -d scratch (matches test-check-invariants.sh
# and test-map-layer.sh DC-8 patterns — NOT plan's suggested tests/__fixtures__/ path,
# which is absent from the project).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
PLUGIN_DIR="${LIB_DIR}/.."
REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"

MOD_FILE="${REPO_ROOT}/docs/ship-flow/_mods/architecture-canon.md"
SHARP_SKILL="${PLUGIN_DIR}/skills/ship-shape/SKILL.md"
EXECUTE_SKILL="${PLUGIN_DIR}/skills/ship-execute/SKILL.md"
SCHEMA="${PLUGIN_DIR}/references/entity-body-schema.yaml"
ARCH_SRC="${REPO_ROOT}/ARCHITECTURE.md"
FAIL=0

# shellcheck source=../map-helpers.sh
[ -f "${LIB_DIR}/map-helpers.sh" ] && source "${LIB_DIR}/map-helpers.sh"

# ---- Assertion helpers (copied from test-map-layer.sh:13-31) ----
# shellcheck disable=SC2329  # helpers invoked via eval / conditional use
assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}
# shellcheck disable=SC2329
assert_stdout_matches() {
  local pattern="$1" cmd="$2" name="$3"
  local out; out="$(eval "$cmd" 2>&1)"
  if echo "$out" | grep -qE "$pattern"; then echo "OK $name"
  else echo "FAIL $name (stdout/stderr did not match /$pattern/)"; FAIL=1; fi
}
# shellcheck disable=SC2329
assert_stderr_contains() {
  local needle="$1" cmd="$2" name="$3"
  local err; err="$(eval "$cmd" 2>&1 >/dev/null)"
  if echo "$err" | grep -qF "$needle"; then echo "OK $name"
  else echo "FAIL $name (stderr missing: $needle)"; FAIL=1; fi
}

# ---- Mock env helper ----
# Creates a scratch git repo with ARCHITECTURE.md, all lib/*.sh, flow-map-schema.yaml, and
# mod file (if it exists). Returns path on stdout. Caller runs `cd "$d" && bash docs/.../mod`
# then rm -rf "$d".
create_mock_arch_env() {
  local d; d="$(mktemp -d)" || return 1
  (
    cd "$d" || exit 1
    git init -q
    git config user.email t@t
    git config user.name t
    mkdir -p plugins/ship-flow/lib plugins/ship-flow/references docs/ship-flow/_mods
    cp "$ARCH_SRC" ARCHITECTURE.md
    cp "${LIB_DIR}"/*.sh plugins/ship-flow/lib/
    cp "${PLUGIN_DIR}/references/flow-map-schema.yaml" plugins/ship-flow/references/
    if [ -f "$MOD_FILE" ]; then cp "$MOD_FILE" docs/ship-flow/_mods/architecture-canon.md; fi
    chmod +x plugins/ship-flow/lib/*.sh
    git add -A >/dev/null
    git commit -qm init >/dev/null
  ) || { rm -rf "$d"; return 1; }
  echo "$d"
}

# Indent each stdin line with 2 spaces (for YAML block-scalar embedding).
# shellcheck disable=SC2329  # used in emit_fixture's subshell
indent2() { sed 's/^/  /'; }

# Emit fixture entity markdown to stdout with an architecture-impact section.
# Args: $1 = target_section, $2 = before body file, $3 = after body file, $4 = summary (optional)
# shellcheck disable=SC2329  # used by DC functions below
emit_fixture() {
  local target="$1" bfile="$2" afile="$3" summary="${4:-test patch}"
  cat <<EOF
---
id: "999"
slug: "fx-architecture-canon"
---

<!-- section:architecture-impact -->
### Architecture Impact

target_section: ${target}
summary: ${summary}
before: |
$(indent2 < "$bfile")
after: |
$(indent2 < "$afile")
rationale: test fixture
<!-- /section:architecture-impact -->
EOF
}

cd "$REPO_ROOT" || exit 1

# ========== DC-1: valid architecture-impact → mod echoes patch-map with correct args ==========
# Mod in --fixture mode prints "DRY-RUN: patch-map.sh ..." (or similar) for each planned
# patch-map invocation so tests can assert arg shape without requiring committed state.
dc1_valid_impact_patches() {
  local d; d="$(create_mock_arch_env)" || return 1
  local bfile="$d/before.md" afile="$d/after.md"
  bash "${LIB_DIR}/extract-map.sh" "$d/ARCHITECTURE.md" constraints > "$bfile"
  { cat "$bfile"; echo "| **DC1 test constraint** | fixture | rollback: remove line |"; } > "$afile"
  emit_fixture constraints "$bfile" "$afile" > "$d/fixture.md"

  local out rc
  out="$(cd "$d" && bash docs/ship-flow/_mods/architecture-canon.md --fixture fixture.md 2>&1)"
  rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ] || return 1
  # Use `-e PATTERN` to disambiguate patterns starting with `--` from grep options (macOS grep).
  echo "$out" | grep -qE -e "patch-map\\.sh ARCHITECTURE\\.md constraints.*--if-hash=" && \
    echo "$out" | grep -qE -e '--commit-as="docs\(architecture\)'
}
if dc1_valid_impact_patches 2>/dev/null; then echo "OK DC-1 valid impact → patch-map args correct"
else echo "FAIL DC-1 valid impact → patch-map args correct"; FAIL=1; fi

# ========== DC-2: no architecture-impact → mod noop (exit 0, no patch-map calls) ==========
dc2_no_impact_noop() {
  local d; d="$(create_mock_arch_env)" || return 1
  cat > "$d/fixture.md" <<'EOF'
---
id: "998"
slug: "fx-no-impact"
---

## Some Other Section

No architecture-impact section in this fixture.
EOF
  local out rc
  out="$(cd "$d" && bash docs/ship-flow/_mods/architecture-canon.md --fixture fixture.md 2>&1)"
  rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ] || return 1
  ! echo "$out" | grep -q "patch-map\\.sh ARCHITECTURE\\.md"
}
if dc2_no_impact_noop 2>/dev/null; then echo "OK DC-2 no impact → noop exit 0 no patch-map"
else echo "FAIL DC-2 no impact → noop exit 0 no patch-map"; FAIL=1; fi

# ========== DC-3: stale before → mod rejects with "freshness" stderr ==========
dc3_stale_before_rejects() {
  local d; d="$(create_mock_arch_env)" || return 1
  local bfile="$d/before.md" afile="$d/after.md"
  { bash "${LIB_DIR}/extract-map.sh" "$d/ARCHITECTURE.md" constraints
    echo "STALE MARKER LINE — not in current ARCHITECTURE.md"; } > "$bfile"
  echo "new after content" > "$afile"
  emit_fixture constraints "$bfile" "$afile" > "$d/fixture.md"

  local err rc
  err="$(cd "$d" && bash docs/ship-flow/_mods/architecture-canon.md --fixture fixture.md 2>&1 >/dev/null)"
  rc=$?
  rm -rf "$d"
  [ "$rc" != "0" ] || return 1
  echo "$err" | grep -qi "freshness"
}
if dc3_stale_before_rejects 2>/dev/null; then echo "OK DC-3 stale before → mod rejects with 'freshness'"
else echo "FAIL DC-3 stale before → mod rejects with 'freshness'"; FAIL=1; fi

# ========== DC-4: target=containers, after lacks mermaid → patch-map exit 9 surfaced ==========
dc4_missing_diagram_rejects() {
  local d; d="$(create_mock_arch_env)" || return 1
  local bfile="$d/before.md" afile="$d/after.md"
  bash "${LIB_DIR}/extract-map.sh" "$d/ARCHITECTURE.md" containers > "$bfile"
  cat > "$afile" <<'EOF'
## Containers
Plain text container description — no mermaid block.
- App
- DB
EOF
  emit_fixture containers "$bfile" "$afile" > "$d/fixture.md"

  local out rc
  out="$(cd "$d" && bash docs/ship-flow/_mods/architecture-canon.md --fixture fixture.md 2>&1)"
  rc=$?
  rm -rf "$d"
  [ "$rc" != "0" ] || return 1
  echo "$out" | grep -qiE "exit 9|mermaid|diagram"
}
if dc4_missing_diagram_rejects 2>/dev/null; then echo "OK DC-4 missing diagram → non-zero w/ mermaid diagnostic"
else echo "FAIL DC-4 missing diagram → non-zero w/ mermaid diagnostic"; FAIL=1; fi

# ========== DC-5: decisions table gets new row via extract-then-patch ==========
dc5_decisions_append() {
  local d; d="$(create_mock_arch_env)" || return 1
  local bfile="$d/before.md" afile="$d/after.md"
  bash "${LIB_DIR}/extract-map.sh" "$d/ARCHITECTURE.md" constraints > "$bfile"
  { cat "$bfile"; echo "| **DC5 constraint** | fixture | rollback |"; } > "$afile"
  emit_fixture constraints "$bfile" "$afile" > "$d/fixture.md"

  local out rc
  out="$(cd "$d" && bash docs/ship-flow/_mods/architecture-canon.md --fixture fixture.md 2>&1)"
  rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ] || return 1
  echo "$out" | grep -qE "patch-map\\.sh ARCHITECTURE\\.md decisions"
}
if dc5_decisions_append 2>/dev/null; then echo "OK DC-5 decisions table append via extract-then-patch"
else echo "FAIL DC-5 decisions table append via extract-then-patch"; FAIL=1; fi

# ========== DC-6: ship-sharp SKILL has ≥3 architecture-impact refs ==========
dc6_sharp_skill_refs() {
  [ -f "$SHARP_SKILL" ] || return 1
  local n; n="$(grep -c 'architecture-impact' "$SHARP_SKILL" 2>/dev/null || echo 0)"
  [ "$n" -ge 3 ]
}
if dc6_sharp_skill_refs 2>/dev/null; then echo "OK DC-6 ship-shape SKILL architecture-impact ≥3"
else echo "FAIL DC-6 ship-shape SKILL architecture-impact ≥3"; FAIL=1; fi

# ========== DC-7: ship-execute SKILL has extract-map on ARCHITECTURE.md ≥1 ==========
dc7_execute_skill_refs() {
  [ -f "$EXECUTE_SKILL" ] || return 1
  local n; n="$(grep -cE 'extract-map.*ARCHITECTURE\.md' "$EXECUTE_SKILL" 2>/dev/null || echo 0)"
  [ "$n" -ge 1 ]
}
if dc7_execute_skill_refs 2>/dev/null; then echo "OK DC-7 ship-execute SKILL extract-map on ARCHITECTURE.md"
else echo "FAIL DC-7 ship-execute SKILL extract-map on ARCHITECTURE.md"; FAIL=1; fi

# ========== DC-8: entity-body-schema declares architecture-impact with required fields ==========
dc8_schema_declares_section() {
  [ -f "$SCHEMA" ] || return 1
  grep -q "section_tag: architecture-impact" "$SCHEMA" || return 1
  local block; block="$(grep -A 30 "section_tag: architecture-impact" "$SCHEMA" 2>/dev/null)"
  echo "$block" | grep -qE "name: target_section" && \
    echo "$block" | grep -qE "name: summary" && \
    echo "$block" | grep -qE "name: before" && \
    echo "$block" | grep -qE "name: after"
}
if dc8_schema_declares_section 2>/dev/null; then echo "OK DC-8 schema declares architecture-impact + fields"
else echo "FAIL DC-8 schema declares architecture-impact + fields"; FAIL=1; fi

# ========== DC-9: freshness normalizes trim+LF — trailing whitespace tolerated ==========
dc9_freshness_tolerates_trim() {
  local d; d="$(create_mock_arch_env)" || return 1
  local bfile="$d/before.md" afile="$d/after.md"
  { bash "${LIB_DIR}/extract-map.sh" "$d/ARCHITECTURE.md" constraints
    printf '   \n\n'; } > "$bfile"
  { cat "$bfile"; echo "| **DC9 line** | fixture | rollback |"; } > "$afile"
  emit_fixture constraints "$bfile" "$afile" > "$d/fixture.md"

  local rc
  (cd "$d" && bash docs/ship-flow/_mods/architecture-canon.md --fixture fixture.md >/dev/null 2>&1)
  rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if dc9_freshness_tolerates_trim 2>/dev/null; then echo "OK DC-9 freshness normalizes trim+LF"
else echo "FAIL DC-9 freshness normalizes trim+LF"; FAIL=1; fi

# ========== DC-10: shellcheck clean on test harness + mod bash ==========
# Mod uses noop-heredoc pattern (`: <<'MARKDOWN'...MARKDOWN`) to stay human-readable
# as markdown while remaining bash-executable — so we shellcheck the whole file
# directly, NOT fenced ```bash blocks (which plan originally anticipated).
dc10_shellcheck_clean() {
  command -v shellcheck >/dev/null 2>&1 || return 0  # SKIP if shellcheck missing
  shellcheck -S warning "${SCRIPT_DIR}/test-architecture-canon.sh" >/dev/null 2>&1 || return 1
  [ -f "$MOD_FILE" ] || return 1
  shellcheck -S warning "$MOD_FILE" >/dev/null 2>&1
}
if dc10_shellcheck_clean 2>/dev/null; then echo "OK DC-10 shellcheck clean (test + mod bash)"
else echo "FAIL DC-10 shellcheck clean (test + mod bash)"; FAIL=1; fi

exit $FAIL
