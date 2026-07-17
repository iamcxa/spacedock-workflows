# PR-Merge Paths — Decision Record

- **Status**: accepted
- **Date**: 2026-07-08
- **Deciders**: captain, with the SO/EM improvement-review findings of 2026-07-07 as the trigger

## Summary

Ship-flow has **two coexisting PR-merge paths**. They share vocabulary
("semantic review", "pr-merge") and even file names, but they have different
owners and independent lifecycles. This record pins the relationship down,
because its absence nearly caused deletion of live plugin machinery (see
"Near-miss" below).

## Path A — plugin-native mechanical auto-merge stack (ACTIVE)

The `bin/` primitives shipped in 0.6.0 ("Auto-merge readiness layer + semantic
review primitives", README Release Notes):

| Component | Role |
|---|---|
| `bin/semantic-review-policy.mjs` / `semantic-review-packet.mjs` | packet schema + policy validation |
| `bin/semantic-review-prepare.mjs` | builds packet JSON + marked PR comment from local review evidence |
| `bin/semantic-review-gate.mjs` | validates the newest marked packet comment against the PR head |
| `bin/review-thread-gate.mjs` | mechanical unresolved-review-thread gate |
| `bin/auto-merge-readiness.mjs` + `-collect.mjs` | report-only readiness verdict + GitHub evidence collector |
| `bin/auto-merge-run.mjs` | optional mutating executor (native auto-merge / policy-approved direct merge) |

These are **live, tested primitives** (`bin/*.test.mjs`, including
`semantic-review-auto-merge-e2e.test.mjs`). The ownership split is the one
declared at their birth in `_plans/semantic-review-layer-2026-05-20.md`:
**the plugin owns generic mechanics; adopter repos own policy** (required
reviewers, dimensions, labels, CI wiring — via `--policy-json` and CLI flags).
The dogfood repo's own merge flow (its repo-local `_mods/pr-merge.md` Claude
challenge gate) consumes this stack.

## Path B — adopter-native manual merge (carlove precedent)

The carlove adopter ran a custom PR-review/auto-merge/owned-review design and
**scrapped it on cost grounds** (2026-06-07, qnow PR #815 — GHA minutes +
Claude tokens + Copilot credits). It reverted to ship-flow-native manual
handling: create PR → manual review → captain merge, with the deterministic
`ci-gate` commit status as the **sole** required merge gate.

What is deprecating on the carlove side (and ONLY there):

- workflow-local mods `pr-review-loop.md`, `review-gate.md`,
  `semantic-review-packet.md` (adopter-authored; pending a dependency sweep)
- hand-copied `docs/ship-flow/scripts/semantic-review-*.mjs` + residual
  `reuse-test.yaml` steps (the CI job itself was removed 2026-06-09, "R3")
- carlove's `_mods/pr-merge.md` stays a keep-local variant
  (draft-until-ship policy coupling) — a policy fork, not drift

## The rules this record encodes

1. **Adopter deprecation ≠ plugin deprecation.** An adopter sunsetting its
   local semantic-review usage says nothing about the plugin's `bin/*.mjs` —
   those remain active primitives feeding the auto-merge-readiness layer.
2. **Sweep boundaries.** An adopter "review-trio dependency sweep" touches
   only that adopter's workflow-local mods, its hand-copied
   `docs/<wf>/scripts/*` forks, and its CI steps. It must **never** reach into
   plugin `bin/`.
3. **Name collisions are lineage, not linkage.** The adopter scripts and the
   plugin `bin/` primitives share names because the plugin **promoted the
   carlove originals** (2026-05-20). Post-promotion they are independent
   copies with independent lifecycles; deleting one implies nothing about the
   other. (Adopter-side copies are the drift surface — the `sync-drift-check`
   manifest mechanism governs those, not this record.)
4. **Default for new adopters is Path B.** Start with manual merge plus one
   deterministic CI gate. Opt into Path A only when merge volume justifies the
   mechanics, wiring policy through `--policy-json` /
   `--required-independent-approvals` rather than forking the primitives.

## Near-miss that motivated this record

A 2026-07-07 improvement review proposed "clean up the deprecated review trio
from plugin `bin/`". The SO/EM pass refuted it with primary evidence: (a) the
`semantic-review-*.mjs` primitives are active 0.6.0 components, and (b)
`pr-review-loop` / `review-gate` never existed in plugin `bin/` at all — they
are adopter-side mods. Executing the sweep as phrased would have deleted live
machinery. The absence of this document was the root cause.

## Post-merge closeout: `merge guard` is the single authority (2026-07-17)

The paths above cover how a PR gets *merged*. This section covers what happens
*after* a merge — turning a merged PR into terminal (`done` + archive) state.

Historically three code paths each did their own raw `status=done` + `--archive`
mutation, diverging in guards, cleanup, and rollback:

- `hooks/warn-state-drift.sh` (Claude-Code `SessionStart` auto-fix);
- `bin/merged-pr-closeout-reconciler.sh` (a manual CLI);
- `_mods/pr-merge.md` `## Hook: startup` / `## Hook: idle` (prose the live FO
  agent runs at every engage-cycle boundary).

Because closeout depended on which path fired, a direct `gh pr merge` that
bypassed the FO flow could leave a merged PR non-terminal (motivating incident:
C14 / PR #47 → manual reconcile PR #51 → latent regression #29).

**Contract (issue #46):** `spacedock merge guard <slug> --verdict passed` is the
single MERGED→done mutation authority. All triggers now delegate to one
`bin/closeout-adapter.sh` (renamed from `merged-pr-closeout-reconciler.sh`), which:

1. normalizes the provider (`gh` MERGED → durable `pr=pr-merge:{N}` sentinel,
   written and committed *before* the guard call, so a dirty worktree cannot
   lose the merge fact);
2. invokes `merge guard` — the sole primitive that clears the mod-block,
   terminalizes, and archives; it never calls `gh` or `git commit` itself;
3. fails closed with `state-driver unavailable` when no compatible state driver
   is present (never a direct-YAML fallback);
4. defers non-fatally on a dirty tree or the wrong branch, so a later clean run
   converges and closeout is never committed on the wrong branch;
5. emits a non-blocking `debrief_due=<slug>` signal on a successful finalize, so
   the ship-stage debrief convention is surfaced, not orphaned.

Replay is idempotent: `merge guard` returns `archived entity is read-only` on an
already-archived entity, which the adapter reports as `state=already_reconciled`
(a no-op); a failed post-finalize commit converges on retry via merge guard's own
resumability (the authority's archive is never rolled back).

**The guarantee is convergence, not hook timing** — whichever trigger notices the
merge first, every path routes through the same authority, so repeated runs
across harnesses all settle on the same terminal state. This is why Claude-only
SessionStart hook metadata is not required as a cross-harness delivery guarantee.

**Intentional non-member:** `skills/ship-execute/SKILL.md`'s "inline-on-main"
no-PR ship pattern deliberately uses `--force` and never creates a PR; it is not
a closeout trigger and is out of scope for this convergence.

## References

- `README.md` § Release Notes 0.6.0 (auto-merge readiness layer)
- `_plans/semantic-review-layer-2026-05-20.md` (promotion origin;
  mechanics-vs-policy split)
- carlove adopter ledger: qnow PR #815 (reversion to native manual merge),
  qnow `docs/ship-flow/SYNC-NOTES.md` (adopter-side deprecation + keep-local
  classification)
- `_mods/sync-drift-check.md` (the manifest mechanism that governs
  adopter-copy drift)
