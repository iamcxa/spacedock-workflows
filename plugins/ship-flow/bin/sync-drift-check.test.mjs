import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

import { runSyncDriftCheck } from "./sync-drift-check.mjs";

const execFileAsync = promisify(execFile);
const SCRIPT_PATH = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "sync-drift-check.mjs",
);

function sha256(text) {
  return createHash("sha256").update(text).digest("hex");
}

async function withFixture(files, fn) {
  const root = await mkdtemp(path.join(tmpdir(), "ship-flow-sync-drift-check-"));
  try {
    for (const [relativePath, contents] of Object.entries(files)) {
      const absolutePath = path.join(root, relativePath);
      await mkdir(path.dirname(absolutePath), { recursive: true });
      await writeFile(absolutePath, contents);
    }
    return await fn(root);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

function manifestJson(mods) {
  return JSON.stringify({ version: 1, mods }, null, 2);
}

function fixtureFiles({ manifestMods, adopterMods = {}, pluginMods = {} }) {
  const files = {};
  if (manifestMods !== undefined) {
    files["adopter/docs/ship-flow/sync-manifest.json"] = manifestJson(manifestMods);
  }
  for (const [name, contents] of Object.entries(adopterMods)) {
    files[`adopter/docs/ship-flow/_mods/${name}.md`] = contents;
  }
  for (const [name, contents] of Object.entries(pluginMods)) {
    files[`plugin/_mods/${name}.md`] = contents;
  }
  return files;
}

async function runFixture(options) {
  return await withFixture(fixtureFiles(options), async (root) =>
    await runSyncDriftCheck({
      cwd: path.join(root, "adopter"),
      workflowDir: "docs/ship-flow",
      pluginModsDir: path.join(root, "plugin", "_mods"),
      acceptUpstream: options.acceptUpstream,
    }),
  );
}

function ruleIds(result) {
  return result.issues.map((issue) => issue.ruleId).sort();
}

test("passes a clean plugin-canonical copy", async () => {
  const result = await runFixture({
    manifestMods: { "design-officer": { bucket: "plugin-canonical" } },
    adopterMods: { "design-officer": "# Design Officer\nsame bytes\n" },
    pluginMods: { "design-officer": "# Design Officer\nsame bytes\n" },
  });

  assert.equal(result.ok, true);
  assert.equal(result.manifestFound, true);
  assert.deepEqual(result.issues, []);
});

test("fails a drifted plugin-canonical copy with re-copy guidance", async () => {
  const result = await runFixture({
    manifestMods: { "design-officer": { bucket: "plugin-canonical" } },
    adopterMods: { "design-officer": "# Design Officer\nlocal edit\n" },
    pluginMods: { "design-officer": "# Design Officer\nupstream bytes\n" },
  });

  assert.equal(result.ok, false);
  assert.deepEqual(ruleIds(result), ["canonical.drifted-copy"]);
  assert.equal(result.issues[0].level, "FAIL");
  assert.match(result.issues[0].message, /re-copy from plugin/);
  assert.match(result.issues[0].message, /reclassify as customized/);
});

test("fails a plugin-canonical entry the plugin does not ship", async () => {
  const result = await runFixture({
    manifestMods: { "ghost-mod": { bucket: "plugin-canonical" } },
    adopterMods: { "ghost-mod": "# Ghost\n" },
  });

  assert.equal(result.ok, false);
  assert.deepEqual(ruleIds(result), ["canonical.plugin-missing"]);
  assert.match(result.issues[0].message, /plugin does not ship this mod/);
});

test("passes a clean customized entry even when the adopter copy differs from the plugin", async () => {
  const pluginContents = "# Lint\nupstream body\n";
  const result = await runFixture({
    manifestMods: {
      "ship-flow-lint": {
        bucket: "customized",
        upstreamBaseHash: sha256(pluginContents),
      },
    },
    adopterMods: { "ship-flow-lint": "# Lint\nheavily customized body\n" },
    pluginMods: { "ship-flow-lint": pluginContents },
  });

  assert.equal(result.ok, true);
  assert.deepEqual(result.issues, []);
});

test("warns (not fails) when upstream moved under a customized entry", async () => {
  const result = await runFixture({
    manifestMods: {
      "ship-flow-lint": {
        bucket: "customized",
        upstreamBaseHash: sha256("# Lint\nold upstream body\n"),
      },
    },
    adopterMods: { "ship-flow-lint": "# Lint\ncustomized body\n" },
    pluginMods: { "ship-flow-lint": "# Lint\nnew upstream body\n" },
  });

  assert.equal(result.ok, true);
  assert.deepEqual(ruleIds(result), ["customized.upstream-moved"]);
  assert.equal(result.issues[0].level, "WARN");
  assert.match(result.issues[0].message, /--accept-upstream ship-flow-lint/);
});

test("fails a customized entry without upstreamBaseHash", async () => {
  const result = await runFixture({
    manifestMods: { "ship-flow-lint": { bucket: "customized" } },
    adopterMods: { "ship-flow-lint": "# Lint\ncustomized body\n" },
    pluginMods: { "ship-flow-lint": "# Lint\nupstream body\n" },
  });

  assert.equal(result.ok, false);
  assert.deepEqual(ruleIds(result), ["customized.missing-upstream-base-hash"]);
  assert.match(result.issues[0].message, /requires upstreamBaseHash/);
});

test("warns on a local-only name collision with a plugin mod", async () => {
  const result = await runFixture({
    manifestMods: { "pr-merge": { bucket: "local-only" } },
    adopterMods: { "pr-merge": "# PR Merge (carlove variant)\n" },
    pluginMods: { "pr-merge": "# PR Merge (upstream)\n" },
  });

  assert.equal(result.ok, true);
  assert.deepEqual(ruleIds(result), ["local-only.plugin-collision"]);
  assert.equal(result.issues[0].level, "WARN");
  assert.match(result.issues[0].message, /reclassify or rename/);
});

test("fails a local-only entry whose adopter file is missing", async () => {
  const result = await runFixture({
    manifestMods: { "pr-merge": { bucket: "local-only" } },
  });

  assert.equal(result.ok, false);
  assert.deepEqual(ruleIds(result), ["local-only.missing-adopter-file"]);
});

test("warns on an unclassified adopter mod", async () => {
  const result = await runFixture({
    manifestMods: {},
    adopterMods: { "mystery-mod": "# Mystery\n" },
  });

  assert.equal(result.ok, true);
  assert.deepEqual(ruleIds(result), ["manifest.unclassified-adopter-mod"]);
  assert.equal(result.issues[0].level, "WARN");
  assert.match(result.issues[0].message, /add it to sync-manifest.json/);
});

test("warns on a non-local-only manifest entry with no adopter file", async () => {
  const result = await runFixture({
    manifestMods: { "design-officer": { bucket: "plugin-canonical" } },
    pluginMods: { "design-officer": "# Design Officer\n" },
  });

  assert.equal(result.ok, true);
  assert.deepEqual(ruleIds(result), ["manifest.missing-adopter-file"]);
  assert.equal(result.issues[0].level, "WARN");
});

test("treats a missing manifest as opt-out: ok with a notice, no issues", async () => {
  const result = await runFixture({ manifestMods: undefined });

  assert.equal(result.ok, true);
  assert.equal(result.manifestFound, false);
  assert.deepEqual(result.issues, []);
  assert.match(result.notice, /sync-manifest\.json/);
});

test("--accept-upstream rewrites upstreamBaseHash to the current plugin hash with stable key order", async () => {
  const newUpstream = "# Lint\nnew upstream body\n";
  const files = fixtureFiles({
    manifestMods: {
      "zeta-mod": {
        bucket: "customized",
        upstreamBaseHash: sha256("# Lint\nold upstream body\n"),
      },
      "alpha-mod": { bucket: "local-only" },
    },
    adopterMods: {
      "zeta-mod": "# Lint\ncustomized body\n",
      "alpha-mod": "# Alpha\n",
    },
    pluginMods: { "zeta-mod": newUpstream },
  });

  await withFixture(files, async (root) => {
    const result = await runSyncDriftCheck({
      cwd: path.join(root, "adopter"),
      workflowDir: "docs/ship-flow",
      pluginModsDir: path.join(root, "plugin", "_mods"),
      acceptUpstream: "zeta-mod",
    });

    assert.equal(result.ok, true);
    assert.deepEqual(result.accepted, {
      mod: "zeta-mod",
      upstreamBaseHash: sha256(newUpstream),
    });
    assert.deepEqual(ruleIds(result), []);

    const savedText = await readFile(
      path.join(root, "adopter/docs/ship-flow/sync-manifest.json"),
      "utf8",
    );
    const saved = JSON.parse(savedText);
    assert.equal(saved.version, 1);
    assert.equal(saved.mods["zeta-mod"].upstreamBaseHash, sha256(newUpstream));
    assert.deepEqual(Object.keys(saved.mods), ["alpha-mod", "zeta-mod"]);
    assert.equal(savedText, `${JSON.stringify(saved, null, 2)}\n`);
  });
});

test("--accept-upstream on a non-customized entry fails without writing the manifest", async () => {
  const files = fixtureFiles({
    manifestMods: { "alpha-mod": { bucket: "local-only" } },
    adopterMods: { "alpha-mod": "# Alpha\n" },
  });

  await withFixture(files, async (root) => {
    const manifestPath = path.join(root, "adopter/docs/ship-flow/sync-manifest.json");
    const before = await readFile(manifestPath, "utf8");
    const result = await runSyncDriftCheck({
      cwd: path.join(root, "adopter"),
      workflowDir: "docs/ship-flow",
      pluginModsDir: path.join(root, "plugin", "_mods"),
      acceptUpstream: "alpha-mod",
    });

    assert.equal(result.ok, false);
    assert.equal(result.accepted, null);
    assert.match(
      result.issues.map((issue) => issue.ruleId).join("\n"),
      /accept-upstream/,
    );
    assert.equal(await readFile(manifestPath, "utf8"), before);
  });
});

test("CLI --json prints the machine-readable result and exits 0 on warns only", async () => {
  const files = fixtureFiles({
    manifestMods: { "zzz-fixture-local": { bucket: "local-only" } },
    adopterMods: {
      "zzz-fixture-local": "# Local Only\n",
      "zzz-fixture-unclassified": "# Unclassified\n",
    },
  });

  await withFixture(files, async (root) => {
    const { stdout } = await execFileAsync(
      process.execPath,
      [SCRIPT_PATH, "--workflow-dir", "docs/ship-flow", "--json"],
      { cwd: path.join(root, "adopter") },
    );

    const result = JSON.parse(stdout);
    assert.equal(result.ok, true);
    assert.equal(result.manifestFound, true);
    assert.deepEqual(
      result.issues.map((issue) => [issue.ruleId, issue.level, issue.mod]),
      [["manifest.unclassified-adopter-mod", "WARN", "zzz-fixture-unclassified"]],
    );
  });
});

test("CLI exits 0 with a one-line notice when the manifest is missing", async () => {
  await withFixture({ "adopter/.keep": "" }, async (root) => {
    const { stdout } = await execFileAsync(
      process.execPath,
      [SCRIPT_PATH, "--workflow-dir", "docs/ship-flow"],
      { cwd: path.join(root, "adopter") },
    );

    assert.match(stdout, /sync-manifest\.json/);
    assert.equal(stdout.trim().split("\n").length, 1);
  });
});

test("CLI exits 1 when a FAIL check fires", async () => {
  const files = fixtureFiles({
    manifestMods: { "zzz-fixture-missing": { bucket: "local-only" } },
  });

  await withFixture(files, async (root) => {
    await assert.rejects(
      execFileAsync(
        process.execPath,
        [SCRIPT_PATH, "--workflow-dir", "docs/ship-flow"],
        { cwd: path.join(root, "adopter") },
      ),
      (error) => {
        assert.equal(error.code, 1);
        assert.match(error.stderr, /local-only\.missing-adopter-file/);
        return true;
      },
    );
  });
});
