#!/usr/bin/env bash
# query-entity-history.sh — report median elapsed duration for shipped archive entities.
set -euo pipefail

WORKFLOW_DIR=""
SIZE_FILTER=""
APPETITE_FILTER=""
DOMAIN_FILTER=""
LIMIT=""

usage() {
  cat <<'EOF'
Usage:
  query-entity-history.sh --workflow-dir <docs/ship-flow> [--size S|M|L] [--appetite small-batch|medium-batch|big-batch] [--domain <name>] [--limit N]
  query-entity-history.sh --help

Reads folder archive records at <workflow-dir>/_archive/*/index.md, filters by
size/appetite and optional domain, and prints the median elapsed wall-clock
duration from started to completed. Even-count medians use integer average.
Malformed or incomplete timestamps are skipped with warnings.
EOF
}

strip_value() {
  local value="$1"
  value="${value%%#*}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  case "$value" in
    \"*\") value="${value#\"}"; value="${value%\"}" ;;
    \'*\') value="${value#\'}"; value="${value%\'}" ;;
  esac
  printf '%s\n' "$value"
}

frontmatter_value() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { exit }
    in_fm {
      split($0, parts, ":")
      if (parts[1] == key) {
        sub("^[^:]*:[[:space:]]*", "", $0)
        print
        exit
      }
    }
  ' "$file" | sed -n '1p' | while IFS= read -r value; do strip_value "$value"; done
}

parse_epoch() {
  local value="$1"
  [ -n "$value" ] || return 1

  case "$value" in
    ????-??-??T??:??:??Z)
      if date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$value" "+%s" >/dev/null 2>&1; then
        date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$value" "+%s"
        return 0
      fi
      ;;
    ????-??-??)
      if date -u -j -f "%Y-%m-%d" "$value" "+%s" >/dev/null 2>&1; then
        date -u -j -f "%Y-%m-%d" "$value" "+%s"
        return 0
      fi
      ;;
  esac

  if [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$ ]]; then
    local compact_offset
    compact_offset="$(printf '%s\n' "$value" | sed -E 's/([+-][0-9]{2}):([0-9]{2})$/\1\2/')"
    if date -u -j -f "%Y-%m-%dT%H:%M:%S%z" "$compact_offset" "+%s" >/dev/null 2>&1; then
      date -u -j -f "%Y-%m-%dT%H:%M:%S%z" "$compact_offset" "+%s"
      return 0
    fi
  fi

  if date -u -d "$value" "+%s" >/dev/null 2>&1; then
    date -u -d "$value" "+%s"
    return 0
  fi

  return 1
}

human_duration() {
  local seconds="$1"
  local days hours minutes remainder
  days=$((seconds / 86400))
  remainder=$((seconds % 86400))
  hours=$((remainder / 3600))
  minutes=$(((remainder % 3600) / 60))

  if [ "$days" -gt 0 ]; then
    printf '%dd %dh %dm\n' "$days" "$hours" "$minutes"
  else
    printf '%dh %dm\n' "$hours" "$minutes"
  fi
}

validate_number() {
  local value="$1" label="$2"
  case "$value" in
    ''|*[!0-9]*)
      echo "Error: ${label} must be a positive integer" >&2
      exit 2
      ;;
    0)
      echo "Error: ${label} must be greater than 0" >&2
      exit 2
      ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --workflow-dir)
      WORKFLOW_DIR="${2:-}"
      shift 2
      ;;
    --workflow-dir=*)
      WORKFLOW_DIR="${1#--workflow-dir=}"
      shift
      ;;
    --size)
      SIZE_FILTER="${2:-}"
      shift 2
      ;;
    --size=*)
      SIZE_FILTER="${1#--size=}"
      shift
      ;;
    --appetite)
      APPETITE_FILTER="${2:-}"
      shift 2
      ;;
    --appetite=*)
      APPETITE_FILTER="${1#--appetite=}"
      shift
      ;;
    --domain)
      DOMAIN_FILTER="${2:-}"
      shift 2
      ;;
    --domain=*)
      DOMAIN_FILTER="${1#--domain=}"
      shift
      ;;
    --limit)
      LIMIT="${2:-}"
      shift 2
      ;;
    --limit=*)
      LIMIT="${1#--limit=}"
      shift
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$WORKFLOW_DIR" ]; then
  echo "Error: --workflow-dir is required" >&2
  usage >&2
  exit 2
fi

if [ -n "$LIMIT" ]; then
  validate_number "$LIMIT" "--limit"
fi

ARCHIVE_DIR="${WORKFLOW_DIR%/}/_archive"
if [ ! -d "$ARCHIVE_DIR" ]; then
  echo "Error: archive directory not found: $ARCHIVE_DIR" >&2
  exit 2
fi

RECORDS_FILE="$(mktemp "${TMPDIR:-/tmp}/query-entity-history.records.XXXXXX")"
cleanup() {
  rm -f "$RECORDS_FILE"
}
trap cleanup EXIT

while IFS= read -r file; do
  size="$(frontmatter_value "$file" size)"
  appetite="$(frontmatter_value "$file" appetite)"
  domain="$(frontmatter_value "$file" domain)"
  started="$(frontmatter_value "$file" started)"
  completed="$(frontmatter_value "$file" completed)"

  if [ -n "$SIZE_FILTER" ] && [ "$size" != "$SIZE_FILTER" ]; then
    continue
  fi
  if [ -n "$APPETITE_FILTER" ] && [ "$appetite" != "$APPETITE_FILTER" ]; then
    continue
  fi
  if [ -n "$DOMAIN_FILTER" ] && [ "$domain" != "$DOMAIN_FILTER" ]; then
    continue
  fi

  if [ -z "$started" ] || [ -z "$completed" ]; then
    echo "warning=skipped_incomplete:${file}" >&2
    continue
  fi

  if ! started_epoch="$(parse_epoch "$started")"; then
    echo "warning=skipped_malformed:${file}:started=${started}" >&2
    continue
  fi
  if ! completed_epoch="$(parse_epoch "$completed")"; then
    echo "warning=skipped_malformed:${file}:completed=${completed}" >&2
    continue
  fi

  duration=$((completed_epoch - started_epoch))
  if [ "$duration" -lt 0 ]; then
    echo "warning=skipped_malformed:${file}:negative_duration" >&2
    continue
  fi

  printf '%s\t%s\t%s\n' "$completed_epoch" "$duration" "$file" >> "$RECORDS_FILE"
done < <(
  find "$ARCHIVE_DIR" -mindepth 2 -maxdepth 2 -type f -name 'index.md' -print | sort
)

if [ ! -s "$RECORDS_FILE" ]; then
  printf 'workflow_dir=%s\n' "$WORKFLOW_DIR"
  printf 'selector=size:%s,appetite:%s,domain:%s\n' "$SIZE_FILTER" "$APPETITE_FILTER" "$DOMAIN_FILTER"
  printf 'matched_count=0\n'
  exit 3
fi

SELECTED_DURATIONS="$(mktemp "${TMPDIR:-/tmp}/query-entity-history.durations.XXXXXX")"
cleanup_all() {
  rm -f "$RECORDS_FILE" "$SELECTED_DURATIONS"
}
trap cleanup_all EXIT

if [ -n "$LIMIT" ]; then
  sort -rn "$RECORDS_FILE" | head -n "$LIMIT" | awk '{ print $2 }' > "$SELECTED_DURATIONS"
else
  awk '{ print $2 }' "$RECORDS_FILE" > "$SELECTED_DURATIONS"
fi

MATCHED_COUNT="$(wc -l < "$SELECTED_DURATIONS" | tr -d '[:space:]')"
SORTED_DURATIONS="$(sort -n "$SELECTED_DURATIONS")"

MEDIAN_SECONDS="$(
  printf '%s\n' "$SORTED_DURATIONS" | awk -v count="$MATCHED_COUNT" '
    { values[NR] = $1 }
    END {
      if (count % 2 == 1) {
        print values[(count + 1) / 2]
      } else {
        left = values[count / 2]
        right = values[(count / 2) + 1]
        print int((left + right) / 2)
      }
    }
  '
)"

printf 'workflow_dir=%s\n' "$WORKFLOW_DIR"
printf 'selector=size:%s,appetite:%s,domain:%s\n' "$SIZE_FILTER" "$APPETITE_FILTER" "$DOMAIN_FILTER"
printf 'matched_count=%s\n' "$MATCHED_COUNT"
printf 'median_seconds=%s\n' "$MEDIAN_SECONDS"
printf 'median_human=%s\n' "$(human_duration "$MEDIAN_SECONDS")"
