---
title: check-invariants terminal misclassification fix
status: draft
source: hackathon-2 Wave 2b (todo check-invariants-terminal-misclassification; #71 verify finding)
started:
completed:
verdict:
score:
worktree:
issue:
pr:
---

Time budget: 1h15m. check-invariants.sh's _entity_is_terminal() misclassifies any entity with an
empty completed: field as terminal, repo-wide. Fix the predicate to require a terminal status
value, not an empty-field accident.

## Acceptance criteria

**AC-1 — Correct predicate.** _entity_is_terminal() returns true ONLY for genuinely terminal
entities (status done/terminal per workflow taxonomy); empty completed: on an active entity no
longer classifies as terminal.
Verified by: RED fixture (active entity, empty completed:) then green.

**AC-2 — Corpus honest.** Any checks previously skipped due to misclassification now run;
resulting findings surfaced (not silently fixed) if any appear.
Verified by: check-invariants full run diff before/after documented.

**AC-3 — Suite green both envs.**
Verified by: dual-env run output.
