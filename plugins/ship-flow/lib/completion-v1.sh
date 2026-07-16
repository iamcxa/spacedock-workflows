#!/usr/bin/env bash
completion_error() { echo "completion-v1[$1]: $2" >&2; return "$1"; }
completion_capture() {
  local name="$1" value rc
  shift
  value="$("$@")"; rc=$?
  [ "$rc" = 0 ] || return "$rc"
  printf -v "$name" '%s' "$value"
}
completion_sha256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
completion_ascii() { local LC_ALL=C; case "$1" in ''|*[![:print:]]*) return 1 ;; *) return 0 ;; esac; }
completion_path_ok() {
  local path="$1" part
  local -a parts
  completion_ascii "$path" || return 1
  case "$path" in /*|*//*|*\\*|*:*) return 1 ;; esac; case "$path" in [A-Za-z0-9]*/*/index.md) ;; *) return 1 ;; esac
  IFS=/ read -r -a parts <<< "$path"
  for part in "${parts[@]}"; do
    case "$part" in ''|.|..|*.lock) return 1 ;; esac
    LC_ALL=C printf '%s' "$part" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' || return 1
  done
}
completion_ref_ok() {
  local ref="$1" rest part old_ifs; completion_ascii "$ref" || return 1
  case "$ref" in refs/heads/*) ;; *) return 1 ;; esac; git check-ref-format "$ref" >/dev/null 2>&1 || return 1
  rest="${ref#refs/heads/}"; old_ifs="$IFS"; IFS=/
  # shellcheck disable=SC2086 # intentional slash-delimited component validation
  set -- $rest; IFS="$old_ifs"
  for part in "$@"; do
    case "$part" in ''|.|..|.*|*.|*.lock) return 1 ;; esac
    LC_ALL=C printf '%s' "$part" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' || return 1
  done
}
completion_oid_ok() {
  local oid="$1" format="$2"
  case "$format" in sha1) LC_ALL=C printf '%s' "$oid" | grep -Eq '^[0-9a-f]{40}$' ;; sha256) LC_ALL=C printf '%s' "$oid" | grep -Eq '^[0-9a-f]{64}$' ;; *) return 1 ;; esac
}
completion_text_ok() {
  local file="$1"
  iconv -f UTF-8 -t UTF-8 "$file" >/dev/null 2>&1 || return 1
  od -An -v -t u1 "$file" | awk '
    { for (i=1; i<=NF; i++) if ($i==0 || $i==13 || ($i<32 && $i!=9 && $i!=10) || $i==127) exit 1 }
  '
}
completion_contract_ok() { case "$1/$2/$3" in design/design/design.md|plan/plan/plan.md|execute/execute/execute.md|verify/verify/verify.md|ship/review/review.md|ship/ship/ship.md) return 0 ;; *) return 1 ;; esac; }
completion_classification_ok() {
  LC_ALL=C awk '
    NR==1 { if ($0!="---") bad=1; next }
    /^status: [a-z][a-z0-9-]*$/ { tail=1; exit }
    /^$/ || /^#/ || /^[ \t]/ { next }
    {
      line=$0
      if (line !~ /^[a-z][a-z0-9_-]*:/) { bad=1; exit }
      key=line; sub(/:.*/,"",key); value=line; sub(/^[^:]*:/,"",value)
      if (key=="entity_type") {
        entity_types++; if (value==" epic") container=1; else if (value!=" entity") bad=1
      } else if (key=="pattern") {
        patterns++; if (value==" epic") container=1
        else if (value!=" single" && value!=" pitch" && value!=" shaped-child") bad=1
      }
      if (bad) exit
    }
    END { exit(bad || !tail || entity_types>1 || patterns>1 || container ? 1 : 0) }
  ' "$1"
}
completion_lease_matches() {
  local file="$1" state="$2" token="$3" entity="$4" stage="$5" worker="$6" ref="$7" before="$8" expected rc; [ -f "$file" ] && [ ! -L "$file" ] || return 1
  expected="$(mktemp)" || return 1
  printf 'completion-v1-lease\nstate=%s\ntoken=%s\nentity=%s\nstage=%s\nworker=%s\nref=%s\nbefore=%s\n' \
    "$state" "$token" "$entity" "$stage" "$worker" "$ref" "$before" > "$expected"
  cmp -s "$expected" "$file"; rc=$?
  rm -f "$expected"
  return "$rc"
}
completion_document() {
  local mode="$1" source="$2" expected="$3" target="$4" target_file="$5" final_byte
  final_byte="$(LC_ALL=C tail -c 1 "$source" | od -An -t u1 | tr -d ' ')"
  awk -v mode="$mode" -v expected="$expected" -v target="$target" -v target_file="$target_file" -v final_byte="$final_byte" '
    function rank(s) {
      if (s=="shape") return 1
      if (s=="design") return 2
      if (s=="plan") return 3
      if (s=="execute") return 4
      if (s=="verify") return 5
      if (s=="review") return 6
      if (s=="ship") return 7
      return 0
    }
    function canonical(s, f) {
      return (s=="shape" && f=="shape.md") || (s=="design" && f=="design.md") ||
             (s=="plan" && f=="plan.md") || (s=="execute" && f=="execute.md") ||
             (s=="verify" && f=="verify.md") || (s=="review" && f=="review.md") ||
             (s=="ship" && f=="ship.md")
    }
    function emit(text, newline) { printf "%s", text; if (newline) printf "%s", ORS }
    { lines[NR]=$0 }
    END {
      if (NR<4 || lines[1]!="---") bad=1
      for (i=2; i<=NR; i++) if (lines[i]=="---") { fmclose=i; break }
      if (!fmclose) bad=1
      for (i=2; i<fmclose; i++) {
        line=lines[i]
        if (line ~ /^status:/) {
          statuses++; statusline=i; status=line; sub(/^status: /,"",status)
          if (line !~ /^status: [a-z][a-z0-9-]*$/) bad=1
        }
        if (line ~ /^stage_outputs:/) { maps++; mapstart=i }
      }
      if (statuses!=1 || maps!=1 || mapstart!=statusline+1) bad=1
      if (lines[mapstart]=="stage_outputs: {}") {
        empty=1
        if (mapstart!=fmclose-1) bad=1
      } else if (lines[mapstart]=="stage_outputs:") {
        previous=0
        for (i=mapstart+1; i<fmclose; i++) {
          entry=lines[i]
          if (entry !~ /^  [a-z]+: [a-z]+\.md$/) { bad=1; continue }
          sub(/^  /,"",entry); split(entry,a,": ")
          current=rank(a[1])
          if (!canonical(a[1],a[2]) || !current || current<=previous || map[a[1]]!="") bad=1
          map[a[1]]=a[2]; previous=current
        }
        if (fmclose==mapstart+1) bad=1
      } else bad=1
      if (expected!="" && status!=expected) bad=1
      mt=(map[target]==target_file)
      if (!canonical(target,target_file)) bad=1
      if (bad) exit 1
      if (mode=="parse") { print mt ? "PRESENT" : "ABSENT"; exit }
      if (mode!="render") exit 1
      for (i=1; i<=NR; i++) {
        if (!mt && empty && i==mapstart) {
          emit("stage_outputs:",1); emit("  " target ": " target_file, i<NR || final_byte=="10")
          continue
        }
        if (!mt && !inserted && !empty && i>mapstart && i<fmclose && lines[i] ~ /^  [a-z]+:/) {
          stage=lines[i]; sub(/^  /,"",stage); sub(/:.*/,"",stage)
          if (rank(stage)>rank(target)) { emit("  " target ": " target_file,1); inserted=1 }
        }
        if (!mt && !inserted && !empty && i==fmclose) { emit("  " target ": " target_file,1); inserted=1 }
        emit(lines[i], i<NR || final_byte=="10")
      }
    }
  ' "$source"
}
completion_parse_entity() {
  local file="$1"
  completion_text_ok "$file" && completion_document parse "$file" "$2" "$3" "$4"
}
completion_render() {
  completion_text_ok "$1" && completion_document render "$1" '' "$2" "$3" > "$4"
}
completion_eligible_at_rev() {
  local rev="$1" entity="$2" status="$3" stage="$4" file="$5" workflow entity_tmp readme_tmp rc=1
  completion_contract_ok "$status" "$stage" "$file" || return 1
  case "$entity" in docs/*/_archive/*/index.md) return 1 ;; esac
  case "$entity" in docs/*/*/index.md) workflow="${entity#docs/}"; workflow="${workflow%%/*}" ;; *) return 1 ;; esac
  entity_tmp="$(mktemp)" || return 1
  readme_tmp="$(mktemp)" || { rm -f "$entity_tmp"; return 1; }
  if completion_tree_entity "$rev" "$entity" "$entity_tmp" &&
     completion_parse_entity "$entity_tmp" "$status" "$stage" "$file" >/dev/null &&
     completion_classification_ok "$entity_tmp" &&
     git show "$rev:docs/$workflow/README.md" > "$readme_tmp" 2>/dev/null &&
     awk -v expected="$status" '
       BEGIN { fm=0; in_stages=0; in_states=0; found=0 }
       /^---[[:space:]]*$/ { fm++; if (fm>=2) exit; next }
       fm!=1 { next }
       /^stages:[[:space:]]*$/ { in_stages=1; in_states=0; next }
       in_stages && /^[^[:space:]#][^:]*:[[:space:]]*/ { in_stages=0; in_states=0; next }
       !in_stages { next }
       /^  states:[[:space:]]*$/ { in_states=1; next }
       in_states && /^  [^[:space:]#][^:]*:[[:space:]]*/ { in_states=0; next }
       in_states && /^    - name:[[:space:]]*/ {
         state=$0; sub(/^    - name:[[:space:]]*/, "", state)
         sub(/[[:space:]\r]+$/, "", state); gsub(/^["\047]|["\047]$/, "", state)
         if (state==expected) found=1
       }
       END { exit(found ? 0 : 1) }
     ' "$readme_tmp"; then
    rc=0
  fi
  rm -f "$entity_tmp" "$readme_tmp"
  return "$rc"
}
completion_path_snapshot() {
  local rev="$1" path="$2" line mode type oid index_line index_mode index_oid work_mode work_oid
  line="$(git ls-tree "$rev" -- "$path")" || return 1
  [ "$(printf '%s\n' "$line" | awk 'NF{n++} END{print n+0}')" = 1 ] || return 1
  mode="${line%% *}"; line="${line#* }"; type="${line%% *}"; line="${line#* }"; oid="${line%%$'\t'*}"
  case "$mode/$type" in 100644/blob|100755/blob) ;; *) return 1 ;; esac
  index_line="$(git ls-files -s -- "$path")" || return 1
  [ "$(printf '%s\n' "$index_line" | awk 'NF{n++} END{print n+0}')" = 1 ] || return 1
  index_mode="${index_line%% *}"; index_line="${index_line#* }"; index_oid="${index_line%% *}"
  [ "$index_mode" = "$mode" ] && [ "$index_oid" = "$oid" ] || return 1
  [ -f "$path" ] && [ ! -L "$path" ] || return 1
  [ -x "$path" ] && work_mode=100755 || work_mode=100644
  work_oid="$(git hash-object --path="$path" "$path")" || return 1
  [ "$work_mode" = "$mode" ] && [ "$work_oid" = "$oid" ] || return 1
  printf '%s %s\n' "$mode" "$oid"
}
completion_tree_entity() { git show "$1:$2" > "$3" 2>/dev/null; }
completion_verify_commit() {
  local before="$1" completion="$2" entity="$3" artifact="$4" status="$5" stage="$6" file="$7" tmp parent changed state before_art after_art
  tmp="$(mktemp)" || return 1
  parent="$(git rev-parse "$completion^" 2>/dev/null)" || { rm -f "$tmp"; return 1; }
  [ "$parent" = "$before" ] || { rm -f "$tmp"; return 1; }
  changed="$(git diff-tree --no-commit-id --name-only -r "$before" "$completion")" || { rm -f "$tmp"; return 1; }
  [ "$changed" = "$entity" ] || { rm -f "$tmp"; return 1; }
  completion_tree_entity "$completion" "$entity" "$tmp" || { rm -f "$tmp"; return 1; }
  state="$(completion_parse_entity "$tmp" "$status" "$stage" "$file")" || { rm -f "$tmp"; return 1; }
  [ "$state" = PRESENT ] || { rm -f "$tmp"; return 1; }
  before_art="$(git rev-parse "$before:$artifact" 2>/dev/null)" || { rm -f "$tmp"; return 1; }
  after_art="$(git rev-parse "$completion:$artifact" 2>/dev/null)" || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
  [ "$before_art" = "$after_art" ]
}
completion_emit_receipt() {
  local disposition="$1" ref="$2" before="$3" completion="$4" entity="$5" status="$6" stage="$7" file="$8" artifact="$9" format="${10}" observed tmp state artifact_oid rc
  completion_ref_ok "$ref" && completion_path_ok "$entity" && completion_contract_ok "$status" "$stage" "$file" || return 1
  completion_oid_ok "$before" "$format" && completion_oid_ok "$completion" "$format" || return 1
  completion_capture observed git rev-parse "$ref" || return 1
  [ "$observed" = "$completion" ] || return 1
  case "$disposition" in
    published)
      [ "$before" != "$completion" ] && completion_verify_commit "$before" "$completion" "$entity" "$artifact" "$status" "$stage" "$file" || return 1
      ;;
    already-registered)
      [ "$before" = "$completion" ] || return 1
      tmp="$(mktemp)" || return 1
      completion_tree_entity "$completion" "$entity" "$tmp" || { rm -f "$tmp"; return 1; }
      state="$(completion_parse_entity "$tmp" "$status" "$stage" "$file")"; rc=$?; rm -f "$tmp"
      [ "$rc" = 0 ] && [ "$state" = PRESENT ] || return 1
      completion_capture artifact_oid git rev-parse "$completion:$artifact" || return 1
      completion_oid_ok "$artifact_oid" "$format" || return 1
      ;;
    *) return 1 ;;
  esac
  printf 'completion-v1 disposition=%s ref=%s before=%s completion=%s entity=%s stage=%s artifact=%s\n' \
    "$disposition" "$ref" "$before" "$completion" "$entity" "$stage" "$file"
}
