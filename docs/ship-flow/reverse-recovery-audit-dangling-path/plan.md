# Fix dangling reverse-recovery-audit adopter-local mod reference + regress-guard — Plan

### Summary

Three atomic, independently-verifiable commits, strictly RED-before-GREEN: **T1** authors
`plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh` against a resolver function that does
not exist yet (RED, legible reason, zero edits to `scripts/check-no-dangling.sh`); **T2** re-points
the two dangling SKILL references (Δ1/Δ2) — a text-only fix, independently safe because the gate
does not check this class yet; **T3** adds the additive `run_mislocated_canonical_mods` pass (Δ3)
to `scripts/check-no-dangling.sh`, turning T1's fixtures GREEN. T2-before-T3 ordering is
deliberate: it means the guard is never live on an unfixed repo (no transient CI-red commit in the
sequence). Exercising design's rule against the real repo (same "prove by exercising" method
design itself used) surfaced one additional load-bearing constraint design's own green-set table
missed — a self-referential mention inside the mod file's own header — recorded as constraint (d)
below and folded into T3 + a new fixture case, because without it AC-2's "green on the repo" proof
does not actually hold.

### Runtime commands (pinned from the existing harness)

- **New test, standalone**: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`
- **Full local suite** (matches CI's "Run full ship-flow shell test suite" step, repo-root-relative):
  `for t in plugins/ship-flow/lib/__tests__/test-*.sh; do CI=true timeout 90 bash "$t" || echo FAILED:$t; done`
- **The guard itself**: `bash scripts/check-no-dangling.sh` (normal run) and `bash scripts/check-no-dangling.sh --self-test` (existing 8-pattern self-test, must stay green — additive-only).
- **AC-1 resolving-reference proof**: `grep -n 'reverse-recovery-audit.md' plugins/ship-flow/skills/ship-shape/SKILL.md plugins/ship-flow/skills/ship-plan/SKILL.md`

### Serial execution order

`T1 → T2 → T3`, strictly serial (single worktree, no parallel waves — matches the entity's S
appetite). Each is one commit, one explicit pathspec, independently verifiable per its own DC.

---

### T1 — Resolver test, RED (test-only commit)

**File** (new): `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`. No edits to
`scripts/check-no-dangling.sh` in this task — the resolver function does not exist yet, and the
test must fail for a *legible* reason, not by accidentally sourcing-and-executing the unguarded
script (see T3's fixture-drivability note — sourcing today's `check-no-dangling.sh` unmodified
would hit its unconditional bottom-of-file `exit 0/1` and corrupt the test run, not just fail
one assertion).

<details>
<summary>T1 fixture spec — harness structure, 9-case table, constraint (d) derivation (raw evidence; collapsed per Principle 8 / C15)</summary>

**Structure** (matches `test-merged-pr-closeout-reconciler.sh` conventions — `PASS`/`FAIL`/`ERRORS`,
`record_pass`/`record_fail`, `assert_exit`):

- `SCRIPT_DIR`/`REPO_ROOT` computed the same way (`../../../..` from
  `plugins/ship-flow/lib/__tests__/`); `HELPER="${REPO_ROOT}/scripts/check-no-dangling.sh"`.
- **First assertion** (the legible-RED gate, mirrors the suite's `[ -x "$HELPER" ]` convention):
  `grep -q '^run_mislocated_canonical_mods()' "$HELPER"` → `record_pass "resolver function
  run_mislocated_canonical_mods defined in check-no-dangling.sh"` or `record_fail` with that same
  description. When this fails, every fixture case below records a single uniform `record_fail
  "<case>: resolver function not yet defined"` line each (skip attempting to source) — so the
  assertion count is identical between the RED and GREEN runs, only PASS/FAIL flips.
- When the existence check passes: `source "$HELPER"` (safe post-T3 — the sourced script no longer
  self-executes because of T3's main-guard) then run each fixture case below by calling
  `run_mislocated_canonical_mods "$scratch_root"` against a `mktemp -d` scratch tree built per case
  (mirrors the script's own existing `--self-test` mode, which already uses `mktemp -d
  /tmp/check-no-dangling-selftest-XXXXXX` + `trap 'rm -rf "$tmpdir"' EXIT` — reuse that idiom, one
  scratch dir per case, cleaned up in the same trap).

**Fixture cases** (scratch tree layout per case: `$root/plugins/ship-flow/<somefile>.md` holding the
scanned line, plus `$root/plugins/ship-flow/_mods/<name>.md` and/or `$root/docs/ship-flow/_mods/<name>.md`
as each case requires):

| # | Case | Scratch layout | Expected |
| --- | --- | --- | --- |
| 1 | RED — unqualified | plugin `_mods/foo.md` present; adopter absent; scanned file has bare `` `docs/ship-flow/_mods/foo.md` `` | exit 1, 1 violation line |
| 2 | GREEN-fixed | scanned line leads with `` `plugins/ship-flow/_mods/foo.md` `` (plugin-canonical) + adopter `` `docs/ship-flow/_mods/foo.md` `` **when present** | exit 0 |
| 3 | GREEN-qualified | `"if a workflow override exists at `docs/ship-flow/_mods/foo.md`, read it"` (single line) | exit 0 |
| 4 | GREEN-wrapped-qualifier | qualifier phrase split across two lines within the same paragraph, mirroring `science-officer-em/SKILL.md:11-12` exactly (`"...before answering; if a\nworkflow override exists at `docs/ship-flow/_mods/foo.md`, read"`) | exit 0 (proves full-logical-unit join, constraint b) |
| 5 | GREEN-no-twin | `` `docs/ship-flow/_mods/bar.md` `` unqualified, **no** plugin twin | exit 0 (cond 2 excludes — out-of-class) |
| 6 | GREEN-agents-override | `"If the repo has `docs/ship-flow/_mods/foo.md`, read that override first"` (mirrors `agents/science-officer-em.md:16-18`) | exit 0 (proves qualifier vocab constraint c) |
| 7 | GREEN-json-noise | `"docs/ship-flow/_mods/foo.md"` double-quoted inside a JSON array (mirrors `_mods/ship-flow-lint.md:60-62`), twin present, adopter absent | exit 0 (proves backtick-only scoping, constraint a) |
| 8 | GREEN-self-reference | scanned file **is** `$root/plugins/ship-flow/_mods/foo.md` itself, containing its own unqualified `` `docs/ship-flow/_mods/foo.md` `` (mirrors the real `_mods/reverse-recovery-audit.md:9-10` header) | exit 0 (proves constraint d — **found during this plan stage**, not in design's green-set table; see note below) |
| 9 | green-on-real-repo-after-fix | `run_mislocated_canonical_mods "$REPO_ROOT"` (the **real** repo root, not a scratch dir) | exit 0, zero violations — this is AC-2's "green on the repo" proof, re-checked every CI run, not a one-off manual step |

**Constraint (d) — self-reference exclusion (plan-stage finding):** `plugins/ship-flow/_mods/reverse-recovery-audit.md:9-10` itself reads *"Plugin-canonical copy. Adopting repos copy this to
`docs/ship-flow/_mods/reverse-recovery-audit.md` and MAY append a repo-specific worked example…"* —
a backtick-fenced, twin-present, adopter-absent, **unqualified** (no "when present"/"override"
token) match, exactly the shape conditions 1-3 flag. Design's green-set table (built by enumerating
every ref *site*) did not list this occurrence. It is semantically different from a load-instruction:
the mod's own file describing where *adopting* repos copy it to is never "dangling" (the twin is the
file itself). Exclusion rule: skip a match when the scanning file's repo-relative path equals
`plugins/ship-flow/_mods/<name>.md` for the very `<name>` captured in that match. Verified via case 8
above and required for case 9 (real-repo green) to hold — dropping it leaves one violation on the
real repo even after Δ1/Δ2/Δ3, breaking AC-2.

</details>

**TDD contract**:
- `red_command`: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`
- `expected_red_failure`: exit 1; all 9 cases (plus the leading existence check) report FAIL with
  reason `resolver function not yet defined` (existence check) or the per-case skip message.
- `green_command`: same command (re-run after T2+T3 land).
- `refactor_check`: none at T1 (test authoring only).

**DC**: the red_command above exits nonzero with the "resolver function not yet defined" reason
visible in output for every case. Commit: `test(check-no-dangling): add RED fixture suite for
mislocated-canonical-mod resolver (AC-2)` — pathspec
`plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`.

---

### T2 — Δ1/Δ2: re-point the two SKILL references (AC-1)

**Files**: `plugins/ship-flow/skills/ship-shape/SKILL.md:597`,
`plugins/ship-flow/skills/ship-plan/SKILL.md:502`. Independently safe to land before T3 — the
current gate does not check this reference class, so this commit changes prose only, breaks
nothing.

**Δ1** (`ship-shape/SKILL.md:597`):
- Before: `` - Reverse-recovery audit mod (brownfield: assume the abstraction exists, classify with evidence, only greenfield confirmed MISSING): `docs/ship-flow/_mods/reverse-recovery-audit.md`; plugin-canonical copy at `plugins/ship-flow/_mods/reverse-recovery-audit.md`. ``
- After: `` - Reverse-recovery audit mod (brownfield: assume the abstraction exists, classify with evidence, only greenfield confirmed MISSING): `plugins/ship-flow/_mods/reverse-recovery-audit.md` (plugin-canonical); adopter override `docs/ship-flow/_mods/reverse-recovery-audit.md` when present. ``

**Δ2** (`ship-plan/SKILL.md:502`, same shape, own parenthetical preserved):
- Before: `` - Reverse-recovery audit mod (every task creating a new file/domain/route needs a confirmed-MISSING classification line; reviewers reject greenfield tasks without it): `docs/ship-flow/_mods/reverse-recovery-audit.md`; plugin-canonical copy at `plugins/ship-flow/_mods/reverse-recovery-audit.md`. ``
- After: `` - Reverse-recovery audit mod (every task creating a new file/domain/route needs a confirmed-MISSING classification line; reviewers reject greenfield tasks without it): `plugins/ship-flow/_mods/reverse-recovery-audit.md` (plugin-canonical); adopter override `docs/ship-flow/_mods/reverse-recovery-audit.md` when present. ``

**TDD contract**: prose-only, no test asserts the changed text (`grep -rl reverse-recovery-audit
plugins/ship-flow/lib/__tests__/` = 0 hits, verified — see Test surfaces below), so there is no
RED/GREEN pair for this task itself; its DC is the AC-1 grep proof plus a full-suite regression run.

**DC**: `grep -n 'reverse-recovery-audit.md' plugins/ship-flow/skills/ship-shape/SKILL.md
plugins/ship-flow/skills/ship-plan/SKILL.md` shows both lines now leading with the
`plugins/ship-flow/_mods/...` path and containing `when present`; full local suite
(`for t in plugins/ship-flow/lib/__tests__/test-*.sh; ...`) — all pre-existing tests still pass
(120 files, zero touching this text). Commit: `fix(ship-shape,ship-plan): re-point
reverse-recovery-audit mod ref to plugin-canonical path (AC-1)` — pathspec both SKILL.md files.

---

### T3 — Δ3: additive `run_mislocated_canonical_mods` resolver pass (AC-2, AC-3)

**File**: `scripts/check-no-dangling.sh` only (extends the existing 177-line script; the 8 existing
denylist patterns and `--self-test` mode are untouched).

<details>
<summary>T3 fixture-drivability infra + resolver logic spec (raw evidence; collapsed per Principle 8 / C15)</summary>

**Fixture-drivability infra (resolves design's open "must either…or…" choice):**
1. Wrap the existing "Normal run" section (current lines 159-177: the `for label in
   "${PATTERN_ORDER[@]}"; do run_pattern_check …; done` loop through the final `exit`) in
   `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then … fi`. Zero behavior change for direct execution
   (`bash scripts/check-no-dangling.sh` still has `BASH_SOURCE[0] == $0`); makes the script safely
   `source`-able for T1's test (defines functions only, does not auto-run or `exit` the sourcing
   shell).
2. New function `run_mislocated_canonical_mods() { local root="$1"; … }` — takes an explicit root
   argument (not the global `REPO_ROOT`/`SCAN_ROOT`), so T1's fixtures can call it against a scratch
   `mktemp -d` tree without perturbing the 8 existing patterns' globals. Prints
   `  VIOLATION [mislocated-canonical-mod]: file:line:content` per hit (matching
   `run_pattern_check`'s existing print format) and returns 1 if any violation found, 0 otherwise.
3. Inside the new main-guard block, after the existing pattern loop: `if ! run_mislocated_canonical_mods
   "$REPO_ROOT"; then violations=$((violations + <hit-count>)); fi` — folds into the existing
   `violations` counter and final PASS/FAIL summary, so a real-repo regression surfaces through the
   same "FAIL: N dangling reference(s) found" message the 8 existing patterns already use.

**Resolver logic** (design's Δ3 spec, conditions 1-3, plus plan's constraint d):
- Scan: `` grep -rnoP '`docs/ship-flow/_mods/[A-Za-z0-9_-]+\.md`' "$root/plugins/ship-flow" `` with
  the same `--include`/`--exclude-dir` set as the existing patterns (backtick delimiters in the
  regex itself is what gives constraint (a) — a double-quoted JSON path never matches).
- For each hit, extract `<name>` and the scanned file's repo-relative path.
- **Constraint (d) first** (cheapest check, short-circuits the rest): if scanned-file-relpath ==
  `plugins/ship-flow/_mods/<name>.md`, skip (self-reference — see T1's fixture 8 note).
- **Cond 1**: `[ ! -f "$root/docs/ship-flow/_mods/<name>.md" ]` (adopter absent).
- **Cond 2**: `[ -f "$root/plugins/ship-flow/_mods/<name>.md" ]` (twin exists) — both resolved
  against `$root`, not `SCAN_ROOT`, per design (the paths straddle `docs/` and `plugins/`).
- **Cond 3**: build the "full logical unit" — from the hit's line number, join it with immediately
  adjacent non-blank lines belonging to the same paragraph/list-item (stop at a blank line, a new
  list marker `^\s*[-*]\s`/`^\s*\d+\.\s`, or a heading `^#`; strip a leading `>` + space from each
  line first so blockquote paragraphs — e.g. the mod-header block itself — join the same as plain
  paragraphs). VIOLATION only if the joined unit contains **none** of: `when present`, `if a
  workflow override exists`, `if the repo has`, `otherwise the plugin copy`, `adopter override`, or
  the bare token `override`.
- VIOLATION iff cond1 AND cond2 AND cond3 all hold (cond-d already short-circuited self-refs).

</details>

**TDD contract**:
- `red_command`: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`
- `expected_red_failure`: still failing at T3's *start* (carried from T1 — function doesn't exist
  until this task's commit lands).
- `green_command`: same command.
- `refactor_check`: `bash scripts/check-no-dangling.sh --self-test` still exits 0 (existing 8-pattern
  self-test unaffected — additive-only proof); `shellcheck scripts/check-no-dangling.sh` clean
  (repo already runs shellcheck-clean bash across `bin/`/`lib/`/`scripts/`; no new warnings).

**DC**: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh` exits 0,
all 9 cases PASS (including case 9, the real-repo run, now green because T2 already landed);
`bash scripts/check-no-dangling.sh` (normal run against the real repo) exits 0 unchanged; full local
suite green (AC-3). Commit: `feat(check-no-dangling): add mislocated-canonical-mod resolver pass
(AC-2)` — pathspec `scripts/check-no-dangling.sh`.

---

### Test surfaces that must move (AC-3 regression scope)

- **New**: `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh` — auto-discovered by the CI
  loop `for t in plugins/ship-flow/lib/__tests__/test-*.sh` at
  `.github/workflows/ship-flow-invariants.yml:110`. The gate itself runs at
  `.github/workflows/ship-flow-invariants.yml:136` (`Check no dangling references` step, gated on
  `steps.ship_flow_scope.outputs.source_repo == 'true'`) — this is the exact CI wiring proof verify
  needs: the new test file rides the existing auto-discovery loop (no YAML change needed), and the
  guard it pins (`scripts/check-no-dangling.sh`) is the same script the invariants workflow already
  invokes at that step, so the resolver pass added in T3 is live in CI the moment T3 merges.
- **No existing string-assertion test pins the changed text.** Verified live:
  `grep -rl reverse-recovery-audit plugins/ship-flow/lib/__tests__/` → 0 hits (119 pre-existing
  `test-*.sh` files, confirmed by direct count this session). So T2's Δ1/Δ2 break zero existing
  tests. `validate-d-references.sh` is unrelated (validates `D{N}` decision backrefs, not `_mods/`
  paths).
- Verified baseline this session: `bash scripts/check-no-dangling.sh` on the unmodified repo exits 0
  ("PASS: no dangling references found (8 patterns checked)") — confirms the current gate is blind
  to this class (matches shape/design's claim) and gives a clean before/after comparison point.

---

### Canonical Doc Actions

| Doc | Action | Rationale |
| --- | --- | --- |
| PRODUCT.md | **skip** | Mechanical doc-ref fix + additive CI guard, not a new user-facing capability. `PRODUCT.md`'s `<!-- section:capabilities -->` already lists "Mechanical CI gates: check-invariants, check-no-dangling, check-version-triple, shell + node test suites" as one row — the resolver pass extends an already-documented capability's *coverage*, it does not add a new one. No edit needed. |
| ARCHITECTURE.md | **skip** | No architecture decision — no new component, no contract change, no `<!-- section:decisions -->` row warranted for a two-line prose reconciliation plus one additive grep-class pass inside an existing gate script. |
| ROADMAP.md | **update, deferred to ship** | `reverse-recovery-audit-dangling-path` currently sits under `## Later` (line 31: *"ship-shape/SKILL.md:585 and ship-plan/SKILL.md:502 reference a nonexistent `docs/ship-flow/_mods/reverse-recovery-audit.md`…"*). This ticket does not dwell in `## Now` — appetite S, same-session shape→plan. Ship stage moves this row from `## Later` directly to `## Shipped` (skipping a `## Now` intermediate row) once the PR merges, per the same "record intent at plan, patch canonical docs at ship" convention `l3-scheduler-tick`'s plan used. Plan records the intent here; it does not patch the file (plan-stage tools do not write root canonical docs). |

Root canonical docs only (per this stage's checklist scope): PRODUCT.md, ARCHITECTURE.md,
ROADMAP.md. `plugins/ship-flow/INVARIANTS.md` is a plugin-level doc, not a root canonical doc, and
no invariant changes at v0 of this fix (matches the pattern — no new hard rule, one additive gate
pass).

### Plugin-surface confirmation

| Path | New/Modified |
| --- | --- |
| `plugins/ship-flow/skills/ship-shape/SKILL.md` | modified (Δ1, one line) |
| `plugins/ship-flow/skills/ship-plan/SKILL.md` | modified (Δ2, one line) |
| `scripts/check-no-dangling.sh` | modified (Δ3, additive: main-guard + new function + one call site) |
| `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh` | new |

Zero new `plugins/ship-flow/bin|lib` files (the gate lives at `scripts/`, outside the plugin-surface
constraint's usual `bin/lib` scope). Zero edits to any other `SKILL.md`. Zero edits to the 119
pre-existing `test-*.sh` files (verified above).

### Plan Report

- status: passed
- task_count: 3 (T1 RED test-only, T2 Δ1/Δ2 SKILL re-point, T3 Δ3 additive resolver → GREEN)
- verification_spec_count: 9 fixture cases (RED + 7 GREEN classes + 1 real-repo green), 1:1 with
  AC-2's "red on synthetic fixture, green on the fixed tree" + AC-2's "green on the repo"
- new_constraint_found_at_plan: 1 (constraint d, self-reference exclusion — not in design's
  green-set table; load-bearing for AC-2's real-repo green claim to actually hold)
- open_contract_decisions: 0 (matches shape/design)
- canonical_doc_actions: PRODUCT skip, ARCHITECTURE skip, ROADMAP update-deferred-to-ship (per
  checklist's "ROADMAP now→shipped consideration")
- ci_wiring_proof: `.github/workflows/ship-flow-invariants.yml:110` (auto-discovery loop) +
  `.github/workflows/ship-flow-invariants.yml:136` (gate invocation, `source_repo == 'true'`)
- skill_md_edits: 2 (ship-shape:597, ship-plan:502 — prose reference lines only, no instruction/gate/output-shape change)
