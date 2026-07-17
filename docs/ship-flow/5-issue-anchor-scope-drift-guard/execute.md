# Execute — Issue-anchor scope-drift guard (route-back re-anchor)

<details>
<summary>Cycle 1 (T1-T4): Execute Output, TDD Evidence, Issues Found, Knowledge Captures, Execute Report, Execute UAT, Self-Check, Hand-off to Verify — collapsed for Principle 8 (C15 artifact-verbosity); see commits `2315135`/`d2658ac`/`e504a7b`/`f5453e1`</summary>

## Execute Output

### Execution Log

| Task | Wave | Model | Status | Files Changed | Retries | Review | Commit | Est. Cost |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | W1 | sonnet | done | `plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` (new) | 0 | self-review (RED confirmed: 25/30 assertions fail on genuine absence, `bash -n` clean) | `2315135` | 1 dispatch |
| T2 | W2 | sonnet | done | `plugins/ship-flow/_mods/issue-anchor-guard.md` (new) | 1 (self-fix: own illustrative prose duplicated the resolver's start/end marker strings, breaking `awk` extraction — rewrote to avoid literal marker text outside the fenced block) | self-review (GREEN: 29/32; remaining 3 are T3-scoped) | `d2658ac` | 1 dispatch |
| T3 | W2 | sonnet | done | `plugins/ship-flow/skills/ship-shape/SKILL.md`, `plugins/ship-flow/references/doc-coupling-map.yaml` | 0 | self-review (GREEN: 32/32; `test-contribution-contract.sh` 24/24 and `test-doc-impact-gate.sh` 112/112 unaffected) | `e504a7b` | 1 dispatch |
| T4 | W3 | sonnet | done | `ROADMAP.md`, `ARCHITECTURE.md` | 0 | self-review (`git diff --check` clean; `check-invariants.sh` clean except the named pre-existing C14 finding) | `f5453e1` | 1 dispatch |

### Execute Dispatch Manifest

| Task | Parallel Group | Depends On | Owned Paths | Integration Owner | Dispatch Mode |
| --- | --- | --- | --- | --- | --- |
| T1 | serial | — | `plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | executer@5-issue-anchor-scope-drift-guard | serial |
| T2 | w2-mod | T1 | `plugins/ship-flow/_mods/issue-anchor-guard.md` | executer@5-issue-anchor-scope-drift-guard | serial |
| T3 | w2-skill | T1 | `plugins/ship-flow/skills/ship-shape/SKILL.md`; `plugins/ship-flow/references/doc-coupling-map.yaml` | executer@5-issue-anchor-scope-drift-guard | serial |
| T4 | serial | T2, T3 | `ROADMAP.md`; `ARCHITECTURE.md` | executer@5-issue-anchor-scope-drift-guard | serial |

Deviation from plan: plan's `wave_order` allowed T2 ∥ T3 in W2 (disjoint owned paths). A single ensign session executed them serially (T2 then T3) rather than fanning out to parallel sub-dispatches — same outcome, no file-ownership conflict, just no wall-clock parallelism gained.

### TDD Evidence

| Task | RED Command | Expected RED Failure | GREEN Command | REFACTOR Check | Result |
| --- | --- | --- | --- | --- | --- |
| T1 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | All assertions fail: mod file absent (DC-1/2/3/4/5/7/8a/8b) and SKILL.md has no `<!-- section:issue-anchor-guard -->` block (DC-6) | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | `bash -n plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | RED confirmed 25/30 fail (commit `2315135`); GREEN after T2+T3 land (32/32, commit `e504a7b`) |
| T2 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | DC-1/2/3/4/5/7/8a/8b fail before this task lands; DC-6 stays red until T3 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | `awk '/# issue-anchor-guard-resolver:start/{f=1;next}/# issue-anchor-guard-resolver:end/{exit}f' plugins/ship-flow/_mods/issue-anchor-guard.md \| bash -n` | RED→GREEN: DC-1/2/3/4/5/7/8a/8b all pass after `d2658ac` (29/32 overall; `shellcheck -s bash` on the extracted resolver: clean) |
| T3 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | DC-6 (pinned section + resolver invocation before Intake) fails before this task lands | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh && bash plugins/ship-flow/lib/__tests__/test-contribution-contract.sh` | `bash -n plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | RED→GREEN: DC-6 passes after `e504a7b` (32/32 full suite; `test-contribution-contract.sh` 24/24 and `test-doc-impact-gate.sh` 112/112 unaffected) |
| T4 | TDD: skip — docs-only canonical synchronization (ROADMAP/ARCHITECTURE row updates); existing `check-invariants.sh` section-tag + `patch-map.sh` CAS gates are the alternate validation | N/A | `CI=true bash plugins/ship-flow/bin/check-invariants.sh` | `git diff --check` | PASS — clean except the pre-existing, out-of-scope C14 finding on commit `cef479ff` (design-stage commit-message format issue predating this execute pass) |

### Issues Found

- The resolver's `AC-N:`/`AC-N.` line parser (used to quote acceptance criteria verbatim from `gh issue view`) requires issues to state ACs as explicit enumerated lines. The real, live issue #49 this entity is itself anchored to writes its acceptance criteria as inline prose (e.g. "(AC-1)", "(AC-4)" embedded in narrative paragraphs under "Case study"), not as `AC-N:` lines — running the guard against entity 5's own issue today would find zero matching lines and fail visible (per the non-hollow rule; correct behavior, but means the guard cannot run end-to-end against issue #49 itself until/unless #49's body is reformatted, or a looser parser is designed in a follow-up). Documented as a named residual in the mod's Rationale + References section. No auto-created entity — flagging this as a known constraint is sufficient at this scope; the fix (a more permissive issue-body AC parser, or a documented "state ACs as AC-N: lines" convention for tracker issues that want this guard) is left for the captain/verify stage to decide whether it's in-scope or a follow-up.

### Knowledge Captures

- **[D1]** When a mod's own "Invocation" prose illustrates the extraction mechanism using the literal marker strings (e.g. showing the `awk '/# foo-resolver:start/ .../ ' file` pattern inline as documentation), the extractor's first match lands on the illustrative snippet rather than the real block, silently producing an empty extraction. Contribution-contract.md avoids this by never restating the marker regex in its own prose. Any future wired mod following this pattern should describe the extraction mechanism by reference ("same pattern as X") rather than reproducing the marker literals in surrounding prose.
- skipped: false (one D1 item above; no D2-candidate this pass)

## Execute Report

status: passed
stage_cost: 1 ensign dispatch (solo session, no sub-agent fan-out); 4 tasks executed serially within it
tasks_summary: 4 done, 0 blocked, 0 needs-context-rounds
knowledge_capture: D1: 1, D2: 0

### Metrics

status: passed
duration_minutes: 90
iteration_count: 1 (one T2 self-fix cycle for the marker-extraction bug; no cross-review round)
task_count: 4
tasks_done: 4
tasks_blocked: 0
commit_count: 4

## Execute UAT

| DC | Verify Procedure | Result | Evidence |
| --- | --- | --- | --- |
| DC-1 | `test -f plugins/ship-flow/_mods/issue-anchor-guard.md && grep -q '^## Hook: pre-shape' plugins/ship-flow/_mods/issue-anchor-guard.md` | PASS | `test-issue-anchor-guard.sh` DC-1 rows |
| DC-2 | extract `# issue-anchor-guard-resolver:start`/`:end`, `bash -n` on the extract | PASS | `test-issue-anchor-guard.sh` DC-2 rows; `shellcheck -s bash` also clean |
| DC-3 | fixture `fx-reshape-with-issue` (design.md+plan.md+`issue:"#49"`, stubbed `gh`) → run resolver `emit` | PASS | `.context/ship-flow/source-diff-fx.yaml` carries all 5 CD4 fields; 3/3 canned ACs present with `met_by_existing_capability` |
| DC-4 | fixture `fx-fresh-shape` (`status: sharp`, no design.md) → run resolver `emit` | PASS | `guard_required: false`, no source-diff fields |
| DC-5 | fixture `fx-reshape-no-issue` (design.md present, no `issue:`) → run resolver `emit` | PASS | `no_issue_anchor: true` + `captain_prompt`, no fake diff |
| DC-6 | `grep -q '<!-- section:issue-anchor-guard -->'` + line-order check before `### Intake`; plus `grep` for `name: issue-anchor-guard` + bidirectional `directions:` row in `doc-coupling-map.yaml` (T3's doc-coupling row, same task, not separately DC-numbered in plan's Verification Spec) | PASS | ship-shape/SKILL.md section precedes Intake; References cites the mod path; doc-coupling row present; `test-contribution-contract.sh` and `test-doc-impact-gate.sh` unaffected |
| DC-7 | crafted `verdict: proceed` + `scope_subset_of_issue: false` fixture → resolver `validate` | PASS | non-hollow rule rejects the combo; consistent `proceed` accepted; out-of-enum `verdict` rejected (CD1 lock) |
| DC-8a | fixture `fx-empty-issue` (`issue: ""`) → run resolver `emit` | PASS | treated identically to DC-5 (`no_issue_anchor: true`) |
| DC-8b | fixture with PATH-stubbed failing `gh` → run resolver `emit` | PASS | non-zero exit, captain-visible stderr, no YAML written |
| Full local gate | `test-issue-anchor-guard.sh` + full shell suite (all `lib/__tests__/test-*.sh`, `CI=true`) + `node --test plugins/ship-flow/bin/*.test.mjs` + `check-invariants.sh` + `check-no-dangling.sh` + `check-version-triple.sh` | PASS | see per-suite results below |

## Self-Check

- typecheck: N/A — shell/Markdown slice, no typed source
- lint: PASS — `bash -n` on the test file and the extracted resolver; `shellcheck -s bash` on the extracted resolver clean; `git diff --check` clean
- unit tests: PASS — `test-issue-anchor-guard.sh` 32/32; full shell suite all green (per-suite log below); Node 79/79
- qa-only: N/A — no UI files, no visible surface
- critical-pass lite: PASS — no SQL/data-safety, race/concurrency, LLM trust-boundary, or shell-injection finding; the one honest residual (AC-line parser format expectation) is named above and in the mod's Rationale section, not hidden

### Metrics

status: passed
duration_minutes: 90
iteration_count: 1
task_count: 4

### Hand-off to Verify

<!-- section:hand-off-to-verify -->
- **commit_list**: `2315135` (T1 RED test authoring) · `d2658ac` (T2 GREEN mod+resolver) · `e504a7b` (T3 GREEN SKILL wiring + doc-coupling row) · `f5453e1` (T4 canonical doc sync)
- **dc_status**: DC-1 PASS; DC-2 PASS; DC-3 PASS; DC-4 PASS; DC-5 PASS; DC-6 PASS (includes doc-coupling row); DC-7 PASS; DC-8a PASS; DC-8b PASS.
- **tdd_evidence_summary**: T1 RED-first (25/30 fail on absence, commit `2315135`) → GREEN after T2+T3 (32/32, commit `e504a7b`). T2 RED→GREEN for DC-1/2/3/4/5/7/8a/8b (commit `d2658ac`). T3 RED→GREEN for DC-6 (commit `e504a7b`). T4: `TDD: skip -- docs-only canonical synchronization`, per plan; validated instead by `check-invariants.sh` + `git diff --check`.
- **deviations**: (1) W2's T2/T3 were disjoint-path parallel-eligible per plan but executed serially in one ensign session — no ownership conflict, just no wall-clock parallelism gained. (2) One self-fix cycle during T2: the mod's own illustrative "Invocation" prose duplicated the resolver's literal start/end marker strings, which broke `awk` extraction (matched the illustrative line as the real boundary, yielding an empty extract) — fixed by describing the extraction mechanism by reference instead of restating the marker regex; re-verified GREEN afterward. (3) Named residual (not a deviation from plan, but worth flagging to captain/verify): the AC-line parser expects `AC-N:`/`AC-N.` enumerated lines; issue #49's own real body uses inline prose references instead, so the guard cannot run end-to-end against its own anchoring issue as currently formatted — see Issues Found above.
- **render_fidelity_evidence**: N/A — non-UI entity (`affects_ui: false`).
- **context_read_receipts**: no non-root `AGENTS.md`/`CLAUDE.md` folder guidance applicable (`plugins/ship-flow/{_mods,skills,lib/__tests__,references}/**` and root canonical docs); plan's Context Manifest recorded `folder_guidance_files=[]`/`folder_guidance_skills=[]` and that was re-confirmed at execute boot.
<!-- /section:hand_off_to_verify -->

</details>

<details>
<summary>Cycle 2 (T5): shape-confirm.sh bounded intake-stamping — collapsed for Principle 8 (C15 artifact-verbosity); see commits `b9598da`/`b46dc35`/`d0668c6`</summary>

## Execute Addendum (cycle 2): T5 — shape-confirm.sh bounded intake-stamping

Route-back from verify: CD5(b) (design.md Reconciliation — bounded intake-stamping, "future entities are born anchored") was a named, captain-adjudicated decision with no task/DC/test — a silent-drop doctrine violation. Bounded scope: intake issue/tracker stamping ONLY — no change to `issue-anchor-guard.md`, no AC-N parsing, no Linear/`external_id` handling.

### TDD Evidence (cycle 2)

| Task | Expected RED Failure | GREEN Fix | Result |
| --- | --- | --- | --- |
| T5 | DC-5.1-1a/1b (folder) / DC-5.1-2 (flat) fail — zero issue/tracker handling | Extract `PITCH_ISSUE`/`PITCH_TRACKER`, conditionally stamp `issue:`/`tracker:` into pitch-only frontmatter (mirrors `instantiate-cut-project.sh`) | RED `b9598da` → GREEN `b46dc35` |

Issues found: first fixture omitted `pm_skill_receipts`, causing a wrong-reason RED (exit 10); fixed by copying the receipts block from `proposal_with_pre_mortem`. Test-fixture-only, no production implication.

Self-check: PASS — `bash -n`/`shellcheck` clean; `test-shape-confirm.sh` full suite (incl. DC-5.1-1..3); `test-issue-anchor-guard.sh` 32/32; `test-doc-impact-gate.sh` 112/112; `test-contribution-contract.sh` 24/24; `check-invariants.sh`/`check-no-dangling.sh`/`check-version-triple.sh` clean; bounded scope confirmed via `git diff --stat`.

<!-- section:hand-off-to-verify-cycle-2 -->
- **commit_list (cycle 2)**: `b9598da` (RED) · `b46dc35` (GREEN) · `d0668c6` (docs — CD5(b) marked IMPLEMENTED)
- **dc_status (cycle 2)**: DC-9 PASS (folds DC-5.1-1..3).
- **residual (unchanged from cycle 1)**: AC-line parser's `AC-N:`/`AC-N.` requirement still can't run end-to-end against issue #49's own prose-style ACs.
<!-- /section:hand-off-to-verify-cycle-2 -->

</details>

<details>
<summary>Cycle 3 (P1-1..P1-4): resolver fail-closed/derivation fixes — collapsed for Principle 8 (C15 artifact-verbosity); see commits `8028dcd`/`23d7e7e`</summary>

## Execute Addendum (cycle 3): P1-1..P1-4 — resolver fail-closed/derivation fixes

Route-back surfaced four resolver-level gaps none of T1-T5 touched: (P1-1) `validate` trusted scalars instead of deriving from `original_issue_acs[]`; (P1-2) AC-N parser dropped multiline continuation and silently accepted an empty-text heading; (P1-3) `issue:` resolution didn't distinguish same-repo `#N` from cross-repo/ambiguous refs; (P1-4) a later failed `emit` left a prior run's stale `verdict: proceed` file on disk. Bounded scope: `issue-anchor-guard.md` (resolver) + new assertions in `test-issue-anchor-guard.sh` only; `shape-confirm.sh`/`ship-shape/SKILL.md`/re-entry detection untouched.

### TDD Evidence (cycle 3)

| Task | Expected RED Failure | GREEN Fix | Result |
| --- | --- | --- | --- |
| P1-1 | DC-10: proceed accepted with zero AC rows / all-met-but-claims-unmet | `iag_ac_met_values()` + derivation-based BLOCK checks | RED `8028dcd` → GREEN `23d7e7e`, 53/53 |
| P1-2 | DC-11: multiline continuation dropped; empty-heading (mid-body/EOF) silently accepted | `iag_parse_ac_blocks()` awk state machine + `IAG_EMPTY_AC` fail-closed check | RED `8028dcd` → GREEN `23d7e7e` |
| P1-3 | DC-12: cross-repo URL / `owner/repo#N` / ambiguous ref pass through to `gh` | owner/repo-qualified-reference BLOCK before any `gh` call | RED `8028dcd` → GREEN `23d7e7e` |
| P1-4 | DC-13: later gh-failure run leaves earlier successful run's file in place; `validate` PASSes against stale path | `rm -f "$IAG_OUT_FILE"` tombstone at top of `emit` | RED `8028dcd` → GREEN `23d7e7e` |

Issues found: DC-12's first draft used the real `gh` CLI (network-dependent false green); rewrote with a would-succeed `gh` stub so RED/GREEN depends only on the guard's own parsing. Residual (named): P1-4's tombstone is last-writer-wins, not a file lock, under true concurrent `emit` overlap — out of bounded scope.

Self-check: PASS — `bash -n`/`shellcheck` clean on both commits; `test-issue-anchor-guard.sh` 53/53; `node --test` 79/79 unaffected; `check-invariants.sh` clean (C14 both variants); `check-no-dangling.sh`/`check-version-triple.sh` PASS; bounded scope confirmed via `git diff --stat` (only `issue-anchor-guard.md` + `test-issue-anchor-guard.sh`).

<!-- section:hand-off-to-verify-cycle-3 -->
- **commit_list (cycle 3)**: `8028dcd` (RED) · `23d7e7e` (GREEN)
- **dc_status (cycle 3)**: DC-10/11/12/13 PASS. Full suite 53/53 (was 32/32).
- **residual (new)**: P1-4's tombstone is last-writer-wins under true concurrent overlap.
- **residual (unchanged)**: AC-line parser still requires an explicit `AC-N:`/`AC-N.` heading.
<!-- /section:hand-off-to-verify-cycle-3 -->

</details>

<details>
<summary>Cycle 4 (P1-A/P1-B/P1-C/P2-D): Execute Addendum, TDD Evidence, Self-Check, Hand-off to Verify — collapsed for Principle 8 (C15 artifact-verbosity); see commits `fd0781f`/`3e6eeda`</summary>

## Execute Addendum (cycle 4): P1-A/P1-B/P1-C/P2-D — structural non-hollow parse, verified same-repo URL, issue+tracker pairing, AC-block indentation boundary

Route-back surfaced four gaps none of T1-T5/P1-1..P1-4 touched: (P1-A)
`validate`'s non-hollow check was a line-oriented text scan that never
checked `text:` for emptiness or `met_by_existing_capability` for a real
boolean, and could be fooled by a `text:` substring resembling that key
(phantom-row miscount); (P1-B) the resolver always cross-repo-BLOCKed a
full GitHub issue URL even for the local repo, breaking SKILL.md's
advertised full-URL intake; (P1-C) `shape-confirm.sh` stamped
`pitch.issue`/`pitch.tracker` independently, allowing a half-anchored or
malformed pair to commit while reporting success; (P2-D) the AC-block
parser absorbed any non-blank line after a heading regardless of
indentation, letting a following section masquerade as AC criteria.

Bounded scope per dispatch: `issue-anchor-guard.md` (resolver,
P1-A/P1-B/P2-D) + `shape-confirm.sh` (P1-C) + `ship-shape/SKILL.md`
(P1-B intake wording only) + new assertions in
`test-issue-anchor-guard.sh` / `test-shape-confirm.sh`. No new
features; re-entry detection and the core emit/validate flow unchanged.

### TDD Evidence (cycle 4)

| Task | Expected RED Failure | GREEN Fix | Result |
| --- | --- | --- | --- |
| P1-A | DC-14 (3): empty text, non-boolean `met_by_existing_capability` ("maybe"), and a text-embedded substring miscounted as a phantom row all pass/misderive | `iag_ac_rows_count()`/`iag_ac_row_met_value()` yq structural parse replaces `iag_ac_met_values()` | RED `fd0781f` → GREEN `3e6eeda`, 66/66 |
| P1-B | DC-15 (2): resolver BLOCKs a full GitHub URL even when owner/repo matches the local git remote | `iag_local_owner_repo()` + same-repo-verified canonicalization to `#N` | RED `fd0781f` → GREEN `3e6eeda` |
| P1-C | DC-5.1-4/5/7 (6): half-anchored pair, bad tracker enum, newline-in-issue all silently accepted and written | all-or-nothing pairing + `gh`/`linear` enum + newline gate right after extraction | RED `fd0781f` → GREEN `3e6eeda`, shape-confirm full suite green |
| P2-D | DC-16 (4): an unindented section absorbed into AC-1's text; a no-text heading + unindented section wrongly accepted with fabricated criteria | `have && /^[^[:space:]]/ { flush(); ... }` indentation-boundary rule in `iag_parse_ac_blocks()` | RED `fd0781f` → GREEN `3e6eeda` |

Issues found: none beyond the four fixes. DC-15's fixture needs
`git init` + a matching `origin` remote (mirrors real invocation);
existing no-git-init DC-12 fixtures still exercise the default BLOCK.
P1-C's newline check is the only YAML-unsafety check needed — embedded
quotes are already neutralized upstream by the existing `tr -d '"'`.

### Self-Check (cycle 4)

PASS across the board: `bash -n` + `shellcheck -s bash` on the extracted
resolver clean; `git diff --check` clean; `test-issue-anchor-guard.sh`
66/66; `test-shape-confirm.sh` full suite; `node --test
plugins/ship-flow/bin/*.test.mjs` 79/79; `test-doc-impact-gate.sh`
112/112; `test-contribution-contract.sh` 24/24; `CI=true
check-invariants.sh` clean (C14 both variants + C15 OK);
`check-no-dangling.sh` / `check-version-triple.sh` PASS. Bounded scope
confirmed via `git diff --stat` (resolver + shape-confirm.sh + SKILL.md
intake paragraph + the two test files only).

<!-- section:hand-off-to-verify-cycle-4 -->
- **commit_list (cycle 4)**: `fd0781f` (RED) · `3e6eeda` (GREEN)
- **dc_status (cycle 4)**: DC-14/15/16 PASS; DC-5.1-4/5/6/7 PASS. `test-issue-anchor-guard.sh` 66/66 (was 53/53); `test-shape-confirm.sh` full suite green (+6 assertions).
- **deviations (cycle 4)**: none — all four fixes match the dispatch's descriptions.
- **render_fidelity_evidence (cycle 4)**: N/A — non-UI entity.
- **residual (unchanged)**: P1-4's tombstone remains last-writer-wins (cycle 3); the AC-line parser still requires an explicit `AC-N:`/`AC-N.` heading (cycle 1); the model-judgment residual in the mod's own Boundary section is named+accepted, not chased.
<!-- /section:hand-off-to-verify-cycle-4 -->

</details>

## Execute Addendum (cycle 5): P1-r3-1 — guard invocation gated to existing-entity re-shape only

Route-back surfaced a real flow bug: the Issue-Anchor Guard section in `ship-shape/SKILL.md` invoked the resolver unconditionally "before Intake" regardless of directive form, so a brand-new free-text or todo-based `/shape` (no existing entity yet) could hit the resolver's "entity path not found" BLOCK — contradicting design premise A1 (the guard is for route-back re-entry on an already-shaped entity, never new-shape intake). Bounded scope per dispatch: `ship-shape/SKILL.md` (guard gating) + the resolver mod's Hook/Invocation prose (docs-only, to match) + the mod's Boundary section (residual note) + `test-issue-anchor-guard.sh` assertions + one rabbit-hole todo — no code fix for the three named shell-parser-robustness residuals, no other features.

### TDD Evidence (cycle 5)

| Task | Expected RED Failure | GREEN Fix | Result |
| --- | --- | --- | --- |
| P1-r3-1 | DC-6 (flipped): guard section still positioned BEFORE `### Intake`; DC-17 (new, 4 text assertions): guard section lacks Entity id / Free text / Todo tid / "entity path not found" gating language | Move `<!-- section:issue-anchor-guard -->` to after `### Intake`, retitled "Post-Intake ... (existing-entity re-shape only)", with explicit gating prose naming the Entity id condition and the Free text/Todo tid exclusion; `issue-anchor-guard.md`'s Hook/Invocation prose updated to match | RED `74c498d` → GREEN `b943212`, 72/72 |

Issues found: none beyond the fix itself. Residual note: design.md's Test-implications #6 and plan.md's DC-6/T3 text still say "before Intake" (pre-P1-r3-1 wording) — out of this cycle's bounded scope (not in the allowed edit list), left for verify/doc-sync to reconcile.

Self-check: PASS — `bash -n`/`shellcheck -s bash` on the extracted resolver clean; `git diff --check` clean; `test-issue-anchor-guard.sh` 72/72; `test-shape-confirm.sh` full suite unaffected; `node --test` 79/79; `test-doc-impact-gate.sh` 112/112; `test-contribution-contract.sh` 24/24; `CI=true check-invariants.sh` clean (C14 both variants + C15 OK); `check-no-dangling.sh`/`check-version-triple.sh` PASS. Bounded scope confirmed via `git diff --stat` (`ship-shape/SKILL.md`, `issue-anchor-guard.md`, `test-issue-anchor-guard.sh`, + the one todo + its ROADMAP row only).

<!-- section:hand-off-to-verify-cycle-5 -->
- **commit_list (cycle 5)**: `74c498d` (RED — DC-6 flip + DC-17 test authoring) · `b943212` (GREEN — SKILL.md guard gating + mod prose/residual note) · `6906f29` (docs — rabbit-hole todo `issue-anchor-guard-resolver-shell-parser-robustness` + ROADMAP row)
- **dc_status (cycle 5)**: DC-6 PASS (corrected polarity); DC-17 PASS (5 assertions). Full suite 72/72 (was 66/66).
- **deviations (cycle 5)**: none — the resolver's emit/validate logic itself is untouched; only the mod's Hook/Invocation prose and Boundary section changed (docs-only).
- **render_fidelity_evidence (cycle 5)**: N/A — non-UI entity.
- **residual (new, named)**: three shell-parser-robustness gaps (tombstone exit-status check, structural-yq scalar reads, Markdown-aware AC extraction) deferred to rabbit hole `issue-anchor-guard-resolver-shell-parser-robustness`, documented in the mod's Boundary section.
- **residual (unchanged)**: P1-4's tombstone remains last-writer-wins (cycle 3); the AC-line parser still requires an explicit `AC-N:`/`AC-N.` heading (cycle 1); the model-judgment residual in the mod's own Boundary section is named+accepted, not chased; design.md/plan.md's "before Intake" wording is now stale relative to the corrected wiring (see Issues Found above).
<!-- /section:hand-off-to-verify-cycle-5 -->
