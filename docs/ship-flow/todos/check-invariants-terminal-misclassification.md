---
tid: check-invariants-terminal-misclassification
captured_at: 2026-07-19T15:17:46Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/bin/check-invariants.sh]
suggest_done_type: code
entity: null
---

check-invariants.sh's _entity_is_terminal() misclassifies any entity with an empty completed: field as terminal, repo-wide — pre-existing, surfaced during #71 verify. Separate ticket per verify.md.
