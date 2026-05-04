#!/usr/bin/env bash
# test-check-invariants-c1-c5.sh — fixture tests for C1-C5 (PR #43 + #44 enforcement).
# Pattern: test-check-invariants.sh (same dir).
#
# Coverage:
#   C1 pre-mortem-emitted               — non-trivial pitch must have pre_mortem
#   C2 pol-probe-invoked                — medium/big-batch pitch must invoke pol-probe-advisor
#   C3 no-design-constraints-dual-write — design.md must NOT have retired ### Constraints for Plan Stage
#   C4 plan-imported-design-dcs-emitted — affects_ui=true + handoff non-skipped → plan.md needs ## Plan Imported Design DCs
#   C5 verify-mechanical-ui-parity-emitted — affects_ui=true + render_fidelity_targets present → verify.md needs #### Mechanical UI Parity

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/../.."
CHECK_SCRIPT="${PLUGIN_DIR}/bin/check-invariants.sh"
FAIL=0

assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}

mk_fixture() {
  local dir; dir=$(mktemp -d)
  mkdir -p "$dir/docs/ship-flow"
  echo "$dir"
}

# ---- C1 pre-mortem-emitted ----
echo "=== C1 pre-mortem-emitted ==="

f=$(mk_fixture)
cat > "$f/docs/ship-flow/999-test.md" <<'EOF'
---
id: "999"
pattern: pitch
title: "Add comprehensive observability dashboard for the new microservice deployment pipeline"
---
EOF
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check pre-mortem-emitted" "C1.1 non-trivial pitch missing pre_mortem fails"

cat >> "$f/docs/ship-flow/999-test.md" <<'EOF'
pre_mortem:
  category: hidden-dependency
  one_liner: foo
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check pre-mortem-emitted" "C1.2 pitch with pre_mortem passes"
rm -rf "$f"

f=$(mk_fixture)
cat > "$f/docs/ship-flow/998-fix.md" <<'EOF'
---
id: "998"
pattern: pitch
title: "fix typo"
---
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check pre-mortem-emitted" "C1.3 short fix-pattern title escapes (no pre_mortem needed)"
rm -rf "$f"

# Non-pitch entity — never required
f=$(mk_fixture)
cat > "$f/docs/ship-flow/997-single.md" <<'EOF'
---
id: "997"
pattern: single
title: "Some long enough title that would otherwise trigger non-trivial threshold for a pitch entity"
---
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check pre-mortem-emitted" "C1.4 non-pitch pattern skipped"
rm -rf "$f"

# ---- C2 pol-probe-invoked ----
echo "=== C2 pol-probe-invoked ==="

f=$(mk_fixture)
cat > "$f/docs/ship-flow/996-medium.md" <<'EOF'
---
id: "996"
pattern: pitch
title: "Medium batch pitch missing pol-probe invocation in body"
appetite: medium-batch
---
## Shape Report

Standard report with no PM-skill mention.
EOF
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check pol-probe-invoked" "C2.1 medium-batch missing pol-probe fails"

cat >> "$f/docs/ship-flow/996-medium.md" <<'EOF'

Layer A delegate Skill: pol-probe-advisor invoked successfully.
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check pol-probe-invoked" "C2.2 medium-batch with pol-probe passes"
rm -rf "$f"

f=$(mk_fixture)
cat > "$f/docs/ship-flow/995-small.md" <<'EOF'
---
id: "995"
pattern: pitch
appetite: small-batch
---
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check pol-probe-invoked" "C2.3 small-batch skipped (not mandatory)"
rm -rf "$f"

# ---- C3 no-design-constraints-dual-write ----
echo "=== C3 no-design-constraints-dual-write ==="

f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/994-design/"
cat > "$f/docs/ship-flow/994-design/design.md" <<'EOF'
## Design Output

### Captain Decisions
- D1: foo

### Constraints for Plan Stage
- bar
EOF
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check no-design-constraints-dual-write" "C3.1 retired Constraints subsection fails"

cat > "$f/docs/ship-flow/994-design/design.md" <<'EOF'
## Design Output

### Captain Decisions
- D1: foo

### Hand-off to Plan
design_constraints:
  - type: token-binding
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check no-design-constraints-dual-write" "C3.2 hand-off only passes"
rm -rf "$f"

# ---- C4 plan-imported-design-dcs-emitted ----
echo "=== C4 plan-imported-design-dcs-emitted ==="

f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/993-ui/"
cat > "$f/docs/ship-flow/993-ui/index.md" <<'EOF'
---
affects_ui: true
---
EOF
cat > "$f/docs/ship-flow/993-ui/design.md" <<'EOF'
## Design Output

### Hand-off to Plan
design_constraints:
  - type: token-binding
EOF
cat > "$f/docs/ship-flow/993-ui/plan.md" <<'EOF'
# Plan

Standard plan body with no Imported Design DCs section.
EOF
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.1 affects_ui + non-skipped + missing imported section fails"

cat >> "$f/docs/ship-flow/993-ui/plan.md" <<'EOF'

## Plan Imported Design DCs
- DC: var(--primary)
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.2 with imported section passes"
rm -rf "$f"

# design-skipped short-circuit
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/992-cli/"
cat > "$f/docs/ship-flow/992-cli/index.md" <<'EOF'
---
affects_ui: true
---
EOF
cat > "$f/docs/ship-flow/992-cli/design.md" <<'EOF'
## Design Output

### Hand-off to Plan
- design-skipped: true
EOF
cat > "$f/docs/ship-flow/992-cli/plan.md" <<'EOF'
# Plan

Backend pitch — no UI section needed.
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.3 design-skipped short-circuits (passes)"
rm -rf "$f"

# ---- C5 verify-mechanical-ui-parity-emitted ----
echo "=== C5 verify-mechanical-ui-parity-emitted ==="

f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/991-render/"
cat > "$f/docs/ship-flow/991-render/index.md" <<'EOF'
---
affects_ui: true
---
EOF
cat > "$f/docs/ship-flow/991-render/design.md" <<'EOF'
## Design Output

### Hand-off to Plan
render_fidelity_targets:
  - selector: .cta-button
    css_property: background-color
EOF
cat > "$f/docs/ship-flow/991-render/verify.md" <<'EOF'
# Verify

### Review Findings

Standard findings with no Mechanical UI Parity subsection.
EOF
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check verify-mechanical-ui-parity-emitted" "C5.1 affects_ui + render_fidelity_targets + missing parity subsection fails"

cat >> "$f/docs/ship-flow/991-render/verify.md" <<'EOF'

#### Mechanical UI Parity
- token check: PASS
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check verify-mechanical-ui-parity-emitted" "C5.2 with parity subsection passes"
rm -rf "$f"

# ---- Summary ----
if [ "$FAIL" = "0" ]; then
  echo ""
  echo "=== test-check-invariants-c1-c5: ALL TESTS PASSED ==="
else
  echo ""
  echo "=== test-check-invariants-c1-c5: FAILURES ABOVE ==="
fi

exit $FAIL
