---
id: "fixture-no-trigger"
title: "No trigger fixture — affects_ui=false, no domain"
status: sharp
affects_ui: false
---

# Fixture: No trigger path

Entity with `affects_ui: false` and no `domain:` set.
Expected router behavior: design skips (skip-when: "!affects_ui && !domain" fires).
