#!/usr/bin/env bash
# registry-resolve.sh — Domain registry lookup + M1-M5 graceful-degradation surface
# Part of ship-flow #113.2 domain-registry-skill
#
# Flags:
#   --help                            Print usage
#   --list                            List all domain names from config
#   --classify <spec-file>            Match spec file against trigger patterns/keywords
#   --domain=<name>                   Look up a specific domain entry (print envelope)
#   --validate                        Validate entire config (M4+M5 checks) + optional --domain check
#   --config=<path>                   Override plugin default config path
#   --adopter-config=<path>           Override adopter project config path
#
# Exit codes:
#   0  = ok or partial_coverage (consumer interprets status= field)
#   2  = usage error
#   10 = M1 specialist_missing (designer_section_anchor empty or not found)
#   11 = M2 knowledge_module_missing (knowledge_module file not on disk)
#   20 = M4 parse_error (config YAML malformed)
#   21 = M5 invalid_trigger_config (domain has empty trigger_patterns AND spec_keywords)
#   1  = generic error
#
# Output envelope (stdout, key=value lines):
#   status=ok|partial_coverage|specialist_missing|knowledge_module_missing|parse_error|invalid_trigger_config
#   matched=<domain1>,<domain2>,...
#   missing=<domain1>,<domain2>,...
#   knowledge_module_path=<path>
#   designer_section_anchor=<anchor>

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

# Default config paths
DEFAULT_CONFIG="${PLUGIN_ROOT}/registry/defaults.yaml"
DEFAULT_ADOPTER_CONFIG=""

# Flags
MODE=""
SPEC_FILE=""
DOMAIN_NAME=""
CONFIG_PATH=""
ADOPTER_CONFIG_PATH=""

usage() {
  cat <<'EOF'
registry-resolve — Domain registry lookup + M1-M5 graceful-degradation surface

Usage:
  registry-resolve.sh --help
  registry-resolve.sh --list [--config=<path>] [--adopter-config=<path>]
  registry-resolve.sh --classify <spec-file> [--config=<path>] [--adopter-config=<path>]
  registry-resolve.sh --domain=<name> [--config=<path>] [--adopter-config=<path>]
  registry-resolve.sh --validate [--domain=<name>] [--config=<path>] [--adopter-config=<path>]

Exit codes: 0=ok/partial_coverage, 2=usage, 10=M1, 11=M2, 20=M4, 21=M5, 1=error
EOF
}

die_usage() {
  echo "ERROR: $*" >&2
  usage >&2
  exit 2
}

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --list)
      MODE="list"
      ;;
    --classify)
      MODE="classify"
      shift
      [ $# -eq 0 ] && die_usage "--classify requires <spec-file>"
      SPEC_FILE="$1"
      ;;
    --domain=*)
      DOMAIN_NAME="${1#--domain=}"
      [ -z "$MODE" ] && MODE="domain"
      ;;
    --validate)
      MODE="validate"
      ;;
    --config=*)
      CONFIG_PATH="${1#--config=}"
      ;;
    --adopter-config=*)
      ADOPTER_CONFIG_PATH="${1#--adopter-config=}"
      ;;
    *)
      die_usage "unknown argument: $1"
      ;;
  esac
  shift
done

[ -z "$MODE" ] && die_usage "no mode specified (use --list, --classify, --domain=, or --validate)"

# Resolve effective config: adopter > plugin default
resolve_config() {
  local plugin_cfg="${CONFIG_PATH:-$DEFAULT_CONFIG}"
  local adopter_cfg="${ADOPTER_CONFIG_PATH:-$DEFAULT_ADOPTER_CONFIG}"
  echo "$plugin_cfg" "$adopter_cfg"
}

# validate_yaml_structure: check for obvious YAML parse issues using awk
# Returns 0 if structure looks valid, 1 if malformed
validate_yaml_structure() {
  local cfg="$1"
  # Check unclosed bracket: a line with '[' but no matching ']'
  if awk '/\[/{open++} /\]/{if(open>0) open--} END{exit (open>0)}' "$cfg" 2>/dev/null; then
    : # valid
  else
    return 1
  fi
  # Check that schema_version and domains keys are present
  if ! grep -q "^schema_version:" "$cfg" 2>/dev/null; then
    return 1
  fi
  if ! grep -q "^domains:" "$cfg" 2>/dev/null; then
    return 1
  fi
  return 0
}

# parse_domain_names: extract top-level domain names from a YAML file
# Reads lines indented exactly 2 spaces under 'domains:' block
# Uses POSIX awk (no 3-arg match) for macOS compatibility
parse_domain_names() {
  local cfg="$1"
  awk '
    /^domains:/ { in_domains=1; next }
    in_domains && /^  [a-zA-Z_][a-zA-Z0-9_-]*:/ {
      line = $0
      sub(/^  /, "", line)
      sub(/:.*/, "", line)
      if (line != "") print line
    }
    in_domains && /^[^ ]/ && !/^domains:/ { in_domains=0 }
  ' "$cfg"
}

# get_domain_field: extract a field value for a specific domain
get_domain_field() {
  local cfg="$1"
  local domain="$2"
  local field="$3"
  awk -v dom="$domain" -v fld="$field" '
    /^domains:/ { in_domains=1; next }
    in_domains && $0 ~ ("^  " dom ":") { in_domain=1; next }
    in_domain && $0 ~ ("^    " fld ":") {
      sub(/^    [^:]+:[[:space:]]*/, "")
      # Strip surrounding quotes if present
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      exit
    }
    in_domain && /^  [a-zA-Z]/ && $0 !~ ("^  " dom ":") { in_domain=0 }
    in_domains && /^[^ ]/ && !/^domains:/ { in_domains=0 }
  ' "$cfg"
}

# get_spec_keywords: extract spec_keywords list for a domain
get_spec_keywords() {
  local cfg="$1"
  local domain="$2"
  awk -v dom="$domain" '
    /^domains:/ { in_domains=1; next }
    in_domains && $0 ~ ("^  " dom ":") { in_domain=1; next }
    in_domain && /^    spec_keywords:/ { in_kw=1; next }
    in_kw && /^      - / {
      sub(/^      - /, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
    }
    in_kw && !/^      / { in_kw=0 }
    in_domain && /^  [a-zA-Z]/ && $0 !~ ("^  " dom ":") { in_domain=0; in_kw=0 }
    in_domains && /^[^ ]/ && !/^domains:/ { in_domains=0 }
  ' "$cfg"
}

# get_trigger_patterns: extract trigger_patterns list for a domain
get_trigger_patterns() {
  local cfg="$1"
  local domain="$2"
  awk -v dom="$domain" '
    /^domains:/ { in_domains=1; next }
    in_domains && $0 ~ ("^  " dom ":") { in_domain=1; next }
    in_domain && /^    trigger_patterns:/ {
      in_tp=1
      # Check inline value on same line: trigger_patterns: []
      if (/\[\]/) { in_tp=0 }
      next
    }
    in_tp && /^      - / {
      sub(/^      - /, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
    }
    in_tp && !/^      / { in_tp=0 }
    in_domain && /^  [a-zA-Z]/ && $0 !~ ("^  " dom ":") { in_domain=0; in_tp=0 }
    in_domains && /^[^ ]/ && !/^domains:/ { in_domains=0 }
  ' "$cfg"
}

# merge_configs: given plugin + adopter configs, produce effective domain list
# Adopter entries fully replace plugin entries on key collision (full-replace, not merge)
# Returns: effective config as temp file path (caller must rm)
merge_configs() {
  local plugin_cfg="$1"
  local adopter_cfg="$2"

  if [ -z "$adopter_cfg" ] || [ ! -f "$adopter_cfg" ]; then
    echo "$plugin_cfg"
    return
  fi

  # Write merged YAML to temp file
  local tmp
  tmp="$(mktemp /tmp/registry-resolve-merged.XXXXXX.yaml)"

  # Get all domain names from both configs
  local plugin_domains adopter_domains all_domains
  plugin_domains="$(parse_domain_names "$plugin_cfg")"
  adopter_domains="$(parse_domain_names "$adopter_cfg")"

  # Start merged file
  echo 'schema_version: "1.0"' > "$tmp"
  echo 'domains:' >> "$tmp"

  # Collect unique domains (adopter wins on collision)
  all_domains="$(printf '%s\n%s\n' "$plugin_domains" "$adopter_domains" | sort -u)"

  while IFS= read -r dom; do
    [ -z "$dom" ] && continue
    # Check if adopter has this domain (full-replace)
    if echo "$adopter_domains" | grep -qxF "$dom"; then
      # Extract raw domain block from adopter
      awk -v dom="$dom" '
        /^domains:/ { in_domains=1; next }
        in_domains && $0 ~ ("^  " dom ":") { in_domain=1; print; next }
        in_domain && /^  [a-zA-Z]/ && $0 !~ ("^  " dom ":") { in_domain=0 }
        in_domain { print }
        in_domains && /^[^ ]/ && !/^domains:/ { in_domains=0 }
      ' "$adopter_cfg" >> "$tmp"
    else
      # Use plugin entry
      awk -v dom="$dom" '
        /^domains:/ { in_domains=1; next }
        in_domains && $0 ~ ("^  " dom ":") { in_domain=1; print; next }
        in_domain && /^  [a-zA-Z]/ && $0 !~ ("^  " dom ":") { in_domain=0 }
        in_domain { print }
        in_domains && /^[^ ]/ && !/^domains:/ { in_domains=0 }
      ' "$plugin_cfg" >> "$tmp"
    fi
  done <<< "$all_domains"

  echo "$tmp"
}

# check_m4_parse: validate YAML structure, emit M4 on failure
check_m4_parse() {
  local cfg="$1"
  if ! validate_yaml_structure "$cfg"; then
    echo "status=parse_error" >&2
    echo "config=$cfg" >&2
    exit 20
  fi
}

# check_m5_triggers: validate all domains have ≥1 trigger pattern or keyword
check_m5_triggers() {
  local cfg="$1"
  while IFS= read -r dom; do
    [ -z "$dom" ] && continue
    local kw_count tp_count
    kw_count="$(get_spec_keywords "$cfg" "$dom" | wc -l | tr -d ' ')"
    tp_count="$(get_trigger_patterns "$cfg" "$dom" | wc -l | tr -d ' ')"
    if [ "$kw_count" -eq 0 ] && [ "$tp_count" -eq 0 ]; then
      echo "status=invalid_trigger_config" >&2
      echo "domain=$dom" >&2
      echo "config=$cfg" >&2
      exit 21
    fi
  done < <(parse_domain_names "$cfg")
}

# check_m1_specialist: verify designer_section_anchor is non-empty
check_m1_specialist() {
  local cfg="$1"
  local dom="$2"
  local anchor
  anchor="$(get_domain_field "$cfg" "$dom" "designer_section_anchor")"
  if [ -z "$anchor" ]; then
    echo "status=specialist_missing" >&2
    echo "domain=$dom" >&2
    echo "options=skip,generalist-marker,file-specialist-first" >&2
    exit 10
  fi
}

# check_m2_knowledge: verify knowledge_module path exists on disk
check_m2_knowledge() {
  local cfg="$1"
  local dom="$2"
  local km_path
  km_path="$(get_domain_field "$cfg" "$dom" "knowledge_module")"
  # Resolve relative to PLUGIN_ROOT
  local abs_path="${PLUGIN_ROOT}/${km_path}"
  if [ -n "$km_path" ] && [ ! -f "$abs_path" ]; then
    echo "status=knowledge_module_missing" >&2
    echo "domain=$dom" >&2
    echo "missing_path=$km_path" >&2
    echo "options=skip,generalist-marker,file-specialist-first" >&2
    exit 11
  fi
}

# classify_spec: match spec file against all domains, return matched/missing lists
classify_spec() {
  local cfg="$1"
  local spec="$2"
  local spec_content
  spec_content="$(cat "$spec")"

  local matched_domains=()
  local missing_specialist=()

  while IFS= read -r dom; do
    [ -z "$dom" ] && continue
    local matched=false

    # Check spec_keywords (case-insensitive grep)
    while IFS= read -r kw; do
      [ -z "$kw" ] && continue
      if echo "$spec_content" | grep -qiF "$kw"; then
        matched=true
        break
      fi
    done < <(get_spec_keywords "$cfg" "$dom")

    # Check trigger_patterns (glob-style — simple fnmatch via find)
    if [ "$matched" = "false" ]; then
      while IFS= read -r pat; do
        [ -z "$pat" ] && continue
        # For spec classification, trigger_patterns match file paths in spec content
        if echo "$spec_content" | grep -qE "$pat"; then
          matched=true
          break
        fi
      done < <(get_trigger_patterns "$cfg" "$dom")
    fi

    if [ "$matched" = "true" ]; then
      local anchor
      anchor="$(get_domain_field "$cfg" "$dom" "designer_section_anchor")"
      if [ -z "$anchor" ]; then
        missing_specialist+=("$dom")
      else
        matched_domains+=("$dom")
      fi
    fi
  done < <(parse_domain_names "$cfg")

  local matched_str
  matched_str="$(IFS=','; echo "${matched_domains[*]-}")"
  local missing_str
  missing_str="$(IFS=','; echo "${missing_specialist[*]-}")"

  if [ ${#matched_domains[@]} -eq 0 ] && [ ${#missing_specialist[@]} -eq 0 ]; then
    echo "status=ok"
    echo "matched="
  elif [ ${#missing_specialist[@]} -gt 0 ] && [ ${#matched_domains[@]} -eq 0 ]; then
    # All matched domains are missing specialists → M1
    echo "status=specialist_missing" >&2
    echo "domain=${missing_str}" >&2
    echo "options=skip,generalist-marker,file-specialist-first" >&2
    exit 10
  elif [ ${#missing_specialist[@]} -gt 0 ]; then
    # Some matched, some missing → M3 partial_coverage
    echo "status=partial_coverage"
    echo "matched=${matched_str}"
    echo "missing=${missing_str}"
  else
    echo "status=ok"
    echo "matched=${matched_str}"
  fi
}

# --- Main dispatch ---

read -r PLUGIN_CFG_RAW ADOPTER_CFG_RAW <<< "$(resolve_config)"
PLUGIN_CFG="$PLUGIN_CFG_RAW"
ADOPTER_CFG="$ADOPTER_CFG_RAW"

# Validate plugin config exists
if [ ! -f "$PLUGIN_CFG" ]; then
  echo "status=parse_error" >&2
  echo "config_missing=$PLUGIN_CFG" >&2
  exit 20
fi

# M4 check on plugin config
check_m4_parse "$PLUGIN_CFG"

# Merge configs (adopter > plugin)
MERGED_CFG="$(merge_configs "$PLUGIN_CFG" "$ADOPTER_CFG")"
MERGED_IS_TMP=false
if [ "$MERGED_CFG" != "$PLUGIN_CFG" ]; then
  MERGED_IS_TMP=true
fi

cleanup() {
  if [ "$MERGED_IS_TMP" = "true" ] && [ -f "$MERGED_CFG" ]; then
    rm -f "$MERGED_CFG"
  fi
}
trap cleanup EXIT

case "$MODE" in
  list)
    parse_domain_names "$MERGED_CFG"
    ;;

  classify)
    [ ! -f "$SPEC_FILE" ] && { echo "ERROR: spec file not found: $SPEC_FILE" >&2; exit 2; }
    classify_spec "$MERGED_CFG" "$SPEC_FILE"
    ;;

  domain)
    [ -z "$DOMAIN_NAME" ] && die_usage "--domain= requires a name"
    local_anchor="$(get_domain_field "$MERGED_CFG" "$DOMAIN_NAME" "designer_section_anchor")"
    local_km="$(get_domain_field "$MERGED_CFG" "$DOMAIN_NAME" "knowledge_module")"
    if [ -z "$local_anchor" ] && [ -z "$local_km" ]; then
      echo "ERROR: domain '$DOMAIN_NAME' not found in config" >&2
      exit 1
    fi
    echo "status=ok"
    echo "domain=$DOMAIN_NAME"
    echo "designer_section_anchor=$local_anchor"
    echo "knowledge_module_path=$local_km"
    ;;

  validate)
    # M4 already checked above
    # M5: check all domains have ≥1 trigger
    check_m5_triggers "$MERGED_CFG"
    # If --domain given, also check M1 + M2
    if [ -n "$DOMAIN_NAME" ]; then
      check_m1_specialist "$MERGED_CFG" "$DOMAIN_NAME"
      check_m2_knowledge "$MERGED_CFG" "$DOMAIN_NAME"
    fi
    echo "status=ok"
    ;;
esac
