---
title: Self-adoption dogfood bootstrap — canonical docs + doc-impact gate
status: shape
source: 2026-07-11 captain decision (dogfood bundle) + 2026-07-08 joint audit
started: 2026-07-11T05:59:50Z
completed:
verdict:
score: 0.9
worktree:
issue:
pr:
---

The plugin repo does not obey its own methodology: the repo root has no
PRODUCT.md / ROADMAP.md / ARCHITECTURE.md (check-invariants Principle 5b
WARNs and skips), plugin development bypasses ship-flow entirely, and the
only doc-currency protection for prose is manual audits (PR #6 found stale
version claims exactly this way). Meanwhile adopters (carlove) are gated by
the very machinery this repo skips. Captain decision 2026-07-11: ship-flow
development must obey its own rules, enforced by code gates rather than
prose.

Scope (captain-approved bundle): bootstrap the three root canonical docs;
build the `doc-impact-gate` primitive (config-driven touch-coupling checker:
src globs ↔ doc paths, or a structured `doc-impact: none — <reason>`
declaration) as a plugin-shipped, zero-dependency checker; wire it into this
repo's CI for plugin-touching PRs above a size threshold; prove the
canonical-doc sync loop by running this very entity through
shape → … → ship. Rideshare: the harvest vocabulary decision record (T3).
Design decision constraint (R3 scar, carlove 2026-06-09): the CI gate is
mechanical declaration-presence only — LLM semantic verification stays in
the pipeline (verify/review route-back) or advisory surfaces, never a
required check.

Adopter sequencing after this ships: helm wires the primitive with its own
coupling map; carlove pilots one narrow coupling (workflows ↔ CI docs) —
both tracked in their own repos (carlove todo `doc-impact-gate-wiring`).

## Acceptance criteria

**AC-1 — Principle 5b enforces instead of skipping.**
Root ARCHITECTURE.md exists with the flow-map-schema six section markers
(mermaid for context/containers/components); PRODUCT.md and ROADMAP.md exist
with patchable section markers. Verified by: `CI=true bash
plugins/ship-flow/bin/check-invariants.sh` output contains no
`WARN [Principle 5b]` skip line.

**AC-2 — Routing policy is a code gate, not prose.**
A plugin-shipped `doc-impact-gate` checker (config-driven couplings +
declaration syntax) runs in this repo's CI and fails a plugin-touching PR
above the configured threshold that neither touches the coupled docs nor
carries a `doc-impact: none — <reason>` declaration. Verified by: the
checker's own test suite (RED-first) + one live CI run showing the gate
evaluated on a real PR.

**AC-3 — The canonical-doc sync loop runs end-to-end on a real entity.**
This entity itself travels shape → design → plan → execute → verify → ship
in this workflow, and ship-review's canonical-doc sync writes the resulting
PRODUCT/ROADMAP/ARCHITECTURE updates (or explicit skip rationales) as
pipeline output. Verified by: this entity's review.md `## Canonical Docs
Update` section citing real commits, and
`bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/bin/canonical-doc-sync-checker.sh"
docs/ship-flow/self-adoption-dogfood-bootstrap` exiting 0.

**AC-4 — T3 rideshare: harvest vocabulary decision record.**
A short reference (pr-merge-paths pattern) pins the correspondence between
debrief-guardrail-harvest's six buckets, harvest-decide's four outcomes, and
kc-forge's D1/D2 layers. Verified by: file exists under
`plugins/ship-flow/references/` and is linked from the plugin README's
further-reading list.
