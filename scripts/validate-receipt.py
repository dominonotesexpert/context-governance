#!/usr/bin/env python3
"""Validate a task receipt YAML against the canonical schema.

Usage: validate-receipt.py <receipt-path> [<target-root>]

Exit: 0 = valid, 1 = validation errors, 2 = parse error
"""
import sys
import os
import re

def parse_yaml_simple(text):
    """Parse a subset of YAML sufficient for receipt files.

    Handles: scalars, nested objects (2-space indent), arrays (- item),
    array-of-objects (- key: val on same line, then indented key: val).
    Does NOT handle flow syntax, multi-line strings, or anchors.
    """
    lines = []
    for line in text.splitlines():
        stripped = line.rstrip()
        if not stripped or stripped.startswith('#') or stripped == '---':
            continue
        lines.append(line.rstrip())

    root = {}
    # stack: list of (container, indent, key_in_parent, parent)
    # container is the dict/list we're currently filling
    stack = [(root, -1, None, None)]
    current_list_item = None
    current_list_item_indent = -1

    for i, line in enumerate(lines):
        indent = len(line) - len(line.lstrip())
        content = line.lstrip()

        # Pop stack entries at same or deeper indent
        while len(stack) > 1 and stack[-1][1] >= indent:
            stack.pop()

        parent_container = stack[-1][0]

        # Array item
        if content.startswith('- '):
            item_content = content[2:].strip()

            # If parent is a dict, find the last key and convert its value to a list
            if isinstance(parent_container, dict):
                # Walk up to find the dict that owns this indent level
                # The array belongs to the last key added at a lower indent
                owner = None
                owner_key = None
                for si in range(len(stack) - 1, -1, -1):
                    c, ci, k, p = stack[si]
                    if isinstance(c, dict) and ci < indent:
                        # Find the last key in this dict whose value should be a list
                        for dk in reversed(list(c.keys())):
                            if isinstance(c[dk], dict) and not c[dk]:
                                # Empty dict placeholder — convert to list
                                c[dk] = []
                                owner = c[dk]
                                owner_key = dk
                                break
                            elif isinstance(c[dk], list):
                                owner = c[dk]
                                owner_key = dk
                                break
                        if owner is not None:
                            break
                if owner is None:
                    # Fallback: create list on parent
                    owner = []

                if ':' in item_content and not item_content.startswith('"'):
                    k, _, v = item_content.partition(':')
                    obj = {k.strip(): _parse_scalar(v.strip())}
                    owner.append(obj)
                    current_list_item = obj
                    current_list_item_indent = indent
                else:
                    owner.append(_parse_scalar(item_content))
                    current_list_item = None
            elif isinstance(parent_container, list):
                if ':' in item_content and not item_content.startswith('"'):
                    k, _, v = item_content.partition(':')
                    obj = {k.strip(): _parse_scalar(v.strip())}
                    parent_container.append(obj)
                    current_list_item = obj
                    current_list_item_indent = indent
                else:
                    parent_container.append(_parse_scalar(item_content))
                    current_list_item = None
            continue

        # Continuation of array-of-objects item
        if current_list_item is not None and indent > current_list_item_indent and ':' in content:
            k, _, v = content.partition(':')
            current_list_item[k.strip()] = _parse_scalar(v.strip())
            continue

        # Key: value
        if ':' in content:
            current_list_item = None
            k, _, v = content.partition(':')
            k = k.strip()
            v = v.strip()

            # Re-pop stack for this indent
            while len(stack) > 1 and stack[-1][1] >= indent:
                stack.pop()
            parent_container = stack[-1][0]

            if not isinstance(parent_container, dict):
                continue

            if v == '' or v is None:
                # Empty value — could be dict or list, decide later
                new_obj = {}
                parent_container[k] = new_obj
                stack.append((new_obj, indent, k, parent_container))
            elif v.startswith('[') and v.endswith(']'):
                inner = v[1:-1].strip()
                if inner:
                    parsed = [_parse_scalar(x.strip()) for x in inner.split(',')]
                else:
                    parsed = []
                parent_container[k] = parsed
                stack.append((parsed, indent, k, parent_container))
            elif v == '{}':
                parent_container[k] = {}
            else:
                parent_container[k] = _parse_scalar(v)

    return root


def _parse_scalar(v):
    if not v or v == '~' or v == 'null':
        return None
    if v == 'true':
        return True
    if v == 'false':
        return False
    if v.startswith('"') and v.endswith('"'):
        return v[1:-1]
    if v.startswith("'") and v.endswith("'"):
        return v[1:-1]
    try:
        return int(v)
    except ValueError:
        pass
    return v


def _try_yaml_import(text):
    """Try to use PyYAML if available; fall back to simple parser."""
    try:
        import yaml
        return yaml.safe_load(text)
    except ImportError:
        return parse_yaml_simple(text)


def validate_receipt(data, target_root):
    errors = []

    # 1. Required top-level fields
    for field in ['schema_version', 'task_id', 'task_type', 'status', 'attestation_mode']:
        if field not in data or data[field] is None:
            errors.append(f"Missing required field: {field}")

    # 2. Enum validation
    valid_task_types = ['bug', 'feature', 'refactor', 'design', 'architecture',
                        'protocol', 'contract_authoring', 'autoresearch', 'trivial']
    task_type = data.get('task_type', '')
    if task_type and task_type not in valid_task_types:
        errors.append(f"Invalid task_type: {task_type} (valid: {', '.join(valid_task_types)})")

    valid_statuses = ['in_progress', 'completed', 'abandoned']
    status = data.get('status', '')
    if status and status not in valid_statuses:
        errors.append(f"Invalid status: {status} (valid: {', '.join(valid_statuses)})")

    valid_modes = ['mcp', 'manual_attestation']
    mode = data.get('attestation_mode', '')
    if mode and mode not in valid_modes:
        errors.append(f"Invalid attestation_mode: {mode} (valid: {', '.join(valid_modes)})")

    # 3. Task ID format
    task_id = str(data.get('task_id', ''))
    if task_id and not re.match(r'^T-\d{8}-\d{3,}$', task_id):
        errors.append(f"Invalid task_id format: {task_id} (expected T-YYYYMMDD-NNN)")

    # 4. Manual attestation requires fallback reason
    if mode == 'manual_attestation':
        reason = data.get('manual_fallback_reason')
        if not reason:
            errors.append("manual_attestation requires non-empty manual_fallback_reason")

    # 5. Scope object
    scope = data.get('scope')
    if scope is None or not isinstance(scope, dict):
        errors.append("Missing required field: scope")
    else:
        if 'affected_modules' not in scope:
            errors.append("Missing scope.affected_modules")
        if 'affected_paths' not in scope:
            errors.append("Missing scope.affected_paths")

    # 6. Governance claims — per task_type
    claims = data.get('governance_claims')
    if claims is None or not isinstance(claims, dict):
        errors.append("Missing required field: governance_claims")
        claims = {}

    if task_type == 'bug':
        if claims.get('debug_case_present') is not True:
            errors.append("bug task requires governance_claims.debug_case_present: true")
        if not claims.get('module_contract_refs'):
            errors.append("bug task requires governance_claims.module_contract_refs")

    if task_type in ('feature', 'refactor'):
        if not claims.get('module_contract_refs'):
            errors.append(f"{task_type} task requires governance_claims.module_contract_refs")

    if task_type == 'autoresearch':
        if not claims.get('optimization_log_ref'):
            errors.append("autoresearch task requires governance_claims.optimization_log_ref")
        if claims.get('escalation_upstream') is not True:
            errors.append("autoresearch task requires governance_claims.escalation_upstream: true")

    # 7. Evidence refs
    evidence_refs = data.get('evidence_refs')
    if not isinstance(evidence_refs, list):
        evidence_refs = []

    valid_kinds = ['debug_case', 'module_contract', 'acceptance_rules',
                   'verification_oracle', 'engineering_constraint', 'optimization_artifact']
    ref_kinds = []
    for ref in evidence_refs:
        if isinstance(ref, dict):
            kind = ref.get('kind', '')
            if kind and kind not in valid_kinds:
                errors.append(f"Invalid evidence_refs kind: {kind}")
            ref_kinds.append(kind)
            ref_path = ref.get('path', '')
            if ref_path and target_root:
                full = os.path.join(target_root, ref_path)
                if not os.path.exists(full):
                    errors.append(f"evidence_refs path does not exist: {ref_path}")

    # Required evidence kinds by task type
    if task_type == 'bug':
        if 'debug_case' not in ref_kinds:
            errors.append("bug task requires evidence_refs with kind: debug_case")
        if 'module_contract' not in ref_kinds:
            errors.append("bug task requires evidence_refs with kind: module_contract")
    if task_type in ('feature', 'refactor'):
        if 'module_contract' not in ref_kinds:
            errors.append(f"{task_type} task requires evidence_refs with kind: module_contract")
    if task_type == 'autoresearch':
        if 'optimization_artifact' not in ref_kinds:
            errors.append("autoresearch task requires evidence_refs with kind: optimization_artifact")

    # 8. Lifecycle
    lifecycle = data.get('lifecycle')
    if lifecycle is None or not isinstance(lifecycle, dict):
        errors.append("Missing required field: lifecycle")
        lifecycle = {}

    for lf in ['created_at', 'updated_at', 'issuer']:
        if not lifecycle.get(lf):
            errors.append(f"Missing lifecycle.{lf}")

    return errors


def main():
    if len(sys.argv) < 2:
        print("Usage: validate-receipt.py <receipt-path> [<target-root>]", file=sys.stderr)
        sys.exit(2)

    receipt_path = sys.argv[1]
    target_root = sys.argv[2] if len(sys.argv) > 2 else '.'

    try:
        with open(receipt_path) as f:
            text = f.read()
    except Exception as e:
        print(f"ERROR: Cannot read {receipt_path}: {e}")
        sys.exit(2)

    data = _try_yaml_import(text)
    if not data or not isinstance(data, dict):
        print(f"ERROR: Failed to parse {receipt_path} as YAML")
        sys.exit(2)

    errors = validate_receipt(data, target_root)

    if errors:
        for e in errors:
            print(f"ERROR: {e}")
        sys.exit(1)
    else:
        print("OK")
        sys.exit(0)


if __name__ == '__main__':
    main()
