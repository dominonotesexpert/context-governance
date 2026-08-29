"""Rule evaluation engine."""

from __future__ import annotations

from typing import Any

from .decisions import Decision
from .evalcontext import EvalContext
from .loaders import Clause, Rule
from .predicates import PREDICATES


class Engine:
    """Rule executor.

    Stateless between evaluations. Exceptions raised by predicates become
    DENY decisions rather than propagating; this is the intentional fail-
    closed posture for a governance system.
    """

    def evaluate(self, rule: Rule, context: EvalContext) -> list[Decision]:
        if rule.kind == "static-reference":
            # static-reference rules do not evaluate; callers access .data directly.
            return []

        context_hash = context.canonical_hash(rule.inputs)

        if rule.iterate is not None:
            items = self._collect_items(rule, context)
        elif "runtime_call" in rule.inputs and context.runtime_call is not None:
            # Non-iterating rule that consumes the runtime_call envelope.
            # Pass the envelope as `item` so predicates see a single dict
            # carrying actor/subject/operation/context_class.
            items = [context.runtime_call]
        else:
            items = [None]

        decisions: list[Decision] = []
        for item in items:
            clause, decision_str, reason = self._evaluate_clauses(rule, context, item)
            subject_id = self._resolve_subject_id(rule, item)
            decisions.append(
                Decision(
                    rule_id=rule.id,
                    policy_version=rule.version,
                    subject_kind=rule.subject.kind,
                    subject_id=subject_id,
                    action=rule.action,
                    decision=decision_str,
                    reason=reason,
                    context_hash=context_hash,
                    clause_id=clause.id if clause else None,
                )
            )
        return decisions

    # ---- internal ----

    def _collect_items(self, rule: Rule, ctx: EvalContext) -> list[Any]:
        assert rule.iterate is not None
        source = self._resolve_input(rule.iterate.over, ctx)
        if source is None:
            return []
        if not isinstance(source, list):
            raise ValueError(f"iterate.over={rule.iterate.over!r} did not resolve to a list")
        items = list(source)
        if rule.iterate.filter:
            fn = PREDICATES.get(rule.iterate.filter)
            if fn is None:
                raise ValueError(f"unknown filter predicate: {rule.iterate.filter}")
            filtered = []
            for it in items:
                try:
                    if fn(ctx, it, *rule.iterate.filter_args):
                        filtered.append(it)
                except Exception:
                    # A filter exception is treated as "exclude from iteration"
                    # to avoid injecting DENY noise for items the rule never
                    # intended to look at.
                    continue
            items = filtered
        return items

    def _resolve_input(self, name: str, ctx: EvalContext) -> Any:
        if name == "staged_files":
            return list(ctx.staged_files)
        if name == "task":
            return ctx.task
        if name == "staged_content":
            return dict(ctx.staged_content)
        if name == "committed_content":
            return dict(ctx.committed_content)
        if name == "escalations_jsonl":
            return ctx.escalations_jsonl
        if name == "runtime_call":
            return ctx.runtime_call
        raise ValueError(f"unknown input: {name}")

    def _evaluate_clauses(
        self, rule: Rule, ctx: EvalContext, item: Any
    ) -> tuple[Clause | None, str, str]:
        for clause in rule.clauses:
            fn = PREDICATES.get(clause.when)
            if fn is None:
                # Unknown predicate is a configuration failure; fail closed.
                return (
                    clause,
                    "DENY",
                    f"unknown predicate '{clause.when}' in clause '{clause.id}'",
                )
            try:
                matched = fn(ctx, item, *clause.when_args, **clause.when_kwargs)
            except Exception as exc:
                return (
                    clause,
                    "DENY",
                    f"predicate '{clause.when}' raised {type(exc).__name__}: {exc}",
                )
            if matched:
                return clause, clause.decision, clause.reason
        # No clause matched: default ALLOW to match shell-script historical
        # behavior; rule authors who want fail-closed default MUST terminate
        # with a `when: always, decision: DENY` clause.
        return None, "ALLOW", "no clause matched (engine default)"

    def _resolve_subject_id(self, rule: Rule, item: Any) -> str:
        if rule.subject.id_literal is not None:
            return rule.subject.id_literal
        if rule.subject.id_from:
            # Iteration variable: subject is the current iteration value.
            if rule.iterate and rule.subject.id_from == rule.iterate.as_:
                return str(item) if item is not None else ""
            # runtime_call envelope: look up a conventional field for the
            # subject. For kind=file we use subject_path; for kind=tool we
            # use tool_name. Fall back to the envelope's own repr.
            if rule.subject.id_from == "runtime_call" and isinstance(item, dict):
                if rule.subject.kind == "file":
                    return str(item.get("subject_path") or item.get("file_path") or "")
                if rule.subject.kind == "tool":
                    return str(item.get("tool_name") or "")
                return str(item)
            # Fallback: literal input name.
            return rule.subject.id_from
        return rule.id
