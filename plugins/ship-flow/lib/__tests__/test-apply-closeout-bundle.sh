#!/usr/bin/env bash
# test-apply-closeout-bundle.sh - atomic direct closeout bundle contract

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/lib/apply-closeout-bundle.sh"
LANDING_RESOLVER="${PLUGIN_ROOT}/lib/resolve-landing-envelope.sh"

PASS=0
FAIL=0
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then pass "$desc"; else fail "$desc (expected ${expected}, got ${actual})"; fi
}
assert_ne() {
  local desc="$1" unexpected="$2" actual="$3"
  if [ "$unexpected" != "$actual" ]; then pass "$desc"; else fail "$desc (unexpected ${unexpected})"; fi
}
assert_contains() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file"; then pass "$desc"; else fail "$desc (missing ${pattern})"; fi
}
assert_nonzero() {
  local desc="$1" actual="$2"
  if [ "$actual" -ne 0 ]; then pass "$desc"; else fail "$desc (expected nonzero exit)"; fi
}
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
tree_hash() {
  git -C "$1" status --porcelain=v1 -z --untracked-files=all |
    shasum -a 256 | awk '{print $1}'
}

write_source() {
  local repo="$1"
  mkdir -p "$repo/docs/ship-flow/widget-closeout/ledgers"
  printf '%s\n' \
    '---' 'slug: widget-closeout' 'title: Widget closeout' 'status: ship' 'pr: "#40"' \
    'worktree:' 'completed:' 'verdict:' 'closeout_owner: true' '---' '' '# Widget closeout' \
    >"$repo/docs/ship-flow/widget-closeout/index.md"
  printf '%s\n' '# Review' '' '## Verdict' '' 'PASSED' >"$repo/docs/ship-flow/widget-closeout/review.md"
  printf '%s\n' '# Ship' '' '### Verdict' 'merge_method_intent: rebase' 'pr: "#40"' >"$repo/docs/ship-flow/widget-closeout/ship.md"
  printf '%s\n' '# Shape' '' 'Preserve shape evidence byte-for-byte.' >"$repo/docs/ship-flow/widget-closeout/shape.md"
  printf '%s\n' '# Design' '' 'Preserve design evidence byte-for-byte.' >"$repo/docs/ship-flow/widget-closeout/design.md"
  printf '%s\n' '# Plan' '' 'Preserve plan evidence byte-for-byte.' >"$repo/docs/ship-flow/widget-closeout/plan.md"
  printf '%s\n' '# Execute' '' 'Preserve execute evidence byte-for-byte.' >"$repo/docs/ship-flow/widget-closeout/execute.md"
  printf '%s\n' '# Verify' '' 'Preserve verify evidence byte-for-byte.' >"$repo/docs/ship-flow/widget-closeout/verify.md"
  printf '%s\n' 'records:' '  - task: T3' '    status: green' >"$repo/docs/ship-flow/widget-closeout/ledgers/tdd.yaml"
}

setup_repo() {
  local repo="$1"
  git init -q -b main "$repo"
  git -C "$repo" config user.email closeout@example.test
  git -C "$repo" config user.name 'Closeout Fixture'
  write_source "$repo"
  printf '%s\n' 'docs/ship-flow/widget-closeout/ignored-private.txt' >"$repo/.gitignore"
  printf '%s\n' 'ignored local bytes must not enter archive' >"$repo/docs/ship-flow/widget-closeout/ignored-private.txt"
  printf '%s\n' '# Roadmap' '| widget-closeout | Outside bounded sections |' '' '## Now' '<!-- section:now -->' '| Entity | Title |' '| --- | --- |' '| widget-closeout | Widget closeout |' '| neighbor | widget-closeout |' '<!-- /section:now -->' '' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' '<!-- /section:shipped -->' >"$repo/ROADMAP.md"
  git -C "$repo" add -- .gitignore ROADMAP.md docs/ship-flow/widget-closeout
  git -C "$repo" commit -qm 'fixture: source entity'
}

make_bundle() {
  local repo="$1" bundle="$2" strategy="${3:-rebase}" source_metadata="${4:-}"
  local proof_anchor proof_envelope source_commits source_one source_two proof_base
  mkdir -p "$bundle/docs/ship-flow/_debriefs" "$bundle/docs/ship-flow/_archive/widget-closeout" "$bundle/docs/ship-flow/_closeouts"
  printf '%s\n' '# Widget closeout debrief' '' '## Outcome' 'Merged and reconciled.' '' '## Reconciliation' 'First: 1111111' 'Last: 2222222' '' '## Todo Closure' 'No open todos.' >"$bundle/docs/ship-flow/_debriefs/2026-07-15-01.md"
  printf '%s\n' '---' 'slug: widget-closeout' 'title: Widget closeout' 'status: done' 'pr: "#40"' 'worktree:' 'completed: 2026-07-15T00:00:00Z' 'verdict: PASSED' 'archived: 2026-07-15T00:00:00Z' 'closeout_owner: true' '---' '' '# Widget closeout' >"$bundle/docs/ship-flow/_archive/widget-closeout/index.md"
  printf '%s\n' '# Ship' '' '### Verdict' "merge_method_intent: $strategy" 'pr: "#40"' 'closeout_id: pending' '' '### Closeout' 'status: applied' >"$bundle/docs/ship-flow/_archive/widget-closeout/ship.md"
  awk '
    $0 == "| widget-closeout | Widget closeout |" { next }
    $0 == "<!-- /section:shipped -->" { print "| widget-closeout | Widget closeout | 2026-07-15 (PR #40) |" }
    { print }
  ' "$repo/ROADMAP.md" >"$bundle/ROADMAP.md"

  if [ "$strategy" = squash ]; then
    proof_base="$(git -C "$repo" rev-parse HEAD)"
    git -C "$repo" checkout -qb bundle-squash-topic "$proof_base"
    printf '%s\n' 'squash source one' >"$repo/landing-proof-fixture.txt"
    git -C "$repo" add -- landing-proof-fixture.txt
    git -C "$repo" commit -qm 'fixture: squash source one'
    source_one="$(git -C "$repo" rev-parse HEAD)"
    printf '%s\n' 'squash source one' 'squash source two' >"$repo/landing-proof-fixture.txt"
    git -C "$repo" commit -qam 'fixture: squash source two'
    source_two="$(git -C "$repo" rev-parse HEAD)"
    git -C "$repo" checkout -q main
    git -C "$repo" merge --squash -q bundle-squash-topic >/dev/null
    git -C "$repo" commit -qm 'fixture: squash landing'
    proof_anchor="$(git -C "$repo" rev-parse HEAD)"
    source_commits="$source_one,$source_two"
  else
    printf '%s\n' 'canonical landing proof fixture' >"$repo/landing-proof-fixture.txt"
    git -C "$repo" add -- landing-proof-fixture.txt
    git -C "$repo" commit -qm 'fixture: canonical landing proof'
    proof_anchor="$(git -C "$repo" rev-parse HEAD)"
    source_commits="$proof_anchor"
  fi
  [ -z "$source_metadata" ] || printf '%s\n' "$source_commits" >"$source_metadata"
  proof_envelope="${bundle}.landing-proof.env"
  "$LANDING_RESOLVER" \
    --repo-dir "$repo" \
    --repository example/repo \
    --base-ref main \
    --implementation-pr 40 \
    --provider-merged-at 2026-07-15T00:00:00Z \
    --landing-anchor "$proof_anchor" \
    --source-commits "$source_commits" \
    --pr-commit-count "$(printf '%s' "$source_commits" | awk -F, '{print NF}')" \
    --merge-method-intent "$strategy" >"$proof_envelope"

  python3 - "$repo" "$bundle" "$proof_envelope" "$strategy" <<'PY'
import hashlib,json,pathlib,sys
repo,bundle,envelope=map(pathlib.Path,sys.argv[1:4]); strategy=sys.argv[4]
ident={"provider":"github","repository":"example/repo","workflow":"docs/ship-flow","entity_slug":"widget-closeout","implementation_pr":40}
cid=hashlib.sha256(b"\0".join((b"v1",b"github",b"example/repo",b"docs/ship-flow",b"widget-closeout",b"40"))).hexdigest()
def h(path): return hashlib.sha256(path.read_bytes()).hexdigest()
landing={}
for line in envelope.read_text().splitlines():
    key,value=line.split("=",1)
    if key in {"schema_version","implementation_pr","pr_commit_count"}:
        landing[key]=int(value)
    elif key in {"source_commit_patch_ids","landing_commits","landing_commit_patch_ids"}:
        landing[key]=value.split(",")
    else:
        landing[key]=value
row="| widget-closeout | Widget closeout | 2026-07-15 (PR #40) |"
r={"schema_version":1,"kind":"ship-flow.closeout","closeout_id":cid,"identity":ident,
 "ownership_proof":{"unique_entity_matches":1,"participant_entities":[],"source_hashes":{
   "index":h(repo/"docs/ship-flow/widget-closeout/index.md"),"review":h(repo/"docs/ship-flow/widget-closeout/review.md"),"ship":h(repo/"docs/ship-flow/widget-closeout/ship.md")}},
 "mode":"direct","merge_method_intent":strategy,"deterministic_closeout_head":"ship-closeout/"+cid,
 "landing_proof":landing,
 "transaction":{"phase":"applied","generation":2,"closeout_pr":None,"main_commit":landing["landing_anchor"]},
 "outputs":{"debrief":{"path":"docs/ship-flow/_debriefs/2026-07-15-01.md","sha256":h(bundle/"docs/ship-flow/_debriefs/2026-07-15-01.md")},
  "ship":{"path":"docs/ship-flow/_archive/widget-closeout/ship.md","sha256":h(bundle/"docs/ship-flow/_archive/widget-closeout/ship.md")},
  "archived_entity":{"path":"docs/ship-flow/_archive/widget-closeout/index.md","sha256":h(bundle/"docs/ship-flow/_archive/widget-closeout/index.md")},
  "roadmap_row":{"identity":"widget-closeout","sha256":hashlib.sha256(row.encode()).hexdigest()}}}
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}
r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
p=bundle/f"docs/ship-flow/_closeouts/{cid}.json"; p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
}

run_bundle() {
  local repo="$1" bundle="$2" out="$3"; shift 3
  local receipt
  receipt="$(find "$bundle/docs/ship-flow/_closeouts" -name '*.json' -maxdepth 1 -print -quit)"
  local relative="${receipt#"$bundle/"}" rc=0
  "$HELPER" --repo-root "$repo" --bundle-root "$bundle" --receipt-relative "$relative" \
    --active-entity-relative docs/ship-flow/widget-closeout \
    --if-head "$(git -C "$repo" rev-parse HEAD)" --if-roadmap-hash "$(sha256_file "$repo/ROADMAP.md")" \
    --commit-as 'ship(widget-closeout): advance status to done' "$@" >"$out" 2>&1 || rc=$?
  printf '%s\n' "$rc"
}

run_bundle_with_shell_and_subject() {
  local shell_bin="$1" path_value="$2" repo="$3" bundle="$4" out="$5" subject="$6"
  local receipt relative rc=0
  receipt="$(find "$bundle/docs/ship-flow/_closeouts" -name '*.json' -maxdepth 1 -print -quit)"
  relative="${receipt#"$bundle/"}"
  PATH="$path_value" "$shell_bin" "$HELPER" --repo-root "$repo" --bundle-root "$bundle" --receipt-relative "$relative" \
    --active-entity-relative docs/ship-flow/widget-closeout \
    --if-head "$(git -C "$repo" rev-parse HEAD)" --if-roadmap-hash "$(sha256_file "$repo/ROADMAP.md")" \
    --commit-as "$subject" >"$out" 2>&1 || rc=$?
  printf '%s\n' "$rc"
}

rewrite_bundle_ship() {
  local bundle="$1" mode="$2"
  python3 - "$bundle" "$mode" <<'PY'
import hashlib,json,pathlib,sys
bundle=pathlib.Path(sys.argv[1]); mode=sys.argv[2]
ship=bundle/"docs/ship-flow/_archive/widget-closeout/ship.md"
if mode=="unterminated-details":
    lines=["# Ship","<details>"]+[f"hidden body {i}" for i in range(1,62)]
elif mode=="raw-overflow":
    lines=["# Ship","<details>"]+[f"collapsed evidence {i}" for i in range(1,119)]+["</details>"]
elif mode=="balanced-valid":
    lines=[f"body line {i}" for i in range(1,11)]+["<details open>"]+[f"collapsed evidence {i}" for i in range(1,21)]+["</details>"]
elif mode=="nested-small":
    lines=["body before","<details>","<details open>","buffered nested line","</details>","</details>"]
elif mode=="stray-close-small":
    lines=["body before","</details>","body after"]
else: raise SystemExit("unknown ship fixture mode")
ship.write_text("\n".join(lines)+"\n")
receipt=next((bundle/"docs/ship-flow/_closeouts").glob("*.json")); r=json.loads(receipt.read_text())
r["outputs"]["ship"]["sha256"]=hashlib.sha256(ship.read_bytes()).hexdigest()
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}
r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
receipt.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
}

echo '=== test-apply-closeout-bundle.sh ==='
if [ ! -x "$HELPER" ]; then
  fail "bundle helper exists and is executable (${HELPER})"
else
  pass 'bundle helper exists and is executable'

  repo="$TMP_DIR/success"; bundle="$TMP_DIR/success-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"
  source_review_hash="$(sha256_file "$repo/docs/ship-flow/widget-closeout/review.md")"
  source_shape_hash="$(sha256_file "$repo/docs/ship-flow/widget-closeout/shape.md")"
  source_design_hash="$(sha256_file "$repo/docs/ship-flow/widget-closeout/design.md")"
  source_plan_hash="$(sha256_file "$repo/docs/ship-flow/widget-closeout/plan.md")"
  source_execute_hash="$(sha256_file "$repo/docs/ship-flow/widget-closeout/execute.md")"
  source_verify_hash="$(sha256_file "$repo/docs/ship-flow/widget-closeout/verify.md")"
  source_ledger_hash="$(sha256_file "$repo/docs/ship-flow/widget-closeout/ledgers/tdd.yaml")"
  before_commits="$(git -C "$repo" rev-list --count HEAD)"
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/success.out")"
  if [ "$rc" != 0 ]; then sed 's/^/    helper: /' "$TMP_DIR/success.out"; fi
  assert_eq 'coherent bundle exits success' 0 "$rc"
  assert_eq 'bundle creates exactly one commit' "$((before_commits + 1))" "$(git -C "$repo" rev-list --count HEAD)"
  assert_eq 'bundle uses sanctioned C14 receipt' 'ship(widget-closeout): advance status to done' "$(git -C "$repo" log -1 --format=%s)"
  assert_contains 'bundle reports applied' '^state=applied$' "$TMP_DIR/success.out"
  if [ ! -e "$repo/docs/ship-flow/widget-closeout" ]; then pass 'active entity removed atomically'; else fail 'active entity removed atomically'; fi
  if [ -f "$repo/docs/ship-flow/_archive/widget-closeout/index.md" ]; then pass 'archived entity landed'; else fail 'archived entity landed'; fi
  if [ -f "$repo/docs/ship-flow/_archive/widget-closeout/ship.md" ]; then pass 'final ship landed'; else fail 'final ship landed'; fi
  assert_eq 'review evidence is archived byte-for-byte' "$source_review_hash" "$(sha256_file "$repo/docs/ship-flow/_archive/widget-closeout/review.md" 2>/dev/null || true)"
  assert_eq 'shape evidence is archived byte-for-byte' "$source_shape_hash" "$(sha256_file "$repo/docs/ship-flow/_archive/widget-closeout/shape.md" 2>/dev/null || true)"
  assert_eq 'design evidence is archived byte-for-byte' "$source_design_hash" "$(sha256_file "$repo/docs/ship-flow/_archive/widget-closeout/design.md" 2>/dev/null || true)"
  assert_eq 'plan evidence is archived byte-for-byte' "$source_plan_hash" "$(sha256_file "$repo/docs/ship-flow/_archive/widget-closeout/plan.md" 2>/dev/null || true)"
  assert_eq 'execute evidence is archived byte-for-byte' "$source_execute_hash" "$(sha256_file "$repo/docs/ship-flow/_archive/widget-closeout/execute.md" 2>/dev/null || true)"
  assert_eq 'verify evidence is archived byte-for-byte' "$source_verify_hash" "$(sha256_file "$repo/docs/ship-flow/_archive/widget-closeout/verify.md" 2>/dev/null || true)"
  assert_eq 'nested TDD ledger is archived byte-for-byte' "$source_ledger_hash" "$(sha256_file "$repo/docs/ship-flow/_archive/widget-closeout/ledgers/tdd.yaml" 2>/dev/null || true)"
  if [ ! -e "$repo/docs/ship-flow/_archive/widget-closeout/ignored-private.txt" ]; then pass 'ignored untracked bytes are not archived'; else fail 'ignored untracked bytes are not archived'; fi
  if [ -f "$repo/docs/ship-flow/_debriefs/2026-07-15-01.md" ]; then pass 'debrief landed'; else fail 'debrief landed'; fi
  assert_eq 'exactly one Shipped row landed' 1 "$(grep -c '^| widget-closeout | Widget closeout | 2026-07-15 (PR #40) |$' "$repo/ROADMAP.md")"
  assert_eq 'ROADMAP preserves exact slug row outside bounded sections' 1 "$(grep -c '^| widget-closeout | Outside bounded sections |$' "$repo/ROADMAP.md")"
  assert_eq 'ROADMAP ignores slug in a non-identity Now cell' 1 "$(grep -c '^| neighbor | widget-closeout |$' "$repo/ROADMAP.md")"
  first_head="$(git -C "$repo" rev-parse HEAD)"
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/noop.out")"
  assert_eq 'matching receipt rerun exits success' 0 "$rc"
  assert_eq 'matching receipt rerun creates no commit' "$first_head" "$(git -C "$repo" rev-parse HEAD)"
  assert_contains 'matching receipt rerun is no-op' '^state=already_applied$' "$TMP_DIR/noop.out"

  repo="$TMP_DIR/squash"; bundle="$TMP_DIR/squash-bundle"; squash_sources_file="$TMP_DIR/squash-sources"
  setup_repo "$repo"; make_bundle "$repo" "$bundle" squash "$squash_sources_file"
  squash_sources="$(cat "$squash_sources_file")"
  before_head="$(git -C "$repo" rev-parse HEAD)"; before_tree="$(tree_hash "$repo")"
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/squash-missing-source.out")"
  assert_eq 'squash bundle without authoritative source commits fails closed' 1 "$rc"
  assert_contains 'squash bundle missing source reports stable sentinel reason' '^reason=closeout-sentinel-invalid$' "$TMP_DIR/squash-missing-source.out"
  assert_eq 'squash bundle missing source preserves HEAD' "$before_head" "$(git -C "$repo" rev-parse HEAD)"
  assert_eq 'squash bundle missing source preserves index and tree' "$before_tree" "$(tree_hash "$repo")"
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/squash-success.out" --source-commits "$squash_sources")"
  assert_eq 'squash bundle accepts authoritative implementation source commits' 0 "$rc"
  assert_contains 'squash bundle reports applied' '^state=applied$' "$TMP_DIR/squash-success.out"
  squash_head="$(git -C "$repo" rev-parse HEAD)"
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/squash-rerun.out" --source-commits "$squash_sources")"
  assert_eq 'squash bundle idempotent replay exits success' 0 "$rc"
  assert_eq 'squash bundle idempotent replay creates no commit' "$squash_head" "$(git -C "$repo" rev-parse HEAD)"
  assert_contains 'squash bundle idempotent replay reports already applied' '^state=already_applied$' "$TMP_DIR/squash-rerun.out"

  repo="$TMP_DIR/bash32"; bundle="$TMP_DIR/bash32-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"
  rc="$(run_bundle_with_shell_and_subject /bin/bash /usr/bin:/bin "$repo" "$bundle" "$TMP_DIR/bash32.out" 'ship(widget-closeout): advance status to done')"
  if [ "$rc" != 0 ]; then sed 's/^/    bash32: /' "$TMP_DIR/bash32.out"; fi
  assert_eq 'focused helper executes under Bash 3.2 restricted PATH' 0 "$rc"
  assert_contains 'Bash 3.2 helper applies bundle' '^state=applied$' "$TMP_DIR/bash32.out"

  repo="$TMP_DIR/unterminated-details"; bundle="$TMP_DIR/unterminated-details-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"; rewrite_bundle_ship "$bundle" unterminated-details
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/unterminated-details.out")"
  assert_eq 'unterminated details cannot hide over-cap ship body' 1 "$rc"
  assert_contains 'unterminated details reports C15 incoherence' '^reason=closeout-stage-artifacts-incoherent$' "$TMP_DIR/unterminated-details.out"
  assert_contains 'unterminated details names malformed balance' '^detail=ship.md contains malformed or unbalanced standalone details$' "$TMP_DIR/unterminated-details.out"

  repo="$TMP_DIR/raw-overflow"; bundle="$TMP_DIR/raw-overflow-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"; rewrite_bundle_ship "$bundle" raw-overflow
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/raw-overflow.out")"
  assert_eq 'balanced details cannot exceed ship raw backstop' 1 "$rc"
  assert_contains 'raw overflow reports C15 incoherence' '^reason=closeout-stage-artifacts-incoherent$' "$TMP_DIR/raw-overflow.out"
  assert_contains 'raw overflow names canonical 2x backstop' '^detail=ship.md exceeds C15 raw backstop$' "$TMP_DIR/raw-overflow.out"

  repo="$TMP_DIR/balanced-valid"; bundle="$TMP_DIR/balanced-valid-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"; rewrite_bundle_ship "$bundle" balanced-valid
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/balanced-valid.out")"
  assert_eq 'balanced standalone details remain excluded under both caps' 0 "$rc"

  repo="$TMP_DIR/nested-small"; bundle="$TMP_DIR/nested-small-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"; rewrite_bundle_ship "$bundle" nested-small
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/nested-small.out")"
  assert_eq 'nested standalone details follow canonical first-close buffering' 0 "$rc"

  repo="$TMP_DIR/stray-close-small"; bundle="$TMP_DIR/stray-close-small-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"; rewrite_bundle_ship "$bundle" stray-close-small
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/stray-close-small.out")"
  assert_eq 'stray standalone details close counts as ordinary body' 0 "$rc"

  repo="$TMP_DIR/subject-midstring"; bundle="$TMP_DIR/subject-midstring-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"
  rc="$(run_bundle_with_shell_and_subject /bin/bash /usr/bin:/bin "$repo" "$bundle" "$TMP_DIR/subject-midstring.out" 'ship(widget-closeout): prefix: advance status to done')"
  assert_eq 'mid-string C14 lookalike subject is usage-rejected' 2 "$rc"
  repo="$TMP_DIR/subject-injection"; bundle="$TMP_DIR/subject-injection-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"
  rc="$(run_bundle_with_shell_and_subject /bin/bash /usr/bin:/bin "$repo" "$bundle" "$TMP_DIR/subject-injection.out" $'ship(widget-closeout): advance status to done\ninjected trailer')"
  assert_eq 'multi-line C14 subject injection is usage-rejected' 2 "$rc"

  repo="$TMP_DIR/fault"; bundle="$TMP_DIR/fault-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"
  before_head="$(git -C "$repo" rev-parse HEAD)"; before_tree="$(tree_hash "$repo")"
  rc="$(SHIP_FLOW_CLOSEOUT_FAILPOINT=before-commit run_bundle "$repo" "$bundle" "$TMP_DIR/fault.out")"
  assert_eq 'injected pre-commit failure stops' 1 "$rc"
  assert_contains 'injected failure is stable conflict' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/fault.out"
  assert_eq 'injected failure restores HEAD' "$before_head" "$(git -C "$repo" rev-parse HEAD)"
  assert_eq 'injected failure restores index and tree' "$before_tree" "$(tree_hash "$repo")"

  repo="$TMP_DIR/post-commit-signal"; bundle="$TMP_DIR/post-commit-signal-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  signal_bin="$TMP_DIR/post-commit-signal-bin"
  mkdir -p "$signal_bin"
  real_git="$(command -v git)"
  # shellcheck disable=SC2016 # emitted wrapper expands these variables at runtime
  printf '%s\n' '#!/usr/bin/env bash' \
    'saw_commit=no' 'for arg in "$@"; do [ "$arg" = commit ] && saw_commit=yes; done' \
    "'$real_git' \"\$@\"" 'rc=$?' \
    '[ "$rc" -eq 0 ] && [ "$saw_commit" = yes ] && kill -TERM "$PPID"' \
    'exit "$rc"' >"$signal_bin/git"
  chmod +x "$signal_bin/git"
  saved_path="$PATH"
  PATH="$signal_bin:$PATH"
  export PATH
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/post-commit-signal.out")"
  PATH="$saved_path"
  export PATH
  assert_nonzero 'signal immediately after durable commit interrupts first invocation' "$rc"
  assert_ne 'post-commit signal preserves the durable new HEAD' "$before_head" "$(git -C "$repo" rev-parse HEAD)"
  assert_eq 'post-commit signal leaves committed worktree coherent' '' "$(git -C "$repo" status --porcelain --untracked-files=all)"
  if [ -f "$repo/docs/ship-flow/_closeouts/$(basename "$(find "$bundle/docs/ship-flow/_closeouts" -name '*.json' -print -quit)")" ]; then pass 'post-commit signal preserves committed receipt'; else fail 'post-commit signal preserves committed receipt'; fi
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/post-commit-rerun.out")"
  assert_eq 'post-commit signal is safely rerunnable' 0 "$rc"
  assert_contains 'post-commit signal rerun detects applied receipt' '^state=already_applied$' "$TMP_DIR/post-commit-rerun.out"

  repo="$TMP_DIR/roadmap-conflict"; bundle="$TMP_DIR/roadmap-conflict-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"
  before_head="$(git -C "$repo" rev-parse HEAD)"; before_tree="$(tree_hash "$repo")"
  rc=0
  "$HELPER" --repo-root "$repo" --bundle-root "$bundle" \
    --receipt-relative "$(find "$bundle/docs/ship-flow/_closeouts" -name '*.json' | sed "s#^$bundle/##")" \
    --active-entity-relative docs/ship-flow/widget-closeout --if-head "$before_head" --if-roadmap-hash "$(printf 'a%.0s' {1..64})" \
    --commit-as 'ship(widget-closeout): advance status to done' >"$TMP_DIR/roadmap-conflict.out" 2>&1 || rc=$?
  assert_eq 'ROADMAP CAS conflict stops' 1 "$rc"
  assert_contains 'ROADMAP CAS reports stable reason' '^reason=closeout-roadmap-conflict$' "$TMP_DIR/roadmap-conflict.out"
  assert_eq 'ROADMAP conflict preserves tree' "$before_tree" "$(tree_hash "$repo")"

  repo="$TMP_DIR/projection-conflict"; bundle="$TMP_DIR/projection-conflict-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"
  mkdir -p "$repo/docs/ship-flow/_debriefs"
  printf '%s\n' 'unrelated landed debrief' >"$repo/docs/ship-flow/_debriefs/2026-07-15-01.md"
  git -C "$repo" add -- docs/ship-flow/_debriefs/2026-07-15-01.md
  git -C "$repo" commit -qm 'fixture: conflicting projection'
  before_head="$(git -C "$repo" rev-parse HEAD)"; before_tree="$(tree_hash "$repo")"
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/projection-conflict.out")"
  assert_eq 'pre-existing projection conflict stops' 1 "$rc"
  assert_contains 'pre-existing projection reports source drift' '^reason=closeout-projection-source-drift$' "$TMP_DIR/projection-conflict.out"
  assert_eq 'pre-existing projection conflict preserves HEAD' "$before_head" "$(git -C "$repo" rev-parse HEAD)"
  assert_eq 'pre-existing projection conflict preserves tree' "$before_tree" "$(tree_hash "$repo")"

  repo="$TMP_DIR/source-drift"; bundle="$TMP_DIR/source-drift-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"
  printf '%s\n' 'late review mutation' >>"$repo/docs/ship-flow/widget-closeout/review.md"
  git -C "$repo" add -- docs/ship-flow/widget-closeout/review.md
  git -C "$repo" commit -qm 'fixture: source drift'
  before_tree="$(tree_hash "$repo")"
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/source-drift.out")"
  assert_eq 'source hash drift stops' 1 "$rc"
  assert_contains 'source hash drift reports stable reason' '^reason=closeout-projection-source-drift$' "$TMP_DIR/source-drift.out"
  assert_eq 'source hash drift preserves tree' "$before_tree" "$(tree_hash "$repo")"

  repo="$TMP_DIR/destination-symlink"; bundle="$TMP_DIR/destination-symlink-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"
  external="$TMP_DIR/destination-symlink-external"
  mkdir -p "$external"
  printf '%s\n' 'external sentinel must remain byte-identical' >"$external/sentinel.txt"
  sentinel_hash="$(sha256_file "$external/sentinel.txt")"
  ln -s "$external" "$repo/docs/ship-flow/_debriefs"
  git -C "$repo" add -- docs/ship-flow/_debriefs
  git -C "$repo" commit -qm 'fixture: tracked destination directory symlink'
  before_head="$(git -C "$repo" rev-parse HEAD)"; before_tree="$(tree_hash "$repo")"
  crash_bin="$TMP_DIR/destination-symlink-bin"
  mkdir -p "$crash_bin"
  # shellcheck disable=SC2016 # emitted wrapper expands these variables at runtime
  printf '%s\n' '#!/usr/bin/env bash' \
    'last=""' 'for arg in "$@"; do last="$arg"; done' \
    'resolved="$(/usr/bin/python3 -c '\''import os,sys; print(os.path.realpath(sys.argv[1]))'\'' "$last")"' \
    "case \"\$resolved\" in '$external'/*) printf observed >'$external/write-observed' ;; esac" \
    'exec /bin/cp "$@"' >"$crash_bin/cp"
  chmod +x "$crash_bin/cp"
  saved_path="$PATH"
  PATH="$crash_bin:$PATH"
  export PATH
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/destination-symlink.out")"
  PATH="$saved_path"
  export PATH
  assert_nonzero 'destination symlink preflight stops before mutation' "$rc"
  assert_contains 'destination symlink reports stable sentinel reason' '^reason=closeout-sentinel-invalid$' "$TMP_DIR/destination-symlink.out"
  assert_eq 'destination symlink preserves HEAD' "$before_head" "$(git -C "$repo" rev-parse HEAD)"
  assert_eq 'destination symlink preserves index and tree' "$before_tree" "$(tree_hash "$repo")"
  assert_eq 'external sentinel remains byte-identical' "$sentinel_hash" "$(sha256_file "$external/sentinel.txt")"
  if [ ! -e "$external/2026-07-15-01.md" ]; then pass 'destination symlink creates no external output'; else fail 'destination symlink creates no external output'; fi
  if [ ! -e "$external/write-observed" ]; then pass 'destination symlink is rejected before any external write'; else fail 'destination symlink is rejected before any external write'; fi

  repo="$TMP_DIR/source-symlink"; bundle="$TMP_DIR/source-symlink-bundle"
  setup_repo "$repo"; make_bundle "$repo" "$bundle"
  external="$TMP_DIR/source-symlink-external"
  printf '%s\n' 'external source bytes must never be followed' >"$external"
  ln -s "$external" "$repo/docs/ship-flow/widget-closeout/external-evidence"
  git -C "$repo" add -- docs/ship-flow/widget-closeout/external-evidence
  git -C "$repo" commit -qm 'fixture: tracked source symlink'
  before_head="$(git -C "$repo" rev-parse HEAD)"; before_tree="$(tree_hash "$repo")"
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/source-symlink.out")"
  assert_nonzero 'tracked source symlink stops before archive mutation' "$rc"
  assert_contains 'tracked source symlink reports stable sentinel reason' '^reason=closeout-sentinel-invalid$' "$TMP_DIR/source-symlink.out"
  assert_eq 'tracked source symlink preserves HEAD' "$before_head" "$(git -C "$repo" rev-parse HEAD)"
  assert_eq 'tracked source symlink preserves index and tree' "$before_tree" "$(tree_hash "$repo")"

  git -C "$repo" checkout -qb not-main
  rc="$(run_bundle "$repo" "$bundle" "$TMP_DIR/not-main.out")"
  assert_eq 'non-authoritative branch stops' 1 "$rc"
  assert_contains 'non-authoritative branch reports stable reason' '^reason=closeout-main-not-authoritative$' "$TMP_DIR/not-main.out"
fi

printf 'Results: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
