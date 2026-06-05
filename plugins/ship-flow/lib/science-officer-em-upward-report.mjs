const ROUTES = new Set(["proceed", "narrow", "return", "block", "costly_no"]);
const CONFIDENCE = new Set(["high", "medium", "low"]);

const REQUIRED_FIELDS = [
  "subject",
  "em_judgment",
  "evidence_synthesis",
  "risk_tradeoff_call",
  "recommendation",
  "route",
  "confidence",
  "fo_boundary",
];

const REQUIRED_SUBJECT_FIELDS = ["entity", "stage", "report_kind"];

const RELAY_PATTERNS = [
  /\bstatus\s*:\s*passed\b/i,
  /\ball green\b/i,
  /\bno blockers?\b/i,
  /\bworkers? completed tasks?\b/i,
  /\breviewers? (?:said )?pass(?:ed)?\b/i,
  /\bworker said done\b/i,
  /\bFO says\b/i,
];

const FO_MECHANICS_PATTERNS = [
  /\b(?:EM|Science[- ]Officer|Engineering Manager)\b[^.;\n]*\b(?:mutate|mutates|advance|advances|create|creates|merge|merges|merging|dispatch|dispatches|own|owns|manage|manages|handle|handles|assigned|responsible|responsibility|accountable|accountability|coordinate|coordinates|coordination)\b[^.;\n]*\b(?:entity status|state|stage advancement|PR creation|PR|pull request|merge coordination|merge|merging|workers?|worktrees?|dispatch|workflow mechanics)\b/i,
  /\b(?:entity status|stage advancement|PR creation|PR|pull request|merge coordination|merge|merging|workers?|worktrees?|dispatch|workflow mechanics)\b[^.;\n]*\b(?:mutated|advanced|created|merged|dispatched|owned|managed|handled|assigned|coordinated)\b[^.;\n]*\bby\s+(?:EM|Science[- ]Officer|Engineering Manager)\b/i,
];

const VERSIONED_VERIFICATION_PATTERN = /\bV\d+(?:\.\d+)?\b\s*(?::|-)\s*\S.{8,}/i;
const COMMAND_OUTPUT_PATTERN =
  /\b(?:command output|command evidence|exit code|status=pass|OK C\d+|returned \d+|failed \d+|passed \d+|\d+\s+(?:passed|pass|failed|fail))\b/i;
const COMMAND_LINE_PATTERN = /\b(?:bash|node|python3?|npm|pnpm|yarn|git|spacedock)\s+[-./:=@A-Za-z0-9_ ]{5,}/i;
const REVIEWER_FINDING_PATTERN =
  /\b(?:reviewer finding|review finding|Panel Coverage|quality gate|kc_pr_review|local_review)\b\s*:?\s*\S.{8,}/i;
const COMMIT_PR_ARTIFACT_PATTERN =
  /\b(?:commit\s+[0-9a-f]{7,40}|PR\s+#?\d+|pull request\s+#?\d+|entity\s+[A-Za-z0-9._/-]+|(?:stage\s+)?artifact\s+[A-Za-z0-9._/-]+)\b/i;
const SHA_PATTERN = /\b[0-9a-f]{7,40}\b/i;
const DURABLE_PATH_PATTERN =
  /\b(?:\.claude|docs|plugins|src|lib|bin|test|tests|__tests__|app|components|pages|packages|scripts)\/[-A-Za-z0-9_./]+\.(?:md|mjs|js|ts|tsx|json|jsonl|yaml|yml|sh|txt)\b/;

const MISSING_EVIDENCE_PATTERNS = [
  /\b(?:missing|absent|unavailable|omitted|not found|lacks?|no evidence)\b/i,
];

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function stringifyReport(report) {
  return JSON.stringify(report, null, 2);
}

function hasRelayOnlyLanguage(report) {
  const judgmentText = [
    report.em_judgment,
    report.risk_tradeoff_call,
    report.recommendation,
  ].filter(isNonEmptyString).join("\n");
  if (RELAY_PATTERNS.some((pattern) => pattern.test(judgmentText))) {
    return true;
  }
  const body = stringifyReport({
    status: report.status,
    checklist: report.checklist,
    worker_summary: report.worker_summary,
  });
  return RELAY_PATTERNS.some((pattern) => pattern.test(body));
}

function hasFoOwnedMechanics(report) {
  const sentences = stringifyReport(report)
    .split(/[.\n]/)
    .map((sentence) => sentence.trim())
    .filter(Boolean);
  return sentences.some((sentence) => FO_MECHANICS_PATTERNS.some((pattern) => pattern.test(sentence)));
}

function validateRequiredShape(report, errors) {
  for (const field of REQUIRED_FIELDS) {
    if (!(field in report)) {
      errors.push(`missing required field: ${field}`);
    }
  }

  if (isObject(report.subject)) {
    for (const field of REQUIRED_SUBJECT_FIELDS) {
      if (!isNonEmptyString(report.subject[field])) {
        errors.push(`missing required subject field: ${field}`);
      }
    }
  } else if ("subject" in report) {
    errors.push("subject must be an object");
  }

  for (const field of ["em_judgment", "risk_tradeoff_call", "recommendation", "fo_boundary"]) {
    if (field in report && !isNonEmptyString(report[field])) {
      errors.push(`${field} must be a non-empty string`);
    }
  }

  if ("evidence_synthesis" in report) {
    if (!Array.isArray(report.evidence_synthesis)) {
      errors.push("evidence_synthesis must be an array");
    } else if (report.evidence_synthesis.filter(isNonEmptyString).length < 2) {
      errors.push("evidence_synthesis must include at least two evidence items");
    } else {
      validateEvidenceSynthesis(report.evidence_synthesis, report.route, errors);
    }
  }

  if ("route" in report && !ROUTES.has(report.route)) {
    errors.push(`route must be one of: ${Array.from(ROUTES).join(", ")}`);
  }

  if ("confidence" in report && !CONFIDENCE.has(report.confidence)) {
    errors.push(`confidence must be one of: ${Array.from(CONFIDENCE).join(", ")}`);
  }
}

function hasSourceLikeSubstance(item, route) {
  if (
    VERSIONED_VERIFICATION_PATTERN.test(item) ||
    COMMAND_OUTPUT_PATTERN.test(item) ||
    COMMAND_LINE_PATTERN.test(item) ||
    REVIEWER_FINDING_PATTERN.test(item) ||
    COMMIT_PR_ARTIFACT_PATTERN.test(item) ||
    SHA_PATTERN.test(item) ||
    DURABLE_PATH_PATTERN.test(item)
  ) {
    return true;
  }
  if (["return", "block", "costly_no"].includes(route)) {
    return MISSING_EVIDENCE_PATTERNS.some((pattern) => pattern.test(item));
  }
  return false;
}

function validateEvidenceSynthesis(items, route, errors) {
  const weakItems = items
    .filter(isNonEmptyString)
    .filter((item) => !hasSourceLikeSubstance(item, route));
  if (weakItems.length > 0) {
    errors.push(
      "evidence_synthesis entries must include source-like substance: file/path refs, command/test/check output, reviewer finding, commit/PR/entity artifact, or explicit missing-evidence rationale for return/block/costly_no",
    );
  }
}

function validateJudgment(report, errors) {
  if (hasRelayOnlyLanguage(report)) {
    errors.push("report reads as a relay/digest instead of independent EM judgment");
  }

  if (hasFoOwnedMechanics(report)) {
    errors.push("report grants EM FO-owned workflow mechanics such as state, dispatch, worktrees, PR, merge, or stage advancement");
  }

  if (isNonEmptyString(report.fo_boundary)) {
    const boundary = report.fo_boundary;
    if (!/FO owns/i.test(boundary) || !/EM owns/i.test(boundary)) {
      errors.push("fo_boundary must state that FO owns workflow mechanics and EM owns judgment/recommendation");
    }
  }
}

export function validateScienceOfficerEmUpwardReport(input) {
  const errors = [];
  const report = input?.science_officer_em_upward_report;

  if (!isObject(report)) {
    return {
      valid: false,
      errors: ["missing science_officer_em_upward_report object"],
    };
  }

  validateRequiredShape(report, errors);
  validateJudgment(report, errors);

  return {
    valid: errors.length === 0,
    errors,
  };
}

export const scienceOfficerEmUpwardReportContract = {
  block: "science_officer_em_upward_report",
  required_fields: REQUIRED_FIELDS,
  routes: Array.from(ROUTES),
  confidence: Array.from(CONFIDENCE),
};
