#!/usr/bin/env bash
# test-closeout-receipt.sh — D2-D4 receipt identity, hashing, and phase contract
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)"
VALIDATOR="${PLUGIN_ROOT}/lib/validate-closeout-receipt.py"
SCHEMA="${PLUGIN_ROOT}/references/closeout-receipt-schema.yaml"
LANDING_RESOLVER="${PLUGIN_ROOT}/lib/resolve-landing-envelope.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/closeout-receipt"
# shellcheck source=/dev/null
source "${FIXTURE_ROOT}/golden.env"
D1_GOLDEN_PROOF_HASH=8aeced60b772068932f4556823b777cf8b008370f5162a9725bf7a686999dcaf
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
 "landing_proof":{"schema_version":1,"repository":"acme/widgets","base_ref":"main","implementation_pr":40,
  "provider_merged_at":"2026-07-15T00:00:00Z","landing_anchor":"b"*40,"base_before":"c"*40,
  "strategy":"squash","strategy_evidence":"topology+ordered-patch-ids+aggregate-patch-digest",
  "pr_commit_count":2,"source_commit_patch_ids":["1"*40,"2"*40],"source_patch_digest":"d"*64,
  "landing_commits":["b"*40],"landing_commit_patch_ids":["3"*40],"landing_patch_digest":"d"*64,
  "first_landing_commit":"b"*40,"last_landing_commit":"b"*40,"method_source":"topology"},
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

make_real_git_receipt() {
  local repo="$1" saved_receipt="$2" metadata="$3"
  git init -q -b main "$repo"
  git -C "$repo" config user.email receipt@example.test
  git -C "$repo" config user.name 'Receipt Proof Fixture'
  printf '%s\n' 'base' >"$repo/proof.txt"
  git -C "$repo" add proof.txt
  git -C "$repo" commit -qm 'fixture: base'
  local base first anchor side envelope canonical
  base="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' 'base' 'first' >"$repo/proof.txt"
  git -C "$repo" commit -qam 'fixture: first landing patch'
  first="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' 'base' 'first' 'second' >"$repo/proof.txt"
  git -C "$repo" commit -qam 'fixture: second landing patch'
  anchor="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -qb forged-side "$base"
  printf '%s\n' 'base' 'forged-side' >"$repo/side.txt"
  git -C "$repo" add side.txt
  git -C "$repo" commit -qm 'fixture: unreachable side anchor'
  side="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -q main
  envelope="$TMP/real-landing.env"
  "$LANDING_RESOLVER" --repo-dir "$repo" --repository acme/widgets --base-ref main \
    --implementation-pr 40 --provider-merged-at 2026-07-15T00:00:00Z \
    --landing-anchor "$anchor" --source-commits "$first,$anchor" --pr-commit-count 2 \
    --merge-method-intent rebase >"$envelope"
  canonical="$(python3 - "$repo" "$envelope" "$saved_receipt" "$metadata" "$base" "$first" "$anchor" "$side" <<'PY'
import hashlib,json,pathlib,sys
repo,envelope,saved,metadata,base,first,anchor,side=sys.argv[1:]
env={}
for line in pathlib.Path(envelope).read_text().splitlines():
    key,value=line.split("=",1); env[key]=value
arrays={"source_commit_patch_ids","landing_commits","landing_commit_patch_ids"}
ints={"schema_version","implementation_pr","pr_commit_count"}
landing={key:(value.split(",") if key in arrays else int(value) if key in ints else value) for key,value in env.items()}
identity={"provider":"github","repository":"acme/widgets","workflow":"docs/ship-flow","entity_slug":"widget-closeout","implementation_pr":40}
cid=hashlib.sha256("\0".join(("v1","github","acme/widgets","docs/ship-flow","widget-closeout","40")).encode()).hexdigest(); h="a"*64
receipt={"schema_version":1,"kind":"ship-flow.closeout","closeout_id":cid,"identity":identity,
 "ownership_proof":{"unique_entity_matches":1,"participant_entities":[],"source_hashes":{"index":h,"review":h,"ship":h}},
 "mode":"direct","merge_method_intent":"rebase","deterministic_closeout_head":"ship-closeout/"+cid,
 "landing_proof":landing,"transaction":{"phase":"prepared","generation":1,"closeout_pr":None,"main_commit":None},
 "outputs":{"debrief":{"path":"docs/ship-flow/_debriefs/2026-07-15-01.md","sha256":h},
 "ship":{"path":"docs/ship-flow/_archive/widget-closeout/ship.md","sha256":h},
 "archived_entity":{"path":"docs/ship-flow/_archive/widget-closeout/index.md","sha256":h},
 "roadmap_row":{"identity":"widget-closeout","sha256":h}}}
payload={key:receipt[key] for key in ("identity","ownership_proof","landing_proof","outputs")}
receipt["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
canonical=pathlib.Path(repo)/"docs/ship-flow/_closeouts"/(cid+".json"); canonical.parent.mkdir(parents=True)
text=json.dumps(receipt,sort_keys=True,indent=2)+"\n"; canonical.write_text(text); pathlib.Path(saved).write_text(text)
pathlib.Path(metadata).write_text(json.dumps({"base":base,"first":first,"anchor":anchor,"side":side})+"\n")
print(canonical)
PY
)"
  printf '%s\n' "$canonical"
}

forge_real_git_receipt() {
  local source="$1" target="$2" metadata="$3" mutation="$4"
  python3 - "$source" "$target" "$metadata" "$mutation" <<'PY'
import hashlib,json,sys
source,target,metadata,mutation=sys.argv[1:]
r=json.load(open(source)); m=json.load(open(metadata)); landing=r["landing_proof"]
if mutation=="unreachable_anchor":
    landing["landing_anchor"]=m["side"]; landing["landing_commits"]=[m["first"],m["side"]]
    landing["last_landing_commit"]=m["side"]
elif mutation=="forged_base_before": landing["base_before"]=m["first"]
elif mutation=="forged_landing_set":
    landing["landing_commits"]=[m["base"],m["anchor"]]; landing["first_landing_commit"]=m["base"]
elif mutation=="forged_topology":
    landing["strategy"]="merge_commit"; landing["landing_commits"]=[m["base"],m["first"],m["anchor"]]
    landing["first_landing_commit"]=m["base"]
else: raise SystemExit("unknown real-git mutation")
payload={key:r[key] for key in ("identity","ownership_proof","landing_proof","outputs")}
r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
with open(target,"w") as handle: json.dump(r,handle,sort_keys=True,indent=2); handle.write("\n")
PY
}

mutate_and_rehash() {
  local source="$1" target="$2" mutation="$3"
  python3 - "$source" "$target" "$mutation" <<'PY'
import hashlib,json,sys
source,target,mutation=sys.argv[1:]
r=json.load(open(source)); landing=r["landing_proof"]; outputs=r["outputs"]
if mutation=="incomplete_landing": r["landing_proof"]={"landing_anchor":"b"*40,"strategy":"squash"}
elif mutation=="landing_schema": landing["schema_version"]=True
elif mutation=="landing_repository": landing["repository"]="acme/other"
elif mutation=="landing_base_ref": landing["base_ref"]=""
elif mutation=="landing_pr": landing["implementation_pr"]=41
elif mutation=="landing_merged_at": landing["provider_merged_at"]="not-rfc3339"
elif mutation=="landing_anchor": landing["landing_anchor"]="b"*39
elif mutation=="landing_base_before": landing["base_before"]="c"*39
elif mutation=="landing_strategy": landing["strategy"]="octopus"
elif mutation=="landing_evidence": landing["strategy_evidence"]="provider-claim"
elif mutation=="landing_count": landing["pr_commit_count"]=0
elif mutation=="source_patch_ids": landing["source_commit_patch_ids"]=["not-a-patch-id"]
elif mutation=="source_patch_digest": landing["source_patch_digest"]="d"*63
elif mutation=="duplicate_landing_commits":
    landing.update({"strategy":"rebase","landing_commits":["b"*40,"b"*40],
                    "landing_commit_patch_ids":["3"*40,"4"*40],
                    "first_landing_commit":"b"*40,"last_landing_commit":"b"*40})
elif mutation=="landing_patch_ids": landing["landing_commit_patch_ids"]=["not-a-patch-id"]
elif mutation=="landing_patch_digest": landing["landing_patch_digest"]="e"*63
elif mutation=="unequal_patch_digests": landing["landing_patch_digest"]="e"*64
elif mutation=="rebase_ordered_patch_mismatch":
    landing.update({"strategy":"rebase","landing_commits":["a"*40,"b"*40],
                    "landing_commit_patch_ids":["2"*40,"1"*40],
                    "first_landing_commit":"a"*40,"last_landing_commit":"b"*40})
elif mutation=="merge_ordered_patch_mismatch":
    landing.update({"strategy":"merge_commit","landing_commits":["a"*40,"c"*40,"b"*40],
                    "landing_commit_patch_ids":["2"*40,"1"*40],
                    "first_landing_commit":"a"*40,"last_landing_commit":"b"*40})
elif mutation=="first_landing": landing["first_landing_commit"]="f"*40
elif mutation=="last_anchor": landing["last_landing_commit"]="f"*40
elif mutation=="debrief_path": outputs["debrief"]["path"]="docs/ship-flow/arbitrary.md"
elif mutation=="ship_path": outputs["ship"]["path"]="docs/ship-flow/_archive/widget-closeout/final.md"
elif mutation=="archive_path": outputs["archived_entity"]["path"]="docs/ship-flow/_archive/other/index.md"
elif mutation=="duplicate_paths": outputs["debrief"]["path"]=outputs["ship"]["path"]
elif mutation=="roadmap_identity": outputs["roadmap_row"]["identity"]="other-entity"
else: raise SystemExit("unknown mutation")
payload={key:r[key] for key in ("identity","ownership_proof","landing_proof","outputs")}
r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
with open(target,"w") as handle: json.dump(r,handle,sort_keys=True,indent=2); handle.write("\n")
PY
}

echo "=== closeout receipt contract ==="
if test -f "$SCHEMA"; then ok "receipt schema exists"; else bad "receipt schema exists"; fi
if grep -q 'min_properties' "$SCHEMA"; then bad "receipt schema removes placeholder landing proof"; else ok "receipt schema removes placeholder landing proof"; fi
if python3 - "$SCHEMA" <<'PY'
import pathlib,sys
text=pathlib.Path(sys.argv[1]).read_text()
fields=("provider_merged_at","landing_anchor","base_before","strategy_evidence","pr_commit_count",
        "source_commit_patch_ids","source_patch_digest","landing_commits","landing_commit_patch_ids",
        "landing_patch_digest","first_landing_commit","last_landing_commit","method_source")
raise SystemExit(0 if all(f"    {field}:" in text for field in fields) else 1)
PY
then ok "receipt schema declares exact D1 landing fields"; else bad "receipt schema declares exact D1 landing fields"; fi
if grep -q 'source_patch_digest equals landing_patch_digest' "$SCHEMA" && grep -q 'ordered source and landing patch IDs are equal' "$SCHEMA"; then ok "receipt schema binds aggregate and ordered patch proof"; else bad "receipt schema binds aggregate and ordered patch proof"; fi
if grep -q 'normal validation re-derives topology, ordered commits, patch IDs, and aggregate digest from Git' "$SCHEMA" && grep -q 'roadmap_row.identity equals identity.entity_slug' "$SCHEMA"; then ok "receipt schema binds Git proof and canonical output identity"; else bad "receipt schema binds Git proof and canonical output identity"; fi
make_receipt "$TMP/receipt.json"
CID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["closeout_id"])' "$TMP/receipt.json")"
mkdir -p "$TMP/docs/ship-flow/_closeouts"; cp "$TMP/receipt.json" "$TMP/docs/ship-flow/_closeouts/$CID.json"
CANONICAL="$TMP/docs/ship-flow/_closeouts/$CID.json"
expect_ok "golden structural receipt validates" python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path
expect_ok "golden NUL identity vector is stable" grep -q "^closeout_id=${GOLDEN_CLOSEOUT_ID}$" <(python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path)
expect_ok "golden canonical payload hash is stable" grep -q "^proof_hash=${D1_GOLDEN_PROOF_HASH}$" <(python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path)

for case in \
  incomplete_landing landing_schema landing_repository landing_base_ref landing_pr landing_merged_at \
  landing_anchor landing_base_before landing_strategy landing_evidence landing_count source_patch_ids \
  source_patch_digest duplicate_landing_commits landing_patch_ids landing_patch_digest first_landing last_anchor \
  unequal_patch_digests rebase_ordered_patch_mismatch merge_ordered_patch_mismatch \
  debrief_path ship_path archive_path duplicate_paths roadmap_identity
do
  mutate_and_rehash "$TMP/receipt.json" "$TMP/invalid-${case}.json" "$case"
  expect_reason "self-rehashed ${case} receipt rejects" closeout-sentinel-invalid \
    python3 "$VALIDATOR" --receipt "$TMP/invalid-${case}.json" --allow-any-path
done

REAL_REPO="$TMP/real-proof-repo"
REAL_SAVED="$TMP/real-proof-valid.json"
REAL_METADATA="$TMP/real-proof-metadata.json"
REAL_RECEIPT="$(make_real_git_receipt "$REAL_REPO" "$REAL_SAVED" "$REAL_METADATA")"
expect_ok "real Git landing proof validates" python3 "$VALIDATOR" --receipt "$REAL_RECEIPT" --repo-root "$REAL_REPO"
for case in unreachable_anchor forged_base_before forged_landing_set forged_topology; do
  forge_real_git_receipt "$REAL_SAVED" "$REAL_RECEIPT" "$REAL_METADATA" "$case"
  expect_reason "real Git ${case} proof rejects" closeout-sentinel-invalid \
    python3 "$VALIDATOR" --receipt "$REAL_RECEIPT" --repo-root "$REAL_REPO"
done
cp "$REAL_SAVED" "$REAL_RECEIPT"

ARCHIVE_ROOT="$TMP/exported-tree"
ARCHIVE_RECEIPT="$ARCHIVE_ROOT/docs/ship-flow/_closeouts/$(basename "$REAL_RECEIPT")"
mkdir -p \
  "$ARCHIVE_ROOT/docs/ship-flow/_closeouts" \
  "$ARCHIVE_ROOT/docs/ship-flow/_debriefs" \
  "$ARCHIVE_ROOT/docs/ship-flow/_archive/widget-closeout"
cp "$REAL_SAVED" "$ARCHIVE_RECEIPT"
printf '%s\n' '# Exported debrief' >"$ARCHIVE_ROOT/docs/ship-flow/_debriefs/2026-07-15-01.md"
printf '%s\n' '# Exported ship' >"$ARCHIVE_ROOT/docs/ship-flow/_archive/widget-closeout/ship.md"
printf '%s\n' '# Exported entity' >"$ARCHIVE_ROOT/docs/ship-flow/_archive/widget-closeout/index.md"
printf '%s\n' \
  '# Roadmap' \
  '<!-- section:shipped -->' \
  '| Entity | Title | Shipped |' \
  '| --- | --- | --- |' \
  '| widget-closeout | Widget closeout | 2026-07-15 |' \
  '<!-- /section:shipped -->' >"$ARCHIVE_ROOT/ROADMAP.md"
python3 - "$ARCHIVE_RECEIPT" "$ARCHIVE_ROOT" <<'PY'
import hashlib,json,pathlib,sys
receipt=pathlib.Path(sys.argv[1]); root=pathlib.Path(sys.argv[2]); r=json.loads(receipt.read_text())
for key in ("debrief","ship","archived_entity"):
    r["outputs"][key]["sha256"]=hashlib.sha256((root/r["outputs"][key]["path"]).read_bytes()).hexdigest()
row="| widget-closeout | Widget closeout | 2026-07-15 |"
r["outputs"]["roadmap_row"]["sha256"]=hashlib.sha256(row.encode()).hexdigest()
payload={key:r[key] for key in ("identity","ownership_proof","landing_proof","outputs")}
r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
receipt.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
expect_ok "exported tree bytes validate against actual-repo landing proof" \
  python3 "$VALIDATOR" --receipt "$ARCHIVE_RECEIPT" --repo-root "$ARCHIVE_ROOT" \
    --landing-proof-repo-root "$REAL_REPO" --verify-outputs
printf '%s\n' 'tampered archive bytes' >>"$ARCHIVE_ROOT/docs/ship-flow/_archive/widget-closeout/ship.md"
expect_reason "separate proof root does not weaken exported output validation" closeout-sentinel-payload-mismatch \
  python3 "$VALIDATOR" --receipt "$ARCHIVE_RECEIPT" --repo-root "$ARCHIVE_ROOT" \
    --landing-proof-repo-root "$REAL_REPO" --verify-outputs
expect_reason "landing proof root must be a real Git repository" closeout-sentinel-invalid \
  python3 "$VALIDATOR" --receipt "$ARCHIVE_RECEIPT" --repo-root "$ARCHIVE_ROOT" \
    --landing-proof-repo-root "$ARCHIVE_ROOT"

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
expect_ok "exact landed output bytes validate" python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-outputs
SPACED_ROW='| widget-closeout | Widget closeout | 2026-07-15 |'
COMPACT_ROW='|widget-closeout|Widget closeout|2026-07-15|'
SPACED_HASH="$(printf '%s' "$SPACED_ROW" | shasum -a 256 | awk '{print $1}')"
COMPACT_HASH="$(printf '%s' "$COMPACT_ROW" | shasum -a 256 | awk '{print $1}')"
if [ "$SPACED_HASH" != "$COMPACT_HASH" ]; then ok "ROADMAP raw row hash excludes newline and distinguishes spacing"; else bad "ROADMAP raw row hash excludes newline and distinguishes spacing"; fi
printf '%s\n' '# Roadmap' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' "$COMPACT_ROW" '<!-- /section:shipped -->' >"$TMP/ROADMAP.md"
expect_reason "normalized cells cannot hide compact landed-byte drift" closeout-sentinel-payload-mismatch python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-outputs
printf '%s\n' '# Roadmap' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' "$SPACED_ROW" '<!-- /section:shipped -->' >"$TMP/ROADMAP.md"
mv "$TMP/docs/ship-flow/_archive/widget-closeout/ship.md" "$TMP/docs/ship-flow/_archive/widget-closeout/internal-target.md"
ln -s "$TMP/docs/ship-flow/_archive/widget-closeout/internal-target.md" "$TMP/docs/ship-flow/_archive/widget-closeout/ship.md"
expect_reason "landed output internal symlink rejects" closeout-sentinel-invalid python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-outputs
rm "$TMP/docs/ship-flow/_archive/widget-closeout/ship.md"; mv "$TMP/docs/ship-flow/_archive/widget-closeout/internal-target.md" "$TMP/docs/ship-flow/_archive/widget-closeout/ship.md"
expect_ok "exact preparation source bytes validate" python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-sources
echo "tampered source" >>"$TMP/docs/ship-flow/widget-closeout/review.md"
expect_reason "tampered preparation source rejects" closeout-projection-source-drift python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-sources
rm "$TMP/docs/ship-flow/widget-closeout/review.md"
expect_reason "missing preparation source rejects" closeout-stage-artifacts-incoherent python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-sources
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
expect_reason "tampered landed output rejects" closeout-sentinel-payload-mismatch python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-outputs
rm "$TMP/docs/ship-flow/_archive/widget-closeout/ship.md"
expect_reason "missing landed output rejects" closeout-stage-artifacts-incoherent python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-outputs
python3 - "$CANONICAL" <<'PY'
import hashlib,json,sys
p=sys.argv[1]; r=json.load(open(p)); r["outputs"]["debrief"]["path"]="../escape.md"
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}
r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
json.dump(r,open(p,"w"),sort_keys=True)
PY
expect_reason "output path traversal rejects" closeout-sentinel-invalid python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-outputs

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
expect_reason "ROADMAP prose mention is not a shipped row" closeout-stage-artifacts-incoherent python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-outputs
printf '%s\n' '# Roadmap' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' '| widget-closeout-child | Child | today |' '<!-- /section:shipped -->' >"$TMP/ROADMAP.md"
python3 - "$CANONICAL" '| widget-closeout-child | Child | today |' <<'PY'
import hashlib,json,sys
p,line=sys.argv[1:]; r=json.load(open(p)); r["outputs"]["roadmap_row"]["sha256"]=hashlib.sha256(line.encode()).hexdigest()
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}; r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest(); json.dump(r,open(p,"w"),sort_keys=True)
PY
expect_reason "ROADMAP substring cell is not exact identity" closeout-stage-artifacts-incoherent python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-outputs
printf '%s\n' '# Roadmap' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' '| widget-closeout | One | today |' '| widget-closeout | Two | today |' '<!-- /section:shipped -->' >"$TMP/ROADMAP.md"
expect_reason "duplicate exact Shipped rows reject" closeout-stage-artifacts-incoherent python3 "$VALIDATOR" --receipt "$CANONICAL" --repo-root "$TMP" --allow-any-path --verify-outputs

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
r=json.load(open(sys.argv[1])); r["identity"]["repository"]="acme/other"; r["landing_proof"]["repository"]="acme/other"
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
