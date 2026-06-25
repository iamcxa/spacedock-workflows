---
plugin: ship-flow
version: 0.6.0
last_sync: 2026-05-20 (0.6.0 release metadata sync)
---

# Ship Flow Doc-Sync Context

Reference file for `ship-flow:doc-sync`. It maps Ship Flow source files to documentation targets and defines sync levels, style defaults, probe policy, and post-sync hooks.

Resolve `PLUGIN_ROOT` before using this map. Prefer `${CLAUDE_PLUGIN_ROOT}`, then a runtime-provided Codex plugin root, then infer from `skills/doc-sync/SKILL.md` by walking up to the plugin root. All paths in this file are relative to `PLUGIN_ROOT`. Installed plugin contexts use the plugin root/cache directory directly.

## Source Map

### Skills -> Doc Targets

| Source | Primary Doc Target | Secondary Doc Target |
|--------|--------------------|----------------------|
| `skills/doc-sync/SKILL.md` | `README.md` (skill triggers and release gate) | `INVARIANTS.md` (doc drift guard, if promoted) |
| `skills/ship/SKILL.md` | `README.md` (pipeline entry and stage flow) | `workflow-template.yaml` (entrypoint expectations) |
| `skills/ship-shape/SKILL.md` | `README.md` (`/shape` journey) | `references/doc-format.md` (shape artifact structure) |
| `skills/ship-design/SKILL.md` | `README.md` (design stage and UI/domain gates) | `references/architecture-lens-triggers.yaml` (routing triggers) |
| `skills/ship-plan/SKILL.md` | `README.md` (plan stage) | `references/doc-format.md` (plan artifact sections) |
| `skills/ship-execute/SKILL.md` | `README.md` (execute stage) | `INVARIANTS.md` (atomic commit/pathspec rules) |
| `skills/ship-verify/SKILL.md` | `README.md` (verify stage and verdicts) | `INVARIANTS.md` (runtime evidence and reviewer rules) |
| `skills/ship-review/SKILL.md` | `README.md` (review/final stage) | `references/flow-map-schema.yaml` (canonical doc sync) |
| `skills/ship-runtime-detect/SKILL.md` | `README.md` (runtime detection) | `references/stack-skill-map.yaml` (routing map) |
| `skills/ship-onboard/SKILL.md` | `README.md` (adoption lifecycle) | `workflow-template.yaml` (adopter scaffold) |
| `skills/add-todos/SKILL.md` | `README.md` (todo capture) | `references/doc-format.md` (todo format, if present) |
| `skills/domain-registry/SKILL.md` | `README.md` (domain registry flow) | `references/domain-knowledge/README.md` |
| `skills/ui-verify/SKILL.md` | `README.md` (built-in UI verify) | `references/doc-format.md` (verification artifacts) |
| `skills/test-driven-development/SKILL.md` | `README.md` (TDD integration) | `INVARIANTS.md` (discipline references) |
| `skills/verify-reviewer-panel/SKILL.md` | `README.md` (reviewer panel) | `INVARIANTS.md` (reviewer fan-out constraints) |
| `skills/architecture-lens/*.md` | `references/architecture-lens-triggers.yaml` | `README.md` (domain routing summary) |

### Shell Primitives and Checks -> Doc Targets

| Source | Primary Doc Target | Secondary Doc Target |
|--------|--------------------|----------------------|
| `bin/check-invariants.sh` | `INVARIANTS.md` (enforcement list) | `README.md` (release checks) |
| `bin/canonical-doc-sync-checker.sh` | `README.md` (canonical sync checks) | `references/flow-map-schema.yaml` |
| `bin/workflow-doctor.sh` | `README.md` (diagnostics) | `workflow-template.yaml` (workflow expectations) |
| `bin/ship-capture.sh` | `README.md` (artifact capture helper) | `references/doc-format.md` |
| `bin/debrief-boundary-resolver.sh` | `README.md` (debrief flow) | `references/debrief-schema.yaml` |
| `bin/pr-feedback-rollback.sh` | `README.md` (PR feedback recovery) | `INVARIANTS.md` (rollback safety, if promoted) |
| `bin/stale-worktree-cleanup-planner.sh` | `README.md` (cleanup planning) | `INVARIANTS.md` (non-destructive cleanup principle) |
| `bin/semantic-review-policy.mjs` | `README.md` (semantic review policy boundary) | `workflow-template.yaml` (adopter policy example, if scaffolded) |
| `bin/semantic-review-packet.mjs` | `README.md` (semantic review packet primitive) | `INVARIANTS.md` (PR gate evidence, if promoted) |
| `bin/semantic-review-prepare.mjs` | `README.md` (semantic review prepare helper) | `workflow-template.yaml` (adopter command wiring, if scaffolded) |
| `bin/semantic-review-gate.mjs` | `README.md` (semantic review PR comment gate) | `INVARIANTS.md` (PR gate evidence, if promoted) |
| `bin/review-thread-gate.mjs` | `README.md` (unresolved PR thread gate) | `INVARIANTS.md` (PR gate evidence, if promoted) |
| `bin/auto-merge-readiness.mjs` | `README.md` (auto-merge readiness reporter) | `workflow-template.yaml` (adopter command wiring, if scaffolded) |
| `bin/auto-merge-readiness-collect.mjs` | `README.md` (auto-merge evidence collector) | `workflow-template.yaml` (adopter command wiring, if scaffolded) |
| `bin/auto-merge-run.mjs` | `README.md` (optional auto-merge executor policy) | `workflow-template.yaml` (adopter command wiring, if scaffolded) |
| `lib/advance-stage.sh` | `README.md` (stage transition helper) | `workflow-template.yaml` |
| `lib/write-stage-artifact.sh` | `README.md` (stage artifacts) | `references/doc-format.md` |
| `lib/register-stage-output.sh` | `README.md` (stage output registration) | `references/entity-body-schema.yaml` |
| `lib/update-entity-status.sh` | `README.md` (status updates) | `workflow-template.yaml` |
| `lib/registry-resolve.sh` | `README.md` (registry/default lookup) | `registry/defaults.yaml` |
| `lib/resolve-skill-routing.sh` | `README.md` (skills_needed routing) | `references/stack-skill-map.yaml` |
| `lib/sync-workflow-sot.sh` | `README.md` (workflow SOT sync) | `workflow-template.yaml` |
| `lib/extract-section.sh` and `lib/write-section.sh` | `INVARIANTS.md` (section-mediated access) | `references/doc-format.md` |
| `lib/extract-map.sh` and `lib/patch-map.sh` | `INVARIANTS.md` (canonical map CAS) | `references/flow-map-schema.yaml` |
| `lib/generate-ui-verify-spec.sh` | `README.md` (UI verify integration) | `references/doc-format.md` |
| `lib/*.sh` validators and resolvers | `README.md` (tooling reference) | Matching `references/*.yaml` schema |

### Hooks, Schemas, and Workflow Sources -> Doc Targets

| Source | Primary Doc Target | Secondary Doc Target |
|--------|--------------------|----------------------|
| `hooks/hooks.json` | `INVARIANTS.md` (hook enforcement layer) | `README.md` (runtime warnings) |
| `hooks/warn-direct-read.js` | `INVARIANTS.md` (direct-read warning) | `README.md` |
| `hooks/warn-state-drift.sh` | `INVARIANTS.md` (state drift warning) | `README.md` |
| `references/doc-format.md` | `README.md` (artifact format summary) | Stage skill docs |
| `references/entity-body-schema.yaml` | `README.md` (entity schema) | `workflow-template.yaml` |
| `references/flow-map-schema.yaml` | `README.md` (canonical doc flow map) | `INVARIANTS.md` |
| `references/debrief-schema.yaml` | `README.md` (debrief lifecycle) | `_debriefs-evidence/*.md` |
| `references/stack-skill-map.yaml` | `README.md` (runtime/stack skill routing) | `skills/ship-runtime-detect/SKILL.md` |
| `references/architecture-lens-triggers.yaml` | `README.md` (domain lens routing) | `skills/ship-design/SKILL.md` |
| `references/domain-knowledge/README.md` | `README.md` (domain knowledge registry) | `skills/domain-registry/SKILL.md` |
| `references/domain-knowledge/schema.md` | `README.md` (domain schema) | `skills/domain-registry/SKILL.md` |
| `registry/defaults.yaml` | `README.md` (default workflow settings) | `workflow-template.yaml` |
| `workflow-template.yaml` | `README.md` (adopter scaffold defaults) | `skills/ship-onboard/SKILL.md` |
| `.claude-plugin/plugin.json` | `README.md` (plugin metadata/version) | Release workflow notes |

## Doc Structure

| Doc File | Purpose | Auto-Sync Level | Notes |
|----------|---------|-----------------|-------|
| `README.md` | Plugin rationale, pipeline overview, skill triggers, adoption lifecycle, release checks | partial | Preserve design rationale; sync factual skill/source behavior. |
| `INVARIANTS.md` | Enforced principles, grep checks, hooks, captain-gate checklist | partial | Treat as canonical for rules; update only when source changed. |
| `references/doc-format.md` | Artifact and section format reference | partial | Sync stage artifact section names and helper usage. |
| `references/entity-body-schema.yaml` | Entity body schema | yes | Regenerable from schema changes. |
| `references/flow-map-schema.yaml` | Canonical doc flow-map schema | yes | Regenerable from map schema changes. |
| `references/debrief-schema.yaml` | Debrief schema | yes | Regenerable from schema changes. |
| `references/stack-skill-map.yaml` | Stack/runtime skill routing map | yes | Regenerable from routing source. |
| `references/architecture-lens-triggers.yaml` | Architecture lens triggers | yes | Regenerable from lens source files. |
| `references/domain-knowledge/README.md` | Domain knowledge registry overview | partial | Preserve curated domain explanations. |
| `references/domain-knowledge/schema.md` | Domain knowledge schema docs | partial | Sync schema facts only. |
| `registry/defaults.yaml` | Default workflow registry values | yes | Sync with workflow template and resolver behavior. |
| `workflow-template.yaml` | Adopter workflow scaffold | yes | Sync with onboarding/runtime expectations. |

## Style Guide

1. Write for maintainers operating Ship Flow under First Officer control.
2. Make stage ownership explicit: shape, design, plan, execute, verify, review, ship-final.
3. Prefer exact artifact names, shell helper paths, schema keys, and verdict names.
4. Keep adopter-project specifics out unless promoted into plugin source.
5. Use "Release gate" language for publish prerequisites.
6. Never weaken invariants to make docs easier; docs must reflect the source and checks.
7. For failures, use Issue | Cause | Fix tables and cite the enforcing primitive.
8. Release wording must be explicit: `ship-flow:doc-sync --check` runs before publish; Critical gaps block release or become a named blocked-release item.
9. Mark uncertain behavior `TODO: verify`; do not invent workflow stages, hooks, or schema fields.

## Probe Config

| Skill or Surface | Method | Reason |
|------------------|--------|--------|
| `ship-flow:doc-sync --check` | cli | Report-only mode; validates doc coverage without writes. |
| `ship-flow:doc-sync --probe-only` | cli | Probe-only mode should not write docs. |
| `ship-flow:doc-sync` | skip | Full sync writes documentation and may dispatch probes. |
| `bin/check-invariants.sh --help` | cli | Read-only help if supported. |
| `bin/check-invariants.sh --check skill-count` | cli | Read-only invariant check against plugin files. |
| `bin/canonical-doc-sync-checker.sh --help` | cli | Read-only help if supported. |
| `bin/workflow-doctor.sh --help` | cli | Read-only help if supported. |
| `lib/__tests__/test-skill-commit-lint.sh` | cli | Fixture-style shell test; no adopter writes expected. |
| `lib/__tests__/test-canonical-doc-sync-checker.sh` | cli | Fixture-style shell test for doc sync checker. |
| `lib/__tests__/test-workflow-sot-sync.sh` | cli | Fixture-style shell test; confirm temp-only behavior before running. |
| `ship-flow:ship` | skip | Orchestrates workflow state and implementation stages. |
| `ship-flow:ship-shape` | skip | Creates or updates workflow entities. |
| `ship-flow:ship-design` | skip | May produce design artifacts and dispatch workers. |
| `ship-flow:ship-plan` | skip | Writes stage artifacts and may dispatch workers. |
| `ship-flow:ship-execute` | skip | Executes implementation code. |
| `ship-flow:ship-verify` | skip | Runs project-specific verification. |
| `ship-flow:ship-review` | skip | Performs PR/review workflow. |
| `ship-flow:ship-onboard` | skip | Writes adopter workflow files. |
| `ship-flow:add-todos` | skip | Writes workflow todo artifacts. |
| `ship-flow:domain-registry` | skip | Writes/updates domain registry docs. |
| `ship-flow:ui-verify` | skip | Requires live app/browser evidence. |

## Post-Sync Hooks

1. **Release gate report** - if any Critical gaps remain, mark release gate `blocked` and name the source/doc pair.
2. **Invariant consistency** - if source changes affect principles or checks, report required `INVARIANTS.md` updates and matching `bin/check-invariants.sh` coverage.
3. **Workflow template consistency** - compare stage names, frontmatter keys, and default registry behavior across `README.md`, `workflow-template.yaml`, and `registry/defaults.yaml`.
4. **Stage skill coverage** - confirm every non-deprecated `skills/*/SKILL.md` has a Source Map row and a README/doc target.
5. **Probe config refresh** - mark any env-dependent shell tests as skip after probe evidence rather than treating them as pass.
6. **Plugin-release handoff** - if release command text needs changes, report exact requested wording for Worker A rather than editing outside scope.
7. **Blocked release summary** - if release is blocked, include owner, severity, source path, target doc, and suggested fix in the final report.
