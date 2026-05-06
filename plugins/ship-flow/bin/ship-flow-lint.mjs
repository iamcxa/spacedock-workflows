#!/usr/bin/env node
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const DEFAULT_CONFIG = {
  markdown: {
    forbiddenPatterns: [
      {
        id: "double-pipe-table-prefix",
        pattern: "^\\|\\|",
        message: "Markdown table rows must use a single leading pipe.",
      },
    ],
  },
  modContract: {
    files: ["docs/ship-flow/_mods/*.md"],
    forbiddenPatterns: [],
  },
  workflow: {
    requiredFiles: [],
  },
};

function mergeConfig(config) {
  return {
    markdown: {
      ...DEFAULT_CONFIG.markdown,
      ...config.markdown,
      forbiddenPatterns: [
        ...DEFAULT_CONFIG.markdown.forbiddenPatterns,
        ...(config.markdown?.forbiddenPatterns ?? []),
      ],
    },
    modContract: {
      ...DEFAULT_CONFIG.modContract,
      ...config.modContract,
      forbiddenPatterns:
        config.modContract?.forbiddenPatterns ??
        DEFAULT_CONFIG.modContract.forbiddenPatterns,
    },
    workflow: {
      ...DEFAULT_CONFIG.workflow,
      ...config.workflow,
      requiredFiles:
        config.workflow?.requiredFiles ?? DEFAULT_CONFIG.workflow.requiredFiles,
    },
  };
}

async function readTextIfExists(filePath) {
  try {
    return await readFile(filePath, "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

async function readConfig(cwd, workflowDir) {
  const configPath = path.join(cwd, workflowDir, "ship-flow-lint.config.json");
  const text = await readTextIfExists(configPath);
  if (text === null) return mergeConfig({});
  return mergeConfig(JSON.parse(text));
}

async function listMarkdownFiles(rootDir) {
  const files = [];

  async function walk(dir) {
    const entries = await readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
      const absolutePath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        await walk(absolutePath);
      } else if (entry.isFile() && entry.name.endsWith(".md")) {
        files.push(absolutePath);
      }
    }
  }

  await walk(rootDir);
  return files.sort();
}

function globToRegExp(glob) {
  const escaped = glob
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replaceAll("**", "\0")
    .replaceAll("*", "[^/]*")
    .replaceAll("\0", ".*");
  return new RegExp(`^${escaped}$`);
}

function matchesAnyGlob(relativeFile, globs) {
  return globs.some((glob) => globToRegExp(glob).test(relativeFile));
}

function lineForIndex(contents, index) {
  return contents.slice(0, index).split("\n").length;
}

function scanForbiddenPatterns({ contents, relativeFile, category, patterns }) {
  const issues = [];
  for (const rule of patterns) {
    if (rule.files && !matchesAnyGlob(relativeFile, rule.files)) continue;
    const regex = new RegExp(rule.pattern, "gim");
    for (const match of contents.matchAll(regex)) {
      const line = contents.split("\n")[lineForIndex(contents, match.index ?? 0) - 1] ?? "";
      if (
        rule.ignoreLinePatterns?.some((pattern) =>
          new RegExp(pattern).test(line),
        )
      ) {
        continue;
      }
      issues.push({
        ruleId: `${category}.${rule.id}`,
        file: relativeFile,
        line: lineForIndex(contents, match.index ?? 0),
        message: rule.message ?? `Forbidden ${category} pattern: ${rule.id}`,
        evidence: match[0],
      });
    }
  }
  return issues;
}

async function checkRequiredFiles({ cwd, config }) {
  const issues = [];
  for (const requiredFile of config.workflow.requiredFiles) {
    if ((await readTextIfExists(path.join(cwd, requiredFile))) !== null) continue;
    issues.push({
      ruleId: "workflow.missing-required-file",
      file: requiredFile,
      line: 1,
      message: "Required ship-flow workflow contract surface is missing",
    });
  }
  return issues;
}

export async function runShipFlowLint(options = {}) {
  const cwd = options.cwd ?? process.cwd();
  const workflowDir = options.workflowDir ?? "docs/ship-flow";
  const workflowRoot = path.join(cwd, workflowDir);
  const config = await readConfig(cwd, workflowDir);
  const markdownFiles = await listMarkdownFiles(workflowRoot);
  const issues = [];

  for (const file of markdownFiles) {
    const relativeFile = path.relative(cwd, file);
    const contents = await readFile(file, "utf8");
    issues.push(
      ...scanForbiddenPatterns({
        contents,
        relativeFile,
        category: "markdown",
        patterns: config.markdown.forbiddenPatterns,
      }),
    );

    if (matchesAnyGlob(relativeFile, config.modContract.files ?? [])) {
      issues.push(
        ...scanForbiddenPatterns({
          contents,
          relativeFile,
          category: "mod-contract",
          patterns: config.modContract.forbiddenPatterns,
        }),
      );
    }
  }

  issues.push(...(await checkRequiredFiles({ cwd, config })));

  return {
    ok: issues.length === 0,
    issues,
  };
}

function formatIssue(issue) {
  const evidence = issue.evidence ? `\n    evidence: ${issue.evidence}` : "";
  return `${issue.file}:${issue.line} ${issue.ruleId}\n    ${issue.message}${evidence}`;
}

async function main() {
  const workflowArgIndex = process.argv.indexOf("--workflow-dir");
  const workflowDir =
    workflowArgIndex >= 0 ? process.argv[workflowArgIndex + 1] : "docs/ship-flow";
  const result = await runShipFlowLint({ workflowDir });
  if (result.ok) {
    console.log("ship-flow lint: OK");
    return;
  }

  console.error(`ship-flow lint: ${result.issues.length} issue(s)`);
  for (const issue of result.issues) {
    console.error(formatIssue(issue));
  }
  process.exitCode = 1;
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === currentFile) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
