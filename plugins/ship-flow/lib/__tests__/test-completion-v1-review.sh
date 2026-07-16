#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; LIB="$HERE/.."; FAIL=0
ok() { echo "OK $1"; }; fail() { echo "FAIL $1"; FAIL=1; }
if [ "${1:-}" = --adversarial-grammar ]; then
  # Exercise the shipped validators from a cwd where shell globs have matches.
  # shellcheck disable=SC1091 # dynamic path; production file is linted separately
  source "$LIB/completion-v1.sh"
  GLOB_CWD="$(mktemp -d)"; mkdir -p "$GLOB_CWD/docs/wf/item" "$GLOB_CWD/docs/wf/x" "$GLOB_CWD/item"; : > "$GLOB_CWD/x"
  : > "$GLOB_CWD/docs/wf/item/index.md"; : > "$GLOB_CWD/docs/wf/x/index.md"
  rejects() {
    local validator="$1" value="$2"
    if (cd "$GLOB_CWD" && "$validator" "$value"); then fail "$validator accepted literal <$value>"
    else ok "$validator rejects literal <$value>"; fi
  }
  rejects completion_path_ok 'docs/wf/*/index.md'
  rejects completion_path_ok 'docs/wf/?/index.md'
  rejects completion_path_ok 'docs/wf/[i]tem/index.md'
  rejects completion_path_ok 'docs/wf/has space/index.md'
  rejects completion_path_ok $'docs/wf/control\tbyte/index.md'
  rejects completion_path_ok $'docs/wf/good\nevil/index.md'
  rejects completion_path_ok 'docs/wf/nonascii-é/index.md'
  rejects completion_path_ok 'docs/wf//index.md'
  rejects completion_path_ok 'docs/wf/./index.md'
  rejects completion_path_ok 'docs/wf/item.lock/index.md'
  rejects completion_path_ok 'docs/wf/item\name/index.md'
  rejects completion_path_ok 'docs/wf/item:name/index.md'
  rejects completion_ref_ok 'refs/heads/topic/*'
  rejects completion_ref_ok 'refs/heads/topic/?'
  rejects completion_ref_ok 'refs/heads/topic/[x]'
  rejects completion_ref_ok 'refs/heads/topic name'
  rejects completion_ref_ok $'refs/heads/control\tbyte'
  rejects completion_ref_ok 'refs/heads/nonascii-é'
  rejects completion_ref_ok 'refs/heads/topic//name'
  rejects completion_ref_ok 'refs/heads/topic/./name'
  rejects completion_ref_ok 'refs/heads/topic.lock'
  rejects completion_ref_ok 'refs/heads/topic\name'
  rejects completion_ref_ok 'refs/heads/topic:name'
  rejects completion_ascii $'worker-ok\n\001'
  for binding in worker token; do
    worker='worker-ok'; token='token-ok'
    if [ "$binding" = worker ]; then worker=$'worker-ok\n\001'; else token=$'token-ok\n\001'; fi
    rc=0; out="$(cd "$GLOB_CWD" && bash "$LIB/fo-completion-lease.sh" acquire --entity=docs/wf/item/index.md --stage=design --worker="$worker" --token="$token" --ref=refs/heads/main --before=0000000000000000000000000000000000000000 2>&1)" || rc=$?
    if [ "$rc" = 2 ] && [ "$out" = 'completion-v1[2]: invalid lease scalar' ]; then ok "lease rejects typed LF/control $binding"
    else fail "lease LF/control $binding rc=$rc out=$out"; fi
  done
  rm -rf "$GLOB_CWD"
  exit "$FAIL"
fi
sha() { if command -v sha256sum >/dev/null; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
setup_repo() {
  R="$(mktemp -d)"; E=docs/wf/item/index.md; A=docs/wf/item/design.md; mkdir -p "$R/docs/wf/item"
  printf '%s\n' '---' 'stages:' '  states:' '    - name: shape' '    - name: design' '    - name: plan' '---' > "$R/docs/wf/README.md"
  printf '%s\n' '---' 'status: design' 'stage_outputs:' '  shape: shape.md' '---' '<!-- section:stage-artifact-links -->' '| Stage | File |' '|-------|------|' '| shape | [shape.md](shape.md) |' '<!-- /section:stage-artifact-links -->' > "$R/$E"
  printf '# Shape\n' > "$R/docs/wf/item/shape.md"; printf '# Design\n' > "$R/$A"
  (cd "$R" && git init -q -b main && git config user.email test@test && git config user.name test && git add docs && git commit -qm init)
  B="$(cd "$R" && git rev-parse HEAD)"; T="$(cd "$R" && git rev-parse 'HEAD^{tree}')"; TOKEN=lease-review; WORKER=ensign-review
}
lease() { (cd "$R" && bash "$LIB/fo-completion-lease.sh" "$1" --entity="$E" --stage=design --worker="$WORKER" --token="$TOKEN" --ref=refs/heads/main --before="$B"); }
acquire() { lease acquire >/dev/null || return; L="$(cd "$R" && git rev-parse --absolute-git-dir)/completion-v1.lease/record"; }
advance() { (cd "$R" && bash "$LIB/advance-stage.sh" --entity="$E" --new-status=design --stage-name=design --stage-file=design.md --if-hash="$(sha "$R/$E")" --commit-as=x --lease-file="$L" --lease-token="$TOKEN" --worker-id="$WORKER"); }
handle() { (cd "$R" && bash "$LIB/fo-reconcile-completion.sh" --disposition="$1" --entity="$E" --new-status=design --stage-name=design --stage-file=design.md --ref=refs/heads/main --before="$B" --completion="$C" --before-tree="$T" --lease-file="$L" --lease-token="$TOKEN" --worker-id="$WORKER"); }
publish_reclaim() { acquire && OUT="$(advance)" && C="$(cd "$R" && git rev-parse refs/heads/main)" && lease reclaim >/dev/null || return; L="$(cd "$R" && git rev-parse --absolute-git-dir)/completion-v1.lease/returned"; }
fingerprint() { (cd "$R" && { git write-tree; git hash-object "$E"; git rev-parse refs/heads/main; }); }
if [ "${1:-}" = --registry-grammar ]; then
  for table_case in missing-header missing-separator reversed duplicate-header duplicate-separator; do
    setup_repo
    case "$table_case" in
      missing-header) perl -0pi -e 's/^\| Stage \| File \|\n//m' "$R/$E" ;; missing-separator) perl -0pi -e 's/^\|-------\|------\|\n//m' "$R/$E" ;;
      reversed) perl -0pi -e 's/^\| Stage \| File \|\n\|-------\|------\|$/|-------|------|\n| Stage | File |/m' "$R/$E" ;;
      duplicate-header) perl -0pi -e 's/^\| Stage \| File \|$/| Stage | File |\n| Stage | File |/m' "$R/$E" ;; duplicate-separator) perl -0pi -e 's/^\|-------\|------\|$/|-------|------|\n|-------|------|/m' "$R/$E" ;;
    esac
    (cd "$R" && git add "$E" && git commit -qm "fixture: $table_case"); B="$(cd "$R" && git rev-parse HEAD)"; T="$(cd "$R" && git rev-parse 'HEAD^{tree}')"; acquire; S="$(fingerprint)"
    OUT="$(advance 2>/dev/null)"; RC=$?
    if [ "$RC" = 0 ] && printf '%s\n' "$OUT" | grep -q 'disposition=published' && [ -f "$L" ]; then ok "historical body registry $table_case is opaque to publication"
    else fail "historical registry $table_case rc=$RC out=$OUT lease=$([ -f "$L" ] && echo yes || echo no)"; fi
    rm -rf "$R"
  done
  exit "$FAIL"
fi
if [ "${1:-}" = --document-regions ]; then
  # shellcheck disable=SC1091 # production parser/renderer contract under test
  source "$LIB/completion-v1.sh"
  D="$(mktemp -d)"; SOURCE="$D/source.md"; EXPECTED="$D/expected.md"; ACTUAL="$D/actual.md"
  cat > "$SOURCE" <<'EOF'
---
status: design
stage_outputs:
  shape: shape.md
---
# Unowned prose before
stage_outputs:
body prose before
| Stage | File |
|-------|------|
| decoy | [outside.md](outside.md) |
> <!-- section:stage-artifact-links -->
<!-- section:stage-artifact-links-decoy -->
<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
<!-- /section:stage-artifact-links-decoy -->
> <!-- /section:stage-artifact-links -->
# Unowned prose after
stage_outputs:
body prose after
| Stage | File |
|-------|------|
| decoy | [outside-again.md](outside-again.md) |
EOF
  cat > "$EXPECTED" <<'EOF'
---
status: design
stage_outputs:
  shape: shape.md
  design: design.md
---
# Unowned prose before
stage_outputs:
body prose before
| Stage | File |
|-------|------|
| decoy | [outside.md](outside.md) |
> <!-- section:stage-artifact-links -->
<!-- section:stage-artifact-links-decoy -->
<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
<!-- /section:stage-artifact-links-decoy -->
> <!-- /section:stage-artifact-links -->
# Unowned prose after
stage_outputs:
body prose after
| Stage | File |
|-------|------|
| decoy | [outside-again.md](outside-again.md) |
EOF
  if [ "$(completion_parse_entity "$SOURCE" design design design.md)" = ABSENT ]; then ok "scanner corpus parses owned regions only before render"
  else fail "scanner source corpus rejected"; fi
  if [ "$(completion_parse_entity "$EXPECTED" design design design.md)" = PRESENT ]; then ok "scanner corpus parses owned regions only after render"
  else fail "scanner expected corpus rejected"; fi
  completion_render "$SOURCE" design design.md "$ACTUAL"
  if cmp -s "$EXPECTED" "$ACTUAL"; then ok "renderer preserves every unowned byte span"; else fail "renderer changed unowned document regions"; diff -u "$EXPECTED" "$ACTUAL" || true; fi
  rm -rf "$D"
  for ambiguity in duplicate-map duplicate-open duplicate-close; do
    setup_repo
    case "$ambiguity" in duplicate-map) perl -0pi -e 's/^stage_outputs:$/stage_outputs:\nstage_outputs:/m' "$R/$E" ;; duplicate-open) perl -0pi -e 's/^<!-- section:stage-artifact-links -->$/<!-- section:stage-artifact-links -->\n<!-- section:stage-artifact-links -->/m' "$R/$E" ;; duplicate-close) perl -0pi -e 's/^<!-- \/section:stage-artifact-links -->$/<!-- \/section:stage-artifact-links -->\n<!-- \/section:stage-artifact-links -->/m' "$R/$E" ;; esac
    (cd "$R" && git add "$E" && git commit -qm "fixture: $ambiguity"); B="$(cd "$R" && git rev-parse HEAD)"; T="$(cd "$R" && git rev-parse 'HEAD^{tree}')"; acquire; S="$(fingerprint)"; OUT="$(advance 2>/dev/null)"; RC=$?
    if [ "$ambiguity" = duplicate-map ]; then
      if [ "$RC" != 0 ] && [ -z "$OUT" ] && [ "$(fingerprint)" = "$S" ] && [ -f "$L" ]; then ok "authority ambiguity $ambiguity fails closed"
      else fail "authority ambiguity $ambiguity rc=$RC out=$OUT lease=$([ -f "$L" ] && echo yes || echo no)"; fi
    elif [ "$RC" = 0 ] && printf '%s\n' "$OUT" | grep -q 'disposition=published' && [ -f "$L" ]; then
      ok "body ambiguity $ambiguity remains opaque"
    else
      fail "body ambiguity $ambiguity rc=$RC out=$OUT lease=$([ -f "$L" ] && echo yes || echo no)"
    fi
    rm -rf "$R"
  done
  exit "$FAIL"
fi
setup_repo; acquire; printf 'preserve\n' > "$R/unrelated"
S="$(fingerprint)"; OUT="$(advance 2>/dev/null)"; RC=$?
if [ "$RC" != 0 ] && [ -z "$OUT" ] && [ "$(fingerprint)" = "$S" ] && [ -f "$L" ] && [ -f "$R/unrelated" ]; then ok "RED-2 global clean checkpoint"; else fail "RED-2 unrelated dirt published rc=$RC out=$OUT"; fi; rm -rf "$R"
CALLS="$(grep -c 'completion_emit_receipt ' "$LIB/advance-stage.sh" || true)"; DEFS="$(grep -c '^completion_emit_receipt()' "$LIB/completion-v1.sh" || true)"
if [ "$CALLS" = 2 ] && [ "$DEFS" = 1 ]; then ok "RED-3 shared receipt validator/emitter"; else fail "RED-3 calls=$CALLS defs=$DEFS"; fi
setup_repo
perl -0pi -e 's/  shape: shape.md/  shape: shape.md\n  design: design.md/; s#<!-- /section:stage-artifact-links -->#| design | [design.md](design.md) |\n<!-- /section:stage-artifact-links -->#' "$R/$E"
(cd "$R" && git add "$E" && git commit -qm registered); B="$(cd "$R" && git rev-parse HEAD)"; T="$(cd "$R" && git rev-parse 'HEAD^{tree}')"
acquire; OUT="$(advance)"; C="$B"; lease reclaim >/dev/null; L="$(cd "$R" && git rev-parse --absolute-git-dir)/completion-v1.lease/returned"
HANDLED="$(handle already-registered 2>/dev/null)"; RC=$?
if [ "$RC" = 0 ] && printf '%s\n' "$OUT" | grep -q 'disposition=already-registered' && printf '%s\n' "$HANDLED" | grep -q 'disposition=ready' && [ ! -e "$L" ]; then ok "RED-4 already no-lag handling"; else fail "RED-4 already handler rc=$RC completion=$OUT handled=$HANDLED"; fi; rm -rf "$R"
for fault in status ref object; do
  setup_repo; publish_reclaim || { fail "RED-5 setup $fault"; rm -rf "$R"; continue; }
  S="$(fingerprint)"; W="$(mktemp -d)"; REAL_GIT="$(command -v git)"
  printf '%s\n' '#!/usr/bin/env bash' "if [ '$fault' = status ] && [ \"\${1:-}\" = status ]; then exit 99; fi" "if [ '$fault' = ref ] && [ \"\${1:-}\" = rev-parse ] && [ \"\${2:-}\" = refs/heads/main ]; then echo '$C'; exit 99; fi" "if [ '$fault' = object ] && [ \"\${1:-}\" = rev-parse ] && [ \"\${2:-}\" = '$C^' ]; then echo '$B'; exit 99; fi" "exec '$REAL_GIT' \"\$@\"" > "$W/git"
  chmod +x "$W/git"
  HANDLED="$(PATH="$W:$PATH" handle published 2>/dev/null)"; RC=$?
  if [ "$RC" != 0 ] && [ -z "$HANDLED" ] && [ -f "$L" ] && [ "$(fingerprint)" = "$S" ]; then ok "RED-5 $fault observation fails closed"
  else fail "RED-5 $fault rc=$RC out=$HANDLED lease=$([ -f "$L" ] && echo yes || echo no)"; fi
  rm -rf "$R" "$W"
done
exit "$FAIL"
