---
tid: plist-installer-placeholder-validation
captured_at: 2026-07-19T20:25:27Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/references/launchd/, docs/ship-flow/_archive/l3-scheduler-tick/RUNBOOK.md]
suggest_done_type: code
entity: null
---

Wave-0 install substituted 2 of 3 template placeholders and missed @SPACEDOCK_BIN@ (unknown third placeholder) — silent until the hardened preflight read it and failed closed. The install step needs a mechanical no-remaining-@PLACEHOLDER@ validation (grep in the RUNBOOK install command or a tiny install script).
