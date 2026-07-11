# Self-adoption dogfood bootstrap — canonical docs + doc-impact gate — Verify

This is the **cycle-3 re-verify** (LAST automatic cycle) after two feedback-routing rounds. Cycle-1's PASS was overridden by codex-gate round-1 FAIL (3 P1, fixed cycle-2, `004456c`/`961223a`/`f030145`); cycle-2's PASS was in turn overridden by codex-gate round-2 FAIL (2 residual P1, fixed cycle-3, `2de8b87`/`670df77`). This round re-verifies the round-2 fixes against the live tree at HEAD, not execute.md's word, and restores verify.md's own C15 artifact-verbosity compliance (re-introduced by the round-2 feedback-routing append). Base for pre-existing comparisons: `7780b2a`.

## Quality Gate

| Check | Command | Result | Note |
|---|---|---|---|
| Shell suite | `for f in plugins/ship-flow/lib/__tests__/test-*.sh; do bash "$f"; done` | 101/103 pass, 2 fail | identical 2 pre-existing failures at HEAD and at base `7780b2a` — re-confirmed cycle-3 — see Known-Dirty |
| Node suite | `node --test plugins/ship-flow/bin/*.test.mjs` | 79/79 pass | zero fail — re-confirmed cycle-3 |
| Invariants | `CI=true bash plugins/ship-flow/bin/check-invariants.sh` | cycle-3: 3 FAIL pre-this-report (2 C14 + 1 C15) → 2 FAIL after (this cycle-3 report closes C15) | only the 2 known historical C14 lines remain — see Known-Dirty |
| No-dangling | `bash scripts/check-no-dangling.sh` | PASS (exit 0) | 8 patterns, 0 violations — re-confirmed cycle-3 |
| Version triple | `bash scripts/check-version-triple.sh` | PASS (exit 0) | 0.8.2 triple-matched — re-confirmed cycle-3 |
| Whitespace | `git diff --check 7780b2a HEAD` | clean (exit 0) | no trailing-whitespace/conflict-marker errors — re-confirmed cycle-3 |
| TDD ledger | `python3 plugins/ship-flow/lib/validate-tdd-ledger.py --plan plan.md --require-ledger-jsonl tdd-ledger.jsonl` | `status=pass records=7` | re-run independently — re-confirmed cycle-3 |
| doc-impact-gate unit tests | `bash plugins/ship-flow/lib/__tests__/test-doc-impact-gate.sh` | 43/43 pass | cycle-3: was 32/32 pre-round-2-fix, +11 round-2 P1-2/P1-3 residual regression assertions (Block 4c, Blocks 12-14) |
| CI-scope unit tests | `bash plugins/ship-flow/lib/__tests__/test-ship-flow-ci-scope.sh` | 8/8 pass | unchanged this cycle — re-confirmed live |

## Per-AC Verification Claims

| AC | Verdict | route_to | Evidence |
|---|---|---|---|
| AC-1 — Principle 5b enforces instead of skipping | VERIFIED | proceed | 0 `WARN [Principle 5b]` lines at HEAD vs 1 at base `7780b2a`; ARCHITECTURE.md 6/6 section markers + mermaid fences; PRODUCT/ROADMAP markers present |
| AC-2 — Routing policy is a code gate (local-equivalent scope) | VERIFIED (local-equivalent) | proceed / review (CI-run leg deferred) | fail path exits 1 with `BLOCKER`; declaration path exits 0 with `PASS`; CI step gated on `plugin_changed=='true'` — cycle-2 also confirms `github.event_name=='pull_request'` guard (P1-1) |
| AC-3 — Canonical-doc sync loop (deferred by design) | NOT YET APPLICABLE | review | `canonical-doc-sync-checker.sh` correctly `BLOCKER`s on missing review.md/ship.md — deferral is live and gated, not silent |
| AC-4 — T3 rideshare harvest vocabulary decision record | VERIFIED | proceed | `plugins/ship-flow/references/harvest-vocabulary.md` exists; 1 README reference at README.md:533 |

<details>
<summary>Full per-AC verification records (claim_source / condition / threshold / baseline / treatment / comparison) — carried over unchanged from cycle-1, independently re-confirmed this cycle</summary>

#### Verification Claim: AC-1 — Principle 5b enforces instead of skipping

| Field | Value |
|---|---|
| claim_source | `DC-AC-1` |
| condition | Root `ARCHITECTURE.md` exists with the 6 flow-map-schema section markers (mermaid for context/containers/components); `PRODUCT.md`/`ROADMAP.md` exist with patchable section markers; `check-invariants.sh` no longer skips Principle 5b |
| metric_or_observable | section-tag grep count + mermaid-fence count per section + `WARN [Principle 5b]` line count |
| threshold | 6/6 ARCHITECTURE.md markers present, mermaid fence in each of context/containers/components, 0 `WARN [Principle 5b]` lines |
| smallest_disproving_surface | `grep -c '<!-- section:' ARCHITECTURE.md` returning <6, or any `WARN [Principle 5b]` line in `check-invariants.sh` output |
| baseline | at base `7780b2a`: `ARCHITECTURE.md` absent — `check-invariants.sh` emits `WARN [Principle 5b]: ARCHITECTURE.md not found ... — skip` |
| treatment | at HEAD: `ARCHITECTURE.md` present with 6 section markers (`context`:8, `containers`:30, `components`:54, `constraints`:87, `dependencies`:106, `decisions`:121), 1 mermaid fence each in context/containers/components; `PRODUCT.md` has `section:capabilities`; `ROADMAP.md` has `section:now/next/later/not-doing/shipped` (5 markers) |
| comparison | WARN line count base=1, HEAD=0 |
| verdict | VERIFIED |
| route_to | proceed |

#### Verification Claim: AC-2 — Routing policy is a code gate, not prose (local-equivalent scope)

| Field | Value |
|---|---|
| claim_source | `DC-AC-2` |
| condition | `doc-impact-gate` checker exists, is config-driven (coupling map + declaration syntax), runs in CI gated on plugin-touching changes, and both its fail path and its declaration-accepted path are independently exercised |
| metric_or_observable | unit-suite pass count, live invocation exit codes + stdout for both paths, presence/shape of the CI workflow step |
| threshold | unit tests pass; live fail-path invocation exits 1 with a `BLOCKER` line naming the unmatched coupling; live declaration-path invocation exits 0 with a `PASS ... declaration accepted` line; CI workflow has a `doc-impact-gate` step gated on `plugin_changed == 'true'` |
| smallest_disproving_surface | any of the two live invocations returning the wrong exit code, or the CI step missing/ungated |
| baseline | at base `7780b2a`: `bin/doc-impact-gate.sh`, `lib/__tests__/test-doc-impact-gate.sh`, `references/doc-coupling-map.yaml` all absent (T2.2 RED-first premise) |
| treatment | live from the worker's own shell: `echo plugins/ship-flow/skills/ship-verify/SKILL.md > /tmp/changed.txt; bash plugins/ship-flow/bin/doc-impact-gate.sh --changed=/tmp/changed.txt --declaration=""` → `BLOCKER doc-impact: stage-skill-readme — ...`, exit 1. Same `--changed` with a valid declaration → `PASS stage-skill-readme: doc-impact declaration accepted (...)`, exit 0. `.github/workflows/ship-flow-invariants.yml` has a `doc-impact-gate (mechanical coupling gate)` step reading `PR_BODY` via env indirection |
| comparison | fail path and declaration path both behave exactly as AC-2 specifies; checker is read-only (no `--fix`/`--write`/`--apply`/`--sync`/`--repair`, confirmed rejected with exit 2) |
| verdict | VERIFIED (local-equivalent scope) |
| route_to | proceed |

**Deferred leg — live-CI-run evidence**: AC-2's acceptance text also asks for "one live CI run showing the gate evaluated on a real PR." This cannot execute pre-PR-creation. Structural readiness is verified above. This leg is explicitly **deferred-to-ship**: review/ship must cite the actual CI run against this entity's own PR. route_to: `review`.

#### Verification Claim: AC-3 — Canonical-doc sync loop runs end-to-end (deferred by design)

| Field | Value |
|---|---|
| claim_source | `DC-AC-3` |
| condition | This entity travels shape→design→plan→execute→verify→ship and ship-review's canonical-doc sync writes/skips PRODUCT/ROADMAP/ARCHITECTURE updates as pipeline output, checked by `canonical-doc-sync-checker.sh` exiting 0 |
| metric_or_observable | `canonical-doc-sync-checker.sh docs/ship-flow/1-self-adoption-dogfood-bootstrap` exit code |
| threshold | exit 0 — but only meaningful once `review.md`/`ship.md` exist; plan.md's own Verification Spec marks this row `(verify/review stage, out of plan scope)` |
| smallest_disproving_surface | checker exiting 0 right now (would mean the deferred gate isn't actually gating) |
| baseline | n/a — first run of the checker against this entity |
| treatment | `bash plugins/ship-flow/bin/canonical-doc-sync-checker.sh docs/ship-flow/1-self-adoption-dogfood-bootstrap` → `BLOCKER review-artifact: missing review.md or ship.md in docs/ship-flow/1-self-adoption-dogfood-bootstrap`, exit 1 |
| comparison | expected-and-correct current state: checker correctly refuses to pass before review/ship artifacts exist |
| verdict | NOT YET APPLICABLE — correctly deferred, confirmed live not silently assumed |
| route_to | review |

#### Verification Claim: AC-4 — T3 rideshare harvest vocabulary decision record

| Field | Value |
|---|---|
| claim_source | `DC-AC-4` |
| condition | reference file exists under `plugins/ship-flow/references/` and is linked from the plugin README's further-reading list |
| metric_or_observable | file existence + grep match count in README |
| threshold | file exists, ≥1 README reference |
| smallest_disproving_surface | `test -f` failing or 0 grep matches |
| baseline | at base `7780b2a`: file absent (T1.3 not yet landed) |
| treatment | `test -f plugins/ship-flow/references/harvest-vocabulary.md` → true; `grep -n harvest-vocabulary.md plugins/ship-flow/README.md` → 1 match at README.md:533, inside `## Further reading` |
| comparison | both conditions hold |
| verdict | VERIFIED |
| route_to | proceed |

</details>

## Runtime UAT

| Claim | Verdict | Evidence |
|---|---|---|
| doc-impact-gate.sh fail path | VERIFIED | synthetic changed file, no declaration → `BLOCKER doc-impact: stage-skill-readme …`, exit 1 |
| doc-impact-gate.sh declaration path | VERIFIED | same file + anchored declaration → `PASS stage-skill-readme: … declaration accepted`, exit 0 |
| CI=true check-invariants.sh on the worktree | VERIFIED | 0 `WARN [Principle 5b]` lines; C11/C12/C15 closed by this stage report; only the 2 known historical C14 lines remain |

### Cycle-2 P1 Fix Re-verification (live against HEAD this session, not execute.md's claims)

| P1 | Fix commit | Live repro this session | Result |
|---|---|---|---|
| P1-1 CI push-event scoping | `004456c` | `grep -A2 'doc-impact-gate (mechanical' .github/workflows/ship-flow-invariants.yml` | `if: steps.ship_flow_scope.outputs.plugin_changed == 'true' && github.event_name == 'pull_request'` — push-event bypass closed |
| P1-2 FO bypass repro | `961223a` | `doc-impact-gate.sh --declaration="doc-impact: none of these docs are affected by my change I promise"` | exit 1 (was exit 0 pre-fix) |
| P1-2 legit anchored declaration | `961223a` | `doc-impact-gate.sh --declaration="doc-impact: none — trivial typo fix, no behavior change"` | exit 0, `PASS stage-skill-readme: doc-impact declaration accepted (...)` |
| P1-3 block-array coupling map | `f030145` | `doc-impact-gate.sh --coupling-map=.../coupling-map-block-array.yaml` | exit 2, `ERROR: coupling map row 'skill-readme' ... has an empty or unparseable srcGlobs/docPaths` (hard-closed, was silent exit 0 pre-fix) |
| Regression suites | all 3 | `test-doc-impact-gate.sh`; `test-ship-flow-ci-scope.sh` | 32/32; 8/8 — both re-run green this session |

### Cycle-3 P1 Fix Re-verification (live against HEAD `3c3c760` this session; full per-case output in index.md `Stage Report: verify (cycle 3)`)

Round-2 residuals re-verified live, class-wide plus 2 NEW variants per class beyond the shipped fixtures, not just the fixture repro strings: **P1-2′** (`2de8b87`) — template-prefixed declaration + 2 NEW same-line-prefix declarations (markdown blockquote, inline code span) all exit 1 `BLOCKER`; line-start control exits 0 `PASS` — anchoring confirmed and generalizes beyond the shipped repro. **P1-3′** (`670df77`) — flow-style fixture, zero-row `couplings: []` fixture, 2 NEW hand-written variants (own empty-map file, own flow-style file), and the unrecognized-line fixture all hard-error exit 2 naming the failure — default-deny confirmed and generalizes beyond the shipped fixture text. Full FO 8-case repro battery (both original P1s + both round-2 residuals) reproduced live this session, matching results. `test-doc-impact-gate.sh` 43/43 (see Quality Gate table).

<details>
<summary>Full runtime-UAT verification records — carried over unchanged from cycle-1, independently re-confirmed this cycle</summary>

#### Verification Claim: runtime_uat — doc-impact-gate.sh fail path

| Field | Value |
|---|---|
| claim_source | `other:runtime_uat` |
| condition | worker-perspective live invocation of `bin/doc-impact-gate.sh` against a synthetic changed-file list touching a coupled srcGlob, no declaration supplied |
| metric_or_observable | exit code + stdout |
| threshold | exit 1, `BLOCKER doc-impact:` line naming the violated coupling |
| smallest_disproving_surface | exit 0 or missing BLOCKER line |
| treatment | `bash plugins/ship-flow/bin/doc-impact-gate.sh --changed=/tmp/verify-synthetic-changed.txt --declaration=""` (changed file = `plugins/ship-flow/skills/ship-verify/SKILL.md`) → `BLOCKER doc-impact: stage-skill-readme — ...`, exit 1 |
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
| treatment | `bash plugins/ship-flow/bin/doc-impact-gate.sh --changed=/tmp/verify-synthetic-changed.txt --declaration="doc-impact: none — trivial typo fix, no behavior change"` → `PASS stage-skill-readme: doc-impact declaration accepted (trivial typo fix, no behavior change)`, exit 0 |
| verdict | VERIFIED |
| route_to | proceed |

#### Verification Claim: runtime_uat — CI=true check-invariants.sh on the worktree

| Field | Value |
|---|---|
| claim_source | `other:runtime_uat` |
| condition | `CI=true bash plugins/ship-flow/bin/check-invariants.sh` re-run live on HEAD, not trusted from execute.md |
| metric_or_observable | `WARN [Principle 5b]` line count; FAIL line identities |
| threshold | 0 `WARN [Principle 5b]` lines; only known FAILs are C14 on the 2 historical shape-stage commits |
| smallest_disproving_surface | any `WARN [Principle 5b]` line, or any FAIL besides the named rows |
| treatment | cycle-1 live re-run: exit 1, 0 `WARN [Principle 5b]` lines, 2 `FAIL C14` lines + 3 verify.md-owned FAILs (C11/C12/C15, addressed by this stage report). Cycle-2 live re-run (this session, post-report): C11/C12/C15 close; only the 2 named C14 lines remain |
| verdict | VERIFIED |
| route_to | proceed |

</details>

## Known-Dirty / Degraded Checks (declared, not silently absorbed)

| # | Item | Class | Evidence | route_to |
|---|---|---|---|---|
| 1 | 2 pre-existing shell-suite failures: `test-archived-corpus-invariants.sh`, `test-merged-pr-closeout-reconciler.sh` | pre-existing, out-of-scope | Independently re-verified via scratch `git worktree add --detach 7780b2a`: both fail identically at base and at HEAD (C14 historical commits; an unrelated stale doc-string assertion). Not a regression. | ship |
| 2 | C14 fires on 2 historical commits (`695addea`, `0d0ca53e`) | pre-existing, FO-acknowledged | Predate this entity's design/plan/execute work; none of the 7 execute commits match the FAIL SHAs. | ship (scaffolding-to-main merge-order resolution) |
| 3 | AC-2 live-CI-run leg | deferred-to-ship (structural) | PR does not exist pre-verify; local-equivalent proven live (see AC-2 above). | review |
| 4 | AC-3 whole | deferred-by-design | plan.md's own Verification Spec marks AC-3 out of plan/execute/verify scope; checker confirmed live. | review |

No item above is `INCONCLUSIVE`; each has a reproducible command and a named root cause, so no `PROMPT_CAPTAIN` line is warranted.

## Verdict (cycle 1 — superseded by cycle 2 below)

**PASS** (local/mechanical scope) — proceed to review/ship.

- AC-1: VERIFIED. AC-2: VERIFIED (local-equivalent scope); live-CI-run leg deferred-to-ship. AC-3: correctly deferred-by-design to ship-review. AC-4: VERIFIED.
- Quality gate: clean apart from the 2 named pre-existing shell-suite failures and the 2 named historical C14 failures — both independently re-verified present-and-unchanged at base and HEAD.
- This verdict was overridden by the parallel codex-gate FAIL below before it could route to review/ship — see cycle-2 verdict.

## Verdict (cycle 2 — superseded by cycle 3 below)

**PASS** (local/mechanical scope) — proceed to review/ship.
All three codex-gate P1 findings are closed, each independently re-verified live against HEAD this session (not execute.md's word — see Cycle-2 P1 Fix Re-verification table above):

- **P1-1** (CI ran the declaration check on `push`, where the PR body is structurally absent) — fixed `004456c`. Live: the workflow step condition now reads `... && github.event_name == 'pull_request'`. `test-ship-flow-ci-scope.sh` 8/8.
- **P1-2** (unanchored `none` match accepted non-waiver prose) — fixed `961223a`. Live: the FO repro string now exits 1; an anchored declaration exits 0. `test-doc-impact-gate.sh` 32/32.
- **P1-3** (coupling-map parser silently fails open on unsupported YAML layouts) — fixed `f030145`. Live: the block-array fixture now hard-errors exit 2 naming the unparseable row; quote/indent variants still parse and gate correctly. `test-doc-impact-gate.sh` 32/32 (shared suite).

verify.md itself is now C11/C12/C15-compliant (this stage report): `## Panel Coverage` and `## Deferred to TODO` sections present exactly once each, body content brought under the 120-line cap via `<details>`-collapsed bulk evidence. `CI=true check-invariants.sh` re-run after this commit shows only the 2 known historical C14 lines — no C11/C12/C15, no new findings.
This verdict was overridden by the parallel codex-gate round-2 FAIL ([P1]:2) before it could route to review/ship — see cycle-3 verdict below.

## Verdict (cycle 3 — current, supersedes cycle 2)

**PASS** (local/mechanical scope) — proceed to review/ship. This is the LAST automatic cycle. Both round-2 residual P1s are closed class-wide, each independently re-verified live against HEAD `3c3c760` this session — original repro strings plus NEW variants exercised beyond the shipped fixture suite (see Cycle-3 P1 Fix Re-verification above; full per-case output in index.md `Stage Report: verify (cycle 3)`):

- **P1-2′** (declaration marker matched anywhere within a line, not anchored to line start) — fixed `2de8b87`. Live: the FO template-prefixed repro now exits 1; 2 NEW same-line-prefix variants (markdown blockquote, inline code span) also exit 1; a genuine line-start declaration still exits 0. `test-doc-impact-gate.sh` 43/43.
- **P1-3′** (coupling-map parser silent when the WHOLE map parses to zero rows, not just per-row) — fixed `670df77`. Live: the FO flow-style repro and the `couplings: []` fixture now hard-error exit 2; 2 NEW hand-written variants (own empty-map file, own flow-style file, not the shipped fixtures) confirm the fix generalizes; an unrecognized-line map also hard-errors exit 2 naming the offending line. `test-doc-impact-gate.sh` 43/43 (shared suite).

verify.md's C15 artifact-verbosity budget (pushed over by the round-2 findings append at `6d338e4`) is restored this cycle: Round 1 + Round 2 codex-gate finding text collapsed into a single `<details>` block (text unchanged, only collapsed) and the Cycle-2/Cycle-3 FO-confirmation prose reflowed to single lines (no wording changed). `CI=true check-invariants.sh` re-run after this commit shows only the 2 known historical C14 lines — no C11/C12/C15, no new findings. Shell suite 101/103 (2 pre-existing fails, identical to base), node 79/79, no-dangling PASS, version-triple PASS, `git diff --check` clean, TDD ledger pass — all independently re-confirmed live this session, not carried over from execute.md's word. No item this cycle is `INCONCLUSIVE`; no `PROMPT_CAPTAIN` line is warranted. No BLOCKING or WARNING finding routes back to execute this cycle — the loop is closed. Feedback Cycles row 2 (index.md) is marked resolved.

## Panel Coverage

- Tier: C (minimal — mechanical re-verify of 2 routed round-2 P1 residuals; no new multi-specialist dispatch this round)
- Specialists run: none newly dispatched this cycle (re-verify scope is the 2 round-2 P1 fixes + the C15 debt re-introduced on verify.md by the round-2 feedback-routing append)
- Adversarial: Claude (this verify worker) ✓; Codex ✓ — codex-gate ran rounds 1 and 2 (`## Codex Gate Findings` below, both GATE: FAIL, resolved cycles 2 and 3 respectively); a parallel Codex round-3 re-review runs at FO level per captain directive — this verdict stands independently of that review's outcome
- Pass ownership: verify_agent_worker_ownership PASS; runtime_uat PASS; workflow_ci PASS; silent_failure PASS (P1-2′/P1-3′ class-wide fail-closed fixes)
- PR Quality Score: not scored this cycle (mechanical re-verify, not a fresh multi-specialist round)
- Cross-model: YES — codex-gate rounds 1+2 findings + a parallel FO-level Codex round-3 re-review of the cycle-3 fix diff

<!-- section:codex-gate-findings -->
## Codex Gate Findings

<details>
<summary>Round 1 + Round 2 finding text (unchanged) — collapsed cycle-3 to restore the C15 artifact-verbosity budget; both rounds RESOLVED (Round 1 by cycle-2, Round 2 by cycle-3, re-verified live above)</summary>
[P1] `.github/workflows/ship-flow-invariants.yml:79` runs the gate on `push` events, but line 81 can only obtain a PR body on `pull_request`; consequently, any legitimately waived PR passes before merge and then produces a red main-branch run after merge because the declaration disappears. Restrict the step to pull-request events or provide an event-independent declaration source for push runs.
[P1] `plugins/ship-flow/bin/doc-impact-gate.sh:106` matches `none` without line anchoring or a word boundary, so text such as `doc-impact: none of these docs...` or an instructional/template sentence containing the marker is accepted as a waiver; both cases were confirmed to exit 0. Require a standalone, anchored declaration with an explicit separator, and ignore comments/template examples.
[P1] `plugins/ship-flow/bin/doc-impact-gate.sh:224` silently recognizes only one exact inline-array YAML layout, so valid adopter overrides using block arrays, single quotes, or different indentation leave `srcGlobs` empty and disable affected coupling rows without an error. Parse the declared YAML format properly or fail closed by validating every row has recognized, nonempty `srcGlobs` and `docPaths`.
FO independent confirmation (2026-07-11): P1-2 reproduced live — declaration text `doc-impact: none of these docs are affected by my change I promise` → PASS exit 0, while the no-declaration control → BLOCKER exit 1; P1-1 and P1-3 confirmed by direct source read (workflow `on: push` + `plugin_changed`-only step gating; parser case patterns match only the exact 4-space inline-array layout). Unknown-arg path exits 2 (fail-closed) — no fourth finding.
GATE: FAIL   prompt-sha256: d8894c2a002c   diff-LOC: 846   codex-version: 0.144.1   [P1]:3  [P2]:0
### Round 2 (cycle-2 fix diff fb59795..0053693, 2026-07-11)
[P1] `plugins/ship-flow/bin/doc-impact-gate.sh:116` still matches the marker anywhere within a line, so a PR-body template or quoted example such as `Example only: doc-impact: none — this is documentation` is accepted as a waiver (confirmed exit 0). Anchor the declaration to the complete line and reject quoted/template contexts.
[P1] `plugins/ship-flow/bin/doc-impact-gate.sh:250` only fails closed after recognizing a `- name:` line, so an unsupported map layout that recognizes zero rows—such as a valid YAML flow-map sequence—silently exits 0 and disables all coupling enforcement. Track recognized rows and hard-error when the document contains no parseable coupling rows, or use a real YAML parser with schema validation.
FO independent confirmation (2026-07-11): both reproduced live — template-prefixed declaration → PASS exit 0; flow-style coupling map → empty output, exit 0 (all enforcement silently disabled).
GATE: FAIL   prompt-sha256: d8894c2a002c   diff-LOC: 329   codex-version: 0.144.1   [P1]:2  [P2]:0
</details>
<!-- /section:codex-gate-findings -->

## Deferred to TODO

Deferred to TODO: 0 findings this round. The 4 Known-Dirty items above are
structurally pre-existing/out-of-scope declarations with named `route_to`
targets (ship/review), not Phase-G NIT-class findings queued via
`ship-flow:add-todos`.
