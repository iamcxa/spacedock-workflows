---
tid: nested-controller-worktree-support
captured_at: 2026-07-19T12:49:58Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/bin/ship-flow-scheduler.sh]
suggest_done_type: code
entity: null
---

spacedock dispatch build rejects nested controller-worktree entity paths — when the scheduler controller is itself a git worktree, entity paths under it live at .worktrees/<controller>/.worktrees/<entity> and the helper's project-root validation refuses them; FO had to break-glass manual-dispatch the resumed verify stage. Helper should support a nested/controller topology or accept an explicit --state-root. (Upstream: spacedock core binary; tracked here as adopter pain.) Source: rra verify resume 2026-07-19.
