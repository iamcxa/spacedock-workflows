---
tid: worktree-task-slug-resolution
captured_at: 2026-07-20T05:25:45Z
status: pending
domain: infra
guess_files: ["[upstream spacedock binary] task/entity resolution", docs/ship-flow/README.md]
suggest_done_type: code
entity: null
---

spacedock claude task-by-slug resolution drifts to the main checkout when launched inside a git worktree: mini leg-2 (2026-07-20) booted with cwd/branch/entity all verified correct in the worktree (LEG3 DIAG evidence), yet the FO resolved the MAIN checkout's docs/ship-flow corpus and reported the seeded entity "does not exist — no file, no ROADMAP entry, no todo". Workaround proven in leg-3: task string carries an explicit entity path instead of a bare slug. Same family as #24 (fixture/instance discovery). Needs an upstream spacedock/ship resolution fix; until then, remote/headless dispatch task strings must use explicit paths.
