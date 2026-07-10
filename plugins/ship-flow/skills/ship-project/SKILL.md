---
name: ship-project
description: "Use when the captain hands a planned tracker project (a Linear project ref — name/URL/id) and wants it instantiated as committed pipeline entities + a wave/parallel plan in one shot, instead of hand-shaping each issue. Fetches + filters the project's issues, builds a cut-project contract, and instantiates an epic + dotted shaped-children with depends-on edges — then STOPS at entities+plan for a clean session to run via /ship-flow:ship-epic. Triggers: 'ship-project', 'intake this project', 'instantiate the Linear project', project-ref + 'set up the pipeline'."
user-invocable: true
argument-hint: "[linear-project-ref | --contract=<path>] [--dry-run]"
---

# ship-project — project intake (tracker project → committed entities + wave plan)

## Overview

You turn an already-cut tracker project into a connected set of pipeline entities
plus a wave/parallel plan that a NEXT clean session runs. You do NOT run the
pipeline — you STOP at entities+plan. The clean session picks them up with
`/ship-flow:ship-epic <epic-id>`, which dispatches the children wave-by-wave in
dependency order (the FO `--next` dispatch is depends-on blind, so ship-epic is the
required orchestrator — see its SKILL).

This is a **utility skill** (uncapped — does not count toward the 7 stage-skill cap).
It sequences three deterministic libs around one Linear MCP fetch; it does not
re-implement any pipeline stage.

```
Linear ref ──(MCP, main session)──► normalized issues JSON
            ──issues-to-contract.sh──► cut-project contract YAML
            ──instantiate-cut-project.sh──► epic + dotted children + wave plan (committed)
            ──► clean-session handoff: "run /ship-flow:ship-epic <epic-id>"   ◄── STOP
```

## When to use

- The captain hands a Linear project ref whose issues are already cut (have titles +
  structured `blocked_by`/`blocks` relations) and wants the whole project instantiated.
- You have a hand-authored cut-project contract and want to skip Linear entirely
  (`--contract=<path>` — the 118.1 standalone path; also the seam for other trackers).
- NOT for a single issue — use `/ship <issue>` directly. NOT to RUN the pipeline —
  that is `/ship-flow:ship-epic` in a clean session.

## The MCP boundary (read first)

Linear MCP tools run **only in the captain main session** — a subagent cannot call
MCP (subagent MCP limitation). So the fetch + normalize step below runs inline in
THIS session. Any subagent you delegate to (e.g. to sanity-read the contract) must
receive the fetched issue set **inlined**, never a "go query Linear" instruction.

## Flow

Resolve `WORKFLOW_DIR` from `docs/*/README.md` `entry-point:` (default `docs/ship-flow`).

### 1. Fetch (main session, Linear MCP) — skip when `--contract=<path>` is given

- Resolve the ref → the Linear project (`mcp__linear-mcp__list_projects` /
  `get_project` by name/URL/id).
- List the project's issues (`mcp__linear-mcp__list_issues` filtered to the project),
  and read each issue's **structured** fields — state, labels, description, and the
  `blocks` / `blocked-by` issue relations (`get_issue` when `list_issues` omits relations).
- Do NOT parse issue description prose for dependencies — structured relations only.

### 2. Normalize → issues JSON (main session)

Map each Linear issue into the tracker-agnostic shape `issues-to-contract.sh` consumes
(see its header for the full schema). Field mapping:

| Normalized field | Linear source |
|---|---|
| `external_id` | issue `identifier` (e.g. `SC-810`) |
| `title` | issue `title` |
| `state_type` | issue `state.type` (`backlog`/`unstarted`/`started`/`completed`/`canceled`) |
| `state` | issue `state.name` (fallback filter) |
| `labels` | issue `labels[].name` |
| `body` | issue `description` |
| `blocked_by` | identifiers of issues this is **blocked by** (relation type `blocks`, inverse) |
| `blocks` | identifiers of issues this **blocks** |
| `affects_ui` | `true` iff a structured label clearly marks UI (`ui`/`frontend`/`design`); else omit |
| `domain` | a label matching a domain-registry key (`.claude/ship-flow/domains.yaml`); else omit |

Set `external_project` to a stable ref (`linear:<team>/<project>`) and `title` to the
project name. Write the JSON to a scratch path (e.g. `/tmp/ship-project-issues.json`).
Do NOT infer `affects_ui`/`domain` from prose — only from structured labels (keeps
intake LLM-coupling-free; a missed flag is corrected when the child reaches design/plan).

### 3. Transform → contract (deterministic)

```bash
bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/issues-to-contract.sh" /tmp/ship-project-issues.json \
  --workflow-dir "$WORKFLOW_DIR" --out /tmp/ship-project-contract.yaml
```

This applies the OCD-2 vocabulary (filter Done/Canceled/Duplicate, exclude `label:Bug`
to the debug fast-path, dedup already-intaken `external_id`s, map `blocked_by`/`blocks`
→ `depends_on` filtered to surviving children). It prints to stderr what it excluded —
**relay the bug list + dedup list to the captain** (the bugs go to `/fix-bug`, not intake).
Exit 1 = nothing intakeable after filter (report and stop).

When invoked with `--contract=<path>`, skip steps 1–3 and use that file directly.

### 4. Instantiate (deterministic, atomic)

```bash
bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/instantiate-cut-project.sh" /tmp/ship-project-contract.yaml \
  --workflow-dir "$WORKFLOW_DIR"            # add --dry-run to preview without writing
```

This validates (cycle/dup/closure BLOCK), allocates an `_archive`-aware epic id, maps
each `external_id` → a dotted `<epic>.N` child id, stamps each child at a LIVE entry
stage (`design` when a design-trigger flag is set, else `plan` — never the dispatch-dead
`sharp`), writes the epic + children in ONE atomic commit, and prints the wave/parallel
plan. It emits the literal next step.

### 5. Hand off — STOP

Relay to the captain: the allocated **epic id**, the committed children, the printed
**wave plan**, the excluded **bugs/dedup** lists, and the literal next step:

> Entities + wave plan committed. In a clean session run **`/ship-flow:ship-epic <epic-id>`**
> to dispatch the children wave-by-wave (merge each wave before the next — merge is captain-gated).

Do NOT continue into plan/execute/PR in this session — that burns the intake session's
context and the clean-session boundary is deliberate.

## OCD-2 — tracker→child mapping (captain-confirmed 2026-06-02: Option 1)

- **Dependency edges** come from structured `blocked_by` / `blocks` only — the canonical
  Linear dependency relation. `blocked_by` ⟹ `depends_on`; `blocks` ⟹ inverse edge.
- **Sub-issue `parentId` is NOT a dependency edge.** Parent/child is hierarchy, not
  execution order; mapping it risks wrong ordering. Under-claiming an edge (two things
  run in parallel) is recoverable; a wrong edge mis-orders the pipeline. Captain-confirmed
  conservative call (2026-06-02). **Revisit trigger**: a project whose sub-issue hierarchy
  genuinely drives execution order and is repeatedly mis-ordered by `blocked_by` alone —
  then reopen OCD-2 (likely "parent depends_on its sub-issues", accepting the empty-shell
  parent-entity cost, or the nested-epic axis filed as the `automatic-coupling-inference` rabbit hole).
- **Filter vocabulary**: drop `state_type` completed/canceled (Done/Canceled/Duplicate);
  `label:Bug` → excluded + reported (debug fast-path); existing-`external_id` → deduped.

## --dry-run

Pass `--dry-run` through to `instantiate-cut-project.sh` to preview the epic id, children,
status stamping, and wave plan without writing or committing. Use to confirm the contract
expands as expected before the real run.

## Known v1 limitations (codex review PR #190 — deferred, not bugs)

- **Cross-batch dependencies are dropped, not preserved.** If a surviving issue is
  `blocked_by` an already-intaken (deduped) issue, the adapter drops that edge and reports
  it to stderr (`N depends_on edge(s) dropped`). The wave plan will NOT enforce it. v1-narrow
  is single-shot intake; **relay the dropped-edge report to the captain** so they sequence
  those manually (or re-intake after the prerequisite ships). Full cross-batch dependency
  support (referencing existing entity ids as deps) is a v2 axis — it breaks the in-batch
  closure model the validator relies on.
- **ID allocation assumes a single intake session.** `instantiate-cut-project.sh` allocates
  the epic id as `max(active ∪ _archive) + 1` with a pre-write collision refuse, but no lock —
  two concurrent intake sessions could race to the same id. Intake is a deliberate captain
  action, so v1 accepts this; the `spacedock-next-id-archive-awareness` rabbit-hole tracks
  switching to spacedock's atomic `--next-id` if concurrent intake ever becomes real.

## Common mistakes

| Mistake | Reality |
|---|---|
| Delegating the Linear fetch to a subagent | MCP cannot run in a subagent — fetch in the main session, inline the result. |
| Parsing issue descriptions for dependencies | Structured relations only (`blocked_by`/`blocks`). No prose parsing. |
| Running the pipeline after intake | `/ship-project` STOPS at entities+plan. A clean session runs `/ship-flow:ship-epic <epic-id>`. |
| Handing off `/ship <epic-id>` | The FO `--next` dispatch is depends-on blind. The orchestrator is `/ship-flow:ship-epic`, not bare `/ship` on the epic. |
| Treating `label:Bug` issues as children | Bugs route to `/fix-bug`; the adapter excludes + reports them. |
| Silently dropping deduped/bug issues | The adapter reports them to stderr — relay to the captain so nothing disappears. |
