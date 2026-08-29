"""Policy engine CLI.

Usage:
  python3 -m policy_engine.cli check <rule-id> [--target DIR] [--format text|json]

Exit codes:
  0  all decisions were ALLOW
  1  at least one DENY or ESCALATE
  2  misuse (missing rule, bad args, etc.)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import ENGINE_BUNDLE_VERSION
from .engine import Engine
from .evalcontext import EvalContext
from .loaders import RuleLoadError, load_rule

DEFAULT_RULES_DIR_CANDIDATES = (
    "docs/templates/governance/rules",
)


def _find_repo_root(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).resolve()
    cwd = Path.cwd().resolve()
    for candidate in [cwd, *cwd.parents]:
        if (candidate / ".governance").is_dir():
            return candidate
    return cwd


def _find_rule_file(repo_root: Path, rule_id: str) -> Path | None:
    for rel in DEFAULT_RULES_DIR_CANDIDATES:
        candidate = repo_root / rel / f"{rule_id}.rule.yaml"
        if candidate.is_file():
            return candidate
    return None


def _print_text(rule_id: str, decisions) -> None:
    header = f"{rule_id}"
    print(header)
    for d in decisions:
        marker = {"ALLOW": "PASS ", "DENY": "FAIL ", "ESCALATE": "ESC  "}.get(d.decision, "???  ")
        subject = d.subject_id or "(rule-scope)"
        print(f"  {marker} {subject} — {d.reason}")
    blocked = sum(1 for d in decisions if d.decision in ("DENY", "ESCALATE"))
    allowed = sum(1 for d in decisions if d.decision == "ALLOW")
    print(f"  summary: allow={allowed} deny={blocked}")


def _print_json(rule_id: str, decisions) -> None:
    payload = {
        "rule_id": rule_id,
        "engine_bundle_version": ENGINE_BUNDLE_VERSION,
        "decisions": [
            {
                "rule_id": d.rule_id,
                "policy_version": d.policy_version,
                "subject": {"kind": d.subject_kind, "id": d.subject_id},
                "action": d.action,
                "decision": d.decision,
                "reason": d.reason,
                "context_hash": d.context_hash,
                "clause_id": d.clause_id,
            }
            for d in decisions
        ],
    }
    json.dump(payload, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


def _cmd_check(args: argparse.Namespace) -> int:
    repo_root = _find_repo_root(args.target)
    rule_file = _find_rule_file(repo_root, args.rule_id)
    if rule_file is None:
        print(
            f"error: rule {args.rule_id!r} not found under "
            f"{', '.join(DEFAULT_RULES_DIR_CANDIDATES)}",
            file=sys.stderr,
        )
        return 2

    try:
        rule = load_rule(rule_file)
    except RuleLoadError as err:
        print(f"error: {err} (at {err.field_path or '<root>'})", file=sys.stderr)
        return 2

    ctx = EvalContext.from_repo(repo_root)
    engine = Engine()
    decisions = engine.evaluate(rule, ctx)

    if args.format == "json":
        _print_json(args.rule_id, decisions)
    else:
        _print_text(args.rule_id, decisions)

    has_block = any(d.decision in ("DENY", "ESCALATE") for d in decisions)
    return 1 if has_block else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="policy_engine", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    check = sub.add_parser("check", help="evaluate a rule")
    check.add_argument("rule_id", help="rule id (without the .rule.yaml suffix)")
    check.add_argument("--target", default=None, help="repo root (default: auto-detect)")
    check.add_argument("--format", choices=["text", "json"], default="text")
    check.set_defaults(func=_cmd_check)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
