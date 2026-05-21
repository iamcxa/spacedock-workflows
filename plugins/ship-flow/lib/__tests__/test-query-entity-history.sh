#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
HELPER="${LIB_DIR}/query-entity-history.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/query-entity-history.XXXXXX")"
WORKFLOW_DIR="${TMP_DIR}/workflow"
ARCHIVE_DIR="${WORKFLOW_DIR}/_archive"
FAIL=0

trap 'rm -rf "$TMP_DIR"' EXIT

pass() {
  echo "OK $1"
}

fail() {
  echo "FAIL $1"
  FAIL=1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local desc="$3"
  if grep -qE "$pattern" "$file"; then
    pass "$desc"
  else
    fail "$desc (missing pattern: ${pattern})"
    sed 's/^/  | /' "$file"
  fi
}

write_folder_entity() {
  local dir="$1" size="$2" appetite="$3" domain="$4" started="$5" completed="$6"
  local entity_id
  entity_id="$(basename "$dir")"
  mkdir -p "$dir"
  cat > "${dir}/index.md" <<EOF
---
id: "${entity_id}"
status: done
size: ${size}
appetite: "${appetite}"
domain: ${domain}
started: ${started}
completed: ${completed}
---

body
EOF
}

mkdir -p "$ARCHIVE_DIR"

write_folder_entity "${ARCHIVE_DIR}/s-fast" S small-batch workflow 2026-01-01T00:00:00Z 2026-01-01T01:00:00Z
write_folder_entity "${ARCHIVE_DIR}/s-mid" S small-batch workflow 2026-01-02T00:00:00Z 2026-01-02T03:00:00Z
write_folder_entity "${ARCHIVE_DIR}/s-slow" S small-batch workflow 2026-01-03T00:00:00Z 2026-01-03T05:00:00Z
write_folder_entity "${ARCHIVE_DIR}/s-offset" S small-batch workflow 2026-01-10T01:00:00+08:00 2026-01-09T19:00:00Z
write_folder_entity "${ARCHIVE_DIR}/s-other-domain" S small-batch design 2026-01-04T00:00:00Z 2026-01-04T09:00:00Z
write_folder_entity "${ARCHIVE_DIR}/m-record" M medium-batch workflow 2026-01-05T00:00:00Z 2026-01-05T10:00:00Z
write_folder_entity "${ARCHIVE_DIR}/date-only" S small-batch workflow 2026-01-06 2026-01-07

mkdir -p "${ARCHIVE_DIR}/missing-started"
cat > "${ARCHIVE_DIR}/missing-started/index.md" <<'EOF'
---
id: missing-started
size: S
appetite: small-batch
domain: workflow
completed: 2026-01-08T01:00:00Z
---
EOF

mkdir -p "${ARCHIVE_DIR}/malformed-completed"
cat > "${ARCHIVE_DIR}/malformed-completed/index.md" <<'EOF'
---
id: malformed-completed
size: S
appetite: small-batch
domain: workflow
started: 2026-01-09T00:00:00Z
completed: not-a-date
---
EOF

if [ ! -x "$HELPER" ]; then
  fail "query-entity-history.sh exists and is executable"
  exit "$FAIL"
fi

HELP_OUT="${TMP_DIR}/help.out"
"$HELPER" --help > "$HELP_OUT" 2>"${TMP_DIR}/help.err"
assert_contains "$HELP_OUT" 'query-entity-history\.sh --workflow-dir' "help prints usage"
if grep -q '_archive/\*\.md' "$HELP_OUT"; then
  fail "help omits top-level archive file support claims"
else
  pass "help omits top-level archive file support claims"
fi

SIZE_OUT="${TMP_DIR}/size.out"
SIZE_ERR="${TMP_DIR}/size.err"
"$HELPER" --workflow-dir "$WORKFLOW_DIR" --size S > "$SIZE_OUT" 2>"$SIZE_ERR"
assert_contains "$SIZE_OUT" '^matched_count=6$' "size selector includes folder, date-only, and offset records"
assert_contains "$SIZE_OUT" '^median_seconds=14400$' "size selector reports median duration"
assert_contains "$SIZE_OUT" '^median_human=4h 0m$' "size selector reports human median"
assert_contains "$SIZE_OUT" '^selector=size:S,appetite:,domain:$' "size selector echoed"
assert_contains "$SIZE_ERR" 'warning=skipped_incomplete:.*/missing-started/index.md' "missing timestamps are skipped with warning"
assert_contains "$SIZE_ERR" 'warning=skipped_malformed:.*/malformed-completed/index.md' "malformed timestamps are skipped with warning"

APPETITE_OUT="${TMP_DIR}/appetite.out"
"$HELPER" --workflow-dir "$WORKFLOW_DIR" --appetite small-batch > "$APPETITE_OUT" 2>"${TMP_DIR}/appetite.err"
assert_contains "$APPETITE_OUT" '^matched_count=6$' "appetite selector matches without size"
assert_contains "$APPETITE_OUT" '^median_seconds=14400$' "appetite selector reports integer-average median"

DOMAIN_OUT="${TMP_DIR}/domain.out"
"$HELPER" --workflow-dir "$WORKFLOW_DIR" --appetite small-batch --domain workflow > "$DOMAIN_OUT" 2>"${TMP_DIR}/domain.err"
assert_contains "$DOMAIN_OUT" '^matched_count=5$' "domain selector narrows matches"
assert_contains "$DOMAIN_OUT" '^median_seconds=10800$' "domain selector reports narrowed median"
assert_contains "$DOMAIN_OUT" '^selector=size:,appetite:small-batch,domain:workflow$' "domain selector echoed"

NO_MATCH_OUT="${TMP_DIR}/no-match.out"
NO_MATCH_ERR="${TMP_DIR}/no-match.err"
"$HELPER" --workflow-dir "$WORKFLOW_DIR" --size L > "$NO_MATCH_OUT" 2>"$NO_MATCH_ERR"
NO_MATCH_RC=$?
if [ "$NO_MATCH_RC" = "3" ]; then
  pass "no-match exits 3"
else
  fail "no-match exits 3 (got ${NO_MATCH_RC})"
fi
assert_contains "$NO_MATCH_OUT" '^matched_count=0$' "no-match reports zero matches"

exit "$FAIL"
