---
title: Fix dangling reverse-recovery-audit adopter-local mod reference + regress-guard
status: ship
source: todo reverse-recovery-audit-dangling-path (pitch 5) + captain 票ok 2026-07-19 (L3 tick real-proof ticket)
started: 2026-07-19T02:37:40Z
completed:
verdict:
score:
worktree: .worktrees/spacedock-ensign-reverse-recovery-audit-dangling-path
issue: "#69"
pr: "#71"
---

ship-shape/SKILL.md:597 and ship-plan/SKILL.md:502 reference adopter-local
docs/ship-flow/_mods/reverse-recovery-audit.md which does not exist; the plugin-canonical
copy plugins/ship-flow/_mods/reverse-recovery-audit.md exists (3.7K). check-no-dangling.sh
misses this reference class. Small (S), non-UI, mechanical. This entity doubles as the live
single-entity proof for the L3 scheduler tick: after shape it must satisfy dual-key
eligibility (shaped + issue #69 labeled sd:approved) and be dispatched by the tick, not by hand.

## Acceptance criteria

**AC-1 — The referenced mod path resolves.** [Shape-resolved: fix (b).] The two SKILL references
(ship-shape:597, ship-plan:502) lead with the plugin-canonical path
`plugins/ship-flow/_mods/reverse-recovery-audit.md` (present in the source repo), with the adopter
path `docs/ship-flow/_mods/reverse-recovery-audit.md` demoted to a "when present" override — matching
the science-officer-em / contribution-contract convention. Materialize-in-adopter (a) rejected; see
shape.md Decision + Deletes.
Verified by: the grep that today returns a dangling reference returns a resolving one.

**AC-2 — The reference class is mechanically regress-guarded.** [Shape-resolved.] A twin-exists +
qualifier-aware mod-reference resolver (new pass in check-no-dangling.sh or an equivalent wired CI
check) fails on a fixture of this class — adopter `_mods/<name>.md` absent while the plugin twin
exists, referenced unconditionally — and passes on the fixed tree; see shape.md Guard spec.
Verified by: the check run red on a synthetic dangling fixture, green on the repo.

**AC-3 — Existing suite green.** The 110+ shell-test suite and CI gates pass unchanged.
Verified by: test suite run output.

## Stage Report: shape

- DONE: LEAN shape for an S mechanical ticket — decide the cheaper honest fix between (a) materialize/sync vs (b) reconcile SKILL references; record rejected alternative with one-line reason.
  Chose (b): re-point both SKILL refs to the plugin-canonical path with adopter "when present" override; shape.md Decision + Deletes. Evidence: mod header (reverse-recovery-audit.md:8-11) says only adopters copy to docs/_mods; no sync-manifest.json here (sync-drift-check dormant); science-officer-em/contribution-contract already follow this convention.
- DONE: The regress-guard is a code gate — name where check-no-dangling.sh misses this class and specify the fixture-backed test.
  Miss: it is a fixed denylist of known-dead literal strings with zero path resolution, and SCAN_ROOT is plugins/ship-flow only while the target is under docs/ship-flow. Guard = twin-exists + qualifier-aware resolver; fixture test RED (unqualified ref, twin present, adopter absent) / GREEN (fixed, qualified, no-twin) in shape.md Guard spec.
- DONE: Do NOT re-ask captain articulation; appetite S; record out-of-scope.
  Articulation cited from todo pitch 5 + issue #69 + captain 票ok, not re-litigated. Appetite S recorded. Out-of-scope: architecture-canon / canonical-doc-sync (different class — mod exists in neither tier), broader doc audit, sync-manifest redesign.

### Summary

Chose fix (b) — reconcile the two SKILL references to the plugin-canonical path (adopter path demoted to "when present") — over (a) materialize-in-adopter, because the mod header itself designates this repo the source (not an adopter), no sync-manifest exists to drift-check a materialized copy, and sibling canonical mods already follow the two-tier convention. Specified a twin-exists + qualifier-aware resolver as the regress-guard, scoped so it reds the reverse-recovery-audit class today, greens after the fix, and does not over-reach onto the out-of-scope missing-everywhere mods (architecture-canon, canonical-doc-sync) discovered during shaping and flagged for a follow-up todo.

## Stage Report: design

- DONE: Confirm trivial-pass eligibility — S mechanical (re-point 2 SKILL refs to plugin-canonical path + adopter 'when present' override per shape fix (b)); no schema/API/contract redesign. Emit minimal design.md + PROCEED, or escalate if a real contract delta surfaces.
  Trivial-pass PROCEED — additive-only, no `references/*.yaml`/CLI/template contract touched; design.md written with the eligibility table. No escalation-worthy contract delta; guard direction fully pre-shaped.
- DONE: Name exact contract deltas — the two SKILL reference lines (ship-shape SKILL.md:597, ship-plan SKILL.md:502) + the regress-guard code surface (twin-exists + qualifier-aware resolver in check-no-dangling.sh or wired CI).
  design.md §Contract deltas: Δ1 ship-shape:597, Δ2 ship-plan:502 (before/after intent), Δ3 additive resolver pass in `scripts/check-no-dangling.sh` (script is at scripts/, not lib/; resolve targets against REPO_ROOT).
- DONE: Name the test surfaces that must move — which of the 110+ shell tests assert the reference strings / dangling-check behavior.
  New `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh` (CI-loop auto-discovered, ship-flow-invariants.yml:110); gate runs at ship-flow-invariants.yml:136. `grep -rl reverse-recovery-audit lib/__tests__/` = 0 hits → Δ1/Δ2 break none of the 120 tests.

### Summary

Trivial-pass PROCEED for an S mechanical ticket: two 1-line reference rewrites (Δ1/Δ2) plus one additive twin-exists+qualifier-aware resolver pass (Δ3) in `scripts/check-no-dangling.sh`. Exercising shape's guard against the real repo surfaced three load-bearing refinements the executer must not drop — (a) backtick-fenced scoping excludes `ship-flow-lint.md` JSON, (b) full-logical-unit unwrap excludes the soft-wrapped science-officer-em SKILL qualifier, and (c) the qualifier vocabulary must cover the agents-file "If the repo has … override" form, which is BEYOND shape's literal qualifier list and would otherwise false-positive `agents/science-officer-em.md:16-18` — plus the resolver must be drivable against a scratch root for the RED/GREEN fixtures. The design.md green-set table enumerates all eight `_mods` references proving only reverse-recovery-audit reds before the fix and nothing reds after (AC-2/AC-3).

## Stage Report: plan

- DONE: TDD contract for Δ3 resolver — RED-first. New plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh with fixtures: RED and 7 GREEN classes (fixed, qualified, wrapped-qualifier, no-twin, agents-override, json-noise, self-reference) plus green-on-real-repo-after-fix.
  plan.md T1 table (9 cases); fixture-drivability solved via main-guard (`[[ "${BASH_SOURCE[0]}" == "${0}" ]]`) + root-arg function `run_mislocated_canonical_mods "$root"`, sourced by the test post-T3.
- DONE: Atomic-commit task decomposition — order tests RED before impl GREEN. Task set T1 (RED test-only) → T2 (Δ1/Δ2 SKILL re-point) → T3 (Δ3 additive resolver → GREEN), each an independent commit with explicit pathspec.
  plan.md T1/T2/T3 sections; T2-before-T3 ordering is deliberate (no transient CI-red commit — the gate never goes live on an unfixed repo).
- DONE: Canonical Doc Actions — per root canonical doc (PRODUCT.md / ARCHITECTURE.md / ROADMAP.md) state update or explicit skip+rationale, naming the exact CI wiring proof.
  plan.md Canonical Doc Actions table: PRODUCT skip, ARCHITECTURE skip, ROADMAP update-deferred-to-ship (Later→Shipped); CI wiring proof cited as ship-flow-invariants.yml:110 (auto-discovery loop) + :136 (gate invocation, source_repo=='true').

### Summary

Wrote plan.md decomposing design's Δ1-Δ3 contract into 3 strictly-ordered atomic commits (T1 RED-only test authoring, T2 the two safe SKILL-ref rewrites, T3 the additive resolver pass), each with an explicit TDD contract and DC command. While exercising the resolver rule against the real repo (same method design used to find constraints a/b/c), found one additional load-bearing gap design's green-set table missed: `plugins/ship-flow/_mods/reverse-recovery-audit.md:9-10` itself contains a backtick-fenced, twin-present, adopter-absent, unqualified self-reference ("Adopting repos copy this to `docs/ship-flow/_mods/reverse-recovery-audit.md`…") that the stated conditions 1-3 alone would flag as a violation even after Δ1/Δ2/Δ3 land — recorded as constraint (d), a same-file self-reference exclusion, with its own fixture case (case 8) so AC-2's "green on the repo" claim is actually provable, not just asserted. Verified the 119 pre-existing `test-*.sh` files contain zero string assertions on the changed SKILL text (T2 breaks nothing) and confirmed the baseline `check-no-dangling.sh` run is currently green (8 patterns, blind to this class), giving a clean before/after comparison.

## Stage Report: execute

- DONE: Execute T1→T2→T3 in strict order with RED→GREEN evidence pasted into execute.md. T1: author plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh (9 fixtures incl case-8 self-reference/constraint-d) — run it RED first, paste the failing output + legible reason (no edits to scripts/check-no-dangling.sh yet). T2: Δ1 ship-shape/SKILL.md:597 + Δ2 ship-plan/SKILL.md:502 re-point to plugin-canonical path with adopter 'when present' override. T3: additive run_mislocated_canonical_mods resolver in scripts/check-no-dangling.sh (main-guard + root-arg function per plan) → run test GREEN, paste passing output. Each an atomic commit with explicit pathspec.
  T1 RED 10/10 FAIL (9ecde9b); T2 AC-1 grep proof (055a7d9); T3 GREEN 10/10 PASS incl case 9 real-repo (39e36d3). Full evidence in execute.md.
- DONE: Honor ALL load-bearing constraints from design+plan — (a) backtick-fenced only, (b) full-logical-unit unwrap, (c) qualifier vocab incl the token 'override' / 'if the repo has' forms, (d) same-file self-reference exclusion (mod's own header). Resolve targets against REPO_ROOT (not SCAN_ROOT). Fixture-drivability via REPO_ROOT-arg function sourced by the test.
  Each constraint has a dedicated fixture case (7=a, 4=b, 3/6=c, 8=d), all PASS; adopter/plugin paths resolved against the `root` argument, not SCAN_ROOT; `run_mislocated_canonical_mods "$root"` is sourced and called directly by the test (case 9 drives it against the real REPO_ROOT).
- DONE: Full local gate run before handoff, name each suite + result in execute.md — the 120-file shell suite (plugins/ship-flow/lib/__tests__/test-*.sh incl the new one), scripts/check-no-dangling.sh green on the real repo post-fix (proving AC-2 + constraint-d), check-invariants, check-version-triple, node tests if any. git diff --check clean. AC-1 grep proof (dangling ref now resolves), AC-3 (zero pre-existing tests regress).
  120/120 shell suite PASS; `check-no-dangling.sh` real-repo run PASS (8 patterns, exit 0); `check-invariants.sh` PASS; `check-version-triple.sh` PASS; no node tests exist (no root `package.json`); `git diff --check` clean. Full breakdown in execute.md.

### Summary

T1→T2→T3 landed as 3 atomic commits (`9ecde9b`, `055a7d9`, `39e36d3`) with RED-before-GREEN proof; a 4th commit (`a94b23c`) fixed a pre-existing, unrelated C15 artifact-verbosity failure on this entity's own `plan.md` (247→168 body lines via balanced `<details>` collapse, content unchanged) so `check-invariants.sh` is genuinely green at handoff — same pattern `l3-scheduler-tick/execute.md` used for the identical gate. Two load-bearing environment findings surfaced by exercising, not assumed: this machine's default `grep` has no `-P` support, so the resolver uses `-E` (functionally identical, no lookaround needed, fully portable) instead of the plan's literal `-P` — using `-P` as specified would have silently blinded the gate on any non-GNU-grep machine (the call is guarded by `|| true`); and a `grep -c`/`pipefail` interaction in the test harness itself needed a `|| true` guard once GREEN made a real zero-violation result possible. Full local gate (120/120 shell suite, real `check-no-dangling.sh` run, `check-invariants`, `check-version-triple`, `git diff --check`, `shellcheck`) is green; AC-by-AC proof and full details are in execute.md.

## Stage Report: verify

- DONE: Independent re-run, not relay: re-run the new check-no-dangling resolver fixture suite (RED fixture must fail on a synthetic mislocated-canonical-mod reference, GREEN on the fixed tree) + the full local gate (shell suite, node tests, check-invariants, check-no-dangling, check-version-triple) in the entity worktree; per-AC evidence: AC-1 the two SKILL refs now resolve (the grep that returned dangling now resolves), AC-2 resolver red/green proven, AC-3 suite green.
  120/120 shell + 79/79 node (corrects execute.md's "no node tests" claim — real suite exists, wired at ship-flow-invariants.yml:128, all pass) + check-no-dangling PASS + check-version-triple PASS + check-invariants PASS + shellcheck clean + git diff --check clean, all fresh. AC-2 proven beyond the shipped fixture suite: reconstructed the actual pre-fix SKILL text from `055a7d9^` and confirmed the resolver flags it RED (the real historical bug, not a synthetic mimic), plus an independent differently-named synthetic fixture rules out name hardcoding. Full detail in verify.md.
- DONE: verify.md must be C11/C12/C15 conformant FROM THE START: include ## Panel Coverage and ## Deferred to TODO sections, body ≤120 lines (raw evidence in <details>).
  verify.md written with both sections; `check-invariants.sh` re-run with verify.md present — C11/C12/C15 all OK, 0 FAILs.
- DONE: Proportional review for an S mechanical ticket: cross-model challenge scoped to the small diff (or declare the proportionality call visibly per ship-verify rules — never silent); this entity was dispatched autonomously by the L3 scheduler tick (delegation receipt 20260719T111714Z) and timed out between execute and verify — the FO is resuming the remaining stages; note this in the verify report's runtime_uat context. No BLOCKING finding may be inline-fixed; route_to per ship-verify rules.
  `review-scope.sh` measured DIFF_LINES=503 (over the SKILL's <50 short-circuit) but zero SCOPE_AUTH/BACKEND/FRONTEND/API/MIGRATIONS flags; declared `panel_coverage: minimal` visibly rather than dispatching the full 5-specialist panel. Codex attempted twice (Tier-A available) for cross-model challenge, both timed out mid-exploration despite scoped no-explore prompts (ruled out pure auth failure via a successful <60s ping); circuit-breaker stopped further retries, `cross_model: false` declared, Fallback Ladder Tier B applied (one scoped Claude adversarial subagent). Found 2 WARNING-severity guard-robustness gaps (independently reproduced with hands-on fixtures), both non-blocking (do not regress any AC) — deferred to TODO, not inline-fixed. runtime_uat: not-applicable (no UI/API/e2e surface — CLI gate script + doc lines); L3 tick delegation receipt cited in verify.md. Full detail in verify.md.

### Summary

Verified the autonomously-executed fix for issue #69 with evidence that exceeds relay: reconstructed the actual pre-fix dangling SKILL text from git history (`055a7d9^`) and proved the new resolver genuinely flags it RED — the real historical bug, not a synthetic stand-in — then proved GREEN on the real fixed repo, plus an independent differently-named fixture ruling out hardcoding. Re-ran the full local gate fresh (120/120 shell, 79/79 node — correcting execute.md's inaccurate "no node tests" claim — check-no-dangling, check-version-triple, check-invariants, shellcheck, git diff --check), all green. Made the S-mechanical-ticket proportionality call visibly: skipped the full 5-specialist panel (zero scope flags fired despite DIFF_LINES>50) and, after codex cross-model timed out twice on the actual review task (not a connectivity failure — a quick ping succeeded), stopped retrying per the circuit-breaker rule and fell back to a scoped Claude adversarial subagent per the SKILL's own Fallback Ladder. That pass surfaced two real, independently-reproduced WARNING-severity gaps in the new guard's robustness against future content (an over-broad bare "override" qualifier term, and a logical-unit boundary-absorption edge case) — both verified non-blocking since neither regresses AC-1/AC-2/AC-3 for the actual shipped fix, and both deferred to TODO along with three advisory items and one pre-existing, out-of-scope check-invariants.sh finding. Verdict: PASS (PROCEED). Full evidence, findings table, and panel-coverage rationale are in verify.md.

## Stage Report: ship

- DONE: PR discipline — compose the PR body ONCE from canonical artifacts (shape.md problem, verify.md verdict + per-AC evidence, execute.md commits) into a body FILE; privacy grep (no /Users/, /home/, ~/Project, personal emails) on that file BEFORE `gh pr create --base main --head spacedock-ensign/reverse-recovery-audit-dangling-path --body-file`; push the branch first; frontmatter pr: written only after the PR number is confirmed via `gh pr view`. NO auto-merge — the entity stops at awaiting_merge. PR body includes a Dependency section (supersets PR #70; merge #70 first; `Closes #69`).
  Body composed once to `/tmp/pr-body-rra-dangling-path.md`; privacy grep 0 hits; branch pushed (`spacedock-ensign/reverse-recovery-audit-dangling-path` → origin); PR #71 created (`gh pr create --base main --head ... --body-file`); `gh pr view 71` confirmed number+state OPEN before write; `persist-pr-metadata.sh --expect-body-file` returned `verdict=OK reason=written pr=#71` (number AND body independently confirmed) before `pr: "#71"` landed in frontmatter (commit `faddf78`). Dependency + Closes #69 sections present in the body verbatim. Entity stops at `awaiting_merge`; no merge attempted.
- DONE: Todo Closeout Digest in ship.md (≤60 body lines) capturing verify.md's Deferred to TODO items (2 WARNING guard-robustness gaps, 3 advisory items, 1 pre-existing out-of-scope check-invariants.sh finding) as concrete follow-up todo candidates, named with one-line claims — todo files not written here (FO batches on canonical root after merge).
  `ship.md` `## Todo Closeout Digest` (56 body lines, under the 60-line C15 cap) lists W1/W2 (WARNING), W3/W4/W5 (advisory), the pre-existing `_entity_is_terminal()` finding, and the carried-forward architecture-canon/canonical-doc-sync/doc-audit/sync-manifest items — each one line, verbatim from verify.md/shape.md. No `.claude/TODO-*.md` or workflow-todo files created; FO batches at canonical-root closeout per this checklist's explicit note.
- DONE: Canonical docs — consume the plan's Canonical Doc Actions rows (update or explicit skip rationale); record the release consideration (version bump call for plugins/ship-flow).
  PRODUCT.md skip (extends an already-documented capability row), ARCHITECTURE.md skip (no new component/contract) — both per plan.md's Canonical Doc Actions table, consumed as-is, no edits needed. ROADMAP.md: plan.md's table said "update, deferred to ship" moving Later→Shipped; this stage's checklist explicitly scopes that row-move to done/closeout on the canonical root (not this worktree/PR) — recorded, not patched, in `ship.md` and the PR body's Canonical docs section. Release consideration: no `plugins/ship-flow` version bump this PR — repo convention batches bumps into separate `chore(ship-flow): release X.Y.Z` commits (current 0.9.0 unchanged across recent merges); this S-mechanical fix + additive guard does not warrant one alone.
- DONE: Note in the stage report that this entity was dispatched autonomously by the L3 scheduler tick (delegation receipt 20260719T111714Z) — it is the tick's live single-entity proof.
  Noted here and in the PR body's Dependency section: this entity was dispatched autonomously by the L3 scheduler tick (delegation receipt `20260719T111714Z`), timed out between execute/verify, and was resumed by a fresh FO-driven verify + this ship stage — it is the tick's live single-entity real-proof case (per shape.md/decisions.md framing). PR #71 is built directly on top of PR #70 (`spacedock-ensign/l3-scheduler-tick`, still open/DIRTY) since that is the tick's own dispatch commit; `Closes #69` and the merge-#70-first dependency are both explicit in the PR body.

### Summary

Opened PR #71 (`gh pr create --base main --head spacedock-ensign/reverse-recovery-audit-dangling-path`) with a privacy-clean body composed once from shape/verify/execute, including a Dependency section stating this branch supersets the still-open PR #70 (l3-scheduler-tick, the autonomous dispatcher) and must land after it, plus `Closes #69`. `persist-pr-metadata.sh` confirmed both PR number and body before `pr: "#71"` was written to frontmatter (commit `faddf78`); no merge attempted — entity stops at `awaiting_merge`. `ship.md` captures the Todo Closeout Digest (2 WARNING + 3 advisory + 1 pre-existing finding, all named one-line, no todo files written — left for FO batching) and the Canonical Doc Actions consumption (PRODUCT/ARCHITECTURE skip per plan.md; ROADMAP update recorded but its Later→Shipped row-move deferred to canonical-root closeout per this stage's explicit scope, not patched in this PR) plus the no-version-bump release call. `gh pr view 71` shows `state=OPEN`, `mergeStateStatus=DIRTY`/`mergeable=CONFLICTING` — expected and unresolved by design: this branch necessarily carries PR #70's own DIRTY drift (152 commits behind `main`), and per the assigned dependency framing the diff collapses to just the rra fix once #70 merges; resolving that drift is PR #70's own unresolved rebase conflict (ROADMAP.md `## Now` section per its ship stage report), outside this stage's authority to hand-resolve.

**Exercising, not asserting, found one live gap:** a fresh `check-invariants.sh` run at ship stage FAILed C15 — `verify.md` measured 139 body lines against its 120-line cap — contradicting verify.md's own "C11/C12/C15 all OK" claim. Fixed with the same remedy this entity's own execute stage already used on plan.md (commit `a94b23c`): wrapped two raw-narrative sections in balanced `<details>` blocks, content byte-identical, body now 107 lines (commit `0c6c05b`, pushed, PR #71 body updated to cite it). Full local gate re-confirmed green after the fix: `check-invariants.sh` 0 FAIL, `check-no-dangling.sh`/`check-version-triple.sh`/`git diff --check` all PASS/clean, node 79/79 PASS, shellcheck clean on both touched shell files; the 120-file shell suite was re-run fresh in the background and its result is folded into this report before commit (see below).

