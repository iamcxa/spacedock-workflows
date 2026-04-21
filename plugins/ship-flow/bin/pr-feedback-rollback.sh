#!/usr/bin/env bash
# pr-feedback-rollback.sh — close PR + flip entity status for ship-execute Mode B
# Usage: pr-feedback-rollback.sh <entity-file> <target-status> <pr-number> [round]
#
# Folded from ship-pr-feedback skill (2026-04-21, entity 064 pr-feedback-fold,
# harness-diet cut principle #2: separate-skill-for-small-function → inline-in-parent
# with tag). Mechanics: (1) flip frontmatter `status:` to target-status,
# (2) bump `pr_feedback_round:`, (3) close PR via gh/glab. Do NOT delete branch —
# next execute pass adds commits to same branch, ship opens new PR.
set -euo pipefail

ENTITY="${1:?Usage: pr-feedback-rollback.sh <entity-file> <target-status> <pr-number> [round]}"
TARGET="${2:?target-status required (execute|plan)}"
PR="${3:?pr-number required}"
ROUND="${4:-1}"

# Validate target-status enum
case "$TARGET" in
  execute|plan) ;;
  *) echo "Error: target-status must be execute|plan (got: $TARGET)" >&2; exit 2 ;;
esac

# Validate entity file exists and is writable
[ -f "$ENTITY" ] || { echo "Error: entity file not found: $ENTITY" >&2; exit 4; }
[ -w "$ENTITY" ] || { echo "Error: entity file not writable: $ENTITY" >&2; exit 4; }

# Inline VCS detection (ported from ship-pr-feedback V1-V3; self-contained
# per harness-diet principle — full preamble extraction deferred to 046f)
if git remote -v 2>/dev/null | grep -q 'github\.com'; then
  VCS="github"
elif git remote -v 2>/dev/null | grep -q 'gitlab\.com'; then
  VCS="gitlab"
else
  echo "Error: unknown VCS provider (expected github or gitlab in git remote)" >&2
  exit 3
fi

# Flip frontmatter status + pr_feedback_round (macOS/BSD sed-compatible -i '' idiom)
sed -i.bak -E "s/^status:[[:space:]].*/status: ${TARGET}/" "$ENTITY"
if grep -q '^pr_feedback_round:' "$ENTITY"; then
  sed -i.bak -E "s/^pr_feedback_round:[[:space:]].*/pr_feedback_round: ${ROUND}/" "$ENTITY"
else
  # Append pr_feedback_round field right after status: line
  sed -i.bak -E "/^status:/a\\
pr_feedback_round: ${ROUND}
" "$ENTITY"
fi
rm -f "${ENTITY}.bak"

# Close PR with rollback comment (do NOT delete branch)
case "$VCS" in
  github)
    gh pr close "$PR" --comment "Rolling back to ${TARGET} for fixes based on review feedback. See entity ## PR Review Feedback for details."
    ;;
  gitlab)
    # glab mr close does not support --comment; post separately then close
    glab mr comment "$PR" --message "Rolling back to ${TARGET} for fixes based on review feedback. See entity ## PR Review Feedback for details."
    glab mr close "$PR"
    ;;
esac

echo "Rollback complete: entity=${ENTITY} status=${TARGET} pr=${PR} round=${ROUND} vcs=${VCS}"
