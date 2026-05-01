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
  folder_guidance_files=<non-root AGENTS.md/CLAUDE.md files>
  folder_guidance_skills=<skills parsed from folder guidance>
  codex_context_boundary=root AGENTS.md/CLAUDE.md intentionally excluded from folder_guidance_files

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

  while IFS= read -r signal; do
    signal="$(printf '%s' "$signal" | sed 's/^ *//; s/ *$//')"
    [ -n "$signal" ] || continue
    regex="$(glob_to_regex "$signal")"
    while IFS= read -r file; do
      file="$(printf '%s' "$file" | sed 's/^ *//; s/ *$//')"
      [ -n "$file" ] || continue
      if printf '%s\n' "$file" | grep -Eq "$regex"; then
        IFS="$old_ifs"
        return 0
      fi
    done <<< "$(printf '%s' "$files_csv" | tr ',' '\n')"
  done <<< "$(printf '%s' "$signals_csv" | tr ',' '\n')"
  IFS="$old_ifs"
  return 1
}

add_unique_csv_items() {
  local csv="$1"
  local item
  local old_ifs="$IFS"

  while IFS= read -r item; do
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
  done <<< "$(printf '%s' "$csv" | tr ',' '\n')"
  IFS="$old_ifs"
}

MATCHED_ROUTES=""
SKILLS_CSV=""
SEEN_ITEMS=""
OUT_CSV=""
GUIDANCE_FILES_CSV=""
GUIDANCE_FILE_SEEN=""
GUIDANCE_SKILLS_CSV=""
GUIDANCE_SKILL_SEEN=""

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

add_guidance_file() {
  local file="$1"
  [ -n "$file" ] || return 0
  if ! printf '%s\n' "$GUIDANCE_FILE_SEEN" | grep -qx "$file"; then
    GUIDANCE_FILE_SEEN="${GUIDANCE_FILE_SEEN}${file}
"
    if [ -n "$GUIDANCE_FILES_CSV" ]; then
      GUIDANCE_FILES_CSV="${GUIDANCE_FILES_CSV},${file}"
    else
      GUIDANCE_FILES_CSV="$file"
    fi
  fi
}

add_guidance_skill() {
  local skill="$1"
  skill="$(printf '%s' "$skill" | sed 's/^ *//; s/ *$//')"
  [ -n "$skill" ] || return 0
  if ! printf '%s\n' "$GUIDANCE_SKILL_SEEN" | grep -qx "$skill"; then
    GUIDANCE_SKILL_SEEN="${GUIDANCE_SKILL_SEEN}${skill}
"
    if [ -n "$GUIDANCE_SKILLS_CSV" ]; then
      GUIDANCE_SKILLS_CSV="${GUIDANCE_SKILLS_CSV},${skill}"
    else
      GUIDANCE_SKILLS_CSV="$skill"
    fi
  fi
}

extract_guidance_skills() {
  local guidance_file="$1"
  local line
  local skill

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *Skills*|*Skill:*)
        while IFS= read -r skill; do
          add_guidance_skill "$skill"
        done <<< "$(printf '%s\n' "$line" | grep -Eo '`[A-Za-z0-9_.:-]+`' | tr -d '`')"
        while IFS= read -r skill; do
          add_guidance_skill "$skill"
        done <<< "$(printf '%s\n' "$line" | sed -n 's/.*Skill:[[:space:]]*"\([^"]*\)".*/\1/p')"
        ;;
    esac
  done < "$guidance_file"
}

discover_folder_guidance() {
  local files_csv="$1"
  local file
  local dir
  local candidate
  local guidance_name

  while IFS= read -r file; do
    file="$(printf '%s' "$file" | sed 's/^ *//; s/ *$//')"
    [ -n "$file" ] || continue
    dir="$(dirname "$file")"
    while [ "$dir" != "." ] && [ "$dir" != "/" ] && [ -n "$dir" ]; do
      for guidance_name in AGENTS.md CLAUDE.md; do
        candidate="${dir}/${guidance_name}"
        if [ -f "$candidate" ]; then
          add_guidance_file "$candidate"
          extract_guidance_skills "$candidate"
        fi
      done
      next_dir="$(dirname "$dir")"
      [ "$next_dir" = "$dir" ] && break
      dir="$next_dir"
    done
  done <<< "$(printf '%s' "$files_csv" | tr ',' '\n')"
}

discover_folder_guidance "$FILES"

if [ -n "$MATCHED_ROUTES" ]; then
  echo "status=ok"
else
  echo "status=no_match"
fi
echo "matched_routes=$MATCHED_ROUTES"
echo "skills_needed=$SKILLS_CSV"
echo "folder_guidance_files=$GUIDANCE_FILES_CSV"
echo "folder_guidance_skills=$GUIDANCE_SKILLS_CSV"
echo "codex_context_boundary=root AGENTS.md/CLAUDE.md intentionally excluded from folder_guidance_files"
