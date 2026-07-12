#!/usr/bin/env node
/**
 * e2e-verify runner — declarative computed-style regression
 *
 * Usage:
 *   node run.js <yaml-path> [--no-screenshot] [--bail-on-first-fail]
 *
 * Scope: Mode B only (fixed selectors × fixed expected values).
 * For forensics / dynamic queries, use agent-browser REPL directly.
 */

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const yaml = require('js-yaml');

const args = process.argv.slice(2);
const flags = {
  yamlPath: null,
  noScreenshot: false,
  bailOnFirstFail: false,
};

for (const a of args) {
  if (a === '--no-screenshot') flags.noScreenshot = true;
  else if (a === '--bail-on-first-fail') flags.bailOnFirstFail = true;
  else if (!flags.yamlPath) flags.yamlPath = a;
}

if (!flags.yamlPath) {
  console.error('Usage: run.js <yaml-path> [--no-screenshot] [--bail-on-first-fail]');
  process.exit(2);
}

const CWD = process.cwd();
const yamlAbs = path.resolve(CWD, flags.yamlPath);

if (!fs.existsSync(yamlAbs)) {
  console.error(`YAML not found: ${yamlAbs}`);
  process.exit(2);
}

// ---------- Phase 0: parse + resolve ----------

let doc;
try {
  doc = yaml.load(fs.readFileSync(yamlAbs, 'utf8'));
} catch (e) {
  console.error(`YAML parse error: ${e.message}`);
  process.exit(2);
}

const required = ['version', 'mapping', 'title', 'checks'];
for (const k of required) {
  if (doc[k] === undefined) {
    console.error(`YAML missing required field: ${k}`);
    process.exit(2);
  }
}
if (doc.version !== 1) {
  console.error(`Unsupported version: ${doc.version}. Expected 1.`);
  process.exit(2);
}
if (!Array.isArray(doc.checks) || doc.checks.length === 0) {
  console.error('YAML.checks must be a non-empty array');
  process.exit(2);
}

const mappingPath = path.resolve(CWD, '.claude/e2e/mappings', `${doc.mapping}.yaml`);
if (!fs.existsSync(mappingPath)) {
  console.error(`Mapping not found: ${mappingPath}`);
  process.exit(2);
}
const mapping = yaml.load(fs.readFileSync(mappingPath, 'utf8'));
const baseUrl = mapping.base_url || '';
const DEFAULT_READINESS_TIMEOUT_MS = 10000;
const DEFAULT_READINESS_POLL_MS = 100;

function positiveInteger(value, fallback, field) {
  if (value === undefined) return fallback;
  if (!Number.isInteger(value) || value <= 0) {
    console.error(`${field} must be a positive integer`);
    process.exit(2);
  }
  return value;
}

const readiness = {
  timeoutMs: positiveInteger(
    doc.readiness?.timeout_ms,
    DEFAULT_READINESS_TIMEOUT_MS,
    'readiness.timeout_ms'
  ),
  pollMs: positiveInteger(
    doc.readiness?.poll_ms,
    DEFAULT_READINESS_POLL_MS,
    'readiness.poll_ms'
  ),
};

let account = null;
if (doc.auth_account) {
  const accounts = mapping.auth?.test_accounts || {};
  account = accounts[doc.auth_account];
  if (!account) {
    console.error(
      `auth_account "${doc.auth_account}" not found in mapping. Available: ${Object.keys(accounts).join(', ')}`
    );
    process.exit(2);
  }
}

// ---------- helpers ----------

let commandTimeoutOverrideMs = null;

function ab(...argv) {
  const timeout = commandTimeoutOverrideMs || readiness.timeoutMs;
  const r = spawnSync('agent-browser', argv, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout,
  });
  if (r.error) {
    throw new Error(
      `agent-browser ${argv.join(' ')} failed after ${timeout}ms: ${r.error.message}`
    );
  }
  if (r.status !== 0) {
    const msg = (r.stderr || r.stdout || '').trim().slice(0, 800);
    throw new Error(`agent-browser ${argv.join(' ')} failed (exit ${r.status}): ${msg}`);
  }
  return (r.stdout || '').trim();
}

function abEval(expr) {
  const out = ab('eval', expr);
  // agent-browser eval prints the return value as a JSON-encoded string
  try {
    const parsed = JSON.parse(out);
    return typeof parsed === 'string' ? JSON.parse(parsed) : parsed;
  } catch {
    // Some agent-browser versions print a raw string; try direct parse
    try {
      return JSON.parse(out);
    } catch {
      return out;
    }
  }
}

function normalize(s) {
  if (s == null) return '';
  return String(s).replace(/\s+/g, ' ').trim();
}

function joinUrl(base, rel) {
  if (!rel) return base;
  if (/^https?:\/\//.test(rel)) return rel;
  return base.replace(/\/$/, '') + (rel.startsWith('/') ? rel : '/' + rel);
}

function sleep(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function withCommandTimeout(timeoutMs, operation) {
  const previousTimeout = commandTimeoutOverrideMs;
  commandTimeoutOverrideMs = Math.max(1, timeoutMs);
  try {
    return operation();
  } finally {
    commandTimeoutOverrideMs = previousTimeout;
  }
}

function retryBoundedly(label, operation, options = {}) {
  const timeoutMs = positiveInteger(options.timeout_ms, readiness.timeoutMs, `${label}.timeout_ms`);
  const pollMs = positiveInteger(options.poll_ms, readiness.pollMs, `${label}.poll_ms`);
  const deadline = Date.now() + timeoutMs;
  let lastError;

  do {
    const previousTimeout = commandTimeoutOverrideMs;
    commandTimeoutOverrideMs = Math.max(1, deadline - Date.now());
    try {
      return operation();
    } catch (e) {
      lastError = e;
    } finally {
      commandTimeoutOverrideMs = previousTimeout;
    }
    sleep(Math.min(pollMs, Math.max(1, deadline - Date.now())));
  } while (Date.now() < deadline);

  throw new Error(
    `${label} timed out after ${timeoutMs}ms${lastError ? `: ${lastError.message}` : ''}`
  );
}

function probeSelectors(selectors) {
  const unique = [...new Set(selectors)];
  return abEval(`(() => {
    const selectors = ${JSON.stringify(unique)};
    const missing = selectors.filter((selector) => !document.querySelector(selector));
    return JSON.stringify({ ready: missing.length === 0, missing });
  })()`);
}

function selectorsExist(selectors) {
  return probeSelectors(selectors)?.ready === true;
}

function probeActionableTarget(selector) {
  if (selector.startsWith('@') || selector.startsWith('text=')) {
    const snapshot = ab('snapshot', '-i');
    if (selector.startsWith('@')) {
      const ref = selector.slice(1);
      return {
        ready: snapshot.includes(`ref=${ref}`),
        missing: snapshot.includes(`ref=${ref}`) ? [] : [selector],
        reason: snapshot.includes(`ref=${ref}`) ? null : 'reference not found',
      };
    }
    const text = selector.slice('text='.length);
    return {
      ready: snapshot.includes(text),
      missing: snapshot.includes(text) ? [] : [selector],
      reason: snapshot.includes(text) ? null : 'text target not found',
    };
  }
  return abEval(`(() => {
    const selector = ${JSON.stringify(selector)};
    let element = null;
    try {
      if (selector.startsWith('/')) {
        element = document.evaluate(
          selector,
          document,
          null,
          XPathResult.FIRST_ORDERED_NODE_TYPE,
          null
        ).singleNodeValue;
      } else {
        element = document.querySelector(selector);
      }
    } catch (error) {
      return JSON.stringify({ ready: false, missing: [selector], reason: error.message });
    }
    if (!element) return JSON.stringify({ ready: false, missing: [selector], reason: 'not found' });
    const style = getComputedStyle(element);
    const disabled = element.disabled || element.getAttribute('aria-disabled') === 'true';
    const visible =
      style.display !== 'none' &&
      style.visibility !== 'hidden' &&
      style.pointerEvents !== 'none' &&
      element.getClientRects().length > 0;
    return JSON.stringify({
      ready: !disabled && visible,
      missing: [],
      reason: disabled ? 'disabled' : visible ? null : 'not actionable'
    });
  })()`);
}

function diagnosticValue(operation) {
  try {
    const value = operation();
    return typeof value === 'string' ? value || '(empty)' : JSON.stringify(value);
  } catch (e) {
    return `(unavailable: ${e.message})`;
  }
}

function readinessDiagnostics(selectors) {
  const finalState = diagnosticValue(() => probeSelectors(selectors));
  let missing = selectors;
  try {
    const parsed = JSON.parse(finalState);
    if (Array.isArray(parsed.missing)) missing = parsed.missing;
  } catch {
    // The final probe failure is still retained verbatim below.
  }

  const currentUrl = diagnosticValue(() => ab('get', 'url'));
  const navigation = diagnosticValue(() =>
    abEval(`(() => {
      const entry = performance.getEntriesByType('navigation')[0];
      if (!entry) return JSON.stringify({ type: 'unavailable' });
      return JSON.stringify({
        type: entry.type,
        startTime: entry.startTime,
        domContentLoadedEventEnd: entry.domContentLoadedEventEnd,
        loadEventEnd: entry.loadEventEnd,
        duration: entry.duration
      });
    })()`)
  );
  const consoleContext = diagnosticValue(() => ab('console'));
  const pageErrors = diagnosticValue(() => ab('errors'));

  return [
    `[readiness] current URL: ${currentUrl}`,
    `[readiness] missing selectors: ${missing.join(', ') || '(none reported)'}`,
    `[readiness] final selector probe: ${finalState}`,
    `[readiness] navigation timing/type: ${navigation}`,
    `[readiness] console: ${consoleContext}`,
    `[readiness] page errors: ${pageErrors}`,
  ].join('\n');
}

function withReadinessDiagnostics(label, selectors, operation) {
  try {
    return operation();
  } catch (e) {
    throw new Error(`${label}: ${e.message}\n${readinessDiagnostics(selectors)}`);
  }
}

function waitForSelectors(selectors, label, options = {}) {
  try {
    return retryBoundedly(label, () => {
      const state = probeSelectors(selectors);
      if (!state?.ready) {
        throw new Error(`missing selectors: ${(state?.missing || selectors).join(', ')}`);
      }
      return state;
    }, options);
  } catch (e) {
    throw new Error(`${e.message}\n${readinessDiagnostics(selectors)}`);
  }
}

function waitForActionableTarget(selector, label, options = {}) {
  try {
    return retryBoundedly(label, () => {
      const state = probeActionableTarget(selector);
      if (!state?.ready) throw new Error(state?.reason || `selector not actionable: ${selector}`);
      return state;
    }, options);
  } catch (e) {
    throw new Error(`${e.message}\n${readinessDiagnostics([selector])}`);
  }
}

function waitForDocumentReady(label, options = {}) {
  try {
    return retryBoundedly(label, () => {
      const state = abEval(`(() => JSON.stringify({
        ready: document.readyState === 'interactive' || document.readyState === 'complete',
        state: document.readyState
      }))()`);
      if (!state?.ready) throw new Error(`document.readyState=${state?.state || 'unknown'}`);
      return state;
    }, options);
  } catch (e) {
    throw new Error(`${e.message}\n${readinessDiagnostics([])}`);
  }
}

function waitForUrlNotContaining(fragment, label, options = {}) {
  try {
    return retryBoundedly(label, () => {
      const currentUrl = ab('get', 'url');
      if (currentUrl.includes(fragment)) {
        throw new Error(`current URL still contains "${fragment}": ${currentUrl}`);
      }
      return currentUrl;
    }, options);
  } catch (e) {
    throw new Error(`${e.message}\n${readinessDiagnostics([])}`);
  }
}

// ---------- Phase 1: login ----------

function login() {
  if (!account) return;
  const signInUrl = joinUrl(baseUrl, mapping.auth?.signin_path || '/');
  console.log(`[login] ${signInUrl}`);
  withReadinessDiagnostics('login navigation failed', [], () => ab('open', signInUrl));
  waitForDocumentReady('login document readiness');

  const authType = mapping.auth?.type || 'password';
  const notContains = mapping.auth?.verification?.url_not_contains;

  // Check if browser is already logged in (handles auth.type=manual or re-used session)
  const initialUrl = ab('get', 'url');
  const alreadyLoggedIn = notContains && !initialUrl.includes(notContains) && initialUrl.startsWith(baseUrl);
  if (alreadyLoggedIn) {
    console.log(`[login] already authenticated (${initialUrl}) — skipping`);
    return;
  }

  if (authType === 'password' || authType === 'email' || authType === 'manual') {
    // For manual: still try the email/password flow if credentials are provided in the account.
    // Manual in mapping just means "no automation preconfigured"; test_accounts having email+password
    // means we CAN auto-login via the generic form.
    if (!account.email || !account.password) {
      throw new Error(
        `auth.type=${authType} requires email+password in test_accounts, got keys: ${Object.keys(account).join(', ')}`
      );
    }
    let form;
    try {
      form = retryBoundedly('login form readiness', () => {
        const currentSnapshot = ab('snapshot', '-i');
        const email = currentSnapshot.match(/\btextbox\b[^\n]*(電子郵件|email|Email|E-mail)[^\n]*\[.*?ref=(e\d+)\]/);
        const password = currentSnapshot.match(/\btextbox\b[^\n]*(密碼|password|Password)[^\n]*\[.*?ref=(e\d+)\]/);
        if (!email || !password) {
          throw new Error(`email/password fields not found; snapshot head: ${currentSnapshot.slice(0, 400)}`);
        }
        return { snap: currentSnapshot, emailMatch: email, passMatch: password };
      });
    } catch (e) {
      throw new Error(`${e.message}\n${readinessDiagnostics([])}`);
    }
    const { snap, emailMatch, passMatch } = form;
    const submitMatch = snap.match(/button[^\n]*(登\s*入|Sign\s*in|Log\s*in)[^\n]*\[.*?ref=(e\d+)\]/);
    ab('fill', '@' + emailMatch[2], account.email);
    ab('fill', '@' + passMatch[2], account.password);
    if (submitMatch) {
      ab('click', '@' + submitMatch[2]);
    } else {
      ab('press', 'Enter');
    }
    if (notContains) waitForUrlNotContaining(notContains, 'login redirect readiness');
    else waitForDocumentReady('post-login document readiness');
  } else {
    throw new Error(`Unsupported auth.type: ${authType}`);
  }

  // Verify post-login
  if (notContains) {
    const currentUrl = ab('get', 'url');
    if (currentUrl.includes(notContains)) {
      throw new Error(`Login did not redirect away from "${notContains}". Current: ${currentUrl}`);
    }
  }
  console.log('[login] ok');
}

// ---------- Phase 2: setup ----------

function runSetup() {
  const steps = doc.setup || [];
  for (let i = 0; i < steps.length; i++) {
    const s = steps[i];
    console.log(`[setup ${i + 1}/${steps.length}] ${s.action}`);
    if (s.action === 'goto') {
      withReadinessDiagnostics(`setup step ${i + 1}: navigation failed`, [], () =>
        ab('open', joinUrl(baseUrl, s.url))
      );
      waitForDocumentReady(`setup step ${i + 1}: document readiness`, s);
    } else if (s.action === 'wait') {
      if (s.ms !== undefined) {
        sleep(positiveInteger(s.ms, undefined, `setup step ${i + 1}.ms`));
      }
      else if (s.for === 'networkidle') {
        waitForDocumentReady(`setup step ${i + 1}: document readiness`, s);
      }
    } else if (s.action === 'click' || s.action === 'fill' || s.action === 'press') {
      if (s.action === 'press') {
        ab('press', s.key || 'Enter');
        continue;
      }
      // Resolve selector through snapshot: agent-browser accepts direct selectors or @refN
      // Easiest path: just pass the selector. agent-browser click supports text=, css, etc.
      const selector = s.selector;
      if (!selector) throw new Error(`setup step ${i + 1}: ${s.action} requires selector`);
      if (s.action === 'click') {
        const stepTimeoutMs = positiveInteger(
          s.timeout_ms,
          readiness.timeoutMs,
          `setup step ${i + 1}.timeout_ms`
        );
        const stepStartedAt = Date.now();
        if (s.ensure !== undefined && s.ensure !== 'open') {
          throw new Error(`setup step ${i + 1}: click ensure must be "open"`);
        }
        if (s.ensure === 'open' && !s.postcondition) {
          throw new Error(`setup step ${i + 1}: ensure "open" requires postcondition`);
        }
        const remainingStepMs = () =>
          Math.max(1, stepTimeoutMs - (Date.now() - stepStartedAt));
        const alreadyOpen =
          s.ensure === 'open' &&
          withReadinessDiagnostics(
            `setup step ${i + 1}: postcondition probe failed`,
            [s.postcondition],
            () => withCommandTimeout(remainingStepMs(), () => selectorsExist([s.postcondition]))
          );
        if (alreadyOpen) {
          console.log(`[setup ${i + 1}/${steps.length}] already open (${s.postcondition}) — skipping click`);
          continue;
        }
        waitForActionableTarget(
          selector,
          `setup step ${i + 1}: selector "${selector}" readiness`,
          { ...s, timeout_ms: remainingStepMs() }
        );
        withReadinessDiagnostics(
          `setup step ${i + 1}: click failed`,
          [selector],
          () => withCommandTimeout(remainingStepMs(), () => ab('click', selector))
        );
        if (s.postcondition) {
          waitForSelectors(
            [s.postcondition],
            `setup step ${i + 1}: postcondition "${s.postcondition}"`,
            { ...s, timeout_ms: remainingStepMs() }
          );
        }
      } else {
        ab('fill', selector, s.value || '');
      }
    } else {
      throw new Error(`Unknown setup action: ${s.action}`);
    }
  }
}

// ---------- Phase 3: checks ----------

function runChecks() {
  const results = [];

  for (let i = 0; i < doc.checks.length; i++) {
    const check = doc.checks[i];
    console.log(`[check ${i + 1}/${doc.checks.length}] ${check.name}`);

    const expr = buildCheckExpr(check);
    let probed;
    try {
      probed = abEval(expr);
    } catch (e) {
      results.push({
        name: check.name,
        selector: check.selector,
        error: e.message.slice(0, 300),
        rows: [],
      });
      if (flags.bailOnFirstFail) break;
      continue;
    }

    const rows = [];

    if (probed && probed.err === 'NOT_FOUND') {
      results.push({
        name: check.name,
        selector: check.selector,
        error: `selector not found: ${check.selector}`,
        rows: [],
      });
      if (flags.bailOnFirstFail) break;
      continue;
    }

    const expect = check.expect || {};
    for (const [prop, expected] of Object.entries(expect)) {
      const actual = normalize(probed?.base?.[prop]);
      const exp = normalize(expected);
      rows.push({ prop, expected: exp, actual, pass: actual === exp });
    }
    const pseudo = check.pseudo || {};
    for (const [pseudoName, pseudoExpect] of Object.entries(pseudo)) {
      const pseudoVals = probed?.pseudo?.[pseudoName] || {};
      for (const [prop, expected] of Object.entries(pseudoExpect)) {
        const actual = normalize(pseudoVals[prop]);
        const exp = normalize(expected);
        rows.push({
          prop: `${pseudoName} ${prop}`,
          expected: exp,
          actual,
          pass: actual === exp,
        });
      }
    }

    results.push({
      name: check.name,
      selector: check.selector,
      rows,
      matched: probed?.matched,
    });

    if (flags.bailOnFirstFail && rows.some((r) => !r.pass)) break;
  }

  return results;
}

function buildCheckExpr(check) {
  const selector = JSON.stringify(check.selector);
  const baseProps = JSON.stringify(Object.keys(check.expect || {}));
  const pseudoMap = JSON.stringify(
    Object.fromEntries(
      Object.entries(check.pseudo || {}).map(([k, v]) => [k, Object.keys(v)])
    )
  );
  return `(() => {
    const el = document.querySelector(${selector});
    if (!el) return JSON.stringify({err: 'NOT_FOUND'});
    const base = getComputedStyle(el);
    const bProps = ${baseProps};
    const pMap = ${pseudoMap};
    const out = { matched: el.tagName + '.' + (el.className||'').toString().slice(0,60), base: {}, pseudo: {} };
    for (const p of bProps) out.base[p] = base[p];
    for (const name of Object.keys(pMap)) {
      const ps = getComputedStyle(el, name);
      out.pseudo[name] = {};
      for (const p of pMap[name]) out.pseudo[name][p] = ps[p];
    }
    return JSON.stringify(out);
  })()`;
}

// ---------- Phase 4: report ----------

function writeReport(results) {
  const reportsDir = path.resolve(CWD, '.claude/e2e/reports');
  fs.mkdirSync(reportsDir, { recursive: true });
  const stem = path.basename(flags.yamlPath, path.extname(flags.yamlPath));
  const stamp = new Date()
    .toISOString()
    .replace(/[:T]/g, '-')
    .replace(/\..*$/, '')
    .slice(0, 16);
  const reportPath = path.join(reportsDir, `verify-${stem}-${stamp}.md`);

  const totalChecks = results.reduce((n, r) => n + (r.rows?.length || 0), 0);
  const passChecks = results.reduce(
    (n, r) => n + (r.rows?.filter((x) => x.pass).length || 0),
    0
  );
  const errorCount = results.filter((r) => r.error).length;
  const overall = errorCount === 0 && passChecks === totalChecks ? 'PASS' : 'FAIL';

  let md = `# E2E Verify — ${doc.title}\n\n`;
  md += `**YAML:** \`${flags.yamlPath}\`\n`;
  md += `**Mapping:** \`${doc.mapping}\`${account ? ` (account \`${doc.auth_account}\`)` : ''}\n`;
  md += `**Run:** ${new Date().toISOString()}\n`;
  md += `**Result:** ${overall} (${passChecks}/${totalChecks} properties pass, ${errorCount} check errors)\n\n`;

  for (const r of results) {
    md += `## ${r.name}\n\n`;
    md += `- **Selector:** \`${r.selector}\`\n`;
    if (r.matched) md += `- **Matched:** \`${r.matched}\`\n`;
    if (r.error) {
      md += `- **Error:** ${r.error}\n\n`;
      continue;
    }
    md += '\n| Property | Expected | Actual | Result |\n';
    md += '|----------|----------|--------|--------|\n';
    for (const row of r.rows) {
      const mark = row.pass ? '✅' : '❌';
      md += `| \`${row.prop}\` | \`${row.expected}\` | \`${row.actual || '(empty)'}\` | ${mark} |\n`;
    }
    md += '\n';
  }

  fs.writeFileSync(reportPath, md, 'utf8');
  console.log(`\n[report] ${reportPath}`);
  console.log(`[result] ${overall} (${passChecks}/${totalChecks})`);
  return { overall, reportPath };
}

// ---------- orchestrate ----------

try {
  login();
  runSetup();
  const checkSelectors = doc.checks.map((check) => check.selector);
  console.log(`[readiness] waiting for ${new Set(checkSelectors).size} check selector(s)`);
  let results;
  try {
    waitForSelectors(checkSelectors, 'check selector readiness');
    results = runChecks();
  } catch (e) {
    console.error(`[readiness timeout]\n${e.message}`);
    let missing = checkSelectors;
    try {
      const finalState = probeSelectors(checkSelectors);
      if (Array.isArray(finalState?.missing)) missing = finalState.missing;
    } catch {
      // Preserve every declared selector as unresolved if the final probe itself fails.
    }
    results = doc.checks.map((check) => ({
      name: check.name,
      selector: check.selector,
      error: missing.includes(check.selector)
        ? `selector not found: ${check.selector}`
        : `check readiness incomplete; missing selectors: ${missing.join(', ')}`,
      rows: [],
    }));
  }
  const { overall } = writeReport(results);
  process.exit(overall === 'PASS' ? 0 : 1);
} catch (e) {
  console.error(`\n[error] ${e.message}`);
  process.exit(2);
}
