---
title: Fix tick refusal scanning head-block
status: draft
---

A refusal consumes the tick's single bounded action and refusals are not deduped/backoff-cached, so the eligibility scan re-refuses the alphabetically-first dormant entity every beat and never reaches later eligible entities (20:15+20:20 identical refusal beats on 2-deterministic-manual-adopter-routing while shaped+approved no-dangling-guard-qualifier-precision sat waiting). Fix: refusals are scan-events not the beat's action (batch-emit, then dispatch the first eligible in the same beat) + refusal dedup window. This blocked hackathon-2's live finale.
