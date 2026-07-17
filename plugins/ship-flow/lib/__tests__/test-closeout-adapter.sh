#!/usr/bin/env bash
# test-closeout-adapter.sh - merged PR closeout reconciler contract

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/bin/closeout-adapter.sh"
STATUS_BIN="${STATUS_BIN:-}"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/closeout-adapter"

PASS=0
FAIL=0
ERRORS=()

record_pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

record_fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
  ERRORS+=("$1")
}

assert_exit() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (expected exit ${expected}, got ${actual})"
  fi
}

assert_contains() {
  local desc="$1"
  local pattern="$2"
  local file="$3"
  if grep -qE "$pattern" "$file"; then
    record_pass "$desc"
  else
    record_fail "$desc (missing pattern: ${pattern})"
  fi
}

assert_not_contains() {
  local desc="$1"
  local pattern="$2"
  local file="$3"
  if grep -qE "$pattern" "$file"; then
    record_fail "$desc (unexpected pattern: ${pattern})"
  else
    record_pass "$desc"
  fi
}

assert_file_exists() {
  local desc="$1"
  local file="$2"
  if [ -f "$file" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (missing file: ${file})"
  fi
}

assert_path_missing() {
  local desc="$1"
  local path="$2"
  if [ ! -e "$path" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (path still exists: ${path})"
  fi
}

assert_path_exists() {
  local desc="$1"
  local path="$2"
  if [ -e "$path" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (missing path: ${path})"
  fi
}

assert_equals() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (expected ${expected}, got ${actual})"
  fi
}

frontmatter_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 {
      prefix = field ":"
      if (index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        gsub(/^["'\''"]|["'\''"]$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

assert_frontmatter_equals() {
  local desc="$1"
  local file="$2"
  local field="$3"
  local expected="$4"
  local actual
  actual="$(frontmatter_field "$file" "$field")"
  if [ "$actual" = "$expected" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (expected ${field}=${expected}, got ${actual})"
  fi
}

assert_frontmatter_nonempty() {
  local desc="$1"
  local file="$2"
  local field="$3"
  local actual
  actual="$(frontmatter_field "$file" "$field")"
  if [ -n "$actual" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (${field} was empty)"
  fi
}

hash_tree() {
  local path="$1"
  if [ ! -d "$path" ]; then
    echo "missing"
    return
  fi
  find "$path" -type f -print | sort | while IFS= read -r file; do
    shasum -a 256 "$file"
  done | shasum -a 256 | awk '{print $1}'
}

write_workflow_readme() {
  local workflow_dir="$1"
  cat > "${workflow_dir}/README.md" <<'EOF'
---
commissioned-by: spacedock@0.22.0
id-style: slug
stages:
  states:
    - name: ship
      next: done
      worktree: true
    - name: done
      terminal: true
      worktree: false
---

# Fixture Workflow
EOF
}

write_pr_merge_mod() {
  local workflow_dir="$1"
  mkdir -p "${workflow_dir}/_mods"
  cat > "${workflow_dir}/_mods/pr-merge.md" <<'EOF'
---
name: pr-merge
standing: true
---

## Agent Prompt

Fixture merge hook.
EOF
}

write_fixture_status_bin() {
  local bin="$1"
  cat > "$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# --- merge guard <slug> --verdict <v> [--workflow-dir <dir>] --------------
# Faithful encoding of the REAL installed spacedock 0.25.0 `merge guard`
# contract, empirically pinned (see 6.1-closeout-adapter-single-authority
# plan.md Research Summary + this dispatch's own live probes against the
# real binary): outcome is driven by the target entity's on-disk state, not
# a canned response, so callers exercising different entity fixtures get the
# real decision tree. Four outcomes: finalized (exit 0), blocked (exit 0,
# non-error), entity-not-found (exit 1), archived-read-only-on-replay
# (exit 1). MERGE_GUARD_FORCE_BLOCKED=<slug> is a test-only override (not
# part of the real contract) for exercising the adapter's "blocked"
# interpretation branch even when a sentinel is already present.
if [ "${1:-}" = merge ] && [ "${2:-}" = guard ]; then
  shift 2
  mg_slug="${1:-}"
  shift || true
  mg_workflow_dir=""
  mg_verdict=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --verdict) mg_verdict="$2"; shift 2 ;;
      --workflow-dir) mg_workflow_dir="$2"; shift 2 ;;
      --json|--quiet) shift ;;
      *) shift ;;
    esac
  done
  [ -n "$mg_workflow_dir" ] || { echo "Error: --workflow-dir required" >&2; exit 2; }
  [ -n "$mg_verdict" ] || { echo "Error: --verdict required" >&2; exit 2; }

  mg_frontmatter_field() {
    local file="$1" field="$2"
    awk -v field="$field" '
      /^---[[:space:]]*$/ { fence++; next }
      fence == 1 {
        prefix = field ":"
        if (index($0, prefix) == 1) {
          value = substr($0, length(prefix) + 1)
          sub(/^[[:space:]]*/, "", value)
          sub(/[[:space:]]*$/, "", value)
          gsub(/^["'\''"]|["'\''"]$/, "", value)
          print value
          exit
        }
      }
    ' "$file"
  }
  mg_update_frontmatter_field() {
    local file="$1" field="$2" value="$3"
    local tmp="${file}.tmp"
    awk -v field="$field" -v value="$value" '
      /^---[[:space:]]*$/ { fence++; print; next }
      fence == 1 {
        prefix = field ":"
        if (index($0, prefix) == 1) {
          print field ": " value
          next
        }
      }
      { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  }

  mg_active_path="${mg_workflow_dir}/${mg_slug}/index.md"
  mg_archived_path="${mg_workflow_dir}/_archive/${mg_slug}/index.md"

  if [ -n "${MERGE_GUARD_FORCE_BLOCKED:-}" ] && [ "$mg_slug" = "$MERGE_GUARD_FORCE_BLOCKED" ]; then
    echo "blocked: PR is pending — mod-block left intact, never finalize on an open PR. When gh reports it MERGED, record the sentinel (pr=pr-merge:{number}) and re-run \`merge guard ${mg_slug}\`."
    exit 0
  fi

  if [ -f "$mg_archived_path" ]; then
    echo "Error: archived entity is read-only: ${mg_slug}" >&2
    exit 1
  fi
  if [ ! -f "$mg_active_path" ]; then
    echo "Error: entity not found: ${mg_slug}" >&2
    exit 1
  fi

  mg_pr="$(mg_frontmatter_field "$mg_active_path" pr)"
  case "$mg_pr" in
    pr-merge:*)
      mg_update_frontmatter_field "$mg_active_path" status done
      mg_update_frontmatter_field "$mg_active_path" verdict PASSED
      mg_update_frontmatter_field "$mg_active_path" completed 2026-05-06T00:00:00Z
      mg_update_frontmatter_field "$mg_active_path" worktree ""
      mkdir -p "${mg_workflow_dir}/_archive"
      mv "${mg_workflow_dir}/${mg_slug}" "${mg_workflow_dir}/_archive/${mg_slug}"
      echo "finalized: ${mg_slug} -> done (verdict ${mg_verdict}), archived."
      exit 0
      ;;
    *)
      echo "blocked: PR ${mg_pr} is pending — mod-block left intact, never finalize on an open PR. When gh reports it MERGED, record the sentinel (pr=pr-merge:{number}) and re-run \`merge guard ${mg_slug}\`."
      exit 0
      ;;
  esac
fi

# `spacedock dispatch trunk --workflow-dir DIR` — trunk (integration base)
# resolver the adapter's wrong-branch safety gate calls. Real 0.25.0 emits a
# bare branch name (default `main`, no `trunk:` key); fixtures init on `main`.
if [ "${1:-}" = dispatch ] && [ "${2:-}" = trunk ]; then
  echo main
  exit 0
fi

workflow_dir=""
include_archived=no
cmd=""
ref=""
where_expr=""
slug=""

# Repoint: invoked as `spacedock status <args>` — skip leading subcommand.
[ "${1:-}" = status ] && shift

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workflow-dir)
      workflow_dir="$2"
      shift 2
      ;;
    --archived)
      include_archived=yes
      shift
      ;;
    --resolve)
      cmd=resolve
      ref="$2"
      shift 2
      ;;
    --where)
      cmd=where
      where_expr="$2"
      shift 2
      ;;
    --set)
      cmd=set
      slug="$2"
      shift 2
      break
      ;;
    --archive)
      cmd=archive
      slug="$2"
      shift 2
      ;;
    *)
      echo "unknown status arg: $1" >&2
      exit 2
      ;;
  esac
done

[ -n "$workflow_dir" ] || exit 2

frontmatter_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 {
      prefix = field ":"
      if (index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        gsub(/^["'\''"]|["'\''"]$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

update_frontmatter_field() {
  local file="$1"
  local field="$2"
  local value="$3"
  local tmp="${file}.tmp"
  awk -v field="$field" -v value="$value" '
    /^---[[:space:]]*$/ { fence++; print; next }
    fence == 1 {
      prefix = field ":"
      if (index($0, prefix) == 1) {
        print field ": " value
        next
      }
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

resolve_path() {
  local raw="$1"
  raw="${raw#archive:}"
  if [ "$include_archived" = yes ]; then
    printf '%s/_archive/%s/index.md\n' "$workflow_dir" "$raw"
  else
    printf '%s/%s/index.md\n' "$workflow_dir" "$raw"
  fi
}

case "$cmd" in
  resolve)
    path="$(resolve_path "$ref")"
    [ -f "$path" ] || exit 1
    slug_value="${ref#archive:}"
    printf 'slug=%s path=%s\n' "$slug_value" "$path"
    ;;
  where)
    slug_value="$(printf '%s\n' "$where_expr" | sed -E 's/^slug[[:space:]]*=[[:space:]]*//')"
    path="${workflow_dir}/_archive/${slug_value}/index.md"
    [ -f "$path" ] || exit 1
    printf 'slug=%s path=%s status=%s\n' "$slug_value" "$path" "$(frontmatter_field "$path" status)"
    ;;
  set)
    path="${workflow_dir}/${slug}/index.md"
    [ -f "$path" ] || exit 1
    for pair in "$@"; do
      case "$pair" in
        *=*)
          key="${pair%%=*}"
          value="${pair#*=}"
          ;;
        completed)
          key=completed
          value=2026-05-06T00:00:00Z
          ;;
        *)
          echo "unsupported set pair: $pair" >&2
          exit 2
          ;;
      esac
      update_frontmatter_field "$path" "$key" "$value"
    done
    ;;
  archive)
    path="${workflow_dir}/${slug}/index.md"
    [ -f "$path" ] || exit 1
    update_frontmatter_field "$path" archived 2026-05-06T00:01:00Z
    mkdir -p "${workflow_dir}/_archive"
    mv "${workflow_dir}/${slug}" "${workflow_dir}/_archive/${slug}"
    ;;
  *)
    echo "missing status command" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "$bin"
}

# write_fixture_status_bin_faithful - ISOLATED variant of write_fixture_status_bin
# (never mutates the shared stub or any existing case). Reproduces the two real
# `spacedock merge guard` 0.25.0 behaviors the shared stub does NOT: (1) the
# archive move is committed by merge guard itself (subject "archive <slug>
# (merge guard)"), leaving a clean tree instead of a pending mv for the caller
# to commit; (2) the archived verdict is written lowercase (`verdict: passed`)
# rather than the shared stub's `PASSED`. Everything else (resolve/where/set,
# the blocked/not-found/read-only branches) is identical to the shared stub so
# the adapter's non-merge-guard status calls keep working unmodified.
write_fixture_status_bin_faithful() {
  local bin="$1"
  cat > "$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# --- merge guard <slug> --verdict <v> [--workflow-dir <dir>] --------------
# Faithful encoding of the REAL installed spacedock 0.25.0 `merge guard`
# self-commit contract (empirically pinned): merge guard performs the
# archive-move AND commits it itself, leaving a clean tree, and writes
# verdict lowercase.
if [ "${1:-}" = merge ] && [ "${2:-}" = guard ]; then
  shift 2
  mg_slug="${1:-}"
  shift || true
  mg_workflow_dir=""
  mg_verdict=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --verdict) mg_verdict="$2"; shift 2 ;;
      --workflow-dir) mg_workflow_dir="$2"; shift 2 ;;
      --json|--quiet) shift ;;
      *) shift ;;
    esac
  done
  [ -n "$mg_workflow_dir" ] || { echo "Error: --workflow-dir required" >&2; exit 2; }
  [ -n "$mg_verdict" ] || { echo "Error: --verdict required" >&2; exit 2; }

  mg_frontmatter_field() {
    local file="$1" field="$2"
    awk -v field="$field" '
      /^---[[:space:]]*$/ { fence++; next }
      fence == 1 {
        prefix = field ":"
        if (index($0, prefix) == 1) {
          value = substr($0, length(prefix) + 1)
          sub(/^[[:space:]]*/, "", value)
          sub(/[[:space:]]*$/, "", value)
          gsub(/^["'\''"]|["'\''"]$/, "", value)
          print value
          exit
        }
      }
    ' "$file"
  }
  mg_update_frontmatter_field() {
    local file="$1" field="$2" value="$3"
    local tmp="${file}.tmp"
    awk -v field="$field" -v value="$value" '
      /^---[[:space:]]*$/ { fence++; print; next }
      fence == 1 {
        prefix = field ":"
        if (index($0, prefix) == 1) {
          print field ": " value
          next
        }
      }
      { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  }

  mg_active_path="${mg_workflow_dir}/${mg_slug}/index.md"
  mg_archived_path="${mg_workflow_dir}/_archive/${mg_slug}/index.md"

  if [ -n "${MERGE_GUARD_FORCE_BLOCKED:-}" ] && [ "$mg_slug" = "$MERGE_GUARD_FORCE_BLOCKED" ]; then
    echo "blocked: PR is pending — mod-block left intact, never finalize on an open PR. When gh reports it MERGED, record the sentinel (pr=pr-merge:{number}) and re-run \`merge guard ${mg_slug}\`."
    exit 0
  fi

  if [ -f "$mg_archived_path" ]; then
    echo "Error: archived entity is read-only: ${mg_slug}" >&2
    exit 1
  fi
  if [ ! -f "$mg_active_path" ]; then
    echo "Error: entity not found: ${mg_slug}" >&2
    exit 1
  fi

  mg_pr="$(mg_frontmatter_field "$mg_active_path" pr)"
  case "$mg_pr" in
    pr-merge:*)
      mg_update_frontmatter_field "$mg_active_path" status done
      mg_update_frontmatter_field "$mg_active_path" verdict passed
      mg_update_frontmatter_field "$mg_active_path" completed 2026-05-06T00:00:00Z
      mg_update_frontmatter_field "$mg_active_path" worktree ""
      mg_update_frontmatter_field "$mg_active_path" archived 2026-05-06T00:01:00Z
      mkdir -p "${mg_workflow_dir}/_archive"
      mv "${mg_workflow_dir}/${mg_slug}" "${mg_workflow_dir}/_archive/${mg_slug}"
      mg_repo_root="$(git -C "$mg_workflow_dir" rev-parse --show-toplevel)"
      git -C "$mg_repo_root" add -- "${mg_workflow_dir}/${mg_slug}" "${mg_workflow_dir}/_archive/${mg_slug}" >/dev/null 2>&1 || true
      git -C "$mg_repo_root" commit -q -m "archive ${mg_slug} (merge guard)" \
          -- "${mg_workflow_dir}/${mg_slug}" "${mg_workflow_dir}/_archive/${mg_slug}"
      echo "finalized: ${mg_slug} -> done (verdict ${mg_verdict}), archived."
      exit 0
      ;;
    *)
      echo "blocked: PR ${mg_pr} is pending — mod-block left intact, never finalize on an open PR. When gh reports it MERGED, record the sentinel (pr=pr-merge:{number}) and re-run \`merge guard ${mg_slug}\`."
      exit 0
      ;;
  esac
fi

# `spacedock dispatch trunk --workflow-dir DIR` — trunk (integration base)
# resolver the adapter's wrong-branch safety gate calls. Real 0.25.0 emits a
# bare branch name (default `main`, no `trunk:` key); fixtures init on `main`.
if [ "${1:-}" = dispatch ] && [ "${2:-}" = trunk ]; then
  echo main
  exit 0
fi

workflow_dir=""
include_archived=no
cmd=""
ref=""
where_expr=""
slug=""

# Repoint: invoked as `spacedock status <args>` — skip leading subcommand.
[ "${1:-}" = status ] && shift

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workflow-dir)
      workflow_dir="$2"
      shift 2
      ;;
    --archived)
      include_archived=yes
      shift
      ;;
    --resolve)
      cmd=resolve
      ref="$2"
      shift 2
      ;;
    --where)
      cmd=where
      where_expr="$2"
      shift 2
      ;;
    --set)
      cmd=set
      slug="$2"
      shift 2
      break
      ;;
    --archive)
      cmd=archive
      slug="$2"
      shift 2
      ;;
    *)
      echo "unknown status arg: $1" >&2
      exit 2
      ;;
  esac
done

[ -n "$workflow_dir" ] || exit 2

frontmatter_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 {
      prefix = field ":"
      if (index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        gsub(/^["'\''"]|["'\''"]$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

update_frontmatter_field() {
  local file="$1"
  local field="$2"
  local value="$3"
  local tmp="${file}.tmp"
  awk -v field="$field" -v value="$value" '
    /^---[[:space:]]*$/ { fence++; print; next }
    fence == 1 {
      prefix = field ":"
      if (index($0, prefix) == 1) {
        print field ": " value
        next
      }
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

resolve_path() {
  local raw="$1"
  raw="${raw#archive:}"
  if [ "$include_archived" = yes ]; then
    printf '%s/_archive/%s/index.md\n' "$workflow_dir" "$raw"
  else
    printf '%s/%s/index.md\n' "$workflow_dir" "$raw"
  fi
}

case "$cmd" in
  resolve)
    path="$(resolve_path "$ref")"
    [ -f "$path" ] || exit 1
    slug_value="${ref#archive:}"
    printf 'slug=%s path=%s\n' "$slug_value" "$path"
    ;;
  where)
    slug_value="$(printf '%s\n' "$where_expr" | sed -E 's/^slug[[:space:]]*=[[:space:]]*//')"
    path="${workflow_dir}/_archive/${slug_value}/index.md"
    [ -f "$path" ] || exit 1
    printf 'slug=%s path=%s status=%s\n' "$slug_value" "$path" "$(frontmatter_field "$path" status)"
    ;;
  set)
    path="${workflow_dir}/${slug}/index.md"
    [ -f "$path" ] || exit 1
    for pair in "$@"; do
      case "$pair" in
        *=*)
          key="${pair%%=*}"
          value="${pair#*=}"
          ;;
        completed)
          key=completed
          value=2026-05-06T00:00:00Z
          ;;
        *)
          echo "unsupported set pair: $pair" >&2
          exit 2
          ;;
      esac
      update_frontmatter_field "$path" "$key" "$value"
    done
    ;;
  archive)
    path="${workflow_dir}/${slug}/index.md"
    [ -f "$path" ] || exit 1
    update_frontmatter_field "$path" archived 2026-05-06T00:01:00Z
    mkdir -p "${workflow_dir}/_archive"
    mv "${workflow_dir}/${slug}" "${workflow_dir}/_archive/${slug}"
    ;;
  *)
    echo "missing status command" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "$bin"
}

write_entity() {
  local workflow_dir="$1"
  local slug="$2"
  local status="$3"
  local pr="$4"
  local worktree="$5"
  local completed="${6:-}"
  local verdict="${7:-}"
  local archived="${8:-}"

  mkdir -p "${workflow_dir}/${slug}"
  cat > "${workflow_dir}/${slug}/index.md" <<EOF
---
title: "Merged fixture entity"
status: ${status}
pr: ${pr}
worktree: ${worktree}
completed: ${completed}
verdict: ${verdict}
archived: ${archived}
---

# Merged fixture entity
EOF
}

# write_merged_pr_fixture - the shared ${FIXTURE_ROOT}/pr-merged.env fixture
# hardcodes number=131, which only matches entities created with `pr: #131`
# (read_provider_fixture rejects on any other number as pr-number-mismatch,
# by design -- see the "PR mismatch rejects fixture" case). Cases that write
# an entity with its own distinct PR number (for readability/isolation) need
# a fixture generated with the SAME number; this writes one on the fly into
# $TMP_DIR. head_ref only matters when the entity also carries a `worktree:`
# value (preflight_worktree_cleanup's branch cross-check) -- pass the
# entity's expected branch name in that case, otherwise any placeholder is
# fine.
write_merged_pr_fixture() {
  local out="$1"
  local number="$2"
  local head="${3:-ship-fixture-entity}"
  cat > "$out" <<FIXEOF
provider=fixture
number=${number}
state=MERGED
merged_at=2026-05-06T00:00:00Z
head_ref=${head}
base_ref=main
url=https://github.com/example/repo/pull/${number}
FIXEOF
}

setup_repo() {
  local repo="$1"
  git init -q "$repo"
  git -C "$repo" config user.email test@example.test
  git -C "$repo" config user.name "Ship Flow Test"
  mkdir -p "${repo}/docs/ship-flow"
  write_workflow_readme "${repo}/docs/ship-flow"
  write_pr_merge_mod "${repo}/docs/ship-flow"
  echo "fixture" > "${repo}/README.md"
  git -C "$repo" add README.md docs/ship-flow/README.md docs/ship-flow/_mods/pr-merge.md
  git -C "$repo" commit -qm initial
}

run_helper() {
  local repo="$1"
  local output="$2"
  shift 2
  local rc=0
  STATUS_BIN="$STATUS_BIN" "$HELPER" --workflow-dir "${repo}/docs/ship-flow" "$@" > "$output" 2>&1 || rc=$?
  echo "$rc"
}

run_helper_with_path() {
  local repo="$1"
  local output="$2"
  local path_value="$3"
  shift 3
  local rc=0
  PATH="$path_value" STATUS_BIN="$STATUS_BIN" "$HELPER" --workflow-dir "${repo}/docs/ship-flow" "$@" > "$output" 2>&1 || rc=$?
  echo "$rc"
}

# run_helper_with_status_bin - like run_helper, but takes an explicit
# status-bin path instead of the shared $STATUS_BIN global. Used by the
# faithful-merge-guard-stub case so it never has to reassign the shared
# global (isolation from the other 125 assertions).
run_helper_with_status_bin() {
  local repo="$1"
  local output="$2"
  local status_bin="$3"
  shift 3
  local rc=0
  STATUS_BIN="$status_bin" "$HELPER" --workflow-dir "${repo}/docs/ship-flow" "$@" > "$output" 2>&1 || rc=$?
  echo "$rc"
}

run_runtime_regression_cases() {
  # NOTE: the prior cache-glob version-selection cases ("resolves from active
  # plugin cache" / "chooses newest spacedock version across cache roots") were
  # removed in the status-helper repoint. The reconciler no longer discovers a
  # packaged python `commission/bin/status` from the plugin cache; the status
  # helper is now the `spacedock` Go binary, discovered via `command -v
  # spacedock` (with SHIP_FLOW_STATUS_BIN/STATUS_BIN override). The override
  # path is covered hermetically below; the STATUS_BIN override path is
  # exercised throughout the rest of this suite via run_helper.

  # SHIP_FLOW_STATUS_BIN override is honored by resolve_status_bin, with no
  # host dependency. Source the helper's resolver in a sandbox subshell.
  local resolver_out resolver_rc=0
  resolver_out="$(
    SHIP_FLOW_STATUS_BIN="/fixture/path/spacedock" STATUS_BIN="" \
      bash -c '
        set -euo pipefail
        eval "$(sed -n "/^resolve_status_bin()/,/^}/p" "$1")"
        resolve_status_bin
      ' _ "$HELPER"
  )" || resolver_rc=$?
  assert_exit "resolve_status_bin honors SHIP_FLOW_STATUS_BIN override" 0 "$resolver_rc"
  if [ "$resolver_out" = "/fixture/path/spacedock" ]; then
    record_pass "resolve_status_bin returns SHIP_FLOW_STATUS_BIN override path"
  else
    record_fail "resolve_status_bin returns SHIP_FLOW_STATUS_BIN override path (got: ${resolver_out})"
  fi

  local rc
  local pipe_repo="$TMP_DIR/pipefail-repo"
  local worktree_path="${pipe_repo}/.worktrees/ship-merged-fixture-entity"
  setup_repo "$pipe_repo"
  mkdir -p "$worktree_path"
  write_entity "${pipe_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/ship-merged-fixture-entity"
  git -C "$pipe_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$pipe_repo" commit -qm "add pipefail entity"

  local fake_bin="$TMP_DIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "${fake_bin}/git" <<EOF
#!/usr/bin/env bash
set -euo pipefail
REAL_GIT="$(command -v git)"
REPO="$pipe_repo"
TARGET="$worktree_path"
repo_arg=""
if [ "\${1:-}" = "-C" ]; then
  repo_arg="\$2"
  shift 2
fi
if [ "\${1:-}" = "worktree" ] && [ "\${2:-}" = "list" ] && [ "\${3:-}" = "--porcelain" ]; then
  printf 'worktree %s\nHEAD fixture-main\nbranch refs/heads/main\n\n' "\$REPO"
  i=0
  while [ "\$i" -lt 3000 ]; do
    printf 'worktree %s/.worktrees/noise-%04d\nHEAD fixture-noise-%04d\nbranch refs/heads/noise-%04d\n\n' "\$REPO" "\$i" "\$i" "\$i"
    i=\$((i + 1))
  done
  printf 'worktree %s\nHEAD fixture-target\nbranch refs/heads/ship-merged-fixture-entity\n\n' "\$TARGET"
  exit 0
fi
if [ "\$repo_arg" = "\$TARGET" ] && [ "\${1:-}" = "status" ] && [ "\${2:-}" = "--porcelain" ]; then
  exit 0
fi
if [ -n "\$repo_arg" ]; then
  exec "\$REAL_GIT" -C "\$repo_arg" "\$@"
fi
exec "\$REAL_GIT" "\$@"
EOF
  chmod +x "${fake_bin}/git"

  rc="$(run_helper_with_path "$pipe_repo" "$TMP_DIR/pipefail-dry-run.out" "${fake_bin}:$PATH" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env" \
    --dry-run)"
  assert_exit "dry-run survives large worktree list under pipefail" 0 "$rc"
  assert_contains "dry-run large worktree list plans cleanup" '^worktree_cleanup=planned$' "$TMP_DIR/pipefail-dry-run.out"
  assert_contains "dry-run large worktree list plans branch cleanup" '^branch_cleanup=planned$' "$TMP_DIR/pipefail-dry-run.out"
}

run_merged_fixture_case() {
  local repo="$TMP_DIR/merged-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ""
  git -C "$repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$repo" commit -qm "add merged entity"

  local rc
  rc="$(run_helper "$repo" "$TMP_DIR/merged.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"

  assert_exit "merged fixture exits success" 0 "$rc"
  assert_contains "merged fixture proceeds" '^verdict=PROCEED$' "$TMP_DIR/merged.out"
  assert_contains "merged fixture reports PR state" '^pr_state=MERGED$' "$TMP_DIR/merged.out"
  assert_contains "merged fixture terminal action" '^terminal_action=merge_guard_finalized$' "$TMP_DIR/merged.out"
  assert_contains "merged fixture emits debrief_due" '^debrief_due=merged-fixture-entity$' "$TMP_DIR/merged.out"
  assert_file_exists "merged fixture archives folder index" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md"
  assert_frontmatter_equals "archived entity status done" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" status done
  assert_frontmatter_nonempty "archived entity completed stamped" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" completed
  assert_frontmatter_equals "archived entity verdict passed" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" verdict PASSED
  assert_frontmatter_equals "archived entity worktree cleared" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" worktree ""
  assert_frontmatter_equals "archived entity pr sentinel written" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" pr pr-merge:131

  local archived_rc=0
  "$STATUS_BIN" --workflow-dir "${repo}/docs/ship-flow" --archived --where "slug = merged-fixture-entity" > "$TMP_DIR/archived-status.out" 2>&1 || archived_rc=$?
  assert_exit "archived status query succeeds" 0 "$archived_rc"
  assert_contains "archived status query finds slug" 'merged-fixture-entity' "$TMP_DIR/archived-status.out"

  local commit_log
  commit_log="$(git -C "$repo" log --oneline)"
  assert_contains "sentinel write-ahead commit landed before archive-move (DC-1)" 'record pr-merge sentinel' <(printf '%s\n' "$commit_log")
  assert_contains "archive-move commit landed via merge guard delegation" 'archive: .*merge guard' <(printf '%s\n' "$commit_log")
}

run_sentinel_write_case() {
  local repo="$TMP_DIR/sentinel-write-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "sentinel-entity" "ship" "#141" ""
  git -C "$repo" add docs/ship-flow/sentinel-entity/index.md
  git -C "$repo" commit -qm "add sentinel entity"

  local fixture="$TMP_DIR/pr-merged-141.env"
  write_merged_pr_fixture "$fixture" 141

  local rc
  rc="$(run_helper "$repo" "$TMP_DIR/sentinel-write.out" \
    --entity sentinel-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture")"
  assert_exit "sentinel-write case exits success" 0 "$rc"

  local sentinel_commit_files
  sentinel_commit_files="$(git -C "$repo" log --format= --name-only --grep='record pr-merge sentinel')"
  assert_equals "sentinel write-ahead commit touches only the entity file" \
    "docs/ship-flow/sentinel-entity/index.md" \
    "$(printf '%s\n' "$sentinel_commit_files" | sed '/^$/d')"
}

run_refusal_cases() {
  local repo="$TMP_DIR/refusal-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ""
  git -C "$repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$repo" commit -qm "add refusal entity"

  local before rc after
  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/open.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-open.env")"
  after="$(hash_tree "${repo}/docs/ship-flow")"
  assert_exit "open PR exits success no-op" 0 "$rc"
  assert_contains "open PR reports noop" '^state=pr_open_noop$' "$TMP_DIR/open.out"
  if [ "$before" = "$after" ]; then
    record_pass "open PR leaves workflow unchanged"
  else
    record_fail "open PR leaves workflow unchanged"
  fi

  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/closed.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-closed.env")"
  after="$(hash_tree "${repo}/docs/ship-flow")"
  assert_exit "closed PR prompts captain" 1 "$rc"
  assert_contains "closed PR reports prompt" '^verdict=PROMPT_CAPTAIN$' "$TMP_DIR/closed.out"
  if [ "$before" = "$after" ]; then
    record_pass "closed PR leaves workflow unchanged"
  else
    record_fail "closed PR leaves workflow unchanged"
  fi

  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/unknown.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-unknown.env")"
  after="$(hash_tree "${repo}/docs/ship-flow")"
  assert_exit "unknown PR prompts captain" 1 "$rc"
  assert_contains "unknown PR reports prompt" '^verdict=PROMPT_CAPTAIN$' "$TMP_DIR/unknown.out"
  if [ "$before" = "$after" ]; then
    record_pass "unknown PR leaves workflow unchanged"
  else
    record_fail "unknown PR leaves workflow unchanged"
  fi

  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/mismatch.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-mismatch.env")"
  after="$(hash_tree "${repo}/docs/ship-flow")"
  assert_exit "PR mismatch rejects fixture" 2 "$rc"
  assert_contains "PR mismatch reports reason" '^reason=pr-number-mismatch$' "$TMP_DIR/mismatch.out"
  if [ "$before" = "$after" ]; then
    record_pass "PR mismatch leaves workflow unchanged"
  else
    record_fail "PR mismatch leaves workflow unchanged"
  fi
}

run_usage_and_dry_run_cases() {
  local repo="$TMP_DIR/usage-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ""
  git -C "$repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$repo" commit -qm "add usage entity"

  local rc before after
  for flag in --tracker --linear --dashboard --create-pr --merge --force-merge --delete-remote-branch; do
    rc="$(run_helper "$repo" "${TMP_DIR}/unsupported-${flag#--}.out" \
      --entity merged-fixture-entity \
      --pr-provider fixture \
      --pr-fixture "${FIXTURE_ROOT}/pr-merged.env" \
      "$flag")"
    assert_exit "unsupported ${flag} exits usage" 2 "$rc"
    assert_contains "unsupported ${flag} rejected" '^verdict=REJECT$' "${TMP_DIR}/unsupported-${flag#--}.out"
  done

  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/dry-run.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env" \
    --dry-run)"
  after="$(hash_tree "${repo}/docs/ship-flow")"
  assert_exit "dry-run merged exits success" 0 "$rc"
  assert_contains "dry-run plans terminal action" '^terminal_action=merge_guard_delegate$' "$TMP_DIR/dry-run.out"
  assert_contains "dry-run plans state" '^state=dry_run_planned$' "$TMP_DIR/dry-run.out"
  if [ "$before" = "$after" ]; then
    record_pass "dry-run leaves workflow unchanged"
  else
    record_fail "dry-run leaves workflow unchanged"
  fi

  local active_done_repo="$TMP_DIR/dry-run-active-done-repo"
  setup_repo "$active_done_repo"
  write_entity "${active_done_repo}/docs/ship-flow" "merged-fixture-entity" "done" "#131" "" "2026-05-06T00:00:00Z" "PASSED"
  git -C "$active_done_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$active_done_repo" commit -qm "add active done entity"
  before="$(hash_tree "${active_done_repo}/docs/ship-flow")"
  rc="$(run_helper "$active_done_repo" "$TMP_DIR/dry-run-active-done.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env" \
    --dry-run)"
  after="$(hash_tree "${active_done_repo}/docs/ship-flow")"
  # An active (not yet archived) entity whose frontmatter already reads
  # status=done is no longer special-cased: spacedock merge guard is the
  # single closeout authority regardless of the entity's current status
  # field (confirmed empirically -- merge guard finalizes+archives a
  # status=done entity exactly like a status=ship one, as long as its PR is
  # merged), so this now flows through the same merge-guard-delegate planning
  # as any other merged entity.
  assert_exit "dry-run active done exits success" 0 "$rc"
  assert_contains "dry-run active done plans merge-guard delegate" '^terminal_action=merge_guard_delegate$' "$TMP_DIR/dry-run-active-done.out"
  assert_contains "dry-run active done plans state" '^state=dry_run_planned$' "$TMP_DIR/dry-run-active-done.out"
  if [ "$before" = "$after" ]; then
    record_pass "dry-run active done leaves workflow unchanged"
  else
    record_fail "dry-run active done leaves workflow unchanged"
  fi
}

run_cleanup_cases() {
  local repo="$TMP_DIR/cleanup-repo"
  setup_repo "$repo"
  mkdir -p "${repo}/.worktrees"

  write_entity "${repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/ship-merged-fixture-entity"
  git -C "$repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$repo" commit -qm "add cleanup entity"
  git -C "$repo" worktree add "${repo}/.worktrees/ship-merged-fixture-entity" -b ship-merged-fixture-entity >/dev/null 2>&1

  local rc
  rc="$(run_helper "$repo" "$TMP_DIR/cleanup.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  assert_exit "clean worktree cleanup exits success" 0 "$rc"
  assert_contains "clean worktree removed" '^worktree_cleanup=removed$' "$TMP_DIR/cleanup.out"
  assert_contains "clean branch deleted" '^branch_cleanup=deleted$' "$TMP_DIR/cleanup.out"
  assert_path_missing "clean worktree path removed" "${repo}/.worktrees/ship-merged-fixture-entity"
  if git -C "$repo" show-ref --verify --quiet refs/heads/ship-merged-fixture-entity; then
    record_fail "clean branch deleted from repo"
  else
    record_pass "clean branch deleted from repo"
  fi

  local dirty_repo="$TMP_DIR/dirty-repo"
  setup_repo "$dirty_repo"
  mkdir -p "${dirty_repo}/.worktrees"
  write_entity "${dirty_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/ship-merged-fixture-entity"
  git -C "$dirty_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$dirty_repo" commit -qm "add dirty entity"
  git -C "$dirty_repo" worktree add "${dirty_repo}/.worktrees/ship-merged-fixture-entity" -b ship-merged-fixture-entity >/dev/null 2>&1
  echo "dirty" > "${dirty_repo}/.worktrees/ship-merged-fixture-entity/dirty.txt"
  local before after
  before="$(hash_tree "${dirty_repo}/docs/ship-flow")"
  rc="$(run_helper "$dirty_repo" "$TMP_DIR/dirty.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  after="$(hash_tree "${dirty_repo}/docs/ship-flow")"
  assert_exit "dirty worktree prompts captain" 1 "$rc"
  assert_contains "dirty worktree blocks cleanup" '^reason=dirty-worktree$' "$TMP_DIR/dirty.out"
  if [ "$before" = "$after" ]; then
    record_pass "dirty worktree leaves workflow unchanged"
  else
    record_fail "dirty worktree leaves workflow unchanged"
  fi

  local mismatch_repo="$TMP_DIR/mismatch-repo"
  setup_repo "$mismatch_repo"
  mkdir -p "${mismatch_repo}/.worktrees"
  write_entity "${mismatch_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/not-derived"
  git -C "$mismatch_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$mismatch_repo" commit -qm "add mismatch entity"
  git -C "$mismatch_repo" worktree add "${mismatch_repo}/.worktrees/not-derived" -b unexpected-branch >/dev/null 2>&1
  before="$(hash_tree "${mismatch_repo}/docs/ship-flow")"
  rc="$(run_helper "$mismatch_repo" "$TMP_DIR/branch-mismatch.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  after="$(hash_tree "${mismatch_repo}/docs/ship-flow")"
  assert_exit "branch mismatch prompts captain" 1 "$rc"
  assert_contains "branch mismatch reports reason" '^reason=branch-mismatch$' "$TMP_DIR/branch-mismatch.out"
  if [ "$before" = "$after" ]; then
    record_pass "branch mismatch leaves workflow unchanged"
  else
    record_fail "branch mismatch leaves workflow unchanged"
  fi

  local derived_repo="$TMP_DIR/derived-branch-repo"
  setup_repo "$derived_repo"
  mkdir -p "${derived_repo}/.worktrees"
  write_entity "${derived_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/not-pr-head"
  git -C "$derived_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$derived_repo" commit -qm "add derived branch entity"
  git -C "$derived_repo" worktree add "${derived_repo}/.worktrees/not-pr-head" -b not-pr-head >/dev/null 2>&1
  before="$(hash_tree "${derived_repo}/docs/ship-flow")"
  rc="$(run_helper "$derived_repo" "$TMP_DIR/derived-branch-mismatch.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  after="$(hash_tree "${derived_repo}/docs/ship-flow")"
  assert_exit "derived branch mismatch prompts captain" 1 "$rc"
  assert_contains "derived branch mismatch reports reason" '^reason=branch-mismatch$' "$TMP_DIR/derived-branch-mismatch.out"
  assert_path_exists "derived branch mismatch keeps worktree path" "${derived_repo}/.worktrees/not-pr-head"
  if [ "$before" = "$after" ]; then
    record_pass "derived branch mismatch leaves workflow unchanged"
  else
    record_fail "derived branch mismatch leaves workflow unchanged"
  fi

  local missing_repo="$TMP_DIR/missing-repo"
  setup_repo "$missing_repo"
  write_entity "${missing_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/missing-local"
  git -C "$missing_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$missing_repo" commit -qm "add missing-local entity"
  rc="$(run_helper "$missing_repo" "$TMP_DIR/missing-local.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  assert_exit "missing local worktree still reconciles" 0 "$rc"
  assert_contains "missing local worktree reported" '^worktree_cleanup=missing-local$' "$TMP_DIR/missing-local.out"

  local skipped_repo="$TMP_DIR/skipped-branch-repo"
  setup_repo "$skipped_repo"
  mkdir -p "${skipped_repo}/.worktrees"
  write_entity "${skipped_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/ship-merged-fixture-entity"
  git -C "$skipped_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$skipped_repo" commit -qm "add skipped branch entity"
  git -C "$skipped_repo" worktree add "${skipped_repo}/.worktrees/ship-merged-fixture-entity" -b ship-merged-fixture-entity >/dev/null 2>&1
  echo "branch only" > "${skipped_repo}/.worktrees/ship-merged-fixture-entity/branch-only.txt"
  git -C "${skipped_repo}/.worktrees/ship-merged-fixture-entity" add branch-only.txt
  git -C "${skipped_repo}/.worktrees/ship-merged-fixture-entity" commit -qm "branch only"
  rc="$(run_helper "$skipped_repo" "$TMP_DIR/branch-skipped.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  assert_exit "unmerged branch cleanup skipped but reconciles" 0 "$rc"
  assert_contains "unmerged branch cleanup skipped" '^branch_cleanup=skipped$' "$TMP_DIR/branch-skipped.out"
  if git -C "$skipped_repo" show-ref --verify --quiet refs/heads/ship-merged-fixture-entity; then
    record_pass "unmerged branch remains after skipped cleanup"
  else
    record_fail "unmerged branch remains after skipped cleanup"
  fi
}

run_idempotency_cases() {
  local active_done_repo="$TMP_DIR/active-done-repo"
  setup_repo "$active_done_repo"
  write_entity "${active_done_repo}/docs/ship-flow" "merged-fixture-entity" "done" "#131" "" "2026-05-06T00:00:00Z" "PASSED"
  git -C "$active_done_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$active_done_repo" commit -qm "add active done entity"
  local rc
  rc="$(run_helper "$active_done_repo" "$TMP_DIR/active-done.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  # An active (not yet archived) entity already reading status=done is no
  # longer special-cased ahead of the PR check (see the dry-run counterpart
  # above): it flows through the same sentinel-write + merge-guard-delegate
  # path as any other merged entity, and merge guard finalizes+archives it
  # exactly the same way regardless of its current status field.
  assert_exit "active done coherent archives now" 0 "$rc"
  assert_contains "active done reports reconciled via merge guard" '^state=reconciled$' "$TMP_DIR/active-done.out"
  assert_file_exists "active done archived file exists" "${active_done_repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md"

  local archived_repo="$TMP_DIR/archived-repo"
  setup_repo "$archived_repo"
  mkdir -p "${archived_repo}/docs/ship-flow/_archive/merged-fixture-entity"
  cat > "${archived_repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" <<'EOF'
---
title: "Archived fixture entity"
status: done
pr: "#131"
worktree:
completed: 2026-05-06T00:00:00Z
verdict: PASSED
archived: 2026-05-06T00:01:00Z
---

# Archived fixture entity
EOF
  git -C "$archived_repo" add docs/ship-flow/_archive/merged-fixture-entity/index.md
  git -C "$archived_repo" commit -qm "add archived entity"
  local before after
  before="$(hash_tree "${archived_repo}/docs/ship-flow")"
  rc="$(run_helper "$archived_repo" "$TMP_DIR/already-archived.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  after="$(hash_tree "${archived_repo}/docs/ship-flow")"
  assert_exit "already archived coherent exits success" 0 "$rc"
  assert_contains "already archived reported" '^state=already_reconciled$' "$TMP_DIR/already-archived.out"
  if [ "$before" = "$after" ]; then
    record_pass "already archived leaves workflow unchanged"
  else
    record_fail "already archived leaves workflow unchanged"
  fi
}

run_merge_guard_blocked_case() {
  local repo="$TMP_DIR/merge-guard-blocked-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "blocked-entity" "ship" "#151" ""
  git -C "$repo" add docs/ship-flow/blocked-entity/index.md
  git -C "$repo" commit -qm "add blocked entity"

  local fixture="$TMP_DIR/pr-merged-151.env"
  write_merged_pr_fixture "$fixture" 151

  local rc
  rc="$(MERGE_GUARD_FORCE_BLOCKED=blocked-entity run_helper "$repo" "$TMP_DIR/merge-guard-blocked.out" \
    --entity blocked-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture")"

  assert_exit "merge-guard-blocked case exits success" 0 "$rc"
  assert_contains "merge-guard-blocked reports await-resume state" '^state=await-pr-sentinel-resume$' "$TMP_DIR/merge-guard-blocked.out"
  assert_contains "merge-guard-blocked reports reason" '^reason=merge-guard-blocked$' "$TMP_DIR/merge-guard-blocked.out"
  # Sentinel write-ahead already committed before the (forced) blocked
  # merge-guard call -- write-ahead happens regardless of what merge guard
  # itself subsequently reports.
  assert_frontmatter_equals "merge-guard-blocked still records sentinel" \
    "${repo}/docs/ship-flow/blocked-entity/index.md" pr pr-merge:151
}

run_idempotent_replay_case() {
  local repo="$TMP_DIR/idempotent-replay-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "replay-entity" "ship" "#161" ""
  git -C "$repo" add docs/ship-flow/replay-entity/index.md
  git -C "$repo" commit -qm "add replay entity"

  local fixture="$TMP_DIR/pr-merged-161.env"
  write_merged_pr_fixture "$fixture" 161

  local rc1 rc2 before after
  rc1="$(run_helper "$repo" "$TMP_DIR/replay-first.out" \
    --entity replay-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture")"
  assert_exit "idempotent replay first run finalizes" 0 "$rc1"
  assert_contains "idempotent replay first run reconciles" '^state=reconciled$' "$TMP_DIR/replay-first.out"

  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc2="$(run_helper "$repo" "$TMP_DIR/replay-second.out" \
    --entity replay-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture")"
  after="$(hash_tree "${repo}/docs/ship-flow")"

  assert_exit "idempotent replay second run exits success" 0 "$rc2"
  assert_contains "idempotent replay second run reports no-op" '^state=already_reconciled$' "$TMP_DIR/replay-second.out"
  if [ "$before" = "$after" ]; then
    record_pass "idempotent replay second run leaves workflow unchanged"
  else
    record_fail "idempotent replay second run leaves workflow unchanged"
  fi
}

run_dirty_worktree_fail_closed_case() {
  local repo="$TMP_DIR/repo-root-dirty-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "repo-dirty-entity" "ship" "#171" ""
  git -C "$repo" add docs/ship-flow/repo-dirty-entity/index.md
  git -C "$repo" commit -qm "add repo-dirty entity"
  # Dirty a file OUTSIDE the entity, anywhere in the repo -- this is the NEW
  # repo-root-wide dirty gate (distinct from the entity's OWN separate git
  # worktree dirty check exercised in run_cleanup_cases).
  echo "unrelated wip" > "${repo}/unrelated-wip.txt"

  local fixture="$TMP_DIR/pr-merged-171.env"
  write_merged_pr_fixture "$fixture" 171

  local rc
  rc="$(run_helper "$repo" "$TMP_DIR/repo-dirty.out" \
    --entity repo-dirty-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture")"

  assert_exit "repo-root dirty-tree exits success (non-fatal defer)" 0 "$rc"
  assert_contains "repo-root dirty-tree reports deferred state" '^state=closeout-deferred-dirty-tree$' "$TMP_DIR/repo-dirty.out"
  assert_frontmatter_equals "repo-root dirty-tree still records sentinel (write-ahead, DC-1/DC-4)" \
    "${repo}/docs/ship-flow/repo-dirty-entity/index.md" pr pr-merge:171
  assert_path_missing "repo-root dirty-tree does not archive yet" "${repo}/docs/ship-flow/_archive/repo-dirty-entity/index.md"

  rm -f "${repo}/unrelated-wip.txt"
  rc="$(run_helper "$repo" "$TMP_DIR/repo-dirty-resume.out" \
    --entity repo-dirty-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture")"
  assert_exit "repo-root dirty-tree resume converges" 0 "$rc"
  assert_contains "repo-root dirty-tree resume reconciles" '^state=reconciled$' "$TMP_DIR/repo-dirty-resume.out"
  assert_file_exists "repo-root dirty-tree resume archives" "${repo}/docs/ship-flow/_archive/repo-dirty-entity/index.md"
}

run_wrong_branch_fail_closed_case() {
  local repo="$TMP_DIR/wrong-branch-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "wrong-branch-entity" "ship" "#181" ""
  git -C "$repo" add docs/ship-flow/wrong-branch-entity/index.md
  git -C "$repo" commit -qm "add wrong-branch entity"

  # R2: the exact rule under test is -- block committing ONLY when the
  # repo's current branch is neither the primary worktree's branch NOR this
  # entity's own registered worktree branch. Simulate a genuinely stray
  # branch by adding a SECOND linked worktree on an unrelated branch and
  # invoking the adapter from inside it (repo_root resolves to that linked
  # worktree, not the primary one).
  local other_worktree="$TMP_DIR/wrong-branch-other-worktree"
  git -C "$repo" worktree add "$other_worktree" -b stray-unrelated-branch >/dev/null 2>&1

  local fixture181="$TMP_DIR/pr-merged-181.env"
  write_merged_pr_fixture "$fixture181" 181

  local rc
  rc="$(run_helper "$other_worktree" "$TMP_DIR/wrong-branch.out" \
    --entity wrong-branch-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture181")"

  assert_exit "wrong-branch defers non-fatally" 0 "$rc"
  assert_contains "wrong-branch reports deferred state" '^state=closeout-deferred-wrong-branch$' "$TMP_DIR/wrong-branch.out"
  assert_contains "wrong-branch reports reason" '^reason=wrong-branch$' "$TMP_DIR/wrong-branch.out"
  # The wrong-branch gate runs BEFORE the sentinel write-ahead: no commit at
  # all (not even the scoped sentinel commit) should land on a branch that's
  # neither the primary worktree's branch nor this entity's own.
  assert_frontmatter_equals "wrong-branch leaves pr field un-sentineled" \
    "${other_worktree}/docs/ship-flow/wrong-branch-entity/index.md" pr "#181"

  rc="$(run_helper "$repo" "$TMP_DIR/wrong-branch-resume.out" \
    --entity wrong-branch-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture181")"
  assert_exit "wrong-branch resume from the primary worktree converges" 0 "$rc"
  assert_contains "wrong-branch resume reconciles" '^state=reconciled$' "$TMP_DIR/wrong-branch-resume.out"

  # P1-c (trunk-only): a self-closeout running FROM the entity's own registered
  # worktree, whose branch differs from the workflow trunk, now DEFERS non-
  # fatally (closeout state committed there would never reach the trunk where
  # the PR merged). It converges on a later run from the trunk. The gate emits
  # a stable deferred signal, never a mutation.
  local self_repo="$TMP_DIR/wrong-branch-self-repo"
  setup_repo "$self_repo"
  mkdir -p "${self_repo}/.worktrees"
  write_entity "${self_repo}/docs/ship-flow" "self-worktree-entity" "ship" "#182" ".worktrees/self-worktree-entity"
  git -C "$self_repo" add docs/ship-flow/self-worktree-entity/index.md
  git -C "$self_repo" commit -qm "add self-worktree entity"
  git -C "$self_repo" worktree add "${self_repo}/.worktrees/self-worktree-entity" -b ship-self-worktree-entity >/dev/null 2>&1

  local fixture182="$TMP_DIR/pr-merged-182.env"
  write_merged_pr_fixture "$fixture182" 182 "ship-self-worktree-entity"

  rc="$(run_helper "${self_repo}/.worktrees/self-worktree-entity" "$TMP_DIR/wrong-branch-self.out" \
    --entity self-worktree-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture182")"
  assert_exit "self-closeout from a non-trunk worktree defers non-fatally" 0 "$rc"
  assert_contains "self-closeout from a non-trunk worktree defers (trunk-only)" \
    '^state=closeout-deferred-wrong-branch$' "$TMP_DIR/wrong-branch-self.out"
  assert_file_exists "self-closeout defer leaves the entity active (not archived)" \
    "${self_repo}/docs/ship-flow/self-worktree-entity/index.md"
}

run_state_driver_unavailable_case() {
  local repo="$TMP_DIR/state-driver-unavailable-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "no-merge-guard-entity" "ship" "#191" ""
  git -C "$repo" add docs/ship-flow/no-merge-guard-entity/index.md
  git -C "$repo" commit -qm "add no-merge-guard entity"

  local nomerge_status="$TMP_DIR/nomerge-status"
  cat > "$nomerge_status" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [ "\${1:-}" = merge ] && [ "\${2:-}" = guard ]; then
  echo "Error: unknown command \"guard\" for \"merge\"" >&2
  exit 2
fi
exec "$STATUS_BIN" "\$@"
EOF
  chmod +x "$nomerge_status"

  local fixture="$TMP_DIR/pr-merged-191.env"
  write_merged_pr_fixture "$fixture" 191

  local original_status="$STATUS_BIN"
  STATUS_BIN="$nomerge_status"
  local rc
  rc="$(run_helper "$repo" "$TMP_DIR/state-driver-unavailable.out" \
    --entity no-merge-guard-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture")"
  STATUS_BIN="$original_status"

  assert_exit "state-driver-unavailable exits non-zero" 1 "$rc"
  assert_contains "state-driver-unavailable stderr signal (DC-5 literal)" 'state-driver unavailable' "$TMP_DIR/state-driver-unavailable.out"
  assert_contains "state-driver-unavailable reports reason" '^reason=state-driver-unavailable$' "$TMP_DIR/state-driver-unavailable.out"
}

run_debrief_due_signal_case() {
  local repo="$TMP_DIR/debrief-due-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "debrief-due-entity" "ship" "#201" ""
  git -C "$repo" add docs/ship-flow/debrief-due-entity/index.md
  git -C "$repo" commit -qm "add debrief-due entity"

  local fixture="$TMP_DIR/pr-merged-201.env"
  write_merged_pr_fixture "$fixture" 201

  local rc
  rc="$(run_helper "$repo" "$TMP_DIR/debrief-due.out" \
    --entity debrief-due-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture")"

  # DC-9: the debrief-due signal is a non-blocking, additive report field --
  # it never gates or rolls back the closeout itself. Exit 0 is asserted
  # regardless of whether anything downstream ever consumes the signal.
  assert_exit "debrief-due signal case exits success regardless of consumption" 0 "$rc"
  assert_contains "debrief-due signal present on successful finalize" '^debrief_due=debrief-due-entity$' "$TMP_DIR/debrief-due.out"
}

run_no_raw_terminal_set_case() {
  assert_equals "adapter has zero raw terminal --set status=done calls (DC-2)" \
    "0" "$(grep -c -- '--set.*status=done' "$HELPER" || true)"
  assert_equals "adapter has zero bare --archive calls (DC-2)" \
    "0" "$(grep -c -- '\-\-archive\b' "$HELPER" || true)"
  if grep -q -- 'merge guard' "$HELPER"; then
    record_pass "adapter delegates to spacedock merge guard (DC-2)"
  else
    record_fail "adapter delegates to spacedock merge guard (DC-2)"
  fi
}

run_archive_commit_failure_recovery_case() {
  local repo="$TMP_DIR/archive-commit-failure-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "archive-commit-failure-entity" "ship" "#211" ""
  git -C "$repo" add docs/ship-flow/archive-commit-failure-entity/index.md
  git -C "$repo" commit -qm "add archive-commit-failure entity"

  # R4: simulate the archive-move commit itself failing (disk full / hook
  # rejection / etc.) AFTER spacedock merge guard has already finalized the
  # entity on disk. `git add` is left to succeed; only the commit whose
  # pathspec touches the _archive/ destination fails.
  local real_git
  real_git="$(command -v git)"
  local failing_git_bin="$TMP_DIR/failing-git-bin"
  mkdir -p "$failing_git_bin"
  cat > "${failing_git_bin}/git" <<EOF
#!/usr/bin/env bash
has_commit=0
has_archive_path=0
for arg in "\$@"; do
  [ "\$arg" = commit ] && has_commit=1
  case "\$arg" in *_archive/*) has_archive_path=1 ;; esac
done
if [ "\$has_commit" = 1 ] && [ "\$has_archive_path" = 1 ]; then
  echo "fatal: simulated archive-move commit failure" >&2
  exit 128
fi
exec "$real_git" "\$@"
EOF
  chmod +x "${failing_git_bin}/git"

  local fixture="$TMP_DIR/pr-merged-211.env"
  write_merged_pr_fixture "$fixture" 211

  local rc
  rc="$(run_helper_with_path "$repo" "$TMP_DIR/archive-commit-failure.out" "${failing_git_bin}:$PATH" \
    --entity archive-commit-failure-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture")"

  assert_exit "archive-commit failure signals non-zero for retry" 1 "$rc"
  assert_contains "archive-commit failure reports recoverable state" '^state=closeout-archive-commit-failed-recoverable$' "$TMP_DIR/archive-commit-failure.out"
  # merge guard's own filesystem mutation (the move to _archive/) already
  # happened and is NOT rolled back (R4) -- on-disk state matches merge
  # guard's own output even though the adapter's own commit failed.
  assert_file_exists "archive-commit failure leaves the FS move in place uncommitted" \
    "${repo}/docs/ship-flow/_archive/archive-commit-failure-entity/index.md"
  if git -C "$repo" status --porcelain -- docs/ship-flow/_archive/archive-commit-failure-entity | grep -q .; then
    record_pass "archive-commit failure leaves the move uncommitted (recoverable)"
  else
    record_fail "archive-commit failure leaves the move uncommitted (recoverable)"
  fi

  # Re-run with a working git -- converges via the archived-resolve recovery
  # retry (attempt_archive_commit_retry), relying on merge guard's own
  # resumability rather than any rollback of the already-finalized FS state.
  rc="$(run_helper "$repo" "$TMP_DIR/archive-commit-recovery.out" \
    --entity archive-commit-failure-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture")"
  assert_exit "archive-commit recovery run exits success" 0 "$rc"
  assert_contains "archive-commit recovery run reports reconciled no-op" '^state=already_reconciled$' "$TMP_DIR/archive-commit-recovery.out"
  if [ -z "$(git -C "$repo" status --porcelain -- docs/ship-flow/_archive/archive-commit-failure-entity)" ]; then
    record_pass "archive-commit recovery run commits the pending move"
  else
    record_fail "archive-commit recovery run commits the pending move"
  fi
}

run_scope_guard() {
  assert_not_contains "helper has no forbidden git/gh mutation commands" 'git branch -D|git push --delete|gh pr (create|merge)|git merge' "$HELPER"
}

# run_real_merge_guard_self_commit_case - REGRESSION guard for the two real
# `spacedock merge guard` 0.25.0 behaviors the shared stub above does NOT
# reproduce (empirically pinned against the installed binary, fixed in
# e6d28fe): (1) merge guard commits the archive-move itself, so success must
# be judged by resulting state, not by whether the adapter's own commit added
# anything; (2) merge guard writes `verdict: passed` lowercase, so terminal
# coherence must compare case-insensitively on replay. Uses the ISOLATED
# write_fixture_status_bin_faithful stub via run_helper_with_status_bin --
# the shared $STATUS_BIN global and the other 125 assertions are untouched.
run_real_merge_guard_self_commit_case() {
  local repo="$TMP_DIR/real-merge-guard-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "real-merge-guard-entity" "ship" "#131" ""
  git -C "$repo" add docs/ship-flow/real-merge-guard-entity/index.md
  git -C "$repo" commit -qm "add real-merge-guard entity"

  local faithful_bin="$TMP_DIR/status-fixture-faithful"
  write_fixture_status_bin_faithful "$faithful_bin"

  local rc
  rc="$(run_helper_with_status_bin "$repo" "$TMP_DIR/real-merge-guard-first.out" "$faithful_bin" \
    --entity real-merge-guard-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"

  assert_exit "real merge-guard self-commit: first run exits success" 0 "$rc"
  assert_contains "real merge-guard self-commit: terminal action finalized" '^terminal_action=merge_guard_finalized$' "$TMP_DIR/real-merge-guard-first.out"
  assert_contains "real merge-guard self-commit: debrief_due present" '^debrief_due=real-merge-guard-entity$' "$TMP_DIR/real-merge-guard-first.out"

  local archived_index="${repo}/docs/ship-flow/_archive/real-merge-guard-entity/index.md"
  assert_file_exists "real merge-guard self-commit: archived index exists" "$archived_index"
  assert_frontmatter_equals "real merge-guard self-commit: archived status done" "$archived_index" status done
  assert_frontmatter_equals "real merge-guard self-commit: archived verdict lowercase passed" "$archived_index" verdict passed
  assert_frontmatter_equals "real merge-guard self-commit: archived pr sentinel" "$archived_index" pr pr-merge:131

  local dirty
  dirty="$(git -C "$repo" status --porcelain)"
  if [ -z "$dirty" ]; then
    record_pass "real merge-guard self-commit: repo tree clean after merge guard's own commit"
  else
    record_fail "real merge-guard self-commit: repo tree clean after merge guard's own commit (dirty: ${dirty})"
  fi

  local commit_log
  commit_log="$(git -C "$repo" log --oneline)"
  assert_contains "real merge-guard self-commit: archive-move commit subject matches merge guard's own contract" \
    'archive real-merge-guard-entity \(merge guard\)' <(printf '%s\n' "$commit_log")

  # Idempotent replay: the case-insensitive verdict-coherence fix must read
  # this already-archived (lowercase-verdict) entity as already_reconciled,
  # not archived-terminal-incoherent.
  local rc2
  rc2="$(run_helper_with_status_bin "$repo" "$TMP_DIR/real-merge-guard-replay.out" "$faithful_bin" \
    --entity real-merge-guard-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"

  assert_exit "real merge-guard self-commit: replay exits success" 0 "$rc2"
  assert_contains "real merge-guard self-commit: replay reports already_reconciled state" '^state=already_reconciled$' "$TMP_DIR/real-merge-guard-replay.out"
  assert_contains "real merge-guard self-commit: replay reports already_reconciled terminal_action" '^terminal_action=already_reconciled$' "$TMP_DIR/real-merge-guard-replay.out"
}

run_doc_scope_cases() {
  # Dogfood check — only runs when docs/ship-flow/_mods/pr-merge.md exists (adopted host).
  # In fresh-clone standalone mode this function is intentionally skipped.
  local pr_merge_doc="${PLUGIN_ROOT}/../../docs/ship-flow/_mods/pr-merge.md"
  if [ ! -f "$pr_merge_doc" ]; then
    echo "  NOTE: pr-merge.md absent (fresh clone) — skipping dogfood doc scope assertions"
    return 0
  fi
  assert_contains "pr merge doc scopes v1 provider support" 'v1 reconciler supports GitHub `gh` and fixture-backed tests only' "$pr_merge_doc"
  assert_not_contains "pr merge doc does not advertise GitLab closeout state checks" 'glab mr view|If `MERGED` .*GitLab|If `MERGED` \(GitHub\) or `merged` \(GitLab\)' "$pr_merge_doc"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
write_fixture_status_bin "${TMP_DIR}/status-fixture"
if [ ! -x "$STATUS_BIN" ]; then
  STATUS_BIN="${TMP_DIR}/status-fixture"
fi

echo "=== test-closeout-adapter.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "helper exists and is executable (${HELPER})"
else
  record_pass "helper exists and is executable"
  run_runtime_regression_cases
  run_merged_fixture_case
  run_sentinel_write_case
  run_refusal_cases
  run_usage_and_dry_run_cases
  run_cleanup_cases
  run_idempotency_cases
  run_merge_guard_blocked_case
  run_idempotent_replay_case
  run_dirty_worktree_fail_closed_case
  run_wrong_branch_fail_closed_case
  run_state_driver_unavailable_case
  run_debrief_due_signal_case
  run_no_raw_terminal_set_case
  run_archive_commit_failure_recovery_case
  run_real_merge_guard_self_commit_case
  run_scope_guard
  run_doc_scope_cases
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ ${FAIL} -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
exit 0
