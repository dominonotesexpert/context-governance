#!/usr/bin/env python3
"""Migrate .governance/attestations/*.receipt.yaml files to the latest schema.

Usage
-----
    migrate-receipts.py [--target DIR] [--dry-run|--write] [--backup-dir PATH]

Defaults
--------
--dry-run is the default. --write requires --backup-dir to avoid data loss.

Exit codes
----------
0 : nothing to do, or all files processed successfully
1 : at least one file failed to migrate (output lists the failures)
2 : misuse of the CLI (e.g., --write without --backup-dir)

Authority: docs/plans/2026-04-23-governance-kernel-v2-implementation-plan.md Step D
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

# Ensure the governance-mcp-server package is importable when invoked from
# the repository root.
_REPO_ROOT = Path(__file__).resolve().parent.parent
_MCP_DIR = _REPO_ROOT / "governance-mcp-server"
if str(_MCP_DIR) not in sys.path:
    sys.path.insert(0, str(_MCP_DIR))

from migrations import CURRENT_VERSION, MigrationError, upgrade_in_memory  # noqa: E402
from migrations.serializer import dump_receipt  # noqa: E402


def _find_project_root(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).resolve()
    # Walk up from CWD to find a .governance/ directory.
    current = Path.cwd().resolve()
    for candidate in [current, *current.parents]:
        if (candidate / ".governance").is_dir():
            return candidate
    # Fall back to repo root so the CLI still works from within the framework.
    return _REPO_ROOT


def _read_receipt_text(path: Path) -> dict:
    """Parse a receipt YAML file without applying the v1->v2 auto-upgrade.

    The migrator specifically needs the raw on-disk shape so it can tell
    v1 from v2; the server's _read_receipt transparently upgrades and
    would make the migrator always report noop.
    """
    # Import lazily so we pick up whatever the user has staged.
    from server import _parse_receipt  # type: ignore[import-not-found]

    return _parse_receipt(path)


def _diff_summary(before: dict, after: dict) -> list[str]:
    """Return a terse human-readable diff summary.

    Not a structural diff; just the keys that changed at the top level
    plus any nested objects we introduce in v2 (actor, signature).
    """
    lines: list[str] = []
    before_keys = set(before.keys())
    after_keys = set(after.keys())

    added = sorted(after_keys - before_keys)
    removed = sorted(before_keys - after_keys)
    for key in added:
        lines.append(f"    + {key}: {after[key]!r}")
    for key in removed:
        lines.append(f"    - {key}: {before[key]!r}")

    # Changed top-level scalar values.
    common = before_keys & after_keys
    for key in sorted(common):
        if key in ("actor", "scope", "lifecycle", "governance_claims", "evidence_refs"):
            continue  # nested; skip for terse diff
        if before[key] != after[key]:
            lines.append(f"    ~ {key}: {before[key]!r} -> {after[key]!r}")

    return lines


def _process_one(path: Path, dry_run: bool, backup_dir: Path | None) -> tuple[str, list[str]]:
    """Return (status, details) for a single receipt file.

    status: "noop" | "upgraded" | "error"
    details: human-readable lines
    """
    try:
        parsed = _read_receipt_text(path)
    except Exception as exc:  # pragma: no cover - parser errors are rare
        return "error", [f"    ! parse error: {exc}"]

    source_version = parsed.get("schema_version")
    if source_version == CURRENT_VERSION:
        return "noop", [f"    = already at v{CURRENT_VERSION}"]

    try:
        upgraded = upgrade_in_memory(parsed, target_version=CURRENT_VERSION)
    except MigrationError as err:
        return "error", [
            f"    ! migration error at {err.field_path or '<root>'}: {err}"
        ]

    if dry_run:
        return "upgraded", _diff_summary(parsed, upgraded)

    # --write path: backup then overwrite.
    assert backup_dir is not None  # guarded by CLI
    backup_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, backup_dir / path.name)
    path.write_text(dump_receipt(upgraded))
    return "upgraded", [f"    ✓ wrote v{CURRENT_VERSION}; backup at {backup_dir / path.name}"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--target", default=None, help="project root (default: auto-detect)")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--dry-run", action="store_true", help="default; scan and show diff")
    group.add_argument("--write", action="store_true", help="apply migrations in place")
    parser.add_argument(
        "--backup-dir",
        default=None,
        help="directory to copy v1 files into before overwriting (required with --write)",
    )
    args = parser.parse_args(argv)

    if args.write and not args.backup_dir:
        print("error: --write requires --backup-dir (refusing to overwrite without backup)", file=sys.stderr)
        return 2

    dry_run = not args.write
    root = _find_project_root(args.target)
    attestation_dir = root / ".governance" / "attestations"

    if not attestation_dir.is_dir():
        print(f"no attestations directory at {attestation_dir}; nothing to do")
        return 0

    receipts = sorted(attestation_dir.glob("*.receipt.yaml"))
    if not receipts:
        print(f"no receipts under {attestation_dir}; nothing to do")
        return 0

    backup_dir = Path(args.backup_dir).resolve() if args.backup_dir else None

    print(f"scanning {len(receipts)} receipt(s) under {attestation_dir}")
    print(f"mode: {'DRY-RUN' if dry_run else 'WRITE'}; target schema v{CURRENT_VERSION}")
    print()

    had_error = False
    stats = {"noop": 0, "upgraded": 0, "error": 0}
    for path in receipts:
        status, details = _process_one(path, dry_run=dry_run, backup_dir=backup_dir)
        stats[status] += 1
        marker = {"noop": "·", "upgraded": "→", "error": "✗"}[status]
        print(f"  {marker} {path.relative_to(root)}")
        for line in details:
            print(line)
        if status == "error":
            had_error = True

    print()
    print(
        f"summary: noop={stats['noop']}  upgraded={stats['upgraded']}  error={stats['error']}"
    )
    return 1 if had_error else 0


if __name__ == "__main__":
    raise SystemExit(main())
