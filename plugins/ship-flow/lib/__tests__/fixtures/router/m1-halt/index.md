---
id: "fixture-m1-halt"
title: "M1 halt fixture — affects_ui=false, domain=schema, no specialist yet"
status: sharp
affects_ui: false
domain: schema
---

# Fixture: M1 HALT path

Entity with `affects_ui: false` and `domain: schema` set.
Expected router behavior: design router consults registry-resolve --validate --domain=schema,
registry returns exit 10 (M1: specialist_missing, designer_section_anchor empty until 113.3),
router emits ## Design Output → ### Router HALT block with 3 options.
