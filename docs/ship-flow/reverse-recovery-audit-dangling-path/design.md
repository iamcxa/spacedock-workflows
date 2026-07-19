# Fix dangling reverse-recovery-audit adopter-local mod reference + regress-guard — Design

### Summary

Trivial-pass (Phase 0). S mechanical: two 1-line doc-reference rewrites + one **additive**
resolver pass in `scripts/check-no-dangling.sh` + one fixture-backed shell test. No
`references/*.yaml` schema change, no helper CLI flag/contract redesign, no template change —
the guard direction and RED/GREEN fixtures are already fully specified by shape (`open_contract
_decisions: []`-equivalent; no new captain decision). **Verdict: PROCEED.** The one thing shape
did not fully pin — the qualifier vocabulary — is refined below; it is a heuristic tightening
inside the shaped twin-exists+qualifier-aware approach, not a contract redesign.

### Trivial-pass eligibility (checklist item 1)

| Contract class | Touched? |
| --- | --- |
| Skill contract / behavior | No — the two edits are prose *reference lines* in `## References`; they change no skill instruction, gate, or output shape |
| Schema (`references/*.yaml`) | No |
| Helper CLI surface (flags/exit codes) | No — the resolver is a new internal pass in an existing gate; no new flag, no changed exit-code meaning (still 0 pass / 1 fail) |
| Template | No |

Additive-only, mechanical → Phase 0 fast-path. PROCEED.

### Contract deltas (checklist item 2)

**Δ1 — `plugins/ship-flow/skills/ship-shape/SKILL.md:597`** (single-line list item under `## References`).
Rewrite to lead with the plugin-canonical path and demote the adopter path to a "when present"
override (shape Decision fix (b)):
- Before: `… : \`docs/ship-flow/_mods/reverse-recovery-audit.md\`; plugin-canonical copy at \`plugins/ship-flow/_mods/reverse-recovery-audit.md\`.`
- After (intent): `… : \`plugins/ship-flow/_mods/reverse-recovery-audit.md\` (plugin-canonical); adopter override \`docs/ship-flow/_mods/reverse-recovery-audit.md\` when present.`

**Δ2 — `plugins/ship-flow/skills/ship-plan/SKILL.md:502`** — identical rewrite shape (same before/after
pattern; preserve that line's own descriptive parenthetical).

**Δ3 — `scripts/check-no-dangling.sh`: new "mislocated-canonical-mod resolver" pass** (additive; the 8
existing denylist patterns and `--self-test` mode untouched). Note the script lives at
`scripts/check-no-dangling.sh` (NOT `plugins/ship-flow/lib/…`); it already computes `REPO_ROOT` and
scans `SCAN_ROOT=$REPO_ROOT/plugins/ship-flow`. The pass: for each **backtick-fenced**
`docs/ship-flow/_mods/<name>.md` occurring in scanned `plugins/ship-flow/**/*.md`, VIOLATION iff **all**:
1. adopter `$REPO_ROOT/docs/ship-flow/_mods/<name>.md` does **not** exist, AND
2. plugin twin `$REPO_ROOT/plugins/ship-flow/_mods/<name>.md` **does** exist (resolve BOTH targets
   against `REPO_ROOT`, not `SCAN_ROOT` — the paths straddle the two trees), AND
3. the reference's **full logical unit** carries no adopter-optional qualifier.

Three scoping constraints are load-bearing — each found by exercising the rule against the real
repo; dropping any one breaks AC-3 (see green-set table). They are NOT optional polish:

- **(a) backtick-fenced only.** `plugins/ship-flow/_mods/ship-flow-lint.md:60-62` lists the path as a
  double-quoted JSON value inside a `requiredFiles` array (twin exists, adopter absent). Matching
  bare/quoted paths would false-positive it; matching only `` `…` `` backtick fences excludes it.
- **(b) full logical unit, not physical line.** `plugins/ship-flow/skills/science-officer-em/SKILL.md:11-12`
  soft-wraps its qualifier ("if a\nworkflow override exists at `docs/…`"); a line-scoped qualifier
  check sees only line 12 and false-positives. Join the soft-wrapped list-item/sentence before
  applying condition (3) (shape's stated refinement).
- **(c) qualifier vocabulary must cover the agents-file form — BEYOND shape's literal list.**
  `plugins/ship-flow/agents/science-officer-em.md:16-18` qualifies with "If the repo has `docs/…`,
  read that **override** first" — which contains none of shape's listed phrases (`when present` / `if a
  workflow override exists` / `otherwise the plugin copy` / `adopter override`). A resolver using only
  shape's literal list REDS this legitimate reference. The qualifier detection MUST also recognize the
  `if the repo has …` / `read that override` / `override` phrasing. Use a robust qualifier signal set
  (recommend matching any of: `when present`, `if a workflow override exists`, `if the repo has`,
  `otherwise the plugin copy`, `adopter override`, or the token `override` within the unit).

**Fixture-drivability constraint:** the resolver must be runnable against a scratch root for the
RED/GREEN fixtures (AC-2). The script currently hardcodes `REPO_ROOT` from `SCRIPT_DIR/..` with no
override — execute must either add a `REPO_ROOT` env override or factor the pass into a function the
test sources and calls with a root argument. Without this the fixture test cannot exercise the pass.

### Real-repo green-set — what the guard must NOT flag (AC-3, verified by enumeration)

Every backtick `docs/ship-flow/_mods/<name>.md` reference in `plugins/ship-flow/**/*.md`:

| mod name | plugin twin? | adopter? | ref sites | guard outcome (post-fix) | excluded by |
| --- | --- | --- | --- | --- | --- |
| reverse-recovery-audit | yes | no | ship-shape:597, ship-plan:502 | **RED today → GREEN after Δ1/Δ2** | cond 3 (becomes qualified) |
| science-officer-em | yes | no | agents:16-18, SKILL:11-12 | green | cond 3 via (c) + (b) |
| contribution-contract | yes | no | ship-review:25 ("when present, otherwise the plugin copy") | green | cond 3 |
| ship-flow-lint | yes | no | _mods/ship-flow-lint.md:60-62 (JSON) | green | cond a (not backtick) |
| architecture-canon | **no** | no | ship-shape:596, ship-plan:501 | green | cond 2 (no twin) |
| canonical-doc-sync | **no** | no | multiple | green | cond 2 |
| decisions-log | **no** | no | 1 | green | cond 2 |
| pr-merge | no | **yes** | 1 (line 564) | green | cond 1 (adopter present) |

Only reverse-recovery-audit reds before the fix; nothing reds after. This IS the AC-2 "green on the
repo" surface and the AC-3 no-over-reach proof. The out-of-scope missing-everywhere mods
(architecture-canon, canonical-doc-sync, decisions-log) are excluded by condition (2) as shape intended.

### Test surfaces that must move (checklist item 3)

- **New:** `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh` — auto-discovered by the CI loop
  `for t in plugins/ship-flow/lib/__tests__/test-*.sh` (`.github/workflows/ship-flow-invariants.yml:110`).
  Fixtures per shape: RED (unqualified backtick, twin present, adopter absent → exit 1); GREEN-fixed
  (leads with plugin path + "when present"); GREEN-qualified; GREEN-wrapped-qualifier (constraint b);
  GREEN-no-twin (constraint cond 2); **add GREEN-agents-override** (constraint c: "If the repo has … read
  that override"); GREEN-json-noise (constraint a: double-quoted path not flagged); plus green on the real
  repo after the fix.
- **Wiring:** `scripts/check-no-dangling.sh` runs at `.github/workflows/ship-flow-invariants.yml:136`
  (`source_repo == 'true'` gate). The new pass rides that same invocation — no CI-YAML change needed.
- **No existing string-assertion test pins the changed text.** `grep -rl reverse-recovery-audit`
  across `lib/__tests__/` returns zero hits, and no test asserts "Reverse-recovery audit mod" /
  "plugin-canonical copy at". So Δ1/Δ2 break **zero** of the 120 shell tests. `validate-d-references.sh`
  is unrelated (validates `D{N}` decision backrefs, not `_mods/` paths).

### Design Report

- Mode: **trivial-pass (Phase 0)** — S mechanical, additive-only; no schema/CLI/template contract redesign.
- Contract deltas: Δ1 ship-shape:597 rewrite, Δ2 ship-plan:502 rewrite, Δ3 additive resolver pass in
  `scripts/check-no-dangling.sh` (twin-exists + qualifier-aware, resolve targets against REPO_ROOT).
- Refinements found by exercising (load-bearing, not polish): (a) backtick-fenced scoping excludes
  ship-flow-lint.md JSON; (b) full-logical-unit unwrap excludes science-officer-em SKILL wrap; (c)
  qualifier vocabulary must cover the agents-file "If the repo has … override" form — **beyond shape's
  literal list**; plus resolver must be drivable against a scratch root for the fixtures.
- Test surfaces: new `lib/__tests__/test-check-no-dangling.sh` (CI-loop auto-discovered) with the shape
  fixtures + two added GREEN cases (agents-override, json-noise); wired via ship-flow-invariants.yml:136;
  zero existing tests pin the edited text (verified) so AC-3 holds for Δ1/Δ2.
- status: passed
- verdict: PROCEED
- open_design_questions_remaining: 0
