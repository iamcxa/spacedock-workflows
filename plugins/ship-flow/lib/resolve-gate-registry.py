#!/usr/bin/env python3
"""Resolve adopter gate registry routes for ship-flow task files.

The parser intentionally supports the small YAML subset used by
`.claude/ship-flow/gates.yaml` so adopter repos do not need extra dependencies.
"""

from __future__ import annotations

import argparse
import fnmatch
import sys
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class GateRoute:
    name: str = ""
    signals: list[str] = field(default_factory=list)
    layer: str = ""
    gates: list[str] = field(default_factory=list)
    reviewer_questions: list[str] = field(default_factory=list)
    evidence_required: list[str] = field(default_factory=list)


def parse_inline_list(value: str) -> list[str]:
    value = value.strip()
    if not (value.startswith("[") and value.endswith("]")):
        return []
    body = value[1:-1].strip()
    if not body:
        return []
    return [item.strip().strip("\"'") for item in body.split(",") if item.strip()]


def parse_routes(config_path: Path) -> list[GateRoute]:
    routes: list[GateRoute] = []
    current: GateRoute | None = None

    for raw_line in config_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.rstrip()
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if line.startswith("  - name: "):
            if current and current.name:
                routes.append(current)
            current = GateRoute(name=line.split(":", 1)[1].strip().strip("\"'"))
            continue
        if current is None or not line.startswith("    "):
            continue
        key, sep, value = stripped.partition(":")
        if not sep:
            continue
        value = value.strip()
        if key == "signals":
            current.signals = parse_inline_list(value)
        elif key == "layer":
            current.layer = value.strip("\"'")
        elif key == "gates":
            current.gates = parse_inline_list(value)
        elif key == "reviewer_questions":
            current.reviewer_questions = parse_inline_list(value)
        elif key == "evidence_required":
            current.evidence_required = parse_inline_list(value)

    if current and current.name:
        routes.append(current)
    return routes


def unique_extend(items: list[str], additions: list[str]) -> list[str]:
    for item in additions:
        if item and item not in items:
            items.append(item)
    return items


def route_matches(route: GateRoute, files: list[str]) -> bool:
    for signal in route.signals:
        for file_path in files:
            if fnmatch.fnmatchcase(file_path, signal):
                return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Resolve adopter gate registry against task files.")
    parser.add_argument("--config", type=Path, default=Path(".claude/ship-flow/gates.yaml"))
    parser.add_argument("--files", required=True, help="Comma-separated task file paths")
    args = parser.parse_args()

    if not args.config.exists():
        print("status=config_missing", file=sys.stderr)
        print(f"config={args.config}", file=sys.stderr)
        return 11

    files = [item.strip() for item in args.files.split(",") if item.strip()]
    matched_names: list[str] = []
    layers: list[str] = []
    gates: list[str] = []
    questions: list[str] = []
    evidence: list[str] = []

    for route in parse_routes(args.config):
        if not route_matches(route, files):
            continue
        matched_names.append(route.name)
        unique_extend(layers, [route.layer])
        unique_extend(gates, route.gates)
        unique_extend(questions, route.reviewer_questions)
        unique_extend(evidence, route.evidence_required)

    print(f"status={'ok' if matched_names else 'no_match'}")
    print(f"matched_routes={','.join(matched_names)}")
    print(f"layers={','.join(layers)}")
    print(f"required_gates={','.join(gates)}")
    print(f"reviewer_questions={'; '.join(questions)}")
    print(f"evidence_required={'; '.join(evidence)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
