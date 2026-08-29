"""Declarative policy engine for governance rules.

Exports
-------
Engine           : rule executor
Rule             : dataclass representation of a rule.yaml file
Decision         : dataclass representation of one evaluation outcome
EvalContext      : evaluation context (staged files, task state, etc.)
load_rule        : parse a rule file from disk
PREDICATES       : name -> predicate callable registry
register_predicate  : decorator to register a new predicate
RuleLoadError    : raised on malformed rule files

Authority: docs/plans/2026-04-23-policy-engine-design.md §5
"""

from .decisions import Decision
from .engine import Engine
from .evalcontext import EvalContext
from .loaders import Rule, RuleLoadError, load_rule
from .predicates import PREDICATES, register_predicate

ENGINE_BUNDLE_VERSION = "1.0.0"

__all__ = [
    "Decision",
    "Engine",
    "EvalContext",
    "Rule",
    "RuleLoadError",
    "load_rule",
    "PREDICATES",
    "register_predicate",
    "ENGINE_BUNDLE_VERSION",
]
