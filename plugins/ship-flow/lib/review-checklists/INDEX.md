# Ship-Flow Review Checklists — Snapshot

**Source**: gstack `/review` skill content at `~/.claude/skills/gstack/review/`
**Snapshot date**: 2026-05-12
**Target after `/spacedock:overhaul`**: `plugins/ship-flow/lib/review-checklists/`

## Why this snapshot exists

Captain confirmed (this conversation, 2026-05-12) that ship-flow plugin must NOT depend on `~/.claude/skills/gstack/` at runtime — too brittle, GStack evolves independently. This directory is a one-time content copy. Ship-flow owns these checklists from now on; future GStack changes are pulled in deliberately, not auto-followed.

## Ship-flow orchestration overrides

ship-flow orchestration supersedes copied specialist scope notes. The copied specialist scope notes remain historical checklist context, but `ship-verify` owns current dispatch semantics: security is always-on for non-trivial diffs (`DIFF_LINES >= 50`), while threat-surface-review is conditional on auth/API/backend/migration/CI/secrets/config/file/network/subprocess/LLM trust-boundary/access-control signals. This preserves the hermetic policy: ship-flow uses this snapshot and does not depend on live GStack internals at runtime.

## What was copied verbatim

- `critical-pass.md` ← `checklist.md` (main pre-landing checklist, 5 critical categories + informational)
- `specialists/testing.md` (always-on)
- `specialists/maintainability.md` (always-on)
- `specialists/security.md` (scope-gated: auth or backend+large)
- `specialists/performance.md` (scope-gated: backend or frontend)
- `specialists/data-migration.md` (scope-gated: migrations)
- `specialists/api-contract.md` (scope-gated: api)
- `specialists/red-team.md` (conditional: diff>200 or security critical)
- `design-checklist.md` (scope-gated: frontend)

## What was stripped or adapted

1. **`design-checklist.md`** — removed `~/.claude/skills/gstack/bin/gstack-diff-scope` bash invocation. Trigger condition rewritten as plain description: ship-verify decides scope detection via its own portable `lib/review-scope.sh` (to be written in `/spacedock:overhaul`).

2. **JSON output schema headers** — KEPT verbatim. Ship-flow adopts the same finding schema (`severity / confidence / path / line / category / summary / fix / fingerprint / specialist`). Cross-tool compatibility is a feature.

3. **Specialist "Scope:" routing notes** — KEPT verbatim. These describe WHEN the specialist applies, which ship-flow's scope detection will honor.

## What was NOT copied

- `SKILL.md` / `SKILL.md.tmpl` — that's the GStack skill orchestrator; ship-flow has its own (ship-verify).
- `TODOS-format.md` — GStack-specific TODOS.md convention; ship-flow doesn't adopt for v1.
- `greptile-triage.md` — Greptile integration; ship-flow explicitly avoids remote review agent dependency (captain decision).

## What ship-flow adds on top (designed in this integration draft, not yet snapshotted)

- `lib/review-scope.sh` — portable diff scope detection (replaces `gstack-diff-scope` bin)
- `lib/review-merge.sh` — fingerprint dedup + multi-specialist confirmation logic
- `lib/review-log.sh` — per-entity JSONL persistence at `<entity-folder>/review-log.jsonl` (replaces `gstack-review-log` global log)
- Codex fallback ladder (Tier A/B/C) — runtime detection, graceful degrade

These live in ship-flow plugin scaffolding, not in this snapshot directory.

## File inventory

```
ship-flow-gstack-integration-checklists/
├── INDEX.md                          ← this file
├── critical-pass.md                  ← main review (Pass 1 + Pass 2)
├── design-checklist.md               ← frontend code-level review
├── specialists/
│   ├── api-contract.md
│   ├── data-migration.md
│   ├── maintainability.md
│   ├── performance.md
│   ├── red-team.md
│   ├── security.md
│   └── testing.md
└── design-methodology/               ← sibling snapshot for design-officer
    ├── INDEX.md
    ├── ux-principles.md              ← Three Laws + Billboard + Goodwill
    ├── shotgun.md                    ← multi-variant ideation discipline
    ├── consultation.md               ← research-grounded proposal flow
    └── html-generation.md            ← production HTML/CSS
```

9 review files + 5 design methodology files = 14 files total, ~1300 lines combined.

## Sibling snapshot: design-methodology/

While `review-checklists/` are used by **ship-verify worker** (panel-driven, fresh-context specialist dispatch), the `design-methodology/` sibling is used by **design-officer** (standing teammate, interactive design exploration). Different consumer, different lifecycle, but same hermetic policy: ship-flow owns the content, no `~/.claude/skills/gstack/` runtime references.

See `design-methodology/INDEX.md` for that snapshot's full inventory.
