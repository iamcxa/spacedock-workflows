#!/usr/bin/env bash
# build-landing-fixture.sh — sourced test helper (not a standalone script).
#
# Builds a hermetic git repo that genuinely satisfies merged-pr-closeout-
# reconciler.sh's require_landing_contract + reconcile_direct_bundle contract
# (landing_anchor/source_commits/pr_commit_count, review.md/ship.md, a
# ROADMAP.md Now/Shipped section pair) so scheduler reconcile tests can drive
# the tick to a REAL PROCEED verdict.
#
# Why this exists: the scheduler test suite originally reused
# fixtures/merged-pr-closeout-reconciler/pr-merged.env directly for its
# "PROCEED" assertions. That exact file is the reconciler's OWN suite's
# deliberately-incomplete negative fixture — test-merged-pr-closeout-
# reconciler.sh's run_incomplete_landing_contract_case asserts THIS SAME FILE
# must REJECT with reason=landing-anchor-missing. A reconcile PROCEED can
# never be reached that way, in any environment. This helper mirrors
# test-merged-pr-closeout-reconciler.sh's prepare_full_d1_repo recipe (proven —
# that suite passes), simplified to a single "landing" commit per entity
# (verified against resolve-landing-envelope.sh: a single source commit that
# equals the landing anchor makes both the rebase and squash candidates valid
# by construction; ship.md's merge_method_intent: rebase deterministically
# breaks that tie via the intent-discriminator path).

# scaffold_landing_repo <repo_dir>
# git init + identity + docs/ship-flow/{README.md,_mods/pr-merge.md} +
# ROADMAP.md (empty Now/Shipped sections) + initial commit.
scaffold_landing_repo() {
  local repo="$1"
  git init -q -b main "$repo"
  git -C "$repo" config user.email "scheduler-fixture@example.test"
  git -C "$repo" config user.name "Scheduler Fixture"
  mkdir -p "${repo}/docs/ship-flow/_mods"
  cat > "${repo}/docs/ship-flow/README.md" <<'EOF'
---
commissioned-by: spacedock@0.22.0
id-style: slug
stages:
  states:
    - name: ship
      next: done
      worktree: true
    - name: done
      terminal: true
      worktree: false
---

# Fixture Workflow
EOF
  cat > "${repo}/docs/ship-flow/_mods/pr-merge.md" <<'EOF'
---
name: pr-merge
standing: true
---

## Agent Prompt

Fixture merge hook.
EOF
  # .ship-flow-scheduler.lease/ + .ship-flow-scheduler-receipts/ mirror this
  # repo's own root .gitignore: the tick's mkdir-atomic controller lease and
  # the runner adapter's receipt dir both land inside controller_worktree,
  # which in the realistic same-repo topology (workflow_dir + controller
  # inside the project's own checkout) IS the repo the reconciler's dirty-
  # worktree guard (`git status --porcelain --untracked-files=all`) inspects —
  # untracked, un-ignored lease/receipt dirs make that guard fail closed with
  # closeout-checkpoint-conflict on every real reconcile.
  printf '%s\n' '.worktrees/' '.ship-flow-scheduler.lease/' '.ship-flow-scheduler-receipts/' > "${repo}/.gitignore"
  printf '%s\n' '# Roadmap' '' '## Now' '<!-- section:now -->' \
    '<!-- /section:now -->' '' '## Shipped' '<!-- section:shipped -->' \
    '| Entity | Title | Shipped |' '| --- | --- | --- |' \
    '<!-- /section:shipped -->' > "${repo}/ROADMAP.md"
  git -C "$repo" add -- .gitignore ROADMAP.md docs/ship-flow/README.md docs/ship-flow/_mods/pr-merge.md
  git -C "$repo" commit -qm 'fixture: initial workflow scaffold'
}

# commit_entity_dir <repo_dir> <slug> <source_dir>
# Copies an existing fixture entity directory in as-is and commits it — for
# entities that participate in a scenario (dispatch, sibling readiness) but
# never go through reconcile themselves (no review.md/ship.md/landing needed).
commit_entity_dir() {
  local repo="$1" slug="$2" src="$3"
  mkdir -p "${repo}/docs/ship-flow"
  cp -R "$src" "${repo}/docs/ship-flow/${slug}"
  git -C "$repo" add -- "docs/ship-flow/${slug}"
  git -C "$repo" commit -qm "fixture: add ${slug}"
}

# write_entity_index <repo_dir> <slug> <content>
# Writes (or overwrites) an entity's index.md from inline content and stages
# it, WITHOUT committing — callers batch this with other changes in one
# commit (see land_entity).
write_entity_index() {
  local repo="$1" slug="$2" content="$3"
  mkdir -p "${repo}/docs/ship-flow/${slug}"
  printf '%s' "$content" > "${repo}/docs/ship-flow/${slug}/index.md"
  git -C "$repo" add -- "docs/ship-flow/${slug}/index.md"
}

# land_entity <repo_dir> <slug> <pr_number> <title> <out_env_path>
# Adds review.md + ship.md (PASSED verdict, non-empty Todo Closeout Digest,
# merge_method_intent: rebase), inserts a Now-section ROADMAP row for the
# entity if not already present, commits everything staged so far (including
# any index.md edits the caller already staged via write_entity_index or a
# prior set_frontmatter_field + git add), then computes a complete merged-PR
# provider fixture (landing_anchor/source_commits/pr_commit_count) from the
# resulting commit and writes it to out_env_path.
land_entity() {
  local repo="$1" slug="$2" pr_number="$3" title="$4" out_env="$5"
  printf '%s\n' '# Review' '' '## Verdict' '' 'PASSED' > "${repo}/docs/ship-flow/${slug}/review.md"
  printf '%s\n' '# Ship' '' '## Todo Closeout Digest' '' \
    '- Fixture closeout bundle.' '' '### Verdict' \
    'merge_method_intent: rebase' "pr: \"#${pr_number}\"" \
    > "${repo}/docs/ship-flow/${slug}/ship.md"
  if ! grep -qF "| ${slug} |" "${repo}/ROADMAP.md"; then
    awk -v row="| ${slug} | ${title} |" \
      '{print} /<!-- section:now -->/ && !added {print row; added=1}' \
      "${repo}/ROADMAP.md" > "${repo}/ROADMAP.md.tmp"
    mv "${repo}/ROADMAP.md.tmp" "${repo}/ROADMAP.md"
  fi
  git -C "$repo" add -- "docs/ship-flow/${slug}" ROADMAP.md
  git -C "$repo" commit -qm "implementation: land ${slug}"
  local anchor
  anchor="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' 'provider=fixture' "number=${pr_number}" 'state=MERGED' \
    'merged_at=2026-07-19T00:00:00Z' \
    "head_ref=ship-${slug}" 'base_ref=main' \
    "url=https://github.com/example/repo/pull/${pr_number}" 'repository=example/repo' \
    "landing_anchor=${anchor}" "source_commits=${anchor}" \
    'pr_commit_count=1' > "$out_env"
}
