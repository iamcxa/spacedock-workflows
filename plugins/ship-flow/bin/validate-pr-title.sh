#!/usr/bin/env bash
# Validate a pull request title against the repository conventional title rule.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
RULE_LIB="${SCRIPT_DIR}/../lib/pr-title-format.sh"

if [ ! -f "$RULE_LIB" ]; then
  printf 'ERROR: PR title format helper not found\n' >&2
  exit 1
fi

# shellcheck source=plugins/ship-flow/lib/pr-title-format.sh
. "$RULE_LIB"

usage() {
  printf 'Usage: %s "<pull request title>"\n' "$(basename "$0")" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

title="$1"

if validate_pr_title "$title"; then
  printf 'PR title format ok: %s\n' "$title"
  exit 0
fi

cat >&2 <<EOF
Invalid PR title: ${title}
Expected format: ${PR_TITLE_FORMAT}
Accepted examples:
  fix(ship-flow): repair merged PR closeout runtime
  docs(ship-flow): update merge guidance
EOF
exit 1
