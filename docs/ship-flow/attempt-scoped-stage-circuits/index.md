---
title: Make stage circuits attempt-scoped and recoverable
status: shape
source: SO/EM narrow verdict on shape-confirm-instance-awareness plan recovery
started: 2026-07-22T02:05:16Z
completed:
verdict:
score: 0.95
worktree:
issue:
pr:
---

Ship-Flow's plan circuit breaker measures an accumulated stage clock but has no durable attempt identity or fresh-versus-resume semantics. After a truthful partial receipt, a newly dispatched continuation inherits an already-expired duration and can never legitimately pass, producing deterministic recovery livelock and forcing agents to infer lifecycle from prose.

## Acceptance criteria

- **AC-1 (value, cli):** After a partial attempt, one fresh continuation can complete within its own 20-minute budget and publish a truthful passed receipt; resume/replay cannot reset that same attempt's budget.
- **AC-2 (mechanism, cli):** Dispatch and receipts carry durable `attempt_id`, `attempt_started_at`, terminal state, and lease binding; current-attempt duration is distinct from monotonic cumulative stage duration.
- **AC-3 (value, cli):** Crash recovery and receipt replay are idempotent: no duplicate attempt, no double-counted duration, and no ambiguous unclosed attempt.
- **AC-4 (mechanism, cli):** A bounded attempt-count or cumulative-duration escalation prevents infinite retry and emits an explicit routeable outcome.
- **AC-5 (value, cli):** The existing #21 partial receipts remain auditable, and one post-landing attempt-scoped revalidation can unblock its unchanged technical plan without waiving the breaker.

## Scope

In: attempt lifecycle schema/prose, FO dispatch envelope/lease integration, receipt publication and validators, recovery/idempotency tests, and bounded escalation.

Out: redesigning #21's allocator plan, changing product code in its preserved diff, generic distributed scheduling, split-root expansion unrelated to attempt identity, or silently treating partial as passed.
