"""Named predicate registry.

A predicate has signature `(ctx, item, **kwargs) -> bool` where `item` is
the iteration value (or None for non-iterating rules). kwargs come from
the rule's `when_args` / `when_kwargs`.

Predicates MUST be side-effect-free. Raising is permitted; the engine
converts any raised exception into a DENY with an explanatory reason.

Authority: docs/plans/2026-04-23-policy-engine-design.md §5
"""

from __future__ import annotations

import fnmatch
import json
import re
from pathlib import PurePosixPath
from typing import Any, Callable

from .evalcontext import EvalContext

Predicate = Callable[..., bool]

PREDICATES: dict[str, Predicate] = {}


def register_predicate(name: str) -> Callable[[Predicate], Predicate]:
    def decorator(fn: Predicate) -> Predicate:
        if name in PREDICATES:
            raise ValueError(f"predicate {name!r} already registered")
        PREDICATES[name] = fn
        return fn

    return decorator


# ============================================================
# Generic combinators
# ============================================================


@register_predicate("always")
def _always(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    return True


@register_predicate("never")
def _never(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    return False


@register_predicate("not_predicate")
def _not(ctx: EvalContext, item: Any | None = None, inner: str = "", *inner_args: Any) -> bool:
    """Negate another predicate.

    Rule YAML form (positional to stay compatible with the flat YAML parser):
        when: not_predicate
        when_args: [is_derived_document]          # inner predicate name
        # any further when_args items are passed through as positional
        # args to the inner predicate.
    """
    if not inner or inner not in PREDICATES:
        raise ValueError(f"unknown inner predicate: {inner!r}")
    fn = PREDICATES[inner]
    return not fn(ctx, item, *inner_args)


@register_predicate("has_suffix")
def _has_suffix(ctx: EvalContext, item: Any | None = None, *suffixes: str, **kwargs: Any) -> bool:
    if not isinstance(item, str):
        return False
    return any(item.endswith(s) for s in suffixes)


# ============================================================
# Git / file predicates
# ============================================================


@register_predicate("is_new_file")
def _is_new_file(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    """True if the staged file has no committed version yet."""
    if not isinstance(item, str):
        return False
    committed = ctx.committed_content_of(item)
    return committed == ""


@register_predicate("content_differs")
def _content_differs(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    if not isinstance(item, str):
        return False
    return ctx.staged_content_of(item) != ctx.committed_content_of(item)


# ============================================================
# Frontmatter / derived-document predicates
# ============================================================

_FRONTMATTER_RE = re.compile(r"\A---\s*\n(.*?\n)---\s*\n", re.DOTALL)


def _extract_frontmatter(text: str) -> dict[str, str]:
    """Return a flat dict of top-level scalar fields from YAML frontmatter.

    Handles the documented pattern:
        ---
        key: value
        nested:
          subkey: value
        ---

    Nested keys are emitted as `parent.child`. Values are returned as
    strings; quoting (`"..."` / `'...'`) is stripped.
    """
    match = _FRONTMATTER_RE.match(text)
    if not match:
        return {}
    body = match.group(1)
    out: dict[str, str] = {}
    stack: list[tuple[int, str]] = []  # (indent, prefix)
    for line in body.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        while stack and stack[-1][0] >= indent:
            stack.pop()
        content = line.strip()
        if ":" not in content:
            continue
        key, _, value = content.partition(":")
        key = key.strip()
        value = value.strip()
        prefix = ".".join(p for _, p in stack)
        full_key = f"{prefix}.{key}" if prefix else key
        if value == "":
            stack.append((indent, key))
        else:
            stripped = value
            if (stripped.startswith('"') and stripped.endswith('"')) or (
                stripped.startswith("'") and stripped.endswith("'")
            ):
                stripped = stripped[1:-1]
            out[full_key] = stripped
    return out


@register_predicate("is_derived_document")
def _is_derived(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    """True if the staged version of the file has derivation_type in frontmatter."""
    if not isinstance(item, str):
        return False
    fm = _extract_frontmatter(ctx.staged_content_of(item))
    return "derivation_type" in fm or any(k.endswith(".derivation_type") for k in fm)


@register_predicate("derivation_context_changed")
def _derivation_context_changed(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    """True if derivation_timestamp or upstream_hash differs between staged and committed."""
    if not isinstance(item, str):
        return False
    staged_fm = _extract_frontmatter(ctx.staged_content_of(item))
    committed_fm = _extract_frontmatter(ctx.committed_content_of(item))

    def _lookup(fm: dict[str, str], key: str) -> str | None:
        # Accept both top-level and dotted-nested form.
        if key in fm:
            return fm[key]
        for k, v in fm.items():
            if k.endswith("." + key):
                return v
        return None

    for key in ("derivation_timestamp", "upstream_hash"):
        if _lookup(staged_fm, key) != _lookup(committed_fm, key):
            return True
    return False


# ============================================================
# Escalation predicates
# ============================================================


def _parse_escalations(raw: str | None) -> list[dict]:
    if not raw:
        return []
    out = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(entry, dict):
            out.append(entry)
    return out


@register_predicate("has_pending_escalation")
def _has_pending_escalation(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    for entry in _parse_escalations(ctx.escalations_jsonl):
        if entry.get("status") == "pending":
            return True
    return False


# ============================================================
# Path classification predicates
# ============================================================

_NON_GOVERNED_CODE_PREFIXES = (
    "docs/",
    ".governance/",
    ".githooks/",
    ".claude/",
    ".codex/",
    "scripts/",
    "tests/",
)


def _is_governed_code_path(path: str) -> bool:
    if path.endswith(".md"):
        return False
    for pref in _NON_GOVERNED_CODE_PREFIXES:
        if path.startswith(pref):
            return False
    return True


@register_predicate("is_governed_code_file")
def _is_governed_code_file(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    if not isinstance(item, str):
        return False
    return _is_governed_code_path(item)


@register_predicate("has_governed_code_staged")
def _has_governed_code_staged(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    return any(_is_governed_code_path(f) for f in ctx.staged_files)


# ============================================================
# Module / contract predicates
# ============================================================


def _walk_up_for_module(ctx: EvalContext, path: str) -> str | None:
    """Walk up `path`'s directory tree looking for a module whose name matches
    a subdirectory of docs/agents/modules/.
    """
    modules_dir = PurePosixPath("docs/agents/modules")
    d = PurePosixPath(path).parent
    while str(d) not in (".", "/", ""):
        name = d.name
        candidate = str(modules_dir / name)
        if ctx.exists(candidate):
            return name
        d = d.parent
    return None


@register_predicate("module_contract_exists")
def _module_contract_exists(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    if not isinstance(item, str):
        return False
    mod = _walk_up_for_module(ctx, item)
    if mod is None:
        # No module matched — treat as "no contract needed at this path".
        return True
    return ctx.exists(f"docs/agents/modules/{mod}/MODULE_CONTRACT.md")


@register_predicate("path_maps_to_governed_module")
def _path_maps_to_governed_module(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    if not isinstance(item, str):
        return False
    return _walk_up_for_module(ctx, item) is not None


# ============================================================
# Bug-evidence predicates
# ============================================================


@register_predicate("task_type_is")
def _task_type_is(ctx: EvalContext, item: Any | None = None, *types: str, **kwargs: Any) -> bool:
    task = ctx.task or {}
    return task.get("task_type") in set(types)


@register_predicate("task_requires_debug")
def _task_requires_debug(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    """Use explicit routing when present; legacy bug tasks fail safe to Debug."""
    task = ctx.task or {}
    declared = task.get("debug_required")
    if isinstance(declared, bool):
        return declared
    return task.get("task_type") == "bug"


@register_predicate("routine_bug_route_is_valid")
def _routine_bug_route_is_valid(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    task = ctx.task or {}
    return (
        task.get("task_type") == "bug"
        and task.get("debug_required") is False
        and bool(task.get("route_reason"))
        and bool(task.get("root_cause_evidence"))
    )


@register_predicate("routine_bug_route_is_invalid")
def _routine_bug_route_is_invalid(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    task = ctx.task or {}
    return task.get("task_type") == "bug" and task.get("debug_required") is False and not (
        task.get("route_reason") and task.get("root_cause_evidence")
    )


# ============================================================
# Runtime-call predicates (authority + context-class gating)
# ============================================================

_FILE_TIER_PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(r"(^|/)PROJECT_BASELINE\.md$"), "0"),
    (re.compile(r"(^|/)PROJECT_ARCHITECTURE_BASELINE\.md$"), "0.8"),
    (re.compile(r"(^|/)BASELINE_INTERPRETATION_LOG\.md$"), "0.5"),
    (re.compile(r"(^|/)SYSTEM_GOAL_PACK\.md$"), "1"),
    (re.compile(r"(^|/)ENGINEERING_CONSTRAINTS\.md$"), "1.5"),
    (re.compile(r"(^|/)SYSTEM_ARCHITECTURE\.md$"), "2"),
    (re.compile(r"(^|/)SYSTEM_INVARIANTS\.md$"), "3"),
    (re.compile(r"(^|/)SYSTEM_AUTHORITY_MAP\.md$"), "3"),
    (re.compile(r"(^|/)ROUTING_POLICY\.md$"), "3"),
    (re.compile(r"(^|/)SYSTEM_CONFLICT_REGISTER\.md$"), "3"),
    (re.compile(r"(^|/)SYSTEM_SCENARIO_MAP_INDEX\.md$"), "3"),
    (re.compile(r"(^|/)MODULE_TAXONOMY\.md$"), "3"),
    (re.compile(r"(^|/)SYSTEM_BOOTSTRAP_PACK\.md$"), "3"),
    (re.compile(r"(^|/)MODULE_CONTRACT\.md$"), "4"),
    (re.compile(r"(^|/)docs/agents/"), "5"),
    (re.compile(r"(^|/)\.governance/"), "5"),
]
_DEFAULT_TIER = "7"

_NETWORKED_TOOL_NAMES = frozenset({
    "WebFetch", "WebSearch", "Fetch", "HttpRequest",
})

_NETWORKED_BASH_RE = re.compile(r"\b(curl|wget|nc|ssh|scp|rsync|http)\b")


def _classify_tier(path: str) -> str:
    norm = path.replace("\\", "/")
    for pat, tier in _FILE_TIER_PATTERNS:
        if pat.search(norm):
            return tier
    return _DEFAULT_TIER


_AUTHORITY_MATRIX_CACHE: dict | None = None


def _load_authority_matrix() -> dict:
    """Read the authority-matrix static-reference rule once and cache it.

    The lookup is repo-root-relative so adapters that place the rule file
    under a non-standard location can override via CG_RULES_DIR.
    """
    global _AUTHORITY_MATRIX_CACHE
    if _AUTHORITY_MATRIX_CACHE is not None:
        return _AUTHORITY_MATRIX_CACHE
    # Import locally to avoid a cycle at module load time.
    import os
    from pathlib import Path as _P
    from .loaders import load_rule

    explicit = os.environ.get("CG_RULES_DIR")
    candidates: list[_P] = []
    if explicit:
        candidates.append(_P(explicit) / "authority-matrix.rule.yaml")
    # Walk up from this file to the repo root.
    here = _P(__file__).resolve()
    for parent in [here.parent] + list(here.parents):
        candidates.append(parent / "docs" / "templates" / "governance" / "rules" / "authority-matrix.rule.yaml")
    for c in candidates:
        if c.is_file():
            rule = load_rule(c)
            raw = rule.data or {}
            # Normalize quoted keys: the hand-rolled YAML parser preserves
            # surrounding quotes on map keys. "0" -> 0 so the tier string
            # returned by _classify_tier matches.
            _AUTHORITY_MATRIX_CACHE = {
                (k[1:-1] if isinstance(k, str) and len(k) >= 2 and k[0] == '"' and k[-1] == '"' else k): v
                for k, v in raw.items()
            }
            return _AUTHORITY_MATRIX_CACHE
    _AUTHORITY_MATRIX_CACHE = {}
    return _AUTHORITY_MATRIX_CACHE


@register_predicate("actor_has_authority")
def _actor_has_authority(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    """True iff the runtime_call's actor_role is permitted on the target tier.

    Expects `item` to be the runtime_call envelope (a dict). Resolves tier
    from subject_path via _FILE_TIER_PATTERNS, then consults the matrix
    under (tier, operation).
    """
    if not isinstance(item, dict):
        return False
    role = item.get("actor_role") or ""
    operation = (item.get("operation") or "").lower()
    if operation not in ("read", "write"):
        return False
    subject = item.get("subject_path") or item.get("file_path") or ""
    tier = _classify_tier(subject)
    matrix = _load_authority_matrix()
    entry = matrix.get(tier) or matrix.get(_DEFAULT_TIER) or {}
    allowed = entry.get(operation) or []
    return role in allowed


@register_predicate("restricted_networked_tool")
def _restricted_networked_tool(ctx: EvalContext, item: Any | None = None, **kwargs: Any) -> bool:
    """True iff the runtime_call targets a network-egress tool AND the
    active context_class is `restricted`. Network egress is identified by
    tool name or (for Bash) tool_args.command content.
    """
    if not isinstance(item, dict):
        return False
    if (item.get("context_class") or "internal") != "restricted":
        return False
    tool_name = item.get("tool_name") or ""
    if tool_name in _NETWORKED_TOOL_NAMES:
        return True
    if tool_name == "Bash":
        cmd = (item.get("tool_args") or {}).get("command") or ""
        if _NETWORKED_BASH_RE.search(cmd):
            return True
    return False


@register_predicate("has_debug_case_for_any_affected_module")
def _has_debug_case_for_any_affected_module(
    ctx: EvalContext, item: Any | None = None, **kwargs: Any
) -> bool:
    task = ctx.task or {}
    modules = list(task.get("affected_modules") or [])
    if not modules:
        # Fall back to walk-up detection from staged code files.
        for path in ctx.staged_files:
            if not _is_governed_code_path(path):
                continue
            mod = _walk_up_for_module(ctx, path)
            if mod and mod not in modules:
                modules.append(mod)
    for module_name in modules:
        pattern = f"docs/agents/debug/cases/DEBUG_CASE_{module_name}*.md"
        if ctx.glob(pattern):
            return True
        # Also accept if a DEBUG_CASE for this module is among staged files.
        for f in ctx.staged_files:
            if f.startswith(f"docs/agents/debug/cases/DEBUG_CASE_{module_name}") and f.endswith(".md"):
                return True
    return False
