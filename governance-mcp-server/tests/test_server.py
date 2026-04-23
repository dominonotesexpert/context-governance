#!/usr/bin/env python3
"""Tests for the Context Governance MCP Attestation Server.

Tests validate:
- Task ID generation
- Receipt creation and schema compliance
- Index management
- Per-task-type claim requirements
- Manual attestation policy
- Task lifecycle (start → update → complete)
- Tool functions end-to-end
- Receipt schema validation integration
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest import TestCase, main

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from server import (
    _next_task_id,
    _now_iso,
    _read_receipt,
    _update_index,
    _write_current_task,
    _write_receipt,
    governance_start_task,
    governance_update_receipt,
    governance_record_debug_case,
    governance_record_escalation,
    governance_record_verification,
    governance_complete_task,
    governance_run_checks,
    governance_start_autoresearch,
    governance_record_optimization,
)
import server


class TestTaskIdGeneration(TestCase):
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


class TestReadReceipt(TestCase):
    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())
        self.att_dir = self.tmpdir / ".governance" / "attestations"
        self.att_dir.mkdir(parents=True)
        server.PROJECT_ROOT = self.tmpdir
        server.ATTESTATION_DIR = self.att_dir
        server.INDEX_FILE = self.att_dir / "index.jsonl"

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_roundtrip(self):
        """Write then read a receipt — data should survive roundtrip."""
        data = {
            "task_type": "feature",
            "status": "in_progress",
            "attestation_mode": "mcp",
            "affected_modules": ["core"],
            "affected_paths": ["src/core.ts"],
            "governance_claims": {
                "module_contract_refs": ["docs/agents/modules/core/MODULE_CONTRACT.md"],
            },
            "evidence_refs": [
                {"path": "docs/agents/modules/core/MODULE_CONTRACT.md", "kind": "module_contract"},
            ],
            "lifecycle": {
                "created_at": "2026-04-01T10:00:00Z",
                "updated_at": "2026-04-01T10:00:00Z",
                "issuer": "governance-mcp",
                "session_ids": ["S-001"],
            },
        }
        path = _write_receipt("T-20260401-001", data)
        parsed = _read_receipt(path)

        self.assertEqual(parsed["task_id"], "T-20260401-001")
        self.assertEqual(parsed["task_type"], "feature")
        self.assertEqual(parsed["status"], "in_progress")
        self.assertEqual(parsed["scope"]["affected_modules"], ["core"])
        self.assertEqual(parsed["scope"]["affected_paths"], ["src/core.ts"])
        self.assertIn("module_contract_refs", parsed["governance_claims"])
        self.assertEqual(len(parsed["evidence_refs"]), 1)
        self.assertEqual(parsed["evidence_refs"][0]["kind"], "module_contract")
        self.assertEqual(parsed["lifecycle"]["issuer"], "governance-mcp")


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


class TestToolStartTask(TestCase):
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

    def test_start_bug_task(self):
        """Start a bug task — creates receipt, index entry, current-task."""
        result = governance_start_task(task_type="bug", affected_modules=["auth"])
        self.assertIn("task_id", result)
        self.assertEqual(result["task_type"], "bug")
        self.assertEqual(result["status"], "in_progress")

        # Receipt file exists
        receipt = self.att_dir / f"{result['task_id']}.receipt.yaml"
        self.assertTrue(receipt.exists())
        content = receipt.read_text()
        self.assertIn("debug_case_present: false", content)

        # Index entry exists
        self.assertTrue(self.index.exists())
        idx = json.loads(self.index.read_text().strip())
        self.assertEqual(idx["task_id"], result["task_id"])

        # current-task.json exists
        ct = self.tmpdir / ".governance" / "current-task.json"
        self.assertTrue(ct.exists())

    def test_start_feature_task(self):
        result = governance_start_task(task_type="feature", affected_modules=["payments"])
        self.assertEqual(result["task_type"], "feature")
        receipt = self.att_dir / f"{result['task_id']}.receipt.yaml"
        content = receipt.read_text()
        self.assertIn("module_contract_refs", content)

    def test_start_trivial_task(self):
        result = governance_start_task(task_type="trivial")
        self.assertEqual(result["task_type"], "trivial")
        self.assertNotIn("error", result)

    def test_invalid_task_type(self):
        result = governance_start_task(task_type="invalid_type")
        self.assertIn("error", result)

    def test_start_autoresearch_task(self):
        result = governance_start_task(task_type="autoresearch")
        receipt = self.att_dir / f"{result['task_id']}.receipt.yaml"
        content = receipt.read_text()
        self.assertIn("optimization_log_ref", content)
        self.assertIn("escalation_upstream: true", content)


class TestToolUpdateReceipt(TestCase):
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

    def test_update_claims(self):
        """Update governance claims on existing receipt."""
        start = governance_start_task(task_type="bug", affected_modules=["auth"])
        tid = start["task_id"]
        result = governance_update_receipt(
            task_id=tid,
            governance_claims={"debug_case_present": True},
        )
        self.assertEqual(result["status"], "updated")
        receipt = self.att_dir / f"{tid}.receipt.yaml"
        content = receipt.read_text()
        self.assertIn("debug_case_present: true", content)

    def test_update_nonexistent(self):
        result = governance_update_receipt(task_id="T-99999999-999")
        self.assertIn("error", result)

    def test_append_evidence(self):
        start = governance_start_task(task_type="feature", affected_modules=["core"])
        tid = start["task_id"]
        result = governance_update_receipt(
            task_id=tid,
            evidence_refs=[
                {"path": "docs/agents/modules/core/MODULE_CONTRACT.md",
                 "kind": "module_contract", "upstream_hash": None},
            ],
        )
        self.assertEqual(result["status"], "updated")
        receipt = self.att_dir / f"{tid}.receipt.yaml"
        content = receipt.read_text()
        self.assertIn("kind: module_contract", content)


class TestToolRecordDebugCase(TestCase):
    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())
        self.att_dir = self.tmpdir / ".governance" / "attestations"
        self.att_dir.mkdir(parents=True)
        self.index = self.att_dir / "index.jsonl"
        server.PROJECT_ROOT = self.tmpdir
        server.ATTESTATION_DIR = self.att_dir
        server.INDEX_FILE = self.index
        # Create module and debug case
        (self.tmpdir / "docs/agents/modules/auth").mkdir(parents=True)
        (self.tmpdir / "docs/agents/modules/auth/MODULE_CONTRACT.md").write_text("# Auth\n")
        (self.tmpdir / "docs/agents/debug/cases").mkdir(parents=True)
        self.debug_path = "docs/agents/debug/cases/DEBUG_CASE_auth.md"
        (self.tmpdir / self.debug_path).write_text("# Debug Case\n")

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_record_debug_case(self):
        start = governance_start_task(task_type="bug", affected_modules=["auth"])
        tid = start["task_id"]
        result = governance_record_debug_case(
            task_id=tid,
            debug_case_path=self.debug_path,
            module_name="auth",
        )
        self.assertEqual(result["status"], "updated")
        receipt = self.att_dir / f"{tid}.receipt.yaml"
        content = receipt.read_text()
        self.assertIn("debug_case_present: true", content)
        self.assertIn("kind: debug_case", content)

    def test_missing_debug_case_file(self):
        start = governance_start_task(task_type="bug", affected_modules=["auth"])
        result = governance_record_debug_case(
            task_id=start["task_id"],
            debug_case_path="nonexistent.md",
            module_name="auth",
        )
        self.assertIn("error", result)


class TestToolRecordEscalation(TestCase):
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

    def test_record_escalation(self):
        start = governance_start_task(task_type="feature")
        result = governance_record_escalation(
            task_id=start["task_id"],
            escalation_type="contract_gap",
            description="Module contract does not cover new endpoint",
        )
        self.assertEqual(result["status"], "pending")
        esc_file = self.tmpdir / ".governance" / "escalations.jsonl"
        self.assertTrue(esc_file.exists())
        entry = json.loads(esc_file.read_text().strip())
        self.assertEqual(entry["type"], "contract_gap")


class TestToolCompleteTask(TestCase):
    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())
        self.att_dir = self.tmpdir / ".governance" / "attestations"
        self.att_dir.mkdir(parents=True)
        self.index = self.att_dir / "index.jsonl"
        server.PROJECT_ROOT = self.tmpdir
        server.ATTESTATION_DIR = self.att_dir
        server.INDEX_FILE = self.index
        # Create scripts dir with check stubs
        scripts_dir = self.tmpdir / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "check-task-receipt.sh").write_text("#!/bin/bash\necho 'PASSED'\nexit 0\n")
        os.chmod(scripts_dir / "check-task-receipt.sh", 0o755)

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_complete_task(self):
        start = governance_start_task(task_type="trivial")
        tid = start["task_id"]
        result = governance_complete_task(task_id=tid)
        self.assertEqual(result["status"], "completed")

        # Receipt updated
        receipt = self.att_dir / f"{tid}.receipt.yaml"
        self.assertIn("status: completed", receipt.read_text())

        # Index updated
        idx = json.loads(self.index.read_text().strip())
        self.assertEqual(idx["status"], "completed")

        # current-task.json cleaned up
        self.assertFalse((self.tmpdir / ".governance" / "current-task.json").exists())

    def test_complete_nonexistent(self):
        result = governance_complete_task(task_id="T-99999999-999")
        self.assertIn("error", result)


class TestSchemaCompliance(TestCase):
    """Verify that MCP-generated receipts pass schema validation."""

    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())
        self.att_dir = self.tmpdir / ".governance" / "attestations"
        self.att_dir.mkdir(parents=True)
        self.index = self.att_dir / "index.jsonl"
        server.PROJECT_ROOT = self.tmpdir
        server.ATTESTATION_DIR = self.att_dir
        server.INDEX_FILE = self.index
        # Locate validator
        self.validator = Path(__file__).resolve().parent.parent.parent / "scripts" / "validate-receipt.py"

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def _validate(self, task_id):
        receipt = self.att_dir / f"{task_id}.receipt.yaml"
        result = subprocess.run(
            [sys.executable, str(self.validator), str(receipt), str(self.tmpdir)],
            capture_output=True, text=True, timeout=10,
        )
        return result.returncode, result.stdout.strip()

    def test_trivial_receipt_validates(self):
        start = governance_start_task(task_type="trivial")
        code, output = self._validate(start["task_id"])
        self.assertEqual(code, 0, f"Validation failed: {output}")

    def test_design_receipt_validates(self):
        start = governance_start_task(task_type="design")
        code, output = self._validate(start["task_id"])
        self.assertEqual(code, 0, f"Validation failed: {output}")

    def test_bug_receipt_with_evidence_validates(self):
        """Bug receipt with all required claims should pass validation."""
        start = governance_start_task(task_type="bug", affected_modules=["auth"])
        tid = start["task_id"]
        # Create evidence files
        (self.tmpdir / "docs/agents/debug/cases").mkdir(parents=True)
        (self.tmpdir / "docs/agents/debug/cases/DEBUG_CASE_auth.md").write_text("# DC\n")
        (self.tmpdir / "docs/agents/modules/auth").mkdir(parents=True)
        (self.tmpdir / "docs/agents/modules/auth/MODULE_CONTRACT.md").write_text("# MC\n")

        governance_record_debug_case(
            task_id=tid,
            debug_case_path="docs/agents/debug/cases/DEBUG_CASE_auth.md",
            module_name="auth",
        )
        code, output = self._validate(tid)
        self.assertEqual(code, 0, f"Validation failed: {output}")


class TestToolStartAutoresearch(TestCase):
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

    def test_start_autoresearch(self):
        """Start autoresearch task — sets correct defaults."""
        result = governance_start_autoresearch(target_skill=".claude/skills/debug/SKILL.md")
        self.assertIn("task_id", result)
        self.assertEqual(result["task_type"], "autoresearch")
        self.assertIn("next_steps", result)
        self.assertIn("warnings", result)

        # Receipt has autoresearch claims
        receipt = self.att_dir / f"{result['task_id']}.receipt.yaml"
        content = receipt.read_text()
        self.assertIn("task_type: autoresearch", content)
        self.assertIn("optimization_log_ref", content)
        self.assertIn("escalation_upstream: true", content)

    def test_start_autoresearch_warns_missing_prereqs(self):
        """Should warn when OPTIMIZATION_LOG or test scenarios are missing."""
        result = governance_start_autoresearch()
        self.assertTrue(len(result["warnings"]) >= 1)

    def test_start_autoresearch_no_warnings_when_prereqs_exist(self):
        """No warnings when prerequisites exist."""
        (self.tmpdir / "docs/agents/optimization").mkdir(parents=True)
        (self.tmpdir / "docs/agents/optimization/OPTIMIZATION_LOG.md").write_text("# Log\n")
        (self.tmpdir / "docs/agents/optimization/test-scenarios").mkdir()
        (self.tmpdir / "docs/agents/optimization/test-scenarios/seed-bug.json").write_text("{}\n")

        result = governance_start_autoresearch()
        self.assertEqual(len(result["warnings"]), 0)


class TestToolRecordOptimization(TestCase):
    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())
        self.att_dir = self.tmpdir / ".governance" / "attestations"
        self.att_dir.mkdir(parents=True)
        self.index = self.att_dir / "index.jsonl"
        server.PROJECT_ROOT = self.tmpdir
        server.ATTESTATION_DIR = self.att_dir
        server.INDEX_FILE = self.index
        # Create optimization artifacts
        (self.tmpdir / "docs/agents/optimization").mkdir(parents=True)
        (self.tmpdir / "docs/agents/optimization/OPTIMIZATION_LOG.md").write_text("# Log\n")

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_record_optimization_round(self):
        """Record an optimization round — updates receipt and audit trail."""
        start = governance_start_autoresearch(target_skill=".claude/skills/debug/SKILL.md")
        tid = start["task_id"]

        result = governance_record_optimization(
            task_id=tid,
            optimization_round=1,
            target_skill_path=".claude/skills/debug/SKILL.md",
            change_description="Added explicit root cause classification step",
            result="improved",
            backup_path="docs/agents/optimization/backups/debug-SKILL-round1.md",
        )
        self.assertEqual(result["status"], "updated")

        # Receipt has evidence
        receipt = self.att_dir / f"{tid}.receipt.yaml"
        content = receipt.read_text()
        self.assertIn("kind: optimization_artifact", content)
        self.assertIn("escalation_upstream: true", content)

        # Audit trail exists
        audit = self.tmpdir / ".governance" / "audit" / f"{tid}-optimization.jsonl"
        self.assertTrue(audit.exists())
        entry = json.loads(audit.read_text().strip())
        self.assertEqual(entry["round"], 1)
        self.assertEqual(entry["result"], "improved")

    def test_record_optimization_invalid_result(self):
        start = governance_start_autoresearch()
        result = governance_record_optimization(
            task_id=start["task_id"],
            optimization_round=1,
            target_skill_path="x",
            change_description="test",
            result="invalid_result",
        )
        self.assertIn("error", result)

    def test_record_optimization_nonexistent_task(self):
        result = governance_record_optimization(
            task_id="T-99999999-999",
            optimization_round=1,
            target_skill_path="x",
            change_description="test",
            result="improved",
        )
        self.assertIn("error", result)


class TestAutoresearchSchemaCompliance(TestCase):
    """Verify autoresearch receipts pass schema validation."""

    def setUp(self):
        self.tmpdir = Path(tempfile.mkdtemp())
        self.att_dir = self.tmpdir / ".governance" / "attestations"
        self.att_dir.mkdir(parents=True)
        self.index = self.att_dir / "index.jsonl"
        server.PROJECT_ROOT = self.tmpdir
        server.ATTESTATION_DIR = self.att_dir
        server.INDEX_FILE = self.index
        self.validator = Path(__file__).resolve().parent.parent.parent / "scripts" / "validate-receipt.py"
        # Create optimization artifacts
        (self.tmpdir / "docs/agents/optimization").mkdir(parents=True)
        (self.tmpdir / "docs/agents/optimization/OPTIMIZATION_LOG.md").write_text("# Log\n")

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def _validate(self, task_id):
        receipt = self.att_dir / f"{task_id}.receipt.yaml"
        result = subprocess.run(
            [sys.executable, str(self.validator), str(receipt), str(self.tmpdir)],
            capture_output=True, text=True, timeout=10,
        )
        return result.returncode, result.stdout.strip()

    def test_autoresearch_with_optimization_validates(self):
        """Autoresearch receipt with optimization evidence passes validation."""
        start = governance_start_autoresearch(target_skill=".claude/skills/debug/SKILL.md")
        tid = start["task_id"]
        governance_record_optimization(
            task_id=tid,
            optimization_round=1,
            target_skill_path=".claude/skills/debug/SKILL.md",
            change_description="Test change",
            result="improved",
        )
        code, output = self._validate(tid)
        self.assertEqual(code, 0, f"Validation failed: {output}")


if __name__ == "__main__":
    main()
