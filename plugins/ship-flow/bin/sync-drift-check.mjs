#!/usr/bin/env node
import { createHash } from "node:crypto";
import { readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_PLUGIN_MODS_DIR = path.join(SCRIPT_DIR, "..", "_mods");
const BUCKETS = ["plugin-canonical", "customized", "local-only"];

async function readBytesIfExists(filePath) {
  try {
    return await readFile(filePath);
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

function sha256Hex(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

async function listModNames(modsDir) {
  try {
    const entries = await readdir(modsDir, { withFileTypes: true });
    return entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
      .map((entry) => entry.name.slice(0, -".md".length));
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

function serializeManifest(manifest) {
  const mods = {};
  for (const name of Object.keys(manifest.mods ?? {}).sort()) {
    const entry = manifest.mods[name];
    const ordered = { bucket: entry.bucket };
    if (entry.upstreamBaseHash !== undefined) {
      ordered.upstreamBaseHash = entry.upstreamBaseHash;
    }
    for (const key of Object.keys(entry).sort()) {
      if (!(key in ordered)) ordered[key] = entry[key];
    }
    mods[name] = ordered;
  }
  const rest = {};
  for (const key of Object.keys(manifest).sort()) {
    if (key !== "version" && key !== "mods") rest[key] = manifest[key];
  }
  return `${JSON.stringify({ version: manifest.version ?? 1, mods, ...rest }, null, 2)}\n`;
}

function issue(level, ruleId, mod, file, message) {
  return { ruleId, level, mod, file, message };
}

export async function runSyncDriftCheck(options = {}) {
  const cwd = options.cwd ?? process.cwd();
  const workflowDir = options.workflowDir ?? "docs/ship-flow";
  const pluginModsDir = options.pluginModsDir ?? DEFAULT_PLUGIN_MODS_DIR;
  const acceptUpstream = options.acceptUpstream ?? null;

  const manifestRel = path.join(workflowDir, "sync-manifest.json");
  const manifestPath = path.join(cwd, manifestRel);
  const manifestBytes = await readBytesIfExists(manifestPath);
  if (manifestBytes === null) {
    return {
      ok: true,
      manifestFound: false,
      notice: `sync drift check: no ${manifestRel} (opt-in; nothing to check)`,
      issues: [],
      accepted: null,
    };
  }

  const manifest = JSON.parse(manifestBytes.toString("utf8"));
  const mods =
    manifest.mods && typeof manifest.mods === "object" ? manifest.mods : {};
  const issues = [];
  let accepted = null;

  if (acceptUpstream) {
    const entry = mods[acceptUpstream];
    if (!entry || entry.bucket !== "customized") {
      issues.push(
        issue(
          "FAIL",
          "accept-upstream.not-customized",
          acceptUpstream,
          manifestRel,
          `--accept-upstream requires a "customized" manifest entry for "${acceptUpstream}"`,
        ),
      );
    } else {
      const pluginBytes = await readBytesIfExists(
        path.join(pluginModsDir, `${acceptUpstream}.md`),
      );
      if (pluginBytes === null) {
        issues.push(
          issue(
            "FAIL",
            "accept-upstream.plugin-missing",
            acceptUpstream,
            manifestRel,
            `cannot accept upstream for "${acceptUpstream}": plugin does not ship this mod`,
          ),
        );
      } else {
        entry.upstreamBaseHash = sha256Hex(pluginBytes);
        manifest.mods = mods;
        await writeFile(manifestPath, serializeManifest(manifest));
        accepted = { mod: acceptUpstream, upstreamBaseHash: entry.upstreamBaseHash };
      }
    }
  }

  const adopterModsDir = path.join(cwd, workflowDir, "_mods");
  const adopterNames = await listModNames(adopterModsDir);
  const names = [...new Set([...Object.keys(mods), ...adopterNames])].sort();

  for (const name of names) {
    const entry = mods[name];
    const adopterFileRel = path.join(workflowDir, "_mods", `${name}.md`);
    const adopterBytes = await readBytesIfExists(
      path.join(adopterModsDir, `${name}.md`),
    );
    const pluginBytes = await readBytesIfExists(
      path.join(pluginModsDir, `${name}.md`),
    );

    if (!entry) {
      issues.push(
        issue(
          "WARN",
          "manifest.unclassified-adopter-mod",
          name,
          adopterFileRel,
          "unclassified adopter mod: add it to sync-manifest.json",
        ),
      );
      continue;
    }

    switch (entry.bucket) {
      case "plugin-canonical": {
        if (pluginBytes === null) {
          issues.push(
            issue(
              "FAIL",
              "canonical.plugin-missing",
              name,
              adopterFileRel,
              "manifest says plugin-canonical but plugin does not ship this mod",
            ),
          );
          break;
        }
        if (adopterBytes === null) {
          issues.push(
            issue(
              "WARN",
              "manifest.missing-adopter-file",
              name,
              adopterFileRel,
              "manifest entry has no adopter file",
            ),
          );
          break;
        }
        if (sha256Hex(adopterBytes) !== sha256Hex(pluginBytes)) {
          issues.push(
            issue(
              "FAIL",
              "canonical.drifted-copy",
              name,
              adopterFileRel,
              "drifted canonical copy: re-copy from plugin or reclassify as customized",
            ),
          );
        }
        break;
      }
      case "customized": {
        if (
          typeof entry.upstreamBaseHash !== "string" ||
          entry.upstreamBaseHash.length === 0
        ) {
          issues.push(
            issue(
              "FAIL",
              "customized.missing-upstream-base-hash",
              name,
              adopterFileRel,
              "customized entry requires upstreamBaseHash",
            ),
          );
          break;
        }
        if (adopterBytes === null) {
          issues.push(
            issue(
              "WARN",
              "manifest.missing-adopter-file",
              name,
              adopterFileRel,
              "manifest entry has no adopter file",
            ),
          );
        }
        if (pluginBytes === null) {
          issues.push(
            issue(
              "WARN",
              "customized.upstream-removed",
              name,
              adopterFileRel,
              "plugin no longer ships this mod: reclassify as local-only or drop the entry",
            ),
          );
          break;
        }
        if (sha256Hex(pluginBytes) !== entry.upstreamBaseHash) {
          issues.push(
            issue(
              "WARN",
              "customized.upstream-moved",
              name,
              adopterFileRel,
              `upstream moved under your customization: review plugin changes, merge what applies, then run --accept-upstream ${name}`,
            ),
          );
        }
        break;
      }
      case "local-only": {
        if (adopterBytes === null) {
          issues.push(
            issue(
              "FAIL",
              "local-only.missing-adopter-file",
              name,
              adopterFileRel,
              "local-only mod must exist in the adopter tree",
            ),
          );
        }
        if (pluginBytes !== null) {
          issues.push(
            issue(
              "WARN",
              "local-only.plugin-collision",
              name,
              adopterFileRel,
              "name collision: plugin now ships a mod with this name; reclassify or rename",
            ),
          );
        }
        break;
      }
      default:
        issues.push(
          issue(
            "FAIL",
            "manifest.unknown-bucket",
            name,
            manifestRel,
            `unknown bucket "${entry.bucket}" (expected ${BUCKETS.join(" | ")})`,
          ),
        );
    }
  }

  return {
    ok: !issues.some((item) => item.level === "FAIL"),
    manifestFound: true,
    issues,
    accepted,
  };
}

function formatIssue(item) {
  return `${item.file} ${item.level} ${item.ruleId}\n    ${item.message}`;
}

async function main() {
  const argv = process.argv;
  const workflowArgIndex = argv.indexOf("--workflow-dir");
  const workflowDir =
    workflowArgIndex >= 0 ? argv[workflowArgIndex + 1] : "docs/ship-flow";
  const acceptArgIndex = argv.indexOf("--accept-upstream");
  const acceptUpstream = acceptArgIndex >= 0 ? argv[acceptArgIndex + 1] : null;
  const json = argv.includes("--json");

  const result = await runSyncDriftCheck({ workflowDir, acceptUpstream });

  if (json) {
    console.log(JSON.stringify(result, null, 2));
  } else if (!result.manifestFound) {
    console.log(result.notice);
  } else {
    if (result.accepted) {
      console.log(
        `sync drift check: accepted upstream for "${result.accepted.mod}" (upstreamBaseHash updated)`,
      );
    }
    if (result.issues.length === 0) {
      console.log("sync drift check: OK");
    } else {
      const fails = result.issues.filter((item) => item.level === "FAIL").length;
      const warns = result.issues.length - fails;
      console.error(`sync drift check: ${fails} FAIL(s), ${warns} WARN(s)`);
      for (const item of result.issues) {
        console.error(formatIssue(item));
      }
    }
  }

  if (!result.ok) process.exitCode = 1;
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === currentFile) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
