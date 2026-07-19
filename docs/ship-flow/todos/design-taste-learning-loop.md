---
tid: design-taste-learning-loop
captured_at: 2026-07-19T15:36:57Z
status: pending
domain: dx
guess_files: [plugins/ship-flow/skills/ship-design/SKILL.md, plugins/ship-flow/skills/ship-verify/SKILL.md]
suggest_done_type: code
entity: null
---

Per-repo design-taste learning loop — make captain 審美/UX 判斷 accumulate instead of evaporate.
(1) Structured capture: every captain UAT verdict on a UI preview lands as a record
(accept/reject + one-line reason + screenshot ref), riding the existing feedback-cycle record
format. (2) Learning: periodic harvest pass clusters recurring reject reasons into CANDIDATE
canon rules; captain batch-ratifies (harvest-decide invariant: the model proposes, never
self-mutates canon). (3) Consumption: ratified rules live in a per-repo design-canon.md that
ship-design MUST consult pre-generation; mechanizable rules graduate to ui-verify code gates
(code gate > prose rule). Include a challenge clause (design may propose canon-breaking with an
explicit flag) to prevent taste ossification. Metric: UAT reject rate per shipped UI entity
trends down = trust earned (Phase-C logic).

HARD CONSTRAINT (captain): cold-start rubrics are DISTILLED into ship-flow-owned assets —
study third-party design-review methodologies (e.g. gstack /design*) as references, then author
our own rubric files in-repo. NO runtime dependency, invocation, or wrapping of third-party
plugins (gstack is not captain-designed; dependency explicitly rejected).
