#!/usr/bin/env bash
# test-canonical-doc-actions-schema.sh - schema-backed canonical context handoff.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
SCHEMA="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"
ASSERT_SCHEMA="${SCRIPT_DIR}/assert-canonical-doc-actions-schema.rb"

PASS=0
FAIL=0
ERRORS=()

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

echo "=== test-canonical-doc-actions-schema.sh ==="
echo ""

check "design schema exposes canonical_context rows" \
  "grep -q 'canonical_context' '${SCHEMA}' && grep -q 'Canonical Context' '${SCHEMA}' && grep -q 'sections_read' '${SCHEMA}' && grep -q 'skip_rationale' '${SCHEMA}'"

check "plan schema exposes canonical_doc_actions table" \
  "grep -q 'canonical_doc_actions' '${SCHEMA}' && grep -q 'Canonical Doc Actions' '${SCHEMA}' && grep -q 'Doc.*Action.*Source.*Rationale' '${SCHEMA}'"

check "plan handoff carries canonical_doc_actions to execute/verify/review" \
  "grep -q 'canonical_doc_actions_summary' '${SCHEMA}' && grep -q 'Consumed by verify and review' '${SCHEMA}'"

check "verify schema exposes canonical drift audit" \
  "grep -q 'canonical_drift_audit' '${SCHEMA}' && grep -q 'Canonical Drift Audit' '${SCHEMA}' && grep -q 'route_to' '${SCHEMA}'"

check "review schema exposes canonical_doc_actions consumption" \
  "grep -q 'canonical_doc_actions_consumed' '${SCHEMA}' && grep -q 'Action Source' '${SCHEMA}' && grep -q 'Review Outcome' '${SCHEMA}'"

check "schema parser validates exact canonical doc action contract" \
  "ruby --disable=gems '${ASSERT_SCHEMA}' '${SCHEMA}'"

DRIFT_SCHEMA="$(mktemp "${TMPDIR:-/tmp}/canonical-doc-actions-schema.XXXXXX.yaml")"
trap 'rm -f "${DRIFT_SCHEMA}"' EXIT
cp "${SCHEMA}" "${DRIFT_SCHEMA}"
ruby --disable=gems -ryaml -e '
  path = ARGV.fetch(0)
  schema = YAML.safe_load(File.read(path), permitted_classes: [Symbol], aliases: true)
  field = schema.dig("stages", "plan", "output", "subsections", "canonical_doc_actions", "fields").find { |item| item["name"] == "canonical_doc_actions" }
  field["allowed_actions"] = field.fetch("allowed_actions") + ["defer"]
  File.write(path, YAML.dump(schema))
' "${DRIFT_SCHEMA}"

check "schema parser rejects canonical doc action drift" \
  "! ruby --disable=gems '${ASSERT_SCHEMA}' '${DRIFT_SCHEMA}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
