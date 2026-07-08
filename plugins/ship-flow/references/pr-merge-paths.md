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

## References

- `README.md` § Release Notes 0.6.0 (auto-merge readiness layer)
- `_plans/semantic-review-layer-2026-05-20.md` (promotion origin;
  mechanics-vs-policy split)
- carlove adopter ledger: qnow PR #815 (reversion to native manual merge),
  qnow `docs/ship-flow/SYNC-NOTES.md` (adopter-side deprecation + keep-local
  classification)
- `_mods/sync-drift-check.md` (the manifest mechanism that governs
  adopter-copy drift)
