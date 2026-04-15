"""Audit trail for Context Governance Hermes plugin.

Writes JSONL entries to .governance/audit/session.jsonl for governance
event tracking and violation detection.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional


def write_audit_entry(
    audit_file: Path,
    entry: dict[str, Any],
) -> None:
    """Append a single audit entry to the session JSONL file."""
    entry.setdefault("timestamp", _now_iso())
    try:
        audit_file.parent.mkdir(parents=True, exist_ok=True)
        with open(audit_file, "a") as f:
            f.write(json.dumps(entry, separators=(",", ":")) + "\n")
    except OSError:
        pass  # Audit failure should never crash the agent


def extract_file_path(tool_name: str, args: dict) -> Optional[str]:
    """Extract the file path from a tool call's arguments.

    Handles common Hermes tool argument patterns.
    """
    # Direct file_path argument (Edit, Write, Read tools)
    for key in ("file_path", "path", "filename", "file"):
        if key in args:
            return str(args[key])

    # Bash commands that touch files
    if tool_name in ("bash", "terminal", "shell"):
        cmd = args.get("command", "")
        # Don't try to parse complex commands — too error-prone
        # The audit trail records the command itself
        return None

    return None


def classify_operation(tool_name: str) -> str:
    """Classify a tool name as a read or write operation."""
    write_tools = {"edit", "write", "create_file", "file_write", "notebook_edit"}
    read_tools = {"read", "file_read", "cat", "head", "tail"}

    name_lower = tool_name.lower()
    if name_lower in write_tools or "write" in name_lower or "edit" in name_lower:
        return "write"
    if name_lower in read_tools or "read" in name_lower:
        return "read"

    return "unknown"


def summarize_args(args: dict) -> dict:
    """Create a concise summary of tool arguments for audit logging.

    Truncates long values to avoid audit file bloat.
    """
    summary = {}
    for key, value in args.items():
        if isinstance(value, str) and len(value) > 200:
            summary[key] = value[:200] + "..."
        else:
            summary[key] = value
    return summary


def _now_iso() -> str:
    """Current UTC timestamp in ISO format."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
