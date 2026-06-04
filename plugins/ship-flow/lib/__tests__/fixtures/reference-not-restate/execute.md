# Reference-Not-Restate Fixture — Execute

Reads: `plan.md → ### Verification Spec`, `shape.md → ## Done Criteria`.

<!-- section:execute-uat -->
## Execute UAT

<!-- DC assertions + types canonical in shape.md → ## Done Criteria. Rows keyed by DC-N. Verify Procedure kept inline (operative command actually run). -->
| DC | Verify Procedure | Result | Evidence |
|---|---|---|---|
| DC-1 | bash plugins/ship-flow/lib/extract-section.sh <folder-entity> done-criteria | PASS | 3-line block returned |
| DC-2 | bash plugins/ship-flow/lib/extract-section.sh <flat-entity> done-criteria | PASS | 3-line block returned |
<!-- /section:execute-uat -->
