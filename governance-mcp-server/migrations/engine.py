"""Migration engine: orchestrates a chain of per-step upgraders."""

from __future__ import annotations

import copy
from typing import Any

from .registry import REGISTRY

CURRENT_VERSION = 2


class MigrationError(Exception):
    """Raised when a receipt cannot be migrated.

    Attributes
    ----------
    field_path : str
        Dotted path identifying the offending field (e.g. "lifecycle.issuer").
    """

    def __init__(self, message: str, field_path: str = ""):
        super().__init__(message)
        self.field_path = field_path


def _detect_version(data: dict) -> int:
    raw = data.get("schema_version")
    if raw is None:
        raise MigrationError(
            "receipt missing required field 'schema_version'", field_path="schema_version"
        )
    try:
        return int(raw)
    except (TypeError, ValueError):
        raise MigrationError(
            f"schema_version must be an integer, got {raw!r}",
            field_path="schema_version",
        ) from None


def upgrade_in_memory(data: dict, target_version: int = CURRENT_VERSION) -> dict:
    """Upgrade `data` to `target_version`.

    Parameters
    ----------
    data : dict
        A parsed receipt (v1 or v2).
    target_version : int
        Target schema version. Defaults to CURRENT_VERSION.

    Returns
    -------
    dict
        A new dict at `target_version`. Input is never mutated.

    Raises
    ------
    MigrationError
        On missing schema_version, unknown version, or unreachable target.
    """
    if not isinstance(data, dict):
        raise MigrationError(
            f"expected dict, got {type(data).__name__}", field_path=""
        )

    source_version = _detect_version(data)

    if source_version == target_version:
        # Deep copy so callers cannot accidentally mutate shared state.
        return copy.deepcopy(data)

    if source_version > target_version:
        raise MigrationError(
            f"cannot downgrade from schema v{source_version} to v{target_version}",
            field_path="schema_version",
        )

    current = copy.deepcopy(data)
    version = source_version
    # Apply upgraders one step at a time until reaching target.
    while version < target_version:
        upgrader = REGISTRY.get((version, version + 1))
        if upgrader is None:
            raise MigrationError(
                f"no upgrader registered for v{version} -> v{version + 1}",
                field_path="schema_version",
            )
        current = upgrader(current)
        version += 1

    return current
