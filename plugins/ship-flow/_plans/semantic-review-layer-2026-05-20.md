# Semantic Review Layer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Promote Carlove's semantic PR review packet, gate, prepare helper, and unresolved review-thread gate into reusable Ship-Flow plugin primitives.

**Architecture:** Ship-Flow owns generic mechanics: packet schema validation, packet preparation, PR comment gate validation, and unresolved review-thread validation. Adopter repos own policy by passing required reviewers, local review key, required dimensions, labels, commands, and CI wiring through CLI/config options.

**Tech Stack:** Node.js ESM CLI modules, `node:test`, GitHub Actions JSON inputs from `gh`, Ship-Flow plugin docs.

### Task 1: Baseline and RED Tests

**Files:**
- Create: `plugins/ship-flow/bin/semantic-review-policy.mjs`
- Create: `plugins/ship-flow/bin/semantic-review-packet.mjs`
- Test: `plugins/ship-flow/bin/semantic-review-packet.test.mjs`

**Step 1: Write failing tests**

Add tests proving:
- A valid packet passes with default Ship-Flow policy.
- Validation accepts an adopter-specific policy with custom `local_review_key`, required dimensions, and required reviewers.
- Validation rejects packets missing required adopter dimensions/reviewers.

**Step 2: Run RED**

Run: `node --test plugins/ship-flow/bin/semantic-review-packet.test.mjs`

Expected: FAIL because the semantic-review modules do not exist.

### Task 2: Packet Validation Implementation

**Files:**
- Modify: `plugins/ship-flow/bin/semantic-review-policy.mjs`
- Modify: `plugins/ship-flow/bin/semantic-review-packet.mjs`

**Step 1: Implement minimal validator**

Implement:
- `DEFAULT_SEMANTIC_REVIEW_POLICY`
- `normalizeSemanticReviewPolicy(options)`
- `runSemanticReviewPacketValidation(options)`
- CLI flags `--packet`, `--head`, `--policy-json`

**Step 2: Run GREEN**

Run: `node --test plugins/ship-flow/bin/semantic-review-packet.test.mjs`

Expected: PASS.

### Task 3: Prepare Helper and Comment Gate

**Files:**
- Create: `plugins/ship-flow/bin/semantic-review-prepare.mjs`
- Create: `plugins/ship-flow/bin/semantic-review-prepare.test.mjs`
- Create: `plugins/ship-flow/bin/semantic-review-gate.mjs`
- Create: `plugins/ship-flow/bin/semantic-review-gate.test.mjs`

**Step 1: Write failing tests**

Add tests proving:
- Prepare builds validator-compatible packets from explicit evidence and configurable policy.
- Comment gate validates the newest marked packet comment and respects `auto|required|off`.

**Step 2: Implement minimal code**

Use existing Carlove behavior as the starting point, but route required reviewers/dimensions/local review key through policy normalization.

**Step 3: Run GREEN**

Run: `node --test plugins/ship-flow/bin/semantic-review-prepare.test.mjs plugins/ship-flow/bin/semantic-review-gate.test.mjs`

Expected: PASS.

### Task 4: Review Thread Gate

**Files:**
- Create: `plugins/ship-flow/bin/review-thread-gate.mjs`
- Create: `plugins/ship-flow/bin/review-thread-gate.test.mjs`

**Step 1: Write failing tests**

Add tests proving unresolved non-outdated review threads fail, resolved/outdated threads pass, and stale payload heads fail.

**Step 2: Implement minimal code**

Move the Carlove mechanism unchanged unless a project-specific assumption appears.

**Step 3: Run GREEN**

Run: `node --test plugins/ship-flow/bin/review-thread-gate.test.mjs`

Expected: PASS.

### Task 5: Documentation and Source Map

**Files:**
- Modify: `plugins/ship-flow/README.md`
- Modify: `plugins/ship-flow/references/doc-sync-context.md`

**Step 1: Document the primitive**

Document that semantic-review is a reusable PR review mechanism layer, while adopter repos define local policy and CI requirements.

**Step 2: Update doc-sync source map**

Add source map rows for the new `bin/*.mjs` primitives.

### Task 6: Dogfood in Carlove

**Files:**
- Modify in Carlove: `package.json`
- Modify in Carlove: `docs/ship-flow/scripts/*`
- Modify in Carlove docs as needed.

**Step 1: Replace local implementation with wrappers**

Make Carlove invoke or re-export the plugin primitives with Carlove policy.

**Step 2: Run Carlove semantic-review tests**

Run: `pnpm ship-flow:semantic-review:test`

Expected: PASS.

### Task 7: Final Verification

Run:
- `node --test plugins/ship-flow/bin/ship-flow-lint.test.mjs`
- `node --test plugins/ship-flow/bin/semantic-review-*.test.mjs plugins/ship-flow/bin/review-thread-gate.test.mjs`
- `git diff --check`

Then commit, push, and create/update PRs as appropriate.

### Task 8: Auto-Merge Readiness Reporter

**Files:**
- Create: `plugins/ship-flow/bin/auto-merge-readiness.mjs`
- Test: `plugins/ship-flow/bin/auto-merge-readiness.test.mjs`
- Modify: `plugins/ship-flow/README.md`
- Modify: `plugins/ship-flow/references/doc-sync-context.md`

**Step 1: Write failing tests**

Add tests proving:
- A mergeable PR with all required checks passing, semantic gate valid, and thread gate clean returns `ready`.
- A PR with pending required checks returns `blocked` and names the check as the next action.
- A stale/invalid semantic-review packet returns `blocked` and points to semantic review regeneration.
- A non-mergeable PR returns `blocked` and points to mergeability/conflict resolution.
- Missing/unknown data returns `unknown` instead of pretending the PR is ready.

**Step 2: Run RED**

Run: `node --test plugins/ship-flow/bin/auto-merge-readiness.test.mjs`

Expected: FAIL because the readiness module does not exist.

**Step 3: Implement minimal reporter**

Implement `runAutoMergeReadiness(options)` and a JSON-printing CLI. Inputs are JSON files from existing primitives and GitHub CLI/API snapshots:
- `--pr-json`: output shaped like `gh pr view --json mergeable,isDraft,state,statusCheckRollup`
- `--semantic-gate-json`: output from `semantic-review-gate.mjs`
- `--thread-gate-json`: output from `review-thread-gate.mjs`
- `--required-check`: repeatable required check name

The reporter must not call `gh pr merge` and must not mutate remote state.

**Step 4: Run GREEN**

Run: `node --test plugins/ship-flow/bin/auto-merge-readiness.test.mjs`

Expected: PASS.
