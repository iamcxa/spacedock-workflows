# UI Quality Contract

This reference defines the ship-flow-native `ui_quality_contract` used by
design-bearing UI entities. It distills UI review rigor into structured fields
that can move through `ship-design`, `ship-plan`, and `ship-verify` without
adding a separate workflow command or runtime dependency.

## Stage Ownership

Design declares `ui_quality_contract` in `### Hand-off to Plan` whenever an
entity affects UI or otherwise makes a design-bearing UI decision.

Plan imports every contract group into delivery criteria, reviewer questions,
or an explicit N/A row. A contract group must not remain a prose-only reminder.

Verify audits implementation evidence or explicit N/A for every contract group
and records findings through the normal review taxonomy.

## Contract Shape

```yaml
ui_quality_contract:
  copy:
    ctas: []
    empty_states: []
    error_states: []
    destructive_confirmation: ""
  visual_hierarchy:
    primary_focal_point: ""
    scan_order: []
    icon_only_fallbacks: []
  color:
    accent_reserved_for: []
    semantic_colors: []
    destructive_color: ""
    token_binding_required: true
  typography:
    allowed_sizes: []
    allowed_weights: []
    body_line_height: ""
  spacing:
    scale: []
    exceptions: []
    grid_multiple: 4
  interaction_states:
    loading: []
    empty: []
    error: []
    disabled: []
    focus: []
  source_safety:
    third_party_registries: []
    vetting_required: true
    evidence_required_at_verify: true
```

## Field Definitions

| Group | Design declares | Verify evidence examples |
|---|---|---|
| `copy` | CTA labels, empty states, error states, destructive confirmation copy. | Implemented strings, state fixtures, or explicit N/A for absent states. |
| `visual_hierarchy` | Primary focal point, scan order, and fallback labels for icon-only controls. | DOM/order evidence, accessible names, review notes, or explicit N/A. |
| `color` | Accent scope, semantic color use, destructive color policy, token binding requirement. | Token/class evidence, semantic state mapping, or explicit N/A. |
| `typography` | Allowed type sizes, weights, and body line-height expectations. | Token/class evidence, computed-style checks when already available, or explicit N/A. |
| `spacing` | Spacing scale, accepted exceptions, and grid multiple. | Token/class evidence, layout assertions, or explicit N/A. |
| `interaction_states` | Loading, empty, error, disabled, and focus state obligations. | State fixtures, screenshots only when an existing harness is already required, or explicit N/A. |
| `source_safety` | Third-party registries, vetting expectations, and verify-time evidence requirement. | Source citations, package provenance, manual review notes, or explicit N/A when no new source is introduced. |

## Blocking Examples

- `copy.ctas` says "Save" while implementation ships a generic "Submit" on the primary action.
- `visual_hierarchy.primary_focal_point` names a primary card, but the implemented layout gives equal weight to unrelated controls.
- `color.token_binding_required` is true, but implementation hardcodes a color where project tokens exist.
- `typography.allowed_sizes` is set, but the implementation introduces an uncited display size.
- `spacing.scale` is set, but implementation uses one-off spacing without an exception.
- `interaction_states.focus` is required, but focus states are absent from keyboard-reachable controls.
- `source_safety.vetting_required` is true, but a new UI asset source has no provenance evidence.

## Boundaries

This contract is a stage artifact and reference-document contract. It does not
create a separate GSD command, legacy file model, local archive dependency, or
additional browser/screenshot harness requirement. Existing render-fidelity and
whole-page visual parity fields keep their current behavior; `ui_quality_contract`
only adds structured obligations and evidence questions.
