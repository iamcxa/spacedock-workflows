#!/usr/bin/env bash
# check-design-readiness-review.sh - gate design readiness before plan.
#
# Usage:
#   bash plugins/ship-flow/lib/check-design-readiness-review.sh <design.md>

set -euo pipefail

if [ "${1:-}" = "" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: bash plugins/ship-flow/lib/check-design-readiness-review.sh <design.md>"
  exit 2
fi

DESIGN_FILE="$1"

if [ ! -f "$DESIGN_FILE" ]; then
  echo "status=blocked reason=design-file-missing"
  exit 2
fi

has() {
  grep -qiE "$1" "$DESIGN_FILE"
}

append_unique() {
  local list="$1"
  local item="$2"
  if [ -z "$list" ]; then
    printf '%s' "$item"
    return
  fi
  case ",${list}," in
    *",${item},"*) printf '%s' "$list" ;;
    *) printf '%s,%s' "$list" "$item" ;;
  esac
}

contains_item() {
  local list="$1"
  local item="$2"
  case ",${list}," in
    *",${item},"*) return 0 ;;
    *) return 1 ;;
  esac
}

affects_ui=false
domain=""
if has '(^|[[:space:]])affects_ui:[[:space:]]*true([[:space:]]|$)'; then
  affects_ui=true
fi
domain="$(sed -nE 's/^[[:space:]]*domain:[[:space:]]*([A-Za-z0-9_-]+).*/\1/p' "$DESIGN_FILE" | head -1)"

has_whole_page=false
if has 'whole_page_visual_targets:'; then
  has_whole_page=true
fi

has_migration=false
if has 'apps/supabase/migrations/|(^|[^A-Za-z0-9_-])migration([^A-Za-z0-9_-]|$)'; then
  has_migration=true
fi

has_api=false
if has 'ts-rest|api-contract|public api'; then
  has_api=true
fi

has_fmodel=false
if has 'fmodel|ddd|saga'; then
  has_fmodel=true
fi

triggers=""
reviewers=""

if [ "$affects_ui" = true ] && [ -n "$domain" ]; then
  triggers="$(append_unique "$triggers" "multi-domain")"
fi
if [ "$has_migration" = true ]; then
  triggers="$(append_unique "$triggers" "migration")"
fi
if [ "$has_api" = true ]; then
  triggers="$(append_unique "$triggers" "api-contract")"
fi
if [ "$has_fmodel" = true ]; then
  triggers="$(append_unique "$triggers" "fmodel")"
fi
if [ "$has_whole_page" = true ]; then
  triggers="$(append_unique "$triggers" "high-risk-ui")"
fi

if [ "$affects_ui" = true ] || [ "$has_whole_page" = true ]; then
  reviewers="$(append_unique "$reviewers" "ui")"
fi
case "$domain" in
  schema) reviewers="$(append_unique "$reviewers" "schema")" ;;
  api) reviewers="$(append_unique "$reviewers" "api")" ;;
  fmodel|domain) reviewers="$(append_unique "$reviewers" "fmodel")" ;;
esac
if [ "$has_migration" = true ]; then
  reviewers="$(append_unique "$reviewers" "schema")"
fi
if [ "$has_api" = true ]; then
  reviewers="$(append_unique "$reviewers" "api")"
fi
if [ "$has_fmodel" = true ]; then
  reviewers="$(append_unique "$reviewers" "fmodel")"
fi

if [ -z "$triggers" ]; then
  if has 'Design Readiness Review:[[:space:]]*skipped[[:space:]]*-[[:space:]]*no risk trigger|docs-only:[[:space:]]*true|appetite:[[:space:]]*trivial'; then
    echo "status=skipped reason=no-risk-trigger"
    echo "risk_triggers="
    echo "required_reviewers="
    exit 0
  fi

  echo "status=blocked reason=design-readiness-skip-reason-missing"
  exit 1
fi

if ! grep -q '^## Design Readiness Review$' "$DESIGN_FILE"; then
  echo "status=blocked reason=design-readiness-review-missing"
  echo "risk_triggers=${triggers}"
  echo "required_reviewers=${reviewers}"
  exit 1
fi

review_block="$(
  awk '
    /^## Design Readiness Review$/ { in_block=1; next }
    /^## / && in_block { exit }
    in_block { print }
  ' "$DESIGN_FILE"
)"

declared_reviewers="$(
  printf '%s\n' "$review_block" \
    | sed -nE 's/^[[:space:]]*reviewers:[[:space:]]*//p' \
    | head -1 \
    | tr -d '[:space:]'
)"
verdict="$(
  printf '%s\n' "$review_block" \
    | sed -nE 's/^[[:space:]]*verdict:[[:space:]]*(PASS|WARN|BLOCK).*/\1/p' \
    | head -1
)"

if [ -z "$verdict" ]; then
  echo "status=blocked reason=design-readiness-verdict-missing"
  echo "risk_triggers=${triggers}"
  echo "required_reviewers=${reviewers}"
  exit 1
fi

missing=""
IFS=',' read -r -a required_array <<< "$reviewers"
for required in "${required_array[@]}"; do
  if [ -n "$required" ] && ! contains_item "$declared_reviewers" "$required"; then
    missing="$(append_unique "$missing" "$required")"
  fi
done

if [ -n "$missing" ]; then
  echo "status=blocked reason=design-readiness-reviewer-missing missing=${missing}"
  echo "risk_triggers=${triggers}"
  echo "required_reviewers=${reviewers}"
  echo "declared_reviewers=${declared_reviewers}"
  exit 1
fi

echo "risk_triggers=${triggers}"
echo "required_reviewers=${reviewers}"
echo "declared_reviewers=${declared_reviewers}"

case "$verdict" in
  PASS)
    echo "status=pass verdict=PASS"
    exit 0
    ;;
  WARN)
    echo "status=warn verdict=WARN"
    exit 0
    ;;
  BLOCK)
    echo "status=blocked reason=design-readiness-verdict-block"
    exit 1
    ;;
esac
