#!/usr/bin/env bash
# Regression guard for 130.1 stage dispatch prompt EM charter injection.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
HELPER="${ROOT}/plugins/ship-flow/lib/build-stage-dispatch-prompt.sh"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "PASS: ${desc}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

run_helper() {
  "$HELPER" \
    --workflow-dir docs/ship-flow \
    --stage execute \
    --teammate executer \
    --entity-folder docs/ship-flow/130.1-em-profile-charter-mandatory-load \
    --prior-artifact plan.md \
    --output-artifact execute.md \
    --skill ship-flow:ship-execute
}

case "${1:-default}" in
  --case)
    case "${2:-}" in
      missing-profile)
        tmp="$(mktemp -d)"
        trap 'rm -rf "$tmp"' EXIT
        out="$tmp/out.txt"
        err="$tmp/err.txt"
        if "$HELPER" \
          --workflow-dir "$tmp/docs/ship-flow" \
          --plugin-root "$tmp/plugins/ship-flow" \
          --stage execute \
          --teammate executer \
          --entity-folder docs/ship-flow/130.1-em-profile-charter-mandatory-load \
          --prior-artifact plan.md \
          --output-artifact execute.md \
          --skill ship-flow:ship-execute >"$out" 2>"$err"; then
          echo "FAIL: missing-profile returned success"
          exit 1
        fi
        grep -q 'science-officer-em-profile-not-loaded' "$err"
        ! grep -q 'Run /execute' "$out"
        ! grep -Eqi 'warning|best-effort|placeholder|degrade|FO relay' "$err" "$out"
        echo "PASS: missing-profile hard block"
        exit 0
        ;;
      *)
        echo "Unknown case: ${2:-}" >&2
        exit 2
        ;;
    esac
    ;;
esac

echo "=== Science Officer (EM) dispatch helper ==="

check "helper exists" "test -x '$HELPER'"

# shellcheck disable=SC2034 # referenced inside eval-backed check commands.
prompt="$(run_helper)"
check "normal stage assignment emitted" "grep -q 'Run /execute' <<<\"\$prompt\" && grep -q 'Entity folder: docs/ship-flow/130.1-em-profile-charter-mandatory-load' <<<\"\$prompt\""
check "output artifact emitted" "grep -q 'output execute.md' <<<\"\$prompt\""
check "skill emitted" "grep -q 'Skill: ship-flow:ship-execute' <<<\"\$prompt\""
check "EM charter section emitted" "grep -q '^### Science Officer (EM) Charter$' <<<\"\$prompt\""
check "anti-relay included" "grep -qi 'anti-relay' <<<\"\$prompt\" && grep -qi 'status-only relay' <<<\"\$prompt\""
check "costly no included" "grep -qi 'costly no' <<<\"\$prompt\" && grep -qi 'say no' <<<\"\$prompt\""
check "independent synthesis included" "grep -qi 'independent synthesis' <<<\"\$prompt\" && grep -qi 'FO state' <<<\"\$prompt\""
check "FO boundary included" "grep -qi 'FO owns' <<<\"\$prompt\" && grep -qi 'EM owns' <<<\"\$prompt\""
check "Codex dispatch evidence guard included in generated prompt" \
  "grep -q 'Codex dispatch evidence guard' <<<\"\$prompt\" && grep -q 'Domain Registry Validation' <<<\"\$prompt\" && grep -q 'Schema Design Output' <<<\"\$prompt\" && grep -q 'Intent Match Findings' <<<\"\$prompt\""

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/docs/ship-flow/_mods" "$tmp/plugins/ship-flow/_mods"
cat >"$tmp/docs/ship-flow/_mods/science-officer-em.md" <<'PROFILE'
name: science-officer-em
standing: true
workflow-profile-marker
Anti-relay status-only relay.
Costly no say no.
Independent synthesis FO state.
FO owns workflow; EM owns judgment.
PROFILE
cat >"$tmp/plugins/ship-flow/_mods/science-officer-em.md" <<'PROFILE'
name: science-officer-em
standing: true
plugin-profile-marker
Anti-relay status-only relay.
Costly no say no.
Independent synthesis FO state.
FO owns workflow; EM owns judgment.
PROFILE
# shellcheck disable=SC2034 # referenced inside eval-backed check commands.
precedence_prompt="$("$HELPER" \
  --workflow-dir "$tmp/docs/ship-flow" \
  --plugin-root "$tmp/plugins/ship-flow" \
  --stage verify \
  --teammate verifier \
  --entity-folder docs/ship-flow/example \
  --prior-artifact execute.md \
  --output-artifact verify.md \
  --skill ship-flow:ship-verify)"
check "workflow profile wins before plugin profile" \
  "grep -q 'workflow-profile-marker' <<<\"\$precedence_prompt\" && ! grep -q 'plugin-profile-marker' <<<\"\$precedence_prompt\""

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
