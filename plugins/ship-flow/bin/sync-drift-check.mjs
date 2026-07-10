#!/usr/bin/env node
import { createHash } from "node:crypto";
import { readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_PLUGIN_MODS_DIR = path.join(SCRIPT_DIR, "..", "_mods");
const DEFAULT_PLUGIN_BIN_DIR = SCRIPT_DIR;
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

async function listScriptNames(scriptsDir) {
  try {
    const entries = await readdir(scriptsDir, { withFileTypes: true });
    return entries.filter((entry) => entry.isFile()).map((entry) => entry.name);
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

function serializeSection(section) {
  const ordered = {};
  for (const name of Object.keys(section ?? {}).sort()) {
    const entry = section[name];
    const orderedEntry = { bucket: entry.bucket };
    if (entry.upstreamBaseHash !== undefined) {
      orderedEntry.upstreamBaseHash = entry.upstreamBaseHash;
    }
    for (const key of Object.keys(entry).sort()) {
      if (!(key in orderedEntry)) orderedEntry[key] = entry[key];
    }
    ordered[name] = orderedEntry;
  }
  return ordered;
}

function serializeManifest(manifest) {
  const output = {
    version: manifest.version ?? 1,
    mods: serializeSection(manifest.mods),
  };
  if (manifest.scripts !== undefined) {
    output.scripts = serializeSection(manifest.scripts);
  }
  for (const key of Object.keys(manifest).sort()) {
    if (key !== "version" && key !== "mods" && key !== "scripts") {
      output[key] = manifest[key];
    }
  }
  return `${JSON.stringify(output, null, 2)}\n`;
}

function issue(level, ruleId, mod, file, message) {
  return { ruleId, level, mod, file, message };
}

async function resolvePluginIdentity() {
  for (const manifestDir of [".claude-plugin", ".codex-plugin"]) {
    const bytes = await readBytesIfExists(
      path.join(SCRIPT_DIR, "..", manifestDir, "plugin.json"),
    );
    if (bytes === null) continue;
    try {
      const parsed = JSON.parse(bytes.toString("utf8"));
      if (typeof parsed.name === "string" && typeof parsed.version === "string") {
        return { name: parsed.name, version: parsed.version };
      }
    } catch {
      // unreadable manifest mirror: try the next candidate
    }
  }
  return null;
}

// Shared 3-bucket checker for one manifest section. `noun` only affects
// message wording; `acceptPrefix` shapes the --accept-upstream hint.
function checkSectionEntry({
  name,
  entry,
  adopterBytes,
  pluginBytes,
  adopterFileRel,
  manifestRel,
  noun,
  acceptPrefix,
  issues,
}) {
  switch (entry.bucket) {
    case "plugin-canonical": {
      if (pluginBytes === null) {
        issues.push(
          issue(
            "FAIL",
            "canonical.plugin-missing",
            name,
            adopterFileRel,
            `manifest says plugin-canonical but plugin does not ship this ${noun}`,
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
            `plugin no longer ships this ${noun}: reclassify as local-only or drop the entry`,
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
            `upstream moved under your customization: review plugin changes, merge what applies, then run --accept-upstream ${acceptPrefix}${name}`,
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
            `local-only ${noun} must exist in the adopter tree`,
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
            `name collision: plugin now ships a ${noun} with this name; reclassify or rename`,
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

async function acceptUpstreamEntry({
  section,
  sectionLabel,
  name,
  upstreamPath,
  manifest,
  manifestPath,
  manifestRel,
  issues,
}) {
  const entry = section?.[name];
  const displayName = sectionLabel === "scripts" ? `scripts/${name}` : name;
  if (!entry || entry.bucket !== "customized") {
    issues.push(
      issue(
        "FAIL",
        "accept-upstream.not-customized",
        displayName,
        manifestRel,
        `--accept-upstream requires a "customized" manifest entry for "${displayName}"`,
      ),
    );
    return null;
  }
  const pluginBytes = await readBytesIfExists(upstreamPath);
  if (pluginBytes === null) {
    issues.push(
      issue(
        "FAIL",
        "accept-upstream.plugin-missing",
        displayName,
        manifestRel,
        `cannot accept upstream for "${displayName}": plugin does not ship this file`,
      ),
    );
    return null;
  }
  entry.upstreamBaseHash = sha256Hex(pluginBytes);
  await writeFile(manifestPath, serializeManifest(manifest));
  return { mod: displayName, upstreamBaseHash: entry.upstreamBaseHash };
}

export async function runSyncDriftCheck(options = {}) {
  const cwd = options.cwd ?? process.cwd();
  const workflowDir = options.workflowDir ?? "docs/ship-flow";
  const pluginModsDir = options.pluginModsDir ?? DEFAULT_PLUGIN_MODS_DIR;
  const pluginBinDir = options.pluginBinDir ?? DEFAULT_PLUGIN_BIN_DIR;
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
  const scripts =
    manifest.scripts && typeof manifest.scripts === "object"
      ? manifest.scripts
      : null;
  const issues = [];
  let accepted = null;

  if (acceptUpstream) {
    if (acceptUpstream.startsWith("scripts/")) {
      const name = acceptUpstream.slice("scripts/".length);
      accepted = await acceptUpstreamEntry({
        section: scripts,
        sectionLabel: "scripts",
        name,
        upstreamPath: path.join(pluginBinDir, name),
        manifest,
        manifestPath,
        manifestRel,
        issues,
      });
    } else {
      const name = acceptUpstream.startsWith("mods/")
        ? acceptUpstream.slice("mods/".length)
        : acceptUpstream;
      accepted = await acceptUpstreamEntry({
        section: mods,
        sectionLabel: "mods",
        name,
        upstreamPath: path.join(pluginModsDir, `${name}.md`),
        manifest,
        manifestPath,
        manifestRel,
        issues,
      });
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

    checkSectionEntry({
      name,
      entry,
      adopterBytes,
      pluginBytes,
      adopterFileRel,
      manifestRel,
      noun: "mod",
      acceptPrefix: "",
      issues,
    });
  }

  // The scripts section is opt-in per manifest: absent key = no script checks
  // (back-compat with version-1 manifests that only classify _mods/).
  if (scripts !== null) {
    const adopterScriptsDir = path.join(cwd, workflowDir, "scripts");
    const adopterScriptNames = await listScriptNames(adopterScriptsDir);
    const scriptNames = [
      ...new Set([...Object.keys(scripts), ...adopterScriptNames]),
    ].sort();

    for (const name of scriptNames) {
      const entry = scripts[name];
      const adopterFileRel = path.join(workflowDir, "scripts", name);
      const adopterBytes = await readBytesIfExists(
        path.join(adopterScriptsDir, name),
      );
      const pluginBytes = await readBytesIfExists(path.join(pluginBinDir, name));

      if (!entry) {
        issues.push(
          issue(
            "WARN",
            "manifest.unclassified-adopter-script",
            name,
            adopterFileRel,
            "unclassified adopter script: add it to sync-manifest.json",
          ),
        );
        continue;
      }

      checkSectionEntry({
        name,
        entry,
        adopterBytes,
        pluginBytes,
        adopterFileRel,
        manifestRel,
        noun: "script",
        acceptPrefix: "scripts/",
        issues,
      });
    }
  }

  // workflow-version stamp check: WARN when the adopter README stamps a
  // different plugin version than the one running this check. Re-stamping is
  // a deliberate post-upgrade action, so this never FAILs.
  let pluginName = options.pluginName ?? null;
  let pluginVersion = options.pluginVersion ?? null;
  if (pluginName === null || pluginVersion === null) {
    const identity = await resolvePluginIdentity();
    if (identity !== null) {
      pluginName = pluginName ?? identity.name;
      pluginVersion = pluginVersion ?? identity.version;
    }
  }
  if (pluginName !== null && pluginVersion !== null) {
    const readmeRel = path.join(workflowDir, "README.md");
    const readmeBytes = await readBytesIfExists(path.join(cwd, readmeRel));
    if (readmeBytes !== null) {
      const match = readmeBytes
        .toString("utf8")
        .match(/^workflow-version:\s*(\S+)/m);
      if (match !== null) {
        const stamped = match[1];
        const expected = `${pluginName}@${pluginVersion}`;
        if (stamped !== expected) {
          issues.push(
            issue(
              "WARN",
              "stamp.workflow-version-stale",
              "workflow-version",
              readmeRel,
              `README stamps ${stamped} but the installed plugin is ${expected}: re-stamp after reviewing the upgrade`,
            ),
          );
        }
      }
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
