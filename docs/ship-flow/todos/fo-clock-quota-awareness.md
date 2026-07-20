---
tid: fo-clock-quota-awareness
captured_at: 2026-07-20T05:25:45Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/INVARIANTS.md]
suggest_done_type: docs
entity: null
---

FO clock-and-quota awareness discipline (captain-directed, 2026-07-20 13:23 incident): FO/workers must check wall-clock time before any time-anchored decision (session-limit reset comparison, budget timers, wait-until declarations) — the FO declared "hold until 13:20" without running date when the reset was already at hand. On worker death by session limit: read the reset time, compare with NOW, act (redispatch if past, bounded wait if near, park+report if far). Treat FO's own liveness as quota evidence — if the FO can still speak, a blanket freeze is self-contradictory; probe with a minimal action instead. Note shared-account quota coupling across machines (mac mini + local share one session limit — physical independence != quota independence). Canonical home: INVARIANTS FO-discipline section, sibling of the time-box prose landed by hackathon-spirit-canonicalization.
