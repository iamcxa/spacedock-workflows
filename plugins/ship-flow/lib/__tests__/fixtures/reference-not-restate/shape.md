# Reference-Not-Restate Fixture — Shape (canonical source)

Demonstrates the 129.1 schema de-dup contract: shape.md is the canonical source
for problem / user-journey / done-criteria. The DC-N keys assigned here are the
stable, immutable reference keys downstream stages cite — assertion + type live
ONLY in this file.

<!-- section:problem -->
## Problem

A small CLI helper has no observable contract: callers cannot tell whether
`extract-section.sh` returns a non-empty block for a folder-layout entity, and
there is no machine-checkable acceptance for the flat-layout fallback.
<!-- /section:problem -->

<!-- section:user-journey -->
## User Journey

- Persona: ship-flow maintainer
- Goal: confirm the section extractor works on both layouts
- Entry point: a shell prompt in the repo root
- Steps:
  1. Run the extractor against a folder-layout entity.
  2. Run the extractor against a flat-layout entity.
<!-- /section:user-journey -->

<!-- section:done-criteria -->
## Done Criteria

- [ ] `cli` — DC-1: extract-section.sh returns the Done-Criteria block for a folder-layout entity (journey step 1)
- [ ] `cli` — DC-2: extract-section.sh returns the Done-Criteria block for a flat-layout entity (journey step 2)
<!-- /section:done-criteria -->
