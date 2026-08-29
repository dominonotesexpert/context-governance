"""Tests for tools.py — governance tool handlers."""

import json
import os
import tempfile
from unittest import TestCase

from adapters.hermes.plugin.tools import (
    governance_check_authority_handler,
    governance_classify_task_handler,
    governance_enforce_hardgate_handler,
    governance_load_role_context_handler,
)


class TestGovernanceClassifyTask(TestCase):
    def test_basic_bug(self):
        result = json.loads(
            governance_classify_task_handler({"description": "Fix login bug"})
        )
        assert result["task_type"] == "bug"
        assert "debug" not in result["route"]
        assert result["debug_required"] is False
        assert result["confidence"] > 0

    def test_production_regression_requires_debug(self):
        result = json.loads(
            governance_classify_task_handler({"description": "production deploy regression"})
        )
        assert result["debug_required"] is True
        assert result["formal_verification_required"] is True

    def test_empty_description_returns_error(self):
        result = json.loads(
            governance_classify_task_handler({"description": ""})
        )
        assert "error" in result

    def test_returns_routing_authority(self):
        result = json.loads(
            governance_classify_task_handler({"description": "add feature"})
        )
        assert "routing_authority" in result


class TestGovernanceCheckAuthority(TestCase):
    def test_allow(self):
        result = json.loads(
            governance_check_authority_handler({
                "file_path": "src/main.py",
                "operation": "write",
                "current_role": "implementation",
            })
        )
        assert result["decision"] == "ALLOW"

    def test_deny(self):
        result = json.loads(
            governance_check_authority_handler({
                "file_path": "docs/agents/PROJECT_BASELINE.md",
                "operation": "read",
                "current_role": "implementation",
            })
        )
        assert result["decision"] == "DENY"

    def test_missing_params_returns_error(self):
        result = json.loads(
            governance_check_authority_handler({"file_path": "test.py"})
        )
        assert "error" in result

    def test_invalid_operation_returns_error(self):
        result = json.loads(
            governance_check_authority_handler({
                "file_path": "test.py",
                "operation": "delete",
                "current_role": "implementation",
            })
        )
        assert "error" in result


class TestGovernanceEnforceHardgate(TestCase):
    def test_pass_when_all_loaded(self):
        result = json.loads(
            governance_enforce_hardgate_handler({
                "role": "implementation",
                "loaded_docs": ["docs/agents/system/SYSTEM_GOAL_PACK.md"],
            })
        )
        assert result["status"] == "PASS"

    def test_fail_when_missing(self):
        result = json.loads(
            governance_enforce_hardgate_handler({
                "role": "implementation",
                "loaded_docs": [],
            })
        )
        assert result["status"] == "FAIL"
        assert len(result["missing_docs"]) > 0

    def test_missing_role_returns_error(self):
        result = json.loads(
            governance_enforce_hardgate_handler({
                "role": "",
                "loaded_docs": [],
            })
        )
        assert "error" in result


class TestGovernanceLoadRoleContext(TestCase):
    def test_no_governance_dir_returns_error(self):
        # Run from a temp dir with no .governance/
        old_cwd = os.getcwd()
        with tempfile.TemporaryDirectory() as tmpdir:
            os.chdir(tmpdir)
            try:
                result = json.loads(
                    governance_load_role_context_handler({"role": "implementation"})
                )
                assert "error" in result
            finally:
                os.chdir(old_cwd)

    def test_with_mock_project(self):
        old_cwd = os.getcwd()
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create mock governance structure
            os.makedirs(os.path.join(tmpdir, ".governance"))
            doc_dir = os.path.join(tmpdir, "docs", "agents", "system")
            os.makedirs(doc_dir)
            with open(os.path.join(doc_dir, "SYSTEM_GOAL_PACK.md"), "w") as f:
                f.write("# Test Goal Pack\ntest content")

            os.chdir(tmpdir)
            try:
                result = json.loads(
                    governance_load_role_context_handler({"role": "implementation"})
                )
                assert result["docs_loaded"] >= 1
                assert result["hardgate_status"] in ("PASS", "FAIL")
            finally:
                os.chdir(old_cwd)
