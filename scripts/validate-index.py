#!/usr/bin/env python3
"""Validate .governance/attestations/index.jsonl consistency.

Usage: validate-index.py <index-path> <target-root>

Checks:
  - Each line is valid JSON
  - Required fields present
  - task_id unique
  - receipt_path points to existing file
  - status/task_type match between index and receipt

Exit: 0 = valid, 1 = errors found
"""
import sys
import json
import os


def extract_yaml_field(filepath, field):
    """Extract a top-level scalar field from a YAML file."""
    try:
        with open(filepath) as f:
            for line in f:
                stripped = line.strip()
                if stripped.startswith('#') or stripped == '---' or not stripped:
                    continue
                if ':' in stripped and not line.startswith(' '):
                    k, _, v = stripped.partition(':')
                    if k.strip() == field:
                        v = v.strip().strip('"').strip("'")
                        if v in ('null', '~'):
                            return None
                        return v
    except Exception:
        pass
    return None


def main():
    if len(sys.argv) < 3:
        print("Usage: validate-index.py <index-path> <target-root>", file=sys.stderr)
        sys.exit(2)

    index_path = sys.argv[1]
    target = sys.argv[2]
    errors = []
    seen_ids = set()
    line_num = 0

    with open(index_path) as f:
        for line in f:
            line_num += 1
            line = line.strip()
            if not line:
                continue

            # 1. Valid JSON
            try:
                entry = json.loads(line)
            except json.JSONDecodeError as e:
                errors.append(f"Line {line_num}: invalid JSON — {e}")
                continue

            # 2. Required fields
            for field in ['task_id', 'task_type', 'status', 'receipt_path',
                          'created_at', 'updated_at', 'attestation_mode']:
                if field not in entry:
                    errors.append(f"Line {line_num}: missing field '{field}'")

            task_id = entry.get('task_id', '')

            # 3. Unique task_id
            if task_id in seen_ids:
                errors.append(f"Line {line_num}: duplicate task_id '{task_id}'")
            seen_ids.add(task_id)

            # 4. Receipt file exists
            receipt_path = entry.get('receipt_path', '')
            full_receipt = os.path.join(target, receipt_path) if receipt_path else ''
            if not receipt_path:
                errors.append(f"Line {line_num} ({task_id}): empty receipt_path")
                continue
            if not os.path.isfile(full_receipt):
                errors.append(f"Line {line_num} ({task_id}): receipt file not found: {receipt_path}")
                continue

            # 5. Cross-check fields
            receipt_status = extract_yaml_field(full_receipt, 'status')
            receipt_type = extract_yaml_field(full_receipt, 'task_type')
            receipt_tid = extract_yaml_field(full_receipt, 'task_id')

            index_status = entry.get('status', '')
            index_type = entry.get('task_type', '')

            if receipt_tid and receipt_tid != task_id:
                errors.append(f"Line {line_num}: index task_id '{task_id}' != receipt task_id '{receipt_tid}'")
            if receipt_status and receipt_status != index_status:
                errors.append(f"Line {line_num} ({task_id}): index status '{index_status}' != receipt status '{receipt_status}'")
            if receipt_type and receipt_type != index_type:
                errors.append(f"Line {line_num} ({task_id}): index task_type '{index_type}' != receipt task_type '{receipt_type}'")

    if errors:
        for e in errors:
            print(f"ERROR: {e}")
        sys.exit(1)
    else:
        print("OK")
        sys.exit(0)


if __name__ == '__main__':
    main()
