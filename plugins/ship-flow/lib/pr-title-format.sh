#!/usr/bin/env bash
# Shared PR title format rule. Source this file; do not duplicate the regex.

PR_TITLE_REGEX='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)\([a-z0-9][a-z0-9._/-]*\)!?: [A-Za-z0-9`].+'
# shellcheck disable=SC2034 # Used by scripts that source this shared rule.
PR_TITLE_FORMAT='type(scope): subject'

validate_pr_title() {
  local title="$1"
  [[ "$title" =~ $PR_TITLE_REGEX ]]
}
