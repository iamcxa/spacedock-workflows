---
title: Migrate entity corpus to split-root state checkout
status: draft
appetite: medium
issue: "#85"
---

State-root split (separate entity corpus from code/tests/CI in .spacedock-state gitignore) requires simultaneous CI-enforcement migration: check-invariants scan must move to state-branch CI to prevent entity red findings from being hidden when corpus is off-main. This is a design+plan task (not 1h mechanical move) covering: state-checkout initialization, CI workflow relocation, check-invariants dual-env verification, and ARCHITECTURE.md update. Blocks later corpus-privacy work.
