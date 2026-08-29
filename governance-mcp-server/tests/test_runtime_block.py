"""Runtime-enforcement integration tests (M3).

Covers:
  1. Claude Code hook blocks implementation writing PROJECT_BASELINE (exit 1).
  2. Claude Code hook allows system-architect writing SYSTEM_INVARIANTS (exit 0).
  3. MCP _evaluate_authority denies impl write to BASELINE.
  4. MCP _evaluate_authority allows SA read of BASELINE.
  5. Hermes check_authority returns abort/rule_id/policy_version on DENY.
  6. context_class=restricted + WebFetch -> DENY via policy engine.
  7. context_class=public + WebFetch -> ALLOW via policy engine.
  8. Engine unavailable (monkeypatched) -> fail-closed DENY for write.

Authority: docs/plans/2026-04-23-runtime-enforcement-implementation-plan.md Step J.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_TEST_DIR = Path(__file__).resolve().parent
_MCP_DIR = _TEST_DIR.parent
_REPO_ROOT = _MCP_DIR.parent
for p in (str(_MCP_DIR), str(_REPO_ROOT / "adapters" / "hermes")):
    if p not in sys.path:
        sys.path.insert(0, p)


class TestClaudeCodeHook(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._project = tempfile.TemporaryDirectory()
        cls.repo_root = Path(cls._project.name)
        bootstrap = subprocess.run(
            [
                "bash",
                str(_REPO_ROOT / "scripts" / "bootstrap-project.sh"),
                "--target",
                str(cls.repo_root),
                "--adapter",
                "claude-code",
            ],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        if bootstrap.returncode != 0:
            cls._project.cleanup()
            raise RuntimeError(f"bootstrap failed: {bootstrap.stderr}")
        cls.cc_hook = cls.repo_root / "adapters" / "claude-code" / "cc-authority-hook.py"

    @classmethod
    def tearDownClass(cls):
        cls._project.cleanup()

    def _run_hook(self, env_overrides: dict) -> subprocess.CompletedProcess:
        env = os.environ.copy()
        env["CG_REPO_ROOT"] = str(self.repo_root)
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        env.update(env_overrides)
        return subprocess.run(
            [sys.executable, str(self.cc_hook)],
            capture_output=True,
            text=True,
            env=env,
            timeout=20,
            check=False,
        )

    def test_impl_writes_baseline_is_blocked(self):
        result = self._run_hook({
            "CG_ACTOR_ROLE": "implementation",
            "CLAUDE_TOOL_NAME": "Edit",
            "CLAUDE_TOOL_PARAM_file_path": "docs/agents/PROJECT_BASELINE.md",
        })
        self.assertEqual(result.returncode, 1)
        self.assertIn("BLOCKED", result.stderr)

    def test_sa_writes_invariants_is_allowed(self):
        result = self._run_hook({
            "CG_ACTOR_ROLE": "system-architect",
            "CLAUDE_TOOL_NAME": "Edit",
            "CLAUDE_TOOL_PARAM_file_path": "docs/agents/system/SYSTEM_INVARIANTS.md",
        })
        self.assertEqual(result.returncode, 0)

    def test_restricted_webfetch_is_blocked(self):
        # Temporarily publish a current-task.json naming context_class: restricted.
        task_file = self.repo_root / ".governance" / "current-task.json"
        previous = task_file.read_text() if task_file.exists() else None
        try:
            task_file.parent.mkdir(parents=True, exist_ok=True)
            task_file.write_text(
                '{"task_id":"T-M3-TEST-001","active_role":"implementation",'
                '"context_class":"restricted"}'
            )
            result = self._run_hook({
                "CG_ACTOR_ROLE": "implementation",
                "CLAUDE_TOOL_NAME": "WebFetch",
                "CLAUDE_TOOL_PARAM_file_path": "",
            })
            self.assertEqual(result.returncode, 1)
            self.assertIn("BLOCKED", result.stderr)
        finally:
            if previous is not None:
                task_file.write_text(previous)
            elif task_file.exists():
                task_file.unlink()


class TestMCPAuthorityHelper(unittest.TestCase):
    """Unit tests for the server-side _evaluate_authority helper."""

    def test_impl_writes_baseline_denied(self):
        from server import _evaluate_authority
        r = _evaluate_authority(
            "implementation", "docs/agents/PROJECT_BASELINE.md", "write"
        )
        self.assertEqual(r["decision"], "DENY")
        self.assertEqual(r["rule_id"], "authority")
        self.assertEqual(r["policy_version"], "1.0.0")

    def test_sa_reads_baseline_allowed(self):
        from server import _evaluate_authority
        r = _evaluate_authority(
            "system-architect", "docs/agents/PROJECT_BASELINE.md", "read"
        )
        self.assertEqual(r["decision"], "ALLOW")

    def test_engine_unavailable_fails_closed_on_write(self):
        # Simulate missing rule file by pointing module PROJECT_ROOT
        # at an empty temp dir.
        import server
        original_root = server.PROJECT_ROOT
        try:
            with tempfile.TemporaryDirectory() as tmp:
                server.PROJECT_ROOT = Path(tmp)
                r = server._evaluate_authority("implementation", "docs/agents/foo.md", "write")
                self.assertEqual(r["decision"], "DENY")
                self.assertIn("engine-unavailable", r["reason"])
                r2 = server._evaluate_authority("implementation", "docs/agents/foo.md", "read")
                self.assertEqual(r2["decision"], "ALLOW")
        finally:
            server.PROJECT_ROOT = original_root


class TestHermesPluginAuthority(unittest.TestCase):
    def test_check_authority_carries_abort_and_policy_version(self):
        from plugin.authority import check_authority
        r = check_authority(
            "docs/agents/PROJECT_BASELINE.md", "write", "implementation"
        )
        self.assertEqual(r["decision"], "DENY")
        self.assertTrue(r["abort"])
        self.assertEqual(r["rule_id"], "authority")
        self.assertEqual(r["policy_version"], "1.0.0")
        self.assertEqual(r["contract_version"], 1)

    def test_check_authority_allow_has_abort_false(self):
        from plugin.authority import check_authority
        r = check_authority(
            "src/core/main.ts", "write", "implementation"
        )
        self.assertEqual(r["decision"], "ALLOW")
        self.assertFalse(r["abort"])


class TestContextClassToolsRule(unittest.TestCase):
    """Verify the context-class rule directly via the policy engine."""

    def _evaluate(self, runtime_call: dict):
        from policy_engine import Engine, EvalContext, load_rule

        rule_path = (
            _REPO_ROOT
            / "docs"
            / "templates"
            / "governance"
            / "rules"
            / "context-class-tools.rule.yaml"
        )
        rule = load_rule(rule_path)
        ctx = EvalContext.from_fixture({"runtime_call": runtime_call})
        return Engine().evaluate(rule, ctx)

    def test_restricted_webfetch_denied(self):
        decisions = self._evaluate(
            {
                "actor_role": "implementation",
                "tool_name": "WebFetch",
                "context_class": "restricted",
            }
        )
        self.assertEqual(decisions[0].decision, "DENY")

    def test_public_webfetch_allowed(self):
        decisions = self._evaluate(
            {
                "actor_role": "implementation",
                "tool_name": "WebFetch",
                "context_class": "public",
            }
        )
        self.assertEqual(decisions[0].decision, "ALLOW")


if __name__ == "__main__":
    unittest.main()
