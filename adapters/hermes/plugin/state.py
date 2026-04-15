"""Governance session state management for Hermes plugin.

Tracks per-session governance context: active task, current role,
pending escalations, governance mode, HARD-GATE satisfaction, and audit trail.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

from .constants import (
    CURRENT_TASK_FILE,
    ESCALATION_FILE,
    GOVERNANCE_DIR,
    GOVERNANCE_MODE_FILE,
)


# Module-level session state registry.
# Keys are Hermes session IDs; values are GovernanceState instances.
SESSION_STATES: dict[str, "GovernanceState"] = {}


@dataclass
class GovernanceState:
    """Per-session governance context."""

    project_root: Optional[Path] = None
    governance_active: bool = False

    # Task state
    current_task: Optional[dict[str, Any]] = None
    current_role: Optional[str] = None

    # Governance mode (default: steady-state)
    governance_mode: str = "steady-state"

    # Escalations
    pending_escalations: list[dict[str, Any]] = field(default_factory=list)

    # Document tracking for HARD-GATE satisfaction
    documents_read: set[str] = field(default_factory=set)
    hardgate_satisfied: bool = False

    # Stale document warnings
    stale_warnings: list[str] = field(default_factory=list)

    # Audit
    audit_file: Optional[Path] = None


def find_project_root(start: Optional[Path] = None) -> Optional[Path]:
    """Find project root by looking for .governance/ directory.

    Mirrors logic from governance-mcp-server/server.py:40-53.
    """
    if start is None:
        start = Path.cwd()

    # Check start directory
    if (start / GOVERNANCE_DIR).is_dir():
        return start

    # Walk up to find .governance/
    for parent in start.parents:
        if (parent / GOVERNANCE_DIR).is_dir():
            return parent

    return None


def load_governance_state(project_root: Path) -> GovernanceState:
    """Load governance state from .governance/ directory."""
    state = GovernanceState(
        project_root=project_root,
        governance_active=True,
    )

    # Load current task
    task_path = project_root / CURRENT_TASK_FILE
    if task_path.exists():
        try:
            state.current_task = json.loads(task_path.read_text())
        except (json.JSONDecodeError, OSError):
            pass

    # Load pending escalations
    esc_path = project_root / ESCALATION_FILE
    if esc_path.exists():
        try:
            lines = esc_path.read_text().strip().split("\n")
            for line in lines:
                if not line.strip():
                    continue
                entry = json.loads(line)
                if entry.get("status") != "resolved":
                    state.pending_escalations.append(entry)
        except (json.JSONDecodeError, OSError):
            pass

    # Load governance mode
    mode_path = project_root / GOVERNANCE_MODE_FILE
    if mode_path.exists():
        state.governance_mode = _parse_governance_mode(mode_path)

    # Initialize audit trail
    audit_dir = project_root / ".governance" / "audit"
    audit_dir.mkdir(parents=True, exist_ok=True)
    state.audit_file = audit_dir / "session.jsonl"

    return state


def _parse_governance_mode(path: Path) -> str:
    """Extract current governance mode from GOVERNANCE_MODE.md.

    Looks for a `current_mode:` field in YAML frontmatter or body.
    Defaults to 'steady-state' if not found.
    """
    try:
        content = path.read_text()
    except OSError:
        return "steady-state"

    for line in content.split("\n"):
        stripped = line.strip()
        if stripped.startswith("current_mode:"):
            mode = stripped.split(":", 1)[1].strip().strip('"').strip("'")
            if mode:
                return mode

    # Fallback: look for mode in markdown body
    for mode_name in ("steady-state", "exploration", "migration", "incident", "exception"):
        if f"**{mode_name}**" in content.lower() or f"current_mode: {mode_name}" in content:
            return mode_name

    return "steady-state"
