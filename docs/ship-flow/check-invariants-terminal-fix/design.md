# check-invariants terminal misclassification fix — Design

### Summary

**Contract-bearing → full design (NOT trivial-pass).** The predicate change is one line, but it
alters *which entities the 5 `_entity_is_terminal`-gated checks scan* = corpus semantics. Six active
entities flip terminal→active; the suite flips green→RED because a real masked entity
(`roborev-migration-receipt-merge-semantics`) surfaces pre-existing violations. That behavioral
blast radius is exactly the "contract-bearing" trigger — the mechanical size does not earn the
Phase 0 fast-path. **Verdict: PROCEED.** One refinement beyond shape's literal enumeration is
flagged below (drop the `verdict: PASSED` branch too) — taxonomically forced, empirically zero-risk.

### Trivial-pass eligibility (checklist item 1) — honest evaluation

| Fast-path criterion | Holds? |
| --- | --- |
| Change is mechanical (1-line predicate) | Yes |
| Change is behavior-neutral (no corpus-semantics shift) | **No** — 6 entities re-classify; 5 checks change what they scan; CI exit flips 0→1 |
| No new masked findings surfaced | **No** — un-masks 25 orphan-header ERRORs + 1 C1 FAIL (AC-2 by design) |

Two "No"s ⇒ contract-bearing. Full design.md required (this file). This matches the stage-def
"Bad" it warns against: shipping a corpus-semantics change without naming which checks/tests move.

### The exact new predicate (checklist item 2a)

`plugins/ship-flow/bin/check-invariants.sh:59-62` — replace line 61 only.

- **Before:** `grep -qE '^(status:[[:space:]]*(done|ship|shipped)|completed:|shipped:|verdict:[[:space:]]*PASSED)' "$f" 2>/dev/null`
- **After:**  `grep -qE '^status:[[:space:]]*done[[:space:]]*$' "$f" 2>/dev/null`

Rationale — README taxonomy (`docs/ship-flow/README.md:54-55`) marks **only `done`** as
`terminal: true`. Every other current branch is a misclassification of the same class:

| Dropped branch | Why it is not terminal | Flagged by |
| --- | --- | --- |
| `completed:` (bare key) | matches an **empty** frontmatter key, not a value — the original bug | shape (AC-1) |
| `shipped:` (bare key) | not a taxonomy field at all | shape (AC-1) |
| `status: ship` | `ship` = review stage, **active** (README:50-52) | shape refinement |
| `status: shipped` | not in the status enum (README:98) | shape refinement |
| **`verdict: PASSED`** | `verdict` (README:99) is set at verify/final stage; a `verdict: PASSED` entity sits at `status: verify\|ship` = **active**, not `done` | **design (see flag)** |

**FLAG — `verdict: PASSED` drop exceeds shape's literal enumeration.** The checklist named
"empty-completed accident AND ship/shipped branches"; it did not name `verdict: PASSED`. But the
governing clause — *"only status done = terminal per README taxonomy"* — is an exact predicate spec
that `verdict: PASSED` violates identically to `status: ship`. Shape already dropped `ship`/`shipped`
though both are "latent today — no active entity exists"; by parity, the equally-latent
`verdict: PASSED` drops too. **Empirical zero-risk:** no current entity carries `verdict: PASSED`
(grep over all 9 entities = 0 hits), so on today's corpus the `status: done`-only predicate is
byte-for-behavior identical to keeping the verdict branch — it removes a latent future-misclassifier,
not any present classification. Surfaced here so the design gate can veto; recorded in decisions.md.

Scoping note (out of scope, unchanged): the grep runs over the whole file, not just frontmatter —
identical to the old predicate. Frontmatter-only anchoring is a separate latent concern, not this fix.

### The 5 gated check sites + expected corpus-honesty diff (checklist item 2b)

Call sites (all `_entity_is_terminal "$f" && continue` / SKIP): `:195` check_section_tag_coverage,
`:607` check_structural_parity_dc, `:662` check_pitch_assumptions (WARN-only), `:823`
check_pre_mortem_emitted, `:842` check_pol_probe_invoked.

Empirically pre-computed on **this worktree (origin/main baseline)** by running the suite with old
vs. fixed predicate and diffing (source reverted; not committed). 6 entities flip terminal→active:
`roborev-migration-receipt-merge-semantics`, `shape-confirm-instance-awareness`,
`7-review-surface-shape-not-plan`, `check-invariants-terminal-fix` (this entity), `l3-scheduler-tick`,
`reverse-recovery-audit-dangling-path` (matches shape's "6 of 9" count; the specific slugs differ
from shape because shape read a staler tree). Expected new output:

| Check site | New findings after fix | Blocking? |
| --- | --- | --- |
| `:195` section-tag-coverage | 25× `ERROR [Principle 5a] … orphan header` on **roborev** (partial tags) + 5× grandfather `WARN` (zero-tag entities) | **ERRORs block** |
| `:823` pre-mortem-emitted | 1× `FAIL C1 … roborev … missing pre_mortem field` (non-trivial pitch) | **blocks** |
| `:662` pitch-assumptions | 2× `WARN [Principle 5c] pattern=pitch but has 0 critical assumptions` (7-review, roborev) | WARN only |
| `:607` structural-parity-dc | none | — |
| `:842` pol-probe-invoked | none | — |

Net: suite exit **0 → 1 (RED)**, driven entirely by one real masked entity (`roborev`). This RED is
AC-2 corpus-honesty, **not** a regression. Execute must reproduce this before/after as AC-2 evidence;
verify/CI RED here is the expected end-state (captain bulk attestation covers the surfaced findings).

### RED fixture spec (checklist item 3) — zero current coverage

`grep _entity_is_terminal` over `plugins/ship-flow/lib/__tests__/` = **0 hits**; no test pins the
predicate text or any dropped branch. The fixture fills a real gap. Add cases to existing
`plugins/ship-flow/lib/__tests__/test-check-invariants.sh` (reuses `create_mock_plugin_dir()` + the
`assert_*` helpers already there; auto-run by the CI loop `for t in …/test-*.sh`,
ship-flow-invariants.yml:110).

**Driver:** `--check section-tag-coverage` on a `--test-fixture <dir>`, asserting on the
terminal-SKIP line (`check-invariants.sh:196`: `SKIP [Principle 5a]: <label> — terminal historical
entity`). This observes the predicate's classification decision *directly* — line 195's terminal-SKIP
precedes all tag/grandfather logic, so the fixture needs only `status:`/`completed:` frontmatter (no
pattern/appetite/tags). Each RED case flips exactly one dropped branch:

| Fixture entity (frontmatter) | Old predicate | Fixed predicate | Assertion | RED-before / GREEN-after |
| --- | --- | --- | --- | --- |
| `status: shape` + empty `completed:` | terminal (bug) | active | stderr **lacks** "terminal historical entity" | proves empty-completed drop (AC-1 core) |
| `status: ship` | terminal | active | stderr **lacks** it | proves `status: ship` drop |
| `status: verify` + `verdict: PASSED` | terminal | active | stderr **lacks** it | proves `verdict: PASSED` drop (design flag) |
| `status: done` + `completed: <ts>` | terminal | terminal | stderr **contains** it | GREEN both — over-correction guard |

The done-entity control is load-bearing: no real `status: done` entity exists in the corpus today, so
only a fixture proves the predicate still classifies genuine terminals correctly (guards against a
too-loose fix). Each RED row fails against current `bin/check-invariants.sh` and passes after the
one-line edit — RED-before-GREEN satisfied per row.

### AC-2 surfacing format (checklist item 4)

Findings are **surfaced, never silently fixed** (captain attestation `「原則上是都核准」`). Execute writes,
in `docs/ship-flow/check-invariants-terminal-fix/execute.md`, a **`## AC-2 Surfaced Findings`**
section: the before/after suite diff (exit 0→1) plus a table `entity | check | finding | pre-existing?`.
Concretely for today's corpus: `roborev-migration-receipt-merge-semantics` → 25 orphan-header ERRORs
(missing `<!-- section: -->` tags) + missing `pre_mortem:` field; `7-review-surface-shape-not-plan`
& `roborev` → 0 critical assumptions (WARN). Execute must **NOT** add `pre_mortem:`/section tags to
roborev, must **NOT** touch any other entity's body — those are separate entities' remediation, out of
scope for the predicate fix. The only source edit is line 61; the only new file is the fixture test.

### Test surfaces that must move (stage-def "Good")

- **Move WITH the change:** `plugins/ship-flow/lib/__tests__/test-check-invariants.sh` — add the 4
  fixture cases above (new DC block, e.g. `DC-TERMINAL`).
- **Pins the changed text?** None. `grep _entity_is_terminal|terminal historical` over `__tests__/` →
  the only "is_terminal"/"terminal" hits (`test-merged-pr-closeout-reconciler.sh`) are an unrelated
  force-push variable + a git fixture commit message. The 1-line edit breaks **0** of the ~120 shell
  tests.
- **AC-3 dual-env:** Env 1 `bash …/test-check-invariants.sh` (fixture unit); Env 2
  `CI=true bash plugins/ship-flow/bin/check-invariants.sh` (ship-flow-invariants.yml:98, full corpus).
  Predicate is a portable POSIX grep (`[[:space:]]`, `$` anchor) — no BSD/GNU divergence expected;
  both envs still required because `CI=true` can flip pipefail/boolean behavior elsewhere.

### Design Report

- Mode: **contract-bearing (full design)** — 1-line edit, but corpus-semantics shift (6 entities
  re-classify, 5 checks change scan set, CI exit flips) disqualifies the Phase 0 trivial-pass.
- Predicate: `^status:[[:space:]]*done[[:space:]]*$` — drops empty-completed accident, `status:
  ship`/`shipped`, bare `shipped:`, **and `verdict: PASSED`** (design refinement; taxonomically forced,
  empirically zero-hit today — flagged for gate veto, logged in decisions.md).
- Corpus diff: empirically measured (old vs fixed run, reverted) — 6 flip; roborev drives RED (25
  ERRORs + 1 C1 FAIL); 5 grandfather WARNs + 2 pitch WARNs non-blocking; :607/:842 add nothing.
- RED fixture: `--check section-tag-coverage` on `--test-fixture`, assert terminal-SKIP presence;
  4 cases (empty-completed / ship / verdict:PASSED RED + done-entity GREEN control); zero prior coverage.
- AC-2 format: `## AC-2 Surfaced Findings` table in execute.md; no entity bodies touched.
- Test impact: 0 of ~120 tests pin the changed text (verified).
- status: passed
- verdict: PROCEED
- open_design_questions_remaining: 1 (gate confirm/veto of the `verdict: PASSED` drop; default = drop)
