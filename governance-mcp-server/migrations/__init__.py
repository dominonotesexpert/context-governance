"""Receipt schema migration framework.

Exports
-------
CURRENT_VERSION : int
    The latest supported receipt schema version (2 as of 2026-04-23).
upgrade_in_memory(data, target_version=CURRENT_VERSION) : dict
    Return a new dict upgraded to `target_version`. Never mutates input.
    Raises MigrationError on missing upgrader or malformed input.
MigrationError : Exception
    Domain error with a `.field_path` attribute identifying the offending field.

Contract
--------
* Pure dict transformations. Serialization to YAML lives elsewhere
  (governance-mcp-server/server.py : _write_receipt).
* Idempotent: upgrading an already-current dict is a no-op.
* Non-destructive: input dict is never mutated.
* Fail-loud on unknown schema_version or malformed structure.

Authority: docs/plans/2026-04-23-governance-kernel-v2-design.md §2.5
"""

from .engine import CURRENT_VERSION, MigrationError, upgrade_in_memory

__all__ = ["CURRENT_VERSION", "MigrationError", "upgrade_in_memory"]
