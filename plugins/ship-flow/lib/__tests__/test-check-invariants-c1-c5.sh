#!/usr/bin/env bash
# test-check-invariants-c1-c5.sh — fixture tests for C1-C5 (PR #43 + #44 enforcement).
# Pattern: test-check-invariants.sh (same dir).
#
# Coverage:
#   C1 pre-mortem-emitted               — non-trivial pitch must have pre_mortem
#   C2 pol-probe-invoked                — medium/big-batch pitch must invoke pol-probe-advisor
#   C3 no-design-constraints-dual-write — design.md must NOT have retired ### Constraints for Plan Stage
#   C4 plan-imported-design-dcs-emitted — design-bearing trigger (affects_ui=true OR domain set OR design_required=true OR contract_decision_required=true) requires (a) '### Hand-off to Plan' at canonical H3, (b) either 'design-skipped: true' or '## Plan Imported Design DCs' in plan.md
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
affects_ui: false
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

# design-bearing entities may only design-skip with an explicit captain bypass.
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/992b-domain-skipped/"
cat > "$f/docs/ship-flow/992b-domain-skipped/index.md" <<'EOF'
---
affects_ui: false
domain: schema
contract_decision_required: true
---
EOF
cat > "$f/docs/ship-flow/992b-domain-skipped/design.md" <<'EOF'
## Design Output

### Hand-off to Plan
- design-skipped: true
EOF
cat > "$f/docs/ship-flow/992b-domain-skipped/plan.md" <<'EOF'
# Plan

Backend contract pitch — design-skipped without captain bypass is invalid.
EOF
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.3b design-bearing + design-skipped without captain bypass fails"
rm -rf "$f"

f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/992c-domain-skipped-bypass/"
cat > "$f/docs/ship-flow/992c-domain-skipped-bypass/index.md" <<'EOF'
---
affects_ui: false
domain: schema
contract_decision_required: true
---
EOF
cat > "$f/docs/ship-flow/992c-domain-skipped-bypass/design.md" <<'EOF'
## Design Output

### Hand-off to Plan
- design-skipped: true
- captain-approved-design-bypass: true
- bypass_rationale: "Captain chose to skip schema design for this fixture."
EOF
cat > "$f/docs/ship-flow/992c-domain-skipped-bypass/plan.md" <<'EOF'
# Plan

Backend contract pitch — explicit captain bypass permits design-skipped.
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.3c design-bearing + design-skipped with captain bypass passes"
rm -rf "$f"

# Non-UI trigger expansion (SKILL Step 1.6: domain-bearing entities also need import)
mk_design_bearing_fixture() {
  local trigger_line="$1" slug="$2"
  local fx; fx=$(mk_fixture)
  mkdir -p "$fx/docs/ship-flow/${slug}/"
  cat > "$fx/docs/ship-flow/${slug}/index.md" <<EOF
---
affects_ui: false
${trigger_line}
---
EOF
  cat > "$fx/docs/ship-flow/${slug}/design.md" <<'EOF'
## Design Output

### Hand-off to Plan
design_constraints:
  - type: contract-shape
EOF
  cat > "$fx/docs/ship-flow/${slug}/plan.md" <<'EOF'
# Plan

Standard plan body with no Imported Design DCs section.
EOF
  echo "$fx"
}

f=$(mk_design_bearing_fixture "domain: ship-flow-pr" "994-domain")
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.4 domain set + missing imported section fails"
rm -rf "$f"

# C4.4b: quoted domain values (YAML allows both unquoted and quoted strings)
f=$(mk_design_bearing_fixture 'domain: "ship-flow-pr"' "994b-domain-dq")
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.4b double-quoted domain + missing imported section fails"
rm -rf "$f"

f=$(mk_design_bearing_fixture "domain: 'ship-flow-pr'" "994c-domain-sq")
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.4c single-quoted domain + missing imported section fails"
rm -rf "$f"

# C4.4d: empty quoted domain — gate should NOT fire (empty == unset semantically)
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/994d-empty-quoted-domain/"
cat > "$f/docs/ship-flow/994d-empty-quoted-domain/index.md" <<'EOF'
---
affects_ui: false
domain: ""
---
EOF
cat > "$f/docs/ship-flow/994d-empty-quoted-domain/design.md" <<'EOF'
## Design Output

### Hand-off to Plan
- design-skipped: true
EOF
cat > "$f/docs/ship-flow/994d-empty-quoted-domain/plan.md" <<'EOF'
# Plan
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.4d empty-quoted domain → gate does not fire (unset semantics)"
rm -rf "$f"

f=$(mk_design_bearing_fixture "design_required: true" "995-design-req")
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.5 design_required=true + missing imported section fails"
rm -rf "$f"

f=$(mk_design_bearing_fixture "contract_decision_required: true" "996-contract")
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.6 contract_decision_required=true + missing imported section fails"
rm -rf "$f"

# Negative trigger: no design-bearing signal — gate should not fire
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/997-pure-cli/"
cat > "$f/docs/ship-flow/997-pure-cli/index.md" <<'EOF'
---
affects_ui: false
---
EOF
cat > "$f/docs/ship-flow/997-pure-cli/design.md" <<'EOF'
## Design Output

### Hand-off to Plan
design_constraints:
  - type: contract-shape
EOF
cat > "$f/docs/ship-flow/997-pure-cli/plan.md" <<'EOF'
# Plan

No imported section, but no trigger either.
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.7 no design-bearing trigger → gate does not fire"
rm -rf "$f"

# Hand-off integrity (header-level + missing-block) — leak classes from 2026-05-24 audit.
# Helper for these cases: design-bearing entity + handoff in design.md with arbitrary header.
mk_handoff_integrity_fixture() {
  local handoff_body="$1" slug="$2"
  local fx; fx=$(mk_fixture)
  mkdir -p "$fx/docs/ship-flow/${slug}/"
  cat > "$fx/docs/ship-flow/${slug}/index.md" <<'EOF'
---
contract_decision_required: true
---
EOF
  printf '## Design Output\n\n%s\n' "$handoff_body" > "$fx/docs/ship-flow/${slug}/design.md"
  cat > "$fx/docs/ship-flow/${slug}/plan.md" <<'EOF'
# Plan

Standard plan body with no Imported Design DCs section.
EOF
  echo "$fx"
}

# C4.8: handoff exists at H2 (wrong level) — pr-merge-claude-challenge-gate class
f=$(mk_handoff_integrity_fixture $'## Hand-off to Plan\ndesign_constraints:\n  - type: contract-shape' "988-h2-handoff")
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.8 H2 'Hand-off to Plan' header (canonical is H3) fails"
rm -rf "$f"

# C4.9: handoff at H1
f=$(mk_handoff_integrity_fixture $'# Hand-off to Plan\ndesign_constraints:\n  - type: contract-shape' "987-h1-handoff")
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.9 H1 'Hand-off to Plan' header (canonical is H3) fails"
rm -rf "$f"

# C4.10: design-bearing entity with NO handoff block at all — ship-flow-stage-metrics-standardization class
f=$(mk_handoff_integrity_fixture $'_design body without any Hand-off block._' "986-no-handoff")
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.10 design-bearing entity with no handoff block fails"
rm -rf "$f"

# C4.11: NOT design-bearing + wrong-level handoff — gate should NOT fire
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/985-non-bearing-h2/"
cat > "$f/docs/ship-flow/985-non-bearing-h2/index.md" <<'EOF'
---
affects_ui: false
---
EOF
cat > "$f/docs/ship-flow/985-non-bearing-h2/design.md" <<'EOF'
## Design Output

## Hand-off to Plan
design_constraints:
  - type: contract-shape
EOF
cat > "$f/docs/ship-flow/985-non-bearing-h2/plan.md" <<'EOF'
# Plan

No imported section, no trigger.
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.11 non-trigger entity + wrong-level handoff → gate does not fire"
rm -rf "$f"

# C4.12: NOT design-bearing + missing handoff — gate should NOT fire
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/984-non-bearing-no-handoff/"
cat > "$f/docs/ship-flow/984-non-bearing-no-handoff/index.md" <<'EOF'
---
affects_ui: false
---
EOF
cat > "$f/docs/ship-flow/984-non-bearing-no-handoff/design.md" <<'EOF'
## Design Output

No handoff block.
EOF
cat > "$f/docs/ship-flow/984-non-bearing-no-handoff/plan.md" <<'EOF'
# Plan

No imported section, no trigger.
EOF
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "C4.12 non-trigger entity + missing handoff → gate does not fire"
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
