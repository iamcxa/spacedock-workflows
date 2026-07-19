---
title: Missing canonical mods — author or de-reference (both tiers)
status: ship
source: hackathon-2 Wave 2c (todo missing-canonical-mods-both-tiers; rra shape discovery)
started: 2026-07-19T16:04:46Z
completed:
verdict:
score:
worktree: .worktrees/spacedock-ensign-missing-canonical-mods
issue: "#77"
pr: "#79"
---

Time budget: 1h00m. architecture-canon.md and some canonical-doc-sync.md references resolve in
NEITHER plugin nor adopter tier. Decide per reference: author the missing mod (only if its content
is genuinely load-bearing and recoverable from context) or reconcile/remove the dangling reference.
Extend the resolver/denylist so this class is mechanically guarded.

## Acceptance criteria

**AC-1 — Every named reference resolves or is removed.** No reference to architecture-canon.md /
canonical-doc-sync.md points at a nonexistent file in either tier; decisions recorded per reference.
Verified by: the discovery grep from rra shape returns only resolving references.

**AC-2 — Class guarded.** check-no-dangling (or equivalent) catches this missing-everywhere class.
Verified by: synthetic fixture red, repo green.

**AC-3 — Suite green both envs.**
Verified by: dual-env run output.

## Shape

Size: **S** (confirmed). Appetite / time budget: **1h00m** (from body). Articulation already
given (hackathon-2 GO + bulk attestation 「原則上是都核准」 2026-07-20) — not re-litigated.

Baseline verified against **origin/main @ 455fc84** (NOT the working tree — see Risk).

### Ground truth (origin/main)

Both mods absent in **both** tiers, all 4 paths — and neither ever existed in git history
(`git log --all` empty for every path):
- `plugins/ship-flow/_mods/architecture-canon.md` — MISSING
- `docs/ship-flow/_mods/architecture-canon.md` — MISSING
- `plugins/ship-flow/_mods/canonical-doc-sync.md` — MISSING
- `docs/ship-flow/_mods/canonical-doc-sync.md` — MISSING

### AC-1 — per-reference decision (verified, cited)

`architecture-canon.md` → **DE-REFERENCE** (do not author). 3 refs, all bibliographic:
- `plugins/ship-flow/skills/ship-shape/SKILL.md:596` — "References" bullet.
- `plugins/ship-flow/skills/ship-plan/SKILL.md:501` — "References" bullet.
- `plugins/ship-flow/_mods/migrate-debrief-vN-to-vN+1.md.template:33` — echo "… for mod pattern".
- Rationale: no live consumer reads it; no test asserts its content; no recoverable content spec
  exists anywhere; the ARCHITECTURE.md doc-timing rules it would nominally own are already owned by
  `canonical-doc-sync.md` (`test-canonical-doc-sync-mod.sh:42-45`). Execute: remove the bullets OR
  re-point ship-shape:596 / ship-plan:501 to `canonical-doc-sync.md` and genericize the template
  echo to a real mod — both cheap, both satisfy AC-1.

`canonical-doc-sync.md` → **AUTHOR / recover** (reverse-recovery: EXISTS_BROKEN, not MISSING). Wired
across live logic + schema + doc-format + 2 tests; only the file is absent (single seam):
- `plugins/ship-flow/skills/ship-review/SKILL.md:156` — unconditional live instruction "Read … →
  Hook: umbrella-closeout" (Step 2.5 closeout logic depends on it); also `:24` (soft "when present"),
  `:29` ("Reads:" list), `:461` (References bullet).
- `plugins/ship-flow/lib/__tests__/integration/test-canonical-doc-sync-mod.sh:10,36-57` — HARD-asserts
  the mod exists + Blocks 1-3 enumerate its required content (a near-complete recovery spec).
- `plugins/ship-flow/lib/__tests__/integration/test-canonical-context-lifecycle.sh:18,62` — HARD-asserts
  `grep 'Silent omission'` in the mod.
- Recoverable: the two tests' assertions form the content spec (names ARCHITECTURE/PRODUCT/ROADMAP;
  architecture-impact + durable-architecture timing; skip prompt-text/workflow-reports; Hook:
  umbrella-closeout; last-open-child; "exactly once for the parent umbrella"; PRODUCT once on
  capability change; follow-up PR; "Silent omission"); prior art in
  `docs/ship-flow/_archive/1-self-adoption-dogfood-bootstrap` (7 refs). De-reference rejected — would
  delete live umbrella-closeout behavior + 2 tests.
- **Tier: author at the adopter path `docs/ship-flow/_mods/canonical-doc-sync.md`** — every ref + both
  tests already point there, ship-review reads that path, and the tier is tracked
  (`docs/ship-flow/_mods/pr-merge.md` is tracked). Plugin-path authoring rejected: it would make the
  #71 resolver newly flag every adopter-path ref as mislocated → forced reference churn.

### AC-2 — guard gap confirmed + mechanism

Current guard `scripts/check-no-dangling.sh` (origin/main = the #71 "Mislocated-canonical-mod
resolver", `:136-236`) flags a backtick-fenced `docs/ship-flow/_mods/<name>.md` ref only when the
adopter file is absent AND the plugin-canonical **twin exists** (Cond 2, `:227`) AND no qualifier.
Both target mods have **no twin anywhere** → Cond 2 false → not flagged (the missing-everywhere class
#71 deliberately skips). Mechanism: add a missing-everywhere branch — flag a backtick-fenced
`_mods/<name>.md` ref with NEITHER adopter file NOR plugin twin AND no qualifier. Fixture (extend
`test-check-no-dangling.sh`): synthetic missing-everywhere ref → RED; repo after AC-1 fixes → GREEN.
Coverage boundary for execute: the resolver only scans backtick-fenced `docs/ship-flow/_mods/`
patterns (`:193`); the non-fenced plugin-path echo at migrate-debrief:33 is out of pattern reach —
handled by AC-1 de-reference, not the guard.

### AC-3 — current state + proof

Two envs: (1) **standalone CI plugin gate** runs `plugins/ship-flow/lib/__tests__/test-*.sh`
(top-level glob; `integration/` excluded, `ship-flow-invariants.yml:110`) + check-no-dangling —
currently **GREEN**. (2) **dogfood-host integration tier** runs `lib/__tests__/integration/test-*.sh`
— currently **RED**: `test-canonical-doc-sync-mod.sh` (14/14 fail, exit 1) and
`test-canonical-context-lifecycle.sh` (exit 1), both because `canonical-doc-sync.md` is missing
(proven by running both). Authoring the mod (AC-1) greens the integration tier; AC-3 proof = dual-env
run with standalone gate + integration tier both green.

### Out of scope

Anything beyond the three ACs; upstream spacedock binary; third-party deps; the #75
no-dangling-guard-qualifier-precision W1-W5 hardening (sibling entity — don't touch); broader
doc-reference audit; sync-manifest redesign; the branch reconciliation itself.

### Risk — BLOCKING for execute (bad news early)

The entity lives on working branch **iamcxa/muscat-v1**, which is 25 ahead / **233 behind**
origin/main; **PR #71 is NOT in this branch**. So the working tree's `scripts/check-no-dangling.sh`
is the OLD 177-line pure denylist, NOT the 312-line #71 resolver AC-2 must extend, and the
ship-review canonical-doc-sync refs at `:24`/`:29` (added post-fork on main) are absent here.
**Execute MUST baseline off origin/main** (fresh worktree from origin/main, or rebase
iamcxa/muscat-v1 onto origin/main) — extending/verifying against the stale working tree would touch a
phantom file set and fail AC-2/AC-3. Captain decision needed: confirm the execute baseline. S sizing
assumes a clean origin/main baseline; branch reconciliation, if required first, is separate scope.

## Stage Report: shape

- DONE: absorb + verify each AC against REAL current files on origin/main (cite file:line)
  All 3 ACs verified against origin/main@455fc84: mods MISSING in both tiers (4 paths); architecture-canon 3 refs (ship-shape:596/ship-plan:501/template:33); canonical-doc-sync load-bearing (ship-review:156 + 2 integration tests); #71 resolver gap at check-no-dangling.sh:227 (Cond 2 needs twin); integration tier RED (both tests exit 1, run live).
- DONE: record decisions per reference (author vs de-reference)
  architecture-canon → DE-REFERENCE (no consumer/spec, redundant with canonical-doc-sync); canonical-doc-sync → AUTHOR at adopter path (EXISTS_BROKEN, recoverable from test spec). Recorded in ## Shape.
- DONE: captain articulation already given — do NOT re-ask
  hackathon-2 GO + bulk attestation 2026-07-20 cited, not re-litigated.
- DONE: record the entity's time_budget from the body
  1h00m recorded in ## Shape.
- DONE: out-of-scope named (beyond ACs / spacedock binary / third-party deps)
  Recorded in ## Shape Out-of-scope (adds: #75 sibling, doc audit, sync-manifest, branch reconciliation).
- DONE: if an AC is already-satisfied or wrong, say so (disproof beats compliance)
  No AC already-satisfied; all 3 hold. Disproof surfaced instead: baseline is origin/main, NOT the stale working branch (233 behind, #71 resolver absent) — flagged BLOCKING for execute.

### Summary

Lean shape for an S entity, verified against origin/main@455fc84. Per-reference decisions: author
`canonical-doc-sync.md` at the adopter path `docs/ship-flow/_mods/` (reverse-recovery EXISTS_BROKEN —
wired into ship-review live logic + 2 integration tests, content recoverable from the test spec);
de-reference `architecture-canon.md` (3 bibliographic refs, no consumer, no content spec, redundant
with canonical-doc-sync). AC-2 gap confirmed at check-no-dangling.sh:227 (resolver Cond 2 requires a
twin) → extend with a no-twin missing-everywhere branch + fixture. AC-3: integration tier currently
RED (proven live), authoring greens it. **Key surprise flagged BLOCKING**: the entity's working
branch iamcxa/muscat-v1 is 233 behind origin/main and lacks PR #71 — execute MUST baseline off
origin/main or it edits a phantom (177-line) resolver.

## Stage Report: design

- DONE: decide trivial-pass vs full design honestly
  Full design — contract-bearing (new mod content contract + resolver code-gate + prose de-refs); trivial-pass rejected per stage-def. design.md written.
- DONE: enumerate EVERY dangling architecture-canon/canonical-doc-sync reference with per-reference decision (author-minimal vs de-reference)
  design.md AC-1 table: architecture-canon ×3 (ship-shape:596, ship-plan:501, migrate-debrief template:33) + decisions-log INVARIANTS:199 (discovered peer) → de-ref; canonical-doc-sync ship-review:24/29/156/461 + doc-format:3 → author at adopter path. Existence + zero-test-pin verified.
- DONE: guard extension spec (synthetic missing-everywhere fixture red, repo green)
  design.md AC-2: classify-by-twin branch (new `missing-everywhere-canonical-mod` label) + `--exclude-dir=__tests__` + adopter-tree guard + aggregator grep at :300; named the 3 test surfaces; real-repo green-set enumerated (8 mods) proving repo-green.
- DONE: baseline off origin/main's 312-line resolver in the seeded worktree
  Verified: worktree HEAD 0 behind origin/main, check-no-dangling.sh = 312 lines (#71 resolver). Shape's BLOCKING baseline risk resolved by the seed.
- DONE: keep it fast (time budget)
  Design done inside budget; no re-litigation of shape's already-verified AC evidence, only the contract-delta/test-surface layer added.

### Summary

Full design (contract-bearing). Contract deltas: author canonical-doc-sync.md at the adopter path (13 grep-pinned tokens = the two integration tests' spec) and de-reference the bibliographic architecture-canon refs. Guard: a `missing-everywhere-canonical-mod` branch classifying by twin-presence, with `--exclude-dir=__tests__` (F2, required — else case9 self-reds on its foo/bar fixtures) and an adopter-tree-present guard (F3, preserves plugins-only clone-green). Two scope findings flagged for the gate: **F1** — a class-wide guard mechanically surfaces a third missing-everywhere peer, `decisions-log.md`, folded in as a one-line de-ref (gate may defer); **F2/F3** as above. Baseline risk from shape is resolved by the seeded worktree (312-line resolver, 0 behind origin/main).

## Stage Report: plan

- DONE: guard-extension RED fixture (missing-everywhere class + case9 self-red guard per F2)
  plan.md T1 (test-only, live-verified new fixtures RED/GREEN against the current unmodified resolver) + T5 (classify-by-twin implementation + `--exclude-dir=__tests__` F2 + F3 guard, turns T1's RED fixture GREEN).
- DONE: author canonical-doc-sync.md in adopter tier (content recovered from the two integration tests' spec — cite them)
  plan.md T3 — 9 grep-pinned assertion groups from `test-canonical-doc-sync-mod.sh` Blocks 1-3 + `test-canonical-context-lifecycle.sh`'s `Silent omission` check; content live-verified 14/14 PASS in a disposable scratch copy.
- DONE: de-reference architecture-canon (3 sites) + decisions-log (1 site)
  plan.md T4 — ship-shape:596, ship-plan:501, migrate-debrief template:33 (architecture-canon) + INVARIANTS.md:199 (decisions-log, F1 fold); all four are prose-only deletions, zero test pins (`grep -rl` verified 0 hits).
- FAILED: dual-env full gate incl. the two previously-RED integration tests now GREEN (as literally worded)
  test-canonical-doc-sync-mod.sh reaches 14/14 (fully green, as scoped); test-canonical-context-lifecycle.sh reaches only 8/10 — 2 residual failures are a pre-existing `docs/ship-flow/README.md` wording gap unrelated to this entity's 3 ACs (see plan.md's "Plan finding" + narrowed AC-3). Not a shortfall in execution — a scope correction to the checklist's literal wording, surfaced for the gate.

### Plan finding (new, not in shape/design)

Live-verified, not re-read: `test-canonical-doc-sync-mod.sh` and `test-canonical-context-lifecycle.sh`
both carry an independent `REPO_ROOT` off-by-one (`../../../..` should be `../../../../..` from
`plugins/ship-flow/lib/__tests__/integration/`) that would have permanently blocked AC-3 even with a
perfectly-authored mod — reproduced live (0/14 → 14/14 and 0/10 → 8/10 in a disposable scratch
copy). plan.md's T2 fixes only the two files this entity's AC-3 names; 9 other integration tests
share the same bug pattern and are flagged as a follow-up todo, not fixed here. Full detail in
plan.md's "Plan finding" section.

### Summary

Five-task TDD plan (T1 RED test-fixture → T2 REPO_ROOT precondition fix → T3 author mod → T4
de-reference 4 sites → T5 implement classify-by-twin guard), ordered so `check-no-dangling.sh` is
never live against an unfixed repo. All evidence live-verified this session (not re-read): current
baselines (`check-no-dangling.sh` PASS/8-patterns, `test-check-no-dangling.sh` 10/10,
`test-canonical-doc-sync-mod.sh` 0/14, `test-canonical-context-lifecycle.sh` 0/10), the new
REPO_ROOT bug and its fix, the authored mod content reaching 14/14, and the intermediate T2-only
(5/14, 7/10) and T2+T3 (14/14, 8/10) states. One narrowing finding for the gate: AC-3's dogfood-tier
"suite green" claim needs to read as 14/14 + 8/10 (2 residual, pre-existing, out-of-scope failures),
not full green on both tests — recommend the gate ratify this narrower reading rather than block on
literal AC-3 wording.

## Stage Report: execute

- DONE: T1 — guard-extension RED fixture (missing-everywhere class + case9 self-red guard)
  `cdc7852`; OBSERVED RED: case 9 FAIL (expected exit 1, got 0), 11/12 otherwise PASS.
- DONE: T2 — REPO_ROOT off-by-one precondition fix
  `8822249`; OBSERVED: 0/14→5/14, 0/10→7/10 (wrong-directory masking removed).
- DONE: T3 — author canonical-doc-sync.md in adopter tier
  `590b1e6`; OBSERVED GREEN: 5/14→14/14, 7/10→8/10 (Silent omission check flips).
- DONE: T4 — de-reference architecture-canon (3 sites) + decisions-log (1 site, F1 fold)
  `785e391`; AC-1 grep proof 0 hits across all 4 files; zero test regressions.
- DONE: T5 — missing-everywhere-canonical-mod classify-by-twin guard (F2 exclude-dir, F3 adopter-tree guard)
  `5a08112`; OBSERVED GREEN: test-check-no-dangling.sh 12/12; check-no-dangling.sh + --self-test both PASS on real repo.
- DONE: full local gate both envs — target = ratified narrowed claim (14/14 + 8/10 + full shell suite + check-* green)
  129/129 standalone suite; 14/14 + 8/10 dogfood (2 residual documented); check-no-dangling/check-invariants/check-version-triple all PASS; `git diff --check` clean.
- DONE: gate discipline — foreground bounded calls, sequential, no background zombie-wait
  full suite run in 3 sequential ≤550s batches; one 90s-per-file timeout false-alarm (test-merged-pr-closeout-reconciler.sh) confirmed 198/198 PASS at 240s, not a real regression.
- FAILED (then fixed): pre-existing C15 artifact-verbosity gap discovered live, not in plan.md's own scope list
  plan.md was 405 body lines (cap 200) since the plan-stage commit, blocking check-invariants.sh green at handoff; fixed via `<details>` collapse (`91d4231`) — same remedy the sibling `reverse-recovery-audit-dangling-path/execute.md` applied for the identical gate; content trimmed only where narratively redundant, no cited fact dropped.

### Summary

All 5 plan.md tasks executed serially (T1→T2→T3→T4→T5), each RED-before-GREEN per its own TDD
contract, matching the plan's live-verified counts exactly. AC-1: architecture-canon (3 sites) +
decisions-log (1 site) de-referenced, canonical-doc-sync.md authored at the adopter tier — 0
dangling refs remain. AC-2: check-no-dangling.sh's new missing-everywhere-canonical-mod class
guards the gap, 12/12 fixture PASS, real-repo green. AC-3 (narrowed, plan-ratified): 129/129
standalone + 14/14 + 8/10 dogfood (2 pre-existing README-wording failures, documented not fixed).
One execute-stage finding not anticipated by shape/design/plan: this entity's own plan.md violated
the C15 artifact-verbosity cap (pre-existing since the plan-stage commit) — fixed as a separate
commit using the exact remedy a sibling entity already established for this same gate, so
check-invariants.sh is green at handoff. Full detail and commit citations in execute.md.

## Stage Report: verify

- DONE: Independent re-run (FOREGROUND bounded only) — guard fixture suite + the two integration tests + full local gate both envs; per-AC evidence
  Guard fixture suite 12/12; test-canonical-doc-sync-mod.sh 14/14; test-canonical-context-lifecycle.sh 8/10 (2 residual re-confirmed unrelated: 0 grep hits for architecture-canon/canonical-doc-sync/decisions-log in README.md, 0 commits touched it); standalone shell suite 129/129 (one 90s-timeout false-alarm on test-merged-pr-closeout-reconciler.sh re-confirmed 198/198 at 300s); check-no-dangling/--self-test/check-invariants/check-version-triple all PASS; git diff --check clean. Full detail in verify.md.
- DONE: verify authored canonical-doc-sync.md content against the 13-token contract from the integration tests (not invented prose)
  Checked token-by-token against the two tests' own `grep -q` patterns directly (not design.md's paraphrase) — 13/13 present verbatim; file is 21 lines, no content beyond the recovered spec.
- DONE: confirm all four de-references resolve and the class guard reds on the synthetic fixture / greens on repo
  `grep -rn 'architecture-canon\|decisions-log'` across all 4 sites → 0 hits. Beyond the shipped fixture suite: sourced check-no-dangling.sh directly and drove `run_mislocated_canonical_mods()` against an independently-named fixture (`zzz-independent-probe-never-in-repo-test.md`, never in the repo's own test file) — RED with adopter tree present, GREEN (F3 guard) with it removed, ruling out name-hardcoding.
- DONE: verify.md C11/C12/C15-conformant from the start
  `## Panel Coverage` + `## Deferred to TODO` present; body 101/120 lines, raw 114/240. `check-invariants.sh` re-run with verify.md present: rc=0, C11/C12/C15 all OK.
- DONE: proportional review for S doc-reconciliation entity — declare panel coverage honestly; scoped cross-model per ship-verify (DEGRADED visible if unavailable)
  `panel_coverage: scoped` declared (non-doc source diff = 86 changed lines, zero UI/API/security/migration flags, S/mechanical carried from shape/design/plan) — full 5-specialist panel not dispatched. Codex cross-model attempted scoped (stdin diff, read-only sandbox, no-explore prompt) and converged clean (~170s, NO_FINDINGS) — unlike the sibling entity's DEGRADED run this same session. `cross_model: true`.
- DONE: BLOCKING → route_to execute; NIT auto-fix per rules
  No BLOCKING or NIT findings this round — Codex converged NO_FINDINGS and the verifier's own diff read found nothing to route or auto-fix.

### Summary

Independently re-ran (not relayed) the guard fixture suite (12/12), both dogfood integration tests
(14/14 + 8/10, the 2 residuals re-confirmed pre-existing/unrelated), and the full local gate
(129/129 standalone with one confirmed timeout false-alarm, check-no-dangling/self-test/
check-invariants/check-version-triple/git-diff-check all green). Went beyond relay on both content
ACs: verified canonical-doc-sync.md's 13 tokens against the tests' own grep patterns directly, and
drove the resolver function against an independently-named synthetic fixture never in the repo's
own test file to rule out hardcoding. Proportionality declared visibly: scoped panel for an
S/mechanical entity with zero UI/API/security/migration flags; Codex cross-model converged clean
this time (contrast: the sibling entity's DEGRADED run). Zero BLOCKING/WARNING findings; 2
pre-existing out-of-scope items deferred to TODO. Verdict: PASS (PROCEED). Full evidence in verify.md.
