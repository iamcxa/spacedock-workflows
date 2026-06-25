# Design: Extract ship-flow into the `spacedock-workflows` plugin repo

- **Date:** 2026-06-25
- **Status:** Approved (brainstorming) — pending implementation plan
- **Scope tag:** Foot 1 / Option A (packaging + reference consistency; engine unchanged)
- **Target repo:** `iamcxa/spacedock-workflows` (Conductor workspace `iamcxa/yangon`)
- **Source:** `spacedock-ui` monorepo, `plugins/ship-flow/` (worktree `spacedock-ui/kathmandu`)

## 1. Problem

`ship-flow` is a mature autonomous-workflow plugin (`0.7.0-rc.7`) that currently
lives inside the `spacedock-ui` monorepo alongside `spacebridge` and the legacy
`spacedock-workflow` plugin. It has accumulated version drift relative to the
current `spacedock` plugin (latest `0.22.0`), and it is entangled with the host
repo's marketplace + release layout. We want it to live in its own marketplace
repo, internally consistent, and aligned to `spacedock 0.22.0` conventions.

The overriding requirement is **consistency**: after the move there must be no
dangling references, no stale version stamps, and no claim of support we have not
actually implemented.

### Three distinct things named "ship-flow" (do not conflate)

| Name | Location (source) | What it is | This foot |
| --- | --- | --- | --- |
| ship-flow **plugin** | `plugins/ship-flow/` | Generic engine: 23 skills, `INVARIANTS.md` (71K), `bin/check-invariants.sh` (84.8K), `workflow-template.yaml`, `agents/`, `hooks/`, `lib/` | **Move** |
| ship-flow **instance** | `docs/ship-flow/` | `spacedock-ui`'s own project tracking (~113 entities, ROADMAP/PRODUCT) | Leave |
| `spacedock-workflow` plugin | `plugins/spacedock-workflow/` | Legacy engine superseded by ship-flow | Leave |

### Version drift (the root of "inconsistency")

- ship-flow plugin: `0.7.0-rc.7`
- ship-flow instance stamp: `commissioned-by: spacedock@0.10.1`
- `spacedock` latest: **`0.22.0`** (CLAUDE.md still references `0.9.6`)
- `spacedock 0.22.0` dropped `workflow-template.yaml` in favour of markdown README
  templates + `commission`/`refit`; ship-flow still ships its own
  `workflow-template.yaml` (consumed by `spacebridge:workflow-adopt`).

## 2. Goals and non-goals

### Goals (this foot)

Produce a clean, internally consistent, installable, **verified** marketplace
repo in `yangon` that contains `ship-flow 0.7.0` aligned to `spacedock 0.22.0`
conventions, **with git history preserved**.

### Non-goals (each becomes its own future foot — "one foot at a time")

- **Foot 2:** Do not touch `spacedock-ui` (no consumer cut-over, no removal of
  the local `plugins/ship-flow/`, no `docs/ship-flow/` instance migration).
- **Foot 3 (Codex D2):** Do not make ship-flow functionally Codex-capable
  (no runtime-adapter refactor of skills).
- **Option B:** Do not re-architect ship-flow into `spacedock 0.22.0` native
  workflow format (no markdown-template conversion, no stage-model rework).
- Do not bring `spacedock-workflow` (legacy), `docs/ship-flow/` (instance), or
  `spacebridge`.

## 3. Decisions (captain-approved)

| # | Decision | Choice |
| --- | --- | --- |
| D1 | Depth of "spacedock format upgrade" | **A** — packaging + reference consistency; engine unchanged |
| D2 | Repo touch scope | Only `yangon`; `spacedock-ui` untouched |
| D3 | Repo structure | Marketplace + `plugins/<name>/` subdir (growth-ready) |
| D4 | Codex support | **D0** — structurally reserved, no `.codex-plugin/` manifest, not claimed |
| D5 | Git history | Preserve via `git filter-repo` |
| D6 | Version | `0.7.0-rc.7` → `0.7.0` (first stable in new repo) |
| D7 | Spec/plan location | `yangon` repo `docs/superpowers/specs/` |

## 4. Target repo structure

```
spacedock-workflows/                    (remote: iamcxa/spacedock-workflows)
├── .claude-plugin/
│   └── marketplace.json                # NEW; plugins[].source = ./plugins/ship-flow
├── plugins/
│   └── ship-flow/                      # filter-repo'd with history; path preserved
│       ├── .claude-plugin/plugin.json  # version 0.7.0; repository -> new repo
│       ├── skills/  lib/  bin/  agents/  hooks/  references/  registry/  rubrics/
│       ├── workflow-template.yaml
│       ├── INVARIANTS.md  README.md  scripts/bump-version.sh
│       └── (Codex reserved: layout does not preclude .codex-plugin/, not created here)
├── scripts/  or  .claude/commands/     # repo-level release tooling (plugin-release peer)
├── README.md                           # repo-level: marketplace purpose + install guide
└── .gitignore
```

Rationale for the subdir marketplace (vs root-level single plugin): the repo is
named `spacedock-workflows` (plural) and is expected to host additional workflow
plugins. The subdir layout matches the existing `spacedock-ui` monorepo-marketplace
pattern and lets a second workflow be added with zero restructuring.

## 5. Migration mechanics (history-preserving)

1. Fresh `clone` of `spacedock-ui`; on the throwaway clone run
   `git filter-repo --path plugins/ship-flow/` (keep the subdir path — it lands
   exactly where Option A wants it).
2. Bring the filtered history into `yangon`. The `iamcxa/yangon` branch currently
   has an **empty tree** (no tracked files; the `Initial commit` is on `master`).
   Combine the filtered history with `yangon` using `--allow-unrelated-histories`
   (or set the filtered history as base and graft), preferring a clean linear
   result. The exact strategy is fixed during planning after confirming the
   remote default branch (`master` vs `main`).
3. Layer repo-level new files (root `marketplace.json`, root `README.md`, release
   tooling, `.gitignore`) as top-of-tree commits.
4. **Risk control:** this is git surgery. It is scoped to a single, precisely
   specified worker task. If index state requires ≥2 mechanical retries, switch to
   a fresh sonnet subagent rather than looping in the orchestrator (per the
   delegation circuit-breaker rule).

## 6. spacedock 0.22.0 alignment work (4 buckets)

Evidence below is from a grep probe of `plugins/ship-flow/` on 2026-06-25.

### B1 — Identity / version (mechanical, firm)

- `plugin.json:3` version `0.7.0-rc.7` → `0.7.0`.
- `plugin.json:8` repository `https://github.com/spacedock-dev/spacebridge`
  → `https://github.com/iamcxa/spacedock-workflows`.
- README H1 token `(v0.7.0-rc.7)` → `(v0.7.0)`.
- Root `marketplace.json` version entry in sync (the version triple:
  `plugin.json` / `marketplace.json` / README H1 must stay locked).

### B2 — spacedock contract references (audit, then fix)

Distinct `spacedock:*` references found in `*.md`:

| Reference | Count | Status in 0.22.0 | Action |
| --- | --- | --- | --- |
| `spacedock:overhaul` | 16 | **Does not exist** | Likely dead / internal-refactor notes — classify & remove or rewrite |
| `spacedock:ensign` | 6 | Exists | Verify contract (runtime adapters) still matches |
| `spacedock:first-officer` | 3 | Exists | Verify contract still matches |
| `spacedock:commission` | 3 | Exists | Verify reference is current |
| `spacedock:workflow-adopt` | 1 | **Wrong namespace** (is `spacebridge:`) | Fix namespace or resolve (see R1) |
| `spacedock:workflow-sync` | 1 | **Wrong namespace** (is `spacebridge:`) | Fix namespace or resolve (see R1) |
| `spacedock:debrief` | 1 | Exists | Verify reference is current |

### B3 — Adoption scaffolding (captain-named: "ship-onboard, ship-flow template")

Files: `workflow-template.yaml`, `skills/ship-onboard/SKILL.md`,
`references/doc-sync-context.md` (and `skills/doc-sync/SKILL.md`,
`INVARIANTS.md`, `README.md` where the adoption story is documented).

Reconcile the frontmatter contract these produce/assume with `spacedock 0.22.0`:
`commissioned-by: spacedock@0.22.0`, plus the current `entity-type` / `id-style` /
`stages.states[]` schema, so a workflow instance freshly adopted from the new
ship-flow stamps the current version and passes `refit` as "up-to-date".

### B4 — Test fixture version staleness (low priority, cosmetic)

`lib/__tests__/fixtures/*` and two test scripts encode `spacedock@0.9.0` /
`0.10.x`. Runtime is pattern-based (`hooks/warn-state-drift.sh:51` greps
`^commissioned-by: spacedock@` version-agnostically), so these do not break
anything. Update for cosmetic consistency only.

### Anti-vagueness guard

The concrete edit list for **B2 and B3** is produced by an **alignment audit**
that runs as the *first* implementation task and is reviewed by the captain / SO
**before** any reconciliation edit. This prevents "align to 0.22.0" from becoming
an untestable acceptance criterion.

## 7. Codex D0 reservation (precise meaning of "structurally ready")

- The repo-level release tool is written so it can later stamp the version triple
  across **both** `.claude-plugin/` and `.codex-plugin/`, but this foot stamps
  Claude only.
- The repo README states plainly: **Claude only today; Codex functionalisation is
  a later foot.**
- **No `.codex-plugin/plugin.json` is created** — shipping one while skills remain
  Claude-native (`Agent()`/`SendMessage`/Claude hooks) would claim unimplemented
  support, the exact inconsistency we are avoiding.
- Layout and marketplace `source` do not preclude adding a Codex manifest later.

## 8. Acceptance criteria (testable definition of "consistent")

- **AC1** In the new repo, `CI=true bash plugins/ship-flow/bin/check-invariants.sh`
  and the `lib/__tests__` suite are fully green.
- **AC2** From the GitHub remote, `/plugin marketplace add iamcxa/spacedock-workflows`
  then `/plugin install ship-flow` succeeds.
- **AC3** Zero dangling: grep finds no `spacedock-ui`-specific paths, no
  non-existent `spacedock:overhaul`, and correctly namespaced spacebridge skills.
- **AC4** Version triple (`plugin.json` / `marketplace.json` / README H1) is
  consistent.
- **AC5** B3 scaffolding yields an instance stamped with the current spacedock
  version, and `refit` reports "up-to-date" (subject to R1 if the adoption path
  depends on spacebridge).
- **AC6** Codex: no `.codex-plugin/` present, README marks Claude-only, release
  tool has the dual-stamp capability reserved.

## 9. Execution approach (FO mode)

- This work does **not** run through ship-flow's own pipeline (circular; the new
  repo has not adopted ship-flow).
- Flow: brainstorming (done) → `superpowers:writing-plans` → FO-orchestrated
  workers applying Superpowers methods. Worktree isolation is provided naturally
  by the two workspaces (read `kathmandu`, write `yangon`).
- Push / PR to the new repo's default branch follows the global "ask first" rule
  (this repo has no ship-flow pipeline pre-authorisation).

## 10. Known risks

- **R1 — Adoption path may depend on spacebridge.** B2 shows `workflow-adopt` /
  `workflow-sync` references that belong to `spacebridge`, which is not coming
  along. This foot's resolution: the audit verifies the adoption path; if it
  depends on spacebridge, **document the dependency clearly (or point to
  `spacedock:commission`)** — full adoption-path redesign is deferred to a later
  foot. This foot does not expand into adoption-mechanism redesign.
- **R2 — Default branch unknown.** Remote `origin/HEAD` is not resolved; the repo
  has a `master` branch with the initial commit. Confirm `master` vs `main`
  before the history graft (affects step 5.2).
- **R3 — Git surgery.** Mitigated by the single-task scoping + delegation
  circuit-breaker in §5.4.
