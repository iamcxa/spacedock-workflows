# Ship-Flow Public Repo Queue

Status: queued
Reason: Spacebridge is a private repo on a free GitHub plan, so repository rulesets, required checks, and native auto-merge cannot be fully managed there.

## Goal

Make Ship-Flow itself a public repository so adopters can install and use the reusable PR review and auto-merge primitives without inheriting Spacebridge's private/free repository limitations.

## Required Follow-Up

1. Create or transfer a public `ship-flow` repository under the chosen owner.
2. Move `plugins/ship-flow/` source into that repository while preserving plugin metadata and release packaging.
3. Update plugin metadata:
   - `.claude-plugin/plugin.json`
   - `.codex-plugin/plugin.json` if retained in the public source
   - marketplace entries
4. Configure GitHub rulesets on the public repo:
   - required approvals: `0`
   - required checks: Ship-Flow test suite and package validation
   - Copilot automatic review when available
   - native auto-merge enabled
5. Dogfood `bin/semantic-review-*`, `bin/review-thread-gate.mjs`, `bin/auto-merge-readiness-collect.mjs`, and `bin/auto-merge-run.mjs` on the new public repo.

## Boundary

Do not block Carlove or Ship-Flow plugin-layer implementation on this. Spacebridge adoption resumes after the public repo exists or Spacebridge's GitHub plan/visibility supports the required rulesets.
