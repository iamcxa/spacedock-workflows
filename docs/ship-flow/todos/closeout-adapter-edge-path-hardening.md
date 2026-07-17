---
tid: closeout-adapter-edge-path-hardening
captured_at: 2026-07-18T00:00:00Z
status: pending
domain: dx
guess_files: [plugins/ship-flow/bin/closeout-adapter.sh]
suggest_done_type: code
entity: null
source_pitch: "6"
---

**Follow-up to #46 (closeout-adapter single authority). Split out per captain decision** — #46's core contract (single authority, convergence, debrief on the normal path) is delivered and runtime-proven; these are deeper error/crash/replay-path robustness items surfaced by codex rounds 3–4 that are beyond #46's literal acceptance criteria. They cluster into structural root causes, so a focused pass (not per-instance whack-a-mole) is warranted.

## Findings deferred from #46 (codex round-4, adjudicated real)

- **debrief_due crash-durability (round-4 #4/#5)** — `debrief_due` is emitted only on the fresh-finalize path. An archived replay (`already_reconciled`) does NOT re-emit it, so a process death/timeout after the archive commit but before the original report permanently loses the mandatory signal (touches the captain Bet's "debrief 不可被略過", but only on a crash at a specific instant). Structural fix: persist debrief-due state (or re-emit on any coherent-archived detection) until explicitly acknowledged.
- **merge-guard output parsing (round-4 #5)** — `run_merge_guard` captures combined `2>&1` and matches `finalized:*` at the START of output; a warning line preceding a real `finalized:` would misclassify an already-mutated closeout as `state-driver-unavailable` and drop its debrief. Fix: parse an anchored `finalized:` LINE (grep) or a structured `--json`/`--quiet` signal, and verify the resulting archived state before assigning the verdict.
- **replay WIP guard (round-4 #1)** — the dirty-entity WIP guard runs only on the fresh (no-sentinel) path; a sentinel replay can still fold unrelated uncommitted entity edits into the sentinel commit. Fix: apply the dirty-path validation on replay too (commit only a verified sentinel-only diff).

## Shape

Consider a small structural refactor rather than more point-fixes: (a) make `debrief_due` durable/re-emittable across all coherent-archived detections; (b) route every commit path (fresh, recovery, replay) through one shared gate set; (c) robust merge-guard output parsing. Re-run `ship-flow:codex-gate` to confirm convergence.

Note: `merge guard` at 0.25.0 emits single-line `finalized:` output (verified), so #5 is latent at the current binary version.
