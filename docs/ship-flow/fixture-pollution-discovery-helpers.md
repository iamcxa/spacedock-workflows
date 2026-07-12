---
title: Fixture-tree exclusion for discovery helpers
status: draft
source: todo fixture-pollution-discovery-helpers (pitch 1 harvest)
started:
completed:
verdict:
score:
worktree:
issue:
pr:
---

`spacedock status --discover` and `plugins/ship-flow/lib/discover-adopter-skills.sh` both match plugin test fixtures when run inside the plugin repo. FO boot discovery lists 4 bogus workflow candidates from `plugins/ship-flow/lib/__tests__/fixtures/workflow-doctor/*` (reproduced at FO boot 2026-07-12 — forces `--workflow-dir` on every helper call); adopter-skill discovery drafts were unusable in pitch 1 shape (carlove-shaped routing from fixture content). WHO pays: every FO session in this repo, and shape-stage skill routing in any adopter repo that vendors fixtures.

Scope note: `status --discover` lives in the spacedock binary (upstream repo — debrief 2026-07-12-01 lists it as candidate upstream issue, not filed); the ship-flow-owned surface here is `discover-adopter-skills.sh` and any other lib/bin helper that walks the tree without fixture exclusion.

## Acceptance criteria

**AC-1 — discover-adopter-skills.sh ignores fixture trees.**
Verified by: running it from this repo root yields zero candidates sourced from `lib/__tests__/fixtures/**`; regression test with a fixture-shaped decoy tree.

**AC-2 — the exclusion rule is shared, not one-off.**
Verified by: a single exclusion helper/config consumed by every tree-walking lib/bin helper (grep shows no duplicated hardcoded fixture paths).

**AC-3 — upstream `status --discover` gap is filed or worked around.**
Verified by: GitHub issue link on the spacedock repo, or a documented `--workflow-dir` guard in this instance README.
