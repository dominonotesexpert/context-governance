"""Rule file loader. Uses the hand-rolled YAML parser from server.py."""

from __future__ import annotations

import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

_SERVER_DIR = Path(__file__).resolve().parent.parent
if str(_SERVER_DIR) not in sys.path:
    sys.path.insert(0, str(_SERVER_DIR))

from server import _parse_receipt  # noqa: E402  -- reuses the YAML parser


SUPPORTED_SCHEMA_VERSIONS = {1}
VALID_DECISIONS = {"ALLOW", "DENY", "ESCALATE"}


class RuleLoadError(Exception):
    """Raised on malformed rule files."""

    def __init__(self, message: str, field_path: str = ""):
        super().__init__(message)
        self.field_path = field_path


@dataclass
class IterateSpec:
    over: str
    as_: str
    filter: str | None = None
    filter_args: list[Any] = field(default_factory=list)


@dataclass
class SubjectSpec:
    kind: str
    id_from: str | None = None   # iteration variable name, if iterating
    id_literal: str | None = None  # fixed string, otherwise


@dataclass
class Clause:
    id: str
    when: str
    decision: str
    reason: str
    when_args: list[Any] = field(default_factory=list)
    when_kwargs: dict = field(default_factory=dict)


@dataclass
class Rule:
    id: str
    name: str
    description: str
    version: str
    inputs: list[str]
    clauses: list[Clause]
    subject: SubjectSpec
    iterate: IterateSpec | None = None
    action: str = "evaluate"
    kind: str = "dynamic"   # dynamic | static-reference
    data: dict | None = None  # populated for static-reference rules


def load_rule(path: str | Path) -> Rule:
    """Load a rule file from disk."""
    path = Path(path)
    if not path.is_file():
        raise RuleLoadError(f"rule file not found: {path}", field_path="path")
    raw = _parse_receipt(path)
    if not isinstance(raw, dict):
        raise RuleLoadError("rule file must parse to a mapping", field_path="<root>")
    return _parse_rule_dict(raw, source_path=str(path))


def _require(d: dict, key: str, type_: type, *, path: str) -> Any:
    if key not in d or d[key] is None:
        raise RuleLoadError(f"missing required field: {key}", field_path=f"{path}{key}")
    val = d[key]
    if not isinstance(val, type_):
        raise RuleLoadError(
            f"{key} must be {type_.__name__}, got {type(val).__name__}",
            field_path=f"{path}{key}",
        )
    return val


def _parse_rule_dict(raw: dict, *, source_path: str) -> Rule:
    schema_version = raw.get("schema_version", 1)
    if schema_version not in SUPPORTED_SCHEMA_VERSIONS:
        raise RuleLoadError(
            f"unsupported rule schema_version: {schema_version}",
            field_path="schema_version",
        )

    kind = raw.get("kind", "dynamic")
    if kind not in {"dynamic", "static-reference"}:
        raise RuleLoadError(f"unknown rule kind: {kind}", field_path="kind")

    rule_id = _require(raw, "id", str, path="")
    name = _require(raw, "name", str, path="")
    version = _require(raw, "version", str, path="")
    description = raw.get("description", "") or ""

    if kind == "static-reference":
        return Rule(
            id=rule_id,
            name=name,
            description=description,
            version=version,
            inputs=[],
            clauses=[],
            subject=SubjectSpec(kind="reference", id_literal=rule_id),
            iterate=None,
            action="lookup",
            kind="static-reference",
            data=raw.get("data") or {},
        )

    # dynamic rules
    inputs_raw = raw.get("inputs") or []
    if not isinstance(inputs_raw, list):
        raise RuleLoadError("inputs must be a list", field_path="inputs")
    inputs = [str(x) for x in inputs_raw]

    iterate_raw = raw.get("iterate")
    iterate = None
    if iterate_raw is not None:
        if not isinstance(iterate_raw, dict):
            raise RuleLoadError("iterate must be an object", field_path="iterate")
        iterate = IterateSpec(
            over=_require(iterate_raw, "over", str, path="iterate."),
            as_=_require(iterate_raw, "as", str, path="iterate."),
            filter=iterate_raw.get("filter"),
            filter_args=iterate_raw.get("filter_args") or [],
        )

    subject_raw = raw.get("subject")
    if not isinstance(subject_raw, dict):
        raise RuleLoadError("subject must be an object", field_path="subject")
    subject = SubjectSpec(
        kind=_require(subject_raw, "kind", str, path="subject."),
        id_from=subject_raw.get("id_from"),
        id_literal=subject_raw.get("id_literal"),
    )

    clauses_raw = raw.get("clauses") or []
    if not isinstance(clauses_raw, list) or not clauses_raw:
        raise RuleLoadError("clauses must be a non-empty list", field_path="clauses")
    clauses = []
    for idx, c in enumerate(clauses_raw):
        if not isinstance(c, dict):
            raise RuleLoadError(
                f"clause[{idx}] must be an object", field_path=f"clauses[{idx}]"
            )
        cid = _require(c, "id", str, path=f"clauses[{idx}].")
        when = _require(c, "when", str, path=f"clauses[{idx}].")
        decision = _require(c, "decision", str, path=f"clauses[{idx}].")
        reason = _require(c, "reason", str, path=f"clauses[{idx}].")
        if decision not in VALID_DECISIONS:
            raise RuleLoadError(
                f"unknown decision: {decision}", field_path=f"clauses[{idx}].decision"
            )
        clauses.append(
            Clause(
                id=cid,
                when=when,
                decision=decision,
                reason=reason,
                when_args=c.get("when_args") or [],
                when_kwargs=c.get("when_kwargs") or {},
            )
        )

    return Rule(
        id=rule_id,
        name=name,
        description=description,
        version=version,
        inputs=inputs,
        iterate=iterate,
        clauses=clauses,
        subject=subject,
        action=raw.get("action") or "evaluate",
        kind="dynamic",
    )
