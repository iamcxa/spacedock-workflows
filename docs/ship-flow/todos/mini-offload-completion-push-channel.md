---
tid: mini-offload-completion-push-channel
captured_at: 2026-07-20T06:58:11Z
status: pending
domain: infra
guess_files: [docs/ship-flow/_debriefs/, "~/Library/LaunchAgents/com.spacedock.mini-fo-*.plist (mini)", plugins/ship-flow/references/launchd/]
suggest_done_type: code
entity: null
---

Mini offload completion push-channel (captain-directed 2026-07-20): remote one-shot FO legs on the mac mini signal completion only via durable state (launchd exit code, git commits, GitHub PR/auto-merge state) that the MacBook audit seat polls on its own turns — no push channel, so an idle-but-open audit session doesn't notice completion until poked. Improvement: end every mini one-shot with a push action (gh PR comment/label, spacebridge message, or an audit-seat wake trigger), keeping durable-rendezvous + poll-on-wake as the honest base layer (laptop-side watchers freeze with the lid). Proven base pattern: legs 1-5 of hackathon-spirit-canonicalization, 2026-07-20.
