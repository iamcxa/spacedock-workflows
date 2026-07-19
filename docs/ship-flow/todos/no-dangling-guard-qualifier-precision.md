---
tid: no-dangling-guard-qualifier-precision
captured_at: 2026-07-19T15:17:46Z
status: pending
domain: infra
guess_files: [scripts/check-no-dangling.sh, plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh]
suggest_done_type: code
entity: null
---

Guard-robustness follow-ups from #71 verify (W1/W2/W3/W5): bare 'override' qualifier term is over-broad (scope to listed phrases or same-sentence proximity); upward logical-unit scan should stop at self-contained list-item starts; broaden qualifier allowlist ('if present', 'falls back to', 'defaults to the plugin copy'); strengthen fixture cases 6/7 naming. Plus W4: add || true to grep -c at check-no-dangling.sh:300. Source: reverse-recovery-audit-dangling-path verify.md Deferred to TODO.
