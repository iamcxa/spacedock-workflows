# Self-adoption dogfood bootstrap — canonical docs + doc-impact gate — Verify

All evidence below was re-executed live against the worktree HEAD
(`f5a8fd2`, branch `spacedock-ensign/1-self-adoption-dogfood-bootstrap`) in
this session — no claim is accepted from execute.md without an independent
re-run. Base for pre-existing comparisons: `7780b2a` (dispatch base, the
plan-resume commit immediately before T1.1).

## Quality Gate

| Check | Command | Result | Note |
|---|---|---|---|
| Shell suite | `for f in plugins/ship-flow/lib/__tests__/test-*.sh; do bash "$f"; done` | 101/103 pass, 2 fail | re-run independently this session; identical 2 failures at HEAD and at base `7780b2a` (see Known-Dirty below) |
| Node suite | `node --test plugins/ship-flow/bin/*.test.mjs` | 79/79 pass | zero fail |
| Invariants | `CI=true bash plugins/ship-flow/bin/check-invariants.sh` | exit 1 | zero `WARN [Principle 5b]` lines; only failure is C14 on 2 historical commits (see Known-Dirty below) — no other FAIL/WARN beyond Principle 5a grandfather-skip WARNs on the 3 shaped-child files (pre-existing, unrelated to this entity's ACs) |
| No-dangling | `bash scripts/check-no-dangling.sh` | PASS (exit 0) | 8 patterns, 0 violations |
| Version triple | `bash scripts/check-version-triple.sh` | PASS (exit 0) | 0.8.2 triple-matched |
| Whitespace | `git diff --check 7780b2a HEAD` | clean (exit 0) | no trailing-whitespace/conflict-marker errors across all 7 execute commits |
| TDD ledger | `python3 plugins/ship-flow/lib/validate-tdd-ledger.py --plan plan.md --require-ledger-jsonl tdd-ledger.jsonl` | `status=pass records=7` | re-run independently |
| doc-impact-gate unit tests | `bash plugins/ship-flow/lib/__tests__/test-doc-impact-gate.sh` | 20/20 pass | re-run independently |
| CI-scope unit tests | `bash plugins/ship-flow/lib/__tests__/test-ship-flow-ci-scope.sh` | 7/7 pass | re-run independently |

## Per-AC Verification Claims

#### Verification Claim: AC-1 — Principle 5b enforces instead of skipping

| Field | Value |
|---|---|
| claim_source | `DC-AC-1` |
| condition | Root `ARCHITECTURE.md` exists with the 6 flow-map-schema section markers (mermaid for context/containers/components); `PRODUCT.md`/`ROADMAP.md` exist with patchable section markers; `check-invariants.sh` no longer skips Principle 5b |
| metric_or_observable | section-tag grep count + mermaid-fence count per section + `WARN [Principle 5b]` line count |
| threshold | 6/6 ARCHITECTURE.md markers present, mermaid fence in each of context/containers/components, 0 `WARN [Principle 5b]` lines |
| smallest_disproving_surface | `grep -c '<!-- section:' ARCHITECTURE.md` returning <6, or any `WARN [Principle 5b]` line in `check-invariants.sh` output |
| baseline | at base `7780b2a`: `ARCHITECTURE.md` absent — `check-invariants.sh` emits `WARN [Principle 5b]: ARCHITECTURE.md not found ... — skip` (confirmed via scratch worktree this session) |
| treatment | at HEAD: `ARCHITECTURE.md` present with 6 section markers (`context`:8, `containers`:30, `components`:54, `constraints`:87, `dependencies`:106, `decisions`:121), 1 mermaid fence each in context/containers/components; `PRODUCT.md` has `section:capabilities`; `ROADMAP.md` has `section:now/next/later/not-doing/shipped` (5 markers) |
| comparison | WARN line count base=1, HEAD=0; full `check-invariants.sh` re-run at HEAD confirms zero `WARN [Principle 5b]` anywhere in output |
| verdict | VERIFIED |
| route_to | proceed |

#### Verification Claim: AC-2 — Routing policy is a code gate, not prose (local-equivalent scope)

| Field | Value |
|---|---|
| claim_source | `DC-AC-2` |
| condition | `doc-impact-gate` checker exists, is config-driven (coupling map + declaration syntax), runs in CI gated on plugin-touching changes, and both its fail path and its declaration-accepted path are independently exercised |
| metric_or_observable | unit-suite pass count, live invocation exit codes + stdout for both paths, presence/shape of the CI workflow step |
| threshold | 20/20 unit tests pass; live fail-path invocation exits 1 with a `BLOCKER` line naming the unmatched coupling; live declaration-path invocation exits 0 with a `PASS ... declaration accepted` line; CI workflow has a `doc-impact-gate` step gated on `plugin_changed == 'true'` |
| smallest_disproving_surface | any of the two live invocations returning the wrong exit code, or the CI step missing/ungated |
| baseline | at base `7780b2a`: `bin/doc-impact-gate.sh`, `lib/__tests__/test-doc-impact-gate.sh`, `references/doc-coupling-map.yaml` all absent (T2.2 RED-first premise, matches plan.md resume note) |
| treatment | this session, live from the worker's own shell (not execute.md's word): `echo plugins/ship-flow/skills/ship-verify/SKILL.md > /tmp/changed.txt; bash plugins/ship-flow/bin/doc-impact-gate.sh --changed=/tmp/changed.txt --declaration=""` → `BLOCKER doc-impact: stage-skill-readme — changed plugins/ship-flow/skills/ship-*/SKILL.md but coupled doc plugins/ship-flow/README.md not touched and no 'doc-impact: none — <reason>' declaration found`, exit 1. Same `--changed` with `--declaration="doc-impact: none — trivial typo fix, no behavior change"` → `PASS stage-skill-readme: doc-impact declaration accepted (trivial typo fix, no behavior change)`, exit 0. `.github/workflows/ship-flow-invariants.yml` has a `doc-impact-gate (mechanical coupling gate)` step, `if: steps.ship_flow_scope.outputs.plugin_changed == 'true'`, reading `PR_BODY` via env indirection (no direct interpolation — matches the R3 boundary in design.md) |
| comparison | fail path and declaration path both behave exactly as AC-2 specifies; checker is read-only (no `--fix`/`--write`/`--apply`/`--sync`/`--repair`, confirmed rejected with exit 2 by `test-doc-impact-gate.sh` Block 6) |
| verdict | VERIFIED (local-equivalent scope) |
| route_to | proceed |

**Deferred leg — live-CI-run evidence**: AC-2's acceptance text also asks for "one live CI run showing the gate evaluated on a real PR." This cannot execute pre-PR-creation — no PR exists yet at the verify stage. Structural readiness is verified above (workflow step exists, correctly gated, both invocation paths proven locally). This leg is explicitly **deferred-to-ship** — review/ship must cite the actual CI run against this entity's own PR as the closing evidence, per plan.md's own Verification Spec language for AC-2 ("live CI run of this PR is the 'one real PR' evidence, cited at review"). Not a gap in this stage's work; a structural impossibility of the stage's timing. route_to: `review` (ship-review cites the real run).

#### Verification Claim: AC-3 — Canonical-doc sync loop runs end-to-end (deferred by design)

| Field | Value |
|---|---|
| claim_source | `DC-AC-3` |
| condition | This entity travels shape→design→plan→execute→verify→ship and ship-review's canonical-doc sync writes/skips PRODUCT/ROADMAP/ARCHITECTURE updates as pipeline output, checked by `canonical-doc-sync-checker.sh` exiting 0 |
| metric_or_observable | `canonical-doc-sync-checker.sh docs/ship-flow/1-self-adoption-dogfood-bootstrap` exit code |
| threshold | exit 0 — but only meaningful once `review.md`/`ship.md` exist; plan.md's own Verification Spec marks this row `(verify/review stage, out of plan scope)` |
| smallest_disproving_surface | checker exiting 0 right now (would mean the deferred gate isn't actually gating) |
| baseline | n/a — this is the first run of the checker against this entity |
| treatment | live re-run this session: `bash plugins/ship-flow/bin/canonical-doc-sync-checker.sh docs/ship-flow/1-self-adoption-dogfood-bootstrap` → `BLOCKER review-artifact: missing review.md or ship.md in docs/ship-flow/1-self-adoption-dogfood-bootstrap`, exit 1 |
| comparison | expected-and-correct current state: the checker correctly refuses to pass before review/ship artifacts exist, confirming the gate is live (not a stub) rather than silently absorbed as N/A |
| verdict | NOT YET APPLICABLE — correctly deferred, confirmed live not silently assumed |
| route_to | review (ship-review is the owning stage; this AC is explicitly out of plan/execute/verify scope per plan.md) |

#### Verification Claim: AC-4 — T3 rideshare harvest vocabulary decision record

| Field | Value |
|---|---|
| claim_source | `DC-AC-4` |
| condition | reference file exists under `plugins/ship-flow/references/` and is linked from the plugin README's further-reading list |
| metric_or_observable | file existence + grep match count in README |
| threshold | file exists, ≥1 README reference |
| smallest_disproving_surface | `test -f` failing or 0 grep matches |
| baseline | at base `7780b2a`: file absent (T1.3 not yet landed) |
| treatment | live re-run this session: `test -f plugins/ship-flow/references/harvest-vocabulary.md` → true; `grep -n harvest-vocabulary.md plugins/ship-flow/README.md` → 1 match at README.md:533, inside the `## Further reading` list alongside `pr-merge-paths.md` (matching the pattern the AC names) |
| comparison | both conditions hold |
| verdict | VERIFIED |
| route_to | proceed |

## Runtime UAT

#### Verification Claim: runtime_uat — doc-impact-gate.sh fail path

| Field | Value |
|---|---|
| claim_source | `other:runtime_uat` |
| condition | worker-perspective live invocation of `bin/doc-impact-gate.sh` against a synthetic changed-file list touching a coupled srcGlob, no declaration supplied |
| metric_or_observable | exit code + stdout |
| threshold | exit 1, `BLOCKER doc-impact:` line naming the violated coupling |
| smallest_disproving_surface | exit 0 or missing BLOCKER line |
| baseline | n/a |
| treatment | `bash plugins/ship-flow/bin/doc-impact-gate.sh --changed=/tmp/verify-synthetic-changed.txt --declaration=""` (changed file = `plugins/ship-flow/skills/ship-verify/SKILL.md`) → `BLOCKER doc-impact: stage-skill-readme — changed plugins/ship-flow/skills/ship-*/SKILL.md but coupled doc plugins/ship-flow/README.md not touched and no 'doc-impact: none — <reason>' declaration found`, exit 1 |
| comparison | matches expected fail-path behavior exactly |
| verdict | VERIFIED |
| route_to | proceed |

#### Verification Claim: runtime_uat — doc-impact-gate.sh declaration path

| Field | Value |
|---|---|
| claim_source | `other:runtime_uat` |
| condition | same synthetic changed-file list, with a `doc-impact: none — <reason>` declaration ≥12 chars supplied |
| metric_or_observable | exit code + stdout |
| threshold | exit 0, `PASS ... declaration accepted` line |
| smallest_disproving_surface | non-zero exit or missing PASS line |
| baseline | n/a |
| treatment | `bash plugins/ship-flow/bin/doc-impact-gate.sh --changed=/tmp/verify-synthetic-changed.txt --declaration="doc-impact: none — trivial typo fix, no behavior change"` → `PASS stage-skill-readme: doc-impact declaration accepted (trivial typo fix, no behavior change)`, exit 0 |
| comparison | matches expected declaration-path behavior exactly |
| verdict | VERIFIED |
| route_to | proceed |

#### Verification Claim: runtime_uat — CI=true check-invariants.sh on the worktree

| Field | Value |
|---|---|
| claim_source | `other:runtime_uat` |
| condition | `CI=true bash plugins/ship-flow/bin/check-invariants.sh` re-run live on HEAD, not trusted from execute.md |
| metric_or_observable | `WARN [Principle 5b]` line count; FAIL line identities |
| threshold | 0 `WARN [Principle 5b]` lines; only known FAIL is C14 on the 2 historical shape-stage commits, no other FAIL |
| smallest_disproving_surface | any `WARN [Principle 5b]` line, or any FAIL besides the named C14 rows |
| baseline | n/a (invariants checker is stateless per-run) |
| treatment | live re-run this session: exit 1, 0 `WARN [Principle 5b]` lines, exactly 2 `FAIL C14` lines (commits `695addea`, `0d0ca53e`), all other checks (`DC-10`, `DC-1.4`, `DC-3.3`, `C1`-`C13`, `C15`) report `OK` |
| comparison | matches execute.md's claim exactly; independently confirmed no new C14 violation on any of the 7 execute-stage commits or the plan-resume commit `7780b2a` (`git log --oneline 7780b2a..HEAD` cross-checked against the FAIL commit SHAs — no overlap) |
| verdict | VERIFIED |
| route_to | proceed |

## Known-Dirty / Degraded Checks (declared, not silently absorbed)

| # | Item | Class | Evidence this session | route_to |
|---|---|---|---|---|
| 1 | 2 pre-existing shell-suite failures: `test-archived-corpus-invariants.sh`, `test-merged-pr-closeout-reconciler.sh` | pre-existing, out-of-scope | Independently re-verified via scratch `git worktree add --detach 7780b2a`: both fail identically at base (same root causes — C14 historical commits for the first, an unrelated stale doc-string assertion "pr merge doc scopes v1 provider support" for the second). Re-ran both at HEAD: identical failure signatures, no new/different failures. Not a regression introduced by this entity. | ship (separate remediation track; flagged for FO/captain visibility, not this entity's fix) |
| 2 | C14 (`entity-status-via-advance-stage-only`) fires on 2 historical commits | pre-existing, FO-acknowledged | `695addea` (shape-stage status migration) and `0d0ca53e` (shape-stage dispatch) predate this entity's design/plan/execute work. Confirmed via full `check-invariants.sh` re-run: exactly these 2 FAIL C14 lines, no others. `git log --oneline 7780b2a..HEAD` (the 7 execute commits) cross-checked — none match the FAIL SHAs. | ship (resolution is a scaffolding-to-main merge-order plan, per FO acknowledgment recorded in the dispatch note — not a plan/execute/verify-stage fix) |
| 3 | AC-2 live-CI-run leg | deferred-to-ship (structural, not a gap) | PR does not exist pre-verify; cannot be satisfied at this stage by definition. Local-equivalent proven live (see AC-2 claim above: CI step exists + correctly gated + both invocation paths exercised). | review (ship-review cites the real CI run against this entity's own PR) |
| 4 | AC-3 whole | deferred-by-design | plan.md's own Verification Spec marks AC-3 `(verify/review stage, out of plan scope)`. Checker confirmed live (BLOCKER on missing review.md/ship.md) — the deferral is real and gated, not a silent skip. | review (ship-review's canonical-doc-sync stage owns this) |

No item above is `INCONCLUSIVE` — each was independently re-run this session with a concrete, reproducible command and a known, named root cause. No `PROMPT_CAPTAIN` line is warranted: nothing here required the captain to resolve an ambiguity: the two shell-suite pre-existing failures and the C14 historical-commit failures are structurally identical at base and at HEAD (proving non-regression), and the two deferred ACs are deferred by the plan's own explicit scoping, not by verify-stage judgment.

## Verdict

**PASS** (local/mechanical scope) — proceed to review/ship.

- AC-1: VERIFIED.
- AC-2: VERIFIED (local-equivalent scope); live-CI-run leg deferred-to-ship (structural, named above).
- AC-3: correctly deferred-by-design to ship-review; not a verify-stage failure.
- AC-4: VERIFIED.
- Quality gate: clean apart from the 2 named pre-existing shell-suite failures and the 2 named historical C14 failures — both independently re-verified present-and-unchanged at base `7780b2a` and at HEAD, so neither is a regression introduced by this entity's 7 execute-stage commits.
- No BLOCKING or WARNING finding routes back to execute. Feedback-to target (execute) is not invoked this cycle.

A parallel Codex 5.6 cross-model EM review of the execute diff runs at FO level per captain directive; this verdict stands independently of that review's outcome, per dispatch instruction.

<!-- section:codex-gate-findings -->
## Codex Gate Findings

[P1] `.github/workflows/ship-flow-invariants.yml:79` runs the gate on `push` events, but line 81 can only obtain a PR body on `pull_request`; consequently, any legitimately waived PR passes before merge and then produces a red main-branch run after merge because the declaration disappears. Restrict the step to pull-request events or provide an event-independent declaration source for push runs.

[P1] `plugins/ship-flow/bin/doc-impact-gate.sh:106` matches `none` without line anchoring or a word boundary, so text such as `doc-impact: none of these docs...` or an instructional/template sentence containing the marker is accepted as a waiver; both cases were confirmed to exit 0. Require a standalone, anchored declaration with an explicit separator, and ignore comments/template examples.

[P1] `plugins/ship-flow/bin/doc-impact-gate.sh:224` silently recognizes only one exact inline-array YAML layout, so valid adopter overrides using block arrays, single quotes, or different indentation leave `srcGlobs` empty and disable affected coupling rows without an error. Parse the declared YAML format properly or fail closed by validating every row has recognized, nonempty `srcGlobs` and `docPaths`.

FO independent confirmation (2026-07-11): P1-2 reproduced live — declaration text
`doc-impact: none of these docs are affected by my change I promise` → PASS exit 0,
while the no-declaration control → BLOCKER exit 1; P1-1 and P1-3 confirmed by direct
source read (workflow `on: push` + `plugin_changed`-only step gating; parser case
patterns match only the exact 4-space inline-array layout). Unknown-arg path exits 2
(fail-closed) — no fourth finding.

GATE: FAIL   prompt-sha256: d8894c2a002c   diff-LOC: 846   codex-version: 0.144.1   [P1]:3  [P2]:0
<!-- /section:codex-gate-findings -->
