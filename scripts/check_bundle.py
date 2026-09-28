#!/usr/bin/env python3
"""Read-only starter-package check. It does not build or test MacSoul."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

try:
    import tomllib
except ImportError:
    tomllib = None

REQUIRED = [
    "README.md", "AGENTS.md", "CLAUDE.md", "START-HERE.md", ".codex/config.toml",
    "docs/PRD.md", "docs/SCOPE.md", "docs/DESIGN.md", "docs/ARCHITECTURE.md",
    "docs/7-DAY-PLAN.md", "docs/STATUS.md", "docs/PROGRESS-PROTOCOL.md",
    "docs/MODEL-STRATEGY.md", "docs/INTEGRATION-NOTES.md", "prompts/BOOTSTRAP.md",
    "review/AUDIT.md", "review/CODEX-HARDENING-PROMPT.md", "review/README.md",
    "review/static-checks.json", "review/tasks.example.json",
    "MacSoul/App/MacSoulApp.swift", "MacSoul/MenuBar/MenuBarContentView.swift",
    "MacSoul/Models/MockStore.swift", "MacSoul/Models/MacSoulModels.swift",
    "DAY1-DESIGN-LOCK.md", "CODEX-DAY1-PROMPT.md", "MANIFEST.md", "BUNDLE-MANIFEST.json"
]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hashes", action="store_true", help="Check initial release hashes; expected to differ after edits.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    root = args.root.resolve()
    errors, warnings = [], []
    for rel in REQUIRED:
        if not (root / rel).is_file():
            errors.append("missing file: " + rel)
    json_count = 0
    for rel in ["review/static-checks.json", "review/tasks.example.json", "BUNDLE-MANIFEST.json", "BUNDLE-CHECKS.json"]:
        p = root / rel
        if p.is_file():
            try:
                json.loads(p.read_text(encoding="utf-8"))
                json_count += 1
            except (ValueError, OSError) as exc:
                errors.append(f"invalid JSON {rel}: {exc}")
    toml_paths = [root / ".codex/config.toml"]
    toml_paths.extend((root / "templates/codex-family-original").rglob("*.toml"))
    toml_count = 0
    if tomllib is None:
        warnings.append("TOML syntax NOT_RUN: use Python 3.11+ to include this check.")
    else:
        for p in toml_paths:
            if not p.is_file():
                continue
            try:
                tomllib.loads(p.read_text(encoding="utf-8"))
                toml_count += 1
            except (ValueError, OSError) as exc:
                errors.append(f"invalid TOML {p.relative_to(root)}: {exc}")
    swift_count = len(list((root / "MacSoul").rglob("*.swift")))
    if swift_count < 16:
        warnings.append(f"Found {swift_count} Swift files; initial package includes 16. Confirm whether intentional refactoring occurred.")
    hash_count = 0
    if args.hashes and (root / "BUNDLE-MANIFEST.json").is_file():
        try:
            manifest = json.loads((root / "BUNDLE-MANIFEST.json").read_text(encoding="utf-8"))
            for entry in manifest["files"]:
                rel = entry["path"]
                p = (root / rel).resolve()
                if p == root or root not in p.parents:
                    errors.append("unsafe manifest path: " + rel)
                    continue
                if not p.is_file():
                    errors.append("missing original file: " + rel)
                elif hashlib.sha256(p.read_bytes()).hexdigest() != entry["sha256"]:
                    errors.append("changed from initial package: " + rel)
                hash_count += 1
        except (KeyError, TypeError, ValueError, OSError) as exc:
            errors.append("manifest validation failed: " + str(exc))
    result = {
        "check_kind": "starter_package_only",
        "status": "FAIL" if errors else "PASS",
        "required_paths_checked": len(REQUIRED),
        "json_parsed": json_count,
        "toml_parsed": toml_count,
        "swift_files_found": swift_count,
        "initial_hashes_checked": hash_count,
        "errors": errors,
        "warnings": warnings,
        "app_build": "NOT_RUN",
        "app_unit_tests": "NOT_RUN",
        "manual_ui": "NOT_RUN",
        "performance": "NOT_RUN"
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main())
