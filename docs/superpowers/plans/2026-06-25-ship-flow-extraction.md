# Ship-Flow Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the `ship-flow` plugin from the `spacedock-ui` monorepo into the standalone `iamcxa/spacedock-workflows` marketplace repo, history-preserved, aligned to `spacedock 0.22.0` packaging conventions, with green CI on a fresh clone and an honestly-documented adoption gap.

**Architecture:** Audit-gated migration. Wave 1 moves the plugin (filter-repo + graft) and lays repo scaffold. Wave 2 runs a complete reference/coupling audit and STOPS at a captain/SO gate. Wave 3 applies the gated reconciliation (identity, reference cleanup, adoption honesty, test/CI decoupling, Codex claim downgrade). Wave 4 verifies against AC1–AC6 and stops at a push/PR gate. Engine is never modified (Option A).

**Tech Stack:** git + `git filter-repo`, bash (plugin lib/bin + tests run under `CI=true`), Node `--test` (`bin/*.test.mjs`), Claude Code plugin/marketplace manifests (JSON), YAML (`workflow-template.yaml`).

**Spec:** `docs/superpowers/specs/2026-06-25-ship-flow-extraction-design.md` (v2, commit `be8f557`).

## Global Constraints

- **Option A — engine unchanged.** No stage-model rework, no `workflow-template.yaml` → markdown-template conversion, no adoption-mechanism rebuild. Reference/packaging/test edits only.
- **Only touch `yangon` (`iamcxa/spacedock-workflows`).** NEVER modify `spacedock-ui` / `kathmandu`. The source plugin is read-only input.
- **Source of truth for the plugin after Wave 1 is `yangon:plugins/ship-flow/`.** All edits happen there.
- **Version triple lockstep:** `plugins/ship-flow/.claude-plugin/plugin.json` `version` = `.claude-plugin/marketplace.json` ship-flow entry `version` = README H1 `(vX.Y.Z)` token. Target `0.7.0`.
- **Commits:** explicit pathspec (never `git add -A`/`-a`), conventional subjects (`type(scope): subject`), end body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Push / PR to `master` = ASK CAPTAIN** (global rule; this repo has no ship-flow pipeline pre-authorisation).
- **No test-only env hooks** in production bash (`SPACEBRIDGE_*`/`SHIP_FLOW_FORCE_*` anti-pattern). Use fixtures.
- **Default branch is `master`; working branch is `iamcxa/yangon`.**

## File Structure

New files in `yangon` (repo-level):
- `.claude-plugin/marketplace.json` — single-plugin marketplace, `source: ./plugins/ship-flow`.
- `README.md` — repo purpose, install command, Claude-only note, adoption-gap note.
- `.gitignore` — Node/macOS/Conductor `.context/` ignores.
- `scripts/plugin-release.sh` (or `.claude/commands/plugin-release.md`) — repo-level release peer (decision in Task 2).
- `docs/superpowers/audits/2026-06-25-ship-flow-alignment-audit.md` — Task 3 output (the gate artifact).

Migrated (history-preserved) under `yangon:plugins/ship-flow/` — edited in place during Wave 3:
- `.claude-plugin/plugin.json` (identity), `README.md` (H1 + adoption + Codex notes), `workflow-template.yaml` (adoption header), `skills/ship-onboard/SKILL.md`, `skills/ship/SKILL.md` (Codex bridge), `lib/review-merge.sh`, `lib/review-log.sh`, `lib/review-scope.sh` (overhaul breadcrumbs), `scripts/bump-version.sh` (bin node tests + paths), and the B5 test files enumerated in Task 7.

---

## Wave 1 — Migration + Scaffold

### Task 1: Extract ship-flow with history and graft onto yangon

**Files:**
- Create (in `yangon`): `plugins/ship-flow/**` (entire plugin, history-preserved)
- Work area: a throwaway clone of `spacedock-ui` outside both workspaces (e.g. `/tmp/ship-flow-extract/`)

**Interfaces:**
- Produces: `yangon:plugins/ship-flow/` populated with preserved history; a verified proof that ~500 `plugins/ship-flow/` commits (full history) are present.

- [ ] **Step 1: Confirm preconditions**

Run:
```bash
command -v git-filter-repo || command -v git filter-repo
git -C /Users/kent/conductor/workspaces/spacedock-workflows/yangon log --oneline   # expect be8f557, 561b48d, bf70589
git -C /Users/kent/conductor/workspaces/spacedock-workflows/yangon branch --show-current  # expect iamcxa/yangon
```
Expected: `git-filter-repo` found; yangon has the 3 commits; branch `iamcxa/yangon`.

- [ ] **Step 2: Fresh clone the source into a throwaway dir**

Run:
```bash
rm -rf /tmp/ship-flow-extract
git clone /Users/kent/conductor/workspaces/spacedock-ui/kathmandu /tmp/ship-flow-extract
# verify the clone has full history for the plugin
git -C /tmp/ship-flow-extract log --oneline -- plugins/ship-flow/ | wc -l
```
Expected: ~500 (the plugin's full commit count). Note: RTK truncates `git log | wc -l` to ~50 — always use `git rev-list --count` for commit counts. Record this number as `EXPECTED_COMMITS`.

- [ ] **Step 3: filter-repo to keep only the plugin subtree (path preserved)**

Run:
```bash
cd /tmp/ship-flow-extract
git filter-repo --path plugins/ship-flow/ --force
git rev-list --count HEAD -- plugins/ship-flow/   # must equal EXPECTED_COMMITS
git ls-files | grep -c '^plugins/ship-flow/'        # all files retained
git ls-files | grep -v '^plugins/ship-flow/' | head # expect EMPTY (nothing outside the subtree)
```
Expected: commit count unchanged; only `plugins/ship-flow/**` files remain; no files outside the subtree.

- [ ] **Step 4: Validate the graft strategy on a scratch copy BEFORE touching yangon**

Decision: use **transplant** — replay ALL of yangon's content commits (everything after the empty `Initial commit` `bf70589`: currently `561b48d` spec v1, `be8f557` spec v2, `a5f1b63` plan, plus any added before execution) onto the filtered ship-flow base, for a clean linear single-root history. Use `git rebase --onto` (NOT hardcoded cherry-picks) so it is robust to however many doc commits exist at execution time. Validate on scratch first:
```bash
rm -rf /tmp/yangon-scratch
git clone /Users/kent/conductor/workspaces/spacedock-workflows/yangon /tmp/yangon-scratch
cd /tmp/yangon-scratch
git remote add filtered /tmp/ship-flow-extract && git fetch filtered
FILTERED_TIP=$(git rev-parse filtered/master 2>/dev/null || git rev-parse filtered/main)
# replay every yangon commit after the empty Initial commit (bf70589) onto the filtered base
git rebase --onto "$FILTERED_TIP" bf70589 iamcxa/yangon
git log --graph --oneline | head -40
git rev-list --count HEAD -- plugins/ship-flow/   # must equal EXPECTED_COMMITS
git ls-files | grep -c '^docs/superpowers/'        # yangon docs retained on top
```
Expected: single linear history, all ship-flow commits present, all yangon doc commits replayed on top, no stray roots. If preserving the empty `Initial commit` as a parent is required for provenance, fall back to **Strategy B (merge with explicit merge commit)** and document why.

- [ ] **Step 5: Apply the validated strategy to the real yangon branch**

Run (transplant variant; adjust if Step 4 chose merge). Safety: tag the current tip first so the rewrite is recoverable.
```bash
cd /Users/kent/conductor/workspaces/spacedock-workflows/yangon
git tag pre-graft-backup iamcxa/yangon          # recovery point
git remote add filtered /tmp/ship-flow-extract && git fetch filtered
FILTERED_TIP=$(git rev-parse filtered/master 2>/dev/null || git rev-parse filtered/main)
git rebase --onto "$FILTERED_TIP" bf70589 iamcxa/yangon   # replay all yangon docs onto filtered base
git remote remove filtered
# verify before deleting the backup tag (Step 6); keep pre-graft-backup until proof passes
```

- [ ] **Step 6: Prove history + cleanliness**

Run:
```bash
cd /Users/kent/conductor/workspaces/spacedock-workflows/yangon
git rev-list --count HEAD -- plugins/ship-flow/              # == EXPECTED_COMMITS
test -f plugins/ship-flow/.claude-plugin/plugin.json && echo "PLUGIN PRESENT"
git log --graph --oneline | head -20                         # single root, linear
git status --short                                           # clean
rm -rf /tmp/ship-flow-extract /tmp/yangon-scratch
```
Expected: commit count matches, plugin present, clean linear history, no stray files. Keep the `pre-graft-backup` tag until the Wave 4 push succeeds, then delete it. **Do NOT push yet** (push gate is Wave 4).

> Note: history graft is the highest-risk task. If index/cherry-pick fails ≥2 mechanical retries, STOP and dispatch a fresh sonnet subagent for the git work (delegation circuit-breaker) rather than looping.

### Task 2: Repo-level marketplace scaffold

**Files:**
- Create: `.claude-plugin/marketplace.json`, `README.md`, `.gitignore`
- Decide + create: repo-level release peer (`scripts/plugin-release.sh` or `.claude/commands/plugin-release.md`)

**Interfaces:**
- Consumes: `plugins/ship-flow/.claude-plugin/plugin.json` (name `ship-flow`, version — still `0.7.0-rc.7` at this point; Task 4 bumps it).
- Produces: a marketplace manifest pointing at `./plugins/ship-flow`; AC4's version-triple now has 3 sites.

- [ ] **Step 1: Write the marketplace manifest**

Create `.claude-plugin/marketplace.json`:
```json
{
  "name": "spacedock-workflows",
  "owner": { "name": "Kent", "email": "duckbaseco@gmail.com" },
  "plugins": [
    { "name": "ship-flow", "source": "./plugins/ship-flow", "version": "0.7.0-rc.7" }
  ]
}
```
(Version is bumped to `0.7.0` transactionally in Task 4 across all three sites.)

- [ ] **Step 2: Write the repo README (Claude-only + adoption-gap notes)**

Create `README.md` with: repo purpose (a marketplace for spacedock workflow plugins, first is ship-flow); install command `/plugin marketplace add iamcxa/spacedock-workflows` then `/plugin install ship-flow`; an explicit **"Claude Code only today; Codex support is a later milestone"** note; an explicit **"Adoption is not self-contained in 0.7.0 — see plugins/ship-flow adoption notes"** pointer.

- [ ] **Step 3: Write `.gitignore`**

Create `.gitignore` covering: `node_modules/`, `.DS_Store`, `.context/` (Conductor), `*.log`.

- [ ] **Step 4: Decide + create the release peer**

Inspect the source release command to decide whether the repo needs its own:
```bash
sed -n '1,60p' /Users/kent/conductor/workspaces/spacedock-ui/kathmandu/plugins/ship-flow/scripts/bump-version.sh
```
Decision rule: `plugins/ship-flow/scripts/bump-version.sh` already does the per-plugin transactional triple bump; the repo only needs a thin wrapper or a documented `/plugin-release ship-flow <version>` note. Create the minimal peer that invokes the plugin's `bump-version.sh` and updates `.claude-plugin/marketplace.json`. Verify `bump-version.sh` references `.claude-plugin/marketplace.json` at the repo root (per source `scripts/bump-version.sh:139`) and adjust the path if the standalone layout differs.

- [ ] **Step 5: Commit the scaffold**

```bash
git add -- .claude-plugin/marketplace.json README.md .gitignore scripts/plugin-release.sh
git commit -m "chore(repo): scaffold spacedock-workflows marketplace for ship-flow

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Wave 2 — Alignment Audit + GATE

### Task 3: Complete reference / coupling audit (gate artifact)

**Files:**
- Create: `docs/superpowers/audits/2026-06-25-ship-flow-alignment-audit.md`

**Interfaces:**
- Consumes: `plugins/ship-flow/**` (migrated copy in yangon).
- Produces: the authoritative edit inventory consumed by Tasks 4–9. Output sections: (A) complete reference inventory, (B) deferred-vs-fixable classification, (C) B5 test-coupling enumeration, (D) delta vs the review-verified floor below.

- [ ] **Step 1: Inventory every spacedock/spacebridge reference (ALL extensions, not `*.md`)**

Run (from `yangon`):
```bash
cd plugins/ship-flow
echo "## spacedock: refs"; grep -rhoE "spacedock:[a-z-]+" . | sort | uniq -c | sort -rn
echo "## spacebridge refs"; grep -rnE "spacebridge" . | wc -l
echo "## overhaul (all ext)"; grep -rn "spacedock:overhaul" .
echo "## adoption surfaces"; grep -rnE "workflow-adopt|workflow-sync" .
echo "## debrief-promote"; grep -rn "debrief-promote" .
```
Record counts. **Verified floor (must be matched or exceeded):** `overhaul` ≥19 (incl. `lib/review-merge.sh:15`, `lib/review-log.sh:19`, `lib/review-scope.sh:17`), `first-officer` ≥6, `ensign` 6, `commission` 4, `debrief` 4, `workflow-adopt` 5, `workflow-sync` 1, `spacebridge` ≈29.

- [ ] **Step 2: Inventory host-repo / portability couplings**

Run:
```bash
cd plugins/ship-flow
echo "## spacedock-ui / spacedock-dev"; grep -rnE "spacedock-ui|spacedock-dev" .
echo "## docs/ship-flow as SOT / THIS project"; grep -rnE "docs/ship-flow/README|THIS project|dogfood" .
echo "## plugins/spacebridge hardcoded paths"; grep -rn "plugins/spacebridge" .
echo "## absolute author paths"; grep -rnE "/Users/kent|/Users/[a-z]+/\.codex" .
echo "## repository field"; grep -n "repository" .claude-plugin/plugin.json
```
**Verified floor:** `plugin.json:8` (spacedock-dev/spacebridge), `README.md:5,351` (THIS project / spacedock-ui adopted), `flow-map-schema.yaml:83-84` + `skills/ship-design/SKILL.md:785` (plugins/spacebridge/design), `skills/ship-onboard/SKILL.md:35-42`, `test-debrief-schema.sh:23`, `test-merged-pr-closeout-reconciler.sh:9`.

- [ ] **Step 3: Enumerate B5 test/CI couplings (clean-clone failures)**

Run:
```bash
cd plugins/ship-flow
echo "## tests walking to monorepo"; grep -rnE "\.\./\.\./\.\./\.\.|REPO_ROOT.*docs/ship-flow|/\.claude/settings\.json" lib/__tests__ lib/*.sh
echo "## bin node tests"; ls bin/*.test.mjs
echo "## bump-version test scope"; sed -n '70,95p' scripts/bump-version.sh
echo "## contradiction test"; sed -n '1,20p' lib/__tests__/test-bidirectional-lifecycle-readme.sh
```
**Verified floor:** `test-designer-skills-available.sh:11`, `test-canonical-context-lifecycle.sh:9,16`, `test-canonical-doc-sync-mod.sh:8`, `test-workflow-sot-sync.sh:8`, `test-render-fidelity-check.sh:18`, `test-debrief-schema.sh:20`, `lib/sync-workflow-sot.sh:24`, and the contradiction test `test-bidirectional-lifecycle-readme.sh:9-11`.

- [ ] **Step 4: Write the audit doc with classification**

For each reference/coupling, classify into exactly one bucket and target task:
- `B1` identity/version (Task 4)
- `B2-remove` dead reference, delete/rewrite (Task 5)
- `B2-verify` live spacedock contract, confirm current (Task 5)
- `B2-deferred` adoption-trio / spacebridge-dependent → document-as-deferred, do NOT rename namespace (Task 6)
- `B5` test/CI coupling (Task 7)
- `B4` cosmetic fixture version (Task 8)
- `AC6` Codex runtime claim (Task 9)

Include a **delta section**: anything found beyond the verified floor above (the reviews under-counted once; this is the completeness net).

- [ ] **Step 5: Commit the audit + STOP at the gate**

```bash
git add -- docs/superpowers/audits/2026-06-25-ship-flow-alignment-audit.md
git commit -m "docs(ship-flow): alignment + coupling audit (Wave 2 gate)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

> **GATE — captain/SO review the audit before any Wave 3 reconciliation.** The FO presents the audit (deferred-vs-fixable classification, B5 size, deltas). Reconciliation does not start until the gate proceeds.

---

## Wave 3 — Reconciliation (post-gate; parallel where independent)

> Dependency notes: Task 4 (identity) and Task 8 (fixtures) are independent. Task 5 (B2 cleanup) and Task 7 (B5 contradiction test) are coupled via `test-bidirectional-lifecycle-readme.sh` — do them in one logical change or strictly order 5→7. Task 6 (adoption honesty) and Task 9 (Codex) are independent of each other. All consume the Task 3 audit as the authoritative target list.

### Task 4: B1 — Identity + version triple bump

**Files:**
- Modify: `plugins/ship-flow/.claude-plugin/plugin.json`, `plugins/ship-flow/README.md` (H1), `.claude-plugin/marketplace.json`

- [ ] **Step 1: Write the failing consistency check**

Create `scripts/check-version-triple.sh` that extracts the version from all three sites and exits non-zero if they differ OR if `plugin.json` still contains `spacedock-dev`/`spacebridge` in `repository`. Run it:
```bash
bash scripts/check-version-triple.sh
```
Expected: FAIL (versions are `0.7.0-rc.7` and repository is stale).

- [ ] **Step 2: Apply identity edits**

- `plugins/ship-flow/.claude-plugin/plugin.json`: `version` → `0.7.0`; `repository` → `https://github.com/iamcxa/spacedock-workflows`.
- `plugins/ship-flow/README.md` H1: `(v0.7.0-rc.7)` → `(v0.7.0)`.
- `.claude-plugin/marketplace.json`: ship-flow entry `version` → `0.7.0`.

- [ ] **Step 3: Verify the check passes**

Run: `bash scripts/check-version-triple.sh` → Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add -- plugins/ship-flow/.claude-plugin/plugin.json plugins/ship-flow/README.md .claude-plugin/marketplace.json scripts/check-version-triple.sh
git commit -m "chore(ship-flow): bump to 0.7.0 and repoint repository to standalone repo

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 5: B2 — spacedock reference reconciliation

**Files:**
- Modify (from audit list; verified floor): `plugins/ship-flow/lib/review-merge.sh`, `lib/review-log.sh`, `lib/review-scope.sh` (remove `spacedock:overhaul` breadcrumbs), plus any additional `overhaul` sites the audit found. Verify (no edit unless drift) `first-officer`/`ensign`/`commission`/`debrief` references against `spacedock 0.22.0`.

- [ ] **Step 1: Remove dead `spacedock:overhaul` references** at every site in the audit's `B2-remove` list (rewrite the breadcrumb comment to drop the dead skill name; keep the surrounding logic).

- [ ] **Step 2: Verify live contracts** — for each `B2-verify` reference (`first-officer`/`ensign`/`commission`/`debrief`), confirm the usage still matches `spacedock 0.22.0` (`/Users/kent/.claude/plugins/cache/spacedock/spacedock/0.22.0/`). If a contract genuinely drifted and the fix is a behavior change to a skill, STOP and route that single sub-item to `superpowers:writing-skills` (prompt-engineering, not mechanical). Otherwise no edit.

- [ ] **Step 3: Verify no `spacedock:overhaul` remains**

Run: `grep -rn "spacedock:overhaul" plugins/ship-flow/` → Expected: no output.

- [ ] **Step 4: Commit** (`fix(ship-flow): remove dead spacedock:overhaul references`).

### Task 6: B3 — adoption story honesty (single consistent statement)

**Files:**
- Modify: `plugins/ship-flow/workflow-template.yaml` (header), `plugins/ship-flow/skills/ship-onboard/SKILL.md`, `plugins/ship-flow/README.md` (adoption section)

- [ ] **Step 1:** Reconcile all adoption surfaces to ONE statement: *0.7.0 adoption is not self-contained; it requires `spacebridge` (`workflow-adopt`/`workflow-sync`) or a manual scaffold; self-adoption is a later milestone.* Fix the today-conflicting namespaces (`workflow-template.yaml:2` says `spacedock:`, `ship-onboard:35` says `spacebridge:`) to agree — keep the **honest deferred statement**, do NOT rename to a namespace the repo cannot satisfy.
- [ ] **Step 2:** In `ship-onboard/SKILL.md:35-42`, change the hard STOP-if-declined into a documented prerequisite note (it must not block when the bridge plugin is absent), consistent with the deferred adoption statement. (If this becomes a semantic skill rewrite, route to `superpowers:writing-skills`.)
- [ ] **Step 3:** Verify the README adoption section and `workflow-template.yaml` header state the same thing (grep both).
- [ ] **Step 4: Commit** (`docs(ship-flow): state one honest deferred adoption story`).

### Task 7: B5 — test / CI decoupling (fresh-clone green, three-state ledger)

**SO-corrected scope (empirical fresh-clone census):** 116 tests → **74 pass / 33 hard-fail / 9 hang**. Actionable surface ≈ **42** (33 hard-fail + 9 hang), NOT ~10-12 and NOT ~70. The 9 hangs include `test-check-invariants.sh` itself (the release gate's gate-1) — the suite is not safely runnable to completion without a bounded timeout wrapper. Two false-green classes to kill: (a) `test-render-fidelity-check.sh` prints `SKIP` + rc=0 (decoupled-by-absence, not genuine); (b) `test-bidirectional-lifecycle-readme.sh` passes only because README still has dangling strings (flips red after T5 — must be co-fixed). Audit C.5 is wrong: `test-debrief-schema.sh` hard-fails at the `_debriefs/*.md` glob (lines 19-21), NOT graceful at the CARLOVE line 23.

**Files:**
- Modify: the B5 test files (Task 3 audit list), `lib/__tests__/test-bidirectional-lifecycle-readme.sh`, `lib/__tests__/test-debrief-schema.sh`, `scripts/bump-version.sh`, `lib/sync-workflow-sot.sh`, `bin/check-invariants.sh` (hang)
- Create: `lib/__tests__/integration/` (adopter-only tier) + an explicit allowlist of what standalone CI runs

- [ ] **Step 1: Census the fresh clone — classify three ways (fail / hang / skip-pass)**

**CRITICAL cwd:** run the suite from the **repo root** (`cd ff`), NOT from `ff/plugins/ship-flow` — the canonical gate does `cd repo_root` (`scripts/bump-version.sh:156`) and several tests resolve `plugins/ship-flow/...` repo-root-relative paths (e.g. `registry-resolve.sh` `check_m2_knowledge`). Running from the plugin dir produces FALSE failures (path-doubling). Use a 60s+ per-test timeout (warn-state-drift is the slowest).
```bash
cd /tmp && rm -rf ff && git clone /Users/kent/conductor/workspaces/spacedock-workflows/yangon ff
cd ff   # REPO ROOT — matches bump-version.sh cd repo_root
for t in plugins/ship-flow/lib/__tests__/test-*.sh; do
  out=$(CI=true timeout 90 bash "$t" 2>&1); rc=$?
  if [ "$rc" = 124 ]; then echo "HANG: $t";
  elif [ "$rc" != 0 ]; then echo "FAIL($rc): $t";
  elif echo "$out" | grep -qE '^[[:space:]]*SKIP:|skipping all|absent.*skipping'; then echo "SKIPPASS: $t";
  fi
done
```
Note: detect true false-green narrowly — a top-level `SKIP:`/`skipping all`/`absent…skipping` abort line, NOT any substring "skip"/"not found" (those appear in legitimate PASS assertions and over-flag). The authoritative signal is rc≠0 / rc=124 plus a genuine skip-on-absence abort. This census IS the work-list (supersedes any grep guess).

- [ ] **Step 2: Resolve each non-PASS test into exactly one of three states (the ledger).** For every FAIL/HANG/SKIPPASS test, choose: **(a) PASS** — rewrite to a local fixture/temp-dir stub so it genuinely exercises the assertion with no monorepo path; **(b) RELOCATED** — move to `lib/__tests__/integration/` (an adopter-only tier standalone CI does NOT run), with a header comment naming the host artifact it needs and why; **(c) DELETED** — only if the test asserts the dogfood instance and has no standalone meaning. **Forbidden:** a test that prints `SKIP`/`degraded`/`not found` and returns rc=0 while remaining in the default suite (that is the false-green being eliminated). The integration tier is excluded by an explicit allowlist, never by silent skip.

- [ ] **Step 3: Fix the 9 hangs** — wrap the suite runner with a bounded `timeout` AND fix/relocate each hanging test so it terminates. `test-check-invariants.sh` hanging is a gate-blocker — it must run to completion on a fresh clone (fix the hang in-place or scope its inputs).

- [ ] **Step 4: Fix the contradiction test** — `test-bidirectional-lifecycle-readme.sh:9-11` asserts the README MUST cite `workflow-adopt`/`workflow-sync`. Co-fix with T5/T6: assert the honest deferred-adoption note exists, not the dangling command names.

- [ ] **Step 5: Fix `test-debrief-schema.sh`** — the real hard-fail is the `_debriefs/*.md` glob loop at lines 19-21 (guard empty/absent dir), NOT just the CARLOVE absolute path at line 23. Fix both: guard the glob AND remove/neutralise `/Users/kent/...` paths (also `test-merged-pr-closeout-reconciler.sh:9`).

- [ ] **Step 6: Add bin node tests to the gate** — `scripts/bump-version.sh` and the standalone CI command must run `node --test plugins/ship-flow/bin/*.test.mjs` (currently excluded; bump-version.sh:76-85 runs only `test-*.sh`).

- [ ] **Step 7: Verify fresh-clone green (three-state acceptance)**

```bash
cd /tmp && rm -rf ff && git clone /Users/kent/conductor/workspaces/spacedock-workflows/yangon ff
cd ff   # REPO ROOT (see Step 1 cwd note)
CI=true timeout 90 bash plugins/ship-flow/bin/check-invariants.sh; echo "inv=$?"   # must terminate, rc 0
fail=0; for t in plugins/ship-flow/lib/__tests__/test-*.sh; do
  out=$(CI=true timeout 90 bash "$t" 2>&1); rc=$?
  [ "$rc" = 0 ] || { echo "NONZERO($rc): $t"; fail=1; }
  echo "$out" | grep -qE '^[[:space:]]*SKIP:|skipping all|absent.*skipping' && { echo "SKIPPASS-IN-SUITE: $t"; fail=1; }
done
node --test plugins/ship-flow/bin/*.test.mjs || fail=1
echo "RESULT fail=$fail"
```
Expected (ACHIEVED 2026-06-26): `inv=0` (2s), pass=101, zero NONZERO, zero SKIPPASS-IN-SUITE, node green → `fail=0`.

- [ ] **Step 8: Produce the before/after ledger table + commit** — a table in the report: each non-PASS test → {fixture | relocated | deleted} + the line it failed/hung on. Commit (`test(ship-flow): decouple suite from monorepo for standalone CI (three-state ledger)`).

### Task 8: B4 — cosmetic fixture version refresh

**Files:**
- Modify: `plugins/ship-flow/lib/__tests__/fixtures/**` files carrying `spacedock@0.9.0`/`0.10.x`

- [ ] **Step 1:** Update fixture `commissioned-by: spacedock@…` stamps to a current-era value for cosmetic consistency (runtime is version-agnostic; this changes nothing functional). - [ ] **Step 2:** Re-run the suite (Task 7 Step 6) → green. - [ ] **Step 3: Commit** (`test(ship-flow): refresh fixture spacedock version stamps`).

### Task 9: AC6 — precise Codex statement + fix CODEX env-marker bug

**SO correction (verified):** the `ship` entry's Codex branch is a **legitimate delegation**, not a false claim — `spacedock 0.22.0` first-officer + ensign are genuinely tri-platform with real `references/codex-*-runtime.md` adapters. So a blanket "downgrade Codex as not-supported" is the WRONG edit (it understates a working delegation). There is also a real consistency BUG: `skills/ship/SKILL.md:24` detects Codex via `CODEX_HOME`, but spacedock 0.22.0 detects via `CODEX_THREAD_ID` (first-officer/SKILL.md:31, ensign/SKILL.md:14) — and `lib/__tests__/test-ship-first-officer-bridge.sh:40` hard-asserts the wrong var.

**Files:**
- Modify: `plugins/ship-flow/skills/ship/SKILL.md` (line ~24 marker + bridge prose), `plugins/ship-flow/lib/__tests__/test-ship-first-officer-bridge.sh` (line ~40), `plugins/ship-flow/README.md`

- [ ] **Step 1: Make the precise honest statement** (in `ship/SKILL.md` + README), verbatim intent: *"`/ship` entry delegates to `spacedock:first-officer`, which supports Claude Code, Codex, and Pi in spacedock 0.22.0 — the entry bridge is Codex-capable. Ship-flow's own stage-dispatch skills (ship-execute, ship-shape ensign dispatch, etc.) are Claude-native and have NOT been verified end-to-end under Codex in 0.7.0 — full-pipeline Codex execution is unverified, not unsupported-by-design."* Do NOT blanket-downgrade. Keep `/codex` review-tool references (the OpenAI Codex CLI review gate — legitimate, unrelated).

- [ ] **Step 2: Fix the env-marker bug** — `skills/ship/SKILL.md:24` `CODEX_HOME` → `CODEX_THREAD_ID` (match the spacedock contract it delegates to), and update `lib/__tests__/test-ship-first-officer-bridge.sh:40` to assert `CODEX_THREAD_ID`. Run that test → green.

- [ ] **Step 3:** Ensure README's Codex note matches the precise statement (delegation Codex-capable; ship-flow pipeline Codex-unverified this release).

- [ ] **Step 4:** Verify: `grep -n "CODEX_HOME" plugins/ship-flow/` returns nothing; the bridge test passes asserting `CODEX_THREAD_ID`.

- [ ] **Step 5: Commit** (`fix(ship-flow): align Codex env marker to CODEX_THREAD_ID + precise Codex-support statement`).

---

## Wave 4 — Verification + Push Gate

### Task 10: AC1 — fresh-clone green (three-state ledger acceptance)

AC1 acceptance (closes the false-green hole): on a fresh clone, `CI=true` over the default suite + `node --test bin/*.test.mjs` yields **zero rc≠0, zero hangs (every test terminates under a bounded timeout), and zero in-suite tests emit a `SKIP`/`degrade`/`not found` line**. Any skip-on-absence test is RELOCATED to the adopter-only integration tier (enumerated by explicit allowlist, NOT silent-skipped) or rewritten to a local fixture.

- [ ] **Step 1:** Run the Task 7 Step 7 three-state census on a fresh `/tmp` clone. Expected: `inv=0` (terminates), zero NONZERO, zero SKIPPASS-IN-SUITE, bin node tests green. - [ ] **Step 2:** `grep -rnE "\.\./\.\./\.\./\.\.|docs/ship-flow/README|/\.claude/settings\.json|/Users/kent" plugins/ship-flow/lib/__tests__ --exclude-dir=integration` → no hits outside the integration tier. - [ ] **Step 3:** Confirm the `lib/__tests__/integration/` allowlist is explicit and that the default-suite runner excludes it by that allowlist (not by silent skip).

### Task 11: AC2 — install + skill/hook smoke

- [ ] **Step 1:** (After push — see Task 13) `/plugin marketplace add iamcxa/spacedock-workflows` then `/plugin install ship-flow`. - [ ] **Step 2:** Invoke one skill and trigger one hook so `${CLAUDE_PLUGIN_ROOT}` resolves in the installed cache (`hooks/hooks.json` + a `warn-*` hook). Expected: resolves, no path errors.

### Task 12: AC3 — dangling-reference grep gate

- [ ] **Step 1: Write the gate as a script** `scripts/check-no-dangling.sh` asserting ZERO hits for: `spacedock-ui`, `spacedock-dev`, `spacedock:overhaul` (all ext), `plugins/spacebridge/design`, `THIS project`/dogfood SOT language, `/Users/kent`, root `.claude/settings.json` deps (outside the integration tier). - [ ] **Step 2:** Run it → Expected: PASS. - [ ] **Step 3:** Confirm no keep-vs-remove contradiction remains (B2 cleanup + the updated bidirectional-lifecycle test agree). - [ ] **Step 4: Commit** the gate script.

### Task 13: AC4/AC5/AC6 final assertions + push gate

- [ ] **Step 1:** `bash scripts/check-version-triple.sh` (AC4) → PASS. - [ ] **Step 2:** AC5 — grep README + `workflow-template.yaml` for the single honest deferred-adoption statement; confirm no `refit up-to-date` claim. - [ ] **Step 3:** AC6 — confirm no `.codex-plugin/` exists, README Claude-only, no un-flagged Codex-runtime claim. - [ ] **Step 4: PUSH GATE — ASK CAPTAIN.** Present the AC1–AC6 evidence. On approval: push `iamcxa/yangon` and open a PR against `master` (or push direct to `master` per captain). Surface any unexpected state (remote divergence, force-push need) BEFORE proceeding.

---

## Self-Review

- **Spec coverage:** B1→T4, B2→T5, B3→T6, B4→T8, B5→T7, Codex/AC6→T9, migration/§5→T1, scaffold/§4→T2, audit/§6 guard→T3, AC1→T10, AC2→T11, AC3→T12, AC4/AC5/AC6→T13. §11 deferred items are explicitly out of scope (non-goals). All spec sections mapped.
- **Audit-gated honesty:** reconciliation tasks (T5/T6/T7) cite the review-verified file:line floor AND consume T3's authoritative list — concrete, not placeholder, with the audit as the completeness net.
- **Skill-authoring escape hatch:** T5/T6 note that any reference fix that becomes a semantic skill rewrite routes to `superpowers:writing-skills` (per the plan-vs-skill-authoring split).
- **Type/name consistency:** gate scripts (`check-version-triple.sh`, `check-no-dangling.sh`) are referenced consistently across T4/T12/T13.
