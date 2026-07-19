# Decisions — check-invariants-terminal-fix

| when | stage | decision | authority | note |
| --- | --- | --- | --- | --- |
| 2026-07-19T16:35Z | shape (gate) | PROCEED | Captain EM-drive grant (hackathon-2) | Checklist 5/5 DONE; AC-1 proven empirically vs main byte-identical predicate; taxonomy refinement (drop ship/shipped) is within AC-1 wording; execute directed to build off origin/main (branch 233 behind) |
| 2026-07-20T00:00Z | design | contract-bearing (full design.md), verdict PROCEED | ensign (design) | NOT trivial-pass: corpus-semantics shift (6 entities flip terminal→active, CI exit 0→1). Predicate `^status:[[:space:]]*done[[:space:]]*$`. Refinement beyond shape's enumeration: also drop `verdict: PASSED` branch — taxonomically forced (README:54-55 only `done` terminal; verdict field is verify/ship-stage = active), empirically zero-hit on current corpus. Flagged for gate veto; default = drop. |
