# Missing canonical mods — author or de-reference (both tiers) — Plan

### Summary

Five small, independently-verifiable commits, strictly ordered so `scripts/check-no-dangling.sh`
is never live against an unfixed repo (same invariant the sibling `reverse-recovery-audit-dangling-path`
plan established for this exact guard file): **T1** authors the missing-everywhere RED/GREEN
fixtures in `test-check-no-dangling.sh` against the unmodified resolver (test-only, safe); **T2**
fixes an independently-discovered `REPO_ROOT` off-by-one in the two dogfood integration tests this
entity's AC-3 depends on (see **Plan finding**, below — required precondition, not in shape/design);
**T3** authors `docs/ship-flow/_mods/canonical-doc-sync.md` (adopter tier); **T4** de-references
architecture-canon (3 sites) + decisions-log (1 site, F1 fold); **T5** implements the
`missing-everywhere-canonical-mod` classify-by-twin branch + F3 adopter-tree guard +
`--exclude-dir=__tests__` (F2) + aggregator update, turning T1's fixture GREEN. T3+T4 land
*before* T5 so the guard's own first real-repo run is already clean — no transient CI-red commit.

### Plan finding (BLOCKING for AC-3 as literally scoped — read before executing)

Live-verified (not re-read): `test-canonical-doc-sync-mod.sh` and `test-canonical-context-lifecycle.sh`
both compute `REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." ...)"` from
`plugins/ship-flow/lib/__tests__/integration/` — **four** `..` segments, which resolves to
`<repo>/plugins`, not the repo root (confirmed live: `ls "$REPO_ROOT/docs"` → No such file or
directory). Of the 22 integration tests that define `REPO_ROOT` this way (`grep -n
"^REPO_ROOT=" plugins/ship-flow/lib/__tests__/integration/*.sh`, 22 hits out of 28 files), 11 share
this exact 4-level bug and 10 correctly use 5 levels (`../../../../..`, e.g.
`test-check-pr-mergeable-dogfood.sh:13`) — proving 5 is correct and 4 is a bug, not a deliberate
convention (the remaining file resolves via a different base variable, `${PLUGIN_ROOT}/../..`).

Consequence for AC-3: **authoring `canonical-doc-sync.md` alone would never green
`test-canonical-doc-sync-mod.sh`** — `MOD_FILE`/`REVIEW_SKILL`/`SCHEMA_FILE`/`DOC_FORMAT` would all
keep resolving one directory too shallow (`plugins/docs/...`, `plugins/plugins/ship-flow/...`),
permanently absent regardless of what execute does. Reproduced live in a disposable scratch copy
(patched `..` count + a temp mod file dropped at the real adopter path, then deleted): **14/14 PASS**
on `test-canonical-doc-sync-mod.sh`, and `test-canonical-context-lifecycle.sh` goes from 0/10 (all
failing for the *wrong* reason — wrong directory, not missing content) to **8/10** — the 2 residual
failures (`README states canonical context control-plane meaning`,
`ship SOT names architecture updates with roadmap and product`) are a `docs/ship-flow/README.md`
wording gap (`Canonical context control plane`, `ARCHITECTURE.md Update`/`ARCHITECTURE.md updated`
absent) entirely unrelated to architecture-canon/canonical-doc-sync/decisions-log — out of this
entity's 3 ACs, not touched by T1-T5. Fixing only the 2 files this entity's AC-3 already names is
in scope (a precondition for this entity's own claim to hold); fixing the other 9 files sharing the
bug is **not** — flagged as a follow-up todo, not this entity's problem.

**Narrowed AC-3 (what this plan actually delivers, for the gate to ratify):**
(1) standalone CI tier — full green, unchanged shape.
(2) dogfood integration tier — `test-canonical-doc-sync-mod.sh` **14/14 PASS** (was 0/14);
`test-canonical-context-lifecycle.sh` **8/10 PASS** (was effectively 0/10 masked by the path bug) —
2 pre-existing, out-of-scope failures remain and are not claimed as fixed.

### Runtime commands (pinned from the existing harness)

- **Resolver test, standalone**: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`
- **Full local suite** (matches CI's "Run full ship-flow shell test suite" step,
  `.github/workflows/ship-flow-invariants.yml:110`, repo-root-relative):
  `for t in plugins/ship-flow/lib/__tests__/test-*.sh; do CI=true timeout 90 bash "$t" || echo FAILED:$t; done`
- **The guard itself**: `bash scripts/check-no-dangling.sh` (normal run, `.github/workflows/ship-flow-invariants.yml:136`)
  and `bash scripts/check-no-dangling.sh --self-test` (existing 8-pattern self-test, must stay green — additive-only).
- **Dogfood integration tier** (from repo root, per `lib/__tests__/integration/README.md` convention):
  `bash plugins/ship-flow/lib/__tests__/integration/test-canonical-doc-sync-mod.sh` and
  `bash plugins/ship-flow/lib/__tests__/integration/test-canonical-context-lifecycle.sh`.
- **AC-1 resolving-reference proof**: `grep -rn 'architecture-canon\|decisions-log' plugins/ship-flow/skills/ship-shape/SKILL.md plugins/ship-flow/skills/ship-plan/SKILL.md plugins/ship-flow/INVARIANTS.md "plugins/ship-flow/_mods/migrate-debrief-vN-to-vN+1.md.template"` → expect 0 hits.

### Serial execution order

`T1 → T2 → T3 → T4 → T5`, strictly serial (single worktree, matches the entity's S appetite).
T2/T3/T4 are mutually independent (different files) and could reorder among themselves without
breaking anything, but T3+T4 **must both land before T5** — that ordering is load-bearing (see
Summary).

---

### T1 — Resolver test, RED-fixture-only (test file, no resolver-behavior change)

**File**: `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`. The resolver function
`run_mislocated_canonical_mods` already exists (312-line resolver, landed by PR #71) — this is an
**extend-existing-function** RED, not the greenfield existence-gate RED the sibling entity used.
No edits to `scripts/check-no-dangling.sh` in this task.

**New fixtures** (append after `build_case8_self_reference`):

```bash
build_case9_missing_everywhere_red() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow" "${root}/docs/ship-flow/_mods"
  cat > "${root}/plugins/ship-flow/scanned.md" <<'MDEOF'
See the reference at `docs/ship-flow/_mods/baz.md` for details.
MDEOF
}

build_case10_missing_everywhere_qualified() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow" "${root}/docs/ship-flow/_mods"
  cat > "${root}/plugins/ship-flow/scanned.md" <<'MDEOF'
If the repo has `docs/ship-flow/_mods/baz.md`, read that override first.
MDEOF
}
```

Both use a fresh name (`baz.md`) with **no** plugin twin ever created; `mkdir -p docs/ship-flow/_mods`
scaffolds the adopter tree so Guard F3 fires once T5 lands (distinguishing these from the existing
`build_case5_no_twin`, which deliberately does *not* scaffold `docs/ship-flow/_mods` and must stay
green throughout — proof of the plugins-only-clone invariant).

**Wiring**: insert `assert_case 9 "RED-missing-everywhere-unqualified" build_case9_missing_everywhere_red 1 1`
and `assert_case 10 "GREEN-missing-everywhere-qualified" build_case10_missing_everywhere_qualified 0 ""`
after the existing `assert_case 8 ...` line. Rename `assert_case9_real_repo` →
`assert_case11_real_repo` (and its two `"case 9 (...)"` label strings → `"case 11 (...)"`), call it
last. Update the existence-check-failure fallback loop's case-description list to add
`"9 (RED-missing-everywhere-unqualified)"` / `"10 (GREEN-missing-everywhere-qualified)"` and rename
`"9 (green-on-real-repo-after-fix)"` → `"11 (green-on-real-repo-after-fix)"`. Update the file's
header comment ("9 fixture cases") to "11 fixture cases".

**Generalize the count regex** (line 144, required now so T5 doesn't need a second touch to this
file): `grep -c '^  VIOLATION \[mislocated-canonical-mod\]'` →
`grep -cE '^  VIOLATION \[(mislocated|missing-everywhere)-canonical-mod\]'`. Harmless pre-T5 (no
`missing-everywhere-canonical-mod` label exists yet to miscount).

**TDD contract**:
- `red_command`: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`
- `expected_red_failure`: case 9 fails — `expected exit 1, got exit 0` (today's resolver still
  `continue`s on no-twin, per Cond 2 at `check-no-dangling.sh:229`, unmodified until T5). All other
  cases (1-8, 10, 11) stay PASS — this file's existing behavior is otherwise untouched.
- `green_command`: same command, re-run after T5.
- `refactor_check`: none (test authoring only).

**DC**: red_command above shows exactly one new FAIL (`case 9 (RED-missing-everywhere-unqualified)`)
with the exit-code mismatch reason; all pre-existing cases (renumbered 11's real-repo check
included) still PASS unchanged. Commit: `test(check-no-dangling): add missing-everywhere RED
fixture (AC-2)` — pathspec `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`.

---

### T2 — Fix REPO_ROOT off-by-one in the two dogfood integration tests (plan finding, precondition for AC-3)

**Files**: `plugins/ship-flow/lib/__tests__/integration/test-canonical-doc-sync-mod.sh:9`,
`plugins/ship-flow/lib/__tests__/integration/test-canonical-context-lifecycle.sh:9`. One-character
diff each (`4` → `5` `..` segments):

- Before: `REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"`
- After: `REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../../.." &> /dev/null && pwd)"`

Verified against the 11 other integration tests already using the 5-level form (e.g.
`test-check-pr-mergeable-dogfood.sh:13`) and by direct `cd`/`pwd` resolution from
`plugins/ship-flow/lib/__tests__/integration/` (5 segments lands at the true repo root; 4 lands
one level shallow, at `<repo>/plugins`).

**TDD contract**: this is itself the RED-to-GREEN pivot for the *diagnostic accuracy* of both
tests, not a new fixture — no separate test-of-a-test exists (matches the pattern: no test asserts
another test's internal path math). DC is the direct before/after run of each file.
- `red_command` (baseline, current buggy state): `bash plugins/ship-flow/lib/__tests__/integration/test-canonical-doc-sync-mod.sh` → 0/14 pass (mod not found — but for the *wrong* reason, wrong directory); `bash .../test-canonical-context-lifecycle.sh` → 0/10 pass (same wrong-directory cause for every check).
- `green_command`: same two commands after the one-line fix — live-verified this session: `test-canonical-doc-sync-mod.sh` moves to **5/14 pass** (Block 4 only — mod not authored yet at this point in the sequence; T3 hasn't landed), now failing Blocks 1-3 for the *correct* reason (`canonical-doc-sync mod exists` genuinely absent, not path-shadowed) — `MOD_FILE` still resolves to a real, correctly-located, currently-absent path; `SCHEMA_FILE`/`DOC_FORMAT`/`REVIEW_SKILL` now resolve to the real files and their content already satisfies Block 4.
- `refactor_check`: none (single-line path fix, two files, no shared helper to regress).

**DC**: `grep -n 'REPO_ROOT=' plugins/ship-flow/lib/__tests__/integration/test-canonical-doc-sync-mod.sh plugins/ship-flow/lib/__tests__/integration/test-canonical-context-lifecycle.sh` shows both now
using `../../../../..`; running both tests shows `REVIEW_SKILL`/`SCHEMA_FILE`/`DOC_FORMAT`-dependent
checks passing (Block 4 of the doc-sync test, 6 of the 10 lifecycle checks) even though the mod
doesn't exist yet. Commit: `fix(integration-tests): correct REPO_ROOT off-by-one in
canonical-doc-sync/context-lifecycle tests (AC-3 precondition)` — pathspec both files.

**Not in scope**: the other 9 integration tests sharing the same 4-level bug
(`test-copilot-bot-head-guard.sh`, `test-distill-reference-first-report.sh`,
`test-parallel-stage-contract.sh`, `test-pr-merge-claude-challenge-gate.sh`,
`test-pr-merge-fo-receipts.sh`, `test-pr-title-format.sh`, `test-sync-workflow-sot.sh`,
`test-verify-agent-worker-ownership-contract.sh`, `test-workflow-sot-sync.sh`) — flagged as a
follow-up todo, not touched here (this entity's ACs name only the two tests above).

---

### T3 — Author `docs/ship-flow/_mods/canonical-doc-sync.md` (AC-1, adopter tier)

**File** (new): `docs/ship-flow/_mods/canonical-doc-sync.md`. Content contract — 9 grep-pinned
assertion groups from `test-canonical-doc-sync-mod.sh` Blocks 1-3 plus
`test-canonical-context-lifecycle.sh`'s `Silent omission` check, each kept on a single physical
line where the source test requires same-line co-occurrence (Block 3's
`grep -q 'PRODUCT.md.*exactly once for the parent umbrella'`):

```markdown
# Canonical Doc Sync — timing + umbrella closeout

Canonical context docs: `ARCHITECTURE.md`, `PRODUCT.md`, `ROADMAP.md`. This mod defines when
ship-review patches each doc, and the umbrella-closeout rule for parent pitch/epic entities.

## Update timing

- ARCHITECTURE.md updates only on an `architecture-impact` block or another durable architecture change (new component, contract, or decision).
- Internal-only diffs never trigger it alone: prompt text changes and workflow reports are explicitly out of scope.
- PRODUCT.md updates when the entity changes a capability the product surfaces.
- ROADMAP.md updates when the entity's row moves stage (e.g. Now to Shipped).
- Every skip records an explicit skip-rationale row in review.md. Silent omission of a canonical doc update is a review-blocking defect.

## Hook: umbrella-closeout

Required when the entity is a `shaped-child`, `pitch`, `epic`, or carries `children:`, and it is the last open child of its parent umbrella.

- ROADMAP.md: the parent umbrella row moves Now/Next to Shipped exactly once for the parent umbrella; the last child to close performs the move, earlier children skip it.
- PRODUCT.md updates exactly once for the parent umbrella when a capability changed, on the same last-open-child trigger.
- If the last child merges before the closeout patch lands, a follow-up PR completes the umbrella closeout instead of blocking the merge.
```

**Verified live** (disposable copy, deleted after): dropped exactly this content at the real
adopter path against a REPO_ROOT-fixed copy of the test → `test-canonical-doc-sync-mod.sh`
**14/14 PASS**. Execute must **not** touch `ship-review/SKILL.md` (`umbrella closeout` substring),
`entity-body-schema.yaml` (`umbrella_closeout`), or `doc-format.md` (`Umbrella Shipped Row` /
`Architecture Patch` / `durable architecture change`) — all 5 Block-4 surfaces already carry the
required text (re-verified this session); editing them is out of this task's scope and unnecessary.

**TDD contract**:
- `red_command`: `bash plugins/ship-flow/lib/__tests__/integration/test-canonical-doc-sync-mod.sh`
  (run only after T2 lands, so the failure is legible) → 5/14 (Block 4 only), `canonical-doc-sync
  mod exists` FAIL leading the list.
- `green_command`: same command → 14/14 PASS.
- `refactor_check`: `bash plugins/ship-flow/lib/__tests__/integration/test-canonical-context-lifecycle.sh`
  goes from 7/10 (T2-only state, live-verified this session — the 3 failures are the 2 pre-existing
  README-wording gaps plus the `Silent omission`-dependent check) to 8/10 (the `Silent omission`
  check flips; the 2 residual README-wording failures are pre-existing and out of scope, see Plan
  finding).

**DC**: both commands above produce the stated counts. Commit: `feat(canonical-doc-sync): author
adopter-tier mod content contract (AC-1)` — pathspec `docs/ship-flow/_mods/canonical-doc-sync.md`.

---

### T4 — De-reference architecture-canon (3 sites) + decisions-log (1 site, F1 fold)

Prose-only removal; no test pins this text (`grep -rl 'architecture-canon\|decisions-log'
plugins/ship-flow/lib/__tests__/` → 0 hits, verified live). "Ref gone" per design's own AC-1
table (not a re-point) — none of these three files currently consume `canonical-doc-sync.md`
either, so re-pointing would invent a new, untrue coupling; deletion is the honest fix.

**Δ1** `plugins/ship-flow/skills/ship-shape/SKILL.md:596` — delete the line:
`` - Architecture-canon mod: `docs/ship-flow/_mods/architecture-canon.md`. ``

**Δ2** `plugins/ship-flow/skills/ship-plan/SKILL.md:501` — delete the line:
`` - Architecture-canon mod: `docs/ship-flow/_mods/architecture-canon.md`. ``

**Δ3** `plugins/ship-flow/_mods/migrate-debrief-vN-to-vN+1.md.template:33` (non-fenced echo, out of
the resolver's pattern reach — AC-1 owns it, not the guard) — delete the line:
`echo "Reference: plugins/ship-flow/_mods/architecture-canon.md for mod pattern."`

**Δ4** `plugins/ship-flow/INVARIANTS.md:199` (F1 fold — the class-wide guard would otherwise
mechanically flag this third missing-everywhere mod; deferring would self-red the entity's own
guard on the real repo, per the design gate's CONFIRMED note):
- Before: `` - Each flip MUST append a decisions.md row (see `docs/ship-flow/_mods/decisions-log.md`) ``
- After: `- Each flip MUST append a decisions.md row.`

**TDD contract**: prose-only, no RED/GREEN pair (no test asserts the removed text). DC is the AC-1
grep proof plus a full-suite regression run.

**DC**: `grep -rn 'architecture-canon\|decisions-log' plugins/ship-flow/skills/ship-shape/SKILL.md
plugins/ship-flow/skills/ship-plan/SKILL.md plugins/ship-flow/INVARIANTS.md
"plugins/ship-flow/_mods/migrate-debrief-vN-to-vN+1.md.template"` → 0 hits; full local suite
(`for t in plugins/ship-flow/lib/__tests__/test-*.sh; ...`) unchanged (129 pre-existing files, zero
touching this text). Commit: `fix(ship-shape,ship-plan,invariants,migrate-debrief): de-reference
dangling architecture-canon and decisions-log mods (AC-1, F1)` — pathspec all four files.

---

### T5 — `missing-everywhere-canonical-mod` classify-by-twin branch (AC-2, AC-3)

**File**: `scripts/check-no-dangling.sh` only (extends the existing 312-line resolver; the 8
denylist patterns, `--self-test`, and constraint (d) self-reference exclusion are untouched).

**(a) Add `--exclude-dir=__tests__` to the resolver's own grep** (F2, line 193) — surgical, this
grep call only, **not** the shared `EXCLUDE_DIRS`/`EXCLUDE_ARGS` the 8 denylist patterns use:
```
hits=$(grep -rnoE '`docs/ship-flow/_mods/[A-Za-z0-9_-]+\.md`' \
  --include="*.sh" --include="*.md" --include="*.yaml" \
  --include="*.json" --include="*.ts" --include="*.rb" \
  "${EXCLUDE_ARGS[@]}" --exclude-dir="__tests__" \
  "${root}/plugins/ship-flow" 2>/dev/null || true)
```
Required because `test-check-no-dangling.sh` itself contains literal, twin-absent
`` `docs/ship-flow/_mods/foo.md` ``/`` bar.md `` fixture text (cases 1, 5, 8) that would otherwise
newly match the classify-by-twin branch below on the real-repo scan and self-red case 11.
Confirmed safe: `grep -rl '`docs/ship-flow/_mods/' plugins/ship-flow/lib/__tests__ --include="*.sh"
--include="*.md" -l` → only `test-check-no-dangling.sh` and the already-excluded
`integration/README.md`.

**(b) Replace lines 222-229** (adopter/twin path setup + old Cond 1/Cond 2) with a classify branch:
```bash
    local adopter_path="${root}/docs/ship-flow/_mods/${name}.md"
    local plugin_path="${root}/plugins/ship-flow/_mods/${name}.md"

    # Cond 1: adopter file absent.
    [[ -f "$adopter_path" ]] && continue

    # Classify by twin presence (both paths resolved against root, not
    # SCAN_ROOT — the two trees straddle docs/ and plugins/).
    local label
    if [[ -f "$plugin_path" ]]; then
      label="mislocated-canonical-mod"        # unchanged class: adopter absent, twin present.
    else
      # Missing-everywhere: adopter absent AND twin absent. Guard (F3): only
      # fire when the adopter tree exists — a plugins-only extraction ships
      # neither file and must stay green (preserves #71 clone-safety).
      [[ ! -d "${root}/docs/ship-flow/_mods" ]] && continue
      label="missing-everywhere-canonical-mod"
    fi
```
Cond 3 (qualifier check, lines 231-238) is unchanged and applies to both classes.

**(c) Replace the hardcoded label in the VIOLATION echo** (line 242):
`echo "  VIOLATION [mislocated-canonical-mod]: ${file}:${lineno}:${content}"` →
`echo "  VIOLATION [${label}]: ${file}:${lineno}:${content}"`.

**(d) Generalize the aggregator count** (line ~300):
`mislocated_count=$(printf '%s\n' "$mislocated_output" | grep -c '^  VIOLATION \[mislocated-canonical-mod\]')`
→ `mislocated_count=$(printf '%s\n' "$mislocated_output" | grep -cE '^  VIOLATION \[(mislocated|missing-everywhere)-canonical-mod\]')`.

**Verified real-repo green-set** (post T3+T4, live enumeration of every backtick-fenced adopter-path
ref in `plugins/ship-flow/` outside `_archive`/`_debriefs-evidence`/`_plans`/`integration`):
`pr-merge` (adopter present, Cond 1 skips), `contribution-contract`/`reverse-recovery-audit`/
`science-officer-em` (twin present, mislocated class, already qualified or N/A — unaffected),
`canonical-doc-sync` (adopter now present, Cond 1 skips — T3), architecture-canon/decisions-log
(refs gone — T4), `foo`/`bar` test fixtures (excluded by F2). Zero remaining missing-everywhere
candidates — case 11 (real-repo) is green the moment T5 lands, no transient CI-red commit.

**TDD contract**:
- `red_command`: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`
- `expected_red_failure`: carried from T1 — case 9 still failing (function doesn't classify
  missing-everywhere until this commit).
- `green_command`: same command → 11/11 PASS (case 9 flips; case 10 and case 11 stay green
  throughout, per the "assertion count identical, only PASS/FAIL flips" convention).
- `refactor_check`: `bash scripts/check-no-dangling.sh --self-test` still exits 0 (existing
  8-pattern self-test unaffected); `bash scripts/check-no-dangling.sh` (normal run) exits 0 on the
  real repo (AC-2's "green on the repo" proof).

**DC**: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh` exits 0,
11/11 PASS; `bash scripts/check-no-dangling.sh` exits 0 unchanged; full local suite green (AC-3
standalone tier). Commit: `feat(check-no-dangling): add missing-everywhere-canonical-mod classify
branch (AC-2)` — pathspec `scripts/check-no-dangling.sh`.

---

### Test surfaces that must move (AC-3 regression scope)

- **`plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`** — 2 new cases (9, 10) + 1 renamed
  (9 → 11) + count-regex generalization (line 144) + header comment update. Auto-discovered by the
  CI loop `for t in plugins/ship-flow/lib/__tests__/test-*.sh`
  (`.github/workflows/ship-flow-invariants.yml:110`).
- **`plugins/ship-flow/lib/__tests__/integration/test-canonical-doc-sync-mod.sh`** — REPO_ROOT fix
  (T2) + content contract satisfied (T3) → 14/14.
- **`plugins/ship-flow/lib/__tests__/integration/test-canonical-context-lifecycle.sh`** — REPO_ROOT
  fix (T2) + `Silent omission` satisfied (T3) → 8/10 (2 residual, out-of-scope failures — see Plan
  finding).
- **No other `test-*.sh` asserts the de-referenced prose** (verified live: `grep -rl
  'architecture-canon\|decisions-log' plugins/ship-flow/lib/__tests__/` → 0 hits, 129 standalone +
  28 integration files scanned) — T4 breaks zero existing tests.
- Verified baseline this session: `bash scripts/check-no-dangling.sh` → `PASS: no dangling
  references found (8 patterns checked)`; `CI=true timeout 90 bash
  plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh` → 10/10 PASS (pre-T1 baseline).

---

### Canonical Doc Actions

| Doc | Action | Rationale |
| --- | --- | --- |
| PRODUCT.md | **skip** | `<!-- section:capabilities -->` already lists "Mechanical CI gates: check-invariants, check-no-dangling, check-version-triple, shell + node test suites" as a capability row; this entity extends that gate's *coverage* and fixes a doc-authoring gap, it does not add a new user-facing capability. |
| ARCHITECTURE.md | **skip** | No new component, contract, or decision — one additive resolver classify-branch inside an existing gate script, one new mod content file, four prose deletions, and a two-file test-harness path fix. Nothing rises to `<!-- section:decisions -->` weight. |
| ROADMAP.md | **skip at plan; ship adds a Shipped row directly** | This entity has **no existing Now/Next/Later row** to move (verified: `grep -n 'missing-canonical\|check-no-dangling' ROADMAP.md` only matches the unrelated `reverse-recovery-audit-dangling-path` Later row) — it is hackathon-2-sourced (issue #77), not roadmap-groomed. Ship stage appends a `## Shipped` row on merge, matching the same-session shape→plan hackathon cadence `c14-fo-dispatch-contract` and `ship-stage-debrief-closeout` used. Plan records intent here; plan-stage tools do not write root canonical docs. |

Root canonical docs only (per this stage's checklist scope): PRODUCT.md, ARCHITECTURE.md,
ROADMAP.md. `plugins/ship-flow/INVARIANTS.md` (touched by T4/Δ4) is a plugin-level doc, not a root
canonical doc — no invariant *rule* changes, only a dangling-parenthetical removal.

### Plugin-surface confirmation

| Path | New/Modified |
| --- | --- |
| `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh` | modified (T1: 2 new fixtures + rename + regex generalization; T5: none further) |
| `plugins/ship-flow/lib/__tests__/integration/test-canonical-doc-sync-mod.sh` | modified (T2: REPO_ROOT one-line fix) |
| `plugins/ship-flow/lib/__tests__/integration/test-canonical-context-lifecycle.sh` | modified (T2: REPO_ROOT one-line fix) |
| `docs/ship-flow/_mods/canonical-doc-sync.md` | new (T3, adopter tier) |
| `plugins/ship-flow/skills/ship-shape/SKILL.md` | modified (T4/Δ1, one line removed) |
| `plugins/ship-flow/skills/ship-plan/SKILL.md` | modified (T4/Δ2, one line removed) |
| `plugins/ship-flow/_mods/migrate-debrief-vN-to-vN+1.md.template` | modified (T4/Δ3, one line removed) |
| `plugins/ship-flow/INVARIANTS.md` | modified (T4/Δ4, parenthetical removed) |
| `scripts/check-no-dangling.sh` | modified (T5: additive classify branch + exclude-dir + label + aggregator) |

Zero new `plugins/ship-flow/bin|lib` files — the guard lives at `scripts/` (outside the plugin
surface), the only new file is the adopter-tier mod under `docs/`. Zero edits to any other
`SKILL.md`. Zero edits to the other 154 pre-existing `test-*.sh`/`integration/test-*.sh` files
(128 of 129 standalone + 26 of 28 integration, verified live, this session).

### Plan Report

- status: passed
- task_count: 5 (T1 RED test-fixture, T2 REPO_ROOT precondition fix, T3 mod authoring, T4 four
  de-references, T5 GREEN classify-branch)
- verification_spec_count: 11 fixture cases in `test-check-no-dangling.sh` (9 pre-existing + 2 new,
  1 renamed) + 14-check + 10-check dogfood integration proofs
- new_constraint_found_at_plan: 1 — **REPO_ROOT off-by-one** in the two named dogfood integration
  tests (independently discovered, verified live by reproducing 14/14 and 8/10 in a disposable
  scratch copy); not present in shape or design, load-bearing for AC-3 to be satisfiable at all
- open_contract_decisions: 0
- canonical_doc_actions: PRODUCT skip, ARCHITECTURE skip, ROADMAP skip-at-plan (no existing row;
  ship appends Shipped directly)
- ci_wiring_proof: `.github/workflows/ship-flow-invariants.yml:110` (auto-discovery loop) +
  `.github/workflows/ship-flow-invariants.yml:136` (guard invocation, `source_repo == 'true'`)
- skill_md_edits: 2 (ship-shape:596, ship-plan:501 — bullet removal only, no instruction/gate/output-shape change)
- residual_known_gap: `test-canonical-context-lifecycle.sh` stays 2/10 red after this entity
  (`docs/ship-flow/README.md` "Canonical context control-plane" + "ARCHITECTURE.md Update" wording)
  — pre-existing, unrelated to this entity's 3 ACs, not claimed as fixed; recommend a follow-up
  todo for both this and the other 9 integration tests sharing the REPO_ROOT bug pattern
