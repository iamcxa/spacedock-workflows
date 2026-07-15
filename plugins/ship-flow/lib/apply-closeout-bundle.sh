#!/usr/bin/env bash
# apply-closeout-bundle.sh - apply one direct closeout as one recoverable Git commit

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
VALIDATOR="${SCRIPT_DIR}/validate-closeout-receipt.py"

REPO_ROOT=""
BUNDLE_ROOT=""
RECEIPT_RELATIVE=""
ACTIVE_ENTITY_RELATIVE=""
IF_HEAD=""
IF_ROADMAP_HASH=""
COMMIT_AS=""
SOURCE_COMMITS=""

usage() {
  echo "Usage: apply-closeout-bundle.sh --repo-root PATH --bundle-root PATH --receipt-relative PATH --active-entity-relative PATH --if-head SHA --if-roadmap-hash SHA256 --commit-as MESSAGE [--source-commits SHA[,SHA...]]" >&2
  exit 2
}

stop() {
  printf 'verdict=STOP\nreason=%s\ndetail=%s\n' "$1" "$2"
  exit "${3:-1}"
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

safe_relative() {
  case "$1" in ""|/*|*".."*) return 1 ;; esac
  [[ "$1" =~ ^[A-Za-z0-9._/-]+$ ]]
}

preflight_lexical_paths() {
  local root="$1"
  shift
  python3 - "$root" "$@" <<'PY'
import os,pathlib,stat,sys
root=os.path.abspath(sys.argv[1]); root_real=os.path.realpath(root)
def reject(detail):
    print("verdict=STOP")
    print("reason=closeout-sentinel-invalid")
    print("detail="+detail)
    raise SystemExit(1)
if os.path.islink(root): reject("preflight root is a symlink")
for raw in sys.argv[2:]:
    logical=pathlib.PurePosixPath(raw)
    if logical.is_absolute() or not logical.parts or any(part in ("", ".", "..") for part in logical.parts):
        reject("preflight path is not a safe repository-relative path: "+raw)
    current=root
    for part in logical.parts:
        current=os.path.join(current,part)
        if os.path.lexists(current):
            if stat.S_ISLNK(os.lstat(current).st_mode):
                reject("preflight path contains a symlink component: "+raw)
    resolved=os.path.realpath(current)
    try: contained=os.path.commonpath((root_real,resolved))==root_real
    except ValueError: contained=False
    if not contained: reject("preflight path resolves outside its root: "+raw)
PY
}

validate_tracked_entity_tree() {
  local repo_root="$1" active_relative="$2"
  python3 - "$repo_root" "$active_relative" <<'PY'
import os,stat,subprocess,sys
repo,active=sys.argv[1:]
prefix=active.rstrip("/")+"/"
tracked=subprocess.check_output(
    ["git","-C",repo,"ls-files","-z","--",active]
).split(b"\0")
tracked=[os.fsdecode(path) for path in tracked if path]
def reject(detail):
    print("verdict=STOP")
    print("reason=closeout-sentinel-invalid")
    print("detail="+detail)
    raise SystemExit(1)
if not tracked:
    reject("active entity has no tracked files")
for relative in tracked:
    if not relative.startswith(prefix):
        reject("tracked entity path is outside the active folder: "+relative)
    current=repo
    for part in relative.split("/"):
        current=os.path.join(current,part)
        try: mode=os.lstat(current).st_mode
        except FileNotFoundError:
            reject("tracked entity path is missing: "+relative)
        if stat.S_ISLNK(mode):
            reject("tracked entity path contains a symlink: "+relative)
    if not stat.S_ISREG(mode):
        reject("tracked entity path is not a regular file: "+relative)
PY
}

copy_tracked_entity_tree() {
  local repo_root="$1" active_relative="$2" archive_root_relative="$3"
  python3 - "$repo_root" "$active_relative" "$archive_root_relative" <<'PY'
import os,shutil,subprocess,sys
repo,active,archive=sys.argv[1:]
prefix=active.rstrip("/")+"/"
tracked=subprocess.check_output(
    ["git","-C",repo,"ls-files","-z","--",active]
).split(b"\0")
for encoded in tracked:
    if not encoded: continue
    relative=os.fsdecode(encoded)
    tail=relative[len(prefix):]
    source=os.path.join(repo,relative)
    destination=os.path.join(repo,archive,tail)
    os.makedirs(os.path.dirname(destination),exist_ok=True)
    shutil.copyfile(source,destination)
    shutil.copymode(source,destination)
PY
}

validate_normal_receipt() {
  local receipt="$1"
  shift
  local validator_out validator_rc=0
  validator_out="$(mktemp)"
  if [ -n "$SOURCE_COMMITS" ]; then
    python3 "$VALIDATOR" --receipt "$receipt" --repo-root "$REPO_ROOT" \
      --source-commits "$SOURCE_COMMITS" "$@" >"$validator_out" 2>&1 || validator_rc=$?
  else
    python3 "$VALIDATOR" --receipt "$receipt" --repo-root "$REPO_ROOT" \
      "$@" >"$validator_out" 2>&1 || validator_rc=$?
  fi
  if [ "$validator_rc" -ne 0 ]; then
    cat "$validator_out"
    rm -f "$validator_out"
    return "$validator_rc"
  fi
  rm -f "$validator_out"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-root) REPO_ROOT="${2:-}"; shift 2 ;;
    --bundle-root) BUNDLE_ROOT="${2:-}"; shift 2 ;;
    --receipt-relative) RECEIPT_RELATIVE="${2:-}"; shift 2 ;;
    --active-entity-relative) ACTIVE_ENTITY_RELATIVE="${2:-}"; shift 2 ;;
    --if-head) IF_HEAD="${2:-}"; shift 2 ;;
    --if-roadmap-hash) IF_ROADMAP_HASH="${2:-}"; shift 2 ;;
    --commit-as) COMMIT_AS="${2:-}"; shift 2 ;;
    --source-commits) SOURCE_COMMITS="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done

[ -d "$REPO_ROOT/.git" ] || git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1 || usage
[ -d "$BUNDLE_ROOT" ] || usage
safe_relative "$RECEIPT_RELATIVE" || usage
safe_relative "$ACTIVE_ENTITY_RELATIVE" || usage
[[ "$IF_HEAD" =~ ^[0-9a-f]{40}$ ]] || usage
[[ "$IF_ROADMAP_HASH" =~ ^[0-9a-f]{64}$ ]] || usage
C14_SUBJECT_RE='^[a-z][a-z0-9-]*(\([A-Za-z0-9._/-]+\))?: advance status to done$'
[[ "$COMMIT_AS" =~ $C14_SUBJECT_RE ]] || usage

REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"
BUNDLE_ROOT="$(cd "$BUNDLE_ROOT" && pwd -P)"
RECEIPT_SOURCE="$BUNDLE_ROOT/$RECEIPT_RELATIVE"
preflight_lexical_paths "$BUNDLE_ROOT" ROADMAP.md "$RECEIPT_RELATIVE" || exit $?
preflight_lexical_paths "$REPO_ROOT" ROADMAP.md "$ACTIVE_ENTITY_RELATIVE" "$RECEIPT_RELATIVE" || exit $?
[ -f "$RECEIPT_SOURCE" ] || stop closeout-stage-artifacts-incoherent "prepared receipt is missing"

CURRENT_BRANCH="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD || true)"
[ "$CURRENT_BRANCH" = main ] || stop closeout-main-not-authoritative "direct closeout requires the authoritative main branch"
CURRENT_HEAD="$(git -C "$REPO_ROOT" rev-parse HEAD)"
[ "$CURRENT_HEAD" = "$IF_HEAD" ] || stop closeout-checkpoint-conflict "authoritative main moved after bundle preparation"
[ -f "$REPO_ROOT/ROADMAP.md" ] || stop closeout-stage-artifacts-incoherent "ROADMAP.md is missing"
[ "$(sha256_file "$REPO_ROOT/ROADMAP.md")" = "$IF_ROADMAP_HASH" ] || stop closeout-roadmap-conflict "ROADMAP.md changed after bundle preparation"

RECEIPT_PATH="$REPO_ROOT/$RECEIPT_RELATIVE"
python3 "$VALIDATOR" --receipt "$RECEIPT_SOURCE" --allow-any-path >/dev/null || exit $?

RECEIPT_FIELDS=()
while IFS= read -r receipt_field; do
  RECEIPT_FIELDS[${#RECEIPT_FIELDS[@]}]="$receipt_field"
done < <(python3 - "$RECEIPT_SOURCE" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
print(r["mode"]); print(r["transaction"]["phase"]); print(r["identity"]["workflow"]); print(r["identity"]["entity_slug"])
print(r["outputs"]["debrief"]["path"]); print(r["outputs"]["ship"]["path"]); print(r["outputs"]["archived_entity"]["path"])
print(r["proof_hash"])
PY
)
[ "${#RECEIPT_FIELDS[@]}" -eq 8 ] || stop closeout-sentinel-invalid "receipt fields could not be parsed"
[ "${RECEIPT_FIELDS[0]}" = direct ] && [ "${RECEIPT_FIELDS[1]}" = applied ] || stop closeout-checkpoint-conflict "direct bundle receipt must be in applied phase"
EXPECTED_ACTIVE="${RECEIPT_FIELDS[2]}/${RECEIPT_FIELDS[3]}"
[ "$ACTIVE_ENTITY_RELATIVE" = "$EXPECTED_ACTIVE" ] || stop closeout-checkpoint-conflict "active entity does not match receipt identity"
DEBRIEF_RELATIVE="${RECEIPT_FIELDS[4]}"
SHIP_RELATIVE="${RECEIPT_FIELDS[5]}"
ARCHIVE_RELATIVE="${RECEIPT_FIELDS[6]}"
PROOF_HASH="${RECEIPT_FIELDS[7]}"
for relative in "$DEBRIEF_RELATIVE" "$SHIP_RELATIVE" "$ARCHIVE_RELATIVE"; do safe_relative "$relative" || stop closeout-sentinel-invalid "receipt output path is unsafe"; done
ARCHIVE_ROOT_RELATIVE="${ARCHIVE_RELATIVE%/index.md}"
[ "$ARCHIVE_RELATIVE" = "$ARCHIVE_ROOT_RELATIVE/index.md" ] || stop closeout-sentinel-invalid "archived entity output must be the canonical index path"
[ "$SHIP_RELATIVE" = "$ARCHIVE_ROOT_RELATIVE/ship.md" ] || stop closeout-sentinel-invalid "ship output must share the canonical archive folder"
[ "$ARCHIVE_ROOT_RELATIVE" = "${RECEIPT_FIELDS[2]}/_archive/${RECEIPT_FIELDS[3]}" ] || stop closeout-sentinel-invalid "archive folder does not match receipt identity"

preflight_lexical_paths "$BUNDLE_ROOT" ROADMAP.md "$RECEIPT_RELATIVE" "$DEBRIEF_RELATIVE" "$SHIP_RELATIVE" "$ARCHIVE_RELATIVE" || exit $?
preflight_lexical_paths "$REPO_ROOT" ROADMAP.md "$ACTIVE_ENTITY_RELATIVE" "$ACTIVE_ENTITY_RELATIVE/index.md" "$ACTIVE_ENTITY_RELATIVE/review.md" "$ACTIVE_ENTITY_RELATIVE/ship.md" "$RECEIPT_RELATIVE" "$DEBRIEF_RELATIVE" "$ARCHIVE_ROOT_RELATIVE" "$SHIP_RELATIVE" "$ARCHIVE_RELATIVE" || exit $?

if [ -f "$RECEIPT_PATH" ]; then
  SOURCE_PROOF="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["proof_hash"])' "$RECEIPT_SOURCE")"
  LANDED_PROOF="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["proof_hash"])' "$RECEIPT_PATH" 2>/dev/null || true)"
  [ -n "$LANDED_PROOF" ] && [ "$SOURCE_PROOF" = "$LANDED_PROOF" ] || stop closeout-proof-hash-mismatch "landed closeout receipt differs from prepared proof"
  validate_normal_receipt "$RECEIPT_PATH" --verify-outputs || exit $?
  printf 'verdict=PROCEED\nstate=already_applied\nproof_hash=%s\ncommit=%s\n' "$LANDED_PROOF" "$(git -C "$REPO_ROOT" rev-parse HEAD)"
  exit 0
fi

[ -z "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all)" ] || stop closeout-checkpoint-conflict "authoritative main worktree is not clean"

for relative in ROADMAP.md "$DEBRIEF_RELATIVE" "$SHIP_RELATIVE" "$ARCHIVE_RELATIVE" "$RECEIPT_RELATIVE"; do
  [ -f "$BUNDLE_ROOT/$relative" ] || stop closeout-stage-artifacts-incoherent "bundle output is missing: $relative"
done
for relative in "$DEBRIEF_RELATIVE" "$SHIP_RELATIVE" "$ARCHIVE_RELATIVE"; do
  if [ -e "$REPO_ROOT/$relative" ]; then
    stop closeout-projection-source-drift "terminal projection exists without the matching closeout receipt: $relative"
  fi
done
[ ! -e "$REPO_ROOT/$ARCHIVE_ROOT_RELATIVE" ] || stop closeout-projection-source-drift "terminal archive exists without the matching closeout receipt: $ARCHIVE_ROOT_RELATIVE"
for source in index.md review.md ship.md; do
  [ -f "$REPO_ROOT/$ACTIVE_ENTITY_RELATIVE/$source" ] || stop closeout-stage-artifacts-incoherent "active source is missing: $source"
done
validate_tracked_entity_tree "$REPO_ROOT" "$ACTIVE_ENTITY_RELATIVE" || exit $?

python3 - "$RECEIPT_SOURCE" "$REPO_ROOT" "$BUNDLE_ROOT" <<'PY'
import hashlib,json,pathlib,re,sys
receipt_path,repo,bundle=pathlib.Path(sys.argv[1]),pathlib.Path(sys.argv[2]),pathlib.Path(sys.argv[3])
r=json.loads(receipt_path.read_text())
def h(path): return hashlib.sha256(path.read_bytes()).hexdigest()
base=repo/r["identity"]["workflow"]/r["identity"]["entity_slug"]
for key,name in (("index","index.md"),("review","review.md"),("ship","ship.md")):
    if h(base/name)!=r["ownership_proof"]["source_hashes"][key]:
        print("verdict=STOP\nreason=closeout-projection-source-drift\ndetail=source bytes changed for "+key); raise SystemExit(1)
for key in ("debrief","ship","archived_entity"):
    out=r["outputs"][key]
    if h(bundle/out["path"])!=out["sha256"]:
        print("verdict=STOP\nreason=closeout-proof-hash-mismatch\ndetail=bundle bytes differ for "+key); raise SystemExit(1)
lines=(bundle/"ROADMAP.md").read_text().splitlines()
identity=r["outputs"]["roadmap_row"]["identity"]
opens=[i for i,line in enumerate(lines) if line.strip()=="<!-- section:shipped -->"]
closes=[i for i,line in enumerate(lines) if line.strip()=="<!-- /section:shipped -->"]
if len(opens)!=1 or len(closes)!=1 or opens[0]>=closes[0]:
    print("verdict=STOP\nreason=closeout-roadmap-conflict\ndetail=ROADMAP must contain exactly one bounded Shipped section"); raise SystemExit(1)
rows=[]
for line in lines[opens[0]+1:closes[0]]:
    stripped=line.strip()
    if not (stripped.startswith("|") and stripped.endswith("|")): continue
    cells=[cell.strip() for cell in stripped[1:-1].split("|")]
    if len(cells)<2 or all(re.fullmatch(r":?-{3,}:?",cell) for cell in cells): continue
    if cells[0]==identity: rows.append(line)
if len(rows)!=1:
    print("verdict=STOP\nreason=closeout-roadmap-conflict\ndetail=ROADMAP must contain exactly one shipped identity row"); raise SystemExit(1)
if hashlib.sha256(rows[0].encode()).hexdigest()!=r["outputs"]["roadmap_row"]["sha256"]:
    print("verdict=STOP\nreason=closeout-roadmap-conflict\ndetail=ROADMAP row bytes differ from receipt"); raise SystemExit(1)
PY

DEBRIEF_SOURCE="$BUNDLE_ROOT/$DEBRIEF_RELATIVE"
if ! grep -q '^## Reconciliation$' "$DEBRIEF_SOURCE" || ! grep -q '^## Todo Closure$' "$DEBRIEF_SOURCE"; then
  stop closeout-stage-artifacts-incoherent "debrief omits reconciliation or todo closure"
fi
grep -qE '^- \[ \]' "$DEBRIEF_SOURCE" && stop closeout-stage-artifacts-incoherent "debrief contains unresolved todo" || true
SHIP_C15="$(
  awk '
    BEGIN { in_fm=0; in_details=0; count=0; pending=0; fm_pending=0; malformed=0 }
    { sub(/\r$/, "") }
    NR == 1 && $0 == "---" { in_fm=1; fm_pending=1; next }
    in_fm == 1 {
      if ($0 == "---") { in_fm=0; fm_pending=0; next }
      fm_pending++
      next
    }
    in_details == 1 {
      if ($0 ~ /^[[:space:]]*<\/details>[[:space:]]*$/) {
        in_details=0; pending=0; next
      }
      pending++
      next
    }
    /^<!--[[:space:]]*\/?section:/ { next }
    /^[[:space:]]*<details([[:space:]][^>]*)?>[[:space:]]*$/ { in_details=1; pending=1; next }
    { count++ }
    END {
      if (in_details == 1) { count += pending; malformed=1 }
      if (in_fm == 1) { count += fm_pending }
      printf "%d %d\n", count, malformed
    }
  ' "$BUNDLE_ROOT/$SHIP_RELATIVE"
)"
SHIP_BODY_LINES="${SHIP_C15%% *}"
SHIP_DETAILS_MALFORMED="${SHIP_C15##* }"
SHIP_RAW_LINES="$(awk 'END { print NR }' "$BUNDLE_ROOT/$SHIP_RELATIVE")"
[ "$SHIP_DETAILS_MALFORMED" -eq 0 ] || stop closeout-stage-artifacts-incoherent "ship.md contains malformed or unbalanced standalone details"
[ "$SHIP_BODY_LINES" -le 60 ] || stop closeout-stage-artifacts-incoherent "ship.md exceeds C15 body cap"
[ "$SHIP_RAW_LINES" -le 120 ] || stop closeout-stage-artifacts-incoherent "ship.md exceeds C15 raw backstop"
if ! grep -q '^status: done$' "$BUNDLE_ROOT/$ARCHIVE_RELATIVE" || ! grep -q '^verdict: PASSED$' "$BUNDLE_ROOT/$ARCHIVE_RELATIVE"; then
  stop archived-terminal-incoherent "archived entity is not coherently terminal"
fi

APPLIED="no"
durable_closeout_commit_exists() {
  local landed_head parent subject
  landed_head="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)"
  [ -n "$landed_head" ] && [ "$landed_head" != "$CURRENT_HEAD" ] || return 1
  parent="$(git -C "$REPO_ROOT" rev-parse "${landed_head}^" 2>/dev/null || true)"
  [ "$parent" = "$CURRENT_HEAD" ] || return 1
  subject="$(git -C "$REPO_ROOT" log -1 --format=%s "$landed_head" 2>/dev/null || true)"
  [ "$subject" = "$COMMIT_AS" ] || return 1
  git -C "$REPO_ROOT" show "${landed_head}:${RECEIPT_RELATIVE}" 2>/dev/null | cmp -s - "$RECEIPT_SOURCE"
}
rollback() {
  local rc="${1:-1}"
  if [ "$APPLIED" = yes ]; then
    if durable_closeout_commit_exists; then
      APPLIED="no"
      exit "$rc"
    fi
    git -C "$REPO_ROOT" reset -q HEAD -- "$ACTIVE_ENTITY_RELATIVE" ROADMAP.md "$DEBRIEF_RELATIVE" "$ARCHIVE_ROOT_RELATIVE" "$RECEIPT_RELATIVE" 2>/dev/null || true
    git -C "$REPO_ROOT" restore --source=HEAD --worktree -- "$ACTIVE_ENTITY_RELATIVE" ROADMAP.md 2>/dev/null || true
    rm -f "$REPO_ROOT/$DEBRIEF_RELATIVE" "$REPO_ROOT/$RECEIPT_RELATIVE"
    rm -rf "$REPO_ROOT/${ARCHIVE_ROOT_RELATIVE:?}"
    rmdir "$REPO_ROOT/$(dirname "$DEBRIEF_RELATIVE")" "$REPO_ROOT/$(dirname "$RECEIPT_RELATIVE")" 2>/dev/null || true
  fi
  exit "$rc"
}
trap 'rollback $?' ERR
trap 'rollback 130' INT
trap 'rollback 143' TERM
APPLIED="yes"
mkdir -p "$REPO_ROOT/$(dirname "$DEBRIEF_RELATIVE")" "$REPO_ROOT/$(dirname "$SHIP_RELATIVE")" "$REPO_ROOT/$(dirname "$ARCHIVE_RELATIVE")" "$REPO_ROOT/$(dirname "$RECEIPT_RELATIVE")"
copy_tracked_entity_tree "$REPO_ROOT" "$ACTIVE_ENTITY_RELATIVE" "$ARCHIVE_ROOT_RELATIVE"
cp "$BUNDLE_ROOT/ROADMAP.md" "$REPO_ROOT/ROADMAP.md"
cp "$BUNDLE_ROOT/$DEBRIEF_RELATIVE" "$REPO_ROOT/$DEBRIEF_RELATIVE"
cp "$BUNDLE_ROOT/$SHIP_RELATIVE" "$REPO_ROOT/$SHIP_RELATIVE"
cp "$BUNDLE_ROOT/$ARCHIVE_RELATIVE" "$REPO_ROOT/$ARCHIVE_RELATIVE"
cp "$RECEIPT_SOURCE" "$RECEIPT_PATH"
rm -rf "$REPO_ROOT/${ACTIVE_ENTITY_RELATIVE:?}"

git -C "$REPO_ROOT" add -- "$ACTIVE_ENTITY_RELATIVE" ROADMAP.md "$DEBRIEF_RELATIVE" "$ARCHIVE_ROOT_RELATIVE" "$RECEIPT_RELATIVE"
validate_normal_receipt "$RECEIPT_PATH" --verify-outputs
if [ "${SHIP_FLOW_CLOSEOUT_FAILPOINT:-}" = before-commit ]; then
  printf 'verdict=STOP\nreason=closeout-checkpoint-conflict\ndetail=injected failure before atomic closeout commit\n'
  false
fi
git -C "$REPO_ROOT" commit -qm "$COMMIT_AS" -- "$ACTIVE_ENTITY_RELATIVE" ROADMAP.md "$DEBRIEF_RELATIVE" "$ARCHIVE_ROOT_RELATIVE" "$RECEIPT_RELATIVE"
APPLIED="no"
trap - ERR INT TERM

printf 'verdict=PROCEED\nstate=applied\nproof_hash=%s\ncommit=%s\n' "$PROOF_HASH" "$(git -C "$REPO_ROOT" rev-parse HEAD)"
