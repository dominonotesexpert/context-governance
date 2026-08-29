"""Evaluation context — the inputs a rule sees at evaluation time."""

from __future__ import annotations

import hashlib
import json
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class EvalContext:
    """Evaluation context for a rule.

    Two construction modes:
    - `from_repo(repo_root)` - materializes inputs from git and disk.
    - Direct construction - used by golden-fixture tests to inject inputs.

    All expensive materializers (git calls, file reads) are cached.
    """

    repo_root: Path
    staged_files: list[str] = field(default_factory=list)
    task: dict | None = None
    escalations_jsonl: str | None = None
    # Pre-supplied content (tests inject this; production mode lazy-loads).
    staged_content: dict[str, str] = field(default_factory=dict)
    committed_content: dict[str, str] = field(default_factory=dict)
    # Extra paths that should answer True to `exists()` in fixture mode
    # without appearing as staged files. Used to simulate repo state.
    existing_paths: list[str] = field(default_factory=list)
    # Runtime-call payload for pre-tool-call adapters. Shape:
    #   {"actor_role", "tool_name", "tool_args", "subject_path",
    #    "operation", "context_class", "task_id"}
    runtime_call: dict | None = None
    # Flags the engine uses to skip git calls in fixture mode.
    offline: bool = False

    # --- Construction helpers ---

    @classmethod
    def from_repo(cls, repo_root: Path) -> "EvalContext":
        """Materialize inputs from the repository on disk."""
        staged = _list_staged(repo_root)
        task = _read_current_task(repo_root)
        escalations = _read_escalations(repo_root)
        return cls(
            repo_root=repo_root,
            staged_files=staged,
            task=task,
            escalations_jsonl=escalations,
            offline=False,
        )

    @classmethod
    def from_fixture(cls, fixture: dict, repo_root: Path | None = None) -> "EvalContext":
        """Build an EvalContext from a golden-fixture dict.

        Fixture shape (all keys optional):
            {
                "staged_files": [...],
                "staged_content": {"path": "..."},
                "committed_content": {"path": "..."},
                "task": {...},
                "escalations_jsonl": "...\n..."
            }
        """
        return cls(
            repo_root=Path(repo_root or "/__fixture__"),
            staged_files=list(fixture.get("staged_files", [])),
            staged_content=dict(fixture.get("staged_content", {})),
            committed_content=dict(fixture.get("committed_content", {})),
            existing_paths=list(fixture.get("existing_paths", [])),
            task=fixture.get("task"),
            escalations_jsonl=fixture.get("escalations_jsonl"),
            runtime_call=fixture.get("runtime_call"),
            offline=True,
        )

    # --- Content accessors ---

    def staged_content_of(self, path: str) -> str:
        if path in self.staged_content:
            return self.staged_content[path]
        if self.offline:
            return ""
        content = _git_show(self.repo_root, f":{path}")
        self.staged_content[path] = content
        return content

    def committed_content_of(self, path: str) -> str:
        if path in self.committed_content:
            return self.committed_content[path]
        if self.offline:
            return ""
        content = _git_show(self.repo_root, f"HEAD:{path}")
        self.committed_content[path] = content
        return content

    def exists(self, relpath: str) -> bool:
        if self.offline:
            # Fixture mode: something "exists" if it matches any of:
            #   - a key in staged_content or committed_content
            #   - a staged file (exact or as a parent of one)
            #   - an explicitly declared existing_path
            target = relpath.rstrip("/")
            if target in self.staged_content or target in self.committed_content:
                return True
            if any(f == target or f.startswith(target + "/") for f in self.staged_files):
                return True
            for p in self.existing_paths:
                p_norm = p.rstrip("/")
                if p_norm == target or p_norm.startswith(target + "/"):
                    return True
            return False
        return (self.repo_root / relpath).exists()

    def glob(self, pattern: str) -> list[str]:
        """Return repo-root-relative paths matching a glob.

        In fixture mode, matches against staged_content / committed_content /
        staged_files / existing_paths.
        """
        if self.offline:
            import fnmatch

            candidates = (
                list(self.staged_content.keys())
                + list(self.committed_content.keys())
                + list(self.staged_files)
                + list(self.existing_paths)
            )
            return sorted({p for p in candidates if fnmatch.fnmatch(p, pattern)})
        return sorted(str(p.relative_to(self.repo_root)) for p in self.repo_root.glob(pattern))

    # --- Canonical context hashing for PDR replay ---

    def canonical_hash(self, inputs: list[str]) -> str:
        """Compute sha256 over a canonical JSON of the declared input subset."""
        snapshot: dict[str, Any] = {}
        for key in inputs:
            if key == "staged_files":
                snapshot[key] = list(self.staged_files)
            elif key == "staged_content":
                snapshot[key] = dict(sorted(self.staged_content.items()))
            elif key == "committed_content":
                snapshot[key] = dict(sorted(self.committed_content.items()))
            elif key == "task":
                snapshot[key] = self.task
            elif key == "escalations_jsonl":
                snapshot[key] = self.escalations_jsonl
            elif key == "runtime_call":
                snapshot[key] = self.runtime_call
            else:
                snapshot[key] = None
        payload = json.dumps(snapshot, sort_keys=True, separators=(",", ":"), default=str)
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()


# ============================================================
# Repository materializers
# ============================================================


def _list_staged(repo_root: Path) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only"],
            cwd=repo_root,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []
    if result.returncode != 0:
        return []
    return [line for line in result.stdout.splitlines() if line]


def _git_show(repo_root: Path, ref: str) -> str:
    try:
        result = subprocess.run(
            ["git", "show", ref],
            cwd=repo_root,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout


def _read_current_task(repo_root: Path) -> dict | None:
    task_file = repo_root / ".governance" / "current-task.json"
    if not task_file.exists():
        return None
    try:
        return json.loads(task_file.read_text())
    except (json.JSONDecodeError, OSError):
        return None


def _read_escalations(repo_root: Path) -> str | None:
    esc_file = repo_root / ".governance" / "escalations.jsonl"
    if not esc_file.exists():
        return None
    try:
        return esc_file.read_text()
    except OSError:
        return None
