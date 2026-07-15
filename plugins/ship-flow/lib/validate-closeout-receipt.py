#!/usr/bin/env python3
"""Validate a v1 Ship-Flow closeout receipt without third-party packages."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any, NoReturn

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
REPOSITORY_RE = re.compile(r"^[^/\s]+/[^/\s]+$")
WORKFLOW_RE = re.compile(r"^docs/[^/]+$")
SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
PHASES = ("prepared", "awaiting_closeout_pr", "applied", "complete")


def fail(reason: str, detail: str) -> NoReturn:
    print("verdict=STOP")
    print(f"reason={reason}")
    print(f"detail={detail}")
    raise SystemExit(1)


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")


def sha256_hex(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def require_object(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail("closeout-sentinel-invalid", f"{label} must be an object")
    return value


def require_exact_keys(value: dict[str, Any], keys: set[str], label: str) -> None:
    missing = sorted(keys - value.keys())
    extra = sorted(value.keys() - keys)
    if missing or extra:
        fail(
            "closeout-sentinel-invalid",
            f"{label} keys mismatch; missing={missing}, extra={extra}",
        )


def require_hash(value: Any, label: str) -> str:
    if not isinstance(value, str) or not SHA256_RE.fullmatch(value):
        fail("closeout-sentinel-invalid", f"{label} must be lowercase sha256")
    return value


def closeout_id(identity: dict[str, Any]) -> str:
    parts = (
        "v1",
        identity["provider"],
        identity["repository"],
        identity["workflow"],
        identity["entity_slug"],
        str(identity["implementation_pr"]),
    )
    return sha256_hex("\0".join(parts).encode("utf-8"))


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail("closeout-sentinel-invalid", f"cannot read canonical JSON: {exc}")
    return require_object(value, "receipt")


def safe_repo_path(repo_root: Path, relative: Any, label: str) -> Path:
    if not isinstance(relative, str) or not relative:
        fail("closeout-sentinel-invalid", f"{label} must be a nonempty repo-relative path")
    logical = PurePosixPath(relative)
    if logical.is_absolute() or any(part in ("", ".", "..") for part in logical.parts):
        fail("closeout-sentinel-invalid", f"{label} contains absolute/traversal components")
    root = Path(os.path.abspath(repo_root))
    candidate = root.joinpath(*logical.parts)
    current = root
    if current.is_symlink():
        fail("closeout-sentinel-invalid", f"{label} repo root is a symlink")
    for part in logical.parts:
        current = current / part
        if current.is_symlink():
            fail("closeout-sentinel-invalid", f"{label} contains a symlink component")
    resolved_root = root.resolve()
    resolved_candidate = candidate.resolve()
    if resolved_candidate != resolved_root and resolved_root not in resolved_candidate.parents:
        fail("closeout-sentinel-invalid", f"{label} escapes repo root")
    return candidate


def validate_supplied_repo_path(repo_root: Path, supplied: Path, label: str) -> Path:
    root = Path(os.path.abspath(repo_root))
    candidate = Path(os.path.abspath(supplied))
    try:
        relative = candidate.relative_to(root)
    except ValueError:
        fail("closeout-sentinel-invalid", f"{label} is lexically outside repo root")
    return safe_repo_path(root, relative.as_posix(), label)


def hash_file(path: Path, label: str) -> str:
    if not path.is_file():
        fail("closeout-stage-artifacts-incoherent", f"missing {label}: {path}")
    try:
        return sha256_hex(path.read_bytes())
    except OSError as exc:
        fail("closeout-stage-artifacts-incoherent", f"cannot read {label}: {exc}")


def verify_output_bytes(receipt: dict[str, Any], repo_root: Path) -> None:
    outputs = receipt["outputs"]
    for key in ("debrief", "ship", "archived_entity"):
        artifact = outputs[key]
        path = safe_repo_path(repo_root, artifact["path"], f"outputs.{key}.path")
        if hash_file(path, f"output {key}") != artifact["sha256"]:
            fail("closeout-sentinel-payload-mismatch", f"landed bytes differ for output {key}")
    roadmap_path = safe_repo_path(repo_root, "ROADMAP.md", "ROADMAP path")
    if not roadmap_path.is_file():
        fail("closeout-stage-artifacts-incoherent", "ROADMAP.md is missing")
    try:
        lines = roadmap_path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as exc:
        fail("closeout-stage-artifacts-incoherent", f"cannot read ROADMAP.md: {exc}")
    opens = [index for index, line in enumerate(lines) if line.strip() == "<!-- section:shipped -->"]
    closes = [index for index, line in enumerate(lines) if line.strip() == "<!-- /section:shipped -->"]
    if len(opens) != 1 or len(closes) != 1 or opens[0] >= closes[0]:
        fail("closeout-stage-artifacts-incoherent", "ROADMAP must contain one bounded Shipped section")
    identity = outputs["roadmap_row"]["identity"]
    matched_rows: list[str] = []
    for line in lines[opens[0] + 1 : closes[0]]:
        stripped = line.strip()
        if not (stripped.startswith("|") and stripped.endswith("|")):
            continue
        cells = [cell.strip() for cell in stripped[1:-1].split("|")]
        if len(cells) < 2 or all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        if identity in cells:
            matched_rows.append(line)
    if len(matched_rows) != 1:
        fail("closeout-stage-artifacts-incoherent", "ROADMAP identity must be one exact Shipped table cell")
    if sha256_hex(matched_rows[0].encode("utf-8")) != outputs["roadmap_row"]["sha256"]:
        fail("closeout-sentinel-payload-mismatch", "landed ROADMAP row bytes differ")


def verify_source_bytes(receipt: dict[str, Any], repo_root: Path) -> None:
    identity = receipt["identity"]
    base = safe_repo_path(
        repo_root,
        f"{identity['workflow']}/{identity['entity_slug']}",
        "owning entity source path",
    )
    expected = receipt["ownership_proof"]["source_hashes"]
    for key, filename in (("index", "index.md"), ("review", "review.md"), ("ship", "ship.md")):
        actual = hash_file(base / filename, f"source {key}")
        if actual != expected[key]:
            fail("closeout-projection-source-drift", f"source bytes differ for {key}")


def validate(receipt: dict[str, Any], path: Path | None = None) -> None:
    required = {
        "schema_version",
        "kind",
        "closeout_id",
        "identity",
        "ownership_proof",
        "mode",
        "merge_method_intent",
        "deterministic_closeout_head",
        "landing_proof",
        "transaction",
        "outputs",
        "proof_hash",
    }
    missing = sorted(required - receipt.keys())
    if missing:
        fail("closeout-sentinel-invalid", f"missing receipt keys: {missing}")
    if receipt["schema_version"] != 1 or receipt["kind"] != "ship-flow.closeout":
        fail("closeout-sentinel-invalid", "unsupported schema_version or kind")

    identity = require_object(receipt["identity"], "identity")
    require_exact_keys(
        identity,
        {"provider", "repository", "workflow", "entity_slug", "implementation_pr"},
        "identity",
    )
    if identity["provider"] != "github":
        fail("closeout-sentinel-invalid", "provider must be github in schema v1")
    if not isinstance(identity["repository"], str) or not REPOSITORY_RE.fullmatch(identity["repository"]):
        fail("closeout-sentinel-invalid", "repository must be owner/name")
    if not isinstance(identity["workflow"], str) or not WORKFLOW_RE.fullmatch(identity["workflow"]):
        fail("closeout-sentinel-invalid", "workflow must be docs/<workflow>")
    if not isinstance(identity["entity_slug"], str) or not SLUG_RE.fullmatch(identity["entity_slug"]):
        fail("closeout-sentinel-invalid", "entity_slug is invalid")
    pr = identity["implementation_pr"]
    if isinstance(pr, bool) or not isinstance(pr, int) or pr < 1:
        fail("closeout-sentinel-invalid", "implementation_pr must be positive integer")

    expected_id = closeout_id(identity)
    if receipt["closeout_id"] != expected_id:
        fail("closeout-sentinel-identity-mismatch", "closeout_id does not match identity")
    if path is not None and path.name != f"{expected_id}.json":
        fail("closeout-id-path-mismatch", "receipt basename does not match closeout_id")
    if receipt["deterministic_closeout_head"] != f"ship-closeout/{expected_id}":
        fail("closeout-sentinel-identity-mismatch", "deterministic head is not identity-bound")

    ownership = require_object(receipt["ownership_proof"], "ownership_proof")
    require_exact_keys(ownership, {"unique_entity_matches", "participant_entities", "source_hashes"}, "ownership_proof")
    participants = ownership["participant_entities"]
    if not isinstance(participants, list):
        fail("closeout-owner-not-unique", "participant_entities must be an array")
    matches = ownership["unique_entity_matches"]
    if isinstance(matches, bool) or not isinstance(matches, int) or matches != len(participants) + 1:
        fail("closeout-owner-not-unique", "unique_entity_matches must equal owner plus participant count")
    slugs: set[str] = set()
    for slug in participants:
        if not isinstance(slug, str) or not SLUG_RE.fullmatch(slug) or slug in slugs or slug == identity["entity_slug"]:
            fail("closeout-owner-not-unique", "participant slugs must be valid and unique")
        slugs.add(slug)
    hashes = require_object(ownership["source_hashes"], "source_hashes")
    require_exact_keys(hashes, {"index", "review", "ship"}, "source_hashes")
    for key, value in hashes.items():
        require_hash(value, f"source_hashes.{key}")

    if receipt["mode"] not in ("direct", "pull_request"):
        fail("closeout-sentinel-invalid", "mode is invalid")
    if receipt["merge_method_intent"] not in (None, "rebase", "squash", "merge_commit"):
        fail("closeout-sentinel-invalid", "merge_method_intent is invalid")
    landing = require_object(receipt["landing_proof"], "landing_proof")
    if not landing:
        fail("closeout-sentinel-invalid", "landing_proof cannot be empty")

    transaction = require_object(receipt["transaction"], "transaction")
    require_exact_keys(transaction, {"phase", "generation", "closeout_pr", "main_commit"}, "transaction")
    if transaction["phase"] not in PHASES:
        fail("closeout-sentinel-invalid", "transaction phase is invalid")
    generation = transaction["generation"]
    if isinstance(generation, bool) or not isinstance(generation, int) or generation < 1:
        fail("closeout-sentinel-invalid", "generation must be positive integer")
    closeout_pr = transaction["closeout_pr"]
    if closeout_pr is not None and (isinstance(closeout_pr, bool) or not isinstance(closeout_pr, int) or closeout_pr < 1):
        fail("closeout-sentinel-invalid", "closeout_pr must be null or positive integer")
    main_commit = transaction["main_commit"]
    if main_commit is not None and (not isinstance(main_commit, str) or not SHA40_RE.fullmatch(main_commit)):
        fail("closeout-sentinel-invalid", "main_commit must be null or full sha")
    phase = transaction["phase"]
    mode = receipt["mode"]
    if phase == "awaiting_closeout_pr" and mode != "pull_request":
        fail("closeout-checkpoint-conflict", "only pull_request mode may await closeout PR")
    if mode == "direct" and closeout_pr is not None:
        fail("closeout-checkpoint-conflict", "direct mode cannot bind closeout_pr")
    if phase == "prepared" and (closeout_pr is not None or main_commit is not None):
        fail("closeout-checkpoint-conflict", "prepared phase cannot bind external checkpoints")
    if phase == "awaiting_closeout_pr" and (closeout_pr is None or main_commit is not None):
        fail("closeout-checkpoint-conflict", "awaiting phase requires PR and forbids main commit")
    if phase in ("applied", "complete") and main_commit is None:
        fail("closeout-checkpoint-conflict", "applied/complete phase requires authoritative main commit")
    if phase in ("applied", "complete"):
        landing_anchor = landing.get("landing_anchor")
        if not isinstance(landing_anchor, str) or not SHA40_RE.fullmatch(landing_anchor):
            fail("closeout-sentinel-invalid", "applied/complete landing proof requires a full landing_anchor sha")
        if main_commit != landing_anchor:
            fail(
                "closeout-checkpoint-conflict",
                "main_commit must equal the implementation PR authoritative landing_anchor",
            )
    if mode == "pull_request" and phase in ("applied", "complete") and closeout_pr is None:
        fail("closeout-checkpoint-conflict", "applied PR closeout must retain closeout_pr")

    outputs = require_object(receipt["outputs"], "outputs")
    require_exact_keys(outputs, {"debrief", "ship", "archived_entity", "roadmap_row"}, "outputs")
    for key in ("debrief", "ship", "archived_entity"):
        artifact = require_object(outputs[key], f"outputs.{key}")
        require_exact_keys(artifact, {"path", "sha256"}, f"outputs.{key}")
        if not isinstance(artifact["path"], str) or not artifact["path"]:
            fail("closeout-sentinel-invalid", f"outputs.{key}.path must be nonempty")
        require_hash(artifact["sha256"], f"outputs.{key}.sha256")
    roadmap = require_object(outputs["roadmap_row"], "outputs.roadmap_row")
    require_exact_keys(roadmap, {"identity", "sha256"}, "outputs.roadmap_row")
    if not isinstance(roadmap["identity"], str) or not roadmap["identity"]:
        fail("closeout-sentinel-invalid", "roadmap identity must be nonempty")
    require_hash(roadmap["sha256"], "outputs.roadmap_row.sha256")

    payload = {key: receipt[key] for key in ("identity", "ownership_proof", "landing_proof", "outputs")}
    expected_proof = sha256_hex(canonical_bytes(payload))
    if receipt["proof_hash"] != expected_proof:
        fail("closeout-sentinel-payload-mismatch", "proof_hash does not bind canonical payload")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--receipt", required=True, type=Path)
    parser.add_argument("--previous", type=Path)
    parser.add_argument("--repo-root", type=Path)
    parser.add_argument("--verify-outputs", action="store_true")
    parser.add_argument("--verify-sources", action="store_true")
    parser.add_argument("--allow-any-path", action="store_true")
    args = parser.parse_args()

    if args.repo_root is None and not args.allow_any_path:
        fail("closeout-sentinel-invalid", "--repo-root is required for canonical receipt validation")
    if (args.verify_outputs or args.verify_sources) and args.repo_root is None:
        fail("closeout-sentinel-invalid", "byte verification requires --repo-root")
    if args.repo_root is not None and not args.allow_any_path:
        validate_supplied_repo_path(args.repo_root, args.receipt, "canonical receipt path")
    receipt = load_json(args.receipt)
    validate(receipt, None if args.allow_any_path else args.receipt)
    if args.repo_root is not None and not args.allow_any_path:
        expected_path = safe_repo_path(
            args.repo_root,
            f"{receipt['identity']['workflow']}/_closeouts/{receipt['closeout_id']}.json",
            "canonical receipt path",
        )
        if Path(os.path.abspath(args.receipt)) != expected_path:
            fail("closeout-sentinel-invalid", "receipt is outside canonical _closeouts location")
    if args.verify_outputs:
        verify_output_bytes(receipt, args.repo_root)
    if args.verify_sources:
        verify_source_bytes(receipt, args.repo_root)
    if args.previous:
        previous = load_json(args.previous)
        validate(previous)
        frozen = ("identity", "mode", "merge_method_intent", "deterministic_closeout_head")
        if any(previous[key] != receipt[key] for key in frozen):
            fail("closeout-checkpoint-conflict", "immutable closeout identity or intent changed")
        if previous["proof_hash"] != receipt["proof_hash"]:
            fail("closeout-proof-hash-mismatch", "payload changed across transaction phase")
        payload_keys = ("identity", "ownership_proof", "landing_proof", "outputs")
        if any(previous[key] != receipt[key] for key in payload_keys):
            fail("closeout-proof-hash-mismatch", "proof payload changed across transaction phase")
        if previous == receipt:
            pass
        else:
            old_tx = previous["transaction"]
            new_tx = receipt["transaction"]
            legal = {
                "direct": {("prepared", "applied"), ("applied", "complete")},
                "pull_request": {
                    ("prepared", "awaiting_closeout_pr"),
                    ("awaiting_closeout_pr", "applied"),
                    ("applied", "complete"),
                },
            }
            if (old_tx["phase"], new_tx["phase"]) not in legal[receipt["mode"]]:
                fail("closeout-checkpoint-conflict", "illegal closeout phase transition")
            if new_tx["generation"] != old_tx["generation"] + 1:
                fail("closeout-checkpoint-conflict", "generation must increment exactly once")
            if old_tx["closeout_pr"] is not None and new_tx["closeout_pr"] != old_tx["closeout_pr"]:
                fail("closeout-checkpoint-conflict", "closeout_pr changed after binding")
            if old_tx["main_commit"] is not None and new_tx["main_commit"] != old_tx["main_commit"]:
                fail("closeout-checkpoint-conflict", "main_commit changed after binding")

    print(f"closeout_id={receipt['closeout_id']}")
    print(f"proof_hash={receipt['proof_hash']}")
    print(f"phase={receipt['transaction']['phase']}")
    print("verdict=OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
