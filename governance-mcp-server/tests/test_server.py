#!/usr/bin/env python3
"""Tests for the Context Governance MCP Attestation Server.

Tests validate:
- Task ID generation
- Receipt creation and schema compliance
- Index management
- Per-task-type claim requirements
- Manual attestation policy
- Task lifecycle (start → update → complete)
"""

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from unittest import TestCase, main

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from server import (
    _next_task_id,
    _now_iso,
    _update_index,
    _write_current_task,
    _write_receipt,
)
import server


class TestTaskIdGeneration(TestCase):
    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())
        self.att_dir = self.tmpdir / ".governance" / "attestations"
        self.att_dir.mkdir(parents=True)
        self.index = self.att_dir / "index.jsonl"
        # Patch module globals
        server.PROJECT_ROOT = self.tmpdir
        server.ATTESTATION_DIR = self.att_dir
        server.INDEX_FILE = self.index

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_first_task_id(self):
        """First task of the day should be -001."""
        tid = _next_task_id()
        self.assertRegex(tid, r"^T-\d{8}-001$")

    def test_incrementing_task_id(self):
        """Subsequent tasks increment the sequence."""
        from datetime import datetime, timezone
        today = datetime.now(timezone.utc).strftime("%Y%m%d")
        self.index.write_text(
            json.dumps({"task_id": f"T-{today}-001", "task_type": "bug"}) + "\n"
            + json.dumps({"task_id": f"T-{today}-003", "task_type": "feature"}) + "\n"
        )
        tid = _next_task_id()
        self.assertEqual(tid, f"T-{today}-004")


class TestReceiptWriting(TestCase):
    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())
        self.att_dir = self.tmpdir / ".governance" / "attestations"
        self.att_dir.mkdir(parents=True)
        self.index = self.att_dir / "index.jsonl"
        server.PROJECT_ROOT = self.tmpdir
        server.ATTESTATION_DIR = self.att_dir
        server.INDEX_FILE = self.index

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_write_bug_receipt(self):
        """Bug receipt should contain required fields."""
        data = {
            "task_type": "bug",
            "status": "in_progress",
            "attestation_mode": "mcp",
            "affected_modules": ["auth"],
            "affected_paths": ["src/auth/handler.ts"],
            "governance_claims": {
                "debug_case_present": True,
                "module_contract_refs": ["docs/agents/modules/auth/MODULE_CONTRACT.md"],
            },
            "evidence_refs": [
                {"path": "docs/agents/debug/cases/DEBUG_CASE_auth.md", "kind": "debug_case"},
            ],
            "lifecycle": {
                "created_at": "2026-03-25T10:00:00Z",
                "updated_at": "2026-03-25T10:00:00Z",
                "issuer": "governance-mcp",
                "session_ids": ["S-001"],
            },
        }
        path = _write_receipt("T-20260325-001", data)
        self.assertTrue(path.exists())
        content = path.read_text()
        self.assertIn("schema_version: 1", content)
        self.assertIn("task_id: T-20260325-001", content)
        self.assertIn("task_type: bug", content)
        self.assertIn("debug_case_present: true", content)
        self.assertIn("attestation_mode: mcp", content)

    def test_write_feature_receipt(self):
        """Feature receipt should contain module_contract_refs."""
        data = {
            "task_type": "feature",
            "status": "in_progress",
            "attestation_mode": "mcp",
            "affected_modules": ["payments"],
            "affected_paths": ["src/payments/checkout.ts"],
            "governance_claims": {
                "module_contract_refs": ["docs/agents/modules/payments/MODULE_CONTRACT.md"],
            },
            "evidence_refs": [],
            "lifecycle": {
                "created_at": "2026-03-25T10:00:00Z",
                "updated_at": "2026-03-25T10:00:00Z",
                "issuer": "governance-mcp",
                "session_ids": [],
            },
        }
        path = _write_receipt("T-20260325-002", data)
        content = path.read_text()
        self.assertIn("task_type: feature", content)
        self.assertIn("module_contract_refs", content)

    def test_manual_attestation_receipt(self):
        """Manual attestation receipt should include fallback reason."""
        data = {
            "task_type": "feature",
            "status": "in_progress",
            "attestation_mode": "manual_attestation",
            "manual_fallback_reason": "MCP offline",
            "affected_modules": [],
            "affected_paths": [],
            "governance_claims": {},
            "evidence_refs": [],
            "lifecycle": {
                "created_at": "2026-03-25T10:00:00Z",
                "updated_at": "2026-03-25T10:00:00Z",
                "issuer": "manual",
                "session_ids": [],
            },
        }
        path = _write_receipt("T-20260325-003", data)
        content = path.read_text()
        self.assertIn("attestation_mode: manual_attestation", content)
        self.assertIn("manual_fallback_reason: MCP offline", content)


class TestIndexManagement(TestCase):
    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())
        self.att_dir = self.tmpdir / ".governance" / "attestations"
        self.att_dir.mkdir(parents=True)
        self.index = self.att_dir / "index.jsonl"
        server.PROJECT_ROOT = self.tmpdir
        server.ATTESTATION_DIR = self.att_dir
        server.INDEX_FILE = self.index

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_create_index_entry(self):
        """New task creates an index entry."""
        _update_index("T-20260325-001", {
            "task_type": "bug",
            "status": "in_progress",
            "attestation_mode": "mcp",
        })
        lines = self.index.read_text().strip().split("\n")
        self.assertEqual(len(lines), 1)
        entry = json.loads(lines[0])
        self.assertEqual(entry["task_id"], "T-20260325-001")
        self.assertEqual(entry["task_type"], "bug")
        self.assertEqual(entry["status"], "in_progress")

    def test_update_existing_entry(self):
        """Updating a task replaces its index entry."""
        _update_index("T-20260325-001", {
            "task_type": "bug",
            "status": "in_progress",
            "attestation_mode": "mcp",
        })
        _update_index("T-20260325-001", {
            "task_type": "bug",
            "status": "completed",
            "attestation_mode": "mcp",
        })
        lines = self.index.read_text().strip().split("\n")
        self.assertEqual(len(lines), 1)
        entry = json.loads(lines[0])
        self.assertEqual(entry["status"], "completed")

    def test_multiple_entries(self):
        """Multiple tasks create separate entries."""
        _update_index("T-20260325-001", {"task_type": "bug", "status": "in_progress", "attestation_mode": "mcp"})
        _update_index("T-20260325-002", {"task_type": "feature", "status": "in_progress", "attestation_mode": "mcp"})
        lines = self.index.read_text().strip().split("\n")
        self.assertEqual(len(lines), 2)


class TestCurrentTask(TestCase):
    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())
        (self.tmpdir / ".governance").mkdir(parents=True)
        server.PROJECT_ROOT = self.tmpdir

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_write_current_task(self):
        """current-task.json should have expected structure."""
        _write_current_task("T-20260325-001", "bug", ["auth"])
        ct = self.tmpdir / ".governance" / "current-task.json"
        self.assertTrue(ct.exists())
        data = json.loads(ct.read_text())
        self.assertEqual(data["task_type"], "bug")
        self.assertEqual(data["task_id"], "T-20260325-001")
        self.assertEqual(data["affected_modules"], ["auth"])
        self.assertEqual(data["created_by"], "governance-mcp")


if __name__ == "__main__":
    main()
