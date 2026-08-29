"""Tests for the v1 -> v2 receipt migration framework.

Covers:
- Upgrade correctness per well-formed v1 fixture (6 scenarios).
- Broken fixtures raise MigrationError with field_path populated (2 scenarios).
- Idempotency: upgrading twice is identical to upgrading once.
- v2 input: upgrade_in_memory is a no-op at current version.
- State machine: v1 status values map to the documented v2 state.
- Round-trip via serializer + parser preserves semantic shape.

Authority: docs/plans/2026-04-23-governance-kernel-v2-implementation-plan.md Step G.
"""

import sys
import unittest
from pathlib import Path

# Ensure both the MCP server package and its tests are importable.
_TEST_DIR = Path(__file__).resolve().parent
_SERVER_DIR = _TEST_DIR.parent
if str(_SERVER_DIR) not in sys.path:
    sys.path.insert(0, str(_SERVER_DIR))

from migrations import CURRENT_VERSION, MigrationError, upgrade_in_memory  # noqa: E402
from migrations.serializer import dump_receipt  # noqa: E402
from server import _read_receipt  # noqa: E402


FIXTURES_V1 = _TEST_DIR / "fixtures" / "v1"


def _parse_via_server(name: str) -> dict:
    """Parse a fixture via the server parser, which auto-upgrades v1 to v2.

    Used to prove the server's read path is wired correctly. To test the
    migrator in isolation against a v1 shape, tests reverse the v2-only
    additions in `_v1_data` below.
    """
    return _read_receipt(FIXTURES_V1 / name)


class TestWellFormedUpgrades(unittest.TestCase):
    """Every well-formed v1 fixture upgrades cleanly to CURRENT_VERSION."""

    def _v1_data(self, fixture_name: str) -> dict:
        """Build a v1-shaped dict by reading the fixture and stripping v2 fields.

        _read_receipt already applies upgrade_in_memory. We reverse the
        upgrade's trivially-added fields so we have a v1-shaped input to
        hand to upgrade_in_memory again, proving it is deterministic.
        """
        upgraded = _parse_via_server(fixture_name)
        self.assertEqual(upgraded["schema_version"], CURRENT_VERSION)
        v1 = dict(upgraded)
        v1["schema_version"] = 1
        # Strip v2-only fields to recreate the v1 shape.
        for key in ("state", "context_class", "policy_version", "actor",
                    "provenance_ref", "signature"):
            v1.pop(key, None)
        return v1

    def test_bug_in_progress(self):
        v1 = self._v1_data("bug_in_progress.yaml")
        v2 = upgrade_in_memory(v1)
        self.assertEqual(v2["schema_version"], 2)
        self.assertEqual(v2["state"], "running")
        self.assertEqual(v2["status"], "in_progress")
        self.assertEqual(v2["context_class"], "internal")
        self.assertEqual(v2["policy_version"], "unversioned-v1")
        self.assertEqual(v2["actor"]["kind"], "mcp")
        self.assertEqual(v2["actor"]["id"], "governance-mcp")
        self.assertEqual(v2["actor"]["session_id"], "S-001")
        self.assertIsNone(v2["provenance_ref"])
        self.assertIsNone(v2["signature"])

    def test_bug_completed(self):
        v1 = self._v1_data("bug_completed.yaml")
        v2 = upgrade_in_memory(v1)
        self.assertEqual(v2["state"], "completed")
        self.assertTrue(v2["governance_claims"]["debug_required"])
        self.assertFalse(v2["governance_claims"]["formal_verification_required"])
        self.assertEqual(v2["status"], "completed")

    def test_feature_in_progress(self):
        v1 = self._v1_data("feature_in_progress.yaml")
        v2 = upgrade_in_memory(v1)
        self.assertEqual(v2["state"], "running")
        self.assertEqual(v2["context_class"], "internal")
        self.assertEqual(v2["actor"]["session_id"], None)

    def test_design_completed(self):
        v1 = self._v1_data("design_completed.yaml")
        v2 = upgrade_in_memory(v1)
        self.assertEqual(v2["state"], "completed")
        self.assertEqual(v2["context_class"], "internal")

    def test_autoresearch_in_progress(self):
        v1 = self._v1_data("autoresearch_in_progress.yaml")
        v2 = upgrade_in_memory(v1)
        self.assertEqual(v2["state"], "running")
        self.assertEqual(v2["context_class"], "internal")
        self.assertEqual(v2["governance_claims"].get("escalation_upstream"), True)

    def test_trivial_completed(self):
        """Trivial tasks default to context_class=public and issuer=manual becomes user."""
        v1 = self._v1_data("trivial_completed.yaml")
        v2 = upgrade_in_memory(v1)
        self.assertEqual(v2["state"], "completed")
        self.assertEqual(v2["context_class"], "public")
        self.assertEqual(v2["actor"]["kind"], "user")
        self.assertEqual(v2["actor"]["id"], "manual")


class TestBrokenFixturesRejected(unittest.TestCase):
    """Malformed v1 receipts fail with MigrationError and a field_path."""

    def test_missing_task_id(self):
        # Build a v1 dict missing task_id directly (fixture parse reveals
        # the same shape, but constructing here avoids parser edge cases).
        bad = {
            "schema_version": 1,
            "task_type": "bug",
            "status": "in_progress",
            "attestation_mode": "mcp",
            "lifecycle": {"issuer": "governance-mcp"},
        }
        with self.assertRaises(MigrationError) as ctx:
            upgrade_in_memory(bad)
        self.assertEqual(ctx.exception.field_path, "task_id")

    def test_unknown_task_type(self):
        bad = {
            "schema_version": 1,
            "task_id": "T-20260325-099",
            "task_type": "mystery",
            "status": "in_progress",
            "attestation_mode": "mcp",
            "lifecycle": {"issuer": "governance-mcp"},
        }
        with self.assertRaises(MigrationError) as ctx:
            upgrade_in_memory(bad)
        self.assertEqual(ctx.exception.field_path, "task_type")


class TestIdempotencyAndNoop(unittest.TestCase):
    def test_upgrade_is_idempotent(self):
        v1 = {
            "schema_version": 1,
            "task_id": "T-20260325-001",
            "task_type": "feature",
            "status": "in_progress",
            "attestation_mode": "mcp",
            "lifecycle": {"issuer": "governance-mcp", "session_ids": []},
        }
        once = upgrade_in_memory(v1)
        twice = upgrade_in_memory(once)
        self.assertEqual(once, twice)

    def test_v2_input_is_noop(self):
        v2 = {
            "schema_version": 2,
            "task_id": "T-20260325-001",
            "task_type": "feature",
            "state": "running",
            "status": "in_progress",
            "context_class": "internal",
            "policy_version": "1.0.0",
            "attestation_mode": "mcp",
            "actor": {"kind": "mcp", "id": "governance-mcp", "session_id": None},
            "lifecycle": {"issuer": "governance-mcp", "session_ids": []},
            "provenance_ref": None,
            "signature": None,
        }
        result = upgrade_in_memory(v2)
        self.assertEqual(result["schema_version"], 2)
        self.assertEqual(result["policy_version"], "1.0.0")

    def test_downgrade_rejected(self):
        v2 = {"schema_version": 2, "task_id": "T-1", "task_type": "bug"}
        with self.assertRaises(MigrationError):
            upgrade_in_memory(v2, target_version=1)


class TestStateMachineMapping(unittest.TestCase):
    def test_status_in_progress_maps_to_state_running(self):
        v1 = {
            "schema_version": 1,
            "task_id": "T-20260325-010",
            "task_type": "feature",
            "status": "in_progress",
            "attestation_mode": "mcp",
            "lifecycle": {"issuer": "governance-mcp"},
        }
        self.assertEqual(upgrade_in_memory(v1)["state"], "running")

    def test_status_abandoned_maps_to_state_abandoned(self):
        v1 = {
            "schema_version": 1,
            "task_id": "T-20260325-011",
            "task_type": "feature",
            "status": "abandoned",
            "attestation_mode": "mcp",
            "lifecycle": {"issuer": "governance-mcp"},
        }
        self.assertEqual(upgrade_in_memory(v1)["state"], "abandoned")


class TestSerializerRoundtrip(unittest.TestCase):
    """Serializer output parses back into the same semantic shape."""

    def test_roundtrip_preserves_new_v2_fields(self):
        v2 = {
            "schema_version": 2,
            "task_id": "T-20260423-001",
            "task_type": "bug",
            "state": "running",
            "status": "in_progress",
            "context_class": "internal",
            "policy_version": "unversioned-v1",
            "attestation_mode": "mcp",
            "manual_fallback_reason": None,
            "actor": {"kind": "mcp", "id": "governance-mcp", "session_id": "S-001"},
            "scope": {
                "affected_modules": ["auth"],
                "affected_paths": ["src/auth/handler.ts"],
            },
            "governance_claims": {
                "debug_required": True,
                "formal_verification_required": False,
                "route_reason": "formal Debug selected for regression",
                "debug_case_present": True,
                "module_contract_refs": [
                    "docs/agents/modules/auth/MODULE_CONTRACT.md"
                ],
            },
            "evidence_refs": [
                {
                    "path": "docs/agents/debug/cases/DEBUG_CASE_auth.md",
                    "kind": "debug_case",
                    "upstream_hash": None,
                }
            ],
            "provenance_ref": None,
            "signature": None,
            "lifecycle": {
                "created_at": "2026-04-23T10:00:00Z",
                "updated_at": "2026-04-23T10:00:00Z",
                "issuer": "governance-mcp",
                "session_ids": ["S-001"],
            },
        }

        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".receipt.yaml", delete=False, mode="w") as fh:
            fh.write(dump_receipt(v2))
            path = Path(fh.name)

        try:
            parsed = _read_receipt(path)
        finally:
            path.unlink()

        self.assertEqual(parsed["schema_version"], 2)
        self.assertEqual(parsed["state"], "running")
        self.assertEqual(parsed["context_class"], "internal")
        self.assertEqual(parsed["actor"]["kind"], "mcp")
        self.assertEqual(parsed["actor"]["id"], "governance-mcp")
        self.assertEqual(parsed["actor"]["session_id"], "S-001")
        self.assertEqual(parsed["policy_version"], "unversioned-v1")


if __name__ == "__main__":
    unittest.main()
