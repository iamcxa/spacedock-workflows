# Decisions — tick-hardening

| when | stage | decision | authority | note |
| --- | --- | --- | --- | --- |
| 2026-07-19T16:05Z | shape (gate) | PROCEED | Captain EM-drive grant (hackathon-2 GO + bulk attestation 「原則上是都核准」); condition: ACs absorbed + no new captain decisions | FO spot-check: 6 ACs mapped, AC-2 probe transcript present (PROBE_OK — launcher path decided), reverse-recovery all-EXISTS_BROKEN (no greenfield), head-block root located (ship-flow-scheduler.sh:358 return 0), time_budget 2h30m recorded |
| 2026-07-19T17:05Z | design (gate) | PROCEED | Captain EM-drive grant; condition: within hard rules, zero new captain decisions | 5 deltas concrete vs real main files; --plugin-dir chosen over --skip-compat-check (loads controller plugin checkout); checkpoint rides blocked-event detail (one-event-per-tick preserved); backoff = events-derived continue (Rule 3, no new store); 4 tunables parked to execute-probes |
