# Reference-Not-Restate Fixture — Plan

Reads: `shape.md → ## Done Criteria [cite, do not restate — assertion/type by DC-N]`.

<!-- section:verification-spec -->
### Verification Spec

<!-- DC assertions + types are canonical in shape.md → ## Done Criteria. Rows keyed by DC-N. -->
| DC | Verify Procedure | Expected |
|---|---|---|
| DC-1 | bash plugins/ship-flow/lib/extract-section.sh <folder-entity> done-criteria | non-empty block |
| DC-2 | bash plugins/ship-flow/lib/extract-section.sh <flat-entity> done-criteria | non-empty block |
<!-- /section:verification-spec -->
