---
tid: issue-anchor-guard-resolver-shell-parser-robustness
captured_at: 2026-07-17T10:14:19Z
status: pending
source_pitch: "5"
---

Three named-not-hidden shell-parser-robustness residuals in
`plugins/ship-flow/_mods/issue-anchor-guard.md`'s resolver (documented in its
Boundary section, no code fix this round): (P1-r3-2) `emit`'s tombstone
`rm -f "$IAG_OUT_FILE"` does not check its own exit status before continuing
to the fetch — should check success and abort before fetch when removal
fails; (P1-r3-3) `validate`'s top-level scalar reads (`verdict`,
`scope_subset_of_issue`, `goal_still_unmet` via `iag_field_from_file`) are a
line-oriented awk text scan rather than a structural `yq` parse like the
per-AC rows, so a duplicate top-level key or a single-quoted boolean-looking
scalar could be misread; (P1-r3-4) the AC-block parser
(`iag_parse_ac_blocks`) is not Markdown-aware — a fenced code block or
blockquoted example showing illustrative `AC-N:` sample text would be parsed
as a real acceptance criterion.
