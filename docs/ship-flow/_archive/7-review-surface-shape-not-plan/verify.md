# Ship-flow core: the human review surface is the shape/spec, not plan.md — Verify

## Verify Report

- verdict: **PASS**
- gate driver: FO with EM-tier judgment + codex cross-vendor 2nd opinion + opus-FO
  adjudication — i.e. this entity's own W3 verify-gate posture, dogfooded.

### Mechanical evidence (all green)
- `check-invariants.sh` (CI=true, full suite): exit 0 — no regression; C9 dup-Principle green; C16 present.
- `test-check-invariants-c16.sh`: 6/6 (A live · B both-present · C neither+stderr · D heading-only-reworded · E one-sentence-only). RED-before-GREEN captured in execute.md.
- Existing suite (no regression): test-check-invariants.sh (incl. DC-5 shellcheck), -c1-c5, -c15, -archived-corpus — all PASS.
- `shellcheck -S warning` on check-invariants.sh: exit 0. `git diff --check`: clean.
- 8 DCs (DC-1..DC-8): all PASS.

### Cross-vendor 2nd opinion (codex, adversarial)
4 findings + 1 CLEAN. FO adjudication (code wins over verdict):
- **[CONFIRMED] test AND-semantics gap** — FIXED: added Case E (exactly one pinned sentence → FAIL); cases A–D would all survive an AND→OR regression. Directly counters the wrong-dcs pre-mortem.
- **[PLAUSIBLE] direction-confirm lacks a hard predicate (#078 re-open risk)** — FIXED (light): tightened the bullet to "ONLY when continuing would build the wrong thing; NOT routine uncertainty / am-I-on-track".
- **[CONFIRMED] graceful-absent `return 0` → vacuous PASS if INVARIANTS.md missing** — ACCEPTED: identical to the C9 pattern (fixture-compat); real CI always has a regular INVARIANTS.md. Theoretical/fixture-only.
- **[CONFIRMED] whole-file grep not scoped to Principle 17** — ACCEPTED: identical to C9; the two sentences are distinctive and currently appear only in Principle 17; scoping would add awk-range/fixture coupling and deviate from the file-wide pattern.
- **[CLEAN]** ASCII/em-dash fail loud (no silent unicode mismatch); C16 wired into both dispatcher + full-run.

### Pre-mortem check (wrong-dcs)
The named risk — "C16 pins text, not FO behavior" — is accepted and stated honestly in Principle 17 itself (Tier B). Case E strengthens the DC from "text present somewhere" toward "both load-bearing sentences present (AND)", the meaningful bar for a text-pin.

### Scope
No science-officer-em re-wiring; no codex-gate promotion. Verify-gate posture codified as descriptive prose only. Deferred "before Intake" doc NIT + the stale ship-shape "design-skipped" guidance left out of scope (filed for debrief).
