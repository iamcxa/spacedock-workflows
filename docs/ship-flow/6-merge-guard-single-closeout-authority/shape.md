# Make spacedock merge guard the single MERGED-to-done closeout authority — Shape

## Problem

Three competing paths turn a merged PR into terminal (done+archive) state: warn-state-drift.sh (SessionStart auto-fix), merged-pr-closeout-reconciler.sh (a second direct set/archive path), and the canonical spacedock merge guard. They diverge in guards, cleanup, and rollback, so closeout depends on which path fires. When C14/PR#47 merged via a direct gh pr merge that bypassed the FO flow, the auto-fix silently did not fire; the captain hand-reconciled (PR#51), which triggered a latent regression (#29).

## Acceptance Outcome

When a ship-flow entity's PR merges, via the FO flow or a direct gh pr merge bypass, it converges to done+archive through exactly one authority (spacedock merge guard), whichever trigger notices; a dirty worktree persists the pr-merge sentinel and a later clean run reconverges without committing on the wrong branch; no compatible driver fails closed with a stable state-driver-unavailable diagnostic; and reaching terminal state surfaces a non-blocking debrief-due signal so the debrief convention is not orphaned.

## Appetite

small-batch (2-3 days)

## Children

- 6.1-closeout-adapter-single-authority — one closeout adapter (gh MERGED → persist pr-merge sentinel → `spacedock merge guard --verdict passed`, idempotent replay, dirty-worktree fail-closed, non-blocking debrief-due signal); all triggers (SessionStart hook, manual, explicit reconcile) delegate to it in one atomic flip; `merged-pr-closeout-reconciler.sh` retired; doc convergence in `pr-merge-paths.md` + README.

## Assumptions

- **A1 (critical, 95%, codebase-grep — VERIFIED)**: `spacedock merge guard <slug> --verdict passed` is the installed-binary (0.25.0, contract 3) idempotent and resumable mutation authority for terminal done+archive. *Verified by running `merge guard --help` + top-level `--help`: confirmed subcommand + arm→detect→clear→terminalize→archive resumable contract.*
- **A2 (critical, 70%, codebase-grep)**: The complete closeout-trigger surface is the SessionStart hook (`warn-state-drift.sh`) plus the manual reconciler (`merged-pr-closeout-reconciler.sh`); FO startup, idle, and explicit reconcile funnel through these, with no third divergent direct-mutation path. *Plan MUST enumerate every trigger before wiring the adapter.*
- **A3 (important, 80%, design-contract)**: The pr-merge sentinel is a ship-flow-owned write-ahead durability marker in entity frontmatter, complementary to merge guard's internal resumability; persisting it before the guard call is what survives a dirty-worktree bail-out. *Issue body decides persist-sentinel-before-merge-guard; grep confirms no code writes this sentinel today.*
- **A4 (important, 90%, codebase-grep — VERIFIED)**: The `state-driver unavailable` fail-closed probe targets `spacedock merge guard` availability, because `state sweep` is absent in the installed 0.25.0 binary. *`spacedock state sweep --help` falls through to top-level help; only `state init` exists.*
- **A5 (important, 90%, codebase-grep — VERIFIED)**: Auto-debrief is not wired today — debrief is a manual convention; the consolidation must not orphan it, hence a non-blocking debrief-due signal at the adapter seam (captain decision D3). *`warn-state-drift.sh` only skips the `_debriefs/` dir; `README.md:489` says run `spacedock:debrief` manually after each shipped pitch.*

## Rabbit Holes

- helm-canonical-adapter-registration-dogfood — Helm adopts the canonical closeout-adapter registration and dogfoods closeout from a clean isolated checkout (no Helm-specific terminalization code). *Follow-up slice per issue; OUT of this landing slice.*

## Deletes (rejected alternatives)

- **Fix each of the three closeout paths independently** — Preserves the fragmentation the issue targets: N paths remain N drift surfaces.
- **Add a new spacedock-core capability or a new `state sweep` detector** — OUT per Non-goals; merge guard 0.25.0 already provides the mutation authority; no speculative core change without a failing Helm dogfood fixture.
- **Have the adapter inline-run the full debrief flow on closeout** — debrief is an interactive LLM skill and cannot run in a SessionStart shell hook; a non-blocking debrief-due signal (D3) is the proportionate mechanism.

## Captain Bet (gate approval 2026-07-17)

> 上線後,不管 ship-flow 本身還是 adopted repos,都不再遇到 merge 流程打架:closeout 一律以安裝的 SD binary 版本為單一權威(`merge guard`)自動收尾;ship-flow 若有額外收尾步驟,adapter 會自動帶上 —— 包含推進到 ship 階段時發出 debrief-due 訊號,不可被略過。若任一項沒做到,這 pitch 就是想錯了「單一權威 + 保住 ship-flow 收尾副作用(debrief)」。

**Captain gate decisions**: D1 — one atomic PR (no two-authority intermediate); D2 — doc convergence (`pr-merge-paths.md` + README) in the same PR; D3 — debrief-due is a lightweight non-blocking signal at the adapter seam (not an inline debrief run).

## Domain Registry Validation

- classify: `bash plugins/ship-flow/lib/registry-resolve.sh --classify docs/ship-flow/6-merge-guard-single-closeout-authority/shape.md`
- validate: n/a (no domain matched)
- domain: (none)
- result: proceed

## Hand-off to Plan

- design-skipped: true

*Design skipped per G14 passthrough: `affects_ui: false` AND `domain:` unset AND `design_required: false` AND `contract_decision_required: false` (registry matched nothing; the one contract ambiguity — debrief-attach semantics — was resolved at the captain gate as D3). Planner imports no design DCs.*

### Plan must resolve (open questions from L0 research, ranked)

1. **Enumerate ALL closeout triggers** (A2) — confirm FO startup / FO idle / explicit reconcile funnel through the two known scripts, or find any third direct-mutation path, before wiring.
2. **Pin `merge guard` failure modes / exit codes empirically** — help text is the only contract observed; dry-run against an `armed`/merged fixture entity to pin behavior (esp. dirty-worktree and open-PR resume) before three call sites depend on it.
3. **Sentinel ownership** — adapter writes `pr=pr-merge:{N}` to entity frontmatter (write-ahead) vs. relying on merge guard resumability; define idempotent replay = no-op.
4. **Adapter home + retirement** — where the ONE adapter lives; how `merged-pr-closeout-reconciler.sh` retires (delete vs thin-shim to adapter); preserve its worktree/branch cleanup only if a trigger still needs it.
5. **Unify dirty-worktree fail-closed contract** across all triggers (sentinel persisted, no mutation, later clean run converges, never commits on the wrong branch).
6. **Debrief-due signal shape** (D3) — non-blocking emission to the existing closeout report surface after a successful terminalize; test that it fires and never blocks/rolls back closeout.
7. **`auto_fix: execute` gating** — decide whether the adapter path preserves the opt-in flag or becomes unconditional once wired.
8. **CI**: touching `plugins/ship-flow/**` runs the full shell suite (~6-7 min) + node + version-triple + no-dangling — run locally before PR; watch the CI git-identity fixture pattern in the two large test files.
