"""Golden fixture tests for the policy engine.

For each subdirectory under tests/policy_golden/<rule-id>/, every *.json
fixture is loaded, the named rule is evaluated against the fixture's
context, and the emitted decisions are asserted to match
`expected_decisions` on the key fields.

Fixture shape:
    {
        "name": "...",
        "context": { staged_files, staged_content, committed_content,
                     task, escalations_jsonl },
        "expected_decisions": [
            {"subject.id": "...", "decision": "ALLOW|DENY|ESCALATE",
             "clause_id": "..."}
        ]
    }

Authority: docs/plans/2026-04-23-policy-engine-implementation-plan.md Step C
"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

_TEST_DIR = Path(__file__).resolve().parent
_SERVER_DIR = _TEST_DIR.parent
if str(_SERVER_DIR) not in sys.path:
    sys.path.insert(0, str(_SERVER_DIR))

from policy_engine import Engine, EvalContext, load_rule  # noqa: E402

_REPO_ROOT = _SERVER_DIR.parent
_RULES_DIR = _REPO_ROOT / "docs" / "templates" / "governance" / "rules"
_GOLDEN_DIR = _TEST_DIR / "policy_golden"


def _discover_fixtures() -> list[tuple[str, Path]]:
    fixtures: list[tuple[str, Path]] = []
    if not _GOLDEN_DIR.is_dir():
        return fixtures
    for rule_dir in sorted(_GOLDEN_DIR.iterdir()):
        if not rule_dir.is_dir():
            continue
        for fx in sorted(rule_dir.glob("*.json")):
            fixtures.append((rule_dir.name, fx))
    return fixtures


class TestPolicyGolden(unittest.TestCase):
    """One test case per fixture, dynamically attached below."""


def _make_test(rule_id: str, fixture_path: Path):
    def test(self):
        payload = json.loads(fixture_path.read_text())
        rule_file = _RULES_DIR / f"{rule_id}.rule.yaml"
        self.assertTrue(rule_file.is_file(), f"rule file not found: {rule_file}")
        rule = load_rule(rule_file)
        ctx = EvalContext.from_fixture(payload.get("context", {}))
        engine = Engine()
        decisions = engine.evaluate(rule, ctx)

        expected = payload.get("expected_decisions", [])
        self.assertEqual(
            len(decisions),
            len(expected),
            f"{fixture_path.name}: expected {len(expected)} decisions, got {len(decisions)}:\n"
            + "\n".join(f"  {d.subject_id} -> {d.decision} ({d.clause_id})" for d in decisions),
        )

        for got, want in zip(decisions, expected):
            if "subject.id" in want:
                self.assertEqual(got.subject_id, want["subject.id"], f"{fixture_path.name} subject.id")
            if "decision" in want:
                self.assertEqual(got.decision, want["decision"], f"{fixture_path.name} decision")
            if "clause_id" in want:
                self.assertEqual(got.clause_id, want["clause_id"], f"{fixture_path.name} clause_id")

    test.__name__ = f"test_{rule_id.replace('-', '_')}_{fixture_path.stem.replace('-', '_')}"
    return test


for _rule_id, _fx in _discover_fixtures():
    _fn = _make_test(_rule_id, _fx)
    setattr(TestPolicyGolden, _fn.__name__, _fn)


if __name__ == "__main__":
    unittest.main()
