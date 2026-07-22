---
id: "006"
title: "Attempt-scoped stage circuits execution re-slice"
entity_type: epic
pattern: epic
external_project: "ship-flow:attempt-scoped-stage-circuits/e800e54"
layout: folder
children:
  - 006.1-attempt-circuit-protocol-and-clock-authority
  - 006.2-attempt-circuit-crash-safe-history-and-replay
  - 006.3-attempt-circuit-bounded-route-and-immutable-21-compatibility
  - 006.4-attempt-circuit-plan-execute-integration-and-full-regression
status: epic
stage_outputs: {}
---

<!-- section:dependency-graph -->
## Dependency Graph

```mermaid
graph LR
  n006_1["006.1 Attempt circuit protocol and clock authority"]
  n006_2["006.2 Attempt circuit crash-safe history and replay"]
  n006_3["006.3 Attempt circuit bounded route and immutable #21 compatibility"]
  n006_4["006.4 Attempt circuit plan-execute integration and full regression"]
  n006_1 --> n006_2
  n006_2 --> n006_3
  n006_3 --> n006_4
```
<!-- /section:dependency-graph -->
