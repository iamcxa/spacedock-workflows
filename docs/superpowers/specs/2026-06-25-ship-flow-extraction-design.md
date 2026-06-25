# Design: Extract ship-flow into the `spacedock-workflows` plugin repo

- **Date:** 2026-06-25
- **Status:** Approved (brainstorming) — revised v2 after em + codex + gemini multi-model review
- **Scope tag:** Foot 1 / Option A (packaging + reference consistency; engine unchanged)
- **Target repo:** `iamcxa/spacedock-workflows` (Conductor workspace `iamcxa/yangon`)
- **Source:** `spacedock-ui` monorepo, `plugins/ship-flow/` (worktree `spacedock-ui/kathmandu`)

### Revision history

- **v1** — initial design from captain brainstorming (decisions D1–D7).
- **v2** — incorporated 3 independent model reviews (Science Officer EM, Codex,
  Gemini), all of which verified against the live source tree and converged on
  `revise-spec-first`. Captain ruling: accept a consistent-but-not-self-adoptable
  0.7.0 (D8), include test/CI decoupling in this foot (D9). Changes: AC5 demoted,
  §5 graft rewritten against the real tree, new bucket B5, AC1/AC2/AC3/AC6
  strengthened, B2 counts corrected, marketplace path fixed.

## 1. Problem

`ship-flow` is a mature autonomous-workflow plugin (`0.7.0-rc.7`) that currently
lives inside the `spacedock-ui` monorepo alongside `spacebridge` and the legacy
`spacedock-workflow` plugin. It has accumulated version drift relative to the
current `spacedock` plugin (latest `0.22.0`), and it is entangled with the host
repo's marketplace + release layout, its dogfood instance at `docs/ship-flow/`,
and `spacebridge`. We want it to live in its own marketplace repo, internally
consistent, and aligned to `spacedock 0.22.0` conventions.

The overriding requirement is **consistency**: after the move there must be no
dangling references, no stale version stamps, no claim of support we have not
implemented, and the standalone CI must be genuinely green on a clean clone.

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
  `workflow-template.yaml` (discovered by `spacebridge:workflow-adopt`, which then
  bridges into `spacedock:commission`).

## 2. Goals and non-goals

### Goal (this foot) — redefined after review

Produce a clean, internally consistent marketplace repo in `yangon` containing
`ship-flow 0.7.0` aligned to `spacedock 0.22.0` packaging conventions, **with git
history preserved** and **CI genuinely green on a fresh clone**.

The deliverable is **a correctly-packaged engine with an honestly-documented
adoption gap — NOT a turnkey self-adoptable plugin.** All three reviews confirmed
that under Option A (keep `workflow-template.yaml`) with `spacebridge` left behind,
a fresh adopter cannot bootstrap via standard commands. That gap is accepted (D8),
documented in-repo, and deferred as the explicit trigger for a later foot (§11).

### Non-goals (each becomes its own future foot — "one foot at a time")

- **Foot 2:** Do not touch `spacedock-ui` (no consumer cut-over, no removal of
  the local `plugins/ship-flow/`, no `docs/ship-flow/` instance migration).
- **Foot 3 (Codex D2):** Do not make ship-flow functionally Codex-capable
  (no runtime-adapter refactor of skills).
- **Adoption rework:** Do not rebuild the adoption path (do not convert
  `workflow-template.yaml` to 0.22.0 markdown templates, do not re-point adoption
  at `spacedock:commission`). That is Option B territory.
- **Option B:** Do not re-architect ship-flow into `spacedock 0.22.0` native
  format (no stage-model rework).
- Do not bring `spacedock-workflow` (legacy), `docs/ship-flow/` (instance), or
  `spacebridge`.

## 3. Decisions

| # | Decision | Choice |
| --- | --- | --- |
| D1 | Depth of "spacedock format upgrade" | **A** — packaging + reference consistency; engine unchanged |
| D2 | Repo touch scope | Only `yangon`; `spacedock-ui` untouched |
| D3 | Repo structure | Marketplace + `plugins/<name>/` subdir (growth-ready AND path-preserving — see §4) |
| D4 | Codex support | **D0** — structurally reserved, no `.codex-plugin/` manifest, existing Codex-runtime claims downgraded/flagged (§7) |
| D5 | Git history | Preserve via `git filter-repo` |
| D6 | Version | `0.7.0-rc.7` → `0.7.0` (first stable in new repo) |
| D7 | Spec/plan location | `yangon` repo `docs/superpowers/specs/` |
| D8 | Adoption gap | **Accepted** — 0.7.0 ships consistent but not self-adoptable; gap documented + deferred (§11). AC5 demoted accordingly. |
| D9 | Test/CI decoupling | **In scope** — bucket B5; CI must be green on a clean clone, no monorepo-path dependencies |

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

Rationale for the subdir marketplace (vs root-level single plugin):
1. **Path preservation (load-bearing, from review):** 21 shipped skill files
   hardcode `plugins/ship-flow/` paths. A root-level layout would break all 21;
   keeping the subdir, and running `git filter-repo --path plugins/ship-flow/`,
   keeps every internal path intact with zero edits.
2. **Growth:** the repo is named `spacedock-workflows` (plural) and is expected to
   host more workflow plugins; the subdir matches the proven `spacedock-ui`
   monorepo-marketplace pattern and lets a second workflow be added with no
   restructuring.

The marketplace manifest lives at `.claude-plugin/marketplace.json` (NOT repo
root) — the release tooling (`scripts/bump-version.sh`) expects that exact path.

## 5. Migration mechanics (history-preserving)

### Real target-tree state (verified — supersedes v1's "empty tree" claim)

`iamcxa/yangon` is **not empty**: it has two commits — `bf70589` (empty
`Initial commit`) and `561b48d` (this design spec) — and **descends from
`master`** (merge-base `bf70589`). `origin`'s default branch is **`master`**
(R2 resolved). Therefore `--allow-unrelated-histories` is **wrong** here: it would
graft the filtered ship-flow root as a third unrelated root onto a tree that
already shares history with `master`, producing the multi-root mess the design
wants to avoid.

### Steps

1. Fresh `clone` of `spacedock-ui`; on the throwaway clone run
   `git filter-repo --path plugins/ship-flow/` (keep the subdir path — it lands
   exactly where §4 wants it, preserving the 21 hardcoded paths). 50 commits
   touch `plugins/ship-flow/`, so history is substantive.
2. Bring the filtered history into `yangon` **without** `--allow-unrelated-histories`.
   Planner picks ONE of (decide from the corrected facts, document the choice):
   - **(a) Transplant:** make the filtered history the base, then replay yangon's
     two commits (`Initial commit`, spec) on top → clean linear history, single root.
   - **(b) Merge:** merge the filtered history into `iamcxa/yangon` with an
     explicit merge commit (accepts two roots but keeps yangon's existing commits
     as first-parent).
   Default to (a) for a clean linear result unless (b) is needed to preserve the
   exact `Initial commit` parent.
3. Decide and document: tag handling (preserve / drop / namespace ship-flow tags),
   removal of the throwaway clone's `spacedock-ui` remote before any push, and the
   **proof command** that the new repo's history contains the prior
   `plugins/ship-flow/` commits (e.g. `git log --oneline -- plugins/ship-flow/ | wc -l`
   ≈ 50, and a known historical SHA is reachable).
4. Layer repo-level new files (`.claude-plugin/marketplace.json`, root `README.md`,
   release tooling, `.gitignore`) as top-of-tree commits.
5. **Risk control:** this is git surgery on a *strategy* choice, not just index
   mechanics. Before executing, the chosen graft strategy (step 2) is validated on
   a scratch copy and the result inspected (`git log --graph --oneline --all`)
   BEFORE pushing. The delegation circuit-breaker still applies to mechanical
   retries, but the primary guard here is "validate strategy on scratch first"
   (a wrong strategy executed cleanly is the real failure mode).

## 6. spacedock 0.22.0 alignment work (5 buckets)

Counts below are the **verified** totals from the multi-model review (v1's table
was a `*.md`-only probe snapshot and under-counted). The authoritative, complete
inventory is still produced by the audit (see anti-vagueness guard).

### B1 — Identity / version (mechanical, firm)

- `plugin.json` version `0.7.0-rc.7` → `0.7.0`.
- `plugin.json:8` repository `https://github.com/spacedock-dev/spacebridge`
  → `https://github.com/iamcxa/spacedock-workflows` (note: the stale org token is
  `spacedock-dev`, which AC3's grep must catch).
- README H1 token `(v0.7.0-rc.7)` → `(v0.7.0)`.
- `.claude-plugin/marketplace.json` version entry in sync (version triple:
  `plugin.json` / `marketplace.json` / README H1 stays locked).

### B2 — spacedock / spacebridge reference reconciliation (audit, then fix)

Verified reference surface (≥ counts; audit produces the exact list):

| Reference | Verified count | Status in 0.22.0 | Action |
| --- | --- | --- | --- |
| `spacedock:overhaul` | ≥19 (incl. `lib/review-merge.sh:15`, `lib/review-log.sh:19`, `lib/review-scope.sh:17` — NOT just `*.md`) | **Does not exist** | Dead / internal-refactor breadcrumbs — remove or rewrite |
| `spacedock:first-officer` | ≥6 (spec said 3) | Exists | Verify contract (runtime adapters) still matches |
| `spacedock:ensign` | 6 | Exists | Verify contract still matches |
| `spacedock:commission` | 4 (incl. `workflow-template.yaml` header) | Exists | Verify reference is current |
| `spacedock:debrief` | 4 (`references/debrief-schema.yaml:2,4,39`, `README.md:477`) | Exists | Verify reference is current |
| `spacedock:workflow-adopt` / `spacedock:workflow-sync` | 5 / 1 | **Does not exist as `spacedock:`** | **Classify as deferred (spacebridge-dependent) — do NOT rename to `spacebridge:`** (see note) |
| `spacebridge:*` load-bearing | 29 occurrences; load-bearing in `skills/ship-onboard/SKILL.md:35-42` (STOPs if `/spacebridge:workflow-adopt` declined), `references/flow-map-schema.yaml:83-84` + `skills/ship-design/SKILL.md:785` (hardcode `plugins/spacebridge/design/design-system.md`), `skills/ui-verify/SKILL.md:47` + `skills/ship-verify/SKILL.md:581` (default e2e map name), `README.md:369,371` (`spacebridge:debrief-promote`) | spacebridge not coming | Classify each: keep-as-stale-docref / fix-to-neutral-default / document-as-deferred |

**Namespace note:** renaming `spacedock:workflow-adopt` → `spacebridge:workflow-adopt`
is cosmetically "correct" but would point the doc at a skill the extracted repo
cannot use. The right action is **document-as-deferred** (the adoption surfaces
disagree today — `workflow-template.yaml:2` says `spacedock:`, `ship-onboard:35`
says `spacebridge:`, `README.md:367-369` mixes both — and the audit must reconcile
them to ONE honest statement, not propagate the wrong namespace).

### B3 — Adoption scaffolding (captain-named: "ship-onboard, ship-flow template")

Files: `workflow-template.yaml`, `skills/ship-onboard/SKILL.md`,
`references/doc-sync-context.md`, `skills/doc-sync/SKILL.md`, `README.md`.

Under D8 the goal is **honesty, not function**: reconcile these surfaces so they
state ONE consistent thing — that 0.7.0 adoption is not self-contained (requires
`spacebridge` or manual scaffold) and self-adoption is a later foot. Do NOT try to
make `refit` report "up-to-date" (impossible this foot — see AC5 / §11).

### B4 — Test fixture version staleness (low priority, cosmetic) — confirmed safe

`lib/__tests__/fixtures/*` encode `spacedock@0.9.0` / `0.10.x`. Runtime is
pattern-based (`hooks/warn-state-drift.sh:48-52` greps `^commissioned-by: spacedock@`
version-agnostically); no test asserts the `repository` URL. Verified: the version
bump + history rewrite will NOT break the suite. Update for cosmetic consistency only.

### B5 — Test / CI decoupling (NEW — D9; required for honest AC1)

The test suite has hard couplings to the monorepo that fail on a clean clone:

- Tests that walk up to monorepo files that won't exist:
  `test-designer-skills-available.sh:11` (root `.claude/settings.json`),
  `test-canonical-context-lifecycle.sh:9,16` and `test-canonical-doc-sync-mod.sh:8`
  (`docs/ship-flow/_mods/canonical-doc-sync.md`), `test-workflow-sot-sync.sh:8`,
  `test-render-fidelity-check.sh:18`, `test-debrief-schema.sh:20`
  (`docs/ship-flow/_debriefs`); plus `lib/sync-workflow-sot.sh:24` defaults to
  `docs/ship-flow/README.md`.
- **Contradiction trap (Gemini):** `test-bidirectional-lifecycle-readme.sh:9-11`
  asserts the README MUST cite `workflow-adopt` / `workflow-sync`. So B2's dangling
  cleanup and this test directly conflict — B2 cleanup MUST update this test in the
  same change, or AC3 becomes self-contradictory (keep refs → dangling; remove →
  test red).
- Local absolute paths leak the author's machine:
  `test-debrief-schema.sh:23` (`/Users/kent/Project/carlove/...`),
  `test-merged-pr-closeout-reconciler.sh:9` (`/Users/kent/.codex/.../0.10.2/...`).
- `bin/*.test.mjs` node tests exist but `scripts/bump-version.sh:85` only runs
  `lib/__tests__/test-*.sh` — the verification command misses them.

B5 work: convert instance-coupled tests to fixtures (temp dirs / stub files) OR
move them to an "adopter-only integration tier" that is skipped in plugin-repo CI;
fix the contradiction test alongside B2; strip absolute paths; add the
`node --test plugins/ship-flow/bin/*.test.mjs` command to the verification path.
The audit sizes B5 precisely. Still no engine change.

### Anti-vagueness guard (load-bearing — keep + widen)

The concrete edit list for **B2, B3, B5** is produced by an **alignment audit**
that runs as the *first* implementation task and is captain/SO-reviewed **before**
any reconciliation edit. The audit must: (a) produce the COMPLETE reference
inventory across all file extensions (not `*.md`-only); (b) classify every
adoption-path reference as `deferred (spacebridge-dependent)` vs `fixable`;
(c) enumerate every monorepo-path test coupling for B5. This prevents "align to
0.22.0" from becoming an untestable acceptance criterion.

## 7. Codex D0 reservation (precise meaning of "structurally ready")

- The repo-level release tool is written so it can later stamp the version triple
  across both `.claude-plugin/` and `.codex-plugin/`, but this foot stamps Claude only.
- The repo README states plainly: **Claude only today; Codex functionalisation is a later foot.**
- **No `.codex-plugin/plugin.json` is created.**
- **Existing Codex-runtime claims must be addressed (from review):** absence of a
  manifest is NOT sufficient to avoid claiming support. `skills/ship/SKILL.md:20,157`
  already contain Codex-runtime bridge language ("the bridge applies in Codex",
  Codex dispatch evidence guard). These are claims that ship-flow runs under Codex
  and must be downgraded or clearly flagged as not-yet-supported. (Distinguish:
  `README.md:127,268` reference the `/codex` **review tool** — legitimate, keep;
  the `ship` skill bridge language is the "runs on Codex" claim — downgrade.)
- Layout and marketplace `source` do not preclude adding a Codex manifest later.

## 8. Acceptance criteria (testable definition of "consistent")

- **AC1** On a **fresh clone** of the new repo (no monorepo parent),
  `CI=true bash plugins/ship-flow/bin/check-invariants.sh`, the
  `lib/__tests__` suite, AND `node --test plugins/ship-flow/bin/*.test.mjs` are all
  green — with zero references to monorepo-only paths (`docs/ship-flow/`, root
  `.claude/settings.json`) reachable by the suite. (Depends on B5.)
- **AC2** From the GitHub remote, `/plugin marketplace add iamcxa/spacedock-workflows`
  then `/plugin install ship-flow` succeeds, AND a smoke check invokes one skill
  and exercises one hook so that `${CLAUDE_PLUGIN_ROOT}` resolves in the installed
  cache (`hooks/hooks.json` + `hooks/warn-state-drift.sh` / `warn-direct-read.js`).
- **AC3** Zero dangling: a grep gate finds none of — `spacedock-ui`, `spacedock-dev`,
  `spacedock:overhaul` (ALL extensions), hardcoded `plugins/spacebridge/design/`
  paths, "THIS project" dogfood language, `docs/ship-flow/README.md`-as-SOT claims,
  local absolute paths (`/Users/kent/...`), root `.claude/settings.json` deps. The
  B2 adoption-reference cleanup and `test-bidirectional-lifecycle-readme.sh` are
  reconciled (no keep-vs-remove contradiction).
- **AC4** Version triple (`plugin.json` / `.claude-plugin/marketplace.json` /
  README H1) is consistent.
- **AC5** *(demoted per D8)* The repo states ONE honest adoption story: 0.7.0 is
  not self-adoptable; adoption requires `spacebridge` or manual scaffold; self-
  adoption is a later foot. This statement appears in the repo README and the
  `workflow-template.yaml` header, and the previously-conflicting adoption surfaces
  (B3) agree with it. We do NOT assert `refit` reports up-to-date.
- **AC6** Codex: no `.codex-plugin/` present; README marks Claude-only; existing
  Codex-runtime bridge claims (§7) are downgraded/flagged; release tool has the
  dual-stamp capability reserved.

## 9. Execution approach (FO mode)

- This work does **not** run through ship-flow's own pipeline (circular; the new
  repo has not adopted ship-flow).
- Flow: brainstorming (done) → `superpowers:writing-plans` → FO-orchestrated
  workers applying Superpowers methods. Worktree isolation is provided naturally
  by the two workspaces (read `kathmandu`, write `yangon`). The plan front-loads
  the alignment audit (B2/B3/B5) with a captain/SO gate before reconciliation.
- Push / PR to the new repo's default branch (`master`) follows the global
  "ask first" rule (this repo has no ship-flow pipeline pre-authorisation).

## 10. Known risks

- **R1 — Adoption path depends on spacebridge (confirmed, not "may").** Verified
  load-bearing in shipped skills (`ship-onboard/SKILL.md:35-42` STOPs). Resolution
  under D8: document the dependency as a known limitation; defer self-adoption.
  AC5 reflects this. Escalation: if a future captain wants self-adoption, that is
  Option B / a later foot, not this one.
- **R2 — Default branch.** Resolved: `origin` default is `master`; working branch
  `iamcxa/yangon`. The graft (§5) targets `master` history.
- **R3 — Git surgery (strategy, not just index).** Mitigated by §5.5 "validate the
  graft strategy on a scratch copy and inspect `--graph` before pushing", plus the
  delegation circuit-breaker for mechanical retries.
- **R4 — B5 size unknown until audit.** Some instance-coupled tests fundamentally
  test the dogfood instance and may move to an adopter-only tier rather than be
  rewritten. The audit sizes this before plan authoring; it stays within Option A
  (no engine change).

## 11. Deferred / known limitations (explicit triggers for later feet)

- **Self-adoption (Foot 2/3 trigger):** 0.7.0 cannot be bootstrapped by standard
  commands without `spacebridge`. Resolving this requires EITHER bringing/replacing
  the `workflow-adopt` mechanism OR converting `workflow-template.yaml` to the
  `spacedock 0.22.0` markdown-template + `commission` model (Option B). Trigger:
  a captain wanting turnkey adoption of the standalone repo.
- **spacedock-ui consumer cut-over (Foot 2):** repointing `spacedock-ui` to consume
  ship-flow from this remote and removing its local `plugins/ship-flow/`.
- **Codex functionalisation (Foot 3 / D2):** runtime-adapter refactor of skills.
