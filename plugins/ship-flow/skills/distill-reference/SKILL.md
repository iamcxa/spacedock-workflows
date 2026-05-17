---
name: distill-reference
description: "Use when mining an external workflow/plugin/source tree for ship-flow improvement candidates while preserving hermetic runtime boundaries."
user-invocable: true
argument-hint: "<source-path-or-url> [--target ship-flow] [--report-name <slug>] [--file-todos]"
---

# Distill Reference

## Overview

Distill-reference is a ship-flow utility/meta skill, not a stage skill. It turns a reference workflow system into an evidence-backed distillation report and optional follow-up drafts without making ship-flow depend on the reference at runtime.

Command:

```text
/ship-flow:distill-reference <source-path-or-url> [--target ship-flow] [--report-name <slug>] [--file-todos]
```

## Quick Reference

| Need | Use |
|---|---|
| Compare an external workflow system to ship-flow | Build source and target maps, then score the stable comparison axes. |
| Preserve evidence from unavailable sources | Record `missing`, `inaccessible`, or `remote-unavailable`; do not infer findings. |
| Propose ship-flow improvements | Capture candidates in the report with source evidence, baseline, hermeticity note, verification idea, and follow-up text. |
| File follow-up todos | Use `--file-todos`; otherwise leave proposed follow-up text inside the report only. |

## Contract

Read these references before running:

- `references/comparison-axes.md`
- `references/report-template.md`
- `references/candidate-capture.md`

Inputs:

- `source-path-or-url`: local file, local directory, git working tree path, or URL.
- `--target`: comparison target; default `ship-flow`.
- `--report-name`: output safe slug; default derived from source identity. Slug must be lowercase kebab-case (`^[a-z0-9][a-z0-9-]*$`), with no slash, no backslash, and no `..`.
- `--file-todos`: optional write mode for candidate todo files. Without this flag, store proposed follow-up text in the report only.

Outputs:

- One report under `docs/ship-flow/_distillations/<yyyy-mm-dd>--<report-name>.md`, where `<report-name>` is the validated report-name. By default, report-name is derived from source identity; `--report-name <slug>` explicitly overrides that derived filename slug.
- Zero or more candidate records inside the report.
- Optional todo files only when `--file-todos` is explicitly present.

## Phases

1. Resolve source.
   - Local paths: read if present.
   - URLs: fetch only when the runtime has an approved fetch tool; otherwise record `remote-unavailable`.
   - Missing sources: record `missing` or `inaccessible`. Missing source availability is data, not a blocker by itself.
2. Build source map.
   - Inventory skill files, commands, lib scripts, README/rationale docs, and thin-wrapper references.
   - Follow thin-wrapper references only as source reads; add every followed file to Source Read List.
3. Build target map.
   - Read ship-flow target surfaces relevant to the axes, such as stage skills, `docs/ship-flow/README.md`, `plugins/ship-flow/INVARIANTS.md`, and ship-flow-owned snapshots.
4. Compare axes.
   - Use exactly the stable axes in `references/comparison-axes.md`.
   - Mark each axis `high`, `medium`, `low`, `not-fit`, or `no-evidence`.
5. Capture candidates.
   - Use the candidate schema in `references/candidate-capture.md`.
   - Candidates require source evidence or explicit `source_unavailable` evidence, ship-flow baseline, fit score, hermeticity note, verification idea, and proposed follow-up text.
6. Write report.
   - Use `references/report-template.md`.
   - Record local sources with stable source aliases or repo-relative paths; do not write local absolute maintainer paths into committed reports.
   - Validate `--report-name` before building the output path.
   - Report path collision policy: if the target report path already exists, stop with `Blocked` and ask for a different safe slug; reports must not overwrite prior distillation evidence.
   - Keep rejected imports in the report; do not turn rejected alternatives into todos.
7. File todos only when requested.
   - With `--file-todos`, write only `docs/ship-flow/todos/<slug>.md` files for high/medium candidates.
   - Todo files must include the established frontmatter contract: `tid: <slug>`, `captured_at: <UTC timestamp>`, `status: pending`, optional `domain`, `guess_files`, `suggest_done_type`, and `entity: null`.
   - Use explicit pathspec commits if committing as part of a broader flow.

## Hermeticity Policy

GStack/GSD and other reference systems are reference-only inputs. They may inform methodology prose, comparison axes, and candidate follow-ups, but they are not runtime dependencies.

Ship-flow stage skills and `lib/` scripts MUST NOT reference `~/.claude/skills/gstack/` as a load-bearing runtime path.

Ship-flow stage skills and `lib/` scripts MUST NOT reference `~/.agents/skills/gstack/` as a load-bearing runtime path.

Ship-flow stage skills and `lib/` scripts MUST NOT reference `$B` as a load-bearing runtime dependency.

Ship-flow stage skills and `lib/` scripts MUST NOT reference `$D` as a load-bearing runtime dependency.

Ship-flow stage skills and `lib/` scripts MUST NOT reference `gstack-*` as required runtime binaries.

If a reference path is missing, record source availability and avoid inferred findings. Do not invent conclusions from absent sources.

## Exit Contract

Success:

- Report path.
- Candidate count.
- Source availability count by status.

Partial:

- Report path.
- `source_unavailable` or missing entries listed in Source Availability.
- Candidate gaps marked `no-evidence` when evidence is unavailable.

Blocked:

- Target map is unreadable.
- Report path cannot be written.
- `--file-todos` requested but todo path write fails.

## Common Mistakes

| Mistake | Correction |
|---|---|
| Treating a missing source as evidence | Record `missing` and mark affected findings `no-evidence`. |
| Copying a reference command into ship-flow runtime | Convert the method into ship-flow-owned prose, tests, or a candidate follow-up. |
| Filing every observation as a todo | File only high/medium candidates with evidence, fit score, hermeticity note, and verification idea. |
| Mixing reusable skill contract with a first report | Keep the reusable skill under `plugins/ship-flow/skills/distill-reference/`; reports are instances under `_distillations/`. |
