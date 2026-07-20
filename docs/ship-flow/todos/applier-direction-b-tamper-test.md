---
tid: applier-direction-b-tamper-test
captured_at: 2026-07-20T15:00:00Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/lib/apply-closeout-bundle.sh, plugins/ship-flow/lib/__tests__/test-closeout-receipt.sh]
suggest_done_type: code
entity: null
---

Test coverage gap: apply-closeout-bundle.sh has no applier-level Direction-B tamper test (receipt claims a "review" source_hashes key while review.md is actually absent on disk) — only Direction-A (file-exists-but-key-omitted) is pinned at the applier layer (test-closeout-receipt.sh's RA_APPLY_* block). Direction-B is currently proven only at the validator layer (test-closeout-receipt.sh:535, pre-existing). This was a deliberate design.md scoping decision through 2 REVISE cycles (relying on validator/applier semantic parity), restored to valid by entity reconciler-review-artifact-assumption's is_file() fix (commit 4b0a0f8). Follow-up: add a dedicated applier-level Direction-B fixture mirroring the existing Direction-A applier test's shape. Surfaced by a codex adversarial cross-model pass during verify, non-blocking (P2).
