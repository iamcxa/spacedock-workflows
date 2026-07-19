# Ship-flow core: the human review surface is the shape/spec, not plan.md — Design

## Design Report

- verdict: PROCEED
- category: trivial-pass (Phase 0 fast-path)
- iterations: 0
- rationale: Pure methodology-prose + shell-checker work. `affects_ui: false`; no
  matched domain (the `registry-resolve --classify` `schema` hit was a lexical
  false positive on assumption A1's "workflow schema" phrase — see index.md
  Domain Registry Validation); `design_required: false`; `contract_decision_required:
  false`; no open contract decisions. The enforcement style (a string-assertion
  `check-invariants.sh` check mirroring C1–C15) is fixed by the issue AC, so there
  is no contract/interface/grammar to decide. Per INVARIANTS Principle 11 the
  design stage always runs; for mechanical work with no contract deltas it
  short-circuits to PROCEED.
- contract_deltas: none
- design_dcs: none (entity is not design-bearing per the C4 trigger — all of
  affects_ui / domain / design_required / contract_decision_required are false)

### Hand-off to Plan
- design-skipped: false
- trivial-pass: true
- open_design_questions: []
- open_contract_decisions: []
- imported_design_dcs: none
