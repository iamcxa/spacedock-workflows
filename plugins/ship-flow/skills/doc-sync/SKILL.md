---
name: doc-sync
description: "Use when syncing Ship Flow plugin documentation after stage skill, invariant, workflow, shell primitive, or release changes."
user-invocable: true
argument-hint: "[--check] [--auto] [--section <doc-file>] [--diff <ref>] [--probe-only]"
---

# Ship Flow Doc Sync

Keep Ship Flow plugin documentation aligned with stage skills, shell primitives, invariants, workflow templates, and release expectations. Docs conform to source behavior; when docs and source disagree, update docs or block release rather than changing implementation from this skill.

Read `plugins/ship-flow/references/doc-sync-context.md` before scanning. It defines the Source Map, Doc Structure, Style Guide, Probe Config, and Post-Sync Hooks for this plugin.

## Routing

| Input | Route |
|-------|-------|
| bare invocation | Full Sync |
| `--check` | Report Only; never write files |
| `--auto` | Full Sync without confirmation prompts |
| `--section <doc-file>` | Targeted Sync for one doc target |
| `--diff <ref>` | Use explicit diff base instead of latest `ship-flow-v*` tag |
| `--probe-only` | Probe existing docs only; no inventory writes |

If no doc-probe worker is available, run Light Mode: static scan, history enrichment, report metrics, and `probes skipped: no doc-probe scaffold`.

## Phase 1: Static Scan

### Step 0 - Diff-Aware Pre-Processing

Find the diff base before inventory:

```bash
DIFF_BASE=$(git tag -l "ship-flow-v*" --sort=-v:refname | head -1)
# If --diff <ref> is present, use that ref instead.
# If no tags exist, use HEAD~10 and warn that older changes may be missed.
```

Extract added lines from release-relevant source surfaces:

```bash
git diff "${DIFF_BASE:-HEAD~10}"..HEAD -- \
  'plugins/ship-flow/skills/*/SKILL.md' \
  'plugins/ship-flow/skills/architecture-lens/*.md' \
  'plugins/ship-flow/bin/*.sh' \
  'plugins/ship-flow/lib/*.sh' \
  'plugins/ship-flow/hooks/*' \
  'plugins/ship-flow/references/**/*' \
  'plugins/ship-flow/registry/*.yaml' \
  'plugins/ship-flow/workflow-template.yaml' \
  'plugins/ship-flow/README.md' \
  'plugins/ship-flow/INVARIANTS.md' \
  'plugins/ship-flow/.claude-plugin/plugin.json' \
  | grep '^+' | grep -v '^+++' | sed 's/^+//'
```

Group added lines by source file and cap the diff summary at 2000 characters.

### Step 1 - Inventory and Cross-Reference

1. Read `plugins/ship-flow/references/doc-sync-context.md`.
2. Inventory sources:
   - `skills/*/SKILL.md`: skill name, description, routing, flags, stage artifacts, FO bridges, safety gates.
   - `skills/architecture-lens/*.md`: domain lens triggers and routing implications.
   - `bin/*.sh` and `lib/*.sh`: CLI contracts, flags, artifact writers, validators, sync primitives.
   - `hooks/*`: hook event types, matchers, warning behavior.
   - `references/**/*`, `registry/*.yaml`, and `workflow-template.yaml`: schema and workflow defaults.
   - `README.md` and `INVARIANTS.md`: canonical rationale and grep-enforced rules.
3. Inventory doc targets listed in Doc Structure.
4. Cross-reference every Source Map entry against its doc target. Include diff-added behavior in the coverage check.
5. Run orphan detection against the full Source Map, even when `--section` is used. Any discovered source file without a Source Map row is a Critical gap.
6. Classify gaps:
   - Critical: stage contract, invariant, workflow schema, hook behavior, release gate, or shell flag has no doc target coverage.
   - Warning: mentioned but not operationally explained.
   - Info: stale example, missing cross-reference, or weak troubleshooting note.
7. In `--check`, stop after report generation and exit non-zero when Critical gaps exist.

## Phase 2: History Enrichment

Check available memory sources independently:

- If episodic/private MCP tools are unavailable, warn and continue.
- Always search readable local memory/docs for prior ship-flow failures, release blockers, and adopter caveats.
- Escalate any contradiction between history and current docs to `accuracy_risk`.
- Preserve adopter-project boundaries: plugin docs describe canonical Ship Flow behavior, not one project-specific entity unless the source file already encodes it as reusable guidance.

Do not fail the sync because MCP history is unavailable.

## Phase 3: Write or Update Docs

Skip this phase for `--check` and `--probe-only`.

Unless `--auto`, present Critical and Warning gaps first and ask which to address. For each approved gap:

1. Determine whether the target doc should be created or updated.
2. Read the target doc and one sibling reference for tone and section conventions.
3. Preserve hand-written rationale unless Doc Structure marks the target `yes`.
4. Update only the sections needed for the gap.
5. Keep release wording explicit: Ship Flow release workflows must run `ship-flow:doc-sync --check` before publishing. Critical gaps block release until fixed or reported as an intentional blocked release.

## Phase 4: Probe Existing Claims

Skip probes in `--check` unless the captain explicitly asks for probe evidence.

For Full Sync and `--probe-only`:

1. Extract observable claims from changed docs, or from all Doc Structure docs in `--probe-only`.
2. Generate read-only probe commands from Probe Config.
3. Apply the pre-dispatch safety gate before dispatch:
   - Allowed: read-only help/check/list/status commands, `bash <script> --help`, `bash bin/check-invariants.sh --help`, `cat`, `grep`, `rg`, `ls`, `git diff --name-only`, and shell tests that operate only on bundled fixtures.
   - Blocked: `rm`, `delete`, `push`, `--force`, `reset`, `drop`, `truncate`, `>`, `git checkout --`, `mv`, `chmod`, `chown`, branch mutation, publish, release, archive mutation, or adopter-project writes.
4. Unsafe commands become skipped claims with reason `unsafe probe command filtered`.
5. Compare probe output with docs. Fix docs to match source behavior; never patch source from doc-sync.
6. Stop after three probe/fix rounds.

## Phase 5: Self-Update Reference

Skip this phase for `--check` and `--probe-only`.

Compare inventory to `doc-sync-context.md`:

- Add new source rows with inferred doc targets.
- Mark removed sources deprecated; do not delete rows automatically.
- Update Probe Config when a command is safe, env-dependent, or unsafe.
- Update `last_sync` and version metadata in the reference file when a write occurred.

## Phase 6: Report and Release Gate

Always report:

| Metric | Value |
|--------|-------|
| Gaps found | N |
| Gaps fixed | N |
| Critical gaps remaining | N |
| Accuracy risks found | N |
| Probes run | N |
| Probe pass rate | N% |
| Docs created | N |
| Docs updated | N |
| Reference self-updated | yes/no |
| Release gate | pass / blocked |

Release rule: before publishing Ship Flow, run `ship-flow:doc-sync --check`. If Critical gaps remain, the release is blocked unless the release report names the gap, owner, and explicit reason it is deferred.

## Safety Rules

- `--check` and `--probe-only` are report-only.
- Preserve Worker A owned files unless the captain explicitly changes scope.
- Docs conform to skills, shell scripts, schemas, hooks, and manifests.
- Orphan detection runs in all modes.
- History enrichment degrades gracefully.
- Probe safety is enforced by this skill before any worker or shell command runs.
