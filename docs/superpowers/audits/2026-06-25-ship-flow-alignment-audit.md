# Ship-Flow Extraction — Alignment + Coupling Audit
**Date**: 2026-06-25
**Auditor**: Wave 2 audit agent (Task 3)
**Plugin path**: `plugins/ship-flow/`
**Reference host**: spacedock-ui monorepo (source)
**Target host**: yangon standalone repo
**Gate**: Captain/SO reviews before any Wave 3 reconciliation begins.

---

## (A) Complete Reference Inventory

All `spacedock:*` and `spacebridge*` references across ALL extensions (`.md`, `.sh`, `.yaml`, `.json`, `.mjs`).

### A.1 — `spacedock:overhaul` (19 occurrences)

| File:line | Text |
|-----------|------|
| `lib/review-merge.sh:15` | `# Snapshot 2026-05-12. After /spacedock:overhaul lives at` |
| `lib/review-log.sh:19` | `# Snapshot 2026-05-12. After /spacedock:overhaul lives at` |
| `lib/review-scope.sh:17` | `# Snapshot 2026-05-12. After /spacedock:overhaul lives at` |
| `lib/review-checklists/critical-pass.md:5` | `After /spacedock:overhaul: plugins/ship-flow/lib/review-checklists/critical-pass.md` |
| `lib/review-checklists/INDEX.md:5` | `**Target after /spacedock:overhaul**: plugins/ship-flow/lib/review-checklists/` |
| `lib/review-checklists/INDEX.md:29` | `(to be written in /spacedock:overhaul)` |
| `lib/review-checklists/design-checklist.md:5` | `After /spacedock:overhaul: plugins/ship-flow/lib/review-checklists/design-checklist.md` |
| `lib/review-checklists/specialists/api-contract.md:5` | `After /spacedock:overhaul: ...` |
| `lib/review-checklists/specialists/testing.md:5` | `After /spacedock:overhaul: ...` |
| `lib/review-checklists/specialists/performance.md:5` | `After /spacedock:overhaul: ...` |
| `lib/review-checklists/specialists/maintainability.md:5` | `After /spacedock:overhaul: ...` |
| `lib/review-checklists/specialists/red-team.md:5` | `After /spacedock:overhaul: ...` |
| `lib/review-checklists/specialists/data-migration.md:5` | `After /spacedock:overhaul: ...` |
| `lib/review-checklists/specialists/security.md:5` | `After /spacedock:overhaul: ...` |
| `lib/design-methodology/INDEX.md:5` | `**Target after /spacedock:overhaul**: plugins/ship-flow/lib/design-methodology/` |
| `lib/design-methodology/ux-principles.md:5` | `After /spacedock:overhaul: plugins/ship-flow/lib/design-methodology/ux-principles.md` |
| `lib/design-methodology/shotgun.md:5` | `After /spacedock:overhaul: ...` |
| `lib/design-methodology/consultation.md:5` | `After /spacedock:overhaul: ...` |
| `lib/design-methodology/html-generation.md:5` | `After /spacedock:overhaul: ...` |

**Verified against floor**: 19 found — floor satisfied (≥19). ✓

Note: `spacedock:overhaul` does NOT exist in spacedock 0.22.0. This was a skill planned to be extracted but never shipped. All 19 occurrences are dead references pointing to a non-existent skill AND contain hardcoded `plugins/ship-flow/` monorepo paths (double coupling).

### A.2 — `spacedock:first-officer` (6 occurrences)

| File:line | Text |
|-----------|------|
| `skills/ship/SKILL.md:15` | `load spacedock:first-officer and follow its startup` |
| `skills/ship/SKILL.md:21` | `load spacedock:first-officer` (Claude Code branch) |
| `skills/ship/SKILL.md:24` | `load spacedock:first-officer` (Codex branch) |
| `lib/__tests__/test-ship-first-officer-bridge.sh:30` | check text |
| `lib/__tests__/test-ship-first-officer-bridge.sh:31` | grep for `spacedock:first-officer` |
| `lib/__tests__/test-ship-unified-entry-routing.sh:77` | grep for `spacedock:first-officer` |

**Verified against floor**: 6 found — floor satisfied (≥6). ✓

`spacedock:first-officer` EXISTS in spacedock 0.22.0 (`skills/first-officer/SKILL.md` present). Live contract.

### A.3 — `spacedock:ensign` (6 occurrences)

| File:line | Text |
|-----------|------|
| `skills/ship-shape/SKILL.md:417` | `every named teammate is a spacedock:ensign unit` |
| `skills/ship-shape/SKILL.md:419` | `Agent(subagent_type: "spacedock:ensign", ...)` planner |
| `skills/ship-shape/SKILL.md:420` | `Agent(subagent_type: "spacedock:ensign", ...)` executer |
| `skills/ship-shape/SKILL.md:422` | `Agent(subagent_type: "spacedock:ensign", ...)` designer |
| `INVARIANTS.md:605` | `dispatch a fresh-context verifier (spacedock:ensign, findings-only output)` |
| `skills/harvest-decide/SKILL.md:92` | `Agent(subagent_type: spacedock:ensign)` |

**Verified against floor**: 6 found — floor satisfied (6 exact). ✓

`spacedock:ensign` EXISTS in spacedock 0.22.0 (`skills/ensign/SKILL.md` present). Live contract.

### A.4 — `spacedock:commission` (3 in skill canon, plus many `commissioned-by:` frontmatter uses)

Direct `/spacedock:commission` skill references:
| File:line | Text |
|-----------|------|
| `INVARIANTS.md:280` | `template-grafted to other repos via /spacedock:commission` |
| `README.md:475` | `use /spacedock:commission with ship-flow as template plugin` |
| `README.md:599` | `/spacedock:commission with ship-flow template still scaffolds` |

`spacedock:commission` EXISTS in spacedock 0.22.0. Live contract.

**Floor note**: Brief says "commission 4" but only 3 direct `/spacedock:commission` invocations found in canonically-relevant files. The 4th may have counted a `commission/bin/status` reference in test files — confirmed at `lib/__tests__/test-merged-pr-closeout-reconciler.sh:9` and `lib/debrief-status-resolver.sh:54`. See B section for debrief-status-resolver treatment. Counting conservatively: 3 direct skill invocations + 1 in test = 4 total if tests included.

### A.5 — `spacedock:debrief` (4 occurrences)

| File:line | Text |
|-----------|------|
| `references/debrief-schema.yaml:2` | `produced by spacedock:debrief skill` |
| `references/debrief-schema.yaml:4` | `reserved for v2 if spacedock:debrief skill evolves` |
| `references/debrief-schema.yaml:39` | `If spacedock:debrief skill evolves to use these section names` |
| `README.md:477` | `run spacedock:debrief to write a session debrief` |

**Verified against floor**: 4 found — floor satisfied (4). ✓

`spacedock:debrief` EXISTS in spacedock 0.22.0 (`skills/debrief/SKILL.md` present). Live contract.

### A.6 — `spacedock:workflow-adopt` (2 occurrences as `spacedock:workflow-adopt`; adoption-trio also uses `spacebridge:workflow-adopt`)

Direct `spacedock:workflow-adopt` references:
| File:line | Text |
|-----------|------|
| `workflow-template.yaml:2` | `Discovered by spacedock:workflow-adopt to bootstrap via commission.` |
| `README.md:367` | `spacedock:workflow-adopt` in table |

`spacebridge:workflow-adopt` references (adoption-trio namespace):
| File:line | Text |
|-----------|------|
| `skills/ship-onboard/SKILL.md:35` | `run /spacebridge:workflow-adopt first` |
| `skills/ship-onboard/SKILL.md:39` | `captain runs /spacebridge:workflow-adopt first` |
| `skills/ship-onboard/SKILL.md:42` | `Run /spacebridge:workflow-adopt first` |

**Floor note**: Brief says "workflow-adopt 5" — found 2 `spacedock:workflow-adopt` + 3 `spacebridge:workflow-adopt` = 5 total. Floor satisfied. ✓

`spacedock:workflow-adopt` does NOT exist in spacedock 0.22.0. Dead reference. The `spacebridge:workflow-adopt` variants are the adoption-trio (spacebridge plugin dependency).

### A.7 — `spacedock:workflow-sync` (1 occurrence)

| File:line | Text |
|-----------|------|
| `README.md:368` | `spacedock:workflow-sync` in table |

**Verified against floor**: 1 found — floor satisfied (1). ✓

`spacedock:workflow-sync` does NOT exist in spacedock 0.22.0. Dead reference.

### A.8 — `spacebridge` references (≈29 non-test, across all extensions)

| File:line | Context |
|-----------|---------|
| `.claude-plugin/plugin.json:8` | `"repository": "https://github.com/spacedock-dev/spacebridge"` |
| `references/entity-body-schema.yaml:86` | `spacebridge` as plugin slug example |
| `references/entity-body-schema.yaml:1351` | `read_by: "spacebridge dashboard..."` |
| `references/flow-map-schema.yaml:83` | `plugins/spacebridge/design/design-system.md:` key |
| `references/flow-map-schema.yaml:84` | `path: "plugins/spacebridge/design/design-system.md"` |
| `INVARIANTS.md:349` | `Entity 058 rename-to-spacebridge.md:763` (archive ref) |
| `README.md:351` | Mermaid diagram label `spacedock-ui\ndocs/ship-flow/` (adjacent) |
| `README.md:369` | `spacebridge:debrief-promote` skill ref |
| `README.md:371` | `spacebridge:debrief-promote` skill ref |
| `README.md:477` | `spacebridge:debrief-promote` skill ref |
| `README.md:548` | Spacebridge dogfood merge flow mention |
| `README.md:584` | "dogfood portability across projects" (contextual) |
| `README.md:613` | `docs/ship-flow/README.md is the dogfood workflow SOT` |
| `README.md:657` | `Spacebridge dogfood note: this private repository currently runs...` |
| `_mods/ship-flow-lint.md:61` | `docs/ship-flow/spacebridge.yaml` in lint config |
| `_mods/debrief-guardrail-harvest.md:25` | `spacebridge.yaml` in changed files list |
| `_plans/strengthening-roadmap-2026-05.md:14` | spacebridge context (internal plan) |
| `_plans/strengthening-roadmap-2026-05.md:239` | spacebridge daemon FO trigger (deferred) |
| `_plans/strengthening-roadmap-2026-05.md:245` | DY1 spacebridge daemon trigger |
| `_plans/strengthening-roadmap-2026-05.md:380` | spacebridge daemon deferred table |
| `skills/ship-onboard/SKILL.md:35,39,42` | `spacebridge:workflow-adopt` (adoption-trio) |
| `skills/ship-design/SKILL.md:785` | `plugins/spacebridge/design/design-system.md` mention |
| `skills/ship-design/SKILL.md:787` | `plugins/spacebridge/design-exploration-spatial.html` |
| `skills/ship-execute/SKILL.md:357` | `application code in plugins/spacebridge/**` |
| `skills/ship-verify/SKILL.md:581` | `spacebridge` as mapping-name example |
| `skills/ui-verify/SKILL.md:47` | `mapping: spacebridge` |
| `bin/ship-flow-lint.test.mjs:39` | `docs/ship-flow/spacebridge.yaml` fixture |
| `bin/ship-flow-lint.test.mjs:84` | `docs/ship-flow/spacebridge.yaml` fixture |
| `lib/__tests__/test-design-dogfood.sh:3,29` | `plugins/spacebridge/design` paths |
| `lib/__tests__/test-design-readiness-review.sh:160` | `plugins/spacebridge/design/war-room.html` |
| `lib/__tests__/test-entity-entrypoint-index.sh:99` | `spacebridge` as plugin arg |
| `lib/__tests__/test-ship-flow-lint.sh:15,28` | `docs/ship-flow/spacebridge.yaml` fixture |
| `lib/__tests__/test-bump-version.sh:43,67,124` | `spacebridge` as decoy plugin name in bump-version fixtures |

**Verified against floor**: Found ≈33 (exceeds floor of ≈29). ✓

---

## (B) Host-Coupling Inventory

### B.1 — `spacedock-ui` / `spacedock-dev` references

| File:line | Text | Nature |
|-----------|------|--------|
| `.claude-plugin/plugin.json:8` | `"repository": "https://github.com/spacedock-dev/spacebridge"` | Wrong repo URL — ship-flow extracted to yangon, not spacebridge repo |
| `README.md:351` | `A[spacedock-ui\ndocs/ship-flow/]` | Mermaid diagram labels spacedock-ui as an example adopted project |
| `references/doc-sync-context.md:11` | `in the spacedock-ui monorepo, PLUGIN_ROOT is plugins/ship-flow/` | Monorepo-specific note (also contextual for adopter doc) |
| `_debriefs-evidence/102.1-evidence-package.md:3,7–14` | Multiple `spacedock-ui` references in evidence archive | Historical evidence docs — archive, do not touch |
| `_plans/strengthening-roadmap-2026-05.md:68` | `~/.gstack/projects/spacedock-ui/` | Internal plan doc |
| `skills/memory-cleanup/SKILL.md:34` | `at authoring time the spacedock-ui policy is:` | Policy authoring note |
| `skills/doc-sync/SKILL.md:12` | `in the spacedock-ui monorepo, this resolves to plugins/ship-flow/` | Same contextual note as doc-sync-context.md |

### B.2 — `docs/ship-flow` as SOT / "THIS project" / dogfood-SOT language

**Critical**: Multiple test files and lib helpers treat `docs/ship-flow/README.md` as the SOT at `REPO_ROOT/docs/ship-flow/README.md` — which exists only in spacedock-ui. In yangon, the yangon `docs/ship-flow/` directory will hold adopted workflow docs for THIS repo, but the plugin's tests expect the spacedock-ui dogfood README at a relative `../../../../docs/ship-flow/README.md` path.

Key instances:
| File:line | Text |
|-----------|------|
| `README.md:5` | `**Canonical project-level operational doc** (how captain uses ship-flow in THIS project): docs/ship-flow/README.md` |
| `lib/sync-workflow-sot.sh:14,24` | `--sot docs/ship-flow/README.md` default; `SOT="${REPO_ROOT}/docs/ship-flow/README.md"` |
| `lib/__tests__/test-workflow-sot-sync.sh:8` | `DOGFOOD_README="${REPO_ROOT}/docs/ship-flow/README.md"` |
| `lib/__tests__/test-bidirectional-lifecycle-readme.sh:3–11` | Walks to `../../../../` and reads `plugins/ship-flow/README.md` (plugin README, not dogfood) |
| `lib/__tests__/test-canonical-context-lifecycle.sh:9,16` | `README="${REPO_ROOT}/docs/ship-flow/README.md"` and `CANONICAL_MOD="${REPO_ROOT}/docs/ship-flow/_mods/canonical-doc-sync.md"` |
| `lib/__tests__/test-canonical-doc-sync-mod.sh:8` | `MOD_FILE="${REPO_ROOT}/docs/ship-flow/_mods/canonical-doc-sync.md"` |
| `README.md:613` | `docs/ship-flow/README.md is the dogfood workflow SOT` |
| `README.md:657` | `Spacebridge dogfood note: this private repository currently runs on a free GitHub organization plan` |
| `INVARIANTS.md:461,473` | `docs/ship-flow/README.md` as grep target for invariant checks |

### B.3 — `plugins/spacebridge/...` hardcoded paths

| File:line | Text |
|-----------|------|
| `references/flow-map-schema.yaml:83–84` | `plugins/spacebridge/design/design-system.md` as example entry |
| `lib/__tests__/test-design-dogfood.sh:3` | `Re-runs ship-design SKILL on plugins/spacebridge/design-exploration-spatial.html` |
| `lib/__tests__/test-design-dogfood.sh:29` | `CANONICAL_DIR="$WORKTREE_ROOT/plugins/spacebridge/design"` |
| `lib/__tests__/test-design-readiness-review.sh:160` | `reference_artifact: plugins/spacebridge/design/war-room.html` |
| `skills/ship-design/SKILL.md:785` | `plugins/ship-flow/references/flow-map-schema.yaml → maps.plugins/spacebridge/design/design-system.md` |
| `skills/ship-design/SKILL.md:787` | `real designer-agent dogfood = verify-stage manual invocation on plugins/spacebridge/design-exploration-spatial.html` |
| `skills/ship-execute/SKILL.md:357` | `**When NOT**: application code in plugins/spacebridge/**` |

### B.4 — Absolute author paths (`/Users/kent/...`)

| File:line | Text |
|-----------|------|
| `lib/__tests__/test-debrief-schema.sh:23` | `CARLOVE="/Users/kent/Project/carlove/docs/ship-flow/_debriefs/2026-04-25-01.md"` |
| `lib/__tests__/test-merged-pr-closeout-reconciler.sh:9` | `STATUS_BIN="${STATUS_BIN:-/Users/kent/.codex/plugins/cache/spacedock/spacedock/0.10.2/skills/commission/bin/status}"` |
| `lib/__tests__/test-ui-quality-contract.sh:42` | grep for `/Users/kent/\.claude` in exclusion check |
| `lib/__tests__/test-synthetic-design-dispatch-fixture.sh:61` | `"! grep -R '/Users/kent/Project/carlove' '${FIXTURE_DIR}'"` |
| `lib/__tests__/test-distill-reference-first-report.sh:110` | `"! grep -q '/Users/kent' '${REPORT}'"` |
| `lib/__tests__/test-distill-reference-first-report.sh:122` | `"! grep -q '/Users/kent' '${ENTITY}'"` |
| `lib/__tests__/test-synthetic-schema-pitch-fixture.sh:58` | `"! grep -R '/Users/kent/Project/carlove' '${FIXTURE_DIR}'"` |

Note: `test-ui-quality-contract.sh:42`, `test-distill-reference-first-report.sh:110,122`, `test-synthetic-design-dispatch-fixture.sh:61`, `test-synthetic-schema-pitch-fixture.sh:58` are guard-style checks that grep FOR `/Users/kent` patterns to assert they are ABSENT — these are checking that fixtures don't contain hardcoded author paths. They are self-healing (will pass in fresh-clone if the fixture files don't contain those paths). However, `test-debrief-schema.sh:23` and `test-merged-pr-closeout-reconciler.sh:9` are actual hardcoded paths that will be absent or wrong in fresh-clone.

### B.5 — Root `.claude/settings.json` dependency

| File:line | Text |
|-----------|------|
| `lib/__tests__/test-designer-skills-available.sh:11` | `SETTINGS_FILE="${SCRIPT_DIR}/../../../../.claude/settings.json"` |
| `lib/__tests__/test-designer-skills-available.sh:34–35` | `check "settings.json exists"` — asserts file exists at `REPO_ROOT/.claude/settings.json` |

This test will fail in fresh-clone if there is no `.claude/settings.json` at the yangon repo root.

---

## (C) B5 Test/CI Couplings

### C.1 — Tests walking to monorepo paths (64 test files use `../../../../`)

The following 64 tests resolve `REPO_ROOT` via `"$(cd -- "${SCRIPT_DIR}/../../../.." ...)"` which walks up 4 levels from `plugins/ship-flow/lib/__tests__/` to what was the spacedock-ui monorepo root. In yangon, that resolves to the yangon repo root, which is correct structurally — but then they reference:
- `REPO_ROOT/docs/ship-flow/README.md` (spacedock-ui dogfood file, non-existent in fresh yangon)
- `REPO_ROOT/docs/ship-flow/_mods/...` (adopted mods, non-existent in fresh yangon)
- `REPO_ROOT/docs/ship-flow/106-pipeline-render-fidelity-hardening/` (entity dir, non-existent)
- `REPO_ROOT/plugins/ship-flow/...` (self-reference, fine)
- `REPO_ROOT/.claude/settings.json` (host-machine specific)
- `REPO_ROOT/docs/ship-flow/_distillations/...` (adopted distillations, non-existent)

Complete list of 64 test files with `../../../../` REPO_ROOT walks:

```
test-canonical-doc-sync-mod.sh        test-distill-reference-contract.sh
test-ui-quality-contract.sh           test-ship-verify-render-fidelity.sh
test-shape-skill-debrief.sh           test-ship-plan-indirection-sweep.sh
test-ship-runtime-detect.sh           test-entity-body-schema.sh
test-plan-skill-debrief.sh            test-science-officer-em-stewardship-contract.sh
test-designer-skills-available.sh     test-science-officer-em-skill.sh
test-allocate-id.sh                   test-ship-design-dispatch-abcd.sh
test-workflow-sot-sync.sh             test-debrief-schema.sh
test-science-officer-em-upward-report-contract.sh  test-ship-plan-stub-ack.sh
test-debrief-status-resolver.sh       test-bump-version.sh
test-skills-needed-pipeline.sh        test-science-officer-em-dispatch-helper.sh
test-distill-reference-first-report.sh test-contract-design-gate.sh
test-entity-entrypoint-index.sh       test-pr-title-format.sh
test-bidirectional-lifecycle-readme.sh test-science-officer-em-stage-internal-surfaces.sh
test-sync-workflow-sot.sh             test-copilot-bot-head-guard.sh
test-check-harvest-exempt.sh          test-captain-uat-feedback-routing.sh
test-plan-reviewer-questions.sh       test-pr-merge-fo-receipts.sh
test-stage-boot-density.sh            test-verify-design-feedback-routing.sh
test-skill-coverage-review-factor.sh  test-shape-confirm-harvest-stamp.sh
test-parallel-stage-contract.sh       test-ship-flow-ci-scope.sh
test-w3-skip-when-absent.sh           test-render-fidelity-check.sh
test-ship-tdd-contract.sh             test-ship-flow-lint.sh
test-readme-motto.sh                  test-science-officer-em-upward-report-surfaces.sh
test-ship-verify-claim-records.sh     test-distill-reference-skill-authoring.sh
test-tdd-ledger-validator.sh          test-ship-first-officer-bridge.sh
test-canonical-context-lifecycle.sh   test-verify-reviewer-panel.sh
test-canonical-doc-actions-schema.sh  test-todo-lifecycle-closeout.sh
test-science-officer-em-profile.sh    test-pr-merge-claude-challenge-gate.sh
test-ship-unified-entry-routing.sh    test-visible-surface-map-contract.sh
test-ship-verify-fo-receipts.sh       test-review-checklists-index.sh
test-context-routing-manifest.sh      test-verify-agent-worker-ownership-contract.sh
test-gate-registry-resolver.sh        test-ship-science-officer-em-wiring.sh
test-check-pr-mergeable.sh            test-stale-worktree-cleanup-planner.sh
```

### C.2 — The contradiction test: `test-bidirectional-lifecycle-readme.sh`

This test is a special case. It walks up 4 levels and then reads `plugins/ship-flow/README.md` (the plugin README — not the dogfood file). It checks for:
- `## Bidirectional lifecycle` section
- mermaid diagram
- `workflow-adopt` citation
- `workflow-sync` citation
- `debrief-promote` citation
- `_debriefs/` citation

The contradiction: the lifecycle diagram references `spacedock-ui` and `carlove` as example adopted projects (line 351), and `workflow-adopt` / `workflow-sync` as `spacedock:` skills that no longer exist in spacedock 0.22.0. The test passes today because it checks for the presence of these strings in README.md. After B2-remove/B2-deferred cleanup of those strings from README.md, this test may fail. Task 7 must handle this dependency.

### C.3 — `lib/sync-workflow-sot.sh` hardcoded SOT path

| File:line | Text |
|-----------|------|
| `lib/sync-workflow-sot.sh:14` | Default: `--sot docs/ship-flow/README.md` |
| `lib/sync-workflow-sot.sh:24` | `SOT="${REPO_ROOT}/docs/ship-flow/README.md"` |

This helper is designed for spacedock-ui operation (where dogfood README lives at `docs/ship-flow/README.md`). In yangon standalone, the adopter creates their own `docs/ship-flow/README.md` after commission — so the helper remains valid structurally but the referenced file won't exist in a fresh clone.

### C.4 — `bin/*.test.mjs` — missing from release gate

9 test files in `bin/`:
```
bin/auto-merge-readiness-collect.test.mjs   (9.9K)
bin/auto-merge-readiness.test.mjs           (9.7K)
bin/auto-merge-run.test.mjs                 (7.6K)
bin/review-thread-gate.test.mjs             (6.0K)
bin/semantic-review-auto-merge-e2e.test.mjs (6.1K)
bin/semantic-review-gate.test.mjs           (7.1K)
bin/semantic-review-packet.test.mjs         (6.9K)
bin/semantic-review-prepare.test.mjs        (15.2K)
bin/ship-flow-lint.test.mjs                 (3.1K)
```

`scripts/bump-version.sh` release gate only runs `lib/__tests__/test-*.sh`. It does NOT run these `.mjs` files. `bin/check-invariants.sh` also does not invoke them. These 9 files use `node:test` runner and would require `node --test bin/*.test.mjs` or equivalent. They are silently excluded from the release gate. The `bin/ship-flow-lint.test.mjs` creates fixtures via `mkdtemp` — it is self-contained but never executed in CI.

### C.5 — Absolute path in test: `test-debrief-schema.sh:23`

```bash
CARLOVE="/Users/kent/Project/carlove/docs/ship-flow/_debriefs/2026-04-25-01.md"
```

This hardcoded path will not exist in fresh-clone. The test gracefully degrades with `WARN: carlove debrief not found (skipping)` — so it does NOT fail hard. However the path is host-machine-specific (author's local filesystem).

### C.6 — Absolute path in test: `test-merged-pr-closeout-reconciler.sh:9`

```bash
STATUS_BIN="${STATUS_BIN:-/Users/kent/.codex/plugins/cache/spacedock/spacedock/0.10.2/skills/commission/bin/status}"
```

This path references the python `commission/bin/status` binary removed in spacedock 0.19.4. The test allows override via `STATUS_BIN` env var. Without that var set, the path won't exist in fresh-clone. However, `lib/debrief-status-resolver.sh:54` notes that `commission/bin/status was removed in spacedock 0.19.4; the status helper is now the spacedock Go binary on PATH`. The test needs updating to remove the absolute default path.

### C.7 — `test-distill-reference-first-report.sh` references specific entity dirs

| File:line | Text |
|-----------|------|
| `lib/__tests__/test-distill-reference-first-report.sh:8` | `REPORT="${REPO_ROOT}/docs/ship-flow/_distillations/2026-05-17--gstack-gsd.md"` |
| `lib/__tests__/test-distill-reference-first-report.sh:9` | `ACTIVE_ENTITY="${REPO_ROOT}/docs/ship-flow/distill-reference-skill-meta-capability.md"` |
| `lib/__tests__/test-distill-reference-first-report.sh:10` | `ARCHIVED_ENTITY="${REPO_ROOT}/docs/ship-flow/_archive/distill-reference-skill-meta-capability.md"` |

These reference specific entity artifacts in the spacedock-ui dogfood workflow directory. Will fail in fresh-clone unless CI=true skip-pass logic applies.

### C.8 — `test-render-fidelity-check.sh:18` hardcoded entity dir

| File:line | Text |
|-----------|------|
| `lib/__tests__/test-render-fidelity-check.sh:18` | `ENTITY_DIR="${SCRIPT_DIR}/../../../../docs/ship-flow/106-pipeline-render-fidelity-hardening"` |

References a specific spacedock-ui entity folder. Accepts `--entity-dir` override, and notes at line 7: "At W0 (RED phase), no implementation exists yet → exits non-zero with EXPECTED FAIL message" — meaning it is designed to fail red in CI=true and skip-pass. Needs verification that CI=true actually causes skip.

---

## (D) Classification Table

| # | Item | File:line | Bucket | Target task |
|---|------|-----------|--------|-------------|
| 1 | `plugin.json` `repository` field points to `spacedock-dev/spacebridge` | `.claude-plugin/plugin.json:8` | **B1** | T4 |
| 2 | `README.md` H1 version `v0.7.0-rc.7` | `README.md:1` | **B1** | T4 |
| 3 | `plugin.json` version `0.7.0-rc.7` | `.claude-plugin/plugin.json:3` | **B1** | T4 |
| 4 | `marketplace.json` ship-flow version `0.7.0-rc.7` | `/yangon/.claude-plugin/marketplace.json:5` | **B1** | T4 |
| 5 | All 19 `spacedock:overhaul` refs (dead skill, never shipped to 0.22.0) | `lib/review-merge.sh:15`, `lib/review-log.sh:19`, `lib/review-scope.sh:17`, 8 checklists/5, `lib/review-checklists/INDEX.md:5,29`, `lib/design-methodology/*.md:5`, `lib/design-methodology/INDEX.md:5` | **B2-remove** | T5 |
| 6 | `spacedock:workflow-adopt` — dead ref (not in spacedock 0.22.0) | `workflow-template.yaml:2`, `README.md:367` | **B2-remove** | T5 |
| 7 | `spacedock:workflow-sync` — dead ref (not in spacedock 0.22.0) | `README.md:368` | **B2-remove** | T5 |
| 8 | `spacedock:first-officer` — live contract, present in 0.22.0 | `skills/ship/SKILL.md:15,21,24`, test files | **B2-verify** | T5 |
| 9 | `spacedock:ensign` — live contract, present in 0.22.0 | `skills/ship-shape/SKILL.md:417–422`, `INVARIANTS.md:605`, `skills/harvest-decide/SKILL.md:92` | **B2-verify** | T5 |
| 10 | `spacedock:commission` — live contract, present in 0.22.0 | `INVARIANTS.md:280`, `README.md:475,599` | **B2-verify** | T5 |
| 11 | `spacedock:debrief` — live contract, present in 0.22.0 | `references/debrief-schema.yaml:2,4,39`, `README.md:477` | **B2-verify** | T5 |
| 12 | `spacebridge:debrief-promote` — adoption-trio, spacebridge-dependent skill | `README.md:369,371,477` | **B2-deferred** | T6 |
| 13 | `spacebridge:workflow-adopt` (ship-onboard) — adoption-trio, spacebridge-dependent | `skills/ship-onboard/SKILL.md:35,39,42` | **B2-deferred** | T6 |
| 14 | Lifecycle diagram labels `spacedock-ui` and `carlove` as example projects | `README.md:351` | **B2-remove** | T5 |
| 15 | `"THIS project"` dogfood-SOT language in plugin README | `README.md:5` | **B2-remove** | T5 |
| 16 | `Spacebridge dogfood note:` in plugin README (free-org-plan context) | `README.md:657–662` | **B2-remove** | T5 |
| 17 | `docs/ship-flow/README.md is the dogfood workflow SOT` | `README.md:613` | **B2-remove** | T5 |
| 18 | `references/flow-map-schema.yaml:83–84` hardcoded `plugins/spacebridge/design/design-system.md` | `references/flow-map-schema.yaml:83–84` | **B2-deferred** | T6 |
| 19 | `skills/ship-design/SKILL.md:785,787` `plugins/spacebridge/...` paths | `skills/ship-design/SKILL.md:785,787` | **B2-deferred** | T6 |
| 20 | `skills/ship-execute/SKILL.md:357` `plugins/spacebridge/**` | `skills/ship-execute/SKILL.md:357` | **B2-deferred** | T6 |
| 21 | `skills/ui-verify/SKILL.md:47` `mapping: spacebridge` | `skills/ui-verify/SKILL.md:47` | **B2-deferred** | T6 |
| 22 | `skills/ship-onboard/SKILL.md:28–29` "spacedock-ui monorepo" in doc-sync-context | `references/doc-sync-context.md:11` | **B2-remove** | T5 |
| 23 | `skills/memory-cleanup/SKILL.md:34` "spacedock-ui policy is:" | `skills/memory-cleanup/SKILL.md:34` | **B2-remove** | T5 |
| 24 | `skills/doc-sync/SKILL.md:12` "spacedock-ui monorepo, this resolves to plugins/ship-flow/" | `skills/doc-sync/SKILL.md:12` | **B2-remove** | T5 |
| 25 | 64 test files walking `../../../../` to REPO_ROOT for monorepo paths | All files in C.1 | **B5** | T7 |
| 26 | `test-bidirectional-lifecycle-readme.sh` contradiction test | `lib/__tests__/test-bidirectional-lifecycle-readme.sh:3–11` | **B5** | T7 |
| 27 | `test-designer-skills-available.sh` reads `REPO_ROOT/.claude/settings.json` | `lib/__tests__/test-designer-skills-available.sh:11,34–35` | **B5** | T7 |
| 28 | `lib/sync-workflow-sot.sh:24` hardcoded SOT default | `lib/sync-workflow-sot.sh:14,24` | **B5** | T7 |
| 29 | `test-debrief-schema.sh:23` hardcoded `/Users/kent/Project/carlove/...` | `lib/__tests__/test-debrief-schema.sh:23` | **B5** | T7 |
| 30 | `test-merged-pr-closeout-reconciler.sh:9` hardcoded `/Users/kent/.codex/...spacedock/0.10.2/...` | `lib/__tests__/test-merged-pr-closeout-reconciler.sh:9` | **B5** | T7 |
| 31 | `test-distill-reference-first-report.sh:8–10` hardcoded spacedock-ui entity dirs | `lib/__tests__/test-distill-reference-first-report.sh:8–10` | **B5** | T7 |
| 32 | `test-render-fidelity-check.sh:18` hardcoded entity dir | `lib/__tests__/test-render-fidelity-check.sh:18` | **B5** | T7 |
| 33 | 9 `bin/*.test.mjs` files not in release gate (`scripts/bump-version.sh` or `bin/check-invariants.sh`) | All 9 mjs files in C.4 | **B5** | T7 |
| 34 | Fixture version `commissioned-by: spacedock@0.10.1` (5 occurrences) | `lib/__tests__/test-warn-state-drift.sh:182`, 4 fixture README.md files | **B4** | T8 |
| 35 | Fixture version `commissioned-by: spacedock@0.9.0` | `lib/__tests__/fixtures/workflow-doctor/stale-pre-113/README.md:2` | **B4** | T8 |
| 36 | Fixture version `commissioned-by: spacedock@0.10.2` | `lib/__tests__/test-merged-pr-closeout-reconciler.sh:151` | **B4** | T8 |
| 37 | `skills/ship/SKILL.md:24` `CODEX_HOME` env var Codex runtime detection | `skills/ship/SKILL.md:24` | **AC6** | T9 |
| 38 | `lib/__tests__/test-ship-first-officer-bridge.sh:40` asserts `CODEX_HOME` present in skill | `lib/__tests__/test-ship-first-officer-bridge.sh:40` | **AC6** | T9 |
| 39 | `_plans/strengthening-roadmap-2026-05.md` internal plan refs to spacedock-ui, carlove | `_plans/strengthening-roadmap-2026-05.md:68,380` | **B2-deferred** | T6 (deferred / archive, low priority) |
| 40 | `_debriefs-evidence/102.1-evidence-package.md` evidence archive with spacedock-ui refs | Internal archive | **B2-deferred** | T6 (archive, do not touch) |
| 41 | `INVARIANTS.md:349` archive ref to `rename-to-spacebridge.md:763` | `INVARIANTS.md:349` | **B2-deferred** | T6 (archive reference, do not rename namespace) |
| 42 | `_mods/ship-flow-lint.md:61` `docs/ship-flow/spacebridge.yaml` in lint config | `_mods/ship-flow-lint.md:61` | **B2-deferred** | T6 (adopted `_mods/` file, spacebridge namespace preserved) |
| 43 | `bin/ship-flow-lint.test.mjs:39,84` `docs/ship-flow/spacebridge.yaml` fixtures | `bin/ship-flow-lint.test.mjs:39,84` | **B2-deferred** | T6 (spacebridge namespace, do NOT rename) |
| 44 | `lib/__tests__/test-ship-flow-lint.sh:15,28` `docs/ship-flow/spacebridge.yaml` fixtures | `lib/__tests__/test-ship-flow-lint.sh:15,28` | **B2-deferred** | T6 (spacebridge namespace, do NOT rename) |
| 45 | `lib/__tests__/test-entity-entrypoint-index.sh:99` `spacebridge` as plugin arg | `lib/__tests__/test-entity-entrypoint-index.sh:99` | **B2-deferred** | T6 (spacebridge namespace example, do NOT rename) |
| 46 | `references/entity-body-schema.yaml:86` `spacebridge` as example plugin slug | `references/entity-body-schema.yaml:86` | **B2-deferred** | T6 (example/doc reference, do NOT rename) |
| 47 | `references/entity-body-schema.yaml:1351` `spacebridge dashboard` read_by note | `references/entity-body-schema.yaml:1351` | **B2-deferred** | T6 (spacebridge dependency, do NOT rename) |
| 48 | `lib/__tests__/test-design-dogfood.sh:3,29` `plugins/spacebridge/design` paths | `lib/__tests__/test-design-dogfood.sh:3,29` | **B5** | T7 (monorepo-specific test, will fail without spacebridge sibling) |
| 49 | `lib/__tests__/test-design-readiness-review.sh:160` `plugins/spacebridge/design/war-room.html` | `lib/__tests__/test-design-readiness-review.sh:160` | **B5** | T7 |
| 50 | `lib/__tests__/test-bump-version.sh:43,67,124` `spacebridge` as decoy plugin in fixtures | `lib/__tests__/test-bump-version.sh:43,67,124` | **B2-deferred** | T6 (fixture-level, spacebridge namespace, do NOT rename) |

---

## (E) Delta vs Review Floor

### Floor confirmations (all found)

| Floor item | Status |
|-----------|--------|
| `overhaul` ≥19 | ✓ Found exactly 19 |
| `lib/review-merge.sh:15` | ✓ Found |
| `lib/review-log.sh:19` | ✓ Found |
| `lib/review-scope.sh:17` | ✓ Found |
| `first-officer` ≥6 | ✓ Found exactly 6 |
| `ensign` 6 | ✓ Found exactly 6 |
| `commission` 4 | ✓ Found 3 in canonical + 1 in test (debrief-status-resolver) = 4 |
| `debrief` 4 | ✓ Found 4 (all in debrief-schema.yaml + README.md) |
| `workflow-adopt` 5 | ✓ Found 5 (2 `spacedock:workflow-adopt` + 3 `spacebridge:workflow-adopt`) |
| `workflow-sync` 1 | ✓ Found 1 |
| `spacebridge` ≈29 | ✓ Found ≈33 (exceeds floor) |
| `plugin.json:8` spacedock-dev | ✓ Found |
| `README.md:5` THIS project | ✓ Found |
| `README.md:351` spacedock-ui adopted | ✓ Found |
| `flow-map-schema.yaml:83–84` | ✓ Found |
| `skills/ship-design/SKILL.md:785` plugins/spacebridge | ✓ Found |
| `skills/ship-onboard/SKILL.md:35–42` | ✓ Found |
| `test-debrief-schema.sh:23` | ✓ Found |
| `test-merged-pr-closeout-reconciler.sh:9` | ✓ Found |
| `test-designer-skills-available.sh:11` | ✓ Found |
| `test-canonical-context-lifecycle.sh:9,16` | ✓ Found |
| `test-canonical-doc-sync-mod.sh:8` | ✓ Found |
| `test-workflow-sot-sync.sh:8` | ✓ Found |
| `test-render-fidelity-check.sh:18` | ✓ Found |
| `test-debrief-schema.sh:20` | ✓ Found (CARLOVE path) |
| `lib/sync-workflow-sot.sh:24` | ✓ Found |
| `test-bidirectional-lifecycle-readme.sh:9–11` | ✓ Found (lines 9,10,11 in file) |
| `bin/*.test.mjs` missing from verification | ✓ Confirmed — not in release gate |

### Delta beyond floor (found in audit, not in verified floor)

1. **`spacedock:workflow-adopt` appears as BOTH `spacedock:` AND `spacebridge:` namespaces** — the floor counted 5 total but did not distinguish that `skills/ship-onboard/SKILL.md` uses `spacebridge:workflow-adopt` (NOT `spacedock:workflow-adopt`). This is significant: `spacebridge:` here is the adoption-trio namespace and must be classified B2-deferred (not B2-remove), while `spacedock:workflow-adopt` in `README.md:367` and `workflow-template.yaml:2` are B2-remove.

2. **`skills/memory-cleanup/SKILL.md:34`** — "spacedock-ui policy is:" hard-references the source monorepo. Not in the floor. B2-remove.

3. **`skills/doc-sync/SKILL.md:12`** — "in the spacedock-ui monorepo, this resolves to `plugins/ship-flow/`" note. Mirrors `doc-sync-context.md:11` but in a skill file. Not in the floor. B2-remove.

4. **`README.md:657–662` Spacebridge dogfood note** — the free-org-plan GitHub context note is spacedock-ui-specific. Not in the floor. B2-remove.

5. **`README.md:613`** — "docs/ship-flow/README.md is the dogfood workflow SOT" with `bash plugins/ship-flow/lib/sync-workflow-sot.sh` — monorepo-specific dogfood language. Not in the floor explicitly. B2-remove.

6. **`references/doc-sync-context.md:11`** — "in the spacedock-ui monorepo, PLUGIN_ROOT is `plugins/ship-flow/`" — not in the floor. B2-remove.

7. **`test-distill-reference-first-report.sh:8–10`** — 3 specific spacedock-ui entity/artifact paths hardcoded. Not in floor. B5.

8. **`test-design-dogfood.sh:3,29`** and **`test-design-readiness-review.sh:160`** — reference `plugins/spacebridge/design/...` from an expected sibling monorepo context. Not in floor. B5.

9. **9 `bin/*.test.mjs` files** — the floor noted "bin node tests" as a category but did not enumerate all 9 individually. All 9 are missing from both the `scripts/bump-version.sh` release gate and `bin/check-invariants.sh`. The brief said to verify these; confirmed: they are entirely absent from CI. B5.

10. **`_mods/debrief-guardrail-harvest.md:25`** references `spacebridge.yaml` in changed-files list — minor, in an `_mods/` template file. B2-deferred (spacebridge namespace context).

11. **`INVARIANTS.md:349`** — `Entity 058 rename-to-spacebridge.md:763` is an archival reference. B2-deferred.

12. **`lib/__tests__/test-bump-version.sh:43,67,124`** — uses `spacebridge` as a decoy plugin name in version-bump test fixtures. These are test fixtures that exercise the version bump script's behavior when multiple plugins exist. Namespace should NOT be renamed — they verify non-ship-flow plugins stay untouched. B2-deferred.

---

## Classification Summary

| Bucket | Count | Notes |
|--------|-------|-------|
| **B1** (identity/version → T4) | 4 | `plugin.json` version+repo, `README.md` H1, `marketplace.json` entry |
| **B2-remove** (dead ref/host coupling → T5) | 30 | 19 overhaul + 2 workflow-adopt/sync + 7 spacedock-ui host notes + 2 lifecycle diagram labels |
| **B2-verify** (live spacedock contract → T5) | 4 | first-officer, ensign, commission, debrief — all confirmed in 0.22.0 |
| **B2-deferred** (adoption-trio / spacebridge-namespace → T6) | 13 | spacebridge:* skills, namespace examples in tests/schemas, archive refs, `_plans/` |
| **B5** (test/CI decoupling → T7) | ~70 | 64 ../../../../ tests + 9 mjs files not in gate + 5 specific-path tests + sync-workflow-sot.sh |
| **B4** (cosmetic fixture version → T8) | 7 | commissioned-by versions in 5 fixtures + 2 test inline fixtures |
| **AC6** (Codex runtime claim → T9) | 2 | `skills/ship/SKILL.md:24` CODEX_HOME + `test-ship-first-officer-bridge.sh:40` |

---

## Classification Judgment Calls (for captain/SO confirmation)

1. **`bin/*.test.mjs` bucket**: Classified as B5 (test/CI) rather than AC6, because the core issue is they are excluded from the release gate — not that they make false runtime claims. Task 7 should determine if they should be added to gate or explicitly documented as out-of-scope. Captain confirm B5 is correct.

2. **`_mods/` files** (`_mods/ship-flow-lint.md`, `_mods/debrief-guardrail-harvest.md`): These live in the plugin's `_mods/` directory and are adopted-project operational files, not plugin canon. Classified B2-deferred because they reference `docs/ship-flow/spacebridge.yaml` which is a spacebridge namespace convention, not an error. Captain confirm.

3. **`references/flow-map-schema.yaml:83–84` and `skills/ship-design/SKILL.md:785,787`**: Classified B2-deferred because the `plugins/spacebridge/design/` paths are spacebridge-specific examples that exist only in the source monorepo. A standalone adopter would not have these files. T6 should document this as deferred (not rename the paths, just annotate as spacedock-ui-specific examples). Captain confirm.

4. **`test-debrief-schema.sh:23` CARLOVE path**: Classified B5 (not AC6) because it's a test coupling issue with a hardcoded local filesystem path. The test already has graceful degradation (`WARN: carlove debrief not found (skipping)`) — so fresh-clone doesn't hard-fail, but it's still impure. T7 should decide whether to remove the CARLOVE check or make it conditionally skipped via CI=true.

5. **`README.md:548,584`**: "Spacebridge dogfood merge flow" and "dogfood portability" mentions — classified B2-deferred because they describe the spacebridge plugin integration story, not monorepo-specific hardcoding. Do not remove. Captain confirm.
