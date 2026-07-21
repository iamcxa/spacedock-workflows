---
tid: mini-tick-account-isolation
captured_at: 2026-07-21T00:13:28Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/references/launchd/, docs/ship-flow/README.md]
suggest_done_type: infra
entity: null
---

Mini tick account isolation (captain direction 2026-07-21): moving dispatch to the mac mini only isolates quota if the mini logs into a SEPARATE account — both machines on one account share session+weekly pools (proven 2026-07-20). Design: mini tick (installed, never loaded) runs on a dedicated background-burn account; MacBook account reserved for interactive/audit. Depends on: controller-state sync (split-root #85), scheduler-quota-preflight, mini-offload-completion-push-channel.
