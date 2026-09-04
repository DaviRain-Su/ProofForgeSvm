#!/usr/bin/env python3
"""Fail when application policy leaks across ProofForge target ownership boundaries.

Also enforces productization P0 (prod-001):
- `ProofForge/Svm/Sdk/**` must not import Emit / Assemble / Registry.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / "Examples"
TARGET_ROOTS = (
    ROOT / "ProofForge" / "Svm",
)
SDK_ROOTS = (
    ROOT / "ProofForge" / "Svm" / "Sdk",
)
# Include the umbrella Sdk.lean files sitting beside the Sdk/ directories.
SDK_FILES_EXTRA = (
    ROOT / "ProofForge" / "Svm" / "Sdk.lean",
)

DIRECT_EMIT_IMPORT = re.compile(
    r"^\s*import\s+ProofForge\.Svm(?:\.[A-Za-z0-9_]+)*\.Emit\s*(?:--.*)?$",
    re.MULTILINE,
)
APPLICATION_IMPORT = re.compile(r"^\s*import\s+(?:Examples|Projects)(?:\.|\s|$)", re.MULTILINE)
PROTOCOL_VOCABULARY = re.compile(
    r"\b(?:Phoenix(?:V1)?|OrderPacket|MarketHeader|TraderState)\b", re.IGNORECASE
)
# Sdk must not reach compiler/backend surfaces for the same target family.
SDK_FORBIDDEN_IMPORT = re.compile(
    r"^\s*import\s+ProofForge\.(?P<target>Svm)(?:\.[A-Za-z0-9_]+)*\."
    r"(?P<kind>Emit|Assemble|Registry)(?:\.[A-Za-z0-9_]+)*\s*(?:--.*)?$",
    re.MULTILINE,
)


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def report(
    matches: list[str], path: Path, text: str, pattern: re.Pattern[str], message: str
) -> None:
    relative = path.relative_to(ROOT)
    for match in pattern.finditer(text):
        matches.append(
            f"{relative}:{line_number(text, match.start())}: {message}: {match.group(0).strip()}"
        )


def iter_sdk_files() -> list[Path]:
    files: list[Path] = []
    for root in SDK_ROOTS:
        if root.is_dir():
            files.extend(sorted(root.rglob("*.lean")))
    for path in SDK_FILES_EXTRA:
        if path.is_file():
            files.append(path)
    # Stable unique order
    return sorted(set(files), key=lambda p: str(p))


def main() -> int:
    failures: list[str] = []

    for path in sorted(EXAMPLES.rglob("*.lean")):
        text = path.read_text(encoding="utf-8")
        report(
            failures,
            path,
            text,
            DIRECT_EMIT_IMPORT,
            "applications must not import target Emit modules directly",
        )

    for path in iter_sdk_files():
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        for match in SDK_FORBIDDEN_IMPORT.finditer(text):
            # Only same-target leakage is in scope for P0 (Svm Sdk → Svm.Emit, etc.).
            target = match.group("target")
            if f"ProofForge/{target}/" in rel.as_posix() or rel.as_posix().startswith(
                f"ProofForge/{target}/"
            ):
                failures.append(
                    f"{rel}:{line_number(text, match.start())}: "
                    f"SDK modules must not import {match.group('kind')}: "
                    f"{match.group(0).strip()}"
                )

    target_paths = [path for target_root in TARGET_ROOTS for path in target_root.rglob("*.lean")]
    for path in sorted(target_paths):
        if path.name == "Registry.lean":
            continue
        text = path.read_text(encoding="utf-8")
        report(
            failures,
            path,
            text,
            APPLICATION_IMPORT,
            "target-owned modules must not import application modules",
        )
        report(
            failures,
            path,
            text,
            PROTOCOL_VOCABULARY,
            "protocol vocabulary belongs in Examples, not generic target modules",
        )

    if failures:
        print("ownership boundary violations:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1

    print("ownership boundaries: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
