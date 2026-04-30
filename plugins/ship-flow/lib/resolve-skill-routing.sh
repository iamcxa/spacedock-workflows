#!/usr/bin/env bash
# resolve-skill-routing.sh — resolve adopter skill-routing.yaml against task files

set -euo pipefail

CONFIG=".claude/ship-flow/skill-routing.yaml"
FILES=""

usage() {
  cat <<'EOF'
resolve-skill-routing — resolve adopter skill-routing.yaml against task files

Usage:
  resolve-skill-routing.sh --files=<comma-separated-paths> [--config=<path>]

Output:
  status=ok|no_match
  matched_routes=<route1>,<route2>,...
  skills_needed=<skill1>,<skill2>,...

Exit codes:
  0  ok/no_match
  2  usage error
  11 config missing
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --config=*)
      CONFIG="${1#--config=}"
      ;;
    --files=*)
      FILES="${1#--files=}"
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

[ -n "$FILES" ] || {
  echo "ERROR: --files is required" >&2
  usage >&2
  exit 2
}

[ -f "$CONFIG" ] || {
  echo "status=config_missing" >&2
  echo "config=$CONFIG" >&2
  exit 11
}

glob_to_regex() {
  local glob="$1"
  local token="__DOUBLE_STAR__"
  local brace_token="__BRACE_GROUP__"
  local brace_group=""

  glob="${glob//\*\*/$token}"
  if printf '%s' "$glob" | grep -qE '\{[^}]+\}'; then
    brace_group=$(printf '%s' "$glob" | sed -n 's/.*{\([^}]*\)}.*/\1/p' | sed 's/[;,]/|/g')
    glob=$(printf '%s' "$glob" | sed 's/{[^}]*}/__BRACE_GROUP__/')
  fi
  glob=$(printf '%s' "$glob" | sed 's/[.[\^$()+?|]/\\&/g')
  glob="${glob//\*/[^\/]*}"
  glob="${glob//$token/.*}"
  if [ -n "$brace_group" ]; then
    glob="${glob//$brace_token/($brace_group)}"
  fi
  printf '^%s$' "$glob"
}

route_matches() {
  local signals_csv="$1"
  local files_csv="$2"
  local old_ifs="$IFS"
  local signal
  local file
  local regex

  # Protect glob brace syntax that can contain commas before CSV splitting.
  signals_csv=$(printf '%s' "$signals_csv" | awk '
    {
      out = ""
      in_brace = 0
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") in_brace = 1
        if (c == "}") in_brace = 0
        if (c == "," && in_brace) c = ";"
        out = out c
      }
      print out
    }
  ')

  IFS=','
  for signal in $signals_csv; do
    signal="$(printf '%s' "$signal" | sed 's/^ *//; s/ *$//')"
    [ -n "$signal" ] || continue
    regex="$(glob_to_regex "$signal")"
    for file in $files_csv; do
      file="$(printf '%s' "$file" | sed 's/^ *//; s/ *$//')"
      [ -n "$file" ] || continue
      if printf '%s\n' "$file" | grep -Eq "$regex"; then
        IFS="$old_ifs"
        return 0
      fi
    done
  done
  IFS="$old_ifs"
  return 1
}

add_unique_csv_items() {
  local csv="$1"
  local item
  local old_ifs="$IFS"

  IFS=','
  for item in $csv; do
    item="$(printf '%s' "$item" | sed 's/^ *//; s/ *$//')"
    [ -n "$item" ] || continue
    if ! printf '%s\n' "$SEEN_ITEMS" | grep -qx "$item"; then
      SEEN_ITEMS="${SEEN_ITEMS}${item}
"
      if [ -n "$OUT_CSV" ]; then
        OUT_CSV="${OUT_CSV},${item}"
      else
        OUT_CSV="$item"
      fi
    fi
  done
  IFS="$old_ifs"
}

MATCHED_ROUTES=""
SKILLS_CSV=""
SEEN_ITEMS=""
OUT_CSV=""

current_name=""
current_signals=""
current_skills=""

flush_route() {
  [ -n "$current_name" ] || return 0
  [ -n "$current_signals" ] || return 0
  [ -n "$current_skills" ] || return 0

  if route_matches "$current_signals" "$FILES"; then
    if [ -n "$MATCHED_ROUTES" ]; then
      MATCHED_ROUTES="${MATCHED_ROUTES},${current_name}"
    else
      MATCHED_ROUTES="$current_name"
    fi
    OUT_CSV="$SKILLS_CSV"
    add_unique_csv_items "$current_skills"
    SKILLS_CSV="$OUT_CSV"
  fi
}

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    "  - name: "*)
      flush_route
      current_name="${line#  - name: }"
      current_signals=""
      current_skills=""
      ;;
    "    signals: ["*"]")
      current_signals="${line#    signals: [}"
      current_signals="${current_signals%]}"
      ;;
    "    skills: ["*"]")
      current_skills="${line#    skills: [}"
      current_skills="${current_skills%]}"
      ;;
  esac
done < "$CONFIG"
flush_route

if [ -n "$MATCHED_ROUTES" ]; then
  echo "status=ok"
else
  echo "status=no_match"
fi
echo "matched_routes=$MATCHED_ROUTES"
echo "skills_needed=$SKILLS_CSV"
