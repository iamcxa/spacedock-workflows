#!/usr/bin/env bash
# test-closeout-receipt.sh — D2-D4 receipt identity, hashing, and phase contract
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)"
VALIDATOR="${PLUGIN_ROOT}/lib/validate-closeout-receipt.py"
SCHEMA="${PLUGIN_ROOT}/references/closeout-receipt-schema.yaml"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/closeout-receipt"
# shellcheck source=/dev/null
source "${FIXTURE_ROOT}/golden.env"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0
FAIL=0

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
expect_ok() { local name="$1"; shift; if "$@" >"$TMP/out" 2>&1; then ok "$name"; else bad "$name"; cat "$TMP/out"; fi; }
expect_reason() {
  local name="$1" reason="$2"; shift 2
  if "$@" >"$TMP/out" 2>&1; then bad "$name (unexpected success)"
  elif grep -q "^reason=${reason}$" "$TMP/out"; then ok "$name"
  else bad "$name (missing reason=${reason})"; cat "$TMP/out"; fi
}

make_receipt() {
  local path="$1" phase="${2:-prepared}" mode="${3:-direct}" owners="${4:-1}"
  python3 - "$path" "$phase" "$mode" "$owners" <<'PY'
import hashlib,json,pathlib,sys
path, phase, mode, owners = sys.argv[1:]
ident={"provider":"github","repository":"acme/widgets","workflow":"docs/ship-flow","entity_slug":"widget-closeout","implementation_pr":40}
raw=b"\0".join([b"v1",b"github",b"acme/widgets",b"docs/ship-flow",b"widget-closeout",b"40"])
cid=hashlib.sha256(raw).hexdigest(); h="a"*64
participants=[]; matches=1
if int(owners)==0: matches=0
if int(owners)==2: matches=2; participants=["widget-closeout"]
r={"schema_version":1,"kind":"ship-flow.closeout","closeout_id":cid,"identity":ident,
 "ownership_proof":{"unique_entity_matches":matches,"participant_entities":participants,"source_hashes":{"index":h,"review":h,"ship":h}},
 "mode":mode,"merge_method_intent":None,"deterministic_closeout_head":"ship-closeout/"+cid,
 "landing_proof":{"landing_anchor":"b"*40,"strategy":"squash"},
 "transaction":{"phase":phase,"generation":1,"closeout_pr":None,"main_commit":None},
 "outputs":{"debrief":{"path":"docs/ship-flow/_debriefs/2026-07-15-01.md","sha256":h},"ship":{"path":"docs/ship-flow/_archive/widget-closeout/ship.md","sha256":h},"archived_entity":{"path":"docs/ship-flow/_archive/widget-closeout/index.md","sha256":h},"roadmap_row":{"identity":"widget-closeout","sha256":h}}}
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}
r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
pathlib.Path(path).parent.mkdir(parents=True,exist_ok=True); pathlib.Path(path).write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
}

transition_receipt() {
  local source="$1" target="$2" phase="$3" generation="$4" closeout_pr="$5" main_commit="$6" mode="${7:-}" intent="${8:-KEEP}" head="${9:-KEEP}"
  python3 - "$source" "$target" "$phase" "$generation" "$closeout_pr" "$main_commit" "$mode" "$intent" "$head" <<'PY'
import json,sys
src,dst,phase,generation,pr,main,mode,intent,head=sys.argv[1:]
r=json.load(open(src)); r["transaction"]["phase"]=phase; r["transaction"]["generation"]=int(generation)
r["transaction"]["closeout_pr"]=None if pr=="null" else int(pr)
r["transaction"]["main_commit"]=None if main=="null" else main
if mode: r["mode"]=mode
if intent!="KEEP": r["merge_method_intent"]=None if intent=="null" else intent
if head!="KEEP": r["deterministic_closeout_head"]=head
json.dump(r,open(dst,"w"),sort_keys=True,indent=2); open(dst,"a").write("\n")
PY
}

bind_repo_bytes() {
  local receipt="$1" root="$2"
  python3 - "$receipt" "$root" <<'PY'
import hashlib,json,pathlib,sys
p=pathlib.Path(sys.argv[1]); root=pathlib.Path(sys.argv[2]); r=json.loads(p.read_text())
for key in ("debrief","ship","archived_entity"):
    r["outputs"][key]["sha256"]=hashlib.sha256((root/r["outputs"][key]["path"]).read_bytes()).hexdigest()
identity=r["outputs"]["roadmap_row"]["identity"]
rows=[line for line in (root/"ROADMAP.md").read_text().splitlines() if line.strip().startswith("|") and identity in [cell.strip() for cell in line.strip()[1:-1].split("|")]]
assert len(rows)==1; r["outputs"]["roadmap_row"]["sha256"]=hashlib.sha256(rows[0].encode()).hexdigest()
base=root/r["identity"]["workflow"]/r["identity"]["entity_slug"]
for key,name in (("index","index.md"),("review","review.md"),("ship","ship.md")):
    r["ownership_proof"]["source_hashes"][key]=hashlib.sha256((base/name).read_bytes()).hexdigest()
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}
r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
}

echo "=== closeout receipt contract ==="
if test -f "$SCHEMA"; then ok "receipt schema exists"; else bad "receipt schema exists"; fi
make_receipt "$TMP/receipt.json"
CID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["closeout_id"])' "$TMP/receipt.json")"
mkdir -p "$TMP/docs/ship-flow/_closeouts"; cp "$TMP/receipt.json" "$TMP/docs/ship-flow/_closeouts/$CID.json"
CANONICAL="$TMP/docs/ship-flow/_closeouts/$CID.json"
expect_ok "golden canonical receipt validates" python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP"
expect_ok "golden NUL identity vector is stable" grep -q "^closeout_id=${GOLDEN_CLOSEOUT_ID}$" <(python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP")
expect_ok "golden canonical payload hash is stable" grep -q "^proof_hash=${GOLDEN_PROOF_HASH}$" <(python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP")

mkdir -p "$TMP/arbitrary"; cp "$TMP/receipt.json" "$TMP/arbitrary/$CID.json"
expect_reason "arbitrary receipt directory rejects" closeout-sentinel-invalid python3 "$VALIDATOR" --receipt "$TMP/arbitrary/$CID.json" --repo-root "$TMP"
mkdir -p "$TMP/symlink-repo/docs/ship-flow/_closeouts"; cp "$TMP/receipt.json" "$TMP/outside-receipt.json"
ln -s "$TMP/outside-receipt.json" "$TMP/symlink-repo/docs/ship-flow/_closeouts/$CID.json"
expect_reason "canonical-path symlink escape rejects" closeout-sentinel-invalid python3 "$VALIDATOR" --receipt "$TMP/symlink-repo/docs/ship-flow/_closeouts/$CID.json" --repo-root "$TMP/symlink-repo"
mkdir -p "$TMP/internal-symlink-repo/docs/ship-flow/_closeouts" "$TMP/internal-symlink-repo/storage"
cp "$TMP/receipt.json" "$TMP/internal-symlink-repo/storage/receipt.json"
ln -s "$TMP/internal-symlink-repo/storage/receipt.json" "$TMP/internal-symlink-repo/docs/ship-flow/_closeouts/$CID.json"
expect_reason "canonical receipt internal symlink rejects" closeout-sentinel-invalid python3 "$VALIDATOR" --receipt "$TMP/internal-symlink-repo/docs/ship-flow/_closeouts/$CID.json" --repo-root "$TMP/internal-symlink-repo"

mkdir -p "$TMP/_closeouts"; cp "$TMP/receipt.json" "$TMP/_closeouts/wrong.json"
expect_reason "path-derived ID mismatch stops" closeout-id-path-mismatch python3 "$VALIDATOR" --receipt "$TMP/_closeouts/wrong.json" --repo-root "$TMP"

make_receipt "$TMP/zero.json" prepared direct 0
expect_reason "shared owner zero stops" closeout-owner-not-unique python3 "$VALIDATOR" --receipt "$TMP/zero.json" --allow-any-path
make_receipt "$TMP/multiple.json" prepared direct 2
expect_reason "shared owner multiple stops" closeout-owner-not-unique python3 "$VALIDATOR" --receipt "$TMP/multiple.json" --allow-any-path

python3 - "$TMP/receipt.json" "$TMP/tampered.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); r["outputs"]["ship"]["sha256"]="c"*64
json.dump(r,open(sys.argv[2],"w"),sort_keys=True)
PY
expect_reason "stale artifact hash invalidates proof" closeout-sentinel-payload-mismatch python3 "$VALIDATOR" --receipt "$TMP/tampered.json" --allow-any-path

make_receipt "$TMP/prepared.json" prepared
transition_receipt "$TMP/prepared.json" "$TMP/mismatched-anchor-applied.json" applied 2 null "c$(printf 'c%.0s' {1..39})"
expect_reason "applied main commit must equal verified landing anchor" closeout-checkpoint-conflict python3 "$VALIDATOR" --receipt "$TMP/mismatched-anchor-applied.json" --allow-any-path
transition_receipt "$TMP/prepared.json" "$TMP/applied.json" applied 2 null "$(printf 'b%.0s' {1..40})"
expect_ok "phase advances monotonically" python3 "$VALIDATOR" --receipt "$TMP/applied.json" --previous "$TMP/prepared.json" --allow-any-path
transition_receipt "$TMP/applied.json" "$TMP/mismatched-anchor-complete.json" complete 3 null "c$(printf 'c%.0s' {1..39})"
expect_reason "complete main commit must equal verified landing anchor" closeout-checkpoint-conflict python3 "$VALIDATOR" --receipt "$TMP/mismatched-anchor-complete.json" --allow-any-path
expect_reason "phase regression stops" closeout-checkpoint-conflict python3 "$VALIDATOR" --receipt "$TMP/prepared.json" --previous "$TMP/applied.json" --allow-any-path
expect_ok "idempotent receipt replay is valid" python3 "$VALIDATOR" --receipt "$TMP/applied.json" --previous "$TMP/applied.json" --allow-any-path

mkdir -p "$TMP/docs/ship-flow/_debriefs" "$TMP/docs/ship-flow/_archive/widget-closeout" "$TMP/docs/ship-flow/widget-closeout"
echo "landed debrief" >"$TMP/docs/ship-flow/_debriefs/2026-07-15-01.md"
echo "landed ship" >"$TMP/docs/ship-flow/_archive/widget-closeout/ship.md"
echo "landed entity" >"$TMP/docs/ship-flow/_archive/widget-closeout/index.md"
printf '%s\n' '# Roadmap' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' '| widget-closeout | Widget closeout | 2026-07-15 |' '<!-- /section:shipped -->' >"$TMP/ROADMAP.md"
echo "source index" >"$TMP/docs/ship-flow/widget-closeout/index.md"
echo "source review" >"$TMP/docs/ship-flow/widget-closeout/review.md"
echo "source ship" >"$TMP/docs/ship-flow/widget-closeout/ship.md"
make_receipt "$CANONICAL" prepared direct 1; bind_repo_bytes "$CANONICAL" "$TMP"
expect_ok "exact landed output bytes validate" python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-outputs
SPACED_ROW='| widget-closeout | Widget closeout | 2026-07-15 |'
COMPACT_ROW='|widget-closeout|Widget closeout|2026-07-15|'
SPACED_HASH="$(printf '%s' "$SPACED_ROW" | shasum -a 256 | awk '{print $1}')"
COMPACT_HASH="$(printf '%s' "$COMPACT_ROW" | shasum -a 256 | awk '{print $1}')"
if [ "$SPACED_HASH" != "$COMPACT_HASH" ]; then ok "ROADMAP raw row hash excludes newline and distinguishes spacing"; else bad "ROADMAP raw row hash excludes newline and distinguishes spacing"; fi
printf '%s\n' '# Roadmap' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' "$COMPACT_ROW" '<!-- /section:shipped -->' >"$TMP/ROADMAP.md"
expect_reason "normalized cells cannot hide compact landed-byte drift" closeout-sentinel-payload-mismatch python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-outputs
printf '%s\n' '# Roadmap' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' "$SPACED_ROW" '<!-- /section:shipped -->' >"$TMP/ROADMAP.md"
mv "$TMP/docs/ship-flow/_archive/widget-closeout/ship.md" "$TMP/docs/ship-flow/_archive/widget-closeout/internal-target.md"
ln -s "$TMP/docs/ship-flow/_archive/widget-closeout/internal-target.md" "$TMP/docs/ship-flow/_archive/widget-closeout/ship.md"
expect_reason "landed output internal symlink rejects" closeout-sentinel-invalid python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-outputs
rm "$TMP/docs/ship-flow/_archive/widget-closeout/ship.md"; mv "$TMP/docs/ship-flow/_archive/widget-closeout/internal-target.md" "$TMP/docs/ship-flow/_archive/widget-closeout/ship.md"
expect_ok "exact preparation source bytes validate" python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-sources
echo "tampered source" >>"$TMP/docs/ship-flow/widget-closeout/review.md"
expect_reason "tampered preparation source rejects" closeout-projection-source-drift python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-sources
rm "$TMP/docs/ship-flow/widget-closeout/review.md"
expect_reason "missing preparation source rejects" closeout-stage-artifacts-incoherent python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-sources
make_receipt "$TMP/source-traversal.json" prepared direct 1
python3 - "$TMP/source-traversal.json" <<'PY'
import hashlib,json,sys
p=sys.argv[1]; r=json.load(open(p)); r["identity"]["workflow"]="../escape"
raw="\0".join(["v1",r["identity"]["provider"],r["identity"]["repository"],r["identity"]["workflow"],r["identity"]["entity_slug"],str(r["identity"]["implementation_pr"])]).encode()
r["closeout_id"]=hashlib.sha256(raw).hexdigest(); r["deterministic_closeout_head"]="ship-closeout/"+r["closeout_id"]
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}; r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
json.dump(r,open(p,"w"),sort_keys=True)
PY
expect_reason "source path traversal identity rejects" closeout-sentinel-invalid python3 "$VALIDATOR" --receipt "$TMP/source-traversal.json" --repo-root "$TMP" --allow-any-path --verify-sources
echo "tampered" >>"$TMP/docs/ship-flow/_archive/widget-closeout/ship.md"
expect_reason "tampered landed output rejects" closeout-sentinel-payload-mismatch python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-outputs
rm "$TMP/docs/ship-flow/_archive/widget-closeout/ship.md"
expect_reason "missing landed output rejects" closeout-stage-artifacts-incoherent python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-outputs
python3 - "$CANONICAL" <<'PY'
import hashlib,json,sys
p=sys.argv[1]; r=json.load(open(p)); r["outputs"]["debrief"]["path"]="../escape.md"
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}
r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
json.dump(r,open(p,"w"),sort_keys=True)
PY
expect_reason "output path traversal rejects" closeout-sentinel-invalid python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-outputs

echo "landed ship" >"$TMP/docs/ship-flow/_archive/widget-closeout/ship.md"
echo "source review" >"$TMP/docs/ship-flow/widget-closeout/review.md"
printf '%s\n' '# Roadmap' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' '| widget-closeout | Widget closeout | 2026-07-15 |' '<!-- /section:shipped -->' >"$TMP/ROADMAP.md"
make_receipt "$CANONICAL" prepared direct 1; bind_repo_bytes "$CANONICAL" "$TMP"
printf '%s\n' '# Roadmap' '## Shipped' '<!-- section:shipped -->' 'widget-closeout shipped in prose only' '<!-- /section:shipped -->' >"$TMP/ROADMAP.md"
python3 - "$CANONICAL" 'widget-closeout shipped in prose only' <<'PY'
import hashlib,json,sys
p,line=sys.argv[1:]; r=json.load(open(p)); r["outputs"]["roadmap_row"]["sha256"]=hashlib.sha256(line.encode()).hexdigest()
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}; r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest(); json.dump(r,open(p,"w"),sort_keys=True)
PY
expect_reason "ROADMAP prose mention is not a shipped row" closeout-stage-artifacts-incoherent python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-outputs
printf '%s\n' '# Roadmap' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' '| widget-closeout-child | Child | today |' '<!-- /section:shipped -->' >"$TMP/ROADMAP.md"
python3 - "$CANONICAL" '| widget-closeout-child | Child | today |' <<'PY'
import hashlib,json,sys
p,line=sys.argv[1:]; r=json.load(open(p)); r["outputs"]["roadmap_row"]["sha256"]=hashlib.sha256(line.encode()).hexdigest()
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}; r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest(); json.dump(r,open(p,"w"),sort_keys=True)
PY
expect_reason "ROADMAP substring cell is not exact identity" closeout-stage-artifacts-incoherent python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-outputs
printf '%s\n' '# Roadmap' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' '| widget-closeout | One | today |' '| widget-closeout | Two | today |' '<!-- /section:shipped -->' >"$TMP/ROADMAP.md"
expect_reason "duplicate exact Shipped rows reject" closeout-stage-artifacts-incoherent python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --verify-outputs

make_receipt "$TMP/direct-prepared.json" prepared direct 1
transition_receipt "$TMP/direct-prepared.json" "$TMP/direct-applied.json" applied 2 null "$(printf 'b%.0s' {1..40})"
expect_ok "direct prepared to applied is legal" python3 "$VALIDATOR" --receipt "$TMP/direct-applied.json" --previous "$TMP/direct-prepared.json" --allow-any-path
transition_receipt "$TMP/direct-applied.json" "$TMP/direct-complete.json" complete 3 null "$(printf 'b%.0s' {1..40})"
expect_ok "direct applied to complete is legal" python3 "$VALIDATOR" --receipt "$TMP/direct-complete.json" --previous "$TMP/direct-applied.json" --allow-any-path
transition_receipt "$TMP/direct-prepared.json" "$TMP/direct-skip.json" complete 2 null "$(printf 'b%.0s' {1..40})"
expect_reason "direct phase skip rejects" closeout-checkpoint-conflict python3 "$VALIDATOR" --receipt "$TMP/direct-skip.json" --previous "$TMP/direct-prepared.json" --allow-any-path
transition_receipt "$TMP/direct-prepared.json" "$TMP/direct-same-generation.json" applied 1 null "$(printf 'b%.0s' {1..40})"
expect_reason "transition requires generation plus one" closeout-checkpoint-conflict python3 "$VALIDATOR" --receipt "$TMP/direct-same-generation.json" --previous "$TMP/direct-prepared.json" --allow-any-path
transition_receipt "$TMP/direct-prepared.json" "$TMP/direct-generation-skip.json" applied 3 null "$(printf 'b%.0s' {1..40})"
expect_reason "transition rejects generation skip" closeout-checkpoint-conflict python3 "$VALIDATOR" --receipt "$TMP/direct-generation-skip.json" --previous "$TMP/direct-prepared.json" --allow-any-path
transition_receipt "$TMP/direct-prepared.json" "$TMP/mode-mutation.json" applied 2 null "$(printf 'b%.0s' {1..40})" pull_request
expect_reason "mode mutation rejects" closeout-checkpoint-conflict python3 "$VALIDATOR" --receipt "$TMP/mode-mutation.json" --previous "$TMP/direct-prepared.json" --allow-any-path
transition_receipt "$TMP/direct-prepared.json" "$TMP/intent-mutation.json" applied 2 null "$(printf 'b%.0s' {1..40})" "" squash
expect_reason "merge intent mutation rejects" closeout-checkpoint-conflict python3 "$VALIDATOR" --receipt "$TMP/intent-mutation.json" --previous "$TMP/direct-prepared.json" --allow-any-path
transition_receipt "$TMP/direct-prepared.json" "$TMP/head-mutation.json" applied 2 null "$(printf 'b%.0s' {1..40})" "" KEEP "ship-closeout/$(printf 'f%.0s' {1..64})"
expect_reason "deterministic head mutation rejects" closeout-sentinel-identity-mismatch python3 "$VALIDATOR" --receipt "$TMP/head-mutation.json" --previous "$TMP/direct-prepared.json" --allow-any-path
python3 - "$TMP/direct-applied.json" "$TMP/identity-mutation.json" <<'PY'
import hashlib,json,sys
r=json.load(open(sys.argv[1])); r["identity"]["repository"]="acme/other"
raw="\0".join(["v1",r["identity"]["provider"],r["identity"]["repository"],r["identity"]["workflow"],r["identity"]["entity_slug"],str(r["identity"]["implementation_pr"])]).encode()
r["closeout_id"]=hashlib.sha256(raw).hexdigest(); r["deterministic_closeout_head"]="ship-closeout/"+r["closeout_id"]
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}; r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
json.dump(r,open(sys.argv[2],"w"),sort_keys=True)
PY
expect_reason "identity mutation across replay rejects" closeout-checkpoint-conflict python3 "$VALIDATOR" --receipt "$TMP/identity-mutation.json" --previous "$TMP/direct-prepared.json" --allow-any-path
make_receipt "$TMP/pr-prepared.json" prepared pull_request 1
transition_receipt "$TMP/pr-prepared.json" "$TMP/pr-awaiting.json" awaiting_closeout_pr 2 88 null
expect_ok "PR prepared to awaiting is legal" python3 "$VALIDATOR" --receipt "$TMP/pr-awaiting.json" --previous "$TMP/pr-prepared.json" --allow-any-path
transition_receipt "$TMP/pr-awaiting.json" "$TMP/pr-applied.json" applied 3 88 "$(printf 'b%.0s' {1..40})"
expect_ok "PR awaiting to applied is legal" python3 "$VALIDATOR" --receipt "$TMP/pr-applied.json" --previous "$TMP/pr-awaiting.json" --allow-any-path
transition_receipt "$TMP/pr-applied.json" "$TMP/pr-changed.json" complete 4 89 "$(printf 'b%.0s' {1..40})"
expect_reason "closeout PR is immutable" closeout-checkpoint-conflict python3 "$VALIDATOR" --receipt "$TMP/pr-changed.json" --previous "$TMP/pr-applied.json" --allow-any-path
transition_receipt "$TMP/pr-applied.json" "$TMP/main-changed.json" complete 4 88 "e$(printf 'e%.0s' {1..39})"
expect_reason "main commit is immutable" closeout-checkpoint-conflict python3 "$VALIDATOR" --receipt "$TMP/main-changed.json" --previous "$TMP/pr-applied.json" --allow-any-path

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
