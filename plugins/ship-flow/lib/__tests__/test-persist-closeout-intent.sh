#!/usr/bin/env bash
# test-persist-closeout-intent.sh — sole pre-merge owner/intent CAS producer
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/lib/persist-closeout-intent.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }; bad(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
hash(){ shasum -a 256 "$1" | awk '{print $1}'; }
entity(){ local p="$1" slug="$2" owner="${3:-}" title="${4:-x}" pr="${5:-#40}"; mkdir -p "$(dirname "$p")"; printf '%s\n' '---' "title: $title" 'status: ship' "slug: $slug" "pr: \"$pr\"" ${owner:+"closeout_owner: $owner"} '---' '' '## Body' >"$p"; }
entity_without_slug(){ local p="$1" owner="${2:-}" title="${3:-x}" pr="${4:-#40}"; mkdir -p "$(dirname "$p")"; printf '%s\n' '---' "title: $title" 'status: ship' "pr: \"$pr\"" ${owner:+"closeout_owner: $owner"} '---' '' '## Body' >"$p"; }
entity_with_empty_slug(){ local p="$1" owner="${2:-}" title="${3:-x}" pr="${4:-#40}"; mkdir -p "$(dirname "$p")"; printf '%s\n' '---' "title: $title" 'status: ship' 'slug: ""' "pr: \"$pr\"" ${owner:+"closeout_owner: $owner"} '---' '' '## Body' >"$p"; }
ship(){ printf '%s\n' '## Summary' '' '### Verdict' 'status: PASSED' >"$1"; }
run(){ set +e; bash "$HELPER" "$@" >"$TMP/out" 2>&1; RC=$?; set -e; }
reason(){ if grep -q "^reason=$2$" "$TMP/out" && [ "$RC" -ne 0 ]; then ok "$1"; else bad "$1"; cat "$TMP/out"; fi; }

echo "=== persist closeout intent contract ==="
entity "$TMP/active/index.md" one; cp "$TMP/active/index.md" "$TMP/main.md"; ship "$TMP/ship.md"
run --entity "$TMP/active/index.md" --if-hash "$(hash "$TMP/active/index.md")" --mirror-entity "$TMP/main.md" --mirror-if-hash "$(hash "$TMP/main.md")" --ship "$TMP/ship.md" --ship-if-hash "$(hash "$TMP/ship.md")" --merge-method-intent squash
if [ "$RC" -eq 0 ] && grep -q '^closeout_owner: true$' "$TMP/active/index.md" && grep -q '^closeout_owner: true$' "$TMP/main.md" && grep -q '^merge_method_intent: squash$' "$TMP/ship.md"; then ok "unique match owns implicitly and mirrors optional intent"; else bad "unique match owns implicitly and mirrors optional intent"; cat "$TMP/out"; fi

entity_without_slug "$TMP/fallback/active/path-identity/index.md"; entity_without_slug "$TMP/fallback/mirror/path-identity/index.md"
run --entity "$TMP/fallback/active/path-identity/index.md" --if-hash "$(hash "$TMP/fallback/active/path-identity/index.md")" --mirror-entity "$TMP/fallback/mirror/path-identity/index.md" --mirror-if-hash "$(hash "$TMP/fallback/mirror/path-identity/index.md")"
if [ "$RC" -eq 0 ] && grep -q '^closeout_owner: true$' "$TMP/fallback/active/path-identity/index.md" && grep -q '^closeout_owner: true$' "$TMP/fallback/mirror/path-identity/index.md"; then ok "missing slug falls back to matching entity directory identity"; else bad "missing slug falls back to matching entity directory identity"; cat "$TMP/out"; fi

entity_without_slug "$TMP/fallback/mirror/other-identity/index.md"
FB_ACTIVE_BEFORE="$(hash "$TMP/fallback/active/path-identity/index.md")"; FB_MISMATCH_BEFORE="$(hash "$TMP/fallback/mirror/other-identity/index.md")"
run --entity "$TMP/fallback/active/path-identity/index.md" --if-hash "$FB_ACTIVE_BEFORE" --mirror-entity "$TMP/fallback/mirror/other-identity/index.md" --mirror-if-hash "$FB_MISMATCH_BEFORE" --closeout-owner true
reason "derived mirror slug mismatch stops" closeout-checkpoint-conflict
if [ "$FB_ACTIVE_BEFORE" = "$(hash "$TMP/fallback/active/path-identity/index.md")" ] && [ "$FB_MISMATCH_BEFORE" = "$(hash "$TMP/fallback/mirror/other-identity/index.md")" ]; then ok "derived slug mismatch leaves active and mirror byte-stable"; else bad "derived slug mismatch leaves active and mirror byte-stable"; fi

entity "$TMP/explicit/active-name/index.md" shared-identity; entity "$TMP/explicit/mirror-name/index.md" shared-identity
run --entity "$TMP/explicit/active-name/index.md" --if-hash "$(hash "$TMP/explicit/active-name/index.md")" --mirror-entity "$TMP/explicit/mirror-name/index.md" --mirror-if-hash "$(hash "$TMP/explicit/mirror-name/index.md")"
if [ "$RC" -eq 0 ]; then ok "explicit matching slug wins over different directory names"; else bad "explicit matching slug wins over different directory names"; cat "$TMP/out"; fi

entity_with_empty_slug "$TMP/explicit-empty/primary/index.md"
EMPTY_PRIMARY_BEFORE="$(hash "$TMP/explicit-empty/primary/index.md")"
run --entity "$TMP/explicit-empty/primary/index.md" --if-hash "$EMPTY_PRIMARY_BEFORE" --closeout-owner true
reason "explicit empty primary slug is malformed" malformed-frontmatter
if [ "$EMPTY_PRIMARY_BEFORE" = "$(hash "$TMP/explicit-empty/primary/index.md")" ]; then ok "explicit empty primary slug rejection is byte-stable"; else bad "explicit empty primary slug rejection is byte-stable"; fi

entity_without_slug "$TMP/explicit-empty/active/shared/index.md"; entity_with_empty_slug "$TMP/explicit-empty/mirror/shared/index.md"
EMPTY_ACTIVE_BEFORE="$(hash "$TMP/explicit-empty/active/shared/index.md")"; EMPTY_MIRROR_BEFORE="$(hash "$TMP/explicit-empty/mirror/shared/index.md")"
run --entity "$TMP/explicit-empty/active/shared/index.md" --if-hash "$EMPTY_ACTIVE_BEFORE" --mirror-entity "$TMP/explicit-empty/mirror/shared/index.md" --mirror-if-hash "$EMPTY_MIRROR_BEFORE" --closeout-owner true
reason "explicit empty mirror slug is malformed" malformed-frontmatter
if [ "$EMPTY_ACTIVE_BEFORE" = "$(hash "$TMP/explicit-empty/active/shared/index.md")" ] && [ "$EMPTY_MIRROR_BEFORE" = "$(hash "$TMP/explicit-empty/mirror/shared/index.md")" ]; then ok "explicit empty mirror slug rejection is byte-stable"; else bad "explicit empty mirror slug rejection is byte-stable"; fi

H="$(hash "$TMP/active/index.md")"; SH="$(hash "$TMP/ship.md")"
run --entity "$TMP/active/index.md" --if-hash "$H" --mirror-entity "$TMP/main.md" --mirror-if-hash "$(hash "$TMP/main.md")" --ship "$TMP/ship.md" --ship-if-hash "$SH" --merge-method-intent squash
if [ "$RC" -eq 0 ] && [ "$H" = "$(hash "$TMP/active/index.md")" ] && [ "$SH" = "$(hash "$TMP/ship.md")" ]; then ok "idempotent replay is byte stable"; else bad "idempotent replay is byte stable"; fi

run --entity "$TMP/active/index.md" --if-hash deadbeef
reason "stale active CAS stops" stale-entity-hash

entity "$TMP/mirror-active.md" same false same-title '#40'; entity "$TMP/mirror-slug.md" unrelated false same-title '#40'
AB="$(hash "$TMP/mirror-active.md")"; MB="$(hash "$TMP/mirror-slug.md")"
run --entity "$TMP/mirror-active.md" --if-hash "$AB" --mirror-entity "$TMP/mirror-slug.md" --mirror-if-hash "$MB" --closeout-owner true
reason "unrelated mirror slug stops" closeout-checkpoint-conflict
if [ "$AB" = "$(hash "$TMP/mirror-active.md")" ] && [ "$MB" = "$(hash "$TMP/mirror-slug.md")" ]; then ok "slug mismatch leaves active and mirror byte-stable"; else bad "slug mismatch leaves active and mirror byte-stable"; fi

entity "$TMP/mirror-title.md" same false other-title '#40'; MB="$(hash "$TMP/mirror-title.md")"
run --entity "$TMP/mirror-active.md" --if-hash "$AB" --mirror-entity "$TMP/mirror-title.md" --mirror-if-hash "$MB" --closeout-owner true
reason "unrelated mirror title stops" closeout-checkpoint-conflict
if [ "$AB" = "$(hash "$TMP/mirror-active.md")" ] && [ "$MB" = "$(hash "$TMP/mirror-title.md")" ]; then ok "title mismatch leaves active and mirror byte-stable"; else bad "title mismatch leaves active and mirror byte-stable"; fi

entity "$TMP/mirror-pr.md" same false same-title '#41'; MB="$(hash "$TMP/mirror-pr.md")"
run --entity "$TMP/mirror-active.md" --if-hash "$AB" --mirror-entity "$TMP/mirror-pr.md" --mirror-if-hash "$MB" --closeout-owner true
reason "unrelated mirror implementation PR stops" closeout-checkpoint-conflict
if [ "$AB" = "$(hash "$TMP/mirror-active.md")" ] && [ "$MB" = "$(hash "$TMP/mirror-pr.md")" ]; then ok "PR mismatch leaves active and mirror byte-stable"; else bad "PR mismatch leaves active and mirror byte-stable"; fi

entity "$TMP/mirror-normalized.md" same false same-title '40'
run --entity "$TMP/mirror-active.md" --if-hash "$AB" --mirror-entity "$TMP/mirror-normalized.md" --mirror-if-hash "$(hash "$TMP/mirror-normalized.md")" --closeout-owner true
if [ "$RC" -eq 0 ]; then ok "mirror implementation PR normalization accepts #40 and 40"; else bad "mirror implementation PR normalization accepts #40 and 40"; cat "$TMP/out"; fi

entity "$TMP/a.md" a false; entity "$TMP/b.md" b false
run --entity "$TMP/a.md" --if-hash "$(hash "$TMP/a.md")" --closeout-owner false --participant-entity "$TMP/b.md" --participant-if-hash "$(hash "$TMP/b.md")"
reason "shared PR with zero owners stops" closeout-owner-not-unique

entity "$TMP/a.md" a false; entity "$TMP/b.md" b false
run --entity "$TMP/a.md" --if-hash "$(hash "$TMP/a.md")" --closeout-owner true --participant-entity "$TMP/b.md" --participant-if-hash "$(hash "$TMP/b.md")"
if [ "$RC" -eq 0 ] && grep -q '^closeout_owner: true$' "$TMP/a.md"; then ok "shared PR with one owner persists"; else bad "shared PR with one owner persists"; cat "$TMP/out"; fi

entity_without_slug "$TMP/fallback/participants/owner/index.md" true; entity_without_slug "$TMP/fallback/participants/member/index.md" false
run --entity "$TMP/fallback/participants/owner/index.md" --if-hash "$(hash "$TMP/fallback/participants/owner/index.md")" --closeout-owner true --participant-entity "$TMP/fallback/participants/member/index.md" --participant-if-hash "$(hash "$TMP/fallback/participants/member/index.md")"
if [ "$RC" -eq 0 ] && grep -q '^closeout_owner: true$' "$TMP/fallback/participants/owner/index.md"; then ok "participant identities fall back to distinct entity directories"; else bad "participant identities fall back to distinct entity directories"; cat "$TMP/out"; fi

entity "$TMP/explicit-empty/participants/owner/index.md" owner true; entity_with_empty_slug "$TMP/explicit-empty/participants/member/index.md" false
EMPTY_PARTICIPANT_OWNER_BEFORE="$(hash "$TMP/explicit-empty/participants/owner/index.md")"; EMPTY_PARTICIPANT_BEFORE="$(hash "$TMP/explicit-empty/participants/member/index.md")"
run --entity "$TMP/explicit-empty/participants/owner/index.md" --if-hash "$EMPTY_PARTICIPANT_OWNER_BEFORE" --closeout-owner true --participant-entity "$TMP/explicit-empty/participants/member/index.md" --participant-if-hash "$EMPTY_PARTICIPANT_BEFORE"
reason "explicit empty participant slug is malformed" malformed-frontmatter
if [ "$EMPTY_PARTICIPANT_OWNER_BEFORE" = "$(hash "$TMP/explicit-empty/participants/owner/index.md")" ] && [ "$EMPTY_PARTICIPANT_BEFORE" = "$(hash "$TMP/explicit-empty/participants/member/index.md")" ]; then ok "explicit empty participant slug rejection is byte-stable"; else bad "explicit empty participant slug rejection is byte-stable"; fi

entity_without_slug "$TMP/fallback/duplicates/a/shared/index.md" true; entity_without_slug "$TMP/fallback/duplicates/b/shared/index.md" false
DUP_OWNER_BEFORE="$(hash "$TMP/fallback/duplicates/a/shared/index.md")"; DUP_MEMBER_BEFORE="$(hash "$TMP/fallback/duplicates/b/shared/index.md")"
run --entity "$TMP/fallback/duplicates/a/shared/index.md" --if-hash "$DUP_OWNER_BEFORE" --closeout-owner true --participant-entity "$TMP/fallback/duplicates/b/shared/index.md" --participant-if-hash "$DUP_MEMBER_BEFORE"
reason "duplicate derived participant slug stops" closeout-owner-not-unique
if [ "$DUP_OWNER_BEFORE" = "$(hash "$TMP/fallback/duplicates/a/shared/index.md")" ] && [ "$DUP_MEMBER_BEFORE" = "$(hash "$TMP/fallback/duplicates/b/shared/index.md")" ]; then ok "duplicate derived participant rejection is byte-stable"; else bad "duplicate derived participant rejection is byte-stable"; fi

entity_without_slug "$TMP/fallback/dot-segments/a/shared/index.md" true; entity_without_slug "$TMP/fallback/dot-segments/b/shared/index.md" false
DOT_OWNER_BEFORE="$(hash "$TMP/fallback/dot-segments/a/shared/index.md")"; DOT_MEMBER_BEFORE="$(hash "$TMP/fallback/dot-segments/b/shared/index.md")"
run --entity "$TMP/fallback/dot-segments/a/shared/index.md" --if-hash "$DOT_OWNER_BEFORE" --closeout-owner true --participant-entity "$TMP/fallback/dot-segments/b/shared/./index.md" --participant-if-hash "$DOT_MEMBER_BEFORE"
reason "dot-segment participant cannot bypass duplicate derived slug" closeout-owner-not-unique
if [ "$DOT_OWNER_BEFORE" = "$(hash "$TMP/fallback/dot-segments/a/shared/index.md")" ] && [ "$DOT_MEMBER_BEFORE" = "$(hash "$TMP/fallback/dot-segments/b/shared/index.md")" ]; then ok "dot-segment duplicate rejection is byte-stable"; else bad "dot-segment duplicate rejection is byte-stable"; fi

entity "$TMP/a.md" a true; entity "$TMP/b.md" b true
run --entity "$TMP/a.md" --if-hash "$(hash "$TMP/a.md")" --closeout-owner true --participant-entity "$TMP/b.md" --participant-if-hash "$(hash "$TMP/b.md")"
reason "shared PR with multiple owners stops" closeout-owner-not-unique

entity "$TMP/a.md" a true; entity "$TMP/b.md" b false
run --entity "$TMP/a.md" --if-hash "$(hash "$TMP/a.md")" --closeout-owner true --participant-entity "$TMP/b.md" --participant-if-hash deadbeef
reason "stale participant CAS stops before read" stale-entity-hash

entity "$TMP/strict-primary.md" strict-primary false
printf '%s\n' 'ordinary body before a later fence' '---' 'title: disguised' 'status: ship' 'slug: disguised' 'pr: "#40"' 'closeout_owner: false' '---' >"$TMP/disguised-participant.md"
STRICT_BEFORE="$(hash "$TMP/strict-primary.md")"; DISGUISED_BEFORE="$(hash "$TMP/disguised-participant.md")"
run --entity "$TMP/strict-primary.md" --if-hash "$STRICT_BEFORE" --closeout-owner true --participant-entity "$TMP/disguised-participant.md" --participant-if-hash "$DISGUISED_BEFORE"
reason "later fenced body cannot masquerade as participant frontmatter" malformed-frontmatter
if [ "$STRICT_BEFORE" = "$(hash "$TMP/strict-primary.md")" ] && [ "$DISGUISED_BEFORE" = "$(hash "$TMP/disguised-participant.md")" ]; then ok "malformed participant rejection is byte-stable"; else bad "malformed participant rejection is byte-stable"; fi

run --entity "$TMP/a.md" --if-hash "$(hash "$TMP/a.md")" --closeout-owner true --participant-entity "$TMP/b.md"
if [ "$RC" -eq 2 ]; then ok "unpaired participant input is usage error"; else bad "unpaired participant input is usage error"; fi

run --entity "$TMP/a.md" --if-hash "$(hash "$TMP/a.md")" --closeout-owner true --participant-if-hash "$(hash "$TMP/b.md")" --participant-entity "$TMP/b.md"
if [ "$RC" -eq 2 ]; then ok "participant hash must be adjacent after its entity"; else bad "participant hash must be adjacent after its entity"; fi

run --entity "$TMP/a.md" --if-hash "$(hash "$TMP/a.md")" --closeout-owner true --participant-entity "$TMP/a.md" --participant-if-hash "$(hash "$TMP/a.md")"
reason "duplicate canonical participant path stops" closeout-owner-not-unique

entity "$TMP/c.md" b false
run --entity "$TMP/a.md" --if-hash "$(hash "$TMP/a.md")" --closeout-owner true --participant-entity "$TMP/b.md" --participant-if-hash "$(hash "$TMP/b.md")" --participant-entity "$TMP/c.md" --participant-if-hash "$(hash "$TMP/c.md")"
reason "duplicate participant slug stops" closeout-owner-not-unique

entity "$TMP/no-intent.md" solo; run --entity "$TMP/no-intent.md" --if-hash "$(hash "$TMP/no-intent.md")"
if [ "$RC" -eq 0 ]; then ok "absence of merge intent is legal"; else bad "absence of merge intent is legal"; cat "$TMP/out"; fi

echo "Results: $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]
