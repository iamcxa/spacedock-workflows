---
title: Missing canonical mods — author or de-reference (both tiers)
status: done
source: hackathon-2 Wave 2c (todo missing-canonical-mods-both-tiers; rra shape discovery)
started: 2026-07-19T16:04:46Z
completed: 2026-07-19T19:52:01Z
verdict: passed
score:
worktree: .worktrees/spacedock-ensign-missing-canonical-mods
issue: "#77"
pr: pr-merge:79
archived: 2026-07-19T19:52:01Z
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
