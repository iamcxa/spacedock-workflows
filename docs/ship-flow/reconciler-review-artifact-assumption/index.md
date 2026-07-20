---
title: Fix reconciler review-artifact validation
status: draft
---

Tick reconcile of every merged entity blocks with closeout-review-missing: the reconciler demands review.md but this workflow's 8-stage taxonomy folds review into verify — the closeout validation must accept the workflow's actual artifact set (verify.md as review-bearing) or read the stage taxonomy. Evidence: l3/rra/missing-canonical-mods reconcile-blocked beats 2026-07-19 19:26-20:10 in controller events log. Blocks Phase-A auto-closeout for ALL merged entities.
