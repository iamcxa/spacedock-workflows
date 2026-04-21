#!/usr/bin/env node
// ship-flow-hook-version: 1.0.0
// Ship-flow warn-direct-read — PreToolUse hook
//
// Nudges agents to use `lib/extract-section.sh` for surgical section access
// on ship-flow entity files, instead of full-file Read/Edit.
//
// Principle #5c: direct Read/Edit on entity files is ALLOWED but warned
// (warn-not-block escape hatch). CI grep on SKILL.md files provides the
// static-side enforcement for Principle #5c unjustified-direct-read patterns.
//
// Triggers on: Read and Edit tool calls
// Match:      file_path matches `docs/ship-flow/*.md` (active, NOT _archive)
// Action:     Advisory (does not block) — injects systemMessage
// Pattern ref: ~/.claude/hooks/gsd-read-guard.js (Write/Edit PreToolUse)

const path = require('path');

let input = '';
const stdinTimeout = setTimeout(() => process.exit(0), 3000);
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);
  try {
    const data = JSON.parse(input);
    const toolName = data.tool_name;

    // Only intercept Read and Edit tool calls
    if (toolName !== 'Read' && toolName !== 'Edit') {
      process.exit(0);
    }

    const filePath = data.tool_input && data.tool_input.file_path;
    if (!filePath || typeof filePath !== 'string') {
      process.exit(0);
    }

    // Normalize — file_path from CC tools is absolute path
    const normalized = path.normalize(filePath);

    // Match: contains /docs/ship-flow/ segment AND ends with .md
    // Exclude: /_archive/ sub-path (archived entities are read-only history)
    const isEntityFile =
      /\/docs\/ship-flow\/(?!_archive\/)[^/]+\.md$/.test(normalized);

    if (!isEntityFile) {
      process.exit(0);
    }

    const fileName = path.basename(normalized);

    // Warn-not-block: emit systemMessage (user-visible) per Principle #5c
    const warnText =
      `[ship-flow] Direct ${toolName} on entity file "${fileName}". ` +
      'Prefer `bash plugins/ship-flow/lib/extract-section.sh ' + fileName +
      ' <section-tag>` for surgical section access (Principle #5c, see ' +
      'plugins/ship-flow/INVARIANTS.md). ' +
      'Full-file ' + toolName + ' allowed but flagged at CI — add `# justification: <reason>` ' +
      'adjacent comment in SKILL.md if intentional.';

    const output = {
      systemMessage: warnText,
    };

    process.stdout.write(JSON.stringify(output));
    process.exit(0);
  } catch {
    // Silent fail — never block tool execution
    process.exit(0);
  }
});
