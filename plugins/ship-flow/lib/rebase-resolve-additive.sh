#!/usr/bin/env bash
# rebase-resolve-additive.sh - resolve safe append-only ROADMAP conflicts.
#
# This helper is intentionally narrow. It only resolves an active rebase/merge
# conflict when ROADMAP.md is the sole unmerged path and both sides changed only
# known append-only sections by adding lines.
set -euo pipefail

PATH_TO_RESOLVE="ROADMAP.md"
SECTIONS="later,not-doing,shipped"

usage() {
  cat >&2 <<'EOF'
Usage: rebase-resolve-additive.sh [--path=ROADMAP.md] [--sections=later,not-doing,shipped]

Exit codes:
  0 resolved and staged
  1 usage or missing git conflict state
  2 unsafe unmerged path set
  3 non-additive or structural conflict
EOF
}

for arg in "$@"; do
  case "$arg" in
    --path=*) PATH_TO_RESOLVE="${arg#--path=}" ;;
    --sections=*) SECTIONS="${arg#--sections=}" ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 1 ;;
  esac
done

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Error: not inside a git repository" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

UNMERGED="$(git diff --name-only --diff-filter=U)"
if [ "$UNMERGED" != "$PATH_TO_RESOLVE" ]; then
  echo "Error: additive auto-resolve requires the sole unmerged path to be ${PATH_TO_RESOLVE}; got:" >&2
  if [ -n "$UNMERGED" ]; then printf '%s\n' "$UNMERGED" >&2; else echo "(none)" >&2; fi
  exit 2
fi

if ! git ls-files -u -- "$PATH_TO_RESOLVE" | awk '{print $3}' | sort -u | tr '\n' ' ' | grep -q '1 2 3 '; then
  echo "Error: ${PATH_TO_RESOLVE} does not have base/ours/theirs conflict stages" >&2
  exit 1
fi

export PATH_TO_RESOLVE SECTIONS
ruby <<'RUBY'
path = ENV.fetch("PATH_TO_RESOLVE")
sections = ENV.fetch("SECTIONS").split(",").map(&:strip).reject(&:empty?)

def git_show(stage, path)
  content = IO.popen(["git", "show", ":#{stage}:#{path}"], err: [:child, :out], &:read)
  raise "missing git stage #{stage} for #{path}" unless $?.success?
  content
end

def split_lines(content)
  content.lines(chomp: true)
end

def section_bounds(lines, section)
  start_marker = "<!-- section:#{section} -->"
  end_marker = "<!-- /section:#{section} -->"
  start_idx = lines.index(start_marker)
  end_idx = lines.index(end_marker)
  return nil if start_idx.nil? || end_idx.nil? || end_idx <= start_idx
  [start_idx, end_idx]
end

def outside_allowed_sections(lines, sections)
  skip = false
  current = nil
  out = []
  lines.each do |line|
    if (match = line.match(/\A<!-- section:([^ ]+) -->\z/)) && sections.include?(match[1])
      skip = true
      current = match[1]
      out << line
      next
    end

    if skip && line == "<!-- /section:#{current} -->"
      skip = false
      current = nil
      out << line
      next
    end

    out << line unless skip
  end
  out
end

def inner(lines, section)
  bounds = section_bounds(lines, section)
  raise "missing section #{section}" if bounds.nil?
  lines[(bounds[0] + 1)...bounds[1]]
end

def subsequence?(needle, haystack)
  idx = 0
  haystack.each do |line|
    idx += 1 if idx < needle.length && line == needle[idx]
  end
  idx == needle.length
end

def additions(base, side)
  idx = 0
  side.each_with_object([]) do |line, added|
    if idx < base.length && line == base[idx]
      idx += 1
    else
      added << line
    end
  end
end

begin
  base = split_lines(git_show(1, path))
  ours = split_lines(git_show(2, path))
  theirs = split_lines(git_show(3, path))

  unless outside_allowed_sections(base, sections) == outside_allowed_sections(ours, sections) &&
         outside_allowed_sections(base, sections) == outside_allowed_sections(theirs, sections)
    warn "Error: changes outside allowed append-only sections: #{sections.join(", ")}"
    exit 3
  end

  replacements = {}
  touched = []

  sections.each do |section|
    base_inner = inner(base, section)
    ours_inner = inner(ours, section)
    theirs_inner = inner(theirs, section)

    unless subsequence?(base_inner, ours_inner) && subsequence?(base_inner, theirs_inner)
      warn "Error: section #{section} has row edits or deletions"
      exit 3
    end

    next if base_inner == ours_inner && base_inner == theirs_inner

    union = base_inner.dup
    (additions(base_inner, ours_inner) + additions(base_inner, theirs_inner)).each do |line|
      union << line unless union.include?(line)
    end
    replacements[section] = union
    touched << section
  end

  if touched.empty?
    warn "Error: no additive changes found in allowed sections"
    exit 3
  end

  resolved = []
  idx = 0
  while idx < base.length
    line = base[idx]
    if (match = line.match(/\A<!-- section:([^ ]+) -->\z/)) && replacements.key?(match[1])
      section = match[1]
      bounds = section_bounds(base, section)
      resolved << line
      resolved.concat(replacements.fetch(section))
      resolved << "<!-- /section:#{section} -->"
      idx = bounds[1] + 1
    else
      resolved << line
      idx += 1
    end
  end

  File.write(path, resolved.join("\n") + "\n")
  system("git", "add", "--", path) || raise("git add failed")
  puts "Resolved #{path} additive sections: #{touched.join(", ")}"
rescue => e
  warn "Error: #{e.message}"
  exit 3
end
RUBY
