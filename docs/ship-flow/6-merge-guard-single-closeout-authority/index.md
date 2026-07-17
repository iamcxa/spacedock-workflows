---
id: "6"
title: "Make spacedock merge guard the single MERGED-to-done closeout authority"
pattern: pitch
appetite: "small-batch (2-3 days)"
layout: folder
harvest_required: true

pre_mortem:
  category: wrong-dcs
  one_liner: Adapter and rewired triggers pass unit tests, but runtime convergence and the debrief-due signal are never proven end-to-end, so single-authority closeout silently fails in the real path.
status: shape
stage_outputs:
  shape: shape.md
---
