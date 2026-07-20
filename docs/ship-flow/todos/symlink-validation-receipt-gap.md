---
tid: symlink-validation-receipt-gap
captured_at: 2026-07-20T15:00:00Z
status: pending
domain: backend
guess_files: [plugins/ship-flow/lib/validate-closeout-receipt.py]
suggest_done_type: code
entity: null
---

Pre-existing symlink-following gap: validate-closeout-receipt.py's hash_file()/is_file() usage follows symlinks for index.md/ship.md/review.md alike (verify_source_bytes at :533-534, and hash_file's own is_file() check). A symlinked artifact file is accepted and its target's bytes hashed, contrary to the receipt schema's intended path-safety contract. Not introduced or worsened by entity reconciler-review-artifact-assumption (PR #92) — same pattern pre-dates the review.md-optionality fix and applies uniformly across all 3 artifacts. Follow-up: harden safe_repo_path (or a new helper) to reject symlinks at the final path component, not just intermediate directory components. Surfaced by a codex adversarial cross-model pass during verify, non-blocking (P2).
