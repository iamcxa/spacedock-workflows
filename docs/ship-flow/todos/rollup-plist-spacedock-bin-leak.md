---
tid: rollup-plist-spacedock-bin-leak
captured_at: 2026-07-20T01:42:16Z
status: pending
domain: infra
guess_files: [~/Library/LaunchAgents/com.spacedock.ship-flow-scheduler.rollup.plist, plugins/ship-flow/references/launchd/]
suggest_done_type: code
entity: null
---

Fix live rollup.plist @SPACEDOCK_BIN@ leak: the MacBook's installed com.spacedock.ship-flow-scheduler.rollup.plist still carries a literal unsubstituted <string>@SPACEDOCK_BIN@</string> in its EnvironmentVariables dict (the tick plist had the same defect, fixed 04:10 2026-07-20; rollup was never fixed and would fail identically when its @SPACEDOCK_BIN@ path runs — historical evidence: 4x '@SPACEDOCK_BIN@ CLI not available for --runner gh' in the tick err.log). Sharpens the R3 lesson tracked in plist-installer-placeholder-validation: the leak lives in the plist EnvironmentVariables value, not the runner script — installer validation must grep installed plists, and both agents (tick + rollup) need the zero-@PLACEHOLDER@ check. (Evidence found by Mac mini bootstrap probe 2026-07-20; mini's freshly-generated plists validated clean.)
