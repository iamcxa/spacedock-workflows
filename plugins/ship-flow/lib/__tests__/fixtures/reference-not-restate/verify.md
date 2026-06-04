# Reference-Not-Restate Fixture — Verify

Reads: `plan.md → ### Verification Spec [cite, do not restate — procedure source]`,
`shape.md → ## Done Criteria [cite, do not restate — assertion/type by DC-N]`.

<!-- section:uat -->
### UAT

mode: spot-check

<!-- DC assertions + types canonical in shape.md → ## Done Criteria. Rows keyed by DC-N. Verify Procedure kept inline (operative command actually re-run). -->
| DC | Verify Procedure | Execute 1st | Verify | Evidence |
|---|---|---|---|---|
| DC-1 | bash plugins/ship-flow/lib/extract-section.sh <folder-entity> done-criteria | PASS | spot-checked | non-empty block |
| DC-2 | bash plugins/ship-flow/lib/extract-section.sh <flat-entity> done-criteria | PASS | trust (evidence: execute.md) | non-empty block |
<!-- /section:uat -->
