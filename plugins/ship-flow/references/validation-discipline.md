# Validation Discipline — process vs output

**Audience**: ship-flow stage skill authors and FOs designing in-pipeline validation experiments.

## TL;DR

When you want to verify "did the worker do X correctly", check the **output shape** (code-pattern grep, structural DC, runtime assertion) in verify stage. Do **NOT** design a per-dispatch experiment to verify the **process** (did the worker load skill Y, did the worker read section Z, did the worker attest to step W).

Process-effect validation has structurally bad cost-to-signal ratio in this pipeline. Output-shape DCs are process-agnostic, accumulate evidence naturally across N, and survive the case where a worker applies the rule from training prior instead of from skill load.

## The trap — n=1 (or n=N small) process-effect validation

Recurring failure mode:

1. Verify stage catches a specific code-pattern miss (e.g. saga listener absent, RBAC pattern violated, design token hardcoded).
2. FO hypothesizes "the worker didn't load skill X" — a process-level claim.
3. FO designs a validation experiment around that hypothesis: inject an attestation token, require the worker to echo it, gate DONE on the echo, sample N dispatches, compare control vs treatment.
4. Experiment ships, burns dispatch budget, produces inconclusive or post-hoc-polluted results, and the underlying code-pattern miss STILL has to be caught by an output-shape DC anyway.

**Net effect**: ceremonial verification primitives accumulate in `plugins/ship-flow/lib/`, dispatch prompts get longer, and the actual safety net is still the verify-stage DC.

## Three failure modes of process-effect validation

These will fire in combination on virtually every attempt:

1. **Scope mismatch** — the predicate (e.g. "did worker register a saga?") doesn't apply to the task type the worker happened to receive (e.g. worker was adding a CASE to existing saga, not registering a new one). Result: INCONCLUSIVE on otherwise-clean dispatches.
2. **Baseline contamination** — workers already apply most skill rules from training prior + dispatch-prompt name-mention + CLAUDE.md context, before any inject experiment runs. Prior commits will grep-PASS the predicate without the inject. Result: control == treatment, attribution to inject is unsupported.
3. **Timing pollution** — the predicate is rarely locked BEFORE the dispatch in practice. Most experiments rationalize the predicate post-hoc to match what the worker happened to produce. Result: false positive.

## Decision rule — output-shape DC vs process attestation

| Question | Home | Tool |
|---|---|---|
| Did the worker produce code matching pattern X? | verify stage (this skill) | grep / AST / unit test / runtime probe |
| Did the worker apply rule Y to file class Z? | verify stage (per-domain DC) | scoped grep against touched files |
| Did the worker load skill W? | **not verifiable, do not try** | n/a |
| Did the worker read section S of skill W? | **not verifiable, do not try** | n/a |
| Did the worker echo attestation token T? | **anti-pattern, do not add** | n/a |

If the rule you care about is checkable from code output → write it as a verify-stage DC (or, when the rule is project-domain-specific, surface it through the per-domain DC pattern in `ship-verify` Step 4.x).

If the rule is only checkable from worker process — cut it. You cannot verify it, and you don't need to: the rule has value because its application produces a recognizable code pattern, and that code pattern is what you actually care about.

## Specific rationalizations to reject

Captured from prior baseline tests. When you find yourself authoring any of the following, stop:

| Rationalization | Why reject |
|---|---|
| "Add a skill-canary token to the skill body; require workers to echo it in the receipt" | Canary proves loaded, not applied. Workers also load skills via direct `Read` calls (no `Skill()` invocation) and still produce correct output. You are gating on the wrong signal. |
| "Run N=10 dispatch experiment: 5 control, 5 treatment, compare X rate" | (a) Baseline contamination (workers already apply most rules); (b) scope mismatch is high in small-N; (c) cost (~$ + ~2 weeks live, or 1 day with synthetic fixtures that don't represent real distribution); (d) verdict almost always lands as "kill the gate, pivot to behavior DC" — start there. |
| "Add `canary_echo:` field to entity body schema / Context Read Receipt" | Permanent schema bloat for a one-shot validation hypothesis. Other adopters inherit the field forever. |
| "Author `check-skill-canary-receipt.sh` primitive" | Ceremonial verification primitive. Maintenance load, BLOCKING gate on a signal that doesn't track the failure mode. |
| "Phase 1 to verify baseline is high enough to kill the gate" | If you suspect baseline is high, treat it AS the prior. Skip Phase 1, write the behavior DC, done. |
| "Worker self-attestation in stage report — list skills loaded" | Self-attestation is unverifiable. Listing skill names in a report is one of the easiest things to confabulate; it cost nothing to add and adds nothing to safety. Existing `## Context Manifest` Skills loaded field is **audit trail only**, not a gate input. Do not promote it. |

## When experiments ARE worth running

Process-level validation is appropriate when:

- The signal is observable from outside the dispatched worker (e.g. tool-use log from the Agent SDK, when available).
- N can reach ≥5 matched-scope tasks before you commit to a decision.
- Both pass and fail outcomes change a concrete decision you have not already made.

Without all three: write the output-shape DC and skip the experiment.

## Case study — 2026-05-16 saga inject validation

Concrete incident the discipline rule was authored from:

- **Trigger**: `care-options` verify caught F-1 (fmodel saga listener absent). FO hypothesized worker did not load `fmodel` skill on dispatch.
- **Experiment designed**: inline `Skill(skill='fmodel')` inject in dispatch prompt + 3 grep predicates (saga listener registered, `occurred_at` not `new Date()`, Rejection event naming) as validation.
- **Run**: n=1 dispatch (`worker 2 saga`). Result: 1 PASS (`occurred_at`), 2 INCONCLUSIVE (scope mismatch — worker added case to existing saga, didn't register new one; worker produced command, didn't emit new rejection event).
- **Pollution**: predicate-lock spec arrived AFTER dispatch (timing pollution). Inject skills used (`fmodel + backend-workflow + vitest`) didn't match spec's `fmodel + domain-patterns`.
- **Contamination signal**: same worker's prior commits (T1.1/T2.1) ALREADY used `occurred_at` correctly without inject. Treatment effect indistinguishable from baseline.
- **Verdict at retro**: inject is cheap + nonzero positive (keep as light prime), but per-dispatch validation around inject has bad cost/signal. Move the safety net to verify-stage per-domain DC.

The F-1 catch itself — verify stage grep on saga-touched files — is the existence proof that the output-shape mechanism works. That's where the load lives.

## Cross-references

- `plugins/ship-flow/skills/ship-execute/SKILL.md` — Step 2 dispatch prompt anatomy (inject discipline; no Stage Report attestation gate).
- `plugins/ship-flow/skills/ship-verify/SKILL.md` — Step 4 DC pattern (per-domain output-shape DCs; the load-bearing safety net).
- `plugins/ship-flow/skills/ship-plan/SKILL.md` — Step 3.5 (when proposing validation tasks, classify output-shape vs process-shape before authoring).
- `plugins/ship-flow/INVARIANTS.md` — Principle 6 (context continuity); validation discipline is a Layer B augmentation around Layer A (`superpowers:writing-plans`).
